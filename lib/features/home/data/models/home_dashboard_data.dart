class HomeDashboardData {
  /// 종합 평균 (개인 + 클럽 게임 전체)
  final int averageScore;

  /// 개인 게임만의 평균 (is_club_game=false)
  final int personalAverageScore;

  /// 클럽 게임만의 평균 (is_club_game=true)
  final int clubAverageScore;
  final int highestScore;
  final double? trendPercentage; // Added trend percentage
  final DateTime? highestScoreDate;
  final List<TrendData> recentTrend;
  final String nickname;

  /// 유저가 클럽(그룹)에 소속되어 있는지 여부 (nullable: 핫 리로드 안전성 확보)
  final bool? hasGroup;

  /// 월별 트렌드 상태 ('both' | 'current_only' | 'last_only' | 'none')
  final String? trendStatus;

  /// 이번 달 경기 수
  final int? currentMonthGameCount;

  /// 이번 달 평균 점수
  final int? currentMonthAvg;

  /// 이번 달 누적 스트라이크/스페어/오픈 + 올커버 게임 수 + 퍼펙트 게임 수
  final int monthlyStrikes;
  final int monthlySpares;
  final int monthlyOpens;
  final int monthlyAllCoverGames;
  final int monthlyPerfectGames;

  /// 소속 클럽 목록
  final List<ClubInfo> clubs;

  HomeDashboardData({
    required this.averageScore,
    this.personalAverageScore = 0,
    this.clubAverageScore = 0,
    required this.highestScore,
    this.trendPercentage,
    this.highestScoreDate,
    required this.recentTrend,
    this.nickname = 'Alex', // Default fallback
    this.hasGroup = false,
    this.trendStatus,
    this.currentMonthGameCount,
    this.currentMonthAvg,
    this.monthlyStrikes = 0,
    this.monthlySpares = 0,
    this.monthlyOpens = 0,
    this.monthlyAllCoverGames = 0,
    this.monthlyPerfectGames = 0,
    this.clubs = const [],
  });

  bool get isEmpty =>
      averageScore == 0 && highestScore == 0 && recentTrend.isEmpty;
}

class TrendData {
  final int score;
  final DateTime date;
  final int strikes;
  final int spares;
  final int opens;

  TrendData({
    required this.score,
    required this.date,
    this.strikes = 0,
    this.spares = 0,
    this.opens = 0,
  });

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      score: (json['score'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      strikes: (json['strikes'] as num?)?.toInt() ?? 0,
      spares: (json['spares'] as num?)?.toInt() ?? 0,
      opens: (json['opens'] as num?)?.toInt() ?? 0,
    );
  }
}


class ClubInfo {
  final int id;
  final String name;
  final String? description;
  final String? coverImageUrl;
  final int memberCount;

  /// 클럽 평균 점수 (멤버 전원의 모든 게임 평균). 게임이 없으면 0.
  final int avgScore;

  ClubInfo({
    required this.id,
    required this.name,
    this.description,
    this.coverImageUrl,
    this.memberCount = 0,
    this.avgScore = 0,
  });

  factory ClubInfo.fromJson(Map<String, dynamic> json) {
    return ClubInfo(
      id: (json['id'] as num).toInt(),
      name: json['name'] ?? '',
      description: json['description'],
      coverImageUrl: json['cover_image_url'],
      memberCount: json['member_count'] ?? 0,
      avgScore: (json['avg_score'] as num?)?.toInt() ?? 0,
    );
  }
}
