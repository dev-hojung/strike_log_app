# system_notices 피처

운영자가 모든 사용자에게 띄우는 시스템 공지를 모달로 노출하고, "오늘 하루 안 보기" 토글을 SharedPreferences로 유지.

## 구성

- `data/models/system_notice.dart` — id/title/body/priority/dismissible/starts_at/ends_at
- `data/services/system_notices_api_service.dart` — `GET /system-notices/active` 호출
- `data/services/system_notices_service.dart` — 싱글톤 진입점. `maybeShowAll(context)` 한 번이면 끝
- `presentation/widgets/system_notice_dialog.dart` — AlertDialog. priority별 색·아이콘 분기

## 호출 위치

- `MainContainer.initState` — 로그인 상태 진입 시
- `LoginPage.initState` — 로그아웃 상태 진입 시

서비스 내부에 `_shownThisRun` 플래그가 있어 한 실행에서 중복 노출 안 됨.

## "오늘 하루 안 보기"

SharedPreferences 키 `system_notices_dismissed_v1`에 JSON 저장:

```json
{ "1": "2026-06-07T23:59:59.000", "5": "2026-06-07T23:59:59.000" }
```

값이 현재 시각보다 미래면 해당 공지는 건너뜀. 새 날(자정) 지나면 자동 재노출.

`dismissible == false`인 공지(점검 임박 등)에는 토글 버튼이 안 뜨고 확인만 가능.

## 백엔드

자세한 SQL/엔드포인트 사양은 `src/system-notices/README.md`.
