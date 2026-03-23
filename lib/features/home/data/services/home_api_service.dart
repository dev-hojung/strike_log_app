import '../../../../core/services/api_client.dart';
import '../models/home_dashboard_data.dart';

class HomeApiService {
  final ApiClient _apiClient = ApiClient();

  /// 여러 API를 조합하여 홈 대시보드 데이터를 구성합니다.
  Future<HomeDashboardData> fetchDashboardData(String userId) async {
    try {
      final dio = _apiClient.dio;

      // 프로필 + 통계는 필수, 최근 경기 + 클럽은 실패해도 무방
      final profileFuture = dio.get('/users/$userId');
      final statsFuture = dio.get('/games/users/$userId/statistics');
      final recentFuture = dio.get('/games/users/$userId/recent').then((r) => r.data).catchError((_) => null);
      final groupsFuture = dio.get('/groups/me/$userId').then((r) => r.data).catchError((_) => null);

      final profileRes = await profileFuture;
      final statsRes = await statsFuture;
      final recentGameData = await recentFuture;
      final groupsData = await groupsFuture;

      final profile = profileRes.data ?? {};
      final stats = statsRes.data ?? {};

      // 월별 트렌드 파싱
      final monthlyTrend = stats['monthlyTrend'] ?? {};
      final trendStatus = monthlyTrend['status'] ?? 'none';

      return HomeDashboardData(
        nickname: profile['nickname'] ?? 'Guest',
        averageScore: stats['averageScore'] ?? 0,
        highestScore: stats['highestScore'] ?? 0,
        highestScoreDate: stats['highestScoreDate'] != null
            ? DateTime.parse(stats['highestScoreDate'].toString())
            : null,
        trendPercentage: monthlyTrend['percentage']?.toDouble(),
        trendStatus: trendStatus,
        currentMonthGameCount: monthlyTrend['currentMonthGameCount'],
        recentTrend: stats['recentTrend'] != null
            ? (stats['recentTrend'] as List)
                .map((e) => TrendData.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : [],
        recentGame: recentGameData != null && recentGameData is Map
            ? RecentGame.fromJson(Map<String, dynamic>.from(recentGameData))
            : null,
        hasGroup: groupsData is List && groupsData.isNotEmpty,
        clubs: groupsData is List
            ? groupsData.map((g) => ClubInfo.fromJson(Map<String, dynamic>.from(g))).toList()
            : [],
      );
    } catch (e) {
      return HomeDashboardData(
        averageScore: 0,
        highestScore: 0,
        recentTrend: [],
        nickname: 'Guest',
      );
    }
  }
}
