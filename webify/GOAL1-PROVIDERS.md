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

- `webracket/function`: contract-free positional combinators. It intentionally
  does not yet preserve the full keyword arity metadata of installed
  `racket/function`.
- `webracket/list`: common callable `racket/list` surface for module programs.
  It is deliberately a staged provider now because installed `racket/list`
  still brings provider-graph and alias shapes that are heavier than Goal 1
  needs. Covered exports include selectors, folds/maps, `filter-map`,
  `append-map`, `append*`, `count`, `filter-not`, `partition`,
  `take`/`drop`/`split-at`, `takef`/`dropf`/`splitf-at`, membership/indexing
  helpers, `remove`/`remove*`/`remf`/`remf*`, `flatten`, list update/prefix
  helpers, `argmin`/`argmax`, `group-by`, `cartesian-product`,
  `combinations`, `in-combinations`, `permutations`, `in-permutations`,
  `add-between`, `remove-duplicates`, `check-duplicates`, and
  `range`/`inclusive-range`. Remaining differences are classified below;
  the current `range` implementation rejects a zero step instead of attempting
  to construct Racket's non-terminating list.
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
- `webracket/dict`: contract-free dictionary operations for hashes, vectors,
  and association lists. It includes the iteration protocol and `in-dict-*`
  single-value sequences needed by current `racket/dict` Goal 1 programs, but
  generic `prop:dict`, contracted dictionaries, chaperone/impersonator behavior,
  and Racket's full two-value `in-dict` sequence are postponed.

## Routing Rule

If `webracket/full` exposes a name that has a staged WebRacket provider, prefer
the staged provider over the installed provider. This keeps `webracket/full`
from accidentally becoming a tunnel into arbitrary installed Racket internals.

The concrete regression to guard is `compose` and `compose1`: `racket/base`
exports them, and installed `racket/function` / `racket/private/list` can pull
in keyword-preserving wrappers that WebRacket does not need for ordinary
positional module programs. `webracket/full` therefore exports the staged
`webracket/function` versions for those names.

The same rule now applies to `racket/list`: the module bridge routes external
`racket/list` requires to `webracket/list`, and `webracket/full` exports the
staged list surface instead of the installed provider.

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

- `webracket/full` exports the staged set surface, but set behavior is tracked
  through dedicated `webracket/set` dashboard rows. External explicit requires
  still need the module bridge path.
- `format` is available in `webracket/full` when the staged `io/format` provider
  is enabled. Tests that pass `--no-io-format-provider` should not use `format`;
  those tests are checking the smaller no-IO-provider path.
- `racket/string` currently routes through `webracket/string` in the module
  bridge for common operations such as `string-join`. The installed provider
  still exposes a deeper transitive `racket/list`/quasiquote edge that is better
  handled as a later provider-graph improvement.
- Coverage rows now exercise representative clusters for `racket/math`,
  `racket/path`, `racket/match`, `racket/sequence`, and the staged
  `webracket/file` VFS surface, not just single-function smoke tests.
- Additional coverage rows exercise staged `webracket/set`, `webracket/promise`,
  `webracket/stream`, `racket/pretty`, `racket/hash`, and `racket/format`.
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
- `racket/dict` routes to staged `webracket/dict`. The coverage row now checks
  both ordinary functions (`dict-map`, `dict-count`) and sequence exports such
  as `in-dict-pairs`. Keep it staged for now: the useful Goal 1 path is hashes,
  vectors, association lists, and iteration. The staged provider now includes
  the common derived operations from the Reference: capability predicates,
  `dict-ref!`, `dict-set*!`, `dict-set*`, `dict-remove!`, `dict-remove`,
  `dict-update!`, `dict-update`, `dict-copy`, `dict-clear`, `dict-clear!`,
  `dict-empty?`, and `dict-map/copy`. Generic `prop:dict`,
  `define-custom-hash-types`, contracted dictionaries, custom hash constructors,
  and chaperone-sensitive behavior remain explicitly outside the current target.
- `racket/pretty` routes to staged `webracket/pretty`. The supported surface is
  still intentionally shallow, but no longer just four procedures:
  `pretty-format`, `pretty-print`, `pretty-write`, `pretty-display`,
  `pretty-print-handler`, `pretty-print-newline`, and the basic pretty-printing
  parameters are available. The parameters are accepted for provider
  compatibility; graph-sensitive layout, hooks with real pretty-port
  integration, tentative pretty-print ports, and the full pretty writer remain
  later IO/printing work.
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

## Dashboard Presets

- `--fast-required` is the tiny inner-loop preset. Use it before and after
  focused edits.
- `--coverage-core` is the everyday commit-time coverage preset for the curated
  Goal 1 surface.
- `--coverage-extended` is the broader provider/FFI confidence preset. Use it
  before larger Goal 1 checkpoints.
- `--tier coverage` still runs every coverage row, including both core and
  extended rows.
