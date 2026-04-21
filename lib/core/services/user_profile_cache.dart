import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'app_logger.dart';

/// 프로필 정보를 로컬에 캐시해 네트워크 응답 전에도 즉시 UI를 그리게 한다.
/// (stale-while-revalidate: 캐시로 즉시 렌더 → 백그라운드 fetch → 갱신)
///
/// 메모리 미러(`_memory`)를 두어 SharedPreferences 비동기 대기 없이
/// 페이지 initState에서 **동기적으로** 캐시에 접근하도록 설계.
/// 앱 시작 시 [init]을 호출해 디스크 값을 메모리로 끌어올린다.
class UserProfileCache {
  UserProfileCache._();
  static const _key = 'user_profile_cache_v1';
  static Map<String, dynamic>? _memory;

  /// 동기 접근용. initState에서 즉시 호출 가능.
  static Map<String, dynamic>? get cached => _memory;

  /// 앱 시작 시 1회 호출 — 디스크에 보관된 캐시를 메모리로 로드.
  static Future<void> init() async {
    _memory = await _readFromDisk();
  }

  static Future<Map<String, dynamic>?> _readFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      // 파싱 실패 시 손상된 캐시는 제거 (재fetch로 복구됨)
      AppLogger.captureError(
        e,
        stackTrace: st,
        context: 'userProfileCache.readFromDisk.parse',
      );
      await prefs.remove(_key);
    }
    return null;
  }

  static Future<void> save(Map<String, dynamic> profile) async {
    _memory = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile));
  }

  /// 비동기 로드 — 여전히 필요할 때만 사용. 새 코드는 [cached] 선호.
  static Future<Map<String, dynamic>?> load() async {
    if (_memory != null) return _memory;
    _memory = await _readFromDisk();
    return _memory;
  }

  static Future<void> clear() async {
    _memory = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// 서버에서 최신 프로필을 받아와 캐시에 저장.
  /// 프로필 수정(닉네임/전화 등) 직후 호출해 다음 조회를 즉시 최신 상태로 반영.
  static Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId == null) return;
    try {
      final res = await ApiClient().dio.get('/users/$userId');
      final data = res.data;
      if (data is Map) {
        await save(Map<String, dynamic>.from(data));
      }
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'userProfileCache.refresh');
    }
  }
}
