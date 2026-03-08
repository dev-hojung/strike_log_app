import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

Future<String?> showLocationInputDialog(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '볼링장 입력',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '현재 플레이 중인 볼링장을 입력해주세요.\n(선택 사항)',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                hintText: '예: 강남역 볼링장',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''), // 건너뛰기
            child: Text(
              '건너뛰기',
              style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('시작하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}
