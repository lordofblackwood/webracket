#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)
RACKET=${RACKET:-racket}
DEST="$ROOT/pkgs/web-easy/examples/fetch/generated"

mkdir -p "$DEST"

"$RACKET" "$ROOT/webracket.rkt" \
  --browser \
  --dest "$DEST" \
  "$ROOT/pkgs/web-easy/examples/fetch/fetch.rkt"

cp "$ROOT/pkgs/web-easy/themes/theme-light.css" "$DEST/theme-light.css"
cp "$ROOT/pkgs/web-easy/themes/theme-dark.css" "$DEST/theme-dark.css"
