class HomeDashboardData {
  final int averageScore;
  final int highestScore;
  final double? trendPercentage; // Added trend percentage
  final DateTime? highestScoreDate;
  final List<TrendData> recentTrend;
  final RecentGame? recentGame;
  final String nickname;

  /// 유저가 클럽(그룹)에 소속되어 있는지 여부 (nullable: 핫 리로드 안전성 확보)
  final bool? hasGroup;

  /// 월별 트렌드 상태 ('both' | 'current_only' | 'last_only' | 'none')
  final String? trendStatus;

  /// 이번 달 경기 수
  final int? currentMonthGameCount;

  /// 소속 클럽 목록
  final List<ClubInfo> clubs;

  HomeDashboardData({
    required this.averageScore,
    required this.highestScore,
    this.trendPercentage,
    this.highestScoreDate,
    required this.recentTrend,
    this.recentGame,
    this.nickname = 'Alex', // Default fallback
    this.hasGroup = false,
    this.trendStatus,
    this.currentMonthGameCount,
    this.clubs = const [],
  });

  bool get isEmpty =>
      averageScore == 0 && highestScore == 0 && recentGame == null;
}

class TrendData {
  final int score;
  final DateTime date;

  TrendData({required this.score, required this.date});

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      score: json['score'] ?? 0,
      date: DateTime.parse(json['date']),
    );
  }
}

class RecentGame {
  final int id;
  final int totalScore;
  final DateTime playDate;
  final String? location;

  RecentGame({
    required this.id,
    required this.totalScore,
    required this.playDate,
    this.location,
  });

  factory RecentGame.fromJson(Map<String, dynamic> json) {
    return RecentGame(
      id: json['id'],
      totalScore: json['total_score'],
      playDate: DateTime.parse(json['play_date']),
      location: json['location'],
    );
  }
}

class ClubInfo {
  final int id;
  final String name;
  final String? description;
  final String? coverImageUrl;
  final int memberCount;

  ClubInfo({
    required this.id,
    required this.name,
    this.description,
    this.coverImageUrl,
    this.memberCount = 0,
  });

  factory ClubInfo.fromJson(Map<String, dynamic> json) {
    return ClubInfo(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      coverImageUrl: json['cover_image_url'],
      memberCount: json['member_count'] ?? 0,
    );
  }
}
