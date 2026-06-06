class WeeklyChallenge {
  final String key;
  final String name;
  final String description;
  final int target;
  final String unit;
  final int current;
  final int percent;
  final bool achieved;
  final DateTime? weekStart;
  final DateTime? weekEnd;

  const WeeklyChallenge({
    required this.key,
    required this.name,
    required this.description,
    required this.target,
    required this.unit,
    required this.current,
    required this.percent,
    required this.achieved,
    this.weekStart,
    this.weekEnd,
  });

  factory WeeklyChallenge.fromJson(Map<String, dynamic> json) {
    return WeeklyChallenge(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      target: (json['target'] as num?)?.toInt() ?? 0,
      unit: json['unit']?.toString() ?? '',
      current: (json['current'] as num?)?.toInt() ?? 0,
      percent: (json['percent'] as num?)?.toInt() ?? 0,
      achieved: json['achieved'] == true,
      weekStart: json['week_start'] != null
          ? DateTime.tryParse(json['week_start'].toString())
          : null,
      weekEnd: json['week_end'] != null
          ? DateTime.tryParse(json['week_end'].toString())
          : null,
    );
  }
}
