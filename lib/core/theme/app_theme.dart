import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// 앱 전체의 테마 설정을 관리하는 클래스입니다.
///
/// 라이트 모드와 다크 모드에 대한 [ThemeData]를 제공합니다.
class AppTheme {
  /// 라이트 모드 테마를 반환합니다.
  ///
  /// - Material 3 디자인 사용
  /// - [AppColors.backgroundLight] 배경색 적용
  /// - [GoogleFonts.lexendTextTheme] 폰트 적용
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        surface: AppColors.surfaceLight,
      ),
      textTheme: GoogleFonts.lexendTextTheme().apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
    );
  }

  /// 다크 모드 테마를 반환합니다.
  ///
  /// - Material 3 디자인 사용
  /// - [AppColors.backgroundDark] 배경색 적용
  /// - [GoogleFonts.lexendTextTheme] 폰트 적용
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surfaceDark,
        onSurface: Colors.white,
      ),
      textTheme: GoogleFonts.lexendTextTheme().apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
    );
  }
}
