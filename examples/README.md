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
| MiniScheme | `minischeme/minischeme-page.rkt` | `module-based` | Browser REPL page backed by a module-based MiniScheme interpreter; uses staged reader support and an opt-in slow browser smoke. |
| MiniScheme 2 | `minischeme2/minischeme-page.rkt` | `duplicate/pending` | Duplicate MiniScheme copy; do not port separately unless it regains a distinct purpose. |
| MathJax 4 | `mathjax4/mathjax.rkt` | `module-based` | Module-based browser example with CDN-loaded MathJax preview. |
| Matrix Rain | `matrix-rain/matrix-rain.rkt` | `module-based` | Browser/xterm example with local `generated/` output and a simple ready/error status marker. |
| Snake | `snake/snake.rkt` | `module-based` | Browser game with `generated/` output. |
| Snake 2 | `snake2/snake2.rkt` | `module-based` | Alternate Snake implementation with separate example layout. |
| Snake 3 | `snake/snake3.rkt` | `debug/internal` | Experimental commented-out variant, not a runnable tutorial entry. |
| Space Invaders | `space-invaders/space-invaders.rkt` | `already-module` | Module-based browser game with `generated/` output. |
| Raco | `raco/raco.rkt` | `legacy-script` | Advanced/example-stress candidate; confirm user-facing status before conversion. |

Support Files And Non-Entry Sources
-----------------------------------

- `bibliography/scheme_oldest_papers_dataset.rkt`: dataset/support file.
- `minischeme/build-id.rkt`, `minischeme/interpreter.rkt`, `minischeme/minischeme.rkt`, `minischeme/repl-in-urlang.rkt`: MiniScheme support files.
- `minischeme2/build-id.rkt`, `minischeme2/minischeme.rkt`: MiniScheme 2 support files.
- `pict/pict-removed.rkt`: old/removed pict experiment.
- `raco/tiles.rkt`: support generator/demo source, not the main raco entry.
- `snake/snake3.rkt`: experimental commented-out Snake variant, not currently runnable.

Planned Conversion Order
------------------------

1. `pict`
2. `minischeme`
3. `minischeme2` if it is still meant to be user-facing
4. `matrix-rain`
5. `raco` if it remains part of the user-facing examples set
