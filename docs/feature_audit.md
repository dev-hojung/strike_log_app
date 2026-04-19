# Strike Log 기능 감사 (Feature Audit)

작성일: 2026-04-19

코드베이스를 훑어 **불필요한 기능 / 보강이 필요한 기능 / 아직 구현되지 않은 기능**을 정리한 문서입니다. 파일 경로:줄번호는 감사 시점 기준입니다.

---

## 1. 불필요하거나 제거/정리 대상

### 1.1 UI만 있고 동작하지 않는 빈 핸들러

| 위치 | 설명 |
| --- | --- |
| `lib/features/home/presentation/pages/home_dashboard_page.dart:192` | 알림 아이콘 버튼 (`onPressed: () {}`) |
| `lib/features/game/presentation/pages/frame_entry_page.dart:578` | 프레임 입력 화면 More(⋮) 버튼 |
| `lib/features/group/presentation/pages/group_detail_page.dart:24` | 그룹 상세 More(⋮) 버튼 |
| `lib/features/group/presentation/pages/group_detail_page.dart:131` | "그룹 매치 기록하기" 버튼 (이동 없음) |
| `lib/features/group/presentation/pages/group_detail_page.dart:150` | 리더보드 필터 UI (기능 없음) |
| `lib/features/group/presentation/pages/club_members_page.dart:72,132,359,378` | More/정렬 버튼 4개 미동작 |
| `lib/features/game/presentation/pages/game_history_page.dart:114` | 게임 기록 필터/정렬 버튼 |
| `lib/features/auth/presentation/pages/login_page.dart:219` | "비밀번호 찾기" 링크 |
| `lib/features/auth/presentation/pages/login_page.dart:407` | 소셜 로그인(Google/Kakao) 버튼 |

**조치 제안**: 단기 출시 범위에 없는 버튼은 UI에서 제거하거나, 유지할 경우 "준비 중" 안내 처리.

### 1.2 Silent Catch (에러를 조용히 삼킴)

| 위치 | 문제 |
| --- | --- |
| `lib/features/profile/presentation/pages/profile_page.dart:37` | `catch (_) {}` — 프로필 로드 실패 무시 |
| `lib/features/profile/presentation/pages/account_settings_page.dart:36` | `catch (_) {}` — 계정 설정 로드 실패 무시 |
| `lib/features/game/data/services/game_draft_repository.dart:21-25` | 드래프트 JSON 손상 시 조용히 초기화(알림 없음) |

**조치 제안**: 최소한 로깅 + 사용자 보이는 SnackBar/Dialog. 드래프트 손상 시에는 사용자가 알아야 복구 가능.

### 1.3 검색/필터 텍스트필드 미연결

- `lib/features/group/presentation/pages/club_members_page.dart` — 멤버 검색 TextField에 `onChanged`가 없어 입력이 결과에 반영되지 않음.

---

## 2. 보강이 필요한 기능 (UX / 안정성)

### 2.1 입력 검증 & 실시간 피드백

| 위치 | 부족한 부분 |
| --- | --- |
| `lib/features/auth/presentation/pages/signup_page.dart` | 비밀번호 강도 표시, 이메일 중복 확인 결과 UI 노출 |
| `lib/features/profile/presentation/pages/edit_phone_page.dart` | 전화번호 형식 검증, 인증 타이머 만료 후 재전송 유도 |
| `lib/features/game/presentation/pages/game_room_page.dart:148` | 방 코드 실시간 검증 (현재 onPressed에서만 확인) |
| `lib/features/auth/presentation/pages/login_page.dart` | 비밀번호 표시/숨김 토글이 아이콘만 있고 토글 동작 없음 |

### 2.2 로딩 / 에러 / 빈 상태

| 위치 | 부족한 부분 |
| --- | --- |
| `lib/features/home/presentation/pages/home_dashboard_page.dart` | 새로고침 버튼 부재(풀투리프레시만), 에러 시 재시도 UI |
| `lib/features/group/presentation/pages/my_groups_page.dart` | 로드 실패 시 재시도 버튼 없음, 그룹 0개일 때 Empty State 없음 |
| `lib/features/game/presentation/pages/frame_entry_page.dart` | 저장 중 로딩 인디케이터 / 저장 후 이동 경로 명확화 |
| `lib/features/game/presentation/pages/game_room_page.dart` | 참가자 0명 상태 문구 명확화 |

### 2.3 접근성 / 키보드

- `signup_page.dart`, `login_page.dart` — `TextInputAction.next/done` 미설정으로 필드 이동 어색함.
- 폰트 스케일/다크모드 색상 대비 점검 필요 (특히 `Colors.grey` 직접 사용 위치).

---

## 3. 아직 구현되지 않은 기능

### 3.1 명시적 TODO

| 위치 | 기능 |
| --- | --- |
| `lib/features/game/presentation/pages/frame_entry_page.dart:572` | **게임 저장 처리** — Save 버튼의 실제 저장 연결 (현재 TODO 표시) |
| `lib/features/group/presentation/pages/my_groups_page.dart:248` | **클럽 설정 페이지** — Settings 버튼의 이동 대상 페이지 |
| `lib/features/profile/presentation/pages/edit_phone_page.dart:61` | **인증번호 발송 API 연동** — 현재 500ms 더미 지연 |

### 3.2 UI는 있으나 로직 없음

- 비밀번호 찾기 플로우 (`login_page.dart:219`)
- 소셜 로그인(Google / Kakao) (`login_page.dart:407`)
- 알림 센터 (`home_dashboard_page.dart:192`)
- 게임 기록 필터/정렬 (`game_history_page.dart:114`)
- 리더보드 기간 필터 (`group_detail_page.dart:150`)
- 멤버 검색 실입력 반영 (`club_members_page.dart`)

### 3.3 데이터 / 백엔드 연동 의심

- 프로필/계정 로드 실패 시 빈 상태로 떨어지는 케이스 (`profile_page.dart`, `account_settings_page.dart`) — 서버 오류 구분 필요.
- 게임 드래프트 복구 UX — 손상 드래프트를 사용자에게 알리고 재사용/폐기 선택지 제공.

---

## 4. 우선순위 제안

### 🔴 High (출시 전 필수)
1. `frame_entry_page.dart:572` 게임 저장 TODO 해결 (또는 검증 후 TODO 제거)
2. Silent catch 3곳 → 최소한 로깅 + 사용자 알림
3. `my_groups_page.dart` 로드 실패 재시도 UI
4. 사용하지 않는 버튼 제거 or "준비 중" 처리

### 🟡 Medium
5. 비밀번호 찾기 / 소셜 로그인 결정 (구현 or UI 제거)
6. 입력 검증 실시간 피드백 (회원가입/전화번호)
7. 클럽 설정 페이지 (`my_groups_page.dart:248`)
8. 인증번호 실제 API 연결 (`edit_phone_page.dart:61`)

### 🟢 Low
9. 필터/정렬 버튼 구현
10. 알림 센터
11. 키보드 네비게이션(TextInputAction) 보완

---

> 이 문서는 정적 코드 분석 기반입니다. 백엔드/기획상 의도와 다른 항목이 있을 수 있으니 각 항목 결정 시 확인 필요.
