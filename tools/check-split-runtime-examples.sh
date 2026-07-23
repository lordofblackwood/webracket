#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT="${SPLIT_RUNTIME_EXAMPLES_PORT:-10061}"
TIMEOUT_SEC="${SPLIT_RUNTIME_EXAMPLES_TIMEOUT_SEC:-720}"
RSS_LIMIT_MB="${SPLIT_RUNTIME_EXAMPLES_RSS_LIMIT_MB:-3500}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN_ROOT="${SPLIT_RUNTIME_EXAMPLES_TMP:-$ROOT_DIR/tmp/split-runtime-examples}/$RUN_ID"
OUT_DIR="$RUN_ROOT/out"
COMPILED_ROOT="$RUN_ROOT/compiled-root"
PROVIDER_CACHE_DIR="$RUN_ROOT/provider-cache"
RUNTIME_PROVIDER_CACHE_DIR="$RUN_ROOT/runtime-provider-cache"
SERVER_LOG="$RUN_ROOT/server.log"
LOCAL_NODE_MODULES="${DOM_HEADLESS_NODE_MODULES:-$ROOT_DIR/.local-tools/node_modules}"
CHROME_EXECUTABLE="${DOM_HEADLESS_EXECUTABLE:-}"
PLAYWRIGHT_CACHE_ROOT="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/Library/Caches/ms-playwright}"
BASE_URL=""
CASE_PASS=collect
LIST_CASES=0
ONLY_CASES=()
GROUP_CASES=()
SELECTED_CASES=0
ALL_CASE_IDS=()
ALL_GROUPS=()
SMOKE_PAGES=()

usage() {
  cat <<'USAGE'
Usage: tools/check-split-runtime-examples.sh [options]

Options:
  --list-cases         List available example cases and exit.
  --only ID            Run only the named case; repeatable.
  --group GROUP        Run cases in the named group; repeatable.
  --help               Show this help.
USAGE
}

contains_value() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    if [ "$value" = "$needle" ]; then
      return 0
    fi
  done
  return 1
}

join_by_comma() {
  local IFS=,
  echo "$*"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --list-cases)
      LIST_CASES=1
      shift
      ;;
    --only)
      if [ "$#" -lt 2 ]; then
        echo "--only requires a case id." >&2
        exit 2
      fi
      ONLY_CASES+=("$2")
      shift 2
      ;;
    --group)
      if [ "$#" -lt 2 ]; then
        echo "--group requires a group name." >&2
        exit 2
      fi
      GROUP_CASES+=("$2")
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

mkdir -p "$OUT_DIR" "$COMPILED_ROOT" "$PROVIDER_CACHE_DIR" "$RUNTIME_PROVIDER_CACHE_DIR"

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

remember_group() {
  local group="$1"
  if ! contains_value "$group" "${ALL_GROUPS[@]}"; then
    ALL_GROUPS+=("$group")
  fi
}

selector_matches() {
  local id="$1"
  shift
  local groups=("$@")
  local group

  if [ "${#ONLY_CASES[@]}" -eq 0 ] && [ "${#GROUP_CASES[@]}" -eq 0 ]; then
    return 0
  fi
  if contains_value "$id" "${ONLY_CASES[@]}"; then
    return 0
  fi
  for group in "${groups[@]}"; do
    if contains_value "$group" "${GROUP_CASES[@]}"; then
      return 0
    fi
  done
  return 1
}

copy_web_easy_assets() {
  local dest="$1"
  cp -f "$ROOT_DIR/lib/web-easy/themes/web-easy-core.css" "$dest/web-easy-core.css"
  cp -f "$ROOT_DIR/lib/web-easy/themes/theme-light.css" "$dest/theme-light.css"
}

compile_case() {
  local id="$1"
  local source="$2"
  local page="$3"
  local web_easy="$4"
  shift 4
  local dest="$OUT_DIR/$id"
  local source_path="$ROOT_DIR/$source"
  local source_dir
  source_dir="$(dirname "$source_path")"
  local source_file
  source_file="$(basename "$source_path")"
  mkdir -p "$dest"
  echo "START split-runtime example compile $id"
  (
    cd "$source_dir"
    python3 "$ROOT_DIR/tools/run-guarded.py" \
      --timeout-sec "$TIMEOUT_SEC" \
      --rss-limit-mb "$RSS_LIMIT_MB" \
      -- \
      /usr/bin/env \
        "PLTCOLLECTS=$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
        "PLTCOMPILEDROOTS=$COMPILED_ROOT" \
        racket "$ROOT_DIR/webracket.rkt" \
          --browser \
          --dest "$dest" \
          --provider-cache-dir "$PROVIDER_CACHE_DIR" \
          --runtime-provider-cache-dir "$RUNTIME_PROVIDER_CACHE_DIR" \
          "$@" \
          "$source_file"
  )
  if [ "$web_easy" = "1" ]; then
    copy_web_easy_assets "$dest"
  fi
  if [ ! -f "$dest/$page" ]; then
    echo "Missing generated page: $dest/$page" >&2
    exit 1
  fi
  if [ ! -f "$dest/${page%.html}.wasm" ]; then
    echo "Missing generated wasm: $dest/${page%.html}.wasm" >&2
    exit 1
  fi
  if [ ! -f "$dest/${page%.html}.runtime.wasm" ]; then
    echo "Missing split runtime sidecar: $dest/${page%.html}.runtime.wasm" >&2
    exit 1
  fi
  echo "PASS split-runtime example compile $id"
}

handle_case() {
  local id="$1"
  local groups_csv="$2"
  local source="$3"
  local page="$4"
  local web_easy="$5"
  shift 5
  local groups=()
  IFS=, read -r -a groups <<<"$groups_csv"

  case "$CASE_PASS" in
    collect)
      ALL_CASE_IDS+=("$id")
      local group
      for group in "${groups[@]}"; do
        remember_group "$group"
      done
      if [ "$LIST_CASES" -eq 1 ]; then
        printf "%s\tgroups=%s\tpage=%s\tsource=%s\n" \
          "$id" \
          "$groups_csv" \
          "$page" \
          "$source"
      fi
      ;;
    run)
      if selector_matches "$id" "${groups[@]}"; then
        SELECTED_CASES=$((SELECTED_CASES + 1))
        compile_case "$id" "$source" "$page" "$web_easy" "$@"
        SMOKE_PAGES+=("$id/$page")
      fi
      ;;
  esac
}

register_cases() {
  handle_case examples-hello-world-dom examples,top,dom \
    examples/hello-world-2/hello-world.rkt hello-world.html 0
  handle_case examples-console-bridge examples,top,console-bridge \
    examples/console-bridge/console-bridge.rkt console-bridge.html 0 \
    --console-bridge
  handle_case webeasy-hello-world examples,web-easy,dom \
    lib/web-easy/examples/hello-world/hello-world.rkt hello-world.html 1 \
    --ffi dom
  handle_case webeasy-7gui-counter examples,web-easy,dom,js \
    lib/web-easy/examples/7gui-counter/7gui-counter.rkt 7gui-counter.html 1 \
    --ffi dom \
    --ffi js
}

validate_selectors() {
  local id
  for id in "${ONLY_CASES[@]}"; do
    if ! contains_value "$id" "${ALL_CASE_IDS[@]}"; then
      echo "Unknown split-runtime example case id: $id" >&2
      exit 2
    fi
  done

  local group
  for group in "${GROUP_CASES[@]}"; do
    if ! contains_value "$group" "${ALL_GROUPS[@]}"; then
      echo "Unknown split-runtime example group: $group" >&2
      echo "Known groups: $(join_by_comma "${ALL_GROUPS[@]}")" >&2
      exit 2
    fi
  done
}

register_cases
validate_selectors

if [ "$LIST_CASES" -eq 1 ]; then
  echo "Total cases: ${#ALL_CASE_IDS[@]}"
  echo "Groups: $(join_by_comma "${ALL_GROUPS[@]}")"
  exit 0
fi

CASE_PASS=run
register_cases

if [ "$SELECTED_CASES" -eq 0 ]; then
  echo "No split-runtime example cases selected." >&2
  exit 1
fi

echo "Selected split-runtime example cases: $SELECTED_CASES"

if ! command -v node >/dev/null 2>&1; then
  echo "node is required for the browser example runner."
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to serve split-runtime examples."
  exit 2
fi

SERVER_PID=""
for candidate in "$PORT" 10062 10063 10064 10065 10066 10067 10068 10069; do
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
  echo "Split-runtime example server failed to bind an available port."
  cat "$SERVER_LOG"
  exit 1
fi

READY_PAGE="${SMOKE_PAGES[0]}"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if curl -sf "$BASE_URL/$READY_PAGE" >/dev/null; then
    break
  fi
  sleep 1
done

if ! curl -sf "$BASE_URL/$READY_PAGE" >/dev/null; then
  echo "Split-runtime example server did not become ready at $BASE_URL."
  cat "$SERVER_LOG"
  exit 1
fi

SMOKE_BASE_URL="$BASE_URL" \
SMOKE_NODE_MODULES="$LOCAL_NODE_MODULES" \
SMOKE_CHROME_EXECUTABLE="$CHROME_EXECUTABLE" \
SMOKE_TESTS="$(join_by_comma "${SMOKE_PAGES[@]}")" \
node "$ROOT_DIR/tools/check-browser-pages-load.mjs"

echo "PASS split-runtime example smoke"
echo "OUTPUT $RUN_ROOT"
