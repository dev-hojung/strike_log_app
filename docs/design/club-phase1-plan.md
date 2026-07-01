# Phase 1 상세 작업계획 — 정기전/모임 + 공지 확장

> 작성일: 2026-06-30 / 선행: [`club-features-prd.md`](./club-features-prd.md) §F1, §F3
> 범위: **F1 정기전/모임**(코어) + **F3 공지 확장**(소규모)
> 대상: `strike_log_api`(NestJS/TypeORM/MySQL) + `strike_log_app`(Flutter)

---

## 0. 확정 결정 (가정 — 변경 시 알려주세요)

| # | 결정 | 값 |
|---|---|---|
| D1 | 정기전↔게임 연결 | **(A) 정기전 안에서 클럽게임 시작 → `event_id` 자동 태깅.** 사후 수동 귀속은 차기 |
| D2 | 정기전 구독 게이트 | **클럽게임과 동일 게이트 적용**(구독/체험 active만 생성·플레이) |
| D3 | 레인 배치 계산 위치 | **서버**(저장 평균 일관성) — `members-with-stats` 평균 재사용 |
| D4 | 권한 | 생성·배치·완료·공지작성 = **`GroupRole.ADMIN`만** (`club-access.guard` 재사용) |

---

## 1. 기반 사실 (코드 확인 완료)

- `GroupRole` enum + `club-access.guard.ts` 존재 → 권한 가드 재사용 가능
- `game.entity`: `user_id`, `total_score`, `played_at(date)`, `location`, `is_club_game`, `room_id` 보유 → **`event_id` 컬럼만 추가**하면 연결 가능
- 클럽게임은 `game-rooms`(`room_id`)로 묶임 → 정기전은 방 생성 시 `event_id`를 함께 전달
- 마이그레이션 타임스탬프 규약: 정수 increment (최신 `1797…`) → 신규는 `1798…`, `1799…`
- 앱 `share_capture.dart` 존재 → 결과 공유 재사용
- 공지: 백엔드 `group-announcement.entity` + CRUD + 앱 서비스/페이지 **이미 존재** → 컬럼/노출만 확장

---

## 2. 백엔드 작업 (strike_log_api)

### 2-A. 엔티티
1. `src/groups/entities/club-event.entity.ts` (신규)
   - `id PK`, `group_id`(FK groups, CASCADE), `name varchar(100)`, `event_date date`,
     `status enum(scheduled|in_progress|completed|cancelled) default scheduled`,
     `lane_mode enum(random|balanced|team) null`, `game_target int null`,
     `created_by uuid`, `created_at`, `updated_at`
2. `src/groups/entities/club-event-participant.entity.ts` (신규)
   - 복합 PK `(event_id, user_id)`, `lane_no int null`, `team_no int null`, `handicap int default 0`
3. `src/games/entities/game.entity.ts` — `event_id int null` 추가 (+ `@Index`)
4. `src/groups/entities/group-announcement.entity.ts` — `link_url varchar(500) null` 추가

### 2-B. 마이그레이션 (`src/migrations/`)
- `1798000000000-CreateClubEvents.ts` — `club_events` + `club_event_participants` 생성, FK·인덱스
- `1799000000000-AddEventIdToGames.ts` — `games.event_id` + 인덱스
- `1800000000000-AddLinkUrlToAnnouncements.ts` — `group_announcements.link_url`
> ⚠️ 운영 DB `migrationsRun:true` → 배포 시 자동 적용. **배포 전 백업.**

### 2-C. DTO (`src/groups/dto/`)
- `create-club-event.dto.ts` (name, event_date, game_target?, participantUserIds[])
- `update-club-event.dto.ts` (name?, event_date?, status?, game_target?)
- `assign-lanes.dto.ts` (mode, laneCount)
- `add-participants.dto.ts` (userIds[])

### 2-D. 서비스 (`groups.service.ts` 또는 신규 `club-events.service.ts`)
- `createEvent`, `listEvents(groupId, statusFilter)`, `getEvent(eventId)` (참가자·레인·집계 포함)
- `updateEvent` / `completeEvent`(스냅샷: 순위·평균 계산해 저장)
- `addParticipants`, `removeParticipant`
- `assignLanes(eventId, mode, laneCount)`:
  - random: 셔플 → 라운드로빈
  - balanced: 평균 desc → 스네이크 드래프트(레인 평균합 균형)
  - team: 평균 desc → 스네이크 팀 분배 + `team_no`
  - 평균 없는 멤버 → 클럽 평균 대입 (`members-with-stats` 재사용)
- `getEventResult(eventId)`: 참가자/팀별 합계·평균·게임수·순위 집계 (`games where event_id`)
- 게임 저장 경로에 `event_id` 전달 반영 (game-rooms 방 생성 시 옵션 + 저장 시 기록)

### 2-E. 컨트롤러 (`groups.controller.ts`)
```
POST  /groups/:id/events                       @UseGuards(club-access ADMIN)
GET   /groups/:id/events?status=
GET   /groups/:id/events/:eid
PATCH /groups/:id/events/:eid                   ADMIN
POST  /groups/:id/events/:eid/attend            self-RSVP (클럽 멤버, STAFF 불필요)
DELETE /groups/:id/events/:eid/attend           self-RSVP 취소 (클럽 멤버)
POST  /groups/:id/events/:eid/participants      운영자 대리 추가 (ADMIN, operator override)
POST  /groups/:id/events/:eid/assign-lanes      ADMIN
GET   /groups/:id/events/:eid/result
PATCH /groups/:id/announcements/:aid            (link_url 포함 — 기존 라우트 확장)
```

### 2-F. 모듈/문서
- `groups.module.ts` — 신규 엔티티 `TypeOrmModule.forFeature` 등록
- `src/groups/README.md` 갱신(엔드포인트 표 + 신규 엔티티)

---

## 3. 프론트엔드 작업 (strike_log_app)

### 3-A. 모델 (`features/group/data/models/`)
- `club_event.dart`, `club_event_participant.dart`, `club_event_result.dart`

### 3-B. 서비스
- `club_events_api_service.dart` (신규) — 위 7개 엔드포인트 래핑
- `announcements_api_service.dart` — `link_url` 파라미터 추가(create/update)

### 3-C. 화면 (`features/group/presentation/pages/`)
1. `club_events_page.dart` — 정기전 목록(예정/진행/완료 탭) + 생성 FAB(ADMIN)
2. `create_club_event_page.dart` — 이름·날짜·목표 게임수. **참가자 선택 UI 제거** — 이벤트는 빈 참가자로 생성되고, 멤버가 직접 참석 신청(self-RSVP)한다.
3. `club_event_detail_page.dart`
   - 참가자/레인/팀 보드, 순위표, 평균
   - **"참석"/"참석 취소" 토글 버튼** (예정·진행 중 정기전에서 모든 멤버에게 노출, self-RSVP)
   - "레인 배치" 액션시트: 랜덤/에버리지 균형/팀전 + 레인 수 입력
   - "정기전에서 게임 시작"(클럽게임 흐름에 `event_id` 전달)
   - "결과 공유"(`share_capture`로 순위·평균 카드 이미지화)
   - 운영자 대리 추가/제거(`participants` 라우트) 유지 (operator override)
4. 공지: `club_announcements_page` 작성/수정 폼에 **링크 URL 필드** 추가, `my_groups_page`(클럽 홈)에 **핀 공지 1개 카드** 노출

### 3-D. 진입점/연동
- 클럽 홈(`my_groups_page`) 또는 클럽 상세에 "정기전" 진입 버튼
- 클럽게임 시작 흐름(`game_mode_page`/소켓 방 생성)에서 `event_id` optional 전달
- 권한: ADMIN 아닌 멤버는 생성/배치/완료 액션 숨김(조회만)

---

## 4. 작업 순서 (의존성)

```
1) 백엔드 엔티티 + 마이그레이션            ← 기반
2) 백엔드 서비스(배치 알고리즘 포함) + 컨트롤러
3) (검증) Swagger/REST로 생성·배치·결과 집계 수동 확인
4) 앱 모델 + 서비스
5) 앱 화면 3종 + 공지 링크/핀
6) 게임 시작 흐름에 event_id 태깅 연결
7) 결과 공유(share_capture) 연결
8) 통합 검증(시뮬레이터 + 로컬 서버) → README 갱신
```

---

## 5. 검증 기준 (Phase 1 완료 정의)

- [ ] ADMIN만 생성/배치/완료, 일반 멤버 조회만 (가드 동작)
- [ ] 3종 배치 동작 + 균형 배치의 레인 평균합 편차 < 랜덤
- [ ] 정기전에서 시작한 클럽게임 저장 시 `event_id` 채워짐 → 순위표 즉시 반영
- [ ] 결과 공유 이미지에 정기전명·날짜·순위·평균 포함
- [ ] 공지에 링크 저장/외부 열기 + 핀 공지 홈 노출
- [ ] `flutter analyze` 무경고 / 백엔드 빌드 통과 / 마이그레이션 up-down 정상

---

## 6. 리스크 / 주의
- **마이그레이션 운영 자동적용** → 배포 전 DB 백업, up/down 모두 테스트
- **게임 저장 경로 변경 최소화** — `event_id`는 nullable 추가만, 기존 소켓/저장 로직 비침습
- 구독 게이트(D2) 위치: 기존 클럽게임 게이트와 동일 지점 재사용(중복 구현 금지)
- 배치 알고리즘 평균 의존 → 신규 멤버 평균 부재 시 클럽 평균 폴백 명시

---

## 7. 착수 제안
백엔드 1)~2)부터 시작. 진행 방식 선택:
- **A. 단계별 직접 진행** (엔티티→서비스→컨트롤러→앱, 각 단계 확인)
- **B. executor 에이전트에 백엔드 일괄 위임 후 검증**
- **C. 이 계획 먼저 커밋하고 착수**
