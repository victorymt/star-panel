#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR=$(cd "$(dirname "$0")/.." && pwd)
HELPER="$PROJECT_DIR/src/clipboard-image.sh"
TEST_ROOT=$(mktemp -d)
FAKE_BIN="$TEST_ROOT/bin"
STAGING_DIR="$TEST_ROOT/cache with spaces"

cleanup() {
    rm -rf -- "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

mkdir -p -- "$FAKE_BIN"

cat > "$FAKE_BIN/wl-paste" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "--list-types" ]; then
    printf '%s\n' "${FAKE_CLIPBOARD_TYPES:-text/plain}"
    exit 0
fi
if [ "${1:-}" = "--no-newline" ] && [ "${2:-}" = "--type" ]; then
    [ "${3:-}" = "${FAKE_EXPECTED_MIME:-image/png}" ] || exit 9
    printf '%s' "${FAKE_IMAGE_BYTES:-fake-image-bytes}"
    exit 0
fi
exit 8
EOF
chmod +x "$FAKE_BIN/wl-paste"

captured=$(PATH="$FAKE_BIN:$PATH" \
    FAKE_CLIPBOARD_TYPES=$'text/plain\nimage/png\nimage/jpeg' \
    FAKE_EXPECTED_MIME=image/png \
    FAKE_IMAGE_BYTES=png-payload \
    "$HELPER" capture "$STAGING_DIR")

[ -f "$captured" ] || fail "capture did not create a file"
[ "$(cat "$captured")" = "png-payload" ] || fail "capture changed image bytes"
case "$captured" in
    "$STAGING_DIR"/paste-*.png) ;;
    *) fail "capture returned an unexpected path: $captured" ;;
esac

unowned="$STAGING_DIR/not-owned.png"
printf 'keep' > "$unowned"
"$HELPER" cleanup "$STAGING_DIR" "$captured" "$unowned"
[ ! -e "$captured" ] || fail "cleanup did not remove the staged image"
[ -e "$unowned" ] || fail "cleanup removed a non-staged file"

old_staged="$STAGING_DIR/paste-old.png"
fresh_staged="$STAGING_DIR/paste-fresh.png"
printf 'old' > "$old_staged"
printf 'fresh' > "$fresh_staged"
touch -d '2 days ago' "$old_staged"
"$HELPER" prune "$STAGING_DIR"
[ ! -e "$old_staged" ] || fail "prune did not remove a stale staged image"
[ -e "$fresh_staged" ] || fail "prune removed a fresh staged image"

if PATH="$FAKE_BIN:$PATH" FAKE_CLIPBOARD_TYPES=text/plain "$HELPER" capture "$STAGING_DIR" >/dev/null 2>&1; then
    fail "text-only clipboard should not be captured as an image"
else
    status=$?
    [ "$status" -eq 3 ] || fail "text-only clipboard returned $status instead of 3"
fi

echo "clipboard_image_test.sh: all tests passed"
