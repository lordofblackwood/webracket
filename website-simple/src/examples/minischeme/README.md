# MiniScheme Example

This is the website-owned copy of the MiniScheme browser example. It was copied
from the old website source:

- `web-site/src/minischeme.html`
- `web-site/src/examples/minischeme/`

The simple replacement website should use the advanced old webpage version of
MiniScheme, not the smaller top-level `examples/minischeme/` example.

## Build

Build it through the simple website script:

```sh
bash website-simple/src/build.sh
```

The generated page appears at:

```text
website-simple/local/examples/minischeme/minischeme-page.html
```

The page is built as a module-based WebRacket program and mounted with
web-easy so it can use the simple website header, theme, and styling.
