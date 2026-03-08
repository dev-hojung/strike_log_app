# Strike Log

볼링 경기 기록 및 통계 관리 앱

## 소개

Strike Log는 볼링 경기 점수를 기록하고, 통계와 성적 추이를 확인할 수 있는 Flutter 기반 모바일 앱입니다.

## 주요 기능

- **경기 기록**: 프레임별 점수 입력 및 게임 기록 저장
- **대시보드**: 평균 점수, 최고 점수, 성적 추이 차트 확인
- **클럽 관리**: 볼링 클럽 가입 및 멤버 확인
- **프로필**: 사용자 정보 및 설정 관리
- **다크 모드**: 시스템 설정 연동 라이트/다크 테마 지원

## 기술 스택

| 구분 | 기술 |
|------|------|
| 프레임워크 | Flutter (Dart SDK ^3.6.0) |
| HTTP 클라이언트 | Dio |
| 차트 | fl_chart |
| 로컬 저장소 | shared_preferences |
| 폰트 | Google Fonts (Lexend) |
| 아이콘 | Material Symbols Icons |
| 환경변수 | flutter_dotenv |

## 프로젝트 구조

```
lib/
├── main.dart
├── core/
│   ├── constants/       # 색상 등 상수 정의
│   ├── theme/           # 앱 테마 설정
│   ├── services/        # API 클라이언트
│   └── widgets/         # 공통 위젯 (MainContainer)
└── features/
    ├── auth/            # 로그인, 회원가입
    ├── home/            # 홈 대시보드, 통계
    ├── game/            # 프레임 입력, 게임 요약
    ├── group/           # 클럽, 멤버 관리
    └── profile/         # 프로필, 설정
```

## 시작하기

### 요구 사항

- Flutter SDK ^3.6.0
- Dart SDK ^3.6.0

### 설치 및 실행

```bash
# 의존성 설치
flutter pub get

# .env 파일 생성 (필요 시)
cp .env.example .env

# 앱 실행
flutter run
```

### 백엔드 서버

개발 환경에서 로컬 API 서버(`localhost:3000`)에 연결됩니다.

- Android 에뮬레이터: `http://10.0.2.2:3000`
- iOS 시뮬레이터: `http://127.0.0.1:3000`

## API 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/users/login` | 로그인 |
| GET | `/users/:id` | 사용자 정보 조회 |
| GET | `/games/users/:id/statistics` | 볼링 통계 조회 |
| GET | `/games/users/:id/recent` | 최근 게임 조회 |
