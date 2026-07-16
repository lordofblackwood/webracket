# Split FFI Browser Smoke Coverage

`test/run-split-ffi-mixed-cache-headless.sh` compiles each fixture with
`--browser --split-runtime-ffi-module` while using separate provider and runtime
provider caches. The generated pages are then run in a browser, so the smoke
checks the runtime/import boundary and not only compilation.

Covered standalone or focused FFI families:

- `array.ffi`
- `audio.ffi`
- `console.ffi`
- `js.ffi` through `array.ffi`
- `math.ffi`
- `performance.ffi`
- `standard.ffi` through browser defaults and `array.ffi`
- `websocket.ffi`

Covered through the DOM aggregate and focused browser wrapper pages:

- `canvas.ffi`
- `document.ffi`
- `dom.ffi`
- `domrect.ffi`
- `element.ffi`
- `event.ffi`
- `image.ffi`
- `media.ffi`
- `window.ffi`

Deferred from the default browser smoke:

- `temp.ffi` is a temporary benchmark-only binding.
- `jsxgraph.ffi` needs JSXGraph host-library setup or a deliberate mock.
- `xtermjs.ffi` needs xterm.js host-library setup or a deliberate mock.
