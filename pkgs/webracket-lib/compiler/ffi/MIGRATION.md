# FFI Migration Matrix

The `.ffi` files in this directory are raw host-import declarations. Goal 1
module programs should use ordinary providers instead:

```text
ffi/foo.ffi
  -> webracket/unsafe/foo
  -> js/foo or browser/foo
```

The unsafe layer is raw and explicitly unsafe. The public layer should choose a
small, documented surface with names that make sense for WebRacket programs.

## Current Matrix

| `.ffi` file | Unsafe module | Public module | Bundle inference | Dashboard coverage | Status |
| --- | --- | --- | --- | --- | --- |
| `console.ffi` | `webracket/unsafe/console` | `js/console` | yes | yes | migrated |
| `math.ffi` | `webracket/unsafe/math` | `js/math` | yes | yes | migrated |
| `performance.ffi` | `webracket/unsafe/performance` | `js/performance` | yes | registry/tests | migrated, needs dashboard row |
| `standard.ffi` | `webracket/unsafe/standard` | `js/standard` | yes | yes | migrated starter surface |
| `temp.ffi` | `webracket/unsafe/temp` | `js/temp` | yes | registry/tests | migrated, needs dashboard row |
| `array.ffi` | none | none | no | no | postponed; currently an aggregate include file |
| `audio.ffi` | none | none | no | no | browser API, later |
| `canvas.ffi` | none | none | no | no | browser API, later |
| `document.ffi` | none | none | no | no | browser API, later |
| `dom.ffi` | none | none | no | no | browser API, later |
| `domrect.ffi` | none | none | no | no | browser API, later |
| `element.ffi` | none | none | no | no | browser API, later |
| `event.ffi` | none | none | no | no | browser API, later |
| `image.ffi` | none | none | no | no | browser API, later |
| `js.ffi` | none | none | no | no | low-level JS helpers, later |
| `jsxgraph.ffi` | none | none | no | no | library-specific API, later |
| `media.ffi` | none | none | no | no | browser API, later |
| `websocket.ffi` | none | none | no | no | browser API, later |
| `window.ffi` | none | none | no | no | browser API, later |
| `xtermjs.ffi` | none | none | no | no | library-specific API, later |

## Namespace Policy

- Use `js/*` for JavaScript built-ins and host-independent JavaScript APIs:
  `js/math`, `js/console`, `js/performance`, `js/standard`, and `js/temp`.
- Use `browser/*` for DOM/window/document/canvas/media APIs. The raw unsafe
  module should still be `webracket/unsafe/foo`.
- Keep library-specific APIs under their own public namespaces after the
  browser/core split is stable; likely candidates are `jsxgraph/*` and
  `xterm/*`, not `js/*`.
- Do not make `.ffi` files public APIs. They are compiler/runtime declarations
  and should remain in `webracket-lib`.

## Performance Boundary

Migrated unsafe modules currently bind names through `unsafe-ffi-primitive`,
which returns closures from a runtime table. This keeps the modules ordinary and
composable, but calls are not yet direct primitive calls. See `README.md` for
the direct-call optimization note.
