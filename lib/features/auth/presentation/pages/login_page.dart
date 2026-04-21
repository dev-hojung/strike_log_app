import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/main_container.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/user_profile_cache.dart';
import 'signup_page.dart';

/// 앱의 로그인 화면을 담당하는 페이지입니다.
///
/// 주요 기능:
/// - 이메일 및 비밀번호 입력 폼
/// - 소셜 로그인 (카카오, 네이버, 애플) 버튼
/// - 배경 이미지 및 오버레이 디자인
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 로그인 직후 프로필을 가져와 로컬 캐시에 저장.
  /// 네트워크 실패해도 로그인 흐름을 방해하지 않도록 조용히 흡수.
  Future<void> _prefetchProfile(String userId) async {
    try {
      final res = await ApiClient().dio.get('/users/$userId');
      final data = res.data;
      if (data is Map) {
        await UserProfileCache.save(Map<String, dynamic>.from(data));
      }
    } catch (e, st) {
      // 로그인 흐름은 막지 않지만 실패는 관측 가능하게.
      AppLogger.captureError(e, stackTrace: st, context: 'login.prefetchProfile');
    }
  }

  /// 이메일/비밀번호 로그인 API 호출
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.post('/users/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 로그인 성공: 유저 정보를 받음
        final userId = response.data['id'];
        final nickname = response.data['nickname'];

        if (userId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', userId.toString());
          if (nickname != null) {
            await prefs.setString('nickname', nickname.toString());
          }
          // FCM 토큰 서버 등록 (실패해도 로그인 흐름은 계속)
          unawaited(FcmService.instance.syncTokenToServer(userId.toString()));
          // 프로필 프리페치 — is_platform_admin 포함. 첫 프로필 탭 진입 시 즉시 렌더.
          unawaited(_prefetchProfile(userId.toString()));
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainContainer()),
          );
        }
      } else {
        throw Exception('서버 응답 오류');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = '로그인에 실패했습니다. 이메일 또는 비밀번호를 확인해주세요.';
        if (e is DioException && e.response?.data != null) {
           errorMessage = e.response?.data['message'] ?? errorMessage;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("=== _LoginPageState build ===");
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const SizedBox(height: 48),

                  // 로고 섹션
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Symbols.sports_score,
                      color: Colors.white,
                      size: 48,
                      fill: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'STRIKE LOG',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    '볼링의 즐거움을 기록하세요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // 로그인 폼
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          '이메일',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1), // slate-300
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                                          TextField(
                                            controller: _emailController,
                                            style: const TextStyle(color: Colors.white),                        decoration: InputDecoration(
                          hintText: 'email@example.com',
                          hintStyle: const TextStyle(
                              color: Color(0xFF64748B)), // slate-500
                          filled: true,
                          fillColor: const Color(0xFF1E293B)
                              .withValues(alpha: 0.5), // slate-800/50
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)), // slate-700
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)), // slate-700
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          '비밀번호',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1), // slate-300
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                                          TextField(
                                            controller: _passwordController,
                                            obscureText: true,                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: const TextStyle(
                              color: Color(0xFF64748B)), // slate-500
                          filled: true,
                          fillColor: const Color(0xFF1E293B)
                              .withValues(alpha: 0.5), // slate-800/50
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)), // slate-700
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF334155)), // slate-700
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                          suffixIcon: const Icon(Symbols.visibility,
                              color: Color(0xFF64748B)),
                        ),
                      ),
                      const SizedBox(height: 24),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 56,
                                            child: ElevatedButton(
                                              onPressed: _isLoading ? null : _login,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primary,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 4,
                                                shadowColor: AppColors.primary.withValues(alpha: 0.2),
                                              ),
                                              child: _isLoading 
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                    )
                                                  : const Text(
                                                      '로그인',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                            ),
                                          ),                    ],
                  ),

                  const SizedBox(height: 32),

                  // 회원가입 링크
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '계정이 없으신가요?',
                        style:
                            TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignupPage()),
                          ).then((_) {
                            // 회원가입 페이지에서 돌아올 때 스크롤 상단으로 초기화
                            if (mounted && _scrollController.hasClients) {
                              _scrollController.animateTo(
                                0.0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                        },
                        child: const Text(
                          '회원가입',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80), // 하단 여백
                ],
              ),
            ),
          ),
      ),
    );
  }

}
