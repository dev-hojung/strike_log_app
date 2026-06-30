import 'package:dio/dio.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/app_logger.dart';

/// 클럽 멤버 역할 상수.
///
/// 백엔드 `GroupRole` enum 값과 1:1 대응.
/// 역할 위계: OWNER(클럽장) > STAFF(운영진) > MEMBER(일반멤버)
abstract class GroupRole {
  static const String owner = 'OWNER';
  static const String staff = 'STAFF';
  static const String member = 'MEMBER';

  /// 해당 역할이 클럽 운영 권한(OWNER 또는 STAFF)을 갖는지 반환.
  static bool canManage(String? role) =>
      role == owner || role == staff;

  /// 역할 위계 숫자 (클수록 높음). 비교용.
  static int rank(String? role) {
    switch (role) {
      case owner:
        return 3;
      case staff:
        return 2;
      case member:
        return 1;
      default:
        return 0;
    }
  }
}

/// 클럽(그룹) 관련 핵심 API 래퍼.
///
/// 멤버 조회·운영진 임명·운영진 해제·클럽장 이양·추방·탈퇴.
///
/// 백엔드 라우트:
/// - `GET    /groups/:id/members-with-stats`           → 멤버 + 평균 점수 리스트
/// - `POST   /groups/:id/members/:userId/promote`      → 운영진 임명 (OWNER→STAFF)
/// - `DELETE /groups/:id/members/:userId/staff`        → 운영진 해제 (STAFF→MEMBER)
/// - `POST   /groups/:id/transfer-ownership`           → 클럽장 이양
/// - `DELETE /groups/:id/members/:userId`              → 회원 추방
/// - `DELETE /groups/:id/leave`                        → 본인 탈퇴
class GroupsApiService {
  GroupsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// 내가 운영자인 클럽들의 pending 가입 신청 합계.
  ///
  /// 하단 네비/헤더 뱃지 표시용. 일반 멤버는 항상 0.
  /// 응답 예: `{ count: 3 }`
  Future<int> fetchPendingJoinRequestsCount() async {
    try {
      final res = await _apiClient.dio.get('/groups/me/pending-join-requests-count');
      final data = res.data;
      if (data is Map && data['count'] is num) {
        return (data['count'] as num).toInt();
      }
      return 0;
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'groups.fetchPendingJoinRequestsCount');
      return 0;
    }
  }

  /// 클럽 멤버 목록(역할 포함) 조회.
  ///
  /// 응답 예: `[{ user: {id, nickname, profile_image_url}, role, avg_score }, ...]`
  Future<List<Map<String, dynamic>>> getMembers(int groupId) async {
    try {
      final res = await _apiClient.dio.get('/groups/$groupId/members-with-stats');
      final data = res.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return const [];
    } on DioException catch (e, st) {
      await AppLogger.captureError(e, stackTrace: st, context: 'groups.getMembers');
      rethrow;
    }
  }

  /// 운영진 임명 (MEMBER → STAFF). 클럽장(OWNER)만 호출 가능.
  ///
  /// 본인이거나 이미 STAFF/OWNER인 경우 백엔드가 409 반환.
  Future<void> promoteMember({
    required int groupId,
    required String targetUserId,
  }) async {
    try {
      await _apiClient.dio
          .post('/groups/$groupId/members/$targetUserId/promote');
    } on DioException catch (e, st) {
      await AppLogger.captureError(e, stackTrace: st, context: 'groups.promoteMember');
      rethrow;
    }
  }

  /// 운영진 해제 (STAFF → MEMBER). 클럽장(OWNER)만 호출 가능.
  ///
  /// 대상이 STAFF가 아니거나 본인인 경우 백엔드가 409 반환.
  Future<void> revokeStaff({
    required int groupId,
    required String targetUserId,
  }) async {
    try {
      await _apiClient.dio
          .delete('/groups/$groupId/members/$targetUserId/staff');
    } on DioException catch (e, st) {
      await AppLogger.captureError(e, stackTrace: st, context: 'groups.revokeStaff');
      rethrow;
    }
  }

  /// 클럽장 이양 (OWNER → 대상, 본인 → STAFF). OWNER만 호출 가능.
  ///
  /// 대상이 동일 클럽 멤버가 아닌 경우 백엔드가 404/409 반환.
  Future<void> transferOwnership({
    required int groupId,
    required String targetUserId,
  }) async {
    try {
      await _apiClient.dio.post(
        '/groups/$groupId/transfer-ownership',
        data: {'targetUserId': targetUserId},
      );
    } on DioException catch (e, st) {
      await AppLogger.captureError(e, stackTrace: st, context: 'groups.transferOwnership');
      rethrow;
    }
  }

  /// 회원 추방. STAFF 이상이 하위 역할 멤버를 클럽에서 제거.
  /// 동급/상위 대상 추방은 백엔드에서 차단된다 (403).
  Future<void> kickMember({
    required int groupId,
    required String targetUserId,
  }) async {
    try {
      await _apiClient.dio.delete('/groups/$groupId/members/$targetUserId');
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'groups.kickMember');
      rethrow;
    }
  }

  /// 클럽 탈퇴.
  ///
  /// 응답: `{ ok: true, group_deleted: bool }`
  /// - `group_deleted=true`면 본인이 마지막 멤버라 클럽 자체도 삭제됨
  /// - OWNER + 다른 멤버 존재 시 409 (`message: '클럽장입니다. ...'`) → 클럽장 이양 후 탈퇴 안내
  Future<Map<String, dynamic>> leaveGroup(int groupId) async {
    try {
      final res = await _apiClient.dio.delete('/groups/$groupId/leave');
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on DioException catch (e, st) {
      await AppLogger.captureError(e, stackTrace: st, context: 'groups.leaveGroup');
      rethrow;
    }
  }
}
