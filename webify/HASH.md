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

The demodded regexp linklet uses immutable-looking local bookkeeping tables,
such as `#hasheqv()` plus `hash-set` and `hash-iterate-*`. WebRacket currently
has mutable hash runtime support and a first immutable `hasheqv` slice. The
`hash` and `hasheq` constructors currently reuse that immutable hasheqv backing
store for expander startup paths with symbol-like keys, but WebRacket does not
yet have complete equal?-key or eq?-key immutable `intmap`/HAMT representations.

Ephemeron hash tables are also currently a strong fallback:
`make-ephemeron-hasheq` returns an ordinary mutable `hasheq`. That is enough for
expander intern/cache tables during startup, but it does not implement
ephemeron GC semantics.

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

Now that `hasheqv` and `hash-set` have a real immutable first slice, Webify no
longer rewrites functional `hash-set` into `hash-set!`. The remaining bridge maps
public `hash-iterate-*` names to the existing mutable iterator primitives until
immutable hash iteration is implemented.

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

When immutable hashes become a milestone, WebRacket should grow a separate
immutable representation, probably starting with a simple persistent
copy-on-write representation for `hasheqv`, then moving toward a HAMT/intmap
style implementation if performance matters.

The remaining Webify hash bridge should be narrowed further when immutable hash
iteration lands, so ordinary `hash-iterate-*` works on the immutable runtime
representation instead of going through mutable iterator names.
