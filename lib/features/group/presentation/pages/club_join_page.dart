import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';

/// 클럽 상세 정보 확인 및 가입 신청 페이지입니다.
class ClubJoinPage extends StatefulWidget {
  final int clubId;
  final String clubName;
  final String clubDescription;
  final String? coverImageUrl;
  final int memberCount;

  const ClubJoinPage({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.clubDescription,
    this.coverImageUrl,
    required this.memberCount,
  });

  @override
  State<ClubJoinPage> createState() => _ClubJoinPageState();
}

class _ClubJoinPageState extends State<ClubJoinPage> {
  final _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _joinClub() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        _showError('로그인 정보를 찾을 수 없습니다.');
        return;
      }

      // 가입 신청 생성. 클럽장이 승인해야 실제 가입이 완료됩니다.
      // 기대 엔드포인트: POST /groups/:clubId/join-requests
      //   body: { user_id, message }
      //   201 Created → 신청 생성 / 409 Conflict → 이미 신청/가입 상태
      await ApiClient().dio.post(
        '/groups/${widget.clubId}/join-requests',
        data: {
          'user_id': userId,
          'message': _messageController.text.trim(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('가입 신청이 전송되었습니다. 클럽장의 승인을 기다려주세요.'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String message = '가입 신청에 실패했습니다.';
        if (e is DioException) {
          if (e.response?.statusCode == 409) {
            message = '이미 신청했거나 가입된 클럽입니다.';
          } else if (e.response?.data != null) {
            final serverMessage = e.response?.data is Map
                ? e.response?.data['message']
                : null;
            if (serverMessage is String && serverMessage.isNotEmpty) {
              message = serverMessage;
            }
          }
        }
        _showError(message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E293B) : Colors.black12;

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
          '클럽 가입 신청',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  // 클럽 프로필 섹션
                  _buildClubProfile(isDark, textColor, secondaryColor),
                  const SizedBox(height: 24),
                  // 클럽 정보 섹션
                  _buildClubInfo(isDark, textColor, secondaryColor, surfaceColor, borderColor),
                  const SizedBox(height: 24),
                  // 가입 인사 섹션
                  _buildMessageSection(isDark, textColor, secondaryColor, surfaceColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // 하단 가입 신청 버튼
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinClub,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          '가입 신청하기',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubProfile(bool isDark, Color textColor, Color secondaryColor) {
    return Center(
      child: Column(
        children: [
          // 클럽 이미지
          Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 4,
              ),
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: isDark ? const Color(0xFF32343E) : Colors.grey[200],
              backgroundImage: widget.coverImageUrl != null
                  ? NetworkImage(widget.coverImageUrl!)
                  : null,
              child: widget.coverImageUrl == null
                  ? Icon(Symbols.groups, size: 40, color: AppColors.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          // 클럽 이름
          Text(
            widget.clubName,
            style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // 멤버 수 뱃지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.grey[100],
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Symbols.person, color: secondaryColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  '멤버 ${widget.memberCount}명',
                  style: TextStyle(color: secondaryColor, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubInfo(
    bool isDark,
    Color textColor,
    Color secondaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? surfaceColor.withValues(alpha: 0.4) : surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.info, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '클럽 정보',
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.clubDescription.isNotEmpty ? widget.clubDescription : '클럽 설명이 없습니다.',
            style: TextStyle(
              color: secondaryColor,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageSection(bool isDark, Color textColor, Color secondaryColor, Color surfaceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '가입 인사',
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            TextField(
              controller: _messageController,
              maxLines: 5,
              maxLength: 200,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: '클럽장에게 보낼 메시지를 작성해주세요\n(예: 최근 에버리지, 볼링 경력 등)',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : Colors.grey, fontSize: 14),
                filled: true,
                fillColor: surfaceColor,
                counterStyle: TextStyle(color: secondaryColor, fontSize: 10),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
