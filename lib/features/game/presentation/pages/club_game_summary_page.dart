import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/socket_service.dart';
import '../../data/services/game_draft_repository.dart';
import '../../data/services/game_save_service.dart';

/// 클럽 게임 종료 후 참가자 전원의 통합 결과를 보여주는 페이지입니다.
///
/// - 우승자 배너: 트로피 + 닉네임 + 최종 점수
/// - 순위표: 참가자 전원의 점수 순위 (실시간 갱신)
/// - 내 스코어카드: 프레임별 점수 상세
/// - 내 경기 통계: 스트라이크/스페어/오픈 수
/// - 내 경기 저장: 본인 게임만 서버에 저장
class ClubGameSummaryPage extends StatefulWidget {
  final List<List<int>> frames;
  final List<int?> cumulativeScores;
  final int totalScore;
  final int strikeCount;
  final int spareCount;
  final int openCount;
  final String? location;
  final String? roomId;
  final String userId;
  final List<Map<String, dynamic>> participants;
  final Map<String, int> participantScores;
  // 참가자별 통계 {userId: (strikes, spares, opens)}. 기본값 제공으로 선택.
  final Map<String, ({int strikes, int spares, int opens})> participantStats;
  // 실제 게임 시작 시각. play_date로 사용해 저장 시각 왜곡을 방지.
  final DateTime? gameStartedAt;

  const ClubGameSummaryPage({
    super.key,
    required this.frames,
    required this.cumulativeScores,
    required this.totalScore,
    required this.strikeCount,
    required this.spareCount,
    required this.openCount,
    required this.userId,
    required this.participants,
    required this.participantScores,
    this.participantStats = const {},
    this.location,
    this.roomId,
    this.gameStartedAt,
  });

  @override
  State<ClubGameSummaryPage> createState() => _ClubGameSummaryPageState();
}

class _ClubGameSummaryPageState extends State<ClubGameSummaryPage> {
  final SocketService _socketService = SocketService();
  final GameSaveService _saveService = GameSaveService();
  final GameDraftRepository _draftRepo = GameDraftRepository();
  late Map<String, int> _scores;
  late Map<String, ({int strikes, int spares, int opens})> _stats;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _scores = Map<String, int>.from(widget.participantScores);
    _scores[widget.userId] = widget.totalScore;
    _stats = Map<String, ({int strikes, int spares, int opens})>.from(
      widget.participantStats,
    );
    _stats[widget.userId] = (
      strikes: widget.strikeCount,
      spares: widget.spareCount,
      opens: widget.openCount,
    );
    _setupSocketListener();
  }

  void _setupSocketListener() {
    if (widget.roomId == null) return;
    _socketService.on('roomStateUpdated', (data) {
      if (!mounted) return;
      if (data['participants'] != null) {
        final ps = data['participants'] as Map<String, dynamic>;
        setState(() {
          for (final uid in ps.keys) {
            if (uid == widget.userId) continue;
            final p = ps[uid];
            final score = p?['score'];
            if (score is int) _scores[uid] = score;
            _stats[uid] = (
              strikes: (p?['strikes'] as int?) ?? _stats[uid]?.strikes ?? 0,
              spares: (p?['spares'] as int?) ?? _stats[uid]?.spares ?? 0,
              opens: (p?['opens'] as int?) ?? _stats[uid]?.opens ?? 0,
            );
          }
        });
      }
    });
  }

  /// 동일 프레임 내 투구 표시 문자열 (X, /, -, 숫자)
  String _getThrowDisplay(int frameIndex, int throwIndex) {
    final frame = widget.frames[frameIndex];
    if (throwIndex >= frame.length) return '';

    final pins = frame[throwIndex];

    if (frameIndex < 9) {
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1 && frame[0] + pins == 10) return '/';
    } else {
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1) {
        if (frame[0] == 10 && pins == 10) return 'X';
        if (frame[0] == 10) return pins == 0 ? '-' : '$pins';
        if (frame[0] + pins == 10) return '/';
      }
      if (throwIndex == 2) {
        if (pins == 10) return 'X';
        if (frame.length == 3) {
          if (frame[1] != 10 && frame[0] == 10 && frame[1] + pins == 10) return '/';
          if (frame[0] + frame[1] == 10 && pins == 10) return 'X';
        }
      }
    }

    return pins == 0 ? '-' : '$pins';
  }

  /// 내 경기 저장 API 호출
  /// GameSaveService로 재시도·에러 분류를 위임하고, 최종 실패 시 재시도 시트를 노출.
  Future<void> _saveGame() async {
    if (_isSaving) return; // 중복 제출 방어
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId == null) {
        if (mounted) {
          await _showFailureSheet('로그인된 사용자 정보가 없습니다. 다시 로그인 후 시도해주세요.');
        }
        return;
      }

      final mappedFrames = <Map<String, dynamic>>[];
      for (int i = 0; i < widget.frames.length; i++) {
        final frame = widget.frames[i];
        if (frame.isEmpty) continue;
        mappedFrames.add({
          'frame_number': i + 1,
          'first_roll': frame[0],
          if (frame.length > 1) 'second_roll': frame[1],
          if (frame.length > 2) 'third_roll': frame[2],
          'score': widget.cumulativeScores[i] ?? 0,
        });
      }

      // 클럽 메타데이터: 본인 순위 + 방 코드 + 플래그를 함께 저장
      final myRank = _buildRanking()
          .firstWhere(
            (p) => p.isMe,
            orElse: () => const _RankedPlayer(
              userId: '',
              nickname: '',
              score: 0,
              isMe: true,
              rank: 0,
            ),
          )
          .rank;

      // DB의 play_date 컬럼이 MySQL DATE 타입(시간/타임존 없음)이라
      // 사용자의 로컬 날짜를 yyyy-MM-dd 문자열로 보내는 게 가장 안전 (자정 경계 왜곡 방지)
      final playDate = DateFormat('yyyy-MM-dd')
          .format(widget.gameStartedAt ?? DateTime.now());

      final payload = <String, dynamic>{
        'user_id': userId,
        'total_score': widget.totalScore,
        'play_date': playDate,
        if (widget.location != null && widget.location!.isNotEmpty)
          'location': widget.location,
        'frames': mappedFrames,
        'is_club_game': true,
        if (widget.roomId != null) 'room_id': widget.roomId,
        if (myRank > 0) 'club_rank': myRank,
        // 실제 플레이 시작·종료 시각 (UTC ISO). 소요 시간 통계에 활용.
        if (widget.gameStartedAt != null)
          'started_at': widget.gameStartedAt!.toUtc().toIso8601String(),
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      };

      // 재시도 루프: GameSaveService 내부 3회 자동 재시도 후,
      // 최종 실패 시 사용자에게 수동 재시도 기회를 준다.
      while (true) {
        final result = await _saveService.saveGame(payload: payload);
        if (!mounted) return;

        if (result.success) {
          _isSaved = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('경기가 성공적으로 저장되었습니다.')),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        // 체험판 만료는 재시도/드래프트 무의미 → 전용 모달 후 복귀
        if (result.errorType == GameSaveErrorType.trialExpired) {
          await _showTrialExpiredDialog(result.errorMessage);
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }

        final shouldRetry = await _showFailureSheet(
          result.errorMessage ?? '저장에 실패했습니다.',
          showRetry: true,
        );
        if (!mounted) return;
        if (!shouldRetry) {
          // 사용자가 "취소"를 선택한 경우에도 데이터 유실 방지:
          // 로컬 드래프트에 보관 → 다음 앱 실행/홈 진입 시 자동 재시도됨.
          await _draftRepo.addDraft(payload);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('임시 저장했습니다. 네트워크 복구 후 자동으로 재시도됩니다.'),
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// 체험판 만료 전용 안내 다이얼로그. 드래프트 저장/재시도 없이 홈으로 복귀시킨다.
  Future<void> _showTrialExpiredDialog(String? message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('체험판이 만료되었습니다'),
        content: Text(
          message ??
              '클럽 체험판이 만료되어 새 클럽 게임을 저장할 수 없습니다.\n관리자 문의 후 다시 시도해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  /// 저장 실패 시트. [showRetry]면 "다시 시도" 버튼 포함.
  /// 반환값은 사용자가 재시도를 선택했는지 여부.
  Future<bool> _showFailureSheet(String message, {bool showRetry = false}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Symbols.cloud_off, color: Colors.red, size: 28),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '저장에 실패했습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        showRetry ? '취소' : '확인',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                if (showRetry) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Symbols.refresh,
                            color: Colors.white, size: 20),
                        label: const Text(
                          '다시 시도',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// 저장하지 않고 나가기 확인 시트 (GameSummaryPage와 동일 디자인)
  Future<bool> _showExitConfirmDialog() async {
    if (_isSaved) return true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Symbols.warning, color: Colors.orange, size: 28),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '경기가 저장되지 않았습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '저장하지 않고 나가면 내 기록이 사라집니다.',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        '취소',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '나가기',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  /// 현재 점수를 기반으로 순위 리스트 생성 (동점자는 같은 순위)
  List<_RankedPlayer> _buildRanking() {
    final entries = <_RankedPlayer>[];
    for (final p in widget.participants) {
      final uid = p['userId']?.toString() ?? '';
      final nickname = p['nickname']?.toString() ?? '?';
      final isMe = uid == widget.userId;
      final score = isMe ? widget.totalScore : (_scores[uid] ?? 0);
      final stat = _stats[uid] ??
          (
            strikes: isMe ? widget.strikeCount : 0,
            spares: isMe ? widget.spareCount : 0,
            opens: isMe ? widget.openCount : 0,
          );
      entries.add(_RankedPlayer(
        userId: uid,
        nickname: nickname,
        score: score,
        isMe: isMe,
        strikes: stat.strikes,
        spares: stat.spares,
        opens: stat.opens,
      ));
    }
    entries.sort((a, b) => b.score.compareTo(a.score));

    final ranked = <_RankedPlayer>[];
    int currentRank = 1;
    int? prevScore;
    for (int i = 0; i < entries.length; i++) {
      if (prevScore != null && entries[i].score < prevScore) {
        currentRank = i + 1;
      }
      ranked.add(entries[i].withRank(currentRank));
      prevScore = entries[i].score;
    }
    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy년 MM월 dd일').format(now);
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    final ranking = _buildRanking();
    final winner = ranking.isNotEmpty ? ranking.first : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // 저장 중일 땐 race condition 방지 위해 back 동작 차단
        if (_isSaving) return;
        final shouldLeave = await _showExitConfirmDialog();
        if (shouldLeave && mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Symbols.arrow_back, color: textColor),
            onPressed: _isSaving
                ? null
                : () async {
              final shouldLeave = await _showExitConfirmDialog();
              if (shouldLeave && mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
          ),
          title: Text(
            '클럽 경기 요약',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    if (winner != null) _buildWinnerBanner(winner, isDark),
                    const SizedBox(height: 12),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildLeaderboard(ranking, isDark),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '내 스코어카드',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildScorecard(isDark),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '내 경기 통계',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildStatBox(
                            '${widget.strikeCount}', '스트라이크', 'X', Colors.blue, isDark),
                        const SizedBox(width: 12),
                        _buildStatBox(
                            '${widget.spareCount}', '스페어', '/', Colors.purple, isDark),
                        const SizedBox(width: 12),
                        _buildStatBox(
                            '${widget.openCount}', '오픈', '-', Colors.amber, isDark),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: _buildActionButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 우승자 배너: 트로피 아이콘 + 닉네임 + 점수
  Widget _buildWinnerBanner(_RankedPlayer winner, bool isDark) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(
              Symbols.emoji_events,
              color: Colors.amber,
              size: 40,
              fill: 1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '우승',
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                winner.nickname,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (winner.isMe)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '나',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${winner.score}',
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 64,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ],
    );
  }

  /// 순위표 카드
  Widget _buildLeaderboard(List<_RankedPlayer> ranking, bool isDark) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '순위표',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '${ranking.length}명 참가',
                  style: const TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: ranking.length,
            // row 자체가 카드 형태라 divider 제거하고 작은 간격만 유지
            separatorBuilder: (_, __) => const SizedBox(height: 2),
            itemBuilder: (context, index) =>
                _buildLeaderboardRow(ranking[index], isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardRow(_RankedPlayer r, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final rankColor = _rankColor(r.rank);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          // 본인 행만 배경 틴트 + 프라이머리 보더로 강조
          color: r.isMe
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: r.isMe
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 순위 배지
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: rankColor.withValues(alpha: 0.3)),
                  ),
                  child: r.rank <= 3
                      ? Icon(
                          Symbols.emoji_events,
                          color: rankColor,
                          size: 18,
                          fill: r.rank == 1 ? 1 : 0,
                        )
                      : Text(
                          '${r.rank}',
                          style: TextStyle(
                            color: rankColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // 아바타
                CircleAvatar(
                  radius: 16,
                  backgroundColor: r.isMe
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : (isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.04)),
                  child: Text(
                    r.nickname.isNotEmpty ? r.nickname[0] : '?',
                    style: TextStyle(
                      color: r.isMe
                          ? AppColors.primary
                          : (isDark ? Colors.white70 : Colors.black54),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // 닉네임 + "나" 배지 (본인은 큰 글자 + primary 색상)
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.nickname,
                          style: TextStyle(
                            fontSize: r.isMe ? 16 : 15,
                            fontWeight: r.isMe
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: r.isMe ? AppColors.primary : textColor,
                          ),
                        ),
                        if (r.isMe)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '나',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 점수 (본인은 한 단계 큰 글자)
                Text(
                  '${r.score}',
                  style: TextStyle(
                    fontSize: r.isMe ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    color: r.isMe ? AppColors.primary : textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 통계 뱃지 (아바타 아래 들여쓰기 정렬)
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Row(
                children: [
                  _buildStatChip('X', r.strikes, Colors.blue),
                  const SizedBox(width: 6),
                  _buildStatChip('/', r.spares, Colors.purple),
                  const SizedBox(width: 6),
                  _buildStatChip('-', r.opens, Colors.amber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 순위표 row 안의 통계 뱃지 (스트라이크/스페어/오픈 1개씩)
  Widget _buildStatChip(String symbol, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.blueGrey.shade300;
      case 3:
        return Colors.brown.shade300;
      default:
        return AppColors.textSecondaryDark;
    }
  }

  /// 내 스코어카드 (GameSummaryPage와 동일한 5x2 그리드 레이아웃)
  Widget _buildScorecard(bool isDark) {
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.black12;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '프레임 상세',
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '총 ${widget.totalScore}점',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.75,
            ),
            itemCount: 10,
            itemBuilder: (context, index) {
              final scoreText = widget.cumulativeScores[index]?.toString() ?? '';
              final frameSlotCount = index == 9 ? 3 : 2;
              final isLastFrame = index == 9;

              return Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  color: isLastFrame
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : null,
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: List.generate(frameSlotCount, (tIndex) {
                          final display = _getThrowDisplay(index, tIndex);
                          final isStrikeOrSpare = display == 'X' || display == '/';
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              display,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isStrikeOrSpare
                                    ? AppColors.primary
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        scoreText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isLastFrame
                              ? AppColors.primary
                              : (isDark ? Colors.white : AppColors.textPrimaryLight),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 통계 박스 (GameSummaryPage와 동일 디자인)
  Widget _buildStatBox(
      String value, String label, String symbol, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  symbol,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveGame,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                '내 경기 저장하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// 순위 한 항목을 담는 내부 데이터 객체
class _RankedPlayer {
  final String userId;
  final String nickname;
  final int score;
  final bool isMe;
  final int rank;
  final int strikes;
  final int spares;
  final int opens;

  const _RankedPlayer({
    required this.userId,
    required this.nickname,
    required this.score,
    required this.isMe,
    this.rank = 0,
    this.strikes = 0,
    this.spares = 0,
    this.opens = 0,
  });

  _RankedPlayer withRank(int rank) => _RankedPlayer(
        userId: userId,
        nickname: nickname,
        score: score,
        isMe: isMe,
        rank: rank,
        strikes: strikes,
        spares: spares,
        opens: opens,
      );
}
