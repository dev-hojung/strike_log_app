import 'package:dio/dio.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/app_logger.dart';

/// 클럽 공지사항 CRUD API 래퍼.
///
/// 백엔드 라우트:
/// - GET    /groups/:id/announcements
/// - POST   /groups/:id/announcements
/// - PATCH  /groups/:id/announcements/:aid
/// - DELETE /groups/:id/announcements/:aid
class AnnouncementsApiService {
  AnnouncementsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// 공지 목록 조회. 응답 항목 예:
  /// `{ id, group_id, title, body, pinned, created_at, updated_at, author: {id, nickname, profile_image_url} }`
  Future<List<Map<String, dynamic>>> list(int groupId) async {
    try {
      final res = await _apiClient.dio.get('/groups/$groupId/announcements');
      final data = res.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return const [];
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'announcements.list');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> create({
    required int groupId,
    required String title,
    required String body,
    bool pinned = false,
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/groups/$groupId/announcements',
        data: {'title': title, 'body': body, 'pinned': pinned},
      );
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'announcements.create');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> update({
    required int groupId,
    required int announcementId,
    String? title,
    String? body,
    bool? pinned,
  }) async {
    try {
      final res = await _apiClient.dio.patch(
        '/groups/$groupId/announcements/$announcementId',
        data: {
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (pinned != null) 'pinned': pinned,
        },
      );
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'announcements.update');
      rethrow;
    }
  }

  Future<void> delete({
    required int groupId,
    required int announcementId,
  }) async {
    try {
      await _apiClient.dio
          .delete('/groups/$groupId/announcements/$announcementId');
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'announcements.delete');
      rethrow;
    }
  }
}
