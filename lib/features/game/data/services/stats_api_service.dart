import '../../../../core/services/api_client.dart';
import '../models/stats_analysis.dart';

/// P2 기록·분석 화면용 통계 API.
///
/// 모든 엔드포인트는 본인/관리자/같은 클럽 멤버만 접근 가능(백엔드 게이팅).
class StatsApiService {
  final ApiClient _apiClient = ApiClient();

  /// 볼링장별 통계 (게임수 내림차순).
  Future<List<CenterStat>> fetchCenterStats(String userId) async {
    final res = await _apiClient.dio.get('/games/users/$userId/center-stats');
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => CenterStat.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// 최근 [months]개월 월별 평균 (오래된→최신).
  Future<List<MonthlyAverage>> fetchMonthlyAverages(
    String userId, {
    int months = 6,
  }) async {
    final res = await _apiClient.dio.get(
      '/games/users/$userId/monthly-averages',
      queryParameters: {'months': months},
    );
    final data = res.data;
    if (data is List) {
      return data
          .map((e) => MonthlyAverage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return const [];
  }

  /// 통계 요약 (최근 [trend]경기 추세 포함).
  Future<StatsSummary> fetchSummary(String userId, {int trend = 20}) async {
    final res = await _apiClient.dio.get(
      '/games/users/$userId/statistics',
      queryParameters: {'trend': trend},
    );
    final data = res.data;
    if (data is Map) {
      return StatsSummary.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('통계 응답이 비정상입니다.');
  }
}
