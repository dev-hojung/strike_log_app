import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_client.dart';
import 'club_join_page.dart';

/// 전체 클럽을 탐색할 수 있는 페이지입니다.
class ExploreClubsPage extends StatefulWidget {
  const ExploreClubsPage({super.key});

  @override
  State<ExploreClubsPage> createState() => _ExploreClubsPageState();
}

class _ExploreClubsPageState extends State<ExploreClubsPage> {
  List<dynamic> _clubs = [];
  List<dynamic> _filteredClubs = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchClubs();
    _searchController.addListener(_filterClubs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchClubs() async {
    try {
      final response = await ApiClient().dio.get('/groups');
      final clubs = response.data is List ? response.data as List : [];

      if (mounted) {
        setState(() {
          _clubs = clubs;
          _filteredClubs = List.from(clubs);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterClubs() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredClubs = List.from(_clubs);
      } else {
        _filteredClubs = _clubs.where((c) {
          final name = (c['name'] ?? '').toString().toLowerCase();
          final desc = (c['description'] ?? '').toString().toLowerCase();
          return name.contains(query) || desc.contains(query);
        }).toList();
      }
    });
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
          '클럽 탐색',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchClubs,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 8),
                  // 검색바
                  _buildSearchBar(isDark, textColor, secondaryColor, borderColor),
                  const SizedBox(height: 20),
                  // 리스트 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '전체 리스트',
                        style: TextStyle(
                          color: secondaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      Text(
                        '${_filteredClubs.length}개',
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 클럽 카드 리스트
                  if (_filteredClubs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          '검색 결과가 없습니다.',
                          style: TextStyle(color: secondaryColor, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ..._filteredClubs.map((club) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildClubCard(club, isDark, surfaceColor, textColor, secondaryColor, borderColor),
                        )),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color textColor, Color secondaryColor, Color borderColor) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: '클럽 이름이나 설명으로 검색...',
          hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : secondaryColor, fontSize: 14),
          prefixIcon: Icon(Symbols.search, color: secondaryColor, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildClubCard(
    dynamic club,
    bool isDark,
    Color surfaceColor,
    Color textColor,
    Color secondaryColor,
    Color borderColor,
  ) {
    final name = club['name'] ?? '';
    final description = club['description'] ?? '';
    final memberCount = club['member_count'] ?? 0;

    return GestureDetector(
      onTap: () => _navigateToJoin(club),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            // 클럽 아이콘
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF32343E) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Symbols.groups,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // 클럽 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Symbols.person, color: secondaryColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$memberCount명',
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            description,
                            style: TextStyle(
                              color: secondaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.28,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 가입 신청 버튼
            GestureDetector(
              onTap: () => _navigateToJoin(club),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '가입 신청',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToJoin(dynamic club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubJoinPage(
          clubId: club['id'],
          clubName: club['name'] ?? '',
          clubDescription: club['description'] ?? '',
          coverImageUrl: club['cover_image_url'],
          memberCount: club['member_count'] ?? 0,
        ),
      ),
    ).then((_) => _fetchClubs());
  }
}
