import '../../../../core/services/api_client.dart';
import '../models/notification_item.dart';

/// 알림 REST API 래퍼.
///
/// 기대하는 백엔드 엔드포인트:
/// - `GET  /notifications/:userId`            → `List<NotificationItem JSON>`
/// - `GET  /notifications/:userId/unread-count` → `{ "count": int }`
/// - `POST /notifications/:id/read`            → `{ "ok": true }`
/// - `POST /notifications/:userId/read-all`    → `{ "ok": true }`
///
/// 백엔드가 아직 없는 동안에는 네트워크/404 에러를 조용히 삼켜 빈 결과를 반환합니다.
class NotificationsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<NotificationItem>> fetchList(String userId) async {
    try {
      final res = await _apiClient.dio.get('/notifications/$userId');
      final data = res.data;
      if (data is List) {
        return data
            .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<int> fetchUnreadCount(String userId) async {
    try {
      final res = await _apiClient.dio.get('/notifications/$userId/unread-count');
      final count = res.data is Map ? res.data['count'] : null;
      if (count is int) return count;
      if (count is num) return count.toInt();
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      await _apiClient.dio.post('/notifications/$notificationId/read');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllAsRead(String userId) async {
    try {
      await _apiClient.dio.post('/notifications/$userId/read-all');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// FCM 디바이스 토큰 등록.
  /// 기대 엔드포인트: `POST /notifications/:userId/fcm-token`
  /// body: `{ "token": "...", "platform": "android" | "ios" }`
  Future<bool> registerFcmToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    try {
      await _apiClient.dio.post(
        '/notifications/$userId/fcm-token',
        data: {'token': token, 'platform': platform},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteFcmToken({
    required String userId,
    required String token,
  }) async {
    try {
      await _apiClient.dio.delete(
        '/notifications/$userId/fcm-token',
        data: {'token': token},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
