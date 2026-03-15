import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import 'frame_entry_page.dart';
import 'game_room_page.dart';
import '../widgets/location_input_dialog.dart';

/// 게임 모드 선택 페이지
///
/// - 개인 게임: 혼자 점수 기록
/// - 클럽 게임: 소켓으로 방 생성, 여러 유저가 참가하여 점수 입력
class GameModePage extends StatelessWidget {
  const GameModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '새 게임',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16, left: 24, right: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '게임 모드를 선택하세요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '혼자 기록하거나, 클럽 멤버들과 함께 플레이하세요.',
              style: TextStyle(
                fontSize: 14,
                color: subTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // 개인 게임
            _buildModeCard(
              context,
              icon: Symbols.person,
              title: '개인 게임',
              description: '혼자서 게임 점수를 기록합니다.',
              iconBgColor: AppColors.primary.withValues(alpha: 0.1),
              iconColor: AppColors.primary,
              isDark: isDark,
              onTap: () async {
                final location = await showLocationInputDialog(context);
                if (location != null && context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FrameEntryPage(isClubGame: false, location: location),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            // 클럽 게임
            _buildModeCard(
              context,
              icon: Symbols.groups,
              title: '클럽 게임',
              description: '방을 만들어 클럽 멤버들과 함께 점수를 기록합니다.',
              iconBgColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              iconColor: const Color(0xFF4CAF50),
              isDark: isDark,
              onTap: () => _startClubGame(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startClubGame(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const GameRoomPage(),
        ),
      );
    }
  }

  Widget _buildModeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color iconBgColor,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: subTextColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Symbols.chevron_right, color: subTextColor, size: 20),
          ],
        ),
      ),
    );
  }
}
