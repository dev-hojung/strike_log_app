import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/group/presentation/pages/admin_creation_requests_page.dart';
import '../../features/group/presentation/pages/club_join_requests_page.dart';
import '../../features/notifications/data/services/notifications_api_service.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../main.dart' show appNavigatorKey;
import '../widgets/main_container.dart';
import 'app_logger.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][background] ${message.messageId} ${message.notification?.title}');
}

/// 메인 Android 알림 채널.
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'strike_log_default',
  'Strike Log 기본 알림',
  description: '클럽 활동, 체험판 상태, 초대 등 앱의 기본 알림',
  importance: Importance.high,
);

/// FCM 싱글톤.
/// - 앱 시작 시 `init()`으로 권한/리스너 등록 + 로컬 알림 채널 세팅
/// - foreground 메시지는 `flutter_local_notifications`로 시스템 배너 표시
/// - 알림/로컬 알림 탭 시 data.type + targetId 기반 라우팅
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  FirebaseMessaging? _messagingInstance;
  FirebaseMessaging get _messaging =>
      _messagingInstance ??= FirebaseMessaging.instance;
  final NotificationsApiService _api = NotificationsApiService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _localNotifReady = false;
  String? _token;
  String? get token => _token;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    await _initLocalNotifications();

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

    FirebaseMessaging.onMessage.listen((msg) async {
      debugPrint('[FCM][foreground] ${msg.notification?.title} / ${msg.notification?.body}');
      await _showForegroundNotification(msg);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(initial));
    }
    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotifReady) return;
    // iOS의 경우 payload 받기 위한 권한 옵션은 firebase_messaging이 별도 처리.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = Map<String, dynamic>.from(jsonDecode(payload));
          _routeByData(data.map((k, v) => MapEntry(k, v?.toString() ?? '')));
        } catch (e, st) {
          AppLogger.captureError(e,
              stackTrace: st,
              context: 'fcm.localNotification.parsePayload',
              extra: {'payload': payload});
        }
      },
    );

    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_androidChannel);
    }
    _localNotifReady = true;
  }

  Future<void> _showForegroundNotification(RemoteMessage msg) async {
    final notification = msg.notification;
    if (notification == null) return;
    final payload = jsonEncode(msg.data);
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  /// onMessageOpenedApp / getInitialMessage 공통 라우팅 진입점.
  void _handleTap(RemoteMessage msg) {
    _routeByData(msg.data.map((k, v) => MapEntry(k, v?.toString() ?? '')));
  }

  /// data payload(Map&lt;String,String&gt;) 기반 네비게이션.
  void _routeByData(Map<String, String> data) {
    final type = data['type'];
    final targetId = data['targetId'];
    final notificationId = data['notificationId'];
    debugPrint('[FCM][route] type=$type targetId=$targetId');

    final nav = appNavigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'club_creation_request':
        nav.push(MaterialPageRoute(
          builder: (_) => const AdminCreationRequestsPage(),
        ));
        break;
      case 'club_join_request':
        final clubId = int.tryParse(targetId ?? '') ?? 0;
        if (clubId > 0) {
          nav.push(MaterialPageRoute(
            builder: (_) => ClubJoinRequestsPage(clubId: clubId, clubName: ''),
          ));
        }
        break;
      case 'club_creation_approved':
      case 'club_join_approved':
        // 내 클럽 탭으로 이동 (pages 배열에서 MyGroupsPage는 index 2)
        _switchToClubsTab(nav);
        break;
      case 'club_creation_rejected':
      case 'club_join_rejected':
        nav.push(MaterialPageRoute(
          builder: (_) => const NotificationsPage(),
        ));
        break;
      case 'club_trial_expiring_soon':
      case 'club_trial_expired':
      case 'club_game_created':
        _switchToClubsTab(nav);
        break;
      default:
        break;
    }

    if (notificationId != null && notificationId.isNotEmpty) {
      _api.markAsRead(notificationId);
    }
  }

  /// 현재 스택을 모두 비우고 내 클럽 탭이 선택된 MainContainer로 진입.
  void _switchToClubsTab(NavigatorState nav) {
    nav.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainContainer(initialTabIndex: 2),
      ),
      (_) => false,
    );
  }

  /// 로그인 직후 호출. 현재 토큰을 백엔드에 등록.
  Future<void> syncTokenToServer(String userId) async {
    if (!_initialized) {
      debugPrint('[FCM] syncTokenToServer skipped (not initialized)');
      return;
    }
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
    if (!_initialized) return;
    final t = _token;
    if (t != null) {
      await _api.deleteFcmToken(userId: userId, token: t);
    }
    await _messaging.deleteToken();
    _token = null;
  }

  String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
