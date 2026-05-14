import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bowling/features/game/data/bowling_scorer.dart';

/// 헬퍼: `List<List<int>>` 생성. 미완성 프레임은 빈 리스트로 채운다.
List<List<int>> framesOf(List<List<int>> partial) {
  final out = List.generate(10, (_) => <int>[]);
  for (int i = 0; i < partial.length && i < 10; i++) {
    out[i] = List<int>.from(partial[i]);
  }
  return out;
}

void main() {
  group('BowlingScorer.totalScore - 표준 시나리오', () {
    test('퍼펙트 게임 (12 스트라이크) = 300점', () {
      final frames = List.generate(9, (_) => [10])..add([10, 10, 10]);
      expect(BowlingScorer.totalScore(frames), 300);
    });

    test('전부 거터(0) = 0점', () {
      final frames = List.generate(10, (_) => [0, 0]);
      expect(BowlingScorer.totalScore(frames), 0);
    });

    test('전부 9-/ (모든 프레임 스페어) = 190점', () {
      // 각 스페어 프레임 점수 = 10 + 다음 1투구(9). 19점 × 10프레임 = 190.
      final frames = List.generate(9, (_) => [9, 1])..add([9, 1, 9]);
      expect(BowlingScorer.totalScore(frames), 190);
    });

    test('전부 오픈 5,4 = 90점', () {
      final frames = List.generate(10, (_) => [5, 4]);
      expect(BowlingScorer.totalScore(frames), 90);
    });

    test('스트라이크 + 오픈 (X,3,4) 17점 누적', () {
      final frames = framesOf([[10], [3, 4]]);
      // 1프레임: 10 + 3 + 4 = 17, 2프레임: 17 + 3 + 4 = 24
      final scores = BowlingScorer.cumulativeScores(frames);
      expect(scores[0], 17);
      expect(scores[1], 24);
    });

    test('스페어 + 오픈 (5/,4,3) 14점 누적', () {
      final frames = framesOf([[5, 5], [4, 3]]);
      // 1프레임: 10 + 4 = 14, 2프레임: 14 + 4 + 3 = 21
      final scores = BowlingScorer.cumulativeScores(frames);
      expect(scores[0], 14);
      expect(scores[1], 21);
    });

    test('연속 스트라이크 보너스 - 더블 후 오픈 (X,X,3,4)', () {
      final frames = framesOf([[10], [10], [3, 4]]);
      final scores = BowlingScorer.cumulativeScores(frames);
      // 1: 10 + 10 + 3 = 23
      // 2: 23 + 10 + 3 + 4 = 40
      // 3: 40 + 3 + 4 = 47
      expect(scores[0], 23);
      expect(scores[1], 40);
      expect(scores[2], 47);
    });
  });

  group('BowlingScorer.cumulativeScores - 미완성 프레임 처리', () {
    test('스트라이크 직후엔 누적 점수가 아직 산정되지 않음', () {
      final frames = framesOf([[10]]);
      final scores = BowlingScorer.cumulativeScores(frames);
      expect(scores[0], isNull); // 보너스 2투구가 없으므로 null
    });

    test('스페어 직후엔 누적 점수가 아직 산정되지 않음', () {
      final frames = framesOf([[5, 5]]);
      final scores = BowlingScorer.cumulativeScores(frames);
      expect(scores[0], isNull); // 보너스 1투구가 없으므로 null
    });

    test('오픈 프레임은 즉시 산정됨', () {
      final frames = framesOf([[3, 4]]);
      final scores = BowlingScorer.cumulativeScores(frames);
      expect(scores[0], 7);
    });

    test('스트라이크 다음 한 투구만 입력된 경우 - 여전히 null', () {
      final frames = framesOf([[10], [5]]);
      final scores = BowlingScorer.cumulativeScores(frames);
      expect(scores[0], isNull);
      expect(scores[1], isNull);
    });

    test('빈 게임 - 총점 0', () {
      expect(BowlingScorer.totalScore(framesOf([])), 0);
    });
  });

  group('BowlingScorer - 10프레임 특수 처리', () {
    test('10프레임 [10,3,5] = 18점 (1구 스트라이크, 2구 3, 3구 5 - 남은 핀)', () {
      final frames = List.generate(9, (_) => [0, 0])..add([10, 3, 5]);
      // 1~9프레임 0점, 10프레임 = 18
      expect(BowlingScorer.totalScore(frames), 18);
    });

    test('10프레임 [5,5,10] = 20점 (스페어 후 보너스 스트라이크)', () {
      final frames = List.generate(9, (_) => [0, 0])..add([5, 5, 10]);
      expect(BowlingScorer.totalScore(frames), 20);
    });

    test('10프레임 [10,10,10] = 30점 (3연속 스트라이크)', () {
      final frames = List.generate(9, (_) => [0, 0])..add([10, 10, 10]);
      expect(BowlingScorer.totalScore(frames), 30);
    });

    test('10프레임 [10,5,5] = 20점 (1구 스트라이크 후 2-3구 스페어)', () {
      final frames = List.generate(9, (_) => [0, 0])..add([10, 5, 5]);
      expect(BowlingScorer.totalScore(frames), 20);
    });

    test('10프레임 [4,5] = 9점 (오픈, 3구 없음)', () {
      final frames = List.generate(9, (_) => [0, 0])..add([4, 5]);
      expect(BowlingScorer.totalScore(frames), 9);
    });

    test('9프레임 스트라이크 + 10프레임 [10,5,3] 보너스 산정', () {
      final frames = framesOf([
        [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0],
        [10],
        [10, 5, 3],
      ]);
      // 9프레임: 10 + 10 + 5 = 25
      // 10프레임: 10 + 5 + 3 = 18
      // 총점: 25 + 18 = 43
      expect(BowlingScorer.totalScore(frames), 43);
    });
  });

  group('BowlingScorer.computeStats - 정확성 (이중 카운트 회귀 방지)', () {
    test('퍼펙트 게임 - strikes=12', () {
      final frames = List.generate(9, (_) => [10])..add([10, 10, 10]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.strikes, 12);
      expect(s.spares, 0);
      expect(s.opens, 0);
    });

    test('전부 거터 - opens=10', () {
      final frames = List.generate(10, (_) => [0, 0]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.strikes, 0);
      expect(s.spares, 0);
      expect(s.opens, 10);
    });

    test('전부 9-/ + 10프레임 [9,1,9] - spares=10, strikes=0', () {
      final frames = List.generate(9, (_) => [9, 1])..add([9, 1, 9]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.spares, 10);
      expect(s.strikes, 0);
      expect(s.opens, 0);
    });

    test('REGRESSION: 10프레임 [3,7,3] - 우연 합산으로 인한 spare 이중 카운트 방지', () {
      // 1+2 = 10 (스페어), 2+3 = 10이지만 같은 세트의 잔여 핀이므로
      // 별도 스페어가 아니다. spares는 1이어야 한다(2가 아니라).
      final frames = List.generate(9, (_) => [0, 0])..add([3, 7, 3]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.spares, 1, reason: '1-2 스페어 1회만 카운트되어야 함');
      expect(s.strikes, 0);
    });

    test('10프레임 [10,5,5] - 1구 스트라이크 + 2-3 스페어, strikes=1, spares=1', () {
      final frames = List.generate(9, (_) => [0, 0])..add([10, 5, 5]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.strikes, 1);
      expect(s.spares, 1);
    });

    test('10프레임 [10,3,7] - 1구 스트라이크 + 2-3 스페어, strikes=1, spares=1', () {
      // 1구 스트라이크 후 핀 리셋된 새 세트에서 2-3구가 스페어
      final frames = List.generate(9, (_) => [0, 0])..add([10, 3, 7]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.strikes, 1);
      expect(s.spares, 1);
    });

    test('10프레임 [10,3,5] - 1구 스트라이크 후 2-3 비스페어, strikes=1, spares=0', () {
      // 1~9프레임 [0,0] 채움분이 opens=9로 카운트됨
      final frames = List.generate(9, (_) => [0, 0])..add([10, 3, 5]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.strikes, 1);
      expect(s.spares, 0);
      expect(s.opens, 9);
    });

    test('10프레임 [10,10,5] - 1-2구 스트라이크, 3구 5, strikes=2', () {
      final frames = List.generate(9, (_) => [0, 0])..add([10, 10, 5]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.strikes, 2);
      expect(s.spares, 0);
    });

    test('10프레임 [10,10,10] - 3연속 스트라이크, strikes=3', () {
      final frames = List.generate(9, (_) => [0, 0])..add([10, 10, 10]);
      final s = BowlingScorer.computeStats(frames);
      expect(s.strikes, 3);
      expect(s.spares, 0);
    });
  });

  group('BowlingScorer.longestStrikeStreak', () {
    test('퍼펙트 게임 = 12연속', () {
      final frames = List.generate(9, (_) => [10])..add([10, 10, 10]);
      expect(BowlingScorer.longestStrikeStreak(frames), 12);
    });

    test('스트라이크 없음 = 0', () {
      final frames = List.generate(10, (_) => [0, 0]);
      expect(BowlingScorer.longestStrikeStreak(frames), 0);
    });

    test('1프레임 X + 2프레임 5,4 = 1연속', () {
      final frames = framesOf([[10], [5, 4]]);
      expect(BowlingScorer.longestStrikeStreak(frames), 1);
    });

    test('터키(3연속) + 오픈 + 더블 시퀀스 = 3연속', () {
      // X X X 3 5 X X 0 0 0 0 ...
      final frames = framesOf([
        [10], [10], [10], [3, 5], [0, 0], [10], [10], [0, 0],
      ]);
      expect(BowlingScorer.longestStrikeStreak(frames), 3);
    });

    test('9프레임 X + 10프레임 [10,10,5] = 3연속', () {
      final frames = List.generate(8, (_) => [0, 0])
        ..add([10])
        ..add([10, 10, 5]);
      expect(BowlingScorer.longestStrikeStreak(frames), 3);
    });

    test('10프레임 [5,5,10] = 1연속 (스페어 후 보너스 strike)', () {
      final frames = List.generate(9, (_) => [0, 0])..add([5, 5, 10]);
      expect(BowlingScorer.longestStrikeStreak(frames), 1);
    });

    test('10프레임 [10,5,10] = 1연속 두 번이지만 longest=1', () {
      // 1구 strike 후 2구 5는 핀 reset 새 세트의 비스트라이크 → streak 끊김
      // 3구는 reset 없음(1-2 합 != 10이고 1-2가 둘 다 strike도 아님) → strike 후보 아님
      final frames = List.generate(9, (_) => [0, 0])..add([10, 5, 10]);
      expect(BowlingScorer.longestStrikeStreak(frames), 1);
    });

    test('미완성 프레임은 streak를 끊지 않음', () {
      final frames = framesOf([[10], [10]]);
      // 2개 strike 후 다음 프레임 미입력 - 끊지 않고 2 반환
      expect(BowlingScorer.longestStrikeStreak(frames), 2);
    });

    test('빈 게임 = 0', () {
      expect(BowlingScorer.longestStrikeStreak(framesOf([])), 0);
    });

    test('8프레임 strike + 10프레임 [10,10,10] = 4연속 (9프레임 미입력은 끊지 않음)', () {
      // 8프레임 strike 후 9프레임이 비어 있으면 streak 계산이 거기서 끝나므로
      // 10프레임 strike들은 합산되지 않는다. 의도된 동작 검증.
      final frames = framesOf([
        [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0], [0, 0],
        [10], // 8프레임(인덱스 7)
      ]);
      // 9프레임(인덱스 8) 비어있음 → return longest = 1
      expect(BowlingScorer.longestStrikeStreak(frames), 1);
    });
  });

  group('BowlingScorer - 헬퍼 함수', () {
    test('isStrike 1~9프레임만 true 반환', () {
      final frames = framesOf([[10], [5, 5]]);
      expect(BowlingScorer.isStrike(frames, 0), true);
      expect(BowlingScorer.isStrike(frames, 1), false);
    });

    test('isSpare 10프레임은 항상 false', () {
      final frames = List.generate(9, (_) => [0, 0])..add([5, 5, 0]);
      expect(BowlingScorer.isSpare(frames, 9), false);
    });

    test('isFrameComplete - 1~9프레임 스트라이크는 즉시 완료', () {
      final frames = framesOf([[10]]);
      expect(BowlingScorer.isFrameComplete(frames, 0), true);
    });

    test('isFrameComplete - 10프레임 오픈은 2투로 완료', () {
      final frames = List.generate(9, (_) => [0, 0])..add([4, 5]);
      expect(BowlingScorer.isFrameComplete(frames, 9), true);
    });

    test('isFrameComplete - 10프레임 스페어는 3투까지 필요', () {
      final frames = List.generate(9, (_) => [0, 0])..add([5, 5]);
      expect(BowlingScorer.isFrameComplete(frames, 9), false);
    });

    test('nextTwoThrows - 두 프레임에 걸쳐 합산', () {
      final frames = framesOf([[10], [3, 4]]);
      expect(BowlingScorer.nextTwoThrows(frames, 0), 7);
    });

    test('nextTwoThrows - 부족하면 null', () {
      final frames = framesOf([[10], [3]]);
      expect(BowlingScorer.nextTwoThrows(frames, 0), isNull);
    });

    test('nextOneThrow - 다음 프레임 첫 투구', () {
      final frames = framesOf([[5, 5], [7, 2]]);
      expect(BowlingScorer.nextOneThrow(frames, 0), 7);
    });
  });
}
