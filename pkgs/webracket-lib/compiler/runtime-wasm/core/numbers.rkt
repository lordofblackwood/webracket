#lang racket

(provide generic-arithmetic-runtime-helper-forms
         number-runtime-string-constants
         number-runtime-symbol-constants
         generic-bitwise-runtime-helper-forms
         generic-numeric-runtime-helper-forms
         number-error-runtime-helper-forms
         number-core-runtime-helpers
         number-runtime-only-helpers
         number-string-conversion-runtime-helper-forms
         floating-point-byte-conversion-runtime-helper-forms
         numeric-formatting-runtime-helper-forms
         string-number-conversion-runtime-helper-forms
         number-type-runtime-helper-forms)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt"
         "../../private/immediates.rkt")

;; number-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by generic number predicates and errors.
(define number-runtime-string-constants
  '((number?                    "number?")
    (real?                      "real?")
    (integer?                   "integer?")
    (rational?                  "rational?")
    (exact-nonnegative-integer? "exact-nonnegative-integer?")
    (exact-integer?             "exact-integer?")
    (number->string:radix       "(or/c 2 8 10 16)")
    (slash                      "/")
    (string->number:radix       "(integer-in 2 16)")
    (real->floating-point-bytes:size "(or/c 4 8)")
    (real->floating-point-bytes:short-dest ": byte string length is shorter than starting position plus size")
    (real->floating-point-bytes:byte-string-length "\n  byte string length: ")
    (real->floating-point-bytes:starting-position "\n  starting position: ")
    (real->floating-point-bytes:size-line "\n  size: ")
    (floating-point-bytes->real:length-not-4-or-8 ": length is not 4 or 8 bytes")
    (floating-point-bytes->real:length-line "\n  length: ")
    (floating-point-bytes->real:index-line "\n  index: ")
    (inexact->exact:no-exact-representation ": no exact representation for ")
    (order-of-magnitude:positive-finite "(and/c (>/c 0.0) (not/c +inf.0))")
    (bitwise-bit-field:end-before-start "ending index is smaller than starting index")
    (angle:nonzero "(not/c zero?)")))

;; number-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by generic number helpers and errors.
(define number-runtime-symbol-constants
  '(+
    -
    *
    /
    =
    <
    >
    <=
    >=
    min
    max
    inexact->exact
    exact->inexact
    real->double-flonum
    zero?
    make-rectangular
    make-polar
    real-part
    imag-part
    magnitude
    angle
    conjugate
    integer-sqrt
    integer-sqrt/remainder
    expt
    exp
    log
    positive?
    negative?
    even?
    odd?
    nan?
    infinite?
    quotient
    remainder
    modulo
    quotient/remainder
    add1
    sub1
    gcd
    lcm
    sqr
    sqrt
    abs
    round
    floor
    ceiling
    truncate
    sgn
    exact-round
    exact-floor
    exact-ceiling
    exact-truncate
    numerator
    denominator
    rationalize
    sin
    cos
    tan
    asin
    acos
    sinh
    cosh
    tanh
    asinh
    acosh
    atanh
    atan
    degrees->radians
    radians->degrees
    order-of-magnitude
    bitwise-and
    bitwise-ior
    bitwise-xor
    bitwise-not
    bitwise-bit-set?
    bitwise-first-bit-set
    arithmetic-shift
    integer-length
    bitwise-bit-field))

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
    $exact-rational-expt/integer
    $number-expt/integer
    $expt
    $complex-exp
    $complex-log
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

;; number-string-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for number/string conversion helpers.
(define number-string-conversion-runtime-only-helper-names
  '($raise-number->string-bad-input
    $raise-number->string-bad-radix
    $number->string:check-radix
    $number->string:max-length
    $number->string:convert
    $number->string))

;; string-number-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string/number conversion helpers.
(define string-number-conversion-runtime-only-helper-names
  '($raise-string->number:bad-argument
    $raise-string->number:bad-radix
    $string->number:parse-fractional-part
    $string->number:parse-integer
    $string->number))

;; floating-point-byte-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for floating-point byte conversion helpers.
(define floating-point-byte-conversion-runtime-only-helper-names
  '($raise-real->floating-point-bytes:bad-size
    $raise-real->floating-point-bytes:bad-start
    $raise-real->floating-point-bytes:short-dest
    $raise-floating-point-bytes->real:bad-bytes
    $raise-floating-point-bytes->real:bad-index
    $raise-floating-point-bytes->real:bad-range
    $raise-floating-point-bytes->real:bad-length
    $floating-point-bytes->real
    $real->floating-point-bytes
    $real->floating-point-bytes/checked))

;; numeric-formatting-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for numeric formatting helpers.
(define numeric-formatting-runtime-only-helper-names
  '($f64->string
    $i32->string/pad6
    $f64->string/scientific
    $old:flonum->string
    $flonum->string
    $i32->string
    $arity-i32->string
    $i32->codepoints))

;; number-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for numeric error helpers.
(define number-error-runtime-only-helper-names
  '($raise-expected-number/common
    $raise-expected-number/who
    $raise-expected-number
    $raise-expected-number1
    $raise-expected-number2
    $raise-expected-number3
    $raise-expected-number4
    $raise-expected-integer
    $raise-expected-exact-integer
    $raise-expected-exact-nonnegative-integer
    $raise-expected-rational
    $raise-expected-real
    $raise-expected-keyword
    $raise-inexact->exact:no-exact-representation))

;; number-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given number helper names from a helper index.
(define (number-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; number-type-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render number-type helpers in runtime assembly order.
(define (number-type-runtime-helper-forms helper-index)
  (number-helper-forms helper-index number-type-runtime-only-helper-names))

;; generic-numeric-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render generic numeric helpers in runtime assembly order.
(define (generic-numeric-runtime-helper-forms helper-index)
  (number-helper-forms helper-index generic-numeric-runtime-only-helper-names))

;; number-error-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render numeric error helpers in runtime assembly order.
(define (number-error-runtime-helper-forms helper-index)
  (number-helper-forms helper-index number-error-runtime-only-helper-names))

;; generic-arithmetic-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render arithmetic and comparison helpers in runtime assembly order.
(define (generic-arithmetic-runtime-helper-forms helper-index)
  (number-helper-forms helper-index generic-arithmetic-runtime-only-helper-names))

;; generic-bitwise-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render bitwise numeric helpers in runtime assembly order.
(define (generic-bitwise-runtime-helper-forms helper-index)
  (number-helper-forms helper-index generic-bitwise-runtime-only-helper-names))

;; number-string-conversion-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render number/string conversion helpers in runtime assembly order.
(define (number-string-conversion-runtime-helper-forms helper-index)
  (number-helper-forms helper-index number-string-conversion-runtime-only-helper-names))

;; string-number-conversion-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render string/number conversion helpers in runtime assembly order.
(define (string-number-conversion-runtime-helper-forms helper-index)
  (number-helper-forms helper-index string-number-conversion-runtime-only-helper-names))

;; floating-point-byte-conversion-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render floating-point byte conversion helpers in runtime assembly order.
(define (floating-point-byte-conversion-runtime-helper-forms helper-index)
  (number-helper-forms helper-index floating-point-byte-conversion-runtime-only-helper-names))

;; numeric-formatting-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render numeric formatting helpers in runtime assembly order.
(define (numeric-formatting-runtime-helper-forms helper-index)
  (number-helper-forms helper-index numeric-formatting-runtime-only-helper-names))

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
	                             (ref.test (ref $Number) (local.get $v))
	                             (then (global.get $true))
	                             (else (global.get $false))))))

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
                            (ref.test (ref $Real) (local.get $v))
                            (then (global.get $true))
                            (else (global.get $false))))))

         (func $rational? (type $Prim1)
               ;; Racket reports finite flonums as rational? but not +inf.0,
               ;; -inf.0, or +nan.0. WebRacket exact rationals are canonical
               ;; $Rational values.
               (param $v (ref eq))
               (result (ref eq))
               (local $f64v f64)
               (if (ref.test i31ref (local.get $v))
                   (then
                    (if (i32.eqz (i32.and (i31.get_s (ref.cast i31ref (local.get $v)))
                                          (i32.const ,fixnum-mask)))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then (return (global.get $true))))
               (if (ref.test (ref $Rational) (local.get $v))
                   (then (return (global.get $true))))
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
               ;; Exact numbers are fixnums, bignums, exact rationals, and
               ;; complex numbers with exact components.
               (param $z (ref eq))
               (result   (ref eq))

               (local $bits i32)
               (local $c (ref $Complex))
               (if (result (ref eq))
                   (ref.test (ref i31) (local.get $z))
                   (then (local.set $bits (i31.get_u (ref.cast (ref i31) (local.get $z))))
                         (if (result (ref eq))
                             (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (if (result (ref eq))
                             (i32.or (ref.test (ref $Bignum) (local.get $z))
                                     (ref.test (ref $Rational) (local.get $z)))
                             (then (global.get $true))
                             (else
                              (if (result (ref eq))
                                  (ref.test (ref $Complex) (local.get $z))
                                  (then
                                   (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                                   (if (result (ref eq))
                                       (i32.and
                                        (ref.eq (call $exact?
                                                      (struct.get $Complex $real
                                                                  (local.get $c)))
                                                (global.get $true))
                                        (ref.eq (call $exact?
                                                      (struct.get $Complex $imag
                                                                  (local.get $c)))
                                                (global.get $true)))
                                       (then (global.get $true))
                                       (else (global.get $false))))
                                  (else (global.get $false))))))))

         (func $inexact? (type $Prim1)
               ;; A number is inexact if it is a flonum or a complex number
               ;; with at least one inexact component.
               (param $z (ref eq))
               (result   (ref eq))

               (local $c (ref $Complex))
               (if (result (ref eq))
                   (ref.test (ref $Flonum) (local.get $z))
                   (then (global.get $true))
                   (else
                    (if (result (ref eq))
                        (ref.test (ref $Complex) (local.get $z))
                        (then
                         (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                         (if (result (ref eq))
                             (i32.or
                              (ref.eq (call $inexact?
                                            (struct.get $Complex $real
                                                        (local.get $c)))
                                      (global.get $true))
                              (ref.eq (call $inexact?
                                            (struct.get $Complex $imag
                                                        (local.get $c)))
                                      (global.get $true)))
                             (then (global.get $true))
                             (else (global.get $false))))
                        (else (global.get $false))))))

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
                   (else (if (result (ref eq))
                             (ref.test (ref $Bignum) (local.get $v))
                             (then (global.get $true))
                             (else (global.get $false))))))

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

               ;; Bignums are canonical and zero is never represented as a bignum.
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then
                    (if (i32.gt_s (struct.get $Bignum $sign
                                              (ref.cast (ref $Bignum) (local.get $v)))
                                  (i32.const 0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Not an exact integer
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
               ;; Bignums are canonical and zero is never represented as a bignum.
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then
                    (if (i32.gt_s (struct.get $Bignum $sign
                                              (ref.cast (ref $Bignum) (local.get $v)))
                                  (i32.const 0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Not a positive exact integer
               (return (global.get $false)))




         (func $inexact->exact (type $Prim1)
              (param $z (ref eq))
              (result   (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)

              ;; If z is a fixnum, ensure LSB = 0 and return it
              (if (ref.test (ref i31) (local.get $z))
                  (then
                   (local.set $bits (i31.get_u (ref.cast (ref i31) (local.get $z))))
                   (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then (return (local.get $z))))))
              ;; Exact heap numbers are already exact.
              (if (ref.test (ref $Bignum) (local.get $z))
                  (then (return (local.get $z))))
              (if (ref.test (ref $Rational) (local.get $z))
                  (then (return (local.get $z))))

              ;; If z is a flonum, convert to fixnum if finite and integral
              (if (ref.test (ref $Flonum) (local.get $z))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.ne (local.get $f64) (local.get $f64))
                       (then (call $raise-inexact->exact:no-exact-representation
                                   (local.get $z))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const +inf))
                       (then (call $raise-inexact->exact:no-exact-representation
                                   (local.get $z))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const -inf))
                       (then (call $raise-inexact->exact:no-exact-representation
                                   (local.get $z))
                             (unreachable)))
                   (return (call $f64->exact-rational (local.get $f64)))))

              ;; Not a number
              (call $raise-expected-number/who
                    (global.get $symbol:inexact->exact)
                    (local.get $z))
              (unreachable))


        (func $exact->inexact (type $Prim1)
              (param $z (ref eq))
              (result   (ref eq))

              (local $bits i32)
              (local $c    (ref $Complex))

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
              ;; Convert exact heap numbers.
              (if (ref.test (ref $Bignum) (local.get $z))
                  (then
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $exact-rational->f64 (local.get $z))))))
              (if (ref.test (ref $Rational) (local.get $z))
                  (then
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $exact-rational->f64 (local.get $z))))))

              ;; Convert the components of a complex number.
              (if (ref.test (ref $Complex) (local.get $z))
                  (then
                   (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                   (return
                    (struct.new $Complex
                                (i32.const 0)
                                (call $exact->inexact
                                      (struct.get $Complex $real (local.get $c)))
                                (call $exact->inexact
                                      (struct.get $Complex $imag (local.get $c)))))))

              ;; Not a number
              (call $raise-expected-number/who
                    (global.get $symbol:exact->inexact)
                    (local.get $z))
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
              ;; Exact heap reals convert through the correctly-rounded path.
              (if (ref.test (ref $Bignum) (local.get $x))
                  (then
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $exact-rational->f64 (local.get $x))))))
              (if (ref.test (ref $Rational) (local.get $x))
                  (then
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $exact-rational->f64 (local.get $x))))))

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
                        (else (call $raise-expected-number/who
                                    (global.get $symbol:zero?)
                                    (local.get $x)) (unreachable)))))
               ;; If x is a flonum, check if it's 0.0
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (if (f64.eq (struct.get $Flonum $v (local.get $x/fl)) (f64.const 0.0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))
               ;; Canonical bignums never represent zero.
               (if (ref.test (ref $Bignum) (local.get $x))
                   (then (return (global.get $false))))
               ;; Canonical rationals never represent zero.
               (if (ref.test (ref $Rational) (local.get $x))
                   (then (return (global.get $false))))
               ;; Not a number
               (call $raise-expected-number/who
                     (global.get $symbol:zero?)
                     (local.get $x))
               (unreachable))

        (func $integer-sqrt (type $Prim1)
              (param $n (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)
              (local $i32 i32)
              (local $bn (ref $Bignum))

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
                       (else (call $raise-expected-integer
                                   (global.get $symbol:integer-sqrt)
                                   (local.get $n))
                             (unreachable)))))

              ;; Positive bignum case
              (if (ref.test (ref $Bignum) (local.get $n))
                  (then
                   (local.set $bn (ref.cast (ref $Bignum) (local.get $n)))
                   (if (i32.gt_s (struct.get $Bignum $sign (local.get $bn))
                                 (i32.const 0))
                       (then (return (call $integer-sqrt/exact
                                           (local.get $n)))))))

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
                       (else (call $raise-expected-integer
                                   (global.get $symbol:integer-sqrt)
                                   (local.get $n))
                             (unreachable)))))

              ;; Not a number
              (call $raise-expected-integer
                    (global.get $symbol:integer-sqrt)
                    (local.get $n))
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
              (local $bn (ref $Bignum))

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
                       (else (call $raise-expected-integer
                                   (global.get $symbol:integer-sqrt/remainder)
                                   (local.get $n))
                             (unreachable))))))

              ;; Positive bignum case
              (if (ref.test (ref $Bignum) (local.get $n))
                  (then
                   (local.set $bn (ref.cast (ref $Bignum) (local.get $n)))
                   (if (i32.gt_s (struct.get $Bignum $sign (local.get $bn))
                                 (i32.const 0))
                       (then (return (call $integer-sqrt/remainder/exact
                                           (local.get $n)))))))

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
                       (else (call $raise-expected-integer
                                   (global.get $symbol:integer-sqrt/remainder)
                                   (local.get $n))
                             (unreachable)))))

              ;; Not a number
              (call $raise-expected-integer
                    (global.get $symbol:integer-sqrt/remainder)
                    (local.get $n))
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

        ;; $exact-rational-expt/integer : exact-rational? exact-integer? -> exact-rational?
        ;;   Compute exact powers by exponentiation by squaring.
        (func $exact-rational-expt/integer
              (param $base (ref eq))
              (param $exp  (ref eq))
              (result      (ref eq))

              (local $negative-exp? i32)
              (local $e             (ref eq))
              (local $factor        (ref eq))
              (local $result        (ref eq))
              (local $vals          (ref $Values))

              (local.set $e      (ref.i31 (i32.const 0)))
              (local.set $factor (ref.i31 (i32.const 2)))
              (local.set $result (ref.i31 (i32.const 2)))
              (local.set $vals
                         (array.new_fixed $Values 2
                                          (ref.i31 (i32.const 0))
                                          (ref.i31 (i32.const 0))))
              (local.set $negative-exp?
                         (i32.lt_s (call $integer-sign/i32 (local.get $exp))
                                   (i32.const 0)))
              (if (local.get $negative-exp?)
                  (then
                   (if (call $exact-rational-zero?/i32 (local.get $base))
                       (then (call $raise-division-by-zero)
                             (unreachable)))
                   (local.set $e (call $integer-negate (local.get $exp))))
                  (else
                   (local.set $e (local.get $exp))))
              (local.set $factor (local.get $base))
              (local.set $result (ref.i31 (i32.const 2)))
              (block $done
                     (loop $loop
                           (br_if $done
                                  (call $integer-zero?/i32 (local.get $e)))
                           (if (i32.eqz
                                (call $integer-even?/i32 (local.get $e)))
                               (then
                                (local.set $result
                                           (call $exact-rational-mul/2
                                                 (local.get $result)
                                                 (local.get $factor)))))
                           (local.set $vals
                                      (call $integer-divmod
                                            (local.get $e)
                                            (ref.i31 (i32.const 4))))
                           (local.set $e
                                      (array.get $Values
                                                 (local.get $vals)
                                                 (i32.const 0)))
                           (br_if $done
                                  (call $integer-zero?/i32 (local.get $e)))
                           (local.set $factor
                                      (call $exact-rational-mul/2
                                            (local.get $factor)
                                            (local.get $factor)))
                           (br $loop)))
              (if (local.get $negative-exp?)
                  (then
                   (return
                    (call $rational-normalize
                          (call $exact-rational-denominator
                                (local.get $result))
                          (call $exact-rational-numerator
                                (local.get $result))))))
              (local.get $result))

        ;; number-expt/integer : number? exact-integer? -> number?
        ;;   Raise a number to an exact integer power by repeated squaring.
        (func $number-expt/integer
              (param $base (ref eq))
              (param $exp  (ref eq))
              (result      (ref eq))

              (local $negative-exp? i32)
              (local $e             (ref eq))
              (local $factor        (ref eq))
              (local $result        (ref eq))
              (local $vals          (ref $Values))

              (local.set $e      (ref.i31 (i32.const 0)))
              (local.set $factor (global.get $one))
              (local.set $result (global.get $one))
              (local.set $vals
                         (array.new_fixed $Values 2
                                          (ref.i31 (i32.const 0))
                                          (ref.i31 (i32.const 0))))
              (local.set $negative-exp?
                         (i32.lt_s (call $integer-sign/i32 (local.get $exp))
                                   (i32.const 0)))
              (if (local.get $negative-exp?)
                  (then (local.set $e (call $integer-negate (local.get $exp))))
                  (else (local.set $e (local.get $exp))))
              (local.set $factor (local.get $base))
              (block $done
                     (loop $loop
                           (br_if $done
                                  (call $integer-zero?/i32 (local.get $e)))
                           (if (i32.eqz
                                (call $integer-even?/i32 (local.get $e)))
                               (then
                                (local.set $result
                                           (call $*/2
                                                 (local.get $result)
                                                 (local.get $factor)))))
                           (local.set $vals
                                      (call $integer-divmod
                                            (local.get $e)
                                            (ref.i31 (i32.const 4))))
                           (local.set $e
                                      (array.get $Values
                                                 (local.get $vals)
                                                 (i32.const 0)))
                           (br_if $done
                                  (call $integer-zero?/i32 (local.get $e)))
                           (local.set $factor
                                      (call $*/2
                                            (local.get $factor)
                                            (local.get $factor)))
                           (br $loop)))
              (if (local.get $negative-exp?)
                  (then
                   (return
                    (call $/2
                          (global.get $one)
                          (local.get $result)))))
              (local.get $result))

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
              (local $z/complex i32)
              (local $w/complex i32)

              ;; Exact 1/2 exponent uses sqrt, which can return exact roots.
              (if (call $exact-rational-half?/i32 (local.get $w))
                  (then
                   (if (call $exact-rational?/i32 (local.get $z))
                       (then (return (call $sqrt (local.get $z)))))
                   (if (ref.test (ref $Flonum) (local.get $z))
                       (then (return (call $sqrt (local.get $z)))))
                   (if (ref.test (ref $Complex) (local.get $z))
                       (then (return (call $sqrt (local.get $z)))))))

              ;; Exact rational base with exact integer exponent.
              (if (i32.and
                   (call $exact-rational?/i32 (local.get $z))
                   (i32.or (call $fx?/i32 (local.get $w))
                           (ref.test (ref $Bignum) (local.get $w))))
                  (then
                   (return
                    (call $exact-rational-expt/integer
                          (local.get $z)
                          (local.get $w)))))

              ;; Complex base with exact integer exponent remains exact when
              ;; the repeated products and divisions are exact.
              (if (i32.and
                   (ref.test (ref $Complex) (local.get $z))
                   (i32.or (call $fx?/i32 (local.get $w))
                           (ref.test (ref $Bignum) (local.get $w))))
                  (then
                   (return
                    (call $number-expt/integer
                          (local.get $z)
                          (local.get $w)))))

              ;; General complex exponentiation.
              (local.set $z/complex (ref.test (ref $Complex) (local.get $z)))
              (local.set $w/complex (ref.test (ref $Complex) (local.get $w)))
              (if (i32.or (local.get $z/complex) (local.get $w/complex))
                  (then
                   (if (i32.eqz
                        (i32.or (local.get $z/complex)
                                (call $real-number?/i32 (local.get $z))))
                       (then (call $raise-expected-number/who
                                   (global.get $symbol:expt)
                                   (local.get $z))
                             (unreachable)))
                   (if (i32.eqz
                        (i32.or (local.get $w/complex)
                                (call $real-number?/i32 (local.get $w))))
                       (then (call $raise-expected-number/who
                                   (global.get $symbol:expt)
                                   (local.get $w))
                             (unreachable)))
                   (return
                    (call $exp
                          (call $*/2
                                (local.get $w)
                                (call $log
                                      (local.get $z)
                                      (global.get $missing)))))))

              ;; Decode z
              (if (ref.test (ref i31) (local.get $z))
                  (then
                   (local.set $zbits (i31.get_s (ref.cast (ref i31) (local.get $z))))
                   (if (i32.eqz (i32.and (local.get $zbits) (i32.const 1)))
                       (then
                        (local.set $zf64 (f64.convert_i32_s (i32.shr_s (local.get $zbits) (i32.const 1))))
                        (local.set $exactz (i32.const 1)))
                       (else (call $raise-expected-number/who
                                   (global.get $symbol:expt)
                                   (local.get $z)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $z))
                       (then
                        (local.set $zf64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $z))))
                        (local.set $exactz (i32.const 0)))
                       (else (call $raise-expected-number/who
                                   (global.get $symbol:expt)
                                   (local.get $z)) (unreachable)))))

              ;; Decode w
              (if (ref.test (ref i31) (local.get $w))
                  (then
                   (local.set $wbits (i31.get_s (ref.cast (ref i31) (local.get $w))))
                   (if (i32.eqz (i32.and (local.get $wbits) (i32.const 1)))
                       (then
                        (local.set $wf64 (f64.convert_i32_s (i32.shr_s (local.get $wbits) (i32.const 1))))
                        (local.set $exactw (i32.const 1)))
                       (else (call $raise-expected-number/who
                                   (global.get $symbol:expt)
                                   (local.get $w)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $w))
                       (then
                        (local.set $wf64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $w))))
                        (local.set $exactw (i32.const 0)))
                       (else (call $raise-expected-number/who
                                   (global.get $symbol:expt)
                                   (local.get $w)) (unreachable)))))

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

        ;; complex-exp : complex? -> number?
        ;;   Compute exp(a+bi) as exp(a) * (cos(b) + i sin(b)).
        (func $complex-exp
              (param $z (ref $Complex))
              (result (ref eq))

              (local $a     (ref eq))
              (local $b     (ref eq))
              (local $scale (ref eq))

              (local.set $a (struct.get $Complex $real (local.get $z)))
              (local.set $b (struct.get $Complex $imag (local.get $z)))
              (local.set $scale (call $exp (local.get $a)))
              (call $make-rectangular/canonical
                    (call $*/2
                          (local.get $scale)
                          (call $cos (local.get $b)))
                    (call $*/2
                          (local.get $scale)
                          (call $sin (local.get $b)))))

        ;; complex-log : complex? -> number?
        ;;   Compute the principal natural logarithm.
        (func $complex-log
              (param $z (ref $Complex))
              (result (ref eq))
              (call $make-rectangular/canonical
                    (call $log
                          (call $magnitude (local.get $z))
                          (global.get $missing))
                    (call $angle (local.get $z))))

        (func $exp (type $Prim1)
              (param $x (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $fl (ref $Flonum))
              (local $f64 f64)

              ;; Complex case
              (if (ref.test (ref $Complex) (local.get $x))
                  (then
                   (return
                    (call $complex-exp
                          (ref.cast (ref $Complex) (local.get $x))))))

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
                       (else (call $raise-expected-number/who
                                   (global.get $symbol:exp)
                                   (local.get $x))
                             (unreachable)))))

              ;; Flonum case
              (if (ref.test (ref $Flonum) (local.get $x))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (return (struct.new $Flonum (i32.const 0) (call $js-raw-math-exp (local.get $f64))))))

              ;; Exact rational heap case
              (if (call $exact-rational?/i32 (local.get $x))
                  (then
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $js-raw-math-exp
                                      (call $exact-rational->f64
                                            (local.get $x)))))))

              ;; Not a number
              (call $raise-expected-number/who
                    (global.get $symbol:exp)
                    (local.get $x))
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
              (local $cmp/i32 i32)

              ;; Natural log when base is missing
              (if (ref.eq (local.get $b) (global.get $missing))
                  (then
                   (if (ref.test (ref $Complex) (local.get $z))
                       (then
                        (return
                         (call $complex-log
                               (ref.cast (ref $Complex) (local.get $z))))))
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
                             (if (i32.lt_s (local.get $bits) (i32.const 0))
                                 (then
                                  (return
                                   (call $make-rectangular/canonical
                                         (struct.new $Flonum
                                                     (i32.const 0)
                                                     (call $js-raw-math-log
                                                           (f64.abs
                                                            (f64.convert_i32_s
                                                             (local.get $bits)))))
                                         (struct.new $Flonum
                                                     (i32.const 0)
                                                     (f64.const 3.141592653589793))))))
                             (local.set $res
                                        (call $js-raw-math-log (f64.convert_i32_s (local.get $bits))))
                             (return (struct.new $Flonum (i32.const 0) (local.get $res))))
                            (else (call $raise-expected-number/who
                                        (global.get $symbol:log)
                                        (local.get $z)) (unreachable)))))
                   (if (ref.test (ref $Flonum) (local.get $z))
                       (then
                        (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                        (local.set $zf64 (struct.get $Flonum $v (local.get $fl)))
                        (if (f64.lt (local.get $zf64) (f64.const 0.0))
                            (then
                             (return
                              (call $make-rectangular/canonical
                                    (struct.new $Flonum
                                                (i32.const 0)
                                                (call $js-raw-math-log
                                                      (f64.abs (local.get $zf64))))
                                    (struct.new $Flonum
                                                (i32.const 0)
                                                (f64.const 3.141592653589793))))))
                        (return (struct.new $Flonum (i32.const 0)
                                            (call $js-raw-math-log (local.get $zf64))))))
                   (if (call $exact-rational?/i32 (local.get $z))
                       (then
                        (if (call $exact-rational-zero?/i32 (local.get $z))
                            (then (call $raise-division-by-zero) (unreachable)))
                        (local.set $cmp/i32
                                   (call $exact-rational-compare/i32
                                         (local.get $z)
                                         (ref.i31 (i32.const 2))))
                        (if (i32.eqz (local.get $cmp/i32))
                            (then (return (ref.i31 (i32.const 0)))))
                        (if (i32.lt_s (local.get $cmp/i32) (i32.const 0))
                            (then
                             (return
                              (call $make-rectangular/canonical
                                    (struct.new $Flonum
                                                (i32.const 0)
                                                (call $js-raw-math-log
                                                      (f64.abs
                                                       (call $exact-rational->f64
                                                             (local.get $z)))))
                                    (struct.new $Flonum
                                                (i32.const 0)
                                                (f64.const 3.141592653589793))))))
                        (return
                         (struct.new $Flonum
                                     (i32.const 0)
                                     (call $js-raw-math-log
                                           (call $exact-rational->f64
                                                 (local.get $z)))))))
                   (call $raise-expected-number/who
                         (global.get $symbol:log)
                         (local.get $z))
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
                            (else (call $raise-expected-number/who
                                        (global.get $symbol:log)
                                        (local.get $z)) (unreachable))))
                       (else
                        (if (ref.test (ref $Flonum) (local.get $z))
                            (then
                             (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                             (local.set $zf64 (struct.get $Flonum $v (local.get $fl))))
                            (else
                             (if (call $exact-rational?/i32 (local.get $z))
                                 (then
                                  (if (call $exact-rational-zero?/i32 (local.get $z))
                                      (then (call $raise-division-by-zero) (unreachable)))
                                  (local.set $zf64
                                             (call $exact-rational->f64
                                                   (local.get $z))))
                                 (else (call $raise-expected-number/who
                                             (global.get $symbol:log)
                                             (local.get $z)) (unreachable)))))))
                   (if (ref.test (ref i31) (local.get $b))
                       (then
                        (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $b))))
                        (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                            (then
                             (local.set $bits (i32.shr_s (local.get $bits) (i32.const 1)))
                             (if (i32.eq (local.get $bits) (i32.const 1))
                                 (then (call $raise-division-by-zero) (unreachable)))
                             (local.set $bf64 (f64.convert_i32_s (local.get $bits))))
                            (else (call $raise-expected-number/who
                                        (global.get $symbol:log)
                                        (local.get $b)) (unreachable))))
                       (else
                        (if (ref.test (ref $Flonum) (local.get $b))
                            (then
                             (local.set $fl (ref.cast (ref $Flonum) (local.get $b)))
                             (local.set $bf64 (struct.get $Flonum $v (local.get $fl))))
                            (else
                             (if (call $exact-rational?/i32 (local.get $b))
                                 (then
                                  (if (i32.eqz
                                       (call $exact-rational-compare/i32
                                             (local.get $b)
                                             (ref.i31 (i32.const 2))))
                                      (then (call $raise-division-by-zero) (unreachable)))
                                  (local.set $bf64
                                             (call $exact-rational->f64
                                                   (local.get $b))))
                                 (else (call $raise-expected-number/who
                                             (global.get $symbol:log)
                                             (local.get $b)) (unreachable)))))))
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
               (local $x/bn (ref $Bignum))
               (local $x/rat (ref $Rational))

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
                        (else (call $raise-expected-real
                                    (global.get $symbol:positive?)
                                    (local.get $x)) (unreachable)))))

               ;; If x is a flonum, check if it's > 0.0
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (if (f64.gt (struct.get $Flonum $v (local.get $x/fl)) (f64.const 0.0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; If x is a bignum, its sign field determines positivity.
               (if (ref.test (ref $Bignum) (local.get $x))
                   (then
                    (local.set $x/bn (ref.cast (ref $Bignum) (local.get $x)))
                    (if (i32.gt_s (struct.get $Bignum $sign (local.get $x/bn))
                                  (i32.const 0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; If x is a rational, the numerator sign determines positivity.
               (if (ref.test (ref $Rational) (local.get $x))
                   (then
                    (local.set $x/rat (ref.cast (ref $Rational) (local.get $x)))
                    (if (i32.gt_s
                         (call $integer-sign/i32
                               (struct.get $Rational $num (local.get $x/rat)))
                         (i32.const 0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Not a number
               (call $raise-expected-real
                     (global.get $symbol:positive?)
                     (local.get $x))
               (unreachable))

         (func $negative? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $x/fx i32)
               (local $x/fl (ref $Flonum))
               (local $x/bn (ref $Bignum))
               (local $x/rat (ref $Rational))

               ;; If x is a fixnum, check if it's < 0
               (if (ref.test (ref i31) (local.get $x))
                   (then
                    (local.set $x/fx (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (if (i32.eqz (i32.and (local.get $x/fx) (i32.const 1))) ;; lsb = 0?
                        (then
                         (if (i32.lt_s (i32.shr_s (local.get $x/fx) (i32.const 1)) (i32.const 0))
                             (then (return (global.get $true)))
                             (else (return (global.get $false)))))
                        (else (call $raise-expected-real
                                    (global.get $symbol:negative?)
                                    (local.get $x)) (unreachable)))))

               ;; If x is a flonum, check if it's < 0.0
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $x/fl (ref.cast (ref $Flonum) (local.get $x)))
                    (if (f64.lt (struct.get $Flonum $v (local.get $x/fl)) (f64.const 0.0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; If x is a bignum, its sign field determines negativity.
               (if (ref.test (ref $Bignum) (local.get $x))
                   (then
                    (local.set $x/bn (ref.cast (ref $Bignum) (local.get $x)))
                    (if (i32.lt_s (struct.get $Bignum $sign (local.get $x/bn))
                                  (i32.const 0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; If x is a rational, the numerator sign determines negativity.
               (if (ref.test (ref $Rational) (local.get $x))
                   (then
                    (local.set $x/rat (ref.cast (ref $Rational) (local.get $x)))
                    (if (i32.lt_s
                         (call $integer-sign/i32
                               (struct.get $Rational $num (local.get $x/rat)))
                         (i32.const 0))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Not a number
               (call $raise-expected-real
                     (global.get $symbol:negative?)
                     (local.get $x))
               (unreachable))

         (func $even? (type $Prim1)
               (param $n (ref eq))
               (result (ref eq))

               (local $bits i32)
               (local $bn (ref $Bignum))
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
                        (else (call $raise-expected-integer
                                    (global.get $symbol:even?)
                                    (local.get $n)) (unreachable)))))

               ;; Bignum case: use the least significant limb.
               (if (ref.test (ref $Bignum) (local.get $n))
                   (then
                    (local.set $bn (ref.cast (ref $Bignum) (local.get $n)))
                    (if (i32.eqz
                         (i32.and
                          (array.get $I32Array
                                     (struct.get $Bignum $limbs (local.get $bn))
                                     (i32.const 0))
                          (i32.const 1)))
                        (then (return (global.get $true)))
                        (else (return (global.get $false))))))

               ;; Flonum case
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then
                    (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                    (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                    (if (f64.ne (local.get $f64) (local.get $f64))
                        (then (call $raise-expected-integer
                                    (global.get $symbol:even?)
                                    (local.get $n)) (unreachable)))
                    (if (f64.eq (local.get $f64) (f64.const +inf))
                        (then (call $raise-expected-integer
                                    (global.get $symbol:even?)
                                    (local.get $n)) (unreachable)))
                    (if (f64.eq (local.get $f64) (f64.const -inf))
                        (then (call $raise-expected-integer
                                    (global.get $symbol:even?)
                                    (local.get $n)) (unreachable)))
                    (if (f64.eq (f64.floor (local.get $f64)) (local.get $f64))
                        (then
                         (local.set $i32 (i32.trunc_f64_s (local.get $f64)))
                         (if (i32.eqz (i32.and (local.get $i32) (i32.const 1)))
                             (then (return (global.get $true)))
                             (else (return (global.get $false)))))
                        (else (call $raise-expected-integer
                                    (global.get $symbol:even?)
                                    (local.get $n)) (unreachable)))))

               ;; Not an integer
               (call $raise-expected-integer
                     (global.get $symbol:even?)
                     (local.get $n))
               (unreachable))

         (func $odd? (type $Prim1)
               (param $n (ref eq))
               (result (ref eq))

               (if (ref.eq (call $integer? (local.get $n)) (global.get $false))
                   (then (call $raise-expected-integer
                               (global.get $symbol:odd?)
                               (local.get $n))
                         (unreachable)))
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
               ;; Case 3: bignum
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then (return (global.get $true))))
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
               ;; Bignum -> #f
               (if (ref.test (ref $Bignum) (local.get $x))
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
               (call $raise-expected-number/who
                     (global.get $symbol:nan?)
                     (local.get $x))
               (unreachable))

         (func $infinite? (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $x/fl (ref $Flonum))
               (local $f64 f64)

               ;; Fixnum -> #f
               (if (ref.test (ref i31) (local.get $x))
                   (then (return (global.get $false))))
               ;; Bignum -> #f
               (if (ref.test (ref $Bignum) (local.get $x))
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
               (call $raise-expected-number/who
                     (global.get $symbol:infinite?)
                     (local.get $x))
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
    $exact-rational-sqrt/real
    $real-negative-sign?/i32
    $complex-sqrt
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
    $numerator
    $denominator
    $rationalize
    $real-number?/i32
    $real->f64/checked
    $flonum-negative-sign?/i32
    $real-negate
    $make-rectangular/canonical
    $make-rectangular
    $real-part
    $imag-part
    $make-polar
    $magnitude
    $angle
    $conjugate
    $complex-asin
    $complex-acos
    $complex-atan
    $complex-sin
    $complex-cos
    $complex-tan
    $complex-sinh
    $complex-cosh
    $complex-tanh
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
               (local $vals (ref $Values))
               (local $nf f64)
               (local $mf f64)
               (local $qf f64)
               (local $n/exact i32)
               (local $m/exact i32)

               ;; Case 1: both fixnums
               (if (ref.test (ref i31) (local.get $n))
                   (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                         (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                             (then (if (ref.test (ref i31) (local.get $m))
                                       (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                             (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                                 (then (return (call $fxquotient (local.get $n) (local.get $m)))))))))))

               ;; Case 1b: exact integers
               (local.set $n/exact
                          (i32.or (call $fx?/i32 (local.get $n))
                                  (ref.test (ref $Bignum) (local.get $n))))
               (local.set $m/exact
                          (i32.or (call $fx?/i32 (local.get $m))
                                  (ref.test (ref $Bignum) (local.get $m))))
               (if (i32.and (local.get $n/exact) (local.get $m/exact))
                   (then
                    (if (call $integer-zero?/i32 (local.get $m))
                        (then (call $raise-division-by-zero) (unreachable)))
                    (local.set $vals
                               (call $integer-divmod
                                     (local.get $n)
                                     (local.get $m)))
                    (return
                     (array.get $Values
                                (local.get $vals)
                                (i32.const 0)))))

               ;; Case 2: flonum/inexact
               ;; convert n to f64
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                         (local.set $nf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $n))
                             (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                                   (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                                       (then (local.set $nf (f64.convert_i32_s (i32.shr_s (local.get $nu) (i32.const 1)))))
                                       (else (call $raise-expected-integer
                                                   (global.get $symbol:quotient)
                                                   (local.get $n)) (unreachable))))
                             (else (call $raise-expected-integer
                                         (global.get $symbol:quotient)
                                         (local.get $n)) (unreachable)))))

               ;; ensure n is a finite integer
               (if (f64.eq (local.get $nf) (f64.const inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient)
                               (local.get $n)) (unreachable)))
               (if (f64.eq (local.get $nf) (f64.const -inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient)
                               (local.get $n)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $nf)) (local.get $nf))
                   (then)
                   (else (call $raise-expected-integer
                               (global.get $symbol:quotient)
                               (local.get $n)) (unreachable)))

               ;; convert m to f64
               (if (ref.test (ref $Flonum) (local.get $m))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $m)))
                         (local.set $mf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $m))
                             (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                   (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                       (then (local.set $mf (f64.convert_i32_s (i32.shr_s (local.get $mu) (i32.const 1)))))
                                       (else (call $raise-expected-integer
                                                   (global.get $symbol:quotient)
                                                   (local.get $m)) (unreachable))))
                             (else (call $raise-expected-integer
                                         (global.get $symbol:quotient)
                                         (local.get $m)) (unreachable)))))

               ;; ensure m is a finite integer
               (if (f64.eq (local.get $mf) (f64.const inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient)
                               (local.get $m)) (unreachable)))
               (if (f64.eq (local.get $mf) (f64.const -inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient)
                               (local.get $m)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $mf)) (local.get $mf))
                   (then)
                   (else (call $raise-expected-integer
                               (global.get $symbol:quotient)
                               (local.get $m)) (unreachable)))

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
               (local $vals (ref $Values))
               (local $nf f64)
               (local $mf f64)
               (local $rf f64)
               (local $n/exact i32)
               (local $m/exact i32)

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

               ;; Case 1b: exact integers
               (local.set $n/exact
                          (i32.or (call $fx?/i32 (local.get $n))
                                  (ref.test (ref $Bignum) (local.get $n))))
               (local.set $m/exact
                          (i32.or (call $fx?/i32 (local.get $m))
                                  (ref.test (ref $Bignum) (local.get $m))))
               (if (i32.and (local.get $n/exact) (local.get $m/exact))
                   (then
                    (if (call $integer-zero?/i32 (local.get $m))
                        (then (call $raise-division-by-zero) (unreachable)))
                    (local.set $vals
                               (call $integer-divmod
                                     (local.get $n)
                                     (local.get $m)))
                    (return
                     (array.get $Values
                                (local.get $vals)
                                (i32.const 1)))))

               ;; Case 2: flonum/inexact
               ;; convert n to f64
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                         (local.set $nf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $n))
                             (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                                   (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                                       (then (local.set $nf (f64.convert_i32_s (i32.shr_s (local.get $nu) (i32.const 1)))))
                                       (else (call $raise-expected-integer
                                                   (global.get $symbol:remainder)
                                                   (local.get $n)) (unreachable))))
                             (else (call $raise-expected-integer
                                         (global.get $symbol:remainder)
                                         (local.get $n)) (unreachable)))))

               ;; ensure n is a finite integer
               (if (f64.eq (local.get $nf) (f64.const inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:remainder)
                               (local.get $n)) (unreachable)))
               (if (f64.eq (local.get $nf) (f64.const -inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:remainder)
                               (local.get $n)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $nf)) (local.get $nf))
                   (then)
                   (else (call $raise-expected-integer
                               (global.get $symbol:remainder)
                               (local.get $n)) (unreachable)))

               ;; convert m to f64
               (if (ref.test (ref $Flonum) (local.get $m))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $m)))
                         (local.set $mf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $m))
                             (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                   (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                       (then (local.set $mf (f64.convert_i32_s (i32.shr_s (local.get $mu) (i32.const 1)))))
                                       (else (call $raise-expected-integer
                                                   (global.get $symbol:remainder)
                                                   (local.get $m)) (unreachable))))
                             (else (call $raise-expected-integer
                                         (global.get $symbol:remainder)
                                         (local.get $m)) (unreachable)))))

               ;; ensure m is a finite integer
               (if (f64.eq (local.get $mf) (f64.const inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:remainder)
                               (local.get $m)) (unreachable)))
               (if (f64.eq (local.get $mf) (f64.const -inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:remainder)
                               (local.get $m)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $mf)) (local.get $mf))
                   (then)
                   (else (call $raise-expected-integer
                               (global.get $symbol:remainder)
                               (local.get $m)) (unreachable)))

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
               (local $n/exact i32)
               (local $m/exact i32)
               (local $r-sign i32)
               (local $m-sign i32)
               (local $vals (ref $Values))
               (local $fl (ref $Flonum))
               (local $mf f64)
	               (local $rf f64)

               ;; Exact integers
               (local.set $n/exact
                          (i32.or (call $fx?/i32 (local.get $n))
                                  (ref.test (ref $Bignum) (local.get $n))))
               (local.set $m/exact
                          (i32.or (call $fx?/i32 (local.get $m))
                                  (ref.test (ref $Bignum) (local.get $m))))
               (if (i32.and (local.get $n/exact) (local.get $m/exact))
                   (then
                    (if (call $integer-zero?/i32 (local.get $m))
                        (then (call $raise-division-by-zero) (unreachable)))
                    (local.set $vals
                               (call $integer-divmod
                                     (local.get $n)
                                     (local.get $m)))
                    (local.set $r
                               (array.get $Values
                                          (local.get $vals)
                                          (i32.const 1)))
                    (if (call $integer-zero?/i32 (local.get $r))
                        (then (return (local.get $r))))
                    (local.set $r-sign (call $integer-sign/i32 (local.get $r)))
                    (local.set $m-sign (call $integer-sign/i32 (local.get $m)))
                    (if (i32.eq (local.get $r-sign) (local.get $m-sign))
                        (then (return (local.get $r)))
                        (else
                         (return
                          (call $integer-add/2
                                (local.get $r)
                                (local.get $m)))))))

	               ;; Validate here so user-facing type errors preserve `modulo` as `who`.
	               (if (ref.eq (call $integer? (local.get $n)) (global.get $false))
	                   (then (call $raise-expected-integer
	                               (global.get $symbol:modulo)
	                               (local.get $n))
	                         (unreachable)))
	               (if (ref.eq (call $integer? (local.get $m)) (global.get $false))
	                   (then (call $raise-expected-integer
	                               (global.get $symbol:modulo)
	                               (local.get $m))
	                         (unreachable)))
	               ;; Compute remainder; it validates the non-zero divisor.
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
                         (call $raise-expected-integer
                               (global.get $symbol:modulo)
                               (local.get $m))
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
               (local $vals (ref $Values))
               (local $nf f64)
               (local $mf f64)
               (local $qf f64)
               (local $rf f64)
               (local $n/exact i32)
               (local $m/exact i32)

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

               ;; Case 1b: exact integers
               (local.set $n/exact
                          (i32.or (call $fx?/i32 (local.get $n))
                                  (ref.test (ref $Bignum) (local.get $n))))
               (local.set $m/exact
                          (i32.or (call $fx?/i32 (local.get $m))
                                  (ref.test (ref $Bignum) (local.get $m))))
               (if (i32.and (local.get $n/exact) (local.get $m/exact))
                   (then
                    (if (call $integer-zero?/i32 (local.get $m))
                        (then (call $raise-division-by-zero) (unreachable)))
                    (return
                     (call $integer-divmod
                           (local.get $n)
                           (local.get $m)))))

               ;; Case 2: flonum/inexact
               ;; convert n to f64
               (if (ref.test (ref $Flonum) (local.get $n))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $n)))
                         (local.set $nf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $n))
                             (then (local.set $nu (i31.get_s (ref.cast i31ref (local.get $n))))
                                   (if (i32.eqz (i32.and (local.get $nu) (i32.const 1)))
                                       (then (local.set $nf (f64.convert_i32_s (i32.shr_s (local.get $nu) (i32.const 1)))))
                                       (else (call $raise-expected-integer
                                                   (global.get $symbol:quotient/remainder)
                                                   (local.get $n)) (unreachable))))
                             (else (call $raise-expected-integer
                                         (global.get $symbol:quotient/remainder)
                                         (local.get $n)) (unreachable)))))

               ;; ensure n is a finite integer
               (if (f64.eq (local.get $nf) (f64.const inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient/remainder)
                               (local.get $n)) (unreachable)))
               (if (f64.eq (local.get $nf) (f64.const -inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient/remainder)
                               (local.get $n)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $nf)) (local.get $nf))
                   (then)
                   (else (call $raise-expected-integer
                               (global.get $symbol:quotient/remainder)
                               (local.get $n)) (unreachable)))

               ;; convert m to f64
               (if (ref.test (ref $Flonum) (local.get $m))
                   (then (local.set $fl (ref.cast (ref $Flonum) (local.get $m)))
                         (local.set $mf (struct.get $Flonum $v (local.get $fl))))
                   (else (if (ref.test (ref i31) (local.get $m))
                             (then (local.set $mu (i31.get_s (ref.cast i31ref (local.get $m))))
                                   (if (i32.eqz (i32.and (local.get $mu) (i32.const 1)))
                                       (then (local.set $mf (f64.convert_i32_s (i32.shr_s (local.get $mu) (i32.const 1)))))
                                       (else (call $raise-expected-integer
                                                   (global.get $symbol:quotient/remainder)
                                                   (local.get $m)) (unreachable))))
                             (else (call $raise-expected-integer
                                         (global.get $symbol:quotient/remainder)
                                         (local.get $m)) (unreachable)))))

               ;; ensure m is a finite integer
               (if (f64.eq (local.get $mf) (f64.const inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient/remainder)
                               (local.get $m)) (unreachable)))
               (if (f64.eq (local.get $mf) (f64.const -inf))
                   (then (call $raise-expected-integer
                               (global.get $symbol:quotient/remainder)
                               (local.get $m)) (unreachable)))
               (if (f64.eq (f64.floor (local.get $mf)) (local.get $mf))
                   (then)
                   (else (call $raise-expected-integer
                               (global.get $symbol:quotient/remainder)
                               (local.get $m)) (unreachable)))

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

               (local $v/fl (ref $Flonum))
               (local $f64v f64)

               ;; Case 1: Fixnum
               (if (call $fx?/i32 (local.get $v))
                   (then (return (call $integer-add/2
                                       (local.get $v)
                                       (global.get $one)))))
               ;; Case 2: Bignum
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then (return (call $integer-add/2
                                       (local.get $v)
                                       (global.get $one)))))
               ;; Case 3: Flonum
               (if (ref.test (ref $Flonum) (local.get $v))
                   (then (local.set $v/fl (ref.cast (ref $Flonum) (local.get $v)))
                         (local.set $f64v (struct.get $Flonum $v (local.get $v/fl)))
                         (return (struct.new $Flonum
                                             (i32.const 0)
                                             (f64.add (local.get $f64v) (f64.const 1.0))))))
               ;; Not a number
               (call $raise-expected-number/who
                     (global.get $symbol:add1)
                     (local.get $v))
               (unreachable))

         (func $sub1 (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $v/fl (ref $Flonum))
               (local $f64v f64)
               ;; Case 1: Fixnum
               (if (call $fx?/i32 (local.get $v))
                   (then (return (call $integer-sub/2
                                       (local.get $v)
                                       (global.get $one)))))
               ;; Case 2: Bignum
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then (return (call $integer-sub/2
                                       (local.get $v)
                                       (global.get $one)))))
               ;; Case 3: Flonum
               (if (ref.test (ref $Flonum) (local.get $v))
                   (then (local.set $v/fl (ref.cast (ref $Flonum) (local.get $v)))
                         (local.set $f64v (struct.get $Flonum $v (local.get $v/fl)))
                         (return
                          (struct.new $Flonum
                                      (i32.const 0)
                                      (f64.sub (local.get $f64v) (f64.const 1.0))))))
               ;; Not a number
               (call $raise-expected-number/who
                     (global.get $symbol:sub1)
                     (local.get $v))
               (unreachable))

         (func $sqr (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $bits i32)

               ;; Case 1: Fixnum
               (if (call $fx?/i32 (local.get $x))
                   (then (return (call $integer-mul/2
                                       (local.get $x)
                                       (local.get $x)))))
              ;; Case 2: Bignum
              (if (ref.test (ref $Bignum) (local.get $x))
                  (then (return (call $integer-mul/2
                                      (local.get $x)
                                      (local.get $x)))))
              ;; Case 3: Rational
              (if (ref.test (ref $Rational) (local.get $x))
                  (then (return (call $exact-rational-mul/2
                                      (local.get $x)
                                      (local.get $x)))))
              ;; Case 4: Flonum
              (if (ref.test (ref $Flonum) (local.get $x))
                  (then (return (call $fl* (local.get $x) (local.get $x)))))
               ;; Not a number
               (call $raise-expected-number/who
                     (global.get $symbol:sqr)
                     (local.get $x))
               (unreachable))

         ;; $exact-rational-sqrt/real : exact-rational? -> real?
         ;;   Return an exact square root for perfect squares, otherwise inexact.
         (func $exact-rational-sqrt/real
               (param $x (ref eq))
               (result (ref eq))

               (local $num      (ref eq))
               (local $den      (ref eq))
               (local $sqrt-num (ref eq))
               (local $sqrt-den (ref eq))
               (local $sq       (ref eq))

               (local.set $num      (ref.i31 (i32.const 0)))
               (local.set $den      (ref.i31 (i32.const 2)))
               (local.set $sqrt-num (ref.i31 (i32.const 0)))
               (local.set $sqrt-den (ref.i31 (i32.const 2)))
               (local.set $sq       (ref.i31 (i32.const 0)))

               (local.set $num (call $exact-rational-numerator (local.get $x)))
               (if (i32.lt_s (call $integer-sign/i32 (local.get $num))
                             (i32.const 0))
                   (then
                    (return
                     (struct.new $Flonum
                                 (i32.const 0)
                                 (call $js-raw-math-sqrt
                                       (call $exact-rational->f64
                                             (local.get $x)))))))
               (local.set $den (call $exact-rational-denominator (local.get $x)))
               (local.set $sqrt-num
                          (call $integer-sqrt/exact (local.get $num)))
               (local.set $sq
                          (call $integer-mul/2
                                (local.get $sqrt-num)
                                (local.get $sqrt-num)))
               (if (i32.ne
                    (call $integer-compare/i32
                          (local.get $sq)
                          (local.get $num))
                    (i32.const 0))
                   (then
                    (return
                     (struct.new $Flonum
                                 (i32.const 0)
                                 (call $js-raw-math-sqrt
                                       (call $exact-rational->f64
                                             (local.get $x)))))))
               (local.set $sqrt-den
                          (call $integer-sqrt/exact (local.get $den)))
               (local.set $sq
                          (call $integer-mul/2
                                (local.get $sqrt-den)
                                (local.get $sqrt-den)))
               (if (i32.ne
                    (call $integer-compare/i32
                          (local.get $sq)
                          (local.get $den))
                    (i32.const 0))
                   (then
                    (return
                     (struct.new $Flonum
                                 (i32.const 0)
                                 (call $js-raw-math-sqrt
                                       (call $exact-rational->f64
                                             (local.get $x)))))))
               (call $rational-normalize
                     (local.get $sqrt-num)
                     (local.get $sqrt-den)))

         ;; real-negative-sign?/i32 : real? -> i32
         ;;   Return 1 for negative exact reals and negative-signed flonums.
         (func $real-negative-sign?/i32
               (param $x (ref eq))
               (result i32)

               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (return
                     (call $flonum-negative-sign?/i32
                           (struct.get $Flonum $v
                                       (ref.cast (ref $Flonum) (local.get $x)))))))
               (if (call $exact-rational?/i32 (local.get $x))
                   (then
                    (return
                     (i32.lt_s
                      (call $exact-rational-compare/i32
                            (local.get $x)
                            (global.get $zero))
                      (i32.const 0)))))
               (i32.const 0))

         ;; complex-sqrt : complex? -> number?
         ;;   Compute the principal square root using exact components when possible.
         (func $complex-sqrt
               (param $z (ref $Complex))
               (result (ref eq))

               (local $a    (ref eq))
               (local $b    (ref eq))
               (local $r    (ref eq))
               (local $u    (ref eq))
               (local $v    (ref eq))
               (local $imag (ref eq))

               (local.set $a (struct.get $Complex $real (local.get $z)))
               (local.set $b (struct.get $Complex $imag (local.get $z)))
               (local.set $r (call $magnitude (local.get $z)))
               (local.set $u
                          (call $sqrt
                                (call $/2
                                      (call $+/2
                                            (local.get $r)
                                            (local.get $a))
                                      (global.get $two))))
               (local.set $v
                          (call $sqrt
                                (call $/2
                                      (call $-/2
                                            (local.get $r)
                                            (local.get $a))
                                      (global.get $two))))
               (local.set $imag
                          (if (result (ref eq))
                              (call $real-negative-sign?/i32 (local.get $b))
                              (then (call $real-negate (local.get $v)))
                              (else (local.get $v))))
               (call $make-rectangular/canonical
                     (local.get $u)
                     (local.get $imag)))

         (func $sqrt (type $Prim1)
               (param $x (ref eq))
               (result (ref eq))

               (local $bits i32)
               (local $fl (ref $Flonum))
               (local $f64 f64)
               (local $cmp/i32 i32)

               ;; Exact rational case
               (if (call $exact-rational?/i32 (local.get $x))
                   (then
                    (local.set $cmp/i32
                               (call $exact-rational-compare/i32
                                     (local.get $x)
                                     (global.get $zero)))
                    (if (i32.lt_s (local.get $cmp/i32) (i32.const 0))
                        (then
                         (return
                          (call $make-rectangular/canonical
                                (global.get $zero)
                                (call $sqrt
                                      (call $exact-rational-abs
                                            (local.get $x)))))))
                    (return
                     (call $exact-rational-sqrt/real
                           (local.get $x)))))

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
                        (else (call $raise-expected-number/who
                                    (global.get $symbol:sqrt)
                                    (local.get $x))
                              (unreachable)))))

               ;; If x is a flonum, compute sqrt and box
               (if (ref.test (ref $Flonum) (local.get $x))
                   (then
                    (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                    (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                    (if (f64.lt (local.get $f64) (f64.const 0.0))
                        (then
                         (return
                          (call $make-rectangular/canonical
                                (struct.new $Flonum
                                            (i32.const 0)
                                            (f64.const 0.0))
                                (struct.new $Flonum
                                            (i32.const 0)
                                            (call $js-raw-math-sqrt
                                                  (f64.abs (local.get $f64))))))))
                    (return (struct.new $Flonum
                                        (i32.const 0)
                                        (call $js-raw-math-sqrt (local.get $f64))))))

               ;; Complex case
               (if (ref.test (ref $Complex) (local.get $x))
                   (then
                    (return
                     (call $complex-sqrt
                           (ref.cast (ref $Complex) (local.get $x))))))

               ;; Not a number
               (call $raise-expected-number/who
                     (global.get $symbol:sqrt)
                     (local.get $x))
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
                  [(fx-abs) `((return (call $integer-abs (local.get $x))))]))
              (define bignumstmts
                (case kind
                  [(fx-abs) `((return (call $integer-abs (local.get $x))))]
                  [else     `((return (local.get $x)))]))
              (define rationalstmts
                (case name
                  [(abs)      `((return (call $exact-rational-abs (local.get $x))))]
                  [(round)    `((return (call $exact-rational-round (local.get $x))))]
                  [(floor)    `((return (call $exact-rational-floor (local.get $x))))]
                  [(ceiling)  `((return (call $exact-rational-ceiling (local.get $x))))]
                  [(truncate) `((return (call $exact-rational-truncate (local.get $x))))]
                  [else       '()]))
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
                              (else (call $raise-expected-real
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x))
                                    (unreachable)))))

                     ;; Bignum case
                     (if (ref.test (ref $Bignum) (local.get $x))
                         (then ,@bignumstmts))

                     ;; Rational case
                     ,@(if (null? rationalstmts)
                           '()
                           `((if (ref.test (ref $Rational) (local.get $x))
                                 (then ,@rationalstmts))))

                     ;; Flonum case
                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (return (struct.new $Flonum
                                              (i32.const 0)
                                              ,expr))))

                     ;; Not a number
                     (call $raise-expected-real
                           (global.get ,(string->symbol (format "$symbol:~a" name)))
                           (local.get $x))
                     (unreachable))))

        (func $sgn (type $Prim1)
              (param $x (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $fl   (ref $Flonum))
              (local $f64  f64)
              (local $bn   (ref $Bignum))
              (local $rat  (ref $Rational))

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
                       (else (call $raise-expected-real
                                   (global.get $symbol:sgn)
                                   (local.get $x))
                             (unreachable)))))

              ;; Bignum case
              (if (ref.test (ref $Bignum) (local.get $x))
                  (then
                   (local.set $bn (ref.cast (ref $Bignum) (local.get $x)))
                   (if (i32.gt_s (struct.get $Bignum $sign (local.get $bn))
                                 (i32.const 0))
                       (then (return ,(Imm 1)))
                       (else (return ,(Imm -1))))))

              ;; Rational case
              (if (ref.test (ref $Rational) (local.get $x))
                  (then
                   (local.set $rat (ref.cast (ref $Rational) (local.get $x)))
                   (if (i32.gt_s
                        (call $integer-sign/i32
                              (struct.get $Rational $num (local.get $rat)))
                        (i32.const 0))
                       (then (return ,(Imm 1)))
                       (else (return ,(Imm -1))))))

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
              (call $raise-expected-real
                    (global.get $symbol:sgn)
                    (local.get $x))
              (unreachable))

        ;; Exact integer rounding functions
        ;; Implements: $exact-round $exact-floor $exact-ceiling $exact-truncate
        ,@(let ([ops '((exact-round    f64.nearest $exact-rational-round)
                       (exact-floor    f64.floor   $exact-rational-floor)
                       (exact-ceiling  f64.ceil    $exact-rational-ceiling)
                       (exact-truncate f64.trunc   $exact-rational-truncate))])
            (for/list ([p ops])
              (define name (car p))
              (define expr (cadr p))
              (define rational-helper (caddr p))
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
                              (else (call $raise-expected-rational
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x))
                                    (unreachable)))))

                     ;; Bignum exact integer case
                     (if (ref.test (ref $Bignum) (local.get $x))
                         (then (return (local.get $x))))

                     ;; Exact rational case
                     (if (ref.test (ref $Rational) (local.get $x))
                         (then (return (call ,rational-helper (local.get $x)))))

                     ;; Flonum case
                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (if (f64.ne (local.get $f64) (local.get $f64))
                              (then (call $raise-expected-rational
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x)) (unreachable)))
                          (if (f64.eq (local.get $f64) (f64.const +inf))
                              (then (call $raise-expected-rational
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x)) (unreachable)))
                          (if (f64.eq (local.get $f64) (f64.const -inf))
                              (then (call $raise-expected-rational
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x)) (unreachable)))
                          (local.set $f64 (,expr (local.get $f64)))
                          (if (f64.gt (local.get $f64) (f64.const 1073741823.0))
                              (then (call $raise-expected-rational
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x)) (unreachable)))
                          (if (f64.lt (local.get $f64) (f64.const -1073741824.0))
                              (then (call $raise-expected-rational
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x)) (unreachable)))
                          (local.set $bits (i32.trunc_f64_s (local.get $f64)))
                          (return (ref.i31 (i32.shl (local.get $bits) (i32.const 1))))))

                     ;; Not a number
                     (call $raise-expected-rational
                           (global.get ,(string->symbol (format "$symbol:~a" name)))
                           (local.get $x))
                     (unreachable))))

        (func $numerator (type $Prim1)
              (param $q (ref eq))
              (result (ref eq))

              (local $fl    (ref $Flonum))
              (local $f64   f64)
              (local $exact (ref eq))

              (if (call $exact-rational?/i32 (local.get $q))
                  (then (return (call $exact-rational-numerator
                                      (local.get $q)))))

              (if (ref.test (ref $Flonum) (local.get $q))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $q)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.ne (local.get $f64) (local.get $f64))
                       (then (call $raise-expected-rational
                                   (global.get $symbol:numerator)
                                   (local.get $q))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const +inf))
                       (then (call $raise-expected-rational
                                   (global.get $symbol:numerator)
                                   (local.get $q))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const -inf))
                       (then (call $raise-expected-rational
                                   (global.get $symbol:numerator)
                                   (local.get $q))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const 0.0))
                       (then (return (struct.new $Flonum
                                                 (i32.const 0)
                                                 (local.get $f64)))))
                   (local.set $exact (call $f64->exact-rational
                                           (local.get $f64)))
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $integer->f64
                                      (call $exact-rational-numerator
                                            (local.get $exact)))))))

              (call $raise-expected-rational
                    (global.get $symbol:numerator)
                    (local.get $q))
              (unreachable))

        (func $denominator (type $Prim1)
              (param $q (ref eq))
              (result (ref eq))

              (local $fl    (ref $Flonum))
              (local $f64   f64)
              (local $exact (ref eq))

              (if (call $exact-rational?/i32 (local.get $q))
                  (then (return (call $exact-rational-denominator
                                      (local.get $q)))))

              (if (ref.test (ref $Flonum) (local.get $q))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $q)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.ne (local.get $f64) (local.get $f64))
                       (then (call $raise-expected-rational
                                   (global.get $symbol:denominator)
                                   (local.get $q))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const +inf))
                       (then (call $raise-expected-rational
                                   (global.get $symbol:denominator)
                                   (local.get $q))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const -inf))
                       (then (call $raise-expected-rational
                                   (global.get $symbol:denominator)
                                   (local.get $q))
                             (unreachable)))
                   (local.set $exact (call $f64->exact-rational
                                           (local.get $f64)))
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $integer->f64
                                      (call $exact-rational-denominator
                                            (local.get $exact)))))))

              (call $raise-expected-rational
                    (global.get $symbol:denominator)
                    (local.get $q))
              (unreachable))

        ;; $rationalize : real? real? -> real?
        ;;   Return the simplest rational within abs(tolerance) of x.
        (func $rationalize (type $Prim2)
              (param $x         (ref eq))
              (param $tolerance (ref eq))
              (result (ref eq))

              (local $x-exact         (ref eq))
              (local $tolerance-exact (ref eq))
              (local $result          (ref eq))
              (local $inexact?        i32)

              (local.set $x-exact         (ref.i31 (i32.const 0)))
              (local.set $tolerance-exact (ref.i31 (i32.const 0)))
              (local.set $result          (ref.i31 (i32.const 0)))
              (local.set $inexact?
                         (i32.or
                          (ref.test (ref $Flonum) (local.get $x))
                          (ref.test (ref $Flonum) (local.get $tolerance))))
              (local.set $x-exact
                         (call $rational-argument->exact
                               (global.get $symbol:rationalize)
                               (local.get $x)))
              (local.set $tolerance-exact
                         (call $rational-argument->exact
                               (global.get $symbol:rationalize)
                               (local.get $tolerance)))
              (local.set $result
                         (call $exact-rational-rationalize
                               (local.get $x-exact)
                               (local.get $tolerance-exact)))
              (if (local.get $inexact?)
                  (then (return (call $exact->inexact
                                      (local.get $result)))))
              (local.get $result))

        ;; real-number?/i32 : any/c -> i32
        ;;   Return 1 when x is a WebRacket real number.
        (func $real-number?/i32
              (param $x (ref eq))
              (result i32)
              (i32.or
               (call $exact-rational?/i32 (local.get $x))
               (ref.test (ref $Flonum) (local.get $x))))

        ;; real->f64/checked : symbol? real? -> f64
        ;;   Convert a real argument to f64 for inexact complex operations.
        (func $real->f64/checked
              (param $who (ref eq))
              (param $x   (ref eq))
              (result f64)

              (local $fl (ref $Flonum))

              (if (ref.test (ref $Flonum) (local.get $x))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                   (return (struct.get $Flonum $v (local.get $fl)))))
              (if (call $exact-rational?/i32 (local.get $x))
                  (then (return (call $exact-rational->f64
                                      (local.get $x)))))
              (call $raise-expected-real
                    (local.get $who)
                    (local.get $x))
              (unreachable))

        ;; flonum-negative-sign?/i32 : f64 -> i32
        ;;   Return 1 when x has the IEEE negative sign bit, including -0.0.
        (func $flonum-negative-sign?/i32
              (param $x f64)
              (result i32)

              (local $bits i64)

              (local.set $bits (i64.reinterpret_f64 (local.get $x)))
              (i32.wrap_i64
               (i64.shr_u (local.get $bits) (i64.const 63))))

        ;; real-negate : real? -> real?
        ;;   Negate a real number while preserving flonum signed zero.
        (func $real-negate
              (param $x (ref eq))
              (result (ref eq))

              (local $fl (ref $Flonum))

              (if (ref.test (ref $Flonum) (local.get $x))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (f64.neg
                                 (struct.get $Flonum $v (local.get $fl)))))))
              (call $-/2 (global.get $zero) (local.get $x)))

        ;; make-rectangular/canonical : real? real? -> number?
        ;;   Build a complex number, collapsing only exact zero imaginary parts.
        (func $make-rectangular/canonical
              (param $real (ref eq))
              (param $imag (ref eq))
              (result (ref eq))

              (local $inexact? i32)

              (if (call $exact-rational-zero?/i32 (local.get $imag))
                  (then (return (local.get $real))))
              (local.set $inexact?
                         (i32.or
                          (ref.test (ref $Flonum) (local.get $real))
                          (ref.test (ref $Flonum) (local.get $imag))))
              (if (local.get $inexact?)
                  (then
                   (return
                    (struct.new $Complex
                                (i32.const 0)
                                (call $exact->inexact (local.get $real))
                                (call $exact->inexact (local.get $imag))))))
              (struct.new $Complex
                          (i32.const 0)
                          (local.get $real)
                          (local.get $imag)))

        ;; make-rectangular : real? real? -> number?
        ;;   Construct a rectangular complex number with Racket canonicalization.
        (func $make-rectangular (type $Prim2)
              (param $real (ref eq))
              (param $imag (ref eq))
              (result (ref eq))

              (if (i32.eqz (call $real-number?/i32 (local.get $real)))
                  (then (call $raise-expected-real
                              (global.get $symbol:make-rectangular)
                              (local.get $real))
                        (unreachable)))
              (if (i32.eqz (call $real-number?/i32 (local.get $imag)))
                  (then (call $raise-expected-real
                              (global.get $symbol:make-rectangular)
                              (local.get $imag))
                        (unreachable)))
              (call $make-rectangular/canonical
                    (local.get $real)
                    (local.get $imag)))

        ;; real-part : number? -> real?
        ;;   Return the real component of a number.
        (func $real-part (type $Prim1)
              (param $z (ref eq))
              (result (ref eq))

              (local $c (ref $Complex))

              (if (call $real-number?/i32 (local.get $z))
                  (then (return (local.get $z))))
              (if (ref.test (ref $Complex) (local.get $z))
                  (then
                   (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                   (return (struct.get $Complex $real (local.get $c)))))
              (call $raise-expected-number/who
                    (global.get $symbol:real-part)
                    (local.get $z))
              (unreachable))

        ;; imag-part : number? -> real?
        ;;   Return the imaginary component of a number.
        (func $imag-part (type $Prim1)
              (param $z (ref eq))
              (result (ref eq))

              (local $c (ref $Complex))

              (if (call $real-number?/i32 (local.get $z))
                  (then (return (global.get $zero))))
              (if (ref.test (ref $Complex) (local.get $z))
                  (then
                   (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                   (return (struct.get $Complex $imag (local.get $c)))))
              (call $raise-expected-number/who
                    (global.get $symbol:imag-part)
                    (local.get $z))
              (unreachable))

        ;; make-polar : real? real? -> number?
        ;;   Construct a polar complex number.
        (func $make-polar (type $Prim2)
              (param $magnitude (ref eq))
              (param $angle     (ref eq))
              (result (ref eq))

              (local $m f64)
              (local $a f64)

              (local.set $m
                         (call $real->f64/checked
                               (global.get $symbol:make-polar)
                               (local.get $magnitude)))
              (local.set $a
                         (call $real->f64/checked
                               (global.get $symbol:make-polar)
                               (local.get $angle)))
              (if (call $exact-rational-zero?/i32 (local.get $magnitude))
                  (then (return (global.get $zero))))
              (if (call $exact-rational-zero?/i32 (local.get $angle))
                  (then (return (local.get $magnitude))))
              (call $make-rectangular/canonical
                    (struct.new $Flonum
                                (i32.const 0)
                                (f64.mul (local.get $m)
                                         (call $js-raw-math-cos
                                               (local.get $a))))
                    (struct.new $Flonum
                                (i32.const 0)
                                (f64.mul (local.get $m)
                                         (call $js-raw-math-sin
                                               (local.get $a))))))

        ;; magnitude : number? -> real?
        ;;   Return the magnitude of a number.
        (func $magnitude (type $Prim1)
              (param $z (ref eq))
              (result (ref eq))

              (local $c (ref $Complex))
              (local $real (ref eq))
              (local $imag (ref eq))

              (if (call $real-number?/i32 (local.get $z))
                  (then (return (call $abs (local.get $z)))))
              (if (ref.test (ref $Complex) (local.get $z))
                  (then
                   (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                   (local.set $real (struct.get $Complex $real (local.get $c)))
                   (local.set $imag (struct.get $Complex $imag (local.get $c)))
                   (return
                    (call $sqrt
                          (call $+/2
                                (call $*/2 (local.get $real) (local.get $real))
                                (call $*/2 (local.get $imag) (local.get $imag)))))))
              (call $raise-expected-number/who
                    (global.get $symbol:magnitude)
                    (local.get $z))
              (unreachable))

        ;; angle : number? -> real?
        ;;   Return the phase angle of a number.
        (func $angle (type $Prim1)
              (param $z (ref eq))
              (result (ref eq))

              (local $c       (ref $Complex))
              (local $fl      (ref $Flonum))
              (local $f64     f64)
              (local $cmp/i32 i32)

              (if (ref.test (ref $Complex) (local.get $z))
                  (then
                   (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                   (return
                    (struct.new $Flonum
                                (i32.const 0)
                                (call $js-raw-math-atan2
                                      (call $real->f64/checked
                                            (global.get $symbol:angle)
                                            (struct.get $Complex $imag
                                                        (local.get $c)))
                                      (call $real->f64/checked
                                            (global.get $symbol:angle)
                                            (struct.get $Complex $real
                                                        (local.get $c))))))))
              (if (call $exact-rational?/i32 (local.get $z))
                  (then
                   (local.set $cmp/i32
                              (call $exact-rational-compare/i32
                                    (local.get $z)
                                    (global.get $zero)))
                   (if (i32.eqz (local.get $cmp/i32))
                       (then (call $raise-argument-error1
                                   (global.get $symbol:angle)
                                   (global.get $string:angle:nonzero)
                                   (local.get $z))
                             (unreachable)))
                   (if (i32.gt_s (local.get $cmp/i32) (i32.const 0))
                       (then (return (global.get $zero)))
                       (else
                        (return
                         (struct.new $Flonum
                                     (i32.const 0)
                                     (f64.const 3.141592653589793)))))))
              (if (ref.test (ref $Flonum) (local.get $z))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $z)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.ne (local.get $f64) (local.get $f64))
                       (then
                        (return
                         (struct.new $Flonum
                                     (i32.const 0)
                                     (f64.div (f64.const 0.0)
                                              (f64.const 0.0))))))
                   (if (call $flonum-negative-sign?/i32 (local.get $f64))
                       (then
                        (return
                         (struct.new $Flonum
                                     (i32.const 0)
                                     (f64.const 3.141592653589793))))
                       (else (return (global.get $zero))))))
              (call $raise-expected-number/who
                    (global.get $symbol:angle)
                    (local.get $z))
              (unreachable))

        ;; conjugate : number? -> number?
        ;;   Return the complex conjugate of a number.
        (func $conjugate (type $Prim1)
              (param $z (ref eq))
              (result (ref eq))

              (local $c (ref $Complex))

              (if (call $real-number?/i32 (local.get $z))
                  (then (return (local.get $z))))
              (if (ref.test (ref $Complex) (local.get $z))
                  (then
                   (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                   (return
                    (call $make-rectangular/canonical
                          (struct.get $Complex $real (local.get $c))
                          (call $real-negate
                                (struct.get $Complex $imag (local.get $c)))))))
              (call $raise-expected-number/who
                    (global.get $symbol:conjugate)
                    (local.get $z))
              (unreachable))

        ;; complex-asin : number? -> number?
        ;;   Compute asin z as -i * log(i*z + sqrt(1 - z*z)).
        (func $complex-asin
              (param $z (ref eq))
              (result (ref eq))

              (local $i   (ref eq))
              (local $-i  (ref eq))
              (local $iz  (ref eq))
              (local $rad (ref eq))

              (local.set $i
                         (call $make-rectangular/canonical
                               (global.get $zero)
                               (global.get $one)))
              (local.set $-i
                         (call $make-rectangular/canonical
                               (global.get $zero)
                               (ref.i31 (i32.const -2))))
              (local.set $iz (call $*/2 (local.get $i) (local.get $z)))
              (local.set $rad
                         (call $sqrt
                               (call $-/2
                                     (global.get $one)
                                     (call $*/2 (local.get $z)
                                                (local.get $z)))))
              (call $*/2
                    (local.get $-i)
                    (call $log
                          (call $+/2 (local.get $iz) (local.get $rad))
                          (global.get $missing))))

        ;; complex-acos : number? -> number?
        ;;   Compute acos z as pi/2 - asin z.
        (func $complex-acos
              (param $z (ref eq))
              (result (ref eq))
              (call $-/2
                    (struct.new $Flonum
                                (i32.const 0)
                                (f64.const 1.5707963267948966))
                    (call $complex-asin (local.get $z))))

        ;; complex-atan : number? -> number?
        ;;   Compute atan z as (log(1+i*z) - log(1-i*z)) / (2*i).
        (func $complex-atan
              (param $z (ref eq))
              (result (ref eq))

              (local $i     (ref eq))
              (local $two-i (ref eq))
              (local $iz    (ref eq))

              (local.set $i
                         (call $make-rectangular/canonical
                               (global.get $zero)
                               (global.get $one)))
              (local.set $two-i
                         (call $make-rectangular/canonical
                               (global.get $zero)
                               (global.get $two)))
              (local.set $iz (call $*/2 (local.get $i) (local.get $z)))
              (call $/2
                    (call $-/2
                          (call $log
                                (call $+/2 (global.get $one)
                                           (local.get $iz))
                                (global.get $missing))
                          (call $log
                                (call $-/2 (global.get $one)
                                           (local.get $iz))
                                (global.get $missing)))
                    (local.get $two-i)))

        ;; complex-sin : complex? -> number?
        ;;   Compute sin(a+bi).
        (func $complex-sin
              (param $z (ref $Complex))
              (result (ref eq))

              (local $a (ref eq))
              (local $b (ref eq))

              (local.set $a (struct.get $Complex $real (local.get $z)))
              (local.set $b (struct.get $Complex $imag (local.get $z)))
              (call $make-rectangular/canonical
                    (call $*/2
                          (call $sin (local.get $a))
                          (call $cosh (local.get $b)))
                    (call $*/2
                          (call $cos (local.get $a))
                          (call $sinh (local.get $b)))))

        ;; complex-cos : complex? -> number?
        ;;   Compute cos(a+bi).
        (func $complex-cos
              (param $z (ref $Complex))
              (result (ref eq))

              (local $a (ref eq))
              (local $b (ref eq))

              (local.set $a (struct.get $Complex $real (local.get $z)))
              (local.set $b (struct.get $Complex $imag (local.get $z)))
              (call $make-rectangular/canonical
                    (call $*/2
                          (call $cos (local.get $a))
                          (call $cosh (local.get $b)))
                    (call $real-negate
                          (call $*/2
                                (call $sin (local.get $a))
                                (call $sinh (local.get $b))))))

        ;; complex-tan : complex? -> number?
        ;;   Compute tan(a+bi).
        (func $complex-tan
              (param $z (ref $Complex))
              (result (ref eq))
              (call $/2
                    (call $complex-sin (local.get $z))
                    (call $complex-cos (local.get $z))))

        ;; complex-sinh : complex? -> number?
        ;;   Compute sinh(a+bi).
        (func $complex-sinh
              (param $z (ref $Complex))
              (result (ref eq))

              (local $a (ref eq))
              (local $b (ref eq))

              (local.set $a (struct.get $Complex $real (local.get $z)))
              (local.set $b (struct.get $Complex $imag (local.get $z)))
              (call $make-rectangular/canonical
                    (call $*/2
                          (call $sinh (local.get $a))
                          (call $cos (local.get $b)))
                    (call $*/2
                          (call $cosh (local.get $a))
                          (call $sin (local.get $b)))))

        ;; complex-cosh : complex? -> number?
        ;;   Compute cosh(a+bi).
        (func $complex-cosh
              (param $z (ref $Complex))
              (result (ref eq))

              (local $a (ref eq))
              (local $b (ref eq))

              (local.set $a (struct.get $Complex $real (local.get $z)))
              (local.set $b (struct.get $Complex $imag (local.get $z)))
              (call $make-rectangular/canonical
                    (call $*/2
                          (call $cosh (local.get $a))
                          (call $cos (local.get $b)))
                    (call $*/2
                          (call $sinh (local.get $a))
                          (call $sin (local.get $b)))))

        ;; complex-tanh : complex? -> number?
        ;;   Compute tanh(a+bi).
        (func $complex-tanh
              (param $z (ref $Complex))
              (result (ref eq))
              (call $/2
                    (call $complex-sinh (local.get $z))
                    (call $complex-cosh (local.get $z))))

        ;; Trigonometric functions
        ;               name js            inbits outbits
        ,@(let ([ops '((sin  $js-raw-math-sin  0      0 $complex-sin)    ;  sin(0) = 0
                       (cos  $js-raw-math-cos  0      2 $complex-cos)    ;  cos(0) = 1
                       (tan  $js-raw-math-tan  0      0 $complex-tan)    ;  tan(0) = 0
                       (asin $js-raw-math-asin 0      0 $complex-asin)    ; asin(0) = 0
                       (acos $js-raw-math-acos 2      0 $complex-acos)    ; acos(1) = 0
                       (sinh  $js-raw-math-sinh  0      0 $complex-sinh) ;  sinh(0) = 0
                       (cosh  $js-raw-math-cosh  0      2 $complex-cosh) ;  cosh(0) = 1
                       (tanh  $js-raw-math-tanh  0      0 $complex-tanh) ;  tanh(0) = 0
                       (asinh $js-raw-math-asinh 0      0 #f) ; asinh(0) = 0
                       (acosh $js-raw-math-acosh 2      0 #f) ; acosh(1) = 0
                       (atanh $js-raw-math-atanh 0      0 #f))]) ; atanh(0) = 0
            ;; inbits and outbits are raw i31 fixnum encodings.
            ;; They mark trivial exact identities of trig functions
            ;; (e.g. sin 0 = 0, cos 0 = 1, acos 1 = 0).
            ;; This avoids JS calls and flonum allocation in those cases.
            (for/list ([p ops])
              (define name    (car p))
              (define js      (cadr p))
              (define inbits  (caddr p))
              (define outbits (cadddr p))
              (define complex-helper (list-ref p 4))
              `(func ,(string->symbol (format "$~a" name))
                     (type $Prim1)
                     (param $x (ref eq))
                     (result (ref eq))

                     (local $bits i32)
                     (local $fl (ref $Flonum))
                     (local $f64 f64)

                     ,@(if complex-helper
                           `((if (ref.test (ref $Complex) (local.get $x))
                                 (then
                                  (return
                                   (call ,complex-helper
                                         (ref.cast (ref $Complex) (local.get $x)))))))
                           '())

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
                              (else (call $raise-expected-number/who
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x))
                                    (unreachable)))))

                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (return (struct.new $Flonum
                                               (i32.const 0)
                                               (call ,js (local.get $f64))))))

                     (if (call $exact-rational?/i32 (local.get $x))
                         (then
                          (return
                           (struct.new $Flonum
                                       (i32.const 0)
                                       (call ,js
                                             (call $exact-rational->f64
                                                   (local.get $x)))))))

                     (call $raise-expected-number/who
                           (global.get ,(string->symbol (format "$symbol:~a" name)))
                           (local.get $x))
                     (unreachable))))

        (func $atan (type $Prim12)
              (param $y (ref eq))
              (param $x (ref eq))
              (result   (ref eq))

              (local $bits i32)
              (local $y/f64 f64)
              (local $x/f64 f64)
              (local $y-exact i32)

              (if (ref.eq (local.get $x) (global.get $missing))
                  (then
                   (if (ref.test (ref $Complex) (local.get $y))
                       (then
                        (return
                         (call $complex-atan
                               (local.get $y)))))))

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
	                       (else (call $raise-expected-number/who
	                                   (global.get $symbol:atan)
	                                   (local.get $y)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $y))
                       (then (local.set $y/f64
                                        (struct.get $Flonum $v
                                                    (ref.cast (ref $Flonum) (local.get $y)))))
                       (else
                        (if (call $exact-rational?/i32 (local.get $y))
                            (then (local.set $y/f64
                                             (call $exact-rational->f64
                                                   (local.get $y)))
                                  (local.set $y-exact (i32.const 1)))
                            (else (call $raise-expected-number/who
                                        (global.get $symbol:atan)
                                        (local.get $y)) (unreachable)))))))

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
	                       (else (call $raise-expected-number/who
	                                   (global.get $symbol:atan)
	                                   (local.get $x)) (unreachable))))
                  (else
                   (if (ref.test (ref $Flonum) (local.get $x))
                       (then (local.set $x/f64
                                        (struct.get $Flonum $v
                                                    (ref.cast (ref $Flonum) (local.get $x)))))
                       (else
                        (if (call $exact-rational?/i32 (local.get $x))
                            (then (local.set $x/f64
                                             (call $exact-rational->f64
                                                   (local.get $x))))
                            (else (call $raise-expected-number/who
                                        (global.get $symbol:atan)
                                        (local.get $x)) (unreachable)))))))

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
                              (else (call $raise-expected-real
                                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                                          (local.get $x))
                                    (unreachable)))))

                     (if (ref.test (ref $Flonum) (local.get $x))
                         (then
                          (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                          (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                          (return (struct.new $Flonum
                                               (i32.const 0)
                                               (f64.mul (local.get $f64) (f64.const ,factor))))))

                    (call $raise-expected-real
                          (global.get ,(string->symbol (format "$symbol:~a" name)))
                          (local.get $x))
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
                            (else (call $raise-argument-error1
                                        (global.get $symbol:order-of-magnitude)
                                        (global.get $string:order-of-magnitude:positive-finite)
                                        (local.get $r))
                                  (unreachable))))
                       (else (call $raise-argument-error1
                                   (global.get $symbol:order-of-magnitude)
                                   (global.get $string:order-of-magnitude:positive-finite)
                                   (local.get $r))
                             (unreachable)))))

              (if (i32.eqz (local.get $ok))
                  (then
                   (if (ref.test (ref $Flonum) (local.get $r))
                       (then
                        (local.set $fl (ref.cast (ref $Flonum) (local.get $r)))
                        (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                        (if (f64.le (local.get $f64) (f64.const 0))
                            (then (call $raise-argument-error1
                                        (global.get $symbol:order-of-magnitude)
                                        (global.get $string:order-of-magnitude:positive-finite)
                                        (local.get $r))
                                  (unreachable)))
                        (if (f64.eq (local.get $f64) (f64.const inf))
                            (then (call $raise-argument-error1
                                        (global.get $symbol:order-of-magnitude)
                                        (global.get $string:order-of-magnitude:positive-finite)
                                        (local.get $r))
                                  (unreachable)))
                        (if (f64.ne (local.get $f64) (local.get $f64))
                            (then (call $raise-argument-error1
                                        (global.get $symbol:order-of-magnitude)
                                        (global.get $string:order-of-magnitude:positive-finite)
                                        (local.get $r))
                                  (unreachable)))
                        (local.set $ok (i32.const 1))))))

              (if (i32.eqz (local.get $ok))
                  (then (call $raise-argument-error1
                              (global.get $symbol:order-of-magnitude)
                              (global.get $string:order-of-magnitude:positive-finite)
                              (local.get $r))
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

;; number-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate numeric error helpers that still depend on monolithic runtime globals.
(define number-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'number-error-runtime-only-helpers
   '(
        (func $raise-expected-number/common
              (param $x (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              ;; The legacy numeric callers do not yet pass a precise `who`.
              ;; Keep the error catchable and preserve expected/given text;
              ;; call-site-specific `who` is tracked as follow-up debt.
              (local.set $out (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:number?))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:number?))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out)
                    (call $format/error-value->string (local.get $x)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))
              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-expected-number/who
              (param $who (ref eq))
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:number?)
                    (local.get $x))
              (unreachable))

        (func $raise-expected-number
              (param $x (ref eq))
              (call $raise-expected-number/common (local.get $x))
              (unreachable))
        (func $raise-expected-number1
              (param $x (ref eq))
              (call $raise-expected-number/common (local.get $x))
              (unreachable))
        (func $raise-expected-number2
              (param $x (ref eq))
              (call $raise-expected-number/common (local.get $x))
              (unreachable))
        (func $raise-expected-number3
              (param $x (ref eq))
              (call $raise-expected-number/common (local.get $x))
              (unreachable))
        (func $raise-expected-number4
              (param $x (ref eq))
              (call $raise-expected-number/common (local.get $x))
              (unreachable))

        (func $raise-expected-integer
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:integer?)
                    (local.get $x))
              (unreachable))

        (func $raise-expected-exact-integer
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:exact-integer?)
                    (local.get $x))
              (unreachable))

        (func $raise-expected-exact-nonnegative-integer
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:exact-nonnegative-integer?)
                    (local.get $x))
              (unreachable))

        (func $raise-expected-rational
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:rational?)
                    (local.get $x))
              (unreachable))

        (func $raise-expected-real
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:real?)
                    (local.get $x))
              (unreachable))

        (func $raise-expected-keyword
              (param $who (ref eq))   ;; symbol
              (param $x   (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:keyword?)
                    (local.get $x))
              (unreachable))

        (func $raise-inexact->exact:no-exact-representation
              (param $x (ref eq))

              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              (local.set $out (call $make-growable-array (i32.const 3)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display
                          (global.get $symbol:inexact->exact)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:inexact->exact:no-exact-representation))
              (call $growable-array-add! (local.get $out)
                    (call $format/error-value->string (local.get $x)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))
     )))

;; generic-arithmetic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic arithmetic helpers.
(define generic-arithmetic-runtime-only-helper-names
  '($number-real-part/unchecked
    $number-imag-part/unchecked
    $complex-add/2
    $complex-sub/2
    $complex-mul/2
    $complex-div/2
    $complex=/2
    $+/2
    $-/2
    $*/2
    $+
    $*
    $-
    $/2
    $/
    $rational-argument->exact
    $rational-abs/argument
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
         ;; number-real-part/unchecked : number? -> real?
         ;;   Return the real component of a validated real-or-complex number.
         (func $number-real-part/unchecked
               (param $z (ref eq))
               (result (ref eq))

               (if (ref.test (ref $Complex) (local.get $z))
                   (then
                    (return
                     (struct.get $Complex $real
                                 (ref.cast (ref $Complex) (local.get $z))))))
               (local.get $z))

         ;; number-imag-part/unchecked : number? -> real?
         ;;   Return the imaginary component of a validated real-or-complex number.
         (func $number-imag-part/unchecked
               (param $z (ref eq))
               (result (ref eq))

               (if (ref.test (ref $Complex) (local.get $z))
                   (then
                    (return
                     (struct.get $Complex $imag
                                 (ref.cast (ref $Complex) (local.get $z))))))
               (global.get $zero))

         ;; complex-add/2 : number? number? -> number?
         ;;   Add two validated real-or-complex numbers.
         (func $complex-add/2
               (param $x (ref eq))
               (param $y (ref eq))
               (result (ref eq))
               (call $make-rectangular/canonical
                     (call $+/2
                           (call $number-real-part/unchecked (local.get $x))
                           (call $number-real-part/unchecked (local.get $y)))
                     (call $+/2
                           (call $number-imag-part/unchecked (local.get $x))
                           (call $number-imag-part/unchecked (local.get $y)))))

         ;; complex-sub/2 : number? number? -> number?
         ;;   Subtract two validated real-or-complex numbers.
         (func $complex-sub/2
               (param $x (ref eq))
               (param $y (ref eq))
               (result (ref eq))
               (call $make-rectangular/canonical
                     (call $-/2
                           (call $number-real-part/unchecked (local.get $x))
                           (call $number-real-part/unchecked (local.get $y)))
                     (call $-/2
                           (call $number-imag-part/unchecked (local.get $x))
                           (call $number-imag-part/unchecked (local.get $y)))))

         ;; complex-mul/2 : number? number? -> number?
         ;;   Multiply two validated real-or-complex numbers exactly when possible.
         (func $complex-mul/2
               (param $x (ref eq))
               (param $y (ref eq))
               (result (ref eq))

               (local $a (ref eq))
               (local $b (ref eq))
               (local $c (ref eq))
               (local $d (ref eq))

               (local.set $a (call $number-real-part/unchecked (local.get $x)))
               (local.set $b (call $number-imag-part/unchecked (local.get $x)))
               (local.set $c (call $number-real-part/unchecked (local.get $y)))
               (local.set $d (call $number-imag-part/unchecked (local.get $y)))
               (call $make-rectangular/canonical
                     (call $-/2
                           (call $*/2 (local.get $a) (local.get $c))
                           (call $*/2 (local.get $b) (local.get $d)))
                     (call $+/2
                           (call $*/2 (local.get $a) (local.get $d))
                           (call $*/2 (local.get $b) (local.get $c)))))

         ;; complex-div/2 : number? number? -> number?
         ;;   Divide two validated real-or-complex numbers exactly when possible.
         (func $complex-div/2
               (param $x (ref eq))
               (param $y (ref eq))
               (result (ref eq))

               (local $a        (ref eq))
               (local $b        (ref eq))
               (local $c        (ref eq))
               (local $d        (ref eq))
               (local $denom    (ref eq))
               (local $inexact? i32)
               (local $af       f64)
               (local $bf       f64)
               (local $cf       f64)
               (local $df       f64)
               (local $r        f64)
               (local $denomf   f64)

               (local.set $a (call $number-real-part/unchecked (local.get $x)))
               (local.set $b (call $number-imag-part/unchecked (local.get $x)))
               (local.set $c (call $number-real-part/unchecked (local.get $y)))
               (local.set $d (call $number-imag-part/unchecked (local.get $y)))
               (local.set $inexact?
                          (i32.or
                           (i32.or
                            (ref.test (ref $Flonum) (local.get $a))
                            (ref.test (ref $Flonum) (local.get $b)))
                           (i32.or
                            (ref.test (ref $Flonum) (local.get $c))
                            (ref.test (ref $Flonum) (local.get $d)))))
               (if (local.get $inexact?)
                   (then
                    (local.set $af
                               (call $real->f64/checked
                                     (global.get $symbol:/)
                                     (local.get $a)))
                    (local.set $bf
                               (call $real->f64/checked
                                     (global.get $symbol:/)
                                     (local.get $b)))
                    (local.set $cf
                               (call $real->f64/checked
                                     (global.get $symbol:/)
                                     (local.get $c)))
                    (local.set $df
                               (call $real->f64/checked
                                     (global.get $symbol:/)
                                     (local.get $d)))
                    (if (f64.ge (f64.abs (local.get $cf))
                                (f64.abs (local.get $df)))
                        (then
                         (local.set $r
                                    (f64.div (local.get $df)
                                             (local.get $cf)))
                         (local.set $denomf
                                    (f64.add (local.get $cf)
                                             (f64.mul (local.get $df)
                                                      (local.get $r))))
                         (return
                          (call $make-rectangular/canonical
                                (struct.new $Flonum
                                            (i32.const 0)
                                            (f64.div
                                             (f64.add
                                              (local.get $af)
                                              (f64.mul (local.get $bf)
                                                       (local.get $r)))
                                             (local.get $denomf)))
                                (struct.new $Flonum
                                            (i32.const 0)
                                            (f64.div
                                             (f64.sub
                                              (local.get $bf)
                                              (f64.mul (local.get $af)
                                                       (local.get $r)))
                                             (local.get $denomf))))))
                        (else
                         (local.set $r
                                    (f64.div (local.get $cf)
                                             (local.get $df)))
                         (local.set $denomf
                                    (f64.add (local.get $df)
                                             (f64.mul (local.get $cf)
                                                      (local.get $r))))
                         (return
                          (call $make-rectangular/canonical
                                (struct.new $Flonum
                                            (i32.const 0)
                                            (f64.div
                                             (f64.add
                                              (f64.mul (local.get $af)
                                                       (local.get $r))
                                              (local.get $bf))
                                             (local.get $denomf)))
                                (struct.new $Flonum
                                            (i32.const 0)
                                            (f64.div
                                             (f64.sub
                                              (f64.mul (local.get $bf)
                                                       (local.get $r))
                                              (local.get $af))
                                             (local.get $denomf)))))))))
               (local.set $denom
                          (call $+/2
                                (call $*/2 (local.get $c) (local.get $c))
                                (call $*/2 (local.get $d) (local.get $d))))
               (call $make-rectangular/canonical
                     (call $/2
                           (call $+/2
                                 (call $*/2 (local.get $a) (local.get $c))
                                 (call $*/2 (local.get $b) (local.get $d)))
                           (local.get $denom))
                     (call $/2
                           (call $-/2
                                 (call $*/2 (local.get $b) (local.get $c))
                                 (call $*/2 (local.get $a) (local.get $d)))
                           (local.get $denom))))

         ;; complex=/2 : number? number? -> boolean?
         ;;   Compare two validated real-or-complex numbers component-wise.
         (func $complex=/2
               (param $x (ref eq))
               (param $y (ref eq))
               (result (ref eq))

               (if (ref.eq
                    (call $=/2
                          (call $number-real-part/unchecked (local.get $x))
                          (call $number-real-part/unchecked (local.get $y)))
                    (global.get $false))
                   (then (return (global.get $false))))
               (call $=/2
                     (call $number-imag-part/unchecked (local.get $x))
                     (call $number-imag-part/unchecked (local.get $y))))

         ,@(let ()
             (define (binop $op $who $flop $intop $ratop $complexop)
               `(func ,$op (type $Prim2)
                      (param $x (ref eq))
                      (param $y (ref eq))
                      (result   (ref eq))

                      (local $x/is-rat i32)
                      (local $y/is-rat i32)
                      (local $x/is-complex i32)
                      (local $y/is-complex i32)

                      (local.set $x/is-complex (ref.test (ref $Complex) (local.get $x)))
                      (local.set $y/is-complex (ref.test (ref $Complex) (local.get $y)))
                      (if (i32.or (local.get $x/is-complex)
                                  (local.get $y/is-complex))
                          (then
                           (if (i32.eqz
                                (i32.or (local.get $x/is-complex)
                                        (call $real-number?/i32 (local.get $x))))
                               (then (call $raise-expected-number/who
                                           (global.get ,$who)
                                           (local.get $x))
                                     (unreachable)))
                           (if (i32.eqz
                                (i32.or (local.get $y/is-complex)
                                        (call $real-number?/i32 (local.get $y))))
                               (then (call $raise-expected-number/who
                                           (global.get ,$who)
                                           (local.get $y))
                                     (unreachable)))
                           (return (call ,$complexop
                                         (local.get $x)
                                         (local.get $y)))))
                      (local.set $x/is-rat (ref.test (ref $Rational) (local.get $x)))
                      (local.set $y/is-rat (ref.test (ref $Rational) (local.get $y)))
                      (if (i32.or (local.get $x/is-rat) (local.get $y/is-rat))
                          (then
                           (if (i32.and
                                (call $exact-rational?/i32 (local.get $x))
                                (call $exact-rational?/i32 (local.get $y)))
                               (then (return (call ,$ratop
                                                   (local.get $x)
                                                   (local.get $y)))))
                           (if (i32.and (local.get $x/is-rat)
                                        (call $fl?/i32 (local.get $y)))
                               (then
                                (return
                                 (call ,$flop
                                       (struct.new $Flonum
                                                   (i32.const 0)
                                                   (call $exact-rational->f64
                                                         (local.get $x)))
                                       (local.get $y)))))
                           (if (i32.and (call $fl?/i32 (local.get $x))
                                        (local.get $y/is-rat))
                               (then
                                (return
                                 (call ,$flop
                                       (local.get $x)
                                       (struct.new $Flonum
                                                   (i32.const 0)
                                                   (call $exact-rational->f64
                                                         (local.get $y)))))))
                           (if (local.get $x/is-rat)
                               (then (call $raise-expected-number/who
                                           (global.get ,$who)
                                           (local.get $y))
                                     (unreachable))
                               (else (call $raise-expected-number/who
                                           (global.get ,$who)
                                           (local.get $x))
                                     (unreachable)))))

                      (if (result (ref eq))
                          (call $fx?/i32 (local.get $x))
                          ; x fixnum
                          (then (if (result (ref eq))
                                    (call $fx?/i32 (local.get $y))
                                    ; x and y fixnums
                                    (then (call ,$intop
                                                (local.get $x) (local.get $y)))
                                    ; x fixnum, y non-fixnum
                                    (else (if (result (ref eq))
                                              (call $fl?/i32 (local.get $y))
                                              ; x fixnum, y flonum
                                              (then (call ,$flop
                                                          (call $fx->fl/precise (local.get $x)) (local.get $y)))
                                              ; x fixnum, y maybe bignum
                                              (else (if (result (ref eq))
                                                        (ref.test (ref $Bignum) (local.get $y))
                                                        ; x fixnum, y bignum
                                                        (then (call ,$intop
                                                                    (local.get $x) (local.get $y)))
                                                        ; x fixnum, y not a number
                                                        (else (call $raise-expected-number/who
                                                                    (global.get ,$who)
                                                                    (local.get $y))
                                                              (unreachable))))))))
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
                                                        ; x flonum, y maybe bignum
                                                        (else (if (result (ref eq))
                                                                  (ref.test (ref $Bignum) (local.get $y))
                                                                  ; x flonum, y bignum
                                                                  (then (call ,$flop
                                                                              (local.get $x)
                                                                              (struct.new $Flonum
                                                                                          (i32.const 0)
                                                                                          (call $integer->f64
                                                                                                (local.get $y)))))
                                                                  ; x flonum, y not a number
                                                                  (else (call $raise-expected-number/who
                                                                              (global.get ,$who)
                                                                              (local.get $y))
                                                                        (unreachable))))))))
                                    ; x maybe bignum
                                    (else (if (result (ref eq))
                                              (ref.test (ref $Bignum) (local.get $x))
                                              ; x bignum
                                              (then (if (result (ref eq))
                                                        (call $fx?/i32 (local.get $y))
                                                        ; x bignum, y fixnum
                                                        (then (call ,$intop
                                                                    (local.get $x) (local.get $y)))
                                                        ; x bignum, y not fixnum
                                                        (else (if (result (ref eq))
                                                                  (ref.test (ref $Bignum) (local.get $y))
                                                                  ; x bignum, y bignum
                                                                  (then (call ,$intop
                                                                              (local.get $x) (local.get $y)))
                                                                  ; x bignum, y maybe flonum
                                                                  (else (if (result (ref eq))
                                                                            (call $fl?/i32 (local.get $y))
                                                                            ; x bignum, y flonum
                                                                            (then (call ,$flop
                                                                                        (struct.new $Flonum
                                                                                                    (i32.const 0)
                                                                                                    (call $integer->f64
                                                                                                          (local.get $x)))
                                                                                        (local.get $y)))
                                                                            ; x bignum, y not a number
                                                                            (else (call $raise-expected-number/who
                                                                                        (global.get ,$who)
                                                                                        (local.get $y))
                                                                                  (unreachable))))))))
                                              ; x is not a number
                                              (else (call $raise-expected-number/who
                                                          (global.get ,$who)
                                                          (local.get $x))
                                                    (unreachable)))))))))
            (list (binop '$+/2 '$symbol:+ '$fl+ '$integer-add/2 '$exact-rational-add/2 '$complex-add/2)
                  (binop '$-/2 '$symbol:- '$fl- '$integer-sub/2 '$exact-rational-sub/2 '$complex-sub/2)
                  (binop '$*/2 '$symbol:* '$fl* '$integer-mul/2 '$exact-rational-mul/2 '$complex-mul/2)))

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
               (local $x/exact i32)
               (local $y/exact i32)
               (local $x/inexact i32)
               (local $y/inexact i32)
               (local $x/complex i32)
               (local $y/complex i32)

               (local.set $x/complex (ref.test (ref $Complex) (local.get $x)))
               (local.set $y/complex (ref.test (ref $Complex) (local.get $y)))
               (if (i32.or (local.get $x/complex) (local.get $y/complex))
                   (then
                    (if (i32.eqz
                         (i32.or (local.get $x/complex)
                                 (call $real-number?/i32 (local.get $x))))
                        (then (call $raise-expected-number/who
                                    (global.get $symbol:/)
                                    (local.get $x))
                              (unreachable)))
                    (if (i32.eqz
                         (i32.or (local.get $y/complex)
                                 (call $real-number?/i32 (local.get $y))))
                        (then (call $raise-expected-number/who
                                    (global.get $symbol:/)
                                    (local.get $y))
                              (unreachable)))
                    (return (call $complex-div/2
                                  (local.get $x)
                                  (local.get $y)))))
               (local.set $x/exact (call $exact-rational?/i32 (local.get $x)))
               (local.set $y/exact (call $exact-rational?/i32 (local.get $y)))
               (local.set $x/inexact (ref.test (ref $Flonum) (local.get $x)))
               (local.set $y/inexact (ref.test (ref $Flonum) (local.get $y)))

               (if (i32.eqz (i32.or (local.get $x/exact) (local.get $x/inexact)))
                   (then (call $raise-expected-number/who
                               (global.get $symbol:/)
                               (local.get $x))
                         (unreachable)))
               (if (i32.eqz (i32.or (local.get $y/exact) (local.get $y/inexact)))
                   (then (call $raise-expected-number/who
                               (global.get $symbol:/)
                               (local.get $y))
                         (unreachable)))

               (if (local.get $y/exact)
                   (then
                    (if (call $exact-rational-zero?/i32 (local.get $y))
                        (then (call $raise-division-by-zero) (unreachable)))))
               (if (i32.and (local.get $x/exact) (local.get $y/exact))
                   (then
                    (return
                     (call $exact-rational-div/2
                           (local.get $x)
                           (local.get $y)))))

               (local.set $x/fl
                          (if (result (ref $Flonum))
                              (local.get $x/inexact)
                              (then (ref.cast (ref $Flonum) (local.get $x)))
                              (else (struct.new $Flonum
                                                (i32.const 0)
                                                (call $exact-rational->f64
                                                      (local.get $x))))))
               (local.set $y/fl
                          (if (result (ref $Flonum))
                              (local.get $y/inexact)
                              (then (ref.cast (ref $Flonum) (local.get $y)))
                              (else (struct.new $Flonum
                                                (i32.const 0)
                                                (call $exact-rational->f64
                                                      (local.get $y))))))
               (call $fl/ (local.get $x/fl) (local.get $y/fl)))

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

        (func $rational-argument->exact
              (param $who (ref eq))
              (param $x   (ref eq))
              (result (ref eq))

              (local $fl  (ref $Flonum))
              (local $f64 f64)

              (if (call $exact-rational?/i32 (local.get $x))
                  (then (return (local.get $x))))
              (if (ref.test (ref $Flonum) (local.get $x))
                  (then
                   (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                   (local.set $f64 (struct.get $Flonum $v (local.get $fl)))
                   (if (f64.ne (local.get $f64) (local.get $f64))
                       (then (call $raise-expected-rational
                                   (local.get $who)
                                   (local.get $x))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const +inf))
                       (then (call $raise-expected-rational
                                   (local.get $who)
                                   (local.get $x))
                             (unreachable)))
                   (if (f64.eq (local.get $f64) (f64.const -inf))
                       (then (call $raise-expected-rational
                                   (local.get $who)
                                   (local.get $x))
                             (unreachable)))
                   (return (call $f64->exact-rational (local.get $f64)))))
              (call $raise-expected-rational
                    (local.get $who)
                    (local.get $x))
              (unreachable))

        (func $rational-abs/argument
              (param $who (ref eq))
              (param $x   (ref eq))
              (result (ref eq))

              (local $exact  (ref eq))
              (local $result (ref eq))

              (local.set $exact
                         (call $rational-argument->exact
                               (local.get $who)
                               (local.get $x)))
              (local.set $result
                         (call $exact-rational-abs (local.get $exact)))
              (if (ref.test (ref $Flonum) (local.get $x))
                  (then (return (call $exact->inexact
                                      (local.get $result)))))
              (local.get $result))

        (func $gcd/2 (type $Prim2)
              (param $n (ref eq))
              (param $m (ref eq))
              (result (ref eq))

              (local $inexact? i32)
              (local $r        (ref eq))

              (local.set $inexact?
                         (i32.or
                          (ref.test (ref $Flonum) (local.get $n))
                          (ref.test (ref $Flonum) (local.get $m))))
              (local.set $n (call $rational-argument->exact
                                  (global.get $symbol:gcd)
                                  (local.get $n)))
              (local.set $m (call $rational-argument->exact
                                  (global.get $symbol:gcd)
                                  (local.get $m)))
              (local.set $r (call $exact-rational-gcd/2
                                  (local.get $n)
                                  (local.get $m)))
              (if (local.get $inexact?)
                  (then (return (call $exact->inexact
                                      (local.get $r)))))
              (local.get $r))

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

               (local $inexact? i32)
               (local $r        (ref eq))

               (local.set $inexact?
                          (i32.or
                           (ref.test (ref $Flonum) (local.get $n))
                           (ref.test (ref $Flonum) (local.get $m))))
               (local.set $n (call $rational-argument->exact
                                   (global.get $symbol:lcm)
                                   (local.get $n)))
               (local.set $m (call $rational-argument->exact
                                   (global.get $symbol:lcm)
                                   (local.get $m)))
               (local.set $r (call $exact-rational-lcm/2
                                   (local.get $n)
                                   (local.get $m)))
               (if (local.get $inexact?)
                   (then (return (call $exact->inexact
                                       (local.get $r)))))
               (local.get $r))



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
               (if (ref.eq (local.get $xs) (global.get $null))
                   (then (return ,(Imm 1))))
               (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
               (local.set $v    (struct.get $Pair $a (local.get $node)))
               (local.set $r    (call $rational-abs/argument
                                      (global.get $symbol:lcm)
                                      (local.get $v)))
               (local.set $xs   (struct.get $Pair $d (local.get $node)))
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
             (define (symbol-global who)
               (string->symbol (~a "$symbol:" who)))

             (define (raise-expected-number who value)
               `((call $raise-expected-number/who
                       (global.get ,(symbol-global who))
                       ,value)
                 (unreachable)))

             (define (raise-expected-real who value)
               `((call $raise-expected-real
                       (global.get ,(symbol-global who))
                       ,value)
                 (unreachable)))

             (define (raise-expected expected who value)
               (case expected
                 [(number) (raise-expected-number who value)]
                 [(real)   (raise-expected-real who value)]
                 [else (error 'gencmp "unknown expected numeric contract: ~a" expected)]))

             (define (cmp-result-test who)
               (case who
                 [(=)  `(i32.eqz (local.get $cmp/i32))]
                 [(<)  `(i32.lt_s (local.get $cmp/i32) (i32.const 0))]
                 [(>)  `(i32.gt_s (local.get $cmp/i32) (i32.const 0))]
                 [(<=) `(i32.le_s (local.get $cmp/i32) (i32.const 0))]
                 [(>=) `(i32.ge_s (local.get $cmp/i32) (i32.const 0))]
                 [else (error 'gencmp "unknown comparator: ~a" who)]))

             (define (cmp-result->boolean who)
               `((if (i32.eq (local.get $cmp/i32) (i32.const 2))
                     (then (return (global.get $false))))
                 (return
                  (if (result (ref eq))
                      ,(cmp-result-test who)
                      (then (global.get $true))
                      (else (global.get $false))))))

             (define (gencmp cmp who expected fxcmp flcmp)
               `(func ,cmp
                      (param $x (ref eq))
                      (param $y (ref eq))
                      (result   (ref eq))

                      (local $x/is-fx i32)
                      (local $y/is-fx i32)
                      (local $x/is-big i32)
                      (local $y/is-big i32)
                      (local $x/is-rat i32)
                      (local $y/is-rat i32)
                      (local $x/is-fl i32)
                      (local $y/is-fl i32)
                      (local $x/is-complex i32)
                      (local $y/is-complex i32)
                      (local $cmp/i32 i32)
                      (local $x-fl    (ref null $Flonum))
                      (local $y-fl    (ref null $Flonum))
                      ,@(if (eq? expected 'number)
                            `((local.set $x/is-complex
                                         (ref.test (ref $Complex) (local.get $x)))
                              (local.set $y/is-complex
                                         (ref.test (ref $Complex) (local.get $y)))
                              (if (i32.or (local.get $x/is-complex)
                                          (local.get $y/is-complex))
                                  (then
                                   (if (i32.eqz
                                        (i32.or (local.get $x/is-complex)
                                                (call $real-number?/i32 (local.get $x))))
                                       (then ,@(raise-expected-number who `(local.get $x))))
                                   (if (i32.eqz
                                        (i32.or (local.get $y/is-complex)
                                                (call $real-number?/i32 (local.get $y))))
                                       (then ,@(raise-expected-number who `(local.get $y))))
                                   (return (call $complex=/2
                                                 (local.get $x)
                                                 (local.get $y))))))
                            '())
                      ;; --- Check if x is a fixnum ---
                      (local.set $x/is-fx (call $fx?/i32 (local.get $x)))
                      ;; --- Check if x is a bignum ---
                      (local.set $x/is-big (ref.test (ref $Bignum) (local.get $x)))
                      ;; --- Check if x is an exact rational ---
                      (local.set $x/is-rat (ref.test (ref $Rational) (local.get $x)))
                      ;; --- Check if y is a fixnum ---
                      (local.set $y/is-fx (call $fx?/i32 (local.get $y)))
                      ;; --- Check if y is a bignum ---
                      (local.set $y/is-big (ref.test (ref $Bignum) (local.get $y)))
                      ;; --- Check if y is an exact rational ---
                      (local.set $y/is-rat (ref.test (ref $Rational) (local.get $y)))
                      ;; --- If both are exact integers, compare without flonum conversion. ---
                      (if (i32.and
                           (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                           (i32.or (local.get $y/is-fx) (local.get $y/is-big)))
                          (then
                           (local.set $cmp/i32
                                      (call $integer-compare/i32
                                            (local.get $x)
                                            (local.get $y)))
                           ,@(cmp-result->boolean who)))
                      ;; --- Exact rational pairs compare by cross multiplication. ---
                      (if (i32.and
                           (i32.or (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                                   (local.get $x/is-rat))
                           (i32.or (i32.or (local.get $y/is-fx) (local.get $y/is-big))
                                   (local.get $y/is-rat)))
                          (then
                           (local.set $cmp/i32
                                      (call $exact-rational-compare/i32
                                            (local.get $x)
                                            (local.get $y)))
                           ,@(cmp-result->boolean who)))
                      ;; --- Check if x is a flonum ---
                      (local.set $x/is-fl (ref.test (ref $Flonum) (local.get $x)))
                      ;; --- Raise if x is not a number ---
                      (if (i32.eqz
                           (i32.or
                            (i32.or
                             (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                             (local.get $x/is-rat))
                            (local.get $x/is-fl)))
                          (then ,@(raise-expected expected who `(local.get $x))))
                      ;; --- Check if y is a flonum ---
                      (local.set $y/is-fl (ref.test (ref $Flonum) (local.get $y)))
                      ;; --- Raise if y is not a number ---
                      (if (i32.eqz
                           (i32.or
                            (i32.or
                             (i32.or (local.get $y/is-fx) (local.get $y/is-big))
                             (local.get $y/is-rat))
                            (local.get $y/is-fl)))
                          (then ,@(raise-expected expected who `(local.get $y))))
                      ;; --- Exact integer/flonum mixed cases compare exactly. ---
                      (if (i32.and
                           (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                           (local.get $y/is-fl))
                          (then
                           (local.set $cmp/i32
                                      (call $integer-flonum-compare/i32
                                            (local.get $x)
                                            (ref.cast (ref $Flonum) (local.get $y))))
                           ,@(cmp-result->boolean who)))
                      (if (i32.and
                           (local.get $x/is-fl)
                           (i32.or (local.get $y/is-fx) (local.get $y/is-big)))
                          (then
                           (local.set $cmp/i32
                                      (call $integer-flonum-compare/i32
                                            (local.get $y)
                                            (ref.cast (ref $Flonum) (local.get $x))))
                           (if (i32.ne (local.get $cmp/i32) (i32.const 2))
                               (then
                                (local.set $cmp/i32
                                           (i32.sub (i32.const 0)
                                                   (local.get $cmp/i32)))))
                           ,@(cmp-result->boolean who)))
                      ;; --- Rational/flonum mixed cases compare against the exact binary flonum value. ---
                      (if (i32.and (local.get $x/is-rat) (local.get $y/is-fl))
                          (then
                           (local.set $cmp/i32
                                      (call $exact-rational-flonum-compare/i32
                                            (local.get $x)
                                            (ref.cast (ref $Flonum) (local.get $y))))
                           ,@(cmp-result->boolean who)))
                      (if (i32.and (local.get $x/is-fl) (local.get $y/is-rat))
                          (then
                           (local.set $cmp/i32
                                      (call $exact-rational-flonum-compare/i32
                                            (local.get $y)
                                            (ref.cast (ref $Flonum) (local.get $x))))
                           (if (i32.ne (local.get $cmp/i32) (i32.const 2))
                               (then
                                (local.set $cmp/i32
                                           (i32.sub (i32.const 0)
                                                    (local.get $cmp/i32)))))
                           ,@(cmp-result->boolean who)))
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

             (list (gencmp '$=/2  '=  'number '$fx=/2  '$fl=)   ; maybe specialize this one?
                   (gencmp '$</2  '<  'real   '$fx</2  '$fl<)
                   (gencmp '$>/2  '>  'real   '$fx>/2  '$fl>)
                   (gencmp '$<=/2 '<= 'real   '$fx<=/2 '$fl<=)
                   (gencmp '$>=/2 '>= 'real   '$fx>=/2 '$fl>=)))

         ;; Variadic Number Comparators
         ,@(let ()
             (define (symbol-global who)
               (string->symbol (~a "$symbol:" who)))

             (define (raise-expected-number who value)
               `((call $raise-expected-number/who
                       (global.get ,(symbol-global who))
                       ,value)
                 (unreachable)))

             (define (raise-expected-real who value)
               `((call $raise-expected-real
                       (global.get ,(symbol-global who))
                       ,value)
                 (unreachable)))

             (define (raise-expected expected who value)
               (case expected
                 [(number) (raise-expected-number who value)]
                 [(real)   (raise-expected-real who value)]
                 [else (error 'gen-variadic-cmp "unknown expected numeric contract: ~a" expected)]))

             (define (gen-variadic-cmp name who expected cmp/2)
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
                      (local $x/is-big i32)
                      (local $x/is-rat i32)
                      (local $x/is-fl i32)
                      (local $x/is-complex i32)

                      (local.set $xs
                                 (if (result (ref eq))
                                     (ref.test (ref $Args) (local.get $xs0))
                                     (then (call $rest-arguments->list
                                                 (ref.cast (ref $Args) (local.get $xs0))
                                                 (i32.const 0)))
                                     (else (local.get $xs0))))

                      ;; Single argument: ensure it is a number and return #t.
                      (if (ref.eq (local.get $xs) (global.get $null))
                          (then (local.set $x/is-fx (call $fx?/i32 (local.get $x0)))
                                (local.set $x/is-big (ref.test (ref $Bignum) (local.get $x0)))
                                (local.set $x/is-rat (ref.test (ref $Rational) (local.get $x0)))
                                (local.set $x/is-fl (ref.test (ref $Flonum) (local.get $x0)))
                                ,@(if (eq? expected 'number)
                                      `((local.set $x/is-complex
                                                   (ref.test (ref $Complex) (local.get $x0))))
                                      '())
                                (if (i32.eqz
                                     (i32.or
                                      (i32.or
                                       (i32.or
                                        (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                                        (local.get $x/is-rat))
                                       (local.get $x/is-fl))
                                      ,(if (eq? expected 'number)
                                           `(local.get $x/is-complex)
                                           `(i32.const 0))))
                                    (then ,@(raise-expected expected who `(local.get $x0))))
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
             (list (gen-variadic-cmp '$=  '=  'number '$=/2)
                   (gen-variadic-cmp '$<  '<  'real   '$</2)
                   (gen-variadic-cmp '$>  '>  'real   '$>/2)
                   (gen-variadic-cmp '$<= '<= 'real   '$<=/2)
                   (gen-variadic-cmp '$>= '>= 'real   '$>=/2)))

        ,@(let ()
            (define (symbol-global who)
              (string->symbol (~a "$symbol:" who)))

            (define (gen-minmax name fxop flop)
              (define $name/2 (string->symbol (~a "$" name "/2")))
              (define $name   (string->symbol (~a "$" name)))
              (define $who    (symbol-global name))
              (define exact-x-wins?
                (case name
                  [(min) `(i32.lt_s (local.get $cmp/i32) (i32.const 0))]
                  [(max) `(i32.gt_s (local.get $cmp/i32) (i32.const 0))]
                  [else (error 'gen-minmax "unknown min/max primitive: ~a" name)]))
              (define fl-exact-x-wins?
                (case name
                  [(min) `(i32.gt_s (local.get $cmp/i32) (i32.const 0))]
                  [(max) `(i32.lt_s (local.get $cmp/i32) (i32.const 0))]
                  [else (error 'gen-minmax "unknown min/max primitive: ~a" name)]))
              `((func ,$name/2 (type $Prim2)
                      (param $x (ref eq))
                      (param $y (ref eq))
                      (result   (ref eq))

                      (local $x/is-fx i32)
                      (local $x/is-big i32)
                      (local $x/is-fl i32)

                      (local $y/is-fx i32)
                      (local $y/is-big i32)
                      (local $y/is-fl i32)
                      (local $cmp/i32 i32)

                      ;; Type check $x
                      (local.set $x/is-fx (call $fx?/i32 (local.get $x)))
                      (local.set $x/is-big (ref.test (ref $Bignum) (local.get $x)))
                      (local.set $x/is-fl (ref.test (ref $Flonum) (local.get $x)))
                      (if (i32.eqz
                           (i32.or
                            (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                            (local.get $x/is-fl)))
                          (then (call $raise-expected-real
                                      (global.get ,$who)
                                      (local.get $x))
                                (unreachable)))

                      ;; Type check $y
                      (local.set $y/is-fx (call $fx?/i32 (local.get $y)))
                      (local.set $y/is-big (ref.test (ref $Bignum) (local.get $y)))
                      (local.set $y/is-fl (ref.test (ref $Flonum) (local.get $y)))
                      (if (i32.eqz
                           (i32.or
                            (i32.or (local.get $y/is-fx) (local.get $y/is-big))
                            (local.get $y/is-fl)))
                          (then (call $raise-expected-real
                                      (global.get ,$who)
                                      (local.get $y))
                                (unreachable)))

                      (if (i32.and (local.get $x/is-fx) (local.get $y/is-fx))
                          (then (return (call ,fxop (local.get $x) (local.get $y)))))

                      (if (i32.and
                           (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                           (i32.or (local.get $y/is-fx) (local.get $y/is-big)))
                          (then
                           (local.set $cmp/i32
                                      (call $integer-compare/i32
                                            (local.get $x)
                                            (local.get $y)))
                           (return
                            (if (result (ref eq))
                                ,exact-x-wins?
                                (then (local.get $x))
                                (else (local.get $y))))))

                      (if (i32.and (local.get $x/is-fl) (local.get $y/is-fl))
                          (then
                           (return
                            (call ,flop
                                  (ref.cast (ref $Flonum) (local.get $x))
                                  (ref.cast (ref $Flonum) (local.get $y))))))

                      (if (i32.and
                           (i32.or (local.get $x/is-fx) (local.get $x/is-big))
                           (local.get $y/is-fl))
                          (then
                           (local.set $cmp/i32
                                      (call $integer-flonum-compare/i32
                                            (local.get $x)
                                            (ref.cast (ref $Flonum) (local.get $y))))
                           (if (i32.eq (local.get $cmp/i32) (i32.const 2))
                               (then (return (local.get $y))))
                           (return
                            (if (result (ref eq))
                                ,exact-x-wins?
                                (then
                                 (struct.new $Flonum
                                             (i32.const 0)
                                             (call $integer->f64 (local.get $x))))
                                (else (local.get $y))))))

                      (if (i32.and
                           (local.get $x/is-fl)
                           (i32.or (local.get $y/is-fx) (local.get $y/is-big)))
                          (then
                           (local.set $cmp/i32
                                      (call $integer-flonum-compare/i32
                                            (local.get $y)
                                            (ref.cast (ref $Flonum) (local.get $x))))
                           (if (i32.eq (local.get $cmp/i32) (i32.const 2))
                               (then (return (local.get $x))))
                           (return
                            (if (result (ref eq))
                                ,fl-exact-x-wins?
                                (then (local.get $x))
                                (else
                                 (struct.new $Flonum
                                             (i32.const 0)
                                             (call $integer->f64 (local.get $y))))))))

                      (unreachable))

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


;; generic-bitwise-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic bitwise helpers.
(define generic-bitwise-runtime-only-helper-names
  '($bitwise-and/2
    $bitwise-and
    $bitwise-ior/2
    $bitwise-ior
    $bitwise-xor/2
    $bitwise-xor
    $bitwise-not
    $bitwise-bit-set?
    $bitwise-first-bit-set
    $bitwise-bit-field
    $arithmetic-shift
    $integer-length))

;; generic-bitwise-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic bitwise helpers that still depend on monolithic runtime globals.
(define generic-bitwise-runtime-only-helpers
  (function-forms->runtime-helpers
   'generic-bitwise-runtime-only-helpers
   `(
        ,@(let ()
            (define (gen-bitop name integer-op)
              (define $name/2 (string->symbol (~a "$" name "/2")))
              (define $name   (string->symbol (~a "$" name)))
              (define $who    (string->symbol (~a "$symbol:" name)))
              `((func ,$name/2 (type $Prim2)
                      (param $x (ref eq)) (param $y (ref eq)) (result (ref eq))
                      (if (ref.eq (call $exact-integer? (local.get $x)) (global.get $false))
                          (then (call $raise-expected-exact-integer
                                      (global.get ,$who)
                                      (local.get $x))
                                (unreachable)))
                      (if (ref.eq (call $exact-integer? (local.get $y)) (global.get $false))
                          (then (call $raise-expected-exact-integer
                                      (global.get ,$who)
                                      (local.get $y))
                                (unreachable)))
                      (call ,integer-op (local.get $x) (local.get $y)))
                (func ,$name (type $Prim>=1)
                      (param $x0 (ref eq)) (param $xs0 (ref eq)) (result (ref eq))
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
                      (if (ref.eq (call $exact-integer? (local.get $x0)) (global.get $false))
                          (then (call $raise-expected-exact-integer
                                      (global.get ,$who)
                                      (local.get $x0))
                                (unreachable)))
                      (local.set $r (local.get $x0))
                      (block $done
                             (loop $loop
                                   (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                                   (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                                   (local.set $v    (struct.get $Pair $a (local.get $node)))
                                   (local.set $r    (call ,$name/2 (local.get $r) (local.get $v)))
                                   (local.set $xs   (struct.get $Pair $d (local.get $node)))
                                   (br $loop)))
                      (local.get $r))))
            (append (gen-bitop 'bitwise-and '$integer-bitwise-and/2)
                    (gen-bitop 'bitwise-ior '$integer-bitwise-ior/2)
                    (gen-bitop 'bitwise-xor '$integer-bitwise-xor/2)))


        (func $bitwise-not (type $Prim1)
              (param $x (ref eq))
              (result   (ref eq))

              ;; --- Validate $x ---
              (if (ref.eq (call $exact-integer? (local.get $x)) (global.get $false))
                  (then (call $raise-expected-exact-integer
                              (global.get $symbol:bitwise-not)
                              (local.get $x))
                        (unreachable)))
              ;; Infinite two's-complement identity: (bitwise-not n) = -1 - n.
              (call $integer-sub/2 ,(Imm -1) (local.get $x)))

        (func $bitwise-bit-set? (type $Prim2)
              (param $n (ref eq))
              (param $m (ref eq))
              (result   (ref eq))

              (local $n/fx i32)   ; raw bits of n
              (local $m/fx i32)   ; raw bits of m
              (local $n/i  i32)   ; unboxed signed n
              (local $m/i  i32)   ; unboxed unsigned m
              (local $m/big? i32)
              (local $bn   (ref $Bignum))
              (local $limbs (ref $I32Array))
              (local $limb-index i32)
              (local $bit-index  i32)

              ;; --- Validate $n and $m ---
              (if (ref.eq (call $exact-integer? (local.get $n)) (global.get $false))
                  (then (call $raise-expected-exact-integer
                              (global.get $symbol:bitwise-bit-set?)
                              (local.get $n))
                        (unreachable)))
              (if (ref.eq (call $exact-nonnegative-integer? (local.get $m)) (global.get $false))
                  (then (call $raise-expected-exact-nonnegative-integer
                              (global.get $symbol:bitwise-bit-set?)
                              (local.get $m))
                        (unreachable)))

              ;; --- Decode bit index ---
              (local.set $m/big? (ref.test (ref $Bignum) (local.get $m)))
              (if (local.get $m/big?)
                  (then
                   (if (i32.eqz (call $integer-single-limb?/i32 (local.get $m)))
                       (then
                        (if (i32.lt_s (call $integer-sign/i32 (local.get $n))
                                      (i32.const 0))
                            (then (return (global.get $true)))
                            (else (return (global.get $false))))))
                   (local.set $m/i (call $integer-abs-u32 (local.get $m))))
                  (else
                   (local.set $m/fx (i31.get_u (ref.cast (ref i31) (local.get $m))))
                   (local.set $m/i  (i32.shr_u (local.get $m/fx) (i32.const 1)))))

              ;; --- Fixnum n case ---
              (if (ref.test (ref i31) (local.get $n))
                  (then
                   (local.set $n/fx (i31.get_u (ref.cast (ref i31) (local.get $n))))
                   (local.set $n/i  (i32.shr_s (local.get $n/fx) (i32.const 1)))
                   (return
                    (if (result (ref eq)) (i32.ge_u (local.get $m/i) (i32.const 30))
                        (then (if (result (ref eq)) (i32.lt_s (local.get $n/i) (i32.const 0))
                                  (then (global.get $true))
                                  (else (global.get $false))))
                        (else (if (result (ref eq))
                                  (i32.eqz (i32.and (local.get $n/i)
                                                     (i32.shl (i32.const 1) (local.get $m/i))))
                                  (then (global.get $false))
                                  (else (global.get $true))))))))

              ;; --- Negative bignum n case ---
              (if (i32.lt_s (call $integer-sign/i32 (local.get $n))
                            (i32.const 0))
                  (then
                   (return
                    (if (result (ref eq))
                        (ref.eq
                         (call $bitwise-bit-set?
                               (call $bitwise-not (local.get $n))
                               (local.get $m))
                         (global.get $true))
                        (then (global.get $false))
                        (else (global.get $true))))))

              ;; --- Positive bignum n case ---
              (local.set $bn (ref.cast (ref $Bignum) (local.get $n)))
              (local.set $limbs (struct.get $Bignum $limbs (local.get $bn)))
              (local.set $limb-index (i32.shr_u (local.get $m/i) (i32.const 5)))
              (if (i32.ge_u (local.get $limb-index)
                            (array.len (local.get $limbs)))
                  (then (return (global.get $false))))
              (local.set $bit-index (i32.and (local.get $m/i) (i32.const 31)))
              (if (result (ref eq))
                  (i32.eqz
                   (i32.and
                    (array.get $I32Array
                               (local.get $limbs)
                               (local.get $limb-index))
                    (i32.shl (i32.const 1) (local.get $bit-index))))
                  (then (global.get $false))
                  (else (global.get $true))))

        (func $bitwise-first-bit-set (type $Prim1)
              (param $n (ref eq))
              (result   (ref eq))

              (local $n/fx i32)
              (local $n/i  i32)
              (local $bn   (ref $Bignum))
              (local $limbs (ref $I32Array))
              (local $i    i32)
              (local $limb i32)
              (local $pos  i64)

              ;; --- Validate $n ---
              (if (ref.eq (call $exact-integer? (local.get $n)) (global.get $false))
                  (then (call $raise-expected-exact-integer
                              (global.get $symbol:bitwise-first-bit-set)
                              (local.get $n))
                        (unreachable)))

              ;; --- Fixnum case ---
              (if (ref.test (ref i31) (local.get $n))
                  (then
                   (local.set $n/fx (i31.get_u (ref.cast (ref i31) (local.get $n))))
                   (local.set $n/i  (i32.shr_s (local.get $n/fx) (i32.const 1)))
                   (return
                    (if (result (ref eq))
                        (i32.eqz (local.get $n/i))
                        (then (ref.i31 (i32.const -2)))
                        (else (ref.i31 (i32.shl (i32.ctz (local.get $n/i))
                                                (i32.const 1))))))))

              ;; --- Bignum case ---
              (local.set $bn (ref.cast (ref $Bignum) (local.get $n)))
              (local.set $limbs (struct.get $Bignum $limbs (local.get $bn)))
              (loop $loop
                    (local.set $limb
                               (array.get $I32Array
                                          (local.get $limbs)
                                          (local.get $i)))
                    (if (i32.ne (local.get $limb) (i32.const 0))
                        (then
                         (local.set $pos
                                    (i64.add
                                     (i64.mul
                                      (i64.extend_i32_u (local.get $i))
                                      (i64.const 32))
                                     (i64.extend_i32_u
                                      (i32.ctz (local.get $limb)))))
                         (return (call $integer-from-i64
                                       (local.get $pos)))))
                    (local.set $i (i32.add (local.get $i) (i32.const 1)))
                    (br $loop))
              (unreachable))


        ;; NOTE: Only supports fixnum arguments; start/end must be
        ;; non-negative fixnums and `end` must be >= `start`.
        (func $bitwise-bit-field (type $Prim3)
              (param $n     (ref eq))
              (param $start (ref eq))
              (param $end   (ref eq))
              (result       (ref eq))

              (local $n/fx     i32)
              (local $start/fx i32)
              (local $end/fx   i32)
              (local $n/i      i32)
              (local $start/i  i32)
              (local $end/i    i32)
              (local $width    i32)
              (local $mask     i32)
              (local $shifted  i32)

              ;; --- Validate inputs ---
              (if (ref.eq (call $exact-integer? (local.get $n)) (global.get $false))
                  (then (call $raise-expected-exact-integer
                              (global.get $symbol:bitwise-bit-field)
                              (local.get $n))
                        (unreachable)))
              (if (ref.eq (call $exact-nonnegative-integer? (local.get $start)) (global.get $false))
                  (then (call $raise-expected-exact-nonnegative-integer
                              (global.get $symbol:bitwise-bit-field)
                              (local.get $start))
                        (unreachable)))
              (if (ref.eq (call $exact-nonnegative-integer? (local.get $end)) (global.get $false))
                  (then (call $raise-expected-exact-nonnegative-integer
                              (global.get $symbol:bitwise-bit-field)
                              (local.get $end))
                        (unreachable)))

              ;; --- Extract values ---
              (local.set $n/fx     (i31.get_s (ref.cast (ref i31) (local.get $n))))
              (local.set $start/fx (i31.get_s (ref.cast (ref i31) (local.get $start))))
              (local.set $end/fx   (i31.get_s (ref.cast (ref i31) (local.get $end))))
              (local.set $n/i      (i32.shr_s (local.get $n/fx) (i32.const 1)))
              (local.set $start/i  (i32.shr_s (local.get $start/fx) (i32.const 1)))
              (local.set $end/i    (i32.shr_s (local.get $end/fx) (i32.const 1)))

              (if (i32.lt_s (local.get $end/i) (local.get $start/i))
                  (then (call $raise-arguments-error
                              (global.get $symbol:bitwise-bit-field)
                              (global.get $string:bitwise-bit-field:end-before-start)
                              (array.new_fixed $Args 0))
                        (unreachable)))

              ;; --- Compute width and mask ---
              (local.set $width (i32.sub (local.get $end/i) (local.get $start/i)))
              (local.set $mask
                        (if (result i32) (i32.ge_u (local.get $width) (i32.const 30))
                            (then (i32.const -1))
                            (else (i32.sub (i32.shl (i32.const 1) (local.get $width))
                                           (i32.const 1)))))

              ;; --- Shift and mask ---
              (local.set $shifted (i32.shr_s (local.get $n/i) (local.get $start/i)))
              (ref.i31 (i32.shl (i32.and (local.get $shifted) (local.get $mask))
                                 (i32.const 1))))


        (func $arithmetic-shift (type $Prim2)
              (param $n (ref eq)) ; exact-integer
              (param $m (ref eq)) ; exact-integer
              (result   (ref eq)) ; exact-integer

              (local $m/fx i32)   ; raw bits of m
              (local $m/i  i32)   ; unboxed signed m
              (local $shift i32)
              (local $pow   (ref eq))
              (local $vals  (ref $Values))
              (local $q     (ref eq))
              (local $comp  (ref eq))

              ;; --- Validate inputs ---
              (if (ref.eq (call $exact-integer? (local.get $n)) (global.get $false))
                  (then (call $raise-expected-exact-integer
                              (global.get $symbol:arithmetic-shift)
                              (local.get $n))
                        (unreachable)))
              (if (ref.eq (call $exact-integer? (local.get $m)) (global.get $false))
                  (then (call $raise-expected-exact-integer
                              (global.get $symbol:arithmetic-shift)
                              (local.get $m))
                        (unreachable)))

              (if (ref.test (ref $Bignum) (local.get $m))
                  (then
                   (if (i32.lt_s (call $integer-sign/i32 (local.get $m))
                                 (i32.const 0))
                       (then
                        (if (i32.lt_s (call $integer-sign/i32 (local.get $n))
                                      (i32.const 0))
                            (then (return ,(Imm -1)))
                            (else (return ,(Imm 0))))))
                   (call $raise-expected-fixnum (local.get $m))
                   (unreachable)))

              (local.set $m/fx (i31.get_s (ref.cast (ref i31) (local.get $m))))
              (local.set $m/i  (i32.shr_s (local.get $m/fx) (i32.const 1)))

              (if (i32.eqz (local.get $m/i))
                  (then (return (local.get $n))))
              (if (i32.gt_s (local.get $m/i) (i32.const 0))
                  (then
                   (local.set $pow
                              (call $u64-shl->integer
                                    (i64.const 1)
                                    (local.get $m/i)))
                   (return (call $integer-mul/2
                                 (local.get $n)
                                 (local.get $pow)))))

              (local.set $shift (i32.sub (i32.const 0) (local.get $m/i)))
              (local.set $pow
                         (call $u64-shl->integer
                               (i64.const 1)
                               (local.get $shift)))
              (if (i32.lt_s (call $integer-sign/i32 (local.get $n))
                            (i32.const 0))
                  (then
                   (local.set $comp
                              (call $integer-sub/2
                                    ,(Imm -1)
                                    (local.get $n)))
                   (local.set $vals
                              (call $integer-divmod
                                    (local.get $comp)
                                    (local.get $pow)))
                   (local.set $q
                              (array.get $Values
                                         (local.get $vals)
                                         (i32.const 0)))
                   (return
                    (call $integer-sub/2
                          ,(Imm -1)
                          (local.get $q)))))
              (local.set $vals
                         (call $integer-divmod
                               (local.get $n)
                               (local.get $pow)))
              (array.get $Values
                         (local.get $vals)
                         (i32.const 0)))


        (func $integer-length (type $Prim1)
              (param $n (ref eq))
              (result (ref eq))

              (local $bits i32)
              (local $n/fx i32)
              (local $len i32)
              (local $bn (ref $Bignum))
              (local $limbs (ref $I32Array))
              (local $top i32)
              (local $len64 i64)
              (local $pos (ref eq))

              ;; Validate: must be an exact integer; otherwise raise.
              (if (ref.eq (call $exact-integer? (local.get $n)) (global.get $false))
                  (then (call $raise-expected-exact-integer
                              (global.get $symbol:integer-length)
                              (local.get $n))
                        (unreachable)))
              (if (result (ref eq))
                  (ref.test (ref i31) (local.get $n))
                  (then
                   (local.set $bits (i31.get_u (ref.cast (ref i31) (local.get $n))))
                   (if (result (ref eq))
                       (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                       (then
                        ;; Extract unboxed signed i32 from fixnum: (bits << 1) >> 2.
                        (local.set $n/fx
                                   (i32.shr_s
                                    (i32.shl (local.get $bits) (i32.const 1))
                                    (i32.const 2)))
                        ;; Compute integer-length per Racket’s definition.
                        (if (result (ref eq))
                            (i32.ge_s (local.get $n/fx) (i32.const 0))
                            (then
                             (if (result (ref eq))
                                 (i32.eqz (local.get $n/fx))
                                 (then
                                  (ref.i31 (i32.const 0)))
                                 (else
                                  (local.set $len
                                             (i32.sub
                                              (i32.const 32)
                                              (i32.clz (local.get $n/fx))))
                                  (ref.i31 (i32.shl (local.get $len) (i32.const 1))))))
                            (else
                             ;; For negatives, use bit-length of (~n).
                             (local.set $len
                                        (i32.sub
                                         (i32.const 32)
                                         (i32.clz
                                          (i32.xor (local.get $n/fx) (i32.const -1)))))
                             (ref.i31 (i32.shl (local.get $len) (i32.const 1))))))
                       (else
                        ;; This branch is unreachable after $exact-integer? validation.
                        (unreachable))))
                  (else
                   (local.set $bn (ref.cast (ref $Bignum) (local.get $n)))
                   (if (i32.lt_s (struct.get $Bignum $sign (local.get $bn))
                                 (i32.const 0))
                       (then
                        (local.set $pos
                                   (call $integer-negate
                                         (call $integer-add/2
                                               (local.get $n)
                                               (global.get $one))))
                        (return (call $integer-length (local.get $pos)))))
                   (local.set $limbs (struct.get $Bignum $limbs
                                                 (local.get $bn)))
                   (local.set $len (array.len (local.get $limbs)))
                   (local.set $top
                              (array.get $I32Array
                                         (local.get $limbs)
                                         (i32.sub (local.get $len) (i32.const 1))))
                   (local.set $len64
                              (i64.add
                               (i64.mul
                                (i64.extend_i32_u
                                 (i32.sub (local.get $len) (i32.const 1)))
                                (i64.const 32))
                               (i64.extend_i32_u
                                (i32.sub
                                 (i32.const 32)
                                 (i32.clz (local.get $top))))))
                   (call $integer-from-i64 (local.get $len64)))))




     )))

;; number-string-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate number/string conversion helpers used by the monolithic runtime.
(define number-string-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'number-string-conversion-runtime-only-helpers
   '(
     ;;; Helpers for $number->string

     (func $raise-number->string-bad-input (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:number->string)
                 (global.get $string:number?)
                 (local.get $bad))
           (unreachable))
     (func $raise-number->string-bad-radix (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:number->string)
                 (global.get $string:number->string:radix)
                 (local.get $bad))
           (unreachable))

     (func $number->string:check-radix (param $radix i32) (result i32)
           ; number->string accepts 2, 8, 10, or 16 as radix
           (if (result i32) (i32.or (i32.eq (local.get $radix) (i32.const 2))
                (i32.or (i32.eq (local.get $radix) (i32.const 8))
                 (i32.or (i32.eq (local.get $radix) (i32.const 10))
                         (i32.eq (local.get $radix) (i32.const 16)))))
               (then (i32.const 1))
               (else (i32.const 0))))

     (func $number->string:max-length (param $radix i32) (result i32)
           ;; Returns the maximum length of a fixnum when converted to a string
           ;; in the given radix, including the sign character.
           (if (result i32) (i32.eq (local.get $radix) (i32.const 2))
               (then (i32.const 30)) ;; binary: 29 bits + sign
               (else
                (if (result i32) (i32.eq (local.get $radix) (i32.const 8))
                    (then (i32.const 12)) ;; octal: 11 digits + sign
                    (else
                     (if (result i32) (i32.eq (local.get $radix) (i32.const 10))
                         (then (i32.const 11)) ;; decimal: 10 digits + sign
                         (else
                          (if (result i32) (i32.eq (local.get $radix) (i32.const 16))
                              (then (i32.const 9)) ;; hex: 8 digits + sign
                              (else (i32.const 0)) ;; invalid radix, caller should check
                              ))))))))

     (func $number->string:convert
           (param $n       i32)
           (param $radix   i32)
           (param $max-len i32)
           (result         (ref $String))

           (local $buf (ref $I32Array))
           (local $i   i32)
           (local $tmp i32)
           (local $neg i32)
           (local $abs i32)
           (local $out (ref $I32Array))
           (local $len i32)

           ;; Special case for 0
           (if (i32.eqz (local.get $n))
               (then (return (call $i32->string (local.get $n)))))
           ;; Step 1: Determine sign and absolute value
           (local.set $neg (i32.lt_s (local.get $n) (i32.const 0)))
           (local.set $abs (if (result i32)
                               (i32.ge_s (local.get $n) (i32.const 0))
                               (then (local.get $n))
                               (else (i32.sub (i32.const 0) (local.get $n)))))
           ;; Step 2: Create buffer of max-len, and fill from right to left
           (local.set $buf (array.new_default $I32Array (local.get $max-len)))
           (local.set $i   (local.get $max-len))
           (block $done
                  (loop $digit-loop
                        (br_if $done (i32.eqz (local.get $abs)))
                        (local.set $i   (i32.sub (local.get $i) (i32.const 1)))
                        (local.set $tmp (i32.rem_u (local.get $abs) (local.get $radix)))
                        (array.set $I32Array (local.get $buf) (local.get $i)
                                   (select
                                    (i32.add (local.get $tmp) (i32.const 48)) ;; '0'-'9'
                                    (i32.add (local.get $tmp) (i32.const 87)) ;; 'a'-'f'
                                    (i32.lt_u (local.get $tmp) (i32.const 10))))
                        (local.set $abs (i32.div_u (local.get $abs) (local.get $radix)))
                        (br $digit-loop)))
           ;; Step 3: Add minus sign if negative
           (if (local.get $neg)
               (then
                (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                (array.set $I32Array (local.get $buf) (local.get $i) (i32.const 45)))) ;; '-'
           ;; Step 4: Slice from $i to $max-len using array.copy
           (local.set $len (i32.sub (local.get $max-len) (local.get $i)))
           (local.set $out (array.new_default $I32Array (local.get $len)))
           (array.copy $I32Array $I32Array
                       (local.get $out) (i32.const 0)
                       (local.get $buf) (local.get $i)
                       (local.get $len))
           ;; Step 5: Wrap into a String object
           (struct.new $String
                       (i32.const 0)        ;; hash = 0
                       (i32.const 1)        ;; immutable = true
                       (local.get $out)))

     (func $number->string (type $Prim12)
           (param $z         (ref eq))
           (param $radix-raw (ref eq)) ;; optional: 10 or #f
           (result           (ref eq)) ;; An (ref $String)

           (local $radix i32)
           (local $n     i32)
           (local $max   i32)
           (local $i31   (ref i31))
           (local $bits  i32)
           (local $b     (ref $Bignum))
           (local $q     (ref $Rational))
           (local $c     (ref $Complex))
           ;; Treat missing radix as #f to reuse the existing default-radix path.
           (if (ref.eq (local.get $radix-raw) (global.get $missing))
               (then (local.set $radix-raw (global.get $false))))
           ;; Exact bignums support the same radix set as fixnums.
           (if (ref.test (ref $Bignum) (local.get $z))
               (then
                (local.set $b (ref.cast (ref $Bignum) (local.get $z)))
                (if (ref.eq (local.get $radix-raw) (global.get $false))
                    (then (local.set $radix (i32.const 10)))
                    (else
                     (if (i32.eqz (ref.test (ref i31) (local.get $radix-raw)))
                         (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                               (unreachable)))
                     (local.set $i31 (ref.cast (ref i31) (local.get $radix-raw)))
                     (local.set $bits (i31.get_u (local.get $i31)))
                     (if (i32.and (local.get $bits) (i32.const 1))
                         (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                               (unreachable)))
                     (local.set $radix (i32.shr_u (local.get $bits) (i32.const 1)))))
                (if (i32.eqz (call $number->string:check-radix (local.get $radix)))
                    (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                          (unreachable)))
                (return (call $bignum->string (local.get $b) (local.get $radix)))))
           ;; Exact rationals support the same radix set as exact integers.
           (if (ref.test (ref $Rational) (local.get $z))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $z)))
                (if (ref.eq (local.get $radix-raw) (global.get $false))
                    (then (local.set $radix (i32.const 10)))
                    (else
                     (if (i32.eqz (ref.test (ref i31) (local.get $radix-raw)))
                         (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                               (unreachable)))
                     (local.set $i31 (ref.cast (ref i31) (local.get $radix-raw)))
                     (local.set $bits (i31.get_u (local.get $i31)))
                     (if (i32.and (local.get $bits) (i32.const 1))
                         (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                               (unreachable)))
                     (local.set $radix (i32.shr_u (local.get $bits) (i32.const 1)))))
                (if (i32.eqz (call $number->string:check-radix (local.get $radix)))
                    (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                          (unreachable)))
                (return (call $rational->string (local.get $q) (local.get $radix)))))
           ;; Step 1: Check if $z is a fixnum or flonum
           (if (ref.test (ref i31) (local.get $z))
               (then
                (local.set $i31 (ref.cast (ref i31) (local.get $z)))
                (local.set $bits (i31.get_u (local.get $i31)))
                (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                    (then (local.set $n (i32.shr_s (i31.get_s (local.get $i31))
                                                   (i32.const 1))))
                    (else (call $raise-number->string-bad-input (local.get $z))
                          (unreachable))))
               (else
                (if (ref.test (ref $Flonum) (local.get $z))
                    (then
                     ;; Handle optional radix for flonum (must be 10 or #f).
                     (if (ref.eq (local.get $radix-raw) (global.get $false))
                         (then (return (call $flonum->string
                                              (ref.cast (ref $Flonum) (local.get $z)))))
                         (else
                          (if (i32.eqz (ref.test (ref i31) (local.get $radix-raw)))
                              (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                                    (unreachable)))
                          (local.set $i31 (ref.cast (ref i31) (local.get $radix-raw)))
                          (local.set $bits (i31.get_u (local.get $i31)))
                          (if (i32.and (local.get $bits) (i32.const 1))
                              (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                                    (unreachable)))
                          (local.set $radix (i32.shr_u (local.get $bits) (i32.const 1)))
                          (if (i32.eq (local.get $radix) (i32.const 10))
                              (then (return (call $flonum->string
                                                   (ref.cast (ref $Flonum) (local.get $z)))))
                              (else (call $raise-number->string-bad-radix (local.get $radix-raw))
                                    (unreachable))))))
                    (else
                     (if (ref.test (ref $Complex) (local.get $z))
                         (then
                          (local.set $c (ref.cast (ref $Complex) (local.get $z)))
                          (if (ref.eq (local.get $radix-raw) (global.get $false))
                              (then (return (call $format/display:complex (local.get $c))))
                              (else
                               (if (i32.eqz (ref.test (ref i31) (local.get $radix-raw)))
                                   (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                                         (unreachable)))
                               (local.set $i31 (ref.cast (ref i31) (local.get $radix-raw)))
                               (local.set $bits (i31.get_u (local.get $i31)))
                               (if (i32.and (local.get $bits) (i32.const 1))
                                   (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                                         (unreachable)))
                               (local.set $radix (i32.shr_u (local.get $bits) (i32.const 1)))
                               (if (i32.eq (local.get $radix) (i32.const 10))
                                   (then (return (call $format/display:complex (local.get $c))))
                                   (else (call $raise-number->string-bad-radix (local.get $radix-raw))
                                         (unreachable))))))
                         (else (call $raise-number->string-bad-input (local.get $z))
                               (unreachable)))))))
           ;; Step 2: Handle radix for fixnums
           (if (ref.eq (local.get $radix-raw) (global.get $false))
               (then (local.set $radix (i32.const 10)))
               (else
                (if (i32.eqz (ref.test (ref i31) (local.get $radix-raw)))
                    (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                          (unreachable)))
                (local.set $i31 (ref.cast (ref i31) (local.get $radix-raw)))
                (local.set $bits (i31.get_u (local.get $i31)))
                (if (i32.and (local.get $bits) (i32.const 1))
                    (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                          (unreachable)))
                (local.set $radix (i32.shr_u (local.get $bits) (i32.const 1)))))
           ;; Step 3: Validate the radix
           (if (i32.eqz (call $number->string:check-radix (local.get $radix)))
               (then (call $raise-number->string-bad-radix (local.get $radix-raw))
                     (unreachable)))
           ;; Step 4: Get max length for this radix
           (local.set $max (call $number->string:max-length (local.get $radix)))
           ;; Step 5: Convert and return
           (call $number->string:convert (local.get $n) (local.get $radix) (local.get $max))))))

;; string-number-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string/number conversion helpers used by the monolithic runtime.
(define string-number-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-number-conversion-runtime-only-helpers
   '(
     (func $raise-string->number:bad-argument (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:string->number)
                 (global.get $string:string?)
                 (local.get $bad))
           (unreachable))
     (func $raise-string->number:bad-radix (param $bad (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:string->number)
                 (global.get $string:string->number:radix)
                 (local.get $bad))
           (unreachable))

     ;; string->number:parse-fractional-part : string? i32 -> f64 i32
     ;;   Parse decimal digits into an inexact fractional value.
     (func $string->number:parse-fractional-part
           (param $s (ref $String))
           (param $i i32)
           (result f64 i32)

           (local $arr   (ref $I32Array))
           (local $len   i32)
           (local $cp    i32)
           (local $digit i32)
           (local $start i32)
           (local $frac  f64)
           (local $scale f64)

           ;; Cache the source array and remember where the fractional scan began.
           (local.set $arr   (struct.get $String $codepoints (local.get $s)))
           (local.set $len   (call $i32array-length (local.get $arr)))
           (local.set $start (local.get $i))

           ;; Build the fraction from left to right:
           ;;   0.1 * digit1 + 0.01 * digit2 + ...
           (local.set $frac  (f64.const 0.0))
           (local.set $scale (f64.const 0.1))

           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))

                        (local.set $cp
                                   (call $i32array-ref (local.get $arr) (local.get $i)))

                        ;; Stop immediately if the next character is not a decimal digit.
                        (if (i32.or
                             (i32.lt_u (local.get $cp) (i32.const 48))
                             (i32.gt_u (local.get $cp) (i32.const 57)))
                            (then
                             (return
                              (f64.const 0.0)
                              (i32.const 0)))
                            (else (nop)))

                        (local.set $digit
                                   (i32.sub (local.get $cp) (i32.const 48)))

                        ;; Add the next digit at the current decimal place.
                        (local.set $frac
                                   (f64.add
                                    (local.get $frac)
                                    (f64.mul
                                     (f64.convert_i32_s (local.get $digit))
                                     (local.get $scale))))

                        (local.set $scale
                                   (f64.mul (local.get $scale) (f64.const 0.1)))

                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; Return the parsed fraction and the number of consumed characters.
           (return
            (local.get $frac)
            (i32.sub (local.get $i) (local.get $start))))

     (func $string->number:parse-integer
           (param $s     (ref $String))
           (param $i     i32)
           (param $radix i32)
           ;; returns:
           ;;   1. fixnum or #f
           ;;   2. number of parsed characters or 0
           (result       (ref eq) i32)

           (local $arr       (ref $I32Array))
           (local $len       i32)
           (local $cp        i32)
           (local $digit     i32)
           (local $acc       i32)
           (local $start     i32)
           (local $limit-div i32)
           (local $limit-rem i32)

           (local.set $arr   (struct.get $String $codepoints (local.get $s)))
           (local.set $len   (call $i32array-length (local.get $arr)))
           (local.set $start (local.get $i))
           (local.set $acc   (i32.const 0))

           ;; largest non-negative 30-bit fixnum payload
           ;;   = 2^29 - 1 = 536870911
           (local.set $limit-div
                      (i32.div_u (i32.const 536870911) (local.get $radix)))
           (local.set $limit-rem
                      (i32.rem_u (i32.const 536870911) (local.get $radix)))

           (block $overflow (result (ref eq) i32)
                  (block $done
                         (loop $loop
                               (br_if $done
                                      (i32.ge_u (local.get $i) (local.get $len)))

                               (local.set $cp
                                          (call $i32array-ref (local.get $arr) (local.get $i)))

                               ;; Try '0'..'9'
                               (local.set $digit
                                          (i32.sub (local.get $cp) (i32.const 48)))
                               (if (i32.lt_u (local.get $digit) (i32.const 10))
                                   (then (nop))
                                   (else
                                    ;; Try 'a'..'z'
                                    (local.set $digit
                                               (i32.sub (local.get $cp) (i32.const 97)))
                                    (if (i32.lt_u (local.get $digit) (i32.const 26))
                                        (then
                                         (local.set $digit
                                                    (i32.add (local.get $digit) (i32.const 10))))
                                        (else
                                         ;; Try 'A'..'Z'
                                         (local.set $digit
                                                    (i32.sub (local.get $cp) (i32.const 65)))
                                         (if (i32.lt_u (local.get $digit) (i32.const 26))
                                             (then
                                              (local.set $digit
                                                         (i32.add (local.get $digit) (i32.const 10))))
                                             (else
                                              (br $done)))))))

                               (if (i32.ge_u (local.get $digit) (local.get $radix))
                                   (then (br $done))
                                   (else (nop)))

                               ;; Overflow check for:
                               ;;   acc * radix + digit <= 536870911
                               (if (i32.or
                                    (i32.gt_u (local.get $acc) (local.get $limit-div))
                                    (i32.and
                                     (i32.eq (local.get $acc) (local.get $limit-div))
                                     (i32.gt_u (local.get $digit) (local.get $limit-rem))))
                                   (then
                                    (global.get $false)
                                    (i32.const 0)
                                    (br $overflow))
                                   (else (nop)))

                               (local.set $acc
                                          (i32.add
                                           (i32.mul (local.get $acc) (local.get $radix))
                                           (local.get $digit)))
                               (local.set $i
                                          (i32.add (local.get $i) (i32.const 1)))
                               (br $loop)))

                  ;; Normal return
                  (if (result (ref eq) i32)
                      (i32.eq (local.get $i) (local.get $start))
                      (then
                       (global.get $false)
                       (i32.const 0))
                      (else
                       (ref.i31 (i32.shl (local.get $acc) (i32.const 1)))
                       (i32.sub (local.get $i) (local.get $start))))))

     (func $string->number (type $Prim15)
           (param $s-raw        (ref eq))
           (param $radix-raw    (ref eq))
           (param $convert-mode (ref eq))
           (param $decimal-mode (ref eq))
           (param $single-mode  (ref eq))
           (result              (ref eq))

           (local $s        (ref $String))
           (local $radix    i32)
           (local $radix-bits i32)
           (local $arr      (ref $I32Array))
           (local $len      i32)
           (local $i        i32)
           (local $neg      i32)
           (local $cp       i32)
           (local $int      (ref eq))
           (local $n        i32)
           (local $has-int  i32)
           (local $acc      i32)
           (local $frac     f64)
           (local $m        i32)
           (local $res      f64)

           ;; Validate string
           (if (ref.test (ref $String) (local.get $s-raw))
               (then (nop))
               (else
                (call $raise-string->number:bad-argument (local.get $s-raw))
                (unreachable)))
           (local.set $s (ref.cast (ref $String) (local.get $s-raw)))

           ;; Radix
           (if (ref.eq (local.get $radix-raw) (global.get $missing))
               (then (local.set $radix (i32.const 10)))
               (else
                (if (ref.test (ref i31) (local.get $radix-raw))
                    (then
                     (local.set $radix-bits
                                (i31.get_u
                                 (ref.cast (ref i31) (local.get $radix-raw))))
                     (if (i32.and (local.get $radix-bits) (i32.const 1))
                         (then
                          (call $raise-string->number:bad-radix (local.get $radix-raw))
                          (unreachable)))
                     (local.set $radix
                                (i32.shr_u (local.get $radix-bits) (i32.const 1))))
                    (else
                     (call $raise-string->number:bad-radix (local.get $radix-raw))
                     (unreachable)))))

           (if (i32.or
                (i32.lt_u (local.get $radix) (i32.const 2))
               (i32.gt_u (local.get $radix) (i32.const 16)))
               (then
                (call $raise-string->number:bad-radix (local.get $radix-raw))
                (unreachable))
               (else (nop)))

           ;; String data
           (local.set $arr (struct.get $String $codepoints (local.get $s)))
           (local.set $len (call $i32array-length (local.get $arr)))

           (if (i32.eqz (local.get $len))
               (then (return (global.get $false)))
               (else (nop)))

           ;; Sign
           (local.set $i   (i32.const 0))
           (local.set $neg (i32.const 0))

           (local.set $cp (call $i32array-ref (local.get $arr) (i32.const 0)))
           (if (i32.eq (local.get $cp) (i32.const 45))
               (then
                (local.set $neg (i32.const 1))
                (local.set $i   (i32.const 1)))
               (else
                (if (i32.eq (local.get $cp) (i32.const 43))
                    (then (local.set $i (i32.const 1)))
                    (else (nop)))))

           ;; Cannot be only sign
           (if (i32.eq (local.get $i) (local.get $len))
               (then (return (global.get $false)))
               (else (nop)))

           ;; Parse integer
           (call $string->number:parse-integer
                 (local.get $s)
                 (local.get $i)
                 (local.get $radix))
           (local.set $n)
           (local.set $int)
           (if (ref.eq (local.get $int) (global.get $false))
               (then (local.set $has-int (i32.const 0)))
               (else (local.set $has-int (i32.const 1))))

           ;; Handle ".1" case
           (if (ref.eq (local.get $int) (global.get $false))
               (then
                (if (i32.eq (local.get $i) (local.get $len))
                    (then (return (global.get $false)))
                    (else
                     (local.set $cp
                                (call $i32array-ref (local.get $arr) (local.get $i)))
                     (if (i32.eq (local.get $cp) (i32.const 46))
                         (then
                          (local.set $int (ref.i31 (i32.const 0)))
                          (local.set $n   (i32.const 0)))
                         (else
                          (return (global.get $false)))))))
               (else (nop)))

           (local.set $i (i32.add (local.get $i) (local.get $n)))

           ;; No fractional part → return fixnum
           (if (i32.eq (local.get $i) (local.get $len))
               (then
                (local.set $acc
                           (i32.shr_u
                            (i31.get_u (ref.cast (ref i31) (local.get $int)))
                            (i32.const 1)))
                (if (local.get $neg)
                    (then
                     (local.set $acc
                                (i32.sub (i32.const 0) (local.get $acc))))
                    (else (nop)))
                (return
                 (ref.i31 (i32.shl (local.get $acc) (i32.const 1)))))
               (else (nop)))

           ;; Must be '.'
           (local.set $cp (call $i32array-ref (local.get $arr) (local.get $i)))
           (if (i32.ne (local.get $cp) (i32.const 46))
               (then (return (global.get $false)))
               (else (nop)))

           ;; Only decimal radix
           (if (i32.ne (local.get $radix) (i32.const 10))
               (then (return (global.get $false)))
               (else (nop)))

           ;; Convert integer part
           (local.set $acc
                      (i32.shr_u
                       (i31.get_u (ref.cast (ref i31) (local.get $int)))
                       (i32.const 1)))

           ;; Skip '.'
           (local.set $i (i32.add (local.get $i) (i32.const 1)))

           ;; Parse fractional digits
           (call $string->number:parse-fractional-part
                 (local.get $s)
                 (local.get $i))
           (local.set $m)
           (local.set $frac)

           ;; A bare decimal point is not a number.
           (if (i32.and
                (i32.eqz (local.get $has-int))
                (i32.eqz (local.get $m)))
               (then (return (global.get $false)))
               (else (nop)))

           ;; Must consume entire string
           (local.set $i (i32.add (local.get $i) (local.get $m)))

           (if (i32.ne (local.get $i) (local.get $len))
               (then (return (global.get $false)))
               (else (nop)))

           (local.set $res
                      (f64.add
                       (f64.convert_i32_s (local.get $acc))
                       (local.get $frac)))

           (if (local.get $neg)
               (then (local.set $res (f64.neg (local.get $res))))
               (else (nop)))

           (struct.new $Flonum
                       (i32.const 0)
                       (local.get $res))))))

;; floating-point-byte-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate floating-point byte conversion helpers used by the monolithic runtime.
(define floating-point-byte-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'floating-point-byte-conversion-runtime-only-helpers
   '(
     (func $raise-real->floating-point-bytes:bad-size
           (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:real->floating-point-bytes)
                 (global.get $string:real->floating-point-bytes:size)
                 (local.get $x)))

     (func $raise-real->floating-point-bytes:bad-start
           (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:real->floating-point-bytes)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $x)))

     (func $raise-real->floating-point-bytes:short-dest
           (param $len   i32)
           (param $start i32)
           (param $size  i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 8)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (global.get $symbol:real->floating-point-bytes)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:real->floating-point-bytes:short-dest))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:real->floating-point-bytes:byte-string-length))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:real->floating-point-bytes:starting-position))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $start) (i32.const 1)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:real->floating-point-bytes:size-line))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $size) (i32.const 1)))))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))

           (call $raise
                 (call $exn:fail:contract/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $raise-floating-point-bytes->real:bad-bytes
           (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:floating-point-bytes->real)
                 (global.get $string:bytes?)
                 (local.get $x)))

     (func $raise-floating-point-bytes->real:bad-index
           (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:floating-point-bytes->real)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $x)))

     (func $raise-floating-point-bytes->real:bad-range
           (param $bstr (ref eq))
           (param $from i32)
           (param $to   i32)

           (local $bs      (ref $Bytes))
           (local $len     i32)
           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $bs  (ref.cast (ref $Bytes) (local.get $bstr)))
           (local.set $len (call $i8array-length
                                 (struct.get $Bytes $bs (local.get $bs))))

           (if (i32.gt_u (local.get $from) (local.get $len))
               (then
                (local.set $out (call $make-growable-array (i32.const 9)))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (global.get $symbol:floating-point-bytes->real)))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:substring:starting-index-out-of-range))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:substring:starting-index))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (ref.i31 (i32.shl (local.get $from) (i32.const 1)))))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:string-ref:valid-range))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:string-ref:valid-range-close))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:floating-point-bytes->real:index-line))
                (call $growable-array-add! (local.get $out)
                      (call $format/error-value->string (local.get $bstr)))
                (local.set $message
                           (call $growable-array-of-strings->string (local.get $out)))
                (call $raise
                      (call $exn:fail:contract/make
                            (local.get $message)
                            (call $current-continuation-marks (global.get $missing)))
                      (global.get $true))
                (unreachable)))

           (if (i32.gt_u (local.get $to) (local.get $len))
               (then
                (local.set $out (call $make-growable-array (i32.const 9)))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (global.get $symbol:floating-point-bytes->real)))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:substring:ending-index-out-of-range))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:substring:ending-index))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (ref.i31 (i32.shl (local.get $to) (i32.const 1)))))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:string-ref:valid-range))
                (call $growable-array-add! (local.get $out)
                      (call $format/display
                            (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:string-ref:valid-range-close))
                (call $growable-array-add! (local.get $out)
                      (global.get $string:floating-point-bytes->real:index-line))
                (call $growable-array-add! (local.get $out)
                      (call $format/error-value->string (local.get $bstr)))
                (local.set $message
                           (call $growable-array-of-strings->string (local.get $out)))
                (call $raise
                      (call $exn:fail:contract/make
                            (local.get $message)
                            (call $current-continuation-marks (global.get $missing)))
                      (global.get $true))
                (unreachable)))

           (local.set $out (call $make-growable-array (i32.const 11)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (global.get $symbol:floating-point-bytes->real)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:substring:ending-index-before-start))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:substring:ending-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $to) (i32.const 1)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:substring:starting-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $from) (i32.const 1)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-ref:valid-range))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-ref:valid-range-close))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:floating-point-bytes->real:index-line))
           (call $growable-array-add! (local.get $out)
                 (call $format/error-value->string (local.get $bstr)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (call $raise
                 (call $exn:fail:contract/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $raise-floating-point-bytes->real:bad-length
           (param $len i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 4)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (global.get $symbol:floating-point-bytes->real)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:floating-point-bytes->real:length-not-4-or-8))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:floating-point-bytes->real:length-line))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (call $raise
                 (call $exn:fail:contract/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $floating-point-bytes->real (type $Prim4)
           (param $bstr  (ref eq)) ; bytes?
           (param $big?  (ref eq)) ; any, default to (system-big-endian?) which is #f
           (param $start (ref eq)) ; exact-non-negative-integer, defaults to 0
           (param $end   (ref eq)) ; exact-nonnegative-integer?, defaults to (bytes-length bstr)
           (result       (ref eq))

           (local $bs      (ref null $Bytes))
           (local $arr     (ref $I8Array))
           (local $from    i32)
           (local $to      i32)
           (local $len     i32)
           (local $nbytes  i32)
           (local $big-i32 i32)
           (local $i       i32)
           (local $idx     i32)
           (local $byte    i32)
           (local $val     i64)

           ;; --- Validate byte string ---
           (if (ref.test (ref $Bytes) (local.get $bstr))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
               (else (call $raise-floating-point-bytes->real:bad-bytes
                           (local.get $bstr))
                     (unreachable)))

           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (local.set $len (call $i8array-length (local.get $arr)))

           ;; --- Decode start ---
           (if (ref.eq (local.get $start) (global.get $missing))
               (then (local.set $from (i32.const 0)))
               (else (if (ref.test (ref i31) (local.get $start))
                         (then (local.set $from (i31.get_s (ref.cast (ref i31) (local.get $start))))
                               (if (i32.eqz (i32.and (local.get $from) (i32.const 1)))
                                   (then (local.set $from (i32.shr_s (local.get $from) (i32.const 1))))
                                   (else (call $raise-floating-point-bytes->real:bad-index
                                               (local.get $start))
                                         (unreachable)))
                               (if (i32.lt_s (local.get $from) (i32.const 0))
                                   (then (call $raise-floating-point-bytes->real:bad-index
                                               (local.get $start))
                                         (unreachable))))
                         (else (call $raise-floating-point-bytes->real:bad-index
                                     (local.get $start))
                               (unreachable)))))

           ;; --- Decode end ---
           (if (ref.eq (local.get $end) (global.get $missing))
               (then (local.set $to (local.get $len)))
               (else (if (ref.test (ref i31) (local.get $end))
                         (then (local.set $to (i31.get_s (ref.cast (ref i31) (local.get $end))))
                               (if (i32.eqz (i32.and (local.get $to) (i32.const 1)))
                                   (then (local.set $to (i32.shr_s (local.get $to) (i32.const 1))))
                                   (else (call $raise-floating-point-bytes->real:bad-index
                                               (local.get $end))
                                         (unreachable)))
                               (if (i32.lt_s (local.get $to) (i32.const 0))
                                   (then (call $raise-floating-point-bytes->real:bad-index
                                               (local.get $end))
                                         (unreachable))))
                         (else (call $raise-floating-point-bytes->real:bad-index
                                     (local.get $end))
                               (unreachable)))))

           ;; --- Bounds check ---
           (if (i32.gt_u (local.get $from) (local.get $len))
               (then (call $raise-floating-point-bytes->real:bad-range
                           (local.get $bstr)
                           (local.get $from)
                           (local.get $to))
                     (unreachable)))
           (if (i32.gt_u (local.get $to) (local.get $len))
               (then (call $raise-floating-point-bytes->real:bad-range
                           (local.get $bstr)
                           (local.get $from)
                           (local.get $to))
                     (unreachable)))
           (if (i32.gt_u (local.get $from) (local.get $to))
               (then (call $raise-floating-point-bytes->real:bad-range
                           (local.get $bstr)
                           (local.get $from)
                           (local.get $to))
                     (unreachable)))

           (local.set $nbytes (i32.sub (local.get $to) (local.get $from)))
           (if (i32.and (i32.ne (local.get $nbytes) (i32.const 4))
                        (i32.ne (local.get $nbytes) (i32.const 8)))
               (then (call $raise-floating-point-bytes->real:bad-length
                           (local.get $nbytes))
                     (unreachable)))

           ;; --- Decode big-endian? ---
           (if (ref.eq (local.get $big?) (global.get $missing))
               (then (local.set $big-i32 (i32.const 0)))
               (else (if (ref.eq (local.get $big?) (global.get $false))
                         (then (local.set $big-i32 (i32.const 0)))
                         (else (local.set $big-i32 (i32.const 1))))))

           ;; --- Accumulate bytes into i64 ---
           (local.set $val (i64.const 0))
           (local.set $i (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $nbytes)))
                        (if (i32.eqz (local.get $big-i32))
                            (then (local.set $idx (i32.add (local.get $from) (local.get $i))))
                            (else (local.set $idx
                                               (i32.add (local.get $from)
                                                        (i32.sub
                                                         (i32.add (local.get $nbytes) (i32.const -1))
                                                         (local.get $i))))))
                        (local.set $byte (call $i8array-ref (local.get $arr) (local.get $idx)))
                        (local.set $val
                                   (i64.or
                                    (local.get $val)
                                    (i64.shl (i64.extend_i32_u (local.get $byte))
                                             (i64.extend_i32_u (i32.shl (local.get $i) (i32.const 3))))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; --- Produce result ---
           (if (i32.eq (local.get $nbytes) (i32.const 4))
               (then (return (struct.new $Flonum
                                          (i32.const 0)
                                          (f64.promote_f32
                                           (f32.reinterpret_i32
                                            (i32.wrap_i64 (local.get $val)))))))
               (else (return (struct.new $Flonum
                                          (i32.const 0)
                                          (f64.reinterpret_i64 (local.get $val))))))
           (unreachable))

     ;; real->floating-point-bytes
     ;; Convert a real number to its IEEE floating-point byte representation.
     ;; Exact values are rounded to an f64 before the selected byte width is
     ;; written. The start argument defaults to 0 when omitted, and a provided
     ;; destination must be a mutable byte string of sufficient length. The
     ;; big-endian? argument defaults to #f.
     (func $real->floating-point-bytes (type $Prim25)
           (param $x         (ref eq))  ; real?
           (param $size-raw  (ref eq))  ; (or/c 4 8)
           (param $big-raw   (ref eq))  ; any/c, defaults to (system-big-endian?) = #f
           (param $dest-raw  (ref eq))  ; (and/c bytes? (not/c immutable?))
           (param $start-raw (ref eq))  ; exact-nonnegative-integer? = 0
           (result           (ref eq))

           (local $size   i32)
           (local $big    i32)
           (local $dest   (ref $Bytes))
           (local $arr    (ref $I8Array))
           (local $fl     (ref $Flonum))
           (local $val    f64)
           (local $bits   i32)
           (local $start  i32)
           (local $dest-len i32)

           ;; --- Decode and validate size ---
           (if (i32.eqz (ref.test (ref i31) (local.get $size-raw)))
               (then (call $raise-real->floating-point-bytes:bad-size
                           (local.get $size-raw))
                     (unreachable)))
           (local.set $size (i31.get_u (ref.cast (ref i31) (local.get $size-raw))))
           (if (i32.and (local.get $size) (i32.const 1))
               (then (call $raise-real->floating-point-bytes:bad-size
                           (local.get $size-raw))
                     (unreachable)))
           (local.set $size (i32.shr_u (local.get $size) (i32.const 1)))
           (if (i32.and (i32.ne (local.get $size) (i32.const 4))
                        (i32.ne (local.get $size) (i32.const 8)))
               (then (call $raise-real->floating-point-bytes:bad-size
                           (local.get $size-raw))
                     (unreachable)))

           ;; --- Decode and validate start (exact-nonnegative-integer?, defaults to 0) ---
           (local.set $start (i32.const 0))
           (if (ref.eq (local.get $start-raw) (global.get $missing))
               (then)
               (else
                (if (i32.eqz (ref.test (ref i31) (local.get $start-raw)))
                    (then (call $raise-real->floating-point-bytes:bad-start
                                (local.get $start-raw))
                          (unreachable)))
                (local.set $start (i31.get_s (ref.cast (ref i31) (local.get $start-raw))))
                (if (i32.and (local.get $start) (i32.const 1))
                    (then (call $raise-real->floating-point-bytes:bad-start
                                (local.get $start-raw))
                          (unreachable)))
                (local.set $start (i32.shr_s (local.get $start) (i32.const 1)))
                (if (i32.lt_s (local.get $start) (i32.const 0))
                    (then (call $raise-real->floating-point-bytes:bad-start
                                (local.get $start-raw))
                          (unreachable)))))

           ;; --- Allocate or validate destination ---
           (if (ref.eq (local.get $dest-raw) (global.get $missing))
               (then (local.set $dest-raw
                                (call $make-bytes (local.get $size-raw) (global.get $missing)))))

           (if (i32.eqz (ref.test (ref $Bytes) (local.get $dest-raw)))
               (then (call $raise-check-mutable-bytes/who
                           (global.get $symbol:real->floating-point-bytes)
                           (local.get $dest-raw))
                     (unreachable)))

           (local.set $dest (ref.cast (ref $Bytes) (local.get $dest-raw)))

           (if (struct.get $Bytes $immutable (local.get $dest))
               (then (call $raise-check-mutable-bytes/who
                           (global.get $symbol:real->floating-point-bytes)
                           (local.get $dest-raw))
                     (unreachable)))


           (local.set $arr (struct.get $Bytes $bs (local.get $dest)))
           (local.set $dest-len (call $i8array-length (local.get $arr)))

           (if (i32.lt_u (local.get $dest-len)
                         (i32.add (local.get $start) (local.get $size)))
               (then (call $raise-real->floating-point-bytes:short-dest
                           (local.get $dest-len)
                           (local.get $start)
                           (local.get $size))
                     (unreachable)))


           ;; --- Decode big-endian? flag, defaulting to (system-big-endian?) ---
           (local.set $big (i32.const 0))
           (if (ref.eq (local.get $big-raw) (global.get $missing))
               (then
                (if (ref.eq (call $system-big-endian?) (global.get $false))
                    (then)
                    (else (local.set $big (i32.const 1)))))
               (else
                (if (ref.eq (local.get $big-raw) (global.get $false))
                    (then)
                    (else (local.set $big (i32.const 1))))))

           ;; --- Convert x to f64 ---
           (if (ref.test (ref $Flonum) (local.get $x))
               (then
                (local.set $fl (ref.cast (ref $Flonum) (local.get $x)))
                (local.set $val (struct.get $Flonum $v (local.get $fl))))
               (else
                (if (ref.test (ref i31) (local.get $x))
                    (then
                     (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                     (if (i32.eqz (i32.and (local.get $bits) (i32.const 1)))
                         (then
                          (local.set $val
                                     (f64.convert_i32_s
                                      (i32.shr_s (local.get $bits)
                                                 (i32.const 1)))))
                         (else (call $raise-expected-real
                                     (global.get $symbol:real->floating-point-bytes)
                                     (local.get $x))
                               (unreachable))))
                    (else
                     (if (ref.test (ref $Bignum) (local.get $x))
                         (then
                          (local.set $val
                                     (call $exact-rational->f64
                                           (local.get $x))))
                         (else
                          (if (ref.test (ref $Rational) (local.get $x))
                              (then
                               (local.set $val
                                          (call $exact-rational->f64
                                                (local.get $x))))
                              (else (call $raise-expected-real
                                          (global.get $symbol:real->floating-point-bytes)
                                          (local.get $x))
                                    (unreachable)))))))))

           ;; Do it!
           (return_call $real->floating-point-bytes/checked
                        (local.get $val)
                        (local.get $size)
                        (local.get $big)
                        (local.get $dest)
                        (local.get $start)))

     (func $real->floating-point-bytes/checked
           (param $val   f64)
           (param $size  i32)
           (param $big   i32)          ; big endian?
           (param $dest  (ref $Bytes))
           (param $start i32)
           (result       (ref eq))

           (local $arr    (ref $I8Array))
           (local $bits64 i64)
           (local $bits32 i32)

           (local.set $arr (struct.get $Bytes $bs (local.get $dest)))
           (if (result (ref eq))
               (i32.eq (local.get $size) (i32.const 8))
               (then
                (local.set $bits64 (i64.reinterpret_f64 (local.get $val)))
                (if (i32.eqz (local.get $big))
                    (then
                     (call $i8array-set! (local.get $arr) (local.get $start) (i32.wrap_i64 (local.get $bits64)))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 1))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 8))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 2))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 16))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 3))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 24))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 4))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 32))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 5))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 40))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 6))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 48))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 7))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 56)))))
                    (else
                     (call $i8array-set! (local.get $arr) (local.get $start)
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 56))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 1))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 48))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 2))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 40))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 3))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 32))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 4))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 24))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 5))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 16))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 6))
                           (i32.wrap_i64 (i64.shr_u (local.get $bits64) (i64.const 8))))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 7))
                           (i32.wrap_i64 (local.get $bits64)))))
                (local.get $dest))
               (else
                (local.set $bits32 (i32.reinterpret_f32 (f32.demote_f64 (local.get $val))))
                (if (i32.eqz (local.get $big))
                    (then
                     (call $i8array-set! (local.get $arr) (local.get $start)
                           (i32.and (local.get $bits32) (i32.const 255)))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 1))
                           (i32.and (i32.shr_u (local.get $bits32) (i32.const 8)) (i32.const 255)))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 2))
                           (i32.and (i32.shr_u (local.get $bits32) (i32.const 16)) (i32.const 255)))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 3))
                           (i32.and (i32.shr_u (local.get $bits32) (i32.const 24)) (i32.const 255))))
                    (else
                     (call $i8array-set! (local.get $arr) (local.get $start)
                           (i32.and (i32.shr_u (local.get $bits32) (i32.const 24)) (i32.const 255)))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 1))
                           (i32.and (i32.shr_u (local.get $bits32) (i32.const 16)) (i32.const 255)))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 2))
                           (i32.and (i32.shr_u (local.get $bits32) (i32.const 8)) (i32.const 255)))
                     (call $i8array-set! (local.get $arr) (i32.add (local.get $start) (i32.const 3))
                           (i32.and (local.get $bits32) (i32.const 255)))))
                (local.get $dest)))))))

;; numeric-formatting-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate numeric formatting helpers used by the monolithic runtime.
(define numeric-formatting-runtime-only-helpers
  (function-forms->runtime-helpers
   'numeric-formatting-runtime-only-helpers
   `(
     ;; This is a very naive implementation.
     ;; It is used as a place holder for now.
     (func $f64->string
           (param $x f64)
           (result (ref $String))

           (local $abs         f64)
           (local $int         i32)
           (local $frac-scaled f64)
           (local $frac        i32)
           (local $neg         i32)
           (local $s-int       (ref $String))
           (local $s-frac      (ref $String))
           (local $dot         (ref $String))
           (local $minus       (ref $String))
           (local $nan         (ref $String))
           (local $pinf        (ref $String))
           (local $ninf        (ref $String))
           ;; --- Construct needed string segments ---
           (local.set $dot   (call $codepoint->string (i32.const 46))) ;; "."
           (local.set $minus (call $codepoint->string (i32.const 45))) ;; "-"
           ;; "+nan.0"
           (local.set $nan (call $i32array->string
                                 (array.new_fixed $I32Array 6
                                                  (i32.const 43)  ;; '+'
                                                  (i32.const 110) ;; 'n'
                                                  (i32.const 97)  ;; 'a'
                                                  (i32.const 110) ;; 'n'
                                                  (i32.const 46)  ;; '.'
                                                  (i32.const 48)  ;; '0'
                                                  )))
           ;; "+inf.0"
           (local.set $pinf (call $i32array->string
                                  (array.new_fixed $I32Array 6
                                                   (i32.const 43)  ;; '+'
                                                   (i32.const 105) ;; 'i'
                                                   (i32.const 110) ;; 'n'
                                                   (i32.const 102) ;; 'f'
                                                   (i32.const 46)  ;; '.'
                                                   (i32.const 48)  ;; '0'
                                                   )))
           ;; "-inf.0"
           (local.set $ninf (call $i32array->string
                                  (array.new_fixed $I32Array 6
                                                   (i32.const 45)  ;; '-'
                                                   (i32.const 105) ;; 'i'
                                                   (i32.const 110) ;; 'n'
                                                   (i32.const 102) ;; 'f'
                                                   (i32.const 46)  ;; '.'
                                                   (i32.const 48)  ;; '0'
                                                   )))
           ;; --- Handle special cases ---
           ;; NaN: x != x
           (if (f64.ne (local.get $x) (local.get $x))
               (then (return (local.get $nan))))
           ;; +inf.0
           (if (f64.eq (local.get $x) (f64.const inf))
               (then (return (local.get $pinf))))
           ;; -inf.0
           (if (f64.eq (local.get $x) (f64.const -inf))
               (then (return (local.get $ninf))))
           ;; --- Absolute value and sign ---
           (local.set $abs (f64.abs (local.get $x)))
           (local.set $neg (f64.lt (local.get $x) (f64.const 0)))
           ;; --- Integer part ---
           (local.set $int (i32.trunc_sat_f64_s (local.get $abs)))  ; todo ? okay to use _sat_ ?
           ;; Scientific notation fallback if too large
           (if (i32.ge_u (local.get $int) (i32.const 1000000))
               (then (return (call $f64->string/scientific (local.get $x)))))
           ;; --- Fractional part ---
           (local.set $frac-scaled
                      (f64.mul
                       (f64.sub (local.get $abs)
                                (f64.convert_i32_s (local.get $int)))
                       (f64.const 1000000.0)))
           (local.set $frac (i32.trunc_sat_f64_s (local.get $frac-scaled))) ; todo ?
           ;; --- Convert parts to strings ---
           (local.set $s-int  (call $i32->string       (local.get $int)))
           (local.set $s-frac (call $i32->string/pad6  (local.get $frac)))
           ;; --- Join int . frac ---
           (local.set $s-int (call $string-append/2
                                   (call $string-append/2
                                         (local.get $s-int)
                                         (local.get $dot))
                                  (local.get $s-frac)))
           ;; --- Add minus sign if needed ---
           (if (result (ref $String))
               (local.get $neg)
               (then (call $string-append/2 (local.get $minus) (local.get $s-int)))
               (else (local.get $s-int))))

     (func $i32->string/pad6
           ; Converts a non-negative integer to a decimal string padded with
           ; leading zeros to exactly 6 digits.
           (param $n i32)
           (result (ref $String))

           (local $g      (ref $I32GrowableArray))
           (local $digits (ref $I32GrowableArray))
           (local $digit  i32)
           (local $count  i32)

           ;; Make a growable array to collect digits
           (local.set $digits (call $make-i32growable-array (i32.const 6)))
           ;; Extract digits in reverse order (least significant first)
           (block $done
                  (loop $loop
                        ;; Append digit
                        (local.set $digit (i32.rem_u (local.get $n) (i32.const 10)))
                        (call $i32growable-array-add!
                              (local.get $digits) (i32.add (local.get $digit) (i32.const 48)))
                        ;; Prepare next
                        (local.set $n (i32.div_u (local.get $n) (i32.const 10)))
                        (br_if $loop (i32.ne (local.get $n) (i32.const 0)))))
           ;; Pad with '0's until we have at least 6 digits
           (local.set $count (call $i32growable-array-count (local.get $digits)))
           (block $pad
                  (loop $pad-loop
                        (br_if $pad (i32.ge_u (local.get $count) (i32.const 6)))
                        (call $i32growable-array-add! (local.get $digits) (i32.const 48)) ;; '0'
                        (local.set $count (i32.add (local.get $count) (i32.const 1)))
                        (br $pad-loop)))
           ;; Create final output array and reverse digits
           (local.set $g (call $make-i32growable-array (i32.const 6)))
           (local.set $count (call $i32growable-array-count (local.get $digits)))
           (block $done
                  (loop $rev
                        (br_if $done (i32.eqz (local.get $count)))
                        (local.set $count (i32.sub (local.get $count) (i32.const 1)))
                        (call $i32growable-array-add!
                              (local.get $g)
                              (call $i32growable-array-ref (local.get $digits) (local.get $count)))
                        (br $rev)))
           ;; Return as string
           (call $i32growable-array->string (local.get $g)))

     (func $f64->string/scientific ; TODO: This is a naive version.
           ; This function converts a 64-bit floating-point number (f64) into a
           ; human-readable scientific notation string like "1.234567e+02".
           ; It handles special cases (NaN, +inf.0, -inf.0), computes the normalized
           ; mantissa and exponent, formats the number to 6  decimal places,
           ; and constructs the result as a Racket-style string.

           (param $x f64)
           (result (ref $String))

           (local $abs   f64)
           (local $neg   i32)
           (local $exp   i32)
           (local $digit i32)
           (local $frac  i32)
           (local $mant  f64)
           (local $g     (ref $I32GrowableArray))
           (local $exp-str (ref $String))
           (local $exp-cps (ref $I32Array))
           (local $count i32)
           (local $i i32)

           ;; --- Special cases ---
           (if (f64.ne (local.get $x) (local.get $x))  ;; NaN
               (then
                (return
                 (call $i32array->string
                       (array.new_fixed $I32Array 5  ;; "nan.0"
                                        (i32.const 110) (i32.const 97) (i32.const 110)
                                        (i32.const 46) (i32.const 48))))))

           (if (f64.eq (local.get $x) (f64.const inf))  ;; +inf.0
               (then
                (return
                 (call $i32array->string
                       (array.new_fixed $I32Array 6    ;; +inf.0
                                        (i32.const 43) (i32.const 105) (i32.const 110)
                                        (i32.const 102) (i32.const 46) (i32.const 48))))))

           (if (f64.eq (local.get $x) (f64.const -inf))
               (then
                (return
                 (call $i32array->string
                       (array.new_fixed $I32Array 6  ;; -inf.0
                                        (i32.const 45) (i32.const 105) (i32.const 110)
                                        (i32.const 102) (i32.const 46) (i32.const 48))))))

           ;; --- Normalize ---
           (local.set $neg (f64.lt (local.get $x) (f64.const 0)))
           (local.set $abs (f64.abs (local.get $x)))
           (local.set $exp (i32.const 0))
           (block $down
                  (loop $norm-down
                        (br_if $down (f64.ge (local.get $abs) (f64.const 1)))
                        (local.set $abs (f64.mul (local.get $abs) (f64.const 10)))
                        (local.set $exp (i32.sub (local.get $exp) (i32.const 1)))
                        (br $norm-down)))
           (block $up
                  (loop $norm-up
                        (br_if $up (f64.lt (local.get $abs) (f64.const 10)))
                        (local.set $abs (f64.div (local.get $abs) (f64.const 10)))
                        (local.set $exp (i32.add (local.get $exp) (i32.const 1)))
                        (br $norm-up)))
           ;; --- Format mantissa ---
           (local.set $mant (local.get $abs))
           (local.set $g    (call $make-i32growable-array (i32.const 16)))
           ;; Optional sign
           (if (local.get $neg)
               (then (call $i32growable-array-add! (local.get $g) (i32.const 45)))) ;; '-'
           ;; Leading digit
           (local.set $digit (i32.trunc_f64_u (local.get $mant)))
           (call $i32growable-array-add! (local.get $g)
                 (i32.add (i32.const 48) (local.get $digit)))
           ;; Decimal point
           (call $i32growable-array-add! (local.get $g) (i32.const 46)) ;; '.'
           ;; Fractional digits
           (local.set $mant (f64.sub (local.get $mant)
                                     (f64.convert_i32_u (local.get $digit))))
           (local.set $frac (i32.const 0))
           (block $exit
                  (loop $frac-loop
                        (br_if $exit (i32.ge_u (local.get $frac) (i32.const 6)))
                        (local.set $mant (f64.mul (local.get $mant) (f64.const 10)))
                        (local.set $digit (i32.trunc_f64_u (local.get $mant)))
                        (call $i32growable-array-add!
                              (local.get $g)
                              (i32.add (i32.const 48) (local.get $digit)))
                        (local.set $mant
                                   (f64.sub (local.get $mant)
                                            (f64.convert_i32_u (local.get $digit))))
                        (local.set $frac (i32.add (local.get $frac) (i32.const 1)))
                        (br $frac-loop)))
           ;; 'e'
           (call $i32growable-array-add! (local.get $g) (i32.const 101)) ;; 'e'
           ;; Exponent
           (local.set $exp-str
                      (ref.cast (ref $String)
                                (call $number->string
                                      (ref.i31 (i32.shl (local.get $exp) (i32.const 1)))   ;; boxed fixnum
                                      (ref.i31 (i32.const 20)))))                          ;; fixnum 10 (radix)
           (local.set $exp-cps
                      (struct.get $String $codepoints (local.get $exp-str)))
           ;; Append minus sign if negative
           (if (i32.lt_s (local.get $exp) (i32.const 0))
               (then (call $i32growable-array-add! (local.get $g) (i32.const 45)))) ;; '-'
           ;; Append digits
           (local.set $count (array.len (local.get $exp-cps)))
           (local.set $i (i32.const 0))
           (block $done
                  (loop $append-loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
                        (call $i32growable-array-add!
                              (local.get $g)
                              (array.get $I32Array (local.get $exp-cps) (local.get $i)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $append-loop)))
           (call $i32growable-array->string (local.get $g)))

     (func $old:flonum->string
           (param $f (ref $Flonum))
           (result   (ref $String))

           (local $s   (ref $String))
           (local $len i32)
           (local $ch  i32)

           ;; Convert to decimal string and trim trailing zeros
           (local.set $s
                      (ref.cast (ref $String)
                        (call $string-trim-right
                              (call $f64->string
                                    (struct.get $Flonum $v (local.get $f)))
                              ,(Imm #\0))))
           (local.set $len (call $string-length/checked/i32 (local.get $s)))
           (local.set $ch
                      (call $string-ref/checked/i32
                            (local.get $s)
                            (i32.sub (local.get $len) (i32.const 1))))
           (if (result (ref $String))
               (i32.eq (local.get $ch) (i32.const 46)) ;; '.'
               (then (call $string-append/2
                            (local.get $s)
                            (call $codepoint->string (i32.const 48)))) ;; '0'
               (else (local.get $s))))

     (func $flonum->string
           (param $f (ref $Flonum))
           (result   (ref $String))

           (ref.cast (ref $String)
                     (call $linear-memory->string
                           (call $js-flonum->string
                                 (struct.get $Flonum $v (local.get $f))))))

     (func $i32->string
           (param $n   i32)
           (result     (ref $String))
           (call $i32array->string
                 (call $i32->codepoints
                       (local.get $n))))

     (func $arity-i32->string
           (param $arity i32)
           (result (ref $String))

           (local $n i32)

           (if (result (ref $String))
               (i32.ge_s (local.get $arity) (i32.const 0))
               (then
                (call $i32->string (local.get $arity)))
               (else
                (local.set $n
                           (i32.sub (i32.const -1) (local.get $arity)))
                (call $string-append/2
                      (global.get $string:arity-error:at-least)
                      (call $i32->string (local.get $n)))))
           )

     (func $i32->codepoints
           (param $n   i32)
           (result     (ref $I32Array))

           (local $len i32)
           (local $tmp i32)
           (local $abs i32)
           (local $neg i32)
           (local $i   i32)
           (local $d   i32)
           (local $arr (ref $I32Array))

           ;; Special case: 0 → [48]
           (if (i32.eqz (local.get $n))
               (then
                (return (array.new_fixed $I32Array 1 (i32.const 48))))) ;; '0'
           ;; Check for negative
           (local.set $neg (i32.lt_s (local.get $n) (i32.const 0)))
           ;; Take absolute value safely (avoid overflow on min int)
           (local.set $abs (select
                            (i32.sub (i32.const 0) (local.get $n)) ;; -n
                            (local.get $n)
                            (local.get $neg)))
           ;; Count digits
           (local.set $tmp (local.get $abs))
           (local.set $len (i32.const 0))
           (block $done-count
                  (loop $count
                        (br_if $done-count (i32.eqz (local.get $tmp)))
                        (local.set $tmp (i32.div_u (local.get $tmp) (i32.const 10)))
                        (local.set $len (i32.add (local.get $len) (i32.const 1)))
                        (br $count)))
           ;; Add one more if negative (for '-')
           (if (local.get $neg)
               (then (local.set $len (i32.add (local.get $len) (i32.const 1)))))
           ;; Allocate array of codepoints
           (local.set $arr (array.new_default $I32Array (local.get $len)))
           ;; Fill from right to left
           (local.set $tmp (local.get $abs))
           (local.set $i (i32.sub (local.get $len) (i32.const 1)))
           (block $fill-done
                  (loop $fill
                        (br_if $fill-done (i32.lt_s (local.get $i) (i32.const 0)))
                        (local.set $d (i32.rem_u (local.get $tmp) (i32.const 10)))
                        (array.set $I32Array
                                   (local.get $arr)
                                   (local.get $i)
                                   (i32.add (i32.const 48) (local.get $d))) ;; '0' + d
                        (local.set $tmp (i32.div_u (local.get $tmp) (i32.const 10)))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (br $fill)))
           ;; Add '-' if needed
           (if (local.get $neg)
               (then
                (array.set $I32Array (local.get $arr) (i32.const 0) (i32.const 45)))) ;; '-'
           (local.get $arr)))))


;; number-core-runtime-helper-names : (listof symbol?)
;;   Name number helpers available in the standalone core runtime.
(define number-core-runtime-helper-names
  (append number-type-runtime-only-helper-names
          generic-numeric-runtime-only-helper-names
          number-error-runtime-only-helper-names
          generic-arithmetic-runtime-only-helper-names
          generic-bitwise-runtime-only-helper-names
          number-string-conversion-runtime-only-helper-names
          string-number-conversion-runtime-only-helper-names
          floating-point-byte-conversion-runtime-only-helper-names
          numeric-formatting-runtime-only-helper-names))

;; number-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate number helpers in monolithic runtime order.
(define number-all-runtime-helpers
  (append number-type-runtime-only-helpers
          generic-numeric-runtime-only-helpers
          number-error-runtime-only-helpers
          generic-arithmetic-runtime-only-helpers
          generic-bitwise-runtime-only-helpers
          number-string-conversion-runtime-only-helpers
          string-number-conversion-runtime-only-helpers
          floating-point-byte-conversion-runtime-only-helpers
          numeric-formatting-runtime-only-helpers))

;; number-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate number helpers available in the standalone core runtime.
(define number-core-runtime-helpers
  (select-runtime-helpers number-all-runtime-helpers
                          number-core-runtime-helper-names))

;; number-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate number helpers that still depend on monolithic runtime globals.
(define number-runtime-only-helpers
  (remove-runtime-helpers number-all-runtime-helpers
                          number-core-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define number-helper-index
    (make-core-runtime-helper-index
     (append number-core-runtime-helpers
             number-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name number-core-runtime-helpers)
   number-core-runtime-helper-names)

  (check-equal?
   (map form-name (number-type-runtime-helper-forms number-helper-index))
   number-type-runtime-only-helper-names)

  (check-equal?
   (map form-name (generic-numeric-runtime-helper-forms number-helper-index))
   generic-numeric-runtime-only-helper-names)

  (check-equal?
   (map form-name (number-error-runtime-helper-forms number-helper-index))
   number-error-runtime-only-helper-names)

  (check-equal?
   (map form-name (generic-arithmetic-runtime-helper-forms number-helper-index))
   generic-arithmetic-runtime-only-helper-names)

  (check-equal?
   (map form-name (generic-bitwise-runtime-helper-forms number-helper-index))
   generic-bitwise-runtime-only-helper-names)

  (check-equal?
   (map form-name (number-string-conversion-runtime-helper-forms number-helper-index))
   number-string-conversion-runtime-only-helper-names)

  (check-equal?
   (map form-name (string-number-conversion-runtime-helper-forms number-helper-index))
   string-number-conversion-runtime-only-helper-names)

  (check-equal?
   (map form-name (floating-point-byte-conversion-runtime-helper-forms number-helper-index))
   floating-point-byte-conversion-runtime-only-helper-names)

  (check-equal?
   (map form-name (numeric-formatting-runtime-helper-forms number-helper-index))
   numeric-formatting-runtime-only-helper-names))
