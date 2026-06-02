# Strike Log

볼링 경기 기록·통계·클럽 커뮤니티 Flutter 앱.

## 개요

10프레임 볼링 점수 입력·계산·저장과 개인/시리즈/클럽 3가지 게임 모드를 제공하는 모바일 앱.
NestJS 백엔드(`/Users/khj/develop/strike_log_api`)와 JWT + Socket.IO + FCM으로 통신.

## 주요 기능

- **점수 기록**: 10프레임 입력 + 자동 스트라이크·스페어 보너스 계산
- **3가지 모드**: 개인 / 시리즈(3·6게임 묶음) / 클럽(Socket.IO 실시간 점수 공유)
- **대시보드**: 평균·최고 점수, 추이 차트, 베스트 시리즈, 이번 달 요약, 출석 streak + 최근 배지
- **클럽**: 생성·가입 승인제, 멤버 통계, 클럽 랭킹
- **배지**: 25개 카탈로그 (마일스톤/점수/스트라이크/시리즈/streak/클럽), 신규 획득 시 모달 + 푸시
- **알림**: 인앱 목록 + 미읽음 뱃지 + FCM(클럽 게임/베스트 갱신/배지)
- **결과 공유**: 게임/상세/시리즈 결과 이미지 캡처 → share_plus

## 기술 스택

| 구분 | 기술 |
|------|------|
| 프레임워크 | Flutter (Dart SDK ^3.6.0) |
| HTTP | Dio |
| 실시간 | socket_io_client |
| 차트 | fl_chart |
| 로컬 저장 | shared_preferences |
| 푸시 | firebase_messaging + flutter_local_notifications |
| 에러 수집 | sentry_flutter |
| 폰트 | Google Fonts (Lexend) |
| 아이콘 | Material Symbols Icons |

## 디렉터리 구조

```
lib/
├── main.dart
├── core/                       — 공통 인프라 (services/widgets/errors/theme/constants)
└── features/
    ├── auth/                   — 로그인·회원가입
    ├── game/                   — 점수 입력·저장·조회·시리즈·클럽 (핵심 도메인)
    ├── home/                   — 대시보드
    ├── group/                  — 클럽 (생성·가입·랭킹·관리)
    ├── badges/                 — 배지 + 출석 streak
    ├── notifications/          — 알림 목록 + FCM
    ├── profile/                — 프로필·계정 설정
    └── legal/                  — 개인정보처리방침·이용약관
```

각 디렉터리에는 상세 `README.md`가 있음.

## 빌드 & 실행

```bash
flutter pub get
flutter run                  # 디바이스 자동 감지
flutter analyze              # 정적 분석
flutter test                 # 테스트
```

### 환경

- `.env` 파일이 프로젝트 루트에 필요 (flutter_dotenv가 기동 시 로드)
- 백엔드 로컬 서버 포트: `3001`
  - Android 에뮬레이터: `http://10.0.2.2:3001`
  - iOS 시뮬레이터: `http://127.0.0.1:3001`
  - 자동 분기는 `lib/core/services/api_client.dart`

### Android 에뮬레이터 헬퍼
```bash
fra      # zsh 함수: 에뮬레이터 자동 부팅 + 빈 포트 탐색
```

## 아키텍처 메모

- 상태관리: **StatefulWidget + setState** (Provider/Riverpod/BLoC 없음)
- 네비게이션: 직접 `Navigator.push/pop` (네임드 라우트 X)
- 세션: `SharedPreferences`에 `user_id` + JWT 보관
- 다크 모드 기본 (`ThemeMode.dark`)
- 색상 팔레트: `core/constants/app_colors.dart` (primary `#135BEC`)

## 출시 인프라

- 호스팅: **Railway All-in-one** (백엔드 + MySQL)
- 도메인: **strikelog.xyz** (Cloudflare Registrar, API: `api.strikelog.xyz`)
- 푸시: Firebase Spark
- 에러: Sentry
- 플랫폼: **Android 우선** (Apple 비용 부담으로 iOS 보류)

자세한 출시 절차는 메모리 `project_launch_plan.md` 참조.

## 라이선스 / 운영자

- 운영자: 김호정 (dev.hojung@gmail.com)
- 비공개 개인 프로젝트
