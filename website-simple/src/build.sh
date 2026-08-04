#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$ROOT_DIR/website-simple/local"
BASENAME="site"
WEB_EASY_SOURCE_BASENAME="web-easy-page"
WEB_EASY_BASENAME="web-easy"
RACKET_BIN="${WEBRACKET_RACKET:-/Applications/Racket v9.2.0.2/bin/racket}"
RACO_BIN="$(dirname "$RACKET_BIN")/raco"
MINISCHEME_RACKET_BIN="${WEBRACKET_MINISCHEME_RACKET:-/Applications/Racket v8.12/bin/racket}"
COMPILED_ROOT="$ROOT_DIR/website-simple/tmp/compiled"
MINISCHEME_COMPILED_ROOT="$ROOT_DIR/website-simple/tmp/minischeme-compiled"
DOC_HTML_ROOT="$ROOT_DIR/html/webracket"
DOC_OUT_DIR="$OUT_DIR/docs"
DOC_BUNDLE_DIR="$DOC_OUT_DIR/webracket"
MINISCHEME_SRC_DIR="$SCRIPT_DIR/examples/minischeme"
MINISCHEME_OUT_DIR="$OUT_DIR/examples/minischeme"
MINISCHEME_PROVIDER_CACHE="$ROOT_DIR/website-simple/tmp/minischeme-provider-cache"
MATHJAX_SRC_DIR="$SCRIPT_DIR/examples/mathjax"
MATHJAX_OUT_DIR="$OUT_DIR/examples/mathjax"
CANVAS_HEXAGONS_SRC_DIR="$SCRIPT_DIR/examples/canvas-hexagons"
CANVAS_HEXAGONS_OUT_DIR="$OUT_DIR/examples/canvas-hexagons"
SPACE_INVADERS_SRC_DIR="$SCRIPT_DIR/examples/space-invaders"
SPACE_INVADERS_OUT_DIR="$OUT_DIR/examples/space-invaders"
FORMULA1_SRC_DIR="$SCRIPT_DIR/examples/formula1"
FORMULA1_OUT_DIR="$OUT_DIR/examples/formula1"
MATRIX_RAIN_SRC_DIR="$SCRIPT_DIR/examples/matrix-rain"
MATRIX_RAIN_OUT_DIR="$OUT_DIR/examples/matrix-rain"
XTERMJS_DEMO_SRC_DIR="$SCRIPT_DIR/examples/xtermjs-demo"
XTERMJS_DEMO_OUT_DIR="$OUT_DIR/examples/xtermjs-demo"
JSXGRAPH_GALLERY_SRC_DIR="$SCRIPT_DIR/examples/jsxgraph-gallery"
JSXGRAPH_GALLERY_OUT_DIR="$OUT_DIR/examples/jsxgraph-gallery"
CONNECTIONS_SRC_DIR="$SCRIPT_DIR/examples/connections"
CONNECTIONS_OUT_DIR="$OUT_DIR/examples/connections"
WEB_EASY_EXAMPLES_SRC_DIR="$SCRIPT_DIR/examples/web-easy"
WEB_EASY_EXAMPLES_OUT_DIR="$OUT_DIR/web-easy-examples"

if [ ! -x "$RACKET_BIN" ]; then
  RACKET_BIN="racket"
  RACO_BIN="raco"
fi

if [ ! -x "$MINISCHEME_RACKET_BIN" ]; then
  MINISCHEME_RACKET_BIN="$RACKET_BIN"
fi

cd "$SCRIPT_DIR"
mkdir -p "$OUT_DIR"
mkdir -p "$COMPILED_ROOT"
mkdir -p "$MINISCHEME_COMPILED_ROOT"
mkdir -p "$OUT_DIR/assets"
mkdir -p "$DOC_OUT_DIR"
mkdir -p "$MINISCHEME_PROVIDER_CACHE"

cd "$ROOT_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACO_BIN" scribble --quiet --htmls --dest html pkgs/webracket-doc/scribblings/webracket.scrbl

rm -rf "$DOC_BUNDLE_DIR"
cp -R "$DOC_HTML_ROOT" "$DOC_OUT_DIR/"
cp -f "$SCRIPT_DIR/docs.css" "$DOC_BUNDLE_DIR/docs.css"
"$RACKET_BIN" "$SCRIPT_DIR/integrate-docs.rkt" "$DOC_BUNDLE_DIR"

rm -rf "$MINISCHEME_OUT_DIR"
mkdir -p "$MINISCHEME_OUT_DIR"
rm -f "$OUT_DIR/minischeme.html" "$OUT_DIR/web-site.wasm"
cd "$MINISCHEME_SRC_DIR"
PLTCOLLECTS="$SCRIPT_DIR/examples:$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$MINISCHEME_COMPILED_ROOT" \
"$MINISCHEME_RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --expander-read-provider \
  --provider-cache-dir "$MINISCHEME_PROVIDER_CACHE" \
  --dest "$MINISCHEME_OUT_DIR" \
  minischeme-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$MINISCHEME_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$MINISCHEME_OUT_DIR/site.css"
cp -f "$MINISCHEME_SRC_DIR/minischeme.css" "$MINISCHEME_OUT_DIR/minischeme.css"
mkdir -p "$MINISCHEME_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$MINISCHEME_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$MATHJAX_OUT_DIR"
mkdir -p "$MATHJAX_OUT_DIR"
cd "$MATHJAX_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$MATHJAX_OUT_DIR" \
  mathjax-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$MATHJAX_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$MATHJAX_OUT_DIR/site.css"
cp -f "$MATHJAX_SRC_DIR/mathjax.css" "$MATHJAX_OUT_DIR/mathjax.css"
mkdir -p "$MATHJAX_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$MATHJAX_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$CANVAS_HEXAGONS_OUT_DIR"
mkdir -p "$CANVAS_HEXAGONS_OUT_DIR"
cd "$CANVAS_HEXAGONS_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$CANVAS_HEXAGONS_OUT_DIR" \
  canvas-hexagons-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$CANVAS_HEXAGONS_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$CANVAS_HEXAGONS_OUT_DIR/site.css"
cp -f "$CANVAS_HEXAGONS_SRC_DIR/canvas-hexagons.css" "$CANVAS_HEXAGONS_OUT_DIR/canvas-hexagons.css"
mkdir -p "$CANVAS_HEXAGONS_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$CANVAS_HEXAGONS_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$SPACE_INVADERS_OUT_DIR"
mkdir -p "$SPACE_INVADERS_OUT_DIR"
cd "$SPACE_INVADERS_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$SPACE_INVADERS_OUT_DIR" \
  space-invaders-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$SPACE_INVADERS_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$SPACE_INVADERS_OUT_DIR/site.css"
cp -f "$SPACE_INVADERS_SRC_DIR/space-invaders.css" "$SPACE_INVADERS_OUT_DIR/space-invaders.css"
mkdir -p "$SPACE_INVADERS_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$SPACE_INVADERS_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$FORMULA1_OUT_DIR"
mkdir -p "$FORMULA1_OUT_DIR"
cd "$FORMULA1_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$FORMULA1_OUT_DIR" \
  formula1-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$FORMULA1_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$FORMULA1_OUT_DIR/site.css"
cp -f "$FORMULA1_SRC_DIR/formula1.css" "$FORMULA1_OUT_DIR/formula1.css"
mkdir -p "$FORMULA1_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$FORMULA1_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$MATRIX_RAIN_OUT_DIR"
mkdir -p "$MATRIX_RAIN_OUT_DIR"
cd "$MATRIX_RAIN_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$MATRIX_RAIN_OUT_DIR" \
  matrix-rain-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$MATRIX_RAIN_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$MATRIX_RAIN_OUT_DIR/site.css"
cp -f "$MATRIX_RAIN_SRC_DIR/matrix-rain.css" "$MATRIX_RAIN_OUT_DIR/matrix-rain.css"
mkdir -p "$MATRIX_RAIN_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$MATRIX_RAIN_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$XTERMJS_DEMO_OUT_DIR"
mkdir -p "$XTERMJS_DEMO_OUT_DIR"
cd "$XTERMJS_DEMO_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$XTERMJS_DEMO_OUT_DIR" \
  xtermjs-demo-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$XTERMJS_DEMO_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$XTERMJS_DEMO_OUT_DIR/site.css"
cp -f "$XTERMJS_DEMO_SRC_DIR/xtermjs-demo.css" "$XTERMJS_DEMO_OUT_DIR/xtermjs-demo.css"
mkdir -p "$XTERMJS_DEMO_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$XTERMJS_DEMO_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$JSXGRAPH_GALLERY_OUT_DIR"
mkdir -p "$JSXGRAPH_GALLERY_OUT_DIR"
cd "$JSXGRAPH_GALLERY_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$JSXGRAPH_GALLERY_OUT_DIR" \
  jsxgraph-gallery-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$JSXGRAPH_GALLERY_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$JSXGRAPH_GALLERY_OUT_DIR/site.css"
cp -f "$JSXGRAPH_GALLERY_SRC_DIR/jsxgraph-gallery.css" "$JSXGRAPH_GALLERY_OUT_DIR/jsxgraph-gallery.css"
mkdir -p "$JSXGRAPH_GALLERY_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$JSXGRAPH_GALLERY_OUT_DIR/assets/hex-racket-wasm-logo.svg"
mkdir -p "$JSXGRAPH_GALLERY_OUT_DIR/assets/vendor/jsxgraph"
cp -f "$ROOT_DIR/extras/jsxgraph/docs/static/jsxgraphcore.js" "$JSXGRAPH_GALLERY_OUT_DIR/assets/vendor/jsxgraph/jsxgraphcore.js"
cp -f "$ROOT_DIR/extras/jsxgraph/docs/static/jsxgraph.css" "$JSXGRAPH_GALLERY_OUT_DIR/assets/vendor/jsxgraph/jsxgraph.css"

rm -rf "$CONNECTIONS_OUT_DIR"
mkdir -p "$CONNECTIONS_OUT_DIR"
cd "$CONNECTIONS_SRC_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
  --browser \
  --dest "$CONNECTIONS_OUT_DIR" \
  connections-page.rkt
cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$CONNECTIONS_OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$CONNECTIONS_OUT_DIR/site.css"
cp -f "$CONNECTIONS_SRC_DIR/connections.css" "$CONNECTIONS_OUT_DIR/connections.css"
mkdir -p "$CONNECTIONS_OUT_DIR/assets"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$CONNECTIONS_OUT_DIR/assets/hex-racket-wasm-logo.svg"

rm -rf "$WEB_EASY_EXAMPLES_OUT_DIR"
mkdir -p "$WEB_EASY_EXAMPLES_OUT_DIR"

copy_web_easy_generated_example() {
  local example_name="$1"
  local generated_dir="$ROOT_DIR/pkgs/web-easy/examples/$example_name/generated"
  local target_dir="$WEB_EASY_EXAMPLES_OUT_DIR/$example_name"

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cp -R "$generated_dir/." "$target_dir/"
  find "$target_dir" -type f \( -name '*.map.sexp' -o -name '*.wasm.map.sexp' \) -delete
  cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$target_dir/web-easy-core.css"
  cp -f "$ROOT_DIR/pkgs/web-easy/themes/theme-light.css" "$target_dir/theme-light.css"
  cp -f "$target_dir/$example_name.html" "$target_dir/index.html"
}

copy_web_easy_generated_example "hello-world"
copy_web_easy_generated_example "a-single-counter"
copy_web_easy_generated_example "multiple-counters"
copy_web_easy_generated_example "dynamic-counters"
copy_web_easy_generated_example "add-two-numbers"
copy_web_easy_generated_example "todo-lists"
copy_web_easy_generated_example "rquery-helpers"
copy_web_easy_generated_example "rquery-counter"
copy_web_easy_generated_example "rquery-toggle"
copy_web_easy_generated_example "rquery-delegate-list"
copy_web_easy_generated_example "rquery-once"
copy_web_easy_generated_example "rquery-trigger"
copy_web_easy_generated_example "7gui-counter"
copy_web_easy_generated_example "7gui-temperature-converter"
copy_web_easy_generated_example "7gui-flight-booker"
copy_web_easy_generated_example "7gui-timer"
copy_web_easy_generated_example "7gui-crud"
copy_web_easy_generated_example "7gui-circle"
copy_web_easy_generated_example "7gui-circle-extended"
copy_web_easy_generated_example "pict-playground"
copy_web_easy_generated_example "pict-fish-school"
copy_web_easy_generated_example "pict-hungry-fish"
copy_web_easy_generated_example "audio-oscillator"
copy_web_easy_generated_example "audio-buffer-playback"
copy_web_easy_generated_example "audio-analyser"
copy_web_easy_generated_example "audio-effects"
copy_web_easy_generated_example "websocket"

printf '%s\n' \
  '<!DOCTYPE html>' \
  '<html lang="en">' \
  '<head>' \
  '  <meta charset="UTF-8">' \
  '  <meta http-equiv="refresh" content="0; url=../web-easy.html">' \
  '  <meta name="viewport" content="width=device-width, initial-scale=1">' \
  '  <title>web-easy</title>' \
  '</head>' \
  '<body>' \
  '  <p>Redirecting to <a href="../web-easy.html">web-easy</a>.</p>' \
  '</body>' \
  '</html>' \
  > "$WEB_EASY_EXAMPLES_OUT_DIR/index.html"

compile_web_easy_example() {
  local example_name="$1"
  local source_file="$2"
  local source_dir="$WEB_EASY_EXAMPLES_SRC_DIR/$example_name"
  local target_dir="$WEB_EASY_EXAMPLES_OUT_DIR/$example_name"

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  cd "$source_dir"
  PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
  PLTCOMPILEDROOTS="$COMPILED_ROOT" \
  "$RACKET_BIN" "$ROOT_DIR/webracket.rkt" \
    --browser \
    --dest "$target_dir" \
    "$source_file"
  cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$target_dir/web-easy-core.css"
  cp -f "$ROOT_DIR/pkgs/web-easy/themes/theme-light.css" "$target_dir/theme-light.css"
  cp -f "$target_dir/${source_file%.rkt}.html" "$target_dir/index.html"
}

compile_web_easy_example "hello-world" "hello-world.rkt"
compile_web_easy_example "a-single-counter" "a-single-counter.rkt"
compile_web_easy_example "multiple-counters" "multiple-counters.rkt"
compile_web_easy_example "dynamic-counters" "dynamic-counters.rkt"
compile_web_easy_example "add-two-numbers" "add-two-numbers.rkt"
compile_web_easy_example "todo-lists" "todo-lists.rkt"

for ext in html js wasm wasm.map.sexp wat; do
  rm -f "$OUT_DIR/$WEB_EASY_BASENAME.$ext" "$OUT_DIR/$WEB_EASY_SOURCE_BASENAME.$ext"
done

cd "$SCRIPT_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" --browser "$WEB_EASY_SOURCE_BASENAME.rkt"

for ext in html js wasm wasm.map.sexp wat; do
  src="$WEB_EASY_SOURCE_BASENAME.$ext"
  if [ -f "$src" ]; then
    if [ "$ext" = "html" ]; then
      mv -f "$src" "$OUT_DIR/$WEB_EASY_BASENAME.$ext"
    else
      mv -f "$src" "$OUT_DIR/$src"
    fi
  fi
done

for src in webracket-runtime-*.wasm webracket-runtime-*.wat \
           webracket-ffi-*.wasm webracket-ffi-*.wat; do
  if [ -f "$src" ]; then
    mv -f "$src" "$OUT_DIR/$src"
  fi
done

cd "$SCRIPT_DIR"
PLTCOLLECTS="$ROOT_DIR/pkgs${PLTCOLLECTS:+:$PLTCOLLECTS}:" \
PLTCOMPILEDROOTS="$COMPILED_ROOT" \
"$RACKET_BIN" "$ROOT_DIR/webracket.rkt" --browser "$BASENAME.rkt"

for ext in html js wasm wasm.map.sexp wat; do
  src="$BASENAME.$ext"
  if [ -f "$src" ]; then
    mv -f "$src" "$OUT_DIR/$src"
  fi
done

for src in webracket-runtime-*.wasm webracket-runtime-*.wat \
           webracket-ffi-*.wasm webracket-ffi-*.wat; do
  if [ -f "$src" ]; then
    mv -f "$src" "$OUT_DIR/$src"
  fi
done

cp -f "$ROOT_DIR/pkgs/web-easy/themes/web-easy-core.css" "$OUT_DIR/web-easy-core.css"
cp -f "$SCRIPT_DIR/site.css" "$OUT_DIR/site.css"
cp -f "$SCRIPT_DIR/web-easy.css" "$OUT_DIR/web-easy.css"
cp -f "$ROOT_DIR/web-site/src/assets/hex-racket-wasm-logo.svg" "$OUT_DIR/assets/hex-racket-wasm-logo.svg"

echo "compiled: $OUT_DIR/$BASENAME.html"
