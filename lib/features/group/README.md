# Group — 클럽 / 커뮤니티

## 목적
사용자 클럽(그룹) 생성·가입·관리 + 클럽 내 멤버 통계/랭킹. 신규 클럽 생성은 플랫폼 관리자 승인제, 가입은 클럽장 승인제.

## 페이지
- `MyGroupsPage` — 내가 속한 클럽 + 멤버 목록 + 점수 정렬/검색 + 가입 신청 진입 (클럽장)
- `CreateClubPage` — 신규 클럽 생성 신청 폼 (이름/설명/커버 이미지)
- `ExploreClubsPage` — 전체 클럽 탐색 + 가입 신청
- `ClubLeaderboardPage` — 클럽 멤버 평균점 desc 랭킹
- `ClubJoinRequestsPage` — 클럽장: 가입 신청 승인/거절
- `AdminCreationRequestsPage` — 플랫폼 관리자: 클럽 생성 신청 심사 (RadioGroup 반려 사유)
- `MemberStatsPage` — 클럽 멤버 상세 통계

## 데이터 모델
- `data/models/club_leaderboard.dart`

## 서비스
- `GroupCreationRequestsService` — 클럽 생성 신청 CRUD + 관리자 승인/반려
- `LeaderboardApiService` — 클럽 랭킹
- `ClubJoinRequestsService` — 클럽 가입 신청 CRUD + 승인/거절

## 백엔드 엔드포인트
| Method | Path | 권한 |
|--------|------|------|
| GET    | `/groups`                                   | — |
| GET    | `/groups/me`                                | — |
| GET    | `/groups/:id`                               | — |
| GET    | `/groups/:id/leaderboard`                   | — |
| GET    | `/groups/:id/members`                       | — |
| GET    | `/groups/:id/members-with-stats`            | — |
| POST   | `/groups/creation-requests`                 | — |
| GET    | `/groups/creation-requests/me`              | — |
| GET    | `/groups/creation-requests`                 | Admin |
| POST   | `/groups/creation-requests/:id/approve`     | Admin |
| POST   | `/groups/creation-requests/:id/reject`      | Admin |
| POST   | `/groups/creation-requests/:id/cancel`      | — |
| POST   | `/groups/:id/join-requests`                 | — |
| GET    | `/groups/:id/join-requests`                 | Leader |
| POST   | `/groups/:id/join-requests/:rid/approve`    | Leader |
| POST   | `/groups/:id/join-requests/:rid/reject`     | Leader |

## 알림 트리거
- 가입 신청 발생 → 클럽장에게 `club_join_request`
- 승인/거절 → 신청자에게 `club_join_approved/rejected`
- 생성 신청 → 관리자에게 `club_creation_request`
- 생성 승인/반려 → 신청자에게 `club_creation_approved/rejected`
- 체험판 만료 임박/만료 → 클럽장에게 `club_trial_expiring_soon/expired`

## 의존성
- `core/errors/...` — `MyGroupsPage`에서 ErrorRetryView 통합
- `features/notifications/...` — 알림 라우팅 진입점
