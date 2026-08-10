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

check-split-runtime-procedure-boundary.rkt
------------------------------------------
Assembles and runs a tiny two-module Wasm-GC boundary check. The runtime module
allocates a procedure value and exports it as an `eqref` global; the program
module imports that value, verifies it passes a program-side `$Procedure`
`ref.test`, and calls a runtime-side apply shim. Both modules splice in the
real `generate-shared-types` output, so this guards the actual shared-type
invariant needed by the compile-once runtime experiment.

Run:

```sh
racket -S pkgs tools/check-split-runtime-procedure-boundary.rkt
```

Or through the smoke target:

```sh
make smoke-split-runtime-procedure-boundary
```

check-split-runtime-default.rkt
-------------------------------
Regression-style check for the public compiler default. It compiles and runs
small Node programs without passing `--split-runtime`, then verifies the
default output shape: a program `.wasm`, a content-addressed
`webracket-runtime-<fingerprint>.wasm`, and a Node host. The default source set
covers a trivial script, a module-language read-demand program, and a generated
regexp-demand script. It also compiles and runs the same programs with
`--no-split-runtime` and verifies that the monolithic opt-out does not emit a
separate runtime module.

Run:

```sh
racket -S pkgs tools/check-split-runtime-default.rkt
```

Or through the smoke target:

```sh
make smoke-split-runtime-default
```

split-runtime readiness gate
----------------------------
`make smoke-split-runtime-readiness` is the focused gate for changes that touch
the split-runtime default, runtime cache lookup, provider-runtime merge path, or
browser shared-runtime URL path. It runs the default output-shape check, the
browser shared-runtime URL smoke, the provider-runtime browser URL smoke, and
the provider-runtime Node cache-reference/materialized-runtime smoke. It is intentionally
part of `make smoke-release`, not `make smoke-quick`, because it compiles
provider-runtime fixtures and usually takes minutes rather than seconds.

Run:

```sh
make smoke-split-runtime-readiness
```

measure-split-runtime.rkt
-------------------------
Benchmarks the default split-runtime path against explicit monolithic output on
a tiny no-stdlib Node program. It uses private provider/runtime caches, runs a
cold split compile to populate the stable runtime cache, then compares
`--no-split-runtime` and warm split compile/run timings. The tool exits
non-zero if the compiled program does not run or if the warm split run does not
use the cached runtime wasm.

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
directly instead of writing a runtime wasm next to the program.

Use `--split-runtime-core-only` to benchmark the helper-only split strategy,
where only registered core-runtime helpers move into the shared runtime module
and the rest of the program/provider graph remains in the program module.

Use `--split-runtime-provider-runtime` with a `#lang webracket/base` or
`#lang webracket/full` source to benchmark the provider-fragment-in-runtime
strategy. With `--prewarm-runtime-first`, the prewarm phase compiles the source
once to populate the provider-augmented runtime cache, and warm measured rows
must reuse that cache without repeating provider-fragment compilation or
runtime merging:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --source test/test-module-read-demand.rkt \
  --split-runtime-provider-runtime \
  --prewarm-runtime-first \
  --include-cache-reference
```

For a small local module graph, the same provider-runtime benchmark is available
as:

```sh
make measure-split-runtime-provider-runtime
```

The warm-process variant of that MiniScheme provider-runtime benchmark is:

```sh
make measure-split-runtime-provider-runtime-warm-process
```

Use `--prewarm-runtime-first --include-cache-reference` to benchmark the
compile-once workflow: first populate the stable runtime cache through
`prewarm-staged-providers.rkt`, then measure user compiles against that cache:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --prewarm-runtime-first \
  --split-runtime-core-only \
  --include-cache-reference
```

Use `--prewarm-staged-providers-first` when the source exercises staged
providers such as regexp/read/io-format. This moves provider construction into
the prewarm phase, so measured rows show the fully warm user-compile path:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --prewarm-staged-providers-first \
  --prewarm-runtime-first \
  --include-cache-reference
```

Use `--prewarm-module-bridge-first` for module-language sources when the
source-specific module-bridge result cache should also be warm before comparing
monolithic and split rows. This keeps bridge extraction/composition out of both
measured rows:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --source examples/minischeme/repro-local-mini-42.rkt \
  --prewarm-module-bridge-first \
  --prewarm-runtime-first \
  --include-cache-reference
```

By default, the split-runtime benchmark leaves the normal Racket compiled-file
roots alone, matching ordinary user invocations. Use
`--isolate-compiled-root` only when you deliberately want fresh subprocess
timings to include a private cold compiled root.

Use `--precompile-compiler-first` when you want an isolated-root benchmark's
wall-clock columns to reflect warm user compiles instead of also including the
cost of loading/byte-compiling the compiler entry modules and their dependency
graph into that private root:

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

The same warm-process benchmark on the tiny default fixture is available as:

```sh
make measure-split-runtime-warm-process
```

Use `--compile-server` to run the measured compile modes through the
WebRacket compile-server client. Start the server first with
`racket -S pkgs webracket.rkt --server-start` when you want to keep lifecycle
management explicit:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --prewarm-runtime-first \
  --include-cache-reference \
  --compile-server
```

Use `--frontend-cache` to pass the experimental compiler frontend cache through
to measured compiles. The cache stores serialized post-unexpand syntax in the
project provider cache, so repeated identical frontend inputs can skip
`topexpand` and `unexpand`:

```sh
racket -S pkgs tools/measure-split-runtime.rkt \
  --prewarm-runtime-first \
  --include-cache-reference \
  --frontend-cache
```

check-split-runtime-prewarm.rkt
-------------------------------
Regression-style check for the compile-once split-runtime workflow. It creates
private provider/runtime caches, prewarms the stable split-runtime wasm cache,
then compiles and runs a tiny no-stdlib program in the explicit
cache-reference mode. Reference-compatible user compiles must use the cached
runtime wasm directly; programs that need a different runtime core are allowed
to fall back to a materialized content-addressed runtime module, but still have
to compile and run correctly.

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

Use `--split-runtime-provider-runtime` with module-language sources to check
the experimental provider-in-runtime path. The checker first prewarms the
source-specific provider-augmented runtime through the normal driver, then
requires the warm cache-reference compile/run to reuse that cached runtime
without repeating provider-fragment compilation or runtime merging:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --source test/test-module-read-demand.rkt \
  --extra-source examples/minischeme/repro-local-mini-42.rkt \
  --split-runtime-provider-runtime
```

The same provider-runtime smoke through a warm compiler process is:

```sh
make smoke-split-runtime-provider-runtime-warm-process
```

By default, each post-prewarm case is checked in both warm runtime modes:
cache-reference output, where the generated Node host reads the cached
runtime wasm directly, and materialized-runtime output, where the compiler
writes a warm `webracket-runtime-<fingerprint>.wasm` next to the program. Use
`--no-materialized-runtime-check` for faster cache-reference-only runs:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --suite \
  --no-materialized-runtime-check
```

Use `--in-process` to run the post-prewarm compile/run cases serially in the
already loaded checker process. This verifies the cached-runtime path under a
warm compiler process, which approximates the compile-server workflow:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt --suite --in-process
```

The small guarded warm-process smoke is available as:

```sh
make smoke-split-runtime-warm-process
```

Use `--compile-server` to run the post-prewarm compile/run cases through the
WebRacket compile-server client. Like `--in-process`, this runs cases
serially, since the local server handles requests one at a time:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt --suite --compile-server
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

Use `--check-module-bridge-result-cache` with module-language sources to warm
the module-bridge result cache with one compile, then require the next
compile/run to report a `module-bridge-result-cache-hit` while still producing
correct output:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --source examples/minischeme/repro-local-mini-42.rkt \
  --check-module-bridge-result-cache
```

`tools/check-provider-fragment-compile.rkt` can emit cached module-bridge
provider and program fragments for the compile-once-runtime experiments. When a
runtime/provider module is initialized by the loader before the program runs,
compile the user fragment with `--fragment program --split-runtime-reference`
and add `--strip-program-entry-runtime-init` so the generated program entry
does not reinitialize runtime-owned state such as struct-type properties:

```sh
racket -S pkgs tools/check-provider-fragment-compile.rkt \
  --source test/test-module-read-demand.rkt \
  --fragment program \
  --split-runtime-reference \
  --strip-program-entry-runtime-init \
  --write-wat tmp/provider-frag-program.wat
```

`tools/check-provider-runtime-split.rkt` takes a split runtime core WAT, a
compiled provider-fragment WAT, and a compiled program-fragment WAT, then emits
a provider-augmented runtime module plus a separate program module. With
`--strip-program-entry-runtime-init`, the generated host initializes runtime
state once, calls the provider entry from the runtime module, and then runs the
program:

```sh
racket -S pkgs tools/check-provider-runtime-split.rkt \
  --core-wat tmp/provider-runtime-check-source/test-module-read-demand.runtime.wat \
  --provider-wat tmp/provider-runtime-check-provider.wat \
  --program-wat tmp/provider-runtime-check-program.wat \
  --write-runtime-wat tmp/provider-runtime-check-runtime.wat \
  --write-runtime-wasm tmp/provider-runtime-check-runtime.wasm \
  --write-program-wat tmp/provider-runtime-check-program.normalized.wat \
  --write-program-wasm tmp/provider-runtime-check-program.wasm \
  --write-host tmp/provider-runtime-check-host.js \
  --strip-program-entry-runtime-init \
  --run \
  --expect-stdout-line 42 \
  --expect-stdout-line '#<void>'
```

The normal driver has an experimental version of this path behind
`--split-runtime-provider-runtime` for Node and browser split-runtime builds. It
keeps module-bridge provider fragments in the split runtime cache instead of
splicing them into the program module. Warm Node cache-reference runs should
report `split-runtime-core:reference-wasm-hit` and should not report
provider-fragment cache or provider-runtime merge work:

```sh
racket -S pkgs webracket.rkt \
  --node \
  --split-runtime \
  --split-runtime-provider-runtime \
  --split-runtime-cache-reference \
  --expander-read-provider \
  --timings \
  -r test/test-module-read-demand.rkt
```

Use `--frontend-cache` to pass the experimental frontend cache through to the
post-prewarm compile/run cases:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --frontend-cache
```

By default, this checker leaves the normal Racket compiled-file roots alone,
matching ordinary user invocations. Use `--isolate-compiled-root` only when you
deliberately want fresh subprocess checks to include a private cold compiled
root.

Use `--precompile-compiler` when you want an isolated-root check where the
compiler and prewarm tools have already been `raco make`d. This flag implies a
private compiled root:

```sh
racket -S pkgs tools/check-split-runtime-prewarm.rkt \
  --source examples/minischeme/repro-local-mini-42.rkt \
  --check-module-bridge-result-cache \
  --precompile-compiler
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
cache, compiles a tiny no-stdlib browser program in the default split-runtime
mode, routes generated artifact requests through Playwright, then verifies that
the browser fetches both the program wasm and the runtime wasm and that the
program prints the expected result.

By default, this checker leaves the normal Racket compiled-file roots alone.
Use `--isolate-compiled-root` only when checking behavior under a private cold
compiled root.

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
`--split-runtime-core-url` instead of materializing a local
`webracket-runtime-<fingerprint>.wasm` file:

```sh
racket -S pkgs tools/check-split-runtime-browser.rkt \
  --shared-runtime-url
```

By default, the checker also copies the generated HTML, program Wasm, and
runtime Wasm into a deploy-shaped package directory, runs that copied page, and
verifies that omitting the runtime Wasm fails on the runtime fetch. Use
`--no-package-copy-check` only when debugging the compiler-side browser check
itself and the extra package run is distracting.

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

Use `--split-runtime-provider-runtime` with `--shared-runtime-url` and a
module-language source to exercise the provider-fragment-in-runtime browser
path. The checker prewarms the provider-augmented runtime first, then requires
the browser compile to use `--split-runtime-core-url` without repeating
provider merge work:

```sh
racket -S pkgs tools/check-split-runtime-browser.rkt \
  --source test/test-module-read-demand.rkt \
  --shared-runtime-url \
  --split-runtime-provider-runtime
```

Omit `--shared-runtime-url` to check the same provider-runtime browser path
when the warm cached runtime is materialized as a content-addressed runtime
file:

```sh
racket -S pkgs tools/check-split-runtime-browser.rkt \
  --source test/test-module-read-demand.rkt \
  --split-runtime-provider-runtime
```

The same guarded check is available as:

```sh
make smoke-split-runtime-browser
```

The shared runtime URL variant is available as:

```sh
make smoke-split-runtime-browser-url
```

The provider-runtime materialized-runtime variant is available as:

```sh
make smoke-split-runtime-browser-provider-runtime
```

The provider-runtime shared runtime URL variant is available as:

```sh
make smoke-split-runtime-browser-provider-runtime-url
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

Repeated split-runtime prewarm first checks the cached runtime wasm and
split-boundary metadata directly; when both match, it skips the dummy compile.
Use `--force` to rebuild the cached artifact anyway.

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

Use `--mode provider-runtime` with a `#lang webracket/base` or
`#lang webracket/full` source to prewarm the experimental provider-fragment
runtime cache. This compiles the source in split-provider-runtime
materialized-runtime mode
without running it, so the source-specific provider-augmented runtime is cached
before the later user compile. With `--runtime-wasm-out`, the materialized
runtime can be copied to the stable browser URL used by
`--split-runtime-core-url`:

```sh
racket -S pkgs tools/prewarm-staged-providers.rkt \
  --provider-cache-dir /tmp/webracket-provider-cache \
  --runtime-provider-cache-dir /tmp/webracket-runtime-cache \
  --mode provider-runtime \
  --host browser \
  --source test/test-module-read-demand.rkt \
  --runtime-wasm-out /tmp/runtime.wasm
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
`pkgs/thematic/main.rkt`.

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
