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

## Phase 2: Move Core Collection Files

Move the actual `webracket` collection files into `pkgs/webracket/`.

Likely first move set:

```text
base.rkt
base/
bool.rkt
compiler.rkt
contract.rkt
driver.rkt
full.rkt
full/
info.rkt
js.rkt
js/
lang/
main.rkt
parameters.rkt
private/
promise.rkt
runtime-wasm.rkt
syntax/
unsafe/
webify/
webracket.rkt
```

The CLI can keep a small repository-root wrapper if useful, but collection
resolution should come from `pkgs/`.

## Phase 3: Separate Non-Package Content

Keep generated and website-oriented content outside package roots:

```text
examples/
tmp/
web-site/
web-site-new/
html/
assets/
```

Scribble documentation can later become either part of the core package or a
separate `webracket-doc` package.

## Phase 4: Split Packages If Needed

After the single package root works, split along package-server boundaries:

```text
pkgs/webracket-lib/
pkgs/webracket-doc/
pkgs/webracket-test/
pkgs/webracket-examples/
```

Do this only after the simple `pkgs/webracket` layout is stable.
