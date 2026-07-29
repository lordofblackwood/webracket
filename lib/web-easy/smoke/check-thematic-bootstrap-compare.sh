#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PORT="${SMOKE_PORT:-8765}"
HOST="${SMOKE_HOST:-127.0.0.1}"
BASE_URL="${SMOKE_BASE_URL:-http://${HOST}:${PORT}}"
LOCAL_TOOLS_DIR="${SMOKE_LOCAL_TOOLS_DIR:-$ROOT_DIR/.local-tools}"
PAGE_NAME="test-browser-theme-thematic-bootstrap-compare.html"
SERVER_LOG="/tmp/web-easy-thematic-bootstrap-compare.log"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required for thematic Bootstrap compare."
  exit 2
fi

if [ -z "${SMOKE_NODE_MODULES:-}" ] && [ -d "$LOCAL_TOOLS_DIR/node_modules" ]; then
  export SMOKE_NODE_MODULES="$LOCAL_TOOLS_DIR/node_modules"
fi

if [ -n "${THEMATIC_COMPARE_URL:-}" ]; then
  node "$SCRIPT_DIR/check-thematic-bootstrap-compare.mjs"
  exit 0
fi

if [ "${THEMATIC_COMPARE_SKIP_REGENERATE:-0}" != "1" ]; then
  echo "Regenerating thematic compare fixtures..."
  "$ROOT_DIR/thematic/regenerate.sh"
fi

if ! command -v raco >/dev/null 2>&1; then
  echo "raco is required to serve smoke files via static-web."
  exit 2
fi

if ! raco static-web --help >/dev/null 2>&1; then
  echo "raco static-web is required to serve smoke files."
  exit 2
fi

raco static-web --port "$PORT" --dir "$SCRIPT_DIR" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

cleanup() {
  if kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

server_ready() {
  node -e 'const http = require("node:http"); const https = require("node:https"); const url = new URL(process.argv[1]); const lib = url.protocol === "https:" ? https : http; const req = lib.get(url, (res) => { res.resume(); process.exit(res.statusCode >= 200 && res.statusCode < 500 ? 0 : 1); }); req.on("error", () => process.exit(1)); req.setTimeout(1000, () => { req.destroy(); process.exit(1); });' "$BASE_URL/$PAGE_NAME"
}

READY=0
for _ in {1..50}; do
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    echo "raco static-web exited before serving $PAGE_NAME."
    sed -n '1,120p' "$SERVER_LOG" || true
    exit 1
  fi
  if server_ready; then
    READY=1
    break
  fi
  sleep 0.2
done

if [ "$READY" != "1" ]; then
  echo "Timed out waiting for $BASE_URL/$PAGE_NAME."
  sed -n '1,120p' "$SERVER_LOG" || true
  exit 1
fi

SMOKE_BASE_URL="$BASE_URL" node "$SCRIPT_DIR/check-thematic-bootstrap-compare.mjs"
