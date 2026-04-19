/// 알림 타입.
///
/// 백엔드 계약:
/// - `club_game_created`: 내가 속한 클럽에서 새 게임이 생성됨 (`targetId` = gameId)
/// - `club_join_request`: 내 클럽에 가입 신청이 옴 (`targetId` = clubId, `actorId` = 신청자)
/// - `club_join_approved`: 내 가입 신청이 승인됨 (`targetId` = clubId)
/// - `club_join_rejected`: 내 가입 신청이 거절됨 (`targetId` = clubId)
enum NotificationType {
  clubGameCreated,
  clubJoinRequest,
  clubJoinApproved,
  clubJoinRejected,
  unknown;

  static NotificationType fromString(String? raw) {
    switch (raw) {
      case 'club_game_created':
        return NotificationType.clubGameCreated;
      case 'club_join_request':
        return NotificationType.clubJoinRequest;
      case 'club_join_approved':
        return NotificationType.clubJoinApproved;
      case 'club_join_rejected':
        return NotificationType.clubJoinRejected;
      default:
        return NotificationType.unknown;
    }
  }
}

/// 단일 알림 레코드.
class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// 대상 리소스 id (게임/클럽 등). 네비게이션에 사용.
  final String? targetId;

  /// 행위자(예: 가입 신청자) id — 관리자 UI 등에서 활용.
  final String? actorId;
  final String? actorNickname;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.targetId,
    this.actorId,
    this.actorNickname,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      type: NotificationType.fromString(json['type']?.toString()),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      targetId: json['targetId']?.toString(),
      actorId: json['actorId']?.toString(),
      actorNickname: json['actorNickname']?.toString(),
    );
  }

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        targetId: targetId,
        actorId: actorId,
        actorNickname: actorNickname,
      );
}
