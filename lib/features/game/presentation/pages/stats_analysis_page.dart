import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/stats_analysis.dart';
import '../../data/services/stats_api_service.dart';

/// P2 기록·분석 상세 페이지.
/// 점수 추세, 월별 평균, 구질 비율, 볼링장별 통계, 인사이트를 표시합니다.
class StatsAnalysisPage extends StatefulWidget {
  const StatsAnalysisPage({super.key, this.userId});

  /// 외부에서 userId를 주입할 때 사용. null이면 SharedPreferences에서 읽음.
  final String? userId;

  @override
  State<StatsAnalysisPage> createState() => _StatsAnalysisPageState();
}

class _StatsAnalysisPageState extends State<StatsAnalysisPage> {
  final StatsApiService _service = StatsApiService();

  bool _isLoading = true;
  String? _errorMessage;

  StatsSummary? _summary;
  List<CenterStat> _centerStats = const [];
  List<MonthlyAverage> _monthlyAverages = const [];

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = widget.userId ?? prefs.getString('user_id');
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final results = await Future.wait([
        _service.fetchSummary(userId, trend: 20),
        _service.fetchCenterStats(userId),
        _service.fetchMonthlyAverages(userId, months: 6),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as StatsSummary;
        _centerStats = results[1] as List<CenterStat>;
        _monthlyAverages = results[2] as List<MonthlyAverage>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '데이터를 불러오지 못했습니다.\n잠시 후 다시 시도해 주세요.';
        _isLoading = false;
      });
    }
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  bool get _hasEnoughGames {
    final trendCount = _summary?.recentTrend.length ?? 0;
    final centerTotal =
        _centerStats.fold<int>(0, (s, c) => s + c.gameCount);
    return trendCount >= 5 || centerTotal >= 5;
  }

  Color _surfaceColor(bool isDark) =>
      isDark ? AppColors.surfaceDark : Colors.white;

  Color _borderColor(bool isDark) =>
      isDark ? Colors.white10 : Colors.black12;

  Color _textPrimary(bool isDark) =>
      isDark ? Colors.white : AppColors.textPrimaryLight;

  Color _textSecondary(bool isDark) =>
      isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          '기록 분석',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textPrimary(isDark),
          ),
        ),
        iconTheme: IconThemeData(color: _textPrimary(isDark)),
      ),
      body: SafeArea(
        top: false,
        child: _buildBody(isDark),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return _buildErrorState(isDark);
    }
    final summary = _summary;
    if (summary == null ||
        (summary.recentTrend.isEmpty &&
            _centerStats.isEmpty &&
            _monthlyAverages.isEmpty)) {
      return _buildGlobalEmptyState(isDark);
    }
    return _buildContent(isDark, summary);
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.error_outline,
                size: 56,
                color: _textSecondary(isDark)),
            const SizedBox(height: 20),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _textSecondary(isDark),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _fetchAll,
              icon: const Icon(Symbols.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.sports_score,
                size: 72,
                color: _textSecondary(isDark)),
            const SizedBox(height: 24),
            Text(
              '아직 기록된 경기가 없어요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _textPrimary(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '게임을 기록하면 자세한 분석을\n확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textSecondary(isDark),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, StatsSummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildScoreTrendSection(isDark, summary),
          const SizedBox(height: 16),
          _buildMonthlyAverageSection(isDark),
          const SizedBox(height: 16),
          _buildBallRatioSection(isDark, summary),
          const SizedBox(height: 16),
          _buildCenterStatsSection(isDark),
          const SizedBox(height: 16),
          _buildInsightsSection(isDark, summary),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── 섹션 헤더 ────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: _textPrimary(isDark),
        ),
      ),
    );
  }

  /// 공통 카드 컨테이너 (홈 대시보드 카드 스타일과 동일)
  Widget _card({required bool isDark, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(isDark)),
      ),
      child: child,
    );
  }

  // ── 1. 점수 추세 ──────────────────────────────────────────────────────────

  Widget _buildScoreTrendSection(bool isDark, StatsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('점수 추세', isDark),
        _card(
          isDark: isDark,
          child: summary.recentTrend.isEmpty
              ? _buildSectionEmpty(isDark, '기록된 경기가 없어요')
              : _buildScoreTrendChart(isDark, summary),
        ),
      ],
    );
  }

  Widget _buildScoreTrendChart(bool isDark, StatsSummary summary) {
    final trend = summary.recentTrend;
    final scores = trend.map((p) => p.score.toDouble()).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final yMin = (minScore - 10).clamp(0, 300).toDouble();
    final yMax = (maxScore + 10).clamp(0, 300).toDouble();
    final maxIdx = scores.indexOf(maxScore);

    final axisStyle = TextStyle(
      color: _textSecondary(isDark),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '최근 ${trend.length}경기',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _textPrimary(isDark),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: yMin,
              maxY: yMax,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: (yMax - yMin) <= 0 ? 1 : (yMax - yMin),
                    getTitlesWidget: (value, meta) {
                      if ((value - yMin).abs() < 0.5 ||
                          (value - yMax).abs() < 0.5) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(value.toInt().toString(),
                              style: axisStyle),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: avg,
                    color: Colors.grey.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: axisStyle,
                      labelResolver: (_) =>
                          '평균 ${avg.toStringAsFixed(0)}',
                    ),
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: trend
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), scores[e.key]))
                      .toList(),
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      final isMax = index == maxIdx;
                      return FlDotCirclePainter(
                        radius: isMax ? 6 : 3,
                        color: isMax ? Colors.amber : AppColors.primary,
                        strokeWidth: isMax ? 2 : 0,
                        strokeColor: _surfaceColor(isDark),
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _chartLabel('1경기'),
            _chartLabel('${(trend.length / 2).floor()}경기'),
            _chartLabel('${trend.length}경기'),
          ],
        ),
      ],
    );
  }

  // ── 2. 월별 평균 ──────────────────────────────────────────────────────────

  Widget _buildMonthlyAverageSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('월별 평균', isDark),
        _card(
          isDark: isDark,
          child: _monthlyAverages.isEmpty
              ? _buildSectionEmpty(isDark, '월별 데이터가 없어요')
              : _buildMonthlyBarChart(isDark),
        ),
      ],
    );
  }

  Widget _buildMonthlyBarChart(bool isDark) {
    final months = _monthlyAverages;
    // null averageScore → 0으로 처리(빈 막대). 크래시 방지.
    final scores =
        months.map((m) => (m.averageScore ?? 0).toDouble()).toList();
    final validScores = scores.where((s) => s > 0).toList();
    final maxScore = validScores.isEmpty
        ? 300.0
        : validScores.reduce((a, b) => a > b ? a : b);
    final yMax = (maxScore + 20).clamp(1, 300).toDouble();

    final axisStyle = TextStyle(
      color: _textSecondary(isDark),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: yMax,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: _borderColor(isDark),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= months.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          months[idx].monthLabel,
                          style: axisStyle,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: yMax / 2,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || (value - yMax).abs() < 1) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(value.toInt().toString(),
                              style: axisStyle),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              barGroups: months.asMap().entries.map((entry) {
                final idx = entry.key;
                final avg = scores[idx];
                final hasData = (entry.value.averageScore ?? 0) > 0;
                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: avg,
                      color: hasData
                          ? AppColors.primary
                          : _borderColor(isDark),
                      width: 24,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                    ),
                  ],
                );
              }).toList(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) =>
                      isDark ? AppColors.surfaceDark : Colors.white,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final m = months[group.x];
                    final hasData = (m.averageScore ?? 0) > 0;
                    return BarTooltipItem(
                      hasData
                          ? '${m.monthLabel}\n평균 ${m.averageScore}\n${m.gameCount}경기'
                          : '${m.monthLabel}\n기록 없음',
                      TextStyle(
                        color: _textPrimary(isDark),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. 구질 비율 ──────────────────────────────────────────────────────────

  Widget _buildBallRatioSection(bool isDark, StatsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('구질 비율', isDark),
        _card(
          isDark: isDark,
          child: _buildBallRatioContent(isDark, summary),
        ),
      ],
    );
  }

  Widget _buildBallRatioContent(bool isDark, StatsSummary summary) {
    final strikes = summary.totalStrikes;
    final spares = summary.totalSpares;
    final opens = summary.totalOpens;
    final total = strikes + spares + opens;

    if (total == 0) {
      return _buildSectionEmpty(isDark, '구질 데이터가 없어요');
    }

    double pct(int v) => v / total * 100;

    const strikeColor = Color(0xFFFBBF24);
    const spareColor = Color(0xFF34D399);
    const openColor = Color(0xFFF87171);

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: [
                if (strikes > 0)
                  PieChartSectionData(
                    value: strikes.toDouble(),
                    color: strikeColor,
                    title: '',
                    radius: 28,
                  ),
                if (spares > 0)
                  PieChartSectionData(
                    value: spares.toDouble(),
                    color: spareColor,
                    title: '',
                    radius: 28,
                  ),
                if (opens > 0)
                  PieChartSectionData(
                    value: opens.toDouble(),
                    color: openColor,
                    title: '',
                    radius: 28,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pieLegend(
                  '스트라이크', strikes, pct(strikes), strikeColor, isDark),
              const SizedBox(height: 10),
              _pieLegend('스페어', spares, pct(spares), spareColor, isDark),
              const SizedBox(height: 10),
              _pieLegend('오픈', opens, pct(opens), openColor, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pieLegend(
      String label, int count, double pct, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _textSecondary(isDark),
            ),
          ),
        ),
        Text(
          '$count회',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary(isDark),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            color: _textSecondary(isDark),
          ),
        ),
      ],
    );
  }

  // ── 4. 볼링장별 통계 ──────────────────────────────────────────────────────

  Widget _buildCenterStatsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('볼링장별 통계', isDark),
        _card(
          isDark: isDark,
          child: _centerStats.isEmpty
              ? _buildSectionEmpty(isDark, '볼링장 데이터가 없어요')
              : _buildCenterStatList(isDark),
        ),
      ],
    );
  }

  Widget _buildCenterStatList(bool isDark) {
    return Column(
      children: _centerStats.asMap().entries.map((entry) {
        final idx = entry.key;
        final c = entry.value;
        return Column(
          children: [
            if (idx > 0)
              Divider(
                height: 20,
                color: _borderColor(isDark),
              ),
            _buildCenterRow(isDark, c),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCenterRow(bool isDark, CenterStat c) {
    final dateStr = c.lastPlayed != null
        ? DateFormat('yy.MM.dd').format(c.lastPlayed!)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Symbols.sports_score,
              color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    c.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary(isDark),
                    ),
                  ),
                  Text(
                    '${c.gameCount}경기',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textSecondary(isDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  _centerStatChip('평균', '${c.averageScore}', isDark),
                  _centerStatChip('최고', '${c.highestScore}', isDark),
                  if (dateStr != null)
                    _centerStatChip('최근', dateStr, isDark),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _centerStatChip(String label, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 11,
            color: _textSecondary(isDark),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary(isDark),
          ),
        ),
      ],
    );
  }

  // ── 5. 인사이트 ──────────────────────────────────────────────────────────

  Widget _buildInsightsSection(bool isDark, StatsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('인사이트', isDark),
        if (!_hasEnoughGames)
          _card(
            isDark: isDark,
            child: Row(
              children: [
                Icon(Symbols.info, color: _textSecondary(isDark), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '게임을 5회 이상 기록하면 인사이트가 표시됩니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textSecondary(isDark),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _buildInsightCards(isDark, summary),
      ],
    );
  }

  Widget _buildInsightCards(bool isDark, StatsSummary summary) {
    final cards = <Widget>[];

    // 이번 달 폼
    final monthInsight = _buildMonthlyInsight(isDark, summary);
    if (monthInsight != null) cards.add(monthInsight);

    // 베스트 볼링장
    final bestCenter = _bestCenterInsight(isDark);
    if (bestCenter != null) cards.add(bestCenter);

    // 최근 폼
    final recentInsight = _buildRecentFormInsight(isDark, summary);
    if (recentInsight != null) cards.add(recentInsight);

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      children: cards
          .expand((w) => [w, const SizedBox(height: 10)])
          .toList()
        ..removeLast(),
    );
  }

  Widget? _buildMonthlyInsight(bool isDark, StatsSummary summary) {
    final status = summary.monthlyTrendStatus;
    final currentAvg = summary.currentMonthAvg;
    final pct = summary.monthlyTrendPercentage;

    String text;
    IconData icon;
    Color iconColor;

    switch (status) {
      case 'both':
        if (currentAvg == null || pct == null) return null;
        final sign = pct >= 0 ? '+' : '';
        final trend = pct >= 0 ? '상승' : '하락';
        icon = pct >= 0 ? Symbols.trending_up : Symbols.trending_down;
        iconColor = pct >= 0 ? const Color(0xFF34D399) : const Color(0xFFF87171);
        text =
            '이번 달 평균 $currentAvg  ·  지난달 대비 $sign${pct.toStringAsFixed(1)}% $trend';
      case 'current_only':
        if (currentAvg == null) return null;
        icon = Symbols.fiber_new;
        iconColor = const Color(0xFF60A5FA);
        text = '이번 달 평균 $currentAvg  ·  이번 달 첫 기록이에요!';
      case 'last_only':
        icon = Symbols.calendar_today;
        iconColor = _textSecondary(isDark);
        text = '이번 달 기록이 없어요. 볼링장을 방문해 보세요!';
      default:
        return null;
    }

    return _insightCard(
      isDark: isDark,
      icon: icon,
      iconColor: iconColor,
      label: '이번 달 폼',
      text: text,
    );
  }

  Widget? _bestCenterInsight(bool isDark) {
    if (_centerStats.isEmpty) return null;

    final qualified =
        _centerStats.where((c) => c.gameCount >= 2).toList();
    final pool = qualified.isNotEmpty ? qualified : _centerStats;
    pool.sort((a, b) => b.averageScore.compareTo(a.averageScore));
    final best = pool.first;

    return _insightCard(
      isDark: isDark,
      icon: Symbols.location_on,
      iconColor: const Color(0xFFA78BFA),
      label: '베스트 볼링장',
      text: '가장 잘 치는 곳: ${best.center}  ·  평균 ${best.averageScore}',
    );
  }

  Widget? _buildRecentFormInsight(bool isDark, StatsSummary summary) {
    final recent = summary.recentForm;
    if (recent == null) return null;
    final overall = summary.averageScore;
    final diff = recent - overall;
    final sign = diff >= 0 ? '+' : '';
    final color = diff > 0
        ? const Color(0xFF34D399)
        : diff < 0
            ? const Color(0xFFF87171)
            : _textSecondary(isDark);

    return _insightCard(
      isDark: isDark,
      icon: Symbols.show_chart,
      iconColor: color,
      label: '최근 폼',
      text:
          '최근 5경기 $recent  ·  시즌 평균 $overall  ($sign$diff)',
    );
  }

  Widget _insightCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor(isDark)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary(isDark),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: _textPrimary(isDark),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 공통 유틸 ─────────────────────────────────────────────────────────────

  Widget _buildSectionEmpty(bool isDark, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.inbox, size: 20, color: _textSecondary(isDark)),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.grey,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }
}
