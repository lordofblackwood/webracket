# Hash Notes

Webify currently has a narrow hash bridge for demodded library linklets. That
bridge is useful for continuing regexp work, but it is not full Racket hash
semantics.

## Racket CS Model

Racket CS keeps mutable and immutable hashes as different representations.

In `/Users/soegaard/Dropbox/GitHub/racket/racket/src/cs/rumble/hash.ss`,
authentic hashes are either immutable `intmap`s or mutable hash records:

```racket
(define (authentic-hash? v) (or (intmap? v) (mutable-hash? v)))

(define (immutable-hash? v)
  (or (intmap? v)
      ...))
```

Mutable hashes wrap Chez Scheme hashtables:

```racket
(define-record mutable-hash locked-iterable-hash
  (ht)) ; Chez Scheme hashtable
```

Immutable hashes are persistent `intmap`s. The current CS implementation lives
mostly in `src/cs/rumble/hamt-stencil.ss`; older/alternate notes are in
`src/cs/rumble/patricia.ss`. The immutable constructors start from empty
`intmap` values and use `intmap-set`:

```racket
(define-hash-constructors hasheqv make-immutable-hasheqv empty-hasheqv)
```

Functional update is therefore persistent:

```racket
(define (hash-set ht k v)
  (cond
   [(intmap? ht) (intmap-set ht k v)]
   ...
   [else error]))
```

The original hash is not mutated.

## Old Webify Bridge

The demodded regexp and expander linklets use immutable-looking local
bookkeeping tables, such as `#hasheqv()` plus `hash-set` and
`hash-iterate-*`. WebRacket now has mutable hash runtime support and a
persistent immutable HAMT slice. The public immutable constructors have
distinct wrapper types for `hash`, `hasheq`, `hasheqv`, and `hashalw`, so
predicates like `hash-equal?`, `hash-eq?`, `hash-eqv?`, and
`hash-equal-always?` can distinguish the public kind.

Those wrappers share the same private HAMT node/entry representation, but
lookup, update, removal, and `hash-ref-key` route through the wrapper's
comparison kind:

- `hasheq`: `eq?` with `eq-hash/i32`
- `hasheqv`: `eqv?` with `eqv-hash/i32`
- `hash`: `equal?` with `equal-hash/i32`
- `hashalw`: `equal-always?` with `equal-always-hash/i32`

The current HAMT uses an 8-way stencil-vector bnode at each level,
path-copying on set/remove. Small buckets are kept as lists of immutable hash
entries; once a bucket grows past the split threshold, it is redistributed into
a child HAMT node. If all usable hash bits are exhausted, WebRacket now uses an
explicit cnode heap object, matching Racket CS's distinction between recursive
bnodes and terminal collision nodes. Updating an existing key replaces the
bucket/cnode entry for traversal purposes, and removing the last entry from a
child node prunes the empty branch.

The Goal 1 installed smoke suite now includes immutable hash paths:
`make-immutable-hash`, functional `hash-set`, `hash-ref`, and traversal through
`hash-keys`, `hash-values`, `hash->list`, `hash-for-each`, `hash-map`, and
`hash-clear`. The unit tests also cover recursive bucket splits, deep bnode
paths, cnode full-hash collisions, path-copy removal, replacement without
duplicate iterator entries, and the public hash-kind predicates.

## Packed Bnode Delta

Racket CS's HAMT bnodes are packed system stencil vectors. A single stencil mask
contains several regions:

- a static field region
- an 8-bit child region
- an 8-bit key region
- an 8-bit value region

For a given 3-bit hash group, the child bit says that the slot contains a child
bnode/cnode, while the key/value bits say that the slot contains an inline
entry. Some Racket CS shapes can represent an implicit `#t` value by omitting a
value bit. The equal?/equal-always? variants can also wrap keys so the HAMT can
cache comparison-specific hash information without changing the public key.

WebRacket now uses physical packed bnodes for new immutable hash HAMT nodes:

- immutable hash wrappers store the public kind, root, and count outside the
  HAMT root
- bnodes are system stencil vectors marked with `system? = 2`
- the stencil mask is the packed metadata word: static marker bit, child bits,
  key bits, and value bits
- slot 0 is the static marker; child/key/value slots are addressed by
  popcounting the metadata below the target bit
- inline entries are stored as separate key and value slots
- terminal full-hash collisions are still represented as ordinary buckets in the
  current packed path; the older explicit `$ImmutableHashCNode` remains supported
  for existing/probed nodes
- equal?/equal-always? keys are not wrapped yet

Lookup, `hash-ref-key`, `hash-has-key?`, set, remove, iteration, and debug-shape
all understand the packed layout. Collision promotion recomputes a stored inline
key's hash from the hash kind when the key/value pair needs to become a recursive
child or terminal bucket.

An internal debug-only compiler hook,
`webracket-internal-immutable-hash-debug-shape`, can be enabled with
`--internal-bind-immutable-hash-debug-shape`. It returns:

```racket
(list entries bnodes cnodes buckets inlines max-depth slots)
```

Here `buckets` means real multi-entry bucket lists, while `inlines` counts
direct `$ImmutableHashEntry` leaves.

The same flag also enables
`webracket-internal-immutable-hamt-packed-bits`, which returns:

```racket
(list group child-bit key-bit value-bit current-bit)
```

Each private HAMT bnode stores the packed word in the stencil vector's private
cache field too. Lookup reads that stored word directly; the derivation helper is
now only for compatibility with older one-region bnodes and debugging.

Removal also collapses singleton bnodes when the remaining slot can stand
directly in its parent. For example, removing one key from a two-key same-slot
bucket leaves a direct `$ImmutableHashEntry` root instead of a one-slot bnode.
That keeps the representation compact while preserving immutable path-copying.

The hook is not exported as a public primitive; it exists so shape regression
tests can verify recursive bnodes, terminal buckets/cnodes, and
collapse-after-remove behavior stay intact while we continue tightening parity
with Racket CS.

Ephemeron hash tables are also currently a strong fallback:
`make-ephemeron-hasheq` returns an ordinary mutable `hasheq`. That is enough for
expander intern/cache tables during startup, but it does not implement
ephemeron GC semantics.

Weak and ephemeron support is intentionally a documented strong approximation
for now. The constructors preserve the public API shape and key-comparison
mode, which is enough for Goal 1 code that uses weak/ephemeron tables as
startup caches or registries. They do not preserve GC-sensitive behavior:
keys are not dropped when unreachable, ephemeron values do not participate in
Racket's key/value reachability rule, and iteration never observes
collector-driven disappearance. A real implementation should wait until the
runtime has either Wasm-GC weak-reference hooks or a deliberate WebRacket weak
reference layer instead of layering ad-hoc behavior on the current strong hash
tables.

Before WebRacket had immutable hash support, `webify/lower.rkt` temporarily
lowered:

```racket
(hash-set ht k v)
```

to:

```racket
(let ([tmp ht])
  (hash-set! tmp k v)
  tmp)
```

The bridge was safe only for local bookkeeping tables where the original table
was not observed as an immutable value. It was not acceptable as general
WebRacket or Webify semantics.

Now that immutable hashes and `hash-set` have a real persistent first slice,
Webify no longer rewrites functional `hash-set` into `hash-set!`. Immutable hash
traversal now reuses the shared private representation through generic iterator
helpers, so public operations like `hash-keys`, `hash-values`, `hash->list`,
`hash-for-each`, and `hash-map` can run on immutable wrappers without copying
them to a mutable table first. `hash-clear` is implemented as a same-wrapper
empty immutable table, which matches the Reference's constant-time
non-chaperone case; chaperone/impersonator hash traversal is not implemented.

## Semantic Gap Probe

`webify/test-lower.rkt` contains a focused probe that intentionally locks in
the old bridge's semantic gap, so it does not come back accidentally:

```racket
(let ([h0 (make-hasheqv)])
  (let ([h1 (lowered-hash-set h0 'a 1)])
    (list (eq? h0 h1)
          (hash-ref h0 'a #f))))
```

The old bridge result was effectively:

```racket
'(#t 1)
```

Real immutable Racket semantics instead keep the original table unchanged and
return a distinct updated immutable table. The current lowering preserves that
functional `hash-set` shape.

## Later Direction

The next immutable-hash semantic milestone is tighter parity with the remaining
Racket CS HAMT details:

- restore/promote terminal full-hash collision buckets to explicit cnodes in the
  physical packed path
- add key wrapping if equal?/equal-always? need it for cyclic data
- replace weak and ephemeron strong fallbacks when the runtime has weak
  reference support
- expose ordinary immutable `hash-iterate-*` paths directly if linklets require
  those names, rather than relying on the current generic iterator bridge
