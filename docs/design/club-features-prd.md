# PRD — 클럽 기능 확장 (정기전 · 공개 프로필 · 공지)

> 작성일: 2026-06-30 / 대상: `strike_log_app`(Flutter) + `strike_log_api`(NestJS)
> 선행 문서: [`club-regular-match-design.md`](./club-regular-match-design.md) (정기전·공개프로필·볼링장통계·초대 기술 설계)
> 본 PRD는 그 설계를 제품 요구사항으로 확정하고, **공지 확장**을 추가한다.
> ※ 기록 가져오기(CSV/엑셀)는 이번 범위에서 **제외**한다.

---

## 1. 배경 & 목표

Strike Log의 클럽은 현재 "이름·멤버·랭킹"만 있는 정적 그룹이다. 운영자가 **실제로 모임을 굴리고 멤버를 모으는** 도구가 없어, 클럽이 살아 움직이지 않는다.

**목표:** 클럽을 *정기적으로 모여 경기하고, 기록이 쌓이고, 사람이 유입되는 커뮤니티*로 전환한다.

**성공 지표 (출시 후 측정)**
- 정기전(정모) 1회 이상 개최한 클럽 비율
- 정기전 결과 공유 이미지 생성/공유 횟수
- 공개 프로필 → 가입 신청 전환율

---

## 2. 현재 상태 (사실 기반)

| 기능 | 상태 | 근거 |
|---|---|---|
| 클럽 생성/가입/멤버·랭킹/운영(추방·위임) | ✅ 구현됨 | `features/group/*`, `groups.service.ts` |
| 클럽 게임(소켓 실시간) | ✅ 구현됨 | `socket_service`, `games.is_club_game` |
| **클럽 공지** | ✅ **이미 구현됨** | `group-announcement.entity.ts`, `/groups/:id/announcements` CRUD, `announcements_api_service.dart`, `club_announcements_page.dart`, FCM `club_announcement` |
| 클럽 탐색 | ✅ 부분 구현 | `explore_clubs_page.dart` (필터는 없음) |
| 정기전/모임 | 🟡 설계만 | `club-regular-match-design.md` §2-1 |
| 클럽 공개 프로필 | 🟡 설계만 | 동 §2-2 |
| 볼링장별 통계 | 🟡 설계만 | 동 §2-5 |
| 초대 코드/딥링크 | 🟡 설계만 | 동 §2-4 |

> **핵심 결정:** 정기전은 **신규 영속 엔티티**(`club_events`)로 만들고, 기존 소켓 클럽게임에 `event_id`를 태깅해 자동 집계한다. 실시간 소켓 로직은 건드리지 않는다. (설계문서 §1 결정 계승)

---

## 3. 범위

### 포함 (In scope)
- F1. 정기전/모임 (참가자·게임수·순위·평균·결과공유·레인배치 3종)
- F2. 클럽 공개 프로필 (지역·활동볼링장·모집여부·평균·멤버수·가입신청)
- F3. 클럽 공지 **확장** (이미 구현됨 → 링크 필드 + 홈 노출만 추가)
- F4. 볼링장별 통계 (F2 보조)

### 비포함 (Out of scope, 차기)
- **기록 가져오기 (CSV/엑셀) — 이번 범위 제외**
- 딥링크 초대(`https://strikelog.xyz/club/:code`) — 인프라 비용 큼 → 초대는 **코드 방식**만 차기 MVP
- 정기전 사전 일정 알림/리마인더 푸시 (차기)
- 게시판형 다중 공지/댓글 (공지는 핀 1개 + 링크 수준 유지)

---

## 4. 기능 요구사항

### F1. 정기전/모임  〔Phase 1 · 코어〕

**사용자 스토리**
- (운영자) "이번 주 정모를 만들고 참가자를 고르고 레인을 자동 배치하고 싶다."
- (운영자) "정모가 끝나면 순위·평균을 한 장으로 공유하고 싶다."
- (멤버) "내가 몇 번 레인 몇 팀인지, 최종 순위가 어떻게 됐는지 보고 싶다."

**기능 요구**
| # | 요구 | 비고 |
|---|---|---|
| F1-1 | 정기전 생성: 이름("6월 4주차 정모")·날짜·목표 게임수 (참가자는 생성 시 지정 안 함 — 멤버 self-RSVP로 확정) | ADMIN 전용 |
| F1-2 | **참가자 self-RSVP**: 멤버 본인이 "참석" 신청/취소. 운영자는 대리 추가/제거(operator override) 가능 | 모든 클럽 멤버 |
| F1-3 | 레인 배치 3종: **랜덤 / 에버리지 균형 / 팀전** | 서버 계산, 저장 평균 사용 |
| F1-4 | 정기전 내 클럽게임 시작 시 `event_id` 자동 태깅 | 기존 소켓 흐름 재사용 |
| F1-5 | 순위표: 참가자별(또는 팀별) 합계·평균 정렬 | 팀전은 팀 합계 |
| F1-6 | 결과 공유: 순위·평균 화면을 `share_capture`로 이미지화 | 기존 위젯캡처 재사용 |
| F1-7 | 완료 처리 시 순위·평균 **스냅샷** 저장 | 멤버 활동 이력용 |

**레인/팀 배치 알고리즘**
- 랜덤: 셔플 → 레인당 라운드로빈
- 균형: 평균 내림차순 → **스네이크 드래프트**로 레인 분배(레인 평균 합 균형)
- 팀전: 평균 정렬 → 스네이크로 팀 분배, `team_no` 기록
- 평균 없는 신규 멤버는 **클럽 평균**으로 임시 대입

**데이터** (신규)
```
club_events(id, group_id FK, name, event_date, status[scheduled|in_progress|completed|cancelled],
            lane_mode[random|balanced|team] null, game_target int null, created_by, created_at, updated_at)
club_event_participants(event_id FK, user_id, lane_no null, team_no null, handicap default 0)  // PK(event_id,user_id)
games += event_id int null (+ index)
```

**API**
```
POST  /groups/:id/events                       생성 (ADMIN)
GET   /groups/:id/events                        목록(예정/진행/완료)
GET   /groups/:id/events/:eid                   상세(참가자·레인·순위·평균)
PATCH /groups/:id/events/:eid                   수정/상태변경 (ADMIN)
POST  /groups/:id/events/:eid/attend            self-RSVP 참석 (클럽 멤버)
DELETE /groups/:id/events/:eid/attend           self-RSVP 취소 (클럽 멤버)
POST  /groups/:id/events/:eid/participants      운영자 대리 추가 (ADMIN, operator override)
POST  /groups/:id/events/:eid/assign-lanes      배치 {mode, laneCount} (ADMIN)
GET   /groups/:id/events/:eid/result            결과 집계(공유용)
```

**화면**: `ClubEventsPage`(탭: 예정/진행/완료) · `CreateClubEventPage` · `ClubEventDetailPage`(참가자/레인/순위/평균/공유 + 배치 액션시트)

**수용 기준**
- [ ] ADMIN만 생성/배치/완료 가능
- [ ] 모든 클럽 멤버가 참석 신청(self-RSVP)/취소 가능, 운영자 대리 추가/제거(operator override) 유지
- [ ] 균형 배치 후 레인별 평균 합 편차가 랜덤 대비 유의하게 작다
- [ ] 정기전 내 게임 저장 시 `event_id`가 채워지고 순위표에 즉시 반영
- [ ] 결과 공유 이미지에 정기전명·날짜·순위·평균 포함

---

### F2. 클럽 공개 프로필  〔Phase 2 · 유입〕

**사용자 스토리**: (비회원) "가입 전에 이 클럽의 지역·활동 볼링장·평균·모집 여부를 보고 신청하고 싶다."

**기능 요구**
| # | 요구 |
|---|---|
| F2-1 | 공개 프로필: 지역·활동볼링장·모집여부·평균점수·멤버수·소개·커버 노출 |
| F2-2 | **가입 신청 버튼** (기존 join-request 플로우 재사용, 1인1클럽 정책 유지) |
| F2-3 | 탐색 필터: 지역 선택 + "모집중" 토글 (`explore_clubs_page` 강화) |
| F2-4 | 활동 볼링장은 F4 통계 1위로 자동 추천(운영자 수정 가능) |

**데이터**: `groups += home_alley varchar(100) null, is_recruiting bool default true` (지역=기존 `activity_region`, 평균/멤버수=집계)

**API**
```
GET /groups/:id/public                      @Public 공개 프로필
GET /groups/explore?region=&recruiting=     탐색 필터
```

**화면**: `ClubPublicProfilePage` (정보 카드 + 가입 신청) · `explore_clubs_page` 필터 추가

**수용 기준**
- [ ] 비로그인/비회원도 `/groups/:id/public` 조회 가능
- [ ] `is_recruiting=false`면 가입 신청 버튼 비활성 + 안내
- [ ] 지역·모집 필터가 탐색 목록에 반영

---

### F3. 클럽 공지 (확장)  〔Phase 1과 병행 · 소규모〕

> **이미 구현됨**: 제목·본문·핀·작성자 + CRUD + FCM 알림. 게시판으로 키우지 않는다.

**추가 요구(최소)**
| # | 요구 |
|---|---|
| F3-1 | 공지에 **링크 URL** 선택 필드 추가(오픈채팅/일정 링크 등) |
| F3-2 | **핀 고정 공지 1개**를 클럽 홈 상단에 노출(전체는 공지 페이지) |

**데이터**: `group_announcements += link_url varchar(500) null`
**수용 기준**: [ ] 링크 있는 공지는 탭 시 외부 열기 · [ ] 핀 공지가 클럽 홈 상단 카드로 노출

---

### F4. 볼링장별 통계  〔Phase 2 · F2 보조〕
- `games.location` 정규화(MVP: `trim`+공백 정규화) 후 group by 집계
- `GET /users/:id/stats/by-location`, `GET /groups/:id/stats/by-location`
- 2차: 입력 자동완성(기존 location distinct) → 표기 수렴. (상세는 설계문서 §2-5)

---

## 5. 데이터 모델 변경 종합

| 테이블 | 변경 | Phase |
|---|---|---|
| `club_events` | 신규 | 1 |
| `club_event_participants` | 신규 | 1 |
| `games` | `event_id` 추가 | 1 |
| `group_announcements` | `link_url` 추가 | 1 |
| `groups` | `home_alley`, `is_recruiting` 추가 | 2 |
| `groups` | `invite_code` 추가 | 3 |

> TypeORM 마이그레이션 신규 작성. 운영 DB `migrationsRun:true` → 배포 시 자동 적용. **배포 전 DB 백업 필수.**

---

## 6. 권한 / 정책
- 정기전 생성·배치·완료, 모집여부/볼링장 수정, 공지 작성: **`GroupRole.ADMIN`만** (`club-access.guard` 재사용)
- 공개 프로필 조회: `@Public`
- 가입 신청: 기존 **1인 1클럽** 정책 유지

---

## 7. 로드맵 (우선순위)

| Phase | 내용 | 가치 | 난이도 |
|---|---|---|---|
| **1** | F1 정기전(엔티티·배치·결과공유) + F3 공지 확장 | ★★★ 코어 | 중~상 |
| **2** | F2 공개 프로필 + F4 볼링장 통계 | ★★ 유입 | 중 |
| **3** | 초대 코드 → (선택) 딥링크 | ★ 확산 | 코드:하 / 딥링크:상 |

권장: **Phase 1 단독 출시**로 클럽 코어 가치 검증 → Phase 2로 유입 강화.

---

## 8. 리스크 & 열린 질문

1. **정기전↔소켓 게임 연결**: (A) 정기전 안에서 게임 시작해 자동 태깅 / (B) 사후 수동 귀속 — MVP는 (A)만?
2. **정기전 구독 게이트**: 클럽 게임이 구독 게이트인데 정기전도 동일하게 막을지?
3. **초대**: 코드 방식으로 충분한지, 딥링크가 출시 필수인지.

---

## 9. 다음 액션
- §8 열린 질문 결정 → **Phase 1 상세 작업계획**(태스크 분해 + 마이그레이션 + 엔드포인트 + 화면) 전개
- 착수 순서(각 Phase 공통): 백엔드(엔티티·마이그레이션·서비스·컨트롤러) → 앱(모델·서비스·화면) → 공유/검증
