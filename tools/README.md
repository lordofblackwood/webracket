Tools
=====

This folder holds various useful tools.

For now, there are a few tools here.


pretty.rkt
----------
Reads s-expressions from an input port and pretty-prints to an output port.


check-docs-standard.py
----------------------
Checks consistency for:
- `DOCS-standard.md` against `ffi/standard.ffi`
- `DOCS-dom.md` against `ffi/dom.ffi`
- `DOCS-js.md` against `ffi/js.ffi`
- `DOCS-math.md` against `ffi/math.ffi`
- `DOCS-jsxgraph.md` against `ffi/jsxgraph.ffi`
- `DOCS-xtermjs.md` against `ffi/xtermjs.ffi`
- `DOCS-websocket.md` against `ffi/websocket.ffi`

Per document, it validates that:
- documented table functions exist in the corresponding `.ffi`
- table function names link to an allowed docs source for that file
- there are no duplicate table function rows
- Table of Contents links cover all `##`/`###` sections
- coverage count matches documented table rows
- documented table rows match all non-legacy `define-foreign` entries

Run:

```
python3 tools/check-docs-standard.py
```

check-wrapper-arity.rkt
-----------------------
Scans `.rkt` files and reports wrapper calls with wrong arity.
Current checks:
- `with-class` must have 2 arguments
- `with-id` must have 2 arguments
- `with-attrs` must have 2 arguments

Useful for catching parenthesis drift where a wrapper accidentally swallows
many following forms (runtime symptom: arity mismatch with large `given` count).

Run:

```sh
racket tools/check-wrapper-arity.rkt lib/web-easy/smoke
```

find-callback-source.rkt
------------------------
Looks up a generated callback/debug label such as `label.4054` in a
`.wasm.map.sexp` file and prints the recorded source location.

By default it prints:
- label
- source path with line and column
- span
- `same-as` target when present

Optional:
- `--show-form` prints the recorded source form when the map includes it

Run:

```sh
racket tools/find-callback-source.rkt test/test-ffi.wasm.map.sexp label.5792
```

With the recorded form:

```sh
racket tools/find-callback-source.rkt --show-form test/test-ffi.wasm.map.sexp label.5792
```

check-treelist-shape-smoke.rkt
------------------------------
Runs the compiler-private treelist shape smoke and validates representative
treelist workloads. This uses the internal `--internal-bind-treelist-debug-shape`
flag, but does not expose any normal WebRacket binding.

It exits `0` when all audited shapes validate and the key shape expectations
still hold, and non-zero on failure.

Run:

```sh
racket tools/check-treelist-shape-smoke.rkt
```

Make target:

```sh
make smoke-treelist-shape
```

measure-simplify-module-builds.rkt
----------------------------------
Compiles representative module examples with and without `--enable-simplify`,
warming each mode once before collecting the measured run. It uses one pinned
Racket toolchain per invocation plus an isolated `PLTCOMPILEDROOTS`, and
prints a compact comparison for:
- `driver total`
- `compile-pipeline`
- `parse-nodes`
- `simplified-nodes`
- `nodes-removed`
- `simplify-LFE`
- `lower-letrec-values`
- `closure-conversion`
- `generate-code`
- `free-var-summary-root-ms`

By default it measures:
- `hello-world`
- `single-counter`

You can also pass explicit example paths:

```sh
racket tools/measure-simplify-module-builds.rkt \
  pkgs/web-easy/examples/hello-world/hello-world.rkt \
  pkgs/web-easy/examples/todo-lists/todo-lists.rkt
```

Optional:

- `--tsv` emits baseline, simplify, and delta rows in TSV form

Example:

```sh
racket tools/measure-simplify-module-builds.rkt \
  --tsv \
  pkgs/web-easy/examples/hello-world/hello-world.rkt
```

measure-split-runtime.rkt
-------------------------
Benchmarks the experimental `--split-runtime` path against monolithic output on
a tiny no-stdlib Node program. It uses private provider/runtime caches, runs a
cold split compile to populate the stable runtime cache, then compares
monolithic and warm split compile/run timings. The tool exits non-zero if the
compiled program does not run or if the warm split run does not use the cached
runtime wasm.

Run:

```sh
racket -S pkgs tools/measure-split-runtime.rkt
```

Optional:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --source test/test-trivial.rkt \
  --expect '(^|\n)42(\n|$)'
```

Use `--include-cache-reference` to also measure Node output generated with
`--split-runtime-cache-reference`, where warm runs read the cached runtime wasm
directly instead of materializing a sidecar next to the program.

prewarm-staged-providers.rkt
----------------------------
Prebuilds cache artifacts before an example compile needs them. Existing modes
prewarm staged provider artifacts such as regexp and expander/read. The
`split-runtime` mode compiles and runs a tiny no-stdlib split-runtime program
through the normal driver so the stable runtime wasm is already in the runtime
provider cache before a real user program compile.

Run:

```sh
racket -S pkgs tools/prewarm-staged-providers.rkt \
  --provider-cache-dir /tmp/webracket-provider-cache \
  --runtime-provider-cache-dir /tmp/webracket-runtime-cache \
  --mode split-runtime
```

fetch-html-element-attributes.mjs
---------------------------------
Generator for a machine-readable HTML element/attribute snapshot.
It fetches the `html-element-attributes` package source and writes:
- `lib/web-easy/generated/html-element-attributes.json`
- `lib/web-easy/spec/html-element-attributes.sexp`

Deprecated/obsolete tags are filtered out of the committed snapshot:
`applet`, `basefont`, `dir`, `font`, `frame`, `frameset`, `isindex`, `param`.

Inputs:
- package version (`--version`, default `3.1.0`)
- source URL (optional override via `--source-url`)

Output paths:
- JSON snapshot: `lib/web-easy/generated/html-element-attributes.json`
- S-expression snapshot: `lib/web-easy/spec/html-element-attributes.sexp`

Refresh command (pinned/default version):

```sh
node tools/fetch-html-element-attributes.mjs --version 3.1.0
```

Optional explicit outputs:

```sh
node tools/fetch-html-element-attributes.mjs \
  --version 3.1.0 \
  --out-json lib/web-easy/generated/html-element-attributes.json \
  --out-sexp lib/web-easy/spec/html-element-attributes.sexp
```

thematic
--------
Launcher for Thematic 2000. It runs the implementation in
`thematic/main.rkt`.

Thematic generates a starter `web-easy` external theme from Bootstrap custom
properties. It reads one selector from a Bootstrap stylesheet, maps `--bs-*`
tokens into a small theme model, derives companion `--we-*` tokens, and emits
a complete starter stylesheet using the existing light theme structure.

Inputs:
- Bootstrap CSS file (`--input`)
- output stylesheet path (`--output`)
- optional theme class (`--theme-class`, default `we-theme-bootstrap`)
- optional selector (`--selector`, default `:root`)

Example:

```sh
racket tools/thematic \
  --input /path/to/bootstrap.css \
  --output /tmp/theme-bootstrap.css \
  --theme-class we-theme-bootstrap \
  --selector ':root'
```

thematic-scope
--------------
Scopes a Bootstrap stylesheet under one wrapper selector so the original
Bootstrap theme can be shown beside a generated `web-easy` theme without
iframes.

It rewrites qualified rule selectors under a scope such as `.bs-preview`,
preserves top-level imports, recursively scopes nested rules inside `@media`
and similar blocks, and leaves blocks like `@keyframes` and `@font-face`
unchanged.

Inputs:
- Bootstrap CSS file (`--input`)
- output stylesheet path (`--output`)
- optional wrapper selector (`--scope`, default `.bs-preview`)

Example:

```sh
racket tools/thematic-scope \
  --input /path/to/bootstrap.css \
  --output /tmp/bootstrap-scoped.css \
  --scope '.bs-preview'
```
