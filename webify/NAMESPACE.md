# Namespace Substrate Audit

Webify should not reimplement Racket's expander namespace model in
`runtime-wasm.rkt`. The extracted/webified expander already contains that layer.
WebRacket's job is to provide the lower runtime substrate that the expander's
namespace code expects.

## Owned By The Webified Expander

The expander sources under
`/Users/soegaard/Dropbox/GitHub/racket/racket/src/expander/namespace/` define the
real namespace model:

- `namespace` structs with module registries, root expansion contexts,
  phase-indexed definitions, available module instances, inspectors, and module
  instances.
- `make-namespace` and `current-namespace`.
- Namespace variable operations such as `namespace-get-variable`,
  `namespace-set-variable!`, and `namespace-set-transformer!`.
- Public namespace APIs such as `namespace-require`,
  `namespace-variable-value`, `namespace-set-variable-value!`,
  `namespace-mapped-symbols`, and `module->namespace`.
- Module declaration/instantiation plumbing for primitive modules, runtime
  modules, and reexporting modules.

That means WebRacket should avoid adding a parallel high-level namespace
implementation just to satisfy the expander. If the extracted expander can run,
those operations should come from the expander linklet itself.

## Required From WebRacket Runtime

The expander namespace layer assumes several lower-level services already exist:

- Linklet instance operations: creating instances, setting variables, reading
  variables, listing variable names, and preserving constant-ness.
- Primitive-module lookup through `primitive-table`.
- Hash tables, including persistent immutable hash constructors and functional
  `hash-set`.
- Boxes, weak boxes, ephemeron-hash fallbacks, symbols, vectors, pairs, structs,
  syntax/correlated values, and exception structs.
- Enough continuation-prompt/continuation-mark shape to let startup proceed, even
  where the first bridge is intentionally a no-op or placeholder.
- Host imports for filesystem/path/character/flonum operations that the compiled
  expander still reaches.

The current `primitive-table` bridge is deliberately broad: it returns a mutable
hasheq table of WebRacket primitive procedures for the primitive module names
that Racket CS uses during expander startup. That gets the namespace code past
primitive-module declaration, but it is not the final per-module primitive-table
partition.

## Current Boundary

The full expander extraction now compiles, validates, and instantiates. Calling
the generated `entry` no longer reports `primitive-table` as the immediate
unbound name. The current runtime failure is an exception-shape problem:
`entry` throws a Wasm exception, and the uncaught-exception path prints
`#<undefined>` for the exception message.

So the next namespace-related work should not be "implement namespaces" in
WebRacket. It should be:

- Keep improving the runtime/linklet substrate that the expander namespace layer
  sits on.
- Narrow `primitive-table` from a broad bridge to per-module tables when failures
  indicate wrong module membership.
- Investigate exception/struct field layout before assuming namespace logic is
  wrong.

## Later Public Namespace Support

Full user-facing Racket namespaces are still a later feature for WebRacket.
After the expander runs, WebRacket may expose namespace APIs by routing to the
webified expander's implementations. Until then, runtime namespace stubs should
stay minimal and should not grow into a second, incompatible namespace system.
