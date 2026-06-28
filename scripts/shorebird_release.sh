#!/usr/bin/env bash
#
# Shorebird 정식 릴리스 빌드 스크립트
# ---------------------------------
# `flutter build` 대신 이걸로 빌드해야 이후 OTA 패치(shorebird patch)가 가능합니다.
# pubspec.yaml 의 version(1.0.2+37 형태)이 릴리스 버전으로 사용됩니다.
#
# 사용법:
#   scripts/shorebird_release.sh android      # Play 스토어용 .aab
#   scripts/shorebird_release.sh ios          # App Store용 .ipa
#   scripts/shorebird_release.sh both         # 둘 다 (기본값)
#
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${1:-both}"
EXPORT_OPTS="ios/ExportOptions.plist"

if ! command -v shorebird >/dev/null 2>&1; then
  echo "❌ shorebird CLI가 없습니다. 먼저 설치/로그인하세요:"
  echo "   curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash"
  echo "   shorebird login && shorebird init"
  exit 1
fi

release_android() {
  echo "▶︎ Android 릴리스 빌드 (shorebird release android)…"
  shorebird release android
  echo "✅ Android 릴리스 완료 (build/app/outputs/bundle/release/app-release.aab)"
}

release_ios() {
  echo "▶︎ iOS 릴리스 빌드 (shorebird release ios)…"
  # 기존 flutter 빌드와 동일하게 ExportOptions.plist 로 App Store 서명/내보내기.
  shorebird release ios -- --export-options-plist="$EXPORT_OPTS"
  echo "✅ iOS 릴리스 완료 (build/ios/ipa/*.ipa)"
}

case "$PLATFORM" in
  android) release_android ;;
  ios)     release_ios ;;
  both)    release_android; release_ios ;;
  *) echo "사용법: $0 [android|ios|both]"; exit 1 ;;
esac

echo ""
echo "다음 단계: 스토어에 업로드한 뒤, 이후 Dart 코드 수정은"
echo "  scripts/shorebird_patch.sh $PLATFORM 으로 OTA 배포하세요."
