# MiniScheme Example

This is the primary MiniScheme browser example. `minischeme2` is currently a
duplicate copy and is not being ported separately unless it regains a distinct
purpose.

## Build

From this folder:

```sh
./compile.sh
```

With an explicit local Racket checkout:

```sh
RACKET=/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket ./compile.sh
```

`compile.sh` enables the staged `expander/read` provider, since the REPL uses
Racket's reader through `(read ...)`.

## Serve

From this folder:

```sh
python3 -m http.server
```

## Open

Open:

- `http://localhost:8000/generated/minischeme-page.html`

The page exposes a small browser smoke marker:

- `#status[data-state="loading"]` while initializing
- `#status[data-state="ready"]` when the REPL is ready
- `#status[data-state="error"]` if evaluation fails
