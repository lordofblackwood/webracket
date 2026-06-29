#lang racket

(provide fixnum-core-runtime-helpers)

(require "../core-helper.rkt")

;; fixnum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate fixnum helpers that can be emitted in core runtime.
(define fixnum-core-runtime-helpers
  (list
   ;; $fx?/i32 : any/c -> i32
   ;;   Return 1 when v is an i31 fixnum value, otherwise 0.
   ;;   This raw i32 predicate is used in validation paths that branch on
   ;;   fixnum-ness instead of returning a WebRacket boolean.
   (core-runtime-helper
    '$fx?/i32
    "$fx?/i32"
    (lambda ()
      `(func $fx?/i32 (param $v (ref eq)) (result i32)
             (local $v/tag i32)
             (if (ref.test (ref i31) (local.get $v))
                 (then (local.set $v/tag (i31.get_u (ref.cast (ref i31) (local.get $v))))
                       (return (i32.eqz (i32.and (local.get $v/tag)
                                                 (i32.const 1)))))
                 (else (return (i32.const 0))))
             (unreachable))))
   ;; $fixnum?/i32 : any/c -> i32
   ;;   Return 1 when v is an i31 fixnum value, otherwise 0.
   ;;   Keep this helper separate from `$fixnum?`, which returns a WebRacket
   ;;   boolean and therefore depends on runtime boolean globals.
   (core-runtime-helper
    '$fixnum?/i32
    "$fixnum?/i32"
    (lambda ()
      `(func $fixnum?/i32
             (param $v (ref eq))
             (result   i32)

             (if (result i32)
                 (ref.test (ref i31) (local.get $v))
                 (then (i32.eqz
                        (i32.and
                         (i31.get_u (ref.cast (ref i31) (local.get $v)))
                         (i32.const 1))))
                 (else (i32.const 0))))))))
