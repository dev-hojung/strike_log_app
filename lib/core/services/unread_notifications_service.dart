import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/data/services/notifications_api_service.dart';
import 'app_logger.dart';

/// 미읽음 알림 수를 앱 전역에서 공유하는 싱글톤.
///
/// - `unreadCount`는 ValueNotifier이므로 `ValueListenableBuilder`로 구독 가능.
/// - 서버와 주기적으로 동기화(`refresh`)하고, FCM 포그라운드 수신 시 `increment()`로 낙관적 갱신.
class UnreadNotificationsService {
  UnreadNotificationsService._();
  static final UnreadNotificationsService instance =
      UnreadNotificationsService._();

  final NotificationsApiService _api = NotificationsApiService();
  final ValueNotifier<int> _count = ValueNotifier<int>(0);

  ValueListenable<int> get unreadCount => _count;
  int get value => _count.value;

  /// 서버에서 최신 카운트 가져와 반영. 로그인 상태가 아니면 0으로 초기화.
  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        _count.value = 0;
        return;
      }
      final count = await _api.fetchUnreadCount(userId);
      _count.value = count;
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'unreadNotifications.refresh');
    }
  }

  /// 포그라운드 FCM 수신 등 새 알림 도착 시 낙관적 +1.
  void increment() {
    _count.value = _count.value + 1;
  }

  /// 단건 읽음 처리 후 -1 (최소 0).
  void decrement() {
    if (_count.value > 0) _count.value = _count.value - 1;
  }

  /// 전체 읽음 처리 후 0.
  void reset() {
    _count.value = 0;
  }
}
