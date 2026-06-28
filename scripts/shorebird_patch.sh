#!/usr/bin/env bash
#
# Shorebird OTA 패치 배포 스크립트
# --------------------------------
# 이미 `shorebird release`로 스토어에 올린 릴리스에, Dart 코드 수정분을
# 앱스토어 재심사 없이 즉시 배포합니다.
#
# ⚠️ 패치 가능: Dart 코드/로직/UI/순수 Dart 패키지
#    패치 불가: 네이티브 코드, 에셋(이미지·폰트), 의존성/Flutter 버전 변경
#               → 이 경우 scripts/shorebird_release.sh 로 새 릴리스가 필요합니다.
#
# 사용법:
#   scripts/shorebird_patch.sh android     # 가장 최근 Android 릴리스에 패치
#   scripts/shorebird_patch.sh ios
#   scripts/shorebird_patch.sh both        # 둘 다 (기본값)
#
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${1:-both}"
EXPORT_OPTS="ios/ExportOptions.plist"

if ! command -v shorebird >/dev/null 2>&1; then
  echo "❌ shorebird CLI가 없습니다. README_SHOREBIRD.md 의 설치 안내를 참고하세요."
  exit 1
fi

patch_android() {
  echo "▶︎ Android 패치 배포 (shorebird patch android)…"
  shorebird patch android
  echo "✅ Android 패치 배포 완료"
}

patch_ios() {
  echo "▶︎ iOS 패치 배포 (shorebird patch ios)…"
  shorebird patch ios -- --export-options-plist="$EXPORT_OPTS"
  echo "✅ iOS 패치 배포 완료"
}

case "$PLATFORM" in
  android) patch_android ;;
  ios)     patch_ios ;;
  both)    patch_android; patch_ios ;;
  *) echo "사용법: $0 [android|ios|both]"; exit 1 ;;
esac

echo ""
echo "패치는 사용자가 앱을 재실행하면 적용됩니다(다음 실행부터 새 코드)."
echo "배포 현황 확인: shorebird patches list  /  대시보드: https://console.shorebird.dev"
