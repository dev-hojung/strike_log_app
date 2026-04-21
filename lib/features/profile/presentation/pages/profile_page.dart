import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/services/fcm_service.dart';
import '../../../../core/services/user_profile_cache.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../group/presentation/pages/admin_creation_requests_page.dart';
import 'account_settings_page.dart';

/// 프로필 화면을 나타내는 페이지입니다.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    // 메모리 캐시에서 동기 즉시 로드 → 첫 build부터 값 표시
    _profile = UserProfileCache.cached;
    // 백그라운드에서 최신화
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
    } catch (_) {}
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (userId != null) {
      await FcmService.instance.clearTokenOnServer(userId);
    }
    await prefs.remove('user_id');
    await UserProfileCache.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    final nickname = _profile?['nickname'] ?? '';
    final email = _profile?['email'] ?? '';
    final profileImageUrl = _profile?['profile_image_url'];
    final createdAt = _profile?['created_at'] != null
        ? DateFormat('yyyy년 MM월 dd일').format(DateTime.parse(_profile!['created_at']))
        : '';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          '프로필',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 448),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileSection(
                    nickname, email, profileImageUrl, createdAt,
                    textColor, secondaryTextColor, surfaceColor,
                  ),
                  const SizedBox(height: 32),
                  _buildSettingsList(surfaceColor, textColor, secondaryTextColor, borderColor),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(
    String nickname, String email, String? profileImageUrl, String createdAt,
    Color textColor, Color secondaryTextColor, Color surfaceColor,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
                border: Border.all(color: surfaceColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? Image.network(profileImageUrl, fit: BoxFit.cover)
                    : Icon(Symbols.person, size: 48, color: Colors.grey[500]),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: surfaceColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Symbols.photo_camera, color: Colors.white, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          nickname,
          style: TextStyle(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: TextStyle(
            color: secondaryTextColor,
            fontSize: 14,
          ),
        ),
        if (createdAt.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            '가입일: $createdAt',
            style: TextStyle(
              color: secondaryTextColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSettingsList(
      Color surfaceColor, Color textColor, Color secondaryTextColor, Color borderColor) {
    final isAdmin = _profile?['is_platform_admin'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdmin) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '관리자 도구',
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: _buildSettingsTile(
              '클럽 생성 신청 관리',
              Symbols.admin_panel_settings,
              textColor,
              secondaryTextColor,
              borderColor,
              isLast: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCreationRequestsPage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildSettingsTile('계정 설정', Symbols.settings, textColor, secondaryTextColor, borderColor, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsPage())).then((_) => _fetchProfile());
              }),
              _buildSettingsTile('알림 설정', Symbols.notifications, textColor, secondaryTextColor, borderColor),
              _buildSettingsTile('앱 설정', Symbols.settings, textColor, secondaryTextColor, borderColor, isLast: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: _logout,
            style: TextButton.styleFrom(
              backgroundColor: surfaceColor,
              foregroundColor: Colors.red[500],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: borderColor),
              ),
              elevation: 0,
            ),
            icon: const Icon(Symbols.logout),
            label: const Text(
              '로그아웃',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
      String title, IconData icon, Color textColor, Color secondaryTextColor, Color borderColor,
      {bool isLast = false, VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.5))),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: secondaryTextColor),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Symbols.chevron_right, color: Colors.grey[400]),
        onTap: onTap ?? () {},
      ),
    );
  }
}
