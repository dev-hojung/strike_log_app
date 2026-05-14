import '../../../../core/services/api_client.dart';
import '../models/club_leaderboard.dart';

class LeaderboardApiService {
  final _dio = ApiClient().dio;

  /// 클럽 리더보드 조회 (평균 점수 내림차순).
  /// 비멤버 요청은 서버에서 403으로 거절됨.
  Future<ClubLeaderboard> fetchClubLeaderboard(int clubId) async {
    final res = await _dio.get('/groups/$clubId/leaderboard');
    return ClubLeaderboard.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}
