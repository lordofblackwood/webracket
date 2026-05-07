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

## Current Webify Bridge

The demodded regexp linklet uses immutable-looking local bookkeeping tables,
such as `#hasheqv()` plus `hash-set` and `hash-iterate-*`. WebRacket currently
has mutable hash runtime support but not a separate immutable `intmap`/HAMT
representation.

To keep the regexp demod path moving, `webify/lower.rkt` temporarily lowers:

```racket
(hash-set ht k v)
```

to:

```racket
(let ([tmp ht])
  (hash-set! tmp k v)
  tmp)
```

and maps public `hash-iterate-*` names to the existing mutable iterator
primitives.

This is safe only for local bookkeeping tables where the original table is not
observed as an immutable value. It is not acceptable as general WebRacket or
Webify semantics.

## Semantic Gap Probe

`webify/test-lower.rkt` contains a focused probe that intentionally locks in
the current bridge behavior:

```racket
(let ([h0 (make-hasheqv)])
  (let ([h1 (lowered-hash-set h0 'a 1)])
    (list (eq? h0 h1)
          (hash-ref h0 'a #f))))
```

The bridge result is effectively:

```racket
'(#t 1)
```

Real immutable Racket semantics would instead keep the original table
unchanged and return a distinct updated immutable table.

## Later Direction

When immutable hashes become a milestone, WebRacket should grow a separate
immutable representation, probably starting with a simple persistent
copy-on-write representation for `hasheqv`, then moving toward a HAMT/intmap
style implementation if performance matters.

The Webify bridge should then be removed or narrowed so ordinary `hash-set`
means real functional update again.
