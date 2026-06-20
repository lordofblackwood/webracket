# Console Bridge Example

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

- `http://localhost:8000/generated/console-bridge.html`

## Browser Smoke

This example is intended for the browser console bridge:

- `window.WR` should be installed
- `WR.names()` should include `counter`, `current-counter`, `increment!`, and `explode!`
- the page also prints `console bridge example ready` to the browser console
