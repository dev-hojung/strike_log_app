import 'package:shared_preferences/shared_preferences.dart';

/// JWT 액세스 토큰을 로컬에 보관.
/// 메모리 미러를 두어 Dio 인터셉터가 각 요청마다 비동기 SharedPreferences를 기다리지 않도록 한다.
class AuthTokenStorage {
  AuthTokenStorage._();
  static const _key = 'auth_access_token_v1';
  static String? _memory;

  static String? get current => _memory;

  /// 앱 시작 시 1회 호출 — 디스크 → 메모리 로드.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _memory = prefs.getString(_key);
  }

  static Future<void> save(String token) async {
    _memory = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  static Future<void> clear() async {
    _memory = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
