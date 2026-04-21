import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// 에러 수집 및 로깅 래퍼.
///
/// - 디버그: stderr로 출력
/// - 릴리즈 + Sentry 초기화됨: Sentry에 보고
///
/// `Sentry.captureException`이 미초기화 상태에서도 호출 가능하지만(no-op 처리),
/// DSN 없이 init()을 호출하면 Sentry 자체가 초기화되지 않으므로 캡처가 조용히 버려진다.
class AppLogger {
  AppLogger._();

  /// 일반 에러 보고. non-fatal.
  static Future<void> captureError(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? extra,
  }) async {
    // 콘솔 출력 (개발 모드에서 보임)
    debugPrint('[AppLogger] ${context ?? ''} $error');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace, label: context);
    }

    // Sentry 전송
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          if (context != null) scope.setTag('context', context);
          if (extra != null && extra.isNotEmpty) {
            scope.setContexts('extra', extra);
          }
        },
      );
    } catch (_) {
      // Sentry 초기화 안 됐거나 네트워크 실패 — 무시
    }
  }

  /// 단순 정보 메시지.
  static void info(String message) {
    debugPrint('[AppLogger][info] $message');
  }
}
