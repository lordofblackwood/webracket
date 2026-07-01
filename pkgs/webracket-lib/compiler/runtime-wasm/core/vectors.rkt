#lang racket

(provide vector-core-runtime-helpers
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

;; vector-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers that still depend on monolithic runtime globals.
(define vector-runtime-only-helpers
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


     )))
