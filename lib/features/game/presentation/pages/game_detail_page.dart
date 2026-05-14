import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/bowling_scorer.dart';
import '../../data/models/game_detail.dart';
import '../../data/services/game_api_service.dart';
import 'series_summary_page.dart';

/// 히스토리에서 게임 카드를 탭했을 때 진입하는 읽기 전용 상세 페이지.
///
/// 표시:
/// - 헤로: 총점, 날짜/시각, 장소, (있다면) 시리즈 진행 배지
/// - 스코어카드: 10프레임 그리드
/// - 통계: 스트라이크/스페어/오픈 + 최장 연속 스트라이크
class GameDetailPage extends StatefulWidget {
  final int gameId;
  const GameDetailPage({super.key, required this.gameId});

  @override
  State<GameDetailPage> createState() => _GameDetailPageState();
}

class _GameDetailPageState extends State<GameDetailPage> {
  final GameApiService _api = GameApiService();
  GameDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final d = await _api.fetchGameDetail(widget.gameId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '게임 상세 정보를 불러오지 못했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final fg = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('경기 상세',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: fg,
            )),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState(fg)
              : _buildBody(isDark, _detail!),
    );
  }

  Widget _buildErrorState(Color fg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: fg, fontSize: 14)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetch();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, GameDetail d) {
    final stats = BowlingScorer.computeStats(d.frames);
    final streak = BowlingScorer.longestStrikeStreak(d.frames);
    final dateStr = DateFormat('yyyy년 MM월 dd일 a h:mm', 'ko_KR')
        .format(d.createdAt ?? d.startedAt ?? d.playDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _buildHero(d, dateStr),
        const SizedBox(height: 24),
        _buildScorecard(isDark, d),
        if (streak >= 2) ...[
          const SizedBox(height: 20),
          _buildStreakRow(isDark, streak),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            _buildStatBox('${stats.strikes}', '스트라이크', 'X', Colors.blue,
                isDark),
            const SizedBox(width: 12),
            _buildStatBox('${stats.spares}', '스페어', '/', Colors.purple,
                isDark),
            const SizedBox(width: 12),
            _buildStatBox('${stats.opens}', '오픈', '-', Colors.amber, isDark),
          ],
        ),
        if (d.seriesId != null) ...[
          const SizedBox(height: 20),
          _buildSeriesLink(isDark, d),
        ],
      ],
    );
  }

  Widget _buildHero(GameDetail d, String dateStr) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF135BEC), Color(0xFF0D47C9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.seriesId != null && d.seriesIndex != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '시리즈 ${d.seriesIndex}번째 게임',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${d.totalScore}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('점',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 18,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            dateStr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          if (d.location != null && d.location!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Symbols.place,
                    color: Colors.white.withValues(alpha: 0.85), size: 14),
                const SizedBox(width: 4),
                Text(
                  d.location!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScorecard(bool isDark, GameDetail d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '스코어카드',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 10,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, i) {
              return _frameTile(isDark, d, i);
            },
          ),
        ],
      ),
    );
  }

  Widget _frameTile(bool isDark, GameDetail d, int i) {
    final cum = d.cumulativeScores[i];
    final throwSlots = i == 9 ? 3 : 2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          Text(
            '${i + 1}',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int t = 0; t < throwSlots; t++) ...[
                if (t > 0) const SizedBox(width: 2),
                Container(
                  width: 14,
                  height: 18,
                  alignment: Alignment.center,
                  child: Text(
                    _throwDisplay(d, i, t),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Text(
            cum != null ? '$cum' : '',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 투구 칸 문자열 (X, /, -, 숫자).
  String _throwDisplay(GameDetail d, int frameIndex, int throwIndex) {
    final frame = d.frames[frameIndex];
    if (throwIndex >= frame.length) return '';
    final pins = frame[throwIndex];
    if (frameIndex < 9) {
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1 && frame[0] + pins == 10) return '/';
    } else {
      // 10프레임: 자리별로 핀 리셋 여부에 따라 X/슬래시 표기
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1) {
        if (frame[0] == 10 && pins == 10) return 'X';
        if (frame[0] != 10 && frame[0] + pins == 10) return '/';
      }
      if (throwIndex == 2) {
        if (pins == 10) return 'X';
        if (frame.length == 3 && frame[1] != 10 && frame[0] == 10 &&
            frame[1] + pins == 10) {
          return '/';
        }
        if (frame[0] != 10 && frame[0] + frame[1] == 10 && pins == 10) {
          return 'X';
        }
      }
    }
    return pins == 0 ? '-' : '$pins';
  }

  Widget _buildStreakRow(bool isDark, int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.local_fire_department,
                color: Colors.deepOrange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '최장 연속 스트라이크',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak >= 3 ? '$streak연속 🔥' : '$streak연속',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeriesLink(bool isDark, GameDetail d) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeriesSummaryPage(seriesId: d.seriesId!),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFF9800).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFFF9800).withValues(alpha: 0.45)),
        ),
        child: Row(
          children: [
            Icon(Symbols.format_list_numbered,
                color: const Color(0xFFFFB74D), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '이 게임이 속한 시리즈 보기',
                style: TextStyle(
                  color:
                      isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Symbols.chevron_right,
                size: 20,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String value, String label, String symbol, Color color,
      bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  symbol,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
