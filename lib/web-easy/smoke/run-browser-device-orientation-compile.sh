#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SMOKE_COMPILE_SOURCE_PATHS="$ROOT_DIR/pkgs/device-orientation/main.rkt
$ROOT_DIR/pkgs/webracket/unsafe/device-orientation.rkt
$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/device-orientation.ffi
$ROOT_DIR/pkgs/webracket-lib/compiler/assembler.rkt
$ROOT_DIR/pkgs/webracket-lib/compiler/runtime-js/imports.js" \
  "$SCRIPT_DIR/run-browser-target-compile.sh" device-orientation
