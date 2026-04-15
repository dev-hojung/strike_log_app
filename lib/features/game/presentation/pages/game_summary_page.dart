import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/services/game_draft_repository.dart';
import '../../data/services/game_save_service.dart';
import 'package:intl/intl.dart';

/// 볼링 게임 종료 후 결과를 보여주는 요약 페이지입니다.
///
/// 주요 기능:
/// - 총점(Total Score) 및 게임 날짜 표시
/// - 스코어카드(Scorecard) 상세 내역 표시
/// - 주요 통계(스트라이크, 스페어, 오픈 수) 표시
/// - 게임 저장 기능 제공
class GameSummaryPage extends StatefulWidget {
  final List<List<int>> frames;
  final List<int?> cumulativeScores;
  final int totalScore;
  final int strikeCount;
  final int spareCount;
  final int openCount;
  final String? location;
  // 실제 게임 시작 시각. play_date로 사용해 저장 시각 왜곡을 방지.
  // 생략되면 DateTime.now() 사용 (backward compat).
  final DateTime? gameStartedAt;

  const GameSummaryPage({
    super.key,
    required this.frames,
    required this.cumulativeScores,
    required this.totalScore,
    required this.strikeCount,
    required this.spareCount,
    required this.openCount,
    this.location,
    this.gameStartedAt,
  });

  @override
  State<GameSummaryPage> createState() => _GameSummaryPageState();
}

class _GameSummaryPageState extends State<GameSummaryPage> {
  final GameSaveService _saveService = GameSaveService();
  final GameDraftRepository _draftRepo = GameDraftRepository();
  bool _isSaving = false;
  bool _isSaved = false;

  String _getThrowDisplay(int frameIndex, int throwIndex) {
    final frame = widget.frames[frameIndex];
    if (throwIndex >= frame.length) return '';

    final pins = frame[throwIndex];

    if (frameIndex < 9) {
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1 && frame[0] + pins == 10) return '/';
    } else {
      // 10프레임
      if (throwIndex == 0 && pins == 10) return 'X';
      if (throwIndex == 1) {
        if (frame[0] == 10 && pins == 10) return 'X';
        if (frame[0] == 10) return pins == 0 ? '-' : '$pins';
        if (frame[0] + pins == 10) return '/';
      }
      if (throwIndex == 2) {
        if (pins == 10) return 'X';
        // 2투 후 스페어 체크
        if (throwIndex == 2 && frame.length == 3) {
          if (frame[1] != 10 && frame[0] == 10 && frame[1] + pins == 10) return '/';
          if (frame[0] + frame[1] == 10 && pins == 10) return 'X';
        }
      }
    }

    return pins == 0 ? '-' : '$pins';
  }

  /// 게임 저장: GameSaveService를 통해 재시도·에러 분류 포함하여 POST.
  /// 실패 시 스낵바가 아닌 재시도 시트를 띄워 데이터 유실을 방지.
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
      };

      // 재시도 루프: 자동 재시도 3회까지, 최종 실패 시 사용자에게 재시도 기회 제공
      while (true) {
        final result = await _saveService.saveGame(payload: payload);
        if (!mounted) return;

        if (result.success) {
          _isSaved = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('게임이 성공적으로 저장되었습니다.')),
          );
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
            // 핸들 바
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 경고 아이콘
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
              '저장하지 않고 나가면 기록이 사라집니다.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            // 버튼 영역
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy년 MM월 dd일').format(now);
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

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
          '경기 요약',
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
                  const SizedBox(height: 16),
                  // 최종 점수 헤더
                  const Text(
                    '최종 점수',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.totalScore}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 날짜 정보
                  Text(
                    formattedDate,
                    style: const TextStyle(
                      color: AppColors.textSecondaryDark,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // 스코어카드 상세
                  _buildScorecard(isDark),
                  const SizedBox(height: 40),
                  
                  // 경기 통계 섹션 제목
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '경기 통계',
                      style: TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 통계 박스 목록
                  Row(
                    children: [
                      _buildStatBox('${widget.strikeCount}', '스트라이크', 'X', Colors.blue, isDark),
                      const SizedBox(width: 12),
                      _buildStatBox('${widget.spareCount}', '스페어', '/', Colors.purple, isDark),
                      const SizedBox(width: 12),
                      _buildStatBox('${widget.openCount}', '오픈', '-', Colors.amber, isDark),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // 하단 버튼 고정 영역
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _buildActionButtons(),
            ),
          ),
        ],
      ),
    ));
  }

  /// 프레임별 점수를 보여주는 스코어카드 위젯입니다.
  ///
  /// 1~10 프레임의 점수를 그리드 형태로 표시합니다.
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
              color: isDark ? Colors.white.withValues(alpha:0.03) : Colors.black.withValues(alpha:0.02),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Text(
              '스코어카드',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
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
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha:0.05) : Colors.black.withValues(alpha:0.05)),
                  color: isLastFrame ? AppColors.primary.withValues(alpha:0.05) : null,
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

  /// 게임의 주요 통계(스트라이크, 스페어 등)를 박스 형태로 보여주는 위젯입니다.
  Widget _buildStatBox(String value, String label, String symbol, Color color, bool isDark) {
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
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
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

  /// 게임 저장 버튼을 포함하는 위젯입니다.
  Widget _buildActionButtons() {
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
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                '경기 저장하기',
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
