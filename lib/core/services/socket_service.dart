import 'dart:async';

// ignore: library_prefixes
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_client.dart';
import 'app_logger.dart';
import 'auth_token_storage.dart';

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

    // 백엔드 GameRoomsGateway.handleConnection이 handshake.auth.token으로 JWT를 검증한다.
    // 토큰이 없으면 즉시 disconnect되므로 connect 시점에 반드시 전달.
    final accessToken = AuthTokenStorage.current;
    _socket = IO.io(ApiClient.baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      // 자동 재연결 제한 (무한 재시도로 완료 실패가 묻히는 것 방지)
      'reconnectionAttempts': 3,
      'timeout': timeout.inMilliseconds,
      if (accessToken != null && accessToken.isNotEmpty)
        'auth': {'token': accessToken},
    });

    _socket!.onConnect((_) {
      AppLogger.info('[Socket] Connected: ${_socket!.id}');
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.onAny((event, data) {
      AppLogger.info('[Socket] Event: $event, Data: $data');
      // 소켓 에러 이벤트 중 club_trial_expired 처리 — ApiClient의 동일 콜백으로 위임
      if (event == 'error' && data is Map && data['code'] == 'club_trial_expired') {
        ApiClient.onClubTrialExpired?.call();
      }
    });

    _socket!.onDisconnect((_) {
      AppLogger.info('[Socket] Disconnected');
    });

    _socket!.onConnectError((err) {
      AppLogger.info('[Socket] Connection Error: $err');
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

  /// 방 생성. mode='bet'이면 핸디캡/내기 메모/최대 인원도 함께 전달.
  /// [teamMode]=true면 내기 팀전(팀 수 [teamCount] 2~3).
  void createRoom({
    required String userId,
    required String nickname,
    String mode = 'club',
    String? betMemo,
    int? maxPlayers,
    bool teamMode = false,
    int? teamCount,
  }) {
    _socket?.emit('createRoom', {
      'user_id': userId,
      'nickname': nickname,
      'mode': mode,
      if (betMemo != null) 'betMemo': betMemo,
      if (maxPlayers != null) 'maxPlayers': maxPlayers,
      if (teamMode) 'teamMode': true,
      if (teamMode && teamCount != null) 'teamCount': teamCount,
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

  /// 내기 핸디캡 설정 (호스트, 게임 시작 전까지만).
  void updateHandicap({
    required String roomId,
    required String targetUserId,
    required int handicap,
  }) {
    _socket?.emit('updateHandicap', {
      'roomId': roomId,
      'targetUserId': targetUserId,
      'handicap': handicap,
    });
  }

  /// 자동 핸디캡 추천 요청. 응답은 'handicapSuggestions' 이벤트.
  void requestHandicapSuggestions(String roomId) {
    _socket?.emit('suggestHandicaps', {'roomId': roomId});
  }

  /// 내기 팀전 팀 배정 (호스트, 시작 전). [teamNo]=null이면 배정 해제.
  void assignTeam({
    required String roomId,
    required String targetUserId,
    required int? teamNo,
  }) {
    _socket?.emit('assignTeam', {
      'roomId': roomId,
      'targetUserId': targetUserId,
      'teamNo': teamNo,
    });
  }

  /// 내기 팀전 자동 팀 배정 (평균 기반 밸런싱, 호스트). 결과는 'roomStateUpdated'.
  void autoAssignTeams(String roomId) {
    _socket?.emit('autoAssignTeams', {'roomId': roomId});
  }

  /// 게임 종료 + 핸디 적용 순위 요청 (호스트만). 결과는 'gameEnded' 이벤트.
  void finishGame(String roomId) {
    _socket?.emit('finishGame', {'roomId': roomId});
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
