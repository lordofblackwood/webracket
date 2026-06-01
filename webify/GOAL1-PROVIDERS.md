# Goal 1 Provider Plan

Goal 1 is module-based WebRacket programs in the browser, without relying on
`eval` and without the old textual stdlib path. The provider strategy is
curated: use installed Racket providers when they compose cleanly, and use
WebRacket-owned staged providers when installed providers drag in contracts,
chaperones, expander internals, unsupported keyword metadata, or browser-hostile
runtime services.

## Provider Classes

- `installed-provider-graph`: an installed Racket library is extracted and
  composed through the module bridge. These rows need more than a one-function
  smoke before we trust them as broadly supported.
- `installed-provider-coverage`: a broader dashboard row for an installed
  provider that exercises several common APIs. These rows are intentionally
  separate from the basic smoke rows so failures can be classified without
  hiding the small signal.
- `installed-provider-diagnostic`: an expected-fail row for an API edge we want
  to keep visible without making the required dashboard red.
- `language-staged-provider`: a WebRacket-owned provider substitutes for a
  Racket library or a library-like surface. These providers are browser-first
  and deliberately avoid postponed features such as contracts, generic
  interfaces, chaperones, and impersonators unless explicitly documented.
- `staged-provider-slice`: staged original Racket code that is extracted or
  demodularized as a reusable provider, such as `io/format` and `regexp`.
- `ffi-module`: a module whose require implies an unsafe FFI bundle, such as
  `js/math` or `js/console`.

## Current Staged Providers

- `webracket/set`: hash-backed set operations. Contracts, generics,
  chaperones, and impersonators are postponed.
- `webracket/promise`: ordinary promise caching for browser programs. Advanced
  synchronization-oriented promise variants are postponed.
- `webracket/stream`: finite stream constructors and selectors for common
  module programs. It avoids importing the full `racket/stream` implementation;
  `stream` and `stream-cons` preserve the lazy syntax shape for staged streams,
  and staged streams expose `prop:sequence` so ordinary `for` clauses can
  iterate over them. The staged surface now includes finite helpers such as
  `stream-length`, `stream-ref`, `stream-tail`, `stream-take`, `stream-append`,
  `stream-map`, and `stream-filter`.
- `webracket/contract`: erased contracts. It preserves provider shape and common
  forms, but it does not enforce contracts.
- `webracket/file`: a small VFS-oriented file provider. This is useful for
  browser tests and examples, including `file-exists?`, `display-to-file`, and
  `file->string`, but it is not a complete host filesystem story.
- `webracket/format`: compact formatting surface while the staged `io/format`
  provider continues to grow.
- Retired staged compatibility shims include `webracket/list` and
  `webracket/dict`. They remain useful for focused regression tests, but
  explicit Goal 1 module requires now use the installed `racket/list` and
  `racket/dict` providers by default.

## Routing Rule

If `webracket/full` exposes a name that has a staged WebRacket provider, prefer
the staged provider over the installed provider. This keeps `webracket/full`
from accidentally becoming a tunnel into arbitrary installed Racket internals.

The driver uses one substitution table for both source-level `require` forms
and provider-graph fetching. Diagnostics can disable the table with
`--no-provider-substitutions`; required Goal 1 rows should normally leave it
enabled.

The table is represented in `driver.rkt` as structured records, not just pairs.
Each substitution has a classification and replacement pressure:

- `temporary-shim`: useful for Goal 1 progress, but the long-term direction is
  to replace it with original Racket code or a much thinner adapter.
- `runtime-owned`: WebRacket should probably keep owning it because browser,
  VFS, FFI, port, representation, or runtime behavior genuinely differs.
- `diagnostic-shim`: intentionally non-complete and present only so unrelated
  module graphs can keep moving while the real feature is postponed.
- `high` pressure means we should prefer bridge/runtime fixes over adding more
  staged API surface.
- `medium` pressure means the shim is acceptable temporarily, but new functions
  should still require a concrete reason.
- `low` pressure means the substitute is probably WebRacket-specific enough
  that replacing it with installed Racket code is not the main goal.

Each substitution also has an audit disposition:

- `keep-webracket-owned`: keep the WebRacket provider as the intended Goal 1
  route because runtime representation, browser/VFS behavior, or host boundary
  semantics differ from full Racket.
- `retire-soon`: actively look for a path back to original Racket code or a
  staged original provider once the named blocker is removed.
- `postpone`: keep the substitute visible, but do not spend Goal 1 effort on
  replacing it yet because the missing feature is outside the current browser
  module-program target.

The former concrete regression to guard was `compose` and `compose1`, where
installed `racket/function` could pull in keyword-preserving wrappers. That
path now passes real-provider diagnostics with substitutions disabled, so
`webracket/full` imports `racket/function` directly.

This rule should stay narrow. Earlier Goal 1 work routed several installed
providers through staged `webracket/*` modules; the default bridge now uses the
real installed providers for `racket/class`, `racket/dict`, `racket/function`,
`racket/list`, `racket/pretty`, `racket/sequence`, `racket/string`,
`racket/private/for`, and
`racket/private/kw` after their representative diagnostics reached runtime.

## Provider Substitution Audit

The current `racket/*` -> `webracket/*` substitutions are:

| Requested provider | Routed provider | Classification | Disposition | Reason |
| --- | --- | --- | --- | --- |
| `racket/contract`, `racket/contract/base`, `racket/contract/combinator`, `racket/contract/region`, selected `racket/contract/private/*` | `webracket/contract` | temporary shim | postpone | Erased contracts let module programs run before chaperones, impersonators, blame, and full contract enforcement are ready. |
| `racket/file` | `webracket/file` | runtime-owned | keep WebRacket-owned | Browser/VFS file behavior is not host filesystem behavior; use a WebRacket provider around the VFS. |
| `racket/format` | `webracket/format` | temporary shim | retire soon | Formatting should move toward staged original `io/format` plus thin adapters; the compact shim should shrink as `~a`, `~s`, and `~v` coverage matures. |
| `racket/generator` | `webracket/generator` | diagnostic shim | postpone | Generators depend on continuation prompts/composable continuations, which are not Goal 1. |
| `racket/hash` | `webracket/hash` | temporary shim | keep WebRacket-owned | Hash helpers should stay aligned with WebRacket's HAMT/runtime hash implementation and equality/hash-table representation. |
| `racket/mpair` | `webracket/mpair` | runtime-owned | keep WebRacket-owned | Mutable pairs are runtime representation work, not a good installed-provider dependency. |
| `racket/port` | `webracket/port` | runtime-owned | keep WebRacket-owned | Port behavior is tied to WebRacket string ports, VFS, and browser IO. |
| `racket/promise` | `webracket/promise` | runtime-owned | keep WebRacket-owned | Ordinary promise semantics are small and browser-local; synchronization-oriented variants remain later work. |
| `racket/set` | `webracket/set` | temporary shim | keep WebRacket-owned | Set support follows WebRacket hash/HAMT behavior and postpones contracts/generics/chaperones. |
| `racket/stream` | `webracket/stream` | temporary shim | postpone | Staged streams preserve lazy syntax for common cases; importing full stream internals is not the next Goal 1 lever. |
| `racket/unsafe/undefined` | `webracket/unsafe/undefined` | runtime-owned | keep WebRacket-owned | Runtime undefined values need WebRacket representation support. |
| `syntax/contract` | `webracket/syntax/contract` | temporary shim | postpone | Supports contract erasure at expansion/provider time. |

The immediate staged-provider audit result for the requested providers is:

- Retire soon: `racket/format`.
- Keep WebRacket-owned: `racket/hash`, `racket/set`, `racket/promise`.
- Postpone: `racket/stream`.

`racket/function` has been retired from this table: the real provider now
passes the module-bridge diagnostic and coverage rows with provider
substitutions disabled, so `webracket/full` imports it directly.

## Real Provider Readiness

Use `webify/goal1-dashboard.rkt --real-provider-readiness --jobs 4
--timeout 120 --memory-mb 1024` to run the expected-fail rows that keep
replacement pressure visible. These rows intentionally disable provider
substitutions.

| Provider/frontier | Readiness row | Current blocker/action |
| --- | --- | --- |
| `webracket/contract` | `real-racket-contract-diagnostic` | Current failure is provider-graph extraction for real `racket/contract`; keep using erased-contract shims while narrowing the transitive provider graph and runtime primitive demand. |
| real installed providers | `real-racket-class-diagnostic`, `real-racket-dict-diagnostic`, `real-racket-dict-coverage-diagnostic`, `real-racket-function-diagnostic`, `real-racket-function-coverage-diagnostic`, `real-racket-list-diagnostic`, `real-racket-string-diagnostic`, `real-racket-pretty-diagnostic`, `real-racket-pretty-coverage-diagnostic`, `real-racket-sequence-diagnostic`, `real-racket-private-for-diagnostic`, `real-racket-private-kw-diagnostic` | These rows now pass representative diagnostics without provider substitution. They remain on the dashboard as regression guards for the real-provider path. |

## `racket/list` Export Audit

The current installed-vs-staged audit shows 62 installed phase-0 exports and the
staged provider now covers all of those exports except `shuffle`. The
host-side audit in `webify/test-webracket-list.rkt` pins that boundary so new
installed exports or accidental staged-provider regressions are visible. The
remaining compatibility notes are:

- Postponed/randomness-sensitive: `shuffle`. It should wait for an explicit
  WebRacket randomness story instead of quietly choosing host-specific or
  deterministic behavior.
- Keyword-sensitive coverage: `add-between`, `remove-duplicates`, and
  `check-duplicates` are source-defined in `webracket/list`; keep them that way,
  because equivalent primitive forms do not generally preserve Racket's keyword
  surface.
- Error-shape coverage: the staged provider now rejects common bad shapes for
  prefix helpers, list update helpers, `argmin`/`argmax`, and splicing
  `add-between` cases instead of silently accepting them. The messages are not
  byte-for-byte contract messages, but the observable failure boundary is much
  closer to `racket/list`.
- Exact sequence fidelity: `in-combinations` and `in-permutations` currently
  return list-valued sequences. This is sufficient for Goal 1 module programs
  that use them in ordinary `for` clauses, but it is not the same
  generator-backed object shape as installed `racket/list`.
- Provider-ownership note: do not re-export equivalent primitives directly from
  `webracket/list` yet. Primitive aliases create extra reflection candidates
  such as both `webracket/list` and `racket/list` owning `append-map`.

## Current Full-Language Notes

- `webracket/full` is intentionally curated. Its surface manifest has an audit
  row for every add-on library, and each row must be either
  `real-provider-proven` or `webracket-owned` with a dashboard case. This keeps
  the full language from quietly growing into an unreviewed re-export of
  installed Racket.
- `racket/class` is deferred from `webracket/full` for now. The module bridge
  has diagnostics for explicit `racket/class` requires, but `webracket/full`
  should not advertise class exports until we add them deliberately with
  required dashboard coverage.
- `webracket/full` exports the staged set surface, but set behavior is tracked
  through dedicated `webracket/set` dashboard rows. External explicit requires
  still need the module bridge path.
- `format` is available in `webracket/full` when the staged `io/format` provider
  is enabled. Tests that pass `--no-io-format-provider` should not use `format`;
  those tests are checking the smaller no-IO-provider path.
- `racket/string` now uses the installed provider by default. The earlier
  staged route remains useful as a narrow regression shim, but it is no longer
  the Goal 1 default path for explicit module requires.
- Coverage rows now exercise representative clusters for `racket/math`,
  `racket/path`, `racket/match`, `racket/sequence`, and the staged
  `webracket/file` VFS surface, not just single-function smoke tests.
- Additional coverage rows exercise staged `webracket/set`, `webracket/promise`,
  `webracket/stream`, real `racket/pretty`, `racket/hash`, and
  `racket/format`.
- Coverage rows also exercise `racket/bool`, `racket/bytes`, `racket/shared`,
  inferred `js/math` and `js/console` FFI bundles, and the staged regexp
  provider.
- Extended coverage rows exercise the runtime-adjacent providers that are
  intentionally narrow today: `racket/file` through the VFS substitute,
  `data/queue` through its contract-erased queue operations, and
  `racket/logging` through its currently exported contract surface.
- Sequence coverage is split into smaller dashboard rows so failures identify
  the prerequisite cluster: core list/vector/string/bytes/indexed generation,
  hash iteration plus `sequence-generate`, mutable lists, input-port byte/char
  and line sequences, `prop:sequence`, real-library pressure rows, and derived
  combinators such as `in-sequences`, `in-cycle`, `in-parallel`,
  `in-values-sequence`, `stop-before`, and `stop-after`. This is still not full
  `racket/private/for`, but explicit public helpers for `in-list`, `in-vector`,
  `in-string`, `in-range`, `in-inclusive-range`, and `in-naturals` are now
  covered. Optimized hash helper defaults and checker variants for ordinary,
  immutable, and mutable hashes are covered too. The staged provider also
  exports the upstream-style sequence entry points for integer, list,
  mutable-list, vector, string, bytes, input-port, and hash sequences, plus the
  internal `prop:gen-sequence`/`do-sequence` surface needed by installed
  provider code. `in-directory` is implemented through WebRacket's virtual
  filesystem-backed `directory-list`, `directory-exists?`, and path primitives.
  `sequence-add-between` is lazy, so it works with infinite producers such as
  `in-cycle` when a surrounding `for` clause bounds consumption.
  `in-files`/`in-glob`, flvector/fxvector sequences, weak/ephemeron hash
  sequence variants, original stream internals, custom sequence syntax, and
  some advanced sequence combinators remain later work.
- `racket/generator` is not part of Goal 1. It still routes to
  `webracket/generator`, a no-op shim, when encountered, because the original
  provider depends on continuation prompts and composable continuations. The
  dashboard keeps a diagnostic row for the eventual continuation/prompt
  milestone, but required Goal 1 sequence rows avoid generator-dependent
  behavior.
- `webify/for-provider-surface.rkt` compares original `racket/private/for`
  exports with the staged provider and classifies them as supported, postponed,
  or missing. Use it when deciding whether the next sequence feature belongs in
  the staged provider or should remain documented as postponed.
- `racket/dict` now uses the installed provider by default. Coverage checks ordinary
  functions (`dict-map`, `dict-count`), sequence exports such as
  `in-dict-pairs`, capability predicates, mutation/update helpers, removal,
  clear/copy, `dict-map/copy`, and `keyword-apply/dict`.
- `racket/pretty` now uses the installed provider by default. Coverage is
  formatting-oriented: `pretty-format`, `pretty-print`,
  `pretty-write`, `pretty-display`, basic style-table helpers, and common
  pretty-print parameters, including the former `racket/treelist`
  `prop:stream` edge.
- `racket/file` routes to staged `webracket/file`. Treat it as a virtual
  filesystem provider, not a host filesystem provider. The current focus is
  portable functions such as `file-exists?`, `directory-list`,
  `display-to-file`, `file->string`, `file->value`, `file->list`,
  `write-to-file`, and `call-with-atomic-output-file`. Permission and file-type
  bit constants are exported for compatibility. `file->value` and `file->list`
  are reader-backed convenience wrappers; they are part of the staged API, but
  required Goal 1 runtime rows avoid depending on the incomplete reader runtime.
  Locks, preferences,
  path-closure discovery, links, timestamps, path normalization quirks, and
  host-specific filesystem effects are not Goal 1 requirements.

## Compatibility Policy

- Passing a basic dashboard row means the provider composes and one common use
  works.
- Passing a coverage row means a small representative API cluster works.
- Neither is a claim of full Racket compatibility.
- Passing or failing a diagnostic row does not affect required Goal 1 status; it
  records a known unsupported or fragile edge for later work.
- When a coverage row fails, decide whether to improve WebRacket primitives,
  improve a staged provider, or explicitly postpone that part of the API.
- For `high` pressure temporary shims, do not add new staged exports until
  checking whether a bridge/runtime fix would let the original provider compose.
  If a staged export is still added, document the reason and add a diagnostic
  or readiness row that keeps the replacement path visible.

## Dashboard Presets

- `--fast-required` is the tiny inner-loop preset. Use it before and after
  focused edits.
- `--coverage-core` is the everyday commit-time coverage preset for the curated
  Goal 1 surface.
- `--coverage-extended` is the broader provider/FFI confidence preset. Use it
  before larger Goal 1 checkpoints.
- `--tier coverage` still runs every coverage row, including both core and
  extended rows.
- `--real-provider-readiness` runs diagnostic rows with provider substitutions
  disabled. These rows may pass as staged providers are retired; their job is to
  show what is blocking or guarding replacement of staged providers with
  original Racket providers.
