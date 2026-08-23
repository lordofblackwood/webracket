#lang racket

(provide immutable-hash-runtime-string-constants
         immutable-hash-constructor-runtime-only-helper-names
         immutable-hash-iteration-runtime-only-helper-names
         immutable-hash-public-runtime-only-helper-names
         immutable-hash-prelude-runtime-helper-forms
         immutable-hash-public-set/remove-runtime-helper-forms
         immutable-hash-public-update-runtime-helper-forms
         immutable-hash-public-clear-runtime-helper-forms
         immutable-hash-iteration-runtime-helper-forms
         immutable-hash-core-runtime-helpers
         immutable-hash-runtime-symbol-constants
         immutable-hash-runtime-only-helpers)

(require "../core-helper.rkt")

;; immutable-hash-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by immutable hash reader-graph placeholder helpers.
(define immutable-hash-runtime-string-constants
  '((ephemeron? "ephemeron?")
    (placeholder? "placeholder?")
    (immutable-hash? "(and/c hash? immutable?)")
    (hash-set-non-hash "hash-set expected hash table, got:")
    (hash-set-exn-message "hash-set received exception message:")
    (hash-set-unsupported "hash-set unsupported hash table:")
    (hash-constructor:key-without-value
     ": key does not have a value (i.e., an odd number of arguments were provided)\n  key: ")
    (reader-graph-unsupported
     "make-reader-graph: cyclic reader graphs and hash placeholders are not supported by WebRacket yet")))

;; immutable-hash-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for empty immutable hash constructors.
(define immutable-hash-constructor-runtime-only-helper-names
  '($make-empty-immutable-hasheq
    $make-empty-immutable-hasheqv
    $make-empty-immutable-hash
    $make-empty-immutable-hashalw))

;; immutable-hash-prelude-runtime-only-helper-names : (listof symbol?)
;;   Preserve the monolithic runtime emission order for immutable hash prelude helpers.
(define immutable-hash-prelude-runtime-only-helper-names
  '($hash-placeholder?
    $placeholder?
    $make-placeholder
    $placeholder-set!
    $placeholder-get
    $reader-graph-resolve
    $make-reader-graph
    $hash-weak?
    $make-hash-placeholder/kind
    $make-hash-placeholder
    $make-hasheq-placeholder
    $make-hasheqv-placeholder
    $make-hashalw-placeholder
    $immutable-hasheqv-bucket-index
    $immutable-hamt-packed-group-index
    $immutable-hamt-packed-child-bit
    $immutable-hamt-packed-key-bit
    $immutable-hamt-packed-value-bit
    $immutable-hamt-packed-bits
    $immutable-hamt-slot-kind
    $immutable-hamt-bnode-packed-metadata
    $immutable-hamt-store-bnode-metadata
    $immutable-hamt-bnode-metadata
    $immutable-hamt-packed-bnode?
    $immutable-hamt-packed-index
    $immutable-hamt-packed-slot
    $immutable-hamt-packed-child-slot
    $immutable-hamt-packed-key-slot
    $immutable-hamt-packed-value-slot
    $immutable-hamt-empty-packed-node
    $immutable-hamt-store-packed-bnode-metadata
    $immutable-hamt-key-hash/kind
    $immutable-hamt-wrap-inline-key/kind
    $immutable-hamt-inline-key-unwrap
    $immutable-hamt-inline-key-cached-hash
    $immutable-hamt-entry-for-key/kind
    $immutable-hamt-packed-metadata-present?/i32
    $immutable-hasheqv-bucket-has-key?
    $immutable-hasheqv-bucket-ref
    $immutable-hasheqv-bucket-ref-key
    $immutable-hasheq-bucket-has-key?
    $immutable-hasheq-bucket-ref
    $immutable-hasheq-bucket-ref-key
    $immutable-hamt-bit
    $immutable-hamt-bucket-ref/kind
    $immutable-hamt-bucket-ref-key/kind
    $immutable-hamt-bucket-has-key?/kind
    $immutable-hamt-key-matches?/kind
    $immutable-hamt-packed-node-ref/kind
    $immutable-hamt-packed-node-ref-key/kind
    $immutable-hamt-packed-node-has-key?/kind
    $immutable-hamt-packed-node-set/kind
    $immutable-hamt-packed-bnode-collapse-if-single/kind
    $immutable-hamt-packed-node-remove/kind
    $immutable-hamt-node-ref/kind
    $immutable-hamt-node-ref-key/kind
    $immutable-hamt-node-has-key?/kind
    $immutable-hamt-empty-node
    $immutable-hamt-bnode-collapse-if-single
    $immutable-hamt-bucket-length
    $immutable-hamt-bucket-first-entry
    $immutable-hamt-collapse-small-bucket
    $immutable-hamt-entry-matches?/kind
    $immutable-hamt-bucket-remove/kind
    $immutable-hamt-cnode-ref/kind
    $immutable-hamt-cnode-ref-key/kind
    $immutable-hamt-cnode-has-key?/kind
    $immutable-hamt-cnode-set/kind
    $immutable-hamt-cnode-remove/kind
    $immutable-hamt-bucket->cnode
    $immutable-hamt-bucket->node/kind
    $immutable-hamt-node-set/kind
    $immutable-hamt-node-remove/kind
    $immutable-hasheqv-ref
    $immutable-hasheq-ref
    $immutable-hasheqv-ref-key
    $immutable-hasheq-ref-key
    $immutable-hasheqv-has-key?
    $immutable-hasheq-has-key?
    $immutable-hash-bucket-has-key?
    $immutable-hash-bucket-ref
    $immutable-hash-bucket-ref-key
    $immutable-hashalw-bucket-has-key?
    $immutable-hashalw-bucket-ref
    $immutable-hashalw-bucket-ref-key
    $immutable-hash-ref
    $immutable-hash-ref-key
    $immutable-hash-has-key?
    $immutable-hashalw-ref
    $immutable-hashalw-ref-key
    $immutable-hashalw-has-key?
    $immutable-hasheqv-set
    $raise-hash-constructor-odd-arguments
    $immutable-hasheq-set
    $immutable-hash-set
    $immutable-hashalw-set
    $immutable-hasheqv-remove
    $immutable-hasheq-remove
    $immutable-hash-remove
    $immutable-hashalw-remove
    $hash
    $hasheq
    $hashalw
    $hasheqv
    $make-immutable-hash
    $make-immutable-hashalw
    $make-immutable-hasheq
    $make-immutable-hasheqv
    $make-weak-hash
    $make-weak-hasheq
    $make-ephemeron-hasheq
    $make-ephemeron
    $ephemeron?
    $ephemeron-value
    $make-weak-hasheqv
    $make-weak-hashalw))

;; immutable-hash-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given immutable hash helper names from the runtime helper index.
(define (immutable-hash-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; immutable-hash-prelude-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render immutable hash prelude helpers in monolithic runtime assembly order.
(define (immutable-hash-prelude-runtime-helper-forms helper-index)
  (append
   (immutable-hash-helper-forms helper-index
                                immutable-hash-constructor-runtime-only-helper-names)
   (immutable-hash-helper-forms helper-index
                                immutable-hash-prelude-runtime-only-helper-names)))

;; immutable-hash-public-set/remove-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for public immutable hash set/remove wrappers.
(define immutable-hash-public-set/remove-runtime-helper-names
  '($hash-set
    $hash-remove))

;; immutable-hash-public-update-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for public immutable hash update.
(define immutable-hash-public-update-runtime-helper-names
  '($hash-update))

;; immutable-hash-public-clear-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for public immutable hash clear.
(define immutable-hash-public-clear-runtime-helper-names
  '($hash-clear))

;; immutable-hash-public-set/remove-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render public immutable hash set/remove wrappers in runtime assembly order.
(define (immutable-hash-public-set/remove-runtime-helper-forms helper-index)
  (immutable-hash-helper-forms
   helper-index
   immutable-hash-public-set/remove-runtime-helper-names))

;; immutable-hash-public-update-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render public immutable hash update in runtime assembly order.
(define (immutable-hash-public-update-runtime-helper-forms helper-index)
  (immutable-hash-helper-forms
   helper-index
   immutable-hash-public-update-runtime-helper-names))

;; immutable-hash-public-clear-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render public immutable hash clear in runtime assembly order.
(define (immutable-hash-public-clear-runtime-helper-forms helper-index)
  (immutable-hash-helper-forms
   helper-index
   immutable-hash-public-clear-runtime-helper-names))

;; immutable-hash-iteration-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for immutable hash iteration and shape helpers.
(define immutable-hash-iteration-runtime-only-helper-names
  '($immutable-hash-as-hasheqv
    $immutable-hamt-packed-node->entries
    $immutable-hamt-packed-node-entry-count
    $immutable-hamt-packed-node-child-count
    $immutable-hamt-packed-node-max-depth
    $immutable-hamt-node->entries
    $immutable-hamt-node-entry-count
    $immutable-hamt-node-bnode-count
    $immutable-hamt-node-cnode-count
    $immutable-hamt-node-bucket-count
    $immutable-hamt-node-inline-count
    $immutable-hamt-node-slot-count
    $immutable-hamt-node-max-depth
    $immutable-hash-debug-shape
    $immutable-hash-root-metadata
    $immutable-hasheqv-iterate-first
    $immutable-hasheqv-iterate-entry
    $immutable-hasheqv-iterate-next
    $immutable-hash-iterate-index->entry/public
    $immutable-hash-iterate-first/public
    $immutable-hash-iterate-next/public
    $immutable-hash-iterate-key/public
    $immutable-hash-iterate-value/public
    $immutable-hash-iterate-pair/public
    $immutable-hash-iterate-key+value/public
    $unsafe-immutable-hash-iterate-first
    $unsafe-immutable-hash-iterate-next
    $unsafe-immutable-hash-iterate-key
    $unsafe-immutable-hash-iterate-value
    $unsafe-immutable-hash-iterate-pair
    $unsafe-immutable-hash-iterate-key+value))

;; immutable-hash-iteration-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render immutable hash iteration and shape helpers in runtime assembly order.
(define (immutable-hash-iteration-runtime-helper-forms helper-index)
  (immutable-hash-helper-forms
   helper-index
   immutable-hash-iteration-runtime-only-helper-names))

;; immutable-hash-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by immutable hash and reader-graph placeholder helpers.
(define immutable-hash-runtime-symbol-constants
  '(hash-placeholder?
    hash-weak?
    hash
    hasheq
    hasheqv
    hashalw
    hash-set
    hash-remove
    hash-update
    hash-clear
    make-reader-graph
    make-placeholder
    placeholder-set!
    placeholder-get
    make-hash-placeholder
    make-hasheq-placeholder
    make-hasheqv-placeholder
    make-hashalw-placeholder
    make-weak-hash
    make-weak-hasheq
    make-weak-hasheqv
    make-weak-hashalw
    make-ephemeron
    make-ephemeron-hasheq
    ephemeron?
    ephemeron-value))

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
                   (drop (call $raise
                               (call $exn:fail:unsupported/make
                                     (global.get $string:reader-graph-unsupported)
                                     (call $current-continuation-marks
                                           (global.get $missing)))
                               (global.get $true)))
                   (unreachable)))
              (if (ref.test (ref $HashPlaceholder) (local.get $v))
                  (then
                   (drop (call $raise
                               (call $exn:fail:unsupported/make
                                     (global.get $string:reader-graph-unsupported)
                                     (call $current-continuation-marks
                                           (global.get $missing)))
                               (global.get $true)))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref:no-value-found-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref-key:does-not-contain-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref:no-value-found-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref-key:does-not-contain-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref:no-value-found-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref-key:does-not-contain-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref:no-value-found-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                 (then (call $raise-hash-ref-key-not-found
                             (global.get $string:hash-ref-key:does-not-contain-key)
                             (local.get $key))
                       (unreachable))
                 (else
                  (if (result (ref eq))
                      (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
                      (then
                       (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                       (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                       (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                       (return_call_ref $ProcedureInvoker
                                        (local.get $proc)
                                        (local.get $noargs)
                                        (local.get $inv)))
                       (else (local.get $fail))))))))))

;; immutable-hash-lookup-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public immutable hash lookup wrappers over the shared HAMT.
(define immutable-hash-lookup-runtime-only-helpers
  (list
   ;; immutable-hasheqv-ref : immutable-hasheqv? any/c any/c -> any/c
   ;;   Look up a key in an immutable eqv?-based hash.
   (core-runtime-helper
    '$immutable-hasheqv-ref
    "$immutable-hasheqv-ref"
    (lambda ()
      `(func $immutable-hasheqv-ref
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hasheqv
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqvImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqvImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheqv-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqvImmutable) (local.get $ht)))
             (local.set $hash (call $eqv-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqvImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref/kind
                                    (i32.const 1)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref/kind
                          (i32.const 1)
                          (struct.get $HashEqvImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hasheq-ref : immutable-hasheq? any/c any/c -> any/c
   ;;   Look up a key in an immutable eq?-based hash.
   (core-runtime-helper
    '$immutable-hasheq-ref
    "$immutable-hasheq-ref"
    (lambda ()
      `(func $immutable-hasheq-ref
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hasheq
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheq-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqImmutable) (local.get $ht)))
             (local.set $hash (call $eq-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref/kind
                                    (i32.const 0)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref/kind
                          (i32.const 0)
                          (struct.get $HashEqImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hasheqv-ref-key : immutable-hasheqv? any/c any/c -> any/c
   ;;   Return the stored key matching a lookup key in an immutable eqv?-based hash.
   (core-runtime-helper
    '$immutable-hasheqv-ref-key
    "$immutable-hasheqv-ref-key"
    (lambda ()
      `(func $immutable-hasheqv-ref-key
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hasheqv
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqvImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqvImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheqv-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqvImmutable) (local.get $ht)))
             (local.set $hash (call $eqv-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqvImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref-key/kind
                                    (i32.const 1)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref-key/kind
                          (i32.const 1)
                          (struct.get $HashEqvImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hasheq-ref-key : immutable-hasheq? any/c any/c -> any/c
   ;;   Return the stored key matching a lookup key in an immutable eq?-based hash.
   (core-runtime-helper
    '$immutable-hasheq-ref-key
    "$immutable-hasheq-ref-key"
    (lambda ()
      `(func $immutable-hasheq-ref-key
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hasheq
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheq-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqImmutable) (local.get $ht)))
             (local.set $hash (call $eq-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref-key/kind
                                    (i32.const 0)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref-key/kind
                          (i32.const 0)
                          (struct.get $HashEqImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hasheqv-has-key? : immutable-hasheqv? any/c -> boolean?
   ;;   Check whether an immutable eqv?-based hash contains a key.
   (core-runtime-helper
    '$immutable-hasheqv-has-key?
    "$immutable-hasheqv-has-key?"
    (lambda ()
      `(func $immutable-hasheqv-has-key?
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hasheqv
             (param $key (ref eq)) ;; lookup key
             (result     (ref eq))
             (local $table (ref $HashEqvImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqvImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheqv-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqvImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqvImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (global.get $false))))
             (local.set $hash (call $eqv-hash/i32 (local.get $key)))
             (if (result (ref eq))
                 (call $immutable-hamt-node-has-key?/kind
                       (i32.const 1)
                       (struct.get $HashEqvImmutable $root (local.get $table))
                       (local.get $key)
                       (local.get $hash)
                       (i32.const 0))
                 (then (global.get $true))
                 (else (global.get $false))))))

   ;; immutable-hasheq-has-key? : immutable-hasheq? any/c -> boolean?
   ;;   Check whether an immutable eq?-based hash contains a key.
   (core-runtime-helper
    '$immutable-hasheq-has-key?
    "$immutable-hasheq-has-key?"
    (lambda ()
      `(func $immutable-hasheq-has-key?
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hasheq
             (param $key (ref eq)) ;; lookup key
             (result     (ref eq))
             (local $table (ref $HashEqImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheq-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (global.get $false))))
             (local.set $hash (call $eq-hash/i32 (local.get $key)))
             (if (result (ref eq))
                 (call $immutable-hamt-node-has-key?/kind
                       (i32.const 0)
                       (struct.get $HashEqImmutable $root (local.get $table))
                       (local.get $key)
                       (local.get $hash)
                       (i32.const 0))
                 (then (global.get $true))
                 (else (global.get $false))))))

   ;; immutable-hash-ref : immutable-hash? any/c any/c -> any/c
   ;;   Look up a key in an immutable equal?-based hash.
   (core-runtime-helper
    '$immutable-hash-ref
    "$immutable-hash-ref"
    (lambda ()
      `(func $immutable-hash-ref
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hash
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqualImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hash-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualImmutable) (local.get $ht)))
             (local.set $hash (call $equal-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqualImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref/kind
                                    (i32.const 2)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref/kind
                          (i32.const 2)
                          (struct.get $HashEqualImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hash-ref-key : immutable-hash? any/c any/c -> any/c
   ;;   Return the stored key matching a lookup key in an immutable equal?-based hash.
   (core-runtime-helper
    '$immutable-hash-ref-key
    "$immutable-hash-ref-key"
    (lambda ()
      `(func $immutable-hash-ref-key
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hash
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqualImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hash-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualImmutable) (local.get $ht)))
             (local.set $hash (call $equal-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqualImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref-key/kind
                                    (i32.const 2)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref-key/kind
                          (i32.const 2)
                          (struct.get $HashEqualImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hash-has-key? : immutable-hash? any/c -> boolean?
   ;;   Check whether an immutable equal?-based hash contains a key.
   (core-runtime-helper
    '$immutable-hash-has-key?
    "$immutable-hash-has-key?"
    (lambda ()
      `(func $immutable-hash-has-key?
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hash
             (param $key (ref eq)) ;; lookup key
             (result     (ref eq))
             (local $table (ref $HashEqualImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hash-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqualImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (global.get $false))))
             (local.set $hash (call $equal-hash/i32 (local.get $key)))
             (if (result (ref eq))
                 (call $immutable-hamt-node-has-key?/kind
                       (i32.const 2)
                       (struct.get $HashEqualImmutable $root (local.get $table))
                       (local.get $key)
                       (local.get $hash)
                       (i32.const 0))
                 (then (global.get $true))
                 (else (global.get $false))))))

   ;; immutable-hashalw-ref : immutable-hashalw? any/c any/c -> any/c
   ;;   Look up a key in an immutable equal-always?-based hash.
   (core-runtime-helper
    '$immutable-hashalw-ref
    "$immutable-hashalw-ref"
    (lambda ()
      `(func $immutable-hashalw-ref
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hashalw
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqualAlwaysImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hashalw-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualAlwaysImmutable) (local.get $ht)))
             (local.set $hash (call $equal-always-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqualAlwaysImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref/kind
                                    (i32.const 3)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref/kind
                          (i32.const 3)
                          (struct.get $HashEqualAlwaysImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hashalw-ref-key : immutable-hashalw? any/c any/c -> any/c
   ;;   Return the stored key matching a lookup key in an immutable equal-always?-based hash.
   (core-runtime-helper
    '$immutable-hashalw-ref-key
    "$immutable-hashalw-ref-key"
    (lambda ()
      `(func $immutable-hashalw-ref-key
             (type $Prim23)
             (param $ht      (ref eq)) ;; immutable hashalw
             (param $key     (ref eq)) ;; lookup key
             (param $failure (ref eq)) ;; optional failure, default raises
             (result         (ref eq))
             (local $table (ref $HashEqualAlwaysImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hashalw-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualAlwaysImmutable) (local.get $ht)))
             (local.set $hash (call $equal-always-hash/i32 (local.get $key)))
             (if (ref.eq (struct.get $HashEqualAlwaysImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return_call $immutable-hamt-bucket-ref-key/kind
                                    (i32.const 3)
                                    (global.get $null)
                                    (local.get $key)
                                    (local.get $failure))))
             (return_call $immutable-hamt-node-ref-key/kind
                          (i32.const 3)
                          (struct.get $HashEqualAlwaysImmutable $root (local.get $table))
                          (local.get $key)
                          (local.get $hash)
                          (i32.const 0)
                          (local.get $failure)))))

   ;; immutable-hashalw-has-key? : immutable-hashalw? any/c -> boolean?
   ;;   Check whether an immutable equal-always?-based hash contains a key.
   (core-runtime-helper
    '$immutable-hashalw-has-key?
    "$immutable-hashalw-has-key?"
    (lambda ()
      `(func $immutable-hashalw-has-key?
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hashalw
             (param $key (ref eq)) ;; lookup key
             (result     (ref eq))
             (local $table (ref $HashEqualAlwaysImmutable))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hashalw-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualAlwaysImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqualAlwaysImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (global.get $false))))
             (local.set $hash (call $equal-always-hash/i32 (local.get $key)))
             (if (result (ref eq))
                 (call $immutable-hamt-node-has-key?/kind
                       (i32.const 3)
                       (struct.get $HashEqualAlwaysImmutable $root (local.get $table))
                       (local.get $key)
                       (local.get $hash)
                       (i32.const 0))
                 (then (global.get $true))
                 (else (global.get $false))))))))

;; immutable-hash-set-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public immutable hash functional update wrappers.
(define immutable-hash-set-runtime-only-helpers
  (list
   ;; immutable-hasheqv-set : immutable-hasheqv? any/c any/c -> immutable-hasheqv?
   ;;   Functionally associate a key with a value in an immutable eqv?-based hash.
   (core-runtime-helper
    '$immutable-hasheqv-set
    "$immutable-hasheqv-set"
    (lambda ()
      `(func $immutable-hasheqv-set (type $Prim3)
             (param $ht  (ref eq)) ;; immutable hasheqv
             (param $key (ref eq)) ;; key
             (param $val (ref eq)) ;; value
             (result     (ref eq))
             (local $table     (ref $HashEqvImmutable))
             (local $root-any  (ref eq))
             (local $entry     (ref $ImmutableHashEntry))
             (local $hash      i32)
             (local $exists?   i32)
             (local $new-count i32)
             (if (i32.eqz (ref.test (ref $HashEqvImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheqv-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqvImmutable) (local.get $ht)))
             (local.set $hash (call $eqv-hash/i32 (local.get $key)))
             (local.set $entry
                        (struct.new $ImmutableHashEntry
                                    (i32.const 0)
                                    (local.get $hash)
                                    (local.get $key)
                                    (local.get $val)))
             (local.set $root-any (struct.get $HashEqvImmutable $root (local.get $table)))
             (if (ref.eq (local.get $root-any) (global.get $missing))
                 (then
                  (local.set $root-any (call $immutable-hamt-empty-node)))
                 (else
                  (local.set $exists?
                             (call $immutable-hamt-node-has-key?/kind
                                   (i32.const 1)
                                   (local.get $root-any)
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.const 0)))))
             (local.set $root-any
                        (call $immutable-hamt-node-set/kind
                              (i32.const 1)
                              (local.get $root-any)
                              (local.get $entry)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (local.set $new-count
                        (i32.add (struct.get $HashEqvImmutable $count (local.get $table))
                                 (if (result i32) (local.get $exists?)
                                     (then (i32.const 0))
                                     (else (i32.const 1)))))
             (struct.new $HashEqvImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root-any)
                         (local.get $new-count)))))

   ;; immutable-hasheq-set : immutable-hasheq? any/c any/c -> immutable-hasheq?
   ;;   Functionally associate a key with a value in an immutable eq?-based hash.
   (core-runtime-helper
    '$immutable-hasheq-set
    "$immutable-hasheq-set"
    (lambda ()
      `(func $immutable-hasheq-set (type $Prim3)
             (param $ht  (ref eq)) ;; immutable hasheq
             (param $key (ref eq)) ;; key
             (param $val (ref eq)) ;; value
             (result     (ref eq))
             (local $table     (ref $HashEqImmutable))
             (local $root-any  (ref eq))
             (local $entry     (ref $ImmutableHashEntry))
             (local $hash      i32)
             (local $exists?   i32)
             (local $new-count i32)
             (if (i32.eqz (ref.test (ref $HashEqImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheq-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqImmutable) (local.get $ht)))
             (local.set $hash (call $eq-hash/i32 (local.get $key)))
             (local.set $entry
                        (struct.new $ImmutableHashEntry
                                    (i32.const 0)
                                    (local.get $hash)
                                    (local.get $key)
                                    (local.get $val)))
             (local.set $root-any (struct.get $HashEqImmutable $root (local.get $table)))
             (if (ref.eq (local.get $root-any) (global.get $missing))
                 (then
                  (local.set $root-any (call $immutable-hamt-empty-node)))
                 (else
                  (local.set $exists?
                             (call $immutable-hamt-node-has-key?/kind
                                   (i32.const 0)
                                   (local.get $root-any)
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.const 0)))))
             (local.set $root-any
                        (call $immutable-hamt-node-set/kind
                              (i32.const 0)
                              (local.get $root-any)
                              (local.get $entry)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (local.set $new-count
                        (i32.add (struct.get $HashEqImmutable $count (local.get $table))
                                 (if (result i32) (local.get $exists?)
                                     (then (i32.const 0))
                                     (else (i32.const 1)))))
             (struct.new $HashEqImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root-any)
                         (local.get $new-count)))))

   ;; immutable-hash-set : immutable-hash? any/c any/c -> immutable-hash?
   ;;   Functionally associate a key with a value in an immutable equal?-based hash.
   (core-runtime-helper
    '$immutable-hash-set
    "$immutable-hash-set"
    (lambda ()
      `(func $immutable-hash-set (type $Prim3)
             (param $ht  (ref eq)) ;; immutable hash
             (param $key (ref eq)) ;; key
             (param $val (ref eq)) ;; value
             (result     (ref eq))
             (local $table     (ref $HashEqualImmutable))
             (local $root-any  (ref eq))
             (local $entry     (ref $ImmutableHashEntry))
             (local $hash      i32)
             (local $exists?   i32)
             (local $new-count i32)
             (if (i32.eqz (ref.test (ref $HashEqualImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hash-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualImmutable) (local.get $ht)))
             (local.set $hash (call $equal-hash/i32 (local.get $key)))
             (local.set $entry
                        (struct.new $ImmutableHashEntry
                                    (i32.const 0)
                                    (local.get $hash)
                                    (local.get $key)
                                    (local.get $val)))
             (local.set $root-any (struct.get $HashEqualImmutable $root (local.get $table)))
             (if (ref.eq (local.get $root-any) (global.get $missing))
                 (then
                  (local.set $root-any (call $immutable-hamt-empty-node)))
                 (else
                  (local.set $exists?
                             (call $immutable-hamt-node-has-key?/kind
                                   (i32.const 2)
                                   (local.get $root-any)
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.const 0)))))
             (local.set $root-any
                        (call $immutable-hamt-node-set/kind
                              (i32.const 2)
                              (local.get $root-any)
                              (local.get $entry)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (local.set $new-count
                        (i32.add (struct.get $HashEqualImmutable $count (local.get $table))
                                 (if (result i32) (local.get $exists?)
                                     (then (i32.const 0))
                                     (else (i32.const 1)))))
             (struct.new $HashEqualImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root-any)
                         (local.get $new-count)))))

   ;; immutable-hashalw-set : immutable-hashalw? any/c any/c -> immutable-hashalw?
   ;;   Functionally associate a key with a value in an immutable equal-always?-based hash.
   (core-runtime-helper
    '$immutable-hashalw-set
    "$immutable-hashalw-set"
    (lambda ()
      `(func $immutable-hashalw-set (type $Prim3)
             (param $ht  (ref eq)) ;; immutable hashalw
             (param $key (ref eq)) ;; key
             (param $val (ref eq)) ;; value
             (result     (ref eq))
             (local $table     (ref $HashEqualAlwaysImmutable))
             (local $root-any  (ref eq))
             (local $entry     (ref $ImmutableHashEntry))
             (local $hash      i32)
             (local $exists?   i32)
             (local $new-count i32)
             (if (i32.eqz (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hashalw-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualAlwaysImmutable) (local.get $ht)))
             (local.set $hash (call $equal-always-hash/i32 (local.get $key)))
             (local.set $entry
                        (struct.new $ImmutableHashEntry
                                    (i32.const 0)
                                    (local.get $hash)
                                    (local.get $key)
                                    (local.get $val)))
             (local.set $root-any (struct.get $HashEqualAlwaysImmutable $root (local.get $table)))
             (if (ref.eq (local.get $root-any) (global.get $missing))
                 (then
                  (local.set $root-any (call $immutable-hamt-empty-node)))
                 (else
                  (local.set $exists?
                             (call $immutable-hamt-node-has-key?/kind
                                   (i32.const 3)
                                   (local.get $root-any)
                                   (local.get $key)
                                   (local.get $hash)
                                   (i32.const 0)))))
             (local.set $root-any
                        (call $immutable-hamt-node-set/kind
                              (i32.const 3)
                              (local.get $root-any)
                              (local.get $entry)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (local.set $new-count
                        (i32.add (struct.get $HashEqualAlwaysImmutable $count (local.get $table))
                                 (if (result i32) (local.get $exists?)
                                     (then (i32.const 0))
                                     (else (i32.const 1)))))
             (struct.new $HashEqualAlwaysImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root-any)
                         (local.get $new-count)))))))

;; immutable-hash-remove-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public immutable hash functional remove wrappers.
(define immutable-hash-remove-runtime-only-helpers
  (list
   ;; immutable-hasheqv-remove : immutable-hasheqv? any/c -> immutable-hasheqv?
   ;;   Functionally remove a key from the private immutable hash HAMT.
   (core-runtime-helper
    '$immutable-hasheqv-remove
    "$immutable-hasheqv-remove"
    (lambda ()
      `(func $immutable-hasheqv-remove
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hasheqv
             (param $key (ref eq)) ;; key to remove
             (result     (ref eq))
             (local $table (ref $HashEqvImmutable))
             (local $root  (ref eq))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqvImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheqv-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqvImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqvImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (local.get $ht))))
             (local.set $hash (call $eqv-hash/i32 (local.get $key)))
             (local.set $root
                        (struct.get $HashEqvImmutable $root (local.get $table)))
             (if (i32.eqz
                  (call $immutable-hamt-node-has-key?/kind
                        (i32.const 1)
                        (local.get $root)
                        (local.get $key)
                        (local.get $hash)
                        (i32.const 0)))
                 (then (return (local.get $ht))))
             (if (i32.eq (struct.get $HashEqvImmutable $count (local.get $table))
                         (i32.const 1))
                 (then (return (call $make-empty-immutable-hasheqv))))
             (local.set $root
                        (call $immutable-hamt-node-remove/kind
                              (i32.const 1)
                              (local.get $root)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (struct.new $HashEqvImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root)
                         (i32.sub (struct.get $HashEqvImmutable $count
                                              (local.get $table))
                                  (i32.const 1))))))

   ;; immutable-hasheq-remove : immutable-hasheq? any/c -> immutable-hasheq?
   ;;   Functionally remove a key from an immutable eq?-based hash.
   (core-runtime-helper
    '$immutable-hasheq-remove
    "$immutable-hasheq-remove"
    (lambda ()
      `(func $immutable-hasheq-remove
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hasheq
             (param $key (ref eq)) ;; key to remove
             (result     (ref eq))
             (local $table (ref $HashEqImmutable))
             (local $root  (ref eq))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hasheq-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (local.get $ht))))
             (local.set $hash (call $eq-hash/i32 (local.get $key)))
             (local.set $root
                        (struct.get $HashEqImmutable $root (local.get $table)))
             (if (i32.eqz
                  (call $immutable-hamt-node-has-key?/kind
                        (i32.const 0)
                        (local.get $root)
                        (local.get $key)
                        (local.get $hash)
                        (i32.const 0)))
                 (then (return (local.get $ht))))
             (if (i32.eq (struct.get $HashEqImmutable $count (local.get $table))
                         (i32.const 1))
                 (then (return (call $make-empty-immutable-hasheq))))
             (local.set $root
                        (call $immutable-hamt-node-remove/kind
                              (i32.const 0)
                              (local.get $root)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (struct.new $HashEqImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root)
                         (i32.sub (struct.get $HashEqImmutable $count
                                              (local.get $table))
                                  (i32.const 1))))))

   ;; immutable-hash-remove : immutable-hash? any/c -> immutable-hash?
   ;;   Functionally remove a key from an immutable equal?-based hash.
   (core-runtime-helper
    '$immutable-hash-remove
    "$immutable-hash-remove"
    (lambda ()
      `(func $immutable-hash-remove
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hash
             (param $key (ref eq)) ;; key to remove
             (result     (ref eq))
             (local $table (ref $HashEqualImmutable))
             (local $root  (ref eq))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hash-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqualImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (local.get $ht))))
             (local.set $hash (call $equal-hash/i32 (local.get $key)))
             (local.set $root
                        (struct.get $HashEqualImmutable $root (local.get $table)))
             (if (i32.eqz
                  (call $immutable-hamt-node-has-key?/kind
                        (i32.const 2)
                        (local.get $root)
                        (local.get $key)
                        (local.get $hash)
                        (i32.const 0)))
                 (then (return (local.get $ht))))
             (if (i32.eq (struct.get $HashEqualImmutable $count (local.get $table))
                         (i32.const 1))
                 (then (return (call $make-empty-immutable-hash))))
             (local.set $root
                        (call $immutable-hamt-node-remove/kind
                              (i32.const 2)
                              (local.get $root)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (struct.new $HashEqualImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root)
                         (i32.sub (struct.get $HashEqualImmutable $count
                                              (local.get $table))
                                  (i32.const 1))))))

   ;; immutable-hashalw-remove : immutable-hashalw? any/c -> immutable-hashalw?
   ;;   Functionally remove a key from an immutable equal-always?-based hash.
   (core-runtime-helper
    '$immutable-hashalw-remove
    "$immutable-hashalw-remove"
    (lambda ()
      `(func $immutable-hashalw-remove
             (type $Prim2)
             (param $ht  (ref eq)) ;; immutable hashalw
             (param $key (ref eq)) ;; key to remove
             (result     (ref eq))
             (local $table (ref $HashEqualAlwaysImmutable))
             (local $root  (ref eq))
             (local $hash  i32)
             (if (i32.eqz (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht)))
                 (then (call $raise-argument-error:hashalw-expected (local.get $ht))
                       (unreachable)))
             (local.set $table (ref.cast (ref $HashEqualAlwaysImmutable) (local.get $ht)))
             (if (ref.eq (struct.get $HashEqualAlwaysImmutable $root (local.get $table))
                         (global.get $missing))
                 (then (return (local.get $ht))))
             (local.set $hash (call $equal-always-hash/i32 (local.get $key)))
             (local.set $root
                        (struct.get $HashEqualAlwaysImmutable $root (local.get $table)))
             (if (i32.eqz
                  (call $immutable-hamt-node-has-key?/kind
                        (i32.const 3)
                        (local.get $root)
                        (local.get $key)
                        (local.get $hash)
                        (i32.const 0)))
                 (then (return (local.get $ht))))
             (if (i32.eq (struct.get $HashEqualAlwaysImmutable $count (local.get $table))
                         (i32.const 1))
                 (then (return (call $make-empty-immutable-hashalw))))
             (local.set $root
                        (call $immutable-hamt-node-remove/kind
                              (i32.const 3)
                              (local.get $root)
                              (local.get $key)
                              (local.get $hash)
                              (i32.const 0)))
             (struct.new $HashEqualAlwaysImmutable
                         (i32.const 0)
                         (global.get $false)
                         (local.get $root)
                         (i32.sub (struct.get $HashEqualAlwaysImmutable $count
                                              (local.get $table))
                                  (i32.const 1))))))))

;; immutable-hash-public-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for public immutable hash wrappers.
(define immutable-hash-public-runtime-only-helper-names
  '($hash-set
    $hash-remove
    $hash-update
    $hash-clear))

;; immutable-hash-public-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public immutable hash functional operation wrappers.
(define immutable-hash-public-runtime-only-helpers
  (function-forms->runtime-helpers
   'immutable-hash-public-runtime-only-helpers
   '(
         ;; hash-set : immutable-hash? any/c any/c -> immutable-hash?
         ;;   Functionally update an immutable hash through the wrapper's key
         ;;   comparison and hash-code strategy.
         (func $hash-set (type $Prim3)
               (param $ht  (ref eq)) ;; immutable hash table
               (param $key (ref eq)) ;; key
               (param $val (ref eq)) ;; value
               (result     (ref eq))
               (call $debug-allocation-tick (i32.const 3))
               (if (i32.eqz (call $immutable-hash-leaf?/i32 (local.get $ht)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-set)
                               (global.get $string:immutable-hash?)
                               (local.get $ht))
                         (unreachable)))
               (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                   (then (return (call $immutable-hasheq-set
                                       (local.get $ht)
                                       (local.get $key)
                                       (local.get $val)))))
               (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                   (then (return (call $immutable-hasheqv-set
                                       (local.get $ht)
                                       (local.get $key)
                                       (local.get $val)))))
               (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                   (then (return (call $immutable-hash-set
                                       (local.get $ht)
                                       (local.get $key)
                                       (local.get $val)))))
               (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                   (then (return (call $immutable-hashalw-set
                                       (local.get $ht)
                                       (local.get $key)
                                       (local.get $val)))))
               (call $raise-argument-error1
                     (global.get $symbol:hash-set)
                     (global.get $string:immutable-hash?)
                     (local.get $ht))
               (unreachable))

         ;; hash-remove : immutable-hash? any/c -> immutable-hash?
         ;;   Functionally remove a key from an immutable hash through the
         ;;   wrapper's key comparison and hash-code strategy.
         (func $hash-remove (type $Prim2)
               (param $ht  (ref eq)) ;; immutable hash table
               (param $key (ref eq)) ;; key
               (result     (ref eq))
               (if (i32.eqz (call $immutable-hash-leaf?/i32 (local.get $ht)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-remove)
                               (global.get $string:immutable-hash?)
                               (local.get $ht))
                         (unreachable)))
               (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                   (then (return (call $immutable-hasheq-remove
                                       (local.get $ht)
                                       (local.get $key)))))
               (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                   (then (return (call $immutable-hasheqv-remove
                                       (local.get $ht)
                                       (local.get $key)))))
               (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                   (then (return (call $immutable-hash-remove
                                       (local.get $ht)
                                       (local.get $key)))))
               (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                   (then (return (call $immutable-hashalw-remove
                                       (local.get $ht)
                                       (local.get $key)))))
               (call $raise-argument-error1
                     (global.get $symbol:hash-remove)
                     (global.get $string:immutable-hash?)
                     (local.get $ht))
               (unreachable))

         ;; hash-update : immutable-hash? any/c (any/c -> any/c) [any/c or (-> any/c)] -> immutable-hash?
         ;;   Functionally update an immutable hash. The optional failure
         ;;   argument defaults to $missing, which makes hash-ref raise when
         ;;   the key is absent.
         (func $hash-update (type $Prim34)
               (param $ht   (ref eq)) ;; immutable hash table
               (param $key  (ref eq)) ;; key
               (param $proc (ref eq)) ;; updater procedure
               (param $fail (ref eq)) ;; optional failure/default, default = raises
               (result      (ref eq))

               (local $f         (ref $Procedure))
               (local $finv      (ref $ProcedureInvoker))
               (local $args      (ref $Args))
               (local $old-value (ref eq))
               (local $new-value (ref eq))

               (if (i32.eqz (call $immutable-hash-leaf?/i32 (local.get $ht)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-update)
                               (global.get $string:immutable-hash?)
                               (local.get $ht))
                         (unreachable)))
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-update)
                               (global.get $string:hash-update-procedure)
                               (local.get $proc))
                         (unreachable)))
               (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $f)
                                  (i32.const 1)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-update)
                               (global.get $string:hash-update-procedure)
                               (local.get $proc))
                         (unreachable)))

               (local.set $old-value
                          (call $hash-ref
                                (local.get $ht)
                                (local.get $key)
                                (local.get $fail)))
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
               (local.set $args (array.new $Args (global.get $null) (i32.const 1)))
               (array.set $Args (local.get $args) (i32.const 0) (local.get $old-value))
               (local.set $new-value
                          (call_ref $ProcedureInvoker
                                    (local.get $f)
                                    (local.get $args)
                                    (local.get $finv)))
               (call $hash-set
                     (local.get $ht)
                     (local.get $key)
                     (local.get $new-value)))

         ;; hash-clear : immutable-hash? -> immutable-hash?
         ;;   Functionally clear immutable hashes. Chaperone/impersonator
         ;;   traversal is not implemented; WebRacket returns a fresh empty
         ;;   hash with the same comparison wrapper.
         (func $hash-clear (type $Prim1)
               (param $ht (ref eq)) ;; immutable hash table
               (result    (ref eq))
               (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-clear)
                               (global.get $string:immutable-hash?)
                               (local.get $ht))
                         (unreachable)))
               (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                   (then (return (call $make-empty-immutable-hasheq))))
               (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                   (then (return (call $make-empty-immutable-hasheqv))))
               (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                   (then (return (call $make-empty-immutable-hash))))
               (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                   (then (return (call $make-empty-immutable-hashalw))))
               (call $raise-argument-error1
                     (global.get $symbol:hash-clear)
                     (global.get $string:immutable-hash?)
                     (local.get $ht))
               (unreachable)))))

;; immutable-hash-varargs-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash constructors that consume alternating rest arguments.
(define immutable-hash-varargs-constructor-runtime-only-helpers
  (list
   (core-runtime-helper
    '$raise-hash-constructor-odd-arguments
    "$raise-hash-constructor-odd-arguments"
    (lambda ()
      `(func $raise-hash-constructor-odd-arguments
             (param $who (ref eq))
             (param $key (ref eq))
             (local $out     (ref $GrowableArray))
             (local $message (ref $String))
             (local.set $out (call $make-growable-array (i32.const 3)))
             (call $growable-array-add! (local.get $out)
                   (call $format/display (local.get $who)))
             (call $growable-array-add! (local.get $out)
                   (global.get $string:hash-constructor:key-without-value))
             (call $growable-array-add! (local.get $out)
                   (call $format/display (local.get $key)))
             (local.set $message
                        (call $growable-array-of-strings->string (local.get $out)))
             (call $raise
                   (call $exn:fail:contract/make
                         (local.get $message)
                         (call $current-continuation-marks (global.get $missing)))
                   (global.get $true))
             (unreachable))))

   ;; hash : any/c any/c ... -> immutable-hash?
   ;;   Build an immutable hash from alternating keys and values.
   (core-runtime-helper
    '$hash
    "$hash"
    (lambda ()
      `(func $hash (type $Prim>=0)
             (param $args (ref eq)) ;; rest arguments as a list
             (result      (ref eq))
             (local $args* (ref eq))
             (local $pair  (ref $Pair))
             (local $key   (ref eq))
             (local $val   (ref eq))
             (local $ht    (ref eq))
             (local.set $args* (local.get $args))
             (local.set $ht (call $make-empty-immutable-hash))
             (block $done
                    (loop $loop
                          (br_if $done (ref.eq (local.get $args*) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hash)
                                          (local.get $args*))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $args*)))
                          (local.set $key (struct.get $Pair $a (local.get $pair)))
                          (local.set $args* (struct.get $Pair $d (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hash)
                                          (local.get $key))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $args*)))
                          (local.set $val (struct.get $Pair $a (local.get $pair)))
                          (local.set $args* (struct.get $Pair $d (local.get $pair)))
                          (local.set $ht
                                     (call $immutable-hash-set
                                           (local.get $ht)
                                           (local.get $key)
                                           (local.get $val)))
                          (br $loop)))
             (local.get $ht))))

   ;; hasheq : any/c any/c ... -> immutable-hasheq?
   ;;   Build an immutable eq?-based hash from alternating keys and
   ;;   values using the system-stencil HAMT root.
   (core-runtime-helper
    '$hasheq
    "$hasheq"
    (lambda ()
      `(func $hasheq (type $Prim>=0)
             (param $args (ref eq)) ;; rest arguments as a list
             (result      (ref eq))
             (local $ht   (ref eq))
             (local $node (ref eq))
             (local $pair (ref $Pair))
             (local $key  (ref eq))
             (local $val  (ref eq))
             (local.set $ht   (call $make-empty-immutable-hasheq))
             (local.set $node (local.get $args))
             (block $done
                    (loop $walk
                          (br_if $done (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hasheq)
                                          (local.get $node))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $key (struct.get $Pair $a (local.get $pair)))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hasheq)
                                          (local.get $key))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $val (struct.get $Pair $a (local.get $pair)))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (local.set $ht (call $immutable-hasheq-set
                                               (local.get $ht)
                                               (local.get $key)
                                               (local.get $val)))
                          (br $walk)))
             (local.get $ht))))

   ;; hashalw : any/c any/c ... -> immutable-hashalw?
   ;;   Build an immutable equal-always?-based hash from alternating keys
   ;;   and values. It uses equal-always-hash/i32 for bucket selection,
   ;;   so mutable subvalues hash by identity.
   (core-runtime-helper
    '$hashalw
    "$hashalw"
    (lambda ()
      `(func $hashalw (type $Prim>=0)
             (param $args (ref eq)) ;; rest arguments as a list
             (result      (ref eq))
             (local $ht   (ref eq))
             (local $node (ref eq))
             (local $pair (ref $Pair))
             (local $key  (ref eq))
             (local $val  (ref eq))
             (local.set $ht   (call $make-empty-immutable-hashalw))
             (local.set $node (local.get $args))
             (block $done
                    (loop $walk
                          (br_if $done (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hashalw)
                                          (local.get $node))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $key (struct.get $Pair $a (local.get $pair)))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hashalw)
                                          (local.get $key))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $val (struct.get $Pair $a (local.get $pair)))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (local.set $ht (call $immutable-hashalw-set
                                               (local.get $ht)
                                               (local.get $key)
                                               (local.get $val)))
                          (br $walk)))
             (local.get $ht))))

   ;; hasheqv : any/c any/c ... -> immutable-hasheqv?
   ;;   Build an immutable eqv?-based hash from alternating keys and values.
   (core-runtime-helper
    '$hasheqv
    "$hasheqv"
    (lambda ()
      `(func $hasheqv (type $Prim>=0)
             (param $args (ref eq)) ;; rest arguments as a list
             (result      (ref eq))
             (local $ht   (ref eq))
             (local $node (ref eq))
             (local $pair (ref $Pair))
             (local $key  (ref eq))
             (local $val  (ref eq))
             (local.set $ht   (call $make-empty-immutable-hasheqv))
             (local.set $node (local.get $args))
             (block $done
                    (loop $walk
                          (br_if $done (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hasheqv)
                                          (local.get $node))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $key (struct.get $Pair $a (local.get $pair)))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (call $raise-hash-constructor-odd-arguments
                                          (global.get $symbol:hasheqv)
                                          (local.get $key))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (local.set $val (struct.get $Pair $a (local.get $pair)))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (local.set $ht (call $immutable-hasheqv-set
                                               (local.get $ht)
                                               (local.get $key)
                                               (local.get $val)))
                          (br $walk)))
             (local.get $ht))))))

;; immutable-hash-alist-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash constructors that consume association lists.
(define immutable-hash-alist-constructor-runtime-only-helpers
  (list
   ;; make-immutable-hash : [(listof pair?) = null] -> immutable-hash?
   ;;   Build an immutable equal?-hash from an association list. This
   ;;   currently uses the shared HAMT backing store described above.
   (core-runtime-helper
    '$make-immutable-hash
    "$make-immutable-hash"
    (lambda ()
      `(func $make-immutable-hash (type $Prim01)
             (param $assocs (ref eq)) ;; optional association list, default null
             (result        (ref eq))
             (local $ht    (ref eq))
             (local $alist (ref eq))
             (local $pair  (ref $Pair))
             (local $kv    (ref eq))
             (local $kvp   (ref $Pair))
             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (local.set $ht (call $make-empty-immutable-hash))
             (local.set $alist (local.get $assocs))
             (block $done
                    (loop $walk
                          (br_if $done (ref.eq (local.get $alist) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $alist)))
                              (then (call $raise-argument-error:pair-expected1
                                          (global.get $symbol:make-immutable-hash)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $alist)))
                          (local.set $kv (struct.get $Pair $a (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $kv)))
                              (then (call $raise-argument-error:pair-expected2
                                          (global.get $symbol:make-immutable-hash)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $kvp (ref.cast (ref $Pair) (local.get $kv)))
                          (local.set $ht (call $immutable-hash-set
                                               (local.get $ht)
                                               (struct.get $Pair $a (local.get $kvp))
                                               (struct.get $Pair $d (local.get $kvp))))
                          (local.set $alist (struct.get $Pair $d (local.get $pair)))
                          (br $walk)))
             (local.get $ht))))

   ;; make-immutable-hashalw : [(listof pair?) = null] -> immutable-hashalw?
   ;;   Build an immutable equal-always?-hash from an association list.
   (core-runtime-helper
    '$make-immutable-hashalw
    "$make-immutable-hashalw"
    (lambda ()
      `(func $make-immutable-hashalw (type $Prim01)
             (param $assocs (ref eq)) ;; optional association list, default null
             (result        (ref eq))
             (local $ht    (ref eq))
             (local $alist (ref eq))
             (local $pair  (ref $Pair))
             (local $kv    (ref eq))
             (local $kvp   (ref $Pair))
             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (local.set $ht (call $make-empty-immutable-hashalw))
             (local.set $alist (local.get $assocs))
             (block $done
                    (loop $walk
                          (br_if $done (ref.eq (local.get $alist) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $alist)))
                              (then (call $raise-argument-error:pair-expected1
                                          (global.get $symbol:make-immutable-hashalw)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $alist)))
                          (local.set $kv (struct.get $Pair $a (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $kv)))
                              (then (call $raise-argument-error:pair-expected2
                                          (global.get $symbol:make-immutable-hashalw)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $kvp (ref.cast (ref $Pair) (local.get $kv)))
                          (local.set $ht (call $immutable-hashalw-set
                                               (local.get $ht)
                                               (struct.get $Pair $a (local.get $kvp))
                                               (struct.get $Pair $d (local.get $kvp))))
                          (local.set $alist (struct.get $Pair $d (local.get $pair)))
                          (br $walk)))
             (local.get $ht))))

   ;; make-immutable-hasheq : [(listof pair?) = null] -> immutable-hasheq?
   ;;   Build an immutable eq?-hash from an association list.
   (core-runtime-helper
    '$make-immutable-hasheq
    "$make-immutable-hasheq"
    (lambda ()
      `(func $make-immutable-hasheq (type $Prim01)
             (param $assocs (ref eq)) ;; optional association list, default null
             (result        (ref eq))
             (local $ht    (ref eq))
             (local $alist (ref eq))
             (local $pair  (ref $Pair))
             (local $kv    (ref eq))
             (local $kvp   (ref $Pair))
             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (local.set $ht (call $make-empty-immutable-hasheq))
             (local.set $alist (local.get $assocs))
             (block $done
                    (loop $walk
                          (br_if $done (ref.eq (local.get $alist) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $alist)))
                              (then (call $raise-argument-error:pair-expected1
                                          (global.get $symbol:make-immutable-hasheq)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $alist)))
                          (local.set $kv (struct.get $Pair $a (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $kv)))
                              (then (call $raise-argument-error:pair-expected2
                                          (global.get $symbol:make-immutable-hasheq)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $kvp (ref.cast (ref $Pair) (local.get $kv)))
                          (local.set $ht (call $immutable-hasheq-set
                                               (local.get $ht)
                                               (struct.get $Pair $a (local.get $kvp))
                                               (struct.get $Pair $d (local.get $kvp))))
                          (local.set $alist (struct.get $Pair $d (local.get $pair)))
                          (br $walk)))
             (local.get $ht))))

   ;; make-immutable-hasheqv : [(listof pair?)] -> immutable-hasheqv?
   ;;   Build an immutable eqv?-based hash from an association list. The
   ;;   optional list defaults to empty.
   (core-runtime-helper
    '$make-immutable-hasheqv
    "$make-immutable-hasheqv"
    (lambda ()
      `(func $make-immutable-hasheqv (type $Prim01)
             (param $assocs (ref eq)) ;; optional association list, default null
             (result        (ref eq))
             (local $ht    (ref eq))
             (local $alist (ref eq))
             (local $pair  (ref $Pair))
             (local $kv    (ref eq))
             (local $kvp   (ref $Pair))
             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (local.set $ht (call $make-empty-immutable-hasheqv))
             (local.set $alist (local.get $assocs))
             (block $done
                    (loop $walk
                          (br_if $done (ref.eq (local.get $alist) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $alist)))
                              (then (call $raise-argument-error:pair-expected1
                                          (global.get $symbol:make-immutable-hasheqv)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $alist)))
                          (local.set $kv (struct.get $Pair $a (local.get $pair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $kv)))
                              (then (call $raise-argument-error:pair-expected2
                                          (global.get $symbol:make-immutable-hasheqv)
                                          (local.get $assocs))
                                    (unreachable)))
                          (local.set $kvp (ref.cast (ref $Pair) (local.get $kv)))
                          (local.set $ht (call $immutable-hasheqv-set
                                               (local.get $ht)
                                               (struct.get $Pair $a (local.get $kvp))
                                               (struct.get $Pair $d (local.get $kvp))))
                          (local.set $alist (struct.get $Pair $d (local.get $pair)))
                          (br $walk)))
             (local.get $ht))))))

;; immutable-hash-iteration-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash iteration and HAMT traversal helpers.
(define immutable-hash-iteration-runtime-only-helpers
  (function-forms->runtime-helpers
   'immutable-hash-iteration-runtime-only-helpers
   '(
        ;; unsafe-immutable-hash-iterate-* : immutable hash iteration
        ;;   Racket CS exposes these as unsafe primitives for iterating
        ;;   immutable hashes. WebRacket's immutable hashes share a compact
        ;;   root-node representation, so all immutable hash kinds are wrapped
        ;;   as a temporary $HashEqvImmutable and walked by the helpers below.
        ;;   The iteration position is a private list cursor. This keeps
        ;;   iteration independent of whether a root slot holds a bucket or a
        ;;   recursive HAMT child node.
	        (func $immutable-hash-as-hasheqv
	              (param $ht (ref eq)) ;; immutable hash table
	              (result    (ref $HashEqvImmutable))

              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then
                   (return
                    (struct.new $HashEqvImmutable
                                (i32.const 0)
                                (global.get $false)
                                (struct.get $HashEqImmutable $root
                                            (ref.cast (ref $HashEqImmutable)
                                                      (local.get $ht)))
                                (struct.get $HashEqImmutable $count
                                            (ref.cast (ref $HashEqImmutable)
                                                      (local.get $ht)))))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (ref.cast (ref $HashEqvImmutable) (local.get $ht)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then
                   (return
                    (struct.new $HashEqvImmutable
                                (i32.const 0)
                                (global.get $false)
                                (struct.get $HashEqualImmutable $root
                                            (ref.cast (ref $HashEqualImmutable)
                                                      (local.get $ht)))
                                (struct.get $HashEqualImmutable $count
                                            (ref.cast (ref $HashEqualImmutable)
                                                      (local.get $ht)))))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then
                   (return
                    (struct.new $HashEqvImmutable
                                (i32.const 0)
                                (global.get $false)
                                (struct.get $HashEqualAlwaysImmutable $root
                                            (ref.cast (ref $HashEqualAlwaysImmutable)
                                                      (local.get $ht)))
                                (struct.get $HashEqualAlwaysImmutable $count
                                            (ref.cast (ref $HashEqualAlwaysImmutable)
                                                      (local.get $ht)))))))
	              (call $raise-argument-error:hash-expected (local.get $ht))
	              (unreachable))

        ;; immutable-hamt-packed-node->entries : packed-bnode acc -> list?
        ;;   Collect entries from a physical packed bnode.
        (func $immutable-hamt-packed-node->entries
              (param $sv  (ref $StencilVector))
              (param $acc (ref eq))
              (result     (ref eq))
              (local $metadata  i32)
              (local $group     i32)
              (local $child-bit i32)
              (local $key-bit   i32)
              (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
              (local.set $group (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $group) (i32.const 8)))
                           (local.set $child-bit
                                      (call $immutable-hamt-packed-child-bit
                                            (local.get $group)
                                            (i32.const 0)))
                           (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                                       (i32.const 0))
                               (then
                                (local.set $acc
                                           (call $immutable-hamt-node->entries
                                                 (call $immutable-hamt-packed-slot
                                                       (local.get $sv)
                                                       (local.get $child-bit))
                                                 (local.get $acc)))))
                           (local.set $key-bit
                                      (call $immutable-hamt-packed-key-bit
                                            (local.get $group)
                                            (i32.const 0)))
                           (if (i32.ne (i32.and (local.get $metadata) (local.get $key-bit))
                                       (i32.const 0))
                               (then
                                (local.set $acc
                                           (call $cons
                                                 (struct.new $ImmutableHashEntry
                                                             (i32.const 0)
                                                             (call $immutable-hamt-inline-key-cached-hash
                                                                   (call $immutable-hamt-packed-slot
                                                                         (local.get $sv)
                                                                         (local.get $key-bit)))
                                                             (call $immutable-hamt-inline-key-unwrap
                                                                   (call $immutable-hamt-packed-slot
                                                                         (local.get $sv)
                                                                         (local.get $key-bit)))
                                                             (call $immutable-hamt-packed-slot
                                                                   (local.get $sv)
                                                                   (call $immutable-hamt-packed-value-bit
                                                                         (local.get $group)
                                                                         (i32.const 0))))
                                                 (local.get $acc)))))
                           (local.set $group (i32.add (local.get $group) (i32.const 1)))
                           (br $loop)))
              (local.get $acc))

        ;; immutable-hamt-packed-node-entry-count : packed-bnode -> exact-nonnegative-integer?
        ;;   Count inline entries and recursive child entries in a physical packed bnode.
        (func $immutable-hamt-packed-node-entry-count
              (param $sv (ref $StencilVector))
              (result    i32)
              (local $metadata  i32)
              (local $group     i32)
              (local $child-bit i32)
              (local $key-bit   i32)
              (local $count     i32)
              (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
              (local.set $group (i32.const 0))
              (local.set $count (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $group) (i32.const 8)))
                           (local.set $child-bit
                                      (call $immutable-hamt-packed-child-bit
                                            (local.get $group)
                                            (i32.const 0)))
                           (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                                       (i32.const 0))
                               (then
                                (local.set $count
                                           (i32.add
                                            (local.get $count)
                                            (call $immutable-hamt-node-entry-count
                                                  (call $immutable-hamt-packed-slot
                                                        (local.get $sv)
                                                        (local.get $child-bit)))))))
                           (local.set $key-bit
                                      (call $immutable-hamt-packed-key-bit
                                            (local.get $group)
                                            (i32.const 0)))
                           (if (i32.ne (i32.and (local.get $metadata) (local.get $key-bit))
                                       (i32.const 0))
                               (then
                                (local.set $count (i32.add (local.get $count) (i32.const 1)))))
                           (local.set $group (i32.add (local.get $group) (i32.const 1)))
                           (br $loop)))
              (local.get $count))

        ;; immutable-hamt-packed-node-child-count : packed-bnode counter-id -> exact-nonnegative-integer?
        ;;   Count recursive child shapes in a physical packed bnode.
        (func $immutable-hamt-packed-node-child-count
              (param $sv      (ref $StencilVector))
              (param $counter i32) ;; 0=bnodes, 1=cnodes, 2=buckets, 3=inlines, 4=slots
              (result         i32)
              (local $metadata  i32)
              (local $group     i32)
              (local $child-bit i32)
              (local $key-bit   i32)
              (local $count     i32)
              (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
              (local.set $group (i32.const 0))
              (local.set $count
                         (if (result i32)
                             (i32.eq (local.get $counter) (i32.const 0))
                             (then (i32.const 1))
                             (else
                              (if (result i32)
                                  (i32.eq (local.get $counter) (i32.const 4))
                                  (then
                                   ;; Do not count the static marker slot.
                                   (i32.sub (i32.popcnt (local.get $metadata)) (i32.const 1)))
                                  (else (i32.const 0))))))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $group) (i32.const 8)))
                           (local.set $child-bit
                                      (call $immutable-hamt-packed-child-bit
                                            (local.get $group)
                                            (i32.const 0)))
                           (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                                       (i32.const 0))
                               (then
                                (local.set $count
                                           (i32.add
                                            (local.get $count)
                                            (if (result i32)
                                                (i32.eq (local.get $counter) (i32.const 0))
                                                (then
                                                 (call $immutable-hamt-node-bnode-count
                                                       (call $immutable-hamt-packed-slot
                                                             (local.get $sv)
                                                             (local.get $child-bit))))
                                                (else
                                                 (if (result i32)
                                                     (i32.eq (local.get $counter) (i32.const 1))
                                                     (then
                                                      (call $immutable-hamt-node-cnode-count
                                                            (call $immutable-hamt-packed-slot
                                                                  (local.get $sv)
                                                                  (local.get $child-bit))))
                                                     (else
                                                      (if (result i32)
                                                          (i32.eq (local.get $counter) (i32.const 2))
                                                          (then
                                                           (call $immutable-hamt-node-bucket-count
                                                                 (call $immutable-hamt-packed-slot
                                                                       (local.get $sv)
                                                                       (local.get $child-bit))))
                                                          (else
                                                           (if (result i32)
                                                               (i32.eq (local.get $counter) (i32.const 3))
                                                               (then
                                                                (call $immutable-hamt-node-inline-count
                                                                      (call $immutable-hamt-packed-slot
                                                                            (local.get $sv)
                                                                            (local.get $child-bit))))
                                                               (else
                                                                (call $immutable-hamt-node-slot-count
                                                                      (call $immutable-hamt-packed-slot
                                                                            (local.get $sv)
                                                                            (local.get $child-bit)))))))))))))))
                           (local.set $key-bit
                                      (call $immutable-hamt-packed-key-bit
                                            (local.get $group)
                                            (i32.const 0)))
                           (if (i32.and
                                (i32.eq (local.get $counter) (i32.const 3))
                                (i32.ne (i32.and (local.get $metadata) (local.get $key-bit))
                                        (i32.const 0)))
                               (then
                                (local.set $count (i32.add (local.get $count) (i32.const 1)))))
                           (local.set $group (i32.add (local.get $group) (i32.const 1)))
                           (br $loop)))
              (local.get $count))

        ;; immutable-hamt-packed-node-max-depth : packed-bnode depth -> exact-nonnegative-integer?
        ;;   Return max depth through physical child slots.
        (func $immutable-hamt-packed-node-max-depth
              (param $sv    (ref $StencilVector))
              (param $depth i32)
              (result       i32)
              (local $metadata  i32)
              (local $group     i32)
              (local $child-bit i32)
              (local $max       i32)
              (local $child     i32)
              (local.set $metadata (call $immutable-hamt-bnode-metadata (local.get $sv)))
              (local.set $group (i32.const 0))
              (local.set $max (local.get $depth))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $group) (i32.const 8)))
                           (local.set $child-bit
                                      (call $immutable-hamt-packed-child-bit
                                            (local.get $group)
                                            (i32.const 0)))
                           (if (i32.ne (i32.and (local.get $metadata) (local.get $child-bit))
                                       (i32.const 0))
                               (then
                                (local.set $child
                                           (call $immutable-hamt-node-max-depth
                                                 (call $immutable-hamt-packed-slot
                                                       (local.get $sv)
                                                       (local.get $child-bit))
                                                 (i32.add (local.get $depth) (i32.const 1))))
                                (if (i32.gt_u (local.get $child) (local.get $max))
                                    (then (local.set $max (local.get $child))))))
                           (local.set $group (i32.add (local.get $group) (i32.const 1)))
                           (br $loop)))
              (local.get $max))

	        (func $immutable-hamt-node->entries
	              (param $node (ref eq)) ;; root/child stencil vector or entry bucket
              (param $acc  (ref eq)) ;; accumulated entry list
              (result      (ref eq))
              (local $sv     (ref $StencilVector))
              (local $slots  (ref $Array))
              (local $len    i32)
              (local $i      i32)
              (local $slot   (ref eq))
              (local $bucket (ref eq))
              (local $pair   (ref $Pair))
              (if (ref.test (ref $ImmutableHashEntry) (local.get $node))
                  (then
                   (return_call $cons
                                (local.get $node)
                                (local.get $acc))))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then
                   (return_call $immutable-hamt-node->entries
                                (struct.get $ImmutableHashCNode $content
                                            (ref.cast (ref $ImmutableHashCNode)
                                                      (local.get $node)))
                                (local.get $acc))))
              (if (ref.test (ref $StencilVector) (local.get $node))
	                  (then
	                   (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	                   (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                       (then
	                        (return_call $immutable-hamt-packed-node->entries
	                                     (local.get $sv)
	                                     (local.get $acc))))
	                   (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
                   (local.set $len   (array.len (local.get $slots)))
                   (local.set $i     (i32.const 0))
                   (block $done-slots
                          (loop $slot-loop
                                (br_if $done-slots
                                       (i32.ge_u (local.get $i) (local.get $len)))
                                (local.set $slot
                                           (array.get $Array
                                                      (local.get $slots)
                                                      (local.get $i)))
                                (local.set $acc
                                           (call $immutable-hamt-node->entries
                                                 (local.get $slot)
                                                 (local.get $acc)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $slot-loop)))
                   (return (local.get $acc))))
              (local.set $bucket (local.get $node))
              (block $done-bucket
                     (loop $bucket-loop
                           (br_if $done-bucket
                                  (ref.eq (local.get $bucket) (global.get $null)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $bucket)))
                               (then (br $done-bucket)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $bucket)))
                           (if (ref.test (ref $ImmutableHashEntry)
                                         (struct.get $Pair $a (local.get $pair)))
                               (then
                                (local.set $acc
                                           (call $cons
                                                 (struct.get $Pair $a (local.get $pair))
                                                 (local.get $acc)))))
                           (local.set $bucket (struct.get $Pair $d (local.get $pair)))
                           (br $bucket-loop)))
              (local.get $acc))

        ;; immutable-hamt-node-entry-count : any/c -> exact-nonnegative-integer?
        ;;   Count immutable hash entries reachable from a private HAMT node.
        (func $immutable-hamt-node-entry-count
              (param $node (ref eq)) ;; root/child stencil vector, cnode, or entry bucket
              (result      i32)
              (local $sv     (ref $StencilVector))
              (local $slots  (ref $Array))
              (local $len    i32)
              (local $i      i32)
              (local $count  i32)
              (local $slot   (ref eq))
              (local $bucket (ref eq))
              (local $pair   (ref $Pair))
              (if (ref.test (ref $ImmutableHashEntry) (local.get $node))
                  (then (return (i32.const 1))))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then
                   (return_call $immutable-hamt-node-entry-count
                                (struct.get $ImmutableHashCNode $content
                                            (ref.cast (ref $ImmutableHashCNode)
                                                      (local.get $node))))))
              (if (ref.test (ref $StencilVector) (local.get $node))
	                  (then
	                   (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	                   (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                       (then
	                        (return_call $immutable-hamt-packed-node-entry-count
	                                     (local.get $sv))))
	                   (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
                   (local.set $len   (array.len (local.get $slots)))
                   (local.set $i     (i32.const 0))
                   (local.set $count (i32.const 0))
                   (block $done-slots
                          (loop $slot-loop
                                (br_if $done-slots
                                       (i32.ge_u (local.get $i) (local.get $len)))
                                (local.set $slot
                                           (array.get $Array
                                                      (local.get $slots)
                                                      (local.get $i)))
                                (local.set $count
                                           (i32.add
                                            (local.get $count)
                                            (call $immutable-hamt-node-entry-count
                                                  (local.get $slot))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $slot-loop)))
                   (return (local.get $count))))
              (local.set $bucket (local.get $node))
              (local.set $count  (i32.const 0))
              (block $done-bucket
                     (loop $bucket-loop
                           (br_if $done-bucket
                                  (ref.eq (local.get $bucket) (global.get $null)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $bucket)))
                               (then (br $done-bucket)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $bucket)))
                           (if (ref.test (ref $ImmutableHashEntry)
                                         (struct.get $Pair $a (local.get $pair)))
                               (then
                                (local.set $count
                                           (i32.add (local.get $count) (i32.const 1)))))
                           (local.set $bucket (struct.get $Pair $d (local.get $pair)))
                           (br $bucket-loop)))
              (local.get $count))

        ;; immutable-hamt-node-bnode-count : any/c -> exact-nonnegative-integer?
        ;;   Count recursive bnodes in a private HAMT node.
        (func $immutable-hamt-node-bnode-count
              (param $node (ref eq)) ;; root/child stencil vector, cnode, or entry bucket
              (result      i32)
              (local $sv    (ref $StencilVector))
              (local $slots (ref $Array))
              (local $len   i32)
              (local $i     i32)
              (local $count i32)
              (local $slot  (ref eq))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then (return (i32.const 0))))
              (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                  (then (return (i32.const 0))))
	              (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	              (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                  (then
	                   (return_call $immutable-hamt-packed-node-child-count
	                                (local.get $sv)
	                                (i32.const 0))))
	              (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
              (local.set $len   (array.len (local.get $slots)))
              (local.set $i     (i32.const 0))
              (local.set $count (i32.const 1))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                           (local.set $slot
                                      (array.get $Array
                                                 (local.get $slots)
                                                 (local.get $i)))
                           (local.set $count
                                      (i32.add
                                       (local.get $count)
                                       (call $immutable-hamt-node-bnode-count
                                             (local.get $slot))))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              (local.get $count))

        ;; immutable-hamt-node-cnode-count : any/c -> exact-nonnegative-integer?
        ;;   Count terminal collision nodes in a private HAMT node.
        (func $immutable-hamt-node-cnode-count
              (param $node (ref eq)) ;; root/child stencil vector, cnode, or entry bucket
              (result      i32)
              (local $sv    (ref $StencilVector))
              (local $slots (ref $Array))
              (local $len   i32)
              (local $i     i32)
              (local $count i32)
              (local $slot  (ref eq))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then (return (i32.const 1))))
              (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                  (then (return (i32.const 0))))
	              (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	              (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                  (then
	                   (return_call $immutable-hamt-packed-node-child-count
	                                (local.get $sv)
	                                (i32.const 1))))
	              (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
              (local.set $len   (array.len (local.get $slots)))
              (local.set $i     (i32.const 0))
              (local.set $count (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                           (local.set $slot
                                      (array.get $Array
                                                 (local.get $slots)
                                                 (local.get $i)))
                           (local.set $count
                                      (i32.add
                                       (local.get $count)
                                       (call $immutable-hamt-node-cnode-count
                                             (local.get $slot))))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              (local.get $count))

         ;; immutable-hamt-node-bucket-count : any/c -> exact-nonnegative-integer?
         ;;   Count non-empty ordinary entry buckets in a private HAMT node.
         (func $immutable-hamt-node-bucket-count
              (param $node (ref eq)) ;; root/child stencil vector, cnode, or entry bucket
              (result      i32)
              (local $sv    (ref $StencilVector))
              (local $slots (ref $Array))
              (local $len   i32)
              (local $i     i32)
              (local $count i32)
              (local $slot  (ref eq))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then (return (i32.const 0))))
              (if (ref.test (ref $ImmutableHashEntry) (local.get $node))
                  (then (return (i32.const 0))))
              (if (ref.test (ref $StencilVector) (local.get $node))
	                  (then
	                   (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	                   (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                       (then
	                        (return_call $immutable-hamt-packed-node-child-count
	                                     (local.get $sv)
	                                     (i32.const 2))))
	                   (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
                   (local.set $len   (array.len (local.get $slots)))
                   (local.set $i     (i32.const 0))
                   (local.set $count (i32.const 0))
                   (block $done
                          (loop $loop
                                (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                (local.set $slot
                                           (array.get $Array
                                                      (local.get $slots)
                                                      (local.get $i)))
                                (local.set $count
                                           (i32.add
                                            (local.get $count)
                                            (call $immutable-hamt-node-bucket-count
                                                  (local.get $slot))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $loop)))
                   (return (local.get $count))))
              (if (ref.test (ref $Pair) (local.get $node))
                  (then (return (i32.const 1))))
              (i32.const 0))

        ;; immutable-hamt-node-inline-count : any/c -> exact-nonnegative-integer?
        ;;   Count direct inline entry leaves in a private HAMT node.
        (func $immutable-hamt-node-inline-count
              (param $node (ref eq)) ;; root/child stencil vector, cnode, or entry bucket
              (result      i32)
              (local $sv    (ref $StencilVector))
              (local $slots (ref $Array))
              (local $len   i32)
              (local $i     i32)
              (local $count i32)
              (local $slot  (ref eq))
              (if (ref.test (ref $ImmutableHashEntry) (local.get $node))
                  (then (return (i32.const 1))))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then (return (i32.const 0))))
              (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                  (then (return (i32.const 0))))
	              (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	              (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                  (then
	                   (return_call $immutable-hamt-packed-node-child-count
	                                (local.get $sv)
	                                (i32.const 3))))
	              (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
              (local.set $len   (array.len (local.get $slots)))
              (local.set $i     (i32.const 0))
              (local.set $count (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                           (local.set $slot
                                      (array.get $Array
                                                 (local.get $slots)
                                                 (local.get $i)))
                           (local.set $count
                                      (i32.add
                                       (local.get $count)
                                       (call $immutable-hamt-node-inline-count
                                             (local.get $slot))))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              (local.get $count))

        ;; immutable-hamt-node-slot-count : any/c -> exact-nonnegative-integer?
        ;;   Count dense slots stored in bnode stencil vectors.
        (func $immutable-hamt-node-slot-count
              (param $node (ref eq)) ;; root/child stencil vector, cnode, or entry bucket
              (result      i32)
              (local $sv    (ref $StencilVector))
              (local $slots (ref $Array))
              (local $len   i32)
              (local $i     i32)
              (local $count i32)
              (local $slot  (ref eq))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then (return (i32.const 0))))
              (if (ref.test (ref $ImmutableHashEntry) (local.get $node))
                  (then (return (i32.const 0))))
              (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                  (then (return (i32.const 0))))
	              (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	              (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                  (then
	                   (return_call $immutable-hamt-packed-node-child-count
	                                (local.get $sv)
	                                (i32.const 4))))
	              (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
              (local.set $len   (array.len (local.get $slots)))
              (local.set $i     (i32.const 0))
              (local.set $count (local.get $len))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                           (local.set $slot
                                      (array.get $Array
                                                 (local.get $slots)
                                                 (local.get $i)))
                           (local.set $count
                                      (i32.add
                                       (local.get $count)
                                       (call $immutable-hamt-node-slot-count
                                             (local.get $slot))))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              (local.get $count))

        ;; immutable-hamt-node-max-depth : any/c exact-nonnegative-integer? -> exact-nonnegative-integer?
        ;;   Return the deepest bnode/cnode/bucket depth in a private HAMT node.
        (func $immutable-hamt-node-max-depth
              (param $node  (ref eq)) ;; root/child stencil vector, cnode, or entry bucket
              (param $depth i32)      ;; current node depth
              (result       i32)
              (local $sv    (ref $StencilVector))
              (local $slots (ref $Array))
              (local $len   i32)
              (local $i     i32)
              (local $max   i32)
              (local $child i32)
              (local $slot  (ref eq))
              (if (ref.test (ref $ImmutableHashCNode) (local.get $node))
                  (then (return (local.get $depth))))
              (if (i32.eqz (ref.test (ref $StencilVector) (local.get $node)))
                  (then
                   (if (ref.test (ref $ImmutableHashEntry) (local.get $node))
                       (then (return (local.get $depth))))
                   (if (ref.test (ref $Pair) (local.get $node))
                       (then (return (local.get $depth))))
                   (return (i32.const 0))))
	              (local.set $sv    (ref.cast (ref $StencilVector) (local.get $node)))
	              (if (call $immutable-hamt-packed-bnode? (local.get $sv))
	                  (then
	                   (return_call $immutable-hamt-packed-node-max-depth
	                                (local.get $sv)
	                                (local.get $depth))))
	              (local.set $slots (struct.get $StencilVector $slots (local.get $sv)))
              (local.set $len   (array.len (local.get $slots)))
              (local.set $i     (i32.const 0))
              (local.set $max   (local.get $depth))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                           (local.set $slot
                                      (array.get $Array
                                                 (local.get $slots)
                                                 (local.get $i)))
                           (local.set $child
                                      (call $immutable-hamt-node-max-depth
                                            (local.get $slot)
                                            (i32.add (local.get $depth) (i32.const 1))))
                           (if (i32.gt_u (local.get $child) (local.get $max))
                               (then (local.set $max (local.get $child))))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              (local.get $max))

        ;; immutable-hash-debug-shape : hash? -> list?
        ;;   Internal-only HAMT shape probe: (entries bnodes cnodes buckets inlines max-depth slots).
        (func $immutable-hash-debug-shape (type $Prim1)
              (param $ht (ref eq)) ;; immutable hash table
              (result    (ref eq))
              (local $view (ref $HashEqvImmutable))
              (local $root (ref eq))
              (local $entries i32)
              (local $bnodes  i32)
              (local $cnodes  i32)
              (local $buckets i32)
              (local $inlines i32)
              (local $depth   i32)
              (local $slots   i32)
              (local.set $view (call $immutable-hash-as-hasheqv (local.get $ht)))
              (local.set $root (struct.get $HashEqvImmutable $root (local.get $view)))
              (block $has-root
                     (br_if $has-root
                            (i32.eqz (ref.eq (local.get $root) (global.get $missing))))
                     (return
                      (call $cons
                            (ref.i31 (i32.const 0))
                            (call $cons
                                  (ref.i31 (i32.const 0))
                                  (call $cons
                                        (ref.i31 (i32.const 0))
                                        (call $cons
                                              (ref.i31 (i32.const 0))
                                              (call $cons
                                                    (ref.i31 (i32.const 0))
                                                    (call $cons
                                                          (ref.i31 (i32.const 0))
                                                          (call $cons
                                                                (ref.i31 (i32.const 0))
                                                                (global.get $null))))))))))
              (local.set $entries (call $immutable-hamt-node-entry-count (local.get $root)))
              (local.set $bnodes  (call $immutable-hamt-node-bnode-count  (local.get $root)))
              (local.set $cnodes  (call $immutable-hamt-node-cnode-count  (local.get $root)))
              (local.set $buckets (call $immutable-hamt-node-bucket-count (local.get $root)))
              (local.set $inlines (call $immutable-hamt-node-inline-count (local.get $root)))
              (local.set $depth   (call $immutable-hamt-node-max-depth
                                        (local.get $root)
                                        (i32.const 0)))
              (local.set $slots   (call $immutable-hamt-node-slot-count   (local.get $root)))
              (call $cons
                    (ref.i31 (i32.shl (local.get $entries) (i32.const 1)))
                    (call $cons
                          (ref.i31 (i32.shl (local.get $bnodes) (i32.const 1)))
                          (call $cons
                                (ref.i31 (i32.shl (local.get $cnodes) (i32.const 1)))
                                (call $cons
                                      (ref.i31 (i32.shl (local.get $buckets) (i32.const 1)))
                                      (call $cons
                                            (ref.i31 (i32.shl (local.get $inlines) (i32.const 1)))
                                            (call $cons
                                                  (ref.i31 (i32.shl (local.get $depth) (i32.const 1)))
                                                  (call $cons
                                                        (ref.i31 (i32.shl (local.get $slots) (i32.const 1)))
                                                        (global.get $null)))))))))

        ;; immutable-hash-root-metadata : hash? -> exact-nonnegative-integer?
        ;;   Internal-only probe for the stored packed metadata word at the root.
        (func $immutable-hash-root-metadata (type $Prim1)
              (param $ht (ref eq)) ;; immutable hash table
              (result    (ref eq))
              (local $view (ref $HashEqvImmutable))
              (local $root (ref eq))
              (local.set $view (call $immutable-hash-as-hasheqv (local.get $ht)))
              (local.set $root (struct.get $HashEqvImmutable $root (local.get $view)))
              (if (i32.eqz (ref.test (ref $StencilVector) (local.get $root)))
                  (then (return (ref.i31 (i32.const 0)))))
              (ref.i31
               (i32.shl
                (call $immutable-hamt-bnode-metadata
                      (ref.cast (ref $StencilVector) (local.get $root)))
                (i32.const 1))))

        (func $immutable-hasheqv-iterate-first
              (param $table (ref $HashEqvImmutable)) ;; immutable hash table
              (result       (ref eq))
              (local $root-any (ref eq))
              (local $entries  (ref eq))

              (local.set $root-any (struct.get $HashEqvImmutable $root (local.get $table)))
              (if (ref.eq (local.get $root-any) (global.get $missing))
                  (then (return (global.get $false))))
              (local.set $entries
                         (call $immutable-hamt-node->entries
                               (local.get $root-any)
                               (global.get $null)))
              (if (ref.eq (local.get $entries) (global.get $null))
                  (then (return (global.get $false))))
              (local.get $entries))

        (func $immutable-hasheqv-iterate-entry
              (param $table     (ref $HashEqvImmutable)) ;; immutable hash table
              (param $who       (ref eq))                ;; public iterator accessor name
              (param $pos       (ref eq))                ;; private list cursor
              (param $bad-index (ref eq))                ;; optional bad-index value, default = raise
              (result           (ref eq))                ;; entry or bad-index result
              (local $pair  (ref $Pair))
              (local $entry (ref eq))

              (block $bad
                     (if (ref.eq (struct.get $HashEqvImmutable $root (local.get $table))
                                 (global.get $missing))
                         (then (br $bad)))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $pos)))
                         (then (br $bad)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $pos)))
                     (local.set $entry (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $ImmutableHashEntry)
                                            (local.get $entry)))
                         (then (br $bad)))
                     (return (local.get $entry)))
              (if (ref.eq (local.get $bad-index) (global.get $missing))
                  (then (call $raise-mutable-hash-iterate-bad-index
                              (local.get $who)
                              (local.get $pos))
                        (unreachable)))
              (local.get $bad-index))

        (func $immutable-hasheqv-iterate-next
              (param $table (ref $HashEqvImmutable)) ;; immutable hash table
              (param $pos   (ref eq))                ;; private list cursor
              (result       (ref eq))
              (local $pair (ref $Pair))
              (local $rest (ref eq))

              (drop (call $immutable-hasheqv-iterate-entry
                          (local.get $table)
                          (global.get $symbol:hash-iterate-next)
                          (local.get $pos)
                          (global.get $missing)))
              (local.set $pair (ref.cast (ref $Pair) (local.get $pos)))
              (local.set $rest (struct.get $Pair $d (local.get $pair)))
              (if (ref.test (ref $Pair) (local.get $rest))
                  (then (return (local.get $rest))))
              (global.get $false))

        ;; immutable-hash-iterate-index->entry/public : hash? exact-nonnegative-integer? [any/c] -> entry-or-bad
        ;;   Resolve a public exact-nonnegative integer iterator index for an immutable hash.
        (func $immutable-hash-iterate-index->entry/public
              (param $ht        (ref eq)) ;; immutable hash table
              (param $who       (ref eq)) ;; public iterator accessor name
              (param $pos       (ref eq)) ;; public iteration index
              (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
              (result           (ref eq))
              (local $view    (ref $HashEqvImmutable))
              (local $entries (ref eq))
              (local $pair    (ref $Pair))
              (local $index   i32)
              (local.set $view (call $immutable-hash-as-hasheqv (local.get $ht)))
              ;; Decode and validate position before considering bad-index.
              (if (ref.eq (call $exact-nonnegative-integer? (local.get $pos))
                          (global.get $false))
                  (then (call $raise-exact-nonnegative-integer-expected/who
                              (local.get $who)
                              (local.get $pos))
                        (unreachable)))
              (local.set $index
                         (if (result i32)
                             (ref.test (ref i31) (local.get $pos))
                             (then
                              (call $exact-nonnegative-integer->i32/saturating
                                    (local.get $pos)))
                             (else
                              ;; Bignum positions satisfy the contract, then
                              ;; fall through to the invalid-index path below.
                              (i32.const 536870911))))
              (block $bad
                     (if (ref.eq (struct.get $HashEqvImmutable $root (local.get $view))
                                 (global.get $missing))
                         (then (br $bad)))
                     (if (i32.ge_u (local.get $index)
                                   (struct.get $HashEqvImmutable $count (local.get $view)))
                         (then (br $bad)))
                     (local.set $entries
                                (call $immutable-hamt-node->entries
                                      (struct.get $HashEqvImmutable $root (local.get $view))
                                      (global.get $null)))
                     (block $found
                            (loop $walk
                                  (br_if $bad
                                         (i32.eqz (ref.test (ref $Pair)
                                                            (local.get $entries))))
                                  (if (i32.eqz (local.get $index))
                                      (then (br $found)))
                                  (local.set $pair (ref.cast (ref $Pair)
                                                             (local.get $entries)))
                                  (local.set $entries (struct.get $Pair $d
                                                                   (local.get $pair)))
                                  (local.set $index (i32.sub (local.get $index)
                                                             (i32.const 1)))
                                  (br $walk)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $entries)))
                     (return (struct.get $Pair $a (local.get $pair))))
              (if (ref.eq (local.get $bad-index) (global.get $missing))
                  (then (call $raise-mutable-hash-iterate-bad-index
                              (local.get $who)
                              (local.get $pos))
                        (unreachable)))
              (local.get $bad-index))

        ;; immutable-hash-iterate-first/public : hash? -> (or/c #f exact-nonnegative-integer?)
        ;;   Public immutable hash iterator first index.
        (func $immutable-hash-iterate-first/public (type $Prim1)
              (param $ht (ref eq)) ;; immutable hash table
              (result    (ref eq))
              (local $view (ref $HashEqvImmutable))
              (local.set $view (call $immutable-hash-as-hasheqv (local.get $ht)))
              (if (i32.eqz (struct.get $HashEqvImmutable $count (local.get $view)))
                  (then (return (global.get $false))))
              (ref.i31 (i32.const 0)))

        ;; immutable-hash-iterate-next/public : hash? exact-nonnegative-integer? -> (or/c #f exact-nonnegative-integer?)
        ;;   Public immutable hash iterator successor index.
        (func $immutable-hash-iterate-next/public (type $Prim2)
              (param $ht  (ref eq)) ;; immutable hash table
              (param $pos (ref eq)) ;; public iteration index
              (result     (ref eq))
              (local $view  (ref $HashEqvImmutable))
              (local $index i32)
              (local.set $view (call $immutable-hash-as-hasheqv (local.get $ht)))
              ;; Decode and validate position.
              (if (ref.eq (call $exact-nonnegative-integer? (local.get $pos))
                          (global.get $false))
                  (then (call $raise-exact-nonnegative-integer-expected/who
                              (global.get $symbol:hash-iterate-next)
                              (local.get $pos))
                        (unreachable)))
              (local.set $index
                         (if (result i32)
                             (ref.test (ref i31) (local.get $pos))
                             (then
                              (call $exact-nonnegative-integer->i32/saturating
                                    (local.get $pos)))
                             (else
                              (i32.const 536870911))))
              (local.set $index (i32.add (local.get $index) (i32.const 1)))
              (if (i32.ge_u (local.get $index)
                            (struct.get $HashEqvImmutable $count (local.get $view)))
                  (then (return (global.get $false))))
              (ref.i31 (i32.shl (local.get $index) (i32.const 1))))

        ;; immutable-hash-iterate-key/public : hash? exact-nonnegative-integer? [any/c] -> any/c
        ;;   Public immutable hash iterator key accessor.
        (func $immutable-hash-iterate-key/public (type $Prim23)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; public iteration index
              (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
              (result           (ref eq))
              (local $entry (ref eq))
              (local.set $entry
                         (call $immutable-hash-iterate-index->entry/public
                               (local.get $ht)
                               (global.get $symbol:hash-iterate-key)
                               (local.get $pos)
                               (local.get $bad-index)))
              (if (i32.eqz (ref.test (ref $ImmutableHashEntry) (local.get $entry)))
                  (then (return (local.get $entry))))
              (struct.get $ImmutableHashEntry $key
                          (ref.cast (ref $ImmutableHashEntry) (local.get $entry))))

        ;; immutable-hash-iterate-value/public : hash? exact-nonnegative-integer? [any/c] -> any/c
        ;;   Public immutable hash iterator value accessor.
        (func $immutable-hash-iterate-value/public (type $Prim23)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; public iteration index
              (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
              (result           (ref eq))
              (local $entry (ref eq))
              (local.set $entry
                         (call $immutable-hash-iterate-index->entry/public
                               (local.get $ht)
                               (global.get $symbol:hash-iterate-value)
                               (local.get $pos)
                               (local.get $bad-index)))
              (if (i32.eqz (ref.test (ref $ImmutableHashEntry) (local.get $entry)))
                  (then (return (local.get $entry))))
              (struct.get $ImmutableHashEntry $value
                          (ref.cast (ref $ImmutableHashEntry) (local.get $entry))))

        ;; immutable-hash-iterate-pair/public : hash? exact-nonnegative-integer? [any/c] -> pair?
        ;;   Public immutable hash iterator pair accessor.
        (func $immutable-hash-iterate-pair/public (type $Prim23)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; public iteration index
              (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
              (result           (ref eq))
              (local $entry (ref eq))
              (local.set $entry
                         (call $immutable-hash-iterate-index->entry/public
                               (local.get $ht)
                               (global.get $symbol:hash-iterate-pair)
                               (local.get $pos)
                               (local.get $bad-index)))
              (if (i32.eqz (ref.test (ref $ImmutableHashEntry) (local.get $entry)))
                  (then
                   (return (call $cons (local.get $entry) (local.get $entry)))))
              (call $cons
                    (struct.get $ImmutableHashEntry $key
                                (ref.cast (ref $ImmutableHashEntry) (local.get $entry)))
                    (struct.get $ImmutableHashEntry $value
                                (ref.cast (ref $ImmutableHashEntry) (local.get $entry)))))

        ;; immutable-hash-iterate-key+value/public : hash? exact-nonnegative-integer? [any/c] -> values
        ;;   Public immutable hash iterator key/value accessor.
        (func $immutable-hash-iterate-key+value/public (type $Prim23)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; public iteration index
              (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
              (result           (ref eq))
              (local $entry (ref eq))
              (local.set $entry
                         (call $immutable-hash-iterate-index->entry/public
                               (local.get $ht)
                               (global.get $symbol:hash-iterate-key+value)
                               (local.get $pos)
                               (local.get $bad-index)))
              (if (i32.eqz (ref.test (ref $ImmutableHashEntry) (local.get $entry)))
                  (then
                   (return (array.new_fixed $Values 2
                                            (local.get $entry)
                                            (local.get $entry)))))
              (array.new_fixed $Values 2
                               (struct.get $ImmutableHashEntry $key
                                           (ref.cast (ref $ImmutableHashEntry)
                                                     (local.get $entry)))
                               (struct.get $ImmutableHashEntry $value
                                           (ref.cast (ref $ImmutableHashEntry)
                                                     (local.get $entry)))))

        (func $unsafe-immutable-hash-iterate-first (type $Prim1)
              (param $ht (ref eq)) ;; immutable hash table
              (result    (ref eq))
              (return_call $immutable-hasheqv-iterate-first
                           (call $immutable-hash-as-hasheqv (local.get $ht))))

        (func $unsafe-immutable-hash-iterate-next (type $Prim2)
              (param $ht  (ref eq)) ;; immutable hash table
              (param $pos (ref eq)) ;; packed iteration position
              (result     (ref eq))
              (return_call $immutable-hasheqv-iterate-next
                           (call $immutable-hash-as-hasheqv (local.get $ht))
                           (local.get $pos)))

        (func $unsafe-immutable-hash-iterate-key (type $Prim2)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; packed iteration position
              (result           (ref eq))
              (local $entry (ref $ImmutableHashEntry))
              (local.set $entry
                         (ref.cast (ref $ImmutableHashEntry)
                                   (call $immutable-hasheqv-iterate-entry
                                         (call $immutable-hash-as-hasheqv (local.get $ht))
                                         (global.get $symbol:hash-iterate-key)
                                         (local.get $pos)
                                         (global.get $missing))))
              (struct.get $ImmutableHashEntry $key (local.get $entry)))

        (func $unsafe-immutable-hash-iterate-value (type $Prim2)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; packed iteration position
              (result           (ref eq))
              (local $entry (ref $ImmutableHashEntry))
              (local.set $entry
                         (ref.cast (ref $ImmutableHashEntry)
                                   (call $immutable-hasheqv-iterate-entry
                                         (call $immutable-hash-as-hasheqv (local.get $ht))
                                         (global.get $symbol:hash-iterate-value)
                                         (local.get $pos)
                                         (global.get $missing))))
              (struct.get $ImmutableHashEntry $value (local.get $entry)))

        (func $unsafe-immutable-hash-iterate-pair (type $Prim2)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; packed iteration position
              (result           (ref eq))
              (local $entry (ref $ImmutableHashEntry))
              (local.set $entry
                         (ref.cast (ref $ImmutableHashEntry)
                                   (call $immutable-hasheqv-iterate-entry
                                         (call $immutable-hash-as-hasheqv (local.get $ht))
                                         (global.get $symbol:hash-iterate-pair)
                                         (local.get $pos)
                                         (global.get $missing))))
              (call $cons
                    (struct.get $ImmutableHashEntry $key (local.get $entry))
                    (struct.get $ImmutableHashEntry $value (local.get $entry))))

        (func $unsafe-immutable-hash-iterate-key+value (type $Prim2)
              (param $ht        (ref eq)) ;; immutable hash table
              (param $pos       (ref eq)) ;; packed iteration position
              (result           (ref eq)) ;; returns two values encoded in $Values
              (local $entry (ref $ImmutableHashEntry))
              (local.set $entry
                         (ref.cast (ref $ImmutableHashEntry)
                                   (call $immutable-hasheqv-iterate-entry
                                         (call $immutable-hash-as-hasheqv (local.get $ht))
                                         (global.get $symbol:hash-iterate-key+value)
                                         (local.get $pos)
                                         (global.get $missing))))
              (array.new_fixed $Values 2
                               (struct.get $ImmutableHashEntry $key (local.get $entry))
                               (struct.get $ImmutableHashEntry $value (local.get $entry))))

     )))

;; weak-ephemeron-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate weak-hash and ephemeron fallbacks backed by strong tables.
(define weak-ephemeron-hash-runtime-only-helpers
  (list
   ; NOTE - TODO - These "weak" hash tables are dummies.
   ;             - They simply call the constructors of
   ;               the non-weak hash table constructors.
   (core-runtime-helper
    '$make-weak-hash
    "$make-weak-hash"
    (lambda ()
      `(func $make-weak-hash (type $Prim01) ; one optional argument
             (param $assocs (ref eq))
             (result        (ref eq))

             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (call $make-hash/who
                   (global.get $symbol:make-weak-hash)
                   (local.get $assocs)))))

   (core-runtime-helper
    '$make-weak-hasheq
    "$make-weak-hasheq"
    (lambda ()
      `(func $make-weak-hasheq (type $Prim01) ; one optional argument
             (param $assocs (ref eq))
             (result        (ref eq))

             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (call $make-hasheq/who
                   (global.get $symbol:make-weak-hasheq)
                   (local.get $assocs)))))

   ;; make-ephemeron-hasheq : [(listof pair?) = null] -> mutable-hasheq?
   ;;   Strong fallback. WebRacket does not have ephemeron/weak GC hooks
   ;;   yet, so expander intern tables use an ordinary mutable hasheq.
   (core-runtime-helper
    '$make-ephemeron-hasheq
    "$make-ephemeron-hasheq"
    (lambda ()
      `(func $make-ephemeron-hasheq (type $Prim01)
             (param $assocs (ref eq)) ;; optional association list, default null
             (result        (ref eq))

             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (call $make-hasheq/who
                   (global.get $symbol:make-ephemeron-hasheq)
                   (local.get $assocs)))))

   ;; make-ephemeron : any/c any/c -> ephemeron?
   ;;   Strong fallback. WebRacket keeps the key/value strongly because
   ;;   Wasm GC does not expose Racket-style weak/ephemeron hooks yet.
   (core-runtime-helper
    '$make-ephemeron
    "$make-ephemeron"
    (lambda ()
      `(func $make-ephemeron (type $Prim2)
             (param $key (ref eq)) ;; ephemeron key
             (param $val (ref eq)) ;; ephemeron value
             (result     (ref eq))
             (struct.new $Ephemeron
                         (i32.const 0)
                         (local.get $key)
                         (local.get $val)))))

   ;; ephemeron? : any/c -> boolean?
   ;;   Predicate for WebRacket's strong ephemeron fallback values.
   (core-runtime-helper
    '$ephemeron?
    "$ephemeron?"
    (lambda ()
      `(func $ephemeron? (type $Prim1)
             (param $v (ref eq)) ;; candidate value
             (result   (ref eq))
             (if (result (ref eq)) (ref.test (ref $Ephemeron) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))

   ;; ephemeron-value : ephemeron? [any/c = #f] [any/c = #f] -> any/c
   ;;   Return the strongly retained value; gced-v and retain-v are ignored.
   (core-runtime-helper
    '$ephemeron-value
    "$ephemeron-value"
    (lambda ()
      `(func $ephemeron-value (type $Prim13)
             (param $e        (ref eq)) ;; ephemeron
             (param $gced-v   (ref eq)) ;; optional fallback, ignored
             (param $retain-v (ref eq)) ;; optional retain value, ignored
             (result          (ref eq))
             (if (i32.eqz (ref.test (ref $Ephemeron) (local.get $e)))
                 (then (call $raise-argument-error1
                             (ref.cast (ref $Symbol) (global.get $symbol:ephemeron-value))
                             (ref.cast (ref $String) (global.get $string:ephemeron?))
                             (local.get $e))))
             (struct.get $Ephemeron $value
                         (ref.cast (ref $Ephemeron) (local.get $e))))))

   (core-runtime-helper
    '$make-weak-hasheqv
    "$make-weak-hasheqv"
    (lambda ()
      `(func $make-weak-hasheqv (type $Prim01) ; one optional argument
             (param $assocs (ref eq))
             (result        (ref eq))

             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (call $make-hasheqv/who
                   (global.get $symbol:make-weak-hasheqv)
                   (local.get $assocs)))))

   (core-runtime-helper
    '$make-weak-hashalw
    "$make-weak-hashalw"
    (lambda ()
      `(func $make-weak-hashalw (type $Prim01) ; one optional argument
             (param $assocs (ref eq))
             (result        (ref eq))

             (if (ref.eq (local.get $assocs) (global.get $missing))
                 (then (local.set $assocs (global.get $null))))
             (call $make-hashalw/who
                   (global.get $symbol:make-weak-hashalw)
                   (local.get $assocs)))))))

;; immutable-hash-core-runtime-helper-names : (listof symbol?)
;;   Name immutable hash helpers available in the standalone core runtime.
(define immutable-hash-core-runtime-helper-names
  '($make-empty-immutable-hasheq
    $make-empty-immutable-hasheqv
    $make-empty-immutable-hash
    $make-empty-immutable-hashalw
    $hash-placeholder?
    $placeholder?
    $make-placeholder
    $reader-graph-resolve
    $make-hash-placeholder/kind
    $make-hash-placeholder
    $make-hasheq-placeholder
    $make-hasheqv-placeholder
    $make-hashalw-placeholder
    $immutable-hasheqv-bucket-index
    $immutable-hamt-packed-group-index
    $immutable-hamt-packed-child-bit
    $immutable-hamt-packed-key-bit
    $immutable-hamt-packed-value-bit
    $immutable-hamt-packed-bits
    $immutable-hamt-slot-kind
    $immutable-hamt-bnode-packed-metadata
    $immutable-hamt-store-bnode-metadata
    $immutable-hamt-bnode-metadata
    $immutable-hamt-packed-bnode?
    $immutable-hamt-packed-index
    $immutable-hamt-packed-slot
    $immutable-hamt-packed-child-slot
    $immutable-hamt-packed-key-slot
    $immutable-hamt-packed-value-slot
    $immutable-hamt-empty-packed-node
    $immutable-hamt-store-packed-bnode-metadata
    $immutable-hamt-key-hash/kind
    $immutable-hamt-wrap-inline-key/kind
    $immutable-hamt-inline-key-unwrap
    $immutable-hamt-inline-key-cached-hash
    $immutable-hamt-entry-for-key/kind
    $immutable-hamt-packed-metadata-present?/i32
    $immutable-hasheqv-bucket-has-key?
    $immutable-hasheqv-bucket-ref-key
    $immutable-hasheq-bucket-has-key?
    $immutable-hasheq-bucket-ref-key
    $immutable-hamt-bit
    $immutable-hamt-bucket-ref-key/kind
    $immutable-hamt-bucket-has-key?/kind
    $immutable-hamt-packed-node-ref-key/kind
    $immutable-hamt-packed-node-has-key?/kind
    $immutable-hamt-packed-node-set/kind
    $immutable-hamt-packed-bnode-collapse-if-single/kind
    $immutable-hamt-packed-node-remove/kind
    $immutable-hamt-node-ref-key/kind
    $immutable-hamt-node-has-key?/kind
    $immutable-hamt-empty-node
    $immutable-hamt-bnode-collapse-if-single
    $immutable-hamt-bucket-length
    $immutable-hamt-bucket-first-entry
    $immutable-hamt-collapse-small-bucket
    $immutable-hamt-bucket-remove/kind
    $immutable-hamt-cnode-ref-key/kind
    $immutable-hamt-cnode-has-key?/kind
    $immutable-hamt-cnode-set/kind
    $immutable-hamt-cnode-remove/kind
    $immutable-hamt-bucket->cnode
    $immutable-hamt-bucket->node/kind
    $immutable-hamt-node-set/kind
    $immutable-hamt-node-remove/kind
    $immutable-hash-bucket-has-key?
    $immutable-hash-bucket-ref-key
    $immutable-hashalw-bucket-has-key?
    $immutable-hashalw-bucket-ref-key
    $immutable-hasheqv-set
    $immutable-hasheq-set
    $immutable-hash-set
    $immutable-hashalw-set
    $hash-set
    $hash-clear
    $raise-hash-constructor-odd-arguments
    $immutable-hamt-packed-node->entries
    $immutable-hamt-packed-node-entry-count
    $immutable-hamt-packed-node-child-count
    $immutable-hamt-packed-node-max-depth
    $immutable-hamt-node->entries
    $immutable-hamt-node-entry-count
    $immutable-hamt-node-bnode-count
    $immutable-hamt-node-cnode-count
    $immutable-hamt-node-bucket-count
    $immutable-hamt-node-inline-count
    $immutable-hamt-node-slot-count
    $immutable-hamt-node-max-depth
    $immutable-hasheqv-iterate-first
    $immutable-hash-iterate-index->entry/public
    $immutable-hash-iterate-first/public
    $immutable-hash-iterate-next/public
    $immutable-hash-iterate-key/public
    $immutable-hash-iterate-value/public
    $immutable-hash-iterate-pair/public
    $immutable-hash-iterate-key+value/public
    $unsafe-immutable-hash-iterate-first
    $unsafe-immutable-hash-iterate-next
    $unsafe-immutable-hash-iterate-key
    $unsafe-immutable-hash-iterate-value
    $unsafe-immutable-hash-iterate-pair
    $unsafe-immutable-hash-iterate-key+value
    $make-ephemeron
    $ephemeron?))

;; immutable-hash-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash helpers in monolithic runtime order.
(define immutable-hash-all-runtime-helpers
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
          immutable-hash-equal-bucket-runtime-only-helpers
          immutable-hash-lookup-runtime-only-helpers
          immutable-hash-set-runtime-only-helpers
          immutable-hash-remove-runtime-only-helpers
          immutable-hash-public-runtime-only-helpers
          immutable-hash-varargs-constructor-runtime-only-helpers
          immutable-hash-alist-constructor-runtime-only-helpers
          immutable-hash-iteration-runtime-only-helpers
          weak-ephemeron-hash-runtime-only-helpers))

;; immutable-hash-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash helpers available in the standalone core runtime.
(define immutable-hash-core-runtime-helpers
  (select-runtime-helpers immutable-hash-all-runtime-helpers
                          immutable-hash-core-runtime-helper-names))

;; immutable-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash helpers that still depend on monolithic runtime globals.
(define immutable-hash-runtime-only-helpers
  (remove-runtime-helpers immutable-hash-all-runtime-helpers
                          immutable-hash-core-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define immutable-hash-helper-index
    (make-core-runtime-helper-index
     (append immutable-hash-core-runtime-helpers
             immutable-hash-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name immutable-hash-core-runtime-helpers)
   immutable-hash-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (immutable-hash-prelude-runtime-helper-forms immutable-hash-helper-index))
   (append immutable-hash-constructor-runtime-only-helper-names
           immutable-hash-prelude-runtime-only-helper-names))

  (check-equal?
   (map form-name
        (immutable-hash-public-set/remove-runtime-helper-forms immutable-hash-helper-index))
   immutable-hash-public-set/remove-runtime-helper-names)

  (check-equal?
   (map form-name
        (immutable-hash-public-update-runtime-helper-forms immutable-hash-helper-index))
   immutable-hash-public-update-runtime-helper-names)

  (check-equal?
   (map form-name
        (immutable-hash-public-clear-runtime-helper-forms immutable-hash-helper-index))
   immutable-hash-public-clear-runtime-helper-names)

  (check-equal?
   (map form-name
        (immutable-hash-iteration-runtime-helper-forms immutable-hash-helper-index))
   immutable-hash-iteration-runtime-only-helper-names))
