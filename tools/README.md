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

Use `--split-runtime-core-only` to benchmark the helper-only split strategy,
where only registered core-runtime helpers move into the shared runtime module
and the rest of the program/provider graph remains in the program module.

Use `--prewarm-runtime-first --include-cache-reference` to benchmark the
compile-once workflow: first populate the stable runtime cache through
`prewarm-staged-providers.rkt`, then measure user compiles against that cache:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --prewarm-runtime-first \
  --split-runtime-core-only \
  --include-cache-reference
```

Use `--precompile-compiler-first` when you want the benchmark's wall-clock
columns to reflect warm user compiles instead of also including the cost of
loading/byte-compiling the compiler entry modules and their dependency graph
into a fresh isolated compiled root:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --precompile-compiler-first \
  --prewarm-runtime-first \
  --split-runtime-core-only \
  --include-cache-reference
```

Use `--in-process` to run the measured compile modes in the benchmark's already
loaded Racket process instead of launching a fresh `racket webracket.rkt`
subprocess for each row. This is useful for estimating the payoff from a warm
compiler process or compile-server workflow:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --prewarm-runtime-first \
  --include-cache-reference \
  --in-process
```

check-split-runtime-prewarm.rkt
-------------------------------
Regression-style check for the compile-once split-runtime workflow. It creates
private provider/runtime caches, prewarms the stable split-runtime wasm cache,
then compiles and runs a tiny no-stdlib program with
`--split-runtime-cache-reference`. Reference-compatible user compiles must use
the cached runtime wasm directly; programs that need a different runtime core
are allowed to fall back to a per-program runtime sidecar, but still have to
compile and run correctly.

Run:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt
```

Use `--suite` to run the selected source plus generated no-stdlib fixtures
against the same prewarmed runtime cache:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt --suite
```

Use `--jobs` to run the post-prewarm compile/run cases with bounded
parallelism. Four jobs is the current guarded smoke setting:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt --suite --jobs 4
```

Use `--in-process` to run the post-prewarm compile/run cases serially in the
already loaded checker process. This verifies the cached-runtime path under a
warm compiler process, which approximates the compile-server workflow:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt --suite --in-process
```

Use `--prewarm-staged-providers` when the workload exercises staged provider
code such as regexp/read/io-format. This checks the intended fully warm path:
staged providers are cached first, then the split runtime is cached, then user
programs compile against those caches:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --suite \
  --in-process \
  --prewarm-staged-providers
```

Use `--extra-source` and `--reject` to check multiple committed fixtures with
one prewarmed runtime cache. This is useful for tests that print pass tables:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --source test/test-lambda-variadic.rkt \
  --extra-source test/test-values-errors.rkt \
  --no-expect \
  --reject '#f'
```

Use `--split-runtime-core-only` to check the helper-only split strategy, where
only registered core-runtime helpers move into the shared runtime module and the
rest of the program/provider graph stays in the program module:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --split-runtime-core-only
```

The same representative check is available as:

```sh
make smoke-split-runtime-prewarm
```

That target runs the generated suite and selected committed fixtures with
`--jobs 4` under `tools/run-guarded.py`.

check-split-runtime-browser.rkt
-------------------------------
Regression-style browser check for the compile-once split-runtime workflow. It
creates private provider/runtime caches, prewarms the stable split-runtime wasm
cache, compiles a tiny no-stdlib browser program with `--split-runtime`, serves
the generated directory, then uses Playwright to verify that the browser fetches
both the program wasm and the runtime sidecar wasm and that the program prints
the expected result.

Run:

```sh
racket -S pkgs tools/check-split-runtime-browser.rkt
```

Useful options:

```sh
racket -S pkgs tools/check-split-runtime-browser.rkt \
  --source test/test-trivial.rkt \
  --expect '(^|\n)42(\n|$)'
```

Use `--shared-runtime-url` to exercise the compile-once browser workflow where
the generated page fetches a prewarmed shared `runtime.wasm` URL via
`--split-runtime-core-url` instead of materializing a per-program
`.runtime.wasm` sidecar:

```sh
racket -S pkgs tools/check-split-runtime-browser.rkt \
  --shared-runtime-url
```

Use `--split-runtime-core-only` with `--shared-runtime-url` to exercise a more
stable compile-once boundary. For example, this compiles a larger browser
module graph against the same helper-only `runtime.wasm` and validates that the
browser fetches both Wasm modules:

```sh
racket -S pkgs tools/check-split-runtime-browser.rkt \
  --shared-runtime-url \
  --split-runtime-core-only \
  --source test/test-racket-list-sort-smoke.rkt \
  --no-expect
```

The same guarded check is available as:

```sh
make smoke-split-runtime-browser
```

The shared runtime URL variant is available as:

```sh
make smoke-split-runtime-browser-url
```

prewarm-staged-providers.rkt
----------------------------
Prebuilds cache artifacts before an example compile needs them. Existing modes
prewarm staged provider artifacts such as regexp, expander/read, and io/format;
`--mode all` warms that ordinary staged-provider set. The `split-runtime` mode
compiles a tiny no-stdlib split-runtime program through the normal driver so
the stable runtime wasm is already in the runtime provider cache before a real
user program compile. By default, split-runtime prewarm targets Node output and
runs the generated program; use `--host browser` when warming the browser
runtime cache.

Run:

```sh
racket -S pkgs tools/prewarm-staged-providers.rkt \
  --provider-cache-dir /tmp/webracket-provider-cache \
  --runtime-provider-cache-dir /tmp/webracket-runtime-cache \
  --mode split-runtime \
  --host browser
```

Use `--runtime-wasm-out` with `--mode split-runtime` to copy the selected cached
runtime artifact to a stable path that browser builds can reference with
`--split-runtime-core-url`:

```sh
racket -S pkgs tools/prewarm-staged-providers.rkt \
  --provider-cache-dir /tmp/webracket-provider-cache \
  --runtime-provider-cache-dir /tmp/webracket-runtime-cache \
  --mode split-runtime \
  --host browser \
  --runtime-wasm-out /tmp/webracket-runtime.wasm
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
