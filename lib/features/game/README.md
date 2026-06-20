# Game — 볼링 점수 기록 / 통계 (핵심 도메인)

## 목적
10프레임 볼링 점수 입력·계산·저장 및 개인/시리즈/클럽 3가지 게임 모드 제공.
백엔드 응답에 동봉된 신규 배지를 모달로 노출.

## 페이지
- `GameModePage` — 모드 선택 (개인/시리즈/클럽/내기), 위치 입력
  - 노출 조건: 개인·시리즈·내기는 누구나. **클럽 게임은 클럽 무료 체험(`club_trial_status == 'active'`)일 때만 노출.**
  - 내기 게임은 클럽 불필요(방 코드로 친구 초대) — 서버도 `mode='bet'`은 체험 검사 면제(`game-rooms.gateway.ts`).
- `GameRoomPage` — 클럽/내기 게임 대기실 (Socket.IO). `mode='bet'`이면 핸디캡 UI.
- `FrameEntryPage` — 10프레임 점수 입력 + 클럽 게임 라이브 순위표 + 시리즈 인디케이터
- `GameSummaryPage` — 단일 게임 결과 (베스트 갱신 배너, 스트릭 하이라이트)
- `SeriesSummaryPage` — 시리즈 종합 결과
- `ClubGameSummaryPage` — 클럽 게임 우승자/순위표
- `GameHistoryPage` — 월별 그룹 + 시리즈 묶음 표시, 에러 시 ErrorRetryView
- `GameDetailPage` — 단건 상세 + 결과 이미지 공유
- `GameRoomPage` — 클럽 게임 대기실 (Socket.IO)

## 데이터 모델
- `data/bowling_scorer.dart` — 순수 점수 계산 모듈 (`totalScore`, `cumulativeScores`, `longestStrikeStreak`, `computeStats`)
- `data/models/game_detail.dart` — 게임 상세
- `data/models/game_series.dart` — 시리즈 메타

## 서비스
- `GameApiService` — 게임 목록·통계·상세 조회
- `SeriesApiService` — 시리즈 라이프사이클
- `GameSaveService` — 게임 저장 + 자동 재시도(3회) + `GameSaveResult.newlyEarnedBadges` 응답 추출
- `GameDraftRepository` — 네트워크 실패 시 로컬 드래프트 보관 (SharedPreferences)

## 백엔드 엔드포인트
| Method | Path | 용도 |
|--------|------|------|
| POST   | `/games`                                      | 게임 저장 (응답에 `newly_earned_badges`) |
| GET    | `/games/me`                                   | 내 게임 목록 |
| GET    | `/games/users/:user_id/statistics`            | 평균/최고/최근10 |
| GET    | `/games/users/:user_id/recent`                | 최근 게임 1건 |
| GET    | `/games/users/:user_id/monthly-frame-stats`   | 이번 달 스트라이크/스페어/오픈 |
| GET    | `/games/:id/detail`                           | 게임 상세 |
| GET    | `/games/club/:room_id`                        | 클럽 게임 방 전원 |
| POST   | `/game-series`                                | 시리즈 시작 |
| POST   | `/game-series/:id/complete`                   | 시리즈 종료 |
| GET    | `/game-series/:id`                            | 시리즈 + 게임 목록 |
| GET    | `/game-series/users/:userId/recent`           | 최근 시리즈 목록 |
| GET    | `/game-series/users/:userId/best`             | 베스트 시리즈 |

## 의존성
- `core/services/socket_service.dart` — 클럽 게임 실시간 점수 공유 (`roomStateUpdated`)
- `core/services/share_capture.dart` — 결과 이미지 공유
- `features/badges/.../new_badges_dialog.dart` — 게임 저장 직후 신규 배지 모달

## 주요 동작 흐름
1. `GameModePage`에서 모드 선택 → `FrameEntryPage` 진입
2. 점수 입력 시마다 `BowlingScorer.totalScore` 재계산 + 클럽 게임이면 `SocketService.sendScoreUpdate`
3. 게임 완료 → 모드별 Summary 페이지 → `GameSaveService.saveGame` → 신규 배지 모달
4. 시리즈: 마지막 게임이면 `completeSeries` 호출 후 `SeriesSummaryPage`
