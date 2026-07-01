#lang racket

(provide number-runtime-only-helpers
         number-type-runtime-only-helper-names)

(require "../core-helper.rkt"
         "../../private/immediates.rkt")

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

;; number-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate number helpers that still depend on monolithic runtime globals.
(define number-runtime-only-helpers
  (function-forms->runtime-helpers
   'number-runtime-only-helpers
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
