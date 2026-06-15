# Snake Example

This is the original/basic Snake browser example: a simple canvas-based grid
game with keyboard controls and automatic restart after game over.

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

- `http://localhost:8000/generated/snake.html`

## Current Status

The example now:

- starts with `#lang webracket/base`
- compiles from this directory with `./compile.sh`
- keeps compiled artifacts under `generated/.compiled`
- keeps its provider cache under `generated/.provider-cache`
- writes browser output to `generated/`
- exposes `#status[data-state=\"loading\" | \"ready\" | \"error\"]`

Related variants:

- `examples/snake2/`: alternate Snake implementation with separate example layout
- `snake3.rkt`: experimental/incomplete variant, not currently treated as a user-facing tutorial entry
