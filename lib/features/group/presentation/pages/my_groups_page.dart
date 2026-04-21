import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import '../../data/services/group_creation_requests_service.dart';
import 'club_join_requests_page.dart';
import 'create_club_page.dart';
import 'explore_clubs_page.dart';
import 'member_stats_page.dart';

/// 사용자가 소속된 클럽의 멤버 목록을 보여주는 페이지입니다.
class MyGroupsPage extends StatefulWidget {
  const MyGroupsPage({super.key});

  @override
  State<MyGroupsPage> createState() => _MyGroupsPageState();
}

class _MyGroupsPageState extends State<MyGroupsPage> {
  Map<String, dynamic>? _club;
  List<dynamic> _members = [];
  List<dynamic> _filteredMembers = [];
  List<Map<String, dynamic>> _pendingCreationRequests = [];
  String? _currentUserId;
  bool _isLoading = true;
  bool _sortByScore = true;
  final _searchController = TextEditingController();
  final GroupCreationRequestsService _creationRequestsService =
      GroupCreationRequestsService();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_filterMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 현재 사용자가 클럽장인지 판별.
  /// 백엔드 필드명이 환경마다 달라질 수 있어 알려진 후보들을 모두 확인.
  bool _isClubLeader() {
    final club = _club;
    final userId = _currentUserId;
    if (club == null || userId == null) return false;
    for (final key in ['leader_id', 'owner_id', 'creator_id', 'created_by']) {
      final value = club[key];
      if (value != null && value.toString() == userId) return true;
    }
    return false;
  }

  Future<void> _openJoinRequests() async {
    final club = _club;
    if (club == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubJoinRequestsPage(
          clubId: club['id'] is int
              ? club['id']
              : int.tryParse(club['id'].toString()) ?? 0,
          clubName: club['name']?.toString() ?? '',
        ),
      ),
    );
    // 승인 처리 후 멤버 목록 새로고침
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      _currentUserId = userId;

      // 클럽 목록과 생성 신청 목록을 병렬 조회
      final results = await Future.wait([
        ApiClient().dio.get('/groups/me/$userId'),
        _creationRequestsService.listMyRequests(userId),
      ]);
      final groupsResponse = results[0] as dynamic;
      final myRequests = results[1] as List<Map<String, dynamic>>;

      final pending = myRequests
          .where((r) => (r['status']?.toString() ?? '') == 'pending')
          .toList();

      final groups = groupsResponse.data is List ? groupsResponse.data : [];

      if (groups.isEmpty) {
        if (mounted) {
          setState(() {
            _pendingCreationRequests = pending;
            _isLoading = false;
          });
        }
        return;
      }

      final club = groups[0];
      final clubId = club['id'];

      final membersResponse = await ApiClient().dio.get('/groups/$clubId/members-with-stats');
      final members = membersResponse.data is List ? membersResponse.data as List : [];

      if (mounted) {
        setState(() {
          _club = club;
          _members = members;
          _filteredMembers = List.from(members);
          _pendingCreationRequests = pending;
          _isLoading = false;
          _applySorting();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelCreationRequest(int requestId) async {
    final userId = _currentUserId;
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('신청을 취소할까요?'),
        content: const Text('취소 후에는 다시 신청해야 합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('닫기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _creationRequestsService.cancel(
      requestId: requestId,
      userId: userId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '신청을 취소했습니다.' : '취소에 실패했습니다.')),
    );
    if (ok) _fetchData();
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        _filteredMembers = _members.where((m) {
          final nickname = (m['user']?['nickname'] ?? '').toString().toLowerCase();
          return nickname.contains(query);
        }).toList();
      }
      _applySorting();
    });
  }

  void _applySorting() {
    if (_sortByScore) {
      _filteredMembers.sort((a, b) {
        final aScore = (a['avg_score'] ?? 0) as num;
        final bScore = (b['avg_score'] ?? 0) as num;
        return bScore.compareTo(aScore);
      });
    }
  }

  void _toggleSort() {
    setState(() {
      _sortByScore = !_sortByScore;
      if (_sortByScore) {
        _applySorting();
      } else {
        _filteredMembers = List.from(_members);
        _filterMembers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: _club == null
          ? AppBar(
              backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: Text(
                '클럽',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _club == null
              ? (_pendingCreationRequests.isNotEmpty
                  ? _buildPendingView(isDark)
                  : _buildEmptyState(isDark))
              : _buildClubContent(isDark),
    );
  }

  /// 클럽 생성 신청 심사 중 전용 화면.
  /// 가입된 클럽이 없고 pending 신청이 하나 이상 있을 때 노출.
  Widget _buildPendingView(bool isDark) {
    final textPrimary = isDark ? Colors.white : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 24, 20, 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Symbols.hourglass_top,
                        size: 56,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '클럽 생성 승인 대기 중',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '관리자 승인 후 클럽이 생성됩니다.\n결과는 알림으로 알려드려요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ..._pendingCreationRequests.map((req) => _buildPendingCard(
                        req,
                        surface: surface,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingCard(
    Map<String, dynamic> req, {
    required Color surface,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final name = req['name']?.toString() ?? '';
    final description = req['description']?.toString();
    final createdAtRaw = req['created_at']?.toString();
    final createdAt = createdAtRaw != null && createdAtRaw.isNotEmpty
        ? DateTime.tryParse(createdAtRaw)
        : null;
    final createdLabel = createdAt == null
        ? ''
        : '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
    final id = req['id'] is int
        ? req['id'] as int
        : int.tryParse(req['id']?.toString() ?? '') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '심사 중',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (createdLabel.isNotEmpty)
                Text(
                  createdLabel,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: textSecondary, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: id == 0 ? null : () => _cancelCreationRequest(id),
              icon: Icon(Symbols.close, size: 18, color: textSecondary),
              label: Text(
                '신청 취소',
                style: TextStyle(color: textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubContent(bool isDark) {
    final clubName = _club?['name'] ?? '클럽';
    final memberCount = _members.length;

    return SafeArea(
      child: Column(
        children: [
          // 클럽 헤더
          _buildClubHeader(clubName, isDark),
          // 콘텐츠
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchData();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  // 체험판 상태 배너
                  if (_buildTrialBanner(isDark) != null) ...[
                    _buildTrialBanner(isDark)!,
                    const SizedBox(height: 12),
                  ],
                  // 멤버 검색
                  _buildSearchBar(isDark),
                  const SizedBox(height: 12),
                  // 멤버 수 + 정렬
                  _buildMemberCountRow(memberCount, isDark),
                  const SizedBox(height: 12),
                  // 멤버 리스트
                  ..._filteredMembers.map((member) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildMemberCard(member, isDark),
                  )),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 체험판/만료 상태 배너. active(정식)면 null 반환해 표시하지 않음.
  Widget? _buildTrialBanner(bool isDark) {
    final status = _club?['subscription_status']?.toString();
    if (status == null || status == 'active') return null;

    final expiresRaw = _club?['trial_expires_at']?.toString();
    final expires = expiresRaw != null && expiresRaw.isNotEmpty
        ? DateTime.tryParse(expiresRaw)
        : null;

    if (status == 'expired') {
      return _trialBannerCard(
        isDark: isDark,
        icon: Symbols.lock_clock,
        accent: Colors.redAccent,
        title: '체험판이 만료되었습니다',
        subtitle: '일부 기능(새 게임 생성 등)이 제한됩니다.',
      );
    }

    // trial
    int daysRemaining = 0;
    if (expires != null) {
      final diff = expires.difference(DateTime.now());
      daysRemaining = diff.inDays;
      if (daysRemaining <= 0 && diff.inSeconds > 0) daysRemaining = 1;
    }

    return _trialBannerCard(
      isDark: isDark,
      icon: Symbols.hourglass_top,
      accent: AppColors.primary,
      title: '체험판 이용 중',
      subtitle: daysRemaining > 0
          ? '$daysRemaining일 남았습니다.'
          : '곧 만료됩니다.',
    );
  }

  Widget _trialBannerCard({
    required bool isDark,
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
  }) {
    final bg = accent.withValues(alpha: 0.12);
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: subColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubHeader(String clubName, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.backgroundDark.withValues(alpha: 0.8)
            : AppColors.backgroundLight,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: const Icon(Symbols.groups, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.45,
                  ),
                ),
                Text(
                  _club?['description'] ?? '',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isClubLeader())
            IconButton(
              icon: Icon(
                Symbols.person_add,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                size: 20,
              ),
              tooltip: '가입 신청 관리',
              onPressed: _openJoinRequests,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : Colors.black12,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: '멤버 검색...',
          hintStyle: TextStyle(
            color: isDark ? const Color(0xFF64748B) : AppColors.textSecondaryLight,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Symbols.search,
            color: isDark ? const Color(0xFF64748B) : AppColors.textSecondaryLight,
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildMemberCountRow(int count, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '멤버 ($count)',
          style: TextStyle(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontSize: 14,
            letterSpacing: 1.4,
          ),
        ),
        GestureDetector(
          onTap: _toggleSort,
          child: Text(
            _sortByScore ? '점수순 정렬' : '기본 정렬',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(dynamic member, bool isDark) {
    final user = member['user'] as Map<String, dynamic>?;
    final nickname = user?['nickname'] ?? '';
    final profileImageUrl = user?['profile_image_url'];
    final avgScore = member['avg_score']?.toString() ?? '-';
    final userId = member['user_id']?.toString() ?? '';
    final isMe = userId == _currentUserId;
    final role = member['role'] ?? 'MEMBER';

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: 0.05)
            : (isDark ? const Color(0xFF0F172A) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF1E293B) : Colors.black12),
          width: isMe ? 2 : 0.66,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // 아바타 + 온라인 표시
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : Colors.black12,
                    ),
                  ),
                  child: ClipOval(
                    child: profileImageUrl != null && profileImageUrl.isNotEmpty
                        ? Image.network(profileImageUrl, fit: BoxFit.cover)
                        : Icon(
                            Symbols.person,
                            size: 28,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                  ),
                ),
                if (isMe)
                  Positioned(
                    left: -2,
                    top: 12,
                    child: Container(
                      width: 4,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // 이름 + 평균 점수
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          style: TextStyle(
                            color: isDark ? const Color(0xFFF1F5F9) : AppColors.textPrimaryLight,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                      if (role == 'ADMIN' && !isMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (isMe)
                        Icon(Symbols.star, size: 13, color: AppColors.primary),
                      if (isMe) const SizedBox(width: 4),
                      Text(
                        '평균 점수: $avgScore',
                        style: TextStyle(
                          color: isMe
                              ? AppColors.primary
                              : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 통계 버튼
            _buildStatsButton(userId, nickname, isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsButton(String userId, String nickname, bool isMe) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemberStatsPage(
              userId: userId,
              nickname: nickname,
              isMe: isMe,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: isMe
              ? null
              : Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          boxShadow: isMe
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Text(
          isMe ? '통계' : '통계 보기',
          style: TextStyle(
            color: isMe ? Colors.white : AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 160),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Icon(Symbols.groups, size: 80, color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              '가입된 클럽이 없어요!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '나만의 클럽을 직접 만들어\n함께 볼링을 즐겨보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateClubPage()),
                  ).then((_) => _fetchData());
                },
                icon: const Icon(Symbols.add, color: Colors.white),
                label: const Text(
                  '새 클럽 만들기',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ExploreClubsPage()),
                  ).then((_) => _fetchData());
                },
                icon: Icon(Symbols.search, color: AppColors.primary),
                label: Text(
                  '클럽 탐색하기',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
}
