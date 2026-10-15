#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$PROJECT_ROOT/scripts/toolchain.sh"
swift test --package-path "$PROJECT_ROOT" --build-system native --enable-code-coverage "$@"
