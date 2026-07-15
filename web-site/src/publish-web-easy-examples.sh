#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_SITE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXAMPLES_DIR="${WEB_EASY_EXAMPLES_SOURCE_DIR:-${WEB_SITE_DIR}/../lib/web-easy/examples}"
PUBLISH_DIR="${WEB_EASY_EXAMPLES_PUBLISH_DIR:-${WEB_SITE_DIR}/public/web-easy-examples}"
INDEX_PAGE="${WEB_EASY_EXAMPLES_INDEX_PAGE:-${WEB_SITE_DIR}/public/web-easy-examples.html}"
REDIRECT_PAGE="${WEB_EASY_EXAMPLES_REDIRECT_PAGE:-${PUBLISH_DIR}/index.html}"
MAX_DRIFT_SECONDS="${MAX_DRIFT_SECONDS:-600}"

mtime() {
  local path="$1"
  if stat -f %m "$path" >/dev/null 2>&1; then
    stat -f %m "$path"
  else
    stat -c %Y "$path"
  fi
}

newest_mtime() {
  local newest=0
  local path
  for path in "$@"; do
    path_mtime="$(mtime "$path")"
    if (( path_mtime > newest )); then
      newest="$path_mtime"
    fi
  done
  echo "$newest"
}

echo "-- Publishing web-easy examples --"
rm -rf "$PUBLISH_DIR"
mkdir -p "$PUBLISH_DIR"

while IFS= read -r compile_sh; do
  example_dir="$(dirname "$compile_sh")"
  example_name="$(basename "$example_dir")"
  generated_dir="$example_dir/generated"
  target_dir="$PUBLISH_DIR/$example_name"

  if [[ ! -d "$generated_dir" ]]; then
    echo "Error: missing generated directory for $example_name: $generated_dir" >&2
    exit 1
  fi

  mapfile -t source_files < <(find "$example_dir" -maxdepth 1 -type f -name '*.rkt' | sort)
  if (( ${#source_files[@]} == 0 )); then
    echo "Error: missing source file for $example_name: expected at least one .rkt in $example_dir" >&2
    exit 1
  fi

  if [[ -f "$generated_dir/$example_name.html" ]]; then
    main_html="$generated_dir/$example_name.html"
  else
    mapfile -t generated_html_files < <(find "$generated_dir" -maxdepth 1 -type f -name '*.html' | sort)
    if (( ${#generated_html_files[@]} != 1 )); then
      echo "Error: expected one generated HTML for $example_name, found ${#generated_html_files[@]}" >&2
      echo "  generated dir: $generated_dir" >&2
      exit 1
    fi
    main_html="${generated_html_files[0]}"
  fi

  generated_base="$(basename "$main_html" .html)"
  main_wasm="$generated_dir/$generated_base.wasm"
  runtime_wasm="$generated_dir/$generated_base.runtime.wasm"

  if [[ ! -f "$main_wasm" ]]; then
    echo "Error: missing generated program wasm for $example_name: $main_wasm" >&2
    exit 1
  fi

  if [[ ! -f "$runtime_wasm" ]]; then
    echo "Error: missing generated split-runtime wasm for $example_name: $runtime_wasm" >&2
    exit 1
  fi

  if ! grep -Fq "$(basename "$main_wasm")" "$main_html"; then
    echo "Error: generated HTML for $example_name does not reference $(basename "$main_wasm")" >&2
    exit 1
  fi

  if ! grep -Fq "$(basename "$runtime_wasm")" "$main_html"; then
    echo "Error: generated HTML for $example_name does not reference $(basename "$runtime_wasm")" >&2
    exit 1
  fi

  source_mtime="$(newest_mtime "${source_files[@]}")"
  html_mtime="$(mtime "$main_html")"

  if (( source_mtime > html_mtime + MAX_DRIFT_SECONDS )); then
    echo "Error: stale generated output for $example_name" >&2
    echo "  source mtime:    $source_mtime" >&2
    echo "  generated: $main_html ($html_mtime)" >&2
    echo "  drift:    $((source_mtime - html_mtime))s (limit ${MAX_DRIFT_SECONDS}s)" >&2
    exit 1
  fi

  echo "Publishing $example_name"
  mkdir -p "$target_dir"
  cp -R "$generated_dir/." "$target_dir/"
  find "$target_dir" -type f \( -name '*.map.sexp' -o -name '*.wasm.map.sexp' \) -delete
  cp "$main_html" "$target_dir/index.html"
  cp "$main_html" "$target_dir/$example_name.html"
done < <(find "$EXAMPLES_DIR" -mindepth 2 -maxdepth 2 -name compile.sh | sort)

WEB_EASY_EXAMPLES_INDEX_PAGE="$INDEX_PAGE" \
WEB_EASY_EXAMPLES_REDIRECT_PAGE="$REDIRECT_PAGE" \
  bash "$SCRIPT_DIR/generate-web-easy-examples-page.sh"
echo "-- Done --"
