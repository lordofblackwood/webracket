# Compile-Time Notes

This note records the current advice from timing a warm-cache
`pkgs/web-easy/examples/hello-world` compile.

Measured setup:

- WebRacket compiler precompiled with `raco make webracket.rkt`
- Provider/cache path warmed before measuring
- Example compiled through the normal module-based browser path

Observed warm-cache wall time is about two minutes. The shell wrapper and CSS
copies are not significant; most time is in WebRacket startup/module loading
and the compiler pipeline.

## Compile Server Result

An implementation-thread measurement showed that a long-lived compile server
helps repeated builds, but only modestly for `hello-world`.

Measured results:

- Cold direct build: about 144 seconds wall clock
- First build after starting the server: about 166 seconds wall clock
- Warm server-backed build: about 130 seconds wall clock
- Repeated-build improvement: about 14 seconds, or roughly 10%

The server startup cost was about 36 seconds. That means the server is worse for
a one-off build, but useful for multiple compiles in one long-lived session.

The warm server-backed driver timing was still dominated by real compiler work:

- `read-source`: about 20.4 seconds
- `compile-pipeline`: about 70.0 seconds
- driver total: about 90.5 seconds

Conclusion: the compile server is useful infrastructure for repeated workflows,
watch mode, and editor integration, but it is not the main optimization lever
yet. The next major wins should come from compiler-pass and module-bridge work.

## Recommended Work

1. Profile and improve `alpha-rename/pass1`.

   `alpha-rename/pass1` was the largest compiler pass, around 22.8 seconds in
   the direct warm-cache timing. Likely improvements are replacing repeated
   association-list lookups with hashes/sets, avoiding repeated environment
   reconstruction, and reducing repeated syntax/form rebuilding.

2. Cache the module bridge result.

   `module-bridge-extract` was about 18.7 seconds for `hello-world`. If the
   source file and required provider fingerprints are unchanged, reuse the
   lowered/composed module input instead of extracting it again.

3. Keep the compile server as infrastructure, but avoid polishing it too early.

   The server produces a real repeated-build improvement, but the measured
   `hello-world` improvement is only about 10%. Keep it available for workflows
   with many compiles per session, but prioritize reducing the actual compile
   work before investing heavily in daemon UX.

4. Avoid compiling the full runtime for tiny programs.

   Runtime generation and tree-shaking are still meaningful costs. Longer term,
   split stable runtime support into cached/prebuilt pieces and link or append
   only the program-specific code.

5. Keep tutorial `compile.sh` scripts simple.

   Example scripts double as documentation. They should remain simple entry
   points. Any compile server or shared cache machinery should live behind a
   shared helper, not be duplicated in every example script.

## Suggested Order

Start with `alpha-rename/pass1` profiling, then module bridge caching, then
larger-example server benchmarks. Keep the compile server available, but treat it
as infrastructure until the compile pipeline itself is faster.

## Runtime And Tree-Shake Pipeline

Current generate-code flow for runtime work:

1. `compiler.rkt` calls `generate-runtime` from
   `pkgs/webracket-lib/compiler/runtime-wasm.rkt`.
2. `generate-runtime` filters active FFI wrapper forms based on the program's
   referenced primitives.
3. It emits one large runtime module as a Racket s-expression via
   `build-runtime-module`.
4. Tree-shake analyzes that emitted module directly as compiler-side s-expr
   data; it does not reparse final WAT text.
5. Analysis builds function and primitive dependency graphs, seeds roots from
   exported/module/elem references plus program primitive demands, computes
   reachability, and then prunes the runtime module.
6. Final WAT text is written later by the assembler/output path, so
   `--pretty-wat` affects output formatting rather than runtime graph analysis.

Inputs that clearly affect runtime generation or pruning:

- browser vs node target
- enabled FFI bundles and generated wrapper/import forms
- used program primitives
- tree-shake enabled vs disabled
- runtime/compiler source changes

This means the best first cache boundary is likely the emitted runtime module or
its analyzed dependency graph, keyed by runtime/compiler source fingerprints,
target kind, and FFI inputs. Root retention should remain program-specific.

## Current Full-Module Shape

The current runtime tree-shake pass still works over one combined module
produced by `build-runtime-module` in
`pkgs/webracket-lib/compiler/runtime-wasm.rkt`.

The combined module currently contains:

- stable runtime support: runtime primitive functions, helper functions, type
  declarations, target-specific host support, and active FFI wrapper/import
  forms
- generated program helper functions from `dls`
- program globals from `top-level-variable-declarations`
- the `$entry` function and its uncaught-exception helpers

Important current behavior:

- pruning already treats generated program functions specially by retaining
  `program-function-names` even when runtime functions are removed
- analysis does not split the module yet; `analyze-runtime-primitives` still
  scans the full combined module
- program roots are currently injected later via `used-primitives` and
  console-bridge roots, but the cached analysis still depends on the combined
  module shape

That explains the current tradeoff:

- keying the cache by the whole module is safe
- but small edits that change `$entry` or generated program helpers are likely
  to invalidate the cache unnecessarily

The runtime-analysis-v2 cache now follows that split:

- stable runtime analysis is cached by target/runtime/FFI fingerprint
- program-specific root and runtime-edge analysis is recomputed every compile

Verified behavior:

- unchanged rebuild: cache hit on the second compile
- small source edit: cache hit remains after editing the program text
- different small program: cache hit remains when compiling a different module
  under the same browser/runtime/FFI configuration

This behavior is locked in by
`test/test-runtime-analysis-cache.rkt`, which asserts the
`runtime-analysis-v2-cache-hit?` diagnostic sequence `no`, `yes`, `yes`,
`yes` across those four compiles.

The remaining cost is still substantial even when the cache behaves correctly,
but the earlier `add-stdlib: 48.2s` diagnosis turned out to be misleading for
module-based programs.

What was happening:

- `#lang webracket/base` already ignored the legacy `--stdlib` root
- but module input still composed the staged `io/format` provider by default
- that provider work was being charged to the broad `add-stdlib` phase

Current behavior:

- module input now reports an explicit stdlib/provider decision block
- `legacy-stdlib-mode` is skipped or ignored for module input
- `io-format-provider-mode` is skipped for module input by default
- script-style input still supports explicit `--stdlib` and `io/format`
  composition

After that change, a tiny `#lang webracket/base` browser compile spent about:

- 10.3 seconds in `read-source`
- 0.1 seconds in `add-stdlib`
- 21.4 seconds in `compile-pipeline`
- 31.8 seconds total driver time

So the stable-runtime cache is no longer only same-program useful, and module
programs no longer pay the old staged `io/format` default cost. The next big
wins are now in module-bridge extraction and the main compile pipeline rather
than in legacy stdlib cleanup.
