#lang racket/base

(require racket/list)

(provide (struct-out number-tower-case)
         number-tower-cases
         number-tower-groups
         select-number-tower-cases)

(struct number-tower-case
  (id group expr comparison gate? note)
  #:transparent)

;; nt-case : symbol? symbol? any/c -> number-tower-case?
;;   Build one CS/WebRacket differential case.
(define (nt-case id group expr
                 #:comparison [comparison 'exact]
                 #:gate? [gate? #f]
                 #:note [note ""])
  (number-tower-case id group expr comparison gate? note))

;; number-tower-cases : (listof number-tower-case?)
;;   Number tower oracle cases, with current known gaps recorded as non-gates.
(define number-tower-cases
  (list
   (nt-case 'oracle-fixnum-add
            'oracle-smoke
            '(+ 1 2)
            #:gate? #t
            #:note "Small exact arithmetic should already agree.")
   (nt-case 'oracle-flonum-add
            'oracle-smoke
            '(+ 1.0 2.5)
            #:gate? #t
            #:note "Small flonum arithmetic should already agree.")
   (nt-case 'fixnum-upper-bound
            'integer-representation
            536870911
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Largest current WebRacket signed 30-bit fixnum.")
   (nt-case 'fixnum-lower-bound
            'integer-representation
            -536870912
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Smallest current WebRacket signed 30-bit fixnum.")
   (nt-case 'above-fixnum-upper-bound
            'integer-representation
            536870912
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "First positive exact integer that needs bignum support.")
   (nt-case 'below-fixnum-lower-bound
            'integer-representation
            -536870913
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "First negative exact integer that needs bignum support.")
   (nt-case 'two-to-32
            'integer-representation
            4294967296
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer around the 32-bit limb boundary.")
   (nt-case 'two-to-53
            'integer-representation
            9007199254740992
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer at the f64 integer precision boundary.")
   (nt-case 'two-to-53-plus-one
            'integer-representation
            9007199254740993
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer just past the f64 integer precision boundary.")
   (nt-case 'two-to-64
            'integer-representation
            18446744073709551616
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact integer around a two-limb unsigned boundary.")
   (nt-case 'two-to-32-binary-string
            'integer-representation
            '(number->string 4294967296 2)
            #:gate? #t
            #:note "Bignum number->string must support radix 2.")
   (nt-case 'two-to-32-hex-string
            'integer-representation
            '(number->string 4294967296 16)
            #:gate? #t
            #:note "Bignum number->string must support radix 16.")
   (nt-case 'negative-bignum-octal-string
            'integer-representation
            '(number->string -536870913 8)
            #:gate? #t
            #:note "Bignum number->string must support radix 8 and signs.")
   (nt-case 'bignum-eqv-same-value
            'integer-representation
            '(eqv? 9007199254740993 9007199254740993)
            #:gate? #t
            #:note "Bignum eqv? compares canonical limb values.")
   (nt-case 'bignum-eqv-different-value
            'integer-representation
            '(eqv? 9007199254740993 9007199254740992)
            #:gate? #t
            #:note "Bignum eqv? distinguishes neighboring limb values.")
   (nt-case 'bignum-equal-same-value
            'integer-representation
            '(equal? 9007199254740993 9007199254740993)
            #:gate? #t
            #:note "Bignum equal? falls through to value-based eqv?.")
   (nt-case 'two-fourths
            'rational-representation
            2/4
            #:gate? #t
            #:note "Rational literals must canonicalize to 1/2.")
   (nt-case 'exact-decimal-tenth
            'rational-representation
            #e0.1
            #:gate? #t
            #:note "Exact decimal syntax must preserve 1/10.")
   (nt-case 'rational-predicate
            'rational-representation
            '(rational? 1/2)
            #:gate? #t
            #:note "Exact rational values satisfy rational?.")
   (nt-case 'rational-exact-predicate
            'rational-representation
            '(exact? 1/2)
            #:gate? #t
            #:note "Exact rational values satisfy exact?.")
   (nt-case 'rational-noninteger-predicate
            'rational-representation
            '(integer? 1/2)
            #:gate? #t
            #:note "Non-integer exact rationals are not integer?.")
   (nt-case 'rational-eqv-same-value
            'rational-representation
            '(eqv? 2/4 1/2)
            #:gate? #t
            #:note "Canonical rationals compare by numerator and denominator.")
   (nt-case 'rational-binary-string
            'rational-representation
            '(number->string 1/10 2)
            #:gate? #t
            #:note "Rational number->string applies the radix to both parts.")
   (nt-case 'negative-rational-hex-string
            'rational-representation
            '(number->string -1/10 16)
            #:gate? #t
            #:note "Rational number->string preserves signs and radix.")
   (nt-case 'rational-add
            'rational-arithmetic
            '(+ 1/3 1/6)
            #:gate? #t
            #:note "Exact rational addition must normalize.")
   (nt-case 'rational-subtract
            'rational-arithmetic
            '(- 1/2 2/3)
            #:gate? #t
            #:note "Exact rational subtraction must normalize signs.")
   (nt-case 'rational-multiply
            'rational-arithmetic
            '(* 2/3 9/4)
            #:gate? #t
            #:note "Exact rational multiplication must normalize.")
   (nt-case 'integer-division-rational
            'rational-arithmetic
            '(/ 1 2)
            #:gate? #t
            #:note "Exact integer / can produce a rational.")
   (nt-case 'rational-divide
            'rational-arithmetic
            '(/ 3/4 9/10)
            #:gate? #t
            #:note "Exact rational division must normalize.")
   (nt-case 'bignum-rational-divide
            'rational-arithmetic
            '(/ 9007199254740993 2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact division can preserve a bignum numerator.")
   (nt-case 'rational-equal-comparison
            'rational-arithmetic
            '(= 2/4 1/2)
            #:gate? #t
            #:note "Exact rational equality compares normalized value.")
   (nt-case 'rational-less-than
            'rational-arithmetic
            '(< 1/3 1/2)
            #:gate? #t
            #:note "Exact rational ordering compares by value.")
   (nt-case 'rational-greater-than-negative
            'rational-arithmetic
            '(> -1/3 -1/2)
            #:gate? #t
            #:note "Exact rational ordering handles negative values.")
   (nt-case 'rational-zero-predicate
            'rational-arithmetic
            '(zero? 1/2)
            #:gate? #t
            #:note "Canonical non-integer rationals are nonzero.")
   (nt-case 'rational-positive-predicate
            'rational-arithmetic
            '(positive? 1/2)
            #:gate? #t
            #:note "Rational positivity follows the numerator sign.")
   (nt-case 'rational-negative-predicate
            'rational-arithmetic
            '(negative? -1/2)
            #:gate? #t
            #:note "Rational negativity follows the numerator sign.")
   (nt-case 'inexact->exact-rational-identity
            'rational-conversion
            '(inexact->exact 1/2)
            #:gate? #t
            #:note "inexact->exact returns exact rationals unchanged.")
   (nt-case 'inexact->exact-bignum-identity
            'rational-conversion
            '(inexact->exact 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "inexact->exact returns exact bignums unchanged.")
   (nt-case 'exact->inexact-rational
            'rational-conversion
            '(exact->inexact 1/2)
            #:gate? #t
            #:note "exact->inexact converts exact rationals to flonums.")
   (nt-case 'exact->inexact-bignum
            'rational-conversion
            '(exact->inexact 9007199254740993)
            #:gate? #t
            #:note "exact->inexact converts bignums using f64 rounding.")
   (nt-case 'rectangular-literal
            'complex-basic
            1+2i
            #:note "Rectangular complex literal with exact components.")
   (nt-case 'unit-imaginary
            'complex-basic
            +i
            #:note "Abbreviated imaginary literal.")
   (nt-case 'polar-zero-angle
            'complex-basic
            2@0
            #:note "Polar syntax that collapses to an exact real in CS.")
   (nt-case 'make-rectangular-exact-zero
            'complex-basic
            '(make-rectangular 1 0)
            #:note "Exact zero imaginary component collapses to a real.")
   (nt-case 'make-rectangular-inexact-positive-zero
            'complex-basic
            '(make-rectangular 1 0.0)
            #:note "CS preserves the inexact zero imaginary component.")
   (nt-case 'make-rectangular-inexact-negative-zero
            'complex-basic
            '(make-rectangular 1 -0.0)
            #:note "CS preserves the negative zero imaginary component.")
   (nt-case 'positive-nan
            'real-special-values
            +nan.0
            #:note "NaN predicate, text, and eqv category.")
   (nt-case 'positive-infinity
            'real-special-values
            +inf.0
            #:note "Positive infinity category.")
   (nt-case 'negative-infinity
            'real-special-values
            -inf.0
            #:note "Negative infinity category.")
   (nt-case 'positive-zero
            'real-special-values
            0.0
            #:note "Positive inexact zero category.")
   (nt-case 'negative-zero
            'real-special-values
            -0.0
            #:note "Negative inexact zero category.")
   (nt-case 'generic-add-overflow
            'integer-arithmetic
            '(+ 536870911 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic + promotes beyond WebRacket's fixnum range.")
   (nt-case 'generic-sub-overflow
            'integer-arithmetic
            '(- -536870912 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic - promotes below WebRacket's fixnum range.")
   (nt-case 'generic-mul-overflow
            'integer-arithmetic
            '(* 536870911 2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic * promotes beyond WebRacket's fixnum range.")
   (nt-case 'bignum-add-limb-carry
            'integer-arithmetic
            '(+ 4294967295 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum addition carries across a 32-bit limb.")
   (nt-case 'bignum-add-two-large
            'integer-arithmetic
            '(+ 9007199254740993 7)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum addition preserves integers beyond f64 precision.")
   (nt-case 'bignum-sub-to-fixnum
            'integer-arithmetic
            '(- 536870912 1)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum subtraction collapses canonical fixnum results.")
   (nt-case 'bignum-sub-cancel
            'integer-arithmetic
            '(- 9007199254740993 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum subtraction canonicalizes zero as a fixnum.")
   (nt-case 'bignum-mul-two-limbs
            'integer-arithmetic
            '(* 4294967296 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Bignum multiplication handles two-limb products.")
   (nt-case 'add1-overflow
            'integer-arithmetic
            '(add1 536870911)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "add1 promotes beyond WebRacket's fixnum range.")
   (nt-case 'sub1-overflow
            'integer-arithmetic
            '(sub1 -536870912)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "sub1 promotes below WebRacket's fixnum range.")
   (nt-case 'abs-most-negative-fixnum
            'integer-arithmetic
            '(abs -536870912)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "abs promotes the most-negative WebRacket fixnum.")
   (nt-case 'bignum-numeric-equal-same-value
            'integer-ordering
            '(= 9007199254740993 9007199254740993)
            #:gate? #t
            #:note "Generic = compares bignum exact integers by value.")
   (nt-case 'bignum-numeric-equal-neighbor
            'integer-ordering
            '(= 9007199254740993 9007199254740992)
            #:gate? #t
            #:note "Generic = distinguishes neighboring bignums.")
   (nt-case 'fixnum-less-than-bignum
            'integer-ordering
            '(< 536870911 536870912)
            #:gate? #t
            #:note "Generic < handles fixnum to bignum boundaries.")
   (nt-case 'bignum-less-than-bignum
            'integer-ordering
            '(< 9007199254740992 9007199254740993)
            #:gate? #t
            #:note "Generic < compares positive bignums by magnitude.")
   (nt-case 'negative-fixnum-greater-than-bignum
            'integer-ordering
            '(> -536870912 -536870913)
            #:gate? #t
            #:note "Generic > handles negative fixnum to bignum boundaries.")
   (nt-case 'bignum-less-equal-same-value
            'integer-ordering
            '(<= 4294967296 4294967296)
            #:gate? #t
            #:note "Generic <= accepts equal bignum values.")
   (nt-case 'negative-bignum-greater-equal-neighbor
            'integer-ordering
            '(>= -9007199254740993 -9007199254740992)
            #:gate? #t
            #:note "Generic >= compares negative bignum magnitudes correctly.")
   (nt-case 'variadic-exact-integer-ordering
            'integer-ordering
            '(< -9007199254740993 -536870913 0 536870912 9007199254740993)
            #:gate? #t
            #:note "Variadic < threads exact fixnum and bignum comparisons.")
   (nt-case 'mixed-exact-flonum-equal-rounded-down
            'integer-ordering
            '(= 9007199254740993 9007199254740992.0)
            #:gate? #t
            #:note "Mixed = compares against the exact f64 value, not a rounded exact integer.")
   (nt-case 'mixed-exact-flonum-greater-rounded-down
            'integer-ordering
            '(> 9007199254740993 9007199254740992.0)
            #:gate? #t
            #:note "Mixed > keeps exact integer precision past 2^53.")
   (nt-case 'mixed-exact-flonum-less-next-f64
            'integer-ordering
            '(< 9007199254740993 9007199254740994.0)
            #:gate? #t
            #:note "Mixed < compares a bignum with a neighboring finite f64.")
   (nt-case 'mixed-exact-flonum-equal-two-to-53
            'integer-ordering
            '(= 9007199254740992 9007199254740992.0)
            #:gate? #t
            #:note "Mixed = recognizes an exactly representable f64 integer.")
   (nt-case 'mixed-exact-flonum-positive-infinity
            'integer-ordering
            '(< 9007199254740993 +inf.0)
            #:gate? #t
            #:note "Mixed < orders finite exact integers below +inf.0.")
   (nt-case 'mixed-exact-flonum-negative-infinity
            'integer-ordering
            '(> -9007199254740993 -inf.0)
            #:gate? #t
            #:note "Mixed > orders finite exact integers above -inf.0.")
   (nt-case 'mixed-exact-flonum-nan-unordered
            'integer-ordering
            '(< 9007199254740993 +nan.0)
            #:gate? #t
            #:note "Mixed comparisons with NaN are unordered and return #f.")
   (nt-case 'bignum-min-exact-only
            'integer-ordering
            '(min 9007199254740993 2)
            #:gate? #t
            #:note "Generic min accepts bignum exact integers.")
   (nt-case 'bignum-max-exact-only
            'integer-ordering
            '(max 9007199254740993 2)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Generic max can return a bignum exact integer.")
   (nt-case 'bignum-min-mixed-flonum
            'integer-ordering
            '(min 9007199254740993 2.0)
            #:gate? #t
            #:note "Generic min accepts mixed bignum/flonum inputs.")
   (nt-case 'bignum-max-mixed-flonum
            'integer-ordering
            '(max 9007199254740993 2.0)
            #:gate? #t
            #:note "Generic max returns inexact when a flonum participates.")
   (nt-case 'mixed-min-signed-zero-tie
            'integer-ordering
            '(eqv? (min -0.0 0) 0.0)
            #:gate? #t
            #:note "Mixed min preserves the current signed-zero tie behavior.")
   (nt-case 'mixed-max-signed-zero-tie
            'integer-ordering
            '(eqv? (max 0 -0.0) -0.0)
            #:gate? #t
            #:note "Mixed max preserves the current signed-zero tie behavior.")
   (nt-case 'bignum-min-nan
            'integer-ordering
            '(eqv? (min +nan.0 9007199254740993) +nan.0)
            #:gate? #t
            #:note "Generic min propagates NaN with bignum inputs.")
   (nt-case 'bignum-max-nan
            'integer-ordering
            '(eqv? (max 9007199254740993 +nan.0) +nan.0)
            #:gate? #t
            #:note "Generic max propagates NaN with bignum inputs.")
   (nt-case 'bignum-quotient-small-divisor
            'integer-division
            '(quotient 9007199254740993 3)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact quotient divides a bignum dividend by a one-limb divisor.")
   (nt-case 'bignum-remainder-small-divisor
            'integer-division
            '(remainder 9007199254740993 7)
            #:gate? #t
            #:note "Exact remainder divides a bignum dividend by a one-limb divisor.")
   (nt-case 'negative-bignum-modulo-small-divisor
            'integer-division
            '(modulo -9007199254740993 7)
            #:gate? #t
            #:note "Exact modulo adjusts the truncating remainder to the divisor sign.")
   (nt-case 'bignum-quotient-remainder-small-divisor
            'integer-division
            '(let-values ([(q r) (quotient/remainder -9007199254740993 7)])
               (and (= q -1286742750677284)
                    (= r -5)))
            #:gate? #t
            #:note "quotient/remainder returns the truncating exact pair for a bignum dividend.")
   (nt-case 'bignum-quotient-smaller-dividend
            'integer-division
            '(quotient 3 9007199254740993)
            #:gate? #t
            #:note "Exact quotient handles the trivial zero quotient with a multi-limb divisor.")
   (nt-case 'bignum-remainder-smaller-dividend
            'integer-division
            '(remainder 3 9007199254740993)
            #:gate? #t
            #:note "Exact remainder handles the trivial dividend remainder with a multi-limb divisor.")
   (nt-case 'bignum-quotient-multi-limb-divisor
            'integer-division
            '(quotient 18446744073709551616 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact quotient handles a multi-limb divisor.")
   (nt-case 'bignum-remainder-multi-limb-divisor
            'integer-division
            '(remainder 18446744073709551617 4294967296)
            #:gate? #t
            #:note "Exact remainder handles a multi-limb divisor.")
   (nt-case 'negative-bignum-modulo-multi-limb-divisor
            'integer-division
            '(modulo -18446744073709551617 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact modulo adjusts signs after multi-limb division.")
   (nt-case 'bignum-quotient-negative-multi-limb-divisor
            'integer-division
            '(quotient 18446744073709551617 -4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact quotient follows sign rules with a negative multi-limb divisor.")
   (nt-case 'bignum-remainder-negative-multi-limb-divisor
            'integer-division
            '(remainder 18446744073709551617 -4294967296)
            #:gate? #t
            #:note "Exact remainder keeps the dividend sign with a negative multi-limb divisor.")
   (nt-case 'bignum-modulo-negative-multi-limb-divisor
            'integer-division
            '(modulo 18446744073709551617 -4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "Exact modulo follows the negative divisor sign.")
   (nt-case 'bignum-quotient-remainder-multi-limb-divisor
            'integer-division
            '(let-values ([(q r) (quotient/remainder -18446744073709551617
                                                     4294967296)])
               (and (= q -4294967296)
                    (= r -1)))
            #:gate? #t
            #:note "quotient/remainder handles signed multi-limb division.")
   (nt-case 'bignum-quotient-remainder-non-power-divisor
            'integer-division
            '(let-values ([(q r) (quotient/remainder 123456789012345678901234567890
                                                     9876543210987654321)])
               (and (= q 12499999886)
                    (= r 925925941327160484)))
            #:gate? #t
            #:note "Multi-limb division handles a non-power divisor and remainder.")
   (nt-case 'bignum-divmod-fixed-random-positive
            'integer-division
            '(let ([n 340282366920938463463374607431768211457]
                   [d 18446744073709551617])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q 18446744073709551615)
                      (= r 2)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant for positive multi-limb operands.")
   (nt-case 'bignum-divmod-fixed-random-negative-dividend
            'integer-division
            '(let ([n -1234567890123456789012345678901234567890]
                   [d 98765432109876543210987654321])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q -12499999886)
                      (= r -9259259400925925941327160484)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant with a negative dividend.")
   (nt-case 'bignum-divmod-fixed-random-negative-divisor
            'integer-division
            '(let ([n 99999999999999999999999999999999999999]
                   [d -3333333333333333333333333333])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q -30000000000)
                      (= r 9999999999)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant with a negative divisor.")
   (nt-case 'bignum-divmod-fixed-random-both-negative
            'integer-division
            '(let ([n -340282366920938463463374607431768211455]
                   [d -18446744073709551615])
               (let-values ([(q r) (quotient/remainder n d)])
                 (and (= q 18446744073709551617)
                      (= r 0)
                      (= n (+ (* q d) r)))))
            #:gate? #t
            #:note "Fixed random divmod invariant with both operands negative.")
   (nt-case 'bignum-quotient-equal-multi-limb
            'integer-division
            '(quotient 18446744073709551616 18446744073709551616)
            #:gate? #t
            #:note "Exact quotient handles equal multi-limb operands.")
   (nt-case 'bignum-remainder-equal-multi-limb
            'integer-division
            '(remainder 18446744073709551616 18446744073709551616)
            #:gate? #t
            #:note "Exact remainder handles equal multi-limb operands.")
   (nt-case 'bignum-gcd-small-divisor
            'integer-gcd
            '(gcd 9007199254740993 3)
            #:gate? #t
            #:note "gcd can reduce a bignum by a one-limb divisor.")
   (nt-case 'bignum-lcm-small-divisor
            'integer-gcd
            '(lcm 9007199254740993 3)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "lcm routes exact bignum division through quotient before multiplying.")
   (nt-case 'bignum-gcd-zero-left
            'integer-gcd
            '(gcd 0 9007199254740993)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "gcd handles the zero-left case with a multi-limb divisor.")
   (nt-case 'bignum-gcd-multi-limb-divisor
            'integer-gcd
            '(gcd 18446744073709551616 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "gcd can reduce exact integers through multi-limb division.")
   (nt-case 'bignum-lcm-multi-limb-divisor
            'integer-gcd
            '(lcm 18446744073709551616 4294967296)
            #:comparison 'ignore-fixnum-width
            #:gate? #t
            #:note "lcm can use exact quotient with a multi-limb gcd.")))

;; number-tower-groups : -> (listof symbol?)
;;   Return the distinct oracle groups in stable display order.
(define (number-tower-groups)
  (remove-duplicates (map number-tower-case-group number-tower-cases)))

;; selected-by-symbols? : (any/c -> symbol?) (listof symbol?) any/c -> boolean?
;;   Check whether a symbol filter accepts v.
(define (selected-by-symbols? selector allowed v)
  (or (null? allowed)
      (memq (selector v) allowed)))

;; select-number-tower-cases :
;;   [#:groups (listof symbol?)] [#:ids (listof symbol?)] [#:include-non-gates? boolean?]
;;   -> (listof number-tower-case?)
;;   Select cases for a runner invocation.
(define (select-number-tower-cases #:groups [groups '()]
                                   #:ids [ids '()]
                                   #:include-non-gates? [include-non-gates? #f])
  (filter
   (lambda (c)
     (and (selected-by-symbols? number-tower-case-group groups c)
          (selected-by-symbols? number-tower-case-id ids c)
          (or include-non-gates?
              (number-tower-case-gate? c))))
   number-tower-cases))
