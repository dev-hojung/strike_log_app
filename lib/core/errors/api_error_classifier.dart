import 'package:dio/dio.dart';

import 'api_error.dart';

/// 임의의 에러 객체를 분류된 [ApiError]로 변환한다.
///
/// 사용 예:
/// ```
/// try {
///   await api.fetch();
/// } catch (e, st) {
///   final err = ApiErrorClassifier.from(e, st);
///   // err.type, err.message로 UI 분기
/// }
/// ```
class ApiErrorClassifier {
  ApiErrorClassifier._();

  /// 임의의 에러 → ApiError.
  /// 이미 ApiError이면 그대로 반환, DioException은 [fromDio]로 분류,
  /// 그 외는 unknown으로 감싼다.
  static ApiError from(Object error, [StackTrace? stackTrace]) {
    if (error is ApiError) return error;
    if (error is DioException) return fromDio(error, stackTrace);
    return ApiError(
      type: ApiErrorType.unknown,
      message: '오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  /// Dio 에러 종류·상태코드 기반 분류.
  ///
  /// - connectionError/connectionTimeout → network
  /// - sendTimeout/receiveTimeout → timeout
  /// - badResponse 5xx → server
  /// - badResponse 401/403 → unauthorized
  /// - badResponse 4xx → client (서버 메시지 우선 사용)
  /// - cancel/badCertificate/unknown → unknown
  static ApiError fromDio(DioException e, [StackTrace? stackTrace]) {
    final status = e.response?.statusCode;
    final serverMessage = _extractServerMessage(e.response?.data);

    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return ApiError(
          type: ApiErrorType.network,
          message: '서버에 연결할 수 없습니다. 인터넷 연결을 확인해주세요.',
          cause: e,
          stackTrace: stackTrace ?? e.stackTrace,
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          type: ApiErrorType.timeout,
          message: '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.',
          cause: e,
          stackTrace: stackTrace ?? e.stackTrace,
        );
      case DioExceptionType.badResponse:
        if (status == 401 || status == 403) {
          return ApiError(
            type: ApiErrorType.unauthorized,
            message: '인증이 만료되었습니다. 다시 로그인 후 시도해주세요.',
            statusCode: status,
            cause: e,
            stackTrace: stackTrace ?? e.stackTrace,
          );
        }
        if (status != null && status >= 500) {
          return ApiError(
            type: ApiErrorType.server,
            message: serverMessage ?? '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
            statusCode: status,
            cause: e,
            stackTrace: stackTrace ?? e.stackTrace,
          );
        }
        if (status != null && status >= 400) {
          return ApiError(
            type: ApiErrorType.client,
            message: serverMessage ?? '요청 처리 중 오류가 발생했습니다. ($status)',
            statusCode: status,
            cause: e,
            stackTrace: stackTrace ?? e.stackTrace,
          );
        }
        return ApiError(
          type: ApiErrorType.unknown,
          message: serverMessage ?? '오류가 발생했습니다.',
          statusCode: status,
          cause: e,
          stackTrace: stackTrace ?? e.stackTrace,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return ApiError(
          type: ApiErrorType.unknown,
          message: '오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
          cause: e,
          stackTrace: stackTrace ?? e.stackTrace,
        );
    }
  }

  /// 서버 응답 본문에서 사람이 읽을 수 있는 message 필드를 꺼낸다.
  /// NestJS의 표준 에러 응답은 message가 string 또는 string[] 형태.
  static String? _extractServerMessage(dynamic data) {
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      if (msg is List && msg.isNotEmpty) return msg.join(', ');
    }
    return null;
  }
}
