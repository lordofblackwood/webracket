#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 EXAMPLE" >&2
  echo "example: $0 hello-world" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

EXAMPLE="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/$EXAMPLE"

case "$EXAMPLE" in
  ""|.*|*/*)
    echo "compile-example.sh: invalid example name: $EXAMPLE" >&2
    exit 2
    ;;
esac

if [ ! -d "$EXAMPLE_DIR" ]; then
  echo "compile-example.sh: no such example: $EXAMPLE" >&2
  exit 1
fi

if [ ! -x "$EXAMPLE_DIR/compile.sh" ]; then
  echo "compile-example.sh: example has no executable compile.sh: $EXAMPLE" >&2
  exit 1
fi

export RACKET="${RACKET:-racket}"
export PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:"

cd "$EXAMPLE_DIR"
exec ./compile.sh
