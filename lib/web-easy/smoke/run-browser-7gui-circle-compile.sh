#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EXAMPLE_DIR="$ROOT_DIR/lib/web-easy/examples/7gui-circle"
TARGET_DIR="$SCRIPT_DIR/generated"

mkdir -p "$TARGET_DIR"
runtime_sidecars=("$EXAMPLE_DIR/generated"/webracket-runtime-*.wasm)
if [ ! -f "$EXAMPLE_DIR/generated/7gui-circle.html" ] \
  || [ "${#runtime_sidecars[@]}" -eq 0 ]; then
  echo "Compiling 7gui-circle example artifacts"
  "$EXAMPLE_DIR/compile.sh"
  runtime_sidecars=("$EXAMPLE_DIR/generated"/webracket-runtime-*.wasm)
fi
if [ "${#runtime_sidecars[@]}" -eq 0 ]; then
  echo "Missing split runtime wasm in $EXAMPLE_DIR/generated" >&2
  exit 1
fi

cp -f "$EXAMPLE_DIR/generated/7gui-circle.html" "$TARGET_DIR/7gui-circle.html"
cp -f "$EXAMPLE_DIR/generated/7gui-circle.wasm" "$TARGET_DIR/7gui-circle.wasm"
cp -f "$EXAMPLE_DIR/generated/7gui-circle.wasm.map.sexp" "$TARGET_DIR/7gui-circle.wasm.map.sexp"
cp -f "$EXAMPLE_DIR/generated/7gui-circle.wat" "$TARGET_DIR/7gui-circle.wat"
cp -f "${runtime_sidecars[@]}" "$TARGET_DIR/"
runtime_wats=("$EXAMPLE_DIR/generated"/webracket-runtime-*.wat)
ffi_sidecars=("$EXAMPLE_DIR/generated"/webracket-ffi-*.wasm)
ffi_wats=("$EXAMPLE_DIR/generated"/webracket-ffi-*.wat)
if [ "${#runtime_wats[@]}" -gt 0 ]; then
  cp -f "${runtime_wats[@]}" "$TARGET_DIR/"
fi
if [ "${#ffi_sidecars[@]}" -gt 0 ]; then
  cp -f "${ffi_sidecars[@]}" "$TARGET_DIR/"
fi
if [ "${#ffi_wats[@]}" -gt 0 ]; then
  cp -f "${ffi_wats[@]}" "$TARGET_DIR/"
fi
cp -f "$EXAMPLE_DIR/generated/web-easy-core.css" "$TARGET_DIR/web-easy-core.css"
cp -f "$EXAMPLE_DIR/generated/theme-light.css" "$TARGET_DIR/theme-light.css"
if [ -f "$EXAMPLE_DIR/generated/theme-external-light.css" ]; then
  cp -f "$EXAMPLE_DIR/generated/theme-external-light.css" "$TARGET_DIR/theme-external-light.css"
fi

echo "compiled: generated/7gui-circle.html"
