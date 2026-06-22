# Hello World 3 Example

This browser example uses SXML via `sxml->dom` to build the page without direct DOM construction calls.

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

- `http://localhost:8000/generated/hello-world-3.html`

This example also calls `(js-log "Hello!")`, which prints `Hello!` in the browser's JavaScript console.
