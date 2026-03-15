import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';

void main() async {
  // Flutter 엔진 초기화 보장 (비동기 처리 시 필수)
  WidgetsFlutterBinding.ensureInitialized();

  // 환경변수(.env) 로드
  await dotenv.load(fileName: ".env");

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
    );
  }
}
