# system_notices 피처

운영자가 띄우는 시스템 공지를 모달로 노출 + (백엔드) FCM broadcast 푸시 수신.

## 구성

- `data/models/system_notice.dart` — id/title/body/priority/dismissible/starts_at/ends_at
- `data/services/system_notices_api_service.dart` — `GET /system-notices/active` 호출
- `data/services/system_notices_service.dart` — 싱글톤 진입점. `maybeShowAll(context)` 한 번 호출
- `presentation/widgets/system_notice_dialog.dart` — AlertDialog. priority별 색·아이콘 분기

## 호출 위치

- `MainContainer.initState` — 로그인 상태 첫 진입
- `LoginPage.initState` — 로그아웃 상태 첫 진입

서비스 내부 `_shownThisRun` 플래그로 한 실행에서 중복 노출 안 됨.

## "오늘 하루 안 보기"

SharedPreferences 키 `system_notices_dismissed_v1`에 JSON 저장:

```json
{ "1": "2026-06-07T23:59:59.000" }
```

값이 현재 시각보다 미래면 해당 공지는 모달로 안 띄움. 자정 지나면 자동 재노출.

`dismissible == false`인 공지(점검 임박 등)에는 토글 버튼 안 뜸.

## 푸시와의 관계

`POST /system-notices` 관리자 엔드포인트로 등록 시 `PushService.sendToAllDevices()`가 즉시 호출되어 모든 디바이스에 broadcast. 로그아웃 디바이스도 수신 (anonymous fcm token 등록 흐름).

매일 반복(`repeat_daily=true`)도 백엔드 Cron이 KST 09:00에 자동 재발송.

자세한 사양은 백엔드 `src/system-notices/README.md`.
