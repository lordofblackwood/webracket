#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT="${SPLIT_FFI_MIXED_CACHE_PORT:-10041}"
TIMEOUT_SEC="${SPLIT_FFI_MIXED_CACHE_TIMEOUT_SEC:-720}"
RSS_LIMIT_MB="${SPLIT_FFI_MIXED_CACHE_RSS_LIMIT_MB:-3500}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN_ROOT="${SPLIT_FFI_MIXED_CACHE_TMP:-$ROOT_DIR/tmp/split-ffi-mixed-cache-headless}/$RUN_ID"
OUT_DIR="$RUN_ROOT/out"
PROVIDER_CACHE_DIR="$RUN_ROOT/provider-cache"
RUNTIME_PROVIDER_CACHE_DIR="$RUN_ROOT/runtime-provider-cache"
SERVER_LOG="$RUN_ROOT/server.log"
BASE_URL=""
LOCAL_NODE_MODULES="${DOM_HEADLESS_NODE_MODULES:-$ROOT_DIR/.local-tools/node_modules}"
CHROME_EXECUTABLE="${DOM_HEADLESS_EXECUTABLE:-}"
PLAYWRIGHT_CACHE_ROOT="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/Library/Caches/ms-playwright}"
SMOKE_PAGES=()

mkdir -p "$OUT_DIR" "$PROVIDER_CACHE_DIR" "$RUNTIME_PROVIDER_CACHE_DIR"

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

compile_root_test() {
  local file="$1"
  shift || true
  echo "START split-ffi compile $file"
  python3 "$ROOT_DIR/tools/run-guarded.py" \
    --timeout-sec "$TIMEOUT_SEC" \
    --rss-limit-mb "$RSS_LIMIT_MB" \
    -- \
    racket "$ROOT_DIR/webracket.rkt" \
      --browser \
      --split-runtime-ffi-module \
      --dest "$OUT_DIR" \
      --provider-cache-dir "$PROVIDER_CACHE_DIR" \
      --runtime-provider-cache-dir "$RUNTIME_PROVIDER_CACHE_DIR" \
      "$@" \
      "$ROOT_DIR/$file"
  echo "PASS split-ffi compile $file"
}

compile_test_dir_test() {
  local file="$1"
  shift || true
  echo "START split-ffi compile test/$file"
  (
    cd "$SCRIPT_DIR"
    python3 "$ROOT_DIR/tools/run-guarded.py" \
      --timeout-sec "$TIMEOUT_SEC" \
      --rss-limit-mb "$RSS_LIMIT_MB" \
      -- \
      racket "$ROOT_DIR/webracket.rkt" \
        --browser \
        --split-runtime-ffi-module \
        --dest "$OUT_DIR" \
        --provider-cache-dir "$PROVIDER_CACHE_DIR" \
        --runtime-provider-cache-dir "$RUNTIME_PROVIDER_CACHE_DIR" \
        "$@" \
        "$file"
  )
  echo "PASS split-ffi compile test/$file"
}

compile_root_case() {
  local page="$1"
  local file="$2"
  shift 2
  compile_root_test "$file" "$@"
  SMOKE_PAGES+=("$page")
}

compile_test_dir_case() {
  local page="$1"
  local file="$2"
  shift 2
  compile_test_dir_test "$file" "$@"
  SMOKE_PAGES+=("$page")
}

join_smoke_pages() {
  local IFS=,
  echo "${SMOKE_PAGES[*]}"
}

compile_test_dir_case test-audio.html test-audio.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/audio.ffi"
compile_root_case test-audio-method-missing-host-ffi.html test/test-audio-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/audio.ffi"
compile_test_dir_case test-console.html test-console.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/console.ffi"
compile_root_case test-console-method-missing-host-ffi.html test/test-console-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/console.ffi"
compile_test_dir_case test-array.html test-array.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/array.ffi"
compile_root_case test-js-array-method-missing-host-ffi.html test/test-js-array-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/array.ffi"
compile_root_case test-standard-send-missing-host-ffi.html test/test-standard-send-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi"
compile_root_case test-standard-property-missing-host-ffi.html test/test-standard-property-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi"
compile_root_case test-js-promise-method-missing-host-ffi.html test/test-js-promise-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi"
compile_root_case test-js-iterator-method-missing-host-ffi.html test/test-js-iterator-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi"
compile_root_case test-js-math-ffi.html test/test-js-math-ffi.rkt
compile_root_case test-js-performance-ffi.html test/test-js-performance-ffi.rkt
compile_root_case test-performance-missing-host-ffi.html test/test-performance-missing-host-ffi.rkt
compile_root_case test-js-temp-ffi.html test/test-js-temp-ffi.rkt
compile_root_case test-xtermjs-missing-host-ffi.html test/test-xtermjs-missing-host-ffi.rkt
compile_root_case test-xtermjs-ffi.html test/test-xtermjs-ffi.rkt
compile_root_case test-jsxgraph-missing-host-ffi.html test/test-jsxgraph-missing-host-ffi.rkt
compile_root_case test-jsxgraph-call-missing-host-ffi.html test/test-jsxgraph-call-missing-host-ffi.rkt
compile_root_case test-jsxgraph-ffi.html test/test-jsxgraph-ffi.rkt
compile_root_case test-browser-constructor-missing-host-ffi.html test/test-browser-constructor-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/audio.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/image.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/websocket.ffi"
compile_root_case test-event-constructor-missing-host-ffi.html test/test-event-constructor-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-event-method-missing-host-ffi.html test/test-event-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-window-missing-host-ffi.html test/test-window-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-window-method-missing-host-ffi.html test/test-window-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-window-value-missing-host-ffi.html test/test-window-value-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-document-missing-host-ffi.html test/test-document-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-object-method-missing-host-ffi.html test/test-object-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-element-method-missing-host-ffi.html test/test-element-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-element-method-missing-host-ffi.html test/test-browser-element-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-shared-dom-method-missing-host-ffi.html test/test-browser-shared-dom-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_test_dir_case test-fetch.html test-fetch.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-fetch-method-missing-host-ffi.html test/test-fetch-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-compression-stream-method-missing-host-ffi.html test/test-compression-stream-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_test_dir_case test-storage.html test-storage.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_test_dir_case test-storage-method-missing-host-ffi.html test-storage-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_test_dir_case test-websocket.html test-websocket.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/websocket.ffi"
compile_root_case test-websocket-surface.html test/test-websocket-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/websocket.ffi"
compile_root_case test-websocket-method-missing-host-ffi.html test/test-websocket-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/websocket.ffi"
compile_test_dir_case test-indexed-db.html test-indexed-db.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_test_dir_case test-indexed-db-method-missing-host-ffi.html test-indexed-db-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-history-surface.html test/test-history-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-history-method-missing-host-ffi.html test/test-history-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-fullscreen-surface.html test/test-fullscreen-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-fullscreen-method-missing-host-ffi.html test/test-fullscreen-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-web-workers-surface.html test/test-web-workers-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-web-workers-method-missing-host-ffi.html test/test-web-workers-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-geolocation-surface.html test/test-geolocation-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-geolocation-method-missing-host-ffi.html test/test-geolocation-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-clipboard-surface.html test/test-clipboard-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-clipboard-mock.html test/test-clipboard-mock.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-clipboard-method-missing-host-ffi.html test/test-clipboard-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-notifications-surface.html test/test-notifications-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-notifications-method-missing-host-ffi.html test/test-notifications-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-screen-orientation-surface.html test/test-screen-orientation-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-screen-orientation-method-missing-host-ffi.html test/test-screen-orientation-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-gamepad-surface.html test/test-gamepad-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-gamepad-method-missing-host-ffi.html test/test-gamepad-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-intersection-observer-surface.html test/test-intersection-observer-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-resize-observer-surface.html test/test-resize-observer-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-observer-method-missing-host-ffi.html test/test-observer-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_test_dir_case test-dom-facade.html test-dom-facade.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-rquery-surface-ffi.html test/test-rquery-surface-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-rquery-method-missing-host-ffi.html test/test-rquery-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/standard.ffi" \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-js-string-symbol-ffi.html test/test-js-string-symbol-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-canvas-draw-image-integers.html test/test-browser-canvas-draw-image-integers.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-window-surface.html test/test-browser-window-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-event-surface.html test/test-browser-event-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-canvas-surface.html test/test-browser-canvas-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-canvas-method-missing-host-ffi.html test/test-browser-canvas-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-image-surface.html test/test-browser-image-surface.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-browser-media-method-missing-host-ffi.html test/test-browser-media-method-missing-host-ffi.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-dom-window-document.html test/test-dom-window-document.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-dom-event.html test/test-dom-event.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-dom-image.html test/test-dom-image.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"
compile_root_case test-dom-canvas-media-image.html test/test-dom-canvas-media-image.rkt \
  --ffi "$ROOT_DIR/pkgs/webracket-lib/compiler/ffi/dom.ffi"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required for the DOM browser runner."
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to serve split-FFI browser tests."
  exit 2
fi

SERVER_PID=""
for candidate in "$PORT" 10042 10043 10044 10045 10046 10047 10048 10049 9991 9992 9993 9994 9995 9996 9997 9998 9999; do
  : >"$SERVER_LOG"
  python3 -m http.server "$candidate" --directory "$OUT_DIR" >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  sleep 1
  if ! kill -0 "$SERVER_PID" >/dev/null 2>&1; then
    SERVER_PID=""
    continue
  fi
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

if [ -z "$SERVER_PID" ]; then
  echo "Split-FFI browser server failed to bind an available port."
  cat "$SERVER_LOG"
  exit 1
fi

for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf "$BASE_URL/test-js-string-symbol-ffi.html" >/dev/null; then
    break
  fi
  sleep 1
done

if grep -q "Address already in use" "$SERVER_LOG"; then
  echo "Split-FFI browser server failed to bind port $PORT."
  cat "$SERVER_LOG"
  exit 1
fi

if ! curl -sf "$BASE_URL/test-js-string-symbol-ffi.html" >/dev/null; then
  echo "Split-FFI browser server did not become ready at $BASE_URL."
  cat "$SERVER_LOG"
  exit 1
fi

SMOKE_BASE_URL="$BASE_URL" \
SMOKE_NODE_MODULES="$LOCAL_NODE_MODULES" \
SMOKE_CHROME_EXECUTABLE="$CHROME_EXECUTABLE" \
SMOKE_TESTS="$(join_smoke_pages)" \
node "$SCRIPT_DIR/run-dom-headless.mjs"

echo "PASS split-ffi mixed-cache browser smoke"
echo "OUTPUT $RUN_ROOT"
