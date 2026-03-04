import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../game/presentation/pages/game_summary_page.dart';
import '../../../game/presentation/pages/frame_entry_page.dart';
import '../../../group/presentation/pages/group_detail_page.dart';
import '../../data/models/home_dashboard_data.dart';
import '../../data/services/home_api_service.dart';

/// 사용자의 볼링 통계 및 최근 활동을 보여주는 홈 대시보드 페이지입니다.
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final HomeApiService _apiService = HomeApiService();
  late Future<HomeDashboardData> _dashboardDataFuture;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    setState(() {
      _dashboardDataFuture = _loadUserIdAndFetchData();
    });
  }

  Future<HomeDashboardData> _loadUserIdAndFetchData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id') ?? '1'; // 기본값 1
    return _apiService.fetchDashboardData(userId);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return RefreshIndicator(
      onRefresh: () async {
        _fetchData();
        await _dashboardDataFuture;
      },
      child: FutureBuilder<HomeDashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              appBar: _buildAppBar(isDark, '...'),
              body: const Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              appBar: _buildAppBar(isDark, 'Guest'),
              body: Center(child: Text('데이터를 불러오는데 실패했습니다:\n${snapshot.error}')),
            );
          } 

          final data = snapshot.data!;
          
          if (data.isEmpty) {
            return Scaffold(
              backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
              appBar: _buildAppBar(isDark, data.nickname),
              body: _buildEmptyState(isDark),
            );
          }

          return Scaffold(
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            appBar: _buildAppBar(isDark, data.nickname),
            body: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    '나의 평균 점수', 
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    )
                  ),
                  const SizedBox(height: 16),
                  // 통계 카드 행 (평균 점수, 최고 점수)
                  Row(
                    children: [
                      _buildStatCard(
                        context,
                        title: '현재 평균',
                        value: data.averageScore.toString(),
                        icon: Symbols.analytics,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        context,
                        title: '최고 점수',
                        value: data.highestScore.toString(),
                        icon: Symbols.emoji_events,
                        subtitle: data.highestScoreDate != null 
                            ? DateFormat('yyyy년 MM월 dd일').format(data.highestScoreDate!)
                            : null,
                        isPrimary: true,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // 성적 추이 그래프
                  if (data.recentTrend.isNotEmpty)
                    _buildTrendChart(context, isDark, data.recentTrend),
                  const SizedBox(height: 24),
                  // 최근 게임 정보
                  if (data.recentGame != null)
                    _buildLatestGame(context, isDark, data.recentGame!),
                  const SizedBox(height: 24),
                  // 내 클럽 목록 (하드코딩 유지)
                  _buildMyClubs(context, isDark),
                  const SizedBox(height: 100), // 하단 여백
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(bool isDark, String nickname) {
    return AppBar(
      backgroundColor: isDark ? AppColors.backgroundDark.withOpacity(0.95) : AppColors.backgroundLight.withOpacity(0.95),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: const DecorationImage(
              image: NetworkImage('https://api.dicebear.com/7.x/avataaars/png?seed=Alex'),
              fit: BoxFit.cover,
            ),
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
          ),
        ),
      ),
      title: Text(
        '안녕하세요, $nickname님', 
        style: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
        )
      ),
      actions: [
        IconButton(
          icon: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            child: Icon(Symbols.notifications, color: isDark ? Colors.white : AppColors.textPrimaryLight, size: 24),
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 데이터가 없을 때 표시되는 빈 화면
  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/bowling_icon.svg',
                    width: 64,
                    height: 64,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '아직 기록된 경기가 없어요!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '첫 게임을 기록하고\n나만의 애버리지를 확인해 보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    String? subtitle,
    bool isPrimary = false,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : (isDark ? AppColors.surfaceDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: !isPrimary ? Border.all(color: isDark ? Colors.white10 : Colors.black12) : null,
          boxShadow: isPrimary 
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] 
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isPrimary ? Colors.white70 : AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: isPrimary ? Colors.white70 : (isDark ? Colors.white60 : Colors.black54), fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black), fontSize: 32, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: isPrimary ? Colors.white60 : Colors.grey, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendChart(BuildContext context, bool isDark, List<TrendData> trend) {
    if (trend.length < 2) return const SizedBox(); // 최소 2개의 데이터 필요

    final spots = trend.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.score.toDouble());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
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
                  const Text('성적 추이', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('최근 ${trend.length}게임', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.2)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestGame(BuildContext context, bool isDark, RecentGame game) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('최근 게임', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            TextButton(
              onPressed: () {}, 
              child: const Text('기록 보기', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500))
            ),
          ],
        ),
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GameSummaryPage())),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue[900]!.withOpacity(0.3) : Colors.blue[50], 
                    shape: BoxShape.circle
                  ),
                  child: Center(
                    child: Text('${game.totalScore}', style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold))
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(game.location ?? '볼링장', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      Text(DateFormat('MM월 dd일 a h:mm').format(game.playDate), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyClubs(BuildContext context, bool isDark) {
    // (기존 하드코딩된 내 클럽 목록 유지)
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('내 클럽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1), 
                shape: BoxShape.circle
              ),
              child: const Icon(Symbols.add, color: AppColors.primary, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildGroupItem(
          context, 
          name: 'Thursday Night League', 
          details: '리그 순위: 3위',
          imageUrl: 'https://api.dicebear.com/7.x/shapes/png?seed=tnl',
          members: [
            'https://api.dicebear.com/7.x/avataaars/png?seed=user1',
            'https://api.dicebear.com/7.x/avataaars/png?seed=user2'
          ],
          extraMembersCount: 2,
          isDark: isDark
        ),
        const SizedBox(height: 12),
        _buildGroupItem(
          context, 
          name: 'Weekend Strikers', 
          details: '다음 모임: 토요일 오후 7시',
          imageUrl: 'https://api.dicebear.com/7.x/shapes/png?seed=ws',
          members: [
            'https://api.dicebear.com/7.x/avataaars/png?seed=user3',
            'https://api.dicebear.com/7.x/avataaars/png?seed=user4'
          ],
          extraMembersCount: 5,
          isDark: isDark
        ),
      ],
    );
  }

  Widget _buildGroupItem(BuildContext context, {
    required String name, 
    required String details, 
    required String imageUrl,
    required List<String> members,
    required int extraMembersCount,
    required bool isDark
  }) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupDetailPage())),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const Icon(Symbols.chevron_right, color: Colors.grey, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SizedBox(
                        width: 60,
                        height: 24,
                        child: Stack(
                          children: [
                            for (int i = 0; i < members.length; i++)
                              Positioned(
                                left: i * 16.0,
                                child: Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isDark ? AppColors.surfaceDark : Colors.white, width: 2),
                                    image: DecorationImage(image: NetworkImage(members[i]), fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: members.length * 16.0,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: isDark ? AppColors.surfaceDark : Colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '+$extraMembersCount', 
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(details, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
