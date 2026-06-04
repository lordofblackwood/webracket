#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)
RACKET=${RACKET:-racket}
DEST="$ROOT/pkgs/web-easy/examples/rquery-toggle/generated"

mkdir -p "$DEST"

"$RACKET" "$ROOT/webracket.rkt" \
  --browser \
  --dest "$DEST" \
  "$ROOT/pkgs/web-easy/examples/rquery-toggle/rquery-toggle.rkt"

cp "$ROOT/pkgs/web-easy/themes/theme-light.css" "$DEST/theme-light.css"
cp "$ROOT/pkgs/web-easy/themes/theme-dark.css" "$DEST/theme-dark.css"
