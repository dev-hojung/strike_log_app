import '../../../../core/services/api_client.dart';

/// 클럽 생성 신청 REST 래퍼.
///
/// 백엔드 엔드포인트 (JWT 인증 기준 — 서버가 토큰의 user.id로 식별):
/// - POST   /groups/creation-requests              신청 생성
/// - GET    /groups/creation-requests/me           내 신청 목록
/// - GET    /groups/creation-requests?status=...   [ADMIN] 전체 신청
/// - POST   /groups/creation-requests/:id/approve  [ADMIN]
/// - POST   /groups/creation-requests/:id/reject   [ADMIN]
/// - POST   /groups/creation-requests/:id/cancel   본인 취소
class GroupCreationRequestsService {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>?> createRequest({
    required String name,
    String? description,
    String? coverImageUrl,
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/groups/creation-requests',
        data: {
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

  Future<List<Map<String, dynamic>>> listMyRequests() async {
    try {
      final res = await _apiClient.dio.get('/groups/creation-requests/me');
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

  Future<List<Map<String, dynamic>>> listForAdmin({String? status}) async {
    try {
      final res = await _apiClient.dio.get(
        '/groups/creation-requests',
        queryParameters: {
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

  Future<bool> approve({required int requestId}) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/approve',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reject({
    required int requestId,
    required String reason,
  }) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/reject',
        data: {'reason': reason},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancel({required int requestId}) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/cancel',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
