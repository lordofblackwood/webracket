#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT="${ROOT_EXAMPLES_PORT:-9987}"
LOCAL_NODE_MODULES="${ROOT_EXAMPLES_NODE_MODULES:-$ROOT_DIR/.local-tools/node_modules}"
CHROME_EXECUTABLE="${ROOT_EXAMPLES_EXECUTABLE:-}"
FILTER="${ROOT_EXAMPLES_FILTER:-}"
SKIP_COMPILE="${ROOT_EXAMPLES_SKIP_COMPILE:-0}"
SKIP_BROWSER_PREFLIGHT="${ROOT_EXAMPLES_SKIP_BROWSER_PREFLIGHT:-0}"
PREFLIGHT_TIMEOUT_MS="${ROOT_EXAMPLES_BROWSER_PREFLIGHT_TIMEOUT_MS:-30000}"
RACKET_CMD="${RACKET:-racket}"
SERVER_LOG="${TMPDIR:-/tmp}/webracket-root-examples-server.log"
PLAYWRIGHT_CACHE_ROOT="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/Library/Caches/ms-playwright}"

if [[ -z "$CHROME_EXECUTABLE" && -d "$PLAYWRIGHT_CACHE_ROOT" ]]; then
  CHROME_EXECUTABLE="$(
    find "$PLAYWRIGHT_CACHE_ROOT" \
      -type f \
      -path '*/chrome-headless-shell' \
      2>/dev/null \
      | sort -V \
      | tail -n 1
  )"
fi

examples=(
  "hello-world-2"
  "hello-world-3"
  "console-bridge"
  "xtermjs-demo"
  "pict"
  "space-invaders"
  "snake"
  "snake2"
  "mathjax4"
  "minischeme"
  "matrix-rain"
  "raco"
)

matches_filter() {
  local name="$1"
  if [[ -z "$FILTER" ]]; then
    return 0
  fi

  local item
  IFS=',' read -r -a items <<< "$FILTER"
  for item in "${items[@]}"; do
    if [[ "$name" == "$item" ]]; then
      return 0
    fi
  done
  return 1
}

if [[ "$SKIP_BROWSER_PREFLIGHT" != "1" ]]; then
  "$RACKET_CMD" "$ROOT_DIR/tools/check-browser-harness.rkt" \
    --node "${ROOT_EXAMPLES_NODE:-node}" \
    --node-modules "$LOCAL_NODE_MODULES" \
    --chrome-executable "$CHROME_EXECUTABLE" \
    --timeout-ms "$PREFLIGHT_TIMEOUT_MS"
fi

compile_example() {
  local dir="$1"
  echo "START compile $dir"
  (
    cd "$SCRIPT_DIR/$dir"
    ./compile.sh
  )
  echo "PASS compile $dir"
}

if [[ "$SKIP_COMPILE" != "1" ]]; then
  for dir in "${examples[@]}"; do
    if matches_filter "$dir"; then
      compile_example "$dir"
    fi
  done
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node is required for the root examples runner."
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to serve root examples."
  exit 2
fi

SERVER_PID=""
BASE_URL=""
for candidate in "$PORT" 9988 9989 9990 9991 9992 9993 9994 9995 9996 9997 9998 9999; do
  : >"$SERVER_LOG"
  (
    cd "$ROOT_DIR"
    python3 -m http.server "$candidate"
  ) >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  sleep 1
  if grep -q "Address already in use" "$SERVER_LOG"; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    SERVER_PID=""
    continue
  fi
  PORT="$candidate"
  BASE_URL="http://127.0.0.1:${PORT}"
  break
done

trap 'kill "$SERVER_PID" >/dev/null 2>&1 || true' EXIT

if [[ -z "$SERVER_PID" ]]; then
  echo "Root examples server failed to bind an available port."
  cat "$SERVER_LOG"
  exit 1
fi

SMOKE_BASE_URL="$BASE_URL" \
SMOKE_NODE_MODULES="$LOCAL_NODE_MODULES" \
SMOKE_CHROME_EXECUTABLE="$CHROME_EXECUTABLE" \
ROOT_EXAMPLES_FILTER="$FILTER" \
node "$SCRIPT_DIR/check-root-examples.mjs"
