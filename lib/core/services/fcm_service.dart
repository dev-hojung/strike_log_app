import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/data/services/notifications_api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][background] ${message.messageId} ${message.notification?.title}');
}

/// FCM 싱글톤.
/// - 앱 시작 시 `init()`으로 권한/리스너 등록
/// - 로그인 성공 직후 `syncTokenToServer()`로 현재 토큰을 서버에 등록
/// - 토큰이 refresh되면 로그인 상태일 때 자동으로 재등록
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final NotificationsApiService _api = NotificationsApiService();

  String? _token;
  String? get token => _token;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    _token = await _messaging.getToken();
    debugPrint('[FCM] token: $_token');

    _messaging.onTokenRefresh.listen((t) async {
      _token = t;
      debugPrint('[FCM] token refreshed: $t');
      // 로그인 상태면 서버에 갱신
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        await _api.registerFcmToken(
          userId: userId,
          token: t,
          platform: _platform(),
        );
      }
    });

    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM][foreground] ${msg.notification?.title} / ${msg.notification?.body}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('[FCM][opened] ${msg.data}');
    });
  }

  /// 로그인 직후 호출. 현재 토큰을 백엔드에 등록.
  Future<void> syncTokenToServer(String userId) async {
    final t = _token ?? await _messaging.getToken();
    if (t == null) {
      debugPrint('[FCM] syncTokenToServer: no token available');
      return;
    }
    _token = t;
    final ok = await _api.registerFcmToken(
      userId: userId,
      token: t,
      platform: _platform(),
    );
    debugPrint('[FCM] register token for user=$userId ok=$ok');
  }

  /// 로그아웃 시 호출. 서버에서 토큰 제거 후 로컬 토큰 삭제.
  Future<void> clearTokenOnServer(String userId) async {
    final t = _token;
    if (t != null) {
      await _api.deleteFcmToken(userId: userId, token: t);
    }
    await _messaging.deleteToken();
    _token = null;
  }

  String _platform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
