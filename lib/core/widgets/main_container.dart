import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/presentation/pages/home_dashboard_page.dart';
import '../../features/group/presentation/pages/my_groups_page.dart';
import '../../features/game/presentation/pages/game_mode_page.dart';
import '../../features/game/presentation/pages/frame_entry_page.dart';
import '../../features/game/presentation/pages/game_history_page.dart';
import '../../features/game/presentation/widgets/location_input_dialog.dart';
import '../../features/game/data/services/game_draft_repository.dart';
import '../../features/game/data/services/game_save_service.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../main.dart' show appRouteObserver;
import '../constants/app_colors.dart';
import '../services/api_client.dart';

/// 앱의 주요 내비게이션 구조를 담당하는 위젯입니다.
///
/// [BottomAppBar]를 사용하여 하단 탭 내비게이션을 제공하며,
/// 중앙의 [FloatingActionButton]을 통해 게임 점수 입력 화면으로 이동할 수 있습니다.
class MainContainer extends StatefulWidget {
  final int initialTabIndex;
  const MainContainer({super.key, this.initialTabIndex = 0});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> with RouteAware {
  /// 현재 선택된 탭의 인덱스입니다.
  late int _selectedIndex = widget.initialTabIndex;
  bool _isCheckingClub = false;

  /// 페이지 갱신을 위한 키 (값이 바뀌면 페이지가 재생성됨)
  Key _refreshKey = UniqueKey();

  final GameDraftRepository _draftRepo = GameDraftRepository();
  final GameSaveService _saveService = GameSaveService();

  @override
  void initState() {
    super.initState();
    // 앱 진입 시 미저장 경기 드래프트 자동 재시도.
    // UI 완전 렌더 이후 실행해 ScaffoldMessenger에 접근 가능하도록 addPostFrameCallback 사용.
    WidgetsBinding.instance.addPostFrameCallback((_) => _retryPendingDrafts());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 전역 RouteObserver 구독. ModalRoute가 반드시 존재하는 시점이라 null 아님.
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// 위쪽 라우트가 pop되어 MainContainer가 다시 topmost가 되었을 때 호출.
  ///
  /// 클럽/개인 게임 저장 후 popUntil로 돌아오는 경우가 대표적.
  /// (pushReplacement 체인 때문에 _onAddButtonPressed의 await는 게임 시작 시점에 이미 resolve되어
  ///  그 쪽의 setState 경로로는 최신화 트리거가 안 걸림.)
  @override
  void didPopNext() {
    super.didPopNext();
    if (!mounted) return;
    HomeDashboardPage.invalidateCache();
    setState(() {
      _refreshKey = UniqueKey();
    });
    // 경기 저장 직후 네트워크 일시 단절로 드래프트가 쌓였을 수도 있으므로 재시도.
    _retryPendingDrafts();
  }

  /// 저장 실패로 로컬에 보관된 드래프트들을 순차 재시도.
  /// 성공한 건은 저장소에서 제거하고, 결과를 MaterialBanner로 안내.
  Future<void> _retryPendingDrafts() async {
    final drafts = await _draftRepo.getAllDrafts();
    if (drafts.isEmpty || !mounted) return;

    int successCount = 0;
    for (final draft in drafts) {
      final result = await _saveService.saveGame(payload: draft.payload);
      if (result.success) {
        await _draftRepo.removeDraft(draft.id);
        successCount++;
      }
      if (!mounted) return;
    }

    if (!mounted) return;

    if (successCount > 0) {
      HomeDashboardPage.invalidateCache();
      setState(() {
        _refreshKey = UniqueKey();
      });
    }

    final failCount = drafts.length - successCount;
    _showDraftResultBanner(
      totalCount: drafts.length,
      successCount: successCount,
      failCount: failCount,
    );
  }

  /// 드래프트 재시도 결과를 화면 상단 MaterialBanner로 표시.
  /// - 전부 성공: 초록 체크 + "닫기"
  /// - 부분 성공: 주황 경고 + "다시 시도" + "닫기"
  /// - 전부 실패: 빨강 경고 + "다시 시도" + "닫기"
  void _showDraftResultBanner({
    required int totalCount,
    required int successCount,
    required int failCount,
  }) {
    if (totalCount == 0 || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String message;
    final Color accentColor;
    final IconData icon;
    final bool showRetry;

    if (failCount == 0) {
      message = '미저장 경기 $successCount개를 자동 저장했습니다.';
      accentColor = const Color(0xFF4CAF50);
      icon = Symbols.check_circle;
      showRetry = false;
    } else if (successCount > 0) {
      message = '미저장 경기 중 $successCount개 저장 완료, $failCount개 실패';
      accentColor = Colors.orange;
      icon = Symbols.warning;
      showRetry = true;
    } else {
      message = '미저장 경기 $totalCount개 저장에 실패했습니다.';
      accentColor = Colors.red;
      icon = Symbols.cloud_off;
      showRetry = true;
    }

    messenger.showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 2,
        leading: Icon(icon, color: accentColor, size: 24),
        content: Text(
          message,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          if (showRetry)
            TextButton(
              onPressed: () {
                messenger.clearMaterialBanners();
                _retryPendingDrafts();
              },
              child: const Text(
                '다시 시도',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          TextButton(
            onPressed: () => messenger.clearMaterialBanners(),
            child: Text(
              '닫기',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      // 게임 종료 후 대시보드 갱신은 RouteAware.didPopNext가 처리
      // (pushReplacement 체인 환경에서는 await가 너무 이르게 resolve되므로
      //  여기서 refresh 콜백을 걸면 실제 저장 전에 stale 데이터로 리프레시됨)
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FrameEntryPage(isClubGame: false, location: location),
        ),
      );
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

      final response = await ApiClient().dio.get('/groups/me');
      final groups = response.data;

      if (mounted) {
        setState(() { _isCheckingClub = false; });
        if (groups is List && groups.isNotEmpty) {
          // 클럽(그룹)이 있는 경우 게임 모드 선택 페이지로 이동
          // (저장 후 대시보드 갱신은 RouteAware.didPopNext가 담당)
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GameModePage()),
          );
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
