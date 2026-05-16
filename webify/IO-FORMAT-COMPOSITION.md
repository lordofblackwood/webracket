# `io/format` Composition Notes

Goal 1 should replace temporary WebRacket stdlib formatting with original
Racket provider modules. The current target provider is:

```text
racket-src/io/format/main-web.rkt
```

It exports:

```racket
format
fprintf
printf
eprintf
```

## Current Working Pieces

- `racket-src/io/format/printf-web.rkt` keeps the upstream `do-printf` body and
  changes only the require surface.
- `racket-src/io/format/main-web.rkt` exposes the public format family through
  the adapted `do-printf`.
- `webify/io-format-provider.rkt` records that `format` and `fprintf` are
  primitive-backed now, but should move to the staged original provider.
- `webify/test-io-format-composition.rkt` proves the existing module registry
  can compose a provider fixture with the same export names and expose them
  through module-variable cells.
- The provider fixture composes with public top-level aliases disabled. That is
  intentional while `format` is still a primitive; the safe bridge shape is
  cell access first, public aliasing later.

## Blockers For Direct Provider Composition

`main-web.rkt` is not yet directly consumed by Webify's module composer because
it is a host Racket module:

```racket
#lang racket/base
```

The current `stdlib/` bridge reads `#lang webracket` source files as flattened
forms. The module registry composes linklet datums, not arbitrary Racket source
modules. To compose `main-web.rkt` directly, Webify needs one of these paths:

- Compile the host/source module to a linklet bundle and extract a first-slice
  linklet that the existing registry can consume.
- Add a source-module provider path that can lower a restricted Racket module
  into the existing `webify-module-registry` representation.
- Keep an explicit generated adapter only as a mechanical artifact derived from
  the staged original sources, not as hand-written `stdlib/` code.

Other practical blockers:

- The provider requires `printf-adapter.rkt` and `printf-web.rkt`, so dependency
  extraction must preserve the small adapted require graph.
- The provider uses host `racket/base` bindings in tests. Runtime composition
  must map those to WebRacket primitives or composed provider exports.
- Public `format` and `fprintf` still exist as compiler/runtime primitives.
  Their public primitive ownership must be retired or renamed before the staged
  provider can export those names at top level without ambiguity.

## Retirement Checklist For Bootstrap `format`/`fprintf`

Before removing primitive ownership:

1. Compose the staged `io/format` provider, not a hand-written `stdlib/`
   replacement.
2. Prove provider exports are available through module-variable cells in a
   `--no-stdlib` runtime smoke.
3. Add behavior coverage for `~a`, `~s`, `~v`, `~e`, `~~`, `~n`, `~%`, `~x`,
   `~o`, `~b`, `~c`, whitespace skipping, argument-count errors, and argument
   type errors.
4. Remove `format` and `fprintf` from compiler primitive tables only after the
   provider path is available in the default `--stdlib` composition.
5. Update `primitives.rkt` so `#lang webracket` keeps the same public surface,
   either by requiring/composing the provider or by documenting any temporary
   fallback.
6. Update inliner/arity handling for any direct primitive call sites that
   previously expected variadic primitive `format` or `fprintf`.
7. Keep low-level runtime helpers such as `$format/display` if they are still
   needed by error reporting or printing internals, but do not expose them as
   public `format`.

The expected user-visible improvement after provider ownership is richer Racket
format directive coverage, including directives that the current bootstrap
primitive leaves literal, such as `~x`.
