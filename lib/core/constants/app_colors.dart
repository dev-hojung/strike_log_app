import 'package:flutter/material.dart';

/// 앱 전체에서 사용되는 색상 상수를 정의하는 클래스입니다.
class AppColors {
  /// 앱의 주요 브랜드 색상 (파란색 계열)
  static const Color primary = Color(0xFF135BEC);

  /// 라이트 모드 배경 색상
  static const Color backgroundLight = Color(0xFFF6F6F8);

  /// 라이트 모드 표면(카드, 다이얼로그 등) 색상
  static const Color surfaceLight = Colors.white;

  /// 다크 모드 배경 색상
  static const Color backgroundDark = Color(0xFF101622);

  /// 다크 모드 표면(카드, 다이얼로그 등) 색상
  static const Color surfaceDark = Color(0xFF1E2532);

  /// 다크 모드 카드 배경 색상 (surfaceDark와 동일)
  static const Color cardDark = Color(0xFF1E2532);

  /// 라이트 모드 주요 텍스트 색상
  static const Color textPrimaryLight = Color(0xFF0F172A);

  /// 라이트 모드 보조 텍스트 색상
  static const Color textSecondaryLight = Color(0xFF64748B);

  /// 다크 모드 주요 텍스트 색상
  static const Color textPrimaryDark = Colors.white;

  /// 다크 모드 보조 텍스트 색상
  static const Color textSecondaryDark = Color(0xFF94A3B8);
}
