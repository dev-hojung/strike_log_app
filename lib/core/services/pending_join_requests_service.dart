import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/group/data/services/groups_api_service.dart';
import 'app_logger.dart';

/// 내가 운영자인 클럽들의 pending 가입 신청 합계를 앱 전역에서 공유하는 싱글톤.
///
/// 사용처:
/// - 하단 네비게이션의 그룹 탭에 "신청 들어왔음" 빨간 점 표시 (값 > 0이면 표시)
/// - my_groups_page 헤더의 가입 신청 관리 아이콘에 숫자 뱃지
///
/// 갱신 시점:
/// - 앱 시작 시(main에서)
/// - my_groups_page 진입/새로고침 시
/// - FCM으로 새 가입 신청 알림 도착 시 (낙관적 [increment])
/// - 신청 승인/반려 후 (낙관적 [decrement])
class PendingJoinRequestsService {
  PendingJoinRequestsService._();
  static final PendingJoinRequestsService instance =
      PendingJoinRequestsService._();

  final GroupsApiService _api = GroupsApiService();
  final ValueNotifier<int> _count = ValueNotifier<int>(0);

  ValueListenable<int> get pendingCount => _count;
  int get value => _count.value;

  /// 서버에서 최신 카운트 가져와 반영. 로그인 상태가 아니면 0.
  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        _count.value = 0;
        return;
      }
      _count.value = await _api.fetchPendingJoinRequestsCount();
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'pendingJoinRequests.refresh');
    }
  }

  /// FCM 포그라운드 수신 등 새 신청 도착 시 낙관적 +1.
  void increment() {
    _count.value = _count.value + 1;
  }

  /// 신청 단건 승인/반려 후 -1 (최소 0).
  void decrement() {
    if (_count.value > 0) _count.value = _count.value - 1;
  }

  /// 0으로 초기화.
  void reset() {
    _count.value = 0;
  }
}
