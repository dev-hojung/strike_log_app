import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/ads_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/user_profile_cache.dart';
import 'bet_result_page.dart';
import 'frame_entry_page.dart';

/// 클럽/내기 게임 방 페이지
///
/// [mode]가 'bet'이면 핸디캡 UI와 betMemo가 활성화됩니다.
class GameRoomPage extends StatefulWidget {
  final String mode;
  const GameRoomPage({super.key, this.mode = 'club'});

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  final SocketService _socketService = SocketService();
  final TextEditingController _roomCodeController = TextEditingController();

  String? _roomId;
  String _userId = '';
  String _nickname = '';
  bool _isHost = false;
  bool _isInRoom = false;
  bool _isConnecting = false;
  bool _isGameStarted = false;
  bool _betAdShown = false; // 내기 광고(생성/참여 시) 1회 노출 가드
  final List<Map<String, String>> _participants = [];

  // 내기 게임 전용
  String? _betMemo;
  int _maxPlayers = 6;
  final Map<String, int> _handicaps = {}; // userId → handicap
  /// 서버가 알려준 실제 방 모드. 코드 입력으로 참가한 사용자는 widget.mode가 'club' 기본인데
  /// 서버 응답으로 'bet' 임을 알 수 있다. UI 분기는 이 값을 우선 사용한다.
  String? _serverMode;

  bool get _isBet => (_serverMode ?? widget.mode) == 'bet';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    // 내기 게임은 생성/참여 시점에 광고를 띄우므로 미리 로드.
    AdsService.instance.preloadInterstitial();
  }

  /// 내기 게임 광고를 1회 노출 (생성자=생성 시, 참여자=참여 시).
  void _maybeShowBetAd() {
    if (!_isBet || _betAdShown) return;
    _betAdShown = true;
    final isPlatformAdmin =
        UserProfileCache.cached?['is_platform_admin'] == true;
    AdsService.instance.maybeShowInterstitial(
      isPlatformAdmin: isPlatformAdmin,
      onClose: () {},
    );
  }

  void _updateParticipantsFromState(dynamic state) {
    if (state == null || state['participants'] == null) return;
    final participants = state['participants'] as Map<String, dynamic>;
    setState(() {
      _participants.clear();
      for (final userId in participants.keys) {
        final p = participants[userId];
        _participants.add({
          'userId': userId,
          'nickname': p?['nickname'] ?? '게스트',
        });
        // 핸디캡 저장
        if (p?['handicap'] != null) {
          _handicaps[userId] = (p['handicap'] as num).toInt();
        }
      }
      // mode/betMemo/maxPlayers 갱신
      if (state['mode'] != null) {
        _serverMode = state['mode']?.toString();
      }
      if (state['betMemo'] != null) {
        _betMemo = state['betMemo'] as String?;
      }
      if (state['maxPlayers'] != null) {
        _maxPlayers = (state['maxPlayers'] as num).toInt();
      }
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id') ?? '';
    _nickname = prefs.getString('nickname') ?? '게스트';
    setState(() {});
  }

  void _setupSocketListeners() {
    _socketService.off('roomCreated');
    _socketService.off('roomStateUpdated');
    _socketService.off('gameStarted');
    _socketService.off('createRoomResponse');
    _socketService.off('joinRoomResponse');
    _socketService.off('error');
    _socketService.off('handicapSuggestions');
    _socketService.off('gameEnded');

    _socketService.on('roomCreated', (data) {
      if (!mounted) return;
      setState(() {
        _roomId = data['roomId'];
        _isInRoom = true;
        _isHost = true;
        _isConnecting = false;
      });
      _updateParticipantsFromState(data['state']);
      // 내기 생성자: 방 생성 직후 광고 노출.
      _maybeShowBetAd();
    });

    _socketService.on('roomStateUpdated', (data) {
      if (!mounted) return;
      final wasInRoom = _isInRoom;
      setState(() {
        _roomId = data['roomId'] ?? _roomId;
        _isInRoom = true;
        _isConnecting = false;
      });
      _updateParticipantsFromState(data);
      // 내기 참여자: 코드 입력 후 막 입장한 순간(호스트 제외) 광고 노출.
      if (!wasInRoom && !_isHost) _maybeShowBetAd();
    });

    _socketService.on('gameStarted', (data) {
      if (!mounted) return;
      _isGameStarted = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FrameEntryPage(
            isClubGame: true,
            roomId: _roomId,
            participants: _participants,
            isBetGame: _isBet,
            isHost: _isHost,
          ),
        ),
      );
    });

    _socketService.on('createRoomResponse', (data) {
      if (!mounted) return;
      if (data['success'] == false) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['data']?['message'] ?? data['message'] ?? '방 생성에 실패했습니다.')),
        );
      }
    });

    _socketService.on('joinRoomResponse', (data) {
      if (!mounted) return;
      if (data['success'] == false) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['data']?['message'] ?? data['message'] ?? '방 참가에 실패했습니다.')),
        );
      }
    });

    _socketService.on('error', (data) {
      if (!mounted) return;
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? '오류가 발생했습니다.')),
      );
    });

    // 핸디캡 추천 응답 (내기 모드)
    _socketService.on('handicapSuggestions', (data) {
      if (!mounted) return;
      final suggestions = (data['suggestions'] as List?) ?? [];
      for (final s in suggestions) {
        final uid = s['userId']?.toString() ?? '';
        final suggested = (s['suggestedHandicap'] as num?)?.toInt() ?? 0;
        if (uid.isNotEmpty) {
          _socketService.updateHandicap(
            roomId: _roomId!,
            targetUserId: uid,
            handicap: suggested,
          );
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('추천 핸디캡이 적용되었습니다.')),
        );
      }
    });

    // 게임 종료 이벤트 (내기 결과)
    _socketService.on('gameEnded', (data) {
      if (!mounted) return;
      // P1-4: 다른 방의 이벤트 무시
      if (_roomId != null && data['roomId'] != null && data['roomId'] != _roomId) return;
      _isGameStarted = true;
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

  Future<void> _createRoom() async {
    if (widget.mode == 'bet') {
      // 메모 입력 다이얼로그
      final memo = await _showBetMemoDialog();
      if (!mounted) return;
      _betMemo = memo ?? '';
    }

    setState(() => _isConnecting = true);
    try {
      await _socketService.connect();
      _setupSocketListeners();

      _socketService.createRoom(
        userId: _userId,
        nickname: _nickname,
        mode: widget.mode,
        betMemo: _betMemo,
        maxPlayers: widget.mode == 'bet' ? _maxPlayers : null,
      );
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 연결에 실패했습니다.')),
        );
      }
    }
  }

  Future<String?> _showBetMemoDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('내기 메모'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '예: 진 사람이 밥 사기 (선택사항)',
              counterText: '',
            ),
            maxLength: 50,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('건너뛰기'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _joinRoom() async {
    final code = _roomCodeController.text.trim();
    if (code.isEmpty || code.length != 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('7자리 방 코드를 입력해주세요.')),
      );
      return;
    }

    setState(() => _isConnecting = true);
    try {
      await _socketService.connect();
      _setupSocketListeners();

      _socketService.joinRoom(
        roomId: code,
        userId: _userId,
        nickname: _nickname,
      );
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서버 연결에 실패했습니다.')),
        );
      }
    }
  }

  void _leaveRoom() {
    if (_roomId != null) {
      _socketService.leaveRoom(roomId: _roomId!, userId: _userId);
    }
    _socketService.off('roomCreated');
    _socketService.off('roomStateUpdated');
    _socketService.off('gameStarted');
    _socketService.off('createRoomResponse');
    _socketService.off('joinRoomResponse');
    _socketService.off('error');
    _socketService.off('handicapSuggestions');
    _socketService.off('gameEnded');
    _socketService.disconnect();

    if (!mounted) {
      _isInRoom = false;
      _isHost = false;
      _roomId = null;
      _participants.clear();
      return;
    }

    setState(() {
      _isInRoom = false;
      _isHost = false;
      _roomId = null;
      _participants.clear();
    });
  }

  @override
  void dispose() {
    _roomCodeController.dispose();
    if (_isGameStarted) {
      // 게임이 시작되어 FrameEntryPage가 이어서 활성화된 상태.
      // 다음 페이지가 사용하는 이벤트(roomStateUpdated, gameEnded)는 off 하지 않는다.
      // socket.io의 off는 인자 없이 호출하면 해당 이벤트 모든 리스너 제거이므로
      // 새 페이지가 이미 등록한 핸들러까지 함께 사라져 BetResultPage 이동이 막힌다.
      _socketService.off('roomCreated');
      _socketService.off('gameStarted');
      _socketService.off('createRoomResponse');
      _socketService.off('joinRoomResponse');
      _socketService.off('handicapSuggestions');
      // FrameEntryPage는 'error'를 등록하지 않으므로 여기서 제거한다.
      // (남겨두면 플레이 중 발생한 소켓 에러가 dispose된 컨텍스트로 전달돼 조용히 사라짐)
      _socketService.off('error');
      // 'gameEnded', 'roomStateUpdated'는 FrameEntryPage가 이어 사용하므로 보존.
    } else if (_isInRoom) {
      _leaveRoom();
    } else {
      _socketService.off('roomCreated');
      _socketService.off('roomStateUpdated');
      _socketService.off('gameStarted');
      _socketService.off('createRoomResponse');
      _socketService.off('joinRoomResponse');
      _socketService.off('error');
      _socketService.off('handicapSuggestions');
      _socketService.off('gameEnded');
      _socketService.disconnect();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final isBet = _isBet;

    return PopScope(
      canPop: !_isInRoom,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirmed = await _confirmLeave();
        if (confirmed && context.mounted) {
          _leaveRoom();
          Navigator.of(context).pop();
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
          onPressed: () async {
            if (!_isInRoom) {
              Navigator.pop(context);
              return;
            }
            final confirmed = await _confirmLeave();
            if (confirmed && context.mounted) {
              _leaveRoom();
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isInRoom
              ? '게임 대기실'
              : (isBet ? '내기 게임' : '클럽 게임'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: _isInRoom ? _buildRoomView(isDark) : _buildJoinView(isDark),
      ),
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    final isBet = _isBet;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('방을 나가시겠어요?'),
        content: Text(
          isBet
              ? '내기 방을 나가면 방 코드는 사라집니다. 호스트면 다른 참가자에게 호스트가 자동 이전됩니다.'
              : '대기 중인 방을 나갑니다. 호스트면 다른 참가자에게 호스트가 자동 이전됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '나가기',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Widget _buildJoinView(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final isBet = _isBet;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isBet ? '친구들과\n내기 한 판 어때요?' : '클럽 멤버들과\n함께 플레이하세요',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '방을 만들거나 코드를 입력하여 참가하세요.',
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isConnecting ? null : _createRoom,
              icon: const Icon(Symbols.add_circle, color: Colors.white),
              label: Text(
                _isConnecting ? '연결 중...' : '새 방 만들기',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isBet ? const Color(0xFFC084FC) : AppColors.primary,
                disabledBackgroundColor: (isBet ? const Color(0xFFC084FC) : AppColors.primary)
                    .withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(child: Container(height: 1, color: isDark ? Colors.white10 : Colors.black12)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('또는', style: TextStyle(fontSize: 12, color: subTextColor)),
              ),
              Expanded(child: Container(height: 1, color: isDark ? Colors.white10 : Colors.black12)),
            ],
          ),

          const SizedBox(height: 32),

          Text(
            '방 코드 입력',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: subTextColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _roomCodeController,
                  keyboardType: TextInputType.text,
                  maxLength: 7,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'abc1234',
                    hintStyle: TextStyle(
                      color: subTextColor.withValues(alpha: 0.3),
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: surfaceColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isBet ? const Color(0xFFC084FC) : AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9]'))],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBet ? const Color(0xFFC084FC) : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: const Text(
                    '참가',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomView(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final isBet = _isBet;
    final accentColor = isBet ? const Color(0xFFC084FC) : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 방 코드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
            ),
            child: Column(
              children: [
                if (isBet && _betMemo != null && _betMemo!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Symbols.casino, size: 14, color: accentColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '내기 메모: $_betMemo',
                            style: TextStyle(fontSize: 13, color: accentColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text('방 코드', style: TextStyle(fontSize: 12, color: subTextColor)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _roomId ?? '',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Symbols.content_copy, color: subTextColor, size: 20),
                      onPressed: () {
                        if (_roomId != null) {
                          Clipboard.setData(ClipboardData(text: _roomId!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('방 코드가 복사되었습니다.')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isBet ? '이 코드를 친구들에게 공유하세요' : '이 코드를 클럽 멤버들에게 공유하세요',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 내기 모드 자동 핸디캡 버튼
          if (isBet && _isHost) ...[
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _roomId != null
                    ? () => _socketService.requestHandicapSuggestions(_roomId!)
                    : null,
                icon: Icon(Symbols.auto_fix_high, size: 18, color: accentColor),
                label: Text(
                  '자동 핸디캡 추천',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 참가자 목록
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '참가자',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_participants.length}명',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _participants.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = _participants[index];
                        final uid = p['userId'] ?? '';
                        final isMe = uid == _userId;
                        final isCreator = index == 0;
                        final handicap = _handicaps[uid] ?? 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe
                                ? accentColor.withValues(alpha: 0.05)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isMe
                                ? Border.all(color: accentColor.withValues(alpha: 0.2))
                                : null,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: accentColor.withValues(alpha: 0.1),
                                child: Text(
                                  (p['nickname'] ?? '?')[0],
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${p['nickname']}${isMe ? ' (나)' : ''}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (isCreator)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '방장',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 핸디캡 (내기 모드)
                              if (isBet) ...[
                                const SizedBox(width: 8),
                                _isHost
                                    ? GestureDetector(
                                        onTap: () => _editHandicap(uid, handicap),
                                        child: _handicapChip(handicap, accentColor, editable: true),
                                      )
                                    : _handicapChip(handicap, accentColor, editable: false),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_isHost)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _participants.isNotEmpty && _roomId != null
                    ? () => _socketService.startGame(_roomId!)
                    : null,
                icon: const Icon(Symbols.play_arrow, color: Colors.white),
                label: const Text(
                  '게임 시작',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.green.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _handicapChip(int handicap, Color color, {required bool editable}) {
    final text = handicap == 0 ? '±0' : (handicap > 0 ? '+$handicap' : '$handicap');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: editable ? Border.all(color: color.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          if (editable) ...[
            const SizedBox(width: 3),
            Icon(Symbols.edit, size: 12, color: color),
          ],
        ],
      ),
    );
  }

  Future<void> _editHandicap(String uid, int current) async {
    final controller = TextEditingController(text: current == 0 ? '' : '$current');
    try {
      final result = await showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('핸디캡 설정'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              hintText: '-100 ~ +100',
              counterText: '',
            ),
            maxLength: 4,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                // 빈 문자열은 0(핸디캡 없음)으로 처리
                final v = text.isEmpty ? 0 : int.tryParse(text);
                if (v == null || v < -100 || v > 100) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('-100 ~ +100 사이 값을 입력해주세요.')),
                  );
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );

      if (result != null && _roomId != null) {
        _socketService.updateHandicap(
          roomId: _roomId!,
          targetUserId: uid,
          handicap: result,
        );
      }
    } finally {
      controller.dispose();
    }
  }
}
