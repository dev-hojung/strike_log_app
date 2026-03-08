import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';
import 'create_club_page.dart';

/// 사용자가 소속된 클럽(그룹) 목록을 보여주는 페이지입니다.
///
/// 주요 기능:
/// - 가입된 그룹 리스트 표시 (그룹명, 멤버 수, 내 평균 점수)
/// - 새 그룹 생성 버튼 제공
class MyGroupsPage extends StatelessWidget {
  const MyGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('내 클럽', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 그룹 목록 리스트뷰
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGroupListItem(context, '스트라이크 포스', '8명', '185', isDark),
              const SizedBox(height: 12),
              _buildGroupListItem(context, '거터 갱', '12명', '142', isDark),
              const SizedBox(height: 12),
              _buildGroupListItem(context, '먼데이 나이트 리그', '24명', '198', isDark),
              const SizedBox(height: 12),
              _buildGroupListItem(context, '스페어 미', '4명', '165', isDark),
              const SizedBox(height: 100), // 하단 버튼 공간 확보
            ],
          ),
          // 새 그룹 생성 플로팅 버튼 (하단 고정)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateClubPage()),
                );
              },
              icon: const Icon(Symbols.add_circle, color: Colors.white),
              label: const Text('새 클럽 생성', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 그룹 목록의 개별 아이템을 생성하는 위젯입니다.
  ///
  /// [name]은 그룹 이름, [members]는 멤버 수, [avg]는 내 평균 점수를 나타냅니다.
  Widget _buildGroupListItem(BuildContext context, String name, String members, String avg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          // 그룹 아이콘 (임시)
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.groups, color: Colors.grey, size: 32),
          ),
          const SizedBox(width: 16),
          // 그룹 정보 텍스트
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(12)),
                  child: Text(members, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                    children: [
                      const TextSpan(text: '내 평균: '),
                      TextSpan(text: avg, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Symbols.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
