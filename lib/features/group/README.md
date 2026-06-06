# Group — 클럽 / 커뮤니티

## 목적
사용자 클럽(그룹) 생성·가입·운영 + 클럽 내 멤버 통계/랭킹.
신규 클럽 생성은 플랫폼 관리자 승인제, 가입은 클럽장(ADMIN) 승인제, **1인 1클럽 정책**.

## 페이지
- `MyGroupsPage` — 내가 속한 클럽 + 멤버 목록 + 검색/정렬 + 운영자용 진입점(랭킹·멤버 관리·가입 신청). 일반 멤버에게는 헤더에 즉시 탈퇴 아이콘 노출. 하단에 "다른 클럽 둘러보기" 진입.
- `CreateClubPage` — 신규 클럽 생성 신청 폼. 백엔드가 동일 이름 차단(승인된 그룹 + PENDING 신청 모두) → 409 시 안내.
- `ExploreClubsPage` — 전체 클럽 탐색 + 가입 신청. 본인이 가입한 클럽은 "내 클럽" 뱃지, 다른 카드는 1인 1클럽 정책상 disabled 처리.
- `ClubLeaderboardPage` — 클럽 멤버 평균점 desc 랭킹.
- `ClubJoinRequestsPage` — 클럽장: 가입 신청 승인/거절. 결과 시 헤더/네비 뱃지 카운트 감소.
- `AdminCreationRequestsPage` — 플랫폼 관리자: 클럽 생성 신청 심사 (RadioGroup 반려 사유).
- `MemberStatsPage` — 클럽 멤버 상세 통계 (같은 클럽 멤버끼리 서로 조회 허용).
- `ClubMembersPage` — 운영자 전용 멤버 관리 페이지. PopupMenu에서 운영자 위임 / 추방. 우상단 메뉴에서 본인 탈퇴(권한 위임 필요 시 409 안내).

## 데이터 모델
- `data/models/club_leaderboard.dart`

## 서비스
- `GroupsApiService` — 멤버 조회·운영자 위임·추방·탈퇴·내 pending 가입 신청 카운트
- `GroupCreationRequestsService` — 클럽 생성 신청 CRUD + 관리자 승인/반려
- `LeaderboardApiService` — 클럽 랭킹
- `ClubJoinRequestsService` — 클럽 가입 신청 CRUD + 승인/거절

## 코어 싱글톤 연동
- `PendingJoinRequestsService`(`core/services/`) — 운영자인 클럽들의 pending 가입 신청 합계.
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
| GET    | `/groups/:id/join-requests`                               | Leader |
| POST   | `/groups/:id/join-requests/:rid/approve`                  | Leader |
| POST   | `/groups/:id/join-requests/:rid/reject`                   | Leader |
| POST   | `/groups/:id/members/:userId/promote`                     | Leader (운영자 위임) |
| DELETE | `/groups/:id/members/:userId`                             | Leader (회원 추방) |
| DELETE | `/groups/:id/leave`                                       | — (본인 탈퇴) |

## 정책 요약
- **1인 1클럽**: 다른 클럽에 가입된 상태에서 가입 신청 시 409.
- **동일 클럽명 금지**: 생성 신청 시 기존 `groups.name` + `creation_requests.name`(PENDING)과 trim 비교.
- **추방**: 운영자만 호출. 본인·다른 ADMIN 추방 차단. 추방 대상에게 `CLUB_KICKED` 알림.
- **탈퇴**: 유일 ADMIN + 다른 멤버 존재 시 409로 위임 안내. 유일 멤버 탈퇴 시 클럽 함께 삭제.
- **운영자 위임**: 같은 클럽 멤버를 ADMIN으로 승격. 본인·기존 ADMIN 대상은 409.

## 알림 트리거
- 가입 신청 발생 → 클럽장에게 `club_join_request`
- 승인/거절 → 신청자에게 `club_join_approved/rejected`
- 회원 추방 → 추방 대상에게 `club_kicked`
- 생성 신청 → 관리자에게 `club_creation_request`
- 생성 승인/반려 → 신청자에게 `club_creation_approved/rejected`
- 체험판 만료 임박/만료 → 클럽장에게 `club_trial_expiring_soon/expired`

## 의존성
- `core/errors/...` — `MyGroupsPage`에서 ErrorRetryView 통합
- `core/services/pending_join_requests_service.dart` — 헤더/네비 뱃지 동기화
- `features/notifications/...` — 알림 라우팅 진입점
