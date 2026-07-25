#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT="${SPLIT_RUNTIME_EXAMPLES_PORT:-10061}"
TIMEOUT_SEC="${SPLIT_RUNTIME_EXAMPLES_TIMEOUT_SEC:-720}"
RSS_LIMIT_MB="${SPLIT_RUNTIME_EXAMPLES_RSS_LIMIT_MB:-3500}"
RACKET_BIN="${RACKET:-racket}"
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN_ROOT="${SPLIT_RUNTIME_EXAMPLES_TMP:-$ROOT_DIR/tmp/split-runtime-examples}/$RUN_ID"
OUT_DIR="$RUN_ROOT/out"
COMPILED_ROOT="$RUN_ROOT/compiled-root"
PROVIDER_CACHE_DIR="$RUN_ROOT/provider-cache"
RUNTIME_PROVIDER_CACHE_DIR="$RUN_ROOT/runtime-provider-cache"
SERVER_LOG="$RUN_ROOT/server.log"
RUN_LOG="$RUN_ROOT/runner.log"
LOCAL_NODE_MODULES="${DOM_HEADLESS_NODE_MODULES:-$ROOT_DIR/.local-tools/node_modules}"
CHROME_EXECUTABLE="${DOM_HEADLESS_EXECUTABLE:-}"
PLAYWRIGHT_CACHE_ROOT="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/Library/Caches/ms-playwright}"
BASE_URL=""
CASE_PASS=collect
LIST_CASES=0
AUDIT_COVERAGE=0
ONLY_CASES=()
SKIP_CASES=()
GROUP_CASES=()
CHUNK_INDEX=0
CHUNK_COUNT=0
CANDIDATE_CASES=0
SELECTED_CASES=0
ALL_CASE_IDS=()
ALL_CASE_DIRS=()
ALL_GROUPS=()
SMOKE_PAGES=()
GLOBAL_EXTRA_ARGS=()

if [ -n "${SPLIT_RUNTIME_EXAMPLES_EXTRA_ARGS:-}" ]; then
  read -r -a GLOBAL_EXTRA_ARGS <<<"$SPLIT_RUNTIME_EXAMPLES_EXTRA_ARGS"
fi

case "$RACKET_BIN" in
  */*)
    if [[ "$RACKET_BIN" != /* ]]; then
      RACKET_BIN="$ROOT_DIR/$RACKET_BIN"
    fi
    ;;
esac

usage() {
  cat <<'USAGE'
Usage: tools/check-split-runtime-examples.sh [options]

Options:
  --list-cases         List available example cases and exit.
  --audit-coverage     Check that compileable example directories are registered.
  --only ID            Run only the named case; repeatable.
  --skip ID            Skip the named case; repeatable.
  --group GROUP        Run cases in the named group; repeatable.
  --chunk N/M          Run chunk N of M after other selectors.
  --help               Show this help.

Environment:
  SPLIT_RUNTIME_EXAMPLES_EXTRA_ARGS
                       Extra webracket.rkt compiler flags for every case.
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

parse_chunk_spec() {
  local spec="$1"
  if [[ ! "$spec" =~ ^([0-9]+)/([0-9]+)$ ]]; then
    echo "Invalid chunk spec: $spec" >&2
    echo "Expected N/M, for example 1/4." >&2
    exit 2
  fi
  CHUNK_INDEX="${BASH_REMATCH[1]}"
  CHUNK_COUNT="${BASH_REMATCH[2]}"
  if [ "$CHUNK_INDEX" -lt 1 ] || [ "$CHUNK_COUNT" -lt 1 ] || [ "$CHUNK_INDEX" -gt "$CHUNK_COUNT" ]; then
    echo "Invalid chunk spec: $spec" >&2
    echo "Expected 1 <= N <= M." >&2
    exit 2
  fi
}

if [ -n "${SPLIT_RUNTIME_EXAMPLES_CHUNK:-}" ]; then
  parse_chunk_spec "$SPLIT_RUNTIME_EXAMPLES_CHUNK"
fi

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
    --audit-coverage)
      AUDIT_COVERAGE=1
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
    --skip)
      if [ "$#" -lt 2 ]; then
        echo "--skip requires a case id." >&2
        exit 2
      fi
      SKIP_CASES+=("$2")
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
    --chunk)
      if [ "$#" -lt 2 ]; then
        echo "--chunk requires N/M." >&2
        exit 2
      fi
      parse_chunk_spec "$2"
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
: >"$RUN_LOG"
exec > >(tee -a "$RUN_LOG") 2>&1

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

  if contains_value "$id" "${SKIP_CASES[@]}"; then
    return 1
  fi
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

case_selected_for_run() {
  local id="$1"
  shift
  local groups=("$@")

  if ! selector_matches "$id" "${groups[@]}"; then
    return 1
  fi

  CANDIDATE_CASES=$((CANDIDATE_CASES + 1))
  if [ "$CHUNK_COUNT" -gt 0 ]; then
    local offset=$((CHUNK_INDEX - 1))
    local candidate_offset=$(((CANDIDATE_CASES - 1) % CHUNK_COUNT))
    if [ "$candidate_offset" -ne "$offset" ]; then
      return 1
    fi
  fi

  return 0
}

copy_web_easy_assets() {
  local dest="$1"
  cp -f "$ROOT_DIR/lib/web-easy/themes/web-easy-core.css" "$dest/web-easy-core.css"
  cp -f "$ROOT_DIR/lib/web-easy/themes/theme-light.css" "$dest/theme-light.css"
}

copy_case_assets() {
  local source="$1"
  local dest="$2"

  case "$source" in
    examples/pict/*)
      mkdir -p "$OUT_DIR/assets"
      cp -R "$ROOT_DIR/examples/pict/assets/." "$OUT_DIR/assets/"
      ;;
    lib/web-easy/examples/web-workers/*)
      cp -f "$ROOT_DIR/lib/web-easy/examples/web-workers/worker.js" "$dest/worker.js"
      ;;
  esac
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
  local extra_args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --host-file|--wasm-file|--wat-file)
        if [ "$#" -lt 2 ]; then
          echo "$1 requires a filename." >&2
          exit 2
        fi
        if [[ "$2" = /* ]]; then
          extra_args+=("$1" "$2")
        else
          extra_args+=("$1" "$dest/$2")
        fi
        shift 2
        ;;
      *)
        extra_args+=("$1")
        shift
        ;;
    esac
  done
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
        "$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
          --browser \
          --dest "$dest" \
          --provider-cache-dir "$PROVIDER_CACHE_DIR" \
          --runtime-provider-cache-dir "$RUNTIME_PROVIDER_CACHE_DIR" \
          "${GLOBAL_EXTRA_ARGS[@]}" \
          "${extra_args[@]}" \
          "$source_file"
  )
  if [ "$web_easy" = "1" ]; then
    copy_web_easy_assets "$dest"
  fi
  copy_case_assets "$source" "$dest"
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
      local source_dir
      source_dir="$(dirname "$source")"
      if ! contains_value "$source_dir" "${ALL_CASE_DIRS[@]}"; then
        ALL_CASE_DIRS+=("$source_dir")
      fi
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
      if case_selected_for_run "$id" "${groups[@]}"; then
        SELECTED_CASES=$((SELECTED_CASES + 1))
        compile_case "$id" "$source" "$page" "$web_easy" "$@"
        SMOKE_PAGES+=("$id/$page")
      fi
      ;;
  esac
}

register_cases() {
  handle_case examples-clipboard examples,top,dom,clipboard \
    examples/clipboard/clipboard-demo.rkt clipboard-demo.html 0
  handle_case examples-hello-world-dom examples,top,dom \
    examples/hello-world-2/hello-world.rkt hello-world.html 0
  handle_case examples-hello-world-3 examples,top,dom \
    examples/hello-world-3/hello-world-3.rkt hello-world-3.html 0
  handle_case examples-console-bridge examples,top,console-bridge \
    examples/console-bridge/console-bridge.rkt console-bridge.html 0 \
    --console-bridge
  handle_case examples-mathjax4 examples,top,dom,external \
    examples/mathjax4/mathjax.rkt mathjax.html 0
  handle_case examples-matrix-rain examples,top,dom,canvas \
    examples/matrix-rain/matrix-rain.rkt matrix-rain.html 0
  handle_case examples-minischeme examples,top,dom,web-easy,minischeme \
    examples/minischeme/minischeme-page.rkt minischeme-page.html 1 \
    --expander-read-provider
  handle_case examples-pict examples,top,dom,pict,assets \
    examples/pict/pict.rkt pict.html 0
  handle_case examples-raco examples,top,dom,canvas \
    examples/raco/tiles.rkt tiles.html 0
  handle_case examples-snake examples,top,dom,game,canvas \
    examples/snake/snake.rkt snake.html 0
  handle_case examples-snake2 examples,top,dom,game,canvas \
    examples/snake2/snake2.rkt snake2.html 0
  handle_case examples-space-invaders examples,top,dom,game,canvas \
    examples/space-invaders/space-invaders.rkt space-invaders.html 0
  handle_case examples-xtermjs-demo examples,top,dom,xtermjs,external \
    examples/xtermjs-demo/xtermjs-demo.rkt xtermjs-demo.html 0

  handle_case webeasy-7gui-circle examples,web-easy,dom,7gui \
    lib/web-easy/examples/7gui-circle/7gui-circle.rkt 7gui-circle.html 1 \
    --ffi dom
  handle_case webeasy-7gui-circle-extended examples,web-easy,dom,7gui \
    lib/web-easy/examples/7gui-circle-extended/7gui-circle-extended.rkt 7gui-circle-extended.html 1 \
    --ffi dom
  handle_case webeasy-hello-world examples,web-easy,dom \
    lib/web-easy/examples/hello-world/hello-world.rkt hello-world.html 1 \
    --ffi dom
  handle_case webeasy-7gui-counter examples,web-easy,dom,7gui,js \
    lib/web-easy/examples/7gui-counter/7gui-counter.rkt 7gui-counter.html 1 \
    --ffi dom \
    --ffi js
  handle_case webeasy-7gui-crud examples,web-easy,dom,7gui \
    lib/web-easy/examples/7gui-crud/7gui-crud.rkt 7gui-crud.html 1 \
    --ffi dom
  handle_case webeasy-7gui-flight-booker examples,web-easy,dom,7gui \
    lib/web-easy/examples/7gui-flight-booker/7gui-flight-booker.rkt 7gui-flight-booker.html 1 \
    --ffi dom
  handle_case webeasy-7gui-temperature-converter examples,web-easy,dom,7gui \
    lib/web-easy/examples/7gui-temperature-converter/7gui-temperature-converter.rkt 7gui-temperature-converter.html 1 \
    --ffi dom
  handle_case webeasy-7gui-timer examples,web-easy,dom,7gui \
    lib/web-easy/examples/7gui-timer/7gui-timer.rkt 7gui-timer.html 1 \
    --ffi dom
  handle_case webeasy-a-single-counter examples,web-easy,dom \
    lib/web-easy/examples/a-single-counter/a-single-counter.rkt a-single-counter.html 1 \
    --ffi dom
  handle_case webeasy-add-two-numbers examples,web-easy,dom \
    lib/web-easy/examples/add-two-numbers/add-two-numbers.rkt add-two-numbers.html 1 \
    --ffi dom
  handle_case webeasy-audio-analyser examples,web-easy,dom,audio \
    lib/web-easy/examples/audio-analyser/audio-analyser.rkt audio-analyser.html 1 \
    --ffi dom \
    --ffi audio
  handle_case webeasy-audio-buffer-playback examples,web-easy,dom,audio \
    lib/web-easy/examples/audio-buffer-playback/audio-buffer-playback.rkt audio-buffer-playback.html 1 \
    --ffi dom \
    --ffi audio
  handle_case webeasy-audio-effects examples,web-easy,dom,audio \
    lib/web-easy/examples/audio-effects/audio-effects.rkt audio-effects.html 1 \
    --ffi dom \
    --ffi audio
  handle_case webeasy-audio-oscillator examples,web-easy,dom,audio \
    lib/web-easy/examples/audio-oscillator/audio-oscillator.rkt audio-oscillator.html 1 \
    --ffi dom \
    --ffi audio
  handle_case webeasy-compression-streams examples,web-easy,dom,browser-api \
    lib/web-easy/examples/compression-streams/app.rkt app.html 1
  handle_case webeasy-dynamic-counters examples,web-easy,dom \
    lib/web-easy/examples/dynamic-counters/dynamic-counters.rkt dynamic-counters.html 1 \
    --ffi dom
  handle_case webeasy-fetch examples,web-easy,dom,browser-api \
    lib/web-easy/examples/fetch/fetch.rkt fetch.html 1 \
    --ffi dom
  handle_case webeasy-fullscreen examples,web-easy,dom,browser-api \
    lib/web-easy/examples/fullscreen/app.rkt app.html 1
  handle_case webeasy-gamepad examples,web-easy,dom,browser-api \
    lib/web-easy/examples/gamepad/app.rkt app.html 1
  handle_case webeasy-geolocation examples,web-easy,dom,browser-api \
    lib/web-easy/examples/geolocation/app.rkt geolocation.html 1 \
    --host-file geolocation.html \
    --wasm-file geolocation.wasm \
    --wat-file geolocation.wat
  handle_case webeasy-history examples,web-easy,dom,browser-api \
    lib/web-easy/examples/history/app.rkt app.html 1
  handle_case webeasy-indexed-db examples,web-easy,dom,browser-api \
    lib/web-easy/examples/indexed-db/indexed-db.rkt indexed-db.html 1 \
    --ffi dom
  handle_case webeasy-intersection-observer examples,web-easy,dom,browser-api \
    lib/web-easy/examples/intersection-observer/app.rkt intersection-observer.html 1 \
    --host-file intersection-observer.html \
    --wasm-file intersection-observer.wasm \
    --wat-file intersection-observer.wat
  handle_case webeasy-jsx-graph-gallery examples,web-easy,dom,jsxgraph \
    lib/web-easy/examples/jsx-graph-gallery/jsx-graph-gallery.rkt jsx-graph-gallery.html 1 \
    --ffi dom \
    --ffi jsxgraph
  handle_case webeasy-multiple-counters examples,web-easy,dom \
    lib/web-easy/examples/multiple-counters/multiple-counters.rkt multiple-counters.html 1 \
    --ffi dom
  handle_case webeasy-notifications examples,web-easy,dom,browser-api \
    lib/web-easy/examples/notifications/app.rkt notifications.html 1 \
    --host-file notifications.html \
    --wasm-file notifications.wasm \
    --wat-file notifications.wat
  handle_case webeasy-pict-fish-school examples,web-easy,dom,pict \
    lib/web-easy/examples/pict-fish-school/pict-fish-school.rkt pict-fish-school.html 1 \
    --ffi dom
  handle_case webeasy-pict-hungry-fish examples,web-easy,dom,pict \
    lib/web-easy/examples/pict-hungry-fish/pict-hungry-fish.rkt pict-hungry-fish.html 1 \
    --ffi dom
  handle_case webeasy-pict-playground examples,web-easy,dom,pict \
    lib/web-easy/examples/pict-playground/pict-playground.rkt pict-playground.html 1 \
    --ffi dom
  handle_case webeasy-resize-observer examples,web-easy,dom,browser-api \
    lib/web-easy/examples/resize-observer/app.rkt resize-observer.html 1 \
    --host-file resize-observer.html \
    --wasm-file resize-observer.wasm \
    --wat-file resize-observer.wat
  handle_case webeasy-rquery-counter examples,web-easy,dom,rquery \
    lib/web-easy/examples/rquery-counter/rquery-counter.rkt rquery-counter.html 1 \
    --ffi dom
  handle_case webeasy-rquery-delegate-list examples,web-easy,dom,rquery \
    lib/web-easy/examples/rquery-delegate-list/rquery-delegate-list.rkt rquery-delegate-list.html 1 \
    --ffi dom
  handle_case webeasy-rquery-helpers examples,web-easy,dom,rquery \
    lib/web-easy/examples/rquery-helpers/rquery-helpers.rkt rquery-helpers.html 1 \
    --ffi dom
  handle_case webeasy-rquery-once examples,web-easy,dom,rquery \
    lib/web-easy/examples/rquery-once/rquery-once.rkt rquery-once.html 1 \
    --ffi dom
  handle_case webeasy-rquery-toggle examples,web-easy,dom,rquery \
    lib/web-easy/examples/rquery-toggle/rquery-toggle.rkt rquery-toggle.html 1 \
    --ffi dom
  handle_case webeasy-rquery-trigger examples,web-easy,dom,rquery \
    lib/web-easy/examples/rquery-trigger/rquery-trigger.rkt rquery-trigger.html 1 \
    --ffi dom
  handle_case webeasy-screen-orientation examples,web-easy,dom,browser-api \
    lib/web-easy/examples/screen-orientation/app.rkt app.html 1
  handle_case webeasy-storage examples,web-easy,dom,browser-api \
    lib/web-easy/examples/storage/storage.rkt storage.html 1 \
    --ffi dom
  handle_case webeasy-todo-lists examples,web-easy,dom \
    lib/web-easy/examples/todo-lists/todo-lists.rkt todo-lists.html 1 \
    --ffi dom
  handle_case webeasy-web-speech examples,web-easy,dom,browser-api \
    lib/web-easy/examples/web-speech/app.rkt app.html 1
  handle_case webeasy-web-workers examples,web-easy,dom,browser-api,assets \
    lib/web-easy/examples/web-workers/app.rkt app.html 1
  handle_case webeasy-websocket examples,web-easy,dom,websocket \
    lib/web-easy/examples/websocket/websocket.rkt websocket.html 1 \
    --ffi dom \
    --ffi websocket
}

validate_selectors() {
  local id
  for id in "${ONLY_CASES[@]}"; do
    if ! contains_value "$id" "${ALL_CASE_IDS[@]}"; then
      echo "Unknown split-runtime example case id: $id" >&2
      exit 2
    fi
  done
  for id in "${SKIP_CASES[@]}"; do
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

audit_coverage() {
  local missing=0
  local compile_sh
  local dir

  while IFS= read -r compile_sh; do
    dir="${compile_sh#$ROOT_DIR/}"
    dir="${dir%/compile.sh}"
    case "$dir" in
      examples/hello-world-1)
        continue
        ;;
    esac
    if ! contains_value "$dir" "${ALL_CASE_DIRS[@]}"; then
      echo "Missing split-runtime example case for $dir" >&2
      missing=1
    fi
  done < <(find "$ROOT_DIR/examples" "$ROOT_DIR/lib/web-easy/examples" \
            -mindepth 2 \
            -maxdepth 2 \
            -name compile.sh \
            | sort)

  if [ "$missing" -ne 0 ]; then
    exit 1
  fi
  echo "PASS split-runtime example coverage audit"
  echo "Registered case directories: ${#ALL_CASE_DIRS[@]}"
}

register_cases
validate_selectors

if [ "$AUDIT_COVERAGE" -eq 1 ]; then
  audit_coverage
  exit 0
fi

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
if [ "$CHUNK_COUNT" -gt 0 ]; then
  echo "Chunk: $CHUNK_INDEX/$CHUNK_COUNT from $CANDIDATE_CASES matching cases"
fi

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
