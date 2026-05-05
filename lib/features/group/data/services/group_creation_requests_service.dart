import 'package:dio/dio.dart';

import '../../../../core/services/api_client.dart';

/// 동일 유저가 이미 심사 중인 신청을 갖고 있을 때(409 Conflict).
class CreationRequestConflictException implements Exception {
  final String message;
  const CreationRequestConflictException(this.message);
  @override
  String toString() => message;
}

/// 그 외 사유로 신청 생성에 실패했을 때.
class CreationRequestFailedException implements Exception {
  final String message;
  const CreationRequestFailedException(this.message);
  @override
  String toString() => message;
}

/// 클럽 생성 신청 REST 래퍼.
///
/// 백엔드 엔드포인트 (JWT 인증 기준 — 서버가 토큰의 user.id로 식별):
/// - POST   /groups/creation-requests              신청 생성
/// - GET    /groups/creation-requests/me           내 신청 목록
/// - GET    /groups/creation-requests?status=...   [ADMIN] 전체 신청
/// - POST   /groups/creation-requests/:id/approve  [ADMIN]
/// - POST   /groups/creation-requests/:id/reject   [ADMIN]
/// - POST   /groups/creation-requests/:id/cancel   본인 취소
class GroupCreationRequestsService {
  final ApiClient _apiClient = ApiClient();

  /// 클럽 생성 신청.
  /// - 성공: 생성된 신청 row(Map) 반환
  /// - 동일 유저의 PENDING 신청이 이미 존재(409): [CreationRequestConflictException]
  /// - 그 외 모든 실패: [CreationRequestFailedException] (사유 포함)
  Future<Map<String, dynamic>> createRequest({
    required String name,
    String? description,
    String? coverImageUrl,
  }) async {
    try {
      final res = await _apiClient.dio.post(
        '/groups/creation-requests',
        data: {
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
          if (coverImageUrl != null && coverImageUrl.isNotEmpty)
            'cover_image_url': coverImageUrl,
        },
      );
      if (res.data is Map) {
        return Map<String, dynamic>.from(res.data);
      }
      throw const CreationRequestFailedException(
          '서버 응답 형식이 예상과 다릅니다.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        final msg = _extractMessage(e.response?.data) ?? '이미 심사 중인 신청이 있습니다.';
        throw CreationRequestConflictException(msg);
      }
      final msg = _extractMessage(e.response?.data) ?? e.message ?? '네트워크 오류';
      throw CreationRequestFailedException(msg);
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> listMyRequests() async {
    try {
      final res = await _apiClient.dio.get('/groups/creation-requests/me');
      if (res.data is List) {
        return (res.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    } catch (e) {
      // ignore: avoid_print
      print('[listMyRequests] failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> listForAdmin({String? status}) async {
    try {
      final res = await _apiClient.dio.get(
        '/groups/creation-requests',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      if (res.data is List) {
        return (res.data as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      // ignore: avoid_print
      print('[listForAdmin] unexpected payload type: ${res.data.runtimeType}');
      return [];
    } catch (e) {
      // 진단: silent catch 대신 사유 노출. (401/403/네트워크 등)
      // ignore: avoid_print
      print('[listForAdmin] status=$status failed: $e');
      return [];
    }
  }

  Future<bool> approve({required int requestId}) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/approve',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> reject({
    required int requestId,
    required String reason,
  }) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/reject',
        data: {'reason': reason},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancel({required int requestId}) async {
    try {
      await _apiClient.dio.post(
        '/groups/creation-requests/$requestId/cancel',
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
