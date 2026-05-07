# Installed Module Compatibility Ladder

This ladder tracks real installed Racket modules through the Webify bridge. It
is intentionally small and evidence-based: a module moves only when a focused
test or smoke demonstrates the new status.

## Passing Runtime Smokes

| Module | Smoke | Evidence |
| --- | --- | --- |
| `racket/bool` | `(boolean=? #t #t)` prints `#t`/`true` | `webify/test-installed-module-runtime.rkt` |
| `racket/fixnum` | `(fx+ 1 2)` prints `3` | `webify/test-installed-module-runtime.rkt` |

These prove that Webify can discover real installed providers, instantiate the
resulting module graph, and observe exported module cells without turning
provider exports into top-level aliases.

## Graph-Resolved Frontiers

| Module | Current status | First blocker |
| --- | --- | --- |
| `racket/list` | Provider graph advances through nested MPI paths and faslable providers | `hash-update` unresolved import |

The old `racket/list` blockers are no longer first failures:

- `racket/for` candidate overreach is skipped during provider closure.
- `racket/private/pico` decodes from the faslable-correlated provider shape.
- `1/reverse` resolves to `racket/private/pico`'s `reverse` export.

## Name-Resolution Frontiers

| Module | Current status | First blocker |
| --- | --- | --- |
| `racket/string` | Focused `string-join.1`/`string-join9.1` provider-export resolution works | `add-between.1` unresolved import |

`racket/string` depends on `racket/list` for `add-between`, so progress on
`racket/list` is expected to move this frontier too.

## How To Move A Module

1. Add or update a focused extractor test that pins the graph/name-resolution
   fact.
2. Tighten the installed runtime smoke to the next exact failure.
3. Move the module row only after the focused test or smoke passes.
