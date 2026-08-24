#lang racket

;;;
;;; Rationals
;;;

;; This file implements exact rationals.
;;
;; Exact integers are represented elsewhere as WebRacket fixnums or bignums.
;; This file handles the remaining exact real numbers: non-integer rationals.
;;
;; Rationals are represented as
;;
;;   (type $Rational (sub $Real
;;                       (struct
;;                         (field $hash (mut i32))
;;                         (field $num  (ref eq))
;;                         (field $den  (ref eq)))))
;;
;; That is, like other boxed numbers rationals have a:
;;   - hash code
;;   - numerator
;;   - denominator
;;
;; The numerator and denominator are canonical exact integers.
;; The denominator is positive.
;; The numerator and denominator share no common factor.
;; The denominator is never 1, since such values collapse to exact integers.
;;
;; In formulas, a rational is written as
;;
;;     q = num/den
;;
;; where den > 0 and gcd(abs(num), den) = 1.
;;
;; This file covers:
;;   - integer gcd and lcm helpers used by rationals
;;   - rational normalization
;;   - predicates and basic operations
;;   - rationalize and simplest rationals
;;   - exact rational rounding
;;   - exact rational and f64 conversion
;;   - rational arithmetic and comparison
;;   - rational printing

(provide rational-core-runtime-helpers
         rational-core-runtime-helper-forms
         rational-runtime-only-helpers)

(require "../core-helper.rkt")

;;;
;;; Runtime Helper Forms
;;;

;; rational-core-runtime-helpers : (listof core-runtime-helper?)
;;   Runtime support for exact, non-integer rationals.
(define rational-core-runtime-helpers
  (function-forms->runtime-helpers
   'rational-core-runtime-helpers
   '(
     ;;;
     ;;; Integer Helpers
     ;;;

     ;; Euclid's algorithm repeatedly uses
     ;;
     ;;     gcd(a, b) = gcd(b, a mod b)
     ;;
     ;; until the second argument becomes zero. The inputs are made
     ;; nonnegative first so the result is always nonnegative.

     ;; $integer-gcd : exact-integer? exact-integer? -> exact-nonnegative-integer?
     ;;   Compute a nonnegative greatest common divisor for exact integers.
     (func $integer-gcd
           (param $n (ref eq))
           (param $m (ref eq))
           (result (ref eq))

           (local $a    (ref eq))
           (local $b    (ref eq))
           (local $r    (ref eq))
           (local $vals (ref $Values))

           ;; Work with absolute values; gcd ignores signs.
           (local.set $a (call $integer-abs (local.get $n)))
           (local.set $b (call $integer-abs (local.get $m)))

           ;; Repeatedly replace (a, b) with (b, a mod b).
           (block $done
                  (loop $loop
                        (br_if $done
                               (call $integer-zero?/i32 (local.get $b)))
                        (local.set $vals
                                   (call $integer-divmod
                                         (local.get $a)
                                         (local.get $b)))
                        (local.set $r
                                   (array.get $Values
                                              (local.get $vals)
                                              (i32.const 1)))
                        (local.set $a (local.get $b))
                        (local.set $b (local.get $r))
                        (br $loop)))
           (local.get $a))

     ;; Least common multiple uses
     ;;
     ;;     lcm(n, m) = abs(n/gcd(n,m) * m)
     ;;
     ;; with a zero shortcut before the division. Dividing before
     ;; multiplying keeps the intermediate product smaller.

     ;; $integer-lcm : exact-integer? exact-integer? -> exact-nonnegative-integer?
     ;;   Compute a nonnegative least common multiple for exact integers.
     (func $integer-lcm
           (param $n (ref eq))
           (param $m (ref eq))
           (result (ref eq))

           (local $g    (ref eq))
           (local $vals (ref $Values))

           ;; Work with absolute values so the result is nonnegative.
           (local.set $n (call $integer-abs (local.get $n)))
           (local.set $m (call $integer-abs (local.get $m)))

           ;; If either side is zero, the lcm is zero.
           (if (call $integer-zero?/i32 (local.get $n))
               (then (return (ref.i31 (i32.const 0)))))
           (if (call $integer-zero?/i32 (local.get $m))
               (then (return (ref.i31 (i32.const 0)))))

           ;; Divide n by gcd(n,m), then multiply by m.
           (local.set $g (call $integer-gcd
                               (local.get $n)
                               (local.get $m)))
           (local.set $vals (call $integer-divmod
                                  (local.get $n)
                                  (local.get $g)))
           (call $integer-mul/2
                 (array.get $Values
                            (local.get $vals)
                            (i32.const 0))
                 (local.get $m)))

     ;;;
     ;;; Canonical Representation
     ;;;

     ;; Normalization turns any integer ratio num0/den0 into the canonical
     ;; representation:
     ;;
     ;;     den > 0
     ;;     gcd(abs(num), den) = 1
     ;;
     ;; It also collapses special cases:
     ;;
     ;;     0/den -> 0
     ;;     num/1 -> num

     ;; $rational-normalize : exact-integer? exact-integer? -> exact-rational?
     ;;   Build a canonical exact rational, collapsing integers.
     (func $rational-normalize
           (param $num0 (ref eq))
           (param $den0 (ref eq))
           (result (ref eq))

           (local $num  (ref eq))
           (local $den  (ref eq))
           (local $g    (ref eq))
           (local $vals (ref $Values))

           ;; Copy inputs into mutable locals and reject a zero denominator.
           (local.set $num (local.get $num0))
           (local.set $den (local.get $den0))
           (if (call $integer-zero?/i32 (local.get $den))
               (then (call $raise-division-by-zero) (unreachable)))

           ;; Keep the sign in the numerator by making the denominator positive.
           (if (i32.lt_s (call $integer-sign/i32 (local.get $den))
                         (i32.const 0))
               (then
                (local.set $num (call $integer-negate (local.get $num)))
                (local.set $den (call $integer-negate (local.get $den)))))

           ;; Zero has only one representation: the exact integer 0.
           (if (call $integer-zero?/i32 (local.get $num))
               (then (return (ref.i31 (i32.const 0)))))

           ;; Divide numerator and denominator by their greatest common divisor.
           (local.set $g
                      (call $integer-gcd
                            (local.get $num)
                            (local.get $den)))
           (local.set $vals
                      (call $integer-divmod
                            (local.get $num)
                            (local.get $g)))
           (local.set $num
                      (array.get $Values
                                 (local.get $vals)
                                 (i32.const 0)))
           (local.set $vals
                      (call $integer-divmod
                            (local.get $den)
                            (local.get $g)))
           (local.set $den
                      (array.get $Values
                                 (local.get $vals)
                                 (i32.const 0)))

           ;; A denominator of 1 means the result is an exact integer.
           (if (i32.eqz
                (call $integer-compare/i32
                      (local.get $den)
                      (ref.i31 (i32.const 2))))
               (then (return (local.get $num))))

           ;; Build the boxed rational for the remaining non-integer case.
           (struct.new $Rational
                       (i32.const 0)
                       (local.get $num)
                       (local.get $den)))

     ;; $rational-numerator : rational? -> exact-integer?
     ;;   Return the canonical numerator.
     (func $rational-numerator
           (param $q (ref $Rational))
           (result (ref eq))
           (struct.get $Rational $num (local.get $q)))

     ;; $rational-denominator : rational? -> exact-positive-integer?
     ;;   Return the canonical positive denominator.
     (func $rational-denominator
           (param $q (ref $Rational))
           (result (ref eq))
           (struct.get $Rational $den (local.get $q)))

     ;;;
     ;;; Predicates and Basic Operations
     ;;;

     ;; $exact-rational?/i32 : any/c -> i32
     ;;   Return 1 for exact integers and exact rational values.
     (func $exact-rational?/i32
           (param $x (ref eq))
           (result i32)

           ;; Exact integers are exact rationals too.
           (if (call $fx?/i32 (local.get $x))
               (then (return (i32.const 1))))
           (if (ref.test (ref $Bignum) (local.get $x))
               (then (return (i32.const 1))))

           ;; The boxed rational case covers exact non-integer rationals.
           (ref.test (ref $Rational) (local.get $x)))

     ;; $exact-rational-zero?/i32 : exact-rational? -> i32
     ;;   Return 1 when x is exact zero, otherwise 0.
     (func $exact-rational-zero?/i32
           (param $x (ref eq))
           (result i32)

           ;; Canonical rationals are never zero; zero collapsed to an integer.
           (if (ref.test (ref $Rational) (local.get $x))
               (then (return (i32.const 0))))
           (call $integer-zero?/i32 (local.get $x)))

     ;; $exact-rational-abs : exact-rational? -> exact-rational?
     ;;   Return the absolute value of an exact rational.
     (func $exact-rational-abs
           (param $x (ref eq))
           (result (ref eq))

           (local $q (ref $Rational))

           ;; For rationals, take the absolute value of the numerator.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $x)))
                (return
                 (call $rational-normalize
                       (call $integer-abs
                             (struct.get $Rational $num (local.get $q)))
                       (struct.get $Rational $den (local.get $q))))))

           ;; Exact integers delegate to integer absolute value.
           (call $integer-abs (local.get $x)))

     ;; $exact-rational-negate : exact-rational? -> exact-rational?
     ;;   Return the exact additive inverse.
     (func $exact-rational-negate
           (param $x (ref eq))
           (result (ref eq))

           (local $q (ref $Rational))

           ;; For rationals, negate the numerator and keep the denominator.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $x)))
                (return
                 (call $rational-normalize
                       (call $integer-negate
                             (struct.get $Rational $num (local.get $q)))
                       (struct.get $Rational $den (local.get $q))))))

           ;; Exact integers delegate to integer negation.
           (call $integer-negate (local.get $x)))

     ;; $exact-rational-sign/i32 : exact-rational? -> i32
     ;;   Return -1, 0, or 1 according to x's sign.
     (func $exact-rational-sign/i32
           (param $x (ref eq))
           (result i32)

           ;; The denominator is always positive, so the numerator decides.
           (call $integer-sign/i32
                 (call $exact-rational-numerator (local.get $x))))

     ;; $exact-rational-half?/i32 : any/c -> i32
     ;;   Return 1 when x is exactly 1/2, otherwise 0.
     (func $exact-rational-half?/i32
           (param $x (ref eq))
           (result i32)

           ;; In tagged fixnum encoding, 1 is i31 payload 2 and 2 is payload 4.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (return
                 (i32.and
                  (i32.eqz
                   (call $integer-compare/i32
                         (struct.get $Rational $num
                                     (ref.cast (ref $Rational) (local.get $x)))
                         (ref.i31 (i32.const 2))))
                  (i32.eqz
                   (call $integer-compare/i32
                         (struct.get $Rational $den
                                     (ref.cast (ref $Rational) (local.get $x)))
                         (ref.i31 (i32.const 4))))))))
           (i32.const 0))

     ;;;
     ;;; Simplest Rationals and Rationalize
     ;;;

     ;; The "simplest" rational in an interval is found by the usual
     ;; continued-fraction recurrence. For a positive interval [x, y],
     ;; let k = floor(x).
     ;;
     ;; If x is exactly k, then k is simplest.
     ;; If floor(x) < floor(y), then k+1 is simplest.
     ;; Otherwise x and y have the same integer part, and
     ;;
     ;;     simplest(x, y)
     ;;       = k + 1 / simplest(1/(y-k), 1/(x-k))
     ;;
     ;; The reciprocal reverses the fractional interval, so the arguments swap.

     ;; $exact-rational-simplest-positive : exact-rational? exact-rational? -> exact-rational?
     ;;   Return the simplest rational in the positive interval [x, y].
     (func $exact-rational-simplest-positive
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $fx     (ref eq))
           (local $fy     (ref eq))
           (local $x-frac (ref eq))
           (local $y-frac (ref eq))
           (local $inner  (ref eq))

           (local.set $fx     (ref.i31 (i32.const 0)))
           (local.set $fy     (ref.i31 (i32.const 0)))
           (local.set $x-frac (ref.i31 (i32.const 0)))
           (local.set $y-frac (ref.i31 (i32.const 0)))
           (local.set $inner  (ref.i31 (i32.const 2)))

           ;; If x is already an integer, it is the simplest value in the interval.
           (local.set $fx (call $exact-rational-floor (local.get $x)))
           (if (i32.eqz
                (call $exact-rational-compare/i32
                      (local.get $x)
                      (local.get $fx)))
               (then (return (local.get $fx))))

           ;; If the interval crosses an integer boundary, use the first integer.
           (local.set $fy (call $exact-rational-floor (local.get $y)))
           (if (i32.ne
                (call $integer-compare/i32
                      (local.get $fx)
                      (local.get $fy))
                (i32.const 0))
               (then
                (return
                 (call $integer-add/2
                       (local.get $fx)
                       (ref.i31 (i32.const 2))))))

           ;; Remove the common integer part to get a fractional interval.
           (local.set $x-frac
                      (call $exact-rational-sub/2
                            (local.get $x)
                            (local.get $fx)))
           (local.set $y-frac
                      (call $exact-rational-sub/2
                            (local.get $y)
                            (local.get $fx)))

           ;; Recurse on the reciprocal interval and invert the result back.
           (local.set $inner
                      (call $exact-rational-simplest-between
                            (call $exact-rational-div/2
                                  (ref.i31 (i32.const 2))
                                  (local.get $y-frac))
                            (call $exact-rational-div/2
                                  (ref.i31 (i32.const 2))
                                  (local.get $x-frac))))
           (call $exact-rational-add/2
                 (local.get $fx)
                 (call $exact-rational-div/2
                       (ref.i31 (i32.const 2))
                       (local.get $inner))))

     ;; The general interval case reduces to the positive case:
     ;;
     ;;     lo > 0         ->  simplest-positive( lo,  hi)
     ;;     hi < 0         -> -simplest-positive(-hi, -lo)
     ;;     lo <= 0 <= hi  ->  0
     ;;
     ;; The negative case negates and swaps endpoints because negation
     ;; reverses the order of an interval.

     ;; $exact-rational-simplest-between : exact-rational? exact-rational? -> exact-rational?
     ;;   Return the simplest rational in the closed interval [lo, hi].
     (func $exact-rational-simplest-between
           (param $lo (ref eq))
           (param $hi (ref eq))
           (result (ref eq))

           (local $tmp (ref eq))
           (local $neg-lo (ref eq))
           (local $neg-hi (ref eq))

           (local.set $tmp    (ref.i31 (i32.const 0)))
           (local.set $neg-lo (ref.i31 (i32.const 0)))
           (local.set $neg-hi (ref.i31 (i32.const 0)))

           ;; Accept endpoints in either order by swapping them if needed.
           (if (i32.gt_s
                (call $exact-rational-compare/i32
                      (local.get $lo)
                      (local.get $hi))
                (i32.const 0))
               (then
                (local.set $tmp (local.get $lo))
                (local.set $lo  (local.get $hi))
                (local.set $hi  (local.get $tmp))))

           ;; A zero-width interval has only one possible answer.
           (if (i32.eqz
                (call $exact-rational-compare/i32
                      (local.get $lo)
                      (local.get $hi)))
               (then (return (local.get $lo))))

           ;; Positive intervals use the continued-fraction recurrence.
           (if (i32.gt_s (call $exact-rational-sign/i32 (local.get $lo))
                         (i32.const 0))
               (then
                (return
                 (call $exact-rational-simplest-positive
                       (local.get $lo)
                       (local.get $hi)))))

           ;; Negative intervals are solved by negating to a positive interval.
           (if (i32.lt_s (call $exact-rational-sign/i32 (local.get $hi))
                         (i32.const 0))
               (then
                (local.set $neg-hi
                           (call $exact-rational-negate (local.get $hi)))
                (local.set $neg-lo
                           (call $exact-rational-negate (local.get $lo)))
                (return
                 (call $exact-rational-negate
                       (call $exact-rational-simplest-positive
                             (local.get $neg-hi)
                             (local.get $neg-lo))))))

           ;; Any interval that contains zero has zero as its simplest value.
           (ref.i31 (i32.const 0)))

     ;; Rationalize first builds the tolerance interval
     ;;
     ;;     [x - abs(tolerance), x + abs(tolerance)]
     ;;
     ;; and then returns the simplest rational in that interval.
     ;; $exact-rational-rationalize : exact-rational? exact-rational? -> exact-rational?
     ;;   Return the simplest rational within abs(tolerance) of x.
     (func $exact-rational-rationalize
           (param $x         (ref eq))
           (param $tolerance (ref eq))
           (result (ref eq))

           (local $t  (ref eq))
           (local $lo (ref eq))
           (local $hi (ref eq))

           (local.set $t  (ref.i31 (i32.const 0)))
           (local.set $lo (ref.i31 (i32.const 0)))
           (local.set $hi (ref.i31 (i32.const 0)))

           ;; Use the absolute tolerance to form the low and high endpoints.
           (local.set $t (call $exact-rational-abs (local.get $tolerance)))
           (local.set $lo
                      (call $exact-rational-sub/2
                            (local.get $x)
                            (local.get $t)))
           (local.set $hi
                      (call $exact-rational-add/2
                            (local.get $x)
                            (local.get $t)))
           (call $exact-rational-simplest-between
                 (local.get $lo)
                 (local.get $hi)))

     ;;;
     ;;; Rounding Exact Rationals
     ;;;

     ;; $exact-rational-truncate : exact-rational? -> exact-integer?
     ;;   Truncate x toward zero.
     (func $exact-rational-truncate
           (param $x (ref eq))
           (result (ref eq))

           (local $q    (ref $Rational))
           (local $vals (ref $Values))

           ;; Integer division already returns the quotient truncated toward zero.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $x)))
                (local.set $vals
                           (call $integer-divmod
                                 (struct.get $Rational $num (local.get $q))
                                 (struct.get $Rational $den (local.get $q))))
                (return
                 (array.get $Values
                            (local.get $vals)
                            (i32.const 0)))))

           ;; Exact integers are already rounded.
           (local.get $x))

     ;; Floor starts with truncating division:
     ;;
     ;;     num = q*den + r
     ;;
     ;; Since den is positive, a negative nonzero remainder means truncation
     ;; rounded upward, so the floor is q-1.

     ;; $exact-rational-floor : exact-rational? -> exact-integer?
     ;;   Round x toward negative infinity.
     (func $exact-rational-floor
           (param $x (ref eq))
           (result (ref eq))

           (local $rat  (ref $Rational))
           (local $vals (ref $Values))
           (local $q    (ref eq))
           (local $r    (ref eq))

           ;; Divide the numerator by the positive denominator.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $rat (ref.cast (ref $Rational) (local.get $x)))
                (local.set $vals
                           (call $integer-divmod
                                 (struct.get $Rational $num (local.get $rat))
                                 (struct.get $Rational $den (local.get $rat))))
                (local.set $q
                           (array.get $Values
                                      (local.get $vals)
                                      (i32.const 0)))
                (local.set $r
                           (array.get $Values
                                      (local.get $vals)
                                      (i32.const 1)))

                ;; Negative remainder means q is one greater than the floor.
                (if (i32.lt_s (call $integer-sign/i32 (local.get $r))
                              (i32.const 0))
                    (then
                     (return
                      (call $integer-sub/2
                            (local.get $q)
                            (ref.i31 (i32.const 2))))))
                (return (local.get $q))))

           ;; Exact integers are already rounded.
           (local.get $x))

     ;; Ceiling is the mirror of floor. A positive nonzero remainder means
     ;; truncation rounded downward, so the ceiling is q+1.

     ;; $exact-rational-ceiling : exact-rational? -> exact-integer?
     ;;   Round x toward positive infinity.
     (func $exact-rational-ceiling
           (param $x (ref eq))
           (result (ref eq))

           (local $rat  (ref $Rational))
           (local $vals (ref $Values))
           (local $q    (ref eq))
           (local $r    (ref eq))

           ;; Divide the numerator by the positive denominator.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $rat (ref.cast (ref $Rational) (local.get $x)))
                (local.set $vals
                           (call $integer-divmod
                                 (struct.get $Rational $num (local.get $rat))
                                 (struct.get $Rational $den (local.get $rat))))
                (local.set $q
                           (array.get $Values
                                      (local.get $vals)
                                      (i32.const 0)))
                (local.set $r
                           (array.get $Values
                                      (local.get $vals)
                                      (i32.const 1)))

                ;; Positive remainder means q is one less than the ceiling.
                (if (i32.gt_s (call $integer-sign/i32 (local.get $r))
                              (i32.const 0))
                    (then
                     (return
                      (call $integer-add/2
                            (local.get $q)
                            (ref.i31 (i32.const 2))))))
                (return (local.get $q))))

           ;; Exact integers are already rounded.
           (local.get $x))

     ;; Round also starts from
     ;;
     ;;     num = q*den + r
     ;;
     ;; Then it compares abs(r) with den/2 by comparing 2*abs(r) with den.
     ;; If the fraction is exactly half, the even quotient wins.

     ;; $exact-rational-round : exact-rational? -> exact-integer?
     ;;   Round x to the nearest integer, choosing even integers on ties.
     (func $exact-rational-round
           (param $x (ref eq))
           (result (ref eq))

           (local $rat   (ref $Rational))
           (local $vals  (ref $Values))
           (local $q     (ref eq))
           (local $r     (ref eq))
           (local $abs-r (ref eq))
           (local $step  (ref eq))
           (local $cmp   i32)

           ;; Divide the numerator by the positive denominator.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $rat (ref.cast (ref $Rational) (local.get $x)))
                (local.set $vals
                           (call $integer-divmod
                                 (struct.get $Rational $num (local.get $rat))
                                 (struct.get $Rational $den (local.get $rat))))
                (local.set $q
                           (array.get $Values
                                      (local.get $vals)
                                      (i32.const 0)))
                (local.set $r
                           (array.get $Values
                                      (local.get $vals)
                                      (i32.const 1)))

                ;; No remainder means the quotient is already exact.
                (if (call $integer-zero?/i32 (local.get $r))
                    (then (return (local.get $q))))

                ;; Compare the distance to q with the halfway point.
                (local.set $abs-r (call $integer-abs (local.get $r)))
                (local.set $cmp
                           (call $integer-compare/i32
                                 (call $integer-add/2
                                       (local.get $abs-r)
                                       (local.get $abs-r))
                                 (struct.get $Rational $den (local.get $rat))))

                ;; Less than half rounds toward q.
                (if (i32.lt_s (local.get $cmp) (i32.const 0))
                    (then (return (local.get $q))))

                ;; The correction step follows the sign of the remainder.
                (local.set $step
                           (ref.i31
                            (i32.shl
                             (call $integer-sign/i32 (local.get $r))
                             (i32.const 1))))

                ;; Greater than half rounds away from q.
                (if (i32.gt_s (local.get $cmp) (i32.const 0))
                    (then
                     (return
                      (call $integer-add/2
                            (local.get $q)
                            (local.get $step)))))

                ;; Exactly half rounds to the even integer.
                (if (call $integer-even?/i32 (local.get $q))
                    (then (return (local.get $q))))
                (return
                 (call $integer-add/2
                       (local.get $q)
                       (local.get $step)))))

           ;; Exact integers are already rounded.
           (local.get $x))

     ;; $exact-rational-numerator : exact-rational? -> exact-integer?
     ;;   Return the numerator, using the integer itself for exact integers.
     (func $exact-rational-numerator
           (param $x (ref eq))
           (result (ref eq))

           ;; Boxed rationals store the canonical numerator explicitly.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (return
                 (struct.get $Rational $num
                             (ref.cast (ref $Rational) (local.get $x))))))

           ;; For exact integers, the numerator is the integer itself.
           (local.get $x))

     ;; $exact-rational-denominator : exact-rational? -> exact-positive-integer?
     ;;   Return the denominator, using 1 for exact integers.
     (func $exact-rational-denominator
           (param $x (ref eq))
           (result (ref eq))

           ;; Boxed rationals store the canonical positive denominator.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (return
                 (struct.get $Rational $den
                             (ref.cast (ref $Rational) (local.get $x))))))

           ;; For exact integers, the denominator is 1.
           (ref.i31 (i32.const 2)))

     ;;;
     ;;; Exact and Inexact Conversion
     ;;;

     ;; $integer-shl/nonnegative : exact-nonnegative-integer? i32 -> exact-nonnegative-integer?
     ;;   Shift x left by shift bits; shift must be nonnegative.
     (func $integer-shl/nonnegative
           (param $x     (ref eq))
           (param $shift i32)
           (result (ref eq))

           ;; A zero shift leaves x unchanged.
           (if (i32.eqz (local.get $shift))
               (then (return (local.get $x))))

           ;; Shift left by multiplying by 2^shift.
           (call $integer-mul/2
                 (local.get $x)
                 (call $u64-shl->integer
                       (i64.const 1)
                       (local.get $shift))))

     ;; $integer-nonnegative->u64 : exact-nonnegative-integer? -> i64
     ;;   Convert a known-small nonnegative integer to an unsigned i64 payload.
     (func $integer-nonnegative->u64
           (param $x (ref eq))
           (result i64)

           ;; Reassemble the low two base-2^32 limbs into one unsigned i64.
           (i64.or
            (i64.extend_i32_u
             (call $integer-nonnegative-limb/u32
                   (local.get $x)
                   (i32.const 0)))
            (i64.shl
             (i64.extend_i32_u
              (call $integer-nonnegative-limb/u32
                    (local.get $x)
                    (i32.const 1)))
             (i64.const 32))))

     ;; Compare num/den with a power of two by cross multiplication:
     ;;
     ;;     e >= 0: compare num with den*2^e
     ;;     e <  0: compare num*2^(-e) with den

     ;; $positive-rational-power2-compare/i32 : exact-positive-integer? exact-positive-integer? i32 -> integer?
     ;;   Compare num/den with 2^e, returning -1, 0, or 1.
     (func $positive-rational-power2-compare/i32
           (param $num (ref eq))
           (param $den (ref eq))
           (param $e   i32)
           (result i32)

           ;; For nonnegative e, shift the denominator side.
           (if (i32.ge_s (local.get $e) (i32.const 0))
               (then
                (return
                 (call $integer-compare/i32
                       (local.get $num)
                       (call $integer-shl/nonnegative
                             (local.get $den)
                             (local.get $e))))))

           ;; For negative e, shift the numerator side by -e.
           (call $integer-compare/i32
                 (call $integer-shl/nonnegative
                       (local.get $num)
                       (i32.sub (i32.const 0) (local.get $e)))
                 (local.get $den)))

     ;; Scaled rounding computes
     ;;
     ;;     round-even(num * 2^shift / den)
     ;;
     ;; without leaving exact integer arithmetic. A negative shift is moved to
     ;; the denominator:
     ;;
     ;;     num * 2^shift / den = num / (den * 2^(-shift))

     ;; $exact-rational-scaled-round : exact-nonnegative-integer? exact-positive-integer? i32 -> exact-nonnegative-integer?
     ;;   Return round-to-even(num * 2^shift / den).
     (func $exact-rational-scaled-round
           (param $num   (ref eq))
           (param $den   (ref eq))
           (param $shift i32)
           (result (ref eq))

           (local $n       (ref eq))
           (local $d       (ref eq))
           (local $vals    (ref $Values))
           (local $q       (ref eq))
           (local $r       (ref eq))
           (local $twice-r (ref eq))
           (local $cmp     i32)

           (local.set $n (local.get $num))
           (local.set $d (local.get $den))

           ;; Positive shifts multiply the numerator by a power of two.
           (if (i32.gt_s (local.get $shift) (i32.const 0))
               (then
                (local.set $n
                           (call $integer-shl/nonnegative
                                 (local.get $n)
                                 (local.get $shift)))))

           ;; Negative shifts multiply the denominator by a power of two.
           (if (i32.lt_s (local.get $shift) (i32.const 0))
               (then
                (local.set $d
                           (call $integer-shl/nonnegative
                                 (local.get $d)
                                 (i32.sub (i32.const 0)
                                          (local.get $shift))))))

           ;; Divide the scaled numerator by the scaled denominator.
           (local.set $vals
                      (call $integer-divmod
                            (local.get $n)
                            (local.get $d)))
           (local.set $q
                      (array.get $Values
                                 (local.get $vals)
                                 (i32.const 0)))
           (local.set $r
                      (array.get $Values
                                 (local.get $vals)
                                 (i32.const 1)))

           ;; Exact division needs no rounding.
           (if (call $integer-zero?/i32 (local.get $r))
               (then (return (local.get $q))))

           ;; Compare the remainder with half of the denominator.
           (local.set $twice-r
                      (call $integer-add/2
                            (local.get $r)
                            (local.get $r)))
           (local.set $cmp
                      (call $integer-compare/i32
                            (local.get $twice-r)
                            (local.get $d)))

           ;; Below half rounds down.
           (if (i32.lt_s (local.get $cmp) (i32.const 0))
               (then (return (local.get $q))))

           ;; Above half rounds up.
           (if (i32.gt_s (local.get $cmp) (i32.const 0))
               (then
                (return
                 (call $integer-add/2
                       (local.get $q)
                       (ref.i31 (i32.const 2))))))

           ;; Exactly half rounds to even.
           (if (call $integer-even?/i32 (local.get $q))
               (then (return (local.get $q))))
           (call $integer-add/2
                 (local.get $q)
                 (ref.i31 (i32.const 2))))

     ;; Convert a positive rational r = num/den to f64 by first finding
     ;; the binary exponent e such that
     ;;
     ;;     2^e <= r < 2^(e+1)
     ;;
     ;; Normal results round the 53-bit significand:
     ;;
     ;;     mantissa = round-even(r * 2^(52-e))
     ;;
     ;; Subnormal results round directly into the low bits:
     ;;
     ;;     mantissa = round-even(r * 2^1074)
     ;;
     ;; The rounding helper handles the halfway-to-even rule.

     ;; $positive-rational->f64 : exact-positive-integer? exact-positive-integer? -> f64
     ;;   Convert a positive exact rational to a correctly rounded f64.
     (func $positive-rational->f64
           (param $num (ref eq))
           (param $den (ref eq))
           (result f64)

           (local $e        i32)
           (local $q        (ref eq))
           (local $mantissa i64)
           (local $bits     i64)

           ;; Positive zero converts directly to f64 zero.
           (if (call $integer-zero?/i32 (local.get $num))
               (then (return (f64.const 0.0))))

           ;; Use bit lengths for an initial exponent estimate.
           (local.set $e
                      (i32.sub
                       (call $integer-nonnegative-bit-length/i32
                             (local.get $num))
                       (call $integer-nonnegative-bit-length/i32
                             (local.get $den))))

           ;; Correct the estimate if num/den is below 2^e.
           (if (i32.lt_s
                (call $positive-rational-power2-compare/i32
                      (local.get $num)
                      (local.get $den)
                      (local.get $e))
                (i32.const 0))
               (then
                (local.set $e
                           (i32.sub (local.get $e) (i32.const 1)))))

           ;; Exponents above the f64 maximum overflow to infinity.
           (if (i32.gt_s (local.get $e) (i32.const 1023))
               (then (return (f64.const +inf))))

           ;; Subnormal numbers and the rounded transition to the minimum normal.
           (if (i32.lt_s (local.get $e) (i32.const -1022))
               (then
                ;; Scale by 2^1074 so one integer unit is one subnormal ulp.
                (local.set $q
                           (call $exact-rational-scaled-round
                                 (local.get $num)
                                 (local.get $den)
                                 (i32.const 1074)))
                (local.set $mantissa
                           (call $integer-nonnegative->u64
                                 (local.get $q)))

                ;; Rounding can underflow to zero.
                (if (i64.eqz (local.get $mantissa))
                    (then (return (f64.const 0.0))))

                ;; Rounding can also cross into the minimum normal number.
                (if (i64.ge_u (local.get $mantissa)
                              (i64.const 4503599627370496))
                    (then
                     (local.set $bits
                                (i64.or
                                 (i64.const 4503599627370496)
                                 (i64.sub
                                  (local.get $mantissa)
                                  (i64.const 4503599627370496)))))
                    (else (local.set $bits (local.get $mantissa))))
                (return (f64.reinterpret_i64 (local.get $bits)))))

           ;; For normal numbers, round the 53-bit significand.
           (local.set $q
                      (call $exact-rational-scaled-round
                            (local.get $num)
                            (local.get $den)
                            (i32.sub (i32.const 52) (local.get $e))))
           (local.set $mantissa
                      (call $integer-nonnegative->u64
                            (local.get $q)))

           ;; A rounded significand of 2^53 carries into the exponent.
           (if (i64.eq (local.get $mantissa)
                       (i64.const 9007199254740992))
               (then
                (local.set $mantissa (i64.const 4503599627370496))
                (local.set $e (i32.add (local.get $e) (i32.const 1)))
                (if (i32.gt_s (local.get $e) (i32.const 1023))
                    (then (return (f64.const +inf))))))

           ;; Pack signless normal bits: biased exponent plus fraction bits.
           (local.set $bits
                      (i64.or
                       (i64.shl
                        (i64.extend_i32_u
                         (i32.add (local.get $e) (i32.const 1023)))
                        (i64.const 52))
                       (i64.sub
                       (local.get $mantissa)
                        (i64.const 4503599627370496))))
           (f64.reinterpret_i64 (local.get $bits)))

     ;; Signed exact rationals convert by converting the absolute value, then
     ;; restoring the sign. Exact integers are the denominator-1 case.

     ;; $exact-rational->f64 : exact-rational? -> f64
     ;;   Convert an exact rational to a correctly rounded f64.
     (func $exact-rational->f64
           (param $x (ref eq))
           (result f64)

           (local $q    (ref $Rational))
           (local $num  (ref eq))
           (local $den  (ref eq))
           (local $sign i32)
           (local $out  f64)

           ;; Boxed rationals provide both numerator and denominator.
           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $x)))
                (local.set $num (struct.get $Rational $num (local.get $q)))
                (local.set $den (struct.get $Rational $den (local.get $q)))
                (local.set $sign (call $integer-sign/i32 (local.get $num)))
                (local.set $out
                           (call $positive-rational->f64
                                 (call $integer-abs (local.get $num))
                                 (local.get $den)))
                (if (i32.lt_s (local.get $sign) (i32.const 0))
                    (then (return (f64.neg (local.get $out)))))
                (return (local.get $out))))

           ;; Exact integers delegate to the integer conversion path.
           (call $integer->f64 (local.get $x)))

     ;; Decode a finite f64 as
     ;;
     ;;     x = (-1)^sign * mantissa * 2^shift
     ;;
     ;; For normal numbers, mantissa includes the hidden 2^52 bit and
     ;; shift = exponent - 1075. For subnormal numbers, there is no hidden
     ;; bit and shift = -1074.

     ;; $f64->exact-rational : finite-flonum? -> exact-rational?
     ;;   Convert a finite f64 to its exact binary rational value.
     (func $f64->exact-rational
           (param $x f64)
           (result (ref eq))

           (local $bits     i64)
           (local $exp      i32)
           (local $shift    i32)
           (local $mantissa i64)
           (local $num      (ref eq))
           (local $den      (ref eq))

           ;; Extract the raw IEEE-754 exponent field.
           (local.set $bits (i64.reinterpret_f64 (local.get $x)))
           (local.set $exp
                      (i32.wrap_i64
                       (i64.and
                        (i64.shr_u (local.get $bits) (i64.const 52))
                        (i64.const 2047))))

           ;; Decode subnormal and normal significands.
           (if (i32.eqz (local.get $exp))
               (then
                (local.set $mantissa
                           (i64.and
                            (local.get $bits)
                            (i64.const 4503599627370495)))
                (if (i64.eqz (local.get $mantissa))
                    (then (return (ref.i31 (i32.const 0)))))
                (local.set $shift (i32.const -1074)))
               (else
                (local.set $mantissa
                           (i64.or
                            (i64.and
                             (local.get $bits)
                             (i64.const 4503599627370495))
                            (i64.const 4503599627370496)))
                (local.set $shift
                           (i32.sub (local.get $exp) (i32.const 1075)))))

           ;; Nonnegative shifts produce exact integers.
           (if (i32.ge_s (local.get $shift) (i32.const 0))
               (then
                (local.set $num
                           (call $u64-shl->integer
                                 (local.get $mantissa)
                                 (local.get $shift)))
                (if (i64.ne (i64.shr_u (local.get $bits) (i64.const 63))
                            (i64.const 0))
                    (then (return (call $integer-negate (local.get $num)))))
                (return (local.get $num))))

           ;; Negative shifts produce mantissa / 2^(-shift).
           (local.set $num (call $u64-shl->integer
                                 (local.get $mantissa)
                                 (i32.const 0)))

           ;; Apply the sign bit to the numerator.
           (if (i64.ne (i64.shr_u (local.get $bits) (i64.const 63))
                       (i64.const 0))
               (then
                (local.set $num (call $integer-negate (local.get $num)))))

           ;; Build the power-of-two denominator and normalize the result.
           (local.set $den
                      (call $u64-shl->integer
                            (i64.const 1)
                            (i32.sub (i32.const 0) (local.get $shift))))
           (call $rational-normalize
                 (local.get $num)
                 (local.get $den)))

     ;; $exact-rational-flonum-compare/i32 : exact-rational? flonum? -> integer?
     ;;   Compare an exact rational against a flonum's exact binary value.
     ;;   Return 2 for unordered NaN comparisons.
     (func $exact-rational-flonum-compare/i32
           (param $x    (ref eq))
           (param $y/fl (ref $Flonum))
           (result i32)

           (local $y f64)

           (local.set $y (struct.get $Flonum $v (local.get $y/fl)))

           ;; NaN is unordered; infinities compare without exact conversion.
           (if (f64.ne (local.get $y) (local.get $y))
               (then (return (i32.const 2))))
           (if (f64.eq (local.get $y) (f64.const +inf))
               (then (return (i32.const -1))))
           (if (f64.eq (local.get $y) (f64.const -inf))
               (then (return (i32.const 1))))

           ;; Finite flonums compare exactly after decoding to a rational.
           (call $exact-rational-compare/i32
                 (local.get $x)
                 (call $f64->exact-rational (local.get $y))))

     ;;;
     ;;; Exact Rational Arithmetic
     ;;;

     ;; Addition first removes the gcd of the denominators:
     ;;
     ;;     g  = gcd(b,d)
     ;;     b1 = b/g
     ;;     d1 = d/g
     ;;     t  = a*d1 + c*b1
     ;;     h  = gcd(abs(t),g)
     ;;
     ;; Then the reduced result is
     ;;
     ;;     (t/h) / (b1*(d/h))

     ;; $exact-rational-add/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Add exact rational values after cancelling shared denominator factors.
     (func $exact-rational-add/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-num (ref eq))
           (local $x-den (ref eq))
           (local $y-num (ref eq))
           (local $y-den (ref eq))
           (local $g     (ref eq))
           (local $b1    (ref eq))
           (local $d1    (ref eq))
           (local $t     (ref eq))
           (local $h     (ref eq))
           (local $vals  (ref $Values))

           ;; Extract integer numerators and denominators; integers use den = 1.
           (local.set $x-num (call $exact-rational-numerator (local.get $x)))
           (local.set $x-den (call $exact-rational-denominator (local.get $x)))
           (local.set $y-num (call $exact-rational-numerator (local.get $y)))
           (local.set $y-den (call $exact-rational-denominator (local.get $y)))

           ;; Split the denominators into coprime pieces around their gcd.
           (local.set $g (call $integer-gcd
                               (local.get $x-den)
                               (local.get $y-den)))
           (local.set $vals (call $integer-divmod
                                  (local.get $x-den)
                                  (local.get $g)))
           (local.set $b1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-den)
                                  (local.get $g)))
           (local.set $d1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))

           ;; Build the reduced cross numerator using b1 and d1.
           (local.set $t
                      (call $integer-add/2
                            (call $integer-mul/2
                                  (local.get $x-num)
                                  (local.get $d1))
                            (call $integer-mul/2
                                  (local.get $y-num)
                                  (local.get $b1))))

           ;; Remove any factor of g that survived in the new numerator.
           (local.set $h (call $integer-gcd
                               (call $integer-abs (local.get $t))
                               (local.get $g)))
           (local.set $vals (call $integer-divmod
                                  (local.get $t)
                                  (local.get $h)))
           (local.set $t (array.get $Values
                                    (local.get $vals)
                                    (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-den)
                                  (local.get $h)))

           ;; Normalize the reduced numerator over b1*(d/h).
           (call $rational-normalize
                 (local.get $t)
                 (call $integer-mul/2
                       (local.get $b1)
                       (array.get $Values
                                  (local.get $vals)
                                  (i32.const 0)))))

     ;; Subtraction uses the same reduced-denominator formula as addition:
     ;;
     ;;     g  = gcd(b,d)
     ;;     b1 = b/g
     ;;     d1 = d/g
     ;;     t  = a*d1 - c*b1
     ;;     h  = gcd(abs(t),g)
     ;;
     ;; and returns
     ;;
     ;;     (t/h) / (b1*(d/h))

     ;; $exact-rational-sub/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Subtract exact rational values after cancelling shared denominator factors.
     (func $exact-rational-sub/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-num (ref eq))
           (local $x-den (ref eq))
           (local $y-num (ref eq))
           (local $y-den (ref eq))
           (local $g     (ref eq))
           (local $b1    (ref eq))
           (local $d1    (ref eq))
           (local $t     (ref eq))
           (local $h     (ref eq))
           (local $vals  (ref $Values))

           ;; Extract integer numerators and denominators; integers use den = 1.
           (local.set $x-num (call $exact-rational-numerator (local.get $x)))
           (local.set $x-den (call $exact-rational-denominator (local.get $x)))
           (local.set $y-num (call $exact-rational-numerator (local.get $y)))
           (local.set $y-den (call $exact-rational-denominator (local.get $y)))

           ;; Split the denominators into coprime pieces around their gcd.
           (local.set $g (call $integer-gcd
                               (local.get $x-den)
                               (local.get $y-den)))
           (local.set $vals (call $integer-divmod
                                  (local.get $x-den)
                                  (local.get $g)))
           (local.set $b1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-den)
                                  (local.get $g)))
           (local.set $d1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))

           ;; Build the reduced cross numerator using b1 and d1.
           (local.set $t
                      (call $integer-sub/2
                            (call $integer-mul/2
                                  (local.get $x-num)
                                  (local.get $d1))
                            (call $integer-mul/2
                                  (local.get $y-num)
                                  (local.get $b1))))

           ;; Remove any factor of g that survived in the new numerator.
           (local.set $h (call $integer-gcd
                               (call $integer-abs (local.get $t))
                               (local.get $g)))
           (local.set $vals (call $integer-divmod
                                  (local.get $t)
                                  (local.get $h)))
           (local.set $t (array.get $Values
                                    (local.get $vals)
                                    (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-den)
                                  (local.get $h)))

           ;; Normalize the reduced numerator over b1*(d/h).
           (call $rational-normalize
                 (local.get $t)
                 (call $integer-mul/2
                       (local.get $b1)
                       (array.get $Values
                                  (local.get $vals)
                                  (i32.const 0)))))

     ;; Multiplication cross-cancels before multiplying:
     ;;
     ;;     g1 = gcd(abs(a),d)
     ;;     g2 = gcd(abs(c),b)
     ;;
     ;; so the products are
     ;;
     ;;     ((a/g1)*(c/g2)) / ((b/g2)*(d/g1))

     ;; $exact-rational-mul/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Multiply exact rational values after cross-cancelling factors.
     (func $exact-rational-mul/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-num (ref eq))
           (local $x-den (ref eq))
           (local $y-num (ref eq))
           (local $y-den (ref eq))
           (local $g1    (ref eq))
           (local $g2    (ref eq))
           (local $a1    (ref eq))
           (local $b1    (ref eq))
           (local $c1    (ref eq))
           (local $d1    (ref eq))
           (local $vals  (ref $Values))

           ;; Extract integer numerators and denominators; integers use den = 1.
           (local.set $x-num (call $exact-rational-numerator (local.get $x)))
           (local.set $x-den (call $exact-rational-denominator (local.get $x)))
           (local.set $y-num (call $exact-rational-numerator (local.get $y)))
           (local.set $y-den (call $exact-rational-denominator (local.get $y)))

           ;; Cancel numerator factors against the opposite denominators.
           (local.set $g1 (call $integer-gcd
                                (call $integer-abs (local.get $x-num))
                                (local.get $y-den)))
           (local.set $g2 (call $integer-gcd
                                (call $integer-abs (local.get $y-num))
                                (local.get $x-den)))

           ;; Divide each cancelled component before building products.
           (local.set $vals (call $integer-divmod
                                  (local.get $x-num)
                                  (local.get $g1)))
           (local.set $a1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-den)
                                  (local.get $g1)))
           (local.set $d1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-num)
                                  (local.get $g2)))
           (local.set $c1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $x-den)
                                  (local.get $g2)))
           (local.set $b1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))

           ;; Normalize after multiplying so integers and reduced rationals collapse.
           (call $rational-normalize
                 (call $integer-mul/2
                       (local.get $a1)
                       (local.get $c1))
                 (call $integer-mul/2
                       (local.get $b1)
                       (local.get $d1))))

     ;; Division multiplies by the reciprocal, but first cross-cancels:
     ;;
     ;;     g1 = gcd(abs(a),abs(c))
     ;;     g2 = gcd(d,b)
     ;;
     ;; so the products are
     ;;
     ;;     ((a/g1)*(d/g2)) / ((b/g2)*(c/g1))

     ;; $exact-rational-div/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Divide exact rational values after cross-cancelling factors.
     (func $exact-rational-div/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-num (ref eq))
           (local $x-den (ref eq))
           (local $y-num (ref eq))
           (local $y-den (ref eq))
           (local $g1    (ref eq))
           (local $g2    (ref eq))
           (local $a1    (ref eq))
           (local $b1    (ref eq))
           (local $c1    (ref eq))
           (local $d1    (ref eq))
           (local $vals  (ref $Values))

           ;; Division by exact zero is an error.
           (if (call $exact-rational-zero?/i32 (local.get $y))
               (then (call $raise-division-by-zero) (unreachable)))

           ;; Extract integer numerators and denominators; integers use den = 1.
           (local.set $x-num (call $exact-rational-numerator (local.get $x)))
           (local.set $x-den (call $exact-rational-denominator (local.get $x)))
           (local.set $y-num (call $exact-rational-numerator (local.get $y)))
           (local.set $y-den (call $exact-rational-denominator (local.get $y)))

           ;; Cancel numerator and reciprocal factors before multiplying.
           (local.set $g1 (call $integer-gcd
                                (call $integer-abs (local.get $x-num))
                                (call $integer-abs (local.get $y-num))))
           (local.set $g2 (call $integer-gcd
                                (local.get $y-den)
                                (local.get $x-den)))

           ;; Divide each cancelled component before building products.
           (local.set $vals (call $integer-divmod
                                  (local.get $x-num)
                                  (local.get $g1)))
           (local.set $a1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-num)
                                  (local.get $g1)))
           (local.set $c1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $x-den)
                                  (local.get $g2)))
           (local.set $b1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-den)
                                  (local.get $g2)))
           (local.set $d1 (array.get $Values
                                     (local.get $vals)
                                     (i32.const 0)))

           ;; Normalize after multiplying by the reduced reciprocal.
           (call $rational-normalize
                 (call $integer-mul/2
                       (local.get $a1)
                       (local.get $d1))
                 (call $integer-mul/2
                       (local.get $b1)
                       (local.get $c1))))

     ;; Comparison avoids division by cross multiplication:
     ;;
     ;;     a/b < c/d  iff  a*(d/g) < c*(b/g)
     ;;
     ;; where
     ;;
     ;;     g = gcd(b,d)
     ;;
     ;; This is safe because canonical denominators are positive.

     ;; $exact-rational-compare/i32 : exact-rational? exact-rational? -> integer?
     ;;   Compare exact rationals with reduced cross products.
     (func $exact-rational-compare/i32
           (param $x (ref eq))
           (param $y (ref eq))
           (result i32)

           (local $x-num  (ref eq))
           (local $x-den  (ref eq))
           (local $y-num  (ref eq))
           (local $y-den  (ref eq))
           (local $g      (ref eq))
           (local $x-sign i32)
           (local $y-sign i32)
           (local $vals   (ref $Values))

           ;; Extract integer numerators and denominators; integers use den = 1.
           (local.set $x-num (call $exact-rational-numerator (local.get $x)))
           (local.set $x-den (call $exact-rational-denominator (local.get $x)))
           (local.set $y-num (call $exact-rational-numerator (local.get $y)))
           (local.set $y-den (call $exact-rational-denominator (local.get $y)))

           ;; Different signs determine the ordering without multiplication.
           (local.set $x-sign (call $integer-sign/i32 (local.get $x-num)))
           (local.set $y-sign (call $integer-sign/i32 (local.get $y-num)))
           (if (i32.ne (local.get $x-sign) (local.get $y-sign))
               (then
                (return
                 (select
                  (i32.const -1)
                  (i32.const 1)
                  (i32.lt_s (local.get $x-sign) (local.get $y-sign))))))

           ;; Divide out the denominator gcd before cross multiplication.
           (local.set $g (call $integer-gcd
                               (local.get $x-den)
                               (local.get $y-den)))
           (local.set $vals (call $integer-divmod
                                  (local.get $y-den)
                                  (local.get $g)))
           (local.set $y-den (array.get $Values
                                        (local.get $vals)
                                        (i32.const 0)))
           (local.set $vals (call $integer-divmod
                                  (local.get $x-den)
                                  (local.get $g)))
           (local.set $x-den (array.get $Values
                                        (local.get $vals)
                                        (i32.const 0)))

           ;; Compare the reduced cross products as exact integers.
           (call $integer-compare/i32
                 (call $integer-mul/2
                       (local.get $x-num)
                       (local.get $y-den))
                 (call $integer-mul/2
                       (local.get $y-num)
                       (local.get $x-den))))

     ;; For exact rationals,
     ;;
     ;;     gcd(a/b, c/d) = gcd(a, c) / lcm(b, d)
     ;;
     ;; with the result normalized afterward.

     ;; $exact-rational-gcd/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Compute the exact rational GCD using numerator GCD and denominator LCM.
     (func $exact-rational-gcd/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           ;; Pair numerator gcd with denominator lcm.
           (call $rational-normalize
                 (call $integer-gcd
                       (call $exact-rational-numerator (local.get $x))
                       (call $exact-rational-numerator (local.get $y)))
                 (call $integer-lcm
                       (call $exact-rational-denominator (local.get $x))
                       (call $exact-rational-denominator (local.get $y)))))

     ;; For exact rationals,
     ;;
     ;;     lcm(a/b, c/d) = lcm(a, c) / gcd(b, d)
     ;;
     ;; with zero handled first.

     ;; $exact-rational-lcm/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Compute the exact rational LCM using numerator LCM and denominator GCD.
     (func $exact-rational-lcm/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           ;; If either operand is zero, the lcm is zero.
           (if (call $exact-rational-zero?/i32 (local.get $x))
               (then (return (ref.i31 (i32.const 0)))))
           (if (call $exact-rational-zero?/i32 (local.get $y))
               (then (return (ref.i31 (i32.const 0)))))

           ;; Pair numerator lcm with denominator gcd.
           (call $rational-normalize
                 (call $integer-lcm
                       (call $exact-rational-numerator (local.get $x))
                       (call $exact-rational-numerator (local.get $y)))
                 (call $integer-gcd
                       (call $exact-rational-denominator (local.get $x))
                       (call $exact-rational-denominator (local.get $y)))))

     ;;;
     ;;; Equality and Printing
     ;;;

     ;; $rational-eqv? : rational? rational? -> boolean?
     ;;   Compare canonical exact rationals by numerator and denominator.
     (func $rational-eqv?
           (param $x (ref $Rational))
           (param $y (ref $Rational))
           (result (ref eq))

           ;; Since rationals are canonical, equal fields mean equal values.
           (if (i32.eqz
                (call $integer-compare/i32
                      (struct.get $Rational $num (local.get $x))
                      (struct.get $Rational $num (local.get $y))))
               (then
                (if (i32.eqz
                     (call $integer-compare/i32
                           (struct.get $Rational $den (local.get $x))
                           (struct.get $Rational $den (local.get $y))))
                    (then (return (global.get $true))))))
           (global.get $false))

     ;; Printing uses the same radix for both exact integer parts:
     ;;
     ;;     numerator/denominator

     ;; $rational->string : rational? (or/c 2 8 10 16) -> string?
     ;;   Render an exact rational in the requested radix.
     (func $rational->string
           (param $q     (ref $Rational))
           (param $radix i32)
           (result       (ref $String))

           (local $radix-raw (ref eq))
           (local $num-str   (ref $String))
           (local $den-str   (ref $String))

           ;; Convert the raw radix to a tagged fixnum argument.
           (local.set $radix-raw
                      (ref.i31
                       (i32.shl (local.get $radix) (i32.const 1))))

           ;; Render numerator and denominator as exact integers.
           (local.set $num-str
                      (ref.cast
                       (ref $String)
                       (call $number->string
                             (struct.get $Rational $num (local.get $q))
                             (local.get $radix-raw))))
           (local.set $den-str
                      (ref.cast
                       (ref $String)
                       (call $number->string
                             (struct.get $Rational $den (local.get $q))
                             (local.get $radix-raw))))

           ;; Join the pieces with a slash.
           (call $string-append/2
                 (call $string-append/2
                       (local.get $num-str)
                       (ref.cast (ref $String)
                                 (global.get $string:slash)))
                 (local.get $den-str)))
     )))

;; rational-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render rational core helpers in runtime assembly order.
(define (rational-core-runtime-helper-forms helper-index)
  (for/list ([helper (in-list rational-core-runtime-helpers)])
    (core-runtime-helper-form helper-index
                              (core-runtime-helper-name helper))))

;; rational-runtime-only-helpers : (listof core-runtime-helper?)
;;   Rational support is currently core-only.
(define rational-runtime-only-helpers '())
