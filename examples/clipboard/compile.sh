#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RACKET="${RACKET:-racket}"
BASENAME="clipboard-demo"

cd "$SCRIPT_DIR"
mkdir -p generated
mkdir -p generated/.provider-cache
mkdir -p generated/.compiled

PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="${PLTCOMPILEDROOTS:-$SCRIPT_DIR/generated/.compiled}" \
  "$RACKET" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --provider-cache-dir generated/.provider-cache \
  --dest generated \
  "$BASENAME.rkt"

echo "compiled: generated/$BASENAME.html"
