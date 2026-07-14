import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';

/// 팀 번호에 대응하는 색상 (1팀=스카이블루, 2팀=오렌지, 3팀=초록)
Color _teamColor(int teamNo) {
  switch (teamNo) {
    case 1:
      return const Color(0xFF4FC3F7);
    case 2:
      return const Color(0xFFFF8A65);
    case 3:
      return const Color(0xFF81C784);
    default:
      return AppColors.textSecondaryDark;
  }
}

/// 내기 게임 종료 후 순위 결과를 보여주는 페이지
///
/// [rankings]는 서버의 gameEnded 이벤트에서 받은 배열.
/// 각 항목: {userId, nickname, score, handicap, adjustedScore, rank}
///
/// [teamMode]=true이고 [teams]가 있으면 팀 순위 섹션을 먼저 보여준다.
/// [teams] 항목: {teamNo, memberCount, teamScore, rank, members:[...]}
class BetResultPage extends StatelessWidget {
  final List<Map<String, dynamic>> rankings;
  final String? betMemo;
  final bool teamMode;
  final List<Map<String, dynamic>>? teams;

  const BetResultPage({
    super.key,
    required this.rankings,
    this.betMemo,
    this.teamMode = false,
    this.teams,
  });

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
      return _buildEmpty(context);
    }

    final showTeams = teamMode && teams != null && teams!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          '내기 결과',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 내기 메모 배너
            if (betMemo != null && betMemo!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC084FC).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC084FC).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Symbols.casino, size: 16, color: Color(0xFFC084FC)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          betMemo!,
                          style: const TextStyle(
                            color: Color(0xFFC084FC),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Expanded(
              child: showTeams
                  ? _buildTeamResultBody()
                  : _buildIndividualResultBody(),
            ),

            // 확인 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC084FC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 팀전 결과 본문
  // ───────────────────────────────────────────────

  Widget _buildTeamResultBody() {
    final sortedTeams = List<Map<String, dynamic>>.from(teams!)
      ..sort((a, b) => ((a['rank'] as num?) ?? 99).compareTo((b['rank'] as num?) ?? 99));

    final sortedIndividual = List<Map<String, dynamic>>.from(rankings)
      ..sort((a, b) => ((a['rank'] as num?) ?? 99).compareTo((b['rank'] as num?) ?? 99));

    final maxTeamRank = sortedTeams
        .map((e) => (e['rank'] as num?)?.toInt() ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // 팀 순위 섹션 헤더
        _sectionHeader('팀 순위', Symbols.groups),
        const SizedBox(height: 12),

        // 우승팀 하이라이트
        _buildWinnerTeamCard(sortedTeams.first),
        const SizedBox(height: 10),

        // 나머지 팀들
        ...sortedTeams.skip(1).map((team) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildTeamCard(team, maxTeamRank),
            )),

        // 정산 문구
        if (betMemo != null && betMemo!.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildSettlementBanner(sortedTeams, maxTeamRank),
        ],

        const SizedBox(height: 24),

        // 개인 순위 섹션
        _sectionHeader('개인 순위', Symbols.person),
        const SizedBox(height: 12),

        // 1등/꼴찌 하이라이트
        _buildIndividualHighlights(sortedIndividual),
        const SizedBox(height: 12),

        // 전체 개인 순위 리스트
        ...sortedIndividual.asMap().entries.map((entry) {
          final maxRank = sortedIndividual
              .map((e) => (e['rank'] as num?)?.toInt() ?? 0)
              .fold(0, (a, b) => a > b ? a : b);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildRankCard(entry.value, maxRank),
          );
        }),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondaryDark),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondaryDark,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
        ),
      ],
    );
  }

  Widget _buildWinnerTeamCard(Map<String, dynamic> team) {
    final teamNo = (team['teamNo'] as num?)?.toInt() ?? 1;
    final teamScore = (team['teamScore'] as num?)?.toInt() ?? 0;
    final members = (team['members'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final teamCol = _teamColor(teamNo);

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: const Icon(Symbols.emoji_events, color: Colors.amber, size: 28),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: teamCol.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: teamCol.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '$teamNo팀',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: teamCol),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '우승',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '팀 평균 $teamScore점 · ${members.length}명',
              style: TextStyle(fontSize: 12, color: Colors.amber.withValues(alpha: 0.8)),
            ),
          ),
          trailing: const Icon(Symbols.expand_more, color: Colors.amber, size: 20),
          children: members.map((m) => _buildMemberRow(m, teamCol)).toList(),
        ),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int maxTeamRank) {
    final teamNo = (team['teamNo'] as num?)?.toInt() ?? 1;
    final rank = (team['rank'] as num?)?.toInt() ?? 0;
    final teamScore = (team['teamScore'] as num?)?.toInt() ?? 0;
    final members = (team['members'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final teamCol = _teamColor(teamNo);
    final isLast = rank == maxTeamRank && maxTeamRank > 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLast
              ? Colors.blueGrey.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$rank',
              style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: teamCol.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: teamCol.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$teamNo팀',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: teamCol),
                ),
              ),
              if (isLast) ...[
                const SizedBox(width: 8),
                Icon(Symbols.sentiment_very_dissatisfied, size: 16, color: Colors.blueGrey.shade300),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '팀 평균 $teamScore점 · ${members.length}명',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
            ),
          ),
          trailing: Icon(Symbols.expand_more, color: AppColors.textSecondaryDark, size: 20),
          children: members.map((m) => _buildMemberRow(m, teamCol)).toList(),
        ),
      ),
    );
  }

  Widget _buildMemberRow(Map<String, dynamic> member, Color teamCol) {
    final nickname = member['nickname']?.toString() ?? '?';
    final score = (member['score'] as num?)?.toInt() ?? 0;
    final handicap = (member['handicap'] as num?)?.toInt() ?? 0;
    final adjustedScore = (member['adjustedScore'] as num?)?.toInt() ?? 0;
    final handicapText = handicap == 0 ? null : (handicap > 0 ? '+$handicap' : '$handicap');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: teamCol.withValues(alpha: 0.6), shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              nickname,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$adjustedScore점',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (handicapText != null)
                Text(
                  '$score $handicapText',
                  style: TextStyle(fontSize: 10, color: AppColors.textSecondaryDark),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementBanner(List<Map<String, dynamic>> sortedTeams, int maxRank) {
    final losingTeam = sortedTeams.firstWhere(
      (t) => (t['rank'] as num?)?.toInt() == maxRank,
      orElse: () => sortedTeams.last,
    );
    final losingTeamNo = (losingTeam['teamNo'] as num?)?.toInt() ?? 0;
    final losingLabel = losingTeamNo > 0 ? '$losingTeamNo팀' : '꼴찌팀';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFC084FC).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC084FC).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Symbols.receipt_long, size: 15, color: Color(0xFFC084FC)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$losingLabel이 $betMemo',
              style: const TextStyle(
                color: Color(0xFFC084FC),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────
  // 개인전 결과 본문 (기존과 동일)
  // ───────────────────────────────────────────────

  Widget _buildIndividualResultBody() {
    final sorted = List<Map<String, dynamic>>.from(rankings)
      ..sort((a, b) => ((a['rank'] as num?) ?? 99).compareTo((b['rank'] as num?) ?? 99));

    final maxRank = sorted
        .map((e) => (e['rank'] as num?)?.toInt() ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        // 1등 / 꼴찌 하이라이트 카드
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildIndividualHighlights(sorted),
        ),
        const SizedBox(height: 20),

        // 전체 순위 리스트
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _buildRankCard(sorted[index], maxRank);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIndividualHighlights(List<Map<String, dynamic>> sorted) {
    final maxRank = sorted
        .map((e) => (e['rank'] as num?)?.toInt() ?? 0)
        .fold(0, (a, b) => a > b ? a : b);

    final winner = sorted.firstWhere(
      (e) => (e['rank'] as num?)?.toInt() == 1,
      orElse: () => sorted.first,
    );
    final loser = maxRank > 1
        ? sorted.firstWhere(
            (e) => (e['rank'] as num?)?.toInt() == maxRank,
            orElse: () => sorted.last,
          )
        : null;

    return Row(
      children: [
        Expanded(child: _buildHighlightCard(winner, isWinner: true)),
        if (loser != null) ...[
          const SizedBox(width: 12),
          Expanded(child: _buildHighlightCard(loser, isWinner: false)),
        ],
      ],
    );
  }

  Widget _buildHighlightCard(Map<String, dynamic> entry, {required bool isWinner}) {
    final nickname = entry['nickname']?.toString() ?? '?';
    final adjustedScore = (entry['adjustedScore'] as num?)?.toInt() ?? 0;

    if (isWinner) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            const Icon(Symbols.emoji_events, color: Colors.amber, size: 32),
            const SizedBox(height: 6),
            Text(
              nickname,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$adjustedScore점',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '1등',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blueGrey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(Symbols.sentiment_very_dissatisfied,
                color: Colors.blueGrey.shade300, size: 32),
            const SizedBox(height: 6),
            Text(
              nickname,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.blueGrey.shade300,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$adjustedScore점',
              style: TextStyle(
                color: Colors.blueGrey.shade300,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '꼴찌',
                style: TextStyle(
                  color: Colors.blueGrey.shade300,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildRankCard(Map<String, dynamic> entry, int maxRank) {
    final rank = (entry['rank'] as num?)?.toInt() ?? 0;
    final nickname = entry['nickname']?.toString() ?? '?';
    final score = (entry['score'] as num?)?.toInt() ?? 0;
    final handicap = (entry['handicap'] as num?)?.toInt() ?? 0;
    final adjustedScore = (entry['adjustedScore'] as num?)?.toInt() ?? 0;
    final isWinner = rank == 1;
    final isLoser = rank == maxRank && maxRank > 1;

    final rankColor = isWinner
        ? Colors.amber
        : isLoser
            ? Colors.blueGrey.shade300
            : Colors.white60;

    final handicapText = handicap == 0
        ? null
        : (handicap > 0 ? '+$handicap' : '$handicap');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner
            ? Colors.amber.withValues(alpha: 0.06)
            : AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWinner
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // 등수 배지
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: isWinner
                ? const Icon(Symbols.emoji_events, color: Colors.amber, size: 20)
                : Text(
                    '$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 14),

          // 닉네임
          Expanded(
            child: Text(
              nickname,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isWinner ? Colors.amber : Colors.white,
              ),
            ),
          ),

          // 점수 영역
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // adjustedScore 강조
              Text(
                '$adjustedScore',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isWinner ? Colors.amber : Colors.white,
                ),
              ),
              // 원점수 + 핸디 표시
              if (handicapText != null)
                Text(
                  '$score $handicapText = $adjustedScore',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                  ),
                )
              else
                Text(
                  '$score점',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('내기 결과',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.casino, color: AppColors.textSecondaryDark, size: 48),
            const SizedBox(height: 16),
            const Text('결과 데이터가 없습니다.',
                style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 15)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC084FC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('확인', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
