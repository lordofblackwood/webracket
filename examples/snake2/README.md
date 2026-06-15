# Snake 2 Example

This browser example is an alternate Snake implementation with a leaner DOM
layout and immediate reset behavior after collisions.

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

- `http://localhost:8000/generated/snake2.html`

## Current Status

The example now:

- starts with `#lang webracket/base`
- compiles from this directory with `./compile.sh`
- keeps compiled artifacts under `generated/.compiled`
- keeps its provider cache under `generated/.provider-cache`
- writes browser output to `generated/`
- exposes `#status[data-state="loading" | "ready" | "error"]`
