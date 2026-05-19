# WebRacket Package Root

This directory is the package-root migration target for the `webracket`
collection.

At the moment, many files here are shallow wrappers back to the legacy
repository-root collection files. That lets local development use:

```sh
PLTCOLLECTS=/path/to/repo/pkgs:$PLTCOLLECTS
```

without putting the repository root itself on the collection path.

The final intended layout is for this directory to contain the real
`webracket` collection files currently at the repository root, including:

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

Do not expose the repository root itself with:

```sh
PLTCOLLECTS=/path/to/repo:$PLTCOLLECTS
```

That makes repo-internal directories look like top-level Racket collections.
