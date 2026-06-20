import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';

/// 이메일 OTP 기반 비밀번호 재설정 페이지.
///
/// 단계:
/// 1. 이메일 입력 → `/email/send-otp` → 6자리 OTP 발송
/// 2. OTP 입력 → `/email/verify-otp` → 통과 시 새 비밀번호 단계로 진입
/// 3. 새 비밀번호 + 확인 → `/users/forgot-password/reset` → 갱신
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtl = TextEditingController();
  final _otpCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  final _pwConfirmCtl = TextEditingController();

  bool _codeSent = false;
  bool _otpVerified = false;
  bool _loading = false;
  int _remainingSec = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtl.dispose();
    _otpCtl.dispose();
    _pwCtl.dispose();
    _pwConfirmCtl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSec = 300);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remainingSec <= 1) {
        t.cancel();
        setState(() => _remainingSec = 0);
      } else {
        setState(() => _remainingSec--);
      }
    });
  }

  String _formatTimer() {
    final m = (_remainingSec ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendOtp() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('올바른 이메일을 입력해주세요.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient().dio.post('/email/send-otp', data: {
        'email': email,
        'purpose': 'reset',
      });
      setState(() => _codeSent = true);
      _startTimer();
      _toast('이메일로 인증번호가 발송되었습니다.');
    } catch (e) {
      _toast(_dioMessage(e, '인증번호 발송 실패'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailCtl.text.trim();
    final code = _otpCtl.text.trim();
    if (code.length < 6) {
      _toast('6자리 인증번호를 입력해주세요.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiClient().dio.post('/email/verify-otp', data: {
        'email': email,
        'code': code,
      });
      _timer?.cancel();
      setState(() => _otpVerified = true);
      _toast('인증이 완료되었습니다. 새 비밀번호를 설정해주세요.');
    } catch (e) {
      _toast(_dioMessage(e, '인증번호가 일치하지 않거나 만료되었습니다.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtl.text.trim();
    final code = _otpCtl.text.trim();
    final pw = _pwCtl.text;
    final pwConfirm = _pwConfirmCtl.text;

    if (pw.length < 8 || pw.length > 16) {
      _toast('비밀번호는 8~16자여야 합니다.');
      return;
    }
    if (pw != pwConfirm) {
      _toast('비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiClient().dio.post('/users/forgot-password/reset', data: {
        'email': email,
        'code': code,
        'newPassword': pw,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호가 변경되었습니다. 로그인해주세요.')),
      );
      Navigator.pop(context);
    } catch (e) {
      _toast(_dioMessage(e, '비밀번호 변경에 실패했습니다.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dioMessage(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('비밀번호 찾기'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepHeader(isDark),
              const SizedBox(height: 20),
              _emailField(isDark),
              const SizedBox(height: 12),
              _sendOtpButton(),
              if (_codeSent) ...[
                const SizedBox(height: 24),
                _otpField(isDark),
                const SizedBox(height: 12),
                _verifyOtpButton(),
              ],
              if (_otpVerified) ...[
                const SizedBox(height: 28),
                _newPasswordFields(isDark),
                const SizedBox(height: 16),
                _resetButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepHeader(bool isDark) {
    String label;
    if (_otpVerified) {
      label = '3단계: 새 비밀번호를 설정해주세요.';
    } else if (_codeSent) {
      label = '2단계: 이메일로 받은 인증번호를 입력해주세요.';
    } else {
      label = '1단계: 가입한 이메일을 입력해주세요.';
    }
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        color:
            isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _emailField(bool isDark) {
    return TextField(
      controller: _emailCtl,
      enabled: !_otpVerified,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: '이메일',
        prefixIcon: Icon(Symbols.mail),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _sendOtpButton() {
    final isResend = _codeSent;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: _loading || _otpVerified ? null : _sendOtp,
        child: Text(isResend ? '인증번호 재발송' : '인증번호 받기'),
      ),
    );
  }

  Widget _otpField(bool isDark) {
    return TextField(
      controller: _otpCtl,
      enabled: !_otpVerified,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: '인증번호 (6자리)',
        prefixIcon: const Icon(Symbols.lock_clock),
        suffixText: _remainingSec > 0 ? _formatTimer() : null,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _verifyOtpButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: _loading || _otpVerified ? null : _verifyOtp,
        child: Text(_otpVerified ? '인증 완료' : '인증번호 확인'),
      ),
    );
  }

  Widget _newPasswordFields(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _pwCtl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '새 비밀번호 (8~16자)',
            prefixIcon: Icon(Symbols.password),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pwConfirmCtl,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '비밀번호 확인',
            prefixIcon: Icon(Symbols.password),
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _resetButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        onPressed: _loading ? null : _resetPassword,
        child: const Text('비밀번호 변경'),
      ),
    );
  }
}
