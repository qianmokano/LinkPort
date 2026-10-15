#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/LinkPort.app"
STAGING_PATH="$PROJECT_ROOT/.build/LinkPort-staging.app"
BINARIES=()

for ARCH in arm64 x86_64; do
    swift build --package-path "$PROJECT_ROOT" --build-system native \
        --configuration release --triple "$ARCH-apple-macosx26.0" \
        --scratch-path "$PROJECT_ROOT/.build/$ARCH" --product LinkPort
    BIN_DIR="$(swift build --package-path "$PROJECT_ROOT" --build-system native \
        --configuration release --triple "$ARCH-apple-macosx26.0" \
        --scratch-path "$PROJECT_ROOT/.build/$ARCH" --show-bin-path)"
    BINARIES+=("$BIN_DIR/LinkPort")
done

# Assemble in staging so a failed build never damages an existing app.
rm -rf "$STAGING_PATH"
mkdir -p "$STAGING_PATH/Contents/MacOS" "$STAGING_PATH/Contents/Resources"
lipo -create "${BINARIES[@]}" -output "$STAGING_PATH/Contents/MacOS/LinkPort"
cp "$PROJECT_ROOT/Configuration/Info.plist" "$STAGING_PATH/Contents/Info.plist"
cp -R "$PROJECT_ROOT/Sources/LinkPort/Resources/en.lproj" "$STAGING_PATH/Contents/Resources/"
cp -R "$PROJECT_ROOT/Sources/LinkPort/Resources/zh-Hans.lproj" "$STAGING_PATH/Contents/Resources/"
swift "$PROJECT_ROOT/scripts/make-icon.swift" "$PROJECT_ROOT/.build/LinkPort.iconset"
iconutil --convert icns "$PROJECT_ROOT/.build/LinkPort.iconset" --output "$STAGING_PATH/Contents/Resources/LinkPort.icns"
plutil -lint "$STAGING_PATH/Contents/Info.plist"
codesign --force --sign - "$STAGING_PATH"
codesign --verify --strict "$STAGING_PATH"
for ARCH in arm64 x86_64; do
    lipo "$STAGING_PATH/Contents/MacOS/LinkPort" -verify_arch "$ARCH"
done
mkdir -p "$PROJECT_ROOT/dist"
if [[ -e "$APP_PATH" ]]; then
    rm -rf "$PROJECT_ROOT/.build/LinkPort-previous.app"
    mv "$APP_PATH" "$PROJECT_ROOT/.build/LinkPort-previous.app"
fi
mv "$STAGING_PATH" "$APP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$PROJECT_ROOT/.build/LinkPort.zip"
mv -f "$PROJECT_ROOT/.build/LinkPort.zip" "$PROJECT_ROOT/dist/LinkPort.zip"
printf 'Built: %s\n' "$APP_PATH"
