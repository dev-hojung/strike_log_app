/// `/games/:id/detail` 응답 모델. 프레임 단위 상세 점수 포함.
class GameDetail {
  final int id;
  final int totalScore;
  final DateTime playDate;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? location;
  final bool isClubGame;
  final int? seriesId;
  final int? seriesIndex;

  /// 길이 10. 각 프레임의 실제 투구만 모은 배열 (BowlingScorer에 그대로 입력 가능).
  final List<List<int>> frames;

  /// 각 프레임의 누적 점수(서버 저장값). null이면 미완성.
  final List<int?> cumulativeScores;

  GameDetail({
    required this.id,
    required this.totalScore,
    required this.playDate,
    this.createdAt,
    this.startedAt,
    this.endedAt,
    this.location,
    this.isClubGame = false,
    this.seriesId,
    this.seriesIndex,
    required this.frames,
    required this.cumulativeScores,
  });

  factory GameDetail.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(dynamic v) =>
        v is String ? DateTime.parse(v).toLocal() : null;

    final framesList = List<List<int>>.generate(10, (_) => <int>[]);
    final cumList = List<int?>.filled(10, null);
    final rawFrames = json['frames'];
    if (rawFrames is List) {
      for (final f in rawFrames) {
        if (f is! Map) continue;
        final frameNumber = (f['frame_number'] as num?)?.toInt();
        if (frameNumber == null || frameNumber < 1 || frameNumber > 10) {
          continue;
        }
        final i = frameNumber - 1;
        final first = f['first_roll'];
        final second = f['second_roll'];
        final third = f['third_roll'];
        final pins = <int>[
          if (first is num) first.toInt(),
          if (second is num) second.toInt(),
          if (third is num) third.toInt(),
        ];
        framesList[i] = pins;
        final s = f['score'];
        if (s is num) cumList[i] = s.toInt();
      }
    }

    return GameDetail(
      id: (json['id'] as num).toInt(),
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      playDate: json['play_date'] is String
          ? DateTime.parse(json['play_date'])
          : DateTime.now(),
      createdAt: parseUtc(json['created_at']),
      startedAt: parseUtc(json['started_at']),
      endedAt: parseUtc(json['ended_at']),
      location: json['location'] as String?,
      isClubGame: json['is_club_game'] == true,
      seriesId: (json['series_id'] as num?)?.toInt(),
      seriesIndex: (json['series_index'] as num?)?.toInt(),
      frames: framesList,
      cumulativeScores: cumList,
    );
  }
}
