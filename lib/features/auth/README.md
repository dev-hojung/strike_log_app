# Auth — 인증 / 회원가입

## 목적
이메일·비밀번호 로그인 + 회원가입(이메일 OTP 인증).
앱 종료 후 재진입 시 **자동 로그인 유지**, 로그인 화면에 **아이디 저장** 옵션 지원.

## 페이지
- `LoginPage` — 로그인 + 401 가드 + 로그인 후 프로필 prefetch + 아이디 저장 체크박스
- `SignupPage` — 이메일 OTP 인증 → 비밀번호/닉네임 입력 → 약관·개인정보 동의 후 가입

## 자동 로그인 / 세션 유지
- 토큰: `AuthTokenStorage`(`core/services/`)가 SharedPreferences에 영구 저장 + 메모리 미러.
- 앱 시작 시 `main.dart`에서 JWT + user_id 모두 있으면 `MainContainer`로 직접 진입 (LoginPage 우회).
- 서버 401 응답 시 `ApiClient.onUnauthorized` 콜백 → `SessionManager.clearAll()` → LoginPage 강제 이동(안전망).

## 아이디 저장
- SharedPreferences 키: `login_remember_email_v1`(bool), `login_remembered_email_v1`(string).
- 체크 시 다음 진입에서 이메일 입력란이 자동 채워짐.
- 체크 해제 후 로그인 성공하면 저장된 이메일 삭제.

## 의존성
- `core/services/api_client.dart` — Dio 호출
- `core/services/auth_token_storage.dart` — JWT 보관
- `core/services/session_manager.dart` — 로그인 직전 캐시/토큰 정리
- `core/services/user_profile_cache.dart` — 로그인 후 prefetch
- `core/services/fcm_service.dart` — 로그인 후 FCM 토큰 서버 동기화
- `features/legal/...` — 약관/개인정보 페이지 링크

## 백엔드 엔드포인트
| Method | Path | 용도 |
|--------|------|------|
| POST   | `/users/login`          | 이메일/비밀번호 로그인 → JWT |
| POST   | `/users/signup`         | 회원가입 |
| POST   | `/users/forgot-password/reset` | 비밀번호 재설정 (OTP 1회 소비 + 새 비번 저장) |
| POST   | `/email/send-otp`       | 이메일 인증 코드 발송 |
| POST   | `/email/verify-otp`     | 인증 코드 검증 |

## 주요 동작
- 회원가입 흐름: 이메일 입력 → 3분 타이머 OTP → 비밀번호 8자 이상 → 닉네임 → **약관 동의 필수 체크박스** → 가입
- 로그인 후: `SessionManager.clearAll()` → JWT 저장(`AuthTokenStorage.save`) → user_id/닉네임 SharedPreferences 저장 → `_prefetchProfile` → `FcmService.syncTokenToServer` → `UnreadNotificationsService.refresh`

## 알려진 TODO
- `EditPhonePage`의 OTP 연동(`features/profile`) — 백엔드 SMS 엔드포인트 부재로 보류
- 소셜 로그인(카카오/네이버/애플) — UI는 삭제됨. 도입 시 `SignupPage` 디자인 재검토 필요.
