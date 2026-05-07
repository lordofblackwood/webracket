# Webify Struct Translation Inventory

This note records the current struct situation in `webify`.

The short version: Webify struct handling should not be a straight Schemify
port. Schemify targets Chez/Racket runtime records and helper forms. WebRacket
already has a Racket-oriented struct runtime and exposes many Racket struct
primitives directly, so Webify should translate toward that surface instead of
preserving Chez-specific record-descriptor output.

## Current Webify Struct Passes

### `struct-convert.rkt`

`struct-convert` recognizes the common lowered shape around
`make-struct-type`:

```racket
(define-values (struct:s make-s s? acc/muts ...)
  (let-values (((struct: make ? -ref -set!) mk))
    (values struct: make ? make-acc/muts ...)))
```

When the shape is accepted, it rewrites the binding into a sequence that is
designed for Chez/Schemify:

- `make-record-type-descriptor`
- `make-record-constructor-descriptor`
- `record-constructor`
- `record-predicate`
- `record-accessor`
- `record-mutator`
- `make-struct-type-install-properties`
- `structure-type-lookup-prefab-uid`
- `struct-type-constructor-add-guards`
- `#%nongenerative-uid`
- `#%struct-constructor`
- `#%struct-predicate`
- `#%struct-field-accessor`
- `#%struct-field-mutator`
- `unsafe-struct`
- `unsafe-sealed-struct?`
- impersonator/error helpers such as `impersonate-ref`,
  `impersonate-set!`, `#%struct-ref-error`, and `#%struct-set!-error`

These forms are currently recognized as unsupported first-slice compatibility
forms in `lower.rkt`. That is the right safety behavior for now: generated
programs should fail early instead of silently targeting Chez-only helpers.
`unsafe-struct*-ref` and `unsafe-struct*-set!` used to be in this rejected set,
but WebRacket now exposes raw starred access/update primitives for the
non-impersonator case.
The normal WebRacket-target path also avoids generating Chez `unsafe-struct`
constructor calls from known-constructor inlining.

### `struct-type-info.rkt`

`make-struct-type-info` parses a subset of `make-struct-type` forms and records
facts such as:

- struct name
- parent type
- immediate and total field counts
- whether the constructor is pure
- authentic and sealed properties
- prefab immutable fields
- non-prefab immutable fields
- constructor-name expression
- remaining `make-struct-type` arguments

This analysis is useful to Webify, but the downstream translation target should
change. The facts can guide WebRacket primitive calls and optimization, not only
Chez record-descriptor generation.

### `webify.rkt`

`webify.rkt` integrates struct analysis in two main ways:

- It calls `struct-convert` for top-level and local struct definitions.
- It inlines known struct constructors, predicates, accessors, and mutators to
  Schemify-style unsafe operations:

```racket
unsafe-struct
unsafe-struct?
unsafe-sealed-struct?
unsafe-struct*-ref
unsafe-struct*-set!
```

Those inlinings are another Chez/Schemify-shaped area. WebRacket now has both
the general `unsafe-struct-ref`/`unsafe-struct-set!` pair and the raw starred
`unsafe-struct*-ref`/`unsafe-struct*-set!` pair. The remaining unsupported part
is the broader Chez/Schemify `unsafe-struct` shape, plus sealed/tagged
predicate behavior and impersonator/chaperone paths.

### `known.rkt`, `infer-known.rkt`, and `constructed-procedure.rkt`

The known-value layer tracks struct-related facts:

- `known-struct-type`
- `known-struct-constructor`
- `known-struct-predicate`
- `known-field-accessor`
- `known-field-mutator`
- delayed `.../need-imports` variants
- `known-struct-type-property/immediate-guard`

`constructed-procedure.rkt` also records that
`make-struct-field-accessor` produces a one-argument procedure and
`make-struct-field-mutator` produces a two-argument procedure.

These facts are still valuable. They should survive the port, but the eventual
rewrites that consume them should emit WebRacket-compatible struct operations.

### `authentic.rkt`

`authentic-valued?` detects expressions known not to produce impersonators. This
is used by struct/property handling and can remain useful, but any behavior that
depends on impersonator/chaperone support must be gated by WebRacket runtime
support.

## WebRacket Struct Surface

WebRacket already exposes a broader Racket struct surface than the Schemify
record-descriptor output assumes.

`primitives.rkt` exports, among others:

- `make-struct-type`
- `make-struct-field-accessor`
- `make-struct-field-mutator`
- `make-struct-type-property`
- `struct-constructor-procedure?`
- `struct-predicate-procedure?`
- `struct-accessor-procedure?`
- `struct-mutator-procedure?`
- `struct?`
- `struct-type?`
- `struct-type-property?`
- `struct-type-property-accessor-procedure?`
- `struct-type-property-predicate-procedure?`
- `struct-type-authentic?`
- `struct->list`
- `struct->vector`
- `current-inspector`
- `impersonator?`
- `impersonator-val`
- `unsafe-struct?`
- `unsafe-struct-ref`
- `unsafe-struct-set!`
- `prop:authentic`
- `prop:sealed`

`compiler.rkt` treats the property descriptors as non-literal runtime
constants. `primitives-db.rkt` registers the callable primitives with
arities/properties, and `runtime-wasm.rkt` contains runtime implementations for
the major struct operations and property globals, including:

- `$make-struct-type`
- `$make-struct-field-accessor`
- `$make-struct-field-mutator`
- `$make-struct-type-property`
- `$struct-type-authentic?`
- `$struct->list`
- `$struct->vector`
- `$impersonator?`
- `$impersonator-val`
- `$unsafe-struct?`
- `$unsafe-struct*-ref`
- `$unsafe-struct*-set!`
- `$unsafe-struct-ref`
- `$unsafe-struct-set!`
- `$prop:sealed`

This means Webify should prefer preserving or translating to Racket struct
primitive calls where possible.

## Translation Direction

The first supported Webify struct subset should be:

- simple `make-struct-type` with zero auto fields
- no guard
- no custom properties except those already implemented in WebRacket
- no impersonator/chaperone paths
- no prefab translation unless the WebRacket runtime path is confirmed
- direct use of `make-struct-field-accessor` and `make-struct-field-mutator`
- `struct->list`, `struct->vector`, `struct?`, `struct-type?`, and procedure
  predicate operations preserved as WebRacket primitive calls

For that subset, a likely strategy is:

1. Keep `struct-type-info` as an analysis pass.
2. Disable or bypass `struct-convert`'s Chez record-descriptor rewrite for the
   WebRacket target. This gate is now in place for the normal Webify path:
   `webify.rkt` no longer calls `struct-convert` or `struct-convert-local`.
3. Preserve `make-struct-type`/accessor/mutator/property calls when WebRacket
   already supports them.
4. Rewrite only when the rewrite targets WebRacket primitives or runtime helpers
   that actually exist.
5. Keep unsupported Chez compatibility forms in `lower.rkt` until each one has
   an explicit WebRacket translation.

## Non-Goals For The First Struct Milestone

Do not attempt these in the first implementation slice:

- Chez `make-record-type-descriptor` compatibility
- `#%struct-constructor` and friends as public bridge targets
- Chez/Schemify `unsafe-struct` type-tagged operations
- prefab UID lookup
- struct guards
- chaperone/impersonator struct access paths
- full property guard semantics
- inspector-sensitive opaque printing
- complete `struct` macro parity

## Open Questions

- Should Webify remove `struct-convert` from the normal WebRacket path, or keep
  it behind an explicit compatibility flag while the runtime catches up?
- Which existing runtime struct property descriptors are complete enough for
  property-preserving translation?
- Should known-struct inlining preserve raw `unsafe-struct*-ref`/
  `unsafe-struct*-set!` when the receiver has already been checked, or target
  the more general `unsafe-struct-ref`/`unsafe-struct-set!` pair?
- How much of prefab support is needed for the first module examples?
- Which generated linklets from real Racket use struct guards early enough to
  block useful programs?

## Implemented Gate

The normal Webify path now preserves simple Racket struct primitive flows
instead of rewriting them to Chez record-descriptor forms. For example, a
linklet that binds a struct type with `make-struct-type` and creates field
accessors/mutators keeps:

```racket
make-struct-type
make-struct-field-accessor
make-struct-field-mutator
```

and does not introduce:

```racket
make-record-type-descriptor
make-record-constructor-descriptor
record-constructor
unsafe-struct
```

The old `struct-convert.rkt` file is still present as inherited source material,
but it is no longer part of the normal WebRacket-target Webify pipeline. Raw
starred struct accessors are now an accepted Webify/WebRacket boundary for the
non-impersonator case, and known constructor calls are preserved instead of
being rewritten to Chez `unsafe-struct`.

The module bridge also has a runtime smoke for struct-related exports across
composed slices. One linklet can create a simple struct type and export the
constructor, accessor, and mutator procedures. A later linklet can import those
export cells through the composer, construct a value, mutate a field, and read
the updated field through WebRacket's preserved struct primitives.

The first runtime-driven struct expansion exposes `prop:sealed` through the
WebRacket compiler/runtime surface. The bridge now has a smoke where one slice
creates a sealed struct type with `(list (cons prop:sealed #t))`, a later slice
imports the constructor and predicate, and the compiled program observes the
public `prop:sealed` value as a struct-type property.

Sealed inheritance is now checked through the same bridge path. An imported
unsealed parent struct type can be used as the parent of a child struct type in
a later slice. An imported sealed parent struct type is rejected by the runtime
with a clear contract message instead of falling through to a formatting trap or
Chez-style helper path.

Custom struct properties now have an inheritance smoke through the composed
module bridge. One slice creates a property with `make-struct-type-property`,
a second slice attaches it to a parent struct type, a third slice derives a
child struct type from that imported parent, and a final slice confirms that a
child instance satisfies the imported property predicate and returns the
inherited property value through the imported accessor. The compiled program
continues to use WebRacket-native `$make-struct-type-property` and
`$make-struct-type`, not Chez record helpers.

Struct constructor guards now run through the WebRacket-native constructor
path. The runtime canonicalizes an omitted guard to `#f`, validates an explicit
guard as a procedure, calls the guard with constructor init fields plus the
struct name, and uses the returned values as replacement init fields before
allocating the struct. The module bridge has positive coverage for a guard that
transforms fields across slices and negative coverage for a guard that returns
the wrong number of values.

Simple prefab struct types now have a first WebRacket-native normalized-key
path. When `make-struct-type` receives inspector `'prefab` for a simple
no-super, no-auto-field, no-property, no-guard shape, the runtime interns the
resulting `$StructType` by an internal key derived from prefab name and field
count. The descriptor also stores normalized prefab metadata as the public
short key plus field count. The module bridge has a smoke where two slices
independently create the same two-field prefab type, while a same-name
one-field prefab type remains distinct. More complex prefab requests are
rejected instead of silently becoming fresh non-prefab structure types.

The first public prefab utility bridge is also in place for that same simple
subset. `prefab-key?` recognizes symbol keys and the simple list aliases such
as `'(name)`, `'(name 2)`, and `'(name 2 (0 #f) #())`.
`make-prefab-struct` constructs instances through the same interned type path
used by `make-struct-type ... 'prefab`, while `prefab-struct-key` and
`prefab-struct-type-key+field-count` expose the stored short key metadata.
That bridge now includes auto-field keys with supported scalar and compound
auto values, such as `'(name 1 (1 #f) #())`, `'(name 1 (1 0) #())`,
`'(name 1 (1 (0 marker)) #())`, and `'(name 1 (1 #(0 marker)) #())`;
constructor calls provide only the non-auto fields, and the generated struct
stores the key's auto value in the auto fields. Single-index mutable field
masks and multi-field mutable masks are supported too, such as
`'(cell 2 (0 #f) #(1))` and `'(triple 3 (0 #f) #(0 2))`. Auto values and
mutable masks both participate in prefab interning and normalized public keys,
and the runtime mutator rejects writes to prefab fields that are not in the
mask. Duplicate mutable indexes, out-of-range mutable indexes, and non-datum
auto values remain outside the accepted subset.
One-level prefab supertypes are supported through the explicit flattened key
shape, such as `'(child 1 (0 #f) #() parent 2 (0 #f) #())`, and the common
one-level aliases `'(child parent 2)`, `'(child 1 parent 2)`,
`'(child #(0) parent 2 #(0 1))`, and
`'(child 1 #(0) parent 2 #(0 1))`. The parent type is interned before the
child type, aliases normalize to the same full child/parent key identity as
the explicit form, and parent/child accessors work on instances built from
`make-prefab-struct`. Nested prefab supertype chains are supported for the
simple no-auto/no-mutable middle shape, such as
`'(grandchild child 1 parent 2)` and
`'(grandchild 1 child 1 parent 2)`. These nested aliases construct instances
and normalize to the same full explicit key identity. Generated accessors from
matching nested `make-struct-type ... 'prefab` descriptors share that nested
type identity and work across the parent, child, and grandchild fields.
The explicit flattened public-key form is no longer limited to that one
nested parent level: deeper simple no-auto/no-mutable chains are reconstructed
recursively for prefab interning, so a chain such as
`deep-grandchild -> grandchild -> child -> parent` shares type identity across
`make-prefab-struct` and matching `make-struct-type ... 'prefab` descriptors.
The same deeper simple chains can also be written with short aliases such as
`'(deep-grandchild grandchild 1 child 1 parent 2)` and
`'(deep-grandchild 1 grandchild 1 child 1 parent 2)`; those aliases normalize
to the same full explicit public key as the long form. Deeper mutable-mask
aliases are intentionally outside the supported subset for now; `prefab-key?`
rejects shapes such as `'(deep-grandchild #(0) grandchild 1 child 1 parent 2)`
while the existing one-level mutable aliases remain supported.

## Proposed Next Implementation Milestone

Extend prefab support beyond the nested-simple-super/prefab-datum-auto subset:

- Decide whether deeper mutable-mask aliases are worth supporting; the current
  contract rejects them while preserving one-level mutable aliases.
- Broaden prefab-datum validation if more Racket datum cases are needed.

That milestone should include small tests showing:

- A deeper prefab subtype with mutable fields normalizes correctly if we choose
  to support that larger subset.
