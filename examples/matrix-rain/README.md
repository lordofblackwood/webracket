# Matrix Rain Example

## Build

From this folder:

```sh
./compile.sh
```

With an explicit local Racket checkout:

```sh
RACKET=/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket ./compile.sh
```

## Serve

From this folder:

```sh
python3 -m http.server
```

## Open

Open:

- `http://localhost:8000/generated/matrix-rain.html`

The page exposes a small browser smoke marker:

- `#status[data-state="loading"]` while xterm.js is loading
- `#status[data-state="ready"]` once the rain animation starts
- `#status[data-state="error"]` if the xterm.js script fails to load
