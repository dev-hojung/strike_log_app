/// 클럽 리더보드 응답 모델.
class ClubLeaderboard {
  /// 정렬/표시 기준 ('avg' 등). 추후 다른 지표 추가 시 활용.
  final String metric;

  /// 응답에 포함된 멤버 수 (entries 길이와 동일).
  final int totalParticipants;

  /// 본인의 순위 (멤버지만 경기가 없으면 myRank=null일 수 있음).
  final LeaderboardMyRank? myRank;

  final List<LeaderboardEntry> entries;

  ClubLeaderboard({
    required this.metric,
    required this.totalParticipants,
    this.myRank,
    required this.entries,
  });

  factory ClubLeaderboard.fromJson(Map<String, dynamic> json) {
    final entriesRaw = json['entries'];
    final myRankRaw = json['myRank'];
    return ClubLeaderboard(
      metric: json['metric']?.toString() ?? 'avg',
      totalParticipants:
          (json['totalParticipants'] as num?)?.toInt() ?? 0,
      myRank: myRankRaw is Map
          ? LeaderboardMyRank.fromJson(Map<String, dynamic>.from(myRankRaw))
          : null,
      entries: entriesRaw is List
          ? entriesRaw
              .map((e) =>
                  LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <LeaderboardEntry>[],
    );
  }
}

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String nickname;
  final double avg;
  final int highest;
  final int gameCount;

  LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.avg,
    required this.highest,
    required this.gameCount,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      userId: json['userId']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      avg: (json['avg'] as num?)?.toDouble() ?? 0,
      highest: (json['highest'] as num?)?.toInt() ?? 0,
      gameCount: (json['gameCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class LeaderboardMyRank {
  final int rank;
  final double avg;
  final int highest;
  final int gameCount;

  LeaderboardMyRank({
    required this.rank,
    required this.avg,
    required this.highest,
    required this.gameCount,
  });

  factory LeaderboardMyRank.fromJson(Map<String, dynamic> json) {
    return LeaderboardMyRank(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      avg: (json['avg'] as num?)?.toDouble() ?? 0,
      highest: (json['highest'] as num?)?.toInt() ?? 0,
      gameCount: (json['gameCount'] as num?)?.toInt() ?? 0,
    );
  }
}
