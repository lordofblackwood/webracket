#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT_DIR="$ROOT_DIR/thematic/generated"
SMOKE_OUT_DIR="$ROOT_DIR/lib/web-easy/smoke/generated"
RACKET=${RACKET:-racket}

run_racket_tool() {
  tool=$1
  shift
  "$RACKET" -e '(use-compiled-file-paths null)' -t "$tool" -- "$@"
}

mkdir -p "$OUT_DIR"
mkdir -p "$SMOKE_OUT_DIR"

for theme in superhero sketchy lux sandstone
do
  run_racket_tool "$ROOT_DIR/tools/thematic" \
    --input "$ROOT_DIR/thematic/original/$theme/bootstrap.css" \
    --output "$OUT_DIR/$theme.css" \
    --theme-class "we-theme-$theme" \
    --selector ':root'
  cp "$OUT_DIR/$theme.css" "$SMOKE_OUT_DIR/thematic-$theme.css"

  run_racket_tool "$ROOT_DIR/tools/thematic-scope" \
    --input "$ROOT_DIR/thematic/original/$theme/bootstrap.css" \
    --output "$OUT_DIR/bootstrap-$theme-scoped.css" \
    --scope '.bs-preview'
  cp "$OUT_DIR/bootstrap-$theme-scoped.css" "$SMOKE_OUT_DIR/bootstrap-$theme-scoped.css"
done

for theme in lux sandstone
do
  run_racket_tool "$ROOT_DIR/tools/thematic" \
    --input "$ROOT_DIR/thematic/original/$theme/bootstrap.css" \
    --output "$OUT_DIR/$theme-boost.css" \
    --theme-class "we-theme-$theme-boost" \
    --selector ':root' \
    --accent-boost
  cp "$OUT_DIR/$theme-boost.css" "$SMOKE_OUT_DIR/thematic-$theme-boost.css"
done
