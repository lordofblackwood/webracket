# Expander Read Provider

`racket-src/expander/read/` is a staged copy of Racket's `src/expander/read`
reader implementation. WebRacket demodularizes it through
`webify/read-provider.rkt`, producing one cached linklet in the provider cache.

## Current Integration

The provider is available behind:

```text
--expander-read-provider
```

When enabled, the driver composes the reader provider and publishes
Webify-owned aliases such as:

```text
webify-expander-read
webify-expander-read-language
webify-expander-current-readtable
webify-expander-string->number
```

The provider also publishes public reader aliases from the matching
`webify-expander-*` module-variable cells while the flag is active. This now
includes `read`, `current-readtable`, `string->number`, `make-readtable`,
`readtable?`, `readtable-mapping`, `current-reader-guard`, the `read-accept-*`
family, and related reader parameters/helpers. The compiler is parameterized so
these provider-owned public names can shadow the temporary runtime stubs instead
of being compiled as direct primitives.

Installed-module composition has a matching import-cell override: when a
linklet imports primitive `read` from a primitive module such as `#%kernel`,
the runtime-smoke composer can supply the expander/read provider cell instead
of synthesizing a fresh cell around the `$read` primitive procedure. This is
needed because module linklets receive imports through cells; a top-level
alias alone does not affect those imported cells.

## What Works

The provider demodularizes successfully and the first-slice adapter can recover
all expected `webify-expander-*` exports.

Focused runtime smokes cover:

- Reading from `open-input-string`.
- Lists and EOF.
- Quoted forms.
- Vectors.
- String datums, including Unicode.
- `#;` datum comments.
- Port location continuity after reads.

The installed-module probe inventory includes ordinary public `read` cases for
lists, vectors, symbol/string sequences, and datum comments. These now pass
when the probe harness enables `--expander-read-provider`, and they are in the
Goal 1 fast set.

The public runtime stub is still present for builds that do not enable the
provider flag. That fallback now formats input/output string ports as
`#<input-port>` and `#<output-port>` in its error path instead of falling into
the formatter's unknown-datatype branch.

## Read-Syntax Track

`read-syntax` is intentionally not part of the public handoff yet. The staged
`read/main.rkt` root exports datum `read` and `read-language`; syntax-aware
reading lives behind the upstream `read/api.rkt` and
`syntax/read-syntax.rkt` path. That path is tracked separately because it brings
syntax objects, source locations, and syntax-reader behavior into the surface
area. The staged source tree already contains `read/api.rkt`, but the
`syntax/read-syntax.rkt` dependency has not been copied into `racket-src/` or
flattened as a provider root yet.

The separate `read-syntax` track has started with:

- `racket-src/expander/read-syntax-provider-root.rkt`, a private provider root
  that exports `webify-expander-read-syntax` and
  `webify-expander-read-syntax/recursive`.
- `racket-src/expander/syntax/read-syntax.rkt`, copied from upstream as the
  first syntax-aware dependency.
- `racket-src/expander/common/performance.rkt`, copied after the first probe
  showed it was the next missing dependency.
- `racket-src/expander/syntax/syntax.rkt`, copied after the next probe showed
  that `read-syntax.rkt` needs the expander's syntax-object representation.
- `racket-src/expander/compile/serialize-property.rkt` and
  `racket-src/expander/compile/serialize-state.rkt`, copied as the paired
  serialization support that `syntax/syntax.rkt` requires.
- `racket-src/expander/common/set.rkt`, copied after the serialization support
  exposed the expander's lightweight set abstraction.
- `racket-src/expander/namespace/inspector.rkt`, copied after `common/set.rkt`
  exposed the syntax object's module-code-inspector parameter dependency.
- `racket-src/expander/syntax/preserved.rkt` and
  `racket-src/expander/syntax/datum-map.rkt`, copied together because preserved
  syntax properties directly depend on the datum walker used by `datum->syntax`
  traversal.
- `racket-src/expander/syntax/taint-object.rkt`, copied after syntax objects
  exposed taint propagation support for compound datum content.
- `racket-src/expander/syntax/weaker-inspector.rkt`, copied after taint objects
  exposed inspector lattice support used by syntax-property handling.
- `webify/read-syntax-provider.rkt` and
  `webify/check-read-syntax-provider.rkt`, a focused demod probe for this
  track.

The current ratchet test expects the probe to reach the next missing file:
`racket-src/expander/syntax/property.rkt`. The full dependency table now
lives in `webify/SYNTAX-SLICE.md`. The probe is expected to reveal
additional missing `expander/syntax`, `expander/namespace`, `expander/eval`,
and `expander/compile` dependencies before it can flatten successfully. Plain
public `read-syntax` should stay unpublished until that dependency story is
understood.

The dependency sequence so far is intentionally ratcheted by
`webify/test-read-syntax-provider.rkt`:

- `syntax/read-syntax.rkt` exposed `common/performance.rkt`.
- `common/performance.rkt` exposed `syntax/syntax.rkt`.
- `syntax/syntax.rkt` exposed `compile/serialize-property.rkt`.
- `compile/serialize-property.rkt` and `compile/serialize-state.rkt` exposed
  `common/set.rkt`.
- `common/set.rkt` exposed `namespace/inspector.rkt`.
- `namespace/inspector.rkt` exposed `syntax/preserved.rkt`.
- `syntax/preserved.rkt` exposed `syntax/datum-map.rkt`; after copying both,
  the next boundary is `syntax/taint-object.rkt`.
- `syntax/taint-object.rkt` exposed `syntax/weaker-inspector.rkt`.
- `syntax/weaker-inspector.rkt` exposed `syntax/property.rkt`.

## Primitive Ownership Cleanup Statuses

The primitive ownership collision report uses a `status` column to explain why
a provider-owned public name is still present in the primitive database:

- `temporary`: a runtime primitive exists only as a bridge while the provider
  is optional or incomplete. `read` is in this class while
  `--expander-read-provider` remains opt-in.
- `remove-primitive-later`: the replacement provider path is already the
  intended owner, but the runtime primitive is still useful during migration.
  Current examples include regexp and `io/format` names.
- `review`: no settled ownership decision has been made yet. Treat these names
  as cleanup work, not as evidence that both definitions should remain public.

## Missing Before Public Replacement

- Decide public ownership for `read-syntax`.
- Audit optional keyword behavior around the upstream reader's `read` entry.
- Decide whether `read-syntax` comes from `expander/read/api.rkt` or a later
  syntax-aware provider slice.
- Test reader extensions: `#reader`, `#lang`, compiled-code reading, and custom
  readtables.
- Keep the provider behind `--expander-read-provider` until the larger stdlib
  and provider-composition story is settled. A small `--stdlib
  --expander-read-provider` hello smoke did not reproduce the earlier duplicate
  WAT identifier problem, but the check is not proof that every stdlib/provider
  composition is clean.
- Remove or narrow the current public `read` runtime stub once the staged
  provider is no longer optional.

## Recommendation

The next safe step is to keep moving one public name at a time. Public `read`
has a staged handoff now; the next candidates are the reader parameters and
`current-readtable`, followed by a separate `read-syntax` provider slice.
