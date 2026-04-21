import 'package:shared_preferences/shared_preferences.dart';

import '../../features/game/data/services/game_draft_repository.dart';
import '../../features/home/presentation/pages/home_dashboard_page.dart';
import 'auth_token_storage.dart';
import 'unread_notifications_service.dart';
import 'user_profile_cache.dart';

/// 로그인/로그아웃 시점에 유저 의존 상태를 일괄 정리하는 중앙 매니저.
///
/// 정적 캐시가 여러 곳에 흩어져 있어 각각 정리 누락이 발생하기 쉬워서
/// 한 함수로 모아 호출하도록 강제한다.
class SessionManager {
  SessionManager._();

  /// 세션 관련 모든 로컬 상태를 비운다. 로그아웃 / 401 / 재로그인 직전에 호출.
  static Future<void> clearAll() async {
    // 토큰 / 프로필 캐시
    await AuthTokenStorage.clear();
    await UserProfileCache.clear();

    // 전역 ValueNotifier 리셋
    UnreadNotificationsService.instance.reset();

    // 페이지 정적 캐시
    HomeDashboardPage.invalidateCache();

    // 유저-specific SharedPreferences 키
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('nickname');

    // 저장 실패한 게임 드래프트 — 기기가 유저 간 공유될 수 있으므로
    // 타 유저의 미저장 게임이 새 계정으로 업로드되는 사고 방지.
    await GameDraftRepository().clearAll();
  }
}
