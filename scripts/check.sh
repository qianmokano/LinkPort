#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$PROJECT_ROOT/.build/reports"
mkdir -p "$REPORT_DIR"
rm -f "$REPORT_DIR/checks.log" "$REPORT_DIR/tests.xml" "$REPORT_DIR/tests-swift-testing.xml" "$REPORT_DIR/coverage.json"
exec > >(tee "$REPORT_DIR/checks.log") 2>&1
source "$PROJECT_ROOT/scripts/toolchain.sh"
export PYTHONDONTWRITEBYTECODE=1

printf 'Checking with Xcode %s\n' "$XCODE_VERSION"
python3 -m unittest discover -s "$PROJECT_ROOT/scripts/tests" -v
python3 "$PROJECT_ROOT/scripts/verify.py" source --root "$PROJECT_ROOT"
"$PROJECT_ROOT/scripts/test.sh" --xunit-output "$REPORT_DIR/tests.xml"
if [[ ! -s "$REPORT_DIR/tests-swift-testing.xml" && ! -s "$REPORT_DIR/tests.xml" ]]; then
    printf 'Swift Testing did not produce an XML test report.\n' >&2
    exit 1
fi
COVERAGE_PATH="$(swift test --package-path "$PROJECT_ROOT" --build-system native --enable-code-coverage --show-codecov-path)"
python3 "$PROJECT_ROOT/scripts/verify.py" coverage --root "$PROJECT_ROOT" \
    --coverage "$COVERAGE_PATH" --report "$REPORT_DIR/coverage.json"
"$PROJECT_ROOT/scripts/build-app.sh"
python3 "$PROJECT_ROOT/scripts/verify.py" bundle --root "$PROJECT_ROOT"
(cd "$PROJECT_ROOT/dist" && shasum -a 256 -c SHA256SUMS)
printf 'All checks passed. Reports: .build/reports/\n'
