import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';

/// 비밀번호 변경 페이지
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentController.text.trim();
    final newPw = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      _showError('모든 필드를 입력해주세요.');
      return;
    }

    if (newPw != confirm) {
      _showError('새 비밀번호가 일치하지 않습니다.');
      return;
    }

    if (newPw.length < 8 || newPw.length > 16) {
      _showError('비밀번호는 8~16자여야 합니다.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        _showError('로그인 정보를 찾을 수 없습니다.');
        return;
      }

      await ApiClient().dio.post('/users/$userId/change-password', data: {
        'currentPassword': current,
        'newPassword': newPw,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비밀번호가 변경되었습니다.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String message = '비밀번호 변경에 실패했습니다.';
        if (e is DioException && e.response?.data != null) {
          message = e.response?.data['message'] ?? message;
        }
        _showError(message);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;
    final hintColor = isDark ? const Color(0xFF64748B) : Colors.grey;
    final inputBgColor = isDark ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[100]!;
    final inputBorderColor = isDark ? AppColors.primary.withValues(alpha: 0.2) : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '비밀번호 변경',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 비밀번호
                  _buildPasswordField(
                    label: '현재 비밀번호',
                    hint: '현재 비밀번호를 입력하세요',
                    controller: _currentController,
                    obscure: !_showCurrent,
                    onToggle: () => setState(() => _showCurrent = !_showCurrent),
                    textColor: textColor,
                    hintColor: hintColor,
                    inputBgColor: inputBgColor,
                    inputBorderColor: inputBorderColor,
                  ),
                  const SizedBox(height: 24),

                  // 새 비밀번호
                  _buildPasswordField(
                    label: '새 비밀번호',
                    hint: '새 비밀번호를 입력하세요',
                    controller: _newController,
                    obscure: !_showNew,
                    onToggle: () => setState(() => _showNew = !_showNew),
                    textColor: textColor,
                    hintColor: hintColor,
                    inputBgColor: inputBgColor,
                    inputBorderColor: inputBorderColor,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '8~16자의 영문, 숫자, 특수문자를 사용하세요.',
                      style: TextStyle(color: secondaryColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 새 비밀번호 확인
                  _buildPasswordField(
                    label: '새 비밀번호 확인',
                    hint: '새 비밀번호를 다시 입력하세요',
                    controller: _confirmController,
                    obscure: !_showConfirm,
                    onToggle: () => setState(() => _showConfirm = !_showConfirm),
                    textColor: textColor,
                    hintColor: hintColor,
                    inputBgColor: inputBgColor,
                    inputBorderColor: inputBorderColor,
                  ),
                ],
              ),
            ),
          ),

          // 하단 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('비밀번호 변경 완료', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required Color textColor,
    required Color hintColor,
    required Color inputBgColor,
    required Color inputBorderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: textColor, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: hintColor),
            filled: true,
            fillColor: inputBgColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Symbols.visibility : Symbols.visibility_off,
                color: hintColor,
                size: 22,
              ),
              onPressed: onToggle,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: inputBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: inputBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }
}
