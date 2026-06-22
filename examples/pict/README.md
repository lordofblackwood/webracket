# Pict Example

This browser example uses the module-based `web-pict` library to render
text, shapes, compositing, tables, frozen picts, and bitmap-backed picts
onto a canvas.

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

- `http://localhost:8000/generated/pict.html`

The generated page loads bitmap assets from:

- `../assets/fish-1.png`
- `../assets/fish-2.png`

so the server root should be `examples/pict/`, not the `generated/` folder by
itself.

After provider-routing changes, clear `generated/.provider-cache` before using
an old browser failure as evidence. The example has previously picked up stale
provider-cache state that survived after the underlying compiler/runtime bug was
already fixed.

## Current Status

The example now:

- compiles from this directory with `./compile.sh`
- keeps compiled artifacts under `generated/.compiled`
- keeps its provider cache under `generated/.provider-cache`
- writes browser output to `generated/`
- loads its committed bitmap assets from `../assets/...`
- reaches `#status[data-state="ready"]` in the browser smoke

The page includes a small status marker:

```text
#status[data-state="ready"]
```

If something goes wrong, the same status element switches to
`data-state="error"` and shows the failure text.
