# Auth — 인증 / 회원가입

## 목적
이메일·비밀번호 로그인, 소셜 로그인(카카오/네이버/애플), 회원가입(OTP 이메일 인증 포함)을 담당.

## 페이지
- `LoginPage` — 로그인 + 401 가드 + 로그인 후 프로필 prefetch
- `SignupPage` — 이메일 OTP 인증 → 비밀번호/닉네임 입력 → 약관·개인정보 동의 후 가입

## 의존성
- `core/services/api_client.dart` — Dio 호출
- `core/services/auth_token_storage.dart` — JWT 보관
- `core/services/session_manager.dart` — 로그인 직전 캐시/토큰 정리
- `core/services/user_profile_cache.dart` — 로그인 후 prefetch
- `features/legal/...` — 약관/개인정보 페이지 링크

## 백엔드 엔드포인트
| Method | Path | 용도 |
|--------|------|------|
| POST   | `/users/login`          | 이메일/비밀번호 로그인 → JWT |
| POST   | `/users/signup`         | 회원가입 |
| POST   | `/users/sync`           | 소셜 로그인 동기화 (없으면 생성) |
| POST   | `/email/send-otp`       | 이메일 인증 코드 발송 |
| POST   | `/email/verify-otp`     | 인증 코드 검증 |

## 주요 동작
- 회원가입 흐름: 이메일 입력 → 3분 타이머 OTP → 비밀번호 8자 이상 → 닉네임 → **약관 동의 필수 체크박스** → 가입
- 로그인 후: `AuthTokenStorage`에 JWT 저장 → `SessionManager.clearAll()` 후 진입 → `UserProfileCache.prefetch()`

## 알려진 TODO
- `EditPhonePage`의 OTP 연동(`features/profile`) — 백엔드 SMS 엔드포인트 부재로 보류
