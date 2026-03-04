import 'package:dio/dio.dart';
import '../../../../core/services/api_client.dart';
import '../models/home_dashboard_data.dart';

class HomeApiService {
  final ApiClient _apiClient = ApiClient();

  /// 사용자의 홈 대시보드 데이터(통계 및 최근 게임)를 가져옵니다.
  /// 
  /// [userId]는 임시로 파라미터로 받습니다 (추후 인증 토큰에서 처리).
  Future<HomeDashboardData> fetchDashboardData(String userId) async {
    try {
      // 1. 유저 프로필 호출 (닉네임 획득)
      String nickname = 'Alex'; // Default fallback
      try {
        final profileResponse = await _apiClient.dio.get('/users/$userId');
        if (profileResponse.data != null && profileResponse.data['nickname'] != null) {
          nickname = profileResponse.data['nickname'];
        }
      } catch (e) {
        // 프로필 조회 실패 시 기본 닉네임 사용
        print('프로필 조회 실패: $e');
      }

      // 2. 통계 데이터 호출
      final statsResponse = await _apiClient.dio.get('/games/users/$userId/statistics');
      
      // 3. 최근 게임 호출 (404가 발생할 수 있으므로 에러 핸들링)
      RecentGame? recentGame;
      try {
        final recentResponse = await _apiClient.dio.get('/games/users/$userId/recent');
        if (recentResponse.data != null) {
          recentGame = RecentGame.fromJson(recentResponse.data);
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) {
          rethrow;
        }
        // 404면 최근 게임이 없는 것이므로 null 유지
      }

      final statsData = statsResponse.data;
      
      List<TrendData> trend = [];
      if (statsData['recentTrend'] != null) {
        trend = (statsData['recentTrend'] as List)
            .map((item) => TrendData.fromJson(item))
            .toList();
      }

      return HomeDashboardData(
        averageScore: statsData['averageScore'] ?? 0,
        highestScore: statsData['highestScore'] ?? 0,
        highestScoreDate: statsData['highestScoreDate'] != null 
            ? DateTime.parse(statsData['highestScoreDate']) 
            : null,
        recentTrend: trend,
        recentGame: recentGame,
        nickname: nickname,
      );
    } catch (e) {
      throw Exception('대시보드 데이터를 불러오는데 실패했습니다: $e');
    }
  }
}
