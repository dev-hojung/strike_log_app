import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/system_notice.dart';

/// 시스템 공지 모달.
///
/// 닫기 결과:
/// - `null` (배경 탭/뒤로) → 다음 실행 때 다시 노출
/// - `'close'` → 일반 닫기 (동일 동작 — 다음 실행 때 재노출)
/// - `'dismiss_today'` → 오늘 하루 안 보기 (dismissible == true일 때만 가능)
Future<String?> showSystemNoticeDialog(
  BuildContext context,
  SystemNotice notice,
) {
  return showDialog<String>(
    context: context,
    barrierDismissible: notice.dismissible,
    builder: (ctx) => _SystemNoticeDialog(notice: notice),
  );
}

class _SystemNoticeDialog extends StatelessWidget {
  final SystemNotice notice;
  const _SystemNoticeDialog({required this.notice});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priorityColor = _colorFor(notice.priority);
    final priorityIcon = _iconFor(notice.priority);

    return AlertDialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(priorityIcon, color: priorityColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice.title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: SingleChildScrollView(
          child: Text(
            notice.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      actions: [
        if (notice.dismissible)
          TextButton(
            onPressed: () => Navigator.of(context).pop('dismiss_today'),
            child: Text(
              '오늘 하루 안 보기',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () => Navigator.of(context).pop('close'),
          child: const Text('확인'),
        ),
      ],
    );
  }

  Color _colorFor(SystemNoticePriority p) {
    switch (p) {
      case SystemNoticePriority.critical:
        return Colors.redAccent;
      case SystemNoticePriority.warning:
        return Colors.orangeAccent;
      case SystemNoticePriority.info:
        return AppColors.primary;
    }
  }

  IconData _iconFor(SystemNoticePriority p) {
    switch (p) {
      case SystemNoticePriority.critical:
        return Symbols.error;
      case SystemNoticePriority.warning:
        return Symbols.warning;
      case SystemNoticePriority.info:
        return Symbols.campaign;
    }
  }
}
