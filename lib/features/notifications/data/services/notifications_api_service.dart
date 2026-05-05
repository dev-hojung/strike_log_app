import '../../../../core/services/api_client.dart';
import '../models/notification_item.dart';

/// 알림 REST 래퍼.
///
/// 백엔드 엔드포인트 (JWT 인증 기준 — 서버가 토큰의 user.id로 식별):
/// - `GET    /notifications/me`                 → `List<NotificationItem JSON>`
/// - `GET    /notifications/me/unread-count`    → `{ count }`
/// - `POST   /notifications/:id/read`           → `{ ok }`
/// - `POST   /notifications/me/read-all`        → `{ ok }`
/// - `POST   /notifications/me/fcm-token`       → `{ ok }`
/// - `DELETE /notifications/me/fcm-token`       → `{ ok }`
class NotificationsApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<NotificationItem>> fetchList() async {
    try {
      final res = await _apiClient.dio.get('/notifications/me');
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

  Future<int> fetchUnreadCount() async {
    try {
      final res = await _apiClient.dio.get('/notifications/me/unread-count');
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

  Future<bool> markAllAsRead() async {
    try {
      await _apiClient.dio.post('/notifications/me/read-all');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// FCM 디바이스 토큰 등록. JWT의 user로 인식되므로 user_id 불필요.
  Future<bool> registerFcmToken({
    required String token,
    required String platform,
  }) async {
    try {
      await _apiClient.dio.post(
        '/notifications/me/fcm-token',
        data: {'token': token, 'platform': platform},
      );
      return true;
    } catch (e) {
      // 진단 가능하도록 실패 사유를 그대로 노출. (LogInterceptor가 4xx/5xx 응답 본문도 출력)
      // ignore: avoid_print
      print('[FCM][registerFcmToken] failed: $e');
      return false;
    }
  }

  Future<bool> deleteFcmToken({required String token}) async {
    try {
      await _apiClient.dio.delete(
        '/notifications/me/fcm-token',
        data: {'token': token},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
