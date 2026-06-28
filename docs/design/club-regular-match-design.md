# 클럽 정기전·공개 프로필·볼링장 통계 — 기획 설계

> 작성일: 2026-06-23 / 대상 빌드: v1.0.x 이후 클럽 기능 확장
> 범위: Flutter 앱(`strike_log_app`) + NestJS 백엔드(`strike_log_api`)

---

## 0. 목표 한 줄 요약

클럽을 "이름만 있는 그룹"에서 **"정기적으로 모여 경기하고 기록이 쌓이는 커뮤니티"**로 끌어올린다.
5개 기능을 **정기전(코어) → 공개 프로필/통계(성장) → 초대 링크(확산)** 순으로 단계 출시한다.

---

## 1. 현재 구조 진단 (기반 사실)

| 영역 | 현재 상태 | 시사점 |
|---|---|---|
| `Group` | id·name·description·`activity_region`·cover·구독상태·체험일정 | 활동 볼링장/모집여부 컬럼 **없음** |
| `GroupMember` | group_id·user_id·role(ADMIN/MEMBER)·joined_at | 그대로 활용 |
| 클럽 게임 | Socket.IO 방(`room_id`) → 저장 시 `games`에 `is_club_game=true`, `room_id`, `club_rank` | **`Group`과 영속 연결 없음** (방 코드로만 묶임) |
| `games.location` | 볼링장 이름 free text(varchar 100, nullable) | 통계화 가능하나 **표기 흔들림** 문제 존재 |
| 공유 | `core/services/share_capture.dart` (위젯 캡처) | 정기전 결과 공유에 재사용 |
| 탐색 | `explore_clubs_page.dart` 이미 존재 | 공개 프로필 진입점으로 확장 |

**핵심 결정:** 정기전(정모)은 **신규 영속 엔티티**로 만들고, 기존 소켓 클럽 게임을 정기전에 **태깅(`event_id`)** 해 결과를 자동 집계한다. 소켓 실시간 플레이 로직은 건드리지 않는다.

---

## 2. 기능별 설계

### 2-1. 정기전/모임 (코어 · Phase 1)

**개념:** 클럽이 여는 명명된 경기 이벤트. 예) "6월 4주차 정모".

#### 신규 엔티티

```
ClubEvent (club_events)
  id            PK
  group_id      FK → groups.id  (CASCADE)
  name          varchar(100)    "6월 4주차 정모"
  event_date    date
  status        enum(scheduled|in_progress|completed|cancelled) default scheduled
  lane_mode     enum(random|balanced|team) nullable  (레인 배치 방식)
  game_target   int nullable    (목표 게임 수, 예 3)
  created_by    uuid (user_id)
  created_at / updated_at

ClubEventParticipant (club_event_participants)
  event_id      PK, FK → club_events.id (CASCADE)
  user_id       PK, uuid
  lane_no       int nullable    (배정 레인)
  team_no       int nullable    (팀전일 때 팀 번호)
  handicap      int default 0   (선택)
```

**games 연결:** `games`에 `event_id int nullable` 컬럼 추가 → 정기전에서 친 게임을 묶는다.
(기존 `room_id`는 유지; `event_id`는 "어느 정모냐"의 영속 키)

#### 요청 필드 매핑

| 요청 | 구현 |
|---|---|
| 참가자 | `ClubEventParticipant` 목록 |
| 게임 수 | 참가자별 `games where event_id=? group by user_id` count, 또는 `game_target` |
| 순위 | 이벤트 내 합계/평균 기준 정렬 (팀전이면 팀 합계) |
| 평균 | `AVG(total_score)` per 참가자 / 팀 |
| 결과 공유 | 결과 화면을 `share_capture`로 이미지 공유 |

#### 레인 배치 알고리즘 (서버에서 계산 — 저장된 평균 사용)

`POST /groups/:id/events/:eventId/assign-lanes { mode, laneCount }`

- **랜덤 배치(random):** 참가자 셔플 → 레인당 N명 라운드로빈.
- **에버리지 균형 배치(balanced):** 참가자를 평균 내림차순 정렬 → **스네이크 드래프트**로 레인에 분배(레인별 평균 합 균형). 평균은 `members-with-stats`에서 이미 계산하는 값 재사용.
- **팀전 배치(team):** 평균 정렬 후 스네이크로 팀에 분배(팀 평균 균형). `team_no` 기록.

> 평균이 없는 신규 멤버는 클럽 평균값으로 임시 대입.

#### 앱 화면 (Phase 1)

- `ClubEventsPage` — 클럽별 정기전 리스트(예정/진행/완료 탭)
- `CreateClubEventPage` — 이름·날짜·목표 게임 수·참가자 선택
- `ClubEventDetailPage` — 참가자/레인 배치/순위표/평균/결과 공유 버튼
  - "레인 배치" 액션시트: 랜덤 / 에버리지 균형 / 팀전 선택
  - 정기전 내에서 클럽 게임 시작 시 `event_id` 태깅

---

### 2-2. 클럽 공개 프로필 (성장 · Phase 2)

**개념:** 비회원도 볼 수 있는 클럽 소개 페이지 → 가입 유입.

#### Group 컬럼 추가
```
home_alley     varchar(100) nullable   (활동 볼링장)
is_recruiting  boolean default true     (모집 여부)
```
(지역=기존 `activity_region`, 평균/멤버수=집계로 계산)

#### 엔드포인트
`GET /groups/:id/public` — **인증 불필요(@Public)**, 반환:
```
{ id, name, description, activity_region, home_alley,
  is_recruiting, member_count, avg_score, cover_image_url }
```
`GET /groups/explore?region=&recruiting=` — 탐색/필터 (기존 `explore_clubs_page` 강화)

#### 앱 화면
- `ClubPublicProfilePage` — 위 정보 카드 + **가입 신청 버튼**(기존 join-request 플로우 재사용)
- `explore_clubs_page` 필터: 지역 드롭다운 + 모집중 토글

---

### 2-3. 클럽 정기전 관리 UX 강화 (Phase 1과 함께)

2-1의 관리자 동선을 운영자(ADMIN) 전용으로 묶는다.
- 정기전 **이름·날짜·참가자·순위 기록**을 한 화면에서 생성/편집
- 완료 처리 시 순위·평균 스냅샷 저장(나중에 멤버 활동 이력으로 표시)
- 권한: 생성/배치/완료는 `GroupRole.ADMIN`만 (기존 가드 패턴 `club-access.guard` 재사용)

---

### 2-4. 클럽 초대/공유 링크 (확산 · Phase 3)

**MVP(권장 1차):** **초대 코드** 방식 — 딥링크 인프라 없이 즉시 가능
- `groups`에 `invite_code varchar(12) unique` 발급(클럽장이 재발급 가능)
- 공유: "클럽 코드: `ABC123` — 앱에서 클럽 찾기 → 코드 입력" 텍스트 공유(`share_plus` 재사용)
- 앱: "코드로 클럽 찾기" 입력 → 공개 프로필 → 가입 신청

**2차(딥링크):** `app_links` 패키지 + iOS Associated Domains + Android App Links
- `https://strikelog.xyz/club/:inviteCode` → 앱 설치 시 바로 가입 화면, 미설치 시 스토어
- ⚠️ 비용: 도메인 연결(이미 검토된 strikelog.xyz) + 양 플랫폼 딥링크 설정 + 검증 파일 호스팅. **Phase 3로 분리** 권장.

---

### 2-5. 볼링장 이름 기반 기록 통계 (성장 · Phase 2)

**기반:** `games.location` 이미 존재(예약/DB 불필요, 요청 취지와 일치).

**문제:** free text라 "강남볼링장" vs "강남 볼링장" 같은 표기 흔들림.

**설계(점진):**
1. **MVP:** 저장 시 `trim()` + 공백 정규화. 통계는 정규화 문자열 group by.
   - `GET /users/:id/stats/by-location` → 볼링장별 게임수·평균·베스트
   - `GET /groups/:id/stats/by-location` → 클럽 주 활동 볼링장 Top N
2. **2차:** 입력 시 **자동완성**(기존 location 값 distinct 추천) → 표기 수렴
3. **3차(선택):** `bowling_alleys` 정규 테이블 + location_id FK (지금은 불필요)

**앱 화면:**
- 프로필/기록에 "볼링장별 기록" 섹션(평균·게임수)
- 클럽 공개 프로필의 "활동 볼링장"을 통계 1위로 자동 추천

---

## 3. 데이터 모델 변경 요약 (마이그레이션)

| 테이블 | 변경 | Phase |
|---|---|---|
| `club_events` | **신규** | 1 |
| `club_event_participants` | **신규** | 1 |
| `games` | `event_id int null` 추가 (+ 인덱스) | 1 |
| `groups` | `home_alley`, `is_recruiting` 추가 | 2 |
| `groups` | `invite_code` 추가 | 3 |

> TypeORM 마이그레이션 신규 작성 (`src/migrations/`). 운영 DB는 `migrationsRun:true`라 푸시 시 자동 적용 — **배포 전 백업 필수**.

---

## 4. API 설계 요약

```
# 정기전 (Phase 1)
POST   /groups/:id/events                      이벤트 생성 (ADMIN)
GET    /groups/:id/events                       이벤트 목록
GET    /groups/:id/events/:eventId              상세(참가자·레인·순위·평균)
PATCH  /groups/:id/events/:eventId              수정/상태변경 (ADMIN)
POST   /groups/:id/events/:eventId/participants 참가자 추가 (ADMIN)
POST   /groups/:id/events/:eventId/assign-lanes 레인/팀 배치 (ADMIN)
GET    /groups/:id/events/:eventId/result       결과 집계(공유용)

# 공개 프로필 / 통계 (Phase 2)
GET    /groups/:id/public                        @Public 공개 프로필
GET    /groups/explore?region=&recruiting=       탐색 필터
GET    /users/:id/stats/by-location              개인 볼링장별 통계
GET    /groups/:id/stats/by-location             클럽 볼링장별 통계

# 초대 (Phase 3)
POST   /groups/:id/invite-code                   코드 발급/재발급 (ADMIN)
GET    /groups/by-invite/:code                    코드로 공개 프로필 조회
```

---

## 5. 단계별 로드맵 (우선순위)

| Phase | 내용 | 가치 | 난이도 |
|---|---|---|---|
| **1** | 정기전 엔티티 + 관리 UX + 레인 배치 + 결과 공유 | ★★★ 코어 | 중~상 |
| **2** | 공개 프로필(지역/볼링장/모집/평균/멤버수) + 볼링장 통계 | ★★ 유입·리텐션 | 중 |
| **3** | 초대 코드 → (선택) 딥링크 | ★ 확산 | 코드:하 / 딥링크:상 |

권장: **Phase 1을 먼저 단독 출시**해 클럽 핵심 가치를 검증한 뒤 2·3 진행.

---

## 6. 리스크 / 열린 질문

1. **정기전 ↔ 기존 소켓 클럽게임 연결 방식**
   - (A) 정기전 안에서 클럽 게임을 시작해 `event_id` 자동 태깅 (권장)
   - (B) 이미 친 게임을 사후에 정기전에 수동 귀속
   - → 둘 다 지원? MVP는 (A)만?
2. **레인 배치 계산 위치**: 서버 권장(평균 일관성) — 동의 여부
3. **정기전이 유료(클럽 구독) 기능인지**: 현재 클럽 게임은 구독 게이트 → 정기전도 동일 게이트로 둘지
4. **초대 링크**: 1차 코드 방식으로 충분한지, 딥링크가 출시 필수인지
5. **볼링장 표기 정규화**: 자동완성(2차)까지 Phase 2에 포함할지, MVP는 trim만 할지

---

## 7. 다음 액션 제안

- 위 **열린 질문 5개**에 대한 결정 → 확정되면 **Phase 1 상세 작업계획(태스크 분해 + 마이그레이션 + 엔드포인트 + 화면)** 으로 전개
- Phase 1 착수 시: 백엔드(엔티티·마이그레이션·서비스·컨트롤러) → 앱(모델·서비스·3개 페이지) → 결과 공유 → 검증 순
