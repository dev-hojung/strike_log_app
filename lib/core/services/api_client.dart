import 'package:dio/dio.dart';
import 'dart:io' show Platform;
import 'auth_token_storage.dart';

/// API 통신을 위한 Dio 클라이언트 싱글톤 클래스.
///
/// - `Authorization: Bearer <token>` 자동 부착
/// - 401 수신 시 [onUnauthorized] 콜백 호출 (메인에서 로그아웃 처리에 연결)
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio dio;

  /// 401 수신 시 실행할 콜백. main.dart에서 강제 로그아웃 구현에 사용.
  static void Function()? onUnauthorized;

  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3001';
    } else {
      return 'http://127.0.0.1:3001';
    }
  }

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Authorization 헤더 자동 부착
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AuthTokenStorage.current;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          // 세션 만료/잘못된 토큰 → 콜백으로 위임
          onUnauthorized?.call();
        }
        handler.next(e);
      },
    ));

    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
}
