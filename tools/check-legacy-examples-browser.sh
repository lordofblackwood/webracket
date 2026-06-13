#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST="${LEGACY_SMOKE_HOST:-127.0.0.1}"
PORT="${LEGACY_SMOKE_PORT:-9878}"
BASE_URL="http://${HOST}:${PORT}"
LOCAL_TOOLS_DIR="${LEGACY_SMOKE_LOCAL_TOOLS_DIR:-$ROOT_DIR/.local-tools}"
EXAMPLES="${LEGACY_EXAMPLES:-hello-world-2 hello-world-3 console-bridge xtermjs-demo}"
RACKET_BIN="${RACKET:-racket}"
SERVER_LOG="${LEGACY_SMOKE_SERVER_LOG:-/tmp/webracket-legacy-examples-browser.log}"

compile_example() {
  local dir="$1"
  echo "Compiling ${dir}"
  (
    cd "$ROOT_DIR/examples/$dir"
    RACKET="$RACKET_BIN" ./compile.sh
  )
}

if [ "${LEGACY_SMOKE_SKIP_COMPILE:-0}" != "1" ]; then
  compile_example "hello-world-2"
  compile_example "hello-world-3"
  compile_example "console-bridge"
  compile_example "xtermjs-demo"
fi

python3 -m http.server "$PORT" --bind "$HOST" --directory "$ROOT_DIR" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" >/dev/null 2>&1 || true' EXIT

sleep 1

LEGACY_EXAMPLES_BASE_URL="$BASE_URL" \
LEGACY_EXAMPLES_NODE_MODULES="$LOCAL_TOOLS_DIR/node_modules" \
LEGACY_EXAMPLES_TIMEOUT_MS="${LEGACY_EXAMPLES_TIMEOUT_MS:-20000}" \
LEGACY_EXAMPLES="$EXAMPLES" \
node "$SCRIPT_DIR/check-legacy-examples-browser.mjs"
