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
  final RecentGame? recentGame;
  final String nickname;

  /// 유저가 클럽(그룹)에 소속되어 있는지 여부 (nullable: 핫 리로드 안전성 확보)
  final bool? hasGroup;

  /// 월별 트렌드 상태 ('both' | 'current_only' | 'last_only' | 'none')
  final String? trendStatus;

  /// 이번 달 경기 수
  final int? currentMonthGameCount;

  /// 이번 달 평균 점수
  final int? currentMonthAvg;

  /// 이번 달 누적 스트라이크/스페어/오픈 + 올커버 게임 수
  final int monthlyStrikes;
  final int monthlySpares;
  final int monthlyOpens;
  final int monthlyAllCoverGames;

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
    this.recentGame,
    this.nickname = 'Alex', // Default fallback
    this.hasGroup = false,
    this.trendStatus,
    this.currentMonthGameCount,
    this.currentMonthAvg,
    this.monthlyStrikes = 0,
    this.monthlySpares = 0,
    this.monthlyOpens = 0,
    this.monthlyAllCoverGames = 0,
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
  // 서버의 `created_at` 타임스탬프 (게임 저장 시각, 시/분/초 포함).
  // play_date 컬럼은 MySQL DATE라 시간 정보가 없으므로
  // 시간 표시가 필요한 UI는 createdAt을 사용한다.
  final DateTime? createdAt;
  final String? location;

  /// 시리즈에 속한 게임이면 시리즈 ID. 단일 게임은 null.
  final int? seriesId;

  /// 시리즈 내 게임 순번(1-based). 단일 게임은 null.
  final int? seriesIndex;

  RecentGame({
    required this.id,
    required this.totalScore,
    required this.playDate,
    this.createdAt,
    this.location,
    this.seriesId,
    this.seriesIndex,
  });

  factory RecentGame.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'];
    return RecentGame(
      id: json['id'],
      totalScore: json['total_score'],
      playDate: DateTime.parse(json['play_date']),
      // DB의 created_at은 UTC로 저장되므로 .toLocal()로 사용자 타임존 변환
      createdAt: createdRaw is String
          ? DateTime.parse(createdRaw).toLocal()
          : null,
      location: json['location'],
      seriesId: (json['series_id'] as num?)?.toInt(),
      seriesIndex: (json['series_index'] as num?)?.toInt(),
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
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      coverImageUrl: json['cover_image_url'],
      memberCount: json['member_count'] ?? 0,
      avgScore: (json['avg_score'] as num?)?.toInt() ?? 0,
    );
  }
}
