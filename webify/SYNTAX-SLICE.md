# Syntax Slice Staging

This file tracks the `read-syntax` staging path. The goal is to copy upstream
Racket expander files only when the demod probe proves they are needed.

The focused probe is:

```sh
../racket/racket/bin/racket webify/check-read-syntax-provider.rkt
```

The ratchet test is:

```sh
../racket/racket/bin/racket webify/test-read-syntax-provider.rkt
```

## Dependency Table

| File | Why copied | Boundary exposed |
| --- | --- | --- |
| `racket-src/expander/syntax/read-syntax.rkt` | First syntax-aware provider dependency for `read-syntax`. | `common/performance.rkt` |
| `racket-src/expander/common/performance.rkt` | Required by `syntax/read-syntax.rkt` for `performance-region`. | `syntax/syntax.rkt` |
| `racket-src/expander/syntax/syntax.rkt` | Provides the expander syntax-object representation used by `read-to-syntax`. | `compile/serialize-property.rkt` |
| `racket-src/expander/compile/serialize-property.rkt` | Provides serialization struct properties used by syntax objects. | `compile/serialize-state.rkt` |
| `racket-src/expander/compile/serialize-state.rkt` | Paired serialization state support required by `syntax/syntax.rkt`. | `common/set.rkt` |
| `racket-src/expander/common/set.rkt` | Lightweight expander set abstraction used by serialization and syntax state. | `namespace/inspector.rkt` |
| `racket-src/expander/namespace/inspector.rkt` | Provides `current-module-code-inspector`, a parameter-like namespace value required by syntax objects. | `syntax/preserved.rkt` |
| `racket-src/expander/syntax/preserved.rkt` | Wraps preserved syntax-property values and checks serializable property content. | `syntax/datum-map.rkt` |
| `racket-src/expander/syntax/datum-map.rkt` | Traverses datum shapes that `datum->syntax` preserves, including vectors, boxes, prefab structs, and immutable hashes. | `syntax/taint-object.rkt` |
| `racket-src/expander/syntax/taint-object.rkt` | Tracks syntax taint propagation for compound datum content. | `syntax/weaker-inspector.rkt` |
| `racket-src/expander/syntax/weaker-inspector.rkt` | Chooses the weaker of two inspectors while preserving `#f` for inaccessible syntax content. | `syntax/property.rkt` |
| `racket-src/expander/syntax/property.rkt` | Implements syntax-property access, preservation checks, symbol-key listing, removal, and internal property predicates. | `syntax/taint.rkt` |
| `racket-src/expander/syntax/taint.rkt` | Provides the public syntax taint predicates and taint transformer used by property handling. | `syntax/original.rkt` |
| `racket-src/expander/syntax/original.rkt` | Provides the original-delimiter property symbol used by `read-syntax`. | `eval/dynamic-require.rkt` |
| `racket-src/expander/eval/dynamic-require.rkt` | Goal 1 stub that rejects reader-extension dynamic loading such as `#reader`. | `namespace/api-module.rkt` |
| `racket-src/expander/namespace/api-module.rkt` | Goal 1 stub for module-declaration checks made by reader-extension paths. | `namespace/namespace.rkt` |
| `racket-src/expander/namespace/namespace.rkt` | Goal 1 namespace shell used only far enough for private read-syntax extraction. | `namespace/registry.rkt` |
| `racket-src/expander/namespace/registry.rkt` | Goal 1 registry shell whose lock helper simply calls its thunk. | `syntax/srcloc.rkt` |
| `racket-src/expander/syntax/srcloc.rkt` | Provides source-location accessors used by syntax-reading paths. | `compile/read-linklet.rkt` |
| `racket-src/expander/compile/read-linklet.rkt` | Goal 1 stub that rejects compiled-code reading while allowing ordinary source syntax reads to flatten. | flattened provider succeeds |

## Current Boundary

There is no longer a missing-file boundary for the private provider slice. The
demodularizer flattens the first `read-syntax` slice, and a host-side linklet
smoke can read a tiny syntax object from an input string.

The public boundary is still intentionally closed:

- Reader extensions that need dynamic module loading are rejected by the
  private `eval/dynamic-require.rkt` stub.
- Compiled-code reading is rejected by the private `compile/read-linklet.rkt`
  stub.
- The namespace modules are shells, not a browser-side namespace/eval system.
- Public `read-syntax` aliases should stay unpublished until the flattened
  provider is composed through WebRacket and tested in the browser runtime.

## Private WebRacket Composition

`webracket.rkt` can now compose the private provider with:

```text
--expander-read-syntax-provider
```

This exposes only `webify-expander-*` aliases for `read-syntax` and same-slice
syntax inspection helpers. It intentionally does not expose public
`read-syntax`; the public handoff waits on the `#lang`/reader-extension story.

The focused WebRacket smoke covers simple datums, vectors, strings, and source
locations. Negative smokes confirm that reader-extension dynamic loading and
compiled-code input fail deliberately instead of silently crossing into an
unsupported namespace/eval path.
