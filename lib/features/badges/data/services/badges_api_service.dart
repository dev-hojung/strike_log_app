import '../../../../core/services/api_client.dart';
import '../models/badge_item.dart';

/// 배지 + 출석 streak REST 래퍼 (JWT 기준, 서버가 토큰의 user.id로 식별).
///
/// 엔드포인트:
/// - `GET /badges/me`         → `List<BadgeItem JSON>`
/// - `GET /badges/me/recent`  → 최근 획득 배지 (limit 쿼리 지원)
/// - `GET /attendance/me/streak` → `{ currentStreak, longestStreak }`
class BadgesApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<BadgeItem>> fetchAll() async {
    final res = await _apiClient.dio.get('/badges/me');
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => BadgeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<List<BadgeItem>> fetchRecent({int limit = 5}) async {
    final res = await _apiClient.dio.get(
      '/badges/me/recent',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => BadgeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  Future<AttendanceStreak> fetchStreak() async {
    final res = await _apiClient.dio.get('/attendance/me/streak');
    final data = res.data;
    if (data is Map) {
      return AttendanceStreak.fromJson(Map<String, dynamic>.from(data));
    }
    return const AttendanceStreak(currentStreak: 0, longestStreak: 0);
  }

  /// 앱 접속 시 출석 체크. 같은 KST 날짜 중복 호출은 서버에서 idempotent 처리.
  /// 실패해도 사용자 경로는 막지 않도록 호출 측에서 silent로 흡수할 것.
  Future<void> checkIn() async {
    await _apiClient.dio.post('/attendance/me/check-in');
  }
}
