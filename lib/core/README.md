# Core — 공통 인프라

## 목적
features 간 공유되는 인프라(HTTP/소켓/인증/캐시/로깅/에러/위젯/테마/상수)를 모은 디렉터리. feature 모듈이 직접 import해서 사용.

## constants/
- `app_colors.dart` — 다크/라이트 팔레트 (primary `#135BEC`)

## theme/
- `app_theme.dart` — Google Fonts Lexend, Material Symbols Icons

## services/
| 파일 | 역할 |
|------|------|
| `api_client.dart`              | Dio 싱글톤. Authorization 헤더 자동 부착, 401 가드 + `onUnauthorized` 콜백 |
| `socket_service.dart`          | Socket.IO 싱글톤 (클럽 게임용). `connect/createRoom/joinRoom/sendScoreUpdate/startGame` |
| `auth_token_storage.dart`      | JWT 토큰 SharedPreferences 저장/조회 |
| `session_manager.dart`         | 로그인 직전 모든 캐시/토큰 정리 |
| `user_profile_cache.dart`      | 프로필 메모리 캐시 + prefetch |
| `unread_notifications_service.dart` | 미읽음 알림 카운트 전역 싱글톤 (홈 뱃지 동기화) |
| `fcm_service.dart`             | FCM 초기화 + 토큰 동기화 + 포어/백그라운드 메시지 처리 + 인앱 라우팅 (타입별 분기) |
| `share_capture.dart`           | RepaintBoundary 캡처 + share_plus 공유 |
| `app_logger.dart`              | Sentry 통합 (`captureError`, `info`) |

## errors/
- `api_error.dart` — `ApiErrorType` enum (network/timeout/server/client/unauthorized/unknown), `ApiError` 클래스 + `isRetryable`
- `api_error_classifier.dart` — `DioException` → `ApiError` 분류

## widgets/
- `main_container.dart` — 로그인 후 하단 네비 허브 (Home/History/Groups/Profile)
- `error_retry_view.dart` — 인라인 에러 + 재시도 카드 (타입별 아이콘·컬러, `isRetryable`일 때만 버튼)

## 사용 패턴
```dart
try {
  await api.fetch();
} catch (e, st) {
  final err = ApiErrorClassifier.from(e, st);
  if (err.type != ApiErrorType.unauthorized) {
    AppLogger.captureError(e, stackTrace: st, context: 'xxx_fetch');
  }
  setState(() => _error = err);
}
// build에서
if (_error != null && _data == null) {
  return ErrorRetryView(error: _error!, onRetry: _retry);
}
```

## 알려진 미해결
- `SocketService.off(event, handler)` 핸들러별 시그니처 미지원 — 현재는 이벤트 전체 off만 가능
