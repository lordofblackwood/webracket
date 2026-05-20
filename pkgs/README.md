# WebRacket Packages

This directory contains the active Racket package roots.

The repository root is intentionally not a Racket collection root. Putting the
repo root on `PLTCOLLECTS` makes ordinary development directories look like
top-level Racket collections, which can shadow installed Racket collections.

The current package roots are:

```text
pkgs/webracket/
pkgs/webracket-lib/
```

`pkgs/webracket` is the public language/library collection. `pkgs/webracket-lib`
holds compiler/runtime implementation support that should not be part of the
public collection surface.

The root `webracket.rkt` file is a CLI wrapper. The CLI implementation,
compiler, driver, runtime generator, assembler, and private helper modules live
under `pkgs/webracket-lib/compiler/`.

Tests use `webify/test-module-support.rkt` to put this directory, not the
repository root, on the collection path. If `pkgs/webracket` is missing, the
helper fails instead of falling back to the old root-as-collection layout.
