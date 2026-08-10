#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RACKET=${RACKET:-racket}
PICO_VERSION=${PICO_VERSION:-2}
PICO_BASE_URL=${PICO_BASE_URL:-https://cdn.jsdelivr.net/npm/@picocss/pico@${PICO_VERSION}/css}
PICO_THEMES=${PICO_THEMES:-amber azure blue cyan fuchsia green grey indigo jade lime orange pink pumpkin purple red sand slate violet yellow zinc}
PICO_MODES=${PICO_MODES:-light dark}
LOCAL_DIR=${PICO_LOCAL_DIR:-"$ROOT_DIR/thematic/original/pico"}
OUT_DIR=${PICO_OUT_DIR:-"$ROOT_DIR/thematic/generated"}

run_racket_tool() {
  tool=$1
  shift
  "$RACKET" -e '(use-compiled-file-paths null)' -t "$tool" -- "$@"
}

pico_css_name() {
  theme=$1
  if [ "$theme" = "azure" ]; then
    printf '%s\n' "pico.css"
  else
    printf '%s\n' "pico.$theme.css"
  fi
}

mode_selector() {
  mode=$1
  case "$mode" in
    light) printf '%s\n' ':root' ;;
    dark) printf '%s\n' '[data-bs-theme=dark]' ;;
    *) echo "unsupported Pico mode: $mode" >&2; exit 1 ;;
  esac
}

mode_suffix() {
  theme=$1
  mode=$2
  case "$mode" in
    light) printf '%s\n' "$theme" ;;
    dark) printf '%s\n' "$theme-dark" ;;
    *) echo "unsupported Pico mode: $mode" >&2; exit 1 ;;
  esac
}

mkdir -p "$LOCAL_DIR"
mkdir -p "$OUT_DIR"

for theme in $PICO_THEMES
do
  css_name=$(pico_css_name "$theme")
  source_css="$LOCAL_DIR/$css_name"

  echo "Downloading Pico CSS $theme to $source_css"
  curl -L "$PICO_BASE_URL/$css_name" -o "$source_css"

  for mode in $PICO_MODES
  do
    suffix=$(mode_suffix "$theme" "$mode")
    selector=$(mode_selector "$mode")
    output_css="$OUT_DIR/pico-$suffix.css"

    echo "Generating web-easy theme pico-$suffix"
    run_racket_tool "$ROOT_DIR/tools/thematic" \
      --input "$source_css" \
      --output "$output_css" \
      --theme-class "we-theme-pico-$suffix" \
      --selector "$selector" \
      --source-dialect pico
  done
done

echo "Pico local themes ready."
echo "Generated files are local-only under thematic/generated/pico-*.css"
