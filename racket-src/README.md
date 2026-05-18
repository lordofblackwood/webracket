# Staged Racket Sources

This directory contains staged copies of upstream Racket source files that
WebRacket is adapting incrementally. These files are not handwritten WebRacket
stdlib files.

## Upstream Source

The current staged `io` files, the copied `regexp/` tree, and the first
`expander/read` slice were copied from:

```text
repository: ../racket
remote:     git@github.com:soegaard/racket.git
commit:    39bb8e670cfc32eee930b9eaab7d7bf27aedfd80
branch:    codex/fix-url-port-ephemeral-reuse
```

The upstream checkout was clean when these files were recorded.

## Files Currently Staged

### Minimal `io/format` Slice

```text
racket-src/io/common/check.rkt
racket-src/io/error/value-string.rkt
racket-src/io/format/main.rkt
racket-src/io/format/printf.rkt
racket-src/io/port/output-port.rkt
racket-src/io/port/parameter.rkt
racket-src/io/port/string-output.rkt
racket-src/io/port/string-port.rkt
racket-src/io/print/main.rkt
racket-src/io/print/main-web.rkt
racket-src/io/print/mode.rkt
racket-src/io/print/parameter.rkt
racket-src/io/print/regexp.rkt
racket-src/io/string/convert.rkt
```

These files are intentionally copied as a minimal `io/format` staging slice:
the format sources, the print regexp hook, and the direct dependencies needed
for the first provider probe. Do not copy all of `../racket/racket/src/io/` at
once; add files only when a focused probe or provider composition needs them.

The print seed files are also the planned owner for high-level `write`,
`display`, `print`, and newline variants. The first helper slice additionally
stages `bytes.rkt`, `char.rkt`, `config.rkt`, `custom-write.rkt`,
`more-pending.rkt`, `string.rkt`, `symbol.rkt`, and `write-with-max.rkt`.
`print/main-web.rkt` is WebRacket-local adapter glue for cell-only provider
tests, not upstream source. The current provider plan and blocker list live in
`webify/IO-PRINT.md` and `webify/io-print-provider.rkt`.

### Whole `regexp/` Slice

```text
racket-src/common/check.rkt
racket-src/regexp/
```

The regexp implementation is staged as the complete upstream source tree. That
is intentional: Racket CS already demodularizes `src/regexp/main.rkt` into one
closed linklet, and WebRacket should reuse that shape instead of maintaining a
handwritten regexp stdlib. The cache-aware provider helper in
`webify/regexp-provider.rkt` runs the demodularizer against
`racket-src/regexp/main.rkt` and writes one reusable `regexp.rktl` artifact.
The shared `racket-src/common/check.rkt` helper is included because
`regexp/main.rkt` requires it through the same relative path that the upstream
`src/regexp/` tree uses.

### `expander/read` Slice

```text
racket-src/expander/common/
racket-src/expander/host/string-to-number.rkt
racket-src/expander/read/
racket-src/expander/read-provider-root.rkt
```

The reader is staged as a provider candidate before replacing WebRacket's old
stdlib reader. The copied `read/` tree is mostly self-contained, but it needs a
small set of `expander/common/` helpers and the host `string-to-number` helper
for number parsing. `read-provider-root.rkt` is WebRacket-local glue: it
re-exports the upstream reader entry points under `webify-expander-*` names so
the demodularized linklet has Webify-owned exports and does not collide with
existing public names such as `read` and `string->number`.

## Sync Guard

`webify/test-io-format-plan.rkt` currently checks that the staged `io` files
are byte-for-byte identical to the upstream files at `../racket/racket/src/io/`.
The regexp and expander/read provider tests check the copied trees exist and
that the demod commands use staged source. When WebRacket starts adapting a
staged file, update the corresponding test and document the local divergence
here.
