#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$SCRIPT_DIR"
mkdir -p generated

SOURCE="app.rkt"
OUTPUT_BASENAME="screen-orientation"

racket "$ROOT_DIR/webracket.rkt" --browser "$SOURCE"

for ext in html js wasm wasm.map.sexp wat; do
  src="app.$ext"
  if [ -f "$src" ]; then
    mv -f "$src" "generated/$OUTPUT_BASENAME.$ext"
  fi
done

echo "compiled: generated/$OUTPUT_BASENAME.html"
