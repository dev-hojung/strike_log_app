import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/fcm_service.dart';
import 'core/services/user_profile_cache.dart';
import 'core/theme/app_theme.dart';
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

  // 환경변수(.env) 로드
  await dotenv.load(fileName: ".env");

  // 프로필 캐시를 메모리로 미리 로드 (페이지 initState에서 동기 접근)
  await UserProfileCache.init();

  // Firebase 초기화 + FCM 준비 (Android: google-services.json 기반)
  await Firebase.initializeApp();
  await FcmService.instance.init();

  runApp(const BowlingApp());
}

/// 플러터 볼링 앱의 진입점입니다.
///
/// [MaterialApp]을 설정하고, 테마 및 라우팅을 관리합니다.
/// 앱의 기본 홈 화면으로 [LoginPage]를 설정합니다.
class BowlingApp extends StatelessWidget {
  const BowlingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Bowling',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const LoginPage(),
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
    );
  }
}
