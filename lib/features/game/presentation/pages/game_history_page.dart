import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import '../../../home/data/models/home_dashboard_data.dart';
import '../../data/services/game_api_service.dart';

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
  int _monthlyAvg = 0;
  int _monthlyGameCount = 0;
  int _monthlyStrikes = 0;
  int _monthlySpares = 0;
  int _monthlyOpens = 0;
  int _monthlyAllCoverGames = 0;
  bool _isLoading = true;

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
      final frameStatsFuture = dio.get('/games/users/$userId/monthly-frame-stats');

      final results = await Future.wait([gamesFuture, statsFuture, frameStatsFuture]);
      final games = results[0] as List<RecentGame>;
      final statsData = (results[1] as dynamic).data;
      final frameStatsData = (results[2] as dynamic).data;

      if (mounted) {
        setState(() {
          _games = games;
          _averageScore = statsData['averageScore'] ?? 0;

          final monthlyTrend = statsData['monthlyTrend'];
          if (monthlyTrend != null) {
            _monthlyAvg = monthlyTrend['currentMonthAvg'] ?? 0;
            _monthlyGameCount = monthlyTrend['currentMonthGameCount'] ?? 0;
          }

          _monthlyStrikes = frameStatsData['strikes'] ?? 0;
          _monthlySpares = frameStatsData['spares'] ?? 0;
          _monthlyOpens = frameStatsData['opens'] ?? 0;
          _monthlyAllCoverGames = frameStatsData['allCoverGames'] ?? 0;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _games.isEmpty
              ? _buildEmptyState(isDark)
              : RefreshIndicator(
                  onRefresh: _fetchData,
                  child: _buildGameList(isDark),
                ),
    );
  }

  Widget _buildGameList(bool isDark) {
    final grouped = _groupByMonth();
    final months = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 24, bottom: 100),
      itemCount: months.length + 1, // +1 for monthly performance card
      itemBuilder: (context, index) {
        // 첫 번째: 현재 월 게임 리스트 (월 라벨 없이)
        if (index == 0 && months.isNotEmpty) {
          final firstMonth = months[0];
          final games = grouped[firstMonth]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...games.map((game) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildGameCard(game, isDark),
              )),
            ],
          );
        }

        // 이번 달 요약 카드 (첫 번째 그룹 다음)
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _buildMonthlyPerformanceCard(),
          );
        }

        // 나머지 월 그룹
        final monthIndex = index - 1;
        if (monthIndex >= months.length) return const SizedBox.shrink();
        final month = months[monthIndex];
        final games = grouped[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ...games.map((game) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGameCard(game, isDark),
            )),
          ],
        );
      },
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

    return Container(
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
    );
  }

  Widget _buildMonthlyPerformanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF135BEC),
            Color(0xFF0D47C9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '이번 달 요약',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '전체',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatColumn('평균', _monthlyAvg > 0 ? '$_monthlyAvg' : '-'),
              const SizedBox(width: 32),
              _buildStatColumn('경기 수', '$_monthlyGameCount'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFrameStatItem('스트라이크', _monthlyStrikes, const Color(0xFFFBBF24)),
              _buildFrameStatItem('스페어', _monthlySpares, const Color(0xFF34D399)),
              _buildFrameStatItem('오픈', _monthlyOpens, const Color(0xFFF87171)),
              _buildFrameStatItem('올커버', _monthlyAllCoverGames, const Color(0xFF60A5FA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildFrameStatItem(String label, int count, Color accentColor) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: accentColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
      ],
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
