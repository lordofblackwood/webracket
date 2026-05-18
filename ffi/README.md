FFI - WebRacket Bindings
========================

This folder contains bindings for various JavaScript libraries.

The `.ffi` files are declaration specs for raw host imports. They are not the
intended public module surface.

The intended module layering is:

```
ffi/console.ffi
  -> webracket/unsafe/console
  -> js/console
```

- `ffi/*.ffi` declares raw imported names, host module names, arities, result
  conventions, and documentation metadata.
- `webracket/unsafe/*` exposes raw/unsafe WebRacket binding names such as
  `js-console-log`.
- `js/*` and future `browser/*` modules expose safe, Rackety wrappers such as
  `console-log`.
- `lib/libs/*` is the legacy `include-lib` compatibility location while those
  libraries are migrated to modules.

`webracket/unsafe/console` is currently a primitive-backed shim so module
programs can require the raw console names. Its export set is checked against
`ffi/console.ffi`; the long-term direction is to generate the whole unsafe
module body directly from these `.ffi` specs.


dom.ffi
-------
Functions that work with the DOM (Document Object Model).
Use the original documentation and read dom.ffi for 
the names used in WebRacket.

https://developer.mozilla.org/en-US/docs/Web/API/Window


js.ffi
------
Foreign function bindings for builtin JavaScript arrays.

https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array


jsxgraph.ffi
------------
Bindings for the JSXGraph project.


math.ffi
--------
Bindings for function in the Math object.

https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Math


standard.ffi
------------
Bindings to access standard JavaScript global properties, functions, and objects.

See https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects

xtermjs.ffi
-----------
Bindings for the xterm.js Terminal API.
Documentation: extras/xtermjs/docs/api/terminal/classes/terminal.md

websocket.ffi
-------------
Bindings for the browser WebSocket API.

console.ffi
-----------
Bindings for the browser Console API.
