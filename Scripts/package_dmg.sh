#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DMG="${1:-$HOME/Downloads/Dango_Installer.dmg}"
ICON_SOURCE="$ROOT_DIR/Dango/Assets.xcassets/AppIcon.appiconset/AppIcon_1024.png"
INFO_PLIST_SRC="$ROOT_DIR/Dango/Info.plist"
SHORT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST_SRC")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST_SRC")"

# Assemble + sign in a temp dir OUTSIDE the (file-provider synced) project tree.
# Synced folders keep re-adding com.apple.FinderInfo / fpfs xattrs onto the app
# bundle, which makes `codesign --verify --strict` fail.
WORK_DIR="$(mktemp -d /tmp/dango_pkg.XXXXXX)"
trap 'rm -rf "$WORK_DIR"' EXIT

PACKAGE_DIR="$WORK_DIR/package"
DMG_SRC_DIR="$WORK_DIR/dmg_src"
APP_BUNDLE="$PACKAGE_DIR/Dango.app"
STAGED_APP="$DMG_SRC_DIR/Dango.app"
NORMALIZED_ICON_SOURCE="$WORK_DIR/AppIcon_1024.normalized.png"
ICONSET_DIR="$WORK_DIR/Dango.iconset"
ICNS_PATH="$WORK_DIR/Dango.icns"

cd "$ROOT_DIR"

swift build -c release
RELEASE_DIR="$(swift build -c release --show-bin-path)"

rm -f "$OUTPUT_DMG"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$DMG_SRC_DIR"

cp "$RELEASE_DIR/Dango" "$APP_BUNDLE/Contents/MacOS/Dango"
cp -R "$RELEASE_DIR/Dango_Dango.bundle" "$APP_BUNDLE/Contents/Resources/"
cp "$ROOT_DIR/Dango/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Generate a proper .icns from the app icon source (the source is JPEG data
# despite the .png extension, so normalize it to real PNG first).
mkdir -p "$ICONSET_DIR"
sips -s format png "$ICON_SOURCE" --out "$NORMALIZED_ICON_SOURCE" >/dev/null
sips -z 16 16   "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32   "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32   "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64   "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$NORMALIZED_ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$NORMALIZED_ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
cp "$ICNS_PATH" "$APP_BUNDLE/Contents/Resources/Dango.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Dango" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.mateusz.dango" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Dango" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile Dango" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string Dango" "$APP_BUNDLE/Contents/Info.plist"

chmod +x "$APP_BUNDLE/Contents/MacOS/Dango"
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

ditto --noextattr --noqtn "$APP_BUNDLE" "$STAGED_APP"
ln -s /Applications "$DMG_SRC_DIR/Applications"
cp -R "$ROOT_DIR/Packaging/DMG/.background" "$DMG_SRC_DIR/.background"
cp "$ROOT_DIR/Packaging/DMG/.DS_Store" "$DMG_SRC_DIR/.DS_Store"

xattr -cr "$DMG_SRC_DIR"
codesign --verify --deep --strict "$STAGED_APP"

hdiutil create -volname "Dango" -srcfolder "$DMG_SRC_DIR" -ov -format UDZO "$OUTPUT_DMG"
hdiutil verify "$OUTPUT_DMG"

echo "Created $OUTPUT_DMG"
