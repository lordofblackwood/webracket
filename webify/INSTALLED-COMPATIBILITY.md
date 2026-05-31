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
| `racket/list` | `(car (cdr (add-between '("a" "b") ",")))` prints `,` | `webify/test-installed-module-runtime.rkt` |
| `racket/list` | `(first (reverse (range 2 7 2)))` prints `6` | `webify/test-installed-module-runtime.rkt` |
| `racket/string` | `(string-join '("a" "b") ",")` prints `a,b` | `webify/test-installed-module-runtime.rkt` |
| `racket/string` | `(string-prefix? "abc" "ab")` prints `#t`/`true` | `webify/test-installed-module-runtime.rkt` |
| `racket/function` | `((compose add1 add1) 40)` prints `42` | `webify/test-installed-module-runtime.rkt` |

These prove that Webify can discover real installed providers, instantiate the
resulting module graph, and observe exported module cells without turning
provider exports into top-level aliases.

## Graph-Resolved Frontiers

| Module | Current status | First blocker |
| --- | --- | --- |
| `racket/list` | Goal 1 module programs route explicit `racket/list` requires to staged `webracket/list`; selectors, common folds/maps, `filter-map`, `append-map`, `append*`, `count`, `filter-not`, `partition`, take/drop/split variants, index helpers, removers, `flatten`, `assoc`, list update/prefix helpers, `argmin`/`argmax`, `group-by`, `cartesian-product`, combinations/permutations, keyword-sensitive `add-between`/`remove-duplicates`/`check-duplicates`, and `range`/`inclusive-range` smokes pass. The export audit now shows the only installed phase-0 export not provided by the staged provider is `shuffle`. | `shuffle` is postponed until WebRacket has an explicit randomness story; remaining behavioral differences are tracked in `GOAL1-PROVIDERS.md` |
| `racket/dict` | Goal 1 module programs route explicit `racket/dict` requires to staged `webracket/dict`; hash, vector, and association-list dictionaries cover the common primitive and derived operations, including mutation, functional update, removal, clear/copy, map/copy, and `in-dict-*` sequence helpers. A tiny direct installed-provider diagnostic passes. | Broader direct installed-provider rows moved past `new-keyword-apply`, `tail-contract-key`, and several contract-erasure ownership edges; the next direct row is still in contract-private provider resolution, so generic/custom/contracted dictionary behavior remains postponed. |
| `racket/pretty` | Goal 1 module programs route explicit `racket/pretty` requires to staged `webracket/pretty` for required coverage: main pretty output functions plus basic parameters and handler helpers. Direct no-substitution diagnostics now pass for the representative cluster, confirming the keyword arity-error and `racket/treelist`/`prop:stream` blockers are gone. | Full layout parity, style hooks, and tentative pretty-print ports remain IO/printing follow-up work. |
| `racket/file` | Goal 1 module programs route explicit `racket/file` requires to staged `webracket/file`; the staged surface now includes VFS-backed file readers/writers, `file->value`, `file->list`, `write-to-file`, `call-with-atomic-output-file`, recursive delete, and bit constants. | Host filesystem services such as locks, preferences, path closures, and platform-specific metadata are postponed. |

The old `racket/list` blockers are no longer first failures:

- `racket/for` candidate overreach is skipped during provider closure.
- `racket/private/pico` decodes from the faslable-correlated provider shape.
- `1/reverse` resolves to `racket/private/pico`'s `reverse` export.
- Demand slicing follows paired exports such as `((1/reverse reverse))`, so
  the internal implementation binding is retained while the external export
  cell remains named `reverse`.
- `hash-update` resolves to `racket/private/more-scheme` via compiled provide metadata.
- `read` is avoided for the `first` smoke because unused `in-port` support is sliced away.
- `raise-binding-result-arity-error` and
  `raise-definition-result-arity-error` are internal WebRacket primitives.
- `prop:method-arity-error` is treated as a runtime global struct-type
  property instead of a closure free variable.
- `variable-reference-constant?` on lowered module-variable references now
  uses the module cell's constance metadata instead of the core
  `$VariableReference` path.

## Name-Resolution Frontiers

| Module | Current status | First blocker |
| --- | --- | --- |
| `racket/string` | Installed `string-join` and `string-prefix?` smokes reach WebRacket; sliced rename aliases and transitive `racket/list` providers are preserved | Regexp-literal-dependent string exports, such as `string-split`, need literal/runtime support |
| `racket/function` | Installed `compose` smoke reaches WebRacket and prints `42` | Broader higher-order exports still need coverage |

`racket/string` depends on `racket/list` for `add-between`. The bridge now
recovers that transitive provider from compiled module-path-index metadata when
`phase-to-link-modules` is too sparse to name the public provider directly.

The current `string-split` probe does not fail because of provider graph
resolution. It reaches WebRacket compilation with a regexp literal such as
`#rx"[][.*?+|(){}\\$^]"`, and `datum->construction-expr` cannot construct that
literal yet. Treat that as a literal/runtime bridge gap, not as evidence that
`racket/string` provider discovery regressed.

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
   `racket/list` `add-between` smoke reaches WebRacket lowering/runtime
   compatibility forms after provider resolution; those are not installed-provider
   graph failures.

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
