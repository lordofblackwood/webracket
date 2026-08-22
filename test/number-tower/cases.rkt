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
            #:note "Rational literals must canonicalize to 1/2.")
   (nt-case 'exact-decimal-tenth
            'rational-representation
            #e0.1
            #:note "Exact decimal syntax must preserve 1/10.")
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
            #:note "Variadic < threads exact fixnum and bignum comparisons.")))

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
