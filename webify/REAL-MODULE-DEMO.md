# Installed Module Demo

This is the current smallest end-to-end demo for the Webify module bridge. It
uses a real installed provider, `racket/bool`, instead of a hand-written test
linklet.

## What It Demonstrates

The demo pipeline is:

1. Compile a source module with Racket 9.2 machine-independent linklet support.
2. Discover the installed provider graph for `racket/bool`.
3. Add Webify's synthetic `module-protocol` provider for protocol imports.
4. Resolve provider imports to module-variable cells.
5. Instantiate the root module with cell-only exports.
6. Observe the root export through `js-log`.

The source module is intentionally tiny:

```racket
(module use-bool racket/base
  (require racket/bool)
  (provide y)
  (define y (boolean=? #t #t)))
```

The expected observed value is true. Under `--no-stdlib`, the JavaScript-facing
printer currently reports this as `true`; some WebRacket paths may report it as
`#t`.

## Where The Demo Lives

The executable smoke is in:

```text
webify/test-installed-module-runtime.rkt
```

The passing case is named:

```text
installed racket/bool graph reaches WebRacket runtime smoke
```

That smoke writes a temporary Racket 9.2 extractor script, serializes a
`webify-module-linklet-manifest`, reads it back in the normal test process,
builds a `webify-module-registry`, instantiates the manifest roots, and emits a
top-level WebRacket program that observes `(use-bool y)`.

The critical bridge call is:

```racket
(webify-module-loader-instantiate!
 loader
 (webify-module-linklet-manifest-roots manifest)
 #:define-export-aliases? #f
 ...)
```

`#:define-export-aliases? #f` matters because installed providers can export
names that collide with WebRacket primitives. The bridge should treat provider
exports as module cells, not top-level definitions.

## Why `racket/bool`

`racket/bool` is useful because it is a real installed module, but its runtime
surface is still small enough for the current bridge. It proves that the path is
no longer limited to synthetic hand-written linklets.

It also exercises a previous failure mode: `xor` is both a WebRacket primitive
and a provider export. The current bridge avoids that primitive alias collision
by observing cells directly instead of emitting top-level aliases.

## Known Frontier

The same smoke file also contains richer installed probes for `racket/list` and
`racket/string`. They are currently classified frontier cases, not passing
runtime demos:

```text
racket/list   -> provider-candidate-overreach / compiled-provider-shape
racket/string -> unresolved-import
```

Those failures are useful. `racket/list` now reaches transitive provider
discovery and exposes two sharper provider-graph blockers: some decoded
candidates overreach into non-module names such as `racket/for`, and some real
providers such as `racket/private/pico` compile to a faslable correlated
linklet object instead of the linklet-directory shape currently decoded by
Webify. `racket/string` is still a linklet-level name-resolution frontier for
internalized `string-join` variants.
