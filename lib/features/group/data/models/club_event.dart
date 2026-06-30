/// 정기전/모임 상태 enum.
enum ClubEventStatus {
  scheduled,
  inProgress,
  completed,
  cancelled;

  static ClubEventStatus fromString(String? s) {
    switch (s) {
      case 'in_progress':
        return ClubEventStatus.inProgress;
      case 'completed':
        return ClubEventStatus.completed;
      case 'cancelled':
        return ClubEventStatus.cancelled;
      default:
        return ClubEventStatus.scheduled;
    }
  }

  String get label {
    switch (this) {
      case ClubEventStatus.scheduled:
        return '예정';
      case ClubEventStatus.inProgress:
        return '진행 중';
      case ClubEventStatus.completed:
        return '완료';
      case ClubEventStatus.cancelled:
        return '취소';
    }
  }
}

/// 정기전 참가자.
class ClubEventParticipant {
  final String userId;
  final String nickname;
  final String? profileImageUrl;
  final int? laneNo;
  final int? teamNo;
  final int handicap;

  ClubEventParticipant({
    required this.userId,
    required this.nickname,
    this.profileImageUrl,
    this.laneNo,
    this.teamNo,
    this.handicap = 0,
  });

  factory ClubEventParticipant.fromJson(Map<String, dynamic> json) {
    return ClubEventParticipant(
      userId: json['user_id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      profileImageUrl: json['profile_image_url']?.toString(),
      laneNo: (json['lane_no'] as num?)?.toInt(),
      teamNo: (json['team_no'] as num?)?.toInt(),
      handicap: (json['handicap'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 정기전/모임 엔티티.
class ClubEvent {
  final int id;
  final int groupId;
  final String name;
  final String eventDate;
  final ClubEventStatus status;
  final String? laneMode;
  final int? gameTarget;
  final String createdBy;
  final String createdAt;
  final String updatedAt;
  final List<ClubEventParticipant> participants;

  ClubEvent({
    required this.id,
    required this.groupId,
    required this.name,
    required this.eventDate,
    required this.status,
    this.laneMode,
    this.gameTarget,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.participants = const [],
  });

  int get participantCount => participants.isEmpty
      ? 0
      : participants.length;

  factory ClubEvent.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    final participants = rawParticipants is List
        ? rawParticipants
            .map((e) =>
                ClubEventParticipant.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : <ClubEventParticipant>[];

    return ClubEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      groupId: (json['group_id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      status: ClubEventStatus.fromString(json['status']?.toString()),
      laneMode: json['lane_mode']?.toString(),
      gameTarget: (json['game_target'] as num?)?.toInt(),
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      participants: participants,
    );
  }
}
