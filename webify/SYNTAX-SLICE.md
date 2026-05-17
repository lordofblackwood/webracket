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

## Current Boundary

The current expected missing file is:

```text
racket-src/expander/syntax/property.rkt
```

Do not publish public `read-syntax` aliases until this staged slice has a
clear provider boundary and the transitive syntax/namespace dependencies are
understood.
