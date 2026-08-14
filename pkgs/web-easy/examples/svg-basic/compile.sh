#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
THEME_DIR="$ROOT_DIR/pkgs/web-easy/themes"
RACKET="${RACKET:-racket}"
BASENAME="svg-basic"

cd "$SCRIPT_DIR"
mkdir -p generated

PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
  "$RACKET" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest generated \
  "$BASENAME.rkt"

cp -f "$THEME_DIR/web-easy-core.css" "generated/web-easy-core.css"
cp -f "$THEME_DIR/theme-light.css" "generated/theme-light.css"

echo "compiled: generated/$BASENAME.html"
