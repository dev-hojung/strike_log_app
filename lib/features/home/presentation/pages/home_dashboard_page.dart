import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../game/presentation/pages/game_summary_page.dart';
import '../../../group/presentation/pages/group_detail_page.dart';

/// 사용자의 볼링 통계 및 최근 활동을 보여주는 홈 대시보드 페이지입니다.
///
/// 주요 기능:
/// - 현재 평균 점수 및 최고 점수 표시
/// - 최근 10게임 성적 변화 추이 그래프 (Performance Trend)
/// - 최근 게임 결과 요약 (Latest Game)
/// - 가입된 클럽 목록 (My Clubs)
class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 다크 모드 여부 확인
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.backgroundDark.withOpacity(0.95) : AppColors.backgroundLight.withOpacity(0.95),
        elevation: 0,
        scrolledUnderElevation: 0,
        // 사용자 프로필 이미지 (임시 URL 사용)
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: const DecorationImage(
                image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDtX-u1PYwF4MsZUShkB-ZWCXN9NdMOvFoWjilOrGhp4zzhQhsP-XvPuNZdznkWEaoISeO0BdoUIUexoNWbdxcEQ4a7qB2Wf83qIQzRPXM5jQpr6Ltf-Rwx6hFHCCYjm8Psd0PDN6fFERfjvwA4YhZrB0Mf3OEVuZ_OgXaFn_2J9_RcvUyzC9GGODM5ENcGEXxXX_3tTO8TlOzY8j7F624SYXiMtvnibfqCLflo6wsYS2WvZBVP1YBfHQTHwHPeDKm9HF1RLnG9t8tx'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
            ),
          ),
        ),
        title: Text(
          '안녕하세요, Alex님', 
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
      ),
      body: SingleChildScrollView(
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
                  value: '192',
                  icon: Symbols.analytics,
                  change: '+3.2%',
                  subtitle: '지난달 대비',
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  context,
                  title: '최고 점수',
                  value: '278',
                  icon: Symbols.emoji_events,
                  subtitle: '2023년 10월 24일',
                  isPrimary: true,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 성적 추이 그래프
            _buildTrendChart(context, isDark),
            const SizedBox(height: 24),
            // 최근 게임 정보
            _buildLatestGame(context, isDark),
            const SizedBox(height: 24),
            // 내 클럽 목록
            _buildMyClubs(context, isDark),
            const SizedBox(height: 100), // 하단 여백
          ],
        ),
      ),
    );
  }

  /// 개별 통계 카드를 생성하는 위젯입니다.
  ///
  /// [title]은 카드 제목, [value]는 주요 수치입니다.
  /// [icon]은 표시할 아이콘, [change]는 등락률, [subtitle]은 부가 설명입니다.
  /// [isPrimary]가 true면 강조 색상이 적용됩니다.
  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    String? change,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: TextStyle(color: isPrimary ? Colors.white : (isDark ? Colors.white : Colors.black), fontSize: 32, fontWeight: FontWeight.bold)),
                if (change != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green.withOpacity(0.2) : Colors.green[50], 
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Row(
                      children: [
                        const Icon(Symbols.trending_up, size: 14, color: Colors.green),
                        const SizedBox(width: 2),
                        Text(change, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: isPrimary ? Colors.white60 : Colors.grey, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }

  /// 성적 추이 차트를 생성하는 위젯입니다.
  ///
  /// [fl_chart] 패키지를 사용하여 최근 10게임의 점수 변화를 시각화합니다.
  Widget _buildTrendChart(BuildContext context, bool isDark) {
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
                  Text('최근 10게임', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isDark ? Colors.white10 : Colors.grey[100],
                ),
                child: const Icon(Symbols.more_horiz, color: Colors.grey, size: 20),
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
                    spots: [
                      const FlSpot(0, 180),
                      const FlSpot(2, 195),
                      const FlSpot(4, 185),
                      const FlSpot(6, 210),
                      const FlSpot(8, 200),
                      const FlSpot(10, 230),
                    ],
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
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1게임', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('5게임', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              Text('10게임', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// 최근 게임 결과를 보여주는 카드 위젯입니다.
  ///
  /// 클릭 시 [GameSummaryPage]로 이동합니다.
  Widget _buildLatestGame(BuildContext context, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('최근 게임', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
            TextButton(onPressed: () {}, child: const Text('기록 보기', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500))),
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
                  child: const Center(child: Text('215', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sunset Lanes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      const Text('어제, 오후 8:30', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.green.withOpacity(0.2) : Colors.green[50],
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: const Row(
                        children: [
                          Icon(Symbols.arrow_upward, color: Colors.green, size: 14),
                          SizedBox(width: 4),
                          Text('평균', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text('매치 #42', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 사용자가 가입한 클럽 목록을 보여주는 위젯입니다.
  Widget _buildMyClubs(BuildContext context, bool isDark) {
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
          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDKHQRmw2rhecl4NwMUfmkbP5G-F5bBU26BJJVXvF6xXkBHX0yaCwRp3tE4_DP9IPb2W_oK6ZgcHSbl0R1wd0aJbE8j_hm8qoH0Fx2AYQveooUc9TbEa701LPrBCuQ5qqQNyhi1DZHI923jnvmmDxUD2g0ADooAiIvPznSM9GROmudnBSrDgW-ii99PakHJg5JpjEOALzMeAPguE6sspAjpHrql4hDqgYOmOjwKKSCFo8KX8vxWyez08b06g7ynSOYgrSqdBUcPwO-R',
          members: [
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCJzQN-ijg6CcrXmdEX5A-ucfZMk1-GBtw4_dTfuX0x6eGNa4xDguUD76BW02whX4gj16Z7VyVENuhR7mhZWQHP4bh7Mfl8HOva9SZcqnxfrEGyS9-3x9USIw9Rv2Ibfx5DNcEfEAWH8p3gOiChI4bcGnNilr78nVQs3zRxzukKK_vzM356IWyII43Iwpupg8yDo0KQBCYO7-rKmt-7SaW4w_tyqCQ1qo4FRRjMPO0henkhUv6m6vEr_e1hVkE4h9qxXHBQI7eDvZTp',
            'https://lh3.googleusercontent.com/aida-public/AB6AXuCjE5k2jCN1ea__j5-v4Y2PcZ_tOyPRWK2hm-6CjzcCjCQg5sBFOkjDpYcc9QIekJxUWxTvza-XTOc4xauNK7DViDG7t7lA5GHELt-ckmCcU1_8YmLL0oVMSyB7ilLFhLRQE5ObZ2oJGSRksuUrVOZzTS7At2JEgEegHmbqyAFeUSIXV1iR-15ltQsspdIJpg-Y8rfRNsbzi3u_zn38CyXxW8eTcCayMpbvf8QENF2cYkoYpLxtfh9IUoL7v15SYbSLxwfYHkxO9-lS'
          ],
          extraMembersCount: 2,
          isDark: isDark
        ),
        const SizedBox(height: 12),
        _buildGroupItem(
          context, 
          name: 'Weekend Strikers', 
          details: '다음 모임: 토요일 오후 7시',
          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDsCghl4u7dPssTmLKbfUth311IgNu-qPmzgLaSG3hi9OlFn76_cEWRqKcUm5LKIGcMDO5qQ7HLOl5_-FLuRX8QFJU-vzxtRvHySdNpcbxlx-gO1zoL8gp1Dutt8zdsXMGhkio6dDwpsfzIKKDiOG-tXWzhKAQVu4IU7CeEoNFe7pG7Veq2UnK2jdRcwgt65ekovkZmAS73BIKtZACgHw7MmXkQQp4yPFbp7rNKs9w0BzrsBDXFTjZXrnBld20gaAWETPHeIeAq3x4j',
          members: [
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDW1j_rG5mfCq8Gzi81_wZXuGl9Xr4BAIId8RQjq7Ruer92X9huG7bI0vTNf7sUXQA9N7cz-kn0m8ajvqxXtqwrbFyyNF7zpphpb4hHvLRxdYuFyPu71yaiAd5gZzPt6CbjZkKKR6azrR6OI9kAm0iuCK8cSCaiaSrx8qtSG1VHtdgerQIh6LTncSWKM6kBo3hk8REnBcz06cBh2t3Eg06FWwAHR2QFZUo0myVk3RXBTEf2-OjA4b0NDeuCq9mOCEi0vqzXHMv7pW7y',
            'https://lh3.googleusercontent.com/aida-public/AB6AXuB3Mmk9p2TtFlCxhCbIY3hPG1A3GNn-JkoHZ2b-4xryQB7M_W3H_HNV9pxwi364V7Ijc473PY9gymMhG-6EskNSoryiZRA8UJg8uNZkdpJYOexotjOU5GscfYBwIOzJ68FiS16GVGJuJzjBAwCWnFE0MmV5qI7p7dQMe3IUIiir2a4SVzrYGjl1apwYPhRFZ7gv6N9Y-UxQHsKIW35D-wS_gusTA9svcRfswMIdfkcspV43mTJbYvbzF9LvZ16SupQhG8cvclSg1r4L'
          ],
          extraMembersCount: 5,
          isDark: isDark
        ),
      ],
    );
  }

  /// 개별 그룹 아이템을 생성하는 위젯입니다.
  ///
  /// 클릭 시 [GroupDetailPage]로 이동합니다.
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
            // 그룹 이미지
            Stack(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? AppColors.surfaceDark : Colors.white, width: 2),
                        ),
                      ),
                    ),
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
                  // 멤버 아바타 및 상세 정보
                  Row(
                    children: [
                      SizedBox(
                        width: 60, // 24 * 2 + overlap
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
