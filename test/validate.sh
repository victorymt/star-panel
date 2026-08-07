#!/usr/bin/env bash
# validate.sh — non-destructive pre-commit validation for star-panel
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT_DIR"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: required command not found: $1" >&2
        exit 1
    fi
}

require_file() {
    if [ ! -f "$1" ]; then
        echo "ERROR: required project file is missing: $1" >&2
        exit 1
    fi
}

echo "== project files =="
require_file shell.qml
for source_file in src/*.qml src/*.js src/*.sh; do
    require_file "$source_file"
done
if [ ! -x src/clipboard-image.sh ] || [ ! -x src/starcatch-pipe.sh ]; then
    echo "ERROR: helper scripts must be executable" >&2
    exit 1
fi
echo "OK: source tree is complete"

echo "== QML lint =="
require_command qmllint
qmllint shell.qml src/*.qml
echo "OK: QML lint passed"

echo "== JavaScript tests =="
require_command node
node test/parsers.test.js
node test/starcatch_commands.test.js
node test/command_router.test.js
echo "OK: JavaScript tests passed"

echo "== clipboard helper =="
bash test/clipboard_image_test.sh
echo "OK: clipboard helper passed"

echo "== diff check =="
require_command git
git diff --check
echo "OK: diff check passed"

echo "Validation passed (no Quickshell process was stopped or restarted)."
