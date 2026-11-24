#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Sentinel"
VERSION="${SENTINEL_VERSION:-1.1.0}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
ARCH="${SENTINEL_ARCH:-arm64}"
SDK_PATH="${SENTINEL_SDK:-$(xcrun --sdk macosx --show-sdk-path)}"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_PATH/Contents"
ICON_WORK_DIR="$DIST_DIR/icon-work"
STAGING_DIR="$DIST_DIR/dmg-staging"

rm -rf "$APP_PATH" "$ICON_WORK_DIR" "$STAGING_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
mkdir -p "$ICON_WORK_DIR" "$STAGING_DIR"

echo "SDK: $SDK_PATH"
echo "Architecture: $ARCH"

BUILD_FLAGS=(--arch "$ARCH" --sdk "$SDK_PATH")
if [[ "${SENTINEL_DISABLE_SANDBOX:-0}" == "1" ]]; then
    BUILD_FLAGS+=(--disable-sandbox)
fi

swift build \
    -c release \
    "${BUILD_FLAGS[@]}" \
    -debug-info-format none \
    --product "$APP_NAME"
BIN_DIR="$(swift build -c release "${BUILD_FLAGS[@]}" -debug-info-format none --show-bin-path)"
EXECUTABLE="$BIN_DIR/$APP_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
    echo "未找到构建产物：$EXECUTABLE" >&2
    exit 1
fi

install -m 755 "$EXECUTABLE" "$CONTENTS_DIR/MacOS/$APP_NAME"
install -m 644 "$ROOT_DIR/Sentinel/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
install -m 644 "$ROOT_DIR/Sentinel/Resources/MicropueAvatar.png" "$CONTENTS_DIR/Resources/MicropueAvatar.png"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS_DIR/Info.plist"

python3 "$ROOT_DIR/Scripts/generate_icon.py" "$ICON_WORK_DIR/sentinel-1024.png"

ICONSET_DIR="$ICON_WORK_DIR/Sentinel.iconset"
mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_WORK_DIR/sentinel-1024.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_WORK_DIR/sentinel-1024.png" "$ICONSET_DIR/icon_512x512@2x.png"

python3 "$ROOT_DIR/Scripts/generate_icns.py" \
    "$ICONSET_DIR" \
    "$CONTENTS_DIR/Resources/Sentinel.icns"

xattr -cr "$APP_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"

ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-macos-$ARCH.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION-macos-$ARCH.dmg"

rm -f "$ZIP_PATH" "$DMG_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

if [[ "${SENTINEL_SKIP_DMG:-0}" == "1" ]]; then
    rm -rf "$ICON_WORK_DIR" "$STAGING_DIR"
    echo "ZIP: $ZIP_PATH"
    exit 0
fi

cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$ICON_WORK_DIR" "$STAGING_DIR"

echo "ZIP: $ZIP_PATH"
echo "DMG: $DMG_PATH"
