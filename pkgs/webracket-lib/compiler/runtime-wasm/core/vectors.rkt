#lang racket

(provide vector-core-runtime-helpers
         vector-error-runtime-only-helper-names
         vector-make-runtime-only-helper-names
         vector-mutability-runtime-only-helper-names
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

;; vector-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers that still depend on monolithic runtime globals.
(define vector-runtime-only-helpers
  (append
   vector-error-runtime-only-helpers
   vector-make-runtime-only-helpers
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
