# Strike Log — 프로젝트 역설계 개요

작성 기준일: 2026-04-19
스캔 대상:
- 앱: `/Users/khj/develop/strike_log_app` (Flutter)
- API: `/Users/khj/develop/strike_log_api` (NestJS)

---

## 1. 제품 개요

볼링 점수를 기록·공유하는 모바일 앱. 개인 경기와 클럽(그룹) 경기를 모두 지원하며, 클럽 경기는 소켓 기반으로 참가자들이 같은 방에 모여 실시간 점수를 공유한다. 클럽 가입은 관리자 승인제이고, 알림/푸시(FCM)가 연동되어 있다.

- 언어/UI: 한국어
- 기본 테마: 다크 (`ThemeMode.dark`)
- 주요 컬러: `#135BEC` (primary)
- 폰트: Google Fonts Lexend
- 아이콘: Material Symbols Icons

---

## 2. 시스템 구성

```
┌────────────────────┐        REST          ┌────────────────────┐
│  Flutter App       │◀───────────────────▶│  NestJS API        │
│  (strike_log_app)  │   /users /groups    │  (strike_log_api)  │
│                    │   /games /notif ...  │  TypeORM + MySQL   │
│  Socket.IO client  │◀── Socket.IO ──────▶│  GameRoomsGateway  │
│  firebase_messaging│                      │  firebase-admin    │
└────────────────────┘                      └────────────────────┘
         ▲                                            │
         │  FCM push                                  │
         └─── Firebase Cloud Messaging ◀──────────────┘
```

### 2.1 앱 계층

- `core/` : 공통 인프라 (테마, 위젯, API 클라이언트, 소켓, FCM 서비스, 상수)
- `features/<name>/data/` : API 서비스·모델
- `features/<name>/presentation/pages/` : 화면
- 상태 관리: `StatefulWidget` + 로컬 state (Provider/BLoC/Riverpod **미사용**)
- 내비게이션: `Navigator.push/pop` 직접 호출 (named routes **미사용**)
- 세션 저장: `SharedPreferences` (`user_id`, `nickname`)

### 2.2 API 계층

- NestJS 모듈: `users`, `groups`, `games`, `game-rooms`, `notifications`, `email`
- DB: MySQL + TypeORM (`synchronize: true` — 개발 환경)
- 실시간: `@nestjs/websockets` + `socket.io` (`GameRoomsGateway`)
- 푸시: `firebase-admin` SDK
- 설정: `ConfigModule` (`.env`)

---

## 3. 앱 기능 맵

### 3.1 메인 내비게이션 (`core/widgets/main_container.dart`)

`BottomAppBar` + 중앙 FAB 구조. 로그인 후 `MainContainer`가 기본 허브.

| 탭 | 페이지 |
|----|--------|
| 홈 | `HomeDashboardPage` |
| 클럽 | `MyGroupsPage` |
| (FAB) 게임 | `GameModePage` → `FrameEntryPage` |
| 기록 | `GameHistoryPage` |
| 프로필 | `ProfilePage` |

기타: 전역 `appRouteObserver`(RouteObserver)로 상단 라우트 pop 시 홈/기록 캐시를 무효화하고 미저장 드래프트를 자동 재시도.

### 3.2 피처 별 페이지/서비스

**auth**
- `login_page.dart` — 이메일/비밀번호 로그인
- `signup_page.dart` — 회원가입

**home**
- `home_dashboard_page.dart`
- `data/services/home_api_service.dart`, `data/models/home_dashboard_data.dart`

**game**
- `game_mode_page.dart` — 개인/클럽 모드 선택
- `frame_entry_page.dart` — 10프레임 점수 입력 (핵심 도메인 로직)
- `game_room_page.dart` — 클럽 경기 대기실/실시간 방
- `game_history_page.dart`
- `game_summary_page.dart`, `club_game_summary_page.dart`
- `data/services/game_api_service.dart` — 게임 REST
- `data/services/game_save_service.dart` — 저장 + 드래프트 재시도
- `data/services/game_draft_repository.dart` — 로컬 드래프트 저장

**group**
- `my_groups_page.dart`, `explore_clubs_page.dart`, `create_club_page.dart`
- `club_join_page.dart`, `club_join_requests_page.dart` — 가입 요청/승인
- `member_stats_page.dart`
- `data/services/club_join_requests_service.dart`

**notifications**
- `notifications_page.dart`
- `data/services/notifications_api_service.dart`
- `data/models/notification_item.dart`

**profile**
- `profile_page.dart`, `account_settings_page.dart`
- `edit_nickname_page.dart`, `edit_phone_page.dart`, `change_password_page.dart`

### 3.3 도메인 로직: 볼링 점수 계산

`features/game/presentation/pages/frame_entry_page.dart`:
- 10프레임, 각 1~3 투구
- Strike/Spare 보너스 점수 lookahead 계산 (`_getNextTwoThrows`, `_getNextOneThrow`)
- 10프레임 특수 규칙(스트라이크/스페어 시 최대 3투구)
- 누적 점수는 `_cumulativeScores` getter로 반응형 계산

---

## 4. REST API 엔드포인트

모든 엔드포인트는 `baseUrl` + 아래 path.

### 4.1 `/users` (`users.controller.ts`)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/users/login` | 이메일/비밀번호 로그인 |
| POST | `/users/signup` | 회원가입 |
| POST | `/users/sync` | Supabase Auth 유저 DB 동기화 |
| GET | `/users/:id` | 프로필 조회 |
| POST | `/users/:id/change-password` | 비밀번호 변경 |
| PATCH | `/users/:id` | 프로필 업데이트 (닉네임/전화/이미지) |

### 4.2 `/groups` (`groups.controller.ts`)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/groups` | 클럽 생성 |
| GET | `/groups` | 전체 클럽 목록 |
| GET | `/groups/me/:user_id` | 내 클럽 목록 |
| GET | `/groups/:id` | 클럽 상세 |
| POST | `/groups/:id/join` | (레거시) 즉시 가입 |
| POST | `/groups/:id/join-requests` | 가입 신청 |
| GET | `/groups/:id/join-requests` | 가입 신청 목록 (관리자) |
| POST | `/groups/:id/join-requests/:requestId/approve` | 가입 승인 |
| POST | `/groups/:id/join-requests/:requestId/reject` | 가입 반려 |
| GET | `/groups/:id/members` | 멤버 목록 |
| GET | `/groups/:id/members-with-stats` | 멤버별 통계 포함 목록 |

### 4.3 `/games` (`games.controller.ts`)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/games` | 게임 기록 저장 (개인/클럽) |
| GET | `/games/club/:room_id` | 클럽 경기 참가자 기록 |
| GET | `/games/users/:user_id/statistics` | 유저 통계 |
| GET | `/games/users/:user_id/recent` | 최근 경기 |
| GET | `/games/me/:user_id` | 내 경기 목록 |
| GET | `/games/users/:user_id/monthly-frame-stats` | 월간 프레임 통계 |
| GET | `/games/:id/detail/:user_id` | 게임 상세 |

### 4.4 `/notifications` (`notifications.controller.ts`)

| Method | Path | 설명 |
|--------|------|------|
| GET | `/notifications/:userId` | 알림 목록 (최신순) |
| GET | `/notifications/:userId/unread-count` | 미읽음 카운트 |
| POST | `/notifications/:id/read` | 단건 읽음 |
| POST | `/notifications/:userId/read-all` | 전체 읽음 |
| POST | `/notifications/:userId/fcm-token` | FCM 토큰 등록 (upsert) |
| DELETE | `/notifications/:userId/fcm-token` | FCM 토큰 삭제 |

### 4.5 `/email` (`email.controller.ts`)

| Method | Path | 설명 |
|--------|------|------|
| POST | `/email/send-otp` | OTP 발송 |
| POST | `/email/verify-otp` | OTP 검증 |

### 4.6 루트

| Method | Path | 설명 |
|--------|------|------|
| GET | `/` | 헬스체크 (hello) |

---

## 5. 실시간 — GameRooms Socket.IO

`src/game-rooms/game-rooms.gateway.ts` — `@WebSocketGateway({ cors: true })`

서버는 방별로 `Map<roomId, Map<clientId, Socket>>`, `Map<clientId, {userId, roomId}>`를 유지하며, disconnect 시 참가자도 자동 정리한다(좀비 방지).

### 클라이언트 → 서버

| 이벤트 | Payload |
|--------|---------|
| `createRoom` | `{ user_id, nickname? }` |
| `joinRoom` | `{ roomId, user_id, nickname? }` |
| `updateScore` | `{ roomId, user_id, score, strikes?, spares?, opens? }` |
| `leaveRoom` | `{ roomId, user_id }` |
| `startGame` | `{ roomId }` |

### 서버 → 클라이언트

| 이벤트 | Payload |
|--------|---------|
| `roomCreated` | `{ roomId, state }` (생성자 한정) |
| `roomStateUpdated` | 방 전체 브로드캐스트 — 참가자·점수 상태 |
| `gameStarted` | `{ roomId, participants }` |
| `error` | `{ message }` |

---

## 6. FCM 푸시 흐름

```
[App 실행] → Firebase.initializeApp() → FcmService.init()
            ↓ getToken()
            FCM 토큰 획득
[로그인 성공] → FcmService.syncTokenToServer(userId)
            → POST /notifications/:userId/fcm-token
            → DB: fcm_tokens 테이블 upsert

[서버 이벤트 발생 — 예: 클럽 가입 신청]
  NotificationsService.create() → notifications 테이블 INSERT
                                → PushService.sendToUser(userId, payload)
                                → firebase-admin.messaging().sendEachForMulticast()
                                → 무효 토큰은 자동 삭제

[앱 수신]
  - foreground: onMessage (로그만, 배너 없음 — flutter_local_notifications 미도입)
  - background/terminated: 시스템 알림 표시, 탭 시 onMessageOpenedApp

[로그아웃] → FcmService.clearTokenOnServer(userId)
          → DELETE /notifications/:userId/fcm-token
          → 로컬 토큰 삭제
```

**Push data payload:** `{ notificationId, type, targetId }`
(`type`은 `NotificationType` enum: `club_game_created`, `club_join_request`, `club_join_approved`, `club_join_rejected`)

**서버 초기화:** `FIREBASE_SERVICE_ACCOUNT_PATH` 환경변수로 서비스 계정 JSON 경로 지정. 미설정 시 Push는 no-op(개발용 안전장치).

---

## 7. 데이터 모델 (MySQL / TypeORM 엔티티)

### users (`User`)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| id | uuid PK | Supabase Auth UUID와 동일 |
| email | varchar UNIQUE | |
| password | varchar nullable, select: false | 해싱 저장 |
| nickname | varchar nullable | |
| phone | varchar nullable | |
| profile_image_url | varchar nullable | |
| created_at | datetime | |
| updated_at | datetime | |

### groups (`Group`)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| id | int PK auto | |
| name | varchar(100) | |
| description | text nullable | |
| cover_image_url | varchar nullable | |
| created_at / updated_at | datetime | |

관계: `OneToMany → group_members`

### group_members (`GroupMember`) — 복합키 PK

| 컬럼 | 타입 | 비고 |
|------|------|------|
| group_id | int PK (FK groups.id) | |
| user_id | uuid PK (FK users.id) | |
| role | enum('ADMIN','MEMBER') | 기본 MEMBER |
| joined_at | datetime | |

### group_join_requests (`GroupJoinRequest`)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| id | int PK auto | |
| group_id | int FK | |
| user_id | uuid FK | |
| message | text nullable | |
| status | enum('pending','approved','rejected') | |
| createdAt / updatedAt | datetime | |

유니크 제약: `(group_id, user_id, status)`

### games (`Game`)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| id | int PK auto | |
| user_id | uuid FK → users.id | |
| total_score | int | 기본 0 |
| play_date | date | |
| location | varchar(100) nullable | 볼링장 |
| is_club_game | bool | 기본 false |
| room_id | varchar(32) nullable | 클럽 경기 방 코드 |
| club_rank | int nullable | 클럽 경기 종료 시 순위 |
| started_at | datetime nullable | FrameEntryPage 진입 시각 |
| ended_at | datetime nullable | 저장 시각 |
| created_at / updated_at | datetime | |

관계: `ManyToOne → User`, `OneToMany → frames`

### frames (`Frame`)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| id | int PK auto | |
| game_id | int FK → games.id | |
| frame_number | int | 1~10 |
| first_roll | int nullable | |
| second_roll | int nullable | |
| third_roll | int nullable | 10프레임 전용 |
| score | int | 해당 프레임까지 누적 |

### notifications (`Notification`)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| id | int PK auto | |
| userId | uuid | 수신자 |
| type | enum (위 참조) | |
| title | varchar(255) | |
| body | varchar(500) | |
| targetId | varchar(255) nullable | 연관 리소스 id (클럽·게임 등) |
| actorId | uuid nullable | 행위자 |
| actorNickname | varchar(100) nullable | |
| isRead | bool | 기본 false |
| createdAt | datetime | |

### fcm_tokens (`FcmToken`)

| 컬럼 | 타입 | 비고 |
|------|------|------|
| token | varchar(255) PK | 디바이스 토큰 자체가 PK (기기 이전 시 upsert) |
| userId | uuid INDEX | |
| platform | varchar(16) | 'android'/'ios'/'other' |
| createdAt / updatedAt | datetime | |

### email_auth (`EmailAuth`)

OTP 발송/검증용 보조 테이블.

---

## 8. 환경 / 설정

### 8.1 API 서버

- 포트: **3000** (개발)
- DB 접속 env (`app.module.ts`):
  - `DB_HOST` (기본 `localhost`)
  - `DB_PORT` (기본 3306)
  - `DB_USERNAME` (기본 `root`)
  - `DB_PASSWORD` (기본 하드코딩값 존재 — 주의)
  - `DB_DATABASE` (기본 `strike_log`)
- FCM:
  - `FIREBASE_SERVICE_ACCOUNT_PATH` = 서비스 계정 JSON 경로
- `.gitignore`: 서비스 계정 JSON 파일명 제외됨

### 8.2 앱

- `.env` 파일 필요 (`flutter_dotenv` 로드) — 프로젝트 루트
- baseUrl 자동 분기 (`core/services/api_client.dart`):
  - Android: `http://10.0.2.2:3000`
  - iOS 시뮬레이터: `http://127.0.0.1:3000`
  - 실기기는 PC 내부 IP로 수정 필요
- 패키지/번들 ID: `com.hojung.strikelog` (Android `applicationId` 및 Podfile 연동)
- iOS 배포 타겟: 15.0 (Firebase 최소 요구)
- Android `POST_NOTIFICATIONS` 권한 manifest 선언 완료

### 8.3 Gradle / CocoaPods

- Android Gradle Plugin 8.9.1, Kotlin 2.1.0, google-services 4.4.2
- iOS Podfile `platform :ios, '15.0'`

---

## 9. 개발 실행 방법

```bash
# API
cd ~/develop/strike_log_api
npm install
npm run start:dev          # 포트 3000

# 앱
cd ~/develop/strike_log_app
flutter pub get
flutter run -d <device-id> # emulator-5554 등
```

다중 Android 에뮬레이터 동시 실행:
```bash
flutter emulators --create --name Strike_Test_2   # 1회만
~/Library/Android/sdk/emulator/emulator -avd Small_Phone_API_36 &
~/Library/Android/sdk/emulator/emulator -avd Strike_Test_2 -port 5556 &
```

---

## 10. 주요 규칙 / 주의사항

- 모든 UI 텍스트·주석은 **한국어**
- `Icons.*` 대신 `Symbols.*` (Material Symbols) 사용
- `withOpacity(x)` 사용 금지 — `withValues(alpha: x)` 권장 (deprecated API 대응)
- 상태관리 라이브러리 도입 없음 — feature 내부에서 StatefulWidget으로 관리
- 개인 게임과 클럽 게임은 같은 `games` 테이블을 `is_club_game` + `room_id`로 구분
- `synchronize: true` 는 개발 전용. 운영 전 마이그레이션 도구 도입 권장

---

## 11. 현재 구현 상태 (체크리스트)

- [x] 이메일 로그인·회원가입, 프로필 수정, 비밀번호 변경
- [x] 개인 게임 기록 (10프레임, 점수 계산, 드래프트 저장/재시도)
- [x] 클럽 CRUD + 가입 승인제 (신청/승인/반려)
- [x] 멤버 통계 페이지
- [x] 클럽 경기 실시간 방 (소켓 기반)
- [x] 알림 모듈 + 미읽음 카운트
- [x] FCM 토큰 등록/삭제, 알림 생성 시 자동 푸시
- [x] Android 13+ 알림 권한 manifest 선언
- [ ] 포그라운드 알림 배너 (`flutter_local_notifications` 미도입)
- [ ] 알림 탭 시 화면 이동 라우팅 로직
- [ ] 커스텀 알림 아이콘 (기본 런처 아이콘 사용 중)
- [ ] iOS Firebase 연동 (APNs 인증키 · GoogleService-Info.plist 미등록)
- [ ] 알림 채널 분리 (타입별)
- [ ] 토픽 구독
- [ ] 운영용 DB 마이그레이션 도구

---

## 12. 최근 커밋

### strike_log_app

```
d091140 feat: FCM 푸시 알림 기반 구축 및 클럽 가입 요청 플로우
dbd39e3 feat: 드래프트 배너 UI, 멤버 통계 페이지, 게임 시작/종료 시각 전송
04b5500 fix: iOS에서 저장 후 대시보드 자동 갱신 안 되는 문제 해결
56dfa4a feat: 클럽 경기 요약 페이지, 저장 안정성 및 대시보드 자동 갱신 개선
81f8042 feat: 소켓 이벤트 리팩토링, 게임룸 상태 관리 개선 및 UI 조정
```

### strike_log_api

```
7003857 feat(games): 클럽 게임 생성 시 멤버 알림 전송
f2a2fb9 feat(groups): 클럽 가입 승인제 도입
68a4f2b feat(notifications): 푸시 알림 모듈 추가
4fafd7b chore: Swagger API 문서화 및 firebase-admin 의존성 추가
89b23ff feat: 좀비 참가자 자동 정리 및 게임 시작/종료 시각 저장
```
