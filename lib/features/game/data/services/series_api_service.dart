import '../../../../core/services/api_client.dart';
import '../models/game_series.dart';

/// 시리즈 API 클라이언트.
class SeriesApiService {
  final _dio = ApiClient().dio;

  /// 시리즈 시작. 성공 시 신규 시리즈 ID 반환.
  Future<int> startSeries({
    required int targetGameCount,
    DateTime? startedAt,
  }) async {
    final res = await _dio.post('/game-series', data: {
      'target_game_count': targetGameCount,
      if (startedAt != null) 'started_at': startedAt.toUtc().toIso8601String(),
    });
    final data = res.data;
    if (data is Map && data['id'] != null) return data['id'] as int;
    throw StateError('시리즈 응답에 id가 없습니다.');
  }

  /// 시리즈 종료.
  Future<void> completeSeries(int seriesId) async {
    await _dio.post('/game-series/$seriesId/complete');
  }

  /// 시리즈 단건 조회(게임 요약 포함).
  Future<GameSeries> getSeries(int seriesId) async {
    final res = await _dio.get('/game-series/$seriesId');
    return GameSeries.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  /// 사용자 최근 시리즈 목록.
  Future<List<GameSeries>> listRecent(String userId, {int limit = 10}) async {
    final res = await _dio.get(
      '/game-series/users/$userId/recent',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) => GameSeries.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 베스트 시리즈(완주 기준 총점 최고).
  Future<GameSeries?> getBest(String userId) async {
    final res = await _dio.get('/game-series/users/$userId/best');
    final data = res.data;
    if (data == null) return null;
    if (data is Map) {
      return GameSeries.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }
}
