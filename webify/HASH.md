# Hash Implementation Notes

WebRacket now has real mutable hash tables and persistent immutable hash
tables. The immutable implementation is a Racket-CS-style HAMT over packed
system stencil vectors, not the old Webify bridge that rewrote functional
updates into mutable updates.

Weak and ephemeron hash tables are intentionally out of scope for the current
HAMT work. They remain documented strong approximations.

## Public Hash Kinds

Immutable hash constructors produce distinct wrapper types so the public
predicates can preserve the requested comparison mode:

- `hasheq`: `eq?` keys, `eq-hash/i32`
- `hasheqv`: `eqv?` keys, `eqv-hash/i32`
- `hash`: `equal?` keys, `equal-hash/i32`
- `hashalw`: `equal-always?` keys, `equal-always-hash/i32`

The wrappers store the public kind, the private HAMT root, and the entry count.
The private HAMT node representation is shared across all four kinds; lookup,
set, remove, `hash-ref-key`, and traversal dispatch through the wrapper's kind.

Mutable hashes are separate open-addressing tables and are not backed by the
immutable HAMT.

## Racket CS Shape

Racket CS keeps mutable hashes and immutable hashes as different
representations. In
`/Users/soegaard/Dropbox/GitHub/racket/racket/src/cs/rumble/hash.ss`,
mutable hashes wrap Chez Scheme hashtables, while immutable hashes are
persistent intmaps. The current Racket CS immutable implementation is mostly in
`src/cs/rumble/hamt-stencil.ss`.

The important WebRacket alignment point is the immutable layout:

- recursive bnodes are system stencil vectors
- terminal full-hash collisions are explicit cnodes
- bnode updates path-copy rather than mutate the original hash
- equal/equal-always keys can carry cached hash data without changing the
  public key returned by hash operations

## Immutable HAMT Layout

WebRacket uses an 8-way HAMT. Each level consumes a 3-bit hash group. New bnodes
are physical packed system stencil vectors:

- `system? = 2` marks a stencil vector as a private HAMT bnode
- the stencil vector mask is the packed metadata word
- slot 0 is a static marker
- the child region has 8 bits
- the key region has 8 bits
- the value region has 8 bits
- a child bit means the slot contains a recursive bnode or cnode
- a key/value bit pair means the slot contains an inline key/value entry

Packed slot indexes are computed by popcounting metadata bits below the target
bit. The packed metadata is also cached in the stencil vector's private hash
field and read directly by lookup/update/traversal code.

Small collision buckets are represented as lists of `$ImmutableHashEntry`
values. Once a bucket reaches the split threshold and more hash bits are
available, it is redistributed into a child HAMT node. If all usable hash bits
are exhausted, the collision is represented as `$ImmutableHashCNode`.

Singleton bnodes collapse on remove when the remaining slot can stand directly
in the parent. For example, removing one key from a two-key same-slot branch can
leave a direct `$ImmutableHashEntry` instead of a one-slot bnode.

## Entries And Wrapped Inline Keys

Full entries use `$ImmutableHashEntry`:

```racket
(key-hash key value)
```

Packed inline entries store key and value in separate stencil-vector slots. For
`hash` and `hashalw`, the inline key slot uses a private
`$ImmutableHashWrappedKey`:

```racket
(kind key-hash key)
```

The wrapper exists only inside packed inline key slots. It lets promotion reuse
the stored comparison-specific hash when an inline key/value pair becomes a
recursive child or terminal cnode. Public operations unwrap before returning a
key, so `hash-ref-key`, iteration, `hash->list`, `hash-keys`, and related
operations expose the original key.

For `hasheq` and `hasheqv`, packed inline key slots store the raw key because
the identity/eqv hash does not need this extra wrapper.

## Supported Operations

The immutable HAMT path supports the core public operations needed by Goal 1:

- constructors: `hash`, `hasheq`, `hasheqv`, `hashalw`
- association-list constructors: `make-immutable-hash`,
  `make-immutable-hasheq`, `make-immutable-hasheqv`,
  `make-immutable-hashalw`
- lookup: `hash-ref`, `hash-ref-key`, `hash-has-key?`
- update: functional `hash-set`, `hash-remove`, `hash-clear`
- predicates: `immutable-hash?`, `hash-equal?`, `hash-eq?`, `hash-eqv?`,
  `hash-equal-always?`
- traversal: `hash-keys`, `hash-values`, `hash->list`, `hash-for-each`,
  `hash-map`, and public `hash-iterate-*` functions

Functional update is persistent: `hash-set` and `hash-remove` return new hash
wrappers and do not mutate the original hash.

`hash-clear` returns a same-kind empty immutable table for immutable hashes,
matching the Reference's constant-time non-chaperone case.

## Webify Lowering

The old Webify bridge temporarily lowered:

```racket
(hash-set ht k v)
```

to:

```racket
(let ([tmp ht])
  (hash-set! tmp k v)
  tmp)
```

That was only a stopgap for local bookkeeping tables where the original table
was not observed. It was not valid immutable Racket semantics. Webify should no
longer rewrite functional immutable `hash-set` into `hash-set!`.

`webify/test-lower.rkt` keeps a semantic-gap probe so the old bridge behavior
does not accidentally return.

## Debug Hooks

The internal debug hook
`webracket-internal-immutable-hash-debug-shape` is available only when the
compiler is run with `--internal-bind-immutable-hash-debug-shape`. It returns:

```racket
(list entries bnodes cnodes buckets inlines max-depth slots)
```

`buckets` counts real multi-entry bucket lists. `inlines` counts direct
`$ImmutableHashEntry` leaves.

The same flag enables `webracket-internal-immutable-hamt-packed-bits`, which
returns:

```racket
(list group child-bit key-bit value-bit current-bit)
```

These hooks are intentionally not public primitives. They exist to make
representation regressions visible while WebRacket continues toward larger
module workloads.

## Verification Coverage

`test/test-basics.rkt` covers the current immutable HAMT behavior:

- all four immutable hash kinds
- path-copying set/remove
- duplicate-key update without duplicate traversal entries
- recursive bucket splits
- deep bnode paths
- terminal cnode full-hash collisions
- singleton branch collapse
- packed metadata shape checks
- cross-kind add/remove/update stress
- private equal-key hash caching during packed inline promotion
- public key unwrapping through `hash-ref-key` and traversal
- public `hash-iterate-*` accessors over mutable and immutable hashes

The bounded runner is `test/test-basics-runner.rkt`, which runs the suite with
`--no-stdlib`, the debug hook enabled, and a memory limit.

## Known Limitations

The remaining hash limitations are outside the core immutable HAMT
representation:

- weak and ephemeron hash tables are strong fallbacks
- weak/ephemeron keys are not dropped by GC
- ephemeron key/value reachability semantics are not implemented
- chaperone/impersonator hash behavior is not implemented
- performance and shape parity should still be checked on library-sized
  workloads, not only unit tests

## Next Direction

For Goal 1, HAMTs are no longer the main blocker. The useful next step is to
return to module/library enablement and use the current immutable hash support
against larger `racket/base`-adjacent libraries such as `racket/set`,
`racket/sequence`, `racket/match`, `racket/format`, and `racket/promise`.

Weak and ephemeron work should wait until WebRacket has a deliberate weak
reference story instead of being layered onto the current strong hash tables.
