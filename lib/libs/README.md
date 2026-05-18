# Legacy Include-Lib Wrappers

This directory contains the old text-inclusion libraries used by
`include-lib`. They predate the Goal 1 module bridge and should gradually move
to normal module providers.

New module-based code should prefer explicit requires:

- `(require js/console)` replaces `(include-lib console)`.
- `(require js/math)` is the first Math provider shape, but its unsafe layer is
  still placeholder-backed until direct `.ffi` module imports are available.

Migration status:

- `console.rkt`: migrated to `js/console`; kept here for compatibility.
- `math`: no legacy include file existed; `js/math` starts directly as a module.
- Other files: still legacy include-lib wrappers.

When migrating another file, put raw bindings under `webracket/unsafe/*`, public
wrappers under an appropriate collection such as `js/*` or `browser/*`, and keep
this manifest current until `include-lib` can be retired.
