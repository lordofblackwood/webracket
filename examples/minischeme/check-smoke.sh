#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RACKET_BIN="${RACKET:-racket}"
HOST="${MINISCHEME_SMOKE_HOST:-127.0.0.1}"
PORT="${MINISCHEME_SMOKE_PORT:-9986}"
BASE_URL="http://${HOST}:${PORT}"
LOCAL_TOOLS_DIR="${MINISCHEME_SMOKE_LOCAL_TOOLS_DIR:-$ROOT_DIR/.local-tools}"
CHROME_EXECUTABLE="${MINISCHEME_SMOKE_EXECUTABLE:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
SERVER_LOG="${MINISCHEME_SMOKE_SERVER_LOG:-/tmp/webracket-minischeme-smoke.log}"
TIMEOUT_SEC="${MINISCHEME_SMOKE_TIMEOUT_SEC:-420}"
RSS_LIMIT_MB="${MINISCHEME_SMOKE_RSS_LIMIT_MB:-4096}"

if [ "${MINISCHEME_SMOKE_SKIP_COMPILE:-0}" != "1" ]; then
  echo "START compile minischeme"
  (
    cd "$SCRIPT_DIR"
    python3 "$ROOT_DIR/tools/run-guarded.py" \
      --rss-limit-mb "$RSS_LIMIT_MB" \
      --timeout-sec "$TIMEOUT_SEC" \
      -- \
      /usr/bin/env \
      RACKET="$RACKET_BIN" \
      ./compile.sh
  )
  echo "PASS compile minischeme"
fi

python3 -m http.server "$PORT" --bind "$HOST" --directory "$SCRIPT_DIR" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
trap 'kill "$SERVER_PID" >/dev/null 2>&1 || true' EXIT

sleep 1

MINISCHEME_SMOKE_BASE_URL="$BASE_URL" \
MINISCHEME_SMOKE_NODE_MODULES="$LOCAL_TOOLS_DIR/node_modules" \
MINISCHEME_SMOKE_EXECUTABLE="$CHROME_EXECUTABLE" \
MINISCHEME_SMOKE_TIMEOUT_MS="${MINISCHEME_SMOKE_TIMEOUT_MS:-30000}" \
node "$SCRIPT_DIR/check-smoke.mjs"
