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

ffi/math.ffi
  -> webracket/unsafe/math
  -> js/math

ffi/temp.ffi
  -> webracket/unsafe/temp
  -> js/temp
```

- `ffi/*.ffi` declares raw imported names, host module names, arities, result
  conventions, and documentation metadata.
- `webracket/unsafe/*` exposes raw/unsafe WebRacket binding names such as
  `js-console-log`.
- `js/*` modules expose JavaScript built-in or host-object wrappers such as
  `console-log` and `math-sqrt`.
- `browser/*` is reserved for DOM/window/document-style browser APIs.
- `lib/libs/*` is the legacy `include-lib` compatibility location while those
  libraries are migrated to modules.

`webracket/unsafe/console` is currently a primitive-backed shim so module
programs can require the raw console names. `webracket/unsafe/math` and
`webracket/unsafe/temp` are generated unsafe modules whose bindings call the
private `unsafe-ffi-primitive` hook, so compiling users must include the
matching `.ffi` bundle, for example `--ffi math`. Their export sets are checked
against their `.ffi` declarations.


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
