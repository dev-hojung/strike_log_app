import 'package:flutter/material.dart';
import '../pages/inquiry_page.dart';

/// 클럽 무료 체험이 만료됐을 때 표시하는 다이얼로그.
///
/// 사용법:
/// ```dart
/// await TrialExpiredDialog.show(context);
/// ```
class TrialExpiredDialog extends StatelessWidget {
  const TrialExpiredDialog({super.key});

  /// 다이얼로그를 표시하는 static helper.
  /// context가 없는 경우(인터셉터 등)에는 appNavigatorKey.currentContext를 사용한다.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const TrialExpiredDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('클럽 무료 체험이 끝났어요'),
      content: const Text(
        '30일 동안 무료로 이용해보셨어요.\n계속 사용하시려면 관리자에게 문의해주세요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InquiryPage(initialCategory: 'club_trial'),
              ),
            );
          },
          child: const Text('문의하기'),
        ),
      ],
    );
  }
}
