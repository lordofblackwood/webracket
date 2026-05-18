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

The current adapter surface used by `format/printf.rkt` is:

```racket
->core-output-port
PRINT-MODE/UNQUOTED
display-via-handler
do-display
do-print
do-write
error-print-width
error-value->string
print-unreadable
print-via-handler
write-string
write-via-handler
```

That is much smaller than the full transitive `io/print/main.rkt` closure, so
the preferred next implementation path is an adapter/proxy for these names, not
a blind copy of all print and host support.

`format/main-web.rkt` additionally uses `print-boolean-long-form` for the
single-argument boolean fast path.

The first adapter files are:

```text
racket-src/io/format/printf-adapter.rkt ; WebRacket-facing print/port proxy
racket-src/io/format/printf-web.rkt     ; adapted do-printf require surface
racket-src/io/format/main-web.rkt       ; adapted public format API
webify/io-format-provider.rkt           ; ownership/readiness metadata
webify/test-io-format-adapter.rkt       ; host-side behavior smoke
webify/test-io-format-main-adapter.rkt  ; host-side public API smoke
webify/test-io-format-provider.rkt      ; provider ownership smoke
webify/test-io-format-composition.rkt   ; module-variable provider fixture
webify/test-io-format-extraction.rkt    ; source/extracted provider smoke
```

`printf-web.rkt` intentionally keeps the upstream `do-printf` body and changes
only the require surface. It is not part of the byte-for-byte upstream sync
guard.

The WebRacket stdlib no longer carries its own hand-written implementation of
the format family. Public `format` and `fprintf` are now provided by the staged
original-Racket-derived `io/format` bridge when `--stdlib` is enabled, not by
compiler/runtime primitive bindings.

Avoid adding a second WebRacket-specific formatter to `stdlib/`;
`stdlib/writing.rkt` should own only the writing/printing substrate.

Current ownership status:

```racket
format   ; staged original `io/format` provider
fprintf  ; staged original `io/format` provider
printf   ; staged original `io/format` provider
eprintf  ; staged original `io/format` provider
```

The provider smoke confirms that the staged original-Racket-derived provider
already covers directives such as `~x`, `~o`, `~b`, and `~c` that the current
bootstrap primitive formatter does not fully cover.

The extracted staged provider now also runs under `--no-stdlib` when accessed
through module-variable cells. The key implementation detail is that
`printf-adapter.rkt` routes display/write/print work through the lower-level
port handler primitives where possible:

```racket
port-display-handler
port-write-handler
```

That keeps the provider from depending on public `display`, `write`, or
`print` top-level aliases while the module-based stdlib bridge is still being
retired in pieces.

`~v` now routes through `port-print-handler`, so custom print handlers are
honored by the staged provider. WebRacket still does not store handlers per
port; setting a print handler currently updates the process-wide print handler.
That is enough for the `io/format` provider path, but it is not the final
Racket-compatible port-handler story.

The reusable bridge is:

```text
webify/io-format-bridge.rkt
```

The provider integration flag is enabled by default, including with
`--no-stdlib`:

```text
--io-format-provider
```

It composes the staged provider into the `--stdlib` program and exposes public
aliases for `format`, `fprintf`, `printf`, and `eprintf`, plus private cells
such as `webify-io-format-export-cell$format`. Use
`--no-io-format-provider` only as a debugging fallback.

With `--no-stdlib`, the old WebRacket stdlib root is still omitted, but this
small `io/format` provider slice is composed unless explicitly disabled. That
lets low-level smokes use Racket-compatible formatting without pulling in the
reader, exception helpers, evaluation helpers, or browser stdlib pieces.

See `webify/IO-FORMAT-COMPOSITION.md` for the direct-composition blockers and
the bootstrap primitive retirement checklist.

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
2. Compose or port `io/format/printf.rkt` behind a focused probe. This is now
   covered by `printf-web.rkt` plus the explicit handler-based adapter.
3. Compose or port `io/format/main.rkt`. This now composes and runs cell-only
   through `webify/test-io-format-extraction.rkt`.
4. Keep `io/print/regexp.rkt` as a hook-only module with
   `printable-regexp? => #f`.
5. Move `format` and `fprintf` out of compiler primitive ownership after the
   default `--stdlib` bridge can publish the staged provider exports without a
   public alias collision. This is done; the retirement gate should pass.
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
