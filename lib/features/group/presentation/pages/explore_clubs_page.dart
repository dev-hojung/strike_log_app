import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/korea_regions.dart';
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

  /// 본인이 이미 가입한 클럽 ID 집합. 1인 1클럽 정책상 보통 0~1개.
  Set<int> _myClubIds = const {};
  bool get _amInAnyClub => _myClubIds.isNotEmpty;

  /// 시/도 필터 ("전체"는 null).
  String? _filterProvince;

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
      // 전체 클럽 + 본인이 가입한 클럽을 병렬 조회.
      // /groups/me 실패는 무시 (가입 상태 정보만 누락될 뿐 탐색은 가능).
      final dio = ApiClient().dio;
      final allFuture = dio.get('/groups');
      final mineFuture = dio.get('/groups/me');
      final allResp = await allFuture;
      dynamic mineRaw;
      try {
        final mineResp = await mineFuture;
        mineRaw = mineResp.data;
      } catch (_) {
        mineRaw = null;
      }
      final clubs = allResp.data is List ? allResp.data as List : [];
      final mineIds = <int>{};
      if (mineRaw is List) {
        for (final m in mineRaw) {
          if (m is Map && m['id'] != null) {
            final id = int.tryParse(m['id'].toString());
            if (id != null) mineIds.add(id);
          }
        }
      }

      if (mounted) {
        setState(() {
          _clubs = clubs;
          _filteredClubs = List.from(clubs);
          _myClubIds = mineIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterClubs() {
    final query = _searchController.text.toLowerCase();
    final province = _filterProvince;
    setState(() {
      _filteredClubs = _clubs.where((c) {
        // 텍스트 검색 (이름·설명)
        if (query.isNotEmpty) {
          final name = (c['name'] ?? '').toString().toLowerCase();
          final desc = (c['description'] ?? '').toString().toLowerCase();
          if (!name.contains(query) && !desc.contains(query)) return false;
        }
        // 시/도 필터 — region 문자열의 앞부분이 시/도와 일치하면 통과.
        if (province != null && province.isNotEmpty) {
          final region = (c['activity_region'] ?? '').toString();
          if (!region.startsWith(province)) return false;
        }
        return true;
      }).toList();
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
                  const SizedBox(height: 12),
                  // 시/도 필터 (가로 스크롤 ChoiceChip)
                  _buildRegionFilter(isDark, textColor, secondaryColor, borderColor),
                  const SizedBox(height: 12),
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

  /// 시/도 필터 — 가로 스크롤 ChoiceChip 리스트.
  Widget _buildRegionFilter(
    bool isDark, Color textColor, Color secondaryColor, Color borderColor,
  ) {
    final all = ['전체', ...kProvinces];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = all[i];
          final isAll = i == 0;
          final selected = isAll
              ? _filterProvince == null
              : _filterProvince == label;
          return ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) {
              setState(() => _filterProvince = isAll ? null : label);
              _filterClubs();
            },
            labelStyle: TextStyle(
              color: selected ? Colors.white : textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
            side: BorderSide(color: selected ? AppColors.primary : borderColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
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
    final avgScore = (club['avg_score'] as num?)?.toInt() ?? 0;
    final activityRegion = (club['activity_region'] ?? '').toString();
    final clubId = int.tryParse(club['id']?.toString() ?? '');
    final isMine = clubId != null && _myClubIds.contains(clubId);
    // 다른 클럽인데 본인이 어떤 클럽에든 이미 가입 상태면 disabled.
    final isDisabled = !isMine && _amInAnyClub;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: () => _navigateToJoin(club),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMine ? AppColors.primary.withValues(alpha: 0.6) : borderColor,
              width: isMine ? 1.5 : 1,
            ),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '내 클럽',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                      const SizedBox(width: 10),
                      Icon(Symbols.equalizer, color: secondaryColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        avgScore > 0 ? '에버 $avgScore' : '에버 -',
                        style: TextStyle(color: secondaryColor, fontSize: 12),
                      ),
                      if (activityRegion.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Symbols.location_on, color: secondaryColor, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            activityRegion,
                            style: TextStyle(color: secondaryColor, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
      ),
    );
  }

  void _navigateToJoin(dynamic club) {
    // 본인이 이미 어떤 클럽에든 가입한 상태면 새 가입 신청 차단.
    final clubId = int.tryParse(club['id']?.toString() ?? '');
    final isMine = clubId != null && _myClubIds.contains(clubId);

    if (_amInAnyClub) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(isMine ? '이미 가입된 클럽이에요' : '먼저 탈퇴 후 시도해주세요'),
          content: Text(
            isMine
                ? '본인이 가입한 클럽입니다. 내 클럽 화면에서 활동을 이어가세요.'
                : '한 번에 하나의 클럽에만 가입할 수 있습니다. 현재 가입된 클럽에서 탈퇴한 후 다시 시도해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return;
    }

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
