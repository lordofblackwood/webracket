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

The provider also publishes plain public `read` from the
`webify-expander-read` module-variable cell while the flag is active. The
compiler is parameterized so this one provider-owned public name can shadow the
runtime stub instead of being compiled as a direct primitive.

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
`syntax/read-syntax.rkt` path. That path should be tracked separately because
it brings syntax objects, source locations, and syntax-reader behavior into the
surface area.

The next `read-syntax` milestone should stage the smallest source slice that
exports `read-syntax` under a Webify-owned alias, for example
`webify-expander-read-syntax`, without publishing plain `read-syntax` until
the syntax provider dependency story is clear.

## Missing Before Public Replacement

- Decide public ownership for `read-syntax`, `string->number`,
  `current-readtable`, and `read-accept-*`.
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
