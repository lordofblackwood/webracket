# Goal 1 Module Path

Goal 1 is ahead-of-time module programs in the browser. It does not require
browser-side `eval`, browser-side source expansion, or backend optimization work
unless a concrete module program exposes a correctness blocker.

## Current Shape

`#lang webracket/base` and `#lang webracket/full` are read and expanded by host
Racket as ordinary modules. Webify extracts the phase-0 runtime linklet reports,
discovers the required provider graph, composes module instances and export
cells, then hands the composed top-level program to WebRacket.

The important boundary is:

```text
host Racket reader/expander
        -> Webify module/linklet extraction
        -> Webify provider graph composition
        -> WebRacket runtime program
```

The driver should not learn Racket's source-level require language beyond the
minimum needed to reject unsupported transitional cases clearly. Compiled module
metadata and provider reports are the source of truth.

## Base And Full

`webracket/base` is intentionally small: `racket/base` plus WebRacket-specific
essentials such as `js-log`. This keeps the name aligned with Racket's
`racket/base` convention.

`webracket/full` is the current curated add-on surface. It is tracked in
`webify/webracket-full-surface.rkt` and includes the libraries that already
have useful Goal 1 evidence, such as `racket/list`, `racket/string`,
`racket/vector`, `racket/function`, `racket/promise`, `racket/sequence`,
`racket/set`, `racket/stream`, staged `io/format`, and friends.

The bridge allowlist is intentionally narrower than "everything exported by the
language." `webify/provider-trials.rkt` is the temporary manifest of installed
providers the bridge may discover. Adding a library there should mean:

- there is a small representative source module for the provider;
- extraction can name the provider and requested exports;
- composition can be tested without requiring a full runtime smoke;
- unsupported providers still fail with a clear allowlist error.

At the moment, `racket/vector` and `racket/function` have joined the passing
external-provider trial set alongside the earlier list/string/bool trials.
`racket/promise`, `racket/stream`, and `racket/set` are still useful Goal 1
libraries, but their direct provider trials currently expose unresolved
reflected exports, so they stay out of the temporary bridge allowlist until that
provider-resolution issue is fixed.

## Stdlib Replacement Direction

The old textual `stdlib/` is a transitional compatibility layer. Goal 1 should
replace pieces with original Racket module providers where practical:

- `regexp/` is staged as an always-available provider slice.
- `expander/read` is staged behind the read-provider path.
- `io/format` is staged from `racket-src/io/format`, replacing hand-written
  format wrappers over time.

Plain `format`, `fprintf`, `printf`, and `eprintf` should continue to come from
the staged `io/format` provider. The installed `racket/format` module is a
different surface for `~a`, `~s`, `~e`, and related helpers, and it currently
pulls a larger contract/location provider cluster that is not part of the
temporary `#lang webracket/base` external-provider allowlist.

The browser and Node stdlib roots may still exist while this migration is in
progress, but ownership should keep moving toward module providers rather than
top-level textual inclusion.

## What Not To Optimize Yet

Compiler-pass timing is useful as a guardrail, but it is not the main Goal 1
thread right now. Avoid spending project time on closure conversion, letrec
lowering, tree shaking, or Wasm code generation unless a module/provider
milestone fails for correctness.

The near-term work is provider graph correctness, module composition coverage,
and replacing temporary stdlib pieces with original Racket module sources.
