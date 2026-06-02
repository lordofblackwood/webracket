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

ffi/standard.ffi
  -> webracket/unsafe/standard
  -> js/standard
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

`webracket/unsafe/console`, `webracket/unsafe/math`,
`webracket/unsafe/performance`, `webracket/unsafe/standard`, and
`webracket/unsafe/temp` are migrated unsafe modules whose bindings call the
private `unsafe-ffi-primitive` hook. For `#lang webracket/base` and
`#lang webracket/full` programs, the driver infers the matching `.ffi` bundle
from required providers such as `js/console`, `js/math`, or
`webracket/unsafe/math`, so users do not need to pass `--ffi console` or
`--ffi math` by hand. Their export sets are checked against their `.ffi`
declarations. The shared module-to-bundle mapping lives in
`webify/ffi-module-registry.rkt` and is discovered from existing `ffi/*.ffi`,
`js/*.rkt`, and `unsafe/*.rkt` files. Adding `ffi/foo.ffi` plus
`unsafe/foo.rkt` and/or `js/foo.rkt` makes the module provider infer
`foo.ffi` without editing the registry.

Performance note
----------------

The migrated module path currently favors composability over direct-call performance.
A binding such as:

```
(define js-foo-bar (unsafe-ffi-primitive 'js-foo-bar))
```

is compiled as a module binding to a closure returned by
`unsafe-ffi-primitive`. Calling `(js-foo-bar 42)` therefore goes through the
ordinary closure/module-variable path. The underlying Wasm import and generated
FFI wrapper are direct, but the module-level call is not yet compiled as a
direct primitive call.

This is intentional for the first module-based FFI migration: it lets ordinary
`require`s infer `.ffi` bundles and keeps unsafe modules regular Racket modules.
The future optimization is to recognize module bindings initialized from
`unsafe-ffi-primitive` and compile calls to those aliases directly to the
generated FFI wrapper, or to generate unsafe modules in a compiler-recognized
primitive-binding form.


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
