#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RACKET=${RACKET:-racket}
DAISYUI_VERSION=${DAISYUI_VERSION:-5}
DAISYUI_BASE_URL=${DAISYUI_BASE_URL:-https://cdn.jsdelivr.net/npm/daisyui@${DAISYUI_VERSION}}
DAISYUI_THEMES=${DAISYUI_THEMES:-light dark cupcake bumblebee emerald corporate synthwave retro cyberpunk valentine halloween garden forest aqua lofi pastel fantasy wireframe black luxury dracula cmyk autumn business acid lemonade night coffee winter dim nord sunset caramellatte abyss silk}
LOCAL_DIR=${DAISYUI_LOCAL_DIR:-"$ROOT_DIR/thematic/original/daisyui"}
OUT_DIR=${DAISYUI_OUT_DIR:-"$ROOT_DIR/thematic/generated"}

run_racket_tool() {
  tool=$1
  shift
  "$RACKET" -e '(use-compiled-file-paths null)' -t "$tool" -- "$@"
}

mkdir -p "$LOCAL_DIR"
mkdir -p "$OUT_DIR"

themes_css="$LOCAL_DIR/themes.css"

echo "Downloading daisyUI themes to $themes_css"
curl -L "$DAISYUI_BASE_URL/themes.css" -o "$themes_css"

for theme in $DAISYUI_THEMES
do
  output_css="$OUT_DIR/daisyui-$theme.css"

  echo "Generating web-easy theme daisyui-$theme"
  run_racket_tool "$ROOT_DIR/tools/thematic" \
    --input "$themes_css" \
    --output "$output_css" \
    --theme-class "we-theme-daisyui-$theme" \
    --selector "[data-theme=$theme]" \
    --source-dialect daisyui
done

echo "daisyUI local themes ready."
echo "Generated files are local-only under thematic/generated/daisyui-*.css"
