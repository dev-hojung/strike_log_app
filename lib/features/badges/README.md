# Badges — 배지 / 출석 streak

## 목적
사용자 도전 의식을 부여하기 위한 25개 배지(마일스톤/점수/스트라이크/시리즈/streak/클럽) + 출석 streak 표시. 게임 저장·시리즈 완료 직후 백엔드가 평가, 신규 획득 시 모달과 푸시 알림.

## 페이지
- `BadgeListPage` — 카테고리별 그리드, 잠긴/획득 표시, 진행률 헤더, `highlightKey`로 특정 배지 강조

## 위젯
- `widgets/new_badges_dialog.dart` — 게임 저장 직후 신규 배지 노출 (최대 5개 + N more, "배지 보기"로 BadgeListPage 진입)

## 데이터 모델
- `data/models/badge_item.dart` — `BadgeItem`, `BadgeCategory`, `AttendanceStreak`

## 서비스
- `BadgesApiService`
  - `fetchAll()` → `GET /badges/me`
  - `fetchRecent({limit})` → `GET /badges/me/recent`
  - `fetchStreak()` → `GET /attendance/me/streak`

## 백엔드 평가 트리거
- `POST /games` 응답에 `newly_earned_badges`가 동봉됨 → `GameSaveService` 추출 → `NewBadgesDialog`
- `POST /game-series/:id/complete` 후 비동기 평가 + `BADGE_EARNED` 알림

## 알림 라우팅
- `NotificationType.badgeEarned` → FcmService가 `BadgeListPage(highlightKey: targetId)`로 push

## 의존성
- `features/game/...` — `GameSummary`/`ClubGameSummary`에서 모달 호출
- `features/home/...` — streak + 최근 배지 카드 진입
- `features/notifications/...` — 알림 매핑/표시
- `core/services/fcm_service.dart` — 푸시 진입 라우팅
