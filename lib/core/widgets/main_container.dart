import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../features/home/presentation/pages/home_dashboard_page.dart';
import '../../features/group/presentation/pages/club_members_page.dart';
import '../../features/game/presentation/pages/frame_entry_page.dart';
import '../constants/app_colors.dart';

/// 앱의 주요 내비게이션 구조를 담당하는 위젯입니다.
///
/// [BottomAppBar]를 사용하여 하단 탭 내비게이션을 제공하며,
/// 중앙의 [FloatingActionButton]을 통해 게임 점수 입력 화면으로 이동할 수 있습니다.
class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  /// 현재 선택된 탭의 인덱스입니다.
  int _selectedIndex = 0;

  /// 각 탭에 해당하는 페이지 위젯 리스트입니다.
  final List<Widget> _pages = [
    const HomeDashboardPage(),
    const Center(child: Text('기록')), // History placeholder
    const ClubMembersPage(),
    const Center(child: Text('프로필')), // Profile placeholder
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      // 중앙 플로팅 액션 버튼: 게임 점수 입력 화면으로 이동
      floatingActionButton: Container(
        height: 64, // Slightly larger touch area/visual
        width: 64,
        margin: const EdgeInsets.only(top: 10), // Adjust positioning if needed
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FrameEntryPage()),
            );
          },
          backgroundColor: AppColors.primary,
          elevation: 4,
          focusElevation: 4,
          hoverElevation: 4,
          highlightElevation: 4,
          shape: const CircleBorder(),
          // Add colored shadow
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Symbols.add, color: Colors.white, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // 하단 내비게이션 바
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 64, // Matches Tailwind h-16
        color: isDark ? AppColors.surfaceDark : Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 0, // Flat look as per HTML border-t
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildNavItem(0, Symbols.dashboard, '홈'),
            _buildNavItem(1, Symbols.history, '기록'),
            const SizedBox(width: 48), // FAB 공간 확보
            _buildNavItem(2, Symbols.groups, '클럽'),
            _buildNavItem(3, Symbols.person, '프로필'),
          ],
        ),
      ),
    );
  }

  /// 하단 내비게이션 바의 개별 아이템을 생성하는 위젯입니다.
  ///
  /// [index]는 탭의 인덱스, [icon]은 아이콘 데이터, [label]은 텍스트 라벨입니다.
  /// 선택된 상태에 따라 색상이 변경됩니다.
  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected
        ? AppColors.primary
        : (Theme.of(context).brightness == Brightness.dark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24, weight: isSelected ? 600 : 400),
            const SizedBox(height: 2), // gap-1 equivalent
            Text(
              label,
              style: TextStyle(
                color: color, 
                fontSize: 10, 
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500
              ),
            ),
          ],
        ),
      ),
    );
  }
}
