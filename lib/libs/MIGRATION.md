# Safe Library Migration Inventory

`lib/libs/` contains the legacy `include-lib` safe libraries. These files sit
above raw FFI bindings: they wrap extern values, normalize strings/symbols,
check arguments, cache callback externals, and provide Rackety APIs.

The long-term direction is to make normal module providers the canonical API
and keep `include-lib` only as a compatibility path while old examples migrate.

## Inventory

| Legacy file | Classification | Suggested owner | Notes |
| --- | --- | --- | --- |
| `array.rkt` | safe wrapper | `js/array` | Migrated; `js/array` is now the canonical safe wrapper API. |
| `audio.rkt` | safe wrapper | `browser/audio` | Web Audio wrapper with callback caching and constructor checks. |
| `canvas.rkt` | safe wrapper, aggregate | `browser/canvas` | Depends on media and array wrappers; owns canvas/image-data/context structs. |
| `console.rkt` | safe wrapper | `js/console` | Already has a module counterpart; legacy file should stay compatibility-only. |
| `define.rkt` | syntax/helper | `webracket/define-key` | Keyword-definition helper macros; not a JS/browser API. |
| `document.rkt` | safe wrapper | `browser/document` | DOM Document wrapper and constructors. |
| `dom.rkt` | aggregate | `browser/dom` | Reexports window/document/domrect/element/image/event family. |
| `domrect.rkt` | safe wrapper | `browser/domrect` | Migrated; module now owns DOMRect wrap/unwrap plus accessors. |
| `element.rkt` | safe wrapper | `browser/element` | Large DOM Element wrapper with event-listener caching. |
| `event.rkt` | legacy include adapter | `browser/event` | Includes `lib/web-easy/event-browser.rkt`; should become a real module source or wrapper. |
| `fetch.rkt` | safe wrapper | `browser/fetch` | Fetch/Headers/Request/Response wrappers; no public module yet. |
| `image.rkt` | safe wrapper | `browser/image` | HTML image wrapper. |
| `indexed-db.rkt` | safe wrapper | `browser/indexed-db` | IndexedDB wrapper; no public module yet. |
| `iterator.rkt` | safe wrapper | `js/iterator` | JavaScript iterator-helper wrapper used by performance. |
| `jsx-graph.rkt` | safe wrapper | `jsxgraph` | High-level JSXGraph wrapper; current module facade should absorb this API. |
| `media.rkt` | safe wrapper | `browser/media` | HTML media element wrapper and conversion helpers. |
| `performance.rkt` | safe wrapper | `js/performance` | Performance API wrapper; depends on iterator helpers. |
| `rquery-chain.rkt` | syntax/helper | `browser/rquery/chain` or private helper | Chain macro used by `rquery`; likely not a standalone public API. |
| `rquery.rkt` | safe wrapper | `browser/rquery` | DOM selection/query helper library; depends on document/element/event. |
| `simple-pretty.rkt` | safe utility | `webracket/simple-pretty` | WebRacket-owned pretty printer; not JS/browser-specific. |
| `storage.rkt` | safe wrapper | `browser/storage` | localStorage/sessionStorage wrapper; no public module yet. |
| `sxml.rkt` | safe utility | `webracket/sxml` | SXML-to-HTML utility; module shim already exists but still includes legacy source. |
| `temp.rkt` | test/demo wrapper | `js/temp` | Tiny demo/test wrapper around `temp.ffi`; keep mostly for coverage. |
| `threading.rkt` | syntax/helper | `webracket/threading` | Threading macros; not JS/browser-specific. |
| `websocket.rkt` | safe wrapper | `browser/websocket` | WebSocket wrapper with handler/listener normalization. |
| `window.rkt` | safe wrapper | `browser/window` | Window wrapper and browser-global helpers. |

Backup files (`*.rkt~`) and `compiled/` artifacts are not part of the migration
surface.

## Public Require Names

Chosen naming rule:

- Raw FFI modules stay under `webracket/unsafe/*`.
- JavaScript language/built-in APIs use `js/*`.
- Browser Web APIs use `browser/*`.
- Third-party library facades use their library name, such as `jsxgraph` and
  `xterm`.
- WebRacket-owned language helpers use `webracket/*`.
- Internal helper modules should be private unless user code has a strong reason
  to require them directly.

Public surface:

| New require | Legacy source |
| --- | --- |
| `js/array` | `array.rkt` |
| `js/console` | `console.rkt` |
| `js/iterator` | `iterator.rkt` |
| `js/performance` | `performance.rkt` |
| `js/temp` | `temp.rkt` |
| `browser/audio` | `audio.rkt` |
| `browser/canvas` | `canvas.rkt` |
| `browser/document` | `document.rkt` |
| `browser/dom` | `dom.rkt` |
| `browser/domrect` | `domrect.rkt` |
| `browser/element` | `element.rkt` |
| `browser/event` | `event.rkt` |
| `browser/fetch` | `fetch.rkt` |
| `browser/image` | `image.rkt` |
| `browser/indexed-db` | `indexed-db.rkt` |
| `browser/media` | `media.rkt` |
| `browser/rquery` | `rquery.rkt` |
| `browser/storage` | `storage.rkt` |
| `browser/websocket` | `websocket.rkt` |
| `browser/window` | `window.rkt` |
| `jsxgraph` | `jsx-graph.rkt` |
| `webracket/define-key` | `define.rkt` |
| `webracket/simple-pretty` | `simple-pretty.rkt` |
| `webracket/sxml` | `sxml.rkt` |
| `webracket/threading` | `threading.rkt` |

Decisions:

- Keep `performance` under `js/performance`, matching the existing module and
  dashboard coverage.
- Keep `iterator` under `js/iterator`, since it is a JavaScript iterator-helper
  wrapper used by other JS-facing APIs.
- Put `fetch`, `indexed-db`, and `storage` under `browser/*`, because the safe
  wrappers target browser host APIs.
- Keep `rquery-chain` private unless user-facing chain macros become a
  standalone API.
- Keep `simple-pretty`, `sxml`, and `threading` under `webracket/*` for now
  because they are WebRacket-owned support utilities.
