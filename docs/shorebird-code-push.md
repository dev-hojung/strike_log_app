# Shorebird 코드 푸시 (OTA 업데이트) 가이드

앱스토어/플레이스토어 **재심사 없이 Dart 코드 수정분을 즉시 배포**하기 위한 Shorebird 사용 안내입니다.

---

## 1. 무엇이 가능하고 무엇이 안 되나

| 패치(OTA)로 배포 가능 ✅ | 새 스토어 릴리스가 필요 ❌ |
|---|---|
| Dart 코드 / 비즈니스 로직 수정 | 네이티브 코드(Swift/Kotlin/Obj-C/Java) 변경 |
| UI(위젯) 변경 — 예: 바텀시트 개선 | 에셋 추가/변경(이미지·폰트·`.env`) |
| 순수 Dart 패키지 추가·수정 | 네이티브 포함 패키지(예: firebase, admob) 추가·버전업 |
| 생성 코드(`app_localizations` 등) | Flutter/Dart SDK 버전 변경, 앱 아이콘/스플래시 |

> 핵심: **"Dart만 고쳤으면 patch, 그 외는 release"**

---

## 2. 최초 1회 세팅

```bash
# 1) CLI 설치 (macOS) — 이미 설치돼 있으면 생략
curl --proto '=https' --tlsv1.2 \
  https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# 2) 로그인 (브라우저 인증) — 터미널에서 직접 실행
shorebird login

# 3) 프로젝트 초기화 → shorebird.yaml(app_id) 생성, pubspec 에 자동 등록
shorebird init
```

`shorebird init` 이 끝나면 프로젝트 루트에 `shorebird.yaml` 이 생기고,
`pubspec.yaml` 의 `flutter:` 섹션에 `shorebird.yaml` 이 에셋으로 추가됩니다.
**이 두 변경은 반드시 커밋**하세요. (`app_id` 는 비밀값 아님 — 커밋 OK)

PATH 가 안 잡히면 새 셸을 열거나:
```bash
export PATH="$HOME/.shorebird/bin:$PATH"
```

---

## 3. 평소 워크플로

### (A) 새 버전 출시 — 스토어 업로드용
`flutter build` **대신** Shorebird 로 빌드해야 이후 패치가 가능합니다.

```bash
scripts/shorebird_release.sh both      # android + ios
# 또는 개별:  scripts/shorebird_release.sh android
#            scripts/shorebird_release.sh ios
```
- 산출물: `build/app/outputs/bundle/release/app-release.aab`, `build/ios/ipa/*.ipa`
- 이걸 Play Console / Transporter 로 업로드.
- 출시 전 `pubspec.yaml` 의 `version`(예: `1.0.2+37`)을 올려두세요.

### (B) 출시 후 Dart 코드 수정 — OTA 패치
스토어에 올린 그 릴리스에 코드만 바꿔 즉시 배포:

```bash
scripts/shorebird_patch.sh both        # 가장 최근 release 에 패치
```
- 사용자는 **앱을 다시 실행하면** 다음 실행부터 패치된 코드로 동작합니다.
- 어떤 릴리스에 패치할지 CLI가 물어보면 대상 버전을 선택하세요.

---

## 4. 현황 확인

```bash
shorebird releases list        # 등록된 릴리스 목록
shorebird patches list         # 배포된 패치 목록
shorebird preview              # 릴리스/패치를 기기에서 미리보기
```
웹 대시보드: https://console.shorebird.dev

---

## 5. 이 프로젝트 주의사항

- **현재 스토어에 올라간 `1.0.2+37` 은 `flutter build` 로 만든 빌드라 패치 불가.**
  코드 푸시는 **다음 릴리스부터** (`shorebird release` 로 빌드한 버전부터) 적용됩니다.
- iOS 서명은 기존과 동일하게 `ios/ExportOptions.plist`(App Store Connect, team `G2AA4LX6TZ`)를
  사용하도록 스크립트에 반영돼 있습니다.
- Firebase/AdMob 등 네이티브 플러그인을 **건드리지 않는 한**, 일반적인 UI/로직 수정은
  모두 패치로 내보낼 수 있습니다.
- 정책: 양 스토어 가이드라인 준수. 단, 앱의 핵심 동작/용도를 크게 바꾸는 패치는 금지.
- 요금: Hobby 무료 티어로 시작, 이후 "패치 설치 수" 기준 과금(릴리스는 무료).
  https://shorebird.dev/pricing

---

## 6. 스크립트 요약

| 스크립트 | 용도 |
|---|---|
| `scripts/shorebird_release.sh [android\|ios\|both]` | 스토어용 정식 릴리스 빌드 |
| `scripts/shorebird_patch.sh [android\|ios\|both]` | 출시된 릴리스에 OTA 패치 배포 |
