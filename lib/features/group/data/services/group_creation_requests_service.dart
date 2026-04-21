import '../../../../core/services/api_client.dart';

/// 클럽 생성 신청 REST 래퍼.
///
/// 백엔드 엔드포인트 (NestJS):
/// - POST   /groups/creation-requests                 신청 생성
/// - GET    /groups/creation-requests/me/:user_id     내 신청 목록
/// - GET    /groups/creation-requests?admin_user_id&status  [ADMIN]
/// - POST   /groups/creation-requests/:id/approve     [ADMIN]
/// - POST   /groups/creation-requests/:id/reject      [ADMIN]
/// - POST   /groups/creation-requests/:id/cancel      본인 취소
class GroupCreationRequestsService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>?> createRequest({
    required String userId,
    required String name,
    String? description,
    String? coverImageUrl,
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/groups/creation-requests',
        data: {
          'user_id': userId,
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            'cover_image_url': coverImageUrl,
        },
      );
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> listMyRequests(String userId) async {
    try {
      final res = await _apiClient.dio.get('/groups/creation-requests/me/$userId');
      if (res.data is List) {
        return (res.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> listForAdmin({
    required String adminUserId,
    String? status,
  }) async {
    try {
      final res = await _apiClient.dio.get(
        '/groups/creation-requests',
        queryParameters: {
          'admin_user_id': adminUserId,
          if (status != null) 'status': status,
        },
      );
      if (res.data is List) {
        return (res.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> approve({required int requestId, required String adminUserId}) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/approve',
        data: {'admin_user_id': adminUserId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reject({
    required int requestId,
    required String adminUserId,
    required String reason,
  }) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/reject',
        data: {'admin_user_id': adminUserId, 'reason': reason},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancel({required int requestId, required String userId}) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/cancel',
        data: {'user_id': userId},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
