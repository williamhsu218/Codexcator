#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Codexcator"
LEGACY_APP_NAME="CodexIndicator"
SCHEME_NAME="CodexIndicator"
BUNDLE_ID="com.willhsu.CodexQuota"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

build_app() {
  xcodebuild \
    -project "$ROOT_DIR/CodexIndicator.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Debug \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    build
}

package_release() {
  local distribution_root="$ROOT_DIR/build/Distribution"
  local release_derived_data="$ROOT_DIR/build/ReleaseDerivedData"
  local built_app="$release_derived_data/Build/Products/Release/$APP_NAME.app"

  rm -rf "$release_derived_data"
  mkdir -p "$distribution_root"

  xcodebuild \
    -project "$ROOT_DIR/CodexIndicator.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$release_derived_data" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    clean build

  local version
  version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$built_app/Contents/Info.plist")"
  local staged_root="$distribution_root/$APP_NAME-$version"
  local staged_app="$staged_root/$APP_NAME.app"
  local zip_path="$distribution_root/$APP_NAME-$version-macos-universal.zip"

  rm -rf "$staged_root"
  rm -f "$zip_path"
  mkdir -p "$staged_root"
  ditto "$built_app" "$staged_app"
  xattr -cr "$staged_app"
  codesign --force --deep --sign - --timestamp=none "$staged_app"
  codesign --verify --deep --strict "$staged_app"
  ditto -c -k --norsrc --keepParent "$staged_app" "$zip_path"
  xattr -c "$zip_path"

  echo "ZIP_PATH=$zip_path"
  echo "SHA256=$(shasum -a 256 "$zip_path" | awk '{print $1}')"
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

build_preview() {
  local preview_root="$ROOT_DIR/build/DesignPreview"
  local preview_bundle="$preview_root/CodexcatorPreview.app"
  local preview_contents="$preview_bundle/Contents"
  local preview_macos="$preview_contents/MacOS"
  local preview_resources="$preview_contents/Resources"
  local preview_binary="$preview_macos/CodexcatorPreview"

  rm -rf "$preview_bundle"
  mkdir -p "$preview_macos" "$preview_resources"
  cp -R "$ROOT_DIR/Resources/en.lproj" "$preview_resources/"
  cp -R "$ROOT_DIR/Resources/zh-Hans.lproj" "$preview_resources/"
  cp "$ROOT_DIR/Design/AppIcon-master.png" "$preview_resources/"

  xcrun swiftc \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -o "$preview_binary" \
    "$ROOT_DIR"/Core/*.swift \
    "$ROOT_DIR"/App/Services/*.swift \
    "$ROOT_DIR"/App/Stores/*.swift \
    "$ROOT_DIR"/App/Support/*.swift \
    "$ROOT_DIR"/App/Views/*.swift \
    "$ROOT_DIR"/Preview/*.swift \
    -framework SwiftUI \
    -framework AppKit

  cat >"$preview_contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CodexcatorPreview</string>
  <key>CFBundleIdentifier</key>
  <string>com.willhsu.Codexcator.preview</string>
  <key>CFBundleName</key>
  <string>Codexcator Preview</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

  pkill -x CodexcatorPreview >/dev/null 2>&1 || true
  /usr/bin/open -n "$preview_bundle"
}

render_preview() {
  local qa_root="$ROOT_DIR/build/qa"
  local language="${1:-en}"
  local appearance="${2:-light}"
  local renderer_bundle="$qa_root/RenderDesignPreview.app"
  local renderer_contents="$renderer_bundle/Contents"
  local renderer_macos="$renderer_contents/MacOS"
  local renderer_resources="$renderer_contents/Resources"
  local renderer="$renderer_macos/RenderDesignPreview"
  local output="$qa_root/implementation-$language-$appearance.png"

  case "$language" in
    en|zh-Hans) ;;
    *)
      echo "language must be en or zh-Hans" >&2
      exit 2
      ;;
  esac

  case "$appearance" in
    light) ;;
    dark) ;;
    *)
      echo "appearance must be light or dark" >&2
      exit 2
      ;;
  esac

  rm -rf "$renderer_bundle"
  mkdir -p "$renderer_macos" "$renderer_resources"
  cp -R "$ROOT_DIR/Resources/en.lproj" "$renderer_resources/"
  cp -R "$ROOT_DIR/Resources/zh-Hans.lproj" "$renderer_resources/"
  cp "$ROOT_DIR/Design/AppIcon-master.png" "$renderer_resources/"
  xcrun swiftc \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -o "$renderer" \
    "$ROOT_DIR"/Core/*.swift \
    "$ROOT_DIR"/App/Services/*.swift \
    "$ROOT_DIR"/App/Stores/*.swift \
    "$ROOT_DIR"/App/Support/*.swift \
    "$ROOT_DIR"/App/Views/*.swift \
    "$ROOT_DIR"/Tools/RenderDesignPreview.swift \
    -framework SwiftUI \
    -framework AppKit

  cat >"$renderer_contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>RenderDesignPreview</string>
  <key>CFBundleIdentifier</key>
  <string>com.willhsu.Codexcator.renderer</string>
  <key>CFBundleName</key>
  <string>Codexcator Renderer</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleLocalizations</key>
  <array>
    <string>en</string>
    <string>zh-Hans</string>
  </array>
</dict>
</plist>
PLIST

  if [[ "$appearance" == "dark" ]]; then
    "$renderer" "$output" --dark -AppleLanguages "($language)"
  else
    "$renderer" "$output" -AppleLanguages "($language)"
  fi
  echo "$output"
}

render_settings() {
  local language="${1:-en}"
  local appearance="${2:-light}"
  local qa_root="$ROOT_DIR/build/qa"
  local renderer="$qa_root/RenderDesignPreview.app/Contents/MacOS/RenderDesignPreview"
  local output="$qa_root/settings-$language-$appearance.png"

  render_preview "$language" "$appearance" >/dev/null
  if [[ "$appearance" == "dark" ]]; then
    "$renderer" "$output" --settings --dark -AppleLanguages "($language)"
  else
    "$renderer" "$output" --settings -AppleLanguages "($language)"
  fi
  echo "$output"
}

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$LEGACY_APP_NAME" >/dev/null 2>&1 || true

case "$MODE" in
  run)
    build_app
    open_app
    ;;
  --debug|debug)
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    build_app
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --preview|preview)
    build_preview
    ;;
  --render-preview|render-preview)
    render_preview "${2:-en}" "${3:-light}"
    ;;
  --render-settings|render-settings)
    render_settings "${2:-en}" "${3:-light}"
    ;;
  --package-release|package-release)
    package_release
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--preview|--render-preview [en|zh-Hans] [light|dark]|--render-settings [en|zh-Hans] [light|dark]|--package-release]" >&2
    exit 2
    ;;
esac
