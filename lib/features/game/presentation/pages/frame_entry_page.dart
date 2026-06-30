import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../data/bowling_scorer.dart';
import 'bet_result_page.dart';
import 'club_game_summary_page.dart';
import 'game_summary_page.dart';

/// 볼링 게임의 점수를 입력하는 페이지입니다.
///
/// 사용자는 이 페이지에서 각 프레임의 투구 결과를 입력하고,
/// 실시간으로 총점과 프레임별 점수를 확인할 수 있습니다.
/// [isClubGame]이 true이면 소켓을 통해 다른 참가자들과 점수를 공유합니다.
class FrameEntryPage extends StatefulWidget {
  final bool isClubGame;
  final String? roomId;
  final List<Map<String, dynamic>>? participants;
  final String? location;

  /// 시리즈에 속한 게임인 경우 시리즈 ID. 단일 게임은 null.
  final int? seriesId;

  /// 시리즈 내 게임 순번 (1-based). 단일 게임은 null.
  final int? seriesIndex;

  /// 시리즈 총 게임 수. 단일 게임은 null.
  final int? targetGameCount;

  /// 내기 게임 여부 (POST /games 에 is_bet_game 전달, finishGame 호출에 사용)
  final bool isBetGame;

  /// 내기 게임에서 방장 여부 (finishGame 호출 주체 결정)
  final bool isHost;

  /// 정기전에서 시작한 게임인 경우 정기전 ID. 일반 게임은 null.
  final int? eventId;

  const FrameEntryPage({
    super.key,
    this.isClubGame = false,
    this.roomId,
    this.participants,
    this.location,
    this.seriesId,
    this.seriesIndex,
    this.targetGameCount,
    this.isBetGame = false,
    this.isHost = false,
    this.eventId,
  });

  @override
  State<FrameEntryPage> createState() => _FrameEntryPageState();
}

class _FrameEntryPageState extends State<FrameEntryPage> {
  // 각 프레임의 투구 기록 (10프레임, 각 프레임 최대 3투구)
  final List<List<int>> _frames = List.generate(10, (_) => <int>[]);

  // 활성 프레임이 화면 밖으로 사라지지 않도록 자동 스크롤을 제어하는 컨트롤러
  final ScrollController _frameScrollController = ScrollController();

  // 현재 선택된 프레임 인덱스 (0~9)
  int _currentFrame = 0;

  // 현재 프레임에서의 투구 순서 (0: 1투, 1: 2투, 2: 10프레임 3투)
  int _currentThrow = 0;

  // 게임 완료 여부
  bool _isGameComplete = false;

  // 키패드 표시 여부
  bool _showKeypad = false;

  // 실제 플레이 시작 시각 (저장 시 play_date로 사용해 저장 시각 왜곡 방지)
  final DateTime _gameStartedAt = DateTime.now();

  // 클럽 게임: 소켓 서비스 및 다른 참가자 점수
  final SocketService _socketService = SocketService();
  String _userId = '';
  // 참가자별 총점 {userId: totalScore}
  final Map<String, int> _participantScores = {};
  // 참가자별 통계 {userId: (strikes, spares, opens)} - 순위표 라이브 표시용
  final Map<String, ({int strikes, int spares, int opens})> _participantStats = {};
  // gameEnded 이벤트 중복 처리 방지
  bool _gameEndedHandled = false;
  // widget.participants를 방어적으로 deep copy하여 보관.
  // (game_room_page의 원본 리스트가 라이프사이클 이벤트로 비워지더라도 영향받지 않도록)
  late final List<Map<String, dynamic>> _participants = widget.participants == null
      ? <Map<String, dynamic>>[]
      : widget.participants!
          .map((p) => Map<String, dynamic>.from(p))
          .toList();

  @override
  void initState() {
    super.initState();
    if (widget.isClubGame) {
      _initClubGame();
    }
    // 개인 게임 또는 내기 게임이면 결과 화면 도달 전에 광고 미리 로드.
    // 클럽 게임(비내기)은 광고 없음.
    if (!widget.isClubGame || widget.isBetGame) {
      AdsService.instance.preloadInterstitial();
    }
  }

  Future<void> _initClubGame() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? '';

    // 참가자 초기 점수 설정
    for (final p in _participants) {
      _participantScores[p['userId']?.toString() ?? ''] = 0;
    }

    // 방 상태 업데이트 수신 (점수/통계 변경 포함)
    _socketService.on('roomStateUpdated', (data) {
      if (!mounted) return;
      if (data['participants'] == null) return;
      final participants = data['participants'] as Map<String, dynamic>;
      setState(() {
        final serverKeys = participants.keys.toSet();
        // 서버에 없는 참가자 제거 (퇴장/연결 끊김 반영)
        _participantScores.removeWhere((k, _) => !serverKeys.contains(k));
        _participantStats.removeWhere((k, _) => !serverKeys.contains(k));
        _participants.removeWhere((p) {
          final uid = p['userId']?.toString() ?? '';
          return uid.isNotEmpty && !serverKeys.contains(uid);
        });
        // 서버 정보로 갱신 (본인 제외)
        for (final userId in participants.keys) {
          if (userId == _userId) continue;
          final p = participants[userId];
          _participantScores[userId] = (p?['score'] as int?) ?? 0;
          _participantStats[userId] = (
            strikes: (p?['strikes'] as int?) ?? 0,
            spares: (p?['spares'] as int?) ?? 0,
            opens: (p?['opens'] as int?) ?? 0,
          );
        }
      });
    });

    // 내기 게임: 방장이 아닌 참가자가 gameEnded 이벤트를 받아 BetResultPage로 이동
    if (widget.isBetGame) {
      _socketService.off('gameEnded');
      _socketService.on('gameEnded', (data) {
        if (!mounted || _gameEndedHandled) return;
        // P1-4: 다른 방의 이벤트 무시
        if (widget.roomId != null && data['roomId'] != null && data['roomId'] != widget.roomId) return;
        _gameEndedHandled = true;
        final rankings = (data['rankings'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BetResultPage(
              rankings: rankings,
              betMemo: data['betMemo'] as String?,
            ),
          ),
        );
      });
    }
  }

  /// 현재 프레임 데이터로 스트라이크/스페어/오픈 개수 계산
  /// (_navigateToSummary와 _emitScoreUpdate에서 공유)
  ({int strikes, int spares, int opens}) _computeStats() =>
      BowlingScorer.computeStats(_frames);

  @override
  void dispose() {
    _frameScrollController.dispose();
    if (widget.isClubGame) {
      _socketService.off('roomStateUpdated');
      if (widget.isBetGame) {
        _socketService.off('gameEnded');
      }
      // 클럽 게임 생명주기 종료 시 서버의 방에서 나가고 소켓 연결을 정리.
      // (ClubGameSummaryPage는 이미 dispose된 상태. popUntil의 마지막 단계)
      if (widget.roomId != null && _userId.isNotEmpty) {
        _socketService.leaveRoom(roomId: widget.roomId!, userId: _userId);
      }
      _socketService.disconnect();
    }
    super.dispose();
  }

  /// 활성 프레임이 가시 영역의 가운데로 오도록 스크롤한다.
  /// (입력 후 다음 프레임으로 진행될 때 호출)
  void _scrollToCurrentFrame() {
    if (!_frameScrollController.hasClients) return;
    const horizontalPadding = 24.0;
    const cardSpacing = 12.0;
    const normalCardWidth = 80.0;
    final cardWidth = _currentFrame == 9 ? 96.0 : normalCardWidth;
    final cardStart =
        horizontalPadding + _currentFrame * (normalCardWidth + cardSpacing);
    final viewportWidth = _frameScrollController.position.viewportDimension;
    final maxScroll = _frameScrollController.position.maxScrollExtent;
    final targetOffset =
        (cardStart + cardWidth / 2 - viewportWidth / 2).clamp(0.0, maxScroll);
    _frameScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// 소켓으로 점수 + 통계 업데이트 전송
  void _emitScoreUpdate() {
    if (!widget.isClubGame || widget.roomId == null) return;
    final stats = _computeStats();
    _socketService.sendScoreUpdate(
      roomId: widget.roomId!,
      userId: _userId,
      score: _totalScore,
      strikes: stats.strikes,
      spares: stats.spares,
      opens: stats.opens,
    );
  }

  /// 현재 프레임에서 남은 핀 수
  int get _remainingPins {
    final frame = _frames[_currentFrame];
    if (_currentFrame == 9) {
      // 10프레임 특수 처리
      if (_currentThrow == 0) return 10;
      if (_currentThrow == 1) {
        // 1투가 스트라이크면 다시 10핀
        if (frame[0] == 10) return 10;
        return 10 - frame[0];
      }
      if (_currentThrow == 2) {
        // 2투가 스페어였거나 1투가 스트라이크였으면 10핀
        if (frame[0] == 10 && frame[1] == 10) return 10;
        if (frame[0] == 10) return 10 - frame[1];
        return 10; // 스페어 후 3투
      }
    } else {
      if (_currentThrow == 0) return 10;
      if (_currentThrow == 1) return 10 - frame[0];
    }
    return 10;
  }

  /// 각 프레임의 누적 점수 계산
  List<int?> get _cumulativeScores => BowlingScorer.cumulativeScores(_frames);

  /// 총점
  int get _totalScore => BowlingScorer.totalScore(_frames);

  /// 해당 프레임이 완료되었는지 확인
  bool _isFrameComplete(int frameIndex) =>
      BowlingScorer.isFrameComplete(_frames, frameIndex);

  /// 키패드 입력 처리
  void _onKeyPress(String key) {
    if (_isGameComplete) return;

    setState(() {
      if (key == 'X') {
        _handleStrike();
      } else if (key == '/') {
        _handleSpare();
      } else if (key == '←') {
        _handleBackspace();
      } else {
        final pins = int.tryParse(key);
        if (pins != null) _handleNumber(pins);
      }
    });
    _emitScoreUpdate();
    // setState로 ListView가 다시 그려진 다음 프레임에 스크롤을 맞춰야 viewport 계산이 정확하다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentFrame());
  }

  void _handleStrike() {
    if (_currentFrame < 9) {
      // 1~9프레임: 1투에서만 스트라이크 가능
      if (_currentThrow != 0) return;
      _frames[_currentFrame] = [10];
      _advanceFrame();
    } else {
      // 10프레임
      if (_currentThrow == 0) {
        _frames[9].add(10);
        _currentThrow = 1;
      } else if (_currentThrow == 1 && _frames[9][0] == 10) {
        _frames[9].add(10);
        _currentThrow = 2;
      } else if (_currentThrow == 2) {
        // 보너스 투구 — _currentThrow == 2에 도달했다는 것은 이미 자격이 검증된 상태
        // (스페어든 더블이든 _handleNumber/_handleSpare에서 _currentThrow=2로 진입할 때만 자격이 부여됨)
        _frames[9].add(10);
        _checkGameComplete();
      }
    }
  }

  /// 현재 투구(_currentThrow)를 기록한다.
  /// 완료된 프레임을 다시 탭해 수정하는 경우 append 대신 해당 위치를 교체하고
  /// 그 뒤 투구는 잘라낸다 — 1~9프레임에 3투구가 쌓여 데이터가 손상되는 것을 방지.
  void _putThrow(int frame, int pins) {
    if (_currentThrow < _frames[frame].length) {
      _frames[frame] = _frames[frame].sublist(0, _currentThrow)..add(pins);
    } else {
      _frames[frame].add(pins);
    }
  }

  void _handleSpare() {
    if (_currentThrow == 0) return; // 1투에서 스페어 불가
    final remaining = _remainingPins;
    if (remaining <= 0 || remaining >= 10) return; // 0 또는 풀스택(=스트라이크)은 스페어 아님

    if (_currentFrame < 9) {
      _putThrow(_currentFrame, remaining);
      _advanceFrame();
    } else {
      _putThrow(9, remaining);
      if (_currentThrow == 1) {
        _currentThrow = 2;
      } else {
        _checkGameComplete();
      }
    }
  }

  void _handleNumber(int pins) {
    if (pins > _remainingPins) return;

    if (_currentFrame < 9) {
      _putThrow(_currentFrame, pins);
      if (_currentThrow == 0 && pins < 10) {
        _currentThrow = 1;
      } else {
        _advanceFrame();
      }
    } else {
      // 10프레임
      _putThrow(9, pins);
      if (_currentThrow == 0) {
        if (pins == 10) {
          _currentThrow = 1; // 스트라이크 → 2투로
        } else {
          _currentThrow = 1;
        }
      } else if (_currentThrow == 1) {
        if (_frames[9][0] == 10 || _frames[9][0] + pins == 10) {
          _currentThrow = 2; // 보너스 투구
        } else {
          _checkGameComplete();
        }
      } else {
        _checkGameComplete();
      }
    }
  }

  void _handleBackspace() {
    // 현재 프레임에서 마지막 투구 삭제
    if (_currentFrame == 9 && _frames[9].isNotEmpty) {
      _frames[9].removeLast();
      _currentThrow = _frames[9].length;
      _isGameComplete = false;
      return;
    }

    if (_currentThrow > 0 && _frames[_currentFrame].isNotEmpty) {
      _frames[_currentFrame].removeLast();
      _currentThrow = _frames[_currentFrame].length;
    } else if (_currentFrame > 0) {
      // 이전 프레임으로 돌아가기
      _currentFrame--;
      final prevFrame = _frames[_currentFrame];
      if (prevFrame.isNotEmpty) {
        prevFrame.removeLast();
        _currentThrow = prevFrame.length;
      }
    }
    _isGameComplete = false;
  }

  void _advanceFrame() {
    // 다음 미완성 프레임을 찾아 이동
    for (int i = _currentFrame + 1; i < 10; i++) {
      if (!_isFrameComplete(i)) {
        _currentFrame = i;
        _currentThrow = _frames[i].length;
        return;
      }
    }
    // 앞쪽에도 미완성 프레임이 있는지 확인
    for (int i = 0; i < _currentFrame; i++) {
      if (!_isFrameComplete(i)) {
        _currentFrame = i;
        _currentThrow = _frames[i].length;
        return;
      }
    }
    // 모든 프레임이 완료됨
    _checkGameComplete();
  }

  void _checkGameComplete() {
    if (_isFrameComplete(9)) {
      _isGameComplete = true;
    }
  }

  void _navigateToSummary() {
    final stats = _computeStats();

    if (widget.isClubGame && _participants.isNotEmpty) {
      // 내기 게임: ClubGameSummaryPage로 이동 후 저장 완료 시 finishGame 호출
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClubGameSummaryPage(
            frames: _frames,
            cumulativeScores: _cumulativeScores,
            totalScore: _totalScore,
            strikeCount: stats.strikes,
            spareCount: stats.spares,
            openCount: stats.opens,
            location: widget.location,
            roomId: widget.roomId,
            userId: _userId,
            participants: _participants,
            participantScores: Map<String, int>.from(_participantScores),
            participantStats: Map<String, ({int strikes, int spares, int opens})>.from(
              _participantStats,
            ),
            gameStartedAt: _gameStartedAt,
            isBetGame: widget.isBetGame,
            isHost: widget.isHost,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameSummaryPage(
            frames: _frames,
            cumulativeScores: _cumulativeScores,
            totalScore: _totalScore,
            strikeCount: stats.strikes,
            spareCount: stats.spares,
            openCount: stats.opens,
            location: widget.location,
            gameStartedAt: _gameStartedAt,
            seriesId: widget.seriesId,
            seriesIndex: widget.seriesIndex,
            targetGameCount: widget.targetGameCount,
            eventId: widget.eventId,
          ),
        ),
      );
    }
  }

  /// 프레임 탭 시 해당 프레임으로 이동 (수정 모드)
  /// 선택한 프레임으로 포커스만 이동하며, 데이터는 삭제하지 않습니다.
  void _onFrameTap(int frameIndex) {
    // 현재 프레임이거나, 데이터가 있거나, 이전 프레임이 완료된 경우 선택 가능
    if (_frames[frameIndex].isEmpty && frameIndex != _currentFrame) {
      // 이전 프레임들이 모두 완료되었으면 선택 허용
      bool previousComplete = true;
      for (int i = 0; i < frameIndex; i++) {
        if (!_isFrameComplete(i)) {
          previousComplete = false;
          break;
        }
      }
      if (!previousComplete) return;
    }

    setState(() {
      _currentFrame = frameIndex;
      _currentThrow = _frames[frameIndex].length;
      if (_currentFrame == 9 && _currentThrow == 3) {
        _currentThrow = 2; // 10프레임 완료 시 마지막 투구 가리키도록
      } else if (_currentFrame < 9 && _currentThrow == 2) {
        _currentThrow = 1; // 1-9프레임 완료 시 마지막 투구
      } else if (_currentFrame < 9 && _frames[frameIndex].isNotEmpty && _frames[frameIndex][0] == 10) {
        _currentThrow = 0; // 1-9프레임 스트라이크 시 1구로
      } else if (_currentFrame == 9 && _currentThrow == 2 && _isFrameComplete(9)) {
        _currentThrow = 1; // 10프레임 오픈 완료 → 마지막 투구 수정 위치로 (append 방지)
      }
      _showKeypad = true;
      _isGameComplete = false;
    });
  }

  /// 프레임의 투구 표시 문자열
  String _getThrowDisplay(int frameIndex, int throwIndex) {
    final frame = _frames[frameIndex];
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

  /// 해당 프레임에 표시할 투구 칸 수
  int _getThrowSlotCount(int frameIndex) {
    return frameIndex == 9 ? 3 : 2;
  }

  /// 어느 프레임이라도 1구 이상 입력됐다면 "진행 중"으로 간주.
  bool get _hasProgress => _frames.any((f) => f.isNotEmpty);

  /// 진행 중인 게임 종료 의사 확인.
  /// 입력된 점수가 없으면 즉시 true, 있으면 다이얼로그로 확정.
  Future<bool> _confirmExit() async {
    if (!_hasProgress) return true;
    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('게임을 종료할까요?'),
        content: const Text(
          '지금 나가면 입력한 점수가 저장되지 않고 사라집니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 진행'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmExit();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: Colors.white),
          onPressed: () async {
            final ok = await _confirmExit();
            if (ok && context.mounted) Navigator.pop(context);
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.isBetGame
                  ? '내기 게임'
                  : (widget.isClubGame ? '클럽 게임' : '개인 게임'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (widget.seriesId != null &&
                widget.seriesIndex != null &&
                widget.targetGameCount != null) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '시리즈 ${widget.seriesIndex}/${widget.targetGameCount}',
                  style: const TextStyle(
                    color: Color(0xFFFFB74D),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 상단 콘텐츠 (스크롤 없음, 탭하면 키패드 닫힘)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_showKeypad) setState(() => _showKeypad = false);
              },
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: _showKeypad ? 16 : 40),
                    // 총점 표시
                    Text(
                      '$_totalScore',
                      style: TextStyle(
                        fontSize: _showKeypad ? 40 : 64,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '총점',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryDark,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: _showKeypad ? 16 : 40),

                    // 프레임 스크롤 영역
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        controller: _frameScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: 10,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return _buildFrameCard(index);
                        },
                      ),
                    ),

                    SizedBox(height: _showKeypad ? 8 : 24),
                  ],
                ),
              ),
            ),
          ),

          // 클럽 게임 라이브 순위표 (다른 참가자 점수/통계 실시간 표시)
          if (widget.isClubGame && _participants.isNotEmpty) ...[
            _buildParticipantLiveBoard(),
            const SizedBox(height: 8),
          ],

          // 키패드 또는 결과 확인 버튼 (프레임 선택 시에만 표시)
          if (_isGameComplete)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '게임이 완료되었습니다!',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _navigateToSummary,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '결과 확인',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_showKeypad)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 현재 프레임 안내
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${_currentFrame + 1}프레임 · ${_currentThrow + 1}번째 투구 (남은 핀: $_remainingPins)',
                        style: const TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKey('X',
                            color: AppColors.primary,
                            isAction: true,
                            enabled: _canStrike),
                        _buildKey('0'),
                        _buildKey('/',
                            color: AppColors.primary,
                            isAction: true,
                            enabled: _canSpare),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKey('←',
                            color: Colors.red,
                            isAction: true,
                            enabled: _canBackspace),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Text(
                  '프레임을 선택하여 점수를 입력하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }

  /// 스트라이크 입력 가능 여부
  bool get _canStrike {
    if (_isGameComplete) return false;
    if (_currentFrame < 9) return _currentThrow == 0;
    // 10프레임
    if (_currentThrow == 0) return true;
    if (_currentThrow == 1 && _frames[9].isNotEmpty && _frames[9][0] == 10) return true;
    if (_currentThrow == 2) {
      if (_frames[9].length >= 2) {
        if (_frames[9][0] == 10 && _frames[9][1] == 10) return true;
        if (_frames[9][0] + _frames[9][1] == 10) return true;
      }
    }
    return false;
  }

  /// 스페어 입력 가능 여부
  bool get _canSpare {
    if (_isGameComplete) return false;
    if (_currentThrow == 0) return false;
    if (_currentFrame < 9) return _remainingPins > 0;
    // 10프레임: 2투나 3투에서 남은 핀이 있을 때
    return _remainingPins > 0 && _remainingPins < 10;
  }

  /// 백스페이스 가능 여부
  bool get _canBackspace {
    if (_currentFrame == 0 && _frames[0].isEmpty) return false;
    return true;
  }

  Widget _buildFrameCard(int index) {
    final isCurrent = index == _currentFrame && !_isGameComplete;
    final hasData = _frames[index].isNotEmpty;
    final scores = _cumulativeScores;

    return GestureDetector(
      onTap: () => _onFrameTap(index),
      child: Container(
        width: index == 9 ? 96 : 80,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? AppColors.primary
                : (hasData
                    ? AppColors.primary.withValues(alpha:0.4)
                    : AppColors.primary.withValues(alpha:0.2)),
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: isCurrent
              ? [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha:0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            // 프레임 번호
            Positioned(
              top: 0,
              left: 0,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isCurrent
                      ? AppColors.primary
                      : AppColors.textSecondaryDark,
                ),
              ),
            ),
            // 투구 결과
            Positioned(
              top: 0,
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_getThrowSlotCount(index), (t) {
                  final display = _getThrowDisplay(index, t);
                  final isStrikeOrSpare = display == 'X' || display == '/';
                  return Container(
                    width: 18,
                    height: 20,
                    alignment: Alignment.center,
                    margin: EdgeInsets.only(left: t > 0 ? 2 : 0),
                    decoration: BoxDecoration(
                      color: display.isEmpty
                          ? AppColors.surfaceDark.withValues(alpha:0.5)
                          : AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      display,
                      style: TextStyle(
                        fontSize: 12,
                        color: isStrikeOrSpare
                            ? AppColors.primary
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),
            ),
            // 누적 점수
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  scores[index]?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 클럽 게임 라이브 순위표 (가로 스크롤 컴팩트 카드)
  /// - 본인은 _totalScore/_computeStats(), 다른 참가자는 소켓 갱신 캐시 사용
  /// - 점수 내림차순 정렬, 본인 행은 primary 강조 + "나" 배지
  Widget _buildParticipantLiveBoard() {
    final myStats = _computeStats();
    final rows = _participants.map((p) {
      final uid = p['userId']?.toString() ?? '';
      final isMe = uid == _userId;
      final score = isMe ? _totalScore : (_participantScores[uid] ?? 0);
      final stats = isMe
          ? (strikes: myStats.strikes, spares: myStats.spares, opens: myStats.opens)
          : (_participantStats[uid] ??
              (strikes: 0, spares: 0, opens: 0));
      return (
        nickname: (p['nickname'] ?? '?').toString(),
        score: score,
        isMe: isMe,
        strikes: stats.strikes,
        spares: stats.spares,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final r = rows[index];
          final rank = index + 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: r.isMe
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: r.isMe
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : Colors.white12,
                width: r.isMe ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _rankBadgeColor(rank).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: _rankBadgeColor(rank),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          r.nickname,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                r.isMe ? FontWeight.w700 : FontWeight.w500,
                            color: r.isMe ? AppColors.primary : Colors.white,
                          ),
                        ),
                        if (r.isMe) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '나',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${r.score}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: r.isMe ? AppColors.primary : Colors.white,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _liveStatChip('X', r.strikes, Colors.blue),
                        const SizedBox(width: 4),
                        _liveStatChip('/', r.spares, Colors.purple),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _liveStatChip(String symbol, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$symbol$count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _rankBadgeColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.blueGrey.shade300;
      case 3:
        return Colors.brown.shade300;
      default:
        return Colors.white60;
    }
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: keys.map((k) {
        final pins = int.tryParse(k);
        final enabled =
            !_isGameComplete && (pins == null || pins <= _remainingPins);
        return _buildKey(k, enabled: enabled);
      }).toList(),
    );
  }

  Widget _buildKey(String label,
      {bool isAction = false, Color? color, bool enabled = true}) {
    final effectiveColor = enabled
        ? (isAction ? color : Colors.white)
        : Colors.white.withValues(alpha:0.2);

    return Expanded(
      child: Container(
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: !enabled
              ? const Color(0xFF111721).withValues(alpha:0.5)
              : isAction
                  ? (color?.withValues(alpha:0.15) ?? const Color(0xFF111721))
                  : const Color(0xFF111721),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: enabled ? () => _onKeyPress(label) : null,
            child: Center(
              child: label == '←'
                  ? Icon(
                      Symbols.backspace,
                      color: effectiveColor,
                      size: 24,
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: isAction ? FontWeight.bold : FontWeight.w500,
                        color: effectiveColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
