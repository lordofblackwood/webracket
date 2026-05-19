# WebRacket Package Root

This directory is reserved for the future `webracket` package root.

The intended layout is for this directory to contain the `webracket` collection
files currently at the repository root, including:

```text
base.rkt
base/
contract.rkt
driver.rkt
compiler.rkt
js/
lang/
private/
syntax/
unsafe/
webify/
```

When the move is complete, local development should expose the collection with:

```sh
PLTCOLLECTS=/path/to/repo/pkgs:$PLTCOLLECTS
```

not with the repository root itself.
