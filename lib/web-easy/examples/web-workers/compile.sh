#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$SCRIPT_DIR"
mkdir -p generated

SOURCE="app.rkt"

racket "$ROOT_DIR/webracket.rkt" --browser "$SOURCE"

for ext in html js wasm wasm.map.sexp wat; do
  src="app.$ext"
  if [ -f "$src" ]; then
    mv -f "$src" "generated/$src"
  fi
done

for src in webracket-runtime-*.wasm webracket-runtime-*.wat \
           webracket-ffi-*.wasm webracket-ffi-*.wat; do
  if [ -f "$src" ]; then
    mv -f "$src" "generated/$src"
  fi
done

cp -f worker.js generated/worker.js

echo "compiled: generated/app.html"
