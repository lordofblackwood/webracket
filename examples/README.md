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
| Xterm.js Demo | `xtermjs-demo/xtermjs-demo.rkt` | `already-module` | Browser terminal example. |
| Pict | `pict/pict.rkt` | `already-module` | Module-based browser example with local assets and `generated/` output. |
| MiniScheme | `minischeme/minischeme-page.rkt` | `legacy-include-lib` | Intended user-facing REPL page; depends on support files. |
| MiniScheme 2 | `minischeme2/minischeme-page.rkt` | `legacy-include-lib` | Duplicate MiniScheme entry; needs classification before more work. |
| MathJax 4 | `mathjax4/mathjax.rkt` | `legacy-script` | Browser example with old top-level script shape. |
| Matrix Rain | `matrix-rain/matrix-rain.rkt` | `legacy-script` | Browser/xterm example with old top-level script shape. |
| Snake | `snake/snake.rkt` | `legacy-script` | Browser game; likely the main snake entry. |
| Space Invaders | `space-invaders/space-invaders.rkt` | `already-module` | Module-based browser game with `generated/` output. |
| Raco | `raco/raco.rkt` | `legacy-script` | Advanced/example-stress candidate; confirm user-facing status before conversion. |

Support Files And Non-Entry Sources
-----------------------------------

- `bibliography/scheme_oldest_papers_dataset.rkt`: dataset/support file.
- `minischeme/build-id.rkt`, `minischeme/interpreter.rkt`, `minischeme/minischeme.rkt`, `minischeme/repl-in-urlang.rkt`: MiniScheme support files.
- `minischeme2/build-id.rkt`, `minischeme2/minischeme.rkt`: MiniScheme 2 support files.
- `pict/pict-removed.rkt`: old/removed pict experiment.
- `raco/tiles.rkt`: support generator/demo source, not the main raco entry.
- `snake/snake2.rkt`, `snake/snake3.rkt`: alternate snake variants, not the default tutorial entry.

Planned Conversion Order
------------------------

1. `pict`
2. `minischeme`
3. `minischeme2` if it is still meant to be user-facing
4. `matrix-rain` and `snake`
5. `mathjax4`
6. `raco` if it remains part of the user-facing examples set
