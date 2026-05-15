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

The next immutable-hash semantic milestone is tighter parity with Racket CS's
packed bnode details rather than the current practical subset:

- match Racket CS's exact packed child/key/value bit regions more closely
- add key wrapping if equal?/equal-always? need it for cyclic data
- replace weak and ephemeron strong fallbacks when the runtime has weak
  reference support
- expose ordinary immutable `hash-iterate-*` paths directly if linklets require
  those names, rather than relying on the current generic iterator bridge
