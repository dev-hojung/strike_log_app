import '../../../../core/services/api_client.dart';

/// 클럽장이 가입 신청을 관리하기 위한 REST 래퍼.
///
/// 기대 엔드포인트:
/// - `GET    /groups/:clubId/join-requests`                  → `List<JoinRequest>`
/// - `POST   /groups/:clubId/join-requests/:requestId/approve`
/// - `POST   /groups/:clubId/join-requests/:requestId/reject`
///
/// JoinRequest 스키마 예시:
/// ```json
/// {
///   "id": "uuid",
///   "userId": "...",
///   "nickname": "...",
///   "profileImageUrl": "...",
///   "message": "...",
///   "createdAt": "ISO8601"
/// }
/// ```
class ClubJoinRequestsService {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> fetchPending(int clubId) async {
    try {
      final res = await _apiClient.dio.get('/groups/$clubId/join-requests');
      final data = res.data;
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<bool> approve(int clubId, String requestId) async {
    try {
      await _apiClient.dio
          .post('/groups/$clubId/join-requests/$requestId/approve');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reject(int clubId, String requestId) async {
    try {
      await _apiClient.dio
          .post('/groups/$clubId/join-requests/$requestId/reject');
      return true;
    } catch (_) {
      return false;
    }
  }
}
