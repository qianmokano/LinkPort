#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Scope tool selection to this process; never change the user's xcode-select setting.
SELECTED_DEVELOPER="$(xcode-select -p)"
if [[ -z "${DEVELOPER_DIR:-}" && "$SELECTED_DEVELOPER" == */CommandLineTools && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
swift test --package-path "$PROJECT_ROOT" --build-system native --enable-code-coverage "$@"
