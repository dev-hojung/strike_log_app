import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../data/services/groups_api_service.dart';

/// 클럽 멤버 관리 페이지.
///
/// 표시:
/// - 멤버 리스트 (아바타·닉네임·역할 배지·평균 점수)
/// - 본인은 "나" 표시
///
/// 액션:
/// - 본인이 ADMIN이면: 다른 MEMBER 옆 "운영자 위임" 버튼
/// - 우상단 ⋮ → "클럽 탈퇴"
///
/// 탈퇴 정책:
/// - 일반 케이스: 즉시 탈퇴 후 pop
/// - 유일 멤버: 백엔드가 클럽 자체 삭제 → pop + "클럽이 사라졌어요"
/// - 유일 ADMIN + 다른 멤버: 409 → 권한 위임 안내 다이얼로그
class ClubMembersPage extends StatefulWidget {
  const ClubMembersPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final int groupId;
  final String groupName;

  @override
  State<ClubMembersPage> createState() => _ClubMembersPageState();
}

class _ClubMembersPageState extends State<ClubMembersPage> {
  final GroupsApiService _api = GroupsApiService();

  List<Map<String, dynamic>> _members = const [];
  String? _myUserId;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getString('user_id');
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('멤버 목록을 불러오지 못했습니다.')),
      );
    }
  }

  bool get _amAdmin {
    if (_myUserId == null) return false;
    final me = _members.firstWhere(
      (m) => (m['user']?['id']?.toString() ?? '') == _myUserId,
      orElse: () => const {},
    );
    return (me['role']?.toString() ?? '') == 'ADMIN';
  }

  Future<void> _confirmPromote(Map<String, dynamic> member) async {
    final nickname = member['user']?['nickname']?.toString() ?? '멤버';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('운영자로 위임할까요?'),
        content: Text(
          '$nickname 님을 클럽 운영자로 위임합니다.\n'
          '운영자는 가입 신청 승인·반려, 다른 멤버 위임을 할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('위임하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _doPromote(member);
  }

  Future<void> _doPromote(Map<String, dynamic> member) async {
    final targetId = member['user']?['id']?.toString();
    if (targetId == null) return;

    setState(() => _busy = true);
    try {
      await _api.promoteMember(groupId: widget.groupId, targetUserId: targetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member['user']?['nickname'] ?? '멤버'} 님을 운영자로 위임했어요.')),
      );
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '위임에 실패했습니다.')
          : '위임에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmKick(Map<String, dynamic> member) async {
    final nickname = member['user']?['nickname']?.toString() ?? '멤버';
    final targetId = member['user']?['id']?.toString();
    if (targetId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('회원을 추방할까요?'),
        content: Text(
          '$nickname 님을 클럽에서 추방합니다.\n'
          '추방된 멤버는 다시 가입 신청을 해야 클럽에 참여할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('추방하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await _api.kickMember(groupId: widget.groupId, targetUserId: targetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$nickname 님을 추방했습니다.')),
      );
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '추방에 실패했습니다.')
          : '추방에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('클럽에서 탈퇴할까요?'),
        content: Text(
          "'${widget.groupName}'에서 나갑니다.\n"
          '그동안의 게임 기록은 본인 계정에 그대로 남아요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('탈퇴하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _doLeave();
  }

  Future<void> _doLeave() async {
    setState(() => _busy = true);
    try {
      final res = await _api.leaveGroup(widget.groupId);
      if (!mounted) return;
      final groupDeleted = res['group_deleted'] == true;
      Navigator.pop(context, {
        'left': true,
        'group_deleted': groupDeleted,
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '탈퇴에 실패했습니다.')
          : '탈퇴에 실패했습니다.';

      if (status == 409) {
        // 유일 ADMIN + 다른 멤버 존재 → 권한 위임 안내
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('운영자 권한을 먼저 위임해주세요'),
            content: Text(
              '$msg\n\n'
              '아래 멤버 목록에서 누군가를 운영자로 위임하면 탈퇴할 수 있어요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('멤버 관리'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Symbols.more_vert),
            onSelected: (v) {
              if (v == 'leave') _confirmLeave();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Symbols.logout, color: Colors.redAccent),
                  title: Text(
                    '클럽 탈퇴',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _members.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  itemBuilder: (_, i) => _buildMemberTile(_members[i], isDark),
                ),
              ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, bool isDark) {
    final user = (member['user'] as Map?) ?? const {};
    final userId = user['id']?.toString() ?? '';
    final nickname = user['nickname']?.toString() ?? '익명';
    final profileUrl = user['profile_image_url']?.toString();
    final role = member['role']?.toString() ?? 'MEMBER';
    final isAdmin = role == 'ADMIN';
    final isMe = userId == _myUserId;
    // 플랫폼 어드민(앱 전체관리자)은 운영자 뱃지를 숨긴다 (UI만; 권한은 그대로).
    final isPlatformAdmin = member['is_platform_admin'] == true;
    final avgScore = (member['avg_score'] as num?)?.toDouble();

    return ListTile(
      leading: SizedBox(
        width: 44,
        height: 44,
        child: ClipOval(
          child: AvatarImage(
            url: profileUrl,
            fallback: const Icon(Symbols.person, size: 26),
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              nickname,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 6),
            _badge('나', color: AppColors.primary),
          ],
          if (isAdmin && !isPlatformAdmin) ...[
            const SizedBox(width: 6),
            _badge('운영자', color: const Color(0xFFFBBF24)),
          ],
        ],
      ),
      subtitle: avgScore != null
          ? Text('평균 ${avgScore.toStringAsFixed(1)}점',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ))
          : null,
      trailing: (_amAdmin && !isAdmin && !isMe)
          ? PopupMenuButton<String>(
              enabled: !_busy,
              icon: const Icon(Symbols.more_vert),
              onSelected: (v) {
                if (v == 'promote') _confirmPromote(member);
                if (v == 'kick') _confirmKick(member);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'promote',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Symbols.shield_person),
                    title: Text('운영자로 위임'),
                  ),
                ),
                PopupMenuItem(
                  value: 'kick',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Symbols.person_remove, color: Colors.redAccent),
                    title: Text('추방하기',
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Widget _badge(String text, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
