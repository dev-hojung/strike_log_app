import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../../../core/constants/app_colors.dart';

/// 내기 게임 종료 후 순위 결과를 보여주는 페이지
///
/// [rankings]는 서버의 gameEnded 이벤트에서 받은 배열.
/// 각 항목: {userId, nickname, score, handicap, adjustedScore, rank}
class BetResultPage extends StatelessWidget {
  final List<Map<String, dynamic>> rankings;
  final String? betMemo;

  const BetResultPage({
    super.key,
    required this.rankings,
    this.betMemo,
  });

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
      return _buildEmpty(context);
    }

    final sorted = List<Map<String, dynamic>>.from(rankings)
      ..sort((a, b) => ((a['rank'] as num?) ?? 99).compareTo((b['rank'] as num?) ?? 99));

    final maxRank = sorted.map((e) => (e['rank'] as num?)?.toInt() ?? 0).fold(0, (a, b) => a > b ? a : b);
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

            // 1등 / 꼴찌 하이라이트 카드
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(child: _buildHighlightCard(winner, isWinner: true)),
                  if (loser != null) ...[
                    const SizedBox(width: 12),
                    Expanded(child: _buildHighlightCard(loser, isWinner: false)),
                  ],
                ],
              ),
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
