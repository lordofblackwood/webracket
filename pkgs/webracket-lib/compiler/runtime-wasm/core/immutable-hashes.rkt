#lang racket

(provide immutable-hash-runtime-only-helpers)

(require "../core-helper.rkt")

;; immutable-hash-prelude-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash and reader-placeholder prelude helpers.
(define immutable-hash-prelude-runtime-only-helpers
  (append
   (for/list ([name '($make-empty-immutable-hasheq
                      $make-empty-immutable-hasheqv
                      $make-empty-immutable-hash
                      $make-empty-immutable-hashalw)]
              [type '($HashEqImmutable
                      $HashEqvImmutable
                      $HashEqualImmutable
                      $HashEqualAlwaysImmutable)])
     (core-runtime-helper
      name
      (symbol->string name)
      (lambda ()
        `(func ,name (type $Prim0)
               (result (ref eq))
               (struct.new ,type
                           (i32.const 0)
                           (global.get $false)
                           (global.get $missing)
                           (i32.const 0))))))

   (list
    ;; hash-placeholder? : any/c -> boolean?
    ;;   Recognize hash placeholders produced by make-hash-placeholder
    ;;   and its comparison-kind variants.
    (core-runtime-helper
     '$hash-placeholder?
     "$hash-placeholder?"
     (lambda ()
       `(func $hash-placeholder? (type $Prim1)
              (param $v (ref eq)) ;; any value
              (result   (ref eq))
              (if (result (ref eq))
                  (ref.test (ref $HashPlaceholder) (local.get $v))
                  (then (global.get $true))
                  (else (global.get $false))))))

    ;; placeholder? : any/c -> boolean?
    ;;   Recognize reader-graph placeholders created by make-placeholder.
    (core-runtime-helper
     '$placeholder?
     "$placeholder?"
     (lambda ()
       `(func $placeholder? (type $Prim1)
              (param $v (ref eq)) ;; any value
              (result   (ref eq))
              (if (result (ref eq))
                  (ref.test (ref $Placeholder) (local.get $v))
                  (then (global.get $true))
                  (else (global.get $false))))))

    ;; make-placeholder : any/c -> placeholder?
    ;;   Create a mutable reader-graph placeholder cell.
    (core-runtime-helper
     '$make-placeholder
     "$make-placeholder"
     (lambda ()
       `(func $make-placeholder (type $Prim1)
              (param $v (ref eq)) ;; initial value
              (result   (ref eq))
              (struct.new $Placeholder
                          (i32.const 0)
                          (local.get $v)))))

    ;; placeholder-set! : placeholder? any/c -> void?
    ;;   Replace the value stored in a reader-graph placeholder.
    (core-runtime-helper
     '$placeholder-set!
     "$placeholder-set!"
     (lambda ()
       `(func $placeholder-set! (type $Prim2)
              (param $ph-raw (ref eq)) ;; placeholder?
              (param $v      (ref eq)) ;; new value
              (result        (ref eq))

              (if (i32.eqz (ref.test (ref $Placeholder) (local.get $ph-raw)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:placeholder-set!)
                              (global.get $string:placeholder?)
                              (local.get $ph-raw))
                        (unreachable)))
              (struct.set $Placeholder $value
                          (ref.cast (ref $Placeholder) (local.get $ph-raw))
                          (local.get $v))
              (global.get $void))))

    ;; placeholder-get : placeholder? -> any/c
    ;;   Return the current value stored in a reader-graph placeholder.
    (core-runtime-helper
     '$placeholder-get
     "$placeholder-get"
     (lambda ()
       `(func $placeholder-get (type $Prim1)
              (param $ph-raw (ref eq)) ;; placeholder?
              (result        (ref eq))

              (if (i32.eqz (ref.test (ref $Placeholder) (local.get $ph-raw)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:placeholder-get)
                              (global.get $string:placeholder?)
                              (local.get $ph-raw))
                        (unreachable)))
              (struct.get $Placeholder $value
                          (ref.cast (ref $Placeholder) (local.get $ph-raw))))))

    ;; $reader-graph-resolve : any/c exact-nonnegative-integer? -> any/c
    ;;   Resolve the acyclic placeholder/pair subset used by simple
    ;;   `shared` expansions. Full reader graph support needs sharing
    ;;   preservation plus hash-placeholder reconstruction.
    (core-runtime-helper
     '$reader-graph-resolve
     "$reader-graph-resolve"
     (lambda ()
       `(func $reader-graph-resolve
              (param $v    (ref eq)) ;; graph fragment
              (param $fuel i32)      ;; recursion budget
              (result     (ref eq))

              (local $ph     (ref $Placeholder))
              (local $pair   (ref $Pair))
              (local $vec    (ref $Vector))
              (local $box    (ref $Box))
              (local $arr    (ref $Array))
              (local $out    (ref $Array))
              (local $len    i32)
              (local $i      i32)
              (local $fuel-1 i32)

              (if (i32.le_s (local.get $fuel) (i32.const 0))
                  (then
                   (call $raise-arguments-error
                         (global.get $symbol:make-reader-graph)
                         (global.get $string:reader-graph-unsupported)
                         (array.new_fixed $Args 0))
                   (unreachable)))
              (if (ref.test (ref $HashPlaceholder) (local.get $v))
                  (then
                   (call $raise-arguments-error
                         (global.get $symbol:make-reader-graph)
                         (global.get $string:reader-graph-unsupported)
                         (array.new_fixed $Args 0))
                   (unreachable)))
              (local.set $fuel-1 (i32.sub (local.get $fuel) (i32.const 1)))
              (if (ref.test (ref $Placeholder) (local.get $v))
                  (then
                   (local.set $ph (ref.cast (ref $Placeholder) (local.get $v)))
                   (return
                    (call $reader-graph-resolve
                          (struct.get $Placeholder $value (local.get $ph))
                          (local.get $fuel-1)))))
              (if (ref.test (ref $Pair) (local.get $v))
                  (then
                   (local.set $pair (ref.cast (ref $Pair) (local.get $v)))
                   (return
                    (struct.new $Pair
                                (i32.const 0)
                                (call $reader-graph-resolve
                                      (struct.get $Pair $a (local.get $pair))
                                      (local.get $fuel-1))
                                (call $reader-graph-resolve
                                      (struct.get $Pair $d (local.get $pair))
                                      (local.get $fuel-1))))))
              (if (ref.test (ref $Vector) (local.get $v))
                  (then
                   (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                   (local.set $arr (struct.get $Vector $arr (local.get $vec)))
                   (local.set $len (array.len (local.get $arr)))
                   (local.set $out (array.new $Array (global.get $void) (local.get $len)))
                   (local.set $i (i32.const 0))
                   (block $done
                          (loop $loop
                                (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                (array.set $Array
                                           (local.get $out)
                                           (local.get $i)
                                           (call $reader-graph-resolve
                                                 (array.get $Array (local.get $arr) (local.get $i))
                                                 (local.get $fuel-1)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $loop)))
                   (return
                    (struct.new $Vector
                                (i32.const 0)
                                (i32.const 1)
                                (local.get $out)))))
              (if (ref.test (ref $Box) (local.get $v))
                  (then
                   (local.set $box (ref.cast (ref $Box) (local.get $v)))
                   (return
                    (struct.new $Box
                                (i32.const 0)
                                (i32.const 1)
                                (call $reader-graph-resolve
                                      (struct.get $Box $v (local.get $box))
                                      (local.get $fuel-1))))))
              (local.get $v))))

    ;; make-reader-graph : any/c -> any/c
    ;;   First slice for `racket/shared`: resolve acyclic placeholder/pair
    ;;   graphs, vectors, and boxes. Cyclic graphs, prefab structs, and
    ;;   hash placeholders need the later sharing-preserving implementation.
    (core-runtime-helper
     '$make-reader-graph
     "$make-reader-graph"
     (lambda ()
       `(func $make-reader-graph (type $Prim1)
              (param $v (ref eq)) ;; graph root
              (result   (ref eq))
              (call $reader-graph-resolve (local.get $v) (i32.const 100000)))))

    ;; hash-weak? : hash? -> boolean?
    ;;   WebRacket weak-hash constructors are currently strong fallbacks,
    ;;   so no hash table retains keys weakly yet.
    (core-runtime-helper
     '$hash-weak?
     "$hash-weak?"
     (lambda ()
       `(func $hash-weak? (type $Prim1)
              (param $ht (ref eq)) ;; hash?
              (result    (ref eq))
              (if (ref.eq (call $hash? (local.get $ht)) (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-weak?)
                              (global.get $string:hash?)
                              (local.get $ht))
                        (unreachable)))
              (global.get $false))))

    ;; $make-hash-placeholder/kind : symbol? (listof pair?) i32 -> hash-placeholder?
    ;;   Shared constructor for reader-graph hash placeholders.
    (core-runtime-helper
     '$make-hash-placeholder/kind
     "$make-hash-placeholder/kind"
     (lambda ()
       `(func $make-hash-placeholder/kind
              (param $who    (ref eq))      ;; constructor name
              (param $assocs (ref eq))      ;; association list
              (param $kind   i32)           ;; comparison kind tag
              (result        (ref eq))

              (local $node  (ref eq))
              (local $pair  (ref $Pair))
              (local $first (ref eq))

              (if (ref.eq (call $list? (local.get $assocs)) (global.get $false))
                  (then (call $raise-argument-error1
                              (local.get $who)
                              (global.get $string:listof-pair?)
                              (local.get $assocs))
                        (unreachable)))
              (local.set $node (local.get $assocs))
              (block $done
                     (loop $walk
                           (br_if $done (ref.eq (local.get $node) (global.get $null)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                           (local.set $first (struct.get $Pair $a (local.get $pair)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $first)))
                               (then (call $raise-argument-error1
                                           (local.get $who)
                                           (global.get $string:listof-pair?)
                                           (local.get $assocs))
                                     (unreachable)))
                           (local.set $node (struct.get $Pair $d (local.get $pair)))
                           (br $walk)))
              (struct.new $HashPlaceholder
                          (i32.const 0)
                          (local.get $kind)
                          (local.get $assocs)))))

    ;; make-hash-placeholder : (listof pair?) -> hash-placeholder?
    ;;   Equal?-based hash placeholder for make-reader-graph/read.
    (core-runtime-helper
     '$make-hash-placeholder
     "$make-hash-placeholder"
     (lambda ()
       `(func $make-hash-placeholder (type $Prim1)
              (param $assocs (ref eq)) ;; association list
              (result        (ref eq))
              (call $make-hash-placeholder/kind
                    (global.get $symbol:make-hash-placeholder)
                    (local.get $assocs)
                    (i32.const 0)))))

    ;; make-hasheq-placeholder : (listof pair?) -> hash-placeholder?
    ;;   Eq?-based hash placeholder for make-reader-graph/read.
    (core-runtime-helper
     '$make-hasheq-placeholder
     "$make-hasheq-placeholder"
     (lambda ()
       `(func $make-hasheq-placeholder (type $Prim1)
              (param $assocs (ref eq)) ;; association list
              (result        (ref eq))
              (call $make-hash-placeholder/kind
                    (global.get $symbol:make-hasheq-placeholder)
                    (local.get $assocs)
                    (i32.const 1)))))

    ;; make-hasheqv-placeholder : (listof pair?) -> hash-placeholder?
    ;;   Eqv?-based hash placeholder for make-reader-graph/read.
    (core-runtime-helper
     '$make-hasheqv-placeholder
     "$make-hasheqv-placeholder"
     (lambda ()
       `(func $make-hasheqv-placeholder (type $Prim1)
              (param $assocs (ref eq)) ;; association list
              (result        (ref eq))
              (call $make-hash-placeholder/kind
                    (global.get $symbol:make-hasheqv-placeholder)
                    (local.get $assocs)
                    (i32.const 2)))))

    ;; make-hashalw-placeholder : (listof pair?) -> hash-placeholder?
    ;;   Equal-always?-based hash placeholder for make-reader-graph/read.
    (core-runtime-helper
     '$make-hashalw-placeholder
     "$make-hashalw-placeholder"
     (lambda ()
       `(func $make-hashalw-placeholder (type $Prim1)
              (param $assocs (ref eq)) ;; association list
              (result        (ref eq))
              (call $make-hash-placeholder/kind
                    (global.get $symbol:make-hashalw-placeholder)
                    (local.get $assocs)
                    (i32.const 3))))))))

;; immutable-hash-hamt-bit-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate HAMT bit/packing helpers that still depend on monolithic runtime globals.
(define immutable-hash-hamt-bit-runtime-only-helpers
  (list
   (core-runtime-helper
    '$immutable-hasheqv-bucket-index
    "$immutable-hasheqv-bucket-index"
    (lambda ()
      `(func $immutable-hasheqv-bucket-index
             (param $mask i32)
             (param $bit  i32)
             (result i32)
             (i32.popcnt
              (i32.and (local.get $mask)
                       (i32.sub (local.get $bit) (i32.const 1)))))))

   ;; immutable-hamt-packed-group-index : i32 i32 -> i32
   ;;   Extract the 3-bit HAMT group used by the current 8-way layout.
   (core-runtime-helper
    '$immutable-hamt-packed-group-index
    "$immutable-hamt-packed-group-index"
    (lambda ()
      `(func $immutable-hamt-packed-group-index
             (param $hash  i32) ;; key hash
             (param $shift i32) ;; HAMT shift in multiples of 3
             (result       i32)
             (i32.and (i32.shr_u (local.get $hash)
                                  (local.get $shift))
                      (i32.const 7)))))

   ;; immutable-hamt-packed-child-bit : i32 i32 -> i32
   ;;   Prototype Racket CS-style child-region bit: static field + group.
   (core-runtime-helper
    '$immutable-hamt-packed-child-bit
    "$immutable-hamt-packed-child-bit"
    (lambda ()
      `(func $immutable-hamt-packed-child-bit
             (param $hash  i32) ;; key hash
             (param $shift i32) ;; HAMT shift in multiples of 3
             (result       i32)
             (i32.shl (i32.const 1)
                      (i32.add (i32.const 1)
                               (call $immutable-hamt-packed-group-index
                                     (local.get $hash)
                                     (local.get $shift)))))))

   ;; immutable-hamt-packed-key-bit : i32 i32 -> i32
   ;;   Prototype Racket CS-style key-region bit.
   (core-runtime-helper
    '$immutable-hamt-packed-key-bit
    "$immutable-hamt-packed-key-bit"
    (lambda ()
      `(func $immutable-hamt-packed-key-bit
             (param $hash  i32) ;; key hash
             (param $shift i32) ;; HAMT shift in multiples of 3
             (result       i32)
             (i32.shl (i32.const 1)
                      (i32.add (i32.const 9)
                               (call $immutable-hamt-packed-group-index
                                     (local.get $hash)
                                     (local.get $shift)))))))

   ;; immutable-hamt-packed-value-bit : i32 i32 -> i32
   ;;   Prototype Racket CS-style value-region bit.
   (core-runtime-helper
    '$immutable-hamt-packed-value-bit
    "$immutable-hamt-packed-value-bit"
    (lambda ()
      `(func $immutable-hamt-packed-value-bit
             (param $hash  i32) ;; key hash
             (param $shift i32) ;; HAMT shift in multiples of 3
             (result       i32)
             (i32.shl (i32.const 1)
                      (i32.add (i32.const 17)
                               (call $immutable-hamt-packed-group-index
                                     (local.get $hash)
                                     (local.get $shift)))))))

   ;; immutable-hamt-packed-bits : exact-integer? exact-integer? -> list?
   ;;   Internal probe: (group child-bit key-bit value-bit current-bit).
   (core-runtime-helper
    '$immutable-hamt-packed-bits
    "$immutable-hamt-packed-bits"
    (lambda ()
      `(func $immutable-hamt-packed-bits (type $Prim2)
             (param $hash/raw  (ref eq)) ;; fixnum hash sample
             (param $shift/raw (ref eq)) ;; fixnum HAMT shift
             (result           (ref eq))
             (local $hash  i32)
             (local $shift i32)
             (local.set $hash
                        (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                        (local.get $hash/raw)))
                                   (i32.const 1)))
             (local.set $shift
                        (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                        (local.get $shift/raw)))
                                   (i32.const 1)))
            (call $cons
                  (ref.i31
                   (i32.shl
                     (call $immutable-hamt-packed-group-index
                           (local.get $hash)
                           (local.get $shift))
                     (i32.const 1)))
                   (call $cons
                         (ref.i31
                          (i32.shl
                           (call $immutable-hamt-packed-child-bit
                                 (local.get $hash)
                                 (local.get $shift))
                           (i32.const 1)))
                         (call $cons
                               (ref.i31
                                (i32.shl
                                 (call $immutable-hamt-packed-key-bit
                                       (local.get $hash)
                                       (local.get $shift))
                                 (i32.const 1)))
                               (call $cons
                                     (ref.i31
                                      (i32.shl
                                       (call $immutable-hamt-packed-value-bit
                                             (local.get $hash)
                                             (local.get $shift))
                                       (i32.const 1)))
                                     (call $cons
                                           (ref.i31
                                            (i32.shl
                                             (call $immutable-hamt-bit
                                                   (local.get $hash)
                                                   (local.get $shift))
                                             (i32.const 1)))
                                           (global.get $null)))))))))))

;; immutable-hash-hamt-metadata-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate HAMT metadata, slot, and wrapped-key helpers.
(define immutable-hash-hamt-metadata-runtime-only-helpers
  (list
   ;; immutable-hamt-slot-kind : any/c -> exact-integer?
   ;;   Classify a WebRacket HAMT slot: 1=bnode, 2=cnode, 3=inline entry, 4=bucket.
   (core-runtime-helper
    '$immutable-hamt-slot-kind
    "$immutable-hamt-slot-kind"
    (lambda ()
      `(func $immutable-hamt-slot-kind
             (param $slot (ref eq))
             (result      i32)
             (if (ref.test (ref $StencilVector) (local.get $slot))
                 (then (return (i32.const 1))))
             (if (ref.test (ref $ImmutableHashCNode) (local.get $slot))
                 (then (return (i32.const 2))))
             (if (ref.test (ref $ImmutableHashEntry) (local.get $slot))
                 (then (return (i32.const 3))))
             (if (ref.test (ref $Pair) (local.get $slot))
                 (then (return (i32.const 4))))
             (i32.const 0))))

   ;; immutable-hamt-bnode-packed-metadata : stencil-vector? -> i32
   ;;   Derive a Racket CS-style packed child/key/value mask for a current bnode.
   (core-runtime-helper
    '$immutable-hamt-bnode-packed-metadata
    "$immutable-hamt-bnode-packed-metadata"
    (lambda ()
      `(func $immutable-hamt-bnode-packed-metadata
             (param $sv (ref $StencilVector))
             (result    i32)
             (local $mask     i32)
             (local $group    i32)
             (local $bit      i32)
             (local $index    i32)
             (local $slot     (ref eq))
             (local $kind     i32)
             (local $metadata i32)
             (local.set $mask     (struct.get $StencilVector $mask (local.get $sv)))
             (local.set $group    (i32.const 0))
             (local.set $metadata (i32.const 1))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $group) (i32.const 8)))
                          (local.set $bit (i32.shl (i32.const 1) (local.get $group)))
                          (if (i32.ne (i32.and (local.get $mask) (local.get $bit))
                                      (i32.const 0))
                              (then
                               (local.set $index
                                          (call $immutable-hasheqv-bucket-index
                                                (local.get $mask)
                                                (local.get $bit)))
                               (local.set $slot
                                          (array.get $Array
                                                     (struct.get $StencilVector $slots
                                                                 (local.get $sv))
                                                     (local.get $index)))
                               (local.set $kind
                                          (call $immutable-hamt-slot-kind
                                                (local.get $slot)))
                               (if (i32.or
                                    (i32.eq (local.get $kind) (i32.const 1))
                                    (i32.eq (local.get $kind) (i32.const 2)))
                                   (then
                                    (local.set $metadata
                                               (i32.or
                                                (local.get $metadata)
                                                (call $immutable-hamt-packed-child-bit
                                                      (local.get $group)
                                                      (i32.const 0)))))
                                   (else
                                    (local.set $metadata
                                               (i32.or
                                                (local.get $metadata)
                                                (i32.or
                                                 (call $immutable-hamt-packed-key-bit
                                                       (local.get $group)
                                                       (i32.const 0))
                                                 (call $immutable-hamt-packed-value-bit
                                                       (local.get $group)
                                                       (i32.const 0)))))))))
                          (local.set $group
                                     (i32.add (local.get $group) (i32.const 1)))
                          (br $loop)))
             (local.get $metadata))))

   ;; immutable-hamt-store-bnode-metadata : stencil-vector? -> stencil-vector?
   ;;   Store the packed metadata word in the private HAMT bnode cache field.
   (core-runtime-helper
    '$immutable-hamt-store-bnode-metadata
    "$immutable-hamt-store-bnode-metadata"
    (lambda ()
      `(func $immutable-hamt-store-bnode-metadata
             (param $sv (ref $StencilVector))
             (result    (ref $StencilVector))
             (struct.set $StencilVector $hash
                         (local.get $sv)
                         (call $immutable-hamt-bnode-packed-metadata
                               (local.get $sv)))
             (local.get $sv))))

   ;; immutable-hamt-bnode-metadata : stencil-vector? -> i32
   ;;   Read stored packed metadata. HAMT constructors/updates must cache it.
   (core-runtime-helper
    '$immutable-hamt-bnode-metadata
    "$immutable-hamt-bnode-metadata"
    (lambda ()
      `(func $immutable-hamt-bnode-metadata
             (param $sv (ref $StencilVector))
             (result    i32)
             (struct.get $StencilVector $hash (local.get $sv)))))

   ;; immutable-hamt-packed-bnode? : stencil-vector? -> boolean?
   ;;   Recognize the future physical packed HAMT bnode marker.
   (core-runtime-helper
    '$immutable-hamt-packed-bnode?
    "$immutable-hamt-packed-bnode?"
    (lambda ()
      `(func $immutable-hamt-packed-bnode?
             (param $sv (ref $StencilVector))
             (result    i32)
             (i32.eq (struct.get $StencilVector $system? (local.get $sv))
                     (i32.const 2)))))

   ;; immutable-hamt-packed-index : packed-metadata bit -> exact-nonnegative-integer?
   ;;   Dense slot index for a physical packed bnode bit; slot 0 is the static marker.
   (core-runtime-helper
    '$immutable-hamt-packed-index
    "$immutable-hamt-packed-index"
    (lambda ()
      `(func $immutable-hamt-packed-index
             (param $metadata i32)
             (param $bit      i32)
             (result          i32)
             (i32.popcnt
              (i32.and (local.get $metadata)
                       (i32.sub (local.get $bit) (i32.const 1)))))))

   ;; immutable-hamt-packed-slot : stencil-vector? bit -> any/c
   ;;   Fetch the physical packed bnode slot for bit.
   (core-runtime-helper
    '$immutable-hamt-packed-slot
    "$immutable-hamt-packed-slot"
    (lambda ()
      `(func $immutable-hamt-packed-slot
             (param $sv  (ref $StencilVector))
             (param $bit i32)
             (result     (ref eq))
             (array.get $Array
                        (struct.get $StencilVector $slots (local.get $sv))
                        (call $immutable-hamt-packed-index
                              (call $immutable-hamt-bnode-metadata (local.get $sv))
                              (local.get $bit))))))

   ;; immutable-hamt-packed-child-slot : stencil-vector? i32 i32 -> any/c
   ;;   Fetch a physical child-region slot for hash/shift.
   (core-runtime-helper
    '$immutable-hamt-packed-child-slot
    "$immutable-hamt-packed-child-slot"
    (lambda ()
      `(func $immutable-hamt-packed-child-slot
             (param $sv    (ref $StencilVector))
             (param $hash  i32)
             (param $shift i32)
             (result       (ref eq))
             (call $immutable-hamt-packed-slot
                   (local.get $sv)
                   (call $immutable-hamt-packed-child-bit
                         (local.get $hash)
                         (local.get $shift))))))

   ;; immutable-hamt-packed-key-slot : stencil-vector? i32 i32 -> any/c
   ;;   Fetch a physical inline-key slot for hash/shift.
   (core-runtime-helper
    '$immutable-hamt-packed-key-slot
    "$immutable-hamt-packed-key-slot"
    (lambda ()
      `(func $immutable-hamt-packed-key-slot
             (param $sv    (ref $StencilVector))
             (param $hash  i32)
             (param $shift i32)
             (result       (ref eq))
             (call $immutable-hamt-packed-slot
                   (local.get $sv)
                   (call $immutable-hamt-packed-key-bit
                         (local.get $hash)
                         (local.get $shift))))))

   ;; immutable-hamt-packed-value-slot : stencil-vector? i32 i32 -> any/c
   ;;   Fetch a physical inline-value slot for hash/shift.
   (core-runtime-helper
    '$immutable-hamt-packed-value-slot
    "$immutable-hamt-packed-value-slot"
    (lambda ()
      `(func $immutable-hamt-packed-value-slot
             (param $sv    (ref $StencilVector))
             (param $hash  i32)
             (param $shift i32)
             (result       (ref eq))
             (call $immutable-hamt-packed-slot
                   (local.get $sv)
                   (call $immutable-hamt-packed-value-bit
                         (local.get $hash)
                         (local.get $shift))))))

   ;; immutable-hamt-empty-packed-node : -> stencil-vector?
   ;;   Construct an empty physical packed bnode scaffold for the HAMT migration.
   (core-runtime-helper
    '$immutable-hamt-empty-packed-node
    "$immutable-hamt-empty-packed-node"
    (lambda ()
      `(func $immutable-hamt-empty-packed-node
             (result (ref $StencilVector))
             (local $sv (ref $StencilVector))
             (local.set $sv
                        (call $$make-stencil-vector/checked
                              (i32.const 2)
                              (i32.const 1)
                              (array.new_fixed $Array 1 (global.get $missing))))
             (struct.set $StencilVector $hash (local.get $sv) (i32.const 1))
             (local.get $sv))))

   ;; immutable-hamt-store-packed-bnode-metadata : stencil-vector? -> stencil-vector?
   ;;   Cache the physical packed bnode mask as metadata.
   (core-runtime-helper
    '$immutable-hamt-store-packed-bnode-metadata
    "$immutable-hamt-store-packed-bnode-metadata"
    (lambda ()
      `(func $immutable-hamt-store-packed-bnode-metadata
             (param $sv (ref $StencilVector))
             (result    (ref $StencilVector))
             (struct.set $StencilVector $hash
                         (local.get $sv)
                         (struct.get $StencilVector $mask (local.get $sv)))
             (local.get $sv))))

   ;; immutable-hamt-key-hash/kind : kind key -> i32
   ;;   Compute the key hash for the immutable hash table's key mode.
   (core-runtime-helper
    '$immutable-hamt-key-hash/kind
    "$immutable-hamt-key-hash/kind"
    (lambda ()
      `(func $immutable-hamt-key-hash/kind
             (param $kind i32)
             (param $key  (ref eq))
             (result      i32)
             (if (ref.test (ref $ImmutableHashWrappedKey) (local.get $key))
                 (then
                  (return
                   (struct.get $ImmutableHashWrappedKey $key-hash
                               (ref.cast (ref $ImmutableHashWrappedKey)
                                         (local.get $key))))))
             (if (i32.eq (local.get $kind) (i32.const 0))
                 (then (return_call $eq-hash/i32 (local.get $key))))
             (if (i32.eq (local.get $kind) (i32.const 1))
                 (then (return_call $eqv-hash/i32 (local.get $key))))
             (if (i32.eq (local.get $kind) (i32.const 2))
                 (then (return_call $equal-hash/i32 (local.get $key))))
             (return_call $equal-always-hash/i32 (local.get $key)))))

   ;; immutable-hamt-wrap-inline-key/kind : kind key hash -> key-or-wrapper
   ;;   Cache equal?/equal-always? hashes in packed inline key slots.
   (core-runtime-helper
    '$immutable-hamt-wrap-inline-key/kind
    "$immutable-hamt-wrap-inline-key/kind"
    (lambda ()
      `(func $immutable-hamt-wrap-inline-key/kind
             (param $kind i32)
             (param $key  (ref eq))
             (param $hash i32)
             (result      (ref eq))
             (if (i32.lt_u (local.get $kind) (i32.const 2))
                 (then (return (local.get $key))))
             (struct.new $ImmutableHashWrappedKey
                         (i32.const 0)
                         (local.get $kind)
                         (local.get $hash)
                         (local.get $key)))))

   ;; immutable-hamt-inline-key-unwrap : key-or-wrapper -> key
   ;;   Recover the public key from a private packed inline wrapper.
   (core-runtime-helper
    '$immutable-hamt-inline-key-unwrap
    "$immutable-hamt-inline-key-unwrap"
    (lambda ()
      `(func $immutable-hamt-inline-key-unwrap
             (param $key (ref eq))
             (result     (ref eq))
             (if (ref.test (ref $ImmutableHashWrappedKey) (local.get $key))
                 (then
                  (return
                   (struct.get $ImmutableHashWrappedKey $key
                               (ref.cast (ref $ImmutableHashWrappedKey)
                                         (local.get $key))))))
             (local.get $key))))

   ;; immutable-hamt-inline-key-cached-hash : key-or-wrapper -> i32
   ;;   Return a packed inline wrapper's cached hash, or 0 for raw keys.
   (core-runtime-helper
    '$immutable-hamt-inline-key-cached-hash
    "$immutable-hamt-inline-key-cached-hash"
    (lambda ()
      `(func $immutable-hamt-inline-key-cached-hash
             (param $key (ref eq))
             (result     i32)
             (if (ref.test (ref $ImmutableHashWrappedKey) (local.get $key))
                 (then
                  (return
                   (struct.get $ImmutableHashWrappedKey $key-hash
                               (ref.cast (ref $ImmutableHashWrappedKey)
                                         (local.get $key))))))
             (i32.const 0))))

   ;; immutable-hamt-entry-for-key/kind : kind key value -> immutable-hash-entry?
   ;;   Build an entry when a physical key/value inline slot is promoted.
   (core-runtime-helper
    '$immutable-hamt-entry-for-key/kind
    "$immutable-hamt-entry-for-key/kind"
    (lambda ()
      `(func $immutable-hamt-entry-for-key/kind
             (param $kind  i32)
             (param $key   (ref eq))
             (param $value (ref eq))
             (result       (ref $ImmutableHashEntry))
             (struct.new $ImmutableHashEntry
                         (i32.const 0)
                         (call $immutable-hamt-key-hash/kind
                               (local.get $kind)
                               (local.get $key))
                         (call $immutable-hamt-inline-key-unwrap
                               (local.get $key))
                         (local.get $value)))))

   ;; immutable-hamt-packed-metadata-present?/i32 : i32 i32 i32 -> i32
   ;;   Check a packed child/key region for the active lookup group.
   (core-runtime-helper
    '$immutable-hamt-packed-metadata-present?/i32
    "$immutable-hamt-packed-metadata-present?/i32"
    (lambda ()
      `(func $immutable-hamt-packed-metadata-present?/i32
             (param $metadata i32)
             (param $hash     i32)
             (param $shift    i32)
             (result          i32)
             (i32.or
              (i32.and (local.get $metadata)
                       (call $immutable-hamt-packed-child-bit
                             (local.get $hash)
                             (local.get $shift)))
              (i32.and (local.get $metadata)
                       (call $immutable-hamt-packed-key-bit
                             (local.get $hash)
                             (local.get $shift)))))))))

;; immutable-hash-eq-bucket-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate eq?/eqv? immutable hash bucket helpers and shared kind dispatch.
(define immutable-hash-eq-bucket-runtime-only-helpers
  (list
   (core-runtime-helper
    '$immutable-hasheqv-bucket-has-key?
    "$immutable-hasheqv-bucket-has-key?"
    (lambda ()
      `(func $immutable-hasheqv-bucket-has-key?
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (result i32)
             (local $node  (ref eq))
             (local $pair  (ref $Pair))
             (local $entry (ref $ImmutableHashEntry))
             (local.set $node (local.get $bucket))
             (block $done
                    (loop $scan
                          (br_if $done (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (return (i32.const 0))))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $eqv?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (i32.const 1))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (i32.const 0))))

   (core-runtime-helper
    '$immutable-hasheqv-bucket-ref
    "$immutable-hasheqv-bucket-ref"
    (lambda ()
      `(func $immutable-hasheqv-bucket-ref
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $eqv?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (struct.get $ImmutableHashEntry $value
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))

   (core-runtime-helper
    '$immutable-hasheqv-bucket-ref-key
    "$immutable-hasheqv-bucket-ref-key"
    (lambda ()
      `(func $immutable-hasheqv-bucket-ref-key
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $eqv?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (struct.get $ImmutableHashEntry $key
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))

   (core-runtime-helper
    '$immutable-hasheq-bucket-has-key?
    "$immutable-hasheq-bucket-has-key?"
    (lambda ()
      `(func $immutable-hasheq-bucket-has-key?
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (result i32)
             (local $node  (ref eq))
             (local $pair  (ref $Pair))
             (local $entry (ref $ImmutableHashEntry))
             (local.set $node (local.get $bucket))
             (block $done
                    (loop $scan
                          (br_if $done (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (return (i32.const 0))))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (struct.get $ImmutableHashEntry $key (local.get $entry))
                                      (local.get $key))
                              (then (return (i32.const 1))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (i32.const 0))))

   (core-runtime-helper
    '$immutable-hasheq-bucket-ref
    "$immutable-hasheq-bucket-ref"
    (lambda ()
      `(func $immutable-hasheq-bucket-ref
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (struct.get $ImmutableHashEntry $key (local.get $entry))
                                      (local.get $key))
                              (then (return (struct.get $ImmutableHashEntry $value
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))

   (core-runtime-helper
    '$immutable-hasheq-bucket-ref-key
    "$immutable-hasheq-bucket-ref-key"
    (lambda ()
      `(func $immutable-hasheq-bucket-ref-key
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (struct.get $ImmutableHashEntry $key (local.get $entry))
                                      (local.get $key))
                              (then (return (struct.get $ImmutableHashEntry $key
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))

   (core-runtime-helper
    '$immutable-hamt-bit
    "$immutable-hamt-bit"
    (lambda ()
      `(func $immutable-hamt-bit
             (param $hash  i32) ;; key hash
             (param $shift i32) ;; HAMT shift in multiples of 3
             (result       i32)
             (i32.shl (i32.const 1)
                      (call $immutable-hamt-packed-group-index
                            (local.get $hash)
                            (local.get $shift))))))

   (core-runtime-helper
    '$immutable-hamt-bucket-ref/kind
    "$immutable-hamt-bucket-ref/kind"
    (lambda ()
      `(func $immutable-hamt-bucket-ref/kind
             (param $kind   i32)      ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (if (ref.test (ref $ImmutableHashEntry) (local.get $bucket))
                 (then
                  (if (call $immutable-hamt-entry-matches?/kind
                            (local.get $kind)
                            (ref.cast (ref $ImmutableHashEntry)
                                      (local.get $bucket))
                            (local.get $key))
                      (then
                       (return
                        (struct.get $ImmutableHashEntry $value
                                    (ref.cast (ref $ImmutableHashEntry)
                                              (local.get $bucket))))))))
             (if (i32.eq (local.get $kind) (i32.const 0))
                 (then (return_call $immutable-hasheq-bucket-ref
                                    (local.get $bucket)
                                    (local.get $key)
                                    (local.get $fail))))
             (if (i32.eq (local.get $kind) (i32.const 1))
                 (then (return_call $immutable-hasheqv-bucket-ref
                                    (local.get $bucket)
                                    (local.get $key)
                                    (local.get $fail))))
             (if (i32.eq (local.get $kind) (i32.const 2))
                 (then (return_call $immutable-hash-bucket-ref
                                    (local.get $bucket)
                                    (local.get $key)
                                    (local.get $fail))))
             (return_call $immutable-hashalw-bucket-ref
                          (local.get $bucket)
                          (local.get $key)
                          (local.get $fail)))))

   (core-runtime-helper
    '$immutable-hamt-bucket-ref-key/kind
    "$immutable-hamt-bucket-ref-key/kind"
    (lambda ()
      `(func $immutable-hamt-bucket-ref-key/kind
             (param $kind   i32)      ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (if (ref.test (ref $ImmutableHashEntry) (local.get $bucket))
                 (then
                  (if (call $immutable-hamt-entry-matches?/kind
                            (local.get $kind)
                            (ref.cast (ref $ImmutableHashEntry)
                                      (local.get $bucket))
                            (local.get $key))
                      (then
                       (return
                        (struct.get $ImmutableHashEntry $key
                                    (ref.cast (ref $ImmutableHashEntry)
                                              (local.get $bucket))))))))
             (if (i32.eq (local.get $kind) (i32.const 0))
                 (then (return_call $immutable-hasheq-bucket-ref-key
                                    (local.get $bucket)
                                    (local.get $key)
                                    (local.get $fail))))
             (if (i32.eq (local.get $kind) (i32.const 1))
                 (then (return_call $immutable-hasheqv-bucket-ref-key
                                    (local.get $bucket)
                                    (local.get $key)
                                    (local.get $fail))))
             (if (i32.eq (local.get $kind) (i32.const 2))
                 (then (return_call $immutable-hash-bucket-ref-key
                                    (local.get $bucket)
                                    (local.get $key)
                                    (local.get $fail))))
             (return_call $immutable-hashalw-bucket-ref-key
                          (local.get $bucket)
                          (local.get $key)
                          (local.get $fail)))))

   (core-runtime-helper
    '$immutable-hamt-bucket-has-key?/kind
    "$immutable-hamt-bucket-has-key?/kind"
    (lambda ()
      `(func $immutable-hamt-bucket-has-key?/kind
             (param $kind   i32)      ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (result        i32)
             (if (ref.test (ref $ImmutableHashEntry) (local.get $bucket))
                 (then
                  (return_call $immutable-hamt-entry-matches?/kind
                               (local.get $kind)
                               (ref.cast (ref $ImmutableHashEntry)
                                         (local.get $bucket))
                               (local.get $key))))
             (if (i32.eq (local.get $kind) (i32.const 0))
                 (then (return_call $immutable-hasheq-bucket-has-key?
                                    (local.get $bucket)
                                    (local.get $key))))
             (if (i32.eq (local.get $kind) (i32.const 1))
                 (then (return_call $immutable-hasheqv-bucket-has-key?
                                    (local.get $bucket)
                                    (local.get $key))))
             (if (i32.eq (local.get $kind) (i32.const 2))
                 (then (return_call $immutable-hash-bucket-has-key?
                                    (local.get $bucket)
                                    (local.get $key))))
             (return_call $immutable-hashalw-bucket-has-key?
                          (local.get $bucket)
                          (local.get $key)))))

   ;; immutable-hamt-key-matches?/kind : kind stored-key lookup-key -> boolean?
   ;;   Compare keys using the immutable hash table's key mode.
   (core-runtime-helper
    '$immutable-hamt-key-matches?/kind
    "$immutable-hamt-key-matches?/kind"
    (lambda ()
      `(func $immutable-hamt-key-matches?/kind
             (param $kind       i32)
             (param $stored-key (ref eq))
             (param $lookup-key (ref eq))
             (result            i32)
             (if (i32.eq (local.get $kind) (i32.const 0))
                 (then (return (ref.eq (call $immutable-hamt-inline-key-unwrap
                                             (local.get $stored-key))
                                       (local.get $lookup-key)))))
             (if (i32.eq (local.get $kind) (i32.const 1))
                 (then
                  (return (ref.eq (call $eqv?
                                        (call $immutable-hamt-inline-key-unwrap
                                              (local.get $stored-key))
                                        (local.get $lookup-key))
                                  (global.get $true)))))
             (if (i32.eq (local.get $kind) (i32.const 2))
                 (then
                  (return (ref.eq (call $equal?
                                        (call $immutable-hamt-inline-key-unwrap
                                              (local.get $stored-key))
                                        (local.get $lookup-key))
                                  (global.get $true)))))
             (return (ref.eq (call $equal-always?
                                   (call $immutable-hamt-inline-key-unwrap
                                         (local.get $stored-key))
                                   (local.get $lookup-key))
                             (global.get $true))))))))

;; immutable-hash-packed-node-read-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate physical packed-node lookup helpers.
(define immutable-hash-packed-node-read-runtime-only-helpers
  (list
   ;; immutable-hamt-packed-node-ref/kind : kind bnode key hash shift fail -> any/c
   ;;   Lookup through a physical packed bnode.
   (core-runtime-helper
    '$immutable-hamt-packed-node-ref/kind
    "$immutable-hamt-packed-node-ref/kind"
    (lambda ()
      `(func $immutable-hamt-packed-node-ref/kind
             (param $kind  i32)
             (param $sv    (ref $StencilVector))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $shift i32)
             (param $fail  (ref eq))
             (result       (ref eq))
             (local $metadata  i32)
             (local $child-bit i32)
             (local $key-bit   i32)
             (local $slot      (ref eq))
             (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
             (local.set $child-bit
                        (call $immutable-hamt-packed-child-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                         (i32.const 0))
                 (then
                  (return_call $immutable-hamt-node-ref/kind
                               (local.get $kind)
                               (call $immutable-hamt-packed-child-slot
                                     (local.get $sv)
                                     (local.get $hash)
                                     (local.get $shift))
                               (local.get $key)
                               (local.get $hash)
                               (i32.add (local.get $shift) (i32.const 3))
                               (local.get $fail))))
             (local.set $key-bit
                        (call $immutable-hamt-packed-key-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.eqz (i32.and (local.get $metadata) (local.get $key-bit)))
                 (then (return_call $immutable-hamt-bucket-ref/kind
                                    (local.get $kind)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $fail))))
             (local.set $slot
                        (call $immutable-hamt-packed-key-slot
                              (local.get $sv)
                              (local.get $hash)
                              (local.get $shift)))
             (if (call $immutable-hamt-key-matches?/kind
                       (local.get $kind)
                       (local.get $slot)
                       (local.get $key))
                 (then
                  (return_call $immutable-hamt-packed-value-slot
                               (local.get $sv)
                               (local.get $hash)
                               (local.get $shift))))
             (return_call $immutable-hamt-bucket-ref/kind
                          (local.get $kind)
                          (global.get $null)
                          (local.get $key)
                          (local.get $fail)))))

   ;; immutable-hamt-packed-node-ref-key/kind : kind bnode key hash shift fail -> any/c
   ;;   Find the stored key through a physical packed bnode.
   (core-runtime-helper
    '$immutable-hamt-packed-node-ref-key/kind
    "$immutable-hamt-packed-node-ref-key/kind"
    (lambda ()
      `(func $immutable-hamt-packed-node-ref-key/kind
             (param $kind  i32)
             (param $sv    (ref $StencilVector))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $shift i32)
             (param $fail  (ref eq))
             (result       (ref eq))
             (local $metadata  i32)
             (local $child-bit i32)
             (local $key-bit   i32)
             (local $slot      (ref eq))
             (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
             (local.set $child-bit
                        (call $immutable-hamt-packed-child-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                         (i32.const 0))
                 (then
                  (return_call $immutable-hamt-node-ref-key/kind
                               (local.get $kind)
                               (call $immutable-hamt-packed-child-slot
                                     (local.get $sv)
                                     (local.get $hash)
                                     (local.get $shift))
                               (local.get $key)
                               (local.get $hash)
                               (i32.add (local.get $shift) (i32.const 3))
                               (local.get $fail))))
             (local.set $key-bit
                        (call $immutable-hamt-packed-key-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.eqz (i32.and (local.get $metadata) (local.get $key-bit)))
                 (then (return_call $immutable-hamt-bucket-ref-key/kind
                                    (local.get $kind)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $fail))))
             (local.set $slot
                        (call $immutable-hamt-packed-key-slot
                              (local.get $sv)
                              (local.get $hash)
                              (local.get $shift)))
             (if (call $immutable-hamt-key-matches?/kind
                       (local.get $kind)
                       (local.get $slot)
                       (local.get $key))
                 (then
                  (return_call $immutable-hamt-inline-key-unwrap
                               (local.get $slot))))
             (return_call $immutable-hamt-bucket-ref-key/kind
                          (local.get $kind)
                          (global.get $null)
                          (local.get $key)
                          (local.get $fail)))))

   ;; immutable-hamt-packed-node-has-key?/kind : kind bnode key hash shift -> boolean?
   ;;   Check a physical packed bnode for a key.
   (core-runtime-helper
    '$immutable-hamt-packed-node-has-key?/kind
    "$immutable-hamt-packed-node-has-key?/kind"
    (lambda ()
      `(func $immutable-hamt-packed-node-has-key?/kind
             (param $kind  i32)
             (param $sv    (ref $StencilVector))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $shift i32)
             (result       i32)
             (local $metadata  i32)
             (local $child-bit i32)
             (local $key-bit   i32)
             (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
             (local.set $child-bit
                        (call $immutable-hamt-packed-child-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                         (i32.const 0))
                 (then
                  (return_call $immutable-hamt-node-has-key?/kind
                               (local.get $kind)
                               (call $immutable-hamt-packed-child-slot
                                     (local.get $sv)
                                     (local.get $hash)
                                     (local.get $shift))
                               (local.get $key)
                               (local.get $hash)
                               (i32.add (local.get $shift) (i32.const 3)))))
             (local.set $key-bit
                        (call $immutable-hamt-packed-key-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.eqz (i32.and (local.get $metadata) (local.get $key-bit)))
                 (then (return (i32.const 0))))
             (return_call $immutable-hamt-key-matches?/kind
                          (local.get $kind)
                          (call $immutable-hamt-packed-key-slot
                                (local.get $sv)
                                (local.get $hash)
                                (local.get $shift))
                          (local.get $key)))))))

;; immutable-hash-packed-node-set-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate physical packed-node functional update helpers.
(define immutable-hash-packed-node-set-runtime-only-helpers
  (list
   ;; immutable-hamt-packed-node-set/kind : kind bnode entry key hash shift -> bnode
   ;;   Functional update for a physical packed bnode.
   (core-runtime-helper
    '$immutable-hamt-packed-node-set/kind
    "$immutable-hamt-packed-node-set/kind"
    (lambda ()
      `(func $immutable-hamt-packed-node-set/kind
             (param $kind  i32)
             (param $sv    (ref $StencilVector))
             (param $entry (ref $ImmutableHashEntry))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $shift i32)
             (result       (ref eq))
             (local $metadata     i32)
             (local $child-bit    i32)
             (local $key-bit      i32)
             (local $value-bit    i32)
             (local $stored-key   (ref eq))
             (local $stored-value (ref eq))
             (local $old-entry    (ref $ImmutableHashEntry))
             (local $child        (ref eq))
             (local.set $stored-key (global.get $null))
             (local.set $stored-value (global.get $null))
             (local.set $old-entry (local.get $entry))
             (local.set $child (global.get $null))
             (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
             (local.set $child-bit
                        (call $immutable-hamt-packed-child-bit
                              (local.get $hash)
                              (local.get $shift)))
             (local.set $key-bit
                        (call $immutable-hamt-packed-key-bit
                              (local.get $hash)
                              (local.get $shift)))
             (local.set $value-bit
                        (call $immutable-hamt-packed-value-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                         (i32.const 0))
                 (then
                  (local.set $child
                             (call $immutable-hamt-node-set/kind
                                   (local.get $kind)
                                   (call $immutable-hamt-packed-child-slot
                                         (local.get $sv)
                                         (local.get $hash)
                                         (local.get $shift))
                                   (local.get $entry)
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.add (local.get $shift) (i32.const 3))))
                  (return_call $immutable-hamt-store-packed-bnode-metadata
                               (ref.cast
                                (ref $StencilVector)
                                (call $$stencil-vector-update/core
                                      (local.get $sv)
                                      (local.get $child-bit)
                                      (local.get $child-bit)
                                      (call $cons (local.get $child) (global.get $null))
                                      (i32.const 2))))))
             (if (i32.ne (i32.and (local.get $metadata) (local.get $key-bit))
                         (i32.const 0))
                 (then
                  (local.set $stored-key
                             (call $immutable-hamt-packed-key-slot
                                   (local.get $sv)
                                   (local.get $hash)
                                   (local.get $shift)))
                  (local.set $stored-value
                             (call $immutable-hamt-packed-value-slot
                                   (local.get $sv)
                                   (local.get $hash)
                                   (local.get $shift)))
                  (if (call $immutable-hamt-key-matches?/kind
                            (local.get $kind)
                            (local.get $stored-key)
                            (local.get $key))
                      (then
                       (return_call $immutable-hamt-store-packed-bnode-metadata
                                    (ref.cast
                                     (ref $StencilVector)
                                     (call $$stencil-vector-update/core
                                           (local.get $sv)
                                           (i32.or (local.get $key-bit) (local.get $value-bit))
                                           (i32.or (local.get $key-bit) (local.get $value-bit))
                                           (call $cons
                                                 (call $immutable-hamt-wrap-inline-key/kind
                                                       (local.get $kind)
                                                       (struct.get $ImmutableHashEntry $key
                                                                   (local.get $entry))
                                                       (struct.get $ImmutableHashEntry $key-hash
                                                                   (local.get $entry)))
                                                 (call $cons
                                                       (struct.get $ImmutableHashEntry $value (local.get $entry))
                                                       (global.get $null)))
                                           (i32.const 2))))))
                  (local.set $old-entry
                             (call $immutable-hamt-entry-for-key/kind
                                   (local.get $kind)
                                   (local.get $stored-key)
                                   (local.get $stored-value)))
                  (if (i32.lt_u (local.get $shift) (i32.const 30))
                      (then
                       (local.set $child (call $immutable-hamt-empty-packed-node))
                       (local.set $child
                                  (call $immutable-hamt-packed-node-set/kind
                                        (local.get $kind)
                                        (ref.cast (ref $StencilVector) (local.get $child))
                                        (local.get $old-entry)
                                        (struct.get $ImmutableHashEntry $key (local.get $old-entry))
                                        (struct.get $ImmutableHashEntry $key-hash (local.get $old-entry))
                                        (i32.add (local.get $shift) (i32.const 3))))
                       (local.set $child
                                  (call $immutable-hamt-node-set/kind
                                        (local.get $kind)
                                        (local.get $child)
                                        (local.get $entry)
                                        (local.get $key)
                                        (local.get $hash)
                                        (i32.add (local.get $shift) (i32.const 3)))))
                      (else
                       (local.set $child
                                  (call $immutable-hamt-bucket->cnode
                                        (call $cons
                                              (local.get $old-entry)
                                              (global.get $null))
                                        (local.get $entry)))))
                  (return_call $immutable-hamt-store-packed-bnode-metadata
                               (ref.cast
                                (ref $StencilVector)
                                (call $$stencil-vector-update/core
                                      (local.get $sv)
                                      (i32.or (local.get $key-bit) (local.get $value-bit))
                                      (local.get $child-bit)
                                      (call $cons (local.get $child) (global.get $null))
                                      (i32.const 2))))))
             (return_call $immutable-hamt-store-packed-bnode-metadata
                          (ref.cast
                           (ref $StencilVector)
                           (call $$stencil-vector-update/core
                                 (local.get $sv)
                                 (i32.const 0)
                                 (i32.or (local.get $key-bit) (local.get $value-bit))
                                 (call $cons
                                       (call $immutable-hamt-wrap-inline-key/kind
                                             (local.get $kind)
                                             (struct.get $ImmutableHashEntry $key (local.get $entry))
                                             (struct.get $ImmutableHashEntry $key-hash (local.get $entry)))
                                       (call $cons
                                             (struct.get $ImmutableHashEntry $value (local.get $entry))
                                             (global.get $null)))
                                 (i32.const 2)))))))))

;; immutable-hash-packed-node-remove-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate physical packed-node remove and collapse helpers.
(define immutable-hash-packed-node-remove-runtime-only-helpers
  (list
   ;; immutable-hamt-packed-bnode-collapse-if-single/kind : kind bnode -> any/c
   ;;   Collapse a physical bnode with one inline key/value pair to an entry.
   (core-runtime-helper
    '$immutable-hamt-packed-bnode-collapse-if-single/kind
    "$immutable-hamt-packed-bnode-collapse-if-single/kind"
    (lambda ()
      `(func $immutable-hamt-packed-bnode-collapse-if-single/kind
             (param $kind i32)
             (param $sv   (ref $StencilVector))
             (result      (ref eq))
             (local $metadata i32)
             (local $group    i32)
             (local $key-bit  i32)
             (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
             (if (i32.ne (i32.popcnt (local.get $metadata)) (i32.const 3))
                 (then (return (local.get $sv))))
             (local.set $group (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $group) (i32.const 8)))
                          (local.set $key-bit
                                     (call $immutable-hamt-packed-key-bit
                                           (local.get $group)
                                           (i32.const 0)))
                          (if (i32.ne (i32.and (local.get $metadata) (local.get $key-bit))
                                      (i32.const 0))
                              (then
                               (return_call $immutable-hamt-entry-for-key/kind
                                            (local.get $kind)
                                            (call $immutable-hamt-packed-slot
                                                  (local.get $sv)
                                                  (local.get $key-bit))
                                            (call $immutable-hamt-packed-slot
                                                  (local.get $sv)
                                                  (call $immutable-hamt-packed-value-bit
                                                        (local.get $group)
                                                        (i32.const 0))))))
                          (local.set $group (i32.add (local.get $group) (i32.const 1)))
                          (br $loop)))
             (local.get $sv))))

   ;; immutable-hamt-packed-node-remove/kind : kind bnode key hash shift -> any/c
   ;;   Functional remove for a physical packed bnode.
   (core-runtime-helper
    '$immutable-hamt-packed-node-remove/kind
    "$immutable-hamt-packed-node-remove/kind"
    (lambda ()
      `(func $immutable-hamt-packed-node-remove/kind
             (param $kind  i32)
             (param $sv    (ref $StencilVector))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $shift i32)
             (result       (ref eq))
             (local $metadata  i32)
             (local $child-bit i32)
             (local $key-bit   i32)
             (local $value-bit i32)
             (local $slot      (ref eq))
             (local $newslot   (ref eq))
             (local.set $slot (global.get $null))
             (local.set $newslot (global.get $null))
             (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
             (local.set $child-bit
                        (call $immutable-hamt-packed-child-bit
                              (local.get $hash)
                              (local.get $shift)))
             (local.set $key-bit
                        (call $immutable-hamt-packed-key-bit
                              (local.get $hash)
                              (local.get $shift)))
             (local.set $value-bit
                        (call $immutable-hamt-packed-value-bit
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                         (i32.const 0))
                 (then
                  (local.set $newslot
                             (call $immutable-hamt-node-remove/kind
                                   (local.get $kind)
                                   (call $immutable-hamt-packed-child-slot
                                         (local.get $sv)
                                         (local.get $hash)
                                         (local.get $shift))
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.add (local.get $shift) (i32.const 3))))
                  (if (ref.eq (local.get $newslot) (global.get $null))
                      (then
                       (return_call $immutable-hamt-packed-bnode-collapse-if-single/kind
                                    (local.get $kind)
                                    (call $immutable-hamt-store-packed-bnode-metadata
                                          (ref.cast
                                           (ref $StencilVector)
                                           (call $$stencil-vector-update/core
                                                 (local.get $sv)
                                                 (local.get $child-bit)
                                                 (i32.const 0)
                                                 (global.get $null)
                                                 (i32.const 2)))))))
                  (if (ref.test (ref $ImmutableHashEntry) (local.get $newslot))
                      (then
                       (return_call $immutable-hamt-packed-bnode-collapse-if-single/kind
                                    (local.get $kind)
                                    (call $immutable-hamt-store-packed-bnode-metadata
                                          (ref.cast
                                           (ref $StencilVector)
                                           (call $$stencil-vector-update/core
                                                 (local.get $sv)
                                                 (local.get $child-bit)
                                                 (i32.or (local.get $key-bit) (local.get $value-bit))
                                                 (call $cons
                                                       (call $immutable-hamt-wrap-inline-key/kind
                                                             (local.get $kind)
                                                             (struct.get $ImmutableHashEntry $key
                                                                         (ref.cast (ref $ImmutableHashEntry)
                                                                                   (local.get $newslot)))
                                                             (struct.get $ImmutableHashEntry $key-hash
                                                                         (ref.cast (ref $ImmutableHashEntry)
                                                                                   (local.get $newslot))))
                                                       (call $cons
                                                             (struct.get $ImmutableHashEntry $value
                                                                         (ref.cast (ref $ImmutableHashEntry)
                                                                                   (local.get $newslot)))
                                                             (global.get $null)))
                                                 (i32.const 2)))))))
                  (return_call $immutable-hamt-store-packed-bnode-metadata
                               (ref.cast
                                (ref $StencilVector)
                                (call $$stencil-vector-update/core
                                      (local.get $sv)
                                      (local.get $child-bit)
                                      (local.get $child-bit)
                                      (call $cons (local.get $newslot) (global.get $null))
                                      (i32.const 2))))))
             (if (i32.eqz (i32.and (local.get $metadata) (local.get $key-bit)))
                 (then (return (local.get $sv))))
             (local.set $slot
                        (call $immutable-hamt-packed-key-slot
                              (local.get $sv)
                              (local.get $hash)
                              (local.get $shift)))
             (if (i32.eqz
                  (call $immutable-hamt-key-matches?/kind
                        (local.get $kind)
                        (local.get $slot)
                        (local.get $key)))
                 (then (return (local.get $sv))))
             (return_call $immutable-hamt-packed-bnode-collapse-if-single/kind
                          (local.get $kind)
                          (call $immutable-hamt-store-packed-bnode-metadata
                                (ref.cast
                                 (ref $StencilVector)
                                 (call $$stencil-vector-update/core
                                       (local.get $sv)
                                       (i32.or (local.get $key-bit) (local.get $value-bit))
                                       (i32.const 0)
                                       (global.get $null)
                                       (i32.const 2))))))))))

;; immutable-hash-node-lookup-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic HAMT node lookup helpers.
(define immutable-hash-node-lookup-runtime-only-helpers
  (list
   (core-runtime-helper
    '$immutable-hamt-node-ref/kind
    "$immutable-hamt-node-ref/kind"
    (lambda ()
      `(func $immutable-hamt-node-ref/kind
             (param $kind  i32)      ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $node  (ref eq)) ;; HAMT node or bucket
             (param $key   (ref eq)) ;; lookup key
             (param $hash  i32)      ;; key hash
             (param $shift i32)      ;; HAMT shift in multiples of 3
             (param $fail  (ref eq)) ;; failure result/procedure/missing
             (result       (ref eq))
             (local $sv    (ref $StencilVector))
             (local $mask  i32)
             (local $metadata i32)
             (local $bit   i32)
             (local $index i32)
             (local $slot  (ref eq))
             (local $slot-kind i32)
             (if (ref.test (ref $StencilVector) (local.get $node))
                 (then
                  (local.set $sv   (ref.cast (ref $StencilVector) (local.get $node)))
                  (if (call $immutable-hamt-packed-bnode? (local.get $sv))
                      (then
                       (return_call $immutable-hamt-packed-node-ref/kind
                                    (local.get $kind)
                                    (local.get $sv)
                                    (local.get $key)
                                    (local.get $hash)
                                    (local.get $shift)
                                    (local.get $fail))))
                  (local.set $mask (struct.get $StencilVector $mask (local.get $sv)))
                  (local.set $metadata
                             (call $immutable-hamt-bnode-metadata
                                   (local.get $sv)))
                  (local.set $bit
                             (call $immutable-hamt-bit
                                   (local.get $hash)
                                   (local.get $shift)))
                  (if (i32.eqz
                       (call $immutable-hamt-packed-metadata-present?/i32
                             (local.get $metadata)
                             (local.get $hash)
                             (local.get $shift)))
                      (then (return_call $immutable-hamt-bucket-ref/kind
                                         (local.get $kind)
                                         (global.get $null)
                                         (local.get $key)
                                         (local.get $fail))))
                  (local.set $index (call $immutable-hasheqv-bucket-index
                                          (local.get $mask)
                                          (local.get $bit)))
                  (local.set $slot
                             (array.get $Array
                                        (struct.get $StencilVector $slots
                                                    (local.get $sv))
                                        (local.get $index)))
                  (local.set $slot-kind
                             (call $immutable-hamt-slot-kind (local.get $slot)))
                  (if (i32.eq (local.get $slot-kind) (i32.const 1))
                      (then (return_call $immutable-hamt-node-ref/kind
                                         (local.get $kind)
                                         (local.get $slot)
                                         (local.get $key)
                                         (local.get $hash)
                                         (i32.add (local.get $shift) (i32.const 3))
                                         (local.get $fail))))
                  (if (i32.eq (local.get $slot-kind) (i32.const 2))
                      (then (return_call $immutable-hamt-cnode-ref/kind
                                         (local.get $kind)
                                         (ref.cast (ref $ImmutableHashCNode)
                                                   (local.get $slot))
                                         (local.get $key)
                                         (local.get $hash)
                                         (local.get $fail))))
                  (return_call $immutable-hamt-bucket-ref/kind
                               (local.get $kind)
                               (local.get $slot)
                               (local.get $key)
                               (local.get $fail))))
             (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                 (then (return_call $immutable-hamt-cnode-ref/kind
                                    (local.get $kind)
                                    (ref.cast (ref $ImmutableHashCNode)
                                              (local.get $node))
                                    (local.get $key)
                                    (local.get $hash)
                                    (local.get $fail))))
             (return_call $immutable-hamt-bucket-ref/kind
                          (local.get $kind)
                          (local.get $node)
                          (local.get $key)
                          (local.get $fail)))))

   (core-runtime-helper
    '$immutable-hamt-node-ref-key/kind
    "$immutable-hamt-node-ref-key/kind"
    (lambda ()
      `(func $immutable-hamt-node-ref-key/kind
             (param $kind  i32)      ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $node  (ref eq)) ;; HAMT node or bucket
             (param $key   (ref eq)) ;; lookup key
             (param $hash  i32)      ;; key hash
             (param $shift i32)      ;; HAMT shift in multiples of 3
             (param $fail  (ref eq)) ;; failure result/procedure/missing
             (result       (ref eq))
             (local $sv    (ref $StencilVector))
             (local $mask  i32)
             (local $metadata i32)
             (local $bit   i32)
             (local $index i32)
             (local $slot  (ref eq))
             (local $slot-kind i32)
             (if (ref.test (ref $StencilVector) (local.get $node))
                 (then
                  (local.set $sv   (ref.cast (ref $StencilVector) (local.get $node)))
                  (if (call $immutable-hamt-packed-bnode? (local.get $sv))
                      (then
                       (return_call $immutable-hamt-packed-node-ref-key/kind
                                    (local.get $kind)
                                    (local.get $sv)
                                    (local.get $key)
                                    (local.get $hash)
                                    (local.get $shift)
                                    (local.get $fail))))
                  (local.set $mask (struct.get $StencilVector $mask (local.get $sv)))
                  (local.set $metadata
                             (call $immutable-hamt-bnode-metadata
                                   (local.get $sv)))
                  (local.set $bit
                             (call $immutable-hamt-bit
                                   (local.get $hash)
                                   (local.get $shift)))
                  (if (i32.eqz
                       (call $immutable-hamt-packed-metadata-present?/i32
                             (local.get $metadata)
                             (local.get $hash)
                             (local.get $shift)))
                      (then (return_call $immutable-hamt-bucket-ref-key/kind
                                         (local.get $kind)
                                         (global.get $null)
                                         (local.get $key)
                                         (local.get $fail))))
                  (local.set $index (call $immutable-hasheqv-bucket-index
                                          (local.get $mask)
                                          (local.get $bit)))
                  (local.set $slot
                             (array.get $Array
                                        (struct.get $StencilVector $slots
                                                    (local.get $sv))
                                        (local.get $index)))
                  (local.set $slot-kind
                             (call $immutable-hamt-slot-kind (local.get $slot)))
                  (if (i32.eq (local.get $slot-kind) (i32.const 1))
                      (then (return_call $immutable-hamt-node-ref-key/kind
                                         (local.get $kind)
                                         (local.get $slot)
                                         (local.get $key)
                                         (local.get $hash)
                                         (i32.add (local.get $shift) (i32.const 3))
                                         (local.get $fail))))
                  (if (i32.eq (local.get $slot-kind) (i32.const 2))
                      (then (return_call $immutable-hamt-cnode-ref-key/kind
                                         (local.get $kind)
                                         (ref.cast (ref $ImmutableHashCNode)
                                                   (local.get $slot))
                                         (local.get $key)
                                         (local.get $hash)
                                         (local.get $fail))))
                  (return_call $immutable-hamt-bucket-ref-key/kind
                               (local.get $kind)
                               (local.get $slot)
                               (local.get $key)
                               (local.get $fail))))
             (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                 (then (return_call $immutable-hamt-cnode-ref-key/kind
                                    (local.get $kind)
                                    (ref.cast (ref $ImmutableHashCNode)
                                              (local.get $node))
                                    (local.get $key)
                                    (local.get $hash)
                                    (local.get $fail))))
             (return_call $immutable-hamt-bucket-ref-key/kind
                          (local.get $kind)
                          (local.get $node)
                          (local.get $key)
                          (local.get $fail)))))

   (core-runtime-helper
    '$immutable-hamt-node-has-key?/kind
    "$immutable-hamt-node-has-key?/kind"
    (lambda ()
      `(func $immutable-hamt-node-has-key?/kind
             (param $kind  i32)      ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $node  (ref eq)) ;; HAMT node or bucket
             (param $key   (ref eq)) ;; lookup key
             (param $hash  i32)      ;; key hash
             (param $shift i32)      ;; HAMT shift in multiples of 3
             (result       i32)
             (local $sv    (ref $StencilVector))
             (local $mask  i32)
             (local $metadata i32)
             (local $bit   i32)
             (local $index i32)
             (local $slot  (ref eq))
             (local $slot-kind i32)
             (if (ref.test (ref $StencilVector) (local.get $node))
                 (then
                  (local.set $sv   (ref.cast (ref $StencilVector) (local.get $node)))
                  (if (call $immutable-hamt-packed-bnode? (local.get $sv))
                      (then
                       (return_call $immutable-hamt-packed-node-has-key?/kind
                                    (local.get $kind)
                                    (local.get $sv)
                                    (local.get $key)
                                    (local.get $hash)
                                    (local.get $shift))))
                  (local.set $mask (struct.get $StencilVector $mask (local.get $sv)))
                  (local.set $metadata
                             (call $immutable-hamt-bnode-metadata
                                   (local.get $sv)))
                  (local.set $bit
                             (call $immutable-hamt-bit
                                   (local.get $hash)
                                   (local.get $shift)))
                  (if (i32.eqz
                       (call $immutable-hamt-packed-metadata-present?/i32
                             (local.get $metadata)
                             (local.get $hash)
                             (local.get $shift)))
                      (then (return (i32.const 0))))
                  (local.set $index (call $immutable-hasheqv-bucket-index
                                          (local.get $mask)
                                          (local.get $bit)))
                  (local.set $slot
                             (array.get $Array
                                        (struct.get $StencilVector $slots
                                                    (local.get $sv))
                                        (local.get $index)))
                  (local.set $slot-kind
                             (call $immutable-hamt-slot-kind (local.get $slot)))
                  (if (i32.eq (local.get $slot-kind) (i32.const 1))
                      (then (return_call $immutable-hamt-node-has-key?/kind
                                         (local.get $kind)
                                         (local.get $slot)
                                         (local.get $key)
                                         (local.get $hash)
                                         (i32.add (local.get $shift) (i32.const 3)))))
                  (if (i32.eq (local.get $slot-kind) (i32.const 2))
                      (then (return_call $immutable-hamt-cnode-has-key?/kind
                                         (local.get $kind)
                                         (ref.cast (ref $ImmutableHashCNode)
                                                   (local.get $slot))
                                         (local.get $key)
                                         (local.get $hash))))
                  (return_call $immutable-hamt-bucket-has-key?/kind
                               (local.get $kind)
                               (local.get $slot)
                               (local.get $key))))
             (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                 (then (return_call $immutable-hamt-cnode-has-key?/kind
                                    (local.get $kind)
                                    (ref.cast (ref $ImmutableHashCNode)
                                              (local.get $node))
                                    (local.get $key)
                                    (local.get $hash))))
             (return_call $immutable-hamt-bucket-has-key?/kind
                          (local.get $kind)
                          (local.get $node)
                          (local.get $key)))))))

;; immutable-hash-hamt-support-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate shared HAMT support helpers for immutable hash updates.
(define immutable-hash-hamt-support-runtime-only-helpers
  (list
   (core-runtime-helper
    '$immutable-hamt-empty-node
    "$immutable-hamt-empty-node"
    (lambda ()
      `(func $immutable-hamt-empty-node
             (result (ref $StencilVector))
             (call $immutable-hamt-empty-packed-node))))

   ;; immutable-hamt-bnode-collapse-if-single : any/c -> any/c
   ;;   Collapse a one-slot bnode when the slot can stand directly in its parent.
   (core-runtime-helper
    '$immutable-hamt-bnode-collapse-if-single
    "$immutable-hamt-bnode-collapse-if-single"
    (lambda ()
      `(func $immutable-hamt-bnode-collapse-if-single
             (param $node (ref eq))
             (result      (ref eq))
             (local $sv        (ref $StencilVector))
             (local $slot      (ref eq))
             (local $collapsed (ref eq))
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                 (then (return (local.get $node))))
             (local.set $sv (ref.cast (ref $StencilVector) (local.get $node)))
             (if (i32.ne (call $$stencil-vector-popcount/i32
                                (struct.get $StencilVector $mask (local.get $sv)))
                          (i32.const 1))
                 (then (return (local.get $node))))
             (local.set $slot
                        (array.get $Array
                                   (struct.get $StencilVector $slots (local.get $sv))
                                   (i32.const 0)))
             (if (ref.test (ref $ImmutableHashEntry) (local.get $slot))
                 (then (return (local.get $slot))))
             (if (ref.test (ref $Pair) (local.get $slot))
                 (then
                  (local.set $collapsed
                             (call $immutable-hamt-collapse-small-bucket
                                   (local.get $slot)))
                  (if (ref.test (ref $ImmutableHashEntry) (local.get $collapsed))
                      (then (return (local.get $collapsed))))
                  (return (local.get $node))))
             (if (ref.test (ref $StencilVector) (local.get $slot))
                 (then
                  (local.set $collapsed
                             (call $immutable-hamt-bnode-collapse-if-single
                                   (local.get $slot)))
                  (if (ref.eq (local.get $collapsed) (local.get $slot))
                      (then (return (local.get $node))))
                  (return (local.get $collapsed))))
             (local.get $node))))

   (core-runtime-helper
    '$immutable-hamt-bucket-length
    "$immutable-hamt-bucket-length"
    (lambda ()
      `(func $immutable-hamt-bucket-length
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (result        i32)
             (local $node (ref eq))
             (local $n    i32)
             (if (ref.test (ref $ImmutableHashEntry) (local.get $bucket))
                 (then (return (i32.const 1))))
             (local.set $node (local.get $bucket))
             (block $done
                    (loop $scan
                          (br_if $done
                                 (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $done)))
                          (local.set $n (i32.add (local.get $n) (i32.const 1)))
                          (local.set $node
                                     (struct.get $Pair $d
                                                 (ref.cast (ref $Pair)
                                                           (local.get $node))))
                          (br $scan)))
             (local.get $n))))

   ;; immutable-hamt-bucket-first-entry : bucket -> entry/null
   ;;   Return the first entry in a one-entry bucket list.
   (core-runtime-helper
    '$immutable-hamt-bucket-first-entry
    "$immutable-hamt-bucket-first-entry"
    (lambda ()
      `(func $immutable-hamt-bucket-first-entry
             (param $bucket (ref eq))
             (result        (ref eq))
             (local $pair (ref $Pair))
             (if (ref.test (ref $ImmutableHashEntry) (local.get $bucket))
                 (then (return (local.get $bucket))))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $bucket)))
                 (then (return (global.get $null))))
             (local.set $pair (ref.cast (ref $Pair) (local.get $bucket)))
             (if (ref.test (ref $ImmutableHashEntry)
                           (struct.get $Pair $a (local.get $pair)))
                 (then (return (struct.get $Pair $a (local.get $pair)))))
             (global.get $null))))

   ;; immutable-hamt-collapse-small-bucket : bucket -> bucket/entry/null
   ;;   Collapse a one-entry bucket back to a direct inline entry.
   (core-runtime-helper
    '$immutable-hamt-collapse-small-bucket
    "$immutable-hamt-collapse-small-bucket"
    (lambda ()
      `(func $immutable-hamt-collapse-small-bucket
             (param $bucket (ref eq))
             (result        (ref eq))
             (if (i32.eq (call $immutable-hamt-bucket-length
                                (local.get $bucket))
                          (i32.const 1))
                 (then
                  (return_call $immutable-hamt-bucket-first-entry
                               (local.get $bucket))))
             (local.get $bucket))))

   (core-runtime-helper
    '$immutable-hamt-entry-matches?/kind
    "$immutable-hamt-entry-matches?/kind"
    (lambda ()
      `(func $immutable-hamt-entry-matches?/kind
             (param $kind  i32)
             (param $entry (ref $ImmutableHashEntry))
             (param $key   (ref eq))
             (result       i32)
             (if (i32.eq (local.get $kind) (i32.const 0))
                 (then (return (ref.eq
                                (struct.get $ImmutableHashEntry $key
                                            (local.get $entry))
                                (local.get $key)))))
             (if (i32.eq (local.get $kind) (i32.const 1))
                 (then (return (ref.eq
                                (call $eqv?
                                      (struct.get $ImmutableHashEntry $key
                                                  (local.get $entry))
                                      (local.get $key))
                                (global.get $true)))))
             (if (i32.eq (local.get $kind) (i32.const 2))
                 (then (return (ref.eq
                                (call $equal?
                                      (struct.get $ImmutableHashEntry $key
                                                  (local.get $entry))
                                      (local.get $key))
                                (global.get $true)))))
             (return (ref.eq
                      (call $equal-always?
                            (struct.get $ImmutableHashEntry $key
                                        (local.get $entry))
                            (local.get $key))
                      (global.get $true))))))

   (core-runtime-helper
    '$immutable-hamt-bucket-remove/kind
    "$immutable-hamt-bucket-remove/kind"
    (lambda ()
      `(func $immutable-hamt-bucket-remove/kind
             (param $kind   i32)
             (param $bucket (ref eq))
             (param $key    (ref eq))
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $result (ref eq))
             (if (ref.test (ref $ImmutableHashEntry) (local.get $bucket))
                 (then
                  (if (call $immutable-hamt-entry-matches?/kind
                            (local.get $kind)
                            (ref.cast (ref $ImmutableHashEntry)
                                      (local.get $bucket))
                            (local.get $key))
                      (then (return (global.get $null)))
                      (else (return (local.get $bucket))))))
             (local.set $node   (local.get $bucket))
             (local.set $result (global.get $null))
             (block $done
                    (loop $scan
                          (br_if $done
                                 (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $done)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (i32.eqz
                               (call $immutable-hamt-entry-matches?/kind
                                     (local.get $kind)
                                     (local.get $entry)
                                     (local.get $key)))
                              (then
                               (local.set $result
                                          (call $cons
                                                (local.get $entry)
                                                (local.get $result)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (return_call $immutable-hamt-collapse-small-bucket
                          (local.get $result)))))))

;; immutable-hash-cnode-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate terminal full-hash collision-node helpers.
(define immutable-hash-cnode-runtime-only-helpers
  (list
   ;; immutable-hamt-cnode-ref/kind : kind cnode key key-hash fail -> any/c
   ;;   Lookup in a terminal full-hash collision node.
   (core-runtime-helper
    '$immutable-hamt-cnode-ref/kind
    "$immutable-hamt-cnode-ref/kind"
    (lambda ()
      `(func $immutable-hamt-cnode-ref/kind
             (param $kind  i32) ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $cnode (ref $ImmutableHashCNode))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $fail  (ref eq))
             (result       (ref eq))

             (if (i32.ne (local.get $hash)
                         (struct.get $ImmutableHashCNode $key-hash
                                     (local.get $cnode)))
                 (then (return (local.get $fail))))
             (return_call $immutable-hamt-bucket-ref/kind
                          (local.get $kind)
                          (struct.get $ImmutableHashCNode $content
                                      (local.get $cnode))
                          (local.get $key)
                          (local.get $fail)))))

   ;; immutable-hamt-cnode-ref-key/kind : kind cnode key key-hash fail -> any/c
   ;;   Find the stored key in a terminal full-hash collision node.
   (core-runtime-helper
    '$immutable-hamt-cnode-ref-key/kind
    "$immutable-hamt-cnode-ref-key/kind"
    (lambda ()
      `(func $immutable-hamt-cnode-ref-key/kind
             (param $kind  i32) ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $cnode (ref $ImmutableHashCNode))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $fail  (ref eq))
             (result       (ref eq))

             (if (i32.ne (local.get $hash)
                         (struct.get $ImmutableHashCNode $key-hash
                                     (local.get $cnode)))
                 (then (return (local.get $fail))))
             (return_call $immutable-hamt-bucket-ref-key/kind
                          (local.get $kind)
                          (struct.get $ImmutableHashCNode $content
                                      (local.get $cnode))
                          (local.get $key)
                          (local.get $fail)))))

   ;; immutable-hamt-cnode-has-key?/kind : kind cnode key key-hash -> i32
   ;;   Check a terminal full-hash collision node for a key.
   (core-runtime-helper
    '$immutable-hamt-cnode-has-key?/kind
    "$immutable-hamt-cnode-has-key?/kind"
    (lambda ()
      `(func $immutable-hamt-cnode-has-key?/kind
             (param $kind  i32) ;; 0 eq?, 1 eqv?, 2 equal?, 3 equal-always?
             (param $cnode (ref $ImmutableHashCNode))
             (param $key   (ref eq))
             (param $hash  i32)
             (result       i32)

             (if (i32.ne (local.get $hash)
                         (struct.get $ImmutableHashCNode $key-hash
                                     (local.get $cnode)))
                 (then (return (i32.const 0))))
             (return_call $immutable-hamt-bucket-has-key?/kind
                          (local.get $kind)
                          (struct.get $ImmutableHashCNode $content
                                      (local.get $cnode))
                          (local.get $key)))))

   ;; immutable-hamt-cnode-set/kind : kind cnode entry key key-hash -> cnode
   ;;   Update or extend a terminal full-hash collision node.
   (core-runtime-helper
    '$immutable-hamt-cnode-set/kind
    "$immutable-hamt-cnode-set/kind"
    (lambda ()
      `(func $immutable-hamt-cnode-set/kind
             (param $kind  i32)
             (param $cnode (ref $ImmutableHashCNode))
             (param $entry (ref $ImmutableHashEntry))
             (param $key   (ref eq))
             (param $hash  i32)
             (result       (ref eq))

             (if (i32.ne (local.get $hash)
                         (struct.get $ImmutableHashCNode $key-hash
                                     (local.get $cnode)))
                 (then
                  ;; This should not occur for a real cnode path, but keeping
                  ;; the new entry preserves lookup safety if a malformed tree
                  ;; reaches this helper.
                  (return
                   (struct.new $ImmutableHashCNode
                               (i32.const 0)
                               (struct.get $ImmutableHashCNode $key-hash
                                           (local.get $cnode))
                               (call $cons
                                     (local.get $entry)
                                     (struct.get $ImmutableHashCNode $content
                                                 (local.get $cnode)))))))
             (struct.new $ImmutableHashCNode
                         (i32.const 0)
                         (local.get $hash)
                         (call $cons
                               (local.get $entry)
                               (call $immutable-hamt-bucket-remove/kind
                                     (local.get $kind)
                                     (struct.get $ImmutableHashCNode $content
                                                 (local.get $cnode))
                                     (local.get $key)))))))

   ;; immutable-hamt-cnode-remove/kind : kind cnode key key-hash -> bucket/cnode
   ;;   Remove a key, collapsing an empty cnode to null.
   (core-runtime-helper
    '$immutable-hamt-cnode-remove/kind
    "$immutable-hamt-cnode-remove/kind"
    (lambda ()
      `(func $immutable-hamt-cnode-remove/kind
             (param $kind  i32)
             (param $cnode (ref $ImmutableHashCNode))
             (param $key   (ref eq))
             (param $hash  i32)
             (result       (ref eq))
             (local $content (ref eq))

             (if (i32.ne (local.get $hash)
                         (struct.get $ImmutableHashCNode $key-hash
                                     (local.get $cnode)))
                 (then (return (local.get $cnode))))
             (local.set $content
                        (call $immutable-hamt-bucket-remove/kind
                              (local.get $kind)
                              (struct.get $ImmutableHashCNode $content
                                          (local.get $cnode))
                              (local.get $key)))
             (if (ref.eq (local.get $content) (global.get $null))
                 (then (return (global.get $null))))
             (if (i32.le_u (call $immutable-hamt-bucket-length
                                  (local.get $content))
                            (i32.const 1))
                 (then (return (local.get $content))))
             (struct.new $ImmutableHashCNode
                         (i32.const 0)
                         (local.get $hash)
                         (local.get $content)))))

   ;; immutable-hamt-bucket->cnode : bucket entry -> cnode
   ;;   Build a terminal full-hash collision node.
   (core-runtime-helper
    '$immutable-hamt-bucket->cnode
    "$immutable-hamt-bucket->cnode"
    (lambda ()
      `(func $immutable-hamt-bucket->cnode
             (param $bucket    (ref eq))
             (param $new-entry (ref $ImmutableHashEntry))
             (result           (ref $ImmutableHashCNode))
             (struct.new $ImmutableHashCNode
                         (i32.const 0)
                         (struct.get $ImmutableHashEntry $key-hash
                                     (local.get $new-entry))
                         (call $cons
                               (local.get $new-entry)
                               (local.get $bucket))))))))

;; immutable-hash-node-set-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic HAMT insertion/update helpers.
(define immutable-hash-node-set-runtime-only-helpers
  (list
   (core-runtime-helper
    '$immutable-hamt-bucket->node/kind
    "$immutable-hamt-bucket->node/kind"
    (lambda ()
      `(func $immutable-hamt-bucket->node/kind
             (param $kind      i32)
             (param $bucket    (ref eq))
             (param $new-entry (ref $ImmutableHashEntry))
             (param $shift     i32)
             (result           (ref eq))
             (local $node  (ref eq))
             (local $scan  (ref eq))
             (local $pair  (ref $Pair))
             (local $entry (ref $ImmutableHashEntry))
             (local.set $node (call $immutable-hamt-empty-node))
             (if (ref.test (ref $ImmutableHashEntry) (local.get $bucket))
                 (then
                  (local.set $node
                             (call $immutable-hamt-node-set/kind
                                   (local.get $kind)
                                   (local.get $node)
                                   (ref.cast (ref $ImmutableHashEntry)
                                             (local.get $bucket))
                                   (struct.get $ImmutableHashEntry $key
                                               (ref.cast (ref $ImmutableHashEntry)
                                                         (local.get $bucket)))
                                   (struct.get $ImmutableHashEntry $key-hash
                                               (ref.cast (ref $ImmutableHashEntry)
                                                         (local.get $bucket)))
                                   (local.get $shift)))
                  (return_call $immutable-hamt-node-set/kind
                               (local.get $kind)
                               (local.get $node)
                               (local.get $new-entry)
                               (struct.get $ImmutableHashEntry $key (local.get $new-entry))
                               (struct.get $ImmutableHashEntry $key-hash (local.get $new-entry))
                               (local.get $shift))))
             (local.set $scan (local.get $bucket))
             (block $done
                    (loop $walk
                          (br_if $done
                                 (ref.eq (local.get $scan) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $scan)))
                              (then (br $done)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $scan)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (local.set $node
                                     (call $immutable-hamt-node-set/kind
                                           (local.get $kind)
                                           (local.get $node)
                                           (local.get $entry)
                                           (struct.get $ImmutableHashEntry $key
                                                       (local.get $entry))
                                           (struct.get $ImmutableHashEntry $key-hash
                                                       (local.get $entry))
                                           (local.get $shift)))
                          (local.set $scan (struct.get $Pair $d (local.get $pair)))
                          (br $walk)))
             (call $immutable-hamt-node-set/kind
                   (local.get $kind)
                   (local.get $node)
                   (local.get $new-entry)
                   (struct.get $ImmutableHashEntry $key (local.get $new-entry))
                   (struct.get $ImmutableHashEntry $key-hash (local.get $new-entry))
                   (local.get $shift)))))

   (core-runtime-helper
    '$immutable-hamt-node-set/kind
    "$immutable-hamt-node-set/kind"
    (lambda ()
      `(func $immutable-hamt-node-set/kind
             (param $kind  i32)
             (param $node  (ref eq))
             (param $entry (ref $ImmutableHashEntry))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $shift i32)
             (result       (ref eq))
             (local $sv      (ref $StencilVector))
             (local $mask    i32)
             (local $bit     i32)
             (local $index   i32)
             (local $slot    (ref eq))
             (local $newslot (ref eq))
             (local.set $newslot (global.get $null))
             (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                 (then
                  (return_call $immutable-hamt-cnode-set/kind
                               (local.get $kind)
                               (ref.cast (ref $ImmutableHashCNode)
                                         (local.get $node))
                               (local.get $entry)
                               (local.get $key)
                               (local.get $hash))))
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                 (then
                  (return (call $cons (local.get $entry) (local.get $node)))))
             (local.set $sv   (ref.cast (ref $StencilVector) (local.get $node)))
             (if (call $immutable-hamt-packed-bnode? (local.get $sv))
                 (then
                  (return_call $immutable-hamt-packed-node-set/kind
                               (local.get $kind)
                               (local.get $sv)
                               (local.get $entry)
                               (local.get $key)
                               (local.get $hash)
                               (local.get $shift))))
             (local.set $mask (struct.get $StencilVector $mask (local.get $sv)))
             (local.set $bit  (call $immutable-hamt-bit
                                    (local.get $hash)
                                    (local.get $shift)))
             (if (i32.eqz (i32.and (local.get $mask) (local.get $bit)))
                 (then
                  (return_call $immutable-hamt-store-bnode-metadata
                               (ref.cast
                                (ref $StencilVector)
                                (call $$stencil-vector-update/core
                                      (local.get $sv)
                                      (i32.const 0)
                                      (local.get $bit)
                                      (call $cons
                                            (local.get $entry)
                                            (global.get $null))
                                      (i32.const 1))))))
             (local.set $index (call $immutable-hasheqv-bucket-index
                                     (local.get $mask)
                                     (local.get $bit)))
             (local.set $slot
                        (array.get $Array
                                   (struct.get $StencilVector $slots (local.get $sv))
                                   (local.get $index)))
             (if (ref.test (ref $StencilVector) (local.get $slot))
                 (then
                  (local.set $newslot
                             (call $immutable-hamt-node-set/kind
                                   (local.get $kind)
                                   (local.get $slot)
                                   (local.get $entry)
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.add (local.get $shift) (i32.const 3)))))
                 (else
                  (if (ref.test (ref $ImmutableHashCNode) (local.get $slot))
                      (then
                       (local.set $newslot
                                  (call $immutable-hamt-cnode-set/kind
                                        (local.get $kind)
                                        (ref.cast (ref $ImmutableHashCNode)
                                                  (local.get $slot))
                                        (local.get $entry)
                                        (local.get $key)
                                        (local.get $hash))))
                      (else
                       (if (ref.test (ref $ImmutableHashEntry) (local.get $slot))
                           (then
                            (if (call $immutable-hamt-entry-matches?/kind
                                      (local.get $kind)
                                      (ref.cast (ref $ImmutableHashEntry)
                                                (local.get $slot))
                                      (local.get $key))
                                (then
                                 (local.set $newslot (local.get $entry)))
                                (else
                                 (local.set $newslot
                                            (call $cons
                                                  (local.get $entry)
                                                  (call $cons
                                                        (local.get $slot)
                                                        (global.get $null)))))))
                           (else
                            (if (i32.and
                                 (i32.eqz
                                  (call $immutable-hamt-bucket-has-key?/kind
                                        (local.get $kind)
                                        (local.get $slot)
                                        (local.get $key)))
                                 (i32.and
                                  (i32.lt_u (local.get $shift) (i32.const 30))
                                  (i32.ge_u
                                   (call $immutable-hamt-bucket-length (local.get $slot))
                                   (i32.const 4))))
                                (then
                                 (local.set $newslot
                                            (call $immutable-hamt-bucket->node/kind
                                                  (local.get $kind)
                                                  (local.get $slot)
                                                  (local.get $entry)
                                                  (i32.add (local.get $shift) (i32.const 3)))))
                                (else
                                 (if (i32.and
                                      (i32.eqz
                                       (call $immutable-hamt-bucket-has-key?/kind
                                             (local.get $kind)
                                             (local.get $slot)
                                             (local.get $key)))
                                      (i32.ge_u
                                       (call $immutable-hamt-bucket-length (local.get $slot))
                                       (i32.const 4)))
                                     (then
                                      (local.set $newslot
                                                 (call $immutable-hamt-bucket->cnode
                                                       (local.get $slot)
                                                       (local.get $entry))))
                                     (else
                                      (local.set $newslot
                                                 (call $cons
                                                       (local.get $entry)
                                                       (call $immutable-hamt-bucket-remove/kind
                                                             (local.get $kind)
                                                             (local.get $slot)
                                                             (local.get $key))))))))))))))
             (return_call $immutable-hamt-store-bnode-metadata
                          (ref.cast
                           (ref $StencilVector)
                           (call $$stencil-vector-update/core
                                 (local.get $sv)
                                 (local.get $bit)
                                 (local.get $bit)
                                 (call $cons (local.get $newslot) (global.get $null))
                                 (i32.const 1)))))))))

;; immutable-hash-node-remove-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic HAMT remove helpers.
(define immutable-hash-node-remove-runtime-only-helpers
  (list
   (core-runtime-helper
    '$immutable-hamt-node-remove/kind
    "$immutable-hamt-node-remove/kind"
    (lambda ()
      `(func $immutable-hamt-node-remove/kind
             (param $kind  i32)
             (param $node  (ref eq))
             (param $key   (ref eq))
             (param $hash  i32)
             (param $shift i32)
             (result       (ref eq))
             (local $sv      (ref $StencilVector))
             (local $newsv   (ref $StencilVector))
             (local $mask    i32)
             (local $bit     i32)
             (local $index   i32)
             (local $slot    (ref eq))
             (local $newslot (ref eq))
             (local.set $newslot (global.get $null))
             (local.set $newsv (call $immutable-hamt-empty-node))
             (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                 (then
                  (return_call $immutable-hamt-cnode-remove/kind
                               (local.get $kind)
                               (ref.cast (ref $ImmutableHashCNode)
                                         (local.get $node))
                               (local.get $key)
                               (local.get $hash))))
             (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                 (then
                  (return_call $immutable-hamt-bucket-remove/kind
                               (local.get $kind)
                               (local.get $node)
                               (local.get $key))))
             (local.set $sv   (ref.cast (ref $StencilVector) (local.get $node)))
             (if (call $immutable-hamt-packed-bnode? (local.get $sv))
                 (then
                  (return_call $immutable-hamt-packed-node-remove/kind
                               (local.get $kind)
                               (local.get $sv)
                               (local.get $key)
                               (local.get $hash)
                               (local.get $shift))))
             (local.set $mask (struct.get $StencilVector $mask (local.get $sv)))
             (local.set $bit  (call $immutable-hamt-bit
                                    (local.get $hash)
                                    (local.get $shift)))
             (if (i32.eqz (i32.and (local.get $mask) (local.get $bit)))
                 (then (return (local.get $node))))
             (local.set $index (call $immutable-hasheqv-bucket-index
                                     (local.get $mask)
                                     (local.get $bit)))
             (local.set $slot
                        (array.get $Array
                                   (struct.get $StencilVector $slots (local.get $sv))
                                   (local.get $index)))
             (if (ref.test (ref $StencilVector) (local.get $slot))
                 (then
                  (local.set $newslot
                             (call $immutable-hamt-node-remove/kind
                                   (local.get $kind)
                                   (local.get $slot)
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.add (local.get $shift) (i32.const 3)))))
                 (else
                  (if (ref.test (ref $ImmutableHashCNode) (local.get $slot))
                      (then
                       (local.set $newslot
                                  (call $immutable-hamt-cnode-remove/kind
                                        (local.get $kind)
                                        (ref.cast (ref $ImmutableHashCNode)
                                                  (local.get $slot))
                                        (local.get $key)
                                        (local.get $hash))))
                      (else
                       (local.set $newslot
                                  (call $immutable-hamt-bucket-remove/kind
                                        (local.get $kind)
                                        (local.get $slot)
                                        (local.get $key)))))))
             (if (ref.eq (local.get $newslot) (global.get $null))
                 (then
                  (return_call $immutable-hamt-bnode-collapse-if-single
                               (call $immutable-hamt-store-bnode-metadata
                                     (ref.cast
                                      (ref $StencilVector)
                                      (call $$stencil-vector-update/core
                                            (local.get $sv)
                                            (local.get $bit)
                                            (i32.const 0)
                                            (global.get $null)
                                            (i32.const 1)))))))
             (if (ref.test (ref $StencilVector) (local.get $newslot))
                 (then
                  (local.set $newsv
                             (ref.cast (ref $StencilVector)
                                       (local.get $newslot)))
                  (if (i32.eqz (struct.get $StencilVector $mask (local.get $newsv)))
                      (then
                       (return_call $immutable-hamt-bnode-collapse-if-single
                                    (call $immutable-hamt-store-bnode-metadata
                                          (ref.cast
                                           (ref $StencilVector)
                                           (call $$stencil-vector-update/core
                                                 (local.get $sv)
                                                 (local.get $bit)
                                                 (i32.const 0)
                                                 (global.get $null)
                                                 (i32.const 1)))))))))
             (return_call $immutable-hamt-bnode-collapse-if-single
                          (call $immutable-hamt-store-bnode-metadata
                                (ref.cast
                                 (ref $StencilVector)
                                 (call $$stencil-vector-update/core
                                       (local.get $sv)
                                       (local.get $bit)
                                       (local.get $bit)
                                       (call $cons (local.get $newslot) (global.get $null))
                                       (i32.const 1))))))))))

;; immutable-hash-equal-bucket-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate equal?/equal-always? immutable hash bucket helpers.
(define immutable-hash-equal-bucket-runtime-only-helpers
  (list
   (core-runtime-helper
    '$immutable-hash-bucket-has-key?
    "$immutable-hash-bucket-has-key?"
    (lambda ()
      `(func $immutable-hash-bucket-has-key?
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (result i32)
             (local $node  (ref eq))
             (local $pair  (ref $Pair))
             (local $entry (ref $ImmutableHashEntry))
             (local.set $node (local.get $bucket))
             (block $done
                    (loop $scan
                          (br_if $done (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (return (i32.const 0))))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $equal?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (i32.const 1))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (i32.const 0))))

   (core-runtime-helper
    '$immutable-hash-bucket-ref
    "$immutable-hash-bucket-ref"
    (lambda ()
      `(func $immutable-hash-bucket-ref
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $equal?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (struct.get $ImmutableHashEntry $value
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))

   (core-runtime-helper
    '$immutable-hash-bucket-ref-key
    "$immutable-hash-bucket-ref-key"
    (lambda ()
      `(func $immutable-hash-bucket-ref-key
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $equal?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (struct.get $ImmutableHashEntry $key
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))

   (core-runtime-helper
    '$immutable-hashalw-bucket-has-key?
    "$immutable-hashalw-bucket-has-key?"
    (lambda ()
      `(func $immutable-hashalw-bucket-has-key?
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (result i32)
             (local $node  (ref eq))
             (local $pair  (ref $Pair))
             (local $entry (ref $ImmutableHashEntry))
             (local.set $node (local.get $bucket))
             (block $done
                    (loop $scan
                          (br_if $done (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (return (i32.const 0))))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $equal-always?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (i32.const 1))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (i32.const 0))))

   (core-runtime-helper
    '$immutable-hashalw-bucket-ref
    "$immutable-hashalw-bucket-ref"
    (lambda ()
      `(func $immutable-hashalw-bucket-ref
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $equal-always?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (struct.get $ImmutableHashEntry $value
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))

   (core-runtime-helper
    '$immutable-hashalw-bucket-ref-key
    "$immutable-hashalw-bucket-ref-key"
    (lambda ()
      `(func $immutable-hashalw-bucket-ref-key
             (param $bucket (ref eq)) ;; list of immutable hash entries
             (param $key    (ref eq)) ;; lookup key
             (param $fail   (ref eq)) ;; failure result/procedure/missing
             (result        (ref eq))
             (local $node   (ref eq))
             (local $pair   (ref $Pair))
             (local $entry  (ref $ImmutableHashEntry))
             (local $proc   (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $noargs (ref $Args))
             (local.set $node (local.get $bucket))
             (block $not-found
                    (loop $scan
                          (br_if $not-found (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (br $not-found)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $entry
                                     (ref.cast (ref $ImmutableHashEntry)
                                               (struct.get $Pair $a (local.get $pair))))
                          (if (ref.eq (call $equal-always?
                                            (struct.get $ImmutableHashEntry $key (local.get $entry))
                                            (local.get $key))
                                      (global.get $true))
                              (then (return (struct.get $ImmutableHashEntry $key
                                                        (local.get $entry)))))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (br $scan)))
             (if (result (ref eq))
                 (ref.eq (local.get $fail) (global.get $missing))
                 (then (call $raise-hash-ref-key-not-found (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.test (ref $Procedure) (local.get $fail))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                      (else (local.get $fail))))))))))

;; immutable-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash helpers that still depend on monolithic runtime globals.
(define immutable-hash-runtime-only-helpers
  (append immutable-hash-prelude-runtime-only-helpers
          immutable-hash-hamt-bit-runtime-only-helpers
          immutable-hash-hamt-metadata-runtime-only-helpers
          immutable-hash-eq-bucket-runtime-only-helpers
          immutable-hash-packed-node-read-runtime-only-helpers
          immutable-hash-packed-node-set-runtime-only-helpers
          immutable-hash-packed-node-remove-runtime-only-helpers
          immutable-hash-node-lookup-runtime-only-helpers
          immutable-hash-hamt-support-runtime-only-helpers
          immutable-hash-cnode-runtime-only-helpers
          immutable-hash-node-set-runtime-only-helpers
          immutable-hash-node-remove-runtime-only-helpers
          immutable-hash-equal-bucket-runtime-only-helpers))
