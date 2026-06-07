enum SystemNoticePriority { info, warning, critical }

class SystemNotice {
  final int id;
  final String title;
  final String body;
  final SystemNoticePriority priority;
  final bool dismissible;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  const SystemNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.dismissible,
    this.startsAt,
    this.endsAt,
    this.createdAt,
  });

  factory SystemNotice.fromJson(Map<String, dynamic> json) {
    return SystemNotice(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      priority: _parsePriority(json['priority']?.toString()),
      dismissible: json['dismissible'] == false ? false : true,
      startsAt: _parseDate(json['starts_at']),
      endsAt: _parseDate(json['ends_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static SystemNoticePriority _parsePriority(String? raw) {
    switch (raw) {
      case 'warning':
        return SystemNoticePriority.warning;
      case 'critical':
        return SystemNoticePriority.critical;
      default:
        return SystemNoticePriority.info;
    }
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
