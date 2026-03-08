import '../../../../core/services/api_client.dart';
import '../../../home/data/models/home_dashboard_data.dart';

class GameApiService {
  final ApiClient _apiClient = ApiClient();

  /// 사용자의 전체 게임 기록 리스트를 가져옵니다.
  Future<List<RecentGame>> fetchGameHistory(String userId) async {
    try {
      final response = await _apiClient.dio.get('/games/me/$userId');
      
      if (response.data is List) {
        return (response.data as List)
            .map((json) => RecentGame.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('게임 기록을 불러오는데 실패했습니다: $e');
    }
  }
}
