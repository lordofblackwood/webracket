Examples
========

This folder contains sample projects written using WebRacket.

See https://github.com/soegaard/webracket/blob/main/README.md
for a description of the individual projects.

Current Root Example Status
---------------------------

The long-term direction is for user-facing examples to be module-based:

- start with `#lang webracket/base`
- use explicit `require` forms instead of `(include-lib ...)`
- compile with `./compile.sh`
- write browser output to a local `generated/` directory

The table below tracks the direct example entry points under `examples/`.
Support files such as interpreters, assets, generated output, and old probes
are listed separately and are not intended to compile directly as tutorials.

| Example | Entry file | Classification | Notes |
| --- | --- | --- | --- |
| Hello World 1 | `hello-world-1/hello-world-1.rkt` | `already-module` | Node-oriented module example. |
| Hello World 2 | `hello-world-2/hello-world.rkt` | `already-module` | Browser DOM example. |
| Hello World 3 | `hello-world-3/hello-world-3.rkt` | `already-module` | Browser SXML example. |
| Console Bridge | `console-bridge/console-bridge.rkt` | `already-module` | Browser console bridge example. |
| Clipboard | `clipboard/clipboard-demo.rkt` | `already-module` | Module-based browser example for plain-text clipboard reads and writes. |
| Xterm.js Demo | `xtermjs-demo/xtermjs-demo.rkt` | `already-module` | Browser terminal example. |
| Pict | `pict/pict.rkt` | `already-module` | Module-based browser example with local assets and `generated/` output. |
| MiniScheme | `minischeme/minischeme-page.rkt` | `module-based` | Browser REPL page backed by a module-based MiniScheme interpreter; uses staged reader support and an opt-in slow browser smoke. |
| MathJax 4 | `mathjax4/mathjax.rkt` | `module-based` | Module-based browser example with CDN-loaded MathJax preview. |
| Matrix Rain | `matrix-rain/matrix-rain.rkt` | `module-based` | Browser/xterm example with local `generated/` output and a simple ready/error status marker. |
| Snake | `snake/snake.rkt` | `module-based` | Browser game with `generated/` output. |
| Snake 2 | `snake2/snake2.rkt` | `module-based` | Alternate Snake implementation with separate example layout. |
| Space Invaders | `space-invaders/space-invaders.rkt` | `already-module` | Module-based browser game with `generated/` output. |
| Raco | `raco/tiles.rkt` | `module-based` | Canvas tile-sheet browser example; `raco.rkt` remains a separate text-mode engine/demo source. |

Opt-In Batch Smoke
------------------

For a slow browser/compile pass across the module-based root examples, run:

```sh
./check-root-examples.sh
```

Useful knobs:

- `RACKET=/path/to/racket ./check-root-examples.sh`
- `ROOT_EXAMPLES_FILTER=hello-world-2,pict ./check-root-examples.sh`
- `ROOT_EXAMPLES_SKIP_COMPILE=1 ./check-root-examples.sh`

The batch is intentionally opt-in because `minischeme` and staged reader setup
are slower than the fast test suite.

For asset-backed examples such as `pict`, browser smoke should serve the
example directory itself, not an arbitrary `/private/tmp` output directory,
because the generated page loads assets via relative paths such as
`../assets/...`. After provider-routing changes, clear any example-local
`generated/.provider-cache` before treating a browser failure as a live source
or runtime bug.

Support Files And Non-Entry Sources
-----------------------------------

- `bibliography/scheme_oldest_papers_dataset.rkt`: dataset/support file.
- `minischeme/build-id.rkt`, `minischeme/interpreter.rkt`, `minischeme/minischeme.rkt`, `minischeme/repl-in-urlang.rkt`: MiniScheme support files.
- `pict/pict-removed.rkt`: old/removed pict experiment.
- `raco/raco.rkt`: text-mode engine/demo source, not the main browser entry.

Remaining Example Work
----------------------

- `raco/raco.rkt`: text-mode engine/demo source, not a browser tutorial entry.
