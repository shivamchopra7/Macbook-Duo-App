#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
BUILD_DIR="${MACBOOKDUO_BUILD_DIR:-.build}"
BUILD_ARCH="${MACBOOKDUO_ARCH:-arm64}"
case "$BUILD_ARCH" in
  arm64) DEFAULT_OUTPUT_DIR="build" ;;
  x86_64) DEFAULT_OUTPUT_DIR="build-intel" ;;
  *) printf 'Unsupported build architecture: %s\n' "$BUILD_ARCH" >&2; exit 2 ;;
esac
OUTPUT_DIR="${MACBOOKDUO_OUTPUT_DIR:-$DEFAULT_OUTPUT_DIR}"
swift build -c release --scratch-path "$BUILD_DIR" --arch "$BUILD_ARCH"
BIN_DIR="$(swift build -c release --scratch-path "$BUILD_DIR" --arch "$BUILD_ARCH" --show-bin-path)"
SIGNING_IDENTITY="${MACBOOKDUO_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  if [[ -f signing-identity.txt ]]; then
    SIGNING_IDENTITY="$(cat signing-identity.txt)"
  else
    SIGNING_IDENTITY="-"
  fi
fi
mkdir -p "$OUTPUT_DIR"
APP="$(cd "$OUTPUT_DIR" && pwd)/Macbook Duo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/MacbookDuo" "$APP/Contents/MacOS/MacbookDuo"
# Remove debug symbols containing local build paths before signing the app.
xcrun strip -S "$APP/Contents/MacOS/MacbookDuo"
# L10n loads this resource bundle from the packaged app Resources directory.
# Ship translations inside the app so it remains relocatable.
ditto --norsrc --noextattr "$BIN_DIR/MacbookDuo_MacbookDuo.bundle" "$APP/Contents/Resources/MacbookDuo_MacbookDuo.bundle"
for localization in Sources/MacbookDuo/Resources/*.lproj; do
  locale="$(basename "$localization")"
  mkdir -p "$APP/Contents/Resources/$locale"
  cp "$localization/InfoPlist.strings" "$APP/Contents/Resources/$locale/InfoPlist.strings"
done
cp Resources/MacbookDuoMark.png Resources/MacbookDuo.icns "$APP/Contents/Resources/"
cp ATTRIBUTION.md "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>zh-Hant</string><string>ja</string></array>
<key>CFBundleName</key><string>Macbook Duo</string>
<key>CFBundleDisplayName</key><string>Macbook Duo</string>
<key>CFBundleIdentifier</key><string>com.shivamchopra.macbookduo</string>
<key>CFBundleExecutable</key><string>MacbookDuo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>MacbookDuo</string>
<key>CFBundleShortVersionString</key><string>1.0.1</string>
<key>CFBundleVersion</key><string>101</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Displays a temporary, animated copy of your desktop as you move the lid. Frames stay in memory on this Mac.</string>
</dict></plist>
PLIST
codesign --force --sign "$SIGNING_IDENTITY" --identifier com.shivamchopra.macbookduo "$APP"
codesign --verify --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
printf 'Built %s\n' "$APP"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  printf 'Ad-hoc development build. Use a consistent Apple Development identity to preserve Screen Recording access across updates.\n'
fi
