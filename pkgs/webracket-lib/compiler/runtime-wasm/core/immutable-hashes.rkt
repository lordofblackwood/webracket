#lang racket

(provide immutable-hash-runtime-only-helpers)

(require "../core-helper.rkt")

;; immutable-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immutable hash helpers that still depend on monolithic runtime globals.
(define immutable-hash-runtime-only-helpers
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
