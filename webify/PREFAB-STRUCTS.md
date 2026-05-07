# Prefab Struct Support in Webify

This note records the prefab-struct implementation status in `webify` so the
thread can be resumed without reconstructing the design from commits and tests.

## Purpose

Prefab structs are important for module-linklet work because independently
compiled slices must agree on prefab type identity. A value created with
`make-prefab-struct` and an accessor or descriptor created later with
`make-struct-type ... 'prefab` should converge on the same runtime struct type
when their prefab keys describe the same shape.

The current implementation deliberately supports a useful subset of Racket's
prefab key grammar. Unsupported shapes should fail explicitly rather than being
quietly treated as fresh non-prefab struct types.

## Runtime Model

Most of the implementation lives in `runtime-wasm.rkt`.

Prefab struct types are interned in the runtime. The implementation builds an
internal registry key that contains enough shape information to identify a
prefab type, then stores the resulting `$StructType` in the prefab registry.
This is separate from the public key returned by `prefab-struct-key`, which may
be shorter for simple cases.

Prefab metadata is stored in the struct type's immutables slot as a pair:

```racket
(public-key . total-field-count)
```

That metadata lets runtime operations distinguish prefab struct types from
ordinary struct types, recover the public key, and preserve the total field
count needed by constructor and accessor operations.

Important runtime helpers include:

- `$simple-prefab-registry-key`, which builds the internal intern key.
- `$simple-prefab-public-key`, which builds the normalized public key.
- `$simple-prefab-type-metadata`, which packages public key metadata.
- `$prefab-metadata?/i32`, which recognizes prefab metadata.
- `$prefab-struct-type-key+field-count`, which reads prefab type metadata.
- `$prefab-struct-key`, which returns a prefab instance's public key.
- `$prefab-key?`, which validates supported prefab key shapes.
- `$simple-prefab-struct-type/checked`, which interns root/simple prefab types.
- `$simple-prefab-super-struct-type/checked`, which interns a child type over a
  simple parent key.
- `$simple-prefab-substruct-type/checked`, which interns a child type over an
  already-interned parent type.
- `$simple-prefab-struct-type-for-key/checked`, which recursively interns
  explicit prefab key chains.
- `$simple-prefab-chain-alias->explicit-key/checked`, which normalizes deeper
  short aliases into explicit key chains.
- `$simple-prefab-immutables->mutables`, which converts `make-struct-type`
  immutables into a prefab mutable-field mask.
- `$prefab-struct-field-mutable?/i32`, which enforces prefab mutability.
- `$make-prefab-struct`, which constructs prefab instances through the shared
  interned type path.
- `$make-struct-type`, whose prefab branch detects inspector `'prefab`, rejects
  unsupported features, and interns a matching prefab type.

One WebAssembly-specific detail: `i32.and` is eager. Alias detection that needs
to inspect list positions therefore uses guarded nested `if` checks instead of
combining shape checks with eager `and` expressions that could call `list-ref`
too early.

## Supported Surface

The compiler and `#lang webracket` surface know about the prefab primitives
through the usual primitive registration path:

- `compiler.rkt` registers the primitives for compiled WebRacket programs.
- `primitives.rkt` exports the public names and supplies dummy/native fallback
  behavior for programs run directly under `#lang webracket`.
- Tests live primarily in `test/test-basics.rkt`, with module-composition
  coverage in `webify/test-module-composer.rkt`.

The currently supported prefab key shapes include:

- Symbol keys such as `'point`.
- Root/simple list keys such as `'(point)`, `'(point 2)`, and
  `'(point 2 (0 #f) #())`.
- Root/simple auto-field keys with the currently validated auto values, such as
  `'(auto 1 (1 #f) #())`, `'(auto-value 1 (1 0) #())`,
  `'(auto-list 1 (1 (0 marker)) #())`, and
  `'(auto-vector 1 (1 #(0 marker)) #())`.
- Root/simple mutable masks such as `'(cell 2 (0 #f) #(1))` and
  `'(triple 3 (0 #f) #(0 2))`.
- One-level explicit super keys such as
  `'(child 1 (0 #f) #() parent 2 (0 #f) #())`.
- One-level aliases such as `'(child parent 2)`,
  `'(child 1 parent 2)`, `'(child #(0) parent 2 #(0 1))`, and
  `'(child 1 #(0) parent 2 #(0 1))`.
- Nested simple no-auto/no-mutable chains such as
  `'(grandchild child 1 parent 2)` and
  `'(grandchild 1 child 1 parent 2)`.
- Deeper explicit public-key chains such as
  `'(deep 1 (0 #f) #() grandchild 1 (0 #f) #() child 1 (0 #f) #() parent 2 (0 #f) #())`.
- Deeper simple aliases such as `'(deep grandchild 1 child 1 parent 2)` and
  `'(deep 1 grandchild 1 child 1 parent 2)`.

## Interning And Identity

The main behavior achieved so far is shared prefab identity across creation
paths.

For supported shapes:

- `make-prefab-struct` normalizes the key, interns or reuses the corresponding
  `$StructType`, fills explicit fields, and fills supported auto fields.
- `make-struct-type` with inspector `'prefab` computes the same prefab identity
  for the same shape.
- Accessors and mutators created from a matching prefab descriptor operate on
  instances created by `make-prefab-struct`.
- Cross-slice/module-composer tests can create prefab values in one slice and
  matching prefab descriptors/accessors in another slice.

This is the important bridge property for webify: prefab type identity is no
longer tied to one immediate constructor call site.

## Construction And Access

`$make-prefab-struct` supports construction for the implemented key subset.
For child structs, it recursively resolves the parent shape, copies parent
fields into the child instance, and then fills the child fields.

Prefab mutability is enforced through the prefab key's mutable mask. Mutators
reject writes to fields that are not listed as mutable.

The prefab branch of `$make-struct-type` rejects unsupported prefab features
such as properties and guards. That keeps the implementation honest: if a
program requests a prefab shape WebRacket does not implement yet, it should get
a clear failure instead of a subtly wrong struct type.

## Tests So Far

The current tests cover these broad behaviors:

- Basic prefab construction with `make-prefab-struct`.
- Public key recovery with `prefab-struct-key`.
- Type key and field-count recovery with
  `prefab-struct-type-key+field-count`.
- Root/simple prefab descriptors from `make-struct-type ... 'prefab`.
- Accessor and mutator identity across `make-prefab-struct` and
  `make-struct-type`.
- Auto fields for the supported auto-value subset.
- Mutable-mask enforcement for root/simple prefab structs.
- One-level supertype keys and aliases.
- Nested and deeper simple prefab chains.
- Deeper alias normalization for no-auto/no-mutable chains.
- Module-composer/cross-slice identity for the supported bridge cases.

## Missing Parts

The implementation is not a complete Racket prefab-struct implementation yet.
The known missing or intentionally deferred pieces are:

- Full Racket prefab key grammar support. The current implementation handles the
  shapes listed above, not every key accepted by Racket.
- Deeper mutable-mask aliases. Shapes such as
  `'(deep #(0) grandchild 1 child 1 parent 2)`,
  `'(deep 1 #(0) grandchild 1 child 1 parent 2)`, and
  `'(deep grandchild 1 #(0) child 1 parent 2)` are intentionally rejected for
  now.
- Deeper auto-field chains. Root/simple auto fields are supported for the
  validated subset, but parent and middle auto-field behavior in long chains
  still needs design and tests.
- Broader prefab-datum validation and interning. The supported auto values are
  limited to the scalar and compound datum-ish cases currently covered by tests.
- A full audit against the Racket Reference prefab section. The implementation
  has been grown from the cases needed by webify, so edge semantics should be
  checked before claiming general compatibility.
- Better diagnostics. Unsupported prefab shapes fail, but some error messages
  could be made more specific.
- Integration with unfinished runtime features such as complete `equal?`,
  printing, reading, writing, and graph sharing. These are not prefab-only
  issues, but full prefab behavior will eventually depend on them.
- Keeping `primitives.rkt` fallback behavior in sync with runtime behavior as
  new prefab shapes are added.

## Continuation Checklist

Good next steps when resuming prefab work:

1. Pick one missing key-family rather than trying to complete the whole grammar
   at once.
2. Add a minimal Racket-side example and expected behavior for that family.
3. Add focused WebRacket tests in `test/test-basics.rkt`.
4. Extend runtime key validation and normalization first.
5. Extend construction/interning second.
6. Re-run the focused prefab tests and module-composer bridge tests.
7. Update this document with the newly supported shapes and remaining gaps.
