#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RACKET="${RACKET:-racket}"
BASENAME="hello-world-1"

cd "$SCRIPT_DIR"

PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
  "$RACKET" "$ROOT_DIR/webracket.rkt" \
  --node \
  "$BASENAME.rkt"

echo "compiled: $BASENAME.js"
