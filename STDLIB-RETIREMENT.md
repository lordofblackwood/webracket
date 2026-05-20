# WebRacket Stdlib Retirement Plan

The old textual stdlib, now in `pkgs/webracket-lib/compiler/legacy-stdlib/`,
is a legacy script-compatibility layer. It should
shrink over time; it should not become the module system for Goal 1 programs.

Goal 1 module programs should get functionality from:

- original Racket providers staged under `racket-src/` or provider caches,
- WebRacket runtime/compiler primitives for semantic substrate,
- WebRacket-specific modules such as `js/*`, `browser/*`, and
  `webracket/unsafe/*`.

## Current Ownership

The executable ownership source is
`webify/stdlib-surface-report.rkt`. Run:

```sh
../racket/racket/bin/racket webify/stdlib-surface-report.rkt
```

The report has two levels:

- `stdlib-file` rows classify whole legacy files.
- `stdlib-symbol` rows classify public names and replacements.

`webify/check-stdlib-primitive-collisions.rkt` is the executable guard. It
checks that newly added compiler primitives do not silently take ownership of
names that the report classifies as provider-owned or temporary-stdlib-owned.

## Formatting

`format`, `fprintf`, `printf`, and `eprintf` are not stdlib-owned. They are
owned by the staged original-Racket `io/format` provider:

- implementation root: `racket-src/io/format/main-web.rkt`
- bridge: `webify/io-format-bridge.rkt`
- replacement owner: `racket-src/io/format`

`stdlib/formatting-numbers.rkt` is therefore marked
`replace-with-original-racket-provider`.

Module-language programs do not get a textual stdlib prelude. If formatting is
needed by module-language input, it should arrive through provider/module
composition, not by falling back to `stdlib/`.

## Writing And Printing

`write`, `display`, `print`, print parameters, and port write handlers are a
mixed area. Some names are compiler/runtime primitives now, while
`stdlib/writing.rkt` still supplies legacy script behavior. Do not delete this
file blindly. The next step is to separate:

- runtime-owned port/write substrate,
- provider-owned high-level printing, if we stage original Racket support,
- script-only aliases that can disappear with `--stdlib`.

The current machine-readable split is:

- runtime substrate: print parameters and handlers such as `current-print`,
  `print-syntax-width`, and `error-value->string-handler`,
- staged high-level provider: `write`, `display`, and `print` via
  `racket-src/io/print`,
- staged formatting provider: `format`, `fprintf`, `printf`, and `eprintf`.

See `webify/IO-PRINT.md` for the staged print-provider plan and the current
blockers.

## Reading And Regexps

`stdlib/reading.rkt` is transitional. `read` and `read-syntax` should come from
the staged expander reader path.

`stdlib/regexp.rkt` is obsolete. Regular expressions are owned by the staged
regexp provider built from the `regexp/` source tree.

## Module-Language Rule

`#lang webracket/base` and `#lang webracket/full` must not depend on the legacy
stdlib prelude. The driver skips temporary stdlib/provider preludes for module
language input. Module functionality should arrive through module/provider
composition instead.
