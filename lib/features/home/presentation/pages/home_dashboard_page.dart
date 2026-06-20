import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/api_error.dart';
import '../../../../core/errors/api_error_classifier.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/unread_notifications_service.dart';
import '../../../../core/services/user_profile_cache.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../../core/widgets/error_retry_view.dart';
import '../../../badges/data/models/badge_item.dart';
import '../../../help/presentation/pages/help_page.dart';
import '../../../badges/data/services/badges_api_service.dart';
import '../../../badges/presentation/pages/badge_list_page.dart';
import '../../../challenges/data/models/weekly_challenge.dart';
import '../../../challenges/data/services/challenges_api_service.dart';
import '../../../challenges/presentation/widgets/weekly_challenges_card.dart';
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
    _HomeDashboardPageState._cachedStreak = null;
    _HomeDashboardPageState._cachedRecentBadge = null;
    _HomeDashboardPageState._cachedWeeklyChallenges = null;
  }

  /// 마지막으로 본 최고 점수(캐시 기준). 게임 종료 직후 "베스트 갱신" 판정용.
  /// 캐시가 비어 있으면 null.
  static int? get cachedHighestScore =>
      _HomeDashboardPageState._cachedData?.highestScore;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

enum _TrendMetric { score, strikes, spares, opens }

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final HomeApiService _apiService = HomeApiService();
  final SeriesApiService _seriesService = SeriesApiService();
  final BadgesApiService _badgesService = BadgesApiService();
  final ChallengesApiService _challengesService = ChallengesApiService();

  /// 캐싱된 대시보드 데이터 (페이지 재생성 시에도 유지)
  static HomeDashboardData? _cachedData;
  static GameSeries? _cachedBestSeries;
  static AttendanceStreak? _cachedStreak;
  static BadgeItem? _cachedRecentBadge;
  static List<WeeklyChallenge>? _cachedWeeklyChallenges;

  HomeDashboardData? _data;
  GameSeries? _bestSeries;
  AttendanceStreak? _streak;
  BadgeItem? _recentBadge;
  List<WeeklyChallenge> _weeklyChallenges = const [];
  bool _isLoading = true;
  ApiError? _error;

  /// 최근 경기 그래프 선택 metric
  _TrendMetric _selectedTrendMetric = _TrendMetric.score;

  @override
  void initState() {
    super.initState();
    _data = _cachedData;
    _bestSeries = _cachedBestSeries;
    _streak = _cachedStreak;
    _recentBadge = _cachedRecentBadge;
    _weeklyChallenges = _cachedWeeklyChallenges ?? const [];
    _isLoading = _cachedData == null;
    _fetchData();
    // 미읽음 알림 수는 전역 싱글톤이 관리. 대시보드 진입마다 동기화.
    UnreadNotificationsService.instance.refresh();
    // 첫 실행 시 1회 온보딩 다이얼로그 노출.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  /// SharedPreferences에 플래그가 없으면 도움말 안내 다이얼로그 1회 표시.
  /// "도움말 보기"를 누르면 [HelpPage]로 이동하고 플래그를 저장.
  Future<void> _maybeShowOnboarding() async {
    const flagKey = 'help_onboarding_shown_v1';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(flagKey) == true) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('스트라이크 로그에 오신 걸 환영합니다! 🎳'),
        content: const Text(
          '주요 기능과 볼링 용어를 안내해드려요.\n\n'
          '• 게임 점수 자동 계산과 기록\n'
          '• 클럽에서 다른 멤버와 함께 게임\n'
          '• 개인/클럽/종합 에버리지로 실력 추적\n'
          '• 배지와 출석 streak로 즐거움 더하기\n\n'
          '언제든 우상단 ❓ 아이콘이나 프로필 → 도움말에서 다시 볼 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpPage()),
              );
            },
            child: const Text('도움말 보기'),
          ),
        ],
      ),
    );
    await prefs.setBool(flagKey, true);
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        // 세션 유실 시 다른 사용자(id '1') 데이터를 불러오지 않는다.
        // 인증 만료는 401 가드가 로그인으로 보낸다.
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      // 메인 dashboard + 보조 4개 fetch를 병렬 실행.
      // 보조 fetch는 각자 실패해도 그 카드만 숨기도록 catch로 격리한다.
      final results = await Future.wait([
        _apiService.fetchDashboardData(userId),
        _seriesService
            .getBest(userId)
            .then<GameSeries?>((v) => v)
            .onError<Object>((_, __) => null),
        _badgesService
            .fetchStreak()
            .then<AttendanceStreak?>((v) => v)
            .onError<Object>((_, __) => null),
        _badgesService
            .fetchRecent(limit: 1)
            .then<BadgeItem?>((list) => list.isNotEmpty ? list.first : null)
            .onError<Object>((_, __) => null),
        _challengesService
            .fetchWeekly()
            .onError<Object>((_, __) => const <WeeklyChallenge>[]),
      ]);
      final data = results[0] as HomeDashboardData;
      final best = results[1] as GameSeries?;
      final streak = results[2] as AttendanceStreak?;
      final recentBadge = results[3] as BadgeItem?;
      final weekly = results[4] as List<WeeklyChallenge>;
      if (mounted) {
        setState(() {
          _data = data;
          _bestSeries = best;
          _streak = streak;
          _recentBadge = recentBadge;
          _weeklyChallenges = weekly;
          _cachedData = data;
          _cachedBestSeries = best;
          _cachedStreak = streak;
          _cachedRecentBadge = recentBadge;
          _cachedWeeklyChallenges = weekly;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e, st) {
      final err = ApiErrorClassifier.from(e, st);
      // 인증 만료는 별도 401 가드가 처리하므로 본 화면 에러 UI는 노출하지 않음.
      if (err.type != ApiErrorType.unauthorized) {
        AppLogger.captureError(e, stackTrace: st, context: 'home_dashboard_fetch');
      }
      if (!mounted) return;
      setState(() {
        _error = err;
        _isLoading = false;
      });
      // 캐시 데이터가 있는 상태에서의 갱신 실패는 SnackBar로만 알리고 화면은 유지.
      if (_data != null && err.type != ApiErrorType.unauthorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err.message)),
        );
      }
    }
  }

  Future<void> _retryFetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _fetchData();
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
        body: const SafeArea(
          top: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // 첫 로드 실패 (캐시 없음 + 에러). 재시도 화면으로 대체.
    if (_error != null && data == null) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: _buildAppBar(isDark, ''),
        body: SafeArea(
          top: false,
          child: ErrorRetryView(
            error: _error!,
            onRetry: _retryFetch,
          ),
        ),
      );
    }

    // 로딩 완료 후 빈 데이터일 경우
    if (data == null || data.isEmpty) {
      return Scaffold(
        backgroundColor:
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        appBar: _buildAppBar(isDark, data?.nickname ?? ''),
        body: SafeArea(
          top: false,
          child: _buildEmptyState(isDark),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: _buildAppBar(isDark, data.nickname),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                  title: '종합 에버리지',
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
            const SizedBox(height: 12),
            // 개인/클럽 에버리지 분할 표시 (클럽 미가입자는 클럽 값이 0)
            _buildAverageBreakdown(data, isDark),
            const SizedBox(height: 16),

            // 출석 streak + 최근 배지 카드 (모든 데이터 로드 후 노출)
            if (_streak != null || _recentBadge != null) ...[
              _buildStreakBadgeCard(isDark),
              const SizedBox(height: 8),
            ],

            // 주간 챌린지 카드 (백엔드 응답이 있을 때만)
            if (_weeklyChallenges.isNotEmpty) ...[
              const SizedBox(height: 8),
              WeeklyChallengesCard(
                challenges: _weeklyChallenges,
                isDark: isDark,
              ),
            ],

            const SizedBox(height: 16),

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

            const SizedBox(height: 140), // 하단 여백 (네비게이션 + FAB 영역)
          ],
        ),
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
              color: Colors.grey[300],
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2), width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: AvatarImage(
              url: UserProfileCache.cached?['profile_image_url']?.toString(),
              fallback: Icon(Symbols.person,
                  size: 22, color: Colors.grey[600]),
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
        IconButton(
          tooltip: '도움말',
          icon: Icon(
            Symbols.help,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            size: 24,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpPage()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 출석 streak + 최근 획득 배지 통합 카드.
  /// 탭하면 BadgeListPage로 이동 (배지가 있으면 해당 배지를 강조).
  Widget _buildStreakBadgeCard(bool isDark) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white10 : Colors.black12;
    final textPrimary =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final current = _streak?.currentStreak ?? 0;
    final hasBadge = _recentBadge != null;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BadgeListPage(highlightKey: _recentBadge?.key),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            // 출석 streak
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Symbols.local_fire_department,
                color: Colors.deepOrange,
                size: 24,
                fill: 1,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '출석 연속',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$current일',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            // 구분
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: 1,
              height: 32,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
            // 최근 배지
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (hasBadge ? Colors.amber : Colors.grey)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.emoji_events,
                      color: hasBadge ? Colors.amber : Colors.grey,
                      size: 20,
                      fill: hasBadge ? 1 : 0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasBadge ? '최근 획득 배지' : '배지 도전',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasBadge ? _recentBadge!.name : '아직 없어요',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right,
              color: textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
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

  /// 개인/클럽 에버리지 작은 분할 표시.
  /// 클럽 미가입자는 클럽 값이 0으로 떨어지지만 시각적으로 표시는 유지(설명용).
  Widget _buildAverageBreakdown(HomeDashboardData data, bool isDark) {
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border = isDark ? Colors.white12 : Colors.black12;
    final mutedText =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primaryText =
        isDark ? Colors.white : AppColors.textPrimaryLight;

    Widget cell(String label, int value, Color accent) {
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: mutedText, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              value > 0 ? '$value' : '-',
              style: TextStyle(
                color: value > 0 ? accent : mutedText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          cell('개인', data.personalAverageScore, const Color(0xFF60A5FA)),
          Container(width: 1, height: 28, color: border),
          cell('클럽', data.clubAverageScore, const Color(0xFFFBBF24)),
          Container(width: 1, height: 28, color: border),
          cell('종합', data.averageScore, primaryText),
        ],
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
    // metric별 레이블·아이콘 정의
    const metricLabels = {
      _TrendMetric.score: '점수',
      _TrendMetric.strikes: '스트라이크',
      _TrendMetric.spares: '스페어',
      _TrendMetric.opens: '오픈',
    };
    const metricIcons = {
      _TrendMetric.score: Symbols.sports_score,
      _TrendMetric.strikes: Symbols.bolt,
      _TrendMetric.spares: Symbols.check_circle,
      _TrendMetric.opens: Symbols.radio_button_unchecked,
    };

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
          // 제목 + 지표 드롭다운 (한 줄). 칩 4개가 좁은 화면에서 가려지던 문제 해소.
          Row(
            children: [
              Expanded(
                child: Text('최근 ${trend.length}경기',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black)),
              ),
              PopupMenuButton<_TrendMetric>(
                tooltip: '지표 선택',
                initialValue: _selectedTrendMetric,
                onSelected: (m) =>
                    setState(() => _selectedTrendMetric = m),
                itemBuilder: (_) => _TrendMetric.values
                    .map((m) => PopupMenuItem<_TrendMetric>(
                          value: m,
                          child: Row(children: [
                            Icon(metricIcons[m]!,
                                size: 18,
                                color: _selectedTrendMetric == m
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : Colors.black54)),
                            const SizedBox(width: 10),
                            Text(metricLabels[m]!,
                                style: TextStyle(
                                    fontWeight: _selectedTrendMetric == m
                                        ? FontWeight.w600
                                        : FontWeight.normal)),
                          ]),
                        ))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(metricIcons[_selectedTrendMetric]!,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(metricLabels[_selectedTrendMetric]!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const SizedBox(width: 2),
                      const Icon(Symbols.expand_more,
                          size: 18, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: _buildTrendLineChart(isDark, trend, _selectedTrendMetric),
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
  /// - Y축 라벨: 최소/최대 값
  /// - 평균 라인: 점선 가이드
  /// - 최고점 마커: 색상 강조 + 라벨
  Widget _buildTrendLineChart(
      bool isDark, List<TrendData> trend, _TrendMetric metric) {
    final values = trend.map((t) {
      switch (metric) {
        case _TrendMetric.score:
          return t.score;
        case _TrendMetric.strikes:
          return t.strikes;
        case _TrendMetric.spares:
          return t.spares;
        case _TrendMetric.opens:
          return t.opens;
      }
    }).toList();

    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final avg = values.reduce((a, b) => a + b) / values.length;

    // Y축 범위: score는 0~300, 나머지(strike/spare/open)는 0~10 기준
    final double yMin;
    final double yMax;
    if (metric == _TrendMetric.score) {
      yMin = (minVal - 10).clamp(0, 300).toDouble();
      yMax = (maxVal + 10).clamp(0, 300).toDouble();
    } else {
      yMin = 0;
      yMax = (maxVal + 1).clamp(1, 10).toDouble();
    }

    // 최고값 인덱스 (여러 개면 첫 번째). 단일 데이터일 때도 안전.
    final maxIdx = values.indexOf(maxVal);

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
                .map((e) => FlSpot(e.key.toDouble(), values[e.key].toDouble()))
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
              _monthlyFrameItem('퍼펙트', data.monthlyPerfectGames,
                  const Color(0xFFC084FC)),
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

}
