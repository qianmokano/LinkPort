#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/LinkPort.app"
STAGING_PATH="$PROJECT_ROOT/.build/LinkPort-staging.app"
BINARIES=()

# Asset compilation needs Xcode; select it only for this process, like test.sh.
SELECTED_DEVELOPER="$(xcode-select -p)"
if [[ -z "${DEVELOPER_DIR:-}" && "$SELECTED_DEVELOPER" == */CommandLineTools && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcrun --find actool >/dev/null 2>&1; then
    printf 'Building the Liquid Glass icon requires Xcode 27 or newer. Set DEVELOPER_DIR to its Developer directory.\n' >&2
    exit 1
fi

BUILD_SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
if (( ${BUILD_SDK_VERSION%%.*} < 27 )); then
    printf 'LinkPort requires the macOS 27 SDK. Select newer developer tools with DEVELOPER_DIR.\n' >&2
    exit 1
fi

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
if [[ -e "$STAGING_PATH" ]]; then rm -r "$STAGING_PATH"; fi
mkdir -p "$STAGING_PATH/Contents/MacOS" "$STAGING_PATH/Contents/Resources"
lipo -create "${BINARIES[@]}" -output "$STAGING_PATH/Contents/MacOS/LinkPort"
cp "$PROJECT_ROOT/Configuration/Info.plist" "$STAGING_PATH/Contents/Info.plist"
cp -R "$PROJECT_ROOT/Sources/LinkPort/Resources/en.lproj" "$STAGING_PATH/Contents/Resources/"
cp -R "$PROJECT_ROOT/Sources/LinkPort/Resources/zh-Hans.lproj" "$STAGING_PATH/Contents/Resources/"
xcrun actool "$PROJECT_ROOT/Configuration/LinkPort.icon" \
    --compile "$STAGING_PATH/Contents/Resources" \
    --platform macosx --target-device mac --minimum-deployment-target 26.0 \
    --app-icon LinkPort --output-format human-readable-text --notices --warnings \
    --output-partial-info-plist "$PROJECT_ROOT/.build/LinkPort-icon-info.plist"
plutil -lint "$STAGING_PATH/Contents/Info.plist"
codesign --force --sign - "$STAGING_PATH"
codesign --verify --strict "$STAGING_PATH"
for ARCH in arm64 x86_64; do
    lipo "$STAGING_PATH/Contents/MacOS/LinkPort" -verify_arch "$ARCH"
done
mkdir -p "$PROJECT_ROOT/dist"
if [[ -e "$APP_PATH" ]]; then
    if [[ -e "$PROJECT_ROOT/.build/LinkPort-previous.app" ]]; then
        rm -r "$PROJECT_ROOT/.build/LinkPort-previous.app"
    fi
    mv "$APP_PATH" "$PROJECT_ROOT/.build/LinkPort-previous.app"
fi
mv "$STAGING_PATH" "$APP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$PROJECT_ROOT/.build/LinkPort.zip"
mv -f "$PROJECT_ROOT/.build/LinkPort.zip" "$PROJECT_ROOT/dist/LinkPort.zip"
if [[ -e "$PROJECT_ROOT/.build/LinkPort-previous.app" ]]; then
    rm -r "$PROJECT_ROOT/.build/LinkPort-previous.app"
fi
printf 'Built: %s\n' "$APP_PATH"
