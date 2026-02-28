import 'package:dio/dio.dart';
import 'dart:io' show Platform;

/// API 통신을 위한 Dio 클라이언트 싱글톤 클래스
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late Dio dio;

  // 개발 환경에 맞춰 기본 BaseUrl 설정
  // Android 에뮬레이터는 10.0.2.2, iOS 시뮬레이터는 127.0.0.1 또는 localhost를 사용합니다.
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    } else {
      return 'http://127.0.0.1:3000'; // 실기기의 경우 PC의 내부 IP(예: 192.168.x.x)로 변경해야 합니다.
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

    // 요청 및 응답 로깅 (개발용)
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }
}
