/// 게임 또는 시리즈 단위의 통계.
class BowlingStats {
  final int strikes;
  final int spares;
  final int opens;
  final int longestStrikeStreak;

  const BowlingStats({
    this.strikes = 0,
    this.spares = 0,
    this.opens = 0,
    this.longestStrikeStreak = 0,
  });

  factory BowlingStats.fromJson(Map<String, dynamic> json) => BowlingStats(
        strikes: (json['strikes'] as num?)?.toInt() ?? 0,
        spares: (json['spares'] as num?)?.toInt() ?? 0,
        opens: (json['opens'] as num?)?.toInt() ?? 0,
        longestStrikeStreak:
            (json['longest_strike_streak'] as num?)?.toInt() ?? 0,
      );

  static const empty = BowlingStats();
}

/// 볼링 시리즈 도메인 모델.
///
/// 한 세션(3게임/6게임 등)을 묶는 단위. 서버의 game_series 레코드 + 속한 games
/// 요약을 함께 표현한다.
class GameSeries {
  final int id;
  final String userId;
  final int targetGameCount;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int gameCount;
  final int totalScore;
  final double averageScore;
  final BowlingStats stats;
  final List<SeriesGame> games;

  GameSeries({
    required this.id,
    required this.userId,
    required this.targetGameCount,
    required this.startedAt,
    this.completedAt,
    required this.gameCount,
    required this.totalScore,
    required this.averageScore,
    this.stats = BowlingStats.empty,
    this.games = const [],
  });

  bool get isCompleted => completedAt != null;
  bool get isReadyToComplete => gameCount >= targetGameCount;

  factory GameSeries.fromJson(Map<String, dynamic> json) {
    final gamesRaw = json['games'];
    final games = gamesRaw is List
        ? gamesRaw
            .map((e) => SeriesGame.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SeriesGame>[];
    final startedAt = json['started_at'];
    final completedAt = json['completed_at'];
    final statsRaw = json['stats'];
    return GameSeries(
      id: json['id'] as int,
      userId: json['user_id']?.toString() ?? '',
      targetGameCount: (json['target_game_count'] as num?)?.toInt() ?? 0,
      startedAt: startedAt is String
          ? DateTime.parse(startedAt).toLocal()
          : DateTime.now(),
      completedAt: completedAt is String
          ? DateTime.parse(completedAt).toLocal()
          : null,
      gameCount: (json['game_count'] as num?)?.toInt() ?? games.length,
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      averageScore: (json['average_score'] as num?)?.toDouble() ?? 0,
      stats: statsRaw is Map
          ? BowlingStats.fromJson(Map<String, dynamic>.from(statsRaw))
          : BowlingStats.empty,
      games: games,
    );
  }
}

/// 시리즈에 속한 게임의 요약 정보.
class SeriesGame {
  final int id;
  final int? seriesIndex;
  final int totalScore;
  final DateTime playDate;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final BowlingStats stats;

  SeriesGame({
    required this.id,
    this.seriesIndex,
    required this.totalScore,
    required this.playDate,
    this.startedAt,
    this.endedAt,
    this.stats = BowlingStats.empty,
  });

  factory SeriesGame.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic v) =>
        v is String ? DateTime.parse(v).toLocal() : null;

    final statsRaw = json['stats'];
    return SeriesGame(
      id: json['id'] as int,
      seriesIndex: (json['series_index'] as num?)?.toInt(),
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      playDate: json['play_date'] is String
          ? DateTime.parse(json['play_date']).toLocal()
          : DateTime.now(),
      startedAt: parseUtc(json['started_at']),
      endedAt: parseUtc(json['ended_at']),
      stats: statsRaw is Map
          ? BowlingStats.fromJson(Map<String, dynamic>.from(statsRaw))
          : BowlingStats.empty,
    );
  }
}
