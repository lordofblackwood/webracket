# WebRacket Treelist Design Notes

This document started as treelist research notes. The immutable dense treelist
port is now implemented in WebRacket, so this file also records the current
status, the supported subset, and the intentional limitations.

## Sources Read

Local reference documentation:

- `docs/reference/treelists.scrbl`
- `docs/reference/contracts.scrbl`, only as background for unsupported
  contract-facing APIs

Papers:

- `tmp/rrb-trees-stucki-2015.pdf`
  - Nicolas Stucki, Tiark Rompf, Vlad Ureche, Phil Bagwell,
    "RRB Vector: A Practical General Purpose Immutable Sequence"
- `/tmp/runtime-compiler-support-hamts-dls21.pdf`
  - Sona Torosyan, Jon Zeppieri, Matthew Flatt,
    "Runtime and Compiler Support for HAMTs"

Racket implementation:

- `../racket/racket/collects/racket/treelist.rkt`
- `../racket/racket/collects/racket/mutable-treelist.rkt`
- `../racket/pkgs/racket-test-core/tests/racket/treelist.rktl`

## Racket API Shape

Treelists are immutable sequence-like collections. They support indexed access,
updates, appending, splitting, and sublists with effectively logarithmic time
using a wide tree.

Core immutable API:

- `treelist?`
- `treelist`
- `make-treelist`
- `empty-treelist`
- `treelist-empty?`
- `treelist-length`
- `treelist-ref`
- `treelist-first`
- `treelist-last`
- `treelist-set`
- `treelist-add`
- `treelist-cons`
- `treelist-append`
- `treelist-insert`
- `treelist-delete`
- `treelist-take`
- `treelist-drop`
- `treelist-take-right`
- `treelist-drop-right`
- `treelist-sublist`
- `treelist-reverse`
- `treelist-rest`

Conversion API:

- `treelist->vector`
- `treelist->list`
- `vector->treelist`
- `list->treelist`

Reference APIs that depend on WebRacket features not currently available:

- `in-treelist`
- `sequence->treelist`
- `for/treelist`
- `for*/treelist`

Higher-level API:

- `treelist-map`
- `treelist-for-each`
- `treelist-filter`
- `treelist-member?`
- `treelist-find`
- `treelist-index-of`
- `treelist-flatten`
- `treelist-append*`
- `treelist-sort`

Mutable treelists are a separate datatype, not recognized by `treelist?`.
Conceptually, a mutable treelist is a box around an immutable treelist. Most
mutating operations replace the wrapped immutable treelist.

Chaperones, impersonators, contracts, serialization, streams, and sequences are
not currently supported in WebRacket. Treelist work should not attempt to add
those compatibility layers as part of the initial implementation.

Out of scope for initial treelists:

- `chaperone-treelist`
- `treelist-chaperone-state`
- `chaperone-mutable-treelist`
- `impersonate-mutable-treelist`
- `treelist/c`
- `mutable-treelist/c`
- serialization integration
- stream behavior
- sequence behavior, including `in-treelist`, `sequence->treelist`,
  `for/treelist`, and `for*/treelist`

## RRB Background

The RRB-vector paper describes treelists' data-structure family: wide immutable
trees with efficient indexed access, update, split, and concatenation.

Important ideas:

- Use a branching factor such as `32`, so tree height stays tiny in practice.
- With branching `32`, each radix step consumes `5` index bits.
- Balanced radix trees can locate a child by bit slicing:
  `(index >> (5 * height)) & 31`.
- Relaxed nodes allow children to have different subtree sizes.
- Relaxed nodes need accumulated child-size metadata to route an index.
- Persistent updates path-copy from root to leaf.
- Concatenation merges the right spine of the left tree with the left spine of
  the right tree, then rebalances.
- Insert and delete can be built from split/append operations.
- The paper's focused/transient-branch optimization improves locality and
  amortized costs, but it is not required for a first correct implementation.

The Racket implementation intentionally does not port every optimization from
the paper. It favors a relatively compact Racket-level implementation with a
simple node representation.

## HAMT Paper Lesson

The HAMT paper is not about treelists, but it is useful design guidance for
WebRacket runtime work.

Racket improved persistent HAMTs by adding `stencil-vector`, a compact
intermediate runtime datatype. The compiler/runtime do not implement all HAMT
logic; they provide a small primitive substrate that makes a library-level HAMT
fast and compact.

Lesson for treelists:

- Avoid baking the whole treelist algorithm into the compiler.
- Prefer a small set of runtime datatypes and helper primitives.
- Compact node layout matters for persistent trees.
- Functional copy/update helpers are worth considering when GC or Wasm-GC
  allocation costs become visible.
- Do not reach for a special packed representation too early if a straightforward
  Wasm-GC struct/array model is enough to get semantics correct.

## Racket Implementation Summary

Racket's immutable treelist is:

```racket
(struct treelist (root size height))
```

Constants:

```racket
(define BITS 5)
(define MAX_WIDTH 32)
(define MASK 31)
(define MAX_ERROR 2)
```

Node representation:

- A leftwise-dense node is just a vector of children.
- A relaxed node is `(cons children sizes)`.
- `children` is a vector.
- `sizes` is an accumulated-size vector.
- Leaves are height `0` nodes whose children are elements.

The implementation distinguishes "leftwise dense" from "fully dense":

- Fully dense means all children are full and dense.
- Leftwise dense means all earlier children are fully dense, while the last child
  can be partial but still leftwise dense.
- A node without a `sizes` vector is treated as leftwise dense.
- A node with a `sizes` vector is relaxed.

Important operations:

- `treelist-ref` uses radix indexing in leftwise-dense nodes and accumulated
  sizes in relaxed nodes.
- `treelist-set` path-copies and preserves the `sizes` vector when structure is
  unchanged.
- `treelist-add` tries to append into the rightmost branch; if the tree is full,
  it grows a new root.
- `treelist-cons` uses a structural left-spine fast path when the existing left
  spine can absorb the prepend; otherwise it falls back to prepending via
  append.
- `treelist-take` and `treelist-drop` trim one spine and then squash single-child
  roots.
- `treelist-insert` is built from `take`, `add`, `drop`, and `append`.
- `treelist-delete` is built from `take`, `drop`, and `append`.
- `treelist-append` calls `concat-subtree`, which uses `rebalance`.
- `rebalance` uses `concat-plan`, `distribute`, and `exec-concat-plan` to
  redistribute child slots.

Notable pragmatic detail:

- Racket's `take` and `drop` may produce trees that do not fully meet all
  invariants, because rebalancing every split would be costly. Future
  concatenations restore shape via rebalancing.

## Mutable Treelist Implementation

Racket's mutable treelist is:

```racket
(struct mutable-treelist ([tl #:mutable]))
```

Most mutating operations read the current immutable treelist, compute a new one,
and install it into the wrapper.

Special case:

- Unchaperoned `mutable-treelist-set!` mutates a leaf vector slot in place.
- To make this safe, mutable treelists are created from a copied treelist using
  `treelist-copy-for-mutable`.
- Appending/prepending another treelist copies or snapshots the other treelist
  before installing it, preserving the immutability of existing values.

This makes mutable treelists a good second-stage feature for WebRacket after
immutable treelists work.

## Suggested WebRacket Representation

The first WebRacket implementation should mirror Racket's simple model, but use
explicit Wasm-GC datatypes instead of Racket vectors and pairs.

Possible heap shapes:

```wasm
(type $Treelist
  (sub $Heap
    (struct
      (field $hash   (mut i32))
      (field $root   (ref $TreelistNode))
      (field $size   i32)
      (field $height i32))))

(type $TreelistNode
  (sub $Heap
    (struct
      (field $hash     (mut i32))
      (field $children (ref $Array))
      (field $sizes    (ref null $I32Array)))))
```

Interpretation:

- `sizes = null` means leftwise dense.
- `sizes != null` means relaxed, with accumulated child sizes.
- At height `0`, `children` contains treelist elements.
- At height greater than `0`, `children` contains `$TreelistNode` references.

This explicit node struct is a little more uniform than Racket's
vector-or-cons encoding, and it fits WebRacket's existing boxed-value style.

Open representation question:

- This question is now resolved in the implementation.
- WebRacket uses `MAX_WIDTH = 32`.
- That matches Racket's reference implementation and keeps the dense treelist
  shape, height boundaries, and regression tests aligned with the intended
  semantics.
- The current implementation therefore uses `BITS = 5`, `MAX_WIDTH = 32`, and
  `MASK = 31` for both dense nodes and conservative relaxed nodes.

## Current WebRacket Status

### Implemented Immutable API

Predicates, constructors, accessors, and conversions:

- `treelist?`
- `treelist`
- `make-treelist`
- `empty-treelist`
- `treelist-empty?`
- `treelist-length`
- `treelist-ref`
- `treelist-first`
- `treelist-last`
- `vector->treelist`
- `treelist->vector`
- `list->treelist`
- `treelist->list`

Persistent update and structural operations:

- `treelist-set`
- `treelist-add`
- `treelist-cons`
- `treelist-append`
- `treelist-append*`
- `treelist-insert`
- `treelist-delete`
- `treelist-take`
- `treelist-drop`
- `treelist-split-at`
- `treelist-take-right`
- `treelist-drop-right`
- `treelist-sublist`
- `treelist-reverse`
- `treelist-rest`
- `treelist-flatten`

Higher-order helpers:

- `treelist-map`
- `treelist-for-each`
- `treelist-filter`
- `treelist-find`
- `treelist-member?`
- `treelist-index-of`
- `treelist-sort`

### Implemented Representation

WebRacket uses:

- `$Treelist(root, size, height)`
- `$TreelistNode(children, sizes)`

Current invariants:

- The branching factor is `32`, with `BITS = 5` and `MASK = 31`.
- Dense nodes use `sizes = null`.
- Relaxed nodes use cumulative child sizes in `sizes`.
- WebRacket still preserves `sizes = null` for truly dense / leftwise-dense
  nodes where possible.
- `empty-treelist` is a runtime value exposed directly as a value primitive.

### Implemented Strategy

The current implementation intentionally favors correctness and persistence over
full RRB-tree sophistication.

- Dense multi-level construction is implemented.
- Relaxed-node traversal is implemented using cumulative child sizes for
  non-leftwise-dense nodes.
- `treelist-ref` and `treelist-set` now traverse both dense and relaxed nodes.
- `treelist-set` and `treelist-add` use persistent path-copying.
- `treelist-add` has a specialized right-spine fast path.
- `treelist-cons` has a specialized left-spine fast path.
- `treelist-append` now uses a closer Racket-style `concat-subtree` /
  `rebalance` append protocol.
- Append descends recursively to the true boundary subtree, merges boundary
  slots from left/center/right, computes a concat plan, flattens exactly one
  child level there, and rebuilds packed nodes upward with exact child sizes.
- Boundary rebuilding preserves element order and lets
  `treelist-node-build/checked` decide whether rebuilt nodes stay dense
  (`sizes = null`) or become relaxed (cumulative `sizes` table).
- This one-level boundary rebalance materially improves repeated append of
  medium chunks compared to the earlier simpler boundary packers while remaining
  smaller than a full RRB normalization pass.
- `treelist-take`, `treelist-drop`, and `treelist-split-at` now use structural
  split helpers instead of the earlier flatten/copy/rebuild path.
- `treelist-take-right`, `treelist-drop-right`, `treelist-sublist`,
  `treelist-insert`, `treelist-delete`, `treelist-rest`, and
  `treelist-reverse` are also structural and preserve dense metadata when valid
  and cumulative size tables otherwise.
- Higher-order operations such as `treelist-map`, `treelist-for-each`,
  `treelist-filter`, `treelist-find`, `treelist-member?`, and
  `treelist-index-of` now traverse treelist nodes directly in left-to-right
  order instead of flattening the input treelist first.
- `treelist-flatten` now traverses nested treelist nodes directly instead of
  materializing each nested treelist before recursion.
- `treelist-append*` now traverses the outer treelist directly, validating each
  element left-to-right before reusing the existing append helper.
- Treelist formatting now traverses nodes directly into the existing growable
  string builder instead of materializing the formatted treelist first.
- Full RRB rebalancing and deep normalization are still not implemented.
- Conversions such as `treelist->vector` / `treelist->list` still intentionally
  materialize flat data, and `treelist-sort` still intentionally materializes
  via the existing list sort.
- `treelist-sort` is intentionally limited to the two-positional-argument form
  `(treelist-sort tl less-than?)`, and currently reuses list sort machinery via
  conversion.

### Formatting And Errors

Formatting:

- Raw treelist formatting is implemented for the existing `format/display`
  pipeline.
- Empty treelists display as `#<treelist>`.
- Non-empty treelists display as `#<treelist: elem elem ...>`.
- Nested treelists format recursively.
- This is display-oriented support; it does not yet aim for full `write`
  parity, graph sharing, or readable serialization.

Errors:

- Treelist contract and bounds failures are catchable in compiled WebRacket.
- Wrong-type treelist errors now report the surface primitive name where
  practical, such as `treelist-length` or `treelist-append*`.
- Exact Racket wording is not a goal yet; catchable behavior and operation-name
  fidelity are the current target.

### Host Shim Notes

`primitives.rkt` mirrors the implemented WebRacket subset for interpreted
`#lang webracket` programs.

- On newer Racket versions, it uses `dynamic-require` from `racket/treelist`.
- On older versions, it falls back to a vector-backed host treelist shim.
- The host shim intentionally restricts `treelist-sort` to the same simplified
  two-argument API as compiled WebRacket, even when host Racket offers keyword
  variants.

### Unsupported Areas

Still unsupported:

- full RRB-style rebalancing and deep normalization
- mutable treelists
- sequence support, including `in-treelist`, `sequence->treelist`,
  `for/treelist`, and `for*/treelist`
- stream behavior
- chaperones and impersonators
- contract-facing treelist APIs such as `treelist/c`
- serialization integration

## Testing Strategy

Use Racket's test file as the behavioral guide:

- `../racket/pkgs/racket-test-core/tests/racket/treelist.rktl`

Implemented WebRacket tests cover:

- predicates and empty value
- small constructors
- `make-treelist`
- `vector->treelist` and `treelist->vector`
- large dense trees crossing width boundaries: `32`, `33`, `1024`, `1025`
- `ref` across all indices
- `add` across leaf and root-growth boundaries
- `set` preserves original treelist
- `take/drop/sublist` at boundaries
- `append` of empty, small, and larger treelists
- `insert/delete` at front, middle, and end
- equality with expected lists/vectors
- catchable error paths
- primitive-name fidelity for representative wrong-type errors
- raw-result treelist formatting smoke cases

Important regression from Racket tests:

```racket
(let ([tl (for/fold ([tl (treelist)])
                    ([_ 1025])
            (treelist-insert tl 0 0))])
  (define tl2
    (for/fold ([tl tl])
              ([_ 962])
      (treelist-delete tl 0)))
  (test 64 treelist-length (treelist-insert tl2 0 0)))
```

This stress-tests repeated front insertion/deletion and should be adapted once
WebRacket has the relevant primitives.

## Remaining Work

The main treelist work that remains is not basic API coverage but fidelity and
future data-structure breadth:

- full RRB-style rebalance and deeper normalization of relaxed trees
- further split/append compaction for long uneven histories
- mutable treelists
- sequence/stream integration
- compatibility layers such as chaperones, contracts, and serialization

Until those land, Racket's implementation remains the semantic reference, while
WebRacket intentionally ships the immutable treelist subset described above,
including conservative relaxed-node support but not full RRB sophistication.
