import 'dart:async';

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

  /// 소켓 연결 (연결 완료 시 Future 반환)
  Future<void> connect() {
    if (_socket != null && _socket!.connected) {
      return Future.value();
    }

    final completer = Completer<void>();

    _socket = IO.io(ApiClient.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket!.onConnect((_) {
      print('[Socket] Connected: ${_socket!.id}');
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.onAny((event, data) {
      print('[Socket] Event: $event, Data: $data');
    });

    _socket!.onDisconnect((_) {
      print('[Socket] Disconnected');
    });

    _socket!.onConnectError((err) {
      print('[Socket] Connection Error: $err');
      if (!completer.isCompleted) completer.completeError(err);
    });

    return completer.future;
  }

  /// 방 생성
  void createRoom({
    required String userId,
    required String nickname,
  }) {
    _socket?.emit('createRoom', {
      'user_id': userId,
      'nickname': nickname,
    });
  }

  /// 방 참가
  void joinRoom({
    required String roomId,
    required String userId,
    required String nickname,
  }) {
    _socket?.emit('joinRoom', {
      'roomId': roomId,
      'user_id': userId,
      'nickname': nickname,
    });
  }

  /// 방 나가기
  void leaveRoom({
    required String roomId,
    required String userId,
  }) {
    _socket?.emit('leaveRoom', {
      'roomId': roomId,
      'user_id': userId,
    });
  }

  /// 점수 업데이트 전송
  void sendScoreUpdate({
    required String roomId,
    required String userId,
    required int score,
  }) {
    _socket?.emit('updateScore', {
      'roomId': roomId,
      'user_id': userId,
      'score': score,
    });
  }

  /// 게임 시작 알림
  void startGame(String roomId) {
    _socket?.emit('startGame', {'roomId': roomId});
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
