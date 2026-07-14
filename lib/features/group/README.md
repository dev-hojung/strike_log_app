# Group — 클럽 / 커뮤니티

## 목적
사용자 클럽(그룹) 생성·가입·운영 + 클럽 내 멤버 통계/랭킹.
신규 클럽 생성은 플랫폼 관리자 승인제, 가입은 운영진(STAFF 이상) 승인제, **1인 1클럽 정책**.

## 역할 모델 (3단계)

| 역할 | 한국어 | 인원 | 뱃지 색상 |
|------|--------|------|-----------|
| `OWNER` | 클럽장 | 클럽당 1명 | 금색 `#FBBF24` |
| `STAFF` | 운영진 | 다수 가능 | 파랑 `AppColors.primary` |
| `MEMBER` | 일반멤버 | 다수 | 없음 |

### 권한 매트릭스

| 액션 | 클럽장(OWNER) | 운영진(STAFF) | 일반멤버(MEMBER) |
|------|:---:|:---:|:---:|
| 가입 신청 승인/거절 | ✅ | ✅ | ❌ |
| 공지 작성/수정/삭제 | ✅ | ✅ | ❌ |
| 정기전 생성/배치/완료 | ✅ | ✅ | ❌ |
| 클럽 정보 수정 | ✅ | ✅ | ❌ |
| **일반멤버 추방** | ✅ | ✅ | ❌ |
| **운영진 추방** | ✅ | ❌ | ❌ |
| **운영진 임명/해제** | ✅ | ❌ | ❌ |
| **클럽장 이양** | ✅ | ❌ | ❌ |
| **클럽 삭제** | ✅ | ❌ | ❌ |

역할 헬퍼: `GroupRole` (`groups_api_service.dart`) — `canManage(role)`, `rank(role)`.

## 페이지
- `MyGroupsPage` — 내가 속한 클럽 + 멤버 목록 + 검색/정렬. OWNER/STAFF에게 멤버 관리·가입 신청 진입점 노출. MEMBER에게는 즉시 탈퇴 아이콘. 하단에 "다른 클럽 둘러보기" 진입.
- `CreateClubPage` — 신규 클럽 생성 신청 폼. 백엔드가 동일 이름 차단(승인된 그룹 + PENDING 신청 모두) → 409 시 안내.
- `ExploreClubsPage` — 전체 클럽 탐색 + 가입 신청. 본인이 가입한 클럽은 "내 클럽" 뱃지, 다른 카드는 1인 1클럽 정책상 disabled 처리. 우상단 "코드로 가입" 액션 → `JoinByCodePage`.
- `JoinByCodePage` — 초대 코드 입력 → 미리보기 조회 → **즉시 가입**(승인 생략). 성공 시 `pop(true)`로 호출자가 목록 갱신. 무효 코드/이미 소속은 인라인 에러.
- `ClubInviteCodePage` — OWNER/STAFF 전용 초대 코드 관리(표시·복사·공유 via share_plus·재발급). `ClubMembersPage` 우상단 person_add 아이콘으로 진입. 재발급 시 이전 코드 무효화 확인 다이얼로그.
- `ClubLeaderboardPage` — 클럽 멤버 평균점 desc 랭킹.
- `ClubJoinRequestsPage` — OWNER/STAFF: 가입 신청 승인/거절. 결과 시 헤더/네비 뱃지 카운트 감소.
- `AdminCreationRequestsPage` — 플랫폼 관리자: 클럽 생성 신청 심사 (RadioGroup 반려 사유).
- `MemberStatsPage` — 클럽 멤버 상세 통계 (같은 클럽 멤버끼리 서로 조회 허용).
- `ClubMembersPage` — OWNER/STAFF 전용 멤버 관리 페이지. PopupMenu 액션은 내 역할과 대상 역할 조합으로 결정됨(상세 아래). 우상단 메뉴에서 본인 탈퇴(OWNER는 이양 필요 시 409 안내).

### ClubMembersPage PopupMenu 액션 규칙

| 내 역할 | 대상 역할 | 가능한 액션 |
|---------|----------|-------------|
| OWNER | MEMBER | 운영진 임명, 클럽장 이양, 추방 |
| OWNER | STAFF | 운영진 해제, 클럽장 이양, 추방 |
| OWNER | OWNER | 없음 (자기 자신) |
| STAFF | MEMBER | 추방만 |
| STAFF | STAFF | 없음 |
| STAFF | OWNER | 없음 |
| MEMBER | 누구 | 없음 |

## 데이터 모델
- `data/models/club_leaderboard.dart`

## 서비스
- `GroupsApiService` — 멤버 조회·운영진 임명·운영진 해제·클럽장 이양·추방·탈퇴·내 pending 가입 신청 카운트 + **초대 코드**(`getInviteCode`/`rotateInviteCode`/`previewByInviteCode`/`joinByInviteCode`)
- `GroupRole` (abstract class in `groups_api_service.dart`) — 역할 상수 및 헬퍼
- `GroupCreationRequestsService` — 클럽 생성 신청 CRUD + 관리자 승인/반려
- `LeaderboardApiService` — 클럽 랭킹
- `ClubJoinRequestsService` — 클럽 가입 신청 CRUD + 승인/거절

## 코어 싱글톤 연동
- `PendingJoinRequestsService`(`core/services/`) — 운영진 이상인 클럽들의 pending 가입 신청 합계.
  - 하단 네비 그룹 탭의 빨간 점 + 헤더 가입 신청 아이콘의 카운트 뱃지 트리거.
  - FCM `club_join_request` 도착 시 `increment()`, 승인/반려 시 `decrement()`.

## 백엔드 엔드포인트
| Method | Path | 권한 |
|--------|------|------|
| GET    | `/groups`                                                 | — (응답에 `avg_score` 포함) |
| GET    | `/groups/me`                                              | — |
| GET    | `/groups/me/pending-join-requests-count`                  | — (뱃지용) |
| GET    | `/groups/:id`                                             | — (응답에 `avg_score` 포함) |
| GET    | `/groups/:id/leaderboard`                                 | — |
| GET    | `/groups/:id/members`                                     | — |
| GET    | `/groups/:id/members-with-stats`                          | — |
| POST   | `/groups`                                                 | Admin (직접 생성) |
| POST   | `/groups/creation-requests`                               | — (동일 이름 차단 409) |
| GET    | `/groups/creation-requests/me`                            | — |
| GET    | `/groups/creation-requests`                               | Admin |
| POST   | `/groups/creation-requests/:id/approve`                   | Admin |
| POST   | `/groups/creation-requests/:id/reject`                    | Admin |
| POST   | `/groups/creation-requests/:id/cancel`                    | — |
| POST   | `/groups/:id/join-requests`                               | — (1인 1클럽 정책 409) |
| GET    | `/groups/by-code/:code`                                   | — (초대 코드 미리보기, 무효 404) |
| POST   | `/groups/join-by-code`                                    | — (초대 코드 즉시 가입, 무효 404/이미 소속 409) |
| GET    | `/groups/:id/invite-code`                                 | STAFF+ (조회, 없으면 발급) |
| POST   | `/groups/:id/invite-code`                                 | STAFF+ (재발급/회전) |
| GET    | `/groups/:id/join-requests`                               | STAFF+ |
| POST   | `/groups/:id/join-requests/:rid/approve`                  | STAFF+ |
| POST   | `/groups/:id/join-requests/:rid/reject`                   | STAFF+ |
| POST   | `/groups/:id/members/:userId/promote`                     | OWNER (운영진 임명 MEMBER→STAFF) |
| DELETE | `/groups/:id/members/:userId/staff`                       | OWNER (운영진 해제 STAFF→MEMBER) |
| POST   | `/groups/:id/transfer-ownership`                          | OWNER (클럽장 이양) `{ targetUserId }` |
| DELETE | `/groups/:id/members/:userId`                             | STAFF+ (회원 추방; 동급/상위 대상 403) |
| DELETE | `/groups/:id/leave`                                       | — (본인 탈퇴) |

## 정책 요약
- **1인 1클럽**: 다른 클럽에 가입된 상태에서 가입 신청 시 409. 초대 코드 즉시 가입도 동일하게 차단.
- **초대 코드**: STAFF+ 발급/회전. 코드 보유자는 승인 없이 즉시 MEMBER로 가입. 회전 시 이전 코드 무효화. (딥링크는 후속 네이티브 작업으로 분리)
- **동일 클럽명 금지**: 생성 신청 시 기존 `groups.name` + `creation_requests.name`(PENDING)과 trim 비교.
- **추방**: STAFF 이상 호출. 동급/상위 역할 추방 차단 (403). 추방 대상에게 `CLUB_KICKED` 알림.
- **탈퇴**: OWNER + 다른 멤버 존재 시 409로 클럽장 이양 안내. 유일 멤버 탈퇴 시 클럽 함께 삭제.
- **운영진 임명**: OWNER만 호출. MEMBER → STAFF 승격. 본인·기존 STAFF/OWNER 대상은 409.
- **운영진 해제**: OWNER만 호출. STAFF → MEMBER 강등.
- **클럽장 이양**: OWNER만 호출. 대상 → OWNER, 본인 → STAFF.

## 알림 트리거
- 가입 신청 발생 → 클럽장 + 운영진 전원에게 `club_join_request`
- 승인/거절 → 신청자에게 `club_join_approved/rejected`
- 회원 추방 → 추방 대상에게 `club_kicked`
- 생성 신청 → 관리자에게 `club_creation_request`
- 생성 승인/반려 → 신청자에게 `club_creation_approved/rejected`
- 체험판 만료 임박/만료 → 클럽장에게 `club_trial_expiring_soon/expired`

## 의존성
- `core/errors/...` — `MyGroupsPage`에서 ErrorRetryView 통합
- `core/services/pending_join_requests_service.dart` — 헤더/네비 뱃지 동기화
- `features/notifications/...` — 알림 라우팅 진입점
