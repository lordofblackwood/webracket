# `io/format` Staging Plan

WebRacket should replace the temporary `stdlib/writing.rkt` formatting layer
with Racket's `../racket/racket/src/io/format` implementation in small pieces.
The important first boundary is that `io/format` itself does not depend on the
regexp implementation.

## Regexp Boundary

The format parser in:

```text
../racket/racket/src/io/format/main.rkt
../racket/racket/src/io/format/printf.rkt
```

scans the format string manually with `string-ref` and dispatches on `~`
directives. It does not use `regexp`, `#rx`, `#px`, `regexp-match`, or
`regexp-replace`.

The nearby regexp dependency is in the printing layer:

```text
../racket/racket/src/io/print/main.rkt
../racket/racket/src/io/print/regexp.rkt
```

`io/print/regexp.rkt` exports only a hook:

```racket
printable-regexp?
set-printable-regexp?!
```

The hook starts with `printable-regexp?` returning `#f`. A later demodularized
regexp provider can install the real predicate. Until then, format can move
first, and regexp values may remain unprintable or use the existing bootstrap
fallback.

The guard script:

```sh
../racket/racket/bin/racket webify/io-format-deps.rkt
```

checks this source-level boundary.

## Minimal Direct Dependencies

`io/format/main.rkt` directly requires:

```text
../common/check.rkt
../port/parameter.rkt
../print/parameter.rkt
../port/output-port.rkt
../port/string-port.rkt
../string/convert.rkt
format/printf.rkt
```

`io/format/printf.rkt` directly requires:

```text
../print/main.rkt
../print/main.rkt submodule internal
../print/mode.rkt
../port/string-output.rkt
../port/output-port.rkt
../error/value-string.rkt
```

This means the first implementation target is not all of `io/main.rkt`; it is a
small in-memory-port, print-parameter, error-value-string, and printf slice.
The dependency guard reports both direct paths and direct require specs so the
internal print submodule edge remains visible.

## Implementation Order

1. Stabilize in-memory output ports:
   `open-output-string`, `get-output-string`, `write-string`, and enough
   `output-port?` support for `fprintf`.
2. Compose or port `io/format/printf.rkt` behind a focused probe.
3. Compose or port `io/format/main.rkt`.
4. Keep `io/print/regexp.rkt` as a hook-only module with
   `printable-regexp? => #f`.
5. Move `format` and `fprintf` out of the temporary primitive-owned overlap
   list only after the provider smoke passes.
6. Integrate the demodularized regexp provider later, then install
   `set-printable-regexp?!`.

## Tests

The focused tests are in:

```text
webify/test-io-format-plan.rkt
```

They check that the format sources remain regexp-free, that the direct
dependency slice is what we expect, and that regexp enters this area only as the
printing hook.
