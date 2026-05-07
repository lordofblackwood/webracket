# Installed Module Compatibility Ladder

This ladder tracks real installed Racket modules through the Webify bridge. It
is intentionally small and evidence-based: a module moves only when a focused
test or smoke demonstrates the new status.

## Passing Runtime Smokes

| Module | Smoke | Evidence |
| --- | --- | --- |
| `racket/bool` | `(boolean=? #t #t)` prints `#t`/`true` | `webify/test-installed-module-runtime.rkt` |
| `racket/fixnum` | `(fx+ 1 2)` prints `3` | `webify/test-installed-module-runtime.rkt` |
| `racket/list` | `(first '(#t #f))` prints `#t`/`true` through demand-sliced providers | `webify/test-installed-module-runtime.rkt` |
| `racket/list` | `(first (rest '(#t #f)))` prints `#f`/`false` | `webify/test-installed-module-runtime.rkt` |

These prove that Webify can discover real installed providers, instantiate the
resulting module graph, and observe exported module cells without turning
provider exports into top-level aliases.

## Graph-Resolved Frontiers

| Module | Current status | First blocker |
| --- | --- | --- |
| `racket/list` | Provider graph follows demand-driven re-export metadata and demand-slices unused `racket/private/for` exports; `first` and `rest` pass; `add-between` now gets past `unsafe-struct?` | richer `add-between` path leaves `impersonator?` after lowering |

The old `racket/list` blockers are no longer first failures:

- `racket/for` candidate overreach is skipped during provider closure.
- `racket/private/pico` decodes from the faslable-correlated provider shape.
- `1/reverse` resolves to `racket/private/pico`'s `reverse` export.
- `hash-update` resolves to `racket/private/more-scheme` via compiled provide metadata.
- `read` is avoided for the `first` smoke because unused `in-port` support is sliced away.

## Name-Resolution Frontiers

| Module | Current status | First blocker |
| --- | --- | --- |
| `racket/string` | Focused `string-join.1`/`string-join9.1` provider-export resolution works; sliced rename aliases are preserved | `add-between.1` unresolved import |

`racket/string` depends on `racket/list` for `add-between`, so progress on
`racket/list` is expected to move this frontier too.

## Demand Slicer Boundaries

The installed-module path now has a demand slicer, but it is deliberately a
bridge compatibility tool, not a general optimizer. It keeps only the provider
exports demanded by the root module graph, and it preserves the original bundle
metadata needed to decode aliases, declarations, and compiled provide tables.
That combination is what lets re-exports such as `racket/list`'s
`hash-update` and raw import aliases such as `1/reverse` survive slicing.

Known supported shapes are the ones exercised by the focused extractor tests:
plain `define-values` bindings, lambda/case-lambda dependencies, basic
let/letrec dependency discovery, quoted data, raw import binding orientation,
and `data`/`decl` metadata preservation. These are enough to avoid unrelated
provider exports for the current `racket/list` first/rest smokes.

Known limits:

1. The slicer does not prove arbitrary linklet expressions dead. When a shape is
   outside the dependency walker, it should be treated conservatively or pinned
   by a focused test before relying on it.
2. The slicer preserves compiled metadata, but it does not synthesize missing
   public-name information. A missing provider export still needs real
   bundle/provider resolution work.
3. The slicer is phase-0 oriented. Phase-specific syntax and transformer
   metadata should stay explicit in tests before being treated as supported.
4. A sliced graph can still expose real runtime/compiler gaps. The current
   `racket/list` `add-between` smoke reaches WebRacket lowering and now fails
   on `impersonator?`; that is not an installed-provider graph failure.

## IO-Dependent Frontiers

| Module/export | Current status | Boundary |
| --- | --- | --- |
| `racket/private/for` / `in-port` | Export is present, but its default producer imports `read` and `current-input-port` | Reader/port runtime support |

`in-port` is intentionally tracked separately from the rest of
`racket/private/for`: only a small port-sequence corner of the module pulls in
the IO layer. Demand slicing can avoid that corner for list-only workloads,
while real `in-port` support belongs to a future IO/runtime milestone.

## Deferred IO Strategy

The next Webify milestones should continue improving module/linklet composition
before implementing `read`. The important boundary is narrow: most
`racket/private/for` sequence support is not inherently IO-dependent, but
exports like `in-port`, `in-lines`, `in-input-port-bytes`, and
`in-input-port-chars` are. Racket's `src/io/README.txt` describes the underlying
IO layer as ports, paths, encoding, printing, and formatting backed by lower
runtime services such as primitive error support, parameters, threads/events,
and locks. That is a runtime subsystem decision, not a small
provider-resolution fix.

When IO work becomes intentional, split it into separate milestones:

1. Decide the supported WebRacket IO surface first: string ports only, browser
   stream ports, or a fuller port model.
2. Add minimal reader smokes independently from installed-module graph smokes.
3. Wire `in-port`, `in-lines`, and related sequence exports only after the
   underlying reader/port behavior is explicit.

## How To Move A Module

1. Add or update a focused extractor test that pins the graph/name-resolution
   fact.
2. Tighten the installed runtime smoke to the next exact failure.
3. Move the module row only after the focused test or smoke passes.
