import '../../../../core/services/api_client.dart';
import '../models/weekly_challenge.dart';

class ChallengesApiService {
  final ApiClient _apiClient = ApiClient();

  Future<List<WeeklyChallenge>> fetchWeekly() async {
    final res = await _apiClient.dio.get('/challenges/me/weekly');
    final data = res.data;
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((e) => WeeklyChallenge.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
