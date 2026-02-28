import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:dio/dio.dart';
import '../../../../core/services/api_client.dart';
import 'login_page.dart';

/// 앱의 회원가입 화면을 담당하는 페이지입니다.
///
/// 주요 기능:
/// - 이메일 인증 (OTP 발송 및 검증)
/// - 설정할 비밀번호, 닉네임 입력 폼
/// - 간편 회원가입 (소셜 로그인)
/// - 기존 계정으로 돌아가는 로그인 링크
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  // 상태 변수
  bool _isCodeSent = false;
  bool _isEmailVerified = false;
  bool _isLoading = false;

  // 타이머 관련 변수
  Timer? _timer;
  int _remainingTime = 180; // 3분

  // 비밀번호 보이기/숨기기
  bool _isPasswordVisible = false;
  bool _isPasswordConfirmVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  /// 타이머 시작
  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remainingTime = 180;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  /// 타이머 문자열 반환 (분:초)
  String get _formattedTime {
    int minutes = _remainingTime ~/ 60;
    int seconds = _remainingTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 이메일 검증 및 OTP 전송
  ///
  /// strike_log_api 연동하여 이메일 OTP 전송
  Future<void> _sendOtpCode() async {
    String email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 이메일 주소를 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.post('/email/send-otp', data: {'email': email});

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _isCodeSent = true;
          _isLoading = false;
        });
        _startTimer();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이메일로 인증번호가 발송되었습니다.')),
          );
        }
      } else {
        throw Exception('서버 응답 오류');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('발송 실패: $e')),
        );
      }
    }
  }

  /// 입력된 OTP 코드 확인
  ///
  /// strike_log_api 연동하여 OTP 검증
  Future<void> _verifyOtp() async {
    String email = _emailController.text.trim();
    String otpCode = _otpController.text.trim();

    if (otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6자리 인증번호를 모두 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.post('/email/verify-otp', data: {
        'email': email,
        'code': otpCode,
      });

      if (response.statusCode == 200) {
        _timer?.cancel();
        setState(() {
          _isEmailVerified = true;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이메일 인증이 완료되었습니다. 나머지 정보를 입력해주세요.')),
          );
        }
      } else {
        throw Exception('서버 응답 오류');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증번호가 일치하지 않거나 만료되었습니다.')),
        );
      }
    }
  }

  /// 최종 회원가입 처리
  ///
  /// strike_log_api 연동하여 회원가입 진행
  Future<void> _signUp() async {
    if (!_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 이메일 인증을 완료해주세요.')),
      );
      return;
    }

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String passwordConfirm = _passwordConfirmController.text.trim();
    String nickname = _nicknameController.text.trim();

    if (password.isEmpty || password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호는 8자 이상 입력해주세요.')),
      );
      return;
    }

    if (password != passwordConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
      );
      return;
    }

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final dio = ApiClient().dio;
      final response = await dio.post('/users/signup', data: {
        'email': email,
        'password': password,
        'nickname': nickname,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입이 완료되었습니다!')),
          );
          Navigator.pop(context); // 로그인 페이지로 이동
        }
      } else {
        throw Exception('회원가입 실패: 서버 응답 오류');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 배경 테마 색상 강제 지정 (스크린샷 기반 다크 테마)
    const backgroundColor = Color(0xFF141923);
    const textColor = Colors.white;
    const subTextColor = Color(0xFF8F939A);
    const inputBgColor = Color(0xFF1F242F);
    const borderColor = Color(0xFF333842);
    const primaryColor = Color(0xFF1A5CFF); // 파란색

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 상단 앱바
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Symbols.arrow_back),
                      color: textColor,
                    ),
                    Expanded(
                      child: Text(
                        '회원가입',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // 로고 및 타이틀
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 32),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Symbols.flag, // 임시 로고 아이콘
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'STRIKE LOG',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '볼링의 즐거움을 기록하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: subTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 폼 입력 영역
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이메일
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '이메일',
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            controller: _emailController,
                            hint: 'example@email.com',
                            inputType: TextInputType.emailAddress,
                            inputBgColor: inputBgColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            hintColor: subTextColor,
                            enabled: !_isEmailVerified,
                          ),
                        ),
                        if (!_isEmailVerified) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtpCode,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF152243),
                                foregroundColor: const Color(0xFF3B72FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isCodeSent ? '재전송' : '인증번호 전송',
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 12),
                          const Icon(
                            Symbols.check_circle,
                            color: Color(0xFF03C75A), // 네이버 초록색과 유사한 성공 컬러
                            size: 28,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 인증번호 (인증 성공 전/후 로직 유지, UI 스타일링)
                    if (!_isEmailVerified && _isCodeSent)
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpController,
                                style: const TextStyle(color: textColor),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: InputDecoration(
                                  hintText: '인증번호 6자리',
                                  hintStyle: TextStyle(color: subTextColor),
                                  counterText: '',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Row(
                                children: [
                                  Text(
                                    _formattedTime,
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  GestureDetector(
                                    onTap: _isLoading ? null : _verifyOtp,
                                    child: const Text(
                                      '확인',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!_isEmailVerified && _isCodeSent)
                      const SizedBox(height: 16),

                    // 비밀번호
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '비밀번호',
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    ),
                    _buildInputField(
                      controller: _passwordController,
                      hint: '8자 이상 입력해주세요',
                      isPassword: true,
                      isVisible: _isPasswordVisible,
                      onVisibilityToggle: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                      inputBgColor: inputBgColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      hintColor: subTextColor,
                    ),
                    const SizedBox(height: 16),

                    // 비밀번호 확인
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '비밀번호 확인',
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    ),
                    _buildInputField(
                      controller: _passwordConfirmController,
                      hint: '비밀번호를 한 번 더 입력해주세요',
                      isPassword: true,
                      isVisible: _isPasswordConfirmVisible,
                      onVisibilityToggle: () {
                        setState(() {
                          _isPasswordConfirmVisible =
                              !_isPasswordConfirmVisible;
                        });
                      },
                      inputBgColor: inputBgColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      hintColor: subTextColor,
                    ),
                    const SizedBox(height: 16),

                    // 닉네임
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        '닉네임',
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                    ),
                    _buildInputField(
                      controller: _nicknameController,
                      hint: '닉네임을 입력해주세요',
                      inputBgColor: inputBgColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      hintColor: subTextColor,
                    ),
                    const SizedBox(height: 32),

                    // 가입하기 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed:
                            (_isEmailVerified && !_isLoading) ? _signUp : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              primaryColor.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                '가입하기',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // 간편 회원가입 로고 라인
              Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 40, right: 16),
                      height: 1,
                      color: borderColor,
                    ),
                  ),
                  Text(
                    '간편 회원가입',
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(left: 16, right: 40),
                      height: 1,
                      color: borderColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 소셜 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialIcon(
                    color: const Color(0xFFFEE500),
                    child: SvgPicture.string(
                      '<svg viewBox="0 0 24 24" fill="#391B1B"><path d="M12 3C7.58 3 4 5.79 4 9.24c0 1.96 1.15 3.73 3 4.94l-.77 2.85c-.06.22.19.4.39.29l3.35-2.23c.66.1 1.34.15 2.03.15 4.42 0 8-2.79 8-6.24S16.42 3 12 3z"></path></svg>',
                    ),
                  ),
                  const SizedBox(width: 20),
                  _buildSocialIcon(
                    color: const Color(0xFF03C75A),
                    child: const Text('N',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 20),
                  _buildSocialIcon(
                    color: Colors.white,
                    child:
                        const Icon(Icons.apple, color: Colors.black, size: 28),
                  ),
                ],
              ),

              const SizedBox(height: 48),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '이미 계정이 있으신가요?',
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '로그인',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  /// 스크린샷 룩앤필에 맞춘 범용 텍스트 필드 빌더
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required Color inputBgColor,
    required Color borderColor,
    required Color textColor,
    required Color hintColor,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
    TextInputType? inputType,
    bool enabled = true,
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        keyboardType: inputType,
        enabled: enabled,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: hintColor),
          filled: true,
          fillColor: inputBgColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A5CFF), width: 1.5),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    isVisible ? Symbols.visibility : Symbols.visibility_off,
                    color: hintColor,
                  ),
                  onPressed: onVisibilityToggle,
                )
              : null,
        ),
      ),
    );
  }

  /// 스크린샷 룩앤필에 맞춘 소셜 버튼
  Widget _buildSocialIcon({required Color color, required Widget child}) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(width: 24, height: 24, child: child),
      ),
    );
  }
}
