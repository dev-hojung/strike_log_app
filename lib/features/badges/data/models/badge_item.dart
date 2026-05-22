/// 배지 카탈로그 카테고리 — 백엔드 `BadgeCategory`와 동일 문자열.
enum BadgeCategory {
  milestone,
  score,
  strike,
  series,
  streak,
  club,
  unknown;

  String get label {
    switch (this) {
      case BadgeCategory.milestone:
        return '마일스톤';
      case BadgeCategory.score:
        return '점수';
      case BadgeCategory.strike:
        return '스트라이크';
      case BadgeCategory.series:
        return '시리즈';
      case BadgeCategory.streak:
        return '출석';
      case BadgeCategory.club:
        return '클럽';
      case BadgeCategory.unknown:
        return '기타';
    }
  }

  static BadgeCategory fromString(String? raw) {
    switch (raw) {
      case 'milestone':
        return BadgeCategory.milestone;
      case 'score':
        return BadgeCategory.score;
      case 'strike':
        return BadgeCategory.strike;
      case 'series':
        return BadgeCategory.series;
      case 'streak':
        return BadgeCategory.streak;
      case 'club':
        return BadgeCategory.club;
      default:
        return BadgeCategory.unknown;
    }
  }
}

/// 배지 단건 (카탈로그 + 본인 획득 여부).
class BadgeItem {
  final String key;
  final BadgeCategory category;
  final String name;
  final String description;
  final int? threshold;
  final bool earned;
  final DateTime? earnedAt;

  const BadgeItem({
    required this.key,
    required this.category,
    required this.name,
    required this.description,
    required this.threshold,
    required this.earned,
    required this.earnedAt,
  });

  factory BadgeItem.fromJson(Map<String, dynamic> json) {
    return BadgeItem(
      key: json['key']?.toString() ?? '',
      category: BadgeCategory.fromString(json['category']?.toString()),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      threshold: json['threshold'] is num ? (json['threshold'] as num).toInt() : null,
      earned: json['earned'] == true,
      earnedAt: json['earnedAt'] != null
          ? DateTime.tryParse(json['earnedAt'].toString())
          : null,
    );
  }
}

/// 출석 streak 요약.
class AttendanceStreak {
  final int currentStreak;
  final int longestStreak;

  const AttendanceStreak({
    required this.currentStreak,
    required this.longestStreak,
  });

  factory AttendanceStreak.fromJson(Map<String, dynamic> json) {
    return AttendanceStreak(
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
    );
  }
}
