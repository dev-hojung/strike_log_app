# 설계 — 클럽 권한 3단계 분리 (클럽장 · 운영진 · 일반멤버)

> 작성일: 2026-06-30 / 대상: `strike_log_api` + `strike_log_app`
> 목적: 현재 2단계(ADMIN/MEMBER) 권한을 **클럽장(OWNER) → 운영진(STAFF) → 일반멤버(MEMBER)** 3단계로 분리.

---

## 1. 현재 상태 진단 (코드 확인)

- `GroupRole = { ADMIN, MEMBER }` (`group-member.entity.ts`)
- `promoteToAdmin`은 대상을 ADMIN으로 올리되 **위임자를 강등하지 않음** → 한 클럽에 ADMIN 여러 명 가능
- 그러나 모든 권한 검사가 `findOne({ group_id, role: ADMIN })` (첫 ADMIN 1명)로 비교
  → **멀티 ADMIN 시 일부 운영자가 403 나는 기존 부채** 존재
- `group` 엔티티에 명시적 owner/created_by 컬럼 **없음** (OWNER ≡ ADMIN 멤버)
- 영향 지점(백엔드 13곳): `groups.service.ts`(승격/탈퇴/추방/가입승인/공지/리더보드 admin 판정), `club-events.service.ts`, `trial-reminder.service.ts`

---

## 2. 목표 모델

```
enum GroupRole { OWNER, STAFF, MEMBER }   // ADMIN → OWNER 로 대체 + STAFF 신설
```

| 역할 | 한국어 | 인원 | 정의 |
|---|---|---|---|
| `OWNER` | 클럽장 | **클럽당 정확히 1명** | 클럽 소유자(생성자/이양받은 자) |
| `STAFF` | 운영진 | 다수 가능 | 클럽장이 임명한 운영 보조 |
| `MEMBER` | 일반멤버 | 다수 | 기본 가입자 |

**불변식**: 모든 클럽은 항상 OWNER 정확히 1명을 가진다. (생성 시 생성자=OWNER, 탈퇴 시 이양 강제)

---

## 3. 권한 매트릭스 (제안 — 검토 요청)

| 액션 | 클럽장 | 운영진 | 일반멤버 |
|---|:--:|:--:|:--:|
| 클럽 조회/랭킹/통계 보기 | ✅ | ✅ | ✅ |
| 정기전 **참가/플레이** | ✅ | ✅ | ✅ |
| 가입 신청 승인/거절 | ✅ | ✅ | ❌ |
| 공지 작성/수정/삭제 | ✅ | ✅ | ❌ |
| 정기전 생성/배치/완료 | ✅ | ✅ | ❌ |
| 클럽 정보(소개·지역·볼링장·모집) 수정 | ✅ | ✅ | ❌ |
| **일반멤버 추방** | ✅ | ✅ | ❌ |
| **운영진 추방** | ✅ | ❌ | ❌ |
| **운영진 임명/해제** | ✅ | ❌ | ❌ |
| **클럽장 이양** | ✅ | ❌ | ❌ |
| **클럽 삭제** | ✅ | ❌ | ❌ |

> 핵심 경계: **운영진 = "운영 업무(가입·공지·정기전·일반멤버 관리)"**, **클럽장 = "인사·소유권(운영진/소유권/삭제)"**.
> 운영진은 동급/상위(운영진·클럽장)를 건드릴 수 없다.

---

## 4. 데이터 마이그레이션

enum 변경 + 기존 데이터 변환이 필요(운영 DB 자동 적용 → **백업 완료됨**).

```sql
-- 1) enum 값 확장: ADMIN/MEMBER → OWNER/STAFF/MEMBER
ALTER TABLE group_members MODIFY role ENUM('OWNER','STAFF','MEMBER') ...;  -- 단계적
-- 2) 기존 ADMIN → 변환:
--    클럽별 가장 먼저 가입한(joined_at ASC) ADMIN 1명 → OWNER
--    그 외 ADMIN(있다면) → STAFF
--    MEMBER → 그대로
```

**변환 규칙(멀티 ADMIN 정리)**: 클럽당 `joined_at` 최솟값 ADMIN을 OWNER로, 나머지 ADMIN은 STAFF로 강등. 이로써 "OWNER 정확히 1명" 불변식 확보.

- 마이그레이션 파일: `1801000000000-SplitGroupRoles.ts` (up: enum 확장 + 데이터 변환 / down: STAFF·OWNER → ADMIN 역변환)
- down 안전성: OWNER·STAFF 모두 ADMIN으로 되돌림(원복 가능)

---

## 5. 백엔드 변경 설계

### 권한 헬퍼 재설계 (`groups.service.ts` + 공용화)
```ts
// 역할 위계: OWNER(3) > STAFF(2) > MEMBER(1)
private async getMembership(groupId, userId): GroupMember | null
private async assertOwner(groupId, userId)          // 클럽장만
private async assertStaffOrAbove(groupId, userId)   // 운영진+클럽장
```
- `isPlatformAdmin(userId)`는 모든 검사 통과(기존 유지)
- **기존 `assertAdmin`(첫-ADMIN findOne 패턴) 전면 교체** → "호출자 본인의 membership.role" 기준 판정 (멀티 운영자 부채 동시 해소)

### 메서드 변경
| 기존 | 변경 |
|---|---|
| `assertAdmin` (announcements/events 등) | 액션 성격에 따라 `assertStaffOrAbove` 또는 `assertOwner` |
| `promoteToAdmin` | `appointStaff`(운영진 임명, OWNER만) |
| (신규) | `revokeStaff`(운영진 해제, OWNER만) |
| (신규) | `transferOwnership`(클럽장 이양, OWNER만 — 대상 STAFF/MEMBER → OWNER, 본인 → STAFF) |
| `kickMember` | 운영진+클럽장 호출 가능, 단 **대상이 동급/상위면 거부** |
| `leaveGroup` | OWNER 탈퇴 시 **이양 강제**(기존 "마지막 운영자" 로직을 OWNER 기준으로) |
| `getAdminUserId` | `getOwnerUserId` (알림 수신자 = 클럽장; 운영진에도 보낼지는 별도 결정) |

### 라우트 (`groups.controller.ts`)
```
POST   /groups/:id/members/:userId/staff           운영진 임명 (OWNER)
DELETE /groups/:id/members/:userId/staff           운영진 해제 (OWNER)
POST   /groups/:id/transfer-ownership              클럽장 이양 (OWNER) { targetUserId }
(기존) POST /promote 는 deprecated → appointStaff 로 대체/리다이렉트
정기전·공지 라우트: 서비스 내 권한만 ADMIN→StaffOrAbove 로 교체(라우트 시그니처 불변)
```

---

## 6. 프론트엔드 변경

- **역할 뱃지**: 클럽장(금색)/운영진(파랑)/일반(무색) — `club_members_page`, `my_groups_page`
- **멤버 관리 UX**(`club_members_page` PopupMenu):
  - 클럽장 시점: 멤버 → "운영진 임명", 운영진 → "운영진 해제", 누구나 → "추방"(상위 제외), "클럽장 이양"
  - 운영진 시점: 일반멤버 → "추방"만, 운영진/클럽장 액션 숨김
- **액션 가시성**: 정기전 생성/공지 작성 버튼을 `role >= STAFF`일 때 노출(기존 ADMIN 체크 → staffOrAbove)
- 역할 모델: 앱에 `GroupRole` 매핑 추가(현재 ADMIN/MEMBER 가정 코드 점검)

---

## 7. 작업 순서 & 리스크

1. 백엔드: enum + 마이그레이션(데이터 변환) → 권한 헬퍼 재설계 → 13개 사용처 교체 → 임명/해제/이양 라우트 → 빌드
2. 검증: 마이그레이션 up/down, 멀티 ADMIN 클럽 변환 결과, 권한별 403 동작
3. 앱: 역할 모델·뱃지·멤버관리 UX·액션 가시성
4. README 갱신(정책 요약 3단계로)

**리스크**
- enum 변경은 파괴적 → **DB 백업 필수(완료)**, down 마이그레이션 검증
- 기존 멀티 ADMIN 클럽의 OWNER 선정 규칙(가장 먼저 가입) 합의 필요
- `assertAdmin` 전면 교체 = 광범위 → 회귀 위험, 권한별 테스트 필요

---

## 8. 확정된 결정 (2026-06-30)
1. **권한 매트릭스(§3) 확정** — 운영진 = 운영 전반(가입승인·공지·정기전 생성/배치/완료·클럽정보 수정·일반멤버 추방). 인사(운영진 임명/해제·이양)·삭제는 클럽장 전용.
2. **가입 신청 알림 = 클럽장 + 운영진 모두 수신** — `getOwnerUserId` 대신 "가입승인 권한자(OWNER+STAFF) 전원"에게 발송하도록 알림 수신자 로직 변경.
3. **OWNER 선정 규칙** = 클럽당 **가장 먼저 가입한(joined_at ASC) ADMIN** 1명 → OWNER, 나머지 ADMIN → STAFF.
4. **기존 `promote` 엔드포인트 = "운영진 임명"으로 의미 변경** (앱 호환 유지). 별도 해제/이양 라우트 신설.
