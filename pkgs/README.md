# WebRacket Packages

This directory is the target home for Racket package roots.

The repository root is intentionally not a Racket collection root. Putting the
repo root on `PLTCOLLECTS` makes ordinary development directories look like
top-level Racket collections, which can shadow installed Racket collections.

The planned first package root is:

```text
pkgs/webracket/
```

During the migration, tests use a helper that prefers `pkgs/webracket` once it
contains the real collection files, and otherwise falls back to the current
legacy layout.
