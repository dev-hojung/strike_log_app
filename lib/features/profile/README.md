# Profile — 프로필 / 계정 설정

## 목적
사용자 프로필 조회/수정 + 계정 설정 진입점 + 로그아웃 + 약관/개인정보 페이지 진입.

## 페이지
- `ProfilePage` — 프로필 표시 + 메뉴(계정 설정 / 도움말) + 로그아웃 (FCM 토큰 서버 삭제 포함)
- `AccountSettingsPage` — 계정 정보 + 닉네임/전화번호 변경 + 비밀번호 변경 + 약관/개인정보 + **회원 탈퇴**
- `EditNicknamePage` — 닉네임 변경 (`PATCH /users/:id`)
- `EditPhonePage` — 전화번호 변경 (OTP 부분은 TODO, 백엔드 부재)
- `ChangePasswordPage` — 비밀번호 변경 (`POST /users/:id/change-password`)

## 백엔드 엔드포인트
- `GET /users/:id`
- `PATCH /users/:id`
- `POST /users/:id/change-password`
- `DELETE /users/me` — 회원 탈퇴 (FK CASCADE로 게임/시리즈/멤버십 정리 + FCM 토큰 직접 삭제)

## 의존성
- `core/services/user_profile_cache.dart` — 메모리 캐시 (첫 build부터 값 표시)
- `core/services/auth_token_storage.dart`, `core/services/session_manager.dart` — 로그아웃 정리
- `core/services/fcm_service.dart` — 로그아웃 시 토큰 서버에서 삭제
- `features/legal/...` — 약관/개인정보 진입
- `features/help/...` — 프로필 메뉴 "도움말" 진입

## 알려진 TODO
- `EditPhonePage:62` — 실제 SMS/OTP API 연동 (백엔드 엔드포인트 신설 필요)
- 알림 토픽 토글 (UI/백엔드 모두 부재) — 미구현 placeholder 메뉴는 제거됨
