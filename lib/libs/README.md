# Legacy Include-Lib Wrappers

This directory contains the old text-inclusion libraries used by
`include-lib`. They predate the Goal 1 module bridge and should gradually move
to normal module providers.

New module-based code should prefer explicit requires:

- `(require js/array)` replaces `(include-lib array)`.
- `(require js/console)` replaces `(include-lib console)`.
- `(require js/math)` is backed by `ffi/math.ffi`; compile runtime users with
  the matching FFI bundle while automatic module-to-FFI inference grows.

Migration status:

- `array.rkt`: migrated to `js/array`; kept here for compatibility.
- `console.rkt`: migrated to `js/console`; kept here for compatibility.
- `domrect.rkt`: migrated to `browser/domrect`; kept here for compatibility.
- `fetch.rkt`: migrated to `fetch`; kept here for compatibility.
- `indexed-db.rkt`: migrated to `indexed-db`; kept here for compatibility.
- `iterator.rkt`: migrated to `js/iterator`; kept here for compatibility.
- `math`: no legacy include file existed; `js/math` starts directly as a module.
- `performance.rkt`: migrated to `js/performance`; kept here for compatibility.
- `storage.rkt`: migrated to `storage`; kept here for compatibility.
- `sxml.rkt`: migrated to `webracket/sxml`; kept here for compatibility.
- `threading.rkt`: migrated to `webracket/threading`; kept here for compatibility.
- Other files: still legacy include-lib wrappers or compatibility shims.

When migrating another file, put raw bindings under `webracket/unsafe/*`.
Use `js/*` for JavaScript built-ins and host-object wrappers, and reserve
`browser/*` for DOM/window/document APIs. Keep this manifest current until
`include-lib` can be retired.
