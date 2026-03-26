import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/socket_service.dart';
import 'frame_entry_page.dart';

/// 클럽 게임 방 페이지
///
/// 방장이 방을 생성하고 코드를 공유하면, 클럽 멤버들이 참가합니다.
/// 모든 참가자가 모이면 방장이 게임을 시작합니다.
class GameRoomPage extends StatefulWidget {
  const GameRoomPage({super.key});

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
  final List<Map<String, String>> _participants = [];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
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
    // 방 생성 응답 (메타데이터만 설정, 참가자 목록은 roomStateUpdated에서 관리)
    _socketService.on('roomCreated', (data) {
      setState(() {
        _roomId = data['roomId'];
        _isInRoom = true;
        _isHost = true;
        _isConnecting = false;
      });
      // 서버에 roomStateUpdated 요청 (참가자 목록 동기화)
      _updateParticipantsFromState(data['state']);
    });

    // 참가자 목록 통합 관리 (모든 상태 변경 시)
    _socketService.on('roomStateUpdated', (data) {
      if (!mounted) return;
      setState(() {
        _roomId = data['roomId'] ?? _roomId;
        _isInRoom = true;
        _isConnecting = false;
      });
      _updateParticipantsFromState(data);
    });

    // 게임 시작
    _socketService.on('gameStarted', (data) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FrameEntryPage(
            isClubGame: true,
            roomId: _roomId,
            participants: _participants,
          ),
        ),
      );
    });

    // 방 생성/참가 응답 (에러 처리)
    _socketService.on('createRoomResponse', (data) {
      if (data['success'] == false) {
        setState(() => _isConnecting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['data']?['message'] ?? data['message'] ?? '방 생성에 실패했습니다.')),
          );
        }
      }
    });

    _socketService.on('joinRoomResponse', (data) {
      if (data['success'] == false) {
        setState(() => _isConnecting = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['data']?['message'] ?? data['message'] ?? '방 참가에 실패했습니다.')),
          );
        }
      }
    });

    _socketService.on('error', (data) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? '오류가 발생했습니다.')),
        );
      }
    });
  }

  Future<void> _createRoom() async {
    setState(() => _isConnecting = true);
    try {
      await _socketService.connect();
      _setupSocketListeners();

      _socketService.createRoom(
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
    _socketService.disconnect();

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
    if (_isInRoom) _leaveRoom();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Symbols.arrow_back, color: textColor),
          onPressed: () {
            if (_isInRoom) {
              _leaveRoom();
            }
            Navigator.pop(context);
          },
        ),
        title: Text(
          _isInRoom ? '게임 대기실' : '클럽 게임',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _isInRoom ? _buildRoomView(isDark) : _buildJoinView(isDark),
    );
  }

  /// 방 생성/참가 선택 화면
  Widget _buildJoinView(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '클럽 멤버들과\n함께 플레이하세요',
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

          // 방 만들기 버튼
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
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 구분선
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '또는',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // 방 코드 입력
          Text(
            '방 코드 입력',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: subTextColor,
            ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
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
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: const Text(
                    '참가',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 방 대기실 화면
  Widget _buildRoomView(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 방 코드 표시
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: Column(
              children: [
                Text(
                  '방 코드',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
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
                            color: AppColors.primary,
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
                  '이 코드를 클럽 멤버들에게 공유하세요',
                  style: TextStyle(fontSize: 12, color: subTextColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 참가자 목록
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_participants.length}명',
                          style: const TextStyle(
                            color: AppColors.primary,
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
                        final isMe = p['userId'] == _userId;
                        final isCreator = index == 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppColors.primary.withValues(alpha: 0.05)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isMe
                                ? Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: Text(
                                  (p['nickname'] ?? '?')[0],
                                  style: const TextStyle(
                                    color: AppColors.primary,
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
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

          // 게임 시작 버튼 (방장만)
          if (_isHost)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _participants.length >= 1 && _roomId != null
                    ? () => _socketService.startGame(_roomId!)
                    : null,
                icon: const Icon(Symbols.play_arrow, color: Colors.white),
                label: const Text(
                  '게임 시작',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.green.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
