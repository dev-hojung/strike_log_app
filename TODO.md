# TODO — 다음 세션에 이어서 할 일

> 마지막 업데이트: 2026-04-15
> 관련 레포: `strike_log_app`, `strike_log_api`

## 🔥 우선순위: 중

### 1. 드래프트 자동 재시도 성공 시 홈 화면 배너 UI
- **현재 상태**: `MainContainer.initState`와 `didPopNext`에서 `_retryPendingDrafts()` 자동 실행, 성공 건수를 `SnackBar`로만 알림 (짧은 노출)
- **할 일**: 홈 대시보드 상단에 dismissible 배너로 "N개의 미저장 경기가 자동 저장되었습니다" 노출. 실패 건은 "재시도" 버튼 제공
- **관련 파일**:
  - `lib/core/widgets/main_container.dart:_retryPendingDrafts`
  - `lib/features/home/presentation/pages/home_dashboard_page.dart`
  - `lib/features/game/data/services/game_draft_repository.dart`

### 2. 서버 `handleDisconnect`에서 좀비 참가자 정리
- **현재 상태**: `game-rooms.gateway.ts:30-39` `handleDisconnect`가 `roomClients` 소켓 추적만 정리하고 `activeRooms[roomId].participants`는 건드리지 않음
- **문제**: 유저가 앱 강제 종료, 네트워크 끊김 등으로 socket이 죽어도 participants 맵에는 남아있음 → 방 리스트에 유령 유저
- **할 일**: `handleDisconnect` 훅에서 해당 client의 user_id를 찾아 모든 참가 중인 방에서 `leaveRoom` 호출
- **관련 파일**:
  - `strike_log_api/src/game-rooms/game-rooms.gateway.ts:30`
  - 보조로 client.id → user_id 매핑 저장소 필요 (connection 시 매핑, disconnect 시 조회)

### 3. 실제 게임 플레이 시작/종료 시각 분리 저장
- **현재 상태**: `games.play_date`는 MySQL DATE(날짜만), `created_at`은 저장 시각
- **부족**: 게임의 실제 시작·종료 시각(플레이 소요 시간 등 통계에 활용 가능한 값)이 DB에 없음. 클라이언트에서 `_gameStartedAt`은 있지만 서버로 안 보냄
- **할 일**:
  - `games` 엔티티에 `started_at: datetime`, `ended_at: datetime` 컬럼 추가
  - 클라이언트 저장 payload에 `started_at`, `ended_at` 포함 (UTC ISO)
  - 기록 상세 화면에 "플레이 시간" 표시 (선택)
- **관련 파일**:
  - `strike_log_api/src/games/entities/game.entity.ts`
  - `strike_log_app/lib/features/game/presentation/pages/club_game_summary_page.dart:_saveGame`
  - `strike_log_app/lib/features/game/presentation/pages/game_summary_page.dart:_saveGame`

## 🧹 우선순위: 하 (클린업)

### 4. `_buildParticipantScores` 미사용 코드 정리
- **현재 상태**: `frame_entry_page.dart:917` 근처에 주석처리된 참가자 점수 UI 메서드가 남아 flutter analyze에서 `unused_element` warning 발생
- **할 일**: 진짜 사용 계획 없으면 삭제, 있으면 주석 해제 후 활성화

### 5. `socket_service.dart` production print 정리
- **현재 상태**: `avoid_print` lint info 4건
- **할 일**: `kDebugMode` 가드로 감싸거나 `developer.log` 사용

### 6. `BuildContext across async gaps` info 정리
- **현재 상태**: `club_game_summary_page.dart`, `game_summary_page.dart`의 PopScope `onPopInvokedWithResult` 핸들러에서 info 4건
- **할 일**: `_showExitConfirmDialog` 결과를 받기 전후에 명시적으로 `if (!mounted) return;` 추가하거나 analyzer ignore 주석

## 📌 참고 (이미 해결됨, 기록용)

- ✅ `game-rooms.service.spec.ts` 오래된 시그니처로 컴파일 에러 → 수정 + 4개 테스트 추가
- ✅ 소켓 listener 중복 등록으로 `setState after dispose` → `_setupSocketListeners` off 선행
- ✅ iOS에서 RouteAware didPopNext 안 뜸 → `RouteObserver<PageRoute<dynamic>>`로 타입 완화
- ✅ participants 리스트 공유 참조 버그 → `_isGameStarted` 플래그 + deep copy
- ✅ Bottom overflow 85px → `Flexible` 제거

## 🔗 오늘 커밋

- `strike_log_app` `56dfa4a` — 클럽 경기 요약 페이지, 저장 안정성 및 대시보드 자동 갱신 개선
- `strike_log_app` `04b5500` — iOS에서 저장 후 대시보드 자동 갱신 안 되는 문제 해결
- `strike_log_api` `77d9d08` — 클럽 게임 기록 저장/조회 및 실시간 통계 지원
