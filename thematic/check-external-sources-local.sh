#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
RACKET=${RACKET:-racket}
RUN_EXTERNAL=${THEMATIC_EXTERNAL_SOURCES:-0}

if [ "$RUN_EXTERNAL" != "1" ]; then
  echo "Skipping external source checks."
  echo "Set THEMATIC_EXTERNAL_SOURCES=1 to download MIT-licensed local fixtures."
  exit 0
fi

check_no_source_vars() {
  css_file=$1
  pattern=$2

  if grep -E "var\\([[:space:]]*$pattern" "$css_file" >/dev/null 2>&1; then
    echo "Generated CSS leaks source variables: $css_file" >&2
    grep -n -E "var\\([[:space:]]*$pattern" "$css_file" >&2
    exit 1
  fi
}

export RACKET

echo "Checking Tabler external source contract"
TABLER_VERSION=${TABLER_VERSION:-latest} \
  "$ROOT_DIR/thematic/fetch-tabler-local.sh"
check_no_source_vars "$ROOT_DIR/thematic/generated/tabler.css" "--tblr-"

echo "Checking Pico external source contract"
PICO_THEMES=${PICO_THEMES:-jade} \
PICO_MODES=${PICO_MODES:-light dark} \
  "$ROOT_DIR/thematic/fetch-pico-local.sh"
check_no_source_vars "$ROOT_DIR/thematic/generated/pico-jade.css" "--pico-"
check_no_source_vars "$ROOT_DIR/thematic/generated/pico-jade-dark.css" "--pico-"

echo "Checking daisyUI external source contract"
DAISYUI_THEMES=${DAISYUI_THEMES:-synthwave} \
  "$ROOT_DIR/thematic/fetch-daisyui-local.sh"
check_no_source_vars "$ROOT_DIR/thematic/generated/daisyui-synthwave.css" "--color-|--radius-|--size-|--border|--depth|--noise"

echo "Checking Bulma external source contract"
BULMA_THEMES=${BULMA_THEMES:-light dark} \
  "$ROOT_DIR/thematic/fetch-bulma-local.sh"
check_no_source_vars "$ROOT_DIR/thematic/generated/bulma-light.css" "--bulma-"
check_no_source_vars "$ROOT_DIR/thematic/generated/bulma-dark.css" "--bulma-"

echo "PASS external source contracts"
