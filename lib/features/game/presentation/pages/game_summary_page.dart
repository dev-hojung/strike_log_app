import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/share_capture.dart';
import '../../../../core/services/user_profile_cache.dart';
import '../../../badges/presentation/widgets/new_badges_dialog.dart';
import '../../../home/presentation/pages/home_dashboard_page.dart';
import '../../data/bowling_scorer.dart';
import '../../data/services/game_draft_repository.dart';
import '../../data/services/game_save_service.dart';
import '../../data/services/series_api_service.dart';
import 'frame_entry_page.dart';
import 'series_summary_page.dart';
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

  /// 시리즈에 속한 게임이면 시리즈 ID. 단일 게임은 null.
  final int? seriesId;

  /// 시리즈 내 현재 게임 순번(1-based). 단일 게임은 null.
  final int? seriesIndex;

  /// 시리즈 총 게임 수. 단일 게임은 null.
  final int? targetGameCount;

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
    this.seriesId,
    this.seriesIndex,
    this.targetGameCount,
  });

  /// 시리즈 중간 게임 여부(다음 게임이 남아 있는지).
  bool get hasNextSeriesGame =>
      seriesId != null &&
      seriesIndex != null &&
      targetGameCount != null &&
      seriesIndex! < targetGameCount!;

  /// 시리즈의 마지막 게임 여부(저장 후 completeSeries 호출 대상).
  bool get isFinalSeriesGame =>
      seriesId != null &&
      seriesIndex != null &&
      targetGameCount != null &&
      seriesIndex! >= targetGameCount!;

  @override
  State<GameSummaryPage> createState() => _GameSummaryPageState();
}

class _GameSummaryPageState extends State<GameSummaryPage> {
  final GameSaveService _saveService = GameSaveService();
  final GameDraftRepository _draftRepo = GameDraftRepository();
  final GlobalKey _shareKey = GlobalKey();
  bool _isSaving = false;
  bool _isSaved = false;
  bool _isSharing = false;

  Future<void> _shareResult() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final ok = await ShareCapture.sharePng(
        key: _shareKey,
        filename: 'game-${widget.totalScore}',
        text: '볼링 ${widget.totalScore}점 🎳',
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유에 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // 페이지 진입 시 기준이 되는 "이전 최고 점수" 스냅샷.
  // 진입 시점에 한 번만 캡처해서, 저장으로 캐시가 갱신되어도 배너가 사라지지 않도록 한다.
  late final int? _previousBest = HomeDashboardPage.cachedHighestScore;

  late final int _streak =
      BowlingScorer.longestStrikeStreak(widget.frames);

  bool _isNewBest() {
    final prev = _previousBest;
    // 캐시 없거나 첫 게임이면 비교 불가
    if (prev == null || prev <= 0) return false;
    return widget.totalScore > prev;
  }

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

      // 서버는 JWT 토큰의 user.id로 식별. user_id 동봉 불필요.
      final payload = <String, dynamic>{
        'total_score': widget.totalScore,
        'play_date': playDate,
        if (widget.location != null && widget.location!.isNotEmpty)
          'location': widget.location,
        'frames': mappedFrames,
        // 실제 플레이 시작·종료 시각 (UTC ISO). 소요 시간 통계에 활용.
        if (widget.gameStartedAt != null)
          'started_at': widget.gameStartedAt!.toUtc().toIso8601String(),
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        // 시리즈 게임이면 시리즈 정보 함께 전달
        if (widget.seriesId != null) 'series_id': widget.seriesId,
        if (widget.seriesIndex != null) 'series_index': widget.seriesIndex,
      };

      // 재시도 루프: 자동 재시도 3회까지, 최종 실패 시 사용자에게 재시도 기회 제공
      while (true) {
        final result = await _saveService.saveGame(payload: payload);
        if (!mounted) return;

        if (result.success) {
          _isSaved = true;
          await _afterSaveSuccess(result);
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

  /// 저장 성공 후 흐름 분기.
  /// - 시리즈 중간 게임이면: "다음 게임 진행" 다이얼로그
  /// - 시리즈 마지막 게임이면: completeSeries 호출 후 루트로 복귀
  /// - 단일 게임이면: 그대로 루트로 복귀
  Future<void> _afterSaveSuccess(GameSaveResult result) async {
    if (!mounted) return;
    // 신규 배지가 있으면 다른 분기보다 먼저 모달로 노출 (확인 후 정상 흐름 진행).
    await NewBadgesDialog.showIfAny(context, result.newlyEarnedBadges);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('게임이 성공적으로 저장되었습니다.')),
    );

    // 광고 표시 후 기존 네비게이션 흐름을 onClose 콜백으로 실행.
    final isPlatformAdmin =
        UserProfileCache.cached?['is_platform_admin'] == true;
    await AdsService.instance.maybeShowInterstitial(
      isPlatformAdmin: isPlatformAdmin,
      onClose: () => _navigateAfterSave(result),
    );
  }

  /// 광고 닫힘(또는 면제) 후 실제 네비게이션을 수행.
  Future<void> _navigateAfterSave(GameSaveResult result) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (widget.hasNextSeriesGame) {
      final shouldContinue = await _askContinueSeries();
      if (!mounted) return;
      if (shouldContinue) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FrameEntryPage(
              isClubGame: false,
              location: widget.location,
              seriesId: widget.seriesId,
              seriesIndex: widget.seriesIndex! + 1,
              targetGameCount: widget.targetGameCount,
            ),
          ),
        );
        return;
      }
      // 중도 종료 선택: 시리즈 명시 종료 후 루트로
      unawaited(SeriesApiService().completeSeries(widget.seriesId!));
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (widget.isFinalSeriesGame) {
      try {
        await SeriesApiService().completeSeries(widget.seriesId!);
      } catch (_) {
        // 종료 실패해도 사용자 흐름 막지 않음 (다음 진입 시 재시도)
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('시리즈가 완료되었습니다.')),
      );
      // 시리즈 결과 페이지로 교체 → 뒤로가기 시 루트로 직행
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SeriesSummaryPage(seriesId: widget.seriesId!),
        ),
        (route) => route.isFirst,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool> _askContinueSeries() async {
    final next = (widget.seriesIndex ?? 0) + 1;
    final total = widget.targetGameCount ?? 0;
    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('다음 게임을 시작할까요?'),
        content: Text('$next / $total 게임으로 이어집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('계속하기'),
          ),
        ],
      ),
    );
    return answer ?? false;
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
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32 + MediaQuery.of(context).viewPadding.bottom),
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
        padding: EdgeInsets.fromLTRB(24, 8, 24, 32 + MediaQuery.of(context).viewPadding.bottom),
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
        if (shouldLeave && context.mounted) {
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
                  if (shouldLeave && context.mounted) {
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
        actions: [
          IconButton(
            icon: Icon(Symbols.share, color: textColor),
            tooltip: '결과 공유',
            onPressed: _isSharing ? null : _shareResult,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: RepaintBoundary(
                key: _shareKey,
                child: Container(
                  color: bgColor,
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
                  
                  // 베스트 갱신 배너 (이전 최고점 대비 갱신 시)
                  if (_isNewBest()) ...[
                    _buildBestUpdateBanner(),
                    const SizedBox(height: 24),
                  ],

                  // 스코어카드 상세
                  _buildScorecard(isDark),
                  const SizedBox(height: 32),

                  // 최장 연속 스트라이크 하이라이트 (2연속 이상일 때만 노출)
                  if (_streak >= 2) ...[
                    _buildStreakHighlight(isDark, _streak),
                    const SizedBox(height: 24),
                  ],

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
  Widget _buildBestUpdateBanner() {
    final prev = _previousBest ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6F00).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Symbols.emoji_events, color: Colors.white, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '베스트 게임 갱신!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '이전 최고 $prev점 → 이번 ${widget.totalScore}점',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakHighlight(bool isDark, int streak) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.local_fire_department,
                color: Colors.deepOrange, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '최장 연속 스트라이크',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak >= 3 ? '$streak연속 🔥' : '$streak연속',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
