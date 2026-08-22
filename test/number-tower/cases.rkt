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
;;   Initial Milestone 0 cases, with current known gaps recorded as non-gates.
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
            #:note "Largest current WebRacket signed 30-bit fixnum.")
   (nt-case 'fixnum-lower-bound
            'integer-representation
            -536870912
            #:note "Smallest current WebRacket signed 30-bit fixnum.")
   (nt-case 'above-fixnum-upper-bound
            'integer-representation
            536870912
            #:note "First positive exact integer that needs bignum support.")
   (nt-case 'below-fixnum-lower-bound
            'integer-representation
            -536870913
            #:note "First negative exact integer that needs bignum support.")
   (nt-case 'two-to-32
            'integer-representation
            4294967296
            #:note "Exact integer around the 32-bit limb boundary.")
   (nt-case 'two-to-53
            'integer-representation
            9007199254740992
            #:note "Exact integer at the f64 integer precision boundary.")
   (nt-case 'two-to-53-plus-one
            'integer-representation
            9007199254740993
            #:note "Exact integer just past the f64 integer precision boundary.")
   (nt-case 'two-to-64
            'integer-representation
            18446744073709551616
            #:note "Exact integer around a two-limb unsigned boundary.")
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
            #:note "Generic + must eventually promote instead of overflowing.")
   (nt-case 'generic-sub-overflow
            'integer-arithmetic
            '(- -536870912 1)
            #:note "Generic - must eventually promote instead of overflowing.")
   (nt-case 'generic-mul-overflow
            'integer-arithmetic
            '(* 536870911 2)
            #:note "Generic * must eventually promote instead of overflowing.")))

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
