/// 정기전 결과 집계 - 참가자별 순위.
class ClubEventResultParticipant {
  final String userId;
  final String nickname;
  final int gameCount;
  final int totalScore;
  final double avgScore;
  final int rank;
  final int? laneNo;
  final int? teamNo;

  ClubEventResultParticipant({
    required this.userId,
    required this.nickname,
    required this.gameCount,
    required this.totalScore,
    required this.avgScore,
    required this.rank,
    this.laneNo,
    this.teamNo,
  });

  factory ClubEventResultParticipant.fromJson(Map<String, dynamic> json) {
    return ClubEventResultParticipant(
      userId: json['user_id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      gameCount: (json['game_count'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      avgScore: (json['avg_score'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      laneNo: (json['lane_no'] as num?)?.toInt(),
      teamNo: (json['team_no'] as num?)?.toInt(),
    );
  }
}

/// 정기전 결과 집계 - 팀별 순위 (팀전 모드에서만 non-null).
class ClubEventResultTeam {
  final int teamNo;
  final int gameCount;
  final int totalScore;
  final double avgScore;
  final int rank;

  ClubEventResultTeam({
    required this.teamNo,
    required this.gameCount,
    required this.totalScore,
    required this.avgScore,
    required this.rank,
  });

  factory ClubEventResultTeam.fromJson(Map<String, dynamic> json) {
    return ClubEventResultTeam(
      teamNo: (json['team_no'] as num?)?.toInt() ?? 0,
      gameCount: (json['game_count'] as num?)?.toInt() ?? 0,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      avgScore: (json['avg_score'] as num?)?.toDouble() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 정기전 결과 전체 응답.
class ClubEventResult {
  final String eventName;
  final String eventDate;
  final String status;
  final String? laneMode;
  final List<ClubEventResultParticipant> participants;
  final List<ClubEventResultTeam>? teams;

  ClubEventResult({
    required this.eventName,
    required this.eventDate,
    required this.status,
    this.laneMode,
    required this.participants,
    this.teams,
  });

  factory ClubEventResult.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    final participants = rawParticipants is List
        ? rawParticipants
            .map((e) => ClubEventResultParticipant.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : <ClubEventResultParticipant>[];

    final rawTeams = json['teams'];
    final teams = rawTeams is List
        ? rawTeams
            .map((e) => ClubEventResultTeam.fromJson(
                Map<String, dynamic>.from(e as Map)))
            .toList()
        : null;

    return ClubEventResult(
      eventName: json['event_name']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      laneMode: json['lane_mode']?.toString(),
      participants: participants,
      teams: teams,
    );
  }
}
