#lang racket

(provide vector-append-runtime-only-helper-names
         vector-build-runtime-only-helper-names
         vector-constructor-runtime-only-helper-names
         vector-copy-runtime-only-helper-names
         vector-core-runtime-helpers
         vector-error-runtime-only-helper-names
         vector-extend-runtime-only-helper-names
         vector-make-runtime-only-helper-names
         vector-mutability-runtime-only-helper-names
         vector-operation-runtime-only-helper-names
         vector-slice-runtime-only-helper-names
         vector-runtime-only-helpers)

(require "../core-helper.rkt")

;; vector-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers that can be emitted in core runtime.
(define vector-core-runtime-helpers
  (list
   ;; vector?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a vector, 0 otherwise.
   (core-runtime-helper
    '$vector?/i32
    "$vector?/i32"
    (lambda ()
      `(func $vector?/i32 (param $a (ref eq)) (result i32)
             (ref.test (ref $Vector) (local.get $a)))))))

;; vector-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector mutability predicates.
(define vector-mutability-runtime-only-helper-names
  '($mutable-vector?
    $immutable-vector?))

;; vector-error-runtime-only-forms : (listof datum?)
;;   Enumerate vector error helpers used by the monolithic runtime.
(define vector-error-runtime-only-forms
  '(
        ;; Vector related exceptions
        (func $raise-check-vector/who
              (param $who (ref eq))
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:vector?)
                    (local.get $x)))
        (func $raise-check-vector
              (param $x (ref eq))
              (call $raise-check-vector/who
                    (global.get $symbol:vector?)
                    (local.get $x)))
        (func $raise-check-fixnum/who
              (param $who (ref eq))
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:fixnum?)
                    (local.get $x)))
        (func $raise-check-fixnum (param $x (ref eq))
              (call $raise-check-fixnum/who
                    (global.get $symbol:fixnum?)
                    (local.get $x)))
        (func $raise-immutable-vector/who
              (param $who (ref eq))
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:mutable-vector?)
                    (local.get $x)))
        (func $raise-immutable-vector
              (param $x (ref eq))
              (call $raise-immutable-vector/who
                    (global.get $symbol:vector-set!)
                    (local.get $x)))
        (func $raise-bad-vector-ref-index/who
              (param $who (ref eq))
              (param $v   (ref $Vector))
              (param $i   i32)
              (param $len i32)
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:valid-vector-index)
                    (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))
        (func $raise-bad-vector-ref-index
              (param $v (ref $Vector)) (param $i i32) (param $len i32)
              (call $raise-bad-vector-ref-index/who
                    (global.get $symbol:vector-ref)
                    (local.get $v)
                    (local.get $i)
                    (local.get $len)))
         (func $raise-bad-vector-copy-range/who
               (param $who        (ref eq))
               (param $dest       (ref $Vector))
               (param $dest-start i32)
               (param $src        (ref $Vector))
               (param $src-start  i32)
               (param $src-end    i32)
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:valid-vector-index)
                     (ref.i31 (i32.shl (local.get $src-start) (i32.const 1)))))
         (func $raise-bad-vector-copy-range
               (param $dest (ref $Vector)) (param $dest-start i32)
               (param $src  (ref $Vector)) (param $src-start  i32) (param $src-end i32)
               (call $raise-bad-vector-copy-range/who
                     (global.get $symbol:vector-copy)
                     (local.get $dest)
                     (local.get $dest-start)
                     (local.get $src)
                     (local.get $src-start)
                     (local.get $src-end)))
         (func $raise-bad-vector-take-index/who
               (param $who (ref eq))
               (param $v   (ref $Vector))
               (param $i   i32)
               (param $len i32)
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:valid-vector-index)
                     (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))
         (func $raise-bad-vector-take-index
               (param $v (ref $Vector)) (param $i i32) (param $len i32)
               (call $raise-bad-vector-take-index/who
                     (global.get $symbol:vector-take)
                     (local.get $v)
                     (local.get $i)
                     (local.get $len)))


         (func $raise-make-vector:bad-length
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:make-vector)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $x)))

     ))

;; vector-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector error helpers used by the monolithic runtime.
(define vector-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-error-runtime-only-helpers
   vector-error-runtime-only-forms))

;; vector-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector error helpers.
(define vector-error-runtime-only-helper-names
  (map core-runtime-helper-name vector-error-runtime-only-helpers))

;; vector-make-runtime-only-forms : (listof datum?)
;;   Enumerate make-vector helpers used by the monolithic runtime.
(define vector-make-runtime-only-forms
  '(
         (func $make-vector (type $Prim12)
               (param $k-fx   (ref eq))  ;; fixnum
               (param $val    (ref eq))  ;; optional, defaults to 0
               (result        (ref eq))

               (local $k   i32)
               (local $k/s i32)
               (local $v   (ref eq))  ;; possibly rewritten value
               ;; --- Type check for fixnum ---
               (if (i32.eqz (ref.test (ref i31) (local.get $k-fx)))
                   (then (call $raise-make-vector:bad-length (local.get $k-fx))
                         (unreachable)))
               ;; --- Decode fixnum to i32 ---
               (local.set $k/s
                          (i32.shr_s
                           (i31.get_s (ref.cast (ref i31) (local.get $k-fx)))
                           (i32.const 1)))
               (if (i32.lt_s (local.get $k/s) (i32.const 0))
                   (then (call $raise-make-vector:bad-length (local.get $k-fx))
                         (unreachable)))
               (local.set $k (local.get $k/s))
               ;; --- Substitute default value if missing ---
               (local.set $v (if (result (ref eq))
                                 (ref.eq (local.get $val) (global.get $missing))
                                 (then (global.get $zero))
                                 (else (local.get $val))))
               ;; --- Delegate to checked version ---
               (call $make-vector/checked (local.get $k) (local.get $v)))

         (func $make-vector/checked
               (param $k   i32)        ;; number of elements
               (param $val (ref eq))   ;; initial value
               (result     (ref $Vector))

               (local $arr (ref $Array))
               (call $debug-allocation-tick (i32.const 1))
               ;; Create the array
               (local.set $arr (array.new $Array (local.get $val) (local.get $k)))
               ;; Construct and return the vector
               (struct.new $Vector
                           (i32.const 0)    ;; hash = 0
                           (i32.const 0)    ;; mutable
                           (local.get $arr)))

     ))

;; vector-make-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate make-vector helpers used by the monolithic runtime.
(define vector-make-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-make-runtime-only-helpers
   vector-make-runtime-only-forms))

;; vector-make-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for make-vector helpers.
(define vector-make-runtime-only-helper-names
  (map core-runtime-helper-name vector-make-runtime-only-helpers))

;; vector-constructor-runtime-only-forms : (listof datum?)
;;   Enumerate vector constructor helpers used by the monolithic runtime.
(define vector-constructor-runtime-only-forms
  '(
         (func $vector (type $Prim>=0)
               (param $args (ref eq))
               (result      (ref eq))

               (local $as        (ref $Args))
               (local $len       i32)
               (local $arr       (ref $Array))
               (local $use-args? i32)
               (local $list      (ref eq))
               (local $node      (ref eq))
               (local $pair      (ref $Pair))
               (local $i         i32)
               (local $x         (ref eq))

               ;; Initialize non-defaultable locals
               (local.set $as   (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $x    (global.get $false))
               (local.set $list (global.get $null))
               (local.set $node (global.get $null))

               ;; Determine whether we received an $Args array or a list of rest arguments.
               (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
               (if (local.get $use-args?)
                   (then
                    (local.set $as (ref.cast (ref $Args) (local.get $args)))
                    (local.set $len (array.len (local.get $as))))
                   (else
                    (local.set $list (local.get $args))
                    (local.set $node (local.get $list))
                    (local.set $len (call $length/i32 (local.get $list)))))

               ;; Allocate backing array
               (local.set $arr (call $make-array (local.get $len) (global.get $false)))
               (local.set $i   (i32.const 0))

               ;; Copy arguments from either $Args or list form
               (if (local.get $use-args?)
                   (then
                    (block $done-args
                           (loop $loop-args
                                 (br_if $done-args
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $x (array.get $Args (local.get $as) (local.get $i)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-args))))
                   (else
                    (local.set $node (local.get $list))
                    (block $done-list
                           (loop $loop-list
                                 (br_if $done-list
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (if (ref.test (ref $Pair) (local.get $node))
                                     (then
                                      (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                      (local.set $x (struct.get $Pair $a (local.get $pair)))
                                      (local.set $node (struct.get $Pair $d (local.get $pair))))
                                     (else
                                      (call $raise-pair-expected (local.get $node))
                                      (unreachable)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-list)))))

               ;; Wrap in a mutable vector structure
               (struct.new $Vector
                           (i32.const 0)          ;; hash
                           (i32.const 0)          ;; mutable
                           (local.get $arr)))


         (func $vector-immutable (type $Prim>=0)
               (param $args (ref eq))
               (result      (ref eq))

               (local $as        (ref $Args))
               (local $len       i32)
               (local $arr       (ref $Array))
               (local $use-args? i32)
               (local $list      (ref eq))
               (local $node      (ref eq))
               (local $pair      (ref $Pair))
               (local $i         i32)
               (local $x         (ref eq))

               ;; Initialize non-defaultable locals
               (local.set $as   (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $x    (global.get $false))
               (local.set $list (global.get $null))
               (local.set $node (global.get $null))

               ;; Determine whether we received an $Args array or a list of rest arguments.
               (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
               (if (local.get $use-args?)
                   (then
                    (local.set $as (ref.cast (ref $Args) (local.get $args)))
                    (local.set $len (array.len (local.get $as))))
                   (else
                    (local.set $list (local.get $args))
                    (local.set $node (local.get $list))
                    (local.set $len (call $length/i32 (local.get $list)))))

               ;; Allocate backing array
               (local.set $arr (call $make-array (local.get $len) (global.get $false)))
               (local.set $i   (i32.const 0))

               ;; Copy arguments from either $Args or list form
               (if (local.get $use-args?)
                   (then
                    (block $done-args
                           (loop $loop-args
                                 (br_if $done-args
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $x (array.get $Args (local.get $as) (local.get $i)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-args))))
                   (else
                    (local.set $node (local.get $list))
                    (block $done-list
                           (loop $loop-list
                                 (br_if $done-list
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (if (ref.test (ref $Pair) (local.get $node))
                                     (then
                                      (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                      (local.set $x (struct.get $Pair $a (local.get $pair)))
                                      (local.set $node (struct.get $Pair $d (local.get $pair))))
                                     (else
                                      (call $raise-pair-expected (local.get $node))
                                      (unreachable)))
                                 (array.set $Array (local.get $arr)
                                            (local.get $i)
                                            (local.get $x))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop-list)))))

               ;; Wrap in a mutable vector structure
               (struct.new $Vector
                           (i32.const 0)          ;; hash
                           (i32.const 1)          ;; immutable
                           (local.get $arr)))


     ))

;; vector-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector constructor helpers used by the monolithic runtime.
(define vector-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-constructor-runtime-only-helpers
   vector-constructor-runtime-only-forms))

;; vector-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector constructor helpers.
(define vector-constructor-runtime-only-helper-names
  (map core-runtime-helper-name vector-constructor-runtime-only-helpers))

;; vector-build-runtime-only-forms : (listof datum?)
;;   Enumerate build-vector helpers used by the monolithic runtime.
(define vector-build-runtime-only-forms
  '(
        (func $build-vector (type $Prim2)
              (param $n-raw (ref eq))  ;; exact-nonnegative integer
              (param $proc  (ref eq))  ;; (exact-nonnegative-integer? . -> . any/c)
              (result       (ref eq))

              (local $n    i32)
              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))

              ;; --- Check and unwrap n ---
              (if (i32.eqz (ref.test (ref i31) (local.get $n-raw)))
                  (then (call $raise-expected-fixnum (local.get $n-raw))))
              (local.set $n
                         (i32.shr_s
                          (i31.get_s (ref.cast (ref i31) (local.get $n-raw)))
                          (i32.const 1)))
              (if (i32.lt_s (local.get $n) (i32.const 0))
                  (then (call $raise-argument-error/internal (local.get $n-raw))))

              ;; --- Check procedure ---
              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; Delegate
              (call $build-vector/checked (local.get $n)
                    (local.get $f)
                    (local.get $finv)))

        (func $build-vector/checked
              (param $n    i32)
              (param $f    (ref $Procedure))
              (param $finv (ref $ProcedureInvoker))
              (result      (ref $Vector))

              (local $args (ref $Args))
              (local $arr  (ref $Array))
              (local $i    i32)
              (local $res  (ref eq))

              ;; Prepare array and argument holder
              (local.set $arr  (call $make-array (local.get $n) (global.get $false)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              ;; Iterate from 0 to n-1
              (local.set $i (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                           ;; Set argument to current index as fixnum
                           (array.set $Args (local.get $args) (i32.const 0)
                                      (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                           ;; Call procedure and store result
                           (local.set $res
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $finv)))
                           (array.set $Array (local.get $arr) (local.get $i) (local.get $res))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))

              ;; Construct vector
              (struct.new $Vector
                          (i32.const 0)    ;; hash
                          (i32.const 0)    ;; mutable
                          (local.get $arr)))

     ))

;; vector-build-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate build-vector helpers used by the monolithic runtime.
(define vector-build-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-build-runtime-only-helpers
   vector-build-runtime-only-forms))

;; vector-build-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for build-vector helpers.
(define vector-build-runtime-only-helper-names
  (map core-runtime-helper-name vector-build-runtime-only-helpers))


;; vector-operation-runtime-only-forms : (listof datum?)
;;   Enumerate vector operation helpers used by the monolithic runtime.
(define vector-operation-runtime-only-forms
  '(
        (func $vector-set/copy (type $Prim3)
              ;; Returns a fresh mutable vector with VAL at index POS.
              (param $v   (ref eq)) ;; vector
              (param $pos (ref eq)) ;; fixnum
              (param $val (ref eq)) ;; any
              (result     (ref eq))

              (local $vec (ref $Vector))
              (local $idx i32)
              (local $len i32)

              ;; --- Validate vector ---
              (local.set $vec (global.get $dummy-vector))
              (if (ref.test (ref $Vector) (local.get $v))
                  (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                  (else (call $raise-check-vector/who
                              (global.get $symbol:vector-set/copy)
                              (local.get $v))))

              ;; --- Validate index ---
              (if (ref.test (ref i31) (local.get $pos))
                  (then (local.set $idx (i31.get_u (ref.cast (ref i31) (local.get $pos))))
                        (if (i32.and (local.get $idx) (i32.const 1))
                            (then (call $raise-check-fixnum/who
                                        (global.get $symbol:vector-set/copy)
                                        (local.get $pos))))
                        (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1))))
                  (else (call $raise-check-fixnum/who
                              (global.get $symbol:vector-set/copy)
                              (local.get $pos))))

              ;; --- Bounds check ---
              (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
              (if (i32.lt_u (local.get $idx) (local.get $len))
                  (then (return
                         (struct.new $Vector
                                    (i32.const 0)
                                    (i32.const 0)
                                    (call $array-set/copy
                                          (struct.get $Vector $arr (local.get $vec))
                                          (local.get $idx)
                                          (local.get $val)))))
                  (else (call $raise-bad-vector-ref-index/who
                              (global.get $symbol:vector-set/copy)
                              (local.get $vec) (local.get $idx) (local.get $len))
                        (unreachable)))
              (unreachable))


        (func $vector-length (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                         (ref.i31
                          (i32.shl
                           (array.len
                            (struct.get $Vector $arr (local.get $vec)))
                           (i32.const 1))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-length)
                               (local.get $v))
                         (unreachable))))


         (func $vector-length/i32 (param $v (ref eq)) (result i32)
               (local $vec (ref $Vector))
               (if (result i32)
                   (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                         (array.len (struct.get $Vector $arr (local.get $vec))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-length)
                               (local.get $v))
                         (unreachable))))

         (func $vector-length/checked/i32 (param $v (ref $Vector)) (result i32)
               (array.len (struct.get $Vector $arr (local.get $v))))


         (func $vector? (type $Prim1) (param $a (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $a))
                   (then (global.get $true))
                   (else (global.get $false))))


         (func $vector-ref/checked
               (param $a (ref $Vector)) (param $i i32)
               (result (ref eq))
               (local $len i32)
               ;; get length
               (local.set $len (array.len (struct.get $Vector $arr (local.get $a))))
               ;; bounds check
               (if (result (ref eq))
                   (i32.lt_u (local.get $i) (local.get $len))
                   (then (array.get $Array
                                    (struct.get $Vector $arr (local.get $a))
                                    (local.get $i)))
                   (else (call $raise-bad-vector-ref-index
                               (local.get $a) (local.get $i) (local.get $len))
                         (unreachable))))

         (func $vector-ref/who
               (param $who (ref eq))
               (param $v (ref eq)) (param $i (ref eq))
               (result (ref eq))
               (local $vec (ref $Vector))
               (local $idx i32)
               (local $len i32)
               ;; Initialize vec to dummy to satisfy non-nullable default requirement
               (local.set $vec (global.get $dummy-vector))
               ;; Check that $v is a vector
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who (local.get $who) (local.get $v))))
               ;; Check that $i is an i31 and decode fixnum
               (if (ref.test (ref i31) (local.get $i))
                   (then
                    (local.set $idx
                               (i31.get_u (ref.cast (ref i31) (local.get $i))))
                    (if (i32.eqz (i32.and (local.get $idx) (i32.const 1)))
                        (then (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1))))
                        (else (call $raise-check-fixnum/who (local.get $who) (local.get $i)))))
                   (else (call $raise-check-fixnum/who (local.get $who) (local.get $i))))
               ;; Get array length
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               ;; Bounds check
               (if (result (ref eq))
                   (i32.lt_u (local.get $idx) (local.get $len))
                   (then (return
                          (array.get $Array
                                     (struct.get $Vector $arr (local.get $vec))
                                     (local.get $idx))))
                   (else (call $raise-bad-vector-ref-index/who
                               (local.get $who)
                               (local.get $vec) (local.get $idx) (local.get $len))
                         (unreachable))))

         (func $vector-ref (type $Prim2)
               (param $v (ref eq)) (param $i (ref eq))
               (result (ref eq))
               (call $vector-ref/who
                     (global.get $symbol:vector-ref)
                     (local.get $v)
                     (local.get $i)))


         (func $vector-set!/checked
               (param $vec (ref $Vector)) (param $i i32) (param $val (ref eq))
               (local $len i32)

               (if (i32.ne (struct.get $Vector $immutable (local.get $vec)) (i32.const 0))
                   (then (call $raise-immutable-vector (local.get $vec)) (unreachable)))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.lt_u (local.get $i) (local.get $len))
                   (then (array.set $Array
                                    (struct.get $Vector $arr (local.get $vec))
                                    (local.get $i)
                                    (local.get $val)))
                   (else (call $raise-bad-vector-ref-index
                               (local.get $vec) (local.get $i) (local.get $len))
                         (unreachable))))

         (func $vector-set!/who
               (param $who (ref eq))
               (param $v   (ref eq))
               (param $i   (ref eq))
               (param $val (ref eq))
               (result     (ref eq))

               (local $vec (ref $Vector))
               (local $idx i32)
               (local $len i32)
               ;; Initialize $vec with dummy to satisfy non-nullable restriction
               (local.set $vec (global.get $dummy-vector))
               ;; 1. Check $v is a vector
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who (local.get $who) (local.get $v))))
               ;; 2. Check $i is a fixnum
               (if (ref.test (ref i31) (local.get $i))
                   (then (local.set $idx
                                    (i31.get_u (ref.cast (ref i31) (local.get $i))))
                         (if (i32.eqz (i32.and (local.get $idx) (i32.const 1)))
                             (then (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1))))
                             (else (call $raise-check-fixnum/who (local.get $who) (local.get $i)))))
                   (else (call $raise-check-fixnum/who (local.get $who) (local.get $i))))
              ;; 3. Check mutability and get length
              (if (i32.ne (struct.get $Vector $immutable (local.get $vec)) (i32.const 0))
                  (then (call $raise-immutable-vector/who (local.get $who) (local.get $v))))
              (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               ;; 4. Bounds check and set
               (if (result (ref eq))
                   (i32.lt_u (local.get $idx) (local.get $len))
                   (then (array.set $Array
                                    (struct.get $Vector $arr (local.get $vec))
                                    (local.get $idx)
                                    (local.get $val))
                         (global.get $void))
                   (else (call $raise-bad-vector-ref-index/who
                               (local.get $who)
                               (local.get $vec) (local.get $idx) (local.get $len))
                         (unreachable))))

         (func $vector-set! (type $Prim3)
               (param $v   (ref eq))
               (param $i   (ref eq))
               (param $val (ref eq))
               (result     (ref eq))
               (call $vector-set!/who
                     (global.get $symbol:vector-set!)
                     (local.get $v)
                     (local.get $i)
                     (local.get $val)))

         ;; vector*-length : vector? -> exact-nonnegative-integer?
         ;;   Checked vector length. WebRacket has no vector impersonators yet,
         ;;   so this currently matches vector-length.
         (func $vector*-length (type $Prim1)
               (param $v (ref eq)) ;; vector?
               (result   (ref eq))

               (local $vec (ref $Vector))
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector*-length)
                               (local.get $v))
                         (unreachable)))
               (ref.i31 (i32.shl
                         (array.len
                          (struct.get $Vector $arr (local.get $vec)))
                         (i32.const 1))))

         ;; vector*-ref : vector? exact-nonnegative-integer? -> any/c
         ;;   Checked vector ref. WebRacket has no vector impersonators yet,
         ;;   so this currently matches vector-ref.
         (func $vector*-ref (type $Prim2)
               (param $v (ref eq)) ;; vector?
               (param $i (ref eq)) ;; exact-nonnegative-integer?
               (result   (ref eq))
               (call $vector-ref/who
                     (global.get $symbol:vector*-ref)
                     (local.get $v)
                     (local.get $i)))

         ;; vector*-set! : (and/c vector? (not/c immutable?)) exact-nonnegative-integer? any/c -> void?
         ;;   Checked vector set. WebRacket has no vector impersonators yet,
         ;;   so this currently matches vector-set!.
         (func $vector*-set! (type $Prim3)
               (param $v   (ref eq)) ;; mutable vector?
               (param $i   (ref eq)) ;; exact-nonnegative-integer?
               (param $val (ref eq)) ;; new value
               (result     (ref eq))
               (call $vector-set!/who
                     (global.get $symbol:vector*-set!)
                     (local.get $v)
                     (local.get $i)
                     (local.get $val)))

         (func $vector-fill! (type $Prim2) (param $v (ref eq)) (param $x (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-fill!)
                               (local.get $v))))
               (if (i32.ne (struct.get $Vector $immutable (local.get $vec)) (i32.const 0))
                   (then (call $raise-immutable-vector/who
                               (global.get $symbol:vector-fill!)
                               (local.get $v))))
               (call $array-fill! (struct.get $Vector $arr (local.get $vec)) (local.get $x))
               (global.get $void))


     ))

;; vector-operation-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector operation helpers used by the monolithic runtime.
(define vector-operation-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-operation-runtime-only-helpers
   vector-operation-runtime-only-forms))

;; vector-operation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector operation helpers.
(define vector-operation-runtime-only-helper-names
  (map core-runtime-helper-name vector-operation-runtime-only-helpers))


;; vector-copy-runtime-only-forms : (listof datum?)
;;   Enumerate vector copy and conversion helpers used by the monolithic runtime.
(define vector-copy-runtime-only-forms
  '(
         (func $vector-copy!
               (param $dest       (ref eq))
               (param $dest-start (ref eq))   ;; fixnum
               (param $src        (ref eq))
               (param $src-start  (ref eq))   ;; fixnum or $missing, default: 0)
               (param $src-end    (ref eq))   ;; fixnum or $missing, default: (vector-length src)
               (result            (ref eq))

               (local $d       (ref $Vector))
               (local $s       (ref $Vector))
               (local $ds      i32)
               (local $ss      i32)
               (local $se      i32)
               (local $src-len i32)

               ;; --- Validate $dest ---
               (if (i32.eqz (ref.test (ref $Vector) (local.get $dest)))
                   (then (call $raise-check-vector/who
                               (global.get $symbol:vector-copy!)
                               (local.get $dest))))
               ;; --- Validate $src ---
               (if (i32.eqz (ref.test (ref $Vector) (local.get $src)))
                   (then (call $raise-check-vector/who
                               (global.get $symbol:vector-copy!)
                               (local.get $src))))
               ;; --- Validate $dest-start ---
               (if (i32.eqz (ref.test (ref i31) (local.get $dest-start)))
                   (then (call $raise-check-fixnum/who
                               (global.get $symbol:vector-copy!)
                               (local.get $dest-start))))
               (if (i32.and (i31.get_u (ref.cast (ref i31) (local.get $dest-start)))
                            (i32.const 1))
                   (then (call $raise-check-fixnum/who
                               (global.get $symbol:vector-copy!)
                               (local.get $dest-start))))
               ;; --- Validate $src-start ---
               (if (i32.eqz (ref.eq (local.get $src-start) (global.get $missing)))
                   (then (if (i32.eqz (ref.test (ref i31) (local.get $src-start)))
                             (then (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-copy!)
                                         (local.get $src-start))))
                         (if (i32.and (i31.get_u (ref.cast (ref i31) (local.get $src-start)))
                                      (i32.const 1))
                             (then (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-copy!)
                                         (local.get $src-start))))))
               ;; --- Validate $src-end ---
               (if (i32.eqz (ref.eq (local.get $src-end) (global.get $missing)))
                   (then (if (i32.eqz (ref.test (ref i31) (local.get $src-end)))
                             (then (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-copy!)
                                         (local.get $src-end))))
                         (if (i32.and (i31.get_u (ref.cast (ref i31) (local.get $src-end)))
                                      (i32.const 1))
                             (then (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-copy!)
                                         (local.get $src-end))))))
               ;; --- Cast and decode after validation ---
               (local.set $d  (ref.cast (ref $Vector) (local.get $dest)))
               (local.set $s  (ref.cast (ref $Vector) (local.get $src)))
               (if (i32.ne (struct.get $Vector $immutable (local.get $d)) (i32.const 0))
                   (then (call $raise-immutable-vector/who
                               (global.get $symbol:vector-copy!)
                               (local.get $dest))))
               (local.set $ds (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $dest-start)))
                                         (i32.const 1)))

               (local.set $src-len (array.len (struct.get $Vector $arr (local.get $s))))

               (if (ref.eq (local.get $src-start) (global.get $missing))
                   (then (local.set $ss (i32.const 0)))
                   (else (local.set $ss (i32.shr_u (i31.get_u (ref.cast (ref i31)
                                                                        (local.get $src-start)))
                                                   (i32.const 1)))))

               (if (ref.eq (local.get $src-end) (global.get $missing))
                   (then (local.set $se (local.get $src-len)))
                   (else (local.set $se (i32.shr_u (i31.get_u (ref.cast (ref i31)
                                                                        (local.get $src-end)))
                                                   (i32.const 1)))))
               ;; --- Delegate to checked copy ---
               (call $vector-copy!/checked/who
                     (global.get $symbol:vector-copy!)
                     (local.get $d) (local.get $ds)
                     (local.get $s) (local.get $ss)
                     (local.get $se)))

         (func $vector-copy!/checked/who
               (param $who  (ref eq))
               (param $dest (ref $Vector)) (param $ds i32)
               (param $src  (ref $Vector)) (param $ss i32) (param $se i32)
               (result (ref eq))

               (local $src-len i32)
               (local $dest-len i32)
               (if (i32.ne (struct.get $Vector $immutable (local.get $dest)) (i32.const 0))
                   (then (call $raise-immutable-vector/who
                               (local.get $who)
                               (local.get $dest))
                         (unreachable)))
               (local.set $src-len  (array.len (struct.get $Vector $arr (local.get $src))))
               (local.set $dest-len (array.len (struct.get $Vector $arr (local.get $dest))))
               (if (i32.or
                    (i32.or (i32.gt_u (local.get $ss) (local.get $src-len))
                            (i32.gt_u (local.get $se) (local.get $src-len)))
                    (i32.gt_u (i32.add (local.get $ds) (i32.sub (local.get $se) (local.get $ss))) (local.get $dest-len)))
                   (then (call $raise-bad-vector-copy-range/who
                               (local.get $who)
                               (local.get $dest) (local.get $ds)
                               (local.get $src) (local.get $ss) (local.get $se))
                         (unreachable)))

               (call $array-copy!
                     (struct.get $Vector $arr (local.get $dest)) (local.get $ds)
                     (struct.get $Vector $arr (local.get $src))  (local.get $ss) (local.get $se))
               (global.get $void))

         (func $vector-copy!/checked
               (param $dest (ref $Vector)) (param $ds i32)
               (param $src  (ref $Vector)) (param $ss i32) (param $se i32)
               (result (ref eq))

               (call $vector-copy!/checked/who
                     (global.get $symbol:vector-copy!)
                     (local.get $dest) (local.get $ds)
                     (local.get $src) (local.get $ss) (local.get $se)))

         (func $vector-copy (type $Prim13)
               (param $v     (ref eq))
               (param $start (ref eq))   ;; fixnum or $missing, default: 0
               (param $end   (ref eq))   ;; fixnum or $missing, default: (vector-length v)
               (result       (ref eq))

               (local $vec (ref $Vector))
               (local $ss  i32)
               (local $se  i32)
               (local $len i32)

               ;; --- Validate vector ---
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-copy)
                               (local.get $v))))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               ;; --- Decode $start ---
               (if (ref.eq (local.get $start) (global.get $missing))
                   (then (local.set $ss (i32.const 0)))
                   (else (if (ref.test (ref i31) (local.get $start))
                             (then (local.set $ss (i31.get_u (ref.cast (ref i31) (local.get $start))))
                                   (if (i32.and (local.get $ss) (i32.const 1))
                                       (then (call $raise-check-fixnum/who
                                                   (global.get $symbol:vector-copy)
                                                   (local.get $start))))
                                   (local.set $ss (i32.shr_u (local.get $ss) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-copy)
                                         (local.get $start))))))
               ;; --- Decode $end ---
               (if (ref.eq (local.get $end) (global.get $missing))
                   (then (local.set $se (local.get $len)))
                   (else (if (ref.test (ref i31) (local.get $end))
                             (then (local.set $se (i31.get_u (ref.cast (ref i31) (local.get $end))))
                                   (if (i32.and (local.get $se) (i32.const 1))
                                       (then (call $raise-check-fixnum/who
                                                   (global.get $symbol:vector-copy)
                                                   (local.get $end))))
                                   (local.set $se (i32.shr_u (local.get $se) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-copy)
                                         (local.get $end))))))
               ;; --- Bounds check: start <= end <= len ---
               (if (i32.or (i32.gt_u (local.get $ss) (local.get $se))
                           (i32.gt_u (local.get $se) (local.get $len)))
                   (then (call $raise-bad-vector-copy-range/who
                               (global.get $symbol:vector-copy)
                               (local.get $vec) (i32.const 0)
                               (local.get $vec) (local.get $ss) (local.get $se))
                         (unreachable)))
               ;; --- Allocate and return new mutable vector ---
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-copy
                                 (struct.get $Vector $arr (local.get $vec))
                                 (local.get $ss) (local.get $se))))

         (func $vector->immutable-vector (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $vec (ref $Vector))

               ;; --- Validate vector ---
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector->immutable-vector)
                               (local.get $v))))

               ;; --- If already immutable, return as-is ---
               (if (result (ref eq))
                   (i32.eq (struct.get $Vector $immutable (local.get $vec)) (i32.const 1))
                   (then (local.get $vec))
                   (else
                    ;; Otherwise, allocate immutable copy
                    (struct.new $Vector
                                (struct.get $Vector $hash (local.get $vec))
                                (i32.const 1)
                                (call $array-copy
                                      (struct.get $Vector $arr (local.get $vec))
                                      (i32.const 0)
                                      (array.len (struct.get $Vector $arr (local.get $vec))))))))

         (func $vector->values (type $Prim13)
               (param $v     (ref eq))
               (param $start (ref eq))   ;; fixnum or $missing, default: 0
               (param $end   (ref eq))   ;; fixnum or $missing, default: (vector-length v)
               (result       (ref eq))

               (local $vec  (ref $Vector))
               (local $arr  (ref $Array))
               (local $ss   i32)
               (local $se   i32)
               (local $len  i32)
               (local $n    i32)
               (local $vals (ref $Values))

               ;; --- Validate vector ---
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector->values)
                               (local.get $v))))
               (local.set $arr (struct.get $Vector $arr (local.get $vec)))
               (local.set $len (array.len (local.get $arr)))

               ;; --- Decode $start ---
               (if (ref.eq (local.get $start) (global.get $missing))
                   (then (local.set $ss (i32.const 0)))
                   (else (if (ref.test (ref i31) (local.get $start))
                             (then (local.set $ss (i31.get_u (ref.cast (ref i31) (local.get $start))))
                                   (if (i32.and (local.get $ss) (i32.const 1))
                                       (then (call $raise-check-fixnum/who
                                                   (global.get $symbol:vector->values)
                                                   (local.get $start))))
                                   (local.set $ss (i32.shr_u (local.get $ss) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector->values)
                                         (local.get $start))))))

               ;; --- Decode $end ---
               (if (ref.eq (local.get $end) (global.get $missing))
                   (then (local.set $se (local.get $len)))
                   (else (if (ref.test (ref i31) (local.get $end))
                             (then (local.set $se (i31.get_u (ref.cast (ref i31) (local.get $end))))
                                   (if (i32.and (local.get $se) (i32.const 1))
                                       (then (call $raise-check-fixnum/who
                                                   (global.get $symbol:vector->values)
                                                   (local.get $end))))
                                   (local.set $se (i32.shr_u (local.get $se) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector->values)
                                         (local.get $end))))))

               ;; --- Bounds check: start <= end <= len ---
               (if (i32.or (i32.gt_u (local.get $ss) (local.get $se))
                           (i32.gt_u (local.get $se) (local.get $len)))
                   (then (call $raise-bad-vector-copy-range/who
                               (global.get $symbol:vector->values)
                               (local.get $vec) (i32.const 0)
                               (local.get $vec) (local.get $ss) (local.get $se))
                         (unreachable)))

               (local.set $n (i32.sub (local.get $se) (local.get $ss)))
               (if (i32.eq (local.get $n) (i32.const 1))
                   (then (return (array.get $Array (local.get $arr) (local.get $ss)))))

               (local.set $vals (array.new $Values (global.get $null) (local.get $n)))
               (array.copy $Values $Array
                           (local.get $vals) (i32.const 0)
                           (local.get $arr) (local.get $ss)
                           (local.get $n))
               (local.get $vals))


     ))

;; vector-copy-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector copy and conversion helpers used by the monolithic runtime.
(define vector-copy-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-copy-runtime-only-helpers
   vector-copy-runtime-only-forms))

;; vector-copy-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector copy and conversion helpers.
(define vector-copy-runtime-only-helper-names
  (map core-runtime-helper-name vector-copy-runtime-only-helpers))


;; vector-extend-runtime-only-forms : (listof datum?)
;;   Enumerate vector extend helpers used by the monolithic runtime.
(define vector-extend-runtime-only-forms
  '(
         (func $raise-vector-extend:bad-length
               (param $v        (ref $Vector))
               (param $new-size (ref eq))
               (param $len      i32)
               (call $raise-argument-error1
                     (global.get $symbol:vector-extend)
                     (global.get $string:valid-vector-length)
                     (local.get $new-size)))

         ; TODO:
         ;   Error message in original vector-extend
         ;     vector-extend: new length is shorter than existing length
         ;       new length: 3
         ;       existing length: 7

         (func $vector-extend (type $Prim23)
               (param $v        (ref eq))  ;; vector
               (param $new-size (ref eq))  ;; fixnum
               (param $val      (ref eq))  ;; optional, defaults to 0
               (result          (ref eq))

               (local $vec  (ref $Vector))
               (local $ns   i32)
               (local $len  i32)
               (local $fill (ref eq))

               (local.set $vec  (global.get $dummy-vector))
               (local.set $fill (global.get $zero))

               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-extend)
                               (local.get $v))))

               (if (ref.test (ref i31) (local.get $new-size))
                   (then (local.set $ns (i31.get_s (ref.cast (ref i31) (local.get $new-size))))
                         (if (i32.and (local.get $ns) (i32.const 1))
                             (then (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-extend)
                                         (local.get $new-size))))
                         (local.set $ns (i32.shr_s (local.get $ns) (i32.const 1))))
                   (else (call $raise-check-fixnum/who
                               (global.get $symbol:vector-extend)
                               (local.get $new-size))))

               (local.set $fill (if (result (ref eq))
                                    (ref.eq (local.get $val) (global.get $missing))
                                    (then (global.get $zero))
                                    (else (local.get $val))))

               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.lt_s (local.get $ns) (local.get $len))
                   (then (call $raise-vector-extend:bad-length
                               (local.get $vec) (local.get $new-size) (local.get $len))
                         (unreachable)))

               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-extend
                                 (struct.get $Vector $arr (local.get $vec))
                                 (local.get $ns)
                                 (local.get $fill))))

         (func $vector-empty? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $len i32)
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                         (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
                         (if (result (ref eq))
                             (i32.eqz (local.get $len))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-empty?)
                               (local.get $v))
                         (unreachable))))


     ))

;; vector-extend-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector extend helpers used by the monolithic runtime.
(define vector-extend-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-extend-runtime-only-helpers
   vector-extend-runtime-only-forms))

;; vector-extend-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector extend helpers.
(define vector-extend-runtime-only-helper-names
  (map core-runtime-helper-name vector-extend-runtime-only-helpers))


;; vector-append-runtime-only-forms : (listof datum?)
;;   Enumerate vector append helpers used by the monolithic runtime.
(define vector-append-runtime-only-forms
  '(
         (func $vector-append (type $Prim>=0)
              (param $xs    (ref eq))        ;; list of vectors
              (result       (ref eq))

              (local $n     i32)
              (local $node  (ref $Pair))
              (local $vec   (ref $Vector))
              (local $v     (ref eq))
              (local $orig  (ref eq))
              (local $total i32)
              (local $len   i32)
              (local $arr   (ref $Array))
              (local $pos   i32)

              ;; initialize non-defaultable refs
              (local.set $vec (global.get $dummy-vector))

              ;; Preserve original list
              (local.set $orig (local.get $xs))
              ;; Determine number of arguments
              (local.set $n (call $length/i32 (local.get $xs)))
              ;; Zero arguments -> empty vector
              (if (i32.eqz (local.get $n))
                  (then (return (struct.new $Vector
                                           (i32.const 0)
                                           (i32.const 0)
                                           (call $make-array
                                                 (i32.const 0)
                                                 (global.get $false))))))
              ;; Extract and check first argument
              (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
              (local.set $v    (struct.get $Pair $a (local.get $node)))
              (if (ref.test (ref $Vector) (local.get $v))
                  (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                  (else (call $raise-check-vector/who
                              (global.get $symbol:vector-append)
                              (local.get $v))))
              ;; Single argument -> copy to ensure fresh vector
              (if (i32.eq (local.get $n) (i32.const 1))
                  (then (return (call $vector-copy
                                      (local.get $v)
                                      (global.get $missing)
                                      (global.get $missing)))))
              ;; Compute total length
              (local.set $total (array.len (struct.get $Vector $arr (local.get $vec))))
              (local.set $xs    (struct.get $Pair $d (local.get $node)))
              (block $done1
                     (loop $loop1
                           (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                           (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                           (local.set $v    (struct.get $Pair $a (local.get $node)))
                           (if (ref.test (ref $Vector) (local.get $v))
                               (then (local.set $vec   (ref.cast (ref $Vector) (local.get $v)))
                                     (local.set $len   (array.len (struct.get $Vector $arr (local.get $vec))))
                                     (local.set $total (i32.add (local.get $total) (local.get $len))))
                               (else (call $raise-check-vector/who
                                           (global.get $symbol:vector-append)
                                           (local.get $v))))
                           (local.set $xs (struct.get $Pair $d (local.get $node)))
                           (br $loop1)))
              ;; Allocate result array
              (local.set $arr (call $make-array (local.get $total) (global.get $false)))
              ;; Copy vectors into result array
              (local.set $xs (local.get $orig))
              (local.set $pos (i32.const 0))
              (block $done2
                     (loop $loop2
                           (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                           (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                           (local.set $vec  (ref.cast (ref $Vector)
                                                      (struct.get $Pair $a (local.get $node))))
                           (local.set $len  (array.len (struct.get $Vector $arr (local.get $vec))))
                           (call $array-copy!
                                 (local.get $arr) (local.get $pos)
                                 (struct.get $Vector $arr (local.get $vec))
                                 (i32.const 0) (local.get $len))
                           (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                           (local.set $xs (struct.get $Pair $d (local.get $node)))
                           (br $loop2)))

              (struct.new $Vector
                          (i32.const 0)
                          (i32.const 0)
                          (local.get $arr)))

         (func $vector-append/2 (param $a (ref eq)) (param $b (ref eq)) (result (ref eq))
               (local $va (ref $Vector))
               (local $vb (ref $Vector))
               (local.set $va (global.get $dummy-vector))
               (local.set $vb (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $a))
                   (then (local.set $va (ref.cast (ref $Vector) (local.get $a))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-append)
                               (local.get $a))))
               (if (ref.test (ref $Vector) (local.get $b))
                   (then (local.set $vb (ref.cast (ref $Vector) (local.get $b))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-append)
                               (local.get $b))))

               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-append
                                 (struct.get $Vector $arr (local.get $va))
                                 (struct.get $Vector $arr (local.get $vb)))))



     ))

;; vector-append-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector append helpers used by the monolithic runtime.
(define vector-append-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-append-runtime-only-helpers
   vector-append-runtime-only-forms))

;; vector-append-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector append helpers.
(define vector-append-runtime-only-helper-names
  (map core-runtime-helper-name vector-append-runtime-only-helpers))


;; vector-slice-runtime-only-forms : (listof datum?)
;;   Enumerate vector take, drop, and split helpers used by the monolithic runtime.
(define vector-slice-runtime-only-forms
  '(
         (func $vector-take (type $Prim2) (param $v (ref eq)) (param $i (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-take)
                               (local.get $v))))
               (if (ref.test (ref i31) (local.get $i))
                   (then (local.set $ix (i31.get_u (ref.cast (ref i31) (local.get $i))))
                         (if (i32.eqz (i32.and (local.get $ix) (i32.const 1)))
                             (then (local.set $ix (i32.shr_u (local.get $ix) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-take)
                                         (local.get $i)))))
                   (else (call $raise-check-fixnum/who
                               (global.get $symbol:vector-take)
                               (local.get $i))))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-take)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-take (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))

         (func $vector-drop (type $Prim2) (param $v (ref eq)) (param $i (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-drop)
                               (local.get $v))))
               (if (ref.test (ref i31) (local.get $i))
                   (then (local.set $ix (i31.get_u (ref.cast (ref i31) (local.get $i))))
                         (if (i32.eqz (i32.and (local.get $ix) (i32.const 1)))
                             (then (local.set $ix (i32.shr_u (local.get $ix) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-drop)
                                         (local.get $i)))))
                   (else (call $raise-check-fixnum/who
                               (global.get $symbol:vector-drop)
                               (local.get $i))))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-drop)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-drop (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))

         (func $vector-drop-right (type $Prim2) (param $v (ref eq)) (param $i (ref eq)) (result (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-drop-right)
                               (local.get $v))))
               (if (ref.test (ref i31) (local.get $i))
                   (then (local.set $ix (i31.get_u (ref.cast (ref i31) (local.get $i))))
                         (if (i32.eqz (i32.and (local.get $ix) (i32.const 1)))
                             (then (local.set $ix (i32.shr_u (local.get $ix) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-drop-right)
                                         (local.get $i)))))
                   (else (call $raise-check-fixnum/who
                               (global.get $symbol:vector-drop-right)
                               (local.get $i))))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-drop-right)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-drop-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))

         (func $vector-take-right (type $Prim2)
               (param $v (ref eq))
               (param $i (ref eq))
               (result   (ref eq))
               (local $vec (ref $Vector))
               (local $ix i32)
               (local $len i32)
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-take-right)
                               (local.get $v))))
               (if (ref.test (ref i31) (local.get $i))
                   (then (local.set $ix (i31.get_u (ref.cast (ref i31) (local.get $i))))
                         (if (i32.eqz (i32.and (local.get $ix) (i32.const 1)))
                             (then (local.set $ix (i32.shr_u (local.get $ix) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-take-right)
                                         (local.get $i)))))
                   (else (call $raise-check-fixnum/who
                               (global.get $symbol:vector-take-right)
                               (local.get $i))))
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-take-right)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               (struct.new $Vector (i32.const 0)
                           (i32.const 0)
                           (call $array-take-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix))))



         (func $vector-split-at (type $Prim2)
               (param $v (ref eq))
               (param $i (ref eq))
               (result   (ref eq))  ; returns two values

               (local $vec (ref $Vector))
               (local $ix  i32)
               (local $len i32)
               (local $res (ref $Array))

               ; 1. Check $v is a vector
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-split-at)
                               (local.get $v))))
               ; 2. Check $i is a fixnum
               (if (ref.test (ref i31) (local.get $i))
                   (then (local.set $ix (i31.get_u (ref.cast (ref i31) (local.get $i))))
                         (if (i32.eqz (i32.and (local.get $ix) (i32.const 1)))
                             (then (local.set $ix (i32.shr_u (local.get $ix) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-split-at)
                                         (local.get $i)))))
                   (else (call $raise-check-fixnum/who
                               (global.get $symbol:vector-split-at)
                               (local.get $i))))
               ; 3. Range check
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-split-at)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               ; 4. Split the vector
               (local.set $res (call $array-split-at (struct.get $Vector $arr (local.get $vec)) (local.get $ix)))
               (array.new_fixed $Values 2
                                (struct.new $Vector
                                            (i32.const 0)  ; hash
                                            (i32.const 0)  ; mutable
                                            (ref.cast (ref $Array)
                                                      (array.get $Array (local.get $res) (i32.const 0))))
                                (struct.new $Vector
                                            (i32.const 0) ; hash
                                            (i32.const 0) ; mutable
                                            (ref.cast (ref $Array)
                                                      (array.get $Array (local.get $res) (i32.const 1))))))

         (func $vector-split-at-right (type $Prim2)
               (param $v (ref eq))      ; vec
               (param $i (ref eq))      ; count
               (result   (ref eq))      ; returns two values

               (local $vec  (ref $Vector))
               (local $ix   i32)
               (local $len  i32)
               (local $take (ref $Array))
               (local $drop (ref $Array))

               ; 1. Check $v is a vector
               (local.set $vec (global.get $dummy-vector))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (local.set $vec (ref.cast (ref $Vector) (local.get $v))))
                   (else (call $raise-check-vector/who
                               (global.get $symbol:vector-split-at-right)
                               (local.get $v))))
               ; 2. Check $i is a fixnum
               (if (ref.test (ref i31) (local.get $i))
                   (then (local.set $ix (i31.get_u (ref.cast (ref i31) (local.get $i))))
                         (if (i32.eqz (i32.and (local.get $ix) (i32.const 1)))
                             (then (local.set $ix (i32.shr_u (local.get $ix) (i32.const 1))))
                             (else (call $raise-check-fixnum/who
                                         (global.get $symbol:vector-split-at-right)
                                         (local.get $i)))))
                   (else (call $raise-check-fixnum/who
                               (global.get $symbol:vector-split-at-right)
                               (local.get $i))))
               ; 3. Range check
               (local.set $len (array.len (struct.get $Vector $arr (local.get $vec))))
               (if (i32.gt_u (local.get $ix) (local.get $len))
                   (then (call $raise-bad-vector-take-index/who
                               (global.get $symbol:vector-split-at-right)
                               (local.get $vec) (local.get $ix) (local.get $len))
                         (unreachable)))
               ; 4. Split the vector from the right
               (local.set $take (call $array-take-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix)))
               (local.set $drop (call $array-drop-right (struct.get $Vector $arr (local.get $vec)) (local.get $ix)))
               (array.new_fixed $Values 2
                                (struct.new $Vector
                                            (i32.const 0) ; hash
                                            (i32.const 0) ; mutable
                                            (local.get $take))
                                (struct.new $Vector
                                            (i32.const 0) ; hash
                                            (i32.const 0) ; mutable
                                            (local.get $drop))))



     ))

;; vector-slice-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector take, drop, and split helpers used by the monolithic runtime.
(define vector-slice-runtime-only-helpers
  (function-forms->runtime-helpers
   'vector-slice-runtime-only-helpers
   vector-slice-runtime-only-forms))

;; vector-slice-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for vector take, drop, and split helpers.
(define vector-slice-runtime-only-helper-names
  (map core-runtime-helper-name vector-slice-runtime-only-helpers))

;; vector-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers that still depend on monolithic runtime globals.
(define vector-runtime-only-helpers
  (append
   vector-error-runtime-only-helpers
   vector-make-runtime-only-helpers
   vector-constructor-runtime-only-helpers
   vector-build-runtime-only-helpers
   vector-operation-runtime-only-helpers
   vector-copy-runtime-only-helpers
   vector-extend-runtime-only-helpers
   vector-append-runtime-only-helpers
   vector-slice-runtime-only-helpers
   (function-forms->runtime-helpers
    'vector-runtime-only-helpers
    '(
         (func $mutable-vector? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Vector $immutable
                                                 (ref.cast (ref $Vector) (local.get $v)))
                                     (i32.const 0))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $immutable-vector? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Vector) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Vector $immutable
                                                 (ref.cast (ref $Vector) (local.get $v)))
                                     (i32.const 1))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))


     ))))
