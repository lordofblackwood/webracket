# Staged Racket Sources

This directory contains small, staged copies of upstream Racket source files
that WebRacket is adapting incrementally. These files are not handwritten
WebRacket stdlib files.

## Upstream Source

The current staged `io` files were copied from:

```text
repository: ../racket
remote:     git@github.com:soegaard/racket.git
commit:    39bb8e670cfc32eee930b9eaab7d7bf27aedfd80
branch:    codex/fix-url-port-ephemeral-reuse
```

The upstream checkout was clean when these files were recorded.

## Files Currently Staged

```text
racket-src/io/format/main.rkt
racket-src/io/format/printf.rkt
racket-src/io/print/regexp.rkt
```

These files are intentionally copied as a minimal `io/format` staging slice.
Do not copy all of `../racket/racket/src/io/` at once; add files only when a
focused probe or provider composition needs them.

## Sync Guard

`webify/test-io-format-plan.rkt` currently checks that the staged files are
byte-for-byte identical to the upstream files at `../racket/racket/src/io/`.
When WebRacket starts adapting a staged file, update that test and document the
local divergence here.
