import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/api_client.dart';
import 'core/services/auth_token_storage.dart';
import 'core/services/fcm_service.dart';
import 'core/services/pending_join_requests_service.dart';
import 'core/services/session_manager.dart';
import 'core/services/unread_notifications_service.dart';
import 'core/services/user_profile_cache.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_container.dart';
import 'features/auth/presentation/pages/login_page.dart';

/// 앱 전역 RouteObserver.
/// MainContainer가 RouteAware로 구독해, 다른 라우트가 pop되어 다시 top이 될 때마다
/// 홈 대시보드/기록 캐시를 무효화하고 리프레시한다.
///
/// 제네릭을 `PageRoute<dynamic>`으로 두어 MaterialPageRoute/CupertinoPageRoute 모두 매칭되도록 함.
/// (iOS에서 `MaterialPageRoute<dynamic>`이 `ModalRoute<void>`로는 `is R` 체크를 통과하지 못해
///  didPopNext가 호출되지 않던 문제 대응)
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// 전역 Navigator 키.
/// context 없이 푸시 알림 탭 이벤트에서 라우팅하기 위해 사용.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Flutter 엔진 초기화 보장 (비동기 처리 시 필수)
  WidgetsFlutterBinding.ensureInitialized();

  // google_fonts 패키지가 런타임에 폰트를 다운로드하지 않도록 차단.
  // `assets/google_fonts/`에 번들된 .ttf만 사용한다.
  // (첫 실행 시 폰트가 시스템 폰트 → Lexend로 깜빡이며 바뀌는 현상 방지)
  GoogleFonts.config.allowRuntimeFetching = false;

  // 환경변수(.env) 로드
  await dotenv.load(fileName: ".env");

  // 한국어 로케일 데이터 초기화. DateFormat(..., 'ko_KR') 호출 전 필수.
  await initializeDateFormatting('ko_KR');

  // 인증 토큰을 메모리로 미리 로드 (Dio 인터셉터가 동기 접근)
  await AuthTokenStorage.init();
  // 프로필 캐시를 메모리로 미리 로드 (페이지 initState에서 동기 접근)
  await UserProfileCache.init();

  // 401 수신 시 강제 로그아웃 후 로그인 화면으로 이동
  ApiClient.onUnauthorized = () async {
    await SessionManager.clearAll();
    final nav = appNavigatorKey.currentState;
    nav?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  };

  final sentryDsn = dotenv.env['SENTRY_DSN'];
  Future<void> runAppWithSentry() async {
    // 1) 자동 로그인 판정. AuthTokenStorage는 init()에서 이미 메모리로 로드된 상태.
    //    저장된 JWT + user_id가 둘 다 있으면 MainContainer로 직접 진입.
    //    (서버 401이 떨어지면 ApiClient.onUnauthorized 콜백이 SessionManager.clearAll → LoginPage push)
    Widget? autoLoginHome;
    String? autoUserId;
    final storedToken = AuthTokenStorage.current;
    if (storedToken != null && storedToken.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null && userId.isNotEmpty) {
        autoLoginHome = const MainContainer();
        autoUserId = userId;
      }
    }

    // 2) Firebase + FCM 초기화. iOS 시뮬레이터처럼 구성 파일이 없으면 조용히 건너뜀.
    try {
      await Firebase.initializeApp();
      await FcmService.instance.init();
      // 저장된 JWT가 있을 때만 동기화 호출 (자동 로그인 케이스).
      if (autoUserId != null) {
        unawaited(FcmService.instance.syncTokenToServer(autoUserId));
        unawaited(UnreadNotificationsService.instance.refresh());
        unawaited(PendingJoinRequestsService.instance.refresh());
      }
    } catch (e, st) {
      debugPrint('[Firebase] init skipped: $e');
      debugPrintStack(stackTrace: st, label: 'Firebase init');
    }

    runApp(BowlingApp(initialHome: autoLoginHome));
  }

  if (sentryDsn != null && sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        // 개발 환경은 전송 비율 낮추고, 릴리즈에서 풀로 수집.
        options.tracesSampleRate = kReleaseMode ? 1.0 : 0.2;
        options.environment = kReleaseMode ? 'production' : 'development';
      },
      appRunner: runAppWithSentry,
    );
  } else {
    await runAppWithSentry();
  }
}

/// 플러터 볼링 앱의 진입점입니다.
///
/// [MaterialApp]을 설정하고, 테마 및 라우팅을 관리합니다.
/// 저장된 JWT + user_id가 모두 유효하면 [MainContainer]로 자동 진입, 아니면 [LoginPage].
class BowlingApp extends StatelessWidget {
  const BowlingApp({super.key, this.initialHome});

  /// 앱 시작 시 표시할 첫 화면. null이면 [LoginPage] (자동 로그인 미해당).
  final Widget? initialHome;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Bowling',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: initialHome ?? const LoginPage(),
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
    );
  }
}
