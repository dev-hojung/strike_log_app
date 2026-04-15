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
  ///
  /// 서버가 unreachable일 때 socket.io_client가 자동 재연결을 영원히 반복해
  /// UI가 "연결 중..." 에 멈추는 문제를 방지하기 위해 [timeout] 초 후 실패 처리.
  Future<void> connect({Duration timeout = const Duration(seconds: 10)}) {
    if (_socket != null && _socket!.connected) {
      return Future.value();
    }

    // 기존 소켓이 남아있다면 정리 (disconnect되었지만 null화 안 된 케이스 방어)
    if (_socket != null) {
      _socket!.dispose();
      _socket = null;
    }

    final completer = Completer<void>();

    _socket = IO.io(ApiClient.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      // 자동 재연결 제한 (무한 재시도로 완료 실패가 묻히는 것 방지)
      'reconnectionAttempts': 3,
      'timeout': timeout.inMilliseconds,
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

    // 최종 안전장치: timeout 시 에러로 완료. 호출 측에서 catch로 스낵바·상태 복구.
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _socket?.dispose();
        _socket = null;
        throw TimeoutException(
          '서버 연결 타임아웃 (${timeout.inSeconds}초)',
          timeout,
        );
      },
    );
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
  /// [strikes]/[spares]/[opens]는 선택 파라미터로, 클럽 게임 순위표에 실시간 통계를 노출할 때 함께 전송합니다.
  void sendScoreUpdate({
    required String roomId,
    required String userId,
    required int score,
    int? strikes,
    int? spares,
    int? opens,
  }) {
    _socket?.emit('updateScore', {
      'roomId': roomId,
      'user_id': userId,
      'score': score,
      if (strikes != null) 'strikes': strikes,
      if (spares != null) 'spares': spares,
      if (opens != null) 'opens': opens,
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
