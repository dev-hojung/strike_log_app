import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import 'create_club_page.dart';
import 'explore_clubs_page.dart';

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
  String? _currentUserId;
  bool _isLoading = true;
  bool _sortByScore = true;
  final _searchController = TextEditingController();

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

  Future<void> _fetchData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }
      _currentUserId = userId;

      final groupsResponse = await ApiClient().dio.get('/groups/me/$userId');
      final groups = groupsResponse.data is List ? groupsResponse.data : [];

      if (groups.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
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
          _isLoading = false;
          _applySorting();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
              ? _buildEmptyState(isDark)
              : _buildClubContent(isDark),
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
                  // 주변 게임 찾기 배너
                  _buildFindGameBanner(),
                  const SizedBox(height: 16),
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
          IconButton(
            icon: Icon(
              Symbols.settings,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              size: 20,
            ),
            onPressed: () {
              // TODO: 클럽 설정 페이지
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFindGameBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.sports_score, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '주변 게임 찾기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Opacity(
            opacity: 0.8,
            child: const Icon(Symbols.chevron_right, color: Colors.white, size: 16),
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
            _buildStatsButton(isMe),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsButton(bool isMe) {
    if (isMe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: const Text(
          '통계',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: const Text(
        '통계 보기',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
    );
  }
}
