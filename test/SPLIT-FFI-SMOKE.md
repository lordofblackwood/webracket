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
- `jsxgraph.ffi` with a mock-backed board/point fixture
- `math.ffi`
- `performance.ffi`
- `standard.ffi` through browser defaults and `array.ffi`
- `temp.ffi`
- `websocket.ffi`
- `xtermjs.ffi` with a mock-backed terminal/addon fixture

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

- Full JSXGraph integration with the real host library is not covered by the
  mock-backed fixture.
- Full xterm.js integration with the real host library is not covered by the
  mock-backed fixture.
