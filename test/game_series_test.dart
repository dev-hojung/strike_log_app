import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bowling/features/game/data/models/game_series.dart';

void main() {
  group('GameSeries.fromJson', () {
    test('전체 필드 포함된 정상 응답 파싱', () {
      final json = {
        'id': 12,
        'user_id': 'user-uuid',
        'target_game_count': 3,
        'started_at': '2026-05-14T01:00:00.000Z',
        'completed_at': '2026-05-14T02:15:00.000Z',
        'game_count': 3,
        'total_score': 520,
        'average_score': 173.33,
        'games': [
          {
            'id': 101,
            'series_index': 1,
            'total_score': 180,
            'play_date': '2026-05-14',
            'started_at': '2026-05-14T01:00:00.000Z',
            'ended_at': '2026-05-14T01:20:00.000Z',
          },
          {
            'id': 102,
            'series_index': 2,
            'total_score': 170,
            'play_date': '2026-05-14',
          },
          {
            'id': 103,
            'series_index': 3,
            'total_score': 170,
            'play_date': '2026-05-14',
          },
        ],
      };

      final series = GameSeries.fromJson(json);
      expect(series.id, 12);
      expect(series.userId, 'user-uuid');
      expect(series.targetGameCount, 3);
      expect(series.gameCount, 3);
      expect(series.totalScore, 520);
      expect(series.averageScore, closeTo(173.33, 0.01));
      expect(series.games.length, 3);
      expect(series.games[0].id, 101);
      expect(series.games[0].seriesIndex, 1);
      expect(series.games[0].totalScore, 180);
      expect(series.isCompleted, true);
      expect(series.isReadyToComplete, true);
    });

    test('completed_at이 null이면 isCompleted=false', () {
      final json = {
        'id': 1,
        'user_id': 'u',
        'target_game_count': 3,
        'started_at': '2026-05-14T01:00:00.000Z',
        'completed_at': null,
        'game_count': 1,
        'total_score': 180,
        'average_score': 180.0,
        'games': [],
      };
      final series = GameSeries.fromJson(json);
      expect(series.isCompleted, false);
      expect(series.isReadyToComplete, false);
    });

    test('isReadyToComplete: game_count >= target', () {
      final json = {
        'id': 1,
        'user_id': 'u',
        'target_game_count': 3,
        'started_at': '2026-05-14T01:00:00.000Z',
        'completed_at': null,
        'game_count': 3,
        'total_score': 540,
        'average_score': 180.0,
        'games': [],
      };
      final series = GameSeries.fromJson(json);
      expect(series.isReadyToComplete, true);
    });

    test('games 배열 누락 시 빈 리스트', () {
      final json = {
        'id': 1,
        'user_id': 'u',
        'target_game_count': 3,
        'started_at': '2026-05-14T01:00:00.000Z',
        'completed_at': null,
        'game_count': 0,
        'total_score': 0,
        'average_score': 0,
      };
      final series = GameSeries.fromJson(json);
      expect(series.games, isEmpty);
    });
  });

  group('SeriesGame.fromJson', () {
    test('started_at/ended_at은 옵셔널', () {
      final game = SeriesGame.fromJson({
        'id': 101,
        'series_index': 1,
        'total_score': 180,
        'play_date': '2026-05-14',
      });
      expect(game.startedAt, isNull);
      expect(game.endedAt, isNull);
    });

    test('UTC 시각은 로컬로 변환', () {
      final game = SeriesGame.fromJson({
        'id': 101,
        'series_index': 1,
        'total_score': 180,
        'play_date': '2026-05-14',
        'started_at': '2026-05-14T01:00:00.000Z',
      });
      expect(game.startedAt, isNotNull);
      expect(game.startedAt!.isUtc, false);
    });
  });
}
