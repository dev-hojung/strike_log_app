import 'package:dio/dio.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/app_logger.dart';

/// 클럽(그룹) 관련 핵심 API 래퍼.
///
/// 멤버 조회·운영자 위임·탈퇴 등 기존 다른 서비스(`leaderboard_api_service`,
/// `club_join_requests_service`)에 포함되지 않는 호출을 모은다.
///
/// 백엔드 라우트:
/// - `GET    /groups/:id/members-with-stats`           → 멤버 + 평균 점수 리스트
/// - `POST   /groups/:id/members/:userId/promote`      → 멤버를 ADMIN으로 승격
/// - `DELETE /groups/:id/leave`                        → 본인 탈퇴
class GroupsApiService {
  GroupsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

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

  /// 멤버를 운영자(ADMIN)로 승격.
  ///
  /// 호출자는 해당 클럽 ADMIN이어야 한다. 본인이거나 이미 ADMIN인 경우 409.
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

  /// 클럽 탈퇴.
  ///
  /// 응답: `{ ok: true, group_deleted: bool }`
  /// - `group_deleted=true`면 본인이 마지막 멤버라 클럽 자체도 삭제됨
  /// - 유일 ADMIN + 다른 멤버 존재 시 409 (`message: '마지막 운영자입니다. ...'`)
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
