# MathJax 4 Example

This browser example loads MathJax 4 from a CDN and turns a textarea into a
live LaTeX preview.

## Build

From this folder:

```sh
./compile.sh
```

## Serve

From this folder:

```sh
python3 -m http.server
```

## Open

Open:

- `http://localhost:8000/generated/mathjax.html`

## Current Status

The example now:

- starts with `#lang webracket/base`
- compiles from this directory with `./compile.sh`
- keeps compiled artifacts under `generated/.compiled`
- keeps its provider cache under `generated/.provider-cache`
- writes browser output to `generated/`
- exposes `#status[data-state="loading" | "ready" | "error"]`

Because MathJax is loaded from a CDN, browser smoke should at least verify page
initialization and status transitions. Full typesetting depends on network
availability.
