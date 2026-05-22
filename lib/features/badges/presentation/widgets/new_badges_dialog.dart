import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../pages/badge_list_page.dart';

/// 게임 저장 직후 신규 획득 배지를 알리는 모달.
///
/// [badges] 항목은 서버 응답의 `newly_earned_badges` 그대로 — 각 원소는
/// 최소 `key`, `name`, `description` 필드를 포함하는 Map.
/// "배지 보기"를 누르면 첫 번째 신규 배지를 강조해 [BadgeListPage]로 이동한다.
class NewBadgesDialog extends StatelessWidget {
  final List<Map<String, dynamic>> badges;

  const NewBadgesDialog({super.key, required this.badges});

  /// badges가 비어 있으면 다이얼로그를 띄우지 않고 즉시 반환.
  static Future<void> showIfAny(
    BuildContext context,
    List<Map<String, dynamic>> badges,
  ) {
    if (badges.isEmpty) return Future.value();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NewBadgesDialog(badges: badges),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final textPrimary =
        isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final highlightKey = badges.isNotEmpty ? badges.first['key']?.toString() : null;

    return Dialog(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Icon(
                Symbols.workspace_premium,
                color: Colors.amber,
                size: 40,
                fill: 1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badges.length == 1 ? '새 배지 획득!' : '새 배지 ${badges.length}개 획득!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '훌륭해요! 새로운 도전이 기록되었어요.',
              style: TextStyle(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            // 배지 목록 (최대 5개까지 표시, 그 이상은 +N more)
            ...badges.take(5).map((b) => _buildBadgeRow(b, isDark, textPrimary, textSecondary)),
            if (badges.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${badges.length - 5}개 더',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        '확인',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                BadgeListPage(highlightKey: highlightKey),
                          ),
                        );
                      },
                      icon: const Icon(Symbols.arrow_forward,
                          color: Colors.white, size: 18),
                      label: const Text(
                        '배지 보기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeRow(Map<String, dynamic> b, bool isDark,
      Color textPrimary, Color textSecondary) {
    final name = b['name']?.toString() ?? b['key']?.toString() ?? '';
    final desc = b['description']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Symbols.check,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                if (desc.isNotEmpty)
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
