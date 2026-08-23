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
