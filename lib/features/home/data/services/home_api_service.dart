import '../../../../core/services/api_client.dart';
import '../models/home_dashboard_data.dart';

class HomeApiService {
  final ApiClient _apiClient = ApiClient();

  /// 여러 API를 조합하여 홈 대시보드 데이터를 구성합니다.
  Future<HomeDashboardData> fetchDashboardData(String userId) async {
    try {
      final dio = _apiClient.dio;

      // 프로필 + 통계는 필수, 클럽 + 월간 프레임 통계는 실패해도 무방
      final profileFuture = dio.get('/users/$userId');
      final statsFuture = dio.get('/games/users/$userId/statistics');
      final groupsFuture = dio.get('/groups/me').then((r) => r.data).catchError((_) => null);
      final monthlyFrameFuture = dio
          .get('/games/users/$userId/monthly-frame-stats')
          .then((r) => r.data)
          .catchError((_) => null);

      final profileRes = await profileFuture;
      final statsRes = await statsFuture;
      final groupsData = await groupsFuture;
      final monthlyFrameData = await monthlyFrameFuture;

      final profile = profileRes.data ?? {};
      final stats = statsRes.data ?? {};

      // 월별 트렌드 파싱
      final monthlyTrend = stats['monthlyTrend'] ?? {};
      final trendStatus = monthlyTrend['status'] ?? 'none';
      final monthlyFrame =
          monthlyFrameData is Map ? monthlyFrameData : <String, dynamic>{};

      return HomeDashboardData(
        nickname: profile['nickname'] ?? 'Guest',
        averageScore: stats['averageScore'] ?? 0,
        personalAverageScore: (stats['personalAverageScore'] as num?)?.toInt() ?? 0,
        clubAverageScore: (stats['clubAverageScore'] as num?)?.toInt() ?? 0,
        highestScore: stats['highestScore'] ?? 0,
        highestScoreDate: stats['highestScoreDate'] != null
            ? DateTime.parse(stats['highestScoreDate'].toString())
            : null,
        trendPercentage: monthlyTrend['percentage']?.toDouble(),
        trendStatus: trendStatus,
        currentMonthGameCount: monthlyTrend['currentMonthGameCount'],
        currentMonthAvg: monthlyTrend['currentMonthAvg'],
        monthlyStrikes: (monthlyFrame['strikes'] as num?)?.toInt() ?? 0,
        monthlySpares: (monthlyFrame['spares'] as num?)?.toInt() ?? 0,
        monthlyOpens: (monthlyFrame['opens'] as num?)?.toInt() ?? 0,
        monthlyAllCoverGames:
            (monthlyFrame['allCoverGames'] as num?)?.toInt() ?? 0,
        monthlyPerfectGames:
            (monthlyFrame['perfectGames'] as num?)?.toInt() ?? 0,
        recentTrend: stats['recentTrend'] != null
            ? (stats['recentTrend'] as List)
                .map((e) => TrendData.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : [],
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
