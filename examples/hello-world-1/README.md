# Hello World 1 (Node)

This example targets Node.js and runs in the terminal.

## Quick start (build + run)

From this folder:

```sh
./compile.sh && node --experimental-wasm-exnref --expose-gc hello-world-1.js
```

The compile helper builds the module-based program for Node, then Node runs the generated launcher.

## Build then run

From this folder:

```sh
./compile.sh
```

This compiles the `#lang webracket/base` module for Node and writes the generated launcher next to the source file.

## Run

From this folder:

```sh
node --experimental-wasm-exnref --expose-gc hello-world-1.js
```

Build writes these files:

- `hello-world-1.wat`             (WebAssembly in text format)
- `hello-world-1.wasm`            (WebAssembly bytecode)
- `hello-world-1.wasm.map.sexp`   (Source map)
- `hello-world-1.js`              (JS used to invoke the WebAssembly program)

Only wasm and js files are needed by Node to run the program.

## Serve/Open

Not applicable (terminal example; no browser page).

Notes:

- Stdlib is enabled by default, so this example works as-is with `displayln`.
- For programs that do not use stdlib functionality, add `--no-stdlib`.
