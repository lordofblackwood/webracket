# `io/print` Staging Plan

High-level writing and printing should be owned by staged Racket IO code, not
by WebRacket's legacy `stdlib/writing.rkt`.

The Reference says `write`, `display`, and `print` first consult the
corresponding port handler and otherwise use the default printer. The newline
variants are thin combinations:

- `writeln` is `write` followed by `newline`.
- `displayln` is `display` followed by `newline`.
- `println` is `print` followed by `newline`.

That means the right long-term split is:

- WebRacket runtime substrate: ports, current output port, string output ports,
  port write/display/print handlers, and low-level string/byte writes.
- Staged `racket-src/io/print`: public `write`, `display`, `print`, newline,
  `displayln`, `writeln`, `println`, default printer dispatch, custom-write
  handling, graph/cycle detection, and print parameters.
- Legacy `stdlib/writing.rkt`: script compatibility only until the staged print
  provider is ready.

## Seed Files

The staged seed currently lives in:

```text
racket-src/io/print/main.rkt
racket-src/io/print/mode.rkt
racket-src/io/print/parameter.rkt
racket-src/io/print/regexp.rkt
```

These files are copied from upstream Racket. The guard is:

```sh
../racket/racket/bin/racket webify/test-io-print-provider.rkt
```

## Why Not Reuse `io/format`'s Adapter?

`io/format` intentionally uses a small adapter:

```text
racket-src/io/format/printf-adapter.rkt
```

That adapter is enough for `format`, `printf`, `fprintf`, and `eprintf`, but it
is not the full default printer. In particular, it does not settle:

- graph/cycle printing,
- custom-write and custom-print-quotable properties,
- print handlers with the optional quote-depth argument,
- prefab/struct printer integration,
- exact `print` mode conventions.

So `io/format` can stay small, while `io/print` becomes the owner for real
high-level printing.

## Current Blockers

The executable blocker list is in:

```text
webify/io-print-provider.rkt
```

Current blockers:

- `print/main.rkt` still requires unstaged print helpers such as
  `custom-write`, `list`, `vector`, `hash`, and `graph`.
- WebRacket needs an adapter for the staged print layer's core-output-port
  protocol.
- `prop:custom-write` and `prop:custom-print-quotable` must line up with
  WebRacket structs.
- Default printing needs graph/cycle detection semantics before replacing
  `stdlib/writing.rkt`.

## First Implementation Slice

The first practical provider slice should not try to copy all of `src/io`.
Instead:

1. Copy the missing `io/print/*` files demanded by `print/main.rkt`.
2. Keep rktio-backed file/network ports out of scope.
3. Add a WebRacket adapter for in-memory output ports and handler calls.
4. Prove `display`, `write`, and `print` work through provider cells with
   `--no-stdlib`.
5. Only then publish public aliases for module-language programs.
