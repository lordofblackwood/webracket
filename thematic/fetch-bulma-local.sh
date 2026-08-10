#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RACKET=${RACKET:-racket}
BULMA_VERSION=${BULMA_VERSION:-1}
BULMA_BASE_URL=${BULMA_BASE_URL:-https://cdn.jsdelivr.net/npm/bulma@${BULMA_VERSION}}
BULMA_THEMES=${BULMA_THEMES:-light dark}
LOCAL_DIR=${BULMA_LOCAL_DIR:-"$ROOT_DIR/thematic/original/bulma"}
OUT_DIR=${BULMA_OUT_DIR:-"$ROOT_DIR/thematic/generated"}

run_racket_tool() {
  tool=$1
  shift
  "$RACKET" -e '(use-compiled-file-paths null)' -t "$tool" -- "$@"
}

mkdir -p "$LOCAL_DIR"
mkdir -p "$OUT_DIR"

bulma_css="$LOCAL_DIR/bulma.css"

echo "Downloading Bulma CSS to $bulma_css"
curl -L "$BULMA_BASE_URL/css/bulma.css" -o "$bulma_css"

for theme in $BULMA_THEMES
do
  output_css="$OUT_DIR/bulma-$theme.css"

  echo "Generating web-easy theme bulma-$theme"
  run_racket_tool "$ROOT_DIR/tools/thematic" \
    --input "$bulma_css" \
    --output "$output_css" \
    --theme-class "we-theme-bulma-$theme" \
    --selector "[data-theme=$theme]" \
    --source-dialect bulma
done

echo "Bulma local themes ready."
echo "Generated files are local-only under thematic/generated/bulma-*.css"
