import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/user_profile_cache.dart';

/// 닉네임 변경 페이지
class EditNicknamePage extends StatefulWidget {
  final String currentNickname;

  const EditNicknamePage({super.key, required this.currentNickname});

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  late final TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newNickname = _controller.text.trim();
    if (newNickname.isEmpty || newNickname == widget.currentNickname) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      await ApiClient().dio.patch('/users/$userId', data: {'nickname': newNickname});
      await UserProfileCache.refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임이 변경되었습니다.')),
        );
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('닉네임 변경에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;
    final hintColor = isDark ? const Color(0xFF64748B) : Colors.grey;
    final inputBgColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.grey[100]!;
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
          '닉네임 변경',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 닉네임 라벨
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '닉네임',
                style: TextStyle(color: secondaryColor, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            // 닉네임 입력 필드
            TextField(
              controller: _controller,
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: inputBgColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
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
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5), width: 1),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 안내 텍스트
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '다른 사용자들에게 보여지는 이름입니다.',
                style: TextStyle(color: hintColor, fontSize: 12),
              ),
            ),

            const SizedBox(height: 40),

            // 변경하기 버튼
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('변경하기', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 56),

            // 안내 박스
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
              ),
              child: Text(
                '닉네임은 30일에 한 번만 변경할 수 있습니다. 비속어나 부적절한 표현은 제재의 대상이 될 수 있습니다.',
                style: TextStyle(color: secondaryColor, fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
