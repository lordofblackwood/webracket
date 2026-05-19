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
The JavaScript FFI modules `js/math` and `js/console` also pass through the
module bridge and infer their `.ffi` bundles from canonical
`webracket/unsafe/*` providers.
`racket/promise`, `racket/stream`, and `racket/set` are still useful Goal 1
libraries, but they stay out of the temporary bridge allowlist until we have a
smaller provider route for them. A direct `racket/set` trial currently expands
into a much larger transitive graph through contracts, syntax support, and
random support; the bridge now rejects unsupported transitive providers instead
of discovering that graph accidentally.

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

## Current Local-Only Default

The driver now tries the module bridge by default for `#lang webracket/base`
and `#lang webracket/full` files whose extracted graph has no installed
provider demands after language-root providers are cut. If external providers
remain, the driver falls back to the transitional top-level lowering unless
`--webracket-module-bridge` is supplied.

Module-language inputs deliberately skip the temporary stdlib and unconditional
provider prelude. The old textual stdlib remains useful for script-style
top-level compatibility, but Goal 1 modules should be composed from modules and
providers, not from stdlib text.

`--timings` prints a `Read Source Details` table for this path. A tiny
`#lang webracket/base` program currently spends little time in module reading,
extraction, registration, or composition; most time is still in the compiler
pipeline after the module bridge has produced a top-level program. A regression
test now keeps `#lang webracket/base` followed by `42` on the tiny module-bridge
path by checking the bridge timing rows and guarding the parse node count.

Installed provider reports are also cached under the active provider cache
directory. This is deliberately conservative: cache rows are keyed by module
name, cache format version, and Racket version, and they store a plain datum
representation of the extracted report instead of reader-dependent struct
syntax.

`webify/webracket-full-dashboard.rkt` is the compact status view for the
curated `webracket/full` surface. Its TSV/JSON columns distinguish "exported by
the language" from "allowed as an external provider" and from "has a direct
runtime smoke." That separation is important while the old stdlib is being
retired: a library can be part of the intended module language without being
implemented by textual stdlib inclusion.

`webify/goal1-dashboard.rkt` is the compact no-stdlib runtime dashboard. It is
deliberately smaller than `probe-installed-runtime-smoke.rkt`: it runs a few
representative `#lang webracket/base` and `#lang webracket/full` programs with
`--no-stdlib`, reports provider-cache events and one compact failure note, and
separates rows into:

- `local-module-graph`, for local-only module composition;
- `installed-provider-graph`, for curated `webracket/full` add-ons;
- `staged-provider-slice`, for always-available staged providers such as
  regexp.

Run it with:

```sh
../racket/racket/bin/racket webify/goal1-dashboard.rkt --tsv --timeout 120 --memory-mb 1024
```

## Current Readiness

| Area | Status | Evidence | Notes |
| --- | --- | --- | --- |
| Local `#lang webracket/base` modules | works | `goal1-dashboard` local rows | No legacy stdlib prelude required. |
| Local require/re-export graphs | works | `test-webracket-base-lang.rkt` and dashboard local rows | Still intentionally rejects unsupported source-level require forms. |
| Curated `webracket/full` add-ons | partial, not runtime-complete | `webracket-full-dashboard.rkt`, `goal1-dashboard` installed-provider rows | The staged `format` row now runs; the current dashboard still exposes unrelated gaps such as `set`. |
| `regexp` provider | works for representative cases | staged provider tests and dashboard staged-provider row | Always-available provider slice; not textual stdlib. |
| `io/format` provider | works for representative cases | provider slice tests and format dashboard row | Public format family is provider-owned; `~v` routes through `port-print-handler` with process-wide handler storage for now. |
| `expander/read` provider | staged/partial | `test-expander-read-provider.rkt` | Enabled explicitly for read-provider cases. |
| `io/print` provider | staged seed | `test-io-print-extraction.rkt` | Cell-only seed works; custom-write/graph semantics still blocked. |
| Legacy `stdlib/` | retiring | `STDLIB-RETIREMENT.md` | Script compatibility only, not Goal 1 module infrastructure. |

FFI bindings follow the same ownership rule. `webracket/js` is the initial
WebRacket-specific provider for JavaScript interop and currently exports
`js-log`. `webracket/base` and `webracket/full` re-export it intentionally, but
future browser or Node APIs should live in explicit provider modules rather
than growing the primitive/top-level surface by accident.

The console pilot uses the intended split:

```
ffi/console.ffi
  -> webracket/unsafe/console
  -> js/console
```

The unsafe module is currently a primitive-backed shim so the module bridge can
compose programs that require raw console names. Its exports are checked
against `ffi/console.ffi`, and legacy `(include-lib console)` remains covered
while examples migrate. Replacing the shim body with a generated `.ffi`-backed
module is the next FFI-generator milestone.

The math pilot uses the same split:

```
ffi/math.ffi
  -> webracket/unsafe/math
  -> js/math
```

Unlike console, math currently uses generated placeholder bodies. That is
intentional: it proves the export/arity metadata and provider names without
pretending direct `.ffi` imports are already module-instance bindings. The next
runtime milestone is to make these generated unsafe modules bind to actual FFI
primitives inside the composed provider graph.
