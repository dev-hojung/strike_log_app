import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/home_dashboard_data.dart';
import '../../data/services/home_api_service.dart';

/// 사용자의 볼링 통계 및 최근 활동을 보여주는 홈 대시보드 페이지입니다.
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  /// 캐시된 데이터를 무효화합니다 (게임 저장 후 최신 데이터 로드를 위해 사용).
  static void invalidateCache() {
    _HomeDashboardPageState._cachedData = null;
  }

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final HomeApiService _apiService = HomeApiService();

  /// 캐싱된 대시보드 데이터 (페이지 재생성 시에도 유지)
  static HomeDashboardData? _cachedData;

  HomeDashboardData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _data = _cachedData;
    _isLoading = _cachedData == null;
    _fetchData();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '1';
    final data = await _apiService.fetchDashboardData(userId);
    if (mounted) {
      setState(() {
        _data = data;
        _cachedData = data;
        _isLoading = false;
      });
    }
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
            // 주변 게임 찾기 배너 (클럽 소속 유저에게만 노출)
            if (data.hasGroup == true) ...[
              _buildNearbyBanner(),
              const SizedBox(height: 24),
            ],

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
        IconButton(
          icon: Icon(Symbols.notifications,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              size: 24),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNearbyBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.explore, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Text(
            '주변 게임 찾기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Icon(Symbols.chevron_right,
              color: Colors.white.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  /// 데이터가 없을 때 표시되는 빈 화면
  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 80, bottom: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/bowling_icon.svg',
                    width: 50,
                    height: 50,
                    colorFilter: const ColorFilter.mode(
                        AppColors.primary, BlendMode.srcIn),
                  ),
                ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('에버리지 변화',
                      style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('최근 ${trend.length}경기',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black)),
                ],
              ),
              const Icon(Symbols.more_horiz, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
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
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.1)),
                  ),
                ],
              ),
            ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('최근 경기',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black)),
          ],
        ),
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
                    Text(DateFormat('MM월 dd일 a h:mm').format(game.playDate),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
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
