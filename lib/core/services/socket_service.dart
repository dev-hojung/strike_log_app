import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_client.dart';

/// Socket.IO 클라이언트 싱글톤 서비스
///
/// 클럽 게임 방 생성, 참가, 실시간 점수 공유에 사용됩니다.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;

  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? get socket => _socket;
  bool get isConnected => _socket?.connected ?? false;

  /// 소켓 연결
  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(ApiClient.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      print('[Socket] Connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      print('[Socket] Disconnected');
    });

    _socket!.onConnectError((err) {
      print('[Socket] Connection Error: $err');
    });
  }

  /// 방 생성
  void createRoom({
    required String roomId,
    required String userId,
    required String nickname,
  }) {
    _socket?.emit('create_room', {
      'roomId': roomId,
      'userId': userId,
      'nickname': nickname,
    });
  }

  /// 방 참가
  void joinRoom({
    required String roomId,
    required String userId,
    required String nickname,
  }) {
    _socket?.emit('join_room', {
      'roomId': roomId,
      'userId': userId,
      'nickname': nickname,
    });
  }

  /// 방 나가기
  void leaveRoom(String roomId) {
    _socket?.emit('leave_room', {'roomId': roomId});
  }

  /// 점수 업데이트 전송
  void sendScoreUpdate({
    required String roomId,
    required String userId,
    required int frameIndex,
    required List<int> throws,
    required int totalScore,
  }) {
    _socket?.emit('score_update', {
      'roomId': roomId,
      'userId': userId,
      'frameIndex': frameIndex,
      'throws': throws,
      'totalScore': totalScore,
    });
  }

  /// 게임 시작 알림
  void startGame(String roomId) {
    _socket?.emit('start_game', {'roomId': roomId});
  }

  /// 이벤트 리스너 등록
  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  /// 이벤트 리스너 해제
  void off(String event) {
    _socket?.off(event);
  }

  /// 소켓 연결 해제
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
