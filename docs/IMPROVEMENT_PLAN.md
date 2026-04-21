# Strike Log — 개선 과제 및 신규 기능 로드맵

작성 기준일: 2026-04-21
대상 레포:
- 앱: `/Users/khj/develop/strike_log_app` (Flutter)
- API: `/Users/khj/develop/strike_log_api` (NestJS)

목적: 실서비스 런칭 가능한 품질로 다듬기 + 중장기 기능 확장 방향성 정리.

---

## 1. 미흡한 부분 (우선순위별)

### 🔴 실서비스 전 **반드시** 해결해야 할 것

| 영역 | 문제 | 영향 |
|------|------|------|
| **인증 모델** | user_id를 요청 body/query로 받음 → 누구나 남의 계정 조작 가능 | 치명적 보안 취약점 |
| **DB 마이그레이션** | `synchronize: true`로 스키마 자동 변경 | 프로덕션 배포 시 데이터 유실 위험 |
| **DTO 검증** | `class-validator` 미적용, 임의 필드 수신 | 잘못된 요청으로 서비스 파손 |
| **비밀번호 처리** | 해싱/검증 로직 검증 안 됨 (bcrypt 사용 여부 확인 필요) | 유출 시 plaintext 위험 |
| **HTTPS** | 로컬 개발 기준, 프로덕션 SSL 미적용 | 중간자 공격 |
| **Rate Limiting** | 없음 — 로그인/SMS 등 남용 가능 | brute-force, 비용 폭증 |
| **시크릿 관리** | `app.module.ts`에 DB 비번 하드코딩 fallback, `.env` 키가 평문 | 저장소 노출 시 즉시 유출 |

### 🟡 운영 품질 관련

- **로깅**: `console.log`, `print` 산재 → 구조화된 로거(pino + JSON) 없음
- **에러 추적**: Sentry 등 미도입
- **테스트**: 유닛/통합/E2E 거의 없음 (`app.controller.spec.ts`만 있는 상태 추정)
- **CI/CD**: GitHub Actions 등 미구성
- **백업 전략**: 문서/스크립트 없음
- **헬스체크**: `/health` 등 표준 엔드포인트 없음
- **에러 핸들러**: 서버 전역 `ExceptionFilter` 없음, 내부 에러 스택이 클라에 노출될 수 있음

### 🟢 코드 품질 / 기술 부채

- **상태관리 없음**: `StatefulWidget` + 직접 API 호출 → 페이지 간 데이터 동기화 어렵고, 네트워크 반복
  - Riverpod / Bloc 도입 고려
- **Dio 직접 호출이 페이지에 섞여 있음**: 레이어 분리 약함 (일부 Service는 정리됨)
- **라우팅**: `Navigator.push` 직접 호출, named route 없음 → 딥링크/푸시 라우팅 확장성 낮음
  - `go_router` 도입 추천
- **타입 안전성**: `Map<String, dynamic>`로 API 응답 처리 → 필드명 오타/누락이 런타임 에러로
  - DTO 모델 클래스 + `freezed`로 변환 권장
- **이미지 업로드**: 프로필/클럽 커버 업로드 경로가 API에 없음 (DB에는 URL 컬럼 존재)
- **웹 지원**: `dart:io`/`Platform` 의존성으로 현재 크래시
- **i18n**: 한국어만, 국제화 불가
- **접근성**: 폰트 크기, 스크린리더 라벨 등 미고려

### 🔵 UX 개선 포인트

- **비밀번호 재설정** 플로우 없음
- **이메일 인증** 로직은 있으나 신규 가입 시 강제되는지 불명확
- **알림 설정** (타입별 on/off) 없음
- **오프라인 대응** 부분적 (게임 드래프트만 있음. 다른 데이터는 네트워크 실패 시 빈 화면)
- **에러 메시지 표준화** 부족 (SnackBar 문구가 피처별로 제각각)
- **빈 상태 디자인** 일부 화면만 있음

---

## 2. 추가 기능 개발 방안

### 🎯 Tier A — 가까운 가치 (1~2주, 당장 만들면 사용자 가치 큼)

1. **비밀번호 재설정** (이메일 OTP 재활용)
2. **프로필/클럽 이미지 업로드**
   - S3 또는 Cloudflare R2 presigned URL
   - 앱에서 이미지 리사이즈(`image` 패키지) 후 업로드
3. **알림 탭 UX 보강**
   - 미읽음 배지, 필터(타입별), 무한 스크롤
4. **경기 상세 통계 강화**
   - 프레임별 스트라이크/스페어/오픈 분포 그래프
   - 10프레임 비교 (처음/마지막 프레임 대비)
   - 볼링장별 평균 점수
5. **업적 / 배지 시스템**
   - 첫 300점, 10연속 스트라이크, 10경기 연속 200↑ 등
   - 알림으로 축하 메시지
6. **리더보드**
   - 클럽 내 월간 평균 점수 순위
   - 전국 주간 TOP 100

### 🌱 Tier B — 중기 확장 (1~2개월)

7. **소셜 로그인** (카카오/구글/애플)
   - 가입 장벽 낮춤. 현재 설계(uuid PK)와 호환 쉬움
8. **친구 / 팔로우**
   - 내 친구들 최근 경기 피드
   - 친구 초대로 클럽 가입 권유
9. **클럽 토너먼트 / 챌린지**
   - "이번 주 평균 200 달성하기" 같은 미션
   - 주간 정산 → 알림
10. **개인 기록 공유 카드**
    - 점수판 이미지 생성 → 카카오톡/인스타 공유
    - Flutter `screenshot` 패키지
11. **볼링장 맵**
    - 경기 기록의 `location`을 그룹핑
    - `google_maps_flutter`로 자주 가는 곳 표시
12. **다크/라이트 토글**
    - `ThemeMode.system` 지원 (현재 다크 고정)

### 🚀 Tier C — 플랫폼 확장 (2~3개월)

13. **웹 포털**
    - 관리자용 대시보드 먼저 (생성 신청 관리, 유저 통계)
    - Phase: Flutter Web 호환화 → 반응형 레이아웃 → 관리자 기능부터
14. **iOS 지원**
    - Firebase iOS 앱 등록 + APNs 인증키
15. **결제 / 구독** (Phase 3)
    - `in_app_purchase` + Google Play Billing
    - 체험판 만료 후 월 구독
    - 프리미엄 기능(상세 통계, 광고 제거)
16. **레슨/프로 매칭** (비즈니스)
    - 볼링장 제휴, 레슨 프로 리스팅
    - 예약/결제 연동

### 🤖 Tier D — 차별화 (장기, 선택)

17. **AI 볼링 분석**
    - 점수 입력 시 약점 프레임 분석, 조언 제공 (OpenAI API)
    - 자세 영상 업로드 → 분석 (향후 MediaPipe 등)
18. **실시간 경기 관전**
    - 클럽 경기방을 외부 관중이 볼 수 있도록 (읽기 전용)
19. **보이스 입력**
    - 점수 입력을 음성으로 ("스트라이크", "8개")
20. **데이터 수집 / 인사이트**
    - 볼링장별 평균 난이도, 지역별 실력 분포 (익명 통계)

---

## 3. 기술 부채 청산 로드맵 제안

| 주차 | 작업 | 효과 |
|------|------|------|
| **1주** | JWT 인증 도입, ValidationPipe 전역 적용 | 보안 기초 확립 |
| **1주** | TypeORM 마이그레이션 전환, `.env` 시크릿 관리 개선 | 배포 안정성 |
| **2주** | Sentry 연동, 구조화 로깅, `/health` 엔드포인트 | 운영 가시성 |
| **2주** | Rate limiting, 전역 Exception Filter | 안정성 |
| **3주** | Flutter 상태관리(Riverpod) 부분 도입, 이미지 업로드 API | 확장 기반 |
| **4주** | GitHub Actions CI/CD, 도메인 + SSL | 배포 자동화 |

---

## 4. 우선순위 요약 (권장)

**먼저 해야 할 것 (실서비스 전 필수):**
1. JWT 인증 도입
2. `synchronize` 제거 + 마이그레이션
3. DTO 검증 + Exception Filter
4. 도메인 + HTTPS + 시크릿 관리

**다음 1개월 동안 만들면 좋은 기능 TOP 3:**
1. 비밀번호 재설정
2. 이미지 업로드
3. 업적/배지 시스템 (retention 증가)

---

## 5. 참고: 현재 세션에서 완료된 주요 작업

- FCM 기반 구축 (토큰 서버 연동, firebase-admin 자동 푸시)
- 클럽 생성 승인제 (신청/승인/반려/취소) + 관리자 UI
- 클럽 체험판 Phase 1 (배너) + Phase 2 (만료 차단, cron 알림)
- 프로필 메모리 캐시 (initState 동기 즉시 렌더)
- 포그라운드 알림 배너 (`flutter_local_notifications`)
- 알림 탭 라우팅 (탭에 따라 내 클럽/관리자/알림 페이지 등으로 이동)
- Android 13+ 알림 권한 manifest 선언
- iOS 배포 타겟 15.0 상향 (firebase_core 대응)

---

## 6. 참고 문서

- [PROJECT_OVERVIEW.md](./PROJECT_OVERVIEW.md) — 현재 아키텍처/기능/엔드포인트/스키마 스냅샷

---

## 7. 구체 TODO — 코드 레벨 감사 결과

> 2026-04-19 1차 감사에서 수집된 항목 중 현재 시점(2026-04-21)까지 유효한 건을 추려 병합한 리스트입니다.
> 삭제된 페이지(`group_detail_page.dart`, `club_members_page.dart`)나 이미 해결된 항목(소셜 로그인 UI 제거, 클럽 승인제 도입 등)은 제외했습니다.

### 7.1 빈 핸들러 / 동작 안 하는 UI

| 위치 | 설명 |
|------|------|
| `lib/features/home/presentation/pages/home_dashboard_page.dart` | 상단 알림 아이콘 버튼 — 알림 페이지로 이동 연결 필요 |
| `lib/features/game/presentation/pages/frame_entry_page.dart` | 프레임 입력 화면 More(⋮) 버튼 — 기능 정의 필요 (현재 빈 핸들러) |
| `lib/features/game/presentation/pages/game_history_page.dart` | 필터/정렬 버튼 — 월/점수 필터 미구현 |
| `lib/features/auth/presentation/pages/login_page.dart` | "비밀번호 찾기" 링크 미연결 (Tier A 재설정 플로우 구현 시 해결) |
| `lib/features/auth/presentation/pages/login_page.dart` | 비밀번호 표시/숨김 아이콘 토글 동작 없음 |

### 7.2 Silent Catch (에러 삼킴)

| 위치 | 문제 |
|------|------|
| `lib/features/game/data/services/game_draft_repository.dart` | 드래프트 JSON 손상 시 조용히 초기화 — 사용자에게 알리고 복구/폐기 선택지 제공 필요 |
| `profile_page.dart` · `account_settings_page.dart` | `catch (_) {}` — 최소한 Sentry 기록 + Retry UI 필요 |

### 7.3 입력 검증 & 실시간 피드백

| 위치 | 부족 |
|------|------|
| `signup_page.dart` | 비밀번호 강도, 이메일 중복 확인 결과 UI |
| `edit_phone_page.dart` | 전화번호 형식 검증, OTP 타이머 만료 후 재전송 |
| `game_room_page.dart` | 방 코드 실시간 검증 (현재 onPressed 시점에만 확인) |
| 전반 | `TextInputAction.next/done` 미설정 — 키보드 이동 어색 |

### 7.4 로딩/에러/빈 상태

| 위치 | 부족 |
|------|------|
| `home_dashboard_page.dart` | 에러 시 재시도 UI |
| `my_groups_page.dart` | 로드 실패 시 재시도 버튼 없음 |
| `frame_entry_page.dart` | 저장 중 로딩 인디케이터 / 저장 후 이동 경로 명확화 |
| `game_room_page.dart` | 참가자 0명 상태 문구 명확화 |

### 7.5 명시적 TODO

| 위치 | 기능 |
|------|------|
| `frame_entry_page.dart` 저장 핸들러 | 저장 로직 연결 검증 (Phase 2 체험판 차단 대응 포함) |
| `my_groups_page.dart` 설정 버튼 | 클럽 설정 페이지 — 멤버 관리/탈퇴/클럽 삭제 |
| `edit_phone_page.dart` 인증번호 발송 | 현재 500ms 더미 지연 → 실제 API 연결 |

### 7.6 접근성 / 다국어

- `Colors.grey` 직접 사용처 대비비 점검 (다크모드 시 가독성)
- 폰트 스케일 대응 (`MediaQuery.textScaleFactor`)
- 한국어 외 추가 로케일 준비 (현재 모든 문자열 하드코딩)

### 7.7 우선순위 요약 (7장 한정)

- 🔴 **즉시**: Silent catch 3곳, `my_groups_page` 로드 실패 재시도, frame_entry 저장 경로 검증
- 🟡 **단기**: 비밀번호 찾기, OTP 실 API, 클럽 설정 페이지, 입력 검증 실시간 피드백
- 🟢 **추후**: 필터/정렬, 키보드 네비게이션, 접근성

