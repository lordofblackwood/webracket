#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$SCRIPT_DIR"
mkdir -p generated

SOURCE="app.rkt"
OUTPUT_BASENAME="resize-observer"

racket "$ROOT_DIR/webracket.rkt" --browser \
  --host-file "$OUTPUT_BASENAME.html" \
  --wasm-file "$OUTPUT_BASENAME.wasm" \
  --wat-file "$OUTPUT_BASENAME.wat" \
  "$SOURCE"

for ext in html js wasm wasm.map.sexp wat runtime.wasm runtime.wat; do
  src="$OUTPUT_BASENAME.$ext"
  if [ -f "$src" ]; then
    mv -f "$src" "generated/$src"
  fi
done

echo "compiled: generated/$OUTPUT_BASENAME.html"
