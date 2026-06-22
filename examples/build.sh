#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXAMPLES_DIR="${ROOT_DIR}/examples"
COMPILER="${ROOT_DIR}/webracket.rkt"
RACKET="${RACKET:-racket}"

build_example() {
  local dir="$1"
  local entry="$2"
  shift 2
  echo "  - ${dir}/${entry}"
  (
    cd "${EXAMPLES_DIR}/${dir}"
    "$RACKET" "${COMPILER}" "$@" -b "${entry}"
  )
}

build_example_node() {
  local dir="$1"
  local entry="$2"
  shift 2
  echo "  - ${dir}/${entry} (node)"
  (
    cd "${EXAMPLES_DIR}/${dir}"
    "$RACKET" "${COMPILER}" --node "$@" "${entry}"
  )
}

build_example_script() {
  local dir="$1"
  echo "  - ${dir}/compile.sh"
  (
    cd "${EXAMPLES_DIR}/${dir}"
    ./compile.sh
  )
}

echo "-- Building runnable examples --"
build_example "mathjax4"       "mathjax.rkt"        --ffi dom --ffi standard
build_example_script "console-bridge"
build_example_script "hello-world-2"
build_example_script "hello-world-3"
build_example "matrix-rain"    "matrix-rain.rkt"    --ffi xtermjs --ffi dom --ffi standard
build_example_script "xtermjs-demo"
build_example "space-invaders" "space-invaders.rkt" --ffi dom --ffi standard
build_example "minischeme"     "minischeme-page.rkt" --ffi standard --ffi xtermjs --ffi js --ffi dom
build_example_script "hello-world-1"
echo "-- Examples built --"
