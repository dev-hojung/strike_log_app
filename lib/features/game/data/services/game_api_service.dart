import '../../../../core/services/api_client.dart';
import '../../../home/data/models/home_dashboard_data.dart';

class GameApiService {
  final ApiClient _apiClient = ApiClient();

  /// 본인의 전체 게임 기록 리스트를 가져옵니다.
  /// 서버는 JWT 토큰의 user.id로 식별하므로 user_id 인자 불필요.
  Future<List<RecentGame>> fetchGameHistory() async {
    try {
      final response = await _apiClient.dio.get('/games/me');

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
