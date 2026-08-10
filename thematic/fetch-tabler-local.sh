#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RACKET=${RACKET:-racket}
TABLER_VERSION=${TABLER_VERSION:-latest}
TABLER_CSS_URL=${TABLER_CSS_URL:-https://cdn.jsdelivr.net/npm/@tabler/core@${TABLER_VERSION}/dist/css/tabler.css}
LOCAL_DIR=${TABLER_LOCAL_DIR:-"$ROOT_DIR/thematic/original/tabler"}
OUT_DIR=${TABLER_OUT_DIR:-"$ROOT_DIR/thematic/generated"}
TEST_OUT_DIR=${TABLER_TEST_OUT_DIR:-"$ROOT_DIR/pkgs/thematic/test/generated"}
SOURCE_CSS="$LOCAL_DIR/tabler.css"

run_racket_tool() {
  tool=$1
  shift
  "$RACKET" -e '(use-compiled-file-paths null)' -t "$tool" -- "$@"
}

mkdir -p "$LOCAL_DIR"
mkdir -p "$OUT_DIR"
mkdir -p "$TEST_OUT_DIR"

echo "Downloading Tabler CSS to $SOURCE_CSS"
curl -L "$TABLER_CSS_URL" -o "$SOURCE_CSS"

echo "Generating web-easy theme from local Tabler CSS"
run_racket_tool "$ROOT_DIR/tools/thematic" \
  --input "$SOURCE_CSS" \
  --output "$OUT_DIR/tabler.css" \
  --theme-class "we-theme-tabler" \
  --selector ':root' \
  --source-dialect tabler
cp "$OUT_DIR/tabler.css" "$TEST_OUT_DIR/thematic-tabler.css"

echo "Generating scoped Tabler source CSS for comparison"
run_racket_tool "$ROOT_DIR/tools/thematic-scope" \
  --input "$SOURCE_CSS" \
  --output "$OUT_DIR/bootstrap-tabler-scoped.css" \
  --scope '.bs-preview'
cp "$OUT_DIR/bootstrap-tabler-scoped.css" "$TEST_OUT_DIR/bootstrap-tabler-scoped.css"

echo "Tabler local fixtures ready."
echo "Open: pkgs/thematic/test/test-browser-theme-thematic-bootstrap-compare.html?theme=tabler"
