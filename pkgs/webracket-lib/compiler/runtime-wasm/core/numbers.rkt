#lang racket

(provide generic-arithmetic-runtime-only-helper-names
         generic-numeric-runtime-only-helper-names
         number-runtime-only-helpers
         number-type-runtime-only-helper-names)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt"
         "../../private/immediates.rkt")

;; Half : datum? -> datum?
;;   Decode a tagged fixnum expression to an i32 payload.
(define (Half x)
  `(i32.shr_s ,x (i32.const 1)))

;; Double : datum? -> datum?
;;   Encode an i32 payload as tagged fixnum bits.
(define (Double x)
  `(i32.shl ,x (i32.const 1)))

;; number-type-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for number-type helpers.
(define number-type-runtime-only-helper-names
  '($number?
    $complex?
    $real?
    $rational?
    $exact?
    $inexact?
    $single-flonum?
    $single-flonum-available?
    $flvector?
    $inexact-real?
    $exact-integer?
    $exact-nonnegative-integer?
    $exact-positive-integer?
    $inexact->exact
    $exact->inexact
    $real->double-flonum
    $zero?
    $integer-sqrt
    $integer-sqrt/remainder
    $pow-special
    $expt
    $exp
    $log
    $positive?
    $negative?
    $even?
    $odd?
    $integer?
    $nan?
    $infinite?
    $positive-integer?
    $negative-integer?
    $nonpositive-integer?
    $nonnegative-integer?
    $natural?))

;; number-type-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate number-type helpers that still depend on monolithic runtime globals.
(define number-type-runtime-only-helpers
  (function-forms->runtime-helpers
   'number-type-runtime-only-helpers
   `(
         (func $number? (type $Prim1)
               (param $v (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (ref.test i31ref (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eqz (i32.and (i31.get_s (ref.cast i31ref (local.get $v)))
                                               (i32.const ,fixnum-mask)))
                             (then (global.get $true))
                             (else (global.get $false))))
	                   (else (if (result (ref eq))
	                             (ref.test (ref $Flonum) (local.get $v))
	                             (then (global.get $true))
	                             (else (if (result (ref eq))
	                                     (ref.test (ref $Complex) (local.get $v))
	                                     (then (global.get $true))
	                                     (else (global.get $false))))))))

         ;; complex? : any/c -> boolean?
         ;;   Racket defines complex? as number?. WebRacket currently has
         ;;   fixnum, flonum, and a small complex representation, so delegate
         ;;   to number? to keep the numeric tower predicate consistent.
         (func $complex? (type $Prim1)
               (param $v (ref eq))
               (result (ref eq))
               (return_call $number? (local.get $v)))

	        (func $real? (type $Prim1)
	              ;; Complex numbers are numbers, but they are not real.
	              (param $v (ref eq))
              (result (ref eq))
              (if (result (ref eq))
                  (ref.test i31ref (local.get $v))
                  (then (if (result (ref eq))
                            (i32.eqz (i32.and (i31.get_s (ref.cast i31ref (local.get $v)))
                                              (i32.const ,fixnum-mask)))
                            (then (global.get $true))
                            (else (global.get $false))))
                  (else (if (result (ref eq))
                            (ref.test (ref $Flonum) (local.get $v))
                            (then (global.get $true))
                            (else (global.get $false))))))

         (func $rational? (type $Prim1)
               ;; WebRacket currently has fixnums and flonums as real numeric
               ;; values. Racket reports finite flonums as rational? but not
               ;; +inf.0, -inf.0, or +nan.0. Exact rationals and complex
               ;; rationals can be added when those representations exist.
               (param $v (ref eq))
               (result (ref eq))
               (local $f64v f64)
               (if (ref.test i31ref (local.get $v))
                   (then
                    (if (i32.eqz (i32.and (i31.get_s (ref.cast i31ref (local.get $v)))
                                          (i32.const ,fixnum-mask)))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               (if (ref.test (ref $Flonum) (local.get $v))
                   (then
                    (local.set $f64v
                               (struct.get $Flonum $v
                                           (ref.cast (ref $Flonum) (local.get $v))))
                    (if (f64.ne (local.get $f64v) (local.get $f64v))
                        (then (return (global.get $false))))
                    (if (f64.eq (local.get $f64v) (f64.const +inf))
                        (then (return (global.get $false))))
                    (if (f64.eq (local.get $f64v) (f64.const -inf))
                        (then (return (global.get $false))))
                    (return (global.get $true))))
               (global.get $false))

         (func $exact? (type $Prim1)
               ;; A number is exact if it's a fixnum: a ref i31 with LSB = 0
               (param $z (ref eq))
               (result   (ref eq))

               (local $bits i32)
               (if (result (ref eq))
                   (ref.test (ref i31) (local.get $z))
                   (then (local.set $bits (i31.get_u (ref.cast (ref i31) (local.get $z))))
                         (if (result (ref eq))
                             (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $inexact? (type $Prim1)
               ;; A number is inexact if it's a flonum
               (param $z (ref eq))
               (result   (ref eq))

               (if (result (ref eq))
                   (ref.test (ref $Flonum) (local.get $z))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $single-flonum? (type $Prim1)
               ;; single-flonums are not supported
               (param $v (ref eq))
               (result (ref eq))
               (global.get $false))

         (func $single-flonum-available? (type $Prim0)
               ;; single-flonums are not supported
               (result (ref eq))
               (global.get $false))

         ;; flvector? : any/c -> boolean?
         ;;   WebRacket does not have flvector values yet, so this predicate
         ;;   is always false until a concrete flvector representation exists.
         (func $flvector? (type $Prim1)
               (param $v (ref eq)) ;; any/c
               (result (ref eq))
               (global.get $false))

         (func $inexact-real? (type $Prim1)
               ;; Returns #t for inexact real numbers (flonums that are not NaN)
               (param $z (ref eq))
               (result   (ref eq))

               (local $fl (ref $Flonum))
               (local $f64 f64)

               ;; Check: is z a flonum?
               (if (result (ref eq))
                   (ref.test (ref $Flonum) (local.get $z))
                   (then
                    (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                    (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                    (if (result (ref eq))
                        (f64.eq (local.get $f64) (local.get $f64)) ; check not NaN
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         (func $exact-integer? (type $Prim1)
              (param $v (ref eq))
              (result   (ref eq))

               (local $bits i32)

               (if (result (ref eq))
                   (ref.test (ref i31) (local.get $v))
                   (then (local.set $bits (i31.get_u (ref.cast (ref i31) (local.get $v))))
                         (if (result (ref eq))
                             (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $exact-nonnegative-integer? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $n i32)

               ;; Check: is v a fixnum with LSB = 0
               (if (ref.test (ref i31) (local.get $v))
                   (then
                    (local.set $n (i31.get_s (ref.cast (ref i31) (local.get $v))))
                    (if (i32.eqz (i32.and (local.get $n) (i32.const 1))) ;; LSB = 0?
                        (then
                         (if (i32.ge_s (i32.shr_s (local.get $n) (i32.const 1))
                                       (i32.const 0))
                             (then (return (global.get $true)))
                             (else (return (global.get $false))))))
                    (return (global.get $false))))

               ;; Not a fixnum
               (return (global.get $false)))

         (func $exact-positive-integer? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $n i32)

               ;; Check if it's a fixnum
               (if (ref.test (ref i31) (local.get $v))
                   (then
                    ;; Extract the signed value
                    (local.set $n (i31.get_s (ref.cast (ref i31) (local.get $v))))
                    ;; Check LSB = 0 (exact) and value > 0
                    (if (i32.eqz (i32.and (local.get $n) (i32.const 1)))
                        (then
                         (if (i32.gt_s (i32.shr_s (local.get $n) (i32.const 1)) (i32.const 0))
                             (then (return (global.get $true)))
                             (else (return (global.get $false))))))
                    ;; LSB ≠ 0 → not an exact integer
                    (return (global.get $false))))
               ;; Not a fixnum → not an exact integer
               (return (global.get $false)))




         (func $inexact->exact (type $Prim1)
              (param $z (ref eq))
              (result   (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)
              (local $i32 i32)

              ;; If z is a fixnum, ensure LSB = 0 and return it
              (if (ref.test (ref i31) (local.get $z))
                  (then
                   (local.set $bits (i31.get_u (ref.cast (ref i31) (local.get $z))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then (return (local.get $z))))))

              ;; If z is a flonum, convert to fixnum if finite and integral
              (if (ref.test (ref $Flonum) (local.get $z))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.ne (local.get $f64) (local.get $f64))
                       (then (call $raise-expected-number (local.get $z)) (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const +inf))
                       (then (call $raise-expected-number (local.get $z)) (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const -inf))
                       (then (call $raise-expected-number (local.get $z)) (unreachable)))
                   (if (f64.eq (f64.floor (local.get $f64)) (local.get $f64))
                       (then
                        (local.set $i32 (i32.trunc_f64_s (local.get $f64)))
                        (return (ref.i31 (i32.shl (local.get $i32) (i32.const 1)))))
                       (else (call $raise-expected-number (local.get $z)) (unreachable)))))

              ;; Not a number
              (call $raise-expected-number (local.get $z))
              (unreachable))


        (func $exact->inexact (type $Prim1)
              (param $z (ref eq))
              (result   (ref eq))

              (local $bits i32)

              ;; If z is already a flonum, return it
              (if (ref.test (ref $Flonum) (local.get $z))
                  (then (return (local.get $z))))

              ;; If z is a fixnum, ensure LSB = 0 and convert
              (if (ref.test (ref i31) (local.get $z))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $z))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then (return (struct.new $Flonum (i32.const 0)
                                                 (f64.convert_i32_s
                                                  (i32.shr_s (local.get $bits)
                                                             (i32.const 1)))))))))

              ;; Not a number
              (call $raise-expected-real (global.get $symbol:exact->inexact) (local.get $z))
              (unreachable))


        (func $real->double-flonum (type $Prim1)
              (param $x (ref eq))
              (result   (ref eq))

              (local $bits i32)

              ;; If x is already a flonum, return it
              (if (ref.test (ref $Flonum) (local.get $x))
                  (then (return (local.get $x))))

              ;; If x is a fixnum, ensure LSB = 0 and convert
              (if (ref.test (ref i31) (local.get $x))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then (return (struct.new $Flonum (i32.const 0)
                                                 (f64.convert_i32_s
                                                  (i32.shr_s (local.get $bits)
                                                             (i32.const 1)))))))))

              ;; Not a number
              (call $raise-expected-real (global.get $symbol:real->double-flonum) (local.get $x))
              (unreachable))


        (func $zero? (type $Prim1)
              (param $x (ref eq))
              (result   (ref eq))

               (local $x/fx i32)
               (local $x/fl (ref $Flonum))

               ;; If x is a fixnum, check if it's 0
               (if (ref.test (ref i31) (local.get $x))
                   (then
                    (local.set $x/fx (i31.get_u (ref.cast (ref i31) (local.get $x))))
                    (if (i32.eqz (i32.and (local.get $x/fx) (i32.const 1))) ;; lsb = 0?
                        (then
                         (if (i32.eqz (i32.shr_u (local.get $x/fx) (i32.const 1))) ;; value == 0?
                             (then (return (global.get $true)))
                             (else (return (global.get $false)))))
                        (else (call $raise-expected-number (local.get $x)) (unreachable)))))
               ;; If x is a flonum, check if it's 0.0
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (if (f64.eq (struct.get $Flonum $v (local.get $x/fl)) (f64.const 0.0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               ;; Not a number
               (call $raise-expected-number (local.get $x))
               (unreachable))

        (func $integer-sqrt (type $Prim1)
              (param $n (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)
              (local $i32 i32)

              ;; Fixnum case
              (if (ref.test (ref i31) (local.get $n))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $n))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then
                        (local.set $i32 (i32.shr_s (local.get $bits) (i32.const 1)))
                        (local.set $f64 (f64.floor (call $js-raw-math-sqrt (f64.convert_i32_s (local.get $i32)))))
                        (if (i32.ge_s (local.get $i32) (i32.const 0))
                            (then
                             (local.set $i32 (i32.trunc_f64_s (local.get $f64)))
                             (return (ref.i31 (i32.shl (local.get $i32) (i32.const 1)))))
                            (else
                             (return (struct.new $Flonum (i32.const 0) (local.get $f64))))))
                       (else (call $raise-expected-number (local.get $n))
                             (unreachable)))))

              ;; Flonum case
              (if (ref.test (ref $Flonum) (local.get $n))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.eq (f64.floor (local.get $f64)) (local.get $f64))
                       (then
                        (return (struct.new $Flonum
                                            (i32.const 0)
                                            (f64.floor (call $js-raw-math-sqrt (local.get $f64))))))
                       (else (call $raise-expected-number (local.get $n))
                             (unreachable)))))

              ;; Not a number
              (call $raise-expected-number (local.get $n))
              (unreachable))

        (func $integer-sqrt/remainder (type $Prim1)
              (param $n (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)
              (local $i32 i32)
              (local $sqrtf f64)
              (local $remf f64)
              (local $sq i32)
              (local $rem i32)

              ;; Fixnum case
              (if (ref.test (ref i31) (local.get $n))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $n))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then
                        (local.set $i32 (i32.shr_s (local.get $bits) (i32.const 1)))
                        (local.set $sqrtf (f64.floor (call $js-raw-math-sqrt (f64.convert_i32_s (local.get $i32)))))
                        (if (i32.ge_s (local.get $i32) (i32.const 0))
                            (then
                             (local.set $sq   (i32.trunc_f64_s (local.get $sqrtf)))
                             (local.set $rem  (i32.sub (local.get $i32) (i32.mul (local.get $sq) (local.get $sq))))
                             (return (array.new_fixed $Values 2
                                                       (ref.i31 (i32.shl (local.get $sq) (i32.const 1)))
                                                       (ref.i31 (i32.shl (local.get $rem) (i32.const 1))))))
                            (else
                             (local.set $remf (f64.sub (f64.convert_i32_s (local.get $i32))
                                                       (f64.mul (local.get $sqrtf) (local.get $sqrtf))))
                             (return (array.new_fixed $Values 2
                                                       (struct.new $Flonum (i32.const 0) (local.get $sqrtf))
                                                       (struct.new $Flonum (i32.const 0) (local.get $remf))))))
                       (else (call $raise-expected-number (local.get $n))
                             (unreachable))))))

              ;; Flonum case
              (if (ref.test (ref $Flonum) (local.get $n))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.eq (f64.floor (local.get $f64)) (local.get $f64))
                       (then
                        (local.set $sqrtf (f64.floor (call $js-raw-math-sqrt (local.get $f64))))
                        (local.set $remf (f64.sub (local.get $f64) (f64.mul (local.get $sqrtf) (local.get $sqrtf))))
                        (return (array.new_fixed $Values 2
                                                  (struct.new $Flonum (i32.const 0) (local.get $sqrtf))
                                                  (struct.new $Flonum (i32.const 0) (local.get $remf)))))
                       (else (call $raise-expected-number (local.get $n))
                             (unreachable)))))

              ;; Not a number
              (call $raise-expected-number (local.get $n))
              (unreachable))

        ; Note:
        ;   The JavaScript math.pow function handles pow(-1,inf.0) does not follow IEEE 704,
        ;   which says 1 is the result (in order to preserve a correct magnitude).
        (func $pow-special
              (param $base f64)
              (param $exp  f64)
              (result      f64)

              (local $abs-base f64)

              (local.set $abs-base (f64.abs (local.get $base)))
              (if (f64.eq (local.get $abs-base) (f64.const 1.0))
                  (then
                   (if (f64.eq (local.get $exp) (f64.const inf))
                       (then (return (f64.const 1.0))))
                   (if (f64.eq (local.get $exp) (f64.const -inf))
                       (then (return (f64.const 1.0))))))

              ; Handle 1.0^w according to IEEE 704-2019.
              (if (f64.eq (local.get $base) (f64.const 1.0))
                  (then (return (f64.const 1.0))))

              (call $js-raw-math-pow (local.get $base) (local.get $exp)))

        (func $expt (type $Prim2)
              (param $z (ref eq))
              (param $w (ref eq))
              (result   (ref eq))

              (local $zbits  i32)
              (local $wbits  i32)
              (local $zf64   f64)
              (local $wf64   f64)
              (local $res    f64)
              (local $exactz i32)
              (local $exactw i32)

              ;; Decode z
              (if (ref.test (ref i31) (local.get $z))
                  (then
                   (local.set $zbits (i31.get_s (ref.cast (ref i31) (local.get $z))))
                   (if (i32.eqz (i32.and (local.get $zbits) (i32.const 1)))
                       (then
                        (local.set $zf64 (f64.convert_i32_s (i32.shr_s (local.get $zbits) (i32.const 1))))
                        (local.set $exactz (i32.const 1)))
                       (else (call $raise-expected-number (local.get $z)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $z))
                       (then
                        (local.set $zf64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $z))))
                        (local.set $exactz (i32.const 0)))
                       (else (call $raise-expected-number (local.get $z)) (unreachable)))))

              ;; Decode w
              (if (ref.test (ref i31) (local.get $w))
                  (then
                   (local.set $wbits (i31.get_s (ref.cast (ref i31) (local.get $w))))
                   (if (i32.eqz (i32.and (local.get $wbits) (i32.const 1)))
                       (then
                        (local.set $wf64 (f64.convert_i32_s (i32.shr_s (local.get $wbits) (i32.const 1))))
                        (local.set $exactw (i32.const 1)))
                       (else (call $raise-expected-number (local.get $w)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $w))
                       (then
                        (local.set $wf64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $w))))
                        (local.set $exactw (i32.const 0)))
                       (else (call $raise-expected-number (local.get $w)) (unreachable)))))

              ;; Special cases for exact results
              (if (i32.and (local.get $exactw)
                           (i32.eqz (i32.shr_s (local.get $wbits) (i32.const 1))))
                  (then (return (ref.i31 (i32.const 2)))))
              (if (i32.and (local.get $exactz)
                           (i32.eq (i32.shr_s (local.get $zbits) (i32.const 1)) (i32.const 1)))
                  (then (return (ref.i31 (i32.const 2)))))

              ;; Handle the 1.0^w case explicitly because JavaScript's Math.pow
              ;; produces +nan.0 when w is +nan.0, while Racket (IEEE 704) specifies 1.0.
              (if (f64.eq (local.get $zf64) (f64.const 1.0))
                  (then (return (struct.new $Flonum (i32.const 0) (f64.const 1.0)))))

              ;; Compute using JS pow
              (local.set $res (call $pow-special (local.get $zf64) (local.get $wf64)))

              ;; If both operands exact and result integral within range, return fixnum
              (if (i32.and (local.get $exactz) (local.get $exactw))
                  (then
                       (if (f64.eq (f64.floor (local.get $res)) (local.get $res))
                       (then
                        ;; 536870911.0 = 2^29-1 and -536870912.0 = -2^29
                        ;; ensure result fits in fixnum range before converting
                        (if (f64.le (local.get $res) (f64.const 536870911.0))
                            (then
                             (if (f64.ge (local.get $res) (f64.const -536870912.0))
                                 (then
                                  (return (ref.i31 (i32.shl (i32.trunc_f64_s (local.get $res)) (i32.const 1))))))))))))

              (struct.new $Flonum (i32.const 0) (local.get $res)))

        (func $exp (type $Prim1)
              (param $x (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)

              ;; Fixnum case
              (if (ref.test (ref i31) (local.get $x))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then
                        (local.set $bits (i32.shr_s (local.get $bits) (i32.const 1)))
                        (if (i32.eqz (local.get $bits))
                            (then (return (ref.i31 (i32.const 2))))
                            (else
                             (local.set $f64 (call $js-raw-math-exp (f64.convert_i32_s (local.get $bits))))
                             (return (struct.new $Flonum (i32.const 0) (local.get $f64))))))
                       (else (call $raise-expected-number (local.get $x))
                             (unreachable)))))

              ;; Flonum case
              (if (ref.test (ref $Flonum) (local.get $x))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (return (struct.new $Flonum (i32.const 0) (call $js-raw-math-exp (local.get $f64))))))

              ;; Not a number
              (call $raise-expected-number (local.get $x))
              (unreachable))

        (func $log (type $Prim12)
              (param $z (ref eq))
              (param $b (ref eq))
              (result   (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $zf64 f64)
              (local $bf64 f64)
              (local $res f64)

              ;; Natural log when base is missing
              (if (ref.eq (local.get $b) (global.get $missing))
                  (then
                   (if (ref.test (ref i31) (local.get $z))
                       (then
                        (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $z))))
                        (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                            (then
                             (local.set $bits (i32.shr_s (local.get $bits) (i32.const 1)))
                             (if (i32.eqz (local.get $bits))
                                 (then (call $raise-division-by-zero) (unreachable)))
                             (if (i32.eq (local.get $bits) (i32.const 1))
                                 (then (return (ref.i31 (i32.const 0)))))
                             (local.set $res
                                        (call $js-raw-math-log (f64.convert_i32_s (local.get $bits))))
                             (return (struct.new $Flonum (i32.const 0) (local.get $res))))
                            (else (call $raise-expected-number (local.get $z)) (unreachable)))))
                   (if (ref.test (ref $Flonum) (local.get $z))
                       (then
                        (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                        (local.set $zf64 (struct.get $Flonum $v (local.get $fl)))
                        (return (struct.new $Flonum (i32.const 0)
                                            (call $js-raw-math-log (local.get $zf64))))))
                   (call $raise-expected-number (local.get $z))
                   (unreachable))
                  (else
                   ;; Log with base
                   (if (ref.test (ref i31) (local.get $z))
                       (then
                        (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $z))))
                        (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                            (then
                             (local.set $bits (i32.shr_s (local.get $bits) (i32.const 1)))
                             (if (i32.eqz (local.get $bits))
                                 (then (call $raise-division-by-zero) (unreachable)))
                             (local.set $zf64 (f64.convert_i32_s (local.get $bits))))
                            (else (call $raise-expected-number (local.get $z)) (unreachable))))
                       (else
                        (if (ref.test (ref $Flonum) (local.get $z))
                            (then
                             (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                             (local.set $zf64 (struct.get $Flonum $v (local.get $fl))))
                            (else (call $raise-expected-number (local.get $z)) (unreachable)))))
                   (if (ref.test (ref i31) (local.get $b))
                       (then
                        (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $b))))
                        (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                            (then
                             (local.set $bits (i32.shr_s (local.get $bits) (i32.const 1)))
                             (if (i32.eq (local.get $bits) (i32.const 1))
                                 (then (call $raise-division-by-zero) (unreachable)))
                             (local.set $bf64 (f64.convert_i32_s (local.get $bits))))
                            (else (call $raise-expected-number (local.get $b)) (unreachable))))
                       (else
                        (if (ref.test (ref $Flonum) (local.get $b))
                            (then
                             (local.set $fl (ref.cast (ref $Flonum) (local.get $b)))
                             (local.set $bf64 (struct.get $Flonum $v (local.get $fl))))
                            (else (call $raise-expected-number (local.get $b)) (unreachable)))))
                   (local.set $res
                              (f64.div (call $js-raw-math-log (local.get $zf64))
                                       (call $js-raw-math-log (local.get $bf64))))
                   (return (struct.new $Flonum (i32.const 0) (local.get $res)))))
              ;; Ensure static fallthrough is unreachable for the validator.
              (unreachable))


        ;; Generic numeric unary functions
         (func $positive? (type $Prim1)
               (param $x (ref eq))
               (result   (ref eq))

               (local $x/fx i32)
               (local $x/fl (ref $Flonum))

               ;; If x is a fixnum, check if it's > 0
               (if (ref.test (ref i31) (local.get $x))
                   (then
                    (local.set $x/fx (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (if (i32.eqz (i32.and (local.get $x/fx) (i32.const 1))) ;; lsb = 0?
                        (then
                         (if (i32.gt_s (i32.shr_s (local.get $x/fx) (i32.const 1))
                                       (i32.const 0))
                             (then (return (global.get $true)))
                             (else (return (global.get $false)))))
                        (else (call $raise-expected-number (local.get $x)) (unreachable)))))

               ;; If x is a flonum, check if it's > 0.0
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (if (f64.gt (struct.get $Flonum $v (local.get $x/fl)) (f64.const 0.0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Not a number
               (call $raise-expected-number (local.get $x))
               (unreachable))

         (func $negative? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $x/fx i32)
               (local $x/fl (ref $Flonum))

               ;; If x is a fixnum, check if it's < 0
               (if (ref.test (ref i31) (local.get $x))
                   (then
                    (local.set $x/fx (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (if (i32.eqz (i32.and (local.get $x/fx) (i32.const 1))) ;; lsb = 0?
                        (then
                         (if (i32.lt_s (i32.shr_s (local.get $x/fx) (i32.const 1)) (i32.const 0))
                             (then (return (global.get $true)))
                             (else (return (global.get $false)))))
                        (else (call $raise-expected-number (local.get $x)) (unreachable)))))

               ;; If x is a flonum, check if it's < 0.0
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (if (f64.lt (struct.get $Flonum $v (local.get $x/fl)) (f64.const 0.0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Not a number
               (call $raise-expected-number (local.get $x))
               (unreachable))

         (func $even? (type $Prim1)
               (param $n (ref eq))
               (result (ref eq))

               (local $bits i32)
               (local $fl (ref $Flonum))
               (local $f64 f64)
               (local $i32 i32)

               ;; Fixnum case
               (if (ref.test (ref i31) (local.get $n))
                   (then
                    (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $n))))
                    (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                        (then
                         (local.set $i32 (i32.shr_s (local.get $bits) (i32.const 1)))
                         (if (i32.eqz (i32.and (local.get $i32) (i32.const 1)))
                             (then (return (global.get $true)))
                             (else (return (global.get $false)))))
                        (else (call $raise-expected-number (local.get $n)) (unreachable)))))

               ;; Flonum case
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then
                    (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                    (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                    (if (f64.ne (local.get $f64) (local.get $f64))
                        (then (call $raise-expected-number (local.get $n)) (unreachable)))
                    (if (f64.eq (local.get $f64) (f64.const +inf))
                        (then (call $raise-expected-number (local.get $n)) (unreachable)))
                    (if (f64.eq (local.get $f64) (f64.const -inf))
                        (then (call $raise-expected-number (local.get $n)) (unreachable)))
                    (if (f64.eq (f64.floor (local.get $f64)) (local.get $f64))
                        (then
                         (local.set $i32 (i32.trunc_f64_s (local.get $f64)))
                         (if (i32.eqz (i32.and (local.get $i32) (i32.const 1)))
                             (then (return (global.get $true)))
                             (else (return (global.get $false)))))
                        (else (call $raise-expected-number (local.get $n)) (unreachable)))))

               ;; Not an integer
               (call $raise-expected-number (local.get $n))
               (unreachable))

         (func $odd? (type $Prim1)
               (param $n (ref eq))
               (result (ref eq))

               (if (result (ref eq))
                   (ref.eq (call $even? (local.get $n)) (global.get $true))
                   (then (global.get $false))
                   (else (global.get $true))))


         (func $integer? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $v/fx i32)
               (local $v/fl (ref $Flonum))
               (local $f64v f64)

               ;; Case 1: fixnum
               (if (ref.test (ref i31) (local.get $v))
                   (then
                    (local.set $v/fx (i31.get_u (ref.cast (ref i31) (local.get $v))))
                    (if (i32.eqz (i32.and (local.get $v/fx) (i32.const 1)))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               ;; Case 2: flonum
               (if (ref.test (ref $Flonum) (local.get $v))
                   (then
                    (local.set $v/fl (ref.cast (ref $Flonum) (local.get $v)))
                    (local.set $f64v (struct.get $Flonum $v (local.get $v/fl)))
                    ;; Check: finite && round
                    (if (f64.ne (local.get $f64v) (local.get $f64v)) ;; NaN
                        (then (return (global.get $false))))
                    (if (f64.eq (local.get $f64v) (f64.const +inf)) ;; +inf.0
                        (then (return (global.get $false))))
                    (if (f64.eq (local.get $f64v) (f64.const -inf)) ;; -inf.0
                        (then (return (global.get $false))))
                    (if (f64.eq (f64.floor (local.get $f64v)) (local.get $f64v))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               ;; Not a number
               (return (global.get $false)))

         (func $nan? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $x/fl (ref $Flonum))
               (local $f64 f64)

               ;; Fixnum -> #f
               (if (ref.test (ref i31) (local.get $x))
                   (then (return (global.get $false))))

               ;; Flonum -> check NaN
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (local.set $f64 (struct.get $Flonum $v (local.get $x/fl)))
                    (if (f64.ne (local.get $f64) (local.get $f64))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Not a number
               (call $raise-expected-number (local.get $x))
               (unreachable))

         (func $infinite? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $x/fl (ref $Flonum))
               (local $f64 f64)

               ;; Fixnum -> #f
               (if (ref.test (ref i31) (local.get $x))
                   (then (return (global.get $false))))

               ;; Flonum -> check ±inf
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (local.set $f64 (struct.get $Flonum $v (local.get $x/fl)))
                    (if (f64.eq (local.get $f64) (f64.const +inf))
                        (then (return (global.get $true))))
                    (if (f64.eq (local.get $f64) (f64.const -inf))
                        (then (return (global.get $true))))
                    (return (global.get $false))))

               ;; Not a number
               (call $raise-expected-number (local.get $x))
               (unreachable))

         (func $positive-integer? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (if (result (ref eq))
                   (ref.eq (call $integer? (local.get $x)) (global.get $true))
                   (then (call $positive? (local.get $x)))
                   (else (global.get $false))))

         (func $negative-integer? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (if (result (ref eq))
                   (ref.eq (call $integer? (local.get $x)) (global.get $true))
                   (then (call $negative? (local.get $x)))
                   (else (global.get $false))))

         (func $nonpositive-integer? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (if (result (ref eq))
                   (ref.eq (call $integer? (local.get $x)) (global.get $true))
                   (then (if (result (ref eq))
                             (ref.eq (call $positive? (local.get $x)) (global.get $true))
                             (then (global.get $false))
                             (else (global.get $true))))
                   (else (global.get $false))))

         (func $nonnegative-integer? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (if (result (ref eq))
                   (ref.eq (call $integer? (local.get $x)) (global.get $true))
                   (then (if (result (ref eq))
                             (ref.eq (call $negative? (local.get $x)) (global.get $true))
                             (then (global.get $false))
                             (else (global.get $true))))
                   (else (global.get $false))))

         (func $natural? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (call $exact-nonnegative-integer? (local.get $x)))


     )))


;; generic-numeric-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic numeric helpers.
(define generic-numeric-runtime-only-helper-names
  '($quotient
    $remainder
    $modulo
    $quotient/remainder
    $add1
    $sub1
    $sqr
    $sqrt
    $abs
    $round
    $floor
    $ceiling
    $truncate
    $sgn
    $exact-round
    $exact-floor
    $exact-ceiling
    $exact-truncate
    $sin
    $cos
    $tan
    $asin
    $acos
    $sinh
    $cosh
    $tanh
    $asinh
    $acosh
    $atanh
    $atan
    $degrees->radians
    $radians->degrees
    $order-of-magnitude))

;; generic-numeric-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic numeric helpers that still depend on monolithic runtime globals.
(define generic-numeric-runtime-only-helpers
  (function-forms->runtime-helpers
   'generic-numeric-runtime-only-helpers
   `(
         ;; 4.3.2 Generic Numerics
         ;;     https://docs.racket-lang.org/reference/generic-numbers.html

         ;; 4.3.2.1 Arithmetic
         ;;   https://docs.racket-lang.org/reference/generic-numbers.html#%28part._.Arithmetic%29

         (func $quotient (type $Prim2)
               (param $n (ref eq))
               (param $m (ref eq))
               (result   (ref eq))

               (local $nu i32)
               (local $mu i32)
               (local $fl (ref $Flonum))
               (local $nf f64)
               (local $mf f64)
               (local $qf f64)

               ;; Case 1: both fixnums
               (if (ref.test (ref i31) (local.get $n))
                   (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                         (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                             (then (if (ref.test (ref i31) (local.get $m))
                                       (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                             (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                                 (then (return (call $fxquotient (local.get $n) (local.get $m)))))))))))

               ;; Case 2: flonum/inexact
               ;; convert n to f64
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                         (local.set $nf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $n))
                             (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                                   (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                                       (then (local.set $nf (f64.convert_i32_s (i32.shr_s (local.get $nu) (i32.const 1)))))
                                       (else (call $raise-expected-number (local.get $n)) (unreachable))))
                             (else (call $raise-expected-number (local.get $n)) (unreachable)))))

               ;; ensure n is a finite integer
               (if (f64.eq (local.get $nf) (f64.const inf))
                   (then (call $raise-expected-number (local.get $n)) (unreachable)))
               (if (f64.eq (local.get $nf) (f64.const -inf))
                   (then (call $raise-expected-number (local.get $n)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $nf)) (local.get $nf))
                   (then)
                   (else (call $raise-expected-number (local.get $n)) (unreachable)))

               ;; convert m to f64
               (if (ref.test (ref $Flonum) (local.get $m))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $m)))
                         (local.set $mf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $m))
                             (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                   (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                       (then (local.set $mf (f64.convert_i32_s (i32.shr_s (local.get $mu) (i32.const 1)))))
                                       (else (call $raise-expected-number (local.get $m)) (unreachable))))
                             (else (call $raise-expected-number (local.get $m)) (unreachable)))))

               ;; ensure m is a finite integer
               (if (f64.eq (local.get $mf) (f64.const inf))
                   (then (call $raise-expected-number (local.get $m)) (unreachable)))
               (if (f64.eq (local.get $mf) (f64.const -inf))
                   (then (call $raise-expected-number (local.get $m)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $mf)) (local.get $mf))
                   (then)
                   (else (call $raise-expected-number (local.get $m)) (unreachable)))

               ;; divide by zero?
               (if (f64.eq (local.get $mf) (f64.const 0.0))
                   (then (call $raise-division-by-zero) (unreachable)))

               ;; compute quotient in flonum
               (local.set $qf (f64.trunc (f64.div (local.get $nf) (local.get $mf))))
               (return (struct.new $Flonum (i32.const 0) (local.get $qf))))


         (func $remainder (type $Prim2)
               (param $n (ref eq))
               (param $m (ref eq))
               (result   (ref eq))

               (local $nu i32)
               (local $mu i32)
               (local $fl (ref $Flonum))
               (local $nf f64)
               (local $mf f64)
               (local $rf f64)

               ;; Case 1: both fixnums
               (if (ref.test (ref i31) (local.get $n))
                   (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                         (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                             (then (if (ref.test (ref i31) (local.get $m))
                                       (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                             (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                                 (then (if (i32.eqz (local.get $mu))
                                                           (then (call $raise-division-by-zero) (unreachable)))
                                                       (return (ref.i31 (i32.rem_s (local.get $nu) (local.get $mu))))))))))))

               ;; Case 2: flonum/inexact
               ;; convert n to f64
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                         (local.set $nf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $n))
                             (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                                   (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                                       (then (local.set $nf (f64.convert_i32_s (i32.shr_s (local.get $nu) (i32.const 1)))))
                                       (else (call $raise-expected-number (local.get $n)) (unreachable))))
                             (else (call $raise-expected-number (local.get $n)) (unreachable)))))

               ;; ensure n is a finite integer
               (if (f64.eq (local.get $nf) (f64.const inf))
                   (then (call $raise-expected-number (local.get $n)) (unreachable)))
               (if (f64.eq (local.get $nf) (f64.const -inf))
                   (then (call $raise-expected-number (local.get $n)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $nf)) (local.get $nf))
                   (then)
                   (else (call $raise-expected-number (local.get $n)) (unreachable)))

               ;; convert m to f64
               (if (ref.test (ref $Flonum) (local.get $m))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $m)))
                         (local.set $mf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $m))
                             (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                   (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                       (then (local.set $mf (f64.convert_i32_s (i32.shr_s (local.get $mu) (i32.const 1)))))
                                       (else (call $raise-expected-number (local.get $m)) (unreachable))))
                             (else (call $raise-expected-number (local.get $m)) (unreachable)))))

               ;; ensure m is a finite integer
               (if (f64.eq (local.get $mf) (f64.const inf))
                   (then (call $raise-expected-number (local.get $m)) (unreachable)))
               (if (f64.eq (local.get $mf) (f64.const -inf))
                   (then (call $raise-expected-number (local.get $m)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $mf)) (local.get $mf))
                   (then)
                   (else (call $raise-expected-number (local.get $m)) (unreachable)))

               ;; divide by zero?
               (if (f64.eq (local.get $mf) (f64.const 0.0))
                   (then (call $raise-division-by-zero) (unreachable)))

               ;; compute remainder in flonum
               (local.set $rf (f64.sub
                               (local.get $nf)
                               (f64.mul
                                (f64.trunc (f64.div (local.get $nf) (local.get $mf)))
                                (local.get $mf))))
                (return (struct.new $Flonum (i32.const 0) (local.get $rf))))

         (func $modulo (type $Prim2)
               (param $n (ref eq))
               (param $m (ref eq))
               (result (ref eq))

               (local $r  (ref eq))
               (local $ru i32)
               (local $mu i32)
               (local $fl (ref $Flonum))
               (local $mf f64)
               (local $rf f64)

               ;; Compute remainder; it validates numeric args and non-zero divisor.
               (local.set $r (call $remainder (local.get $n) (local.get $m)))
               ;; Convert m to f64 for sign checks; capture integer payload when fixnum.
               (if (ref.test (ref i31) (local.get $m))
                   (then
                    (local.set $mu (i31.get_s (ref.cast (ref i31) (local.get $m))))
                    ;; Ensure it's a fixnum (lsb=0), else raise (should be unreachable if
                    ;; $remainder already validated).
                    (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                        (then
                         (local.set $mf
                                    (f64.convert_i32_s
                                     (i32.shr_s (local.get $mu) (i32.const 1)))))
                        (else
                         (call $raise-expected-number (local.get $m))
                         (unreachable))))
                   (else
                    (local.set $fl (ref.cast (ref $Flonum) (local.get $m)))
                    (local.set $mf (struct.get $Flonum $v (local.get $fl)))))
               ;; Result expression: handle integer and flonum remainders.
               (if (result (ref eq))
                   (ref.test (ref i31) (local.get $r))
                   ;; --- Integer remainder case ------------------------------------------
                   (then
                    (block (result (ref eq))
                           (local.set $ru (i31.get_s (ref.cast (ref i31) (local.get $r))))
                           (if (result (ref eq))
                               (i32.eqz (local.get $ru))             ;; r == 0  → exact 0
                               (then (local.get $r))
                               ;; If r and m have same sign → r, else r + m (still a fixnum).
                               (else (if (result (ref eq))
                                         (i32.eq (i32.lt_s (local.get $ru) (i32.const 0))
                                                 (i32.lt_s (local.get $mu) (i32.const 0)))
                                         (then (local.get $r))
                                         (else (ref.i31
                                                (i32.add (local.get $ru) (local.get $mu)))))))))
                   ;; --- Flonum remainder case -------------------------------------------
                   (else
                    (block (result (ref eq))
                           (local.set $fl (ref.cast (ref $Flonum) (local.get $r)))
                           (local.set $rf (struct.get $Flonum $v (local.get $fl)))
                           (if (result (ref eq))
                               (f64.eq (local.get $rf) (f64.const 0.0))
                               ;; Preserve signed zero: 0.0 * mf carries mf's sign.
                               (then (struct.new $Flonum (i32.const 0)
                                                 (f64.mul (f64.const 0.0) (local.get $mf))))
                               ;; Non-zero: if signs match → r, else r + m.
                               (else (if (result (ref eq))
                                         (i32.eq (f64.lt (local.get $rf) (f64.const 0.0))
                                                 (f64.lt (local.get $mf) (f64.const 0.0)))
                                         (then (local.get $r))
                                         (else (struct.new $Flonum (i32.const 0)
                                                           (f64.add (local.get $rf) (local.get $mf)))))))))))


         (func $quotient/remainder (type $Prim2)
               (param $n (ref eq))
               (param $m (ref eq))
               (result   (ref eq))

               (local $nu i32)
               (local $mu i32)
               (local $q  i32)
               (local $r  i32)
               (local $fl (ref $Flonum))
               (local $nf f64)
               (local $mf f64)
               (local $qf f64)
               (local $rf f64)

               ;; Case 1: both fixnums
               (if (ref.test (ref i31) (local.get $n))
                   (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                         (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                             (then (if (ref.test (ref i31) (local.get $m))
                                       (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                             (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                                 (then (if (i32.eqz (local.get $mu))
                                                           (then (call $raise-division-by-zero) (unreachable)))
                                                      (local.set $q (i32.shl (i32.div_s (local.get $nu) (local.get $mu))
                                                                            (i32.const 1)))
                                                      (local.set $r (i32.rem_s (local.get $nu) (local.get $mu)))
                                                      (return (array.new_fixed $Values 2
                                                                              (ref.i31 (local.get $q))
                                                                              (ref.i31 (local.get $r))))))))))))

               ;; Case 2: flonum/inexact
               ;; convert n to f64
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                         (local.set $nf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $n))
                             (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                                   (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                                       (then (local.set $nf (f64.convert_i32_s (i32.shr_s (local.get $nu) (i32.const 1)))))
                                       (else (call $raise-expected-number (local.get $n)) (unreachable))))
                             (else (call $raise-expected-number (local.get $n)) (unreachable)))))

               ;; ensure n is a finite integer
               (if (f64.eq (local.get $nf) (f64.const inf))
                   (then (call $raise-expected-number (local.get $n)) (unreachable)))
               (if (f64.eq (local.get $nf) (f64.const -inf))
                   (then (call $raise-expected-number (local.get $n)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $nf)) (local.get $nf))
                   (then)
                   (else (call $raise-expected-number (local.get $n)) (unreachable)))

               ;; convert m to f64
               (if (ref.test (ref $Flonum) (local.get $m))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $m)))
                         (local.set $mf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $m))
                             (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                   (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                       (then (local.set $mf (f64.convert_i32_s (i32.shr_s (local.get $mu) (i32.const 1)))))
                                       (else (call $raise-expected-number (local.get $m)) (unreachable))))
                             (else (call $raise-expected-number (local.get $m)) (unreachable)))))

               ;; ensure m is a finite integer
               (if (f64.eq (local.get $mf) (f64.const inf))
                   (then (call $raise-expected-number (local.get $m)) (unreachable)))
               (if (f64.eq (local.get $mf) (f64.const -inf))
                   (then (call $raise-expected-number (local.get $m)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $mf)) (local.get $mf))
                   (then)
                   (else (call $raise-expected-number (local.get $m)) (unreachable)))

               ;; divide by zero?
               (if (f64.eq (local.get $mf) (f64.const 0.0))
                   (then (call $raise-division-by-zero) (unreachable)))

               ;; compute quotient and remainder in flonum
               (local.set $qf (f64.trunc (f64.div (local.get $nf) (local.get $mf))))
               (local.set $rf (f64.sub (local.get $nf) (f64.mul (local.get $qf) (local.get $mf))))
               (return (array.new_fixed $Values 2
                                        (struct.new $Flonum (i32.const 0) (local.get $qf))
                                        (struct.new $Flonum (i32.const 0) (local.get $rf)))))


         (func $add1 (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $v/fx i32)
               (local $sum  i32)
               (local $v/fl (ref $Flonum))
               (local $f64v f64)

               ;; Case 1: Fixnum
               (if (ref.test (ref i31) (local.get $v))
                   (then (local.set $v/fx (i31.get_u (ref.cast (ref i31) (local.get $v))))
                         (if (i32.eqz (i32.and (local.get $v/fx) (i32.const 1)))
                             (then (local.set $sum (i32.add (local.get $v/fx) (i32.const 2))) ;; add1 on unshifted
                                   (return (ref.i31 (local.get $sum)))))))
               ;; Case 2: Flonum
               (if (ref.test (ref $Flonum) (local.get $v))
                   (then (local.set $v/fl (ref.cast (ref $Flonum) (local.get $v)))
                         (local.set $f64v (struct.get $Flonum $v (local.get $v/fl)))
                         (return (struct.new $Flonum
                                             (i32.const 0)
                                             (f64.add (local.get $f64v) (f64.const 1.0))))))
               ;; Not a number
               (call $raise-expected-number (local.get $v))
               (unreachable))

         (func $sub1 (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $v/fx i32)
               (local $diff i32)
               (local $v/fl (ref $Flonum))
               (local $f64v f64)
               ;; Case 1: Fixnum
               (if (ref.test (ref i31) (local.get $v))
                   (then (local.set $v/fx (i31.get_u (ref.cast (ref i31) (local.get $v))))
                         (if (i32.eqz (i32.and (local.get $v/fx) (i32.const 1)))
                             (then (local.set $diff (i32.sub (local.get $v/fx) (i32.const 2))) ;; sub1 = -1 << 1
                                   (return (ref.i31 (local.get $diff)))))))
               ;; Case 2: Flonum
               (if (ref.test (ref $Flonum) (local.get $v))
                   (then (local.set $v/fl (ref.cast (ref $Flonum) (local.get $v)))
                         (local.set $f64v (struct.get $Flonum $v (local.get $v/fl)))
                         (return
                          (struct.new $Flonum
                                      (i32.const 0)
                                      (f64.sub (local.get $f64v) (f64.const 1.0))))))
               ;; Not a number
               (call $raise-expected-number (local.get $v))
               (unreachable))

         (func $sqr (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $bits i32)

               ;; Case 1: Fixnum
               (if (ref.test (ref i31) (local.get $x))
                   (then (local.set $bits (i31.get_u (ref.cast (ref i31) (local.get $x))))
                         (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                             (then (return (call $fx* (local.get $x) (local.get $x)))))))
               ;; Case 2: Flonum
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then (return (call $fl* (local.get $x) (local.get $x)))))
               ;; Not a number
               (call $raise-expected-number (local.get $x))
               (unreachable))


         (func $sqrt (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $bits i32)
               (local $fl (ref $Flonum))
               (local $f64 f64)

               ;; If x is a fixnum, compute sqrt and return fixnum if integral
               (if (ref.test (ref i31) (local.get $x))
                   (then
                    (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                        (then
                         (local.set $f64
                                    (call $js-raw-math-sqrt
                                          (f64.convert_i32_s
                                           (i32.shr_s (local.get $bits) (i32.const 1)))))
                         (if (f64.eq (f64.floor (local.get $f64)) (local.get $f64))
                             (then
                              (local.set $bits (i32.trunc_f64_s (local.get $f64)))
                              (return (ref.i31 (i32.shl (local.get $bits) (i32.const 1)))))
                             (else
                              (return (struct.new $Flonum (i32.const 0) (local.get $f64))))))
                        (else (call $raise-expected-number (local.get $x))
                              (unreachable)))))

               ;; If x is a flonum, compute sqrt and box
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                    (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                    (return (struct.new $Flonum
                                        (i32.const 0)
                                        (call $js-raw-math-sqrt (local.get $f64))))))

               ;; Not a number
               (call $raise-expected-number (local.get $x))
               (unreachable))


        ;; Generic numeric unary functions
        ;               name      kind    flonum-expr
        ; Implements: $abs $round $floor $ceiling $truncate
        ,@(let ([ops '((abs     fx-abs   (f64.abs     (local.get $f64)))
                       (round   fx-id    (f64.nearest (local.get $f64)))
                       (floor   fx-id    (f64.floor   (local.get $f64)))
                       (ceiling fx-id    (f64.ceil    (local.get $f64)))
                       (truncate fx-id   (f64.trunc   (local.get $f64))))])
            (for/list ([p ops])
              (define name (car p))
              (define kind (cadr p))
              (define expr (caddr p))
              (define fixstmts
                (case kind
                  [(fx-id)  `((return (local.get $x)))]
                  [(fx-abs) `((local.set $bits (i32.shr_s (local.get $bits) (i32.const 1)))
                              (if (i32.lt_s (local.get $bits) (i32.const 0))
                                  (then (local.set $bits (i32.sub (i32.const 0) (local.get $bits)))))
                              (if (i32.lt_u (local.get $bits) (i32.const 1073741824))
                                  (then (return (ref.i31 (i32.shl (local.get $bits) (i32.const 1)))))
                                  (else (return (struct.new $Flonum
                                                            (i32.const 0)
                                                            (f64.convert_i32_s (local.get $bits)))))))]))
              `(func ,(string->symbol (format "$~a" name))
                     (type $Prim1)
                     (param $x (ref eq))
                     (result (ref eq))

                     (local $bits i32)
                     (local $fl (ref $Flonum))
                     (local $f64 f64)

                     ;; Fixnum case
                     (if (ref.test (ref i31) (local.get $x))
                         (then
                          (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                          (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                              (then ,@fixstmts)
                              (else (call $raise-expected-number (local.get $x))
                                    (unreachable)))))

                     ;; Flonum case
                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (return (struct.new $Flonum
                                              (i32.const 0)
                                              ,expr))))

                     ;; Not a number
                     (call $raise-expected-number (local.get $x))
                     (unreachable))))

        (func $sgn (type $Prim1)
              (param $x (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $fl   (ref $Flonum))
              (local $f64  f64)

              ;; Fixnum case
              (if (ref.test (ref i31) (local.get $x))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then
                        (local.set $bits (i32.shr_s (local.get $bits) (i32.const 1)))
                        (if (i32.eqz (local.get $bits))
                            (then (return (local.get $x)))
                            (else (if (i32.gt_s (local.get $bits) (i32.const 0))
                                      (then (return ,(Imm 1)))
                                      (else (return ,(Imm -1)))))))
                       (else (call $raise-expected-number (local.get $x))
                             (unreachable)))))

              ;; Flonum case
              (if (ref.test (ref $Flonum) (local.get $x))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.eq (local.get $f64) (f64.const 0.0))
                       (then (return (local.get $x)))
                       (else (if (f64.gt (local.get $f64) (f64.const 0.0))
                                 (then (return (struct.new $Flonum (i32.const 0) (f64.const 1.0))))
                                 (else (if (f64.lt (local.get $f64) (f64.const 0.0))
                                           (then (return (struct.new $Flonum (i32.const 0) (f64.const -1.0))))
                                           (else (return (struct.new $Flonum (i32.const 0)
                                                                     (f64.div (f64.const 0.0)
                                                                              (f64.const 0.0))))))))))))

              ;; Not a number
              (call $raise-expected-number (local.get $x))
              (unreachable))

        ;; Exact integer rounding functions
        ;; Implements: $exact-round $exact-floor $exact-ceiling $exact-truncate
        ,@(let ([ops '((exact-round   f64.nearest)
                       (exact-floor   f64.floor)
                       (exact-ceiling f64.ceil)
                       (exact-truncate f64.trunc))])
            (for/list ([p ops])
              (define name (car p))
              (define expr (cadr p))
              `(func ,(string->symbol (format "$~a" name))
                     (type $Prim1)
                     (param $x (ref eq))
                     (result (ref eq))

                     (local $bits i32)
                     (local $fl (ref $Flonum))
                     (local $f64 f64)

                     ;; Fixnum case
                     (if (ref.test (ref i31) (local.get $x))
                         (then
                          (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                          (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                              (then (return (local.get $x)))
                              (else (call $raise-expected-number (local.get $x))
                                    (unreachable)))))

                     ;; Flonum case
                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (if (f64.ne (local.get $f64) (local.get $f64))
                              (then (call $raise-expected-number (local.get $x)) (unreachable)))
                          (if (f64.eq (local.get $f64) (f64.const +inf))
                              (then (call $raise-expected-number (local.get $x)) (unreachable)))
                          (if (f64.eq (local.get $f64) (f64.const -inf))
                              (then (call $raise-expected-number (local.get $x)) (unreachable)))
                          (local.set $f64 (,expr (local.get $f64)))
                          (if (f64.gt (local.get $f64) (f64.const 1073741823.0))
                              (then (call $raise-expected-number (local.get $x)) (unreachable)))
                          (if (f64.lt (local.get $f64) (f64.const -1073741824.0))
                              (then (call $raise-expected-number (local.get $x)) (unreachable)))
                          (local.set $bits (i32.trunc_f64_s (local.get $f64)))
                          (return (ref.i31 (i32.shl (local.get $bits) (i32.const 1))))))

                     ;; Not a number
                     (call $raise-expected-number (local.get $x))
                     (unreachable))))

        ;; Trigonometric functions
        ;               name js            inbits outbits
        ,@(let ([ops '((sin  $js-raw-math-sin  0      0)    ;  sin(0) = 0
                       (cos  $js-raw-math-cos  0      2)    ;  cos(0) = 1
                       (tan  $js-raw-math-tan  0      0)    ;  tan(0) = 0
                       (asin $js-raw-math-asin 0      0)    ; asin(0) = 0
                       (acos $js-raw-math-acos 2      0)    ; acos(1) = 0
                       (sinh  $js-raw-math-sinh  0      0) ;  sinh(0) = 0
                       (cosh  $js-raw-math-cosh  0      2) ;  cosh(0) = 1
                       (tanh  $js-raw-math-tanh  0      0) ;  tanh(0) = 0
                       (asinh $js-raw-math-asinh 0      0) ; asinh(0) = 0
                       (acosh $js-raw-math-acosh 2      0) ; acosh(1) = 0
                       (atanh $js-raw-math-atanh 0      0))]) ; atanh(0) = 0
            ;; inbits and outbits are raw i31 fixnum encodings.
            ;; They mark trivial exact identities of trig functions
            ;; (e.g. sin 0 = 0, cos 0 = 1, acos 1 = 0).
            ;; This avoids JS calls and flonum allocation in those cases.
            (for/list ([p ops])
              (define name    (car p))
              (define js      (cadr p))
              (define inbits  (caddr p))
              (define outbits (cadddr p))
              `(func ,(string->symbol (format "$~a" name))
                     (type $Prim1)
                     (param $x (ref eq))
                     (result (ref eq))

                     (local $bits i32)
                     (local $fl (ref $Flonum))
                     (local $f64 f64)

                     (if (ref.test (ref i31) (local.get $x))
                         (then
                          (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                          (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                              (then
                               (if (i32.eq (local.get $bits) (i32.const ,inbits))
                                   (then (return (ref.i31 (i32.const ,outbits)))))
                               (return (struct.new $Flonum
                                                   (i32.const 0)
                                                   (call ,js
                                                         (f64.convert_i32_s
                                                          (i32.shr_s (local.get $bits) (i32.const 1)))))))
                              (else (call $raise-expected-number (local.get $x))
                                    (unreachable)))))

                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (return (struct.new $Flonum
                                               (i32.const 0)
                                               (call ,js (local.get $f64))))))

                     (call $raise-expected-number (local.get $x))
                     (unreachable))))

        (func $atan (type $Prim12)
              (param $y (ref eq))
              (param $x (ref eq))
              (result   (ref eq))

              (local $bits i32)
              (local $y/f64 f64)
              (local $x/f64 f64)
              (local $y-exact i32)

              ;; Decode y. In the one-argument case this is the ordinary
              ;; unary atan input; with x present, Racket computes atan2(y, x).
              (if (ref.test (ref i31) (local.get $y))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $y))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then (local.set $y/f64
                                        (f64.convert_i32_s
                                         (i32.shr_s (local.get $bits) (i32.const 1))))
                             (local.set $y-exact (i32.const 1)))
                       (else (call $raise-expected-number (local.get $y)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $y))
                       (then (local.set $y/f64
                                        (struct.get $Flonum $v
                                                    (ref.cast (ref $Flonum) (local.get $y)))))
                       (else (call $raise-expected-number (local.get $y)) (unreachable)))))

              (if (ref.eq (local.get $x) (global.get $missing))
                  (then
                   (if (i32.and (local.get $y-exact)
                                (f64.eq (local.get $y/f64) (f64.const 0.0)))
                       (then (return ,(Imm 0))))
                   (return (struct.new $Flonum
                                       (i32.const 0)
                                       (call $js-raw-math-atan (local.get $y/f64))))))

              ;; Decode x for the two-argument case.
              (if (ref.test (ref i31) (local.get $x))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then (local.set $x/f64
                                        (f64.convert_i32_s
                                         (i32.shr_s (local.get $bits) (i32.const 1)))))
                       (else (call $raise-expected-number (local.get $x)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $x))
                       (then (local.set $x/f64
                                        (struct.get $Flonum $v
                                                    (ref.cast (ref $Flonum) (local.get $x)))))
                       (else (call $raise-expected-number (local.get $x)) (unreachable)))))

              (struct.new $Flonum
                          (i32.const 0)
                          (call $js-raw-math-atan2 (local.get $y/f64) (local.get $x/f64))))

        ;; Angle conversion functions
        ,@(let ([ops '((degrees->radians 0.017453292519943295)
                       (radians->degrees 57.29577951308232))])
            (for/list ([p ops])
              (define name (car p))
              (define factor (cadr p))
              `(func ,(string->symbol (format "$~a" name))
                     (type $Prim1)
                     (param $x (ref eq))
                     (result (ref eq))

                     (local $bits i32)
                     (local $fl (ref $Flonum))
                     (local $f64 f64)

                     (if (ref.test (ref i31) (local.get $x))
                         (then
                          (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                          (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                              (then
                               (local.set $f64
                                          (f64.mul
                                           (f64.convert_i32_s
                                            (i32.shr_s (local.get $bits) (i32.const 1)))
                                           (f64.const ,factor)))
                               (return (struct.new $Flonum
                                                   (i32.const 0)
                                                   (local.get $f64))))
                              (else (call $raise-expected-number (local.get $x))
                                    (unreachable)))))

                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (return (struct.new $Flonum
                                               (i32.const 0)
                                               (f64.mul (local.get $f64) (f64.const ,factor))))))

                    (call $raise-expected-number (local.get $x))
                    (unreachable))))

        (func $order-of-magnitude (type $Prim1)
              (param $r (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $i i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)
              (local $m i32)
              (local $p f64)
              (local $u f64)
              (local $ok i32)

              (local.set $ok (i32.const 0))

              (if (ref.test (ref i31) (local.get $r))
                  (then
                   (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $r))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then
                        (local.set $i (i32.shr_s (local.get $bits) (i32.const 1)))
                        (if (i32.gt_s (local.get $i) (i32.const 0))
                            (then
                             (local.set $f64 (f64.convert_i32_s (local.get $i)))
                             (local.set $ok (i32.const 1)))
                            (else (call $raise-argument-error/internal (local.get $r))
                                  (unreachable))))
                       (else (call $raise-argument-error/internal (local.get $r))
                             (unreachable)))))

              (if (i32.eqz (local.get $ok))
                  (then
                   (if (ref.test (ref $Flonum) (local.get $r))
                       (then
                        (local.set $fl (ref.cast (ref $Flonum) (local.get $r)))
                        (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                        (if (f64.le (local.get $f64) (f64.const 0))
                            (then (call $raise-argument-error/internal (local.get $r))
                                  (unreachable)))
                        (if (f64.eq (local.get $f64) (f64.const inf))
                            (then (call $raise-argument-error/internal (local.get $r))
                                  (unreachable)))
                        (if (f64.ne (local.get $f64) (local.get $f64))
                            (then (call $raise-argument-error/internal (local.get $r))
                                  (unreachable)))
                        (local.set $ok (i32.const 1))))))

              (if (i32.eqz (local.get $ok))
                  (then (call $raise-argument-error/internal (local.get $r))
                        (unreachable)))

              (local.set $m
                         (i32.trunc_f64_s
                          (f64.floor
                           (f64.mul
                            (call $js-raw-math-log (local.get $f64))
                            (f64.const 0.4342944819032518)))))
              (local.set $p
                         (call $js-raw-math-pow
                               (f64.const 10)
                               (f64.convert_i32_s (local.get $m))))

              (block $down
                     (loop $loop-down
                           (br_if $down (f64.le (local.get $p) (local.get $f64)))
                           (local.set $m (i32.sub (local.get $m) (i32.const 1)))
                           (local.set $p (f64.mul (local.get $p) (f64.const 0.1)))
                           (br $loop-down)))

              (local.set $u (f64.mul (local.get $p) (f64.const 10)))

              (block $up
                     (loop $loop-up
                           (br_if $up (f64.lt (local.get $f64) (local.get $u)))
                           (local.set $m (i32.add (local.get $m) (i32.const 1)))
                           (local.set $p (local.get $u))
                           (local.set $u (f64.mul (local.get $u) (f64.const 10)))
                           (br $loop-up)))

              (ref.i31 (i32.shl (local.get $m) (i32.const 1))))


     )))

;; generic-arithmetic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic arithmetic helpers.
(define generic-arithmetic-runtime-only-helper-names
  '($+/2
    $-/2
    $*/2
    $+
    $*
    $-
    $/2
    $/
    $gcd/2
    $gcd
    $lcm/2
    $lcm
    $=/2
    $</2
    $>/2
    $<=/2
    $>=/2
    $=
    $<
    $>
    $<=
    $>=
    $min/2
    $min
    $max/2
    $max))

;; generic-arithmetic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic arithmetic helpers that still depend on monolithic runtime globals.
(define generic-arithmetic-runtime-only-helpers
  (function-forms->runtime-helpers
   'generic-arithmetic-runtime-only-helpers
   `(
         ,@(let ()
             (define (binop $op $fxop $flop)
               `(func ,$op (type $Prim2)
                      (param $x (ref eq))
                      (param $y (ref eq))
                      (result   (ref eq))

                      (if (result (ref eq))
                          (call $fx?/i32 (local.get $x))
                          ; x fixnum
                          (then (if (result (ref eq))
                                    (call $fx?/i32 (local.get $y))
                                    ; x and y fixnums
                                    (then (call ,$fxop
                                                (local.get $x) (local.get $y)))
                                    ; x fixnum, y non-fixnum
                                    (else (if (result (ref eq))
                                              (call $fl?/i32 (local.get $y))
                                              ; x fixnum, y flonum
                                              (then (call ,$flop
                                                          (call $fx->fl/precise (local.get $x)) (local.get $y)))
                                              ; x fixnum, y not a number
                                              (else (call $raise-expected-number1 (local.get $y))
                                                    (unreachable))))))
                          ; x not fixnum
                          (else (if (result (ref eq))
                                    (call $fl?/i32 (local.get $x))
                                    ; x flonum
                                    (then (if (result (ref eq))
                                              (call $fl?/i32 (local.get $y))
                                              ; x flonum, y flonum
                                              (then (call ,$flop
                                                          (local.get $x) (local.get $y)))
                                              ; x flonum, y not flonum
                                              (else (if (result (ref eq))
                                                        (call $fx?/i32 (local.get $y))
                                                        ; x flonum, y fixnum
                                                        (then (call ,$flop
                                                                    (local.get $x) (call $fx->fl/precise (local.get $y))))
                                                        ; x flonum, y not a number
                                                        (else (call $raise-expected-number2 (local.get $y))
                                                              (unreachable))))))
                                    ; x is not a number
                                    (else (call $raise-expected-number3 (local.get $x))
                                          (unreachable)))))))
            (list (binop '$+/2 '$fx+ '$fl+)
                  (binop '$-/2 '$fx- '$fl-)
                  (binop '$*/2 '$fx* '$fl*)))

        (func $+ (type $Prim>=0)
               (param $xs0 (ref eq)) (result (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $r    (ref eq))

               (local.set $xs
                          (if (result (ref eq))
                              (ref.test (ref $Args) (local.get $xs0))
                              (then (call $rest-arguments->list
                                          (ref.cast (ref $Args) (local.get $xs0))
                                          (i32.const 0)))
                              (else (local.get $xs0))))
               (local.set $r (global.get $zero))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $r    (call $+/2 (local.get $r) (local.get $v)))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
              (local.get $r))

        (func $* (type $Prim>=0)
               (param $xs0 (ref eq)) (result (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $r    (ref eq))

               (local.set $xs
                          (if (result (ref eq))
                              (ref.test (ref $Args) (local.get $xs0))
                              (then (call $rest-arguments->list
                                          (ref.cast (ref $Args) (local.get $xs0))
                                          (i32.const 0)))
                              (else (local.get $xs0))))
               (local.set $r (global.get $one))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (if (ref.eq (call $fxzero? (local.get $v)) (global.get $true))
                                (then (local.set $r (global.get $zero))
                                      (br $done))
                                (else (local.set $r (call $*/2 (local.get $r) (local.get $v)))))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
              (local.get $r))

        (func $- (type $Prim>=1)
               (param $a1   (ref eq))
               (param $rest (ref eq))
               (result      (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $r    (ref eq))

               (local.set $xs (local.get $rest))
               (if (result (ref eq))
                   (ref.eq (local.get $xs) (global.get $null))
                   (then (call $-/2 (global.get $zero) (local.get $a1)))
                   (else (local.set $r (local.get $a1))
                         (block $done
                                (loop $loop
                                      (br_if $done
                                             (ref.eq (local.get $xs) (global.get $null)))
                                      (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                                      (local.set $v    (struct.get $Pair $a (local.get $node)))
                                      (local.set $r    (call $-/2 (local.get $r) (local.get $v)))
                                      (local.set $xs   (struct.get $Pair $d (local.get $node)))
                                      (br $loop)))
                         (local.get $r))))


        ;; Note: fx/ doesn't exist, but fxquotient do.

        (func $/2 (type $Prim2)
              (param $x (ref eq))
              (param $y (ref eq))
              (result   (ref eq))

               (local $x/fl (ref $Flonum))
               (local $y/fl (ref $Flonum))
               (local $xi i32) (local $yi i32) (local $r i32)
               ;; --- Check that $x is a number ---
               ; Note: $x is not a number if: it is not a fixnum and not a flonum
               (if (i32.and
                    (i32.eqz (ref.test (ref i31) (local.get $x)))
                    (i32.eqz (ref.test (ref $Flonum) (local.get $x))))
                   (then (call $raise-expected-number (local.get $x)) (unreachable)))
               ;; --- Check that $y is a number ---
               (if (i32.and
                    (i32.eqz (ref.test (ref i31) (local.get $y)))
                    (i32.eqz (ref.test (ref $Flonum) (local.get $y))))
                   (then (call $raise-expected-number (local.get $y)) (unreachable)))
               ;; --- Both fixnums? try exact division ---
               (if (result (ref eq))
                   (i32.and (ref.test (ref i31) (local.get $x))
                            (ref.test (ref i31) (local.get $y)))
                   (then (local.set $xi ,(Half `(i31.get_s (ref.cast i31ref (local.get $x)))))
                         (local.set $yi ,(Half `(i31.get_s (ref.cast i31ref (local.get $y)))))
                         (if (i32.eqz (local.get $yi))
                             (then (call $raise-division-by-zero) (unreachable)))
                         (local.set $r (i32.rem_s (local.get $xi) (local.get $yi)))
                         (if (result (ref eq))
                             (i32.eqz (local.get $r))
                             (then (ref.i31 ,(Double `(i32.div_s (local.get $xi) (local.get $yi)))))
                             (else (local.set $x/fl (call $fx->fl/precise (local.get $x)))
                                   (local.set $y/fl (call $fx->fl/precise (local.get $y)))
                                   (call $fl/ (local.get $x/fl) (local.get $y/fl)))))
                   (else (local.set $x/fl
                                    (if (result (ref $Flonum))
                                        (ref.test (ref $Flonum) (local.get $x))
                                        (then (ref.cast (ref $Flonum) (local.get $x)))
                                        (else (call $fx->fl/precise (local.get $x)))))
                         (local.set $y/fl
                                    (if (result (ref $Flonum))
                                        (ref.test (ref $Flonum) (local.get $y))
                                        (then (ref.cast (ref $Flonum) (local.get $y)))
                                        (else (call $fx->fl/precise (local.get $y)))))
                         (call $fl/ (local.get $x/fl) (local.get $y/fl)))))

        (func $/ (type $Prim>=1)
               (param $a1   (ref eq))
               (param $rest (ref eq))
               (result      (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $r    (ref eq))

               (local.set $xs (local.get $rest))
               (if (result (ref eq))
                   (ref.eq (local.get $xs) (global.get $null))
                   (then (call $/2 (global.get $one) (local.get $a1)))
                   (else (local.set $r (local.get $a1))
                         (block $done
                                (loop $loop
                                      (br_if $done
                                             (ref.eq (local.get $xs) (global.get $null)))
                                      (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                                      (local.set $v    (struct.get $Pair $a (local.get $node)))
                                      (local.set $r    (call $/2 (local.get $r) (local.get $v)))
                                      (local.set $xs   (struct.get $Pair $d (local.get $node)))
                                      (br $loop)))
                         (local.get $r))))

        (func $gcd/2 (type $Prim2)
               (param $n (ref eq))
               (param $m (ref eq))
               (result (ref eq))

               (local $tmp (ref eq))

               (local.set $n (call $abs (local.get $n)))
               (local.set $m (call $abs (local.get $m)))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (call $zero? (local.get $m)) (global.get $true)))
                            (local.set $tmp (local.get $m))
                            (local.set $m (call $remainder (local.get $n) (local.get $m)))
                            (local.set $n (local.get $tmp))
                            (br $loop)))
               (local.get $n))

         (func $gcd (type $Prim>=0)
               (param $xs0 (ref eq))
               (result (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $r    (ref eq))

               (local.set $xs
                          (if (result (ref eq))
                              (ref.test (ref $Args) (local.get $xs0))
                              (then (call $rest-arguments->list
                                          (ref.cast (ref $Args) (local.get $xs0))
                                          (i32.const 0)))
                              (else (local.get $xs0))))
               (local.set $r ,(Imm 0))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $r    (call $gcd/2 (local.get $r) (local.get $v)))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (local.get $r))

         (func $lcm/2 (type $Prim2)
               (param $n (ref eq))
               (param $m (ref eq))
               (result (ref eq))

               (local $g (ref eq))

               ;; Work with absolute values.
               (local.set $n (call $abs (local.get $n)))
               (local.set $m (call $abs (local.get $m)))

               ;; Expression style: the top-level IF yields the final (ref eq).
               (if (result (ref eq))
                   (ref.eq (call $zero? (local.get $n)) (global.get $true))
                   ;; THEN: n = 0
                   (then (if (result (ref eq))
                             (ref.eq (call $zero? (local.get $m)) (global.get $true))
                             ;; both zero: prefer inexact if any is inexact
                             (then (if (result (ref eq))
                                       (ref.eq (call $exact? (local.get $n)) (global.get $true))
                                       (then (if (result (ref eq))
                                                 (ref.eq (call $exact? (local.get $m)) (global.get $true))
                                                 (then (local.get $n))                    ;; both exact zeros → n (exact 0)
                                                 (else (local.get $m))))                  ;; m is inexact zero → m
                                       (else (local.get $n))))                            ;; n is inexact zero → n
                             ;; n = 0, m ≠ 0 → 0 (preserve n’s zero)
                             (else (local.get $n))))
                   ;; ELSE: n ≠ 0
                   (else (if (result (ref eq))
                             (ref.eq (call $zero? (local.get $m)) (global.get $true))
                             ;; m = 0, n ≠ 0 → 0 (preserve m’s zero)
                             (then (local.get $m))
                             ;; general case: lcm(n,m) = (n / gcd(n,m)) * m
                             (else (block (result (ref eq))
                                          (local.set $g (call $gcd/2 (local.get $n) (local.get $m)))
                                          (call $*/2
                                                (if (result (ref eq))
                                                    (i32.and (call $fx?/i32 (local.get $n))
                                                             (call $fx?/i32 (local.get $g)))
                                                    (then (call $quotient (local.get $n)
                                                                          (local.get $g)))
                                                    (else (call $/2 (local.get $n)
                                                                   (local.get $g))))
                                                (local.get $m))))))))



         (func $lcm (type $Prim>=0)
               (param $xs0 (ref eq))
               (result (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $v    (ref eq))
               (local $r    (ref eq))

               (local.set $xs
                          (if (result (ref eq))
                              (ref.test (ref $Args) (local.get $xs0))
                              (then (call $rest-arguments->list
                                          (ref.cast (ref $Args) (local.get $xs0))
                                          (i32.const 0)))
                              (else (local.get $xs0))))
               (local.set $r ,(Imm 1))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (local.set $r    (call $lcm/2 (local.get $r) (local.get $v)))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (br $loop)))
               (local.get $r))

         ;; Binary number comparators
         ,@(let ()
             (define (gencmp cmp fxcmp flcmp)
               `(func ,cmp
                      (param $x (ref eq))
                      (param $y (ref eq))
                      (result   (ref eq))

                      (local $x/is-fx i32)
                      (local $y/is-fx i32)
                      (local $x/is-fl i32)
                      (local $y/is-fl i32)
                      (local $x-fx    i32)
                      (local $y-fx    i32)
                      (local $x-fl    (ref null $Flonum))
                      (local $y-fl    (ref null $Flonum))
                      ;; --- Check if x is a fixnum ---
                      (local.set $x/is-fx (ref.test (ref i31) (local.get $x)))
                      (if (local.get $x/is-fx)
                          (then (local.set $x-fx (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                ;; Check low bit is 0 => valid fixnum
                                (if (i32.and (local.get $x-fx) (i32.const 1))
                                    (then (call $raise-check-fixnum (local.get $x)) (unreachable)))))
                      ;; --- Check if x is a flonum ---
                      (local.set $x/is-fl (ref.test (ref $Flonum) (local.get $x)))
                      ;; --- Raise if x is not a number ---
                      (if (i32.eqz (i32.or (local.get $x/is-fx) (local.get $x/is-fl)))
                          (then (call $raise-expected-number (local.get $x)) (unreachable)))
                      ;; --- Check if y is a fixnum ---
                      (local.set $y/is-fx (ref.test (ref i31) (local.get $y)))
                      (if (local.get $y/is-fx)
                          (then (local.set $y-fx (i31.get_u (ref.cast (ref i31) (local.get $y))))
                                (if (i32.and (local.get $y-fx) (i32.const 1))
                                    (then (call $raise-check-fixnum (local.get $y)) (unreachable)))))
                      ;; --- Check if y is a flonum ---
                      (local.set $y/is-fl (ref.test (ref $Flonum) (local.get $y)))
                      ;; --- Raise if y is not a number ---
                      (if (i32.eqz (i32.or (local.get $y/is-fx) (local.get $y/is-fl)))
                          (then (call $raise-expected-number (local.get $y)) (unreachable)))
                      ;; --- If both are fixnums, use fx< ---
                      (if (i32.and (local.get $x/is-fx) (local.get $y/is-fx))
                          (then (return (call ,fxcmp (local.get $x) (local.get $y)))))
                      ;; --- If both are flonums, use fl< ---
                      (if (i32.and (local.get $x/is-fl) (local.get $y/is-fl))
                          (then (return (call ,flcmp (local.get $x) (local.get $y)))))
                      ;; --- Mixed case: promote to flonum as needed ---
                      (if (local.get $x/is-fl)
                          (then (local.set $x-fl (ref.cast (ref $Flonum) (local.get $x))))
                          (else (local.set $x-fl (call $fx->fl/precise (local.get $x)))))
                      (if (local.get $y/is-fl)
                          (then (local.set $y-fl (ref.cast (ref $Flonum) (local.get $y))))
                          (else (local.set $y-fl (call $fx->fl/precise (local.get $y)))))

                      (call ,flcmp
                            (ref.as_non_null (local.get $x-fl))
                            (ref.as_non_null (local.get $y-fl)))))

             (list (gencmp '$=/2  '$fx=/2  '$fl=)   ; maybe specialize this one?
                   (gencmp '$</2  '$fx</2  '$fl<)
                   (gencmp '$>/2  '$fx>/2  '$fl>)
                   (gencmp '$<=/2 '$fx<=/2 '$fl<=)
                   (gencmp '$>=/2 '$fx>=/2 '$fl>=)))

         ;; Variadic Number Comparators
         ,@(let ()
             (define (gen-variadic-cmp name cmp/2)
               `(func ,name (type $Prim>=1)
                      (param $x0  (ref eq))
                      (param $xs0 (ref eq))
                      (result     (ref eq))

                      (local $xs      (ref eq))
                      (local $node    (ref $Pair))
                      (local $prev    (ref eq))
                      (local $curr    (ref eq))
                      (local $res     (ref eq))
                      (local $x/is-fx i32)
                      (local $x/is-fl i32)
                      (local $x-fx    i32)

                      (local.set $xs
                                 (if (result (ref eq))
                                     (ref.test (ref $Args) (local.get $xs0))
                                     (then (call $rest-arguments->list
                                                 (ref.cast (ref $Args) (local.get $xs0))
                                                 (i32.const 0)))
                                     (else (local.get $xs0))))

                      ;; Single argument: ensure it is a number and return #t.
                      (if (ref.eq (local.get $xs) (global.get $null))
                          (then (local.set $x/is-fx (ref.test (ref i31) (local.get $x0)))
                                (if (local.get $x/is-fx)
                                    (then (local.set $x-fx (i31.get_u (ref.cast (ref i31) (local.get $x0))))
                                          (if (i32.and (local.get $x-fx) (i32.const 1))
                                              (then (call $raise-check-fixnum (local.get $x0)) (unreachable)))))
                                (local.set $x/is-fl (ref.test (ref $Flonum) (local.get $x0)))
                                (if (i32.eqz (i32.or (local.get $x/is-fx) (local.get $x/is-fl)))
                                    (then (call $raise-expected-number (local.get $x0)) (unreachable)))
                                (return ,(Imm #t))))

                      (local.set $res  ,(Imm #t))
                      (local.set $prev (local.get $x0))
                      (block $done
                             (loop $loop
                                   (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                                   (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                                       (then (call $raise-pair-expected (local.get $xs))
                                             (unreachable)))
                                   (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                                   (local.set $curr (struct.get $Pair $a (local.get $node)))
                                   (local.set $res  (call ,cmp/2 (local.get $prev) (local.get $curr)))
                                   (if (ref.eq (local.get $res) ,(Imm #f))
                                       (then (return ,(Imm #f))))
                                   (local.set $prev (local.get $curr))
                                   (local.set $xs   (struct.get $Pair $d (local.get $node)))
                                   (br $loop)))
                      (local.get $res)))
             (list (gen-variadic-cmp '$=  '$=/2)
                   (gen-variadic-cmp '$<  '$</2)
                   (gen-variadic-cmp '$>  '$>/2)
                   (gen-variadic-cmp '$<= '$<=/2)
                   (gen-variadic-cmp '$>= '$>=/2)))

        ,@(let ()
            (define (gen-minmax name fxop flop)
              (define $name/2 (string->symbol (~a "$" name "/2")))
              (define $name   (string->symbol (~a "$" name)))
              `((func ,$name/2 (type $Prim2)
                      (param $x (ref eq))
                      (param $y (ref eq))
                      (result   (ref eq))

                      (local $x/is-fx i32)
                      (local $x/is-fl i32)
                      (local $x-fx    i32)
                      (local $x-fl    (ref $Flonum))

                      (local $y/is-fx i32)
                      (local $y/is-fl i32)
                      (local $y-fx    i32)
                      (local $y-fl    (ref $Flonum))

                      ; Initialize non-defaultable locals
                      (local.set $x-fl (ref.cast (ref $Flonum) (global.get $flzero)))
                      (local.set $y-fl (ref.cast (ref $Flonum) (global.get $flzero)))

                      ;; Type check $x
                      (local.set $x/is-fx (ref.test (ref i31) (local.get $x)))
                      (if (local.get $x/is-fx)
                          (then (local.set $x-fx (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                (if (i32.and (local.get $x-fx) (i32.const 1))
                                    (then (call $raise-check-fixnum (local.get $x)) (unreachable)))))
                      (local.set $x/is-fl (ref.test (ref $Flonum) (local.get $x)))
                      (if (i32.eqz (i32.or (local.get $x/is-fx) (local.get $x/is-fl)))
                          (then (call $raise-expected-number (local.get $x)) (unreachable)))

                      ;; Type check $y
                      (local.set $y/is-fx (ref.test (ref i31) (local.get $y)))
                      (if (local.get $y/is-fx)
                          (then (local.set $y-fx (i31.get_u (ref.cast (ref i31) (local.get $y))))
                                (if (i32.and (local.get $y-fx) (i32.const 1))
                                    (then (call $raise-check-fixnum (local.get $y)) (unreachable)))))
                      (local.set $y/is-fl (ref.test (ref $Flonum) (local.get $y)))
                      (if (i32.eqz (i32.or (local.get $y/is-fx) (local.get $y/is-fl)))
                          (then (call $raise-expected-number (local.get $y)) (unreachable)))

                      (if (i32.and (local.get $x/is-fx) (local.get $y/is-fx))
                          (then (return (call ,fxop (local.get $x) (local.get $y)))))

                      (if (local.get $x/is-fl)
                          (then (local.set $x-fl (ref.cast (ref $Flonum) (local.get $x))))
                          (else (local.set $x-fl (call $fx->fl/precise (local.get $x)))))
                      (if (local.get $y/is-fl)
                          (then (local.set $y-fl (ref.cast (ref $Flonum) (local.get $y))))
                          (else (local.set $y-fl (call $fx->fl/precise (local.get $y)))))

                      (call ,flop
                            (ref.as_non_null (local.get $x-fl))
                            (ref.as_non_null (local.get $y-fl))))

                (func ,$name (type $Prim>=1)
                      (param $x0  (ref eq))
                      (param $xs0 (ref eq))
                      (result     (ref eq))

                      (local $xs   (ref eq))
                      (local $node (ref $Pair))
                      (local $v    (ref eq))
                      (local $r    (ref eq))

                      (local.set $xs
                                 (if (result (ref eq))
                                     (ref.test (ref $Args) (local.get $xs0))
                                     (then (call $rest-arguments->list
                                                 (ref.cast (ref $Args) (local.get $xs0))
                                                 (i32.const 0)))
                                     (else (local.get $xs0))))

                      (if (ref.eq (local.get $xs) (global.get $null))
                          (then (return (call ,$name/2 (local.get $x0) (local.get $x0)))))
                      (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                          (then (call $raise-pair-expected (local.get $xs))
                                (unreachable)))
                      (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                      (local.set $v    (struct.get $Pair $a (local.get $node)))
                      (local.set $r    (call ,$name/2 (local.get $x0) (local.get $v)))
                      (local.set $xs   (struct.get $Pair $d (local.get $node)))

                      (block $done
                             (loop $loop
                                   (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                                   (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                                       (then (call $raise-pair-expected (local.get $xs))
                                             (unreachable)))
                                   (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                                   (local.set $v    (struct.get $Pair $a (local.get $node)))
                                   (local.set $r    (call ,$name/2 (local.get $r) (local.get $v)))
                                   (local.set $xs   (struct.get $Pair $d (local.get $node)))
                                   (br $loop)))
                      (local.get $r))))

            (append (gen-minmax 'min '$fxmin/2 '$unsafe-flmin/2)
                    (gen-minmax 'max '$fxmax/2 '$unsafe-flmax/2)))


     )))


;; number-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate number helpers that still depend on monolithic runtime globals.
(define number-runtime-only-helpers
  (append number-type-runtime-only-helpers
          generic-numeric-runtime-only-helpers
          generic-arithmetic-runtime-only-helpers))
