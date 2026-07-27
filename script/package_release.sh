#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FolderHub"
BUNDLE_ID="com.folderhub.app"
MIN_SYSTEM_VERSION="26.0"
VERSION="${1:-0.1.1}"
BUILD_NUMBER="${BUILD_NUMBER:-2}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
WORK_DIR="/private/tmp/com.folderhub.release"
STAGE_DIR="$WORK_DIR/stage"
DMG_ROOT="$WORK_DIR/dmg-root"
VERIFY_DIR="$WORK_DIR/verify"
APP_BUNDLE="$STAGE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ZIP_NAME="$APP_NAME-v$VERSION-macos26-universal.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
DMG_NAME="$APP_NAME-v$VERSION-macos26-universal.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]]; then
  echo "invalid version: $VERSION" >&2
  exit 2
fi
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "invalid build number: $BUILD_NUMBER" >&2
  exit 2
fi

cd "$ROOT_DIR"
rm -rf "$WORK_DIR"
rm -f "$ZIP_PATH" "$DMG_PATH" "$RELEASE_DIR/SHA256SUMS"
mkdir -p "$APP_MACOS" "$DMG_ROOT" "$VERIFY_DIR" "$RELEASE_DIR"

swift build -c release --arch arm64 \
  --build-path "$WORK_DIR/build-arm64"
swift build -c release --arch x86_64 \
  --build-path "$WORK_DIR/build-x86_64"

ARM_BINARY="$(swift build -c release --arch arm64 --build-path "$WORK_DIR/build-arm64" --show-bin-path)/$APP_NAME"
X86_BINARY="$(swift build -c release --arch x86_64 --build-path "$WORK_DIR/build-x86_64" --show-bin-path)/$APP_NAME"
/usr/bin/lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Folder Hub</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/xattr -cr "$APP_BUNDLE"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  /usr/bin/codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp=none \
    --sign - \
    "$APP_BUNDLE"
else
  /usr/bin/codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$APP_BUNDLE"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/bin/lipo -archs "$APP_BINARY" | /usr/bin/grep -q "arm64"
/usr/bin/lipo -archs "$APP_BINARY" | /usr/bin/grep -q "x86_64"
/usr/bin/plutil -extract CFBundleShortVersionString raw "$INFO_PLIST" \
  | /usr/bin/grep -qx "$VERSION"
/usr/bin/plutil -extract LSUIElement raw "$INFO_PLIST" \
  | /usr/bin/grep -qx "false"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
/usr/bin/ditto --noextattr --noqtn "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
/bin/ln -s /Applications "$DMG_ROOT/Applications"
/usr/bin/hdiutil create \
  -volname "Folder Hub" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
/usr/bin/hdiutil verify "$DMG_PATH"

/usr/bin/ditto -x -k "$ZIP_PATH" "$VERIFY_DIR"
VERIFY_APP="$VERIFY_DIR/$APP_NAME.app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$VERIFY_APP"
/usr/bin/lipo -archs "$VERIFY_APP/Contents/MacOS/$APP_NAME" \
  | /usr/bin/grep -q "arm64"
/usr/bin/lipo -archs "$VERIFY_APP/Contents/MacOS/$APP_NAME" \
  | /usr/bin/grep -q "x86_64"
/usr/bin/plutil -extract CFBundleShortVersionString raw \
  "$VERIFY_APP/Contents/Info.plist" \
  | /usr/bin/grep -qx "$VERSION"

(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 "$ZIP_NAME" "$DMG_NAME" > SHA256SUMS
)

echo "$ZIP_PATH"
echo "$DMG_PATH"
echo "$RELEASE_DIR/SHA256SUMS"
