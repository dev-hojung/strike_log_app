import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/club_leaderboard.dart';
import '../../data/services/leaderboard_api_service.dart';

/// 클럽 리더보드 페이지.
///
/// 멤버 전원의 누적 평균 점수 내림차순. 본인 행은 스티키로 하단에 강조 표시.
class ClubLeaderboardPage extends StatefulWidget {
  final int clubId;
  final String clubName;

  const ClubLeaderboardPage({
    super.key,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<ClubLeaderboardPage> createState() => _ClubLeaderboardPageState();
}

class _ClubLeaderboardPageState extends State<ClubLeaderboardPage> {
  final LeaderboardApiService _api = LeaderboardApiService();
  ClubLeaderboard? _data;
  String? _currentUserId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final data = await _api.fetchClubLeaderboard(widget.clubId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '랭킹을 불러오지 못했습니다.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final fg = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: fg),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '랭킹',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.clubName,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(fg)
              : _buildBody(isDark),
    );
  }

  Widget _buildError(Color fg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.error_outline,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: fg, fontSize: 14)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _fetch();
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    final data = _data!;
    if (data.entries.isEmpty) {
      return _buildEmpty(isDark);
    }
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetch,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: data.entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = data.entries[i];
                final isMe = e.userId == _currentUserId;
                return _entryTile(isDark, e, isMe: isMe);
              },
            ),
          ),
        ),
        if (data.myRank != null && _currentUserId != null)
          _buildStickyMine(isDark, data),
      ],
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Symbols.leaderboard,
                size: 64,
                color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              '아직 멤버 기록이 없습니다.',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entryTile(bool isDark, LeaderboardEntry e, {required bool isMe}) {
    final rankColor = _rankAccent(e.rank);
    final tileBg = isMe
        ? AppColors.primary.withValues(alpha: 0.12)
        : (isDark ? AppColors.surfaceDark : Colors.white);
    final tileBorder = isMe
        ? AppColors.primary.withValues(alpha: 0.55)
        : (isDark ? Colors.white10 : Colors.black12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tileBorder, width: isMe ? 1.4 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: _rankBadge(e.rank, rankColor, isDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        e.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '나',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  e.gameCount > 0
                      ? '최고 ${e.highest} · ${e.gameCount}경기'
                      : '아직 경기 없음',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                e.gameCount > 0 ? e.avg.toStringAsFixed(1) : '-',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              const Text(
                'AVG',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rankBadge(int rank, Color color, bool isDark) {
    // 1~3등은 메달 아이콘, 그 이하는 숫자.
    if (rank <= 3) {
      return Container(
        alignment: Alignment.center,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(Symbols.workspace_premium, color: color, size: 22),
      );
    }
    return Container(
      alignment: Alignment.center,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: TextStyle(
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Color _rankAccent(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFB300); // gold
      case 2:
        return const Color(0xFFB0BEC5); // silver
      case 3:
        return const Color(0xFFFF8A65); // bronze
      default:
        return AppColors.primary;
    }
  }

  Widget _buildStickyMine(bool isDark, ClubLeaderboard data) {
    final me = data.myRank!;
    final myEntry = data.entries.firstWhere(
      (e) => e.userId == _currentUserId,
      orElse: () => LeaderboardEntry(
        rank: me.rank,
        userId: _currentUserId!,
        nickname: '나',
        avg: me.avg,
        highest: me.highest,
        gameCount: me.gameCount,
      ),
    );
    // 본인 행이 리스트 상단에 보이면(상위 3) 굳이 스티키 중복 노출 안 함.
    if (me.rank <= 3) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          border: Border(
            top: BorderSide(
                color: isDark ? Colors.white10 : Colors.black12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: _entryTile(isDark, myEntry, isMe: true),
      ),
    );
  }
}
