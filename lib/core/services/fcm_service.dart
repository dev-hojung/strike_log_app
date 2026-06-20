import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/badges/presentation/pages/badge_list_page.dart';
import '../../features/game/presentation/pages/game_detail_page.dart';
import '../../features/group/presentation/pages/admin_creation_requests_page.dart';
import '../../features/group/presentation/pages/club_join_requests_page.dart';
import 'pending_join_requests_service.dart';
import '../../features/notifications/data/services/notifications_api_service.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../main.dart' show appNavigatorKey;
import '../widgets/main_container.dart';
import 'app_logger.dart';
import 'unread_notifications_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM][background] ${message.messageId} ${message.notification?.title}');
}

/// 메인 Android 알림 채널.
///
/// 채널 ID 끝의 `_v2`는 강제로 새 채널을 만들기 위함이다.
/// 동일 ID 채널은 한 번 만들어지면 importance를 OS 차원에서 사용자만 바꿀 수 있어서,
/// 기존 채널이 default importance로 박혀 있으면 heads-up이 안 뜬다.
/// 이후 importance를 더 올려야 한다면 또 한 번 ID를 올려서 재생성해야 한다.
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'strike_log_default_v2',
  'Strike Log 기본 알림',
  description: '클럽 활동, 체험판 상태, 초대 등 앱의 기본 알림',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
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

  /// 직전 register 성공 시 저장된 토큰. 같은 토큰을 또 보내지 않기 위해 비교용으로 사용.
  String? _lastRegisteredToken;

  /// 토큰 등록 재시도 백오프 단계 (0=첫시도, 마지막 도달 시 멈춤).
  /// 5s → 15s → 30s → 60s → 5min → 30min.
  int _registerRetryStep = 0;
  Timer? _registerRetryTimer;

  /// 중복 진입 방지 가드.
  bool _registerInFlight = false;

  static const List<Duration> _retryBackoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(minutes: 5),
    Duration(minutes: 30),
  ];

  Future<void> init() async {
    // 핫 리스타트나 다른 진입점에서 init이 또 호출돼도 listener가 중복 등록되지
    // 않도록 가드. onTokenRefresh/onMessage/onMessageOpenedApp 구독은 핸들이
    // 저장되지 않아 cancel이 불가하므로, 진입 자체를 막는다.
    if (_initialized) return;

    // 어떤 단계가 던지든 _ensureTokenRegistered/reverifyTokenRegistration이
    // 동작할 수 있도록 초기화 플래그를 가장 먼저 켠다. (이전 구현은 init의 일부 await에서
    // 예외가 나면 등록 호출이 영영 안 일어나는 사고가 있었음)
    _initialized = true;

    try {
      await _initLocalNotifications();
    } catch (e) {
      debugPrint('[FCM] local notifications init skipped: $e');
    }

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    } catch (e) {
      debugPrint('[FCM] onBackgroundMessage register skipped: $e');
    }

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] permission: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('[FCM] requestPermission skipped: $e');
    }

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[FCM] setForegroundNotificationPresentationOptions skipped: $e');
    }

    try {
      _token = await _messaging.getToken();
      if (kDebugMode) debugPrint('[FCM] token: $_token');
    } catch (e) {
      debugPrint('[FCM] getToken skipped: $e');
      _token = null;
    }

    // 권한·네트워크·JWT 어디서 막혀도 자동 재시도되도록 백오프 매니저로 일원화.
    // 위 단계가 실패해도 무조건 1회는 시도한다(빈 token이면 retry 스케줄됨).
    unawaited(_ensureTokenRegistered(reason: 'init'));

    try {
      _messaging.onTokenRefresh.listen((t) async {
        _token = t;
        if (kDebugMode) debugPrint('[FCM] token refreshed: $t');
        // 토큰이 바뀌면 마지막 성공 캐시 무효화 후 재등록 시도.
        _lastRegisteredToken = null;
        unawaited(_ensureTokenRegistered(reason: 'refresh'));
      });
    } catch (e) {
      debugPrint('[FCM] onTokenRefresh listener skipped: $e');
    }

    try {
      FirebaseMessaging.onMessage.listen((msg) async {
        debugPrint(
          '[FCM][foreground] ${msg.notification?.title} / ${msg.notification?.body}',
        );
        UnreadNotificationsService.instance.increment();
        if (msg.data['type']?.toString() == 'club_join_request') {
          PendingJoinRequestsService.instance.increment();
        }
        await _showForegroundNotification(msg);
      });
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _handleTap(initial));
      }
    } catch (e) {
      debugPrint('[FCM] message listeners skipped: $e');
    }
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
    if (notification == null) {
      debugPrint('[FCM][foreground] no notification field — data-only message, banner skipped');
      return;
    }
    final payload = jsonEncode(msg.data);
    try {
      await _localNotifications.show(
        // 고유 ID로 들어와 매 알림이 트레이에 누적되도록 한다.
        // 같은 ID면 Android가 기존 알림을 덮어써서 마지막 1건만 보이는 문제가 있어
        // 시각(ms) 기반 고유값으로 분리. 32비트 정수 범위로 안전하게 자른다.
        // 그룹 키를 명시해 Android 자동 그룹화로 인한 SILENT 강제를 회피.
        id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.message,
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
            // Android는 같은 앱의 알림이 4개 이상 쌓이면 자동 그룹화하면서
            // 개별 알림에 SILENT 플래그를 붙여 heads-up/소리를 다 죽인다.
            // 우리만의 group key로 묶고, 그룹 내 모든 알림이 alert하도록 명시.
            groupKey: 'com.hojung.strikelog.foreground',
            setAsGroupSummary: false,
            groupAlertBehavior: GroupAlertBehavior.all,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
      debugPrint('[FCM][foreground] banner shown title="${notification.title}"');
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'fcm.showForegroundNotification');
    }
  }

  /// onMessageOpenedApp / getInitialMessage 공통 라우팅 진입점.
  void _handleTap(RemoteMessage msg) {
    _routeByData(msg.data.map((k, v) => MapEntry(k, v?.toString() ?? '')));
  }

  /// FCM 데이터 페이로드 기반 라우팅 (FCM 탭 진입점).
  /// notificationId가 있으면 마킹/카운트 갱신까지 수행한다.
  /// 인앱 알림 리스트의 탭 핸들러는 이미 markAsRead를 별도로 호출하므로
  /// 여기를 거치지 않고 [navigateForType]을 직접 호출해야 한다.
  void _routeByData(Map<String, String> data) {
    final notificationId = data['notificationId'];
    navigateForType(type: data['type'], targetId: data['targetId']);
    if (notificationId != null && notificationId.isNotEmpty) {
      _api.markAsRead(notificationId);
      UnreadNotificationsService.instance.decrement();
    }
  }

  /// 타입별로 실제 이동할 곳이 있는지 여부.
  /// "거절"처럼 알림 페이지 자체가 종착지인 항목은 인앱 탭에서 push하지 않도록 한다.
  static bool hasDestination(String? type) {
    switch (type) {
      case 'club_creation_request':
      case 'club_join_request':
      case 'club_creation_approved':
      case 'club_join_approved':
      case 'club_trial_started':
      case 'club_trial_expiring_soon':
      case 'club_trial_expired':
      case 'club_game_created':
      case 'club_announcement':
      case 'club_perfect_game':
      case 'new_best_score':
      case 'badge_earned':
        return true;
      default:
        // 거절 / 알 수 없는 타입은 이동 대상 없음.
        return false;
    }
  }

  /// 타입/타깃ID 기반 네비게이션 분기.
  ///
  /// [fromInAppList] 가 true면 이미 알림 페이지에 있는 상황이므로 종착지가 없는
  /// 타입(거절 등)은 어떤 라우트도 push하지 않는다 (히스토리 오염 방지).
  void navigateForType({
    String? type,
    String? targetId,
    bool fromInAppList = false,
  }) {
    debugPrint('[FCM][route] type=$type targetId=$targetId inApp=$fromInAppList');

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
        // 거절은 종착지가 알림 페이지 자체. 인앱 탭이면 no-op,
        // FCM 시스템 알림 탭처럼 외부에서 진입한 경우엔 알림 페이지로 안내.
        if (!fromInAppList) {
          nav.push(MaterialPageRoute(
            builder: (_) => const NotificationsPage(),
          ));
        }
        break;
      case 'club_trial_started':
      case 'club_trial_expiring_soon':
      case 'club_trial_expired':
      case 'club_game_created':
      case 'club_announcement':
        // 클럽 탭으로 이동. 공지사항은 사용자가 헤더 📢 아이콘으로 열 수 있음.
        _switchToClubsTab(nav);
        break;
      case 'club_perfect_game':
        // 다른 클럽원이 퍼펙트 달성 알림 — 해당 게임 상세로 이동
        final perfectGameId = int.tryParse(targetId ?? '') ?? 0;
        if (perfectGameId > 0) {
          nav.push(MaterialPageRoute(
            builder: (_) => GameDetailPage(gameId: perfectGameId),
          ));
        }
        break;
      case 'new_best_score':
        final gameId = int.tryParse(targetId ?? '') ?? 0;
        if (gameId > 0) {
          nav.push(MaterialPageRoute(
            builder: (_) => GameDetailPage(gameId: gameId),
          ));
        }
        break;
      case 'badge_earned':
        // targetId = badge key. 카드 강조해 해당 배지를 강조 표시.
        nav.push(MaterialPageRoute(
          builder: (_) => BadgeListPage(highlightKey: targetId),
        ));
        break;
      case 'club_kicked':
        // 클럽에서 추방됨 — 그 클럽은 더 이상 멤버 아니라 진입 불가.
        // 알림 페이지 자체가 종착지(인앱)지만, FCM 시스템 알림 탭처럼 외부에서
        // 진입한 경우엔 알림 페이지로 안내(club_creation_rejected와 동일 패턴).
        if (!fromInAppList) {
          nav.push(MaterialPageRoute(
            builder: (_) => const NotificationsPage(),
          ));
        }
        break;
      default:
        // 미지의 type — 백엔드에 신규 type이 추가되고 클라가 아직 업데이트 안 됐을
        // 수 있다. 외부 진입이면 알림 페이지로 fallback해 사용자 흐름이 끊기지 않게.
        debugPrint('[FCM][route] unknown type=$type — fallback to NotificationsPage');
        if (!fromInAppList) {
          nav.push(MaterialPageRoute(
            builder: (_) => const NotificationsPage(),
          ));
        }
        break;
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
  /// 새 세션이라 마지막 성공 캐시 무효화 후 즉시 시도 + 실패 시 백오프 재시도.
  Future<void> syncTokenToServer(String userId) async {
    if (!_initialized) {
      debugPrint('[FCM] syncTokenToServer skipped (not initialized)');
      return;
    }
    _lastRegisteredToken = null;
    await _ensureTokenRegistered(reason: 'login:$userId');
  }

  /// 토큰 등록을 "최종적 일관성"으로 보장하는 단일 진입점.
  ///
  /// 호출 위치: init / onTokenRefresh / 로그인 / AppLifecycleState.resumed.
  ///
  /// 흐름:
  /// 1. 권한 거부/토큰 null이면 → 다음 백오프 슬롯에 재시도 예약 (사용자가 늦게 권한 켤 수도 있음)
  /// 2. user_id 없으면 → 등록 안 함 (로그아웃 상태). 재시도도 안 함 — 로그인 시점에 다시 진입함
  /// 3. 이전에 동일 토큰으로 성공했으면 → no-op (불필요한 호출 방지)
  /// 4. dio.post 실패면 → 다음 백오프 슬롯에 재시도 예약
  /// 5. 성공이면 → 백오프 리셋, _lastRegisteredToken 갱신
  Future<void> _ensureTokenRegistered({required String reason}) async {
    // ⚠️ _initialized 가드를 두면 안 됨 — init()이 _initialized=true 설정 전에 이 함수를
    //   호출하므로 가드가 있으면 init 시점 등록이 항상 무산됨. 외부 진입점
    //   (syncTokenToServer, reverifyTokenRegistration)이 각자 _initialized를 검사함.
    if (_registerInFlight) {
      debugPrint('[FCM] register skipped — already in flight ($reason)');
      return;
    }
    _registerInFlight = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      // 토큰 확보. permission 거부면 null 반환.
      final t = _token ?? await _messaging.getToken();
      if (t == null || t.isEmpty) {
        debugPrint('[FCM] register skipped — no token yet ($reason). scheduling retry.');
        _scheduleRetry(reason);
        return;
      }
      _token = t;

      // 같은 토큰을 같은 바인딩 상태로 또 보내지 않도록 캐시 키에 user_id 포함.
      final cacheKey = '${userId ?? 'anon'}|$t';
      if (_lastRegisteredToken == cacheKey) {
        debugPrint('[FCM] register skipped — unchanged ($reason)');
        _cancelRetry();
        return;
      }

      final loggedIn = userId != null && userId.isNotEmpty;
      final ok = loggedIn
          ? await _api.registerFcmToken(token: t, platform: _platform())
          : await _api.registerAnonymousFcmToken(token: t, platform: _platform());
      debugPrint(
        '[FCM] register ok=$ok mode=${loggedIn ? "auth" : "anon"} user=${userId ?? "-"} reason=$reason',
      );
      if (ok) {
        _lastRegisteredToken = cacheKey;
        _cancelRetry();
      } else {
        _scheduleRetry(reason);
      }
    } catch (e, st) {
      debugPrint('[FCM] _ensureTokenRegistered error: $e');
      AppLogger.captureError(e, stackTrace: st, context: 'fcm.ensureTokenRegistered');
      _scheduleRetry(reason);
    } finally {
      _registerInFlight = false;
    }
  }

  void _scheduleRetry(String reason) {
    _registerRetryTimer?.cancel();
    if (_registerRetryStep >= _retryBackoff.length) {
      debugPrint('[FCM] retry budget exhausted — will try again on next resume/login');
      return;
    }
    final delay = _retryBackoff[_registerRetryStep];
    _registerRetryStep++;
    debugPrint('[FCM] schedule retry in ${delay.inSeconds}s (step=$_registerRetryStep) reason=$reason');
    _registerRetryTimer = Timer(delay, () {
      unawaited(_ensureTokenRegistered(reason: 'retry:$reason'));
    });
  }

  void _cancelRetry() {
    _registerRetryTimer?.cancel();
    _registerRetryTimer = null;
    _registerRetryStep = 0;
  }

  /// 외부(앱 라이프사이클 옵저버 등)에서 강제 재검증할 때 호출.
  Future<void> reverifyTokenRegistration() async {
    if (!_initialized) return;
    // resume 시점엔 백오프 리셋해서 빠르게 첫 시도.
    _registerRetryStep = 0;
    _registerRetryTimer?.cancel();
    await _ensureTokenRegistered(reason: 'resume');
  }

  /// 로그아웃 시 호출. 서버 토큰을 익명 바인딩으로 재등록해서
  /// 시스템 공지 broadcast 푸시는 계속 받을 수 있도록 유지.
  ///
  /// (예전 구현: 서버에서 토큰 행 삭제 + 로컬 deleteToken — 로그아웃 후 시스템 공지도 못 받음)
  Future<void> clearTokenOnServer(String userId) async {
    if (!_initialized) return;
    final t = _token ?? await _messaging.getToken();
    if (t == null || t.isEmpty) {
      debugPrint('[FCM] logout — no token to rebind');
      return;
    }
    // 서버 측 userId 바인딩만 NULL로 풀어둔다. FCM 토큰 자체는 살려둠.
    final ok = await _api.registerAnonymousFcmToken(
      token: t,
      platform: _platform(),
    );
    debugPrint('[FCM] logout rebind to anonymous ok=$ok user=$userId');
    // 다음 로그인 시점에 _ensureTokenRegistered가 다시 호출되도록 캐시 초기화.
    _lastRegisteredToken = null;
  }

  String _platform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'other';
  }
}
