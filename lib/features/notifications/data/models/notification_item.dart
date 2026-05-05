/// 알림 타입.
///
/// 백엔드 계약 (`strike_log_api/notification.entity.ts`와 동일하게 유지):
/// - `club_game_created`: 내가 속한 클럽에서 새 게임이 생성됨 (`targetId` = gameId)
/// - `club_join_request`: 내 클럽에 가입 신청이 옴 (`targetId` = clubId, `actorId` = 신청자)
/// - `club_join_approved`: 내 가입 신청이 승인됨 (`targetId` = clubId)
/// - `club_join_rejected`: 내 가입 신청이 거절됨 (`targetId` = clubId)
/// - `club_creation_request`: 신규 클럽 생성 신청이 접수됨 (관리자 전용)
/// - `club_creation_approved`: 내 클럽 생성 신청이 승인됨 (`targetId` = groupId)
/// - `club_creation_rejected`: 내 클럽 생성 신청이 거절됨
/// - `club_trial_expiring_soon`: 체험판 만료 임박
/// - `club_trial_expired`: 체험판 만료
enum NotificationType {
  clubGameCreated,
  clubJoinRequest,
  clubJoinApproved,
  clubJoinRejected,
  clubCreationRequest,
  clubCreationApproved,
  clubCreationRejected,
  clubTrialExpiringSoon,
  clubTrialExpired,
  unknown;

  /// 백엔드에서 내려오는 문자열 값.
  String get wireValue {
    switch (this) {
      case NotificationType.clubGameCreated:
        return 'club_game_created';
      case NotificationType.clubJoinRequest:
        return 'club_join_request';
      case NotificationType.clubJoinApproved:
        return 'club_join_approved';
      case NotificationType.clubJoinRejected:
        return 'club_join_rejected';
      case NotificationType.clubCreationRequest:
        return 'club_creation_request';
      case NotificationType.clubCreationApproved:
        return 'club_creation_approved';
      case NotificationType.clubCreationRejected:
        return 'club_creation_rejected';
      case NotificationType.clubTrialExpiringSoon:
        return 'club_trial_expiring_soon';
      case NotificationType.clubTrialExpired:
        return 'club_trial_expired';
      case NotificationType.unknown:
        return '';
    }
  }

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
      case 'club_creation_request':
        return NotificationType.clubCreationRequest;
      case 'club_creation_approved':
        return NotificationType.clubCreationApproved;
      case 'club_creation_rejected':
        return NotificationType.clubCreationRejected;
      case 'club_trial_expiring_soon':
        return NotificationType.clubTrialExpiringSoon;
      case 'club_trial_expired':
        return NotificationType.clubTrialExpired;
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
