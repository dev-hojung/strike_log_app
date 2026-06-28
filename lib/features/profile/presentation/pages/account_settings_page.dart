import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/app_logger.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/session_manager.dart';
import '../../../../core/services/user_profile_cache.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../inquiry/presentation/pages/inquiry_page.dart';
import '../../../legal/presentation/pages/privacy_policy_page.dart';
import '../../../legal/presentation/pages/terms_of_service_page.dart';
import 'edit_nickname_page.dart';
import 'change_password_page.dart';

/// 계정 설정 페이지
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _profile = UserProfileCache.cached;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) return;

      final response = await ApiClient().dio.get('/users/$userId');
      final data = response.data;
      if (data is Map) {
        final profile = Map<String, dynamic>.from(data);
        await UserProfileCache.save(profile);
        if (mounted) {
          setState(() => _profile = profile);
        }
      }
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'accountSettings.fetch');
    }
  }

  /// 회원 탈퇴 확인 다이얼로그. 사용자가 명확히 동의해야 실제 처리로 진행.
  Future<void> _confirmDeleteAccount() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: const Text('회원 탈퇴하시겠어요?'),
        content: const Text(
          '탈퇴 시 다음 데이터가 영구 삭제되며 복구할 수 없습니다.\n\n'
          '• 게임 및 시리즈 기록\n'
          '• 클럽 멤버십 및 신청 내역\n'
          '• 획득한 배지와 출석 기록\n'
          '• 알림 및 푸시 토큰\n\n'
          '정말 진행하시겠어요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _performDeleteAccount();
  }

  /// 실제 탈퇴 처리. DELETE /users/me 호출 후 세션 정리 + 로그인 화면으로 복귀.
  Future<void> _performDeleteAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // 로그아웃과 동일하게 FCM 토큰을 서버에서 먼저 제거.
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        await FcmService.instance.clearTokenOnServer(userId);
      }

      await ApiClient().dio.delete('/users/me');

      await SessionManager.clearAll();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
      );
    } catch (e, st) {
      AppLogger.captureError(e,
          stackTrace: st, context: 'accountSettings.delete');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('회원 탈퇴에 실패했어요. 잠시 후 다시 시도해주세요.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : Colors.grey[200]!;
    final textColor = isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondaryLight;

    final nickname = _profile?['nickname'] ?? '';
    final email = _profile?['email'] ?? '';
    final profileImageUrl = _profile?['profile_image_url'];

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
          '계정 설정',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프로필 섹션
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        // 프로필 이미지
                        Stack(
                          children: [
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[300],
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  width: 4,
                                ),
                              ),
                              child: ClipOval(
                                child: AvatarImage(
                                  url: profileImageUrl?.toString(),
                                  fallback: Icon(Symbols.person,
                                      size: 64, color: Colors.grey[500]),
                                ),
                              ),
                            ),
                            // 프로필 사진 변경은 프로필 페이지 아바타에서 처리한다.
                            // (여기 카메라 배지는 동작 핸들러가 없어 제거 — 무응답 버튼 방지)
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          nickname,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 내 정보 섹션
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          '내 정보',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                              label: '닉네임',
                              value: nickname,
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              borderColor: borderColor,
                              showChevron: true,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => EditNicknamePage(currentNickname: nickname)),
                                );
                                if (result == true) _fetchProfile();
                              },
                            ),
                            _buildInfoRow(
                              label: '이메일',
                              value: email,
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              borderColor: borderColor,
                              isLast: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 보안 섹션
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          '보안',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: _buildActionRow(
                          icon: Symbols.lock,
                          label: '비밀번호 변경',
                          textColor: textColor,
                          secondaryColor: secondaryColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          '약관 및 정책',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            _buildActionRow(
                              icon: Symbols.gavel,
                              label: '이용약관',
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TermsOfServicePage(),
                                ),
                              ),
                            ),
                            Divider(height: 1, color: borderColor),
                            _buildActionRow(
                              icon: Symbols.shield_person,
                              label: '개인정보처리방침',
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyPage(),
                                ),
                              ),
                            ),
                            Divider(height: 1, color: borderColor),
                            _buildActionRow(
                              icon: Symbols.support_agent,
                              label: '관리자 문의',
                              textColor: textColor,
                              secondaryColor: secondaryColor,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const InquiryPage(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          '계정 관리',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: _buildActionRow(
                          icon: Symbols.delete_forever,
                          label: '회원 탈퇴',
                          textColor: Colors.redAccent,
                          secondaryColor: Colors.redAccent,
                          onTap: _confirmDeleteAccount,
                        ),
                      ),

                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required Color textColor,
    required Color secondaryColor,
    required Color borderColor,
    bool showChevron = false,
    bool isLast = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: secondaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 8),
                  Icon(Symbols.chevron_right, color: secondaryColor, size: 20),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow({
    required IconData icon,
    required String label,
    required Color textColor,
    required Color secondaryColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: secondaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Icon(Symbols.chevron_right, color: secondaryColor, size: 20),
          ],
        ),
      ),
    );
  }

}
