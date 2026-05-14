import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/unread_notifications_service.dart';
import '../../../game/data/models/game_series.dart';
import '../../../game/data/services/series_api_service.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../data/models/home_dashboard_data.dart';
import '../../data/services/home_api_service.dart';

/// 사용자의 볼링 통계 및 최근 활동을 보여주는 홈 대시보드 페이지입니다.
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  /// 캐시된 데이터를 무효화합니다 (게임 저장 후 최신 데이터 로드를 위해 사용).
  static void invalidateCache() {
    _HomeDashboardPageState._cachedData = null;
    _HomeDashboardPageState._cachedBestSeries = null;
  }

  /// 마지막으로 본 최고 점수(캐시 기준). 게임 종료 직후 "베스트 갱신" 판정용.
  /// 캐시가 비어 있으면 null.
  static int? get cachedHighestScore =>
      _HomeDashboardPageState._cachedData?.highestScore;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final HomeApiService _apiService = HomeApiService();
  final SeriesApiService _seriesService = SeriesApiService();

  /// 캐싱된 대시보드 데이터 (페이지 재생성 시에도 유지)
  static HomeDashboardData? _cachedData;
  static GameSeries? _cachedBestSeries;

  HomeDashboardData? _data;
  GameSeries? _bestSeries;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _data = _cachedData;
    _bestSeries = _cachedBestSeries;
    _isLoading = _cachedData == null;
    _fetchData();
    // 미읽음 알림 수는 전역 싱글톤이 관리. 대시보드 진입마다 동기화.
    UnreadNotificationsService.instance.refresh();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '1';
    final data = await _apiService.fetchDashboardData(userId);
    // 베스트 시리즈는 실패해도 대시보드 자체에는 영향 없도록 격리.
    GameSeries? best;
    try {
      best = await _seriesService.getBest(userId);
    } catch (_) {
      best = null;
    }
    if (mounted) {
      setState(() {
        _data = data;
        _bestSeries = best;
        _cachedData = data;
        _cachedBestSeries = best;
        _isLoading = false;
      });
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
    // 복귀 시 혹시 모를 서버-클라 불일치 대비 재동기화
    UnreadNotificationsService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = _data;

    // 로딩 중일 때 (캐시 데이터 없는 첫 로드)
    if (_isLoading && data == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: _buildAppBar(isDark, ''),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 로딩 완료 후 빈 데이터일 경우
    if (data == null || data.isEmpty) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: _buildAppBar(isDark, data?.nickname ?? ''),
        body: _buildEmptyState(isDark),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: _buildAppBar(isDark, data.nickname),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('나의 에버리지',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                )),
            const SizedBox(height: 16),

            // 통계 카드 행 (현재 에버리지, 최고 점수)
            IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatCard(
                  context,
                  title: '현재 에버리지',
                  value: data.averageScore.toString(),
                  icon: Symbols.analytics,
                  isDark: isDark,
                  trend: data.trendPercentage != null
                      ? '${data.trendPercentage! >= 0 ? '+' : ''}${data.trendPercentage!.toStringAsFixed(1)}%'
                      : null,
                  trendStatus: data.trendStatus,
                  currentMonthGameCount: data.currentMonthGameCount,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  context,
                  title: '최고 점수',
                  value: data.highestScore.toString(),
                  icon: Symbols.emoji_events,
                  subtitle: data.highestScoreDate != null
                      ? DateFormat('yyyy년 MM월 dd일')
                          .format(data.highestScoreDate!)
                      : null,
                  isPrimary: true,
                  isDark: isDark,
                ),
              ],
            ),
            ),
            const SizedBox(height: 24),

            // 성적 추이 그래프
            if (data.recentTrend.isNotEmpty)
              _buildTrendChart(context, isDark, data.recentTrend),

            // 이번 달 요약 (이번 달 경기가 있을 때만)
            if ((data.currentMonthGameCount ?? 0) > 0) ...[
              const SizedBox(height: 24),
              _buildMonthlyPerformanceCard(data),
            ],

            // 베스트 시리즈 카드 (완주된 시리즈가 있을 때만)
            if (_bestSeries != null) ...[
              const SizedBox(height: 24),
              _buildBestSeriesCard(isDark, _bestSeries!),
            ],

            const SizedBox(height: 24),

            // 최근 경기 정보
            if (data.recentGame != null)
              _buildLatestGame(context, isDark, data.recentGame!),

            const SizedBox(height: 140), // 하단 여백 (네비게이션 + FAB 영역)
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, String nickname) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 16,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: const DecorationImage(
                image: NetworkImage(
                    'https://api.dicebear.com/7.x/avataaars/png?seed=Alex'),
                fit: BoxFit.cover,
              ),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2), width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('안녕하세요, $nickname님',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  )),
            ),
          ),
        ],
      ),
      actions: [
        ValueListenableBuilder<int>(
          valueListenable: UnreadNotificationsService.instance.unreadCount,
          builder: (context, count, _) => IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Symbols.notifications,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    size: 24),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      constraints: const BoxConstraints(
                          minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _openNotifications,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 데이터가 없을 때 표시되는 빈 화면
  Widget _buildEmptyState(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
              SvgPicture.asset(
                'assets/images/empty_state_bowling.svg',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 32),
              Text(
                '아직 기록된 경기가 없어요',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '첫 번째 스트라이크를 기록하고\n성장하는 나의 실력을 확인해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.5,
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

  /// 통계 카드 위젯
  /// [trendStatus] - 월별 트렌드 상태 ('both' | 'current_only' | 'last_only' | 'none')
  /// [currentMonthGameCount] - 이번 달 경기 수 (current_only 시 표시용)
  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    String? trend,
    String? trendStatus,
    int? currentMonthGameCount,
    bool isPrimary = false,
    required bool isDark,
  }) {
    final bgColor = isPrimary
        ? AppColors.primary
        : (isDark ? AppColors.surfaceDark : Colors.white);
    final textColor = (isPrimary || isDark) ? Colors.white : Colors.black;
    final labelColor = isPrimary
        ? Colors.white.withValues(alpha: 0.8)
        : (isDark ? AppColors.textSecondaryDark : Colors.grey);
    final iconColor =
        isPrimary ? Colors.white.withValues(alpha: 0.8) : AppColors.primary;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: !isPrimary
              ? Border.all(color: isDark ? Colors.white10 : Colors.black12)
              : null,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        style: TextStyle(
                            color: labelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(value,
                    style: TextStyle(
                        color: textColor,
                        fontSize: 36,
                        fontWeight: FontWeight.bold)),
                // trendStatus에 따른 뱃지 분기 렌더링
                if (trendStatus == 'both' && trend != null)
                  Builder(builder: (context) {
                    final trendColor = trend.startsWith('-')
                        ? Colors.red
                        : trend == '+0.0%' || trend == '0.0%'
                            ? Colors.grey
                            : Colors.green;
                    final trendIcon = trend.startsWith('-')
                        ? Symbols.trending_down
                        : trend == '+0.0%' || trend == '0.0%'
                            ? Symbols.trending_flat
                            : Symbols.trending_up;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: trendColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(trendIcon, color: trendColor, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            trend,
                            style: TextStyle(
                                color: trendColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  }),
                if (trendStatus == 'current_only')
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            // 하단 라벨: trendStatus에 따라 다른 텍스트 표시
            if (subtitle != null ||
                trendStatus == 'both' ||
                trendStatus == 'current_only' ||
                trendStatus == 'last_only') ...[
              const SizedBox(height: 4),
              Text(
                subtitle ??
                    (trendStatus == 'both'
                        ? '지난달 대비'
                        : trendStatus == 'current_only'
                            ? '이번 달 ${currentMonthGameCount ?? 0}경기'
                            : trendStatus == 'last_only'
                                ? '이번 달 기록이 없어요'
                                : ''),
                style: TextStyle(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey,
                    fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(
      BuildContext context, bool isDark, List<TrendData> trend) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('최근 ${trend.length}경기',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: _buildTrendLineChart(isDark, trend),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildChartLabel('1경기'),
              _buildChartLabel('${(trend.length / 2).floor()}경기'),
              _buildChartLabel('${trend.length}경기'),
            ],
          ),
        ],
      ),
    );
  }

  /// 추이 라인 차트.
  /// - Y축 라벨: 최소/최대 점수
  /// - 평균 라인: 점선 가이드
  /// - 최고점 마커: 색상 강조 + 라벨
  Widget _buildTrendLineChart(bool isDark, List<TrendData> trend) {
    final scores = trend.map((t) => t.score).toList();
    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final avg = scores.reduce((a, b) => a + b) / scores.length;

    // Y축 여백: 최저점 아래 10, 최고점 위 10. 동일 값일 때 division-by-zero 방지.
    final yMin = (minScore - 10).clamp(0, 300).toDouble();
    final yMax = (maxScore + 10).clamp(0, 300).toDouble();

    // 최고점 인덱스 (여러 개면 첫 번째). 단일 데이터일 때도 안전.
    final maxIdx = scores.indexOf(maxScore);

    final axisLabelStyle = TextStyle(
      color: isDark ? AppColors.textSecondaryDark : Colors.grey,
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    return LineChart(
      LineChartData(
        minY: yMin,
        maxY: yMax,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: (yMax - yMin) <= 0 ? 1 : (yMax - yMin),
              getTitlesWidget: (value, meta) {
                // 가장자리 값에만 라벨 표시(최저/최고). 중간 값 노이즈 차단.
                if ((value - yMin).abs() < 0.5 || (value - yMax).abs() < 0.5) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(value.toInt().toString(),
                        style: axisLabelStyle),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        // 평균 라인 (점선)
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
                style: axisLabelStyle,
                labelResolver: (_) => '평균 ${avg.toStringAsFixed(0)}',
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: trend
                .asMap()
                .entries
                .map((e) =>
                    FlSpot(e.key.toDouble(), e.value.score.toDouble()))
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
                  strokeColor: isDark
                      ? AppColors.surfaceDark
                      : Colors.white,
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
    );
  }

  /// 이번 달 요약 카드: 평균, 경기 수, 누적 X/S/-, 올커버 게임 수.
  Widget _buildMonthlyPerformanceCard(HomeDashboardData data) {
    final avg = data.currentMonthAvg ?? 0;
    final games = data.currentMonthGameCount ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF135BEC), Color(0xFF0D47C9)],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '전체',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _monthlyStatColumn('평균', avg > 0 ? '$avg' : '-'),
              const SizedBox(width: 32),
              _monthlyStatColumn('경기 수', '$games'),
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
              _monthlyFrameItem('스트라이크', data.monthlyStrikes,
                  const Color(0xFFFBBF24)),
              _monthlyFrameItem('스페어', data.monthlySpares,
                  const Color(0xFF34D399)),
              _monthlyFrameItem('오픈', data.monthlyOpens,
                  const Color(0xFFF87171)),
              _monthlyFrameItem('올커버', data.monthlyAllCoverGames,
                  const Color(0xFF60A5FA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthlyStatColumn(String label, String value) {
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
          style: const TextStyle(color: Colors.white, fontSize: 32),
        ),
      ],
    );
  }

  Widget _monthlyFrameItem(String label, int count, Color accentColor) {
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

  /// 베스트 시리즈 카드: 완주된 시리즈 중 총점 최고 기록을 표시.
  Widget _buildBestSeriesCard(bool isDark, GameSeries series) {
    final dateStr = DateFormat('yyyy년 MM월 dd일').format(series.startedAt);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF135BEC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.workspace_premium,
                color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '베스트 시리즈',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${series.totalScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '점 · ${series.gameCount}게임',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '평균 ${series.averageScore.toStringAsFixed(1)}점 · $dateStr',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          color: Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0),
    );
  }

  Widget _buildLatestGame(BuildContext context, bool isDark, RecentGame game) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('최근 경기',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Center(
                    child: Text('${game.totalScore}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.location ?? '장소 정보 없음',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
                    Text(
                      // createdAt(시간 포함)이 있으면 시:분까지, 없으면 날짜만
                      // (play_date는 MySQL DATE 컬럼이라 시간 정보가 없음)
                      game.createdAt != null
                          ? DateFormat('MM월 dd일 a h:mm').format(game.createdAt!)
                          : DateFormat('MM월 dd일').format(game.playDate),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Symbols.arrow_upward,
                            color: Colors.green, size: 14),
                        SizedBox(width: 2),
                        Text('에버리지',
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Match #42',
                      style: TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

}
