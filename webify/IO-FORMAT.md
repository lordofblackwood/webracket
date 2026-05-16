# `io/format` Staging Plan

WebRacket should replace the temporary `stdlib/writing.rkt` formatting layer
with a staged copy of Racket's `io/format` implementation in small pieces. The
staged source lives in:

```text
racket-src/io/
```

The important first boundary is that `io/format` itself does not depend on the
regexp implementation.

## Regexp Boundary

The format parser in:

```text
racket-src/io/format/main.rkt
racket-src/io/format/printf.rkt
```

scans the format string manually with `string-ref` and dispatches on `~`
directives. It does not use `regexp`, `#rx`, `#px`, `regexp-match`, or
`regexp-replace`.

The nearby regexp dependency is in the printing layer:

```text
racket-src/io/print/main.rkt
racket-src/io/print/regexp.rkt
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

The staged files currently copied from upstream are:

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
racket-src/io/print/mode.rkt
racket-src/io/print/parameter.rkt
racket-src/io/print/regexp.rkt
racket-src/io/string/convert.rkt
```

Additional `io` files should be copied into `racket-src/io/` only when the
next probe needs them.

The dependency guard also reports the current local transitive closure. The
first direct slice is present, but `print/main.rkt` still points at many
unstaged print and port helpers, and `common/check.rkt` intentionally exposes
that some shared Racket CS support lives outside `src/io`.

Current closure shape:

```text
present staged files: 13
missing io transitive files: 32
external shared support files: 1
```

The next provider milestone should decide whether to copy the missing print
and port helpers, or to introduce a smaller adapter around the operations that
`format/printf.rkt` actually calls.

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
   `output-port?` support for `fprintf`. The focused no-stdlib smoke is
   `webify/test-io-format-substrate.rkt`.
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
