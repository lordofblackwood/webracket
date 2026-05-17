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
- `webify/io-format-provider.rkt` records that the public format family is now
  owned by the staged original provider.
- `webify/test-io-format-composition.rkt` proves the existing module registry
  can compose a provider fixture with the same export names and expose them
  through module-variable cells.
- The provider fixture can still compose with public top-level aliases disabled
  for cell-only tests, but the default command-line path now publishes public
  provider aliases. This includes `--no-stdlib`, which omits the old WebRacket
  stdlib root but still composes this small `io/format` provider slice unless
  disabled.
- `webify/test-io-format-extraction.rkt` proves a tiny source module can be
  compiled, extracted to a registry-ready linklet input, composed cell-only, and
  run under `--no-stdlib`.
- `webify/io-format-bridge.rkt` owns the reusable staged provider graph,
  including the map shim, module-protocol cells, registry inputs, private
  stdlib cell aliases, and public aliases.
- The driver now caches the lowered `io/format` provider forms in the shared
  provider cache. The cache is fingerprinted from `racket-src/io/` plus the
  bridge module, and it participates in `--provider-cache-dir`,
  `--clear-provider-cache`, `--force-provider-cache-refresh`, and verbose
  provider-cache diagnostics.
- The same extraction path can resolve the staged `main-web.rkt`,
  `printf-web.rkt`, and `printf-adapter.rkt` provider graph into registry-ready
  inputs when supplied with a small `map2` shim and module-protocol cells.
- The resolved staged graph now runs under `--no-stdlib` through
  module-variable cells. The runtime smoke calls the extracted provider's
  `format` export and covers representative `~a`, `~s`, `~~`, `~x`, `~o`,
  `~b`, and `~c` directives.

## Remaining Caveats

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

The provider still requires `printf-adapter.rkt` and `printf-web.rkt`, so
dependency extraction must preserve the small adapted require graph.

The print substrate blocker was retired by routing the adapter through
`port-display-handler`, `port-write-handler`, and `port-print-handler` instead
of public `display`, `write`, and `print` bindings.

One caveat remains in the adapter: `~v` is routed through write handling for
now. WebRacket has `port-print-handler` as a primitive, but the full Racket
print-handler protocol is not complete enough for this provider path yet.

## Retired Bootstrap `format`/`fprintf` Checklist

The public bootstrap primitive ownership has been retired:

1. Compose the staged `io/format` provider, not a hand-written `stdlib/`
   replacement.
2. Prove provider exports are available through module-variable cells in a
   `--no-stdlib` runtime smoke. This is done for representative format calls.
3. Add behavior coverage for `~a`, `~s`, `~v`, `~e`, `~~`, `~n`, `~%`, `~x`,
   `~o`, `~b`, `~c`, whitespace skipping, argument-count errors, and argument
   type errors. Host-side coverage exists for this set; runtime coverage should
   continue to grow around `~v`, `~e`, newlines, and error paths.
4. Remove `format` and `fprintf` from compiler primitive tables only after the
   provider path is available in the default `--stdlib` composition. This is
   done. The default command-line path now composes the provider, including
   with `--no-stdlib`. A debugging switch remains:

   ```sh
   --no-io-format-provider
   ```

   Private cells such as `webify-io-format-export-cell$format` are still
   exposed for focused bridge tests.
5. Update `primitives.rkt` so `#lang webracket` keeps the same public surface,
   either by requiring/composing the provider or by documenting any temporary
   fallback. The host-side language still re-exports Racket's `format` family;
   compiled WebRacket gets the provider through `--stdlib`.
6. Update inliner/arity handling for any direct primitive call sites that
   previously expected variadic primitive `format` or `fprintf`. This is done
   by removing those names from the primitive/inliner tables.
7. Keep low-level runtime helpers such as `$format/display` if they are still
   needed by error reporting or printing internals, but do not expose them as
   public `format`. `$format/display` remains internal runtime support.

The expected user-visible improvement after provider ownership is richer Racket
format directive coverage, including directives that the current bootstrap
primitive leaves literal, such as `~x`.
