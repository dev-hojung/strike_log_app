# Help — 도움말

## 목적
앱 사용 가이드 + 볼링 용어 사전. 신규/초보 사용자가 기능 사용법과 볼링 기본 용어를 한곳에서 학습할 수 있도록 한다.

## 페이지
- `HelpPage` — 탭 2개:
  - **사용 가이드**: 카테고리별 ExpansionTile (게임 기록 / 시리즈 / 클럽 / 통계와 배지).
  - **볼링 용어**: 검색바 + 가나다순 카드 리스트. term/english/description/symbol 어디든 매칭.

## 데이터
- `data/help_content.dart` — 정적 데이터. `kHelpGuideSections`, `kBowlingTerms`.
  - 콘텐츠 추가/수정 시 이 파일만 편집하면 `HelpPage`에 자동 반영.
  - 백엔드 인프라 없이 오프라인에서도 표시.

## 진입점
- 홈 대시보드 AppBar 우측 `?` 아이콘.
- 프로필 페이지 → 계정 설정 아래 "도움말" 메뉴.
- 회원가입 직후 1회 환영 다이얼로그 (`SharedPreferences` 키 `help_onboarding_shown_v1`).

## 의존성
- `core/constants/app_colors.dart`
- 외부 호출/네트워크 없음 — 순수 표시 페이지.

## 콘텐츠 가이드
신규 가이드 항목 추가는 `HelpGuideSection` / `HelpGuideItem` 객체 추가, 신규 용어는 `BowlingTerm` 객체 추가.
용어 정렬은 list 순서를 그대로 따른다(가나다순으로 직접 정렬).
