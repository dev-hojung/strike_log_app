/// P2 기록·분석 고도화용 모델.
///
/// 백엔드 계약:
/// - GET /games/users/:id/center-stats     → `List<CenterStat>`
/// - GET /games/users/:id/monthly-averages → `List<MonthlyAverage>`
/// - GET /games/users/:id/statistics?trend= → StatsSummary (recentTrend 포함)
library;

/// 볼링장별 통계 1건.
class CenterStat {
  const CenterStat({
    required this.center,
    required this.gameCount,
    required this.averageScore,
    required this.highestScore,
    this.lastPlayed,
  });

  /// 볼링장 표시명. 미기입 게임은 "미지정".
  final String center;
  final int gameCount;
  final int averageScore;
  final int highestScore;
  final DateTime? lastPlayed;

  factory CenterStat.fromJson(Map<String, dynamic> json) {
    return CenterStat(
      center: (json['center'] ?? '미지정').toString(),
      gameCount: (json['gameCount'] as num?)?.toInt() ?? 0,
      averageScore: (json['averageScore'] as num?)?.toInt() ?? 0,
      highestScore: (json['highestScore'] as num?)?.toInt() ?? 0,
      lastPlayed: json['lastPlayed'] != null
          ? DateTime.tryParse(json['lastPlayed'].toString())
          : null,
    );
  }
}

/// 월별 평균 1건. 게임이 없는 달은 [averageScore]가 null.
class MonthlyAverage {
  const MonthlyAverage({
    required this.ym,
    required this.averageScore,
    required this.gameCount,
  });

  /// "YYYY-MM".
  final String ym;
  final int? averageScore;
  final int gameCount;

  /// 막대 그래프용 월 라벨 (예: "7월").
  String get monthLabel {
    final parts = ym.split('-');
    if (parts.length == 2) {
      final m = int.tryParse(parts[1]);
      if (m != null) return '$m월';
    }
    return ym;
  }

  factory MonthlyAverage.fromJson(Map<String, dynamic> json) {
    return MonthlyAverage(
      ym: (json['ym'] ?? '').toString(),
      averageScore: (json['averageScore'] as num?)?.toInt(),
      gameCount: (json['gameCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 최근 추세 게임 1건 (점수 + 구질 카운트).
class StatsTrendPoint {
  const StatsTrendPoint({
    required this.score,
    this.date,
    required this.strikes,
    required this.spares,
    required this.opens,
  });

  final int score;
  final DateTime? date;
  final int strikes;
  final int spares;
  final int opens;

  factory StatsTrendPoint.fromJson(Map<String, dynamic> json) {
    return StatsTrendPoint(
      score: (json['score'] as num?)?.toInt() ?? 0,
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      strikes: (json['strikes'] as num?)?.toInt() ?? 0,
      spares: (json['spares'] as num?)?.toInt() ?? 0,
      opens: (json['opens'] as num?)?.toInt() ?? 0,
    );
  }
}

/// /statistics 응답 요약 (분석 화면용에 필요한 필드만).
class StatsSummary {
  const StatsSummary({
    required this.averageScore,
    required this.personalAverageScore,
    required this.clubAverageScore,
    required this.highestScore,
    required this.recentTrend,
    required this.monthlyTrendStatus,
    this.monthlyTrendPercentage,
    this.currentMonthAvg,
    this.lastMonthAvg,
  });

  final int averageScore;
  final int personalAverageScore;
  final int clubAverageScore;
  final int highestScore;
  final List<StatsTrendPoint> recentTrend;

  /// 'both' | 'current_only' | 'last_only' | 'none'
  final String monthlyTrendStatus;
  final double? monthlyTrendPercentage;
  final int? currentMonthAvg;
  final int? lastMonthAvg;

  /// 전체 추세 구질 합계 (도넛 차트용).
  int get totalStrikes => recentTrend.fold(0, (s, p) => s + p.strikes);
  int get totalSpares => recentTrend.fold(0, (s, p) => s + p.spares);
  int get totalOpens => recentTrend.fold(0, (s, p) => s + p.opens);

  /// 최근 5경기 평균 (없으면 null).
  int? get recentForm {
    if (recentTrend.isEmpty) return null;
    // recentTrend는 오래된→최신 순. 마지막 5개가 최신.
    final last5 = recentTrend.length <= 5
        ? recentTrend
        : recentTrend.sublist(recentTrend.length - 5);
    if (last5.isEmpty) return null;
    final sum = last5.fold(0, (s, p) => s + p.score);
    return (sum / last5.length).round();
  }

  factory StatsSummary.fromJson(Map<String, dynamic> json) {
    final monthly = json['monthlyTrend'] is Map
        ? Map<String, dynamic>.from(json['monthlyTrend'] as Map)
        : <String, dynamic>{};
    return StatsSummary(
      averageScore: (json['averageScore'] as num?)?.toInt() ?? 0,
      personalAverageScore: (json['personalAverageScore'] as num?)?.toInt() ?? 0,
      clubAverageScore: (json['clubAverageScore'] as num?)?.toInt() ?? 0,
      highestScore: (json['highestScore'] as num?)?.toInt() ?? 0,
      recentTrend: json['recentTrend'] is List
          ? (json['recentTrend'] as List)
              .map((e) => StatsTrendPoint.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      monthlyTrendStatus: (monthly['status'] ?? 'none').toString(),
      monthlyTrendPercentage: (monthly['percentage'] as num?)?.toDouble(),
      currentMonthAvg: (monthly['currentMonthAvg'] as num?)?.toInt(),
      lastMonthAvg: (monthly['lastMonthAvg'] as num?)?.toInt(),
    );
  }
}
