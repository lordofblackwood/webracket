#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

SMOKE_COMPILE_SOURCE_PATHS="$ROOT_DIR/pkgs/file-system/main.rkt
$ROOT_DIR/pkgs/webracket/unsafe/file-system.rkt
$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/file-system.ffi
$ROOT_DIR/pkgs/webracket-lib/compiler/assembler.rkt
$ROOT_DIR/pkgs/webracket-lib/compiler/runtime-js/imports.js" \
  "$SCRIPT_DIR/run-browser-target-compile.sh" file-system
