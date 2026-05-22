/// 네트워크/API 호출 실패의 분류된 표현.
///
/// 각 호출 측에서 `try/catch (e)` 후 `ApiErrorClassifier.from(e)`로 변환해 사용한다.
/// UI는 [ApiError.type]을 보고 적절한 아이콘·문구·재시도 가능 여부를 결정한다.
enum ApiErrorType {
  /// 연결 실패 (네트워크 끊김, 호스트 도달 불가)
  network,

  /// 요청/응답 타임아웃
  timeout,

  /// 5xx 서버 오류
  server,

  /// 4xx 클라이언트 오류 (401/403/410 제외)
  client,

  /// 401/403 인증/권한 만료
  unauthorized,

  /// 알 수 없는 오류 (cancel, 인증서, 기타)
  unknown,
}

class ApiError implements Exception {
  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final Object? cause;
  final StackTrace? stackTrace;

  const ApiError({
    required this.type,
    required this.message,
    this.statusCode,
    this.cause,
    this.stackTrace,
  });

  /// 동일 요청을 재시도할 가치가 있는 종류인지.
  /// network/timeout/server는 일시적 → 재시도 권장, client/unauthorized는 의미 없음.
  bool get isRetryable =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.server;

  @override
  String toString() =>
      'ApiError(type: $type, status: $statusCode, message: $message)';
}
