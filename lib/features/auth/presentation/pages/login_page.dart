import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/main_container.dart';
import '../../../../core/services/api_client.dart';
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
        // 로그인 성공: 유저 정보를 받음 (추후 로컬 저장소 등에 저장 가능)
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
    return Scaffold(
      body: Stack(
        children: [
          // 배경 이미지 및 오버레이
          Positioned.fill(
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDGM-Jx4OQRaN-AEZazNBNz36V-HmiHAfy6iHFuCRIQbSMjPeLAwWVx-fvC9mvTGX9DOFtjZ8MhJtj1M88_KGpVgieBPxDr7OjeghijLtl6mZ8H1K9CVbnq_kIfan439IPhuUgkL3FjoU4aPhc7Tu9c_k_5Shg2fUmyIwGoykBp9ULWzxMVuRzW0op6qnef41IIBllWHquBJQp0wWO2A4uEDthlJv98CeC3ui3UrsnJqp1jqpb2672BOl3rpS7mNYOekJjlhVwQkRUS',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF101622).withOpacity(0.7),
                    const Color(0xFF101622).withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),

          // 메인 컨텐츠
          Center(
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
                          color: AppColors.primary.withOpacity(0.3),
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
                      color: AppColors.primary.withOpacity(0.9),
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
                              .withOpacity(0.5), // slate-800/50
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                          GestureDetector(
                            onTap: () {},
                            child: const Text(
                              '비밀번호 찾기',
                              style: TextStyle(
                                color: Color(0xFF94A3B8), // slate-400
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
                              .withOpacity(0.5), // slate-800/50
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
                                                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                elevation: 4,
                                                shadowColor: AppColors.primary.withOpacity(0.2),
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

                  // 소셜 로그인 구분선
                  Row(
                    children: [
                      Expanded(
                          child: Container(
                              height: 1,
                              color: const Color(0xFF334155).withOpacity(0.5))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '간편 로그인',
                          style: TextStyle(
                            color: Color(0xFF64748B), // slate-500
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Container(
                              height: 1,
                              color: const Color(0xFF334155).withOpacity(0.5))),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 소셜 로그인 버튼들
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        color: const Color(0xFFFEE500), // Kakao Yellow
                        iconPath:
                            '<svg viewBox="0 0 24 24" fill="#3A1D1D" xmlns="http://www.w3.org/2000/svg"><path d="M12 3C6.477 3 2 6.48 2 10.77C2 13.55 3.84 15.97 6.6 17.41L5.65 20.91C5.58 21.17 5.74 21.43 6.01 21.49C6.11 21.51 6.22 21.49 6.31 21.44L10.46 18.66C10.96 18.71 11.47 18.74 12 18.74C17.52 18.74 22 15.26 22 10.97C22 6.68 17.52 3.2 12 3.2V3Z"/></svg>',
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        color: const Color(0xFF03C75A), // Naver Green
                        iconPath:
                            '<svg viewBox="0 0 24 24" fill="white" xmlns="http://www.w3.org/2000/svg"><path d="M16.273 12.845L7.376 0H0V24H7.727V11.155L16.624 24H24V0H16.273V12.845Z"/></svg>',
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        color: Colors.white,
                        iconPath:
                            '<svg viewBox="0 0 24 24" fill="black" xmlns="http://www.w3.org/2000/svg"><path d="M17.05 20.28c-.96.001-1.85-.35-2.58-.35-.74 0-1.52.34-2.35.34-3.11 0-5.85-4.47-5.85-7.85 0-3.32 2.1-5.07 4.14-5.07.96 0 1.76.41 2.37.41.61 0 1.58-.45 2.68-.45 1.13 0 2.45.54 3.21 1.63-2.6 1.34-2.18 5.2.47 6.27-.63 1.64-2.19 5.07-2.1 5.07zM12.03 7.25c.01-2.42 2.02-4.35 4.46-4.24.12 2.51-2.14 4.58-4.46 4.24z"/></svg>',
                      ),
                    ],
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
        ],
      ),
    );
  }

  Widget _buildSocialButton({required Color color, required String iconPath}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: SvgPicture.string(iconPath),
          ),
        ),
      ),
    );
  }
}
