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
  /// 목록 API에서 participant_count로 내려오는 숫자.
  /// 상세 API에서는 participants 배열 길이로 계산.
  final int? _participantCountFromApi;

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
    int? participantCount,
  }) : _participantCountFromApi = participantCount;

  /// 참가자 수. 목록 API의 participant_count를 우선 사용하고
  /// 없으면 participants 배열 길이로 계산한다.
  int get participantCount =>
      _participantCountFromApi ?? participants.length;

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
      participantCount: (json['participant_count'] as num?)?.toInt(),
    );
  }

  /// eventDate 문자열에서 날짜·시간 컴포넌트를 파싱한다.
  ///
  /// 서버는 'YYYY-MM-DD HH:mm:ss' 또는 'YYYY-MM-DD' 형태로 내려준다.
  /// DateTime.parse를 쓰지 않고 직접 분해해 TZ 변환을 완전히 차단한다.
  static Map<String, int> _parseComponents(String s) {
    // 날짜 부분: 최소 'YYYY-MM-DD'
    final datePart = s.length >= 10 ? s.substring(0, 10) : s;
    final dateParts = datePart.split('-');
    final year = dateParts.isNotEmpty ? (int.tryParse(dateParts[0]) ?? 0) : 0;
    final month = dateParts.length > 1 ? (int.tryParse(dateParts[1]) ?? 0) : 0;
    final day = dateParts.length > 2 ? (int.tryParse(dateParts[2]) ?? 0) : 0;

    int hour = 0;
    int minute = 0;
    // 시간 부분: 'YYYY-MM-DD HH:mm:ss' 또는 'YYYY-MM-DDTHH:mm:ss'
    if (s.length > 10) {
      final timePart = s.substring(11); // skip date + separator
      final timeParts = timePart.split(':');
      hour = timeParts.isNotEmpty ? (int.tryParse(timeParts[0]) ?? 0) : 0;
      minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
    }

    return {
      'year': year,
      'month': month,
      'day': day,
      'hour': hour,
      'minute': minute,
    };
  }

  /// 카드/헤더 날짜 블럭용: 월(int), 일(int) 반환.
  (int month, int day) get dateComponents {
    final c = _parseComponents(eventDate);
    return (c['month']!, c['day']!);
  }

  /// 상세 표시용 날짜 문자열. 예: "2026년 7월 5일"
  String get formattedDate {
    final c = _parseComponents(eventDate);
    return '${c['year']}년 ${c['month']}월 ${c['day']}일';
  }

  /// 시간 표시 문자열. 예: "오후 7:00" (시간 정보 없으면 null 반환)
  String? get formattedTime {
    final c = _parseComponents(eventDate);
    final h = c['hour']!;
    final m = c['minute']!;
    if (h == 0 && m == 0) return null;
    final period = h < 12 ? '오전' : '오후';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final minuteStr = m.toString().padLeft(2, '0');
    return '$period $displayHour:$minuteStr';
  }

  /// 날짜+시간 전체 표시 문자열. 예: "2026년 7월 5일 오후 7:00"
  String get formattedDateTime {
    final time = formattedTime;
    if (time == null) return formattedDate;
    return '$formattedDate $time';
  }
}
