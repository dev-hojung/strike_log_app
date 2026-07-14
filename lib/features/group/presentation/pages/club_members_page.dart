import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/avatar_image.dart';
import '../../data/services/groups_api_service.dart';
import 'club_invite_code_page.dart';

/// 클럽 멤버 관리 페이지.
///
/// 표시:
/// - 멤버 리스트 (아바타·닉네임·역할 배지·평균 점수)
/// - 본인은 "나" 표시
///
/// 액션 (내 역할 기준):
/// - OWNER: 모든 MEMBER에게 "운영진 임명" + "추방", 모든 STAFF에게 "운영진 해제" + "추방",
///          모든 비본인·비OWNER에게 "클럽장 이양"
/// - STAFF: MEMBER에게 "추방"만. STAFF/OWNER에게는 아무 액션 없음.
/// - MEMBER: 액션 없음.
///
/// 탈퇴 정책:
/// - 일반 케이스: 즉시 탈퇴 후 pop
/// - 유일 멤버: 백엔드가 클럽 자체 삭제 → pop + "클럽이 사라졌어요"
/// - OWNER + 다른 멤버: 409 → 클럽장 이양 안내 다이얼로그
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

  /// 내 역할 문자열. 데이터 미로드 시 'MEMBER' 반환.
  String get _myRole {
    if (_myUserId == null) return GroupRole.member;
    final me = _members.firstWhere(
      (m) => (m['user']?['id']?.toString() ?? '') == _myUserId,
      orElse: () => const {},
    );
    return me['role']?.toString() ?? GroupRole.member;
  }

  // ── 운영진 임명 ──────────────────────────────────────────────────────────

  Future<void> _confirmAppointStaff(Map<String, dynamic> member) async {
    final nickname = member['user']?['nickname']?.toString() ?? '멤버';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('운영진으로 임명할까요?'),
        content: Text(
          '$nickname 님을 운영진으로 임명합니다.\n'
          '운영진은 가입 신청 승인, 공지 작성, 일반멤버 추방을 할 수 있어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('임명하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _doAppointStaff(member);
  }

  Future<void> _doAppointStaff(Map<String, dynamic> member) async {
    final targetId = member['user']?['id']?.toString();
    if (targetId == null) return;
    setState(() => _busy = true);
    try {
      await _api.promoteMember(groupId: widget.groupId, targetUserId: targetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member['user']?['nickname'] ?? '멤버'} 님을 운영진으로 임명했어요.')),
      );
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '임명에 실패했습니다.')
          : '임명에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 운영진 해제 ──────────────────────────────────────────────────────────

  Future<void> _confirmRevokeStaff(Map<String, dynamic> member) async {
    final nickname = member['user']?['nickname']?.toString() ?? '멤버';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('운영진을 해제할까요?'),
        content: Text(
          '$nickname 님의 운영진 권한을 해제합니다.\n'
          '해제 후 일반멤버로 변경돼요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해제하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _doRevokeStaff(member);
  }

  Future<void> _doRevokeStaff(Map<String, dynamic> member) async {
    final targetId = member['user']?['id']?.toString();
    if (targetId == null) return;
    setState(() => _busy = true);
    try {
      await _api.revokeStaff(groupId: widget.groupId, targetUserId: targetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member['user']?['nickname'] ?? '멤버'} 님의 운영진을 해제했어요.')),
      );
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '해제에 실패했습니다.')
          : '해제에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 클럽장 이양 ──────────────────────────────────────────────────────────

  Future<void> _confirmTransferOwnership(Map<String, dynamic> member) async {
    final nickname = member['user']?['nickname']?.toString() ?? '멤버';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('클럽장을 이양할까요?'),
        content: Text(
          '$nickname 님에게 클럽장 권한을 이양합니다.\n\n'
          '이양 후 본인은 운영진으로 변경되며,\n'
          '클럽장 권한은 되돌릴 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('이양하기'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _doTransferOwnership(member);
  }

  Future<void> _doTransferOwnership(Map<String, dynamic> member) async {
    final targetId = member['user']?['id']?.toString();
    if (targetId == null) return;
    setState(() => _busy = true);
    try {
      await _api.transferOwnership(groupId: widget.groupId, targetUserId: targetId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member['user']?['nickname'] ?? '멤버'} 님에게 클럽장을 이양했어요.')),
      );
      await _refresh();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data is Map
          ? (e.response!.data['message']?.toString() ?? '이양에 실패했습니다.')
          : '이양에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── 추방 ─────────────────────────────────────────────────────────────────

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

  // ── 탈퇴 ─────────────────────────────────────────────────────────────────

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
        // OWNER + 다른 멤버 존재 → 클럽장 이양 안내
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('클럽장을 먼저 이양해주세요'),
            content: Text(
              '$msg\n\n'
              '아래 멤버 목록에서 다른 멤버에게 클럽장을 이양하면 탈퇴할 수 있어요.',
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

  // ── 빌드 ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('멤버 관리'),
        actions: [
          if (GroupRole.canManage(_myRole))
            IconButton(
              icon: const Icon(Symbols.person_add),
              tooltip: '초대 코드',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClubInviteCodePage(
                      groupId: widget.groupId,
                      groupName: widget.groupName,
                    ),
                  ),
                );
              },
            ),
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
    final role = member['role']?.toString() ?? GroupRole.member;
    final isMe = userId == _myUserId;
    final isPlatformAdmin = member['is_platform_admin'] == true;
    final avgScore = (member['avg_score'] as num?)?.toDouble();

    final myRole = _myRole;
    final trailing = _buildTrailing(
      member: member,
      role: role,
      isMe: isMe,
      myRole: myRole,
    );

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
          if (role == GroupRole.owner && !isPlatformAdmin) ...[
            const SizedBox(width: 6),
            _badge('클럽장', color: const Color(0xFFFBBF24)),
          ],
          if (role == GroupRole.staff && !isPlatformAdmin) ...[
            const SizedBox(width: 6),
            _badge('운영진', color: AppColors.primary),
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
      trailing: trailing,
    );
  }

  /// 멤버 행 우측 액션 버튼. 내 역할과 대상 역할에 따라 메뉴 항목 결정.
  Widget? _buildTrailing({
    required Map<String, dynamic> member,
    required String role,
    required bool isMe,
    required String myRole,
  }) {
    // 본인 행에는 액션 없음
    if (isMe) return null;
    // 내가 MEMBER면 액션 없음
    if (!GroupRole.canManage(myRole)) return null;
    // 대상이 OWNER면 항상 액션 없음
    if (role == GroupRole.owner) return null;
    // STAFF는 MEMBER에게만 추방 가능 (STAFF 대상 불가)
    if (myRole == GroupRole.staff && role == GroupRole.staff) return null;

    final items = <PopupMenuEntry<String>>[];

    if (myRole == GroupRole.owner) {
      if (role == GroupRole.member) {
        // OWNER가 MEMBER를 볼 때: 운영진 임명 + 추방 + 클럽장 이양
        items.add(const PopupMenuItem(
          value: 'appoint_staff',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Symbols.shield_person),
            title: Text('운영진 임명'),
          ),
        ));
        items.add(const PopupMenuItem(
          value: 'transfer_ownership',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Symbols.swap_horiz),
            title: Text('클럽장 이양'),
          ),
        ));
        items.add(const PopupMenuItem(
          value: 'kick',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Symbols.person_remove, color: Colors.redAccent),
            title: Text('추방하기', style: TextStyle(color: Colors.redAccent)),
          ),
        ));
      } else if (role == GroupRole.staff) {
        // OWNER가 STAFF를 볼 때: 운영진 해제 + 추방 + 클럽장 이양
        items.add(const PopupMenuItem(
          value: 'revoke_staff',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Symbols.shield),
            title: Text('운영진 해제'),
          ),
        ));
        items.add(const PopupMenuItem(
          value: 'transfer_ownership',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Symbols.swap_horiz),
            title: Text('클럽장 이양'),
          ),
        ));
        items.add(const PopupMenuItem(
          value: 'kick',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Symbols.person_remove, color: Colors.redAccent),
            title: Text('추방하기', style: TextStyle(color: Colors.redAccent)),
          ),
        ));
      }
    } else if (myRole == GroupRole.staff) {
      // STAFF가 MEMBER를 볼 때: 추방만
      items.add(const PopupMenuItem(
        value: 'kick',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Symbols.person_remove, color: Colors.redAccent),
          title: Text('추방하기', style: TextStyle(color: Colors.redAccent)),
        ),
      ));
    }

    if (items.isEmpty) return null;

    return PopupMenuButton<String>(
      enabled: !_busy,
      icon: const Icon(Symbols.more_vert),
      onSelected: (v) {
        if (v == 'appoint_staff') _confirmAppointStaff(member);
        if (v == 'revoke_staff') _confirmRevokeStaff(member);
        if (v == 'transfer_ownership') _confirmTransferOwnership(member);
        if (v == 'kick') _confirmKick(member);
      },
      itemBuilder: (_) => items,
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
