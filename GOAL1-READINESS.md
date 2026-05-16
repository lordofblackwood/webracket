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
