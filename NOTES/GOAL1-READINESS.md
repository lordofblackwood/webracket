# Goal 1 Readiness Dashboard

Goal 1 is module-based Racket programs in the browser, without requiring
browser-side `eval`.

## Current Tiers

- `require works`: the module can be extracted, composed, and instantiated.
- `simple calls work`: a small exported value exercises the library at runtime.
- `representative calls work`: the smoke covers a useful behavior shape instead
  of only requiring the module.
- `semantic approximation`: WebRacket intentionally keeps a bootstrap behavior
  that is enough for Goal 1 but not full Racket.

## Current Fast Runtime Coverage

- `racket/promise`: require, plain predicate, identity forcing,
  representative promise forcing, and state predicates.
- `racket/set`: representative immutable set operations, comparator
  semantics, and `racket/private/set-types` predicate coverage.
- `racket/sequence` and `for`: list, vector, range, naturals, nested, parallel,
  and fold/list/first shapes.
- `racket/match`: literal, default, predicate, and `match-let` shapes.
- `racket/format`: require, `~a`, `~s`, width/alignment, and `fprintf`
  through a `prop:output-port` wrapper. `~v` is intentionally ignored for now.
- `racket/class`: basic class construction and method call.
- Multi-module provider/reexport smokes for installed-library dependencies.
- `racket/stream`: first/rest coverage through installed module composition.

## Example And Library Migration Checkpoint

- Root user-facing examples are module-based and use local compile scripts:
  `console-bridge`, `hello-world-2`, `hello-world-3`, `pict`,
  `space-invaders`, `snake`, `snake2`, `mathjax4`, `minischeme`,
  `matrix-rain`, `raco/tiles`, and `xtermjs-demo`.
- The opt-in root example harness lives in `examples/check-root-examples.sh`.
  Its browser preflight rejects known bad translated/Rosetta launch shapes
  before starting Chrome.
- Browser-only root example smoke currently passes with the native pinned
  Racket toolchain and current generated outputs.
- The current `lib/libs/*.rkt` inventory has module-world counterparts.
  `lib/libs/` remains the legacy `include-lib` compatibility layer while new
  code should require the module providers directly.
- `simple-pretty.rkt` is intentionally not a pending module port. It is
  obsolete legacy surface, superseded by `webracket/pretty`.

## Semantic Approximations

- Continuation marks are erased; `call-with-immediate-continuation-mark` calls
  its receiver with the default value.
- Chaperone/impersonator constructors are identity or wrapper bridges. They do
  not implement real interposition yet.
- `prop:output-port` wrappers resolve to the underlying native output port for
  the common field-index case.
- Bootstrap regexp replacement handles a literal string-backed subset; full
  regexp behavior should come from the demodded regexp implementation.
- `~v`/full `print` parity is intentionally out of the current fast Goal 1
  matrix.

## Known Local Gaps

- Full chaperone semantics are still missing.
- Full continuation mark stacks are still missing.
- The Goal 1 compact dependency dashboard is clean, but larger library programs
  can still expose provider-graph or primitive coverage gaps.
- Full cold compile runs for staged-read examples, especially MiniScheme, are
  still expensive. Use warmed caches and the staged-provider prewarm tool for
  routine example verification; treat cold timings as performance diagnostics.
- `web-site/`, `web-site-new/`, and generated runtime artifacts are reference
  or publish-output trees. Do not normalize them as part of Goal 1 closeout
  unless doing a deliberate publish/update pass.
