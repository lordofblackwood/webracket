#lang racket

(provide unsafe-runtime-only-helpers
         unsafe-runtime-helper-names)

(require "../core-helper.rkt")

;; unsafe-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for unsafe operation helpers.
(define unsafe-runtime-helper-names
  '($unsafe-fx+/2
    $unsafe-fx+
    $unsafe-fx-
    $unsafe-fx*
    $unsafe-fx=
    $unsafe-fx<
    $unsafe-fx>
    $unsafe-fx<=
    $unsafe-fx>=
    $unsafe-fxmin
    $unsafe-fxmax
    $unsafe-fxand
    $unsafe-fxior
    $unsafe-fxxor
    $unsafe-fxnot
    $unsafe-fxpopcount
    $unsafe-fxpopcount32
    $unsafe-fxpopcount16
    $unsafe-fxlshift
    $unsafe-fx+/wraparound
    $unsafe-fx-/wraparound
    $unsafe-fx*/wraparound
    $unsafe-fxlshift/wraparound
    $unsafe-fxrshift
    $unsafe-fxrshift/logical
    $unsafe-car
    $unsafe-cdr
    $unsafe-struct?
    $unsafe-sealed-struct?
    $unsafe-struct-ref
    $unsafe-struct*-ref
    $unsafe-vector-ref
    $unsafe-vector*-ref
    $unsafe-vector-length
    $unsafe-vector*-length
    $unsafe-vector-set!
    $unsafe-vector*-set!
    $unsafe-stencil-vector
    $unsafe-stencil-vector-length
    $unsafe-stencil-vector-mask
    $unsafe-stencil-vector-ref
    $unsafe-stencil-vector-set!
    $unsafe-stencil-vector-update
    $unsafe-struct-set!
    $unsafe-struct*-set!
    $unsafe-struct*-cas!
    $unsafe-string-length
    $unsafe-bytes-length
    $unsafe-bytes-ref
    $unsafe-bytes-set!))

;; unsafe-runtime-only-helper-names : (listof symbol?)
;;   Name the unsafe operation helpers implemented in this module.
(define unsafe-runtime-only-helper-names
  '($unsafe-fx+/2
    $unsafe-fx+
    $unsafe-fx-
    $unsafe-fx*
    $unsafe-fx=
    $unsafe-fx<
    $unsafe-fx>
    $unsafe-fx<=
    $unsafe-fx>=
    $unsafe-fxmin
    $unsafe-fxmax
    $unsafe-fxand
    $unsafe-fxior
    $unsafe-fxxor
    $unsafe-fx-/wraparound
    $unsafe-car
    $unsafe-cdr
    $unsafe-struct?
    $unsafe-sealed-struct?
    $unsafe-struct-ref
    $unsafe-struct*-ref
    $unsafe-vector-ref
    $unsafe-vector*-ref
    $unsafe-vector-length
    $unsafe-vector*-length
    $unsafe-vector-set!
    $unsafe-vector*-set!
    $unsafe-stencil-vector
    $unsafe-stencil-vector-length
    $unsafe-stencil-vector-mask
    $unsafe-stencil-vector-ref
    $unsafe-stencil-vector-set!
    $unsafe-stencil-vector-update
    $unsafe-struct-set!
    $unsafe-struct*-set!
    $unsafe-struct*-cas!
    $unsafe-string-length
    $unsafe-bytes-length
    $unsafe-bytes-ref
    $unsafe-bytes-set!))

;; unsafe-runtime-only-forms : (listof datum?)
;;   Enumerate unsafe operation helpers implemented in this module.
(define unsafe-runtime-only-forms
  '(
         ;;;
         ;;; 17. UNSAFE OPERATIONS
         ;;;

         ;; 17.1 Unsafe Numeric Operations

         (func $unsafe-fx+/2
               (param $x (ref eq))   ;; x must be a fixnum (i31 with lsb = 0)
               (param $y (ref eq))   ;; y must be a fixnum (i31 with lsb = 0)
               (result   (ref eq))   ;; result is a fixnum (i31)
               ; the tag was chosen, so we could do this:
               (ref.i31 (i32.add (i31.get_s (ref.cast (ref i31) (local.get $x)))
                                 (i31.get_s (ref.cast (ref i31) (local.get $y))))))

         (func $unsafe-fx+ (type $Prim>=0)
               (param $xs0 (ref eq))
               (result     (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $sum  i32)

               (local.set $xs
                          (if (result (ref eq))
                              (ref.test (ref $Args) (local.get $xs0))
                              (then (call $rest-arguments->list
                                          (ref.cast (ref $Args) (local.get $xs0))
                                          (i32.const 0)))
                              (else (local.get $xs0))))
               (local.set $sum (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $sum  (i32.add (local.get $sum)
                                                      (i31.get_s (ref.cast (ref i31)
                                                                            (local.get $v)))))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (ref.i31 (local.get $sum)))

         (func $unsafe-fx- (type $Prim>=1)
               (param $a1   (ref eq))
               (param $rest (ref eq))
               (result      (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $acc  i32)

               (local.set $xs  (local.get $rest))
               (local.set $acc (i31.get_s (ref.cast (ref i31) (local.get $a1))))
               (if (result (ref eq))
                   (ref.eq (local.get $xs) (global.get $null))
                   (then (ref.i31 (i32.sub (i32.const 0) (local.get $acc))))
                   (else (block $done
                                (loop $loop
                                      (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                                      (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                                      (local.set $v    (struct.get $Pair $a (local.get $node)))
                                      (local.set $acc  (i32.sub (local.get $acc)
                                                                (i31.get_s (ref.cast (ref i31)
                                                                                     (local.get $v)))))
                                      (local.set $xs   (struct.get $Pair $d (local.get $node)))
                                      (br $loop)))
                         (ref.i31 (local.get $acc)))))

         (func $unsafe-fx* (type $Prim>=0)
               (param $xs0 (ref eq))
               (result     (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $prod i32)

               (local.set $xs
                          (if (result (ref eq))
                              (ref.test (ref $Args) (local.get $xs0))
                              (then (call $rest-arguments->list
                                          (ref.cast (ref $Args) (local.get $xs0))
                                          (i32.const 0)))
                              (else (local.get $xs0))))
               (local.set $prod (i32.const 2))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $prod (i32.mul (local.get $prod)
                                                      (i32.shr_s
                                                       (i31.get_s (ref.cast (ref i31)
                                                                            (local.get $v)))
                                                       (i32.const 1))))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (ref.i31 (local.get $prod)))

         (func $unsafe-fx= (type $Prim2)
               (param $x (ref eq))
               (param $y (ref eq))
               (result   (ref eq))

               (if (result (ref eq))
                   (i32.eq (i31.get_s (ref.cast (ref i31) (local.get $x)))
                           (i31.get_s (ref.cast (ref i31) (local.get $y))))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $unsafe-fx< (type $Prim2)
               (param $x (ref eq)) ;; x must be a fixnum (i31 with lsb = 0)
               (param $y (ref eq)) ;; y must be a fixnum (i31 with lsb = 0)
               (result   (ref eq)) ;; result is a boolean

               (if (result (ref eq))
                   (i32.lt_s (i31.get_s (ref.cast (ref i31) (local.get $x)))
                             (i31.get_s (ref.cast (ref i31) (local.get $y))))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $unsafe-fx> (type $Prim2)
               (param $x (ref eq)) ;; x must be a fixnum (i31 with lsb = 0)
               (param $y (ref eq)) ;; y must be a fixnum (i31 with lsb = 0)
               (result   (ref eq)) ;; result is a boolean

               (if (result (ref eq))
                   (i32.gt_s (i31.get_s (ref.cast (ref i31) (local.get $x)))
                             (i31.get_s (ref.cast (ref i31) (local.get $y))))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $unsafe-fx<= (type $Prim2)
               (param $x (ref eq)) ;; x must be a fixnum (i31 with lsb = 0)
               (param $y (ref eq)) ;; y must be a fixnum (i31 with lsb = 0)
               (result   (ref eq)) ;; result is a boolean

               (if (result (ref eq))
                   (i32.le_s (i31.get_s (ref.cast (ref i31) (local.get $x)))
                             (i31.get_s (ref.cast (ref i31) (local.get $y))))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $unsafe-fx>= (type $Prim2)
               (param $x (ref eq)) ;; x must be a fixnum (i31 with lsb = 0)
               (param $y (ref eq)) ;; y must be a fixnum (i31 with lsb = 0)
               (result   (ref eq)) ;; result is a boolean

               (if (result (ref eq))
                   (i32.ge_s (i31.get_s (ref.cast (ref i31) (local.get $x)))
                             (i31.get_s (ref.cast (ref i31) (local.get $y))))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $unsafe-fxmin (type $Prim>=1)
               (param $x0 (ref eq)) ;; first fixnum argument (i31 with lsb = 0)
               (param $xs (ref eq)) ;; xs is a list of remaining fixnum arguments
               (result   (ref eq))  ;; result is a fixnum (i31)

               (local $node    (ref $Pair))
               (local $fx      (ref eq))
               (local $best    (ref eq))
               (local $best-i32 i32)
               (local $fx-i32   i32)

               (local.set $best     (local.get $x0))
               (local.set $best-i32 (i31.get_s (ref.cast (ref i31) (local.get $best))))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $fx   (struct.get $Pair $a (local.get $node)))
                            (local.set $fx-i32 (i31.get_s (ref.cast (ref i31) (local.get $fx))))
                            (if (i32.lt_s (local.get $fx-i32) (local.get $best-i32))
                                (then (local.set $best     (local.get $fx))
                                      (local.set $best-i32 (local.get $fx-i32))))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (local.get $best))

         (func $unsafe-fxmax (type $Prim>=1)
               (param $x0 (ref eq)) ;; first fixnum argument (i31 with lsb = 0)
               (param $xs (ref eq)) ;; xs is a list of remaining fixnum arguments
               (result   (ref eq))  ;; result is a fixnum (i31)

               (local $node    (ref $Pair))
               (local $fx      (ref eq))
               (local $best    (ref eq))
               (local $best-i32 i32)
               (local $fx-i32   i32)

               (local.set $best     (local.get $x0))
               (local.set $best-i32 (i31.get_s (ref.cast (ref i31) (local.get $best))))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $fx   (struct.get $Pair $a (local.get $node)))
                            (local.set $fx-i32 (i31.get_s (ref.cast (ref i31) (local.get $fx))))
                            (if (i32.gt_s (local.get $fx-i32) (local.get $best-i32))
                                (then (local.set $best     (local.get $fx))
                                      (local.set $best-i32 (local.get $fx-i32))))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (local.get $best))

         (func $unsafe-fxand (type $Prim>=1)
               (param $a1   (ref eq)) ;; first fixnum argument (i31 with lsb = 0)
               (param $rest (ref eq)) ;; list of remaining fixnum arguments
               (result      (ref eq)) ;; result is a fixnum (i31)

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $acc  i32)

               (local.set $xs  (local.get $rest))
               (local.set $acc (i31.get_s (ref.cast (ref i31) (local.get $a1))))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $acc  (i32.and (local.get $acc)
                                                      (i31.get_s (ref.cast (ref i31)
                                                                           (local.get $v)))))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (ref.i31 (local.get $acc)))

         (func $unsafe-fxior (type $Prim>=1)
               (param $a1   (ref eq)) ;; first fixnum argument (i31 with lsb = 0)
               (param $rest (ref eq)) ;; list of remaining fixnum arguments
               (result      (ref eq)) ;; result is a fixnum (i31)

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $acc  i32)

               (local.set $xs  (local.get $rest))
               (local.set $acc (i31.get_s (ref.cast (ref i31) (local.get $a1))))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $acc  (i32.or (local.get $acc)
                                                     (i31.get_s (ref.cast (ref i31)
                                                                          (local.get $v)))))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (ref.i31 (local.get $acc)))

         (func $unsafe-fxxor (type $Prim>=1)
               (param $a1   (ref eq)) ;; first fixnum argument (i31 with lsb = 0)
               (param $rest (ref eq)) ;; list of remaining fixnum arguments
               (result      (ref eq)) ;; result is a fixnum (i31)

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $acc  i32)

               (local.set $xs  (local.get $rest))
               (local.set $acc (i31.get_s (ref.cast (ref i31) (local.get $a1))))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $acc  (i32.xor (local.get $acc)
                                                      (i31.get_s (ref.cast (ref i31)
                                                                           (local.get $v)))))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (ref.i31 (local.get $acc)))







         (func $unsafe-fx-/wraparound (type $Prim>=1)
               (param $a1   (ref eq)) ;; first argument (fixnum)
               (param $rest (ref eq)) ;; optional second argument; defaults to 0 when absent
               (result      (ref eq)) ;; result is a fixnum (i31)

               (local $a    (ref eq))
               (local $b    (ref eq))
               (local $node (ref $Pair))

               ;; Eager init so locals are definitely assigned before any possible get.
               (local.set $a (ref.i31 (i32.const 0)))
               (local.set $b (local.get $a1))
               (if (ref.eq (local.get $rest) (global.get $null))
                   (then
                    (local.set $a (ref.i31 (i32.const 0)))
                    (local.set $b (local.get $a1)))
                   (else
                    (local.set $node (ref.cast (ref $Pair) (local.get $rest)))
                    (local.set $a    (local.get $a1))
                    (local.set $b    (struct.get $Pair $a (local.get $node)))))
               (ref.i31
                (i32.sub
                 (i31.get_s (ref.cast (ref i31) (local.get $a)))
                 (i31.get_s (ref.cast (ref i31) (local.get $b))))))






         ;; 17.2 Unsafe Character Operations
         ;; 17.3 Unsafe Compound-Data Operations

         (func $unsafe-car (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $v))))

         (func $unsafe-cdr (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $v))))

         (func $unsafe-struct? (type $Prim2)
               (param $v   (ref eq)) ;; candidate struct value
               (param $std (ref eq)) ;; expected struct type descriptor
               (result     (ref eq)) ;; boolean

               (local $struct (ref $Struct))
               (local $type   (ref eq))
               (local $ok     i32)

               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (return (global.get $false))))
               (if (i32.eqz (ref.test (ref $StructType) (local.get $std)))
                   (then (return (global.get $false))))

               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $type   (struct.get $Struct $type (local.get $struct)))
               (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
               (if (result (ref eq))
                   (local.get $ok)
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; unsafe-sealed-struct? : any/c struct-type? -> boolean?
         ;;   Internal Schemify predicate for sealed struct predicates. Since
         ;;   WebRacket rejects sealed parents, the ordinary subtype check is
         ;;   equivalent for currently representable sealed struct values.
         (func $unsafe-sealed-struct? (type $Prim2)
               (param $v   (ref eq)) ;; candidate struct value
               (param $std (ref eq)) ;; expected sealed struct type descriptor
               (result     (ref eq)) ;; boolean
               (call $unsafe-struct? (local.get $v) (local.get $std)))

         (func $unsafe-struct-ref (type $Prim2)
               (param $v (ref eq))
               (param $k (ref eq))
               (result (ref eq))
               (array.get $Array
                          (struct.get $Struct $fields
                                      (ref.cast (ref $Struct) (local.get $v)))
                          (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                          (local.get $k)))
                                     (i32.const 1))))

         ;; unsafe-struct*-ref : (not/c impersonator?) fixnum? -> any/c
         ;;   Raw field access. WebRacket does not yet implement impersonators,
         ;;   so this is currently the same operation as unsafe-struct-ref.
         (func $unsafe-struct*-ref (type $Prim2)
               (param $v (ref eq))
               (param $k (ref eq))
               (result (ref eq))
               (array.get $Array
                          (struct.get $Struct $fields
                                      (ref.cast (ref $Struct) (local.get $v)))
                          (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                          (local.get $k)))
                                     (i32.const 1))))

        (func $unsafe-vector-ref (type $Prim2)
              (param $v (ref eq))
              (param $k (ref eq))
              (result (ref eq))
              (array.get $Array
                         (struct.get $Vector $arr
                                     (ref.cast (ref $Vector) (local.get $v)))
                         (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                         (local.get $k)))
                                    (i32.const 1))))

        (func $unsafe-vector*-ref (type $Prim2)
              (param $v (ref eq))
              (param $k (ref eq))
              (result (ref eq))
              (array.get $Array
                         (struct.get $Vector $arr
                                     (ref.cast (ref $Vector) (local.get $v)))
                         (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                         (local.get $k)))
                                    (i32.const 1))))

        (func $unsafe-vector-length (type $Prim1)
              (param $v (ref eq))
              (result   (ref eq))

              (local $vec (ref $Vector))
              (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
               (ref.i31 (i32.shl
                         (array.len
                          (struct.get $Vector $arr (local.get $vec)))
                         (i32.const 1))))


        ;; Note the `unsafe-vector*-...` variants do not work on impersonators.
        ;; (the `unsafe-vector-...` variants do)
        (func $unsafe-vector*-length (type $Prim1)
              (param $v (ref eq))
              (result   (ref eq))

              (local $vec (ref $Vector))
              (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
               (ref.i31 (i32.shl
                         (array.len
                          (struct.get $Vector $arr (local.get $vec)))
                         (i32.const 1))))

        (func $unsafe-vector-set! (type $Prim3)
              (param $vec (ref eq))
              (param $idx (ref eq))
              (param $val (ref eq))
              (result     (ref eq))

              (array.set $Array
                         (struct.get $Vector $arr
                                     (ref.cast (ref $Vector) (local.get $vec)))
                         (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                         (local.get $idx)))
                                    (i32.const 1))
                         (local.get $val))
              (global.get $void))

        (func $unsafe-vector*-set! (type $Prim3)
              (param $vec (ref eq))
              (param $idx (ref eq))
              (param $val (ref eq))
              (result     (ref eq))

              (array.set $Array
                         (struct.get $Vector $arr
                                     (ref.cast (ref $Vector) (local.get $vec)))
                         (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                         (local.get $idx)))
                                    (i32.const 1))
                         (local.get $val))
              (global.get $void))

        ;; unsafe-stencil-vector : mask value ... -> stencil-vector?
        ;;   Unsafe alias for now; the checked primitive keeps the contract
        ;;   boundary until the HAMT path is stable.
        (func $unsafe-stencil-vector (type $Prim>=1)
              (param $mask-v (ref eq))
              (param $vals   (ref eq))
              (result        (ref eq))
              (call $stencil-vector (local.get $mask-v) (local.get $vals)))

        (func $unsafe-stencil-vector-length (type $Prim1)
              (param $v (ref eq))
              (result   (ref eq))
              (call $stencil-vector-length (local.get $v)))

        (func $unsafe-stencil-vector-mask (type $Prim1)
              (param $v (ref eq))
              (result   (ref eq))
              (call $stencil-vector-mask (local.get $v)))

        (func $unsafe-stencil-vector-ref (type $Prim2)
              (param $v (ref eq))
              (param $i (ref eq))
              (result   (ref eq))
              (call $stencil-vector-ref (local.get $v) (local.get $i)))

        (func $unsafe-stencil-vector-set! (type $Prim3)
              (param $v   (ref eq))
              (param $i   (ref eq))
              (param $val (ref eq))
              (result     (ref eq))
              (call $stencil-vector-set! (local.get $v) (local.get $i) (local.get $val)))

        (func $unsafe-stencil-vector-update (type $Prim>=3)
              (param $v        (ref eq))
              (param $remove-v (ref eq))
              (param $add-v    (ref eq))
              (param $vals     (ref eq))
              (result          (ref eq))
              (call $stencil-vector-update
                    (local.get $v)
                    (local.get $remove-v)
                    (local.get $add-v)
                    (local.get $vals)))

        (func $unsafe-struct-set!
              (param $struct (ref eq))
              (param $idx    (ref eq))
              (param $val    (ref eq))
              (result        (ref eq))

              (array.set $Array
                         (struct.get $Struct $fields
                                     (ref.cast (ref $Struct) (local.get $struct)))
                         (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                         (local.get $idx)))
                                    (i32.const 1))
                         (local.get $val))
              (global.get $void))

        ;; unsafe-struct*-set! : (not/c impersonator?) fixnum? any/c -> void?
        ;;   Raw field update. WebRacket does not yet implement impersonators,
        ;;   so this is currently the same operation as unsafe-struct-set!.
        (func $unsafe-struct*-set! (type $Prim3)
              (param $struct (ref eq))
              (param $idx    (ref eq))
              (param $val    (ref eq))
              (result        (ref eq))

              (array.set $Array
                         (struct.get $Struct $fields
                                     (ref.cast (ref $Struct) (local.get $struct)))
                         (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                         (local.get $idx)))
                                    (i32.const 1))
                         (local.get $val))
              (global.get $void))

        ;; unsafe-struct*-cas! : (not/c impersonator?) fixnum? any/c any/c -> boolean?
        ;;   Single-threaded raw-field compare-and-set. This is not a full
        ;;   atomic substrate yet, but it preserves the expander's expected
        ;;   success/failure protocol for non-impersonated structs.
        (func $unsafe-struct*-cas! (type $Prim4)
              (param $struct (ref eq)) ;; struct value
              (param $idx    (ref eq)) ;; fixnum field index
              (param $old    (ref eq)) ;; expected old value
              (param $new    (ref eq)) ;; replacement value
              (result        (ref eq))

              (local $fields (ref $Array))
              (local $i      i32)

              (local.set $fields
                         (struct.get $Struct $fields
                                     (ref.cast (ref $Struct) (local.get $struct))))
              (local.set $i
                         (i32.shr_s (i31.get_s (ref.cast (ref i31)
                                                        (local.get $idx)))
                                    (i32.const 1)))
              (if (ref.eq (array.get $Array (local.get $fields) (local.get $i))
                          (local.get $old))
                  (then
                   (array.set $Array
                              (local.get $fields)
                              (local.get $i)
                              (local.get $new))
                   (return (global.get $true))))
              (global.get $false))

        (func $unsafe-string-length (type $Prim1)
              (param $s   (ref eq))
              (result     (ref eq))

              (local $str (ref $String))

              (local.set $str (ref.cast (ref $String) (local.get $s)))
              (ref.i31 (i32.shl
                        (array.len
                         (struct.get $String $codepoints (local.get $str)))
                        (i32.const 1))))

        (func $unsafe-bytes-length (type $Prim1)
              (param $b   (ref eq))
              (result     (ref eq))

              (local $bs  (ref $Bytes))

              (local.set $bs (ref.cast (ref $Bytes) (local.get $b)))
              (ref.i31 (i32.shl
                        (array.len
                         (struct.get $Bytes $bs (local.get $bs)))
                        (i32.const 1))))

        (func $unsafe-bytes-ref (type $Prim2)
              (param $bstr (ref eq)) ;; bytes
              (param $k    (ref eq)) ;; fixnum index
              (result      (ref eq))

              (local $bs  (ref $Bytes))
              (local $arr (ref $I8Array))
              (local $idx i32)

              (local.set $bs  (ref.cast (ref $Bytes) (local.get $bstr)))
              (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
              (local.set $idx (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $k)))
                                         (i32.const 1)))

              (ref.i31 (i32.shl (call $i8array-ref (local.get $arr) (local.get $idx))
                                (i32.const 1))))

        (func $unsafe-bytes-set! (type $Prim3)
              (param $bstr (ref eq)) ;; bytes
              (param $k    (ref eq)) ;; fixnum index
              (param $b    (ref eq)) ;; byte
              (result (ref eq))

              (local $bs  (ref $Bytes))
              (local $arr (ref $I8Array))
              (local $idx i32)
              (local $bv  i32)

              (local.set $bs  (ref.cast (ref $Bytes) (local.get $bstr)))
              (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
              (local.set $idx (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $k)))
                                         (i32.const 1)))
              (local.set $bv  (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $b)))
                                         (i32.const 1)))

              (call $i8array-set! (local.get $arr) (local.get $idx) (local.get $bv))
              (global.get $void))


        ;; 17.4 Unsafe Extflonum Operations
        ;; 17.5 Unsafe Impersonators and Chaperones
        ;; 17.6 Unsafe Assertions
        ;; 17.7 Unsafe Undefined





    ))

(define unsafe-runtime-only-helpers
  (function-forms->runtime-helpers
   'unsafe-runtime-only-helpers
   unsafe-runtime-only-forms))
