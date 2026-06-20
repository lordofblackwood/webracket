# Raco Tiles Example

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

- `http://localhost:8000/generated/tiles.html`

The page exposes a small browser smoke marker:

- `#status[data-state="loading"]` while the page is being prepared
- `#status[data-state="ready"]` once the tile sheet is fully drawn
