#lang racket

(provide rational-core-runtime-helpers
         rational-core-runtime-helper-forms
         rational-runtime-only-helpers)

(require "../core-helper.rkt")

;; rational-core-runtime-helpers : (listof core-runtime-helper?)
;;   Runtime support for exact, non-integer rationals.
(define rational-core-runtime-helpers
  (function-forms->runtime-helpers
   'rational-core-runtime-helpers
   '(
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

           (local.set $a (call $integer-abs (local.get $n)))
           (local.set $b (call $integer-abs (local.get $m)))
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

     ;; $integer-lcm : exact-integer? exact-integer? -> exact-nonnegative-integer?
     ;;   Compute a nonnegative least common multiple for exact integers.
     (func $integer-lcm
           (param $n (ref eq))
           (param $m (ref eq))
           (result (ref eq))

           (local $g    (ref eq))
           (local $vals (ref $Values))

           (local.set $n (call $integer-abs (local.get $n)))
           (local.set $m (call $integer-abs (local.get $m)))
           (if (call $integer-zero?/i32 (local.get $n))
               (then (return (ref.i31 (i32.const 0)))))
           (if (call $integer-zero?/i32 (local.get $m))
               (then (return (ref.i31 (i32.const 0)))))
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

           (local.set $num (local.get $num0))
           (local.set $den (local.get $den0))
           (if (call $integer-zero?/i32 (local.get $den))
               (then (unreachable)))
           (if (i32.lt_s (call $integer-sign/i32 (local.get $den))
                         (i32.const 0))
               (then
                (local.set $num (call $integer-negate (local.get $num)))
                (local.set $den (call $integer-negate (local.get $den)))))
           (if (call $integer-zero?/i32 (local.get $num))
               (then (return (ref.i31 (i32.const 0)))))
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
           (if (i32.eqz
                (call $integer-compare/i32
                      (local.get $den)
                      (ref.i31 (i32.const 2))))
               (then (return (local.get $num))))
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

     ;; $exact-rational?/i32 : any/c -> i32
     ;;   Return 1 for exact integers and exact rational values.
     (func $exact-rational?/i32
           (param $x (ref eq))
           (result i32)

           (if (call $fx?/i32 (local.get $x))
               (then (return (i32.const 1))))
           (if (ref.test (ref $Bignum) (local.get $x))
               (then (return (i32.const 1))))
           (ref.test (ref $Rational) (local.get $x)))

     ;; $exact-rational-zero?/i32 : exact-rational? -> i32
     ;;   Return 1 when x is exact zero, otherwise 0.
     (func $exact-rational-zero?/i32
           (param $x (ref eq))
           (result i32)

           (if (ref.test (ref $Rational) (local.get $x))
               (then (return (i32.const 0))))
           (call $integer-zero?/i32 (local.get $x)))

     ;; $exact-rational-abs : exact-rational? -> exact-rational?
     ;;   Return the absolute value of an exact rational.
     (func $exact-rational-abs
           (param $x (ref eq))
           (result (ref eq))

           (local $q (ref $Rational))

           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $x)))
                (return
                 (call $rational-normalize
                       (call $integer-abs
                             (struct.get $Rational $num (local.get $q)))
                       (struct.get $Rational $den (local.get $q))))))
           (call $integer-abs (local.get $x)))

     ;; $exact-rational-negate : exact-rational? -> exact-rational?
     ;;   Return the exact additive inverse.
     (func $exact-rational-negate
           (param $x (ref eq))
           (result (ref eq))

           (local $q (ref $Rational))

           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $x)))
                (return
                 (call $rational-normalize
                       (call $integer-negate
                             (struct.get $Rational $num (local.get $q)))
                       (struct.get $Rational $den (local.get $q))))))
           (call $integer-negate (local.get $x)))

     ;; $exact-rational-sign/i32 : exact-rational? -> i32
     ;;   Return -1, 0, or 1 according to x's sign.
     (func $exact-rational-sign/i32
           (param $x (ref eq))
           (result i32)

           (call $integer-sign/i32
                 (call $exact-rational-numerator (local.get $x))))

     ;; $exact-rational-half?/i32 : any/c -> i32
     ;;   Return 1 when x is exactly 1/2, otherwise 0.
     (func $exact-rational-half?/i32
           (param $x (ref eq))
           (result i32)

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

           (local.set $fx (call $exact-rational-floor (local.get $x)))
           (if (i32.eqz
                (call $exact-rational-compare/i32
                      (local.get $x)
                      (local.get $fx)))
               (then (return (local.get $fx))))
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

           (local.set $x-frac
                      (call $exact-rational-sub/2
                            (local.get $x)
                            (local.get $fx)))
           (local.set $y-frac
                      (call $exact-rational-sub/2
                            (local.get $y)
                            (local.get $fx)))
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

           (if (i32.gt_s
                (call $exact-rational-compare/i32
                      (local.get $lo)
                      (local.get $hi))
                (i32.const 0))
               (then
                (local.set $tmp (local.get $lo))
                (local.set $lo  (local.get $hi))
                (local.set $hi  (local.get $tmp))))
           (if (i32.eqz
                (call $exact-rational-compare/i32
                      (local.get $lo)
                      (local.get $hi)))
               (then (return (local.get $lo))))
           (if (i32.gt_s (call $exact-rational-sign/i32 (local.get $lo))
                         (i32.const 0))
               (then
                (return
                 (call $exact-rational-simplest-positive
                       (local.get $lo)
                       (local.get $hi)))))
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
           (ref.i31 (i32.const 0)))

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

     ;; $exact-rational-truncate : exact-rational? -> exact-integer?
     ;;   Truncate x toward zero.
     (func $exact-rational-truncate
           (param $x (ref eq))
           (result (ref eq))

           (local $q    (ref $Rational))
           (local $vals (ref $Values))

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
           (local.get $x))

     ;; $exact-rational-floor : exact-rational? -> exact-integer?
     ;;   Round x toward negative infinity.
     (func $exact-rational-floor
           (param $x (ref eq))
           (result (ref eq))

           (local $rat  (ref $Rational))
           (local $vals (ref $Values))
           (local $q    (ref eq))
           (local $r    (ref eq))

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
                (if (i32.lt_s (call $integer-sign/i32 (local.get $r))
                              (i32.const 0))
                    (then
                     (return
                      (call $integer-sub/2
                            (local.get $q)
                            (ref.i31 (i32.const 2))))))
                (return (local.get $q))))
           (local.get $x))

     ;; $exact-rational-ceiling : exact-rational? -> exact-integer?
     ;;   Round x toward positive infinity.
     (func $exact-rational-ceiling
           (param $x (ref eq))
           (result (ref eq))

           (local $rat  (ref $Rational))
           (local $vals (ref $Values))
           (local $q    (ref eq))
           (local $r    (ref eq))

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
                (if (i32.gt_s (call $integer-sign/i32 (local.get $r))
                              (i32.const 0))
                    (then
                     (return
                      (call $integer-add/2
                            (local.get $q)
                            (ref.i31 (i32.const 2))))))
                (return (local.get $q))))
           (local.get $x))

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
                (if (call $integer-zero?/i32 (local.get $r))
                    (then (return (local.get $q))))
                (local.set $abs-r (call $integer-abs (local.get $r)))
                (local.set $cmp
                           (call $integer-compare/i32
                                 (call $integer-add/2
                                       (local.get $abs-r)
                                       (local.get $abs-r))
                                 (struct.get $Rational $den (local.get $rat))))
                (if (i32.lt_s (local.get $cmp) (i32.const 0))
                    (then (return (local.get $q))))
                (local.set $step
                           (ref.i31
                            (i32.shl
                             (call $integer-sign/i32 (local.get $r))
                             (i32.const 1))))
                (if (i32.gt_s (local.get $cmp) (i32.const 0))
                    (then
                     (return
                      (call $integer-add/2
                            (local.get $q)
                            (local.get $step)))))
                (if (call $integer-even?/i32 (local.get $q))
                    (then (return (local.get $q))))
                (return
                 (call $integer-add/2
                       (local.get $q)
                       (local.get $step)))))
           (local.get $x))

     ;; $exact-rational-numerator : exact-rational? -> exact-integer?
     ;;   Return the numerator, using the integer itself for exact integers.
     (func $exact-rational-numerator
           (param $x (ref eq))
           (result (ref eq))

           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (return
                 (struct.get $Rational $num
                             (ref.cast (ref $Rational) (local.get $x))))))
           (local.get $x))

     ;; $exact-rational-denominator : exact-rational? -> exact-positive-integer?
     ;;   Return the denominator, using 1 for exact integers.
     (func $exact-rational-denominator
           (param $x (ref eq))
           (result (ref eq))

           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (return
                 (struct.get $Rational $den
                             (ref.cast (ref $Rational) (local.get $x))))))
           (ref.i31 (i32.const 2)))

     ;; $exact-rational->f64 : exact-rational? -> f64
     ;;   Convert an exact rational to f64 for mixed inexact arithmetic.
     (func $exact-rational->f64
           (param $x (ref eq))
           (result f64)

           (local $q (ref $Rational))

           (if (ref.test (ref $Rational) (local.get $x))
               (then
                (local.set $q (ref.cast (ref $Rational) (local.get $x)))
                (return
                 (f64.div
                  (call $integer->f64
                        (struct.get $Rational $num (local.get $q)))
                  (call $integer->f64
                        (struct.get $Rational $den (local.get $q)))))))
           (call $integer->f64 (local.get $x)))

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

           (local.set $bits (i64.reinterpret_f64 (local.get $x)))
           (local.set $exp
                      (i32.wrap_i64
                       (i64.and
                        (i64.shr_u (local.get $bits) (i64.const 52))
                        (i64.const 2047))))
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

           (local.set $num (call $u64-shl->integer
                                 (local.get $mantissa)
                                 (i32.const 0)))
           (if (i64.ne (i64.shr_u (local.get $bits) (i64.const 63))
                       (i64.const 0))
               (then
                (local.set $num (call $integer-negate (local.get $num)))))
           (local.set $den
                      (call $u64-shl->integer
                            (i64.const 1)
                            (i32.sub (i32.const 0) (local.get $shift))))
           (call $rational-normalize
                 (local.get $num)
                 (local.get $den)))

     ;; $exact-rational-add/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Add exact rational values and normalize the result.
     (func $exact-rational-add/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-num (ref eq))
           (local $x-den (ref eq))
           (local $y-num (ref eq))
           (local $y-den (ref eq))

           (local.set $x-num (call $exact-rational-numerator (local.get $x)))
           (local.set $x-den (call $exact-rational-denominator (local.get $x)))
           (local.set $y-num (call $exact-rational-numerator (local.get $y)))
           (local.set $y-den (call $exact-rational-denominator (local.get $y)))
           (call $rational-normalize
                 (call $integer-add/2
                       (call $integer-mul/2 (local.get $x-num) (local.get $y-den))
                       (call $integer-mul/2 (local.get $y-num) (local.get $x-den)))
                 (call $integer-mul/2 (local.get $x-den) (local.get $y-den))))

     ;; $exact-rational-sub/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Subtract exact rational values and normalize the result.
     (func $exact-rational-sub/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-num (ref eq))
           (local $x-den (ref eq))
           (local $y-num (ref eq))
           (local $y-den (ref eq))

           (local.set $x-num (call $exact-rational-numerator (local.get $x)))
           (local.set $x-den (call $exact-rational-denominator (local.get $x)))
           (local.set $y-num (call $exact-rational-numerator (local.get $y)))
           (local.set $y-den (call $exact-rational-denominator (local.get $y)))
           (call $rational-normalize
                 (call $integer-sub/2
                       (call $integer-mul/2 (local.get $x-num) (local.get $y-den))
                       (call $integer-mul/2 (local.get $y-num) (local.get $x-den)))
                 (call $integer-mul/2 (local.get $x-den) (local.get $y-den))))

     ;; $exact-rational-mul/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Multiply exact rational values and normalize the result.
     (func $exact-rational-mul/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (call $rational-normalize
                 (call $integer-mul/2
                       (call $exact-rational-numerator (local.get $x))
                       (call $exact-rational-numerator (local.get $y)))
                 (call $integer-mul/2
                       (call $exact-rational-denominator (local.get $x))
                       (call $exact-rational-denominator (local.get $y)))))

     ;; $exact-rational-div/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Divide exact rational values and normalize the result.
     (func $exact-rational-div/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (if (call $exact-rational-zero?/i32 (local.get $y))
               (then (call $raise-division-by-zero) (unreachable)))
           (call $rational-normalize
                 (call $integer-mul/2
                       (call $exact-rational-numerator (local.get $x))
                       (call $exact-rational-denominator (local.get $y)))
                 (call $integer-mul/2
                       (call $exact-rational-denominator (local.get $x))
                       (call $exact-rational-numerator (local.get $y)))))

     ;; $exact-rational-compare/i32 : exact-rational? exact-rational? -> integer?
     ;;   Compare exact rationals, returning -1, 0, or 1.
     (func $exact-rational-compare/i32
           (param $x (ref eq))
           (param $y (ref eq))
           (result i32)

           (call $integer-compare/i32
                 (call $integer-mul/2
                       (call $exact-rational-numerator (local.get $x))
                       (call $exact-rational-denominator (local.get $y)))
                 (call $integer-mul/2
                       (call $exact-rational-numerator (local.get $y))
                       (call $exact-rational-denominator (local.get $x)))))

     ;; $exact-rational-gcd/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Compute the exact rational GCD using numerator GCD and denominator LCM.
     (func $exact-rational-gcd/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (call $rational-normalize
                 (call $integer-gcd
                       (call $exact-rational-numerator (local.get $x))
                       (call $exact-rational-numerator (local.get $y)))
                 (call $integer-lcm
                       (call $exact-rational-denominator (local.get $x))
                       (call $exact-rational-denominator (local.get $y)))))

     ;; $exact-rational-lcm/2 : exact-rational? exact-rational? -> exact-rational?
     ;;   Compute the exact rational LCM using numerator LCM and denominator GCD.
     (func $exact-rational-lcm/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (if (call $exact-rational-zero?/i32 (local.get $x))
               (then (return (ref.i31 (i32.const 0)))))
           (if (call $exact-rational-zero?/i32 (local.get $y))
               (then (return (ref.i31 (i32.const 0)))))
           (call $rational-normalize
                 (call $integer-lcm
                       (call $exact-rational-numerator (local.get $x))
                       (call $exact-rational-numerator (local.get $y)))
                 (call $integer-gcd
                       (call $exact-rational-denominator (local.get $x))
                       (call $exact-rational-denominator (local.get $y)))))

     ;; $rational-eqv? : rational? rational? -> boolean?
     ;;   Compare canonical exact rationals by numerator and denominator.
     (func $rational-eqv?
           (param $x (ref $Rational))
           (param $y (ref $Rational))
           (result (ref eq))

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

     ;; $rational->string : rational? (or/c 2 8 10 16) -> string?
     ;;   Render an exact rational in the requested radix.
     (func $rational->string
           (param $q     (ref $Rational))
           (param $radix i32)
           (result       (ref $String))

           (local $radix-raw (ref eq))
           (local $num-str   (ref $String))
           (local $den-str   (ref $String))

           (local.set $radix-raw
                      (ref.i31
                       (i32.shl (local.get $radix) (i32.const 1))))
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
