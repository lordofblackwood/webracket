#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RACKET="${RACKET:-racket}"
BASENAME="minischeme-page"
CACHE_TAG="expander-read-provider"
PROVIDER_CACHE_DIR="$SCRIPT_DIR/generated/.provider-cache-$CACHE_TAG"
COMPILED_ROOTS_DIR="${PLTCOMPILEDROOTS:-$SCRIPT_DIR/generated/.compiled-$CACHE_TAG}"

cd "$SCRIPT_DIR"
mkdir -p generated
mkdir -p "$PROVIDER_CACHE_DIR"
mkdir -p "$COMPILED_ROOTS_DIR"

PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOTS_DIR" \
  "$RACKET" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --expander-read-provider \
  --provider-cache-dir "$PROVIDER_CACHE_DIR" \
  --dest generated \
  "$BASENAME.rkt"

echo "compiled: generated/$BASENAME.html"
