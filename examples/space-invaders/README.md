# Space Invaders Example

This browser example renders a small arcade-style shooter directly on a canvas
using the module-based browser wrappers in WebRacket.

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

- `http://localhost:8000/generated/space-invaders.html`

## Current Status

The example now:

- starts with `#lang webracket/base`
- compiles from this directory with `./compile.sh`
- keeps compiled artifacts under `generated/.compiled`
- keeps its provider cache under `generated/.provider-cache`
- writes browser output to `generated/`
- exposes a small `#status` marker for smoke tests and manual checks

The page includes a simple state marker:

```text
#status[data-state="loading" | "ready" | "error"]
```
