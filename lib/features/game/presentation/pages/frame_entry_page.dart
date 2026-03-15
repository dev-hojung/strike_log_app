import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/socket_service.dart';
import 'game_summary_page.dart';

/// 볼링 게임의 점수를 입력하는 페이지입니다.
///
/// 사용자는 이 페이지에서 각 프레임의 투구 결과를 입력하고,
/// 실시간으로 총점과 프레임별 점수를 확인할 수 있습니다.
/// [isClubGame]이 true이면 소켓을 통해 다른 참가자들과 점수를 공유합니다.
class FrameEntryPage extends StatefulWidget {
  final bool isClubGame;
  final String? roomId;
  final List<Map<String, String>>? participants;
  final String? location;

  const FrameEntryPage({
    super.key,
    this.isClubGame = false,
    this.roomId,
    this.participants,
    this.location,
  });

  @override
  State<FrameEntryPage> createState() => _FrameEntryPageState();
}

class _FrameEntryPageState extends State<FrameEntryPage> {
  // 각 프레임의 투구 기록 (10프레임, 각 프레임 최대 3투구)
  final List<List<int>> _frames = List.generate(10, (_) => <int>[]);

  // 현재 선택된 프레임 인덱스 (0~9)
  int _currentFrame = 0;

  // 현재 프레임에서의 투구 순서 (0: 1투, 1: 2투, 2: 10프레임 3투)
  int _currentThrow = 0;

  // 게임 완료 여부
  bool _isGameComplete = false;

  // 키패드 표시 여부
  bool _showKeypad = false;

  // 클럽 게임: 소켓 서비스 및 다른 참가자 점수
  final SocketService _socketService = SocketService();
  String _userId = '';
  // 참가자별 총점 {userId: totalScore}
  final Map<String, int> _participantScores = {};

  @override
  void initState() {
    super.initState();
    if (widget.isClubGame) {
      _initClubGame();
    }
  }

  Future<void> _initClubGame() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? '';

    // 참가자 초기 점수 설정
    if (widget.participants != null) {
      for (final p in widget.participants!) {
        _participantScores[p['userId'] ?? ''] = 0;
      }
    }

    // 다른 참가자의 점수 업데이트 수신
    _socketService.on('score_update', (data) {
      if (!mounted) return;
      final senderId = data['userId'] as String?;
      if (senderId == null || senderId == _userId) return;
      setState(() {
        _participantScores[senderId] = data['totalScore'] ?? 0;
      });
    });
  }

  @override
  void dispose() {
    if (widget.isClubGame) {
      _socketService.off('score_update');
    }
    super.dispose();
  }

  /// 소켓으로 점수 업데이트 전송
  void _emitScoreUpdate() {
    if (!widget.isClubGame || widget.roomId == null) return;
    _socketService.sendScoreUpdate(
      roomId: widget.roomId!,
      userId: _userId,
      frameIndex: _currentFrame,
      throws: _frames[_currentFrame],
      totalScore: _totalScore,
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
  List<int?> get _cumulativeScores {
    final scores = List<int?>.filled(10, null);
    int cumulative = 0;

    for (int i = 0; i < 10; i++) {
      final frame = _frames[i];
      if (frame.isEmpty) break;

      if (i < 9) {
        // 1~9프레임
        if (_isStrike(i)) {
          // 스트라이크: 다음 2투구가 필요
          final bonus = _getNextTwoThrows(i);
          if (bonus == null) break;
          cumulative += 10 + bonus;
          scores[i] = cumulative;
        } else if (_isSpare(i)) {
          // 스페어: 다음 1투구가 필요
          final bonus = _getNextOneThrow(i);
          if (bonus == null) break;
          cumulative += 10 + bonus;
          scores[i] = cumulative;
        } else if (frame.length >= 2) {
          // 오픈 프레임
          cumulative += frame[0] + frame[1];
          scores[i] = cumulative;
        }
      } else {
        // 10프레임
        if (!_isFrameComplete(9)) break;
        int sum = 0;
        for (final pin in frame) {
          sum += pin;
        }
        cumulative += sum;
        scores[i] = cumulative;
      }
    }
    return scores;
  }

  /// 총점
  int get _totalScore {
    final scores = _cumulativeScores;
    for (int i = 9; i >= 0; i--) {
      if (scores[i] != null) return scores[i]!;
    }
    return 0;
  }

  bool _isStrike(int frameIndex) {
    final frame = _frames[frameIndex];
    if (frame.isEmpty) return false;
    return frame[0] == 10;
  }

  bool _isSpare(int frameIndex) {
    final frame = _frames[frameIndex];
    if (frame.length < 2) return false;
    if (frameIndex < 9) return frame[0] + frame[1] == 10 && frame[0] != 10;
    return false;
  }

  /// 해당 프레임이 완료되었는지 확인
  bool _isFrameComplete(int frameIndex) {
    final frame = _frames[frameIndex];
    if (frameIndex < 9) {
      if (frame.isEmpty) return false;
      if (frame[0] == 10) return true; // 스트라이크
      return frame.length >= 2;
    } else {
      // 10프레임
      if (frame.length < 2) return false;
      if (frame[0] == 10 || frame[0] + frame[1] == 10) {
        return frame.length >= 3; // 스트라이크/스페어면 3투
      }
      return frame.length >= 2; // 오픈이면 2투
    }
  }

  /// 다음 2투구 합 (스트라이크 보너스 계산용)
  int? _getNextTwoThrows(int frameIndex) {
    final throws = <int>[];
    for (int i = frameIndex + 1; i < 10 && throws.length < 2; i++) {
      for (final pin in _frames[i]) {
        throws.add(pin);
        if (throws.length == 2) break;
      }
    }
    if (throws.length < 2) return null;
    return throws[0] + throws[1];
  }

  /// 다음 1투구 (스페어 보너스 계산용)
  int? _getNextOneThrow(int frameIndex) {
    for (int i = frameIndex + 1; i < 10; i++) {
      if (_frames[i].isNotEmpty) return _frames[i][0];
    }
    return null;
  }

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
        if (_frames[9][1] == 10 || (_frames[9][0] == 10 && _frames[9].length == 2)) {
          _frames[9].add(10);
          _checkGameComplete();
        }
      }
    }
  }

  void _handleSpare() {
    if (_currentThrow == 0) return; // 1투에서 스페어 불가
    final remaining = _remainingPins;
    if (remaining == 0) return;

    if (_currentFrame < 9) {
      _frames[_currentFrame].add(remaining);
      _advanceFrame();
    } else {
      _frames[9].add(remaining);
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
      _frames[_currentFrame].add(pins);
      if (_currentThrow == 0 && pins < 10) {
        _currentThrow = 1;
      } else {
        _advanceFrame();
      }
    } else {
      // 10프레임
      _frames[9].add(pins);
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
    int strikeCount = 0;
    int spareCount = 0;
    int openCount = 0;

    for (int i = 0; i < 10; i++) {
      final frame = _frames[i];
      if (frame.isEmpty) continue;
      
      if (i < 9) {
        if (frame[0] == 10) {
          strikeCount++;
        } else if (frame.length >= 2 && frame[0] + frame[1] == 10) {
          spareCount++;
        } else if (frame.length >= 2) {
          openCount++;
        }
      } else {
        // 10th frame
        if (frame[0] == 10) strikeCount++;
        if (frame.length >= 2) {
          if (frame[0] != 10 && frame[0] + frame[1] == 10) spareCount++;
          if (frame[0] == 10 && frame[1] == 10) strikeCount++;
          if (frame[0] != 10 && frame[0] + frame[1] < 10) openCount++;
        }
        if (frame.length >= 3) {
          if (frame[2] == 10) strikeCount++;
          if (frame[1] != 10 && frame[1] + frame[2] == 10) spareCount++;
        }
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSummaryPage(
          frames: _frames,
          cumulativeScores: _cumulativeScores,
          totalScore: _totalScore,
          strikeCount: strikeCount,
          spareCount: spareCount,
          openCount: openCount,
          location: widget.location,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            widget.isClubGame ? '클럽 게임' : '개인 게임',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_isGameComplete)
            IconButton(
              icon: const Icon(Symbols.check, color: Colors.white),
              onPressed: () {
                // TODO: 게임 저장 처리
                Navigator.pop(context);
              },
            ),
          IconButton(
            icon: const Icon(Symbols.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 상단 콘텐츠 (스크롤 없음, 탭하면 키패드 닫힘)
          Expanded(
            child: ClipRect(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                if (_showKeypad) setState(() => _showKeypad = false);
              },
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
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
                const Spacer(),

                // 프레임 스크롤 영역
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: 10,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _buildFrameCard(index);
                    },
                  ),
                ),

                // 클럽 게임: 참가자 점수 목록
                if (widget.isClubGame && widget.participants != null) ...[
                  const SizedBox(height: 24),
                  _buildParticipantScores(),
                ],
                SizedBox(height: _showKeypad ? 8 : 24),
              ],
            ),
            ),
            ),
          ),

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

  /// 클럽 게임 참가자 점수 목록
  Widget _buildParticipantScores() {
    final participants = widget.participants ?? [];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '참가자 점수',
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...participants.map((p) {
            final isMe = p['userId'] == _userId;
            final score = isMe
                ? _totalScore
                : (_participantScores[p['userId']] ?? 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isMe
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.white10,
                    child: Text(
                      (p['nickname'] ?? '?')[0],
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? AppColors.primary : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${p['nickname']}${isMe ? ' (나)' : ''}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : Colors.white70,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isMe ? AppColors.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
