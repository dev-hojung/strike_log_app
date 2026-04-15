import 'package:dio/dio.dart';
import '../../../../core/services/api_client.dart';

/// 게임 저장 실패 원인 분류
enum GameSaveErrorType {
  /// 네트워크 연결 실패 (인터넷 없음, 서버 미응답)
  network,

  /// 요청/응답 타임아웃
  timeout,

  /// 서버 5xx 오류
  server,

  /// 인증 실패 (401/403)
  unauthorized,

  /// 기타 4xx (클라이언트 요청 문제)
  client,

  /// 분류 불가
  unknown,
}

/// 게임 저장 결과. [success] 여부에 따라 [errorType]/[errorMessage]가 설정됨.
class GameSaveResult {
  final bool success;
  final GameSaveErrorType? errorType;
  final String? errorMessage;
  final int? statusCode;

  const GameSaveResult.success()
      : success = true,
        errorType = null,
        errorMessage = null,
        statusCode = null;

  const GameSaveResult.failure({
    required this.errorType,
    required this.errorMessage,
    this.statusCode,
  }) : success = false;
}

/// 게임 저장 API 호출 + 자동 재시도 + 에러 분류를 담당하는 서비스.
///
/// UI는 [GameSaveResult]를 받아 성공/실패 메시지만 처리하면 된다.
class GameSaveService {
  final Dio _dio;

  GameSaveService([Dio? dio]) : _dio = dio ?? ApiClient().dio;

  /// `/games` POST. 성공 시 [GameSaveResult.success], 실패 시 분류된 [GameSaveResult.failure] 반환.
  ///
  /// 재시도 정책:
  /// - 최대 [maxAttempts]회 시도 (기본 3회)
  /// - 시도 간격은 [retryDelays] 순서 (기본 1s, 3s 백오프)
  /// - 4xx 응답은 재시도해도 결과가 같으므로 즉시 중단
  Future<GameSaveResult> saveGame({
    required Map<String, dynamic> payload,
    int maxAttempts = 3,
    List<Duration> retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
    ],
  }) async {
    GameSaveResult lastFailure = const GameSaveResult.failure(
      errorType: GameSaveErrorType.unknown,
      errorMessage: '알 수 없는 오류',
    );

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0 && attempt - 1 < retryDelays.length) {
        await Future.delayed(retryDelays[attempt - 1]);
      }

      try {
        final response = await _dio.post('/games', data: payload);
        final code = response.statusCode;
        if (code == 200 || code == 201) {
          return const GameSaveResult.success();
        }
        lastFailure = GameSaveResult.failure(
          errorType: GameSaveErrorType.server,
          errorMessage: '서버가 비정상 응답을 반환했습니다. ($code)',
          statusCode: code,
        );
      } on DioException catch (e) {
        lastFailure = _classify(e);
        final status = e.response?.statusCode ?? 0;
        // 4xx는 재시도해도 의미 없음
        if (status >= 400 && status < 500) break;
      } catch (_) {
        lastFailure = const GameSaveResult.failure(
          errorType: GameSaveErrorType.unknown,
          errorMessage: '저장 중 예상치 못한 오류가 발생했습니다.',
        );
      }
    }

    return lastFailure;
  }

  GameSaveResult _classify(DioException e) {
    final status = e.response?.statusCode;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return const GameSaveResult.failure(
          errorType: GameSaveErrorType.network,
          errorMessage: '서버에 연결할 수 없습니다. 인터넷 연결을 확인해주세요.',
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const GameSaveResult.failure(
          errorType: GameSaveErrorType.timeout,
          errorMessage: '서버 응답이 지연되고 있습니다. 잠시 후 다시 시도해주세요.',
        );
      case DioExceptionType.badResponse:
        if (status == 401 || status == 403) {
          return GameSaveResult.failure(
            errorType: GameSaveErrorType.unauthorized,
            errorMessage: '인증이 만료되었습니다. 다시 로그인 후 시도해주세요.',
            statusCode: status,
          );
        }
        if (status != null && status >= 500) {
          return GameSaveResult.failure(
            errorType: GameSaveErrorType.server,
            errorMessage: '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
            statusCode: status,
          );
        }
        if (status != null && status >= 400) {
          return GameSaveResult.failure(
            errorType: GameSaveErrorType.client,
            errorMessage: '요청 처리 중 오류가 발생했습니다. ($status)',
            statusCode: status,
          );
        }
        return GameSaveResult.failure(
          errorType: GameSaveErrorType.unknown,
          errorMessage: '저장 중 오류가 발생했습니다.',
          statusCode: status,
        );
      case DioExceptionType.cancel:
        return const GameSaveResult.failure(
          errorType: GameSaveErrorType.unknown,
          errorMessage: '저장이 취소되었습니다.',
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return const GameSaveResult.failure(
          errorType: GameSaveErrorType.unknown,
          errorMessage: '저장 중 오류가 발생했습니다.',
        );
    }
  }
}
