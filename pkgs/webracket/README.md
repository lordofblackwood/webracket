# WebRacket Public Collection

This directory is the public `webracket` collection package root.

Use `pkgs/`, not the repository root, as the collection parent during local
development:

```sh
PLTCOLLECTS=/path/to/repo/pkgs:$PLTCOLLECTS
```

The public collection contains language and library modules such as:

```text
webracket/base
webracket/full
webracket/lang/reader
webracket/js
webracket/contract
webracket/define-key
webracket/set
webracket/stream
webracket/sxml
webracket/unsafe/*
```

`webracket/define-key` and `webracket/sxml` are initial module wrappers for
legacy include-style libraries in `lib/libs/`. New code should prefer these
module names over `(include-lib define)` and `(include-lib sxml)` when possible.

Compiler/runtime implementation modules are intentionally not part of this
public collection. They live in the separate `webracket-lib` package under:

```text
pkgs/webracket-lib/compiler/
```

The repository root should not be put on `PLTCOLLECTS`; doing so makes
development-only directories look like top-level Racket collections and can
shadow installed libraries.
