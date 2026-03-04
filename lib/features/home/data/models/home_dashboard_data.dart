class HomeDashboardData {
  final int averageScore;
  final int highestScore;
  final DateTime? highestScoreDate;
  final List<TrendData> recentTrend;
  final RecentGame? recentGame;
  final String nickname;

  HomeDashboardData({
    required this.averageScore,
    required this.highestScore,
    this.highestScoreDate,
    required this.recentTrend,
    this.recentGame,
    this.nickname = 'Alex', // Default fallback
  });

  bool get isEmpty => averageScore == 0 && highestScore == 0 && recentGame == null;
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
