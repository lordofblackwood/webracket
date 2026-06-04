#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../../../.." && pwd)
RACKET=${RACKET:-racket}
DEST="$ROOT/pkgs/web-easy/examples/audio-analyser/generated"

mkdir -p "$DEST"

"$RACKET" "$ROOT/webracket.rkt" \
  --browser \
  --dest "$DEST" \
  "$ROOT/pkgs/web-easy/examples/audio-analyser/audio-analyser.rkt"

cp "$ROOT/pkgs/web-easy/themes/web-easy-core.css" "$DEST/web-easy-core.css"
cp "$ROOT/pkgs/web-easy/themes/theme-light.css" "$DEST/theme-light.css"
