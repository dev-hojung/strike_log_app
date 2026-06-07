import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/api_error.dart';
import '../../../../core/errors/api_error_classifier.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../home/data/models/home_dashboard_data.dart';
import '../../data/services/game_api_service.dart';
import 'game_detail_page.dart';
import 'series_summary_page.dart';

/// 히스토리 표시용 아이템: 단일 게임 또는 시리즈 그룹.
sealed class _HistoryItem {
  const _HistoryItem();
}

class _StandaloneGame extends _HistoryItem {
  final RecentGame game;
  const _StandaloneGame(this.game);
}

class _SeriesGroup extends _HistoryItem {
  final int seriesId;
  final List<RecentGame> games; // 시리즈 순번 오름차순으로 정렬되어 들어옴
  const _SeriesGroup(this.seriesId, this.games);

  int get totalScore =>
      games.fold(0, (acc, g) => acc + g.totalScore);
  double get averageScore =>
      games.isEmpty ? 0 : totalScore / games.length;
  // 시리즈 대표 날짜: 가장 마지막 게임의 시각 (히스토리 정렬 기준과 일치)
  DateTime get representativeDate =>
      games.first.createdAt ?? games.first.playDate;
}

/// 같은 series_id를 가진 인접 게임들을 그룹으로 묶는다.
/// 단일 게임(series_id null)은 그대로 _StandaloneGame.
List<_HistoryItem> _groupBySeries(List<RecentGame> games) {
  final out = <_HistoryItem>[];
  int i = 0;
  while (i < games.length) {
    final g = games[i];
    if (g.seriesId == null) {
      out.add(_StandaloneGame(g));
      i++;
      continue;
    }
    final sid = g.seriesId!;
    int j = i;
    while (j < games.length && games[j].seriesId == sid) {
      j++;
    }
    final groupGames = games.sublist(i, j).toList()
      // 시리즈 순번 오름차순(1게임 → N게임). 같으면 created_at 기준.
      ..sort((a, b) {
        final ai = a.seriesIndex ?? 0;
        final bi = b.seriesIndex ?? 0;
        if (ai != bi) return ai.compareTo(bi);
        final ad = a.createdAt ?? a.playDate;
        final bd = b.createdAt ?? b.playDate;
        return ad.compareTo(bd);
      });
    out.add(_SeriesGroup(sid, groupGames));
    i = j;
  }
  return out;
}

/// 사용자의 과거 볼링 경기 기록 목록을 보여주는 페이지입니다.
class GameHistoryPage extends StatefulWidget {
  const GameHistoryPage({super.key});

  @override
  State<GameHistoryPage> createState() => _GameHistoryPageState();
}

class _GameHistoryPageState extends State<GameHistoryPage> {
  final GameApiService _apiService = GameApiService();
  List<RecentGame> _games = [];
  int _averageScore = 0;
  bool _isLoading = true;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final dio = ApiClient().dio;
      final gamesFuture = _apiService.fetchGameHistory();
      final statsFuture = dio.get('/games/users/$userId/statistics');

      final results = await Future.wait([gamesFuture, statsFuture]);
      final games = results[0] as List<RecentGame>;
      final statsData = (results[1] as dynamic).data;

      if (mounted) {
        setState(() {
          _games = games;
          _averageScore = statsData['averageScore'] ?? 0;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e, st) {
      final err = ApiErrorClassifier.from(e, st);
      if (err.type != ApiErrorType.unauthorized) {
        AppLogger.captureError(e, stackTrace: st, context: 'game_history_fetch');
      }
      if (!mounted) return;
      setState(() {
        _error = err;
        _isLoading = false;
      });
    }
  }

  Future<void> _retryFetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _fetchData();
  }

  /// 게임을 월별로 그룹핑
  Map<String, List<RecentGame>> _groupByMonth() {
    final grouped = <String, List<RecentGame>>{};
    for (final game in _games) {
      final key = DateFormat('yyyy년 M월').format(game.playDate);
      grouped.putIfAbsent(key, () => []).add(game);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          '경기 기록',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.45,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _games.isEmpty
                ? ErrorRetryView(
                    error: _error!,
                    onRetry: _retryFetch,
                  )
                : _games.isEmpty
                    ? _buildEmptyState(isDark)
                    : RefreshIndicator(
                        onRefresh: _fetchData,
                        child: _buildGameList(isDark),
                      ),
      ),
    );
  }

  Widget _buildGameList(bool isDark) {
    final grouped = _groupByMonth();
    final months = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 24, bottom: 100),
      itemCount: months.length,
      itemBuilder: (context, monthIndex) {
        final month = months[monthIndex];
        final items = _groupBySeries(grouped[month]!);
        final isFirstMonth = monthIndex == 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 두 번째 월부터만 월 라벨 표시 (첫 번째 월은 페이지 컨텍스트상 생략)
            if (!isFirstMonth)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12, top: 4),
                child: Text(
                  month,
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 14,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildHistoryItem(item, isDark),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryItem(_HistoryItem item, bool isDark) {
    return switch (item) {
      _StandaloneGame(:final game) => _buildGameCard(game, isDark),
      _SeriesGroup() => _buildSeriesGroupCard(item, isDark),
    };
  }

  Widget _buildSeriesGroupCard(_SeriesGroup group, bool isDark) {
    final dateStr = DateFormat('yyyy년 MM월 dd일 HH:mm')
        .format(group.representativeDate);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeriesSummaryPage(seriesId: group.seriesId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(17, 14, 17, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF9800).withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Symbols.format_list_numbered,
                          size: 13,
                          color: const Color(0xFFFFB74D)),
                      const SizedBox(width: 4),
                      Text(
                        '${group.games.length}게임 시리즈',
                        style: const TextStyle(
                          color: Color(0xFFFFB74D),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Symbols.chevron_right,
                    size: 18,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${group.totalScore}',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFF1F5F9)
                            : AppColors.textPrimaryLight,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '평균 ${group.averageScore.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in group.games)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${g.seriesIndex ?? "?"}G ${g.totalScore}',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dateStr,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(RecentGame game, bool isDark) {
    final diff = _averageScore > 0 ? game.totalScore - _averageScore : 0;
    final isAboveAvg = diff > 0;
    final isBelowAvg = diff < 0;

    final scoreColor = isAboveAvg
        ? AppColors.primary
        : (isDark ? const Color(0xFF64748B) : AppColors.textSecondaryLight);

    // AVG 뱃지 색상
    Color badgeBgColor;
    Color badgeBorderColor;
    Color badgeTextColor;
    if (isAboveAvg) {
      badgeBgColor = const Color(0xFF10B981).withValues(alpha: 0.1);
      badgeBorderColor = const Color(0xFF10B981).withValues(alpha: 0.2);
      badgeTextColor = const Color(0xFF34D399);
    } else if (isBelowAvg) {
      badgeBgColor = const Color(0xFFF43F5E).withValues(alpha: 0.1);
      badgeBorderColor = const Color(0xFFF43F5E).withValues(alpha: 0.2);
      badgeTextColor = const Color(0xFFF43F5E);
    } else {
      badgeBgColor = const Color(0xFF64748B).withValues(alpha: 0.1);
      badgeBorderColor = const Color(0xFF64748B).withValues(alpha: 0.2);
      badgeTextColor = const Color(0xFF64748B);
    }

    final diffText = diff >= 0 ? '+$diff AVG' : '$diff AVG';
    // createdAt이 있으면 시:분까지, 없으면 기존처럼 날짜만 표시
    // (play_date는 MySQL DATE 컬럼이라 시간 정보가 없음 → created_at 사용)
    final formattedDate = game.createdAt != null
        ? DateFormat('yyyy년 MM월 dd일 HH:mm').format(game.createdAt!)
        : DateFormat('yyyy년 MM월 dd일').format(game.playDate);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GameDetailPage(gameId: game.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            // 점수
            Text(
              '${game.totalScore}',
              style: TextStyle(
                color: scoreColor,
                fontSize: 30,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            // 장소 + 날짜
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.location ?? '장소 정보 없음',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            // AVG 뱃지
            if (_averageScore > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeBorderColor),
                ),
                child: Text(
                  diffText,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.25,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.history,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 기록된 경기가 없습니다.',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '새 게임을 시작하고 기록을 남겨보세요!',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
