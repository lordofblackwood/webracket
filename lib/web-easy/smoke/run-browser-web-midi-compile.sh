#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SMOKE_COMPILE_SOURCE_PATHS="$ROOT_DIR/pkgs/web-midi/main.rkt
$ROOT_DIR/pkgs/webracket/unsafe/web-midi.rkt
$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/web-midi.ffi
$ROOT_DIR/pkgs/webracket-lib/compiler/assembler.rkt
$ROOT_DIR/pkgs/webracket-lib/compiler/runtime-js/imports.js" \
  "$SCRIPT_DIR/run-browser-target-compile.sh" web-midi
