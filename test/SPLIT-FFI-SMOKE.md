# Split FFI Browser Smoke Coverage

`test/run-split-ffi-mixed-cache-headless.sh` compiles each fixture with
`--browser --split-runtime-ffi-module` while using separate provider and runtime
provider caches. The generated pages are then run in a browser, so the smoke
checks the runtime/import boundary and not only compilation.

Covered standalone or focused FFI families:

- `array.ffi`
- `audio.ffi`
- Browser constructor host errors for `AudioContext`, `Event`, `Image`, and `WebSocket`
- Browser document optional/deprecated host errors such as XPath and fullscreen helpers
- Browser element method host errors for optional and browser-version-sensitive APIs
- Browser event method host errors for optional and browser-version-sensitive APIs
- Browser object method host errors for canvas, media, and image methods
- Browser window method host errors for direct function-valued APIs
- Browser window optional host errors for functions such as `fetch` and `structuredClone`
- Browser window object-valued host errors such as storage, caches, and IndexedDB
- `console.ffi`
- `js.ffi` through `array.ffi`
- `jsxgraph.ffi` with missing-host, dynamic-call boundary, and mock-backed board/point fixtures
- `math.ffi`
- `performance.ffi` with optional method boundary checks
- `standard.ffi` through browser defaults, `array.ffi`, generic JS send boundary checks,
  and generic JS property/new boundary checks
- `temp.ffi`
- `websocket.ffi`
- `xtermjs.ffi` with missing-host and mock-backed terminal/addon fixtures

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
