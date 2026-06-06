# challenges 피처

주간 챌린지 진행률을 홈 대시보드에 노출하는 가벼운 모듈.

## 구성

- `data/models/weekly_challenge.dart` — 응답 모델 (`key/name/target/current/percent/achieved/...`)
- `data/services/challenges_api_service.dart` — `GET /challenges/me/weekly` 호출
- `presentation/widgets/weekly_challenges_card.dart` — 홈 대시보드용 카드 위젯

## 진입점

`HomeDashboardPage`가 데이터 로드 시 같이 fetch → 출석/배지 카드 아래에 카드 노출. 응답이 비어 있거나 실패하면 카드 자체를 숨김.

## 백엔드

`/challenges/me/weekly` — 자세한 사양은 백엔드 `src/challenges/README.md`.
