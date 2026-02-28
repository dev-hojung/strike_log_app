import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';

/// 볼링 클럽(그룹)의 상세 정보를 보여주는 페이지입니다.
///
/// 주요 기능:
/// - 클럽 정보 및 통계 표시 (멤버 수, 평균 점수, 최고 점수 등)
/// - 그룹 매치 기록 버튼 제공
/// - 클럽 내 리더보드 (순위표) 표시
class GroupDetailPage extends StatelessWidget {
  const GroupDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Symbols.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text('스트라이크 포스 클럽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Symbols.more_vert), onPressed: () {})],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 클럽 헤더 정보 (아이콘, 이름, 설명)
            _buildHeader(isDark),
            const SizedBox(height: 32),
            // 클럽 통계 요약 (평균, 최고 기록, 게임 수)
            _buildStatsRow(isDark),
            const SizedBox(height: 24),
            // 매치 기록 액션 버튼
            _buildActionButton(),
            const SizedBox(height: 32),
            // 리더보드 헤더
            _buildLeaderboardHeader(isDark),
            const SizedBox(height: 16),
            // 리더보드 리스트
            _buildLeaderboardList(isDark),
          ],
        ),
      ),
    );
  }

  /// 클럽의 기본 정보(아이콘, 이름, 멤버 수 등)를 표시하는 헤더 위젯입니다.
  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 4),
                color: Colors.grey.withOpacity(0.2),
              ),
              child: const Icon(Symbols.groups, size: 60, color: Colors.grey),
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Symbols.verified, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('스트라이크 포스 클럽', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('멤버 24명 • 매주 모임 • 2021년 창단', style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14)),
      ],
    );
  }

  /// 클럽의 주요 통계(평균, 최고 점수, 총 게임 수)를 가로로 나열하는 위젯입니다.
  Widget _buildStatsRow(bool isDark) {
    return Row(
      children: [
        _buildStatItem('평균', '185', Symbols.equalizer, AppColors.primary, isDark),
        const SizedBox(width: 12),
        _buildStatItem('최고', '279', Symbols.emoji_events, Colors.green, isDark),
        const SizedBox(width: 12),
        _buildStatItem('게임', '42', Symbols.history, Colors.orange, isDark),
      ],
    );
  }

  /// 개별 통계 아이템을 생성하는 위젯입니다.
  Widget _buildStatItem(String label, String value, IconData icon, Color iconColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 4),
                Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// 'Record Group Match' 버튼을 생성하는 위젯입니다.
  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Symbols.add_circle, color: Colors.white),
        label: const Text('그룹 매치 기록하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  /// 리더보드 섹션의 헤더(제목 및 필터)를 생성하는 위젯입니다.
  Widget _buildLeaderboardHeader(bool isDark) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('순위표', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          children: [
            Text('필터', style: TextStyle(color: Colors.grey, fontSize: 14)),
            SizedBox(width: 4),
            Icon(Symbols.filter_list, color: Colors.grey, size: 18),
          ],
        ),
      ],
    );
  }

  /// 리더보드 목록을 생성하는 위젯입니다.
  Widget _buildLeaderboardList(bool isDark) {
    return Column(
      children: [
        _buildRankItem('1위', 'Sarah Jenkins', '최고 점수: 265', '215', true, isDark),
        const SizedBox(height: 12),
        _buildRankItem('2위', 'Michael Ross', '최고 점수: 244', '208', false, isDark),
        const SizedBox(height: 12),
        _buildRankItem('3위', 'Jessica Pearson', '최고 점수: 230', '195', false, isDark),
      ],
    );
  }

  /// 리더보드의 개별 순위 아이템을 생성하는 위젯입니다.
  ///
  /// [isFirst]가 true일 경우 금색 테두리와 왕관 아이콘으로 1등을 강조합니다.
  Widget _buildRankItem(String rank, String name, String sub, String avg, bool isFirst, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isFirst ? Colors.amber.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (isFirst) const Icon(Symbols.military_tech, color: Colors.amber, size: 20),
                Text(rank, style: TextStyle(color: isFirst ? Colors.amber : Colors.grey, fontWeight: FontWeight.bold, fontSize: isFirst ? 10 : 14)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(radius: 20, child: Icon(Symbols.person)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(avg, style: const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
              const Text('평균', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
