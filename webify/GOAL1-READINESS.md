# Goal 1 Readiness Matrix

Goal 1 is module-based WebRacket programs in the browser, without `eval` and
without the old textual stdlib path. This matrix is the working checklist for
choosing the next milestone from evidence instead of memory.

## Legend

- `ready`: representative module-bridge runtime coverage passes.
- `owned`: WebRacket intentionally owns the provider because browser, VFS,
  runtime representation, FFI, or staged-original behavior differs from full
  Racket.
- `substituted`: a Racket provider is routed to a WebRacket provider.
- `postponed`: visible but not a Goal 1 implementation target.
- `diagnostic`: tracked as an expected-fail or no-substitution pressure row.

## Core Language Surface

| Surface | Current route | Readiness | Evidence | Next action |
| --- | --- | --- | --- | --- |
| `webracket/base` | local module bridge | ready | `base-local-expression`, language tests | Keep small; do not grow into `racket`. |
| `webracket/full` | curated add-on manifest | ready/partial | full surface audit, coverage rows | Keep every add-on tied to a dashboard row. |
| Local module graphs | module bridge | ready | module-language dashboard rows | Keep rejecting unsupported source require shapes rather than inventing a parallel expander. |
| External provider graph | provider bridge | ready/partial | installed-provider rows | Prefer installed providers when representative no-substitution rows reach runtime. |
| Old textual `stdlib/` | transitional | postponed | `STDLIB-RETIREMENT.md` | Avoid using it for Goal 1 work. |

## Installed Providers That Are Currently Proven Enough For Goal 1

| Provider | Route | Readiness | Evidence | Notes |
| --- | --- | --- | --- | --- |
| `racket/bool` | installed provider | ready | `installed-racket-bool-coverage` | Representative runtime coverage. |
| `racket/bytes` | installed provider | ready | `full-bytes-coverage` | Representative runtime coverage. |
| `racket/dict` | installed provider | ready | `installed-racket-dict-coverage`, `installed-racket-dict-extra-coverage` | Old staged dict shim retired from default route. |
| `racket/function` | installed provider | ready | `installed-racket-function-coverage` | Real provider is used directly. |
| `racket/list` | installed provider | ready | list coverage cluster | `shuffle` remains randomness-sensitive later work. |
| `racket/match` | installed provider | ready | `full-match-coverage`, `installed-racket-match-explicit` | Host expansion plus module bridge. |
| `racket/math` | installed provider plus inferred FFI where needed | ready | `full-math-coverage`, `ffi-js-math-coverage` | FFI bundle inference is part of this story. |
| `racket/path` | installed provider/runtime support | ready | `full-path-coverage` | Browser path behavior is still bounded by WebRacket runtime choices. |
| `racket/port` | substituted to `webracket/port` where needed | owned | `installed-racket-port-coverage`, `installed-racket-port-display` | Ports are tied to WebRacket string ports, VFS, and browser IO. |
| `racket/pretty` | installed provider | ready | pretty coverage rows | Uses real provider by default. |
| `racket/sequence` | installed provider | ready/partial | `real-racket-sequence-coverage` | Public helper surface is covered; advanced sequence edges remain documented. |
| `racket/private/for` | installed provider with staged support pressure | ready/partial | sequence/for coverage cluster | Not full upstream `racket/private/for`; see postponed edges below. |
| `racket/shared` | installed provider | ready | `full-shared-coverage` | Expansion-oriented coverage. |
| `racket/string` | installed provider | ready | string coverage rows | Real provider is the default route. |
| `racket/vector` | installed provider | ready | vector coverage rows | Representative runtime coverage. |
| `racket/class` | installed provider, `webracket/full` add-on | ready/partial | `full-class`, class diagnostic and coverage rows | Requires the default staged `io/format` provider; no-IO-format diagnostics are not a valid class/full proof. |

## WebRacket-Owned Or Staged Providers

| Provider | Route | Readiness | Evidence | Why owned |
| --- | --- | --- | --- | --- |
| `racket/contract` | `webracket/contract` | substituted/postponed | `full-contract-erased`, contract diagnostic row | Contracts are erased; enforcement, blame, chaperones, and impersonators are not Goal 1. |
| `syntax/contract` | `webracket/syntax/contract` | substituted/postponed | contract erasure tests | Expansion/provider-time contract erasure support. |
| `racket/file` | `webracket/file` | owned | `full-file-coverage`, VFS rows | Browser VFS behavior is not host filesystem behavior. |
| `racket/format` | staged `io/format` adapter | owned | format coverage rows | Uses staged original Racket IO/format slices instead of textual stdlib. |
| `racket/hash` | `webracket/hash` | owned | hash coverage rows | Must track WebRacket HAMT/hash representation. |
| `racket/mpair` | `webracket/mpair` | owned | mpair sequence rows | Runtime representation work. |
| `racket/promise` | `webracket/promise` | owned | `full-promise-coverage` | Ordinary promises are small browser-local semantics. |
| `racket/set` | `webracket/set` | owned | `full-set-coverage` | Must track WebRacket hash/HAMT behavior; contracts/generics postponed. |
| `racket/stream` | `webracket/stream` | substituted/postponed | stream coverage rows | Staged lazy stream syntax works for common cases; full stream internals postponed. |
| `regexp` | staged original regexp slice | owned | regexp provider coverage | Always-available provider slice. |
| `expander/read` | staged original reader slice | partial | expander/read provider tests | Useful because Goal 1 still uses host expansion, but reader runtime support is not complete. |
| `js/console`, `js/math`, `js/standard` | WebRacket FFI modules | owned | FFI coverage rows | Require implies matching unsafe FFI bundle. |

## Postponed Or Diagnostic Edges

| Area | Status | Reason |
| --- | --- | --- |
| Full `racket/contract` semantics | postponed | Needs contract enforcement, blame, chaperones, impersonators. |
| `racket/generator` | postponed | Depends on continuation prompts/composable continuations. |
| Weak/ephemeron hashes | postponed | Explicitly outside current HAMT/hash target. |
| `racket/private/for` advanced edges | postponed | Includes `in-files`/`in-glob`, flvector/fxvector sequences, weak/ephemeron hash sequence variants, original stream internals, custom sequence syntax, and some advanced combinators. |
| OS/network providers | postponed | `racket/cmdline`, `racket/future`, `racket/place`, `racket/system`, `racket/tcp`, and `racket/udp` are deferred. |
| `racket/unit` | postponed | Deferred from `webracket/full`; needs separate provider evidence before promotion. |

## Next Recommended Milestones

1. Run the compact checkpoint with a warm cache and record the current red/yellow rows.
2. Keep `full-class` in the compact checkpoint with the default io/format provider; do not run it in the no-IO-format lane.
3. Audit postponed `racket/private/for` exports with `webify/for-provider-surface.rkt` and decide which, if any, are Goal 1 requirements.
4. Tighten the staged-provider list so every substitution is either clearly owned or has a diagnostic replacement path.
5. Pick the next implementation target only from the matrix and dashboard output.

The current strongest candidate is now the next dashboard-selected red or
yellow row after the class/full checkpoint. Contract, list, sequence, and class
all have explicit Goal 1 stories; their remaining gaps are mostly deliberate
boundaries rather than forgotten first steps.
