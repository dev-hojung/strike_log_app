# Home — 대시보드

## 목적
로그인 직후 진입하는 홈. 사용자의 평균/최고 점수, 추이 차트, 베스트 시리즈, 이번 달 요약, 출석 streak + 최근 배지를 한 화면에 집약.

## 페이지
- `HomeDashboardPage`
  - AppBar: 좌측 닉네임, 우측 알림(미읽음 카운트 뱃지) + 도움말(`?`) 아이콘
  - 통계 카드 (종합 에버리지·최고 점수, 트렌드 %)
  - **에버리지 3분할 패널** (개인/클럽/종합) — `HomeDashboardData.personalAverageScore`, `clubAverageScore`, `averageScore`
  - 출석 streak + 최근 배지 통합 카드 (탭 → BadgeListPage)
  - 성적 추이 라인 차트 (fl_chart)
  - 이번 달 프레임 요약 (스트라이크/스페어/오픈/올커버)
  - 베스트 시리즈 카드
  - 최근 게임
  - 빈 상태 SVG 일러스트
  - **첫 실행 1회 온보딩 다이얼로그** (`SharedPreferences` 키 `help_onboarding_shown_v1`)

## 데이터 모델
- `data/models/home_dashboard_data.dart` — 대시보드 집계 응답 + `RecentGame`/`TrendData`

## 서비스
- `HomeApiService` — 통계 조회 + 대시보드 데이터 조합

## 백엔드 엔드포인트
- `GET /games/users/:user_id/statistics` — 평균/최고/총 게임 수/트렌드/최근10
- `GET /game-series/users/:userId/best` — 베스트 시리즈
- `GET /badges/me/recent?limit=1` — 최근 배지
- `GET /attendance/me/streak` — 현재/최장 streak

## 의존성
- `core/errors/...` — 첫 로드 실패 시 `ErrorRetryView` 노출
- `core/services/unread_notifications_service.dart` — 미읽음 뱃지
- `core/services/pending_join_requests_service.dart` — 하단 네비 그룹 탭 가입 신청 뱃지 (운영자만)
- `features/badges/...` — streak/배지 카드 + 진입
- `features/game/...` — 최근 게임, 시리즈 등
- `features/help/...` — AppBar `?` 아이콘 / 온보딩 다이얼로그가 `HelpPage`로 진입

## 캐싱 전략
- `static HomeDashboardData? _cachedData`, `_cachedBestSeries` — 페이지 재생성 시에도 유지
- `HomeDashboardPage.cachedHighestScore` — 베스트 갱신 판정용 (저장 직후 캐시 invalidate)

## 에러 정책
- 캐시 없는 첫 로드 실패 → `ErrorRetryView` 전체 교체
- 캐시 있는 갱신 실패 → SnackBar 알림, 기존 화면 유지
- `unauthorized`는 401 가드에 위임 (본 화면 로깅/노출 X)
