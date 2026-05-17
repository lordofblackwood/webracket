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

The provider deliberately does not publish plain `read` yet. `read`,
`read-syntax`, `string->number`, `current-readtable`, and the `read-accept-*`
parameters are still primitive or stdlib-owned public names. Publishing a
top-level `(define read ...)` today collides with primitive ownership.

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

The installed-module probe inventory now includes ordinary public `read` cases
for lists, vectors, symbol/string sequences, and datum comments. They are not
part of the passing Goal 1 fast set yet: public `read` is still a loud runtime
stub, so these cases are tracking probes for the later ownership swap.

## Missing Before Public Replacement

- Decide public ownership for `read`, `read-syntax`, `string->number`,
  `current-readtable`, and `read-accept-*`.
- Remove or rename old primitive/stdlib-owned public names before publishing
  provider aliases with those names.
- Audit optional keyword behavior around the upstream reader's `read` entry.
- Decide whether `read-syntax` comes from `expander/read/api.rkt` or a later
  syntax-aware provider slice.
- Test reader extensions: `#reader`, `#lang`, compiled-code reading, and custom
  readtables.
- Keep the provider behind `--expander-read-provider` until the duplicate-WAT
  identifier problem from unconditional stdlib composition is understood.
- Replace the current public `read` runtime stub, which still raises
  `reader-unsupported` and even exposes a formatter gap when it tries to report
  an input port in the error message.

## Recommendation

The next safe step is to move one public name at a time. Start with `read` in a
focused branch: remove public primitive ownership for `read`, compose this
provider under stdlib, publish `read` as a module-variable alias to
`webify-expander-read`, then run the Goal 1 `read-*` probes and the existing
port tests.
