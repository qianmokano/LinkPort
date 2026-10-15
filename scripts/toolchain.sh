#!/bin/bash
# Sourced by the build, test, and check entry points.
# Keep tool selection local to this process.
SELECTED_DEVELOPER="$(xcode-select -p)"
if [[ -z "${DEVELOPER_DIR:-}" && "$SELECTED_DEVELOPER" == */CommandLineTools && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! TOOLCHAIN_VERSION="$(xcrun xcodebuild -version 2>/dev/null)"; then
    printf 'LinkPort requires full Xcode 27 or newer. Set DEVELOPER_DIR to its Developer directory.\n' >&2
    exit 1
fi
XCODE_VERSION="$(printf '%s\n' "$TOOLCHAIN_VERSION" | awk '/^Xcode / { print $2; exit }')"
if [[ -z "$XCODE_VERSION" ]] || (( ${XCODE_VERSION%%.*} < 27 )); then
    printf 'LinkPort requires Xcode 27 or newer (selected: %s).\n' "${XCODE_VERSION:-unknown}" >&2
    exit 1
fi
