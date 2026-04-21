import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/group/presentation/pages/admin_creation_requests_page.dart';
import '../../features/group/presentation/pages/club_join_requests_page.dart';
import '../../features/notifications/data/services/notifications_api_service.dart';
import '../../main.dart' show appNavigatorKey;

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][background] ${message.messageId} ${message.notification?.title}');
}

/// FCM 싱글톤.
/// - 앱 시작 시 `init()`으로 권한/리스너 등록
/// - 로그인 성공 직후 `syncTokenToServer()`로 현재 토큰을 서버에 등록
/// - 토큰이 refresh되면 로그인 상태일 때 자동으로 재등록
/// - 알림 탭 시 data.type + targetId 기반으로 해당 페이지로 라우팅
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

    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 앱이 종료된 상태에서 알림을 탭해 실행된 경우
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // 첫 프레임 렌더 이후 네비게이션
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(initial));
    }
  }

  /// 알림 탭 시 라우팅. data payload는 서버에서 String-String으로 전달됨.
  /// 키: `type`, `targetId`, `notificationId`
  void _handleTap(RemoteMessage msg) {
    final data = msg.data;
    final type = data['type']?.toString();
    final targetId = data['targetId']?.toString();
    debugPrint('[FCM][tap] type=$type targetId=$targetId');

    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('[FCM][tap] navigator not ready');
      return;
    }

    switch (type) {
      case 'club_creation_request':
        // 관리자: 신청 관리 페이지
        nav.push(MaterialPageRoute(
          builder: (_) => const AdminCreationRequestsPage(),
        ));
        break;
      case 'club_join_request':
        // 클럽장: 가입 요청 페이지
        final clubId = int.tryParse(targetId ?? '') ?? 0;
        if (clubId > 0) {
          nav.push(MaterialPageRoute(
            builder: (_) => ClubJoinRequestsPage(
              clubId: clubId,
              clubName: '',
            ),
          ));
        }
        break;
      // 신청자/일반 멤버가 받는 결과 알림들은 별도 페이지가 없어
      // 현재 화면을 유지 (사용자가 내 클럽 탭을 열면 갱신된 상태가 보임).
      case 'club_creation_approved':
      case 'club_creation_rejected':
      case 'club_join_approved':
      case 'club_join_rejected':
      case 'club_game_created':
      default:
        // 명시적 라우팅 없음
        break;
    }

    // 읽음 처리는 탭과 동시에 처리 (notificationId가 있을 때)
    final notificationIdStr = data['notificationId']?.toString();
    if (notificationIdStr != null && notificationIdStr.isNotEmpty) {
      _api.markAsRead(notificationIdStr);
    }
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
