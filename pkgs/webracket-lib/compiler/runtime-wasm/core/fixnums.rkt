#lang racket

(provide fixnum-core-runtime-helpers)

(require "../core-helper.rkt")

;; local-fixnum-bits-s : symbol? -> datum?
;;   Return WAT that reads the signed tagged fixnum bits from local-name.
(define (local-fixnum-bits-s local-name)
  `(i31.get_s (ref.cast i31ref (local.get ,local-name))))

;; local-fixnum-bits-u : symbol? -> datum?
;;   Return WAT that reads the unsigned tagged fixnum bits from local-name.
(define (local-fixnum-bits-u local-name)
  `(i31.get_u (ref.cast i31ref (local.get ,local-name))))

;; local-fixnum-payload-s : symbol? -> datum?
;;   Return WAT that decodes local-name to a signed i32 fixnum payload.
(define (local-fixnum-payload-s local-name)
  `(i32.shr_s ,(local-fixnum-bits-s local-name) (i32.const 1)))

;; local-fixnum-payload-u : symbol? -> datum?
;;   Return WAT that decodes local-name to an unsigned i32 fixnum payload.
(define (local-fixnum-payload-u local-name)
  `(i32.shr_s ,(local-fixnum-bits-u local-name) (i32.const 1)))

;; tag-fixnum-bits : datum? -> datum?
;;   Return WAT that encodes an i32 fixnum payload as tagged bits.
(define (tag-fixnum-bits bits)
  `(i32.shl ,bits (i32.const 1)))

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
                 (else (i32.const 0))))))
   ;; $fxand/2 : fixnum? fixnum? -> fixnum?
   ;;   Compute the bitwise-and of two already validated fixnums.
   (core-runtime-helper
    '$fxand/2
    "$fxand/2"
    (lambda ()
      `(func $fxand/2 (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.and (i31.get_s (ref.cast i31ref (local.get $x)))
                               (i31.get_s (ref.cast i31ref (local.get $y))))))))
   ;; $fxior/2 : fixnum? fixnum? -> fixnum?
   ;;   Compute the bitwise-ior of two already validated fixnums.
   (core-runtime-helper
    '$fxior/2
    "$fxior/2"
    (lambda ()
      `(func $fxior/2 (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.or (i31.get_s (ref.cast i31ref (local.get $x)))
                              (i31.get_s (ref.cast i31ref (local.get $y))))))))
   ;; $fxxor/2 : fixnum? fixnum? -> fixnum?
   ;;   Compute the bitwise-xor of two already validated fixnums.
   (core-runtime-helper
    '$fxxor/2
    "$fxxor/2"
    (lambda ()
      `(func $fxxor/2 (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.xor (i31.get_s (ref.cast i31ref (local.get $x)))
                               (i31.get_s (ref.cast i31ref (local.get $y))))))))
   ;; $fxnot : fixnum? -> fixnum?
   ;;   Compute the bitwise-not of an already validated fixnum.
   (core-runtime-helper
    '$fxnot
    "$fxnot"
    (lambda ()
      `(func $fxnot (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.xor ,(local-fixnum-payload-s '$x)
                                  (i32.const -1)))))))
   ;; $fxlshift : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum left by an already validated amount.
   (core-runtime-helper
    '$fxlshift
    "$fxlshift"
    (lambda ()
      `(func $fxlshift (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $fxrshift : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum right by an already validated amount.
   (core-runtime-helper
    '$fxrshift
    "$fxrshift"
    (lambda ()
      `(func $fxrshift (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_s ,(local-fixnum-payload-s '$x)
                                    ,(local-fixnum-payload-s '$y)))))))
   ;; $fxpopcount : fixnum? -> fixnum?
   ;;   Count one bits in an already validated fixnum.
   (core-runtime-helper
    '$fxpopcount
    "$fxpopcount"
    (lambda ()
      `(func $fxpopcount (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-payload-u '$x)))))))
   ;; $fxpopcount32 : fixnum? -> fixnum?
   ;;   Count one bits in an already validated fixnum.
   (core-runtime-helper
    '$fxpopcount32
    "$fxpopcount32"
    (lambda ()
      `(func $fxpopcount32 (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-payload-u '$x)))))))
   ;; $fxpopcount16 : fixnum? -> fixnum?
   ;;   Count one bits in the low 16 bits of an already validated fixnum.
   (core-runtime-helper
    '$fxpopcount16
    "$fxpopcount16"
    (lambda ()
      `(func $fxpopcount16 (type $Prim1)
             (param $x (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt
                          (i32.and ,(local-fixnum-payload-u '$x)
                                   (i32.const 65535))))))))
   ;; $fx+/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Add two already validated fixnums with wraparound.
   (core-runtime-helper
    '$fx+/wraparound
    "$fx+/wraparound"
    (lambda ()
      `(func $fx+/wraparound (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.add ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-bits-s '$y))))))
   ;; $fx*/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Multiply two already validated fixnums with wraparound.
   (core-runtime-helper
    '$fx*/wraparound
    "$fx*/wraparound"
    (lambda ()
      `(func $fx*/wraparound (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.mul ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $fxlshift/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum left with wraparound.
   (core-runtime-helper
    '$fxlshift/wraparound
    "$fxlshift/wraparound"
    (lambda ()
      `(func $fxlshift/wraparound (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $fxrshift/logical : fixnum? fixnum? -> fixnum?
   ;;   Shift an already validated fixnum right logically.
   (core-runtime-helper
    '$fxrshift/logical
    "$fxrshift/logical"
    (lambda ()
      `(func $fxrshift/logical (type $Prim2)
             (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_u ,(local-fixnum-payload-u '$x)
                                    ,(local-fixnum-payload-u '$y)))))))
   ;; $unsafe-fxnot : fixnum? -> fixnum?
   ;;   Compute bitwise-not; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxnot
    "$unsafe-fxnot"
    (lambda ()
      `(func $unsafe-fxnot (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.xor ,(local-fixnum-payload-s '$x)
                                  (i32.const -1)))))))
   ;; $unsafe-fxpopcount : fixnum? -> fixnum?
   ;;   Count one bits; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxpopcount
    "$unsafe-fxpopcount"
    (lambda ()
      `(func $unsafe-fxpopcount (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-bits-u '$x)))))))
   ;; $unsafe-fxpopcount32 : fixnum? -> fixnum?
   ;;   Count one bits; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxpopcount32
    "$unsafe-fxpopcount32"
    (lambda ()
      `(func $unsafe-fxpopcount32 (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt ,(local-fixnum-bits-u '$x)))))))
   ;; $unsafe-fxpopcount16 : fixnum? -> fixnum?
   ;;   Count one bits in the low 16 representation bits; x must already be a fixnum.
   (core-runtime-helper
    '$unsafe-fxpopcount16
    "$unsafe-fxpopcount16"
    (lambda ()
      `(func $unsafe-fxpopcount16 (type $Prim1)
             (param $x (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.popcnt
                          (i32.and ,(local-fixnum-bits-u '$x)
                                   (i32.const 65535))))))))
   ;; $unsafe-fxlshift : fixnum? fixnum? -> fixnum?
   ;;   Shift left; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxlshift
    "$unsafe-fxlshift"
    (lambda ()
      `(func $unsafe-fxlshift (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$k))))))
   ;; $unsafe-fx+/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Add with wraparound; x and y must already be fixnums.
   (core-runtime-helper
    '$unsafe-fx+/wraparound
    "$unsafe-fx+/wraparound"
    (lambda ()
      `(func $unsafe-fx+/wraparound (type $Prim2)
             (param $x (ref eq))
             (param $y (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.add ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-bits-s '$y))))))
   ;; $unsafe-fx*/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Multiply with wraparound; x and y must already be fixnums.
   (core-runtime-helper
    '$unsafe-fx*/wraparound
    "$unsafe-fx*/wraparound"
    (lambda ()
      `(func $unsafe-fx*/wraparound (type $Prim2)
             (param $x (ref eq))
             (param $y (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.mul ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$y))))))
   ;; $unsafe-fxlshift/wraparound : fixnum? fixnum? -> fixnum?
   ;;   Shift left with wraparound; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxlshift/wraparound
    "$unsafe-fxlshift/wraparound"
    (lambda ()
      `(func $unsafe-fxlshift/wraparound (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 (i32.shl ,(local-fixnum-bits-s '$x)
                               ,(local-fixnum-payload-s '$k))))))
   ;; $unsafe-fxrshift : fixnum? fixnum? -> fixnum?
   ;;   Shift right; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxrshift
    "$unsafe-fxrshift"
    (lambda ()
      `(func $unsafe-fxrshift (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_s ,(local-fixnum-payload-s '$x)
                                    ,(local-fixnum-payload-s '$k)))))))
   ;; $unsafe-fxrshift/logical : fixnum? fixnum? -> fixnum?
   ;;   Shift right logically; x and k must already be fixnums.
   (core-runtime-helper
    '$unsafe-fxrshift/logical
    "$unsafe-fxrshift/logical"
    (lambda ()
      `(func $unsafe-fxrshift/logical (type $Prim2)
             (param $x (ref eq))
             (param $k (ref eq))
             (result   (ref eq))
             (ref.i31 ,(tag-fixnum-bits
                        `(i32.shr_u ,(local-fixnum-payload-u '$x)
                                    ,(local-fixnum-payload-u '$k)))))))))
