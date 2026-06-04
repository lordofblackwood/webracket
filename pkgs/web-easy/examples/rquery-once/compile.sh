#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)
RACKET=${RACKET:-racket}
DEST="$ROOT/pkgs/web-easy/examples/rquery-once/generated"

mkdir -p "$DEST"

"$RACKET" "$ROOT/webracket.rkt" \
  --browser \
  --dest "$DEST" \
  "$ROOT/pkgs/web-easy/examples/rquery-once/rquery-once.rkt"

cp "$ROOT/pkgs/web-easy/themes/theme-light.css" "$DEST/theme-light.css"
cp "$ROOT/pkgs/web-easy/themes/theme-dark.css" "$DEST/theme-dark.css"
