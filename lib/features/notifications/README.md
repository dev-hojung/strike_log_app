# Notifications — 알림 / FCM

## 목적
인앱 알림 목록 + 미읽음 카운트 + FCM 토큰 등록/해제 + 푸시 수신 시 라우팅. 백엔드의 `NotificationType` enum과 1:1 동기화.

## 페이지
- `NotificationsPage` — 알림 목록 (최신순), 단건/전체 읽음, 타입별 아이콘·색상, ErrorRetryView 통합

## 데이터 모델
- `data/models/notification_item.dart`
  - `NotificationItem` — id/type/title/body/createdAt/isRead/targetId/actorId/actorNickname
  - `NotificationType` enum + `wireValue`/`fromString` (백엔드 문자열과 매핑)

## 알림 타입 (백엔드와 동기화)
| wire | 의미 | targetId | 라우팅 |
|------|------|----------|--------|
| `club_game_created`         | 클럽 새 게임 | gameId | 클럽 탭 |
| `club_join_request`         | 가입 신청 도착 | clubId | ClubJoinRequestsPage |
| `club_join_approved/rejected` | 가입 결과 | clubId | 클럽 탭 |
| `club_creation_request`     | 클럽 생성 신청 | requestId | AdminCreationRequestsPage |
| `club_creation_approved/rejected` | 생성 결과 | groupId | 클럽 탭 |
| `club_trial_expiring_soon/expired` | 체험판 | clubId | 클럽 탭 |
| `new_best_score`            | 베스트 갱신 | gameId | GameDetailPage |
| `badge_earned`              | 신규 배지 | badge_key | BadgeListPage(highlightKey) |

## 서비스
- `NotificationsApiService`
  - `fetchList`, `fetchUnreadCount`, `markAsRead`, `markAllAsRead`
  - `registerFcmToken`, `deleteFcmToken`

## 백엔드 엔드포인트
- `GET /notifications/me`
- `GET /notifications/me/unread-count`
- `POST /notifications/:id/read`
- `POST /notifications/me/read-all`
- `POST /notifications/me/fcm-token`
- `DELETE /notifications/me/fcm-token`

## 의존성
- `core/services/fcm_service.dart` — Firebase 메시지 수신 / 토큰 동기화 / 인앱 라우팅
- `core/services/unread_notifications_service.dart` — 전역 미읽음 카운트 싱글톤
- `features/badges/...`, `features/game/...`, `features/group/...` — 라우팅 진입점
