/// 10핀 볼링 점수 계산을 위한 순수 함수 모음.
///
/// 입력은 `frames`: 길이 10의 리스트이며, 각 원소는 해당 프레임에서
/// 실제로 굴린 투구의 핀 수(0~10) 리스트이다. 미완성 프레임은 짧거나 비어 있을 수 있다.
///
/// 표준 USBC 규칙을 따른다:
///  - 1~9프레임: 1구 10 = 스트라이크(1구만), 1+2 = 10 = 스페어(2구), 그 외 = 오픈
///  - 스트라이크 보너스: 다음 2투구
///  - 스페어 보너스: 다음 1투구
///  - 10프레임: 1구 스트라이크 또는 1+2구 스페어면 3구까지 진행
///    1구 스트라이크 후 2구가 스트라이크가 아니면, 3구는 남은 핀으로 플레이(핀 리셋 X).
class BowlingScorer {
  BowlingScorer._();

  /// 1~9프레임 스트라이크 여부 (10프레임은 false 반환 - 보너스 산정 대상 아님)
  static bool isStrike(List<List<int>> frames, int frameIndex) {
    // 10프레임(index 9)은 보너스 산정 대상이 아니므로 false. (문서와 일치)
    if (frameIndex < 0 || frameIndex >= 9) return false;
    final f = frames[frameIndex];
    if (f.isEmpty) return false;
    return f[0] == 10;
  }

  /// 1~9프레임 스페어 여부.
  static bool isSpare(List<List<int>> frames, int frameIndex) {
    if (frameIndex < 0 || frameIndex >= 9) return false;
    final f = frames[frameIndex];
    if (f.length < 2) return false;
    return f[0] != 10 && f[0] + f[1] == 10;
  }

  /// 해당 프레임이 완료 상태인지.
  static bool isFrameComplete(List<List<int>> frames, int frameIndex) {
    final f = frames[frameIndex];
    if (frameIndex < 9) {
      if (f.isEmpty) return false;
      if (f[0] == 10) return true;
      return f.length >= 2;
    }
    if (f.length < 2) return false;
    if (f[0] == 10 || f[0] + f[1] == 10) return f.length >= 3;
    return f.length >= 2;
  }

  /// 스트라이크 보너스 산정용 - 다음 2투구의 합. 부족하면 null.
  static int? nextTwoThrows(List<List<int>> frames, int frameIndex) {
    final throws = <int>[];
    for (int i = frameIndex + 1; i < 10 && throws.length < 2; i++) {
      for (final pin in frames[i]) {
        throws.add(pin);
        if (throws.length == 2) break;
      }
    }
    if (throws.length < 2) return null;
    return throws[0] + throws[1];
  }

  /// 스페어 보너스 산정용 - 다음 1투구. 부족하면 null.
  static int? nextOneThrow(List<List<int>> frames, int frameIndex) {
    for (int i = frameIndex + 1; i < 10; i++) {
      if (frames[i].isNotEmpty) return frames[i][0];
    }
    return null;
  }

  /// 각 프레임의 누적 점수. 보너스 산정이 불가능한(아직 던지지 않은) 프레임은 null.
  static List<int?> cumulativeScores(List<List<int>> frames) {
    final scores = List<int?>.filled(10, null);
    int cumulative = 0;

    for (int i = 0; i < 10; i++) {
      final f = frames[i];
      if (f.isEmpty) break;

      if (i < 9) {
        if (isStrike(frames, i)) {
          final bonus = nextTwoThrows(frames, i);
          if (bonus == null) break;
          cumulative += 10 + bonus;
          scores[i] = cumulative;
        } else if (isSpare(frames, i)) {
          final bonus = nextOneThrow(frames, i);
          if (bonus == null) break;
          cumulative += 10 + bonus;
          scores[i] = cumulative;
        } else if (f.length >= 2) {
          cumulative += f[0] + f[1];
          scores[i] = cumulative;
        }
      } else {
        if (!isFrameComplete(frames, 9)) break;
        int sum = 0;
        for (final pin in f) {
          sum += pin;
        }
        cumulative += sum;
        scores[i] = cumulative;
      }
    }
    return scores;
  }

  /// 현재까지의 총점.
  static int totalScore(List<List<int>> frames) {
    final scores = cumulativeScores(frames);
    for (int i = 9; i >= 0; i--) {
      if (scores[i] != null) return scores[i]!;
    }
    return 0;
  }

  /// 스트라이크/스페어/오픈 개수.
  ///
  /// 10프레임 규칙:
  ///  - 1구가 10 → strikes++
  ///  - 1구가 10이고 2구도 10 → strikes++ (두 번째 스트라이크)
  ///  - 3구가 10 → strikes++
  ///  - 1구가 10이 아니면서 1+2구가 10 → spares++
  ///  - 1구가 10이면서(핀 리셋된 새 세트) 2구 != 10이고 2+3구가 10 → spares++
  ///    (1구 비스트라이크 시 2+3구 합산은 1+2 스페어와 동일한 세트의 잔여 핀이므로
  ///     별도 스페어로 카운트하지 않는다 - 이중 카운트 방지)
  ///  - 1구가 10이 아니면서 1+2 < 10 → opens++
  static ({int strikes, int spares, int opens}) computeStats(
      List<List<int>> frames) {
    int strikes = 0;
    int spares = 0;
    int opens = 0;

    for (int i = 0; i < 10; i++) {
      final f = frames[i];
      if (f.isEmpty) continue;

      if (i < 9) {
        if (f[0] == 10) {
          strikes++;
        } else if (f.length >= 2 && f[0] + f[1] == 10) {
          spares++;
        } else if (f.length >= 2) {
          opens++;
        }
      } else {
        if (f[0] == 10) strikes++;
        if (f.length >= 2) {
          if (f[0] != 10 && f[0] + f[1] == 10) spares++;
          if (f[0] == 10 && f[1] == 10) strikes++;
          if (f[0] != 10 && f[0] + f[1] < 10) opens++;
        }
        if (f.length >= 3) {
          if (f[2] == 10) strikes++;
          if (f[0] == 10 && f[1] != 10 && f[1] + f[2] == 10) spares++;
        }
      }
    }

    return (strikes: strikes, spares: spares, opens: opens);
  }

  /// 한 게임 안에서 가장 길게 이어진 연속 스트라이크 길이를 반환한다.
  ///
  /// 1~9프레임은 1구가 10이면 스트라이크 1회로 카운트한다.
  /// 10프레임은 frame[0]/frame[1]/frame[2] 각각이 10일 때마다 스트라이크 1회씩
  /// 누적되며, **연속성**은 frame 사이에서 끊기지 않고 이어진다.
  ///
  /// 예) 9프레임 X + 10프레임 [10,10,5] = 3연속, 10프레임 [10,5,10] = 1연속 두 번.
  static int longestStrikeStreak(List<List<int>> frames) {
    int longest = 0;
    int current = 0;

    void hit(bool isStrike) {
      if (isStrike) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }

    for (int i = 0; i < 9; i++) {
      final f = frames[i];
      if (f.isEmpty) {
        // 아직 투구 없음 - 연속 계산을 중단(미완성 프레임은 streak를 끊지 않음)
        return longest;
      }
      hit(f[0] == 10);
    }

    final tenth = frames[9];
    if (tenth.isEmpty) return longest;
    // 10프레임은 각 투구를 독립적인 strike 후보로 본다.
    // 1구가 strike가 아니면 거기서 끊기고 더 이상 비교할 strike 후보가 없다(2/3구는
    // strike가 될 수 없는 위치이므로).
    hit(tenth[0] == 10);
    if (tenth.length >= 2) {
      // 1구가 strike였을 때만 2구가 strike 후보(핀 리셋).
      // 1구가 strike가 아니면 2구가 10이어도 그것은 spare의 일부이며 strike가 아니다.
      if (tenth[0] == 10) {
        hit(tenth[1] == 10);
      } else {
        // streak 계속 0
      }
    }
    if (tenth.length >= 3) {
      // 3구가 strike인지 판정.
      // 핀 리셋 조건: 1-2구가 둘 다 strike이거나, 1+2가 스페어(핀 리셋된 새 세트).
      final resetForThird = (tenth[0] == 10 && tenth[1] == 10) ||
          (tenth[0] != 10 && tenth[0] + tenth[1] == 10);
      if (resetForThird) {
        hit(tenth[2] == 10);
      }
    }

    return longest;
  }
}
