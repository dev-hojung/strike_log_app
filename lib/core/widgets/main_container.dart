import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/presentation/pages/home_dashboard_page.dart';
import '../../features/group/presentation/pages/my_groups_page.dart';
import '../../features/game/presentation/pages/game_mode_page.dart';
import '../../features/game/presentation/pages/frame_entry_page.dart';
import '../../features/game/presentation/pages/game_history_page.dart';
import '../../features/game/presentation/widgets/location_input_dialog.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../constants/app_colors.dart';
import '../services/api_client.dart';

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
  bool _isCheckingClub = false;

  /// 페이지 갱신을 위한 키 (값이 바뀌면 페이지가 재생성됨)
  Key _refreshKey = UniqueKey();

  /// 각 탭에 해당하는 페이지 위젯 리스트입니다.
  List<Widget> get _pages => [
    HomeDashboardPage(key: _refreshKey),
    GameHistoryPage(key: _refreshKey),
    MyGroupsPage(key: _refreshKey),
    ProfilePage(key: _refreshKey),
  ];

  Future<void> _startIndividualGame() async {
    final location = await showLocationInputDialog(context);
    if (location != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FrameEntryPage(isClubGame: false, location: location)),
      );
      // 게임 화면에서 돌아오면 캐시 무효화 후 대시보드 및 기록 갱신
      if (mounted) {
        HomeDashboardPage.invalidateCache();
        setState(() {
          _refreshKey = UniqueKey();
        });
      }
    }
  }

  Future<void> _onAddButtonPressed() async {
    if (_isCheckingClub) return;
    setState(() {
      _isCheckingClub = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        setState(() { _isCheckingClub = false; });
        await _startIndividualGame();
        return;
      }

      final response = await ApiClient().dio.get('/groups/me/$userId');
      final groups = response.data;

      if (mounted) {
        setState(() { _isCheckingClub = false; });
        if (groups is List && groups.isNotEmpty) {
          // 클럽(그룹)이 있는 경우 게임 모드 선택 페이지로 이동
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GameModePage()),
          );
          if (mounted) {
            HomeDashboardPage.invalidateCache();
            setState(() {
              _refreshKey = UniqueKey();
            });
          }
        } else {
          // 클럽이 없는 경우 개인 게임 바로 시작
          await _startIndividualGame();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isCheckingClub = false; });
        // 오류 발생 시 기본적으로 개인 게임 시작
        await _startIndividualGame();
      }
    }
  }

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
          onPressed: _onAddButtonPressed,
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
                  color: AppColors.primary.withValues(alpha:0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isCheckingClub 
                ? const SizedBox(
                    width: 24, 
                    height: 24, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Icon(Symbols.add, color: Colors.white, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // 하단 내비게이션 바
      extendBody: true,
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        height: 64,
        color: isDark ? AppColors.surfaceDark : Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildNavItem(0, Symbols.home, '홈'),
            _buildNavItem(1, Symbols.bar_chart, '기록'),
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
        onTap: () => setState(() {
          if (index != _selectedIndex) {
            _refreshKey = UniqueKey();
          }
          _selectedIndex = index;
        }),
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
