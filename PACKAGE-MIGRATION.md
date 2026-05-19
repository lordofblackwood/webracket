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
- Keep the current root layout working while tests learn to prefer
  `pkgs/webracket` once it contains the real collection files.
- Do not add the repository root itself to `PLTCOLLECTS`.

## Phase 2: Shallow Package Root

Add modules under `pkgs/webracket/` for the collection paths that are used by
the current module bridge and tests.

This phase makes the checkout work with:

```sh
PLTCOLLECTS=/path/to/repo/pkgs:$PLTCOLLECTS
```

while avoiding a large physical move in a dirty worktree. The first slice used
copied source for provider/language modules where wrapper re-exporting was not
enough for Webify's export extraction.

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

The repository-root compatibility shims have been quarantined under
`deleted/`. The live source of truth for public collection modules is now
`pkgs/webracket/...`.

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

Compiler/runtime internals such as `compiler.rkt`, `driver.rkt`,
`runtime-wasm.rkt`, and the active `webify/` tooling stay at the repository
root until the package layout is less turbulent.

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
have not leaked into `pkgs/webracket/`.

Scribble documentation can later become either part of the core package or a
separate `webracket-doc` package.

## Phase 5: Split Packages If Needed

The first package split is now being tried for compiler-private implementation
helpers. Files that felt like compiler/runtime infrastructure, not public
collection modules, live under:

```text
pkgs/webracket-lib/
  info.rkt
  compiler/
    private/
      browser-options.rkt
      define-foreign.rkt
      immediates.rkt
      parameters.rkt
      priminfo.rkt
      primitives-db.rkt
      structs.rkt
```

The old root copies and the accidental `pkgs/webracket` copies are quarantined
under `deleted/` for review before final deletion.

Potential later splits:

```text
pkgs/webracket-doc/
pkgs/webracket-test/
pkgs/webracket-examples/
```
