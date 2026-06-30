import 'package:dio/dio.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/services/app_logger.dart';
import '../models/club_event.dart';
import '../models/club_event_result.dart';

/// 정기전/모임 API 래퍼.
///
/// 백엔드 라우트:
/// - POST   /groups/:id/events
/// - GET    /groups/:id/events?status=scheduled|in_progress|completed
/// - GET    /groups/:id/events/:eid
/// - PATCH  /groups/:id/events/:eid
/// - POST   /groups/:id/events/:eid/complete
/// - POST   /groups/:id/events/:eid/participants
/// - DELETE /groups/:id/events/:eid/participants/:uid
/// - POST   /groups/:id/events/:eid/assign-lanes
/// - GET    /groups/:id/events/:eid/result
class ClubEventsApiService {
  ClubEventsApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// 정기전 생성. STAFF 이상만 호출 가능.
  ///
  /// [participantUserIds] 빈 리스트 허용 (나중에 추가 가능).
  Future<ClubEvent> createEvent({
    required int groupId,
    required String name,
    required String eventDate,
    int? gameTarget,
    List<String> participantUserIds = const [],
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/groups/$groupId/events',
        data: {
          'name': name,
          'event_date': eventDate,
          if (gameTarget != null) 'game_target': gameTarget,
          'participantUserIds': participantUserIds,
        },
      );
      return ClubEvent.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.createEvent');
      rethrow;
    }
  }

  /// 정기전 목록 조회.
  ///
  /// [status] null이면 전체 반환. 'scheduled' | 'in_progress' | 'completed' 사용.
  Future<List<ClubEvent>> listEvents(int groupId, {String? status}) async {
    try {
      final res = await _apiClient.dio.get(
        '/groups/$groupId/events',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      final data = res.data;
      if (data is List) {
        return data
            .map((e) => ClubEvent.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return const [];
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.listEvents');
      rethrow;
    }
  }

  /// 정기전 상세 조회 (참가자·레인 포함).
  Future<ClubEvent> getEvent(int groupId, int eventId) async {
    try {
      final res =
          await _apiClient.dio.get('/groups/$groupId/events/$eventId');
      return ClubEvent.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.getEvent');
      rethrow;
    }
  }

  /// 정기전 수정 (이름·날짜·상태·목표 게임 수). STAFF 이상만.
  Future<ClubEvent> updateEvent({
    required int groupId,
    required int eventId,
    String? name,
    String? eventDate,
    String? status,
    int? gameTarget,
  }) async {
    try {
      final res = await _apiClient.dio.patch(
        '/groups/$groupId/events/$eventId',
        data: {
          if (name != null) 'name': name,
          if (eventDate != null) 'event_date': eventDate,
          if (status != null) 'status': status,
          if (gameTarget != null) 'game_target': gameTarget,
        },
      );
      return ClubEvent.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.updateEvent');
      rethrow;
    }
  }

  /// 정기전 완료 처리. STAFF 이상만.
  Future<Map<String, dynamic>> completeEvent(
      int groupId, int eventId) async {
    try {
      final res = await _apiClient.dio
          .post('/groups/$groupId/events/$eventId/complete');
      final data = res.data;
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.completeEvent');
      rethrow;
    }
  }

  /// 참가자 추가. STAFF 이상만.
  Future<void> addParticipants({
    required int groupId,
    required int eventId,
    required List<String> userIds,
  }) async {
    try {
      await _apiClient.dio.post(
        '/groups/$groupId/events/$eventId/participants',
        data: {'userIds': userIds},
      );
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.addParticipants');
      rethrow;
    }
  }

  /// 참가자 제거. STAFF 이상만.
  Future<void> removeParticipant({
    required int groupId,
    required int eventId,
    required String userId,
  }) async {
    try {
      await _apiClient.dio
          .delete('/groups/$groupId/events/$eventId/participants/$userId');
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.removeParticipant');
      rethrow;
    }
  }

  /// 레인 배치. STAFF 이상만.
  ///
  /// [mode]: 'random' | 'balanced' | 'team'
  /// [laneCount]: 사용할 레인 수
  Future<ClubEvent> assignLanes({
    required int groupId,
    required int eventId,
    required String mode,
    required int laneCount,
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/groups/$groupId/events/$eventId/assign-lanes',
        data: {'mode': mode, 'laneCount': laneCount},
      );
      return ClubEvent.fromJson(Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.assignLanes');
      rethrow;
    }
  }

  /// 결과 집계 조회 (참가자/팀별 순위·평균).
  Future<ClubEventResult> getEventResult(int groupId, int eventId) async {
    try {
      final res = await _apiClient.dio
          .get('/groups/$groupId/events/$eventId/result');
      return ClubEventResult.fromJson(
          Map<String, dynamic>.from(res.data as Map));
    } on DioException catch (e, st) {
      await AppLogger.captureError(e,
          stackTrace: st, context: 'clubEvents.getEventResult');
      rethrow;
    }
  }
}
