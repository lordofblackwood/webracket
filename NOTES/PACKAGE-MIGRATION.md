# Package Migration Plan

## Goal

Move WebRacket from "repository root is the collection" to an explicit package
root under `pkgs/webracket`.

This makes the repository ready for package-server publication and prevents
development-only directories such as `web-site/`, `tmp/`, or `syntax/` from
accidentally becoming top-level Racket collections.

## Phase 1: Scaffolding and Path Discipline

- Add `pkgs/webracket/` as the intended package root.
- Centralize local collection-path setup in `webify/test-module-support.rkt`.
- Keep the current root layout working only during the initial move. Once
  `pkgs/webracket` contains real collection files, tests must use `pkgs/`
  directly and fail instead of falling back to the repo parent.
- Do not add the repository root itself to `PLTCOLLECTS`.

## Phase 2: Shallow Package Root

Add modules under `pkgs/webracket/` for the collection paths that are used by
the current module bridge and tests.

This phase makes the checkout work with:

```sh
PLTCOLLECTS=/path/to/repo/pkgs:$PLTCOLLECTS
```

while avoiding a large physical move in a dirty worktree. This was temporary:
the root shims have since been removed, and `pkgs/` is now
the only collection parent used by the Webify tests.

## Phase 3: Promote the Current Package Surface

Make `pkgs/webracket/` the source of truth for the public collection surface
that has already been copied:

- `webracket/base`
- `webracket/full`
- `webracket/main`
- `webracket/contract`
- `webracket/js`
- `webracket/js/*`
- `webracket/unsafe/*`
- `webracket/private/for`
- `webracket/syntax/contract`
- `webracket/promise`
- `webracket/set`
- `webracket/stream`

The repository-root compatibility shims have been removed. The live source of
truth for public collection modules is now `pkgs/webracket/...`.

The current public package surface is:

```text
pkgs/webracket/
  base.rkt
  bool.rkt
  contract.rkt
  core.rkt
  full.rkt
  fully.rkt
  info.rkt
  js.rkt
  main.rkt
  primitives.rkt
  promise.rkt
  set.rkt
  stream.rkt
  base/
  full/
  js/
  lang/
  private/
  syntax/
  unsafe/
```

Compiler/runtime internals have moved into `pkgs/webracket-lib/compiler/`.
The repository root keeps `webracket.rkt` as a small CLI wrapper, while the
CLI implementation, driver, compiler, expander, assembler, runtime generator,
and private helper modules are package-owned implementation modules.

The CLI can keep a small repository-root wrapper if useful, but collection
resolution for tests and package-style use should come from `pkgs/`.

## Phase 4: Separate Non-Package Content

Keep generated and website-oriented content outside package roots:

```text
examples/
tmp/
web-site/
web-site-new/
html/
assets/
```

`webify/test-package-layout.rkt` guards this by checking that the active
collection parent is `pkgs/` and that obvious development/generated directories
have not leaked into `pkgs/webracket/`. It also checks that old root collection
shims stay removed, that compiler-private helpers stay out of the public
`webracket` package, and that the package `info.rkt` files declare the intended
collections.

Scribble documentation can later become either part of the core package or a
separate `webracket-doc` package.

## Phase 5: Split Packages If Needed

The first package split moved compiler-private implementation helpers out of the
public collection. Files that feel like compiler/runtime infrastructure, not
public collection modules, live under:

```text
pkgs/webracket-lib/
  info.rkt
  compiler/
    assembler.rkt
    cli.rkt
    compiler.rkt
    driver.rkt
    expander.rkt
    runtime-wasm.rkt
    ffi/
      *.ffi
    legacy-stdlib/
    webify/
    private/
      browser-options.rkt
      define-foreign.rkt
      fasl.rkt
      get-env-path.rkt
      immediates.rkt
      parameters.rkt
      priminfo.rkt
      primitives-db.rkt
      structs.rkt
      timings.rkt
      wasm-data.rkt
      wasm-utils.rkt
      wat-identifiers.rkt
```

The old root copies and accidental `pkgs/webracket` private-helper copies were
reviewed and removed after the package split landed. The remaining root Racket
entrypoint is the CLI wrapper `webracket.rkt`.

Potential later splits:

```text
pkgs/webracket-doc/
pkgs/webracket-test/
pkgs/webracket-examples/
```
