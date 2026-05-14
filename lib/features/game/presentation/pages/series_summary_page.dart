import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/game_series.dart';
import '../../data/services/series_api_service.dart';

/// 시리즈 종료 후 또는 히스토리에서 시리즈 카드를 탭했을 때 진입하는 요약 페이지.
///
/// 표시 정보:
/// - 시리즈 시작/종료 시각, 게임 수
/// - 시리즈 총점, 평균
/// - 게임별 점수 목록 (1게임 → N게임)
class SeriesSummaryPage extends StatefulWidget {
  final int seriesId;
  final GameSeries? initialSeries;

  const SeriesSummaryPage({
    super.key,
    required this.seriesId,
    this.initialSeries,
  });

  @override
  State<SeriesSummaryPage> createState() => _SeriesSummaryPageState();
}

class _SeriesSummaryPageState extends State<SeriesSummaryPage> {
  final SeriesApiService _api = SeriesApiService();
  GameSeries? _series;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _series = widget.initialSeries;
    _isLoading = widget.initialSeries == null;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final series = await _api.getSeries(widget.seriesId);
      if (!mounted) return;
      setState(() {
        _series = series;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '시리즈 정보를 불러오지 못했습니다.';
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
        title: Text('시리즈 결과',
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.error_outline,
                            color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(color: fg, fontSize: 14)),
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
                )
              : _buildContent(isDark, _series!),
    );
  }

  Widget _buildContent(bool isDark, GameSeries series) {
    final hasStats = series.stats.strikes +
            series.stats.spares +
            series.stats.opens +
            series.stats.longestStrikeStreak >
        0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _buildHeroCard(series),
        const SizedBox(height: 24),
        _buildMetaRow(isDark, series),
        if (hasStats) ...[
          const SizedBox(height: 24),
          Text(
            '시리즈 합계',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          _buildAggStatsRow(isDark, series.stats),
        ],
        const SizedBox(height: 28),
        Text(
          '게임별 점수',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ..._buildGameList(isDark, series),
      ],
    );
  }

  Widget _buildAggStatsRow(bool isDark, BowlingStats s) {
    return Row(
      children: [
        _aggTile(isDark, 'X', '${s.strikes}', '스트라이크', Colors.blue),
        const SizedBox(width: 10),
        _aggTile(isDark, '/', '${s.spares}', '스페어', Colors.purple),
        const SizedBox(width: 10),
        _aggTile(isDark, '-', '${s.opens}', '오픈', Colors.amber),
        if (s.longestStrikeStreak >= 2) ...[
          const SizedBox(width: 10),
          _aggTile(
            isDark,
            null,
            '${s.longestStrikeStreak}',
            '최장 연속',
            Colors.deepOrange,
            icon: Symbols.local_fire_department,
          ),
        ],
      ],
    );
  }

  Widget _statChip(String symbol, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$symbol$count',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _aggTile(
    bool isDark,
    String? symbol,
    String value,
    String label,
    Color color, {
    IconData? icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: color, size: 18)
                    : Text(
                        symbol ?? '',
                        style: TextStyle(
                          color: color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(GameSeries series) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF135BEC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.format_list_numbered,
                  color: Colors.white.withValues(alpha: 0.85), size: 18),
              const SizedBox(width: 6),
              Text(
                '${series.gameCount}게임 시리즈',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.6,
                ),
              ),
              if (series.isCompleted) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('완주',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${series.totalScore}',
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
                child: Text(
                  '점',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '평균 ${series.averageScore.toStringAsFixed(1)}점',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(bool isDark, GameSeries series) {
    String fmtDateTime(DateTime? d) => d == null
        ? '-'
        : DateFormat('MM월 dd일 a h:mm', 'ko_KR').format(d);
    return Row(
      children: [
        _metaTile(isDark,
            label: '시작', value: fmtDateTime(series.startedAt)),
        const SizedBox(width: 12),
        _metaTile(isDark,
            label: '종료', value: fmtDateTime(series.completedAt)),
      ],
    );
  }

  Widget _metaTile(bool isDark,
      {required String label, required String value}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGameList(bool isDark, GameSeries series) {
    if (series.games.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: const Center(
            child: Text(
              '아직 저장된 게임이 없습니다.',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
        ),
      ];
    }

    // 시리즈 내 최고점 한 번만 강조
    final maxScore =
        series.games.map((g) => g.totalScore).reduce((a, b) => a > b ? a : b);
    int highlightedAt = -1;

    return [
      for (int i = 0; i < series.games.length; i++)
        Builder(builder: (context) {
          final g = series.games[i];
          final isHigh = g.totalScore == maxScore && highlightedAt == -1;
          if (isHigh) highlightedAt = i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _gameRow(isDark, g, isHigh),
          );
        }),
    ];
  }

  Widget _gameRow(bool isDark, SeriesGame g, bool isHigh) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHigh
              ? Colors.amber.withValues(alpha: 0.55)
              : (isDark ? Colors.white10 : Colors.black12),
          width: isHigh ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${g.seriesIndex ?? "-"}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${g.seriesIndex ?? "?"}번째 게임',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (g.startedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('a h:mm', 'ko_KR').format(g.startedAt!),
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 11,
                    ),
                  ),
                ],
                if (g.stats.strikes +
                        g.stats.spares +
                        g.stats.opens >
                    0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _statChip('X', g.stats.strikes, Colors.blue),
                      const SizedBox(width: 4),
                      _statChip('/', g.stats.spares, Colors.purple),
                      const SizedBox(width: 4),
                      _statChip('-', g.stats.opens, Colors.amber),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isHigh)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Symbols.workspace_premium,
                  color: Colors.amber, size: 22),
            ),
          Text(
            '${g.totalScore}',
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
