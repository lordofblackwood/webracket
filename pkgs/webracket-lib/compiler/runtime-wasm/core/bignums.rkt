#lang racket

;;;
;;; Bignums
;;;

;; This file implements bignums.
;;
;; Bignums are represented as
;;
;;   (type $Bignum (sub $Real
;;                     (struct
;;                       (field $hash  (mut i32))
;;                       (field $sign  i32)
;;                       (field $limbs (ref $I32Array)))))
;;
;;
;; That is, like other boxed numbers bignums have a:
;;   - hash code
;;   - a sign (+1 or -1)
;;   - some limbs, an array of 32 bit numbers
;;
;; Limbs are unsigned base-2^32 words in little-endian order.
;; The limbs can not all be zero.
;; Zero and values in the WebRacket fixnum range are represented as fixnums.

;; This file is all about the exact integers. Covered here:
;;   - arithmetic

;;   - division
;;   - comparison
;;   - conversion
;;   - hashing
;;   - printing

(provide bignum-core-runtime-helpers
         bignum-core-runtime-helper-forms
         bignum-runtime-only-helpers)

(require "../core-helper.rkt")

;;;
;;; Thresholds for the multiplication algorithms
;;;

;; Since we have multiple multiplication algorithms, we need a policy for
;; choosing an algorithm. Our policy is based on the number of limbs.
;; For small numbers, we use the schoolbook algorithm,
;; and for large numbers Karatsuba. Currently, Toom-3 is disabled
;; since it requires a very large number of limbs before it becomes
;; the fastest (in clock time).

;; While tuning (finding thresholds), we read thresholds from
;; environment variables.

(define bignum-threshold-max 2147483647)

;; read-bignum-threshold : string? exact-positive-integer? -> exact-positive-integer?
;;   Read a private compile-time multiplication tuning threshold.
(define (read-bignum-threshold name default)
  (define configured (getenv name))
  (define value
    (cond
      [(not configured) default]
      [(let ([value (string->number configured)])
         (and (exact-positive-integer? value) value))
       => values]
      [else
       (error 'bignum-core-runtime-helpers
              "expected ~a to be an exact positive integer, got ~e"
              name
              configured)]))
  (unless (<= value bignum-threshold-max)
    (error 'bignum-core-runtime-helpers
           "expected ~a to fit an i32 threshold, got ~e"
           name
           value))
  value)

;; validate-recursive-bignum-threshold : string? exact-positive-integer? -> void?
;;   Reject recursive thresholds that cannot shrink the recursive split.
(define (validate-recursive-bignum-threshold name value)
  (when (< value 2)
    (error 'bignum-core-runtime-helpers
           "expected ~a to be at least 2 limbs for recursive multiplication, got ~e"
           name
           value)))

;; These values are private compiler tuning controls. The measurement tool
;; recompiles the runtime with overrides while locating stable crossovers.
;; The current WebRacket measurements select Karatsuba at 128 limbs and keep
;; Toom-3 disabled: its generic evaluation/interpolation allocation overhead
;; does not repay itself through 16384 limbs without a workspace implementation.
;; The measurement tool is in tools/.

(define bignum-mul-karatsuba-threshold
  (read-bignum-threshold "WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD" 128))
(define bignum-mul-toom3-threshold
  (read-bignum-threshold "WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD" 2147483647)) ; disabled
(define bignum-sqr-basecase-threshold
  (read-bignum-threshold "WEBRACKET_BIGNUM_SQR_BASECASE_THRESHOLD" 128))
(define bignum-sqr-karatsuba-threshold
  (read-bignum-threshold "WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD" 128))
(define bignum-sqr-toom3-threshold
  (read-bignum-threshold "WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD" 2147483647)) ; disabled
(define bignum-mul-max-balance-ratio
  (read-bignum-threshold "WEBRACKET_BIGNUM_MUL_MAX_BALANCE_RATIO" 2))

(validate-recursive-bignum-threshold
 "WEBRACKET_BIGNUM_MUL_KARATSUBA_THRESHOLD"
 bignum-mul-karatsuba-threshold)
(validate-recursive-bignum-threshold
 "WEBRACKET_BIGNUM_MUL_TOOM3_THRESHOLD"
 bignum-mul-toom3-threshold)
(validate-recursive-bignum-threshold
 "WEBRACKET_BIGNUM_SQR_KARATSUBA_THRESHOLD"
 bignum-sqr-karatsuba-threshold)
(validate-recursive-bignum-threshold
 "WEBRACKET_BIGNUM_SQR_TOOM3_THRESHOLD"
 bignum-sqr-toom3-threshold)

;;;
;;; Runtime Helper Forms
;;;

;; bignum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Runtime support for exact integers outside the i31 fixnum range.
(define bignum-core-runtime-helpers
  (function-forms->runtime-helpers
   'bignum-core-runtime-helpers
   `(
     ;;;
     ;;; Checked Size Arithmetic
     ;;;

     ;; $bignum-size-add/i32 : i32 i32 -> i32
     ;;   Add two internal nonnegative sizes, trapping before i32 wraparound.
     (func $bignum-size-add/i32
           (param $a i32)
           (param $b i32)
           (result i32)

           (local $sum i64)

           ;; Compute in i64 so oversized resource requests cannot wrap.
           (local.set $sum
                      (i64.add
                       (i64.extend_i32_u (local.get $a))
                       (i64.extend_i32_u (local.get $b))))
           (if (i64.gt_u (local.get $sum)
                         (i64.const 2147483647))
               (then (unreachable)))
           (i32.wrap_i64 (local.get $sum)))

     ;; $bignum-size-mul/i32 : i32 i32 -> i32
     ;;   Multiply two internal nonnegative sizes, trapping before i32 wraparound.
     (func $bignum-size-mul/i32
           (param $a i32)
           (param $b i32)
           (result i32)

           (local $product i64)

           ;; Compute in i64 so oversized resource requests cannot wrap.
           (local.set $product
                      (i64.mul
                       (i64.extend_i32_u (local.get $a))
                       (i64.extend_i32_u (local.get $b))))
           (if (i64.gt_u (local.get $product)
                         (i64.const 2147483647))
               (then (unreachable)))
           (i32.wrap_i64 (local.get $product)))

     ;;;
     ;;; Canonical Representation
     ;;;

     ;; $integer-from-i64 : i64 -> exact-integer?
     ;;   Build a canonical exact integer from a signed 64-bit value.
     ;;   Canonical:  use a WebRacket fixnum when possible, otherwise
     ;;               use a normalized bignum with sign plus little-endian limbs.
     ;;   Normalized: no zero bignum, no fixnum-range bignum, and no leading zero limbs.
     (func $integer-from-i64
           (param $v i64)
           (result (ref eq))

           (local $sign i32)
           (local $abs  i64)
           (local $low  i32)
           (local $high i32)

           ;; Values in [-2^29, 2^29-1] fit WebRacket's tagged i31 fixnum range.
           (if (i32.and
                (i64.ge_s (local.get $v) (i64.const -536870912))
                (i64.le_s (local.get $v) (i64.const  536870911)))
               (then
                (return
                 (ref.i31
                  (i32.shl (i32.wrap_i64 (local.get $v)) (i32.const 1))))))

           ;; Record the sign as +/-1 and work with the absolute magnitude.
           (if (i64.lt_s (local.get $v) (i64.const 0))
               (then
                (local.set $sign (i32.const -1))
                (local.set $abs  (i64.sub (i64.const 0) (local.get $v))))
               (else
                (local.set $sign (i32.const 1))
                (local.set $abs  (local.get $v))))

           ;; Split the absolute 64-bit magnitude into low and high 32-bit limbs.
           (local.set $low  (i32.wrap_i64            (local.get $abs)))
           (local.set $high (i32.wrap_i64 (i64.shr_u (local.get $abs)
                                                     (i64.const 32))))

           ;; A zero high limb means the magnitude fits in one 32-bit limb.
           (if (i32.eqz (local.get $high))
               (then
                (return
                 (call $bignum-normalize
                       (local.get $sign)
                       (array.new_fixed $I32Array 1 (local.get $low))))))

           ;; Otherwise normalize a two-limb little-endian bignum magnitude.
           (call $bignum-normalize
                 (local.get $sign)
                 (array.new_fixed $I32Array 2
                                  (local.get $low)
                                  (local.get $high))))

     ;; $bignum-normalize : integer? i32-array? -> exact-integer?
     ;;   Trim zero limbs and collapse results that fit WebRacket fixnums.
     (func $bignum-normalize
           (param $sign  i32)
           (param $limbs (ref $I32Array))
           (result (ref eq))

           (local $len        i32)
           (local $active-len i32)
           (local $limb       i32)
           (local $trimmed    (ref $I32Array))

           ;; Start with the full limb array and trim from the high end.
           (local.set $len        (array.len (local.get $limbs)))
           (local.set $active-len (local.get $len))
           (block $trim-done
                  (loop $trim-loop
                        (br_if $trim-done (i32.eqz (local.get $active-len)))
                        (if (i32.eqz
                             (array.get $I32Array
                                        (local.get $limbs)
                                        (i32.sub (local.get $active-len)
                                                 (i32.const 1))))
                            (then
                             (local.set $active-len
                                        (i32.sub (local.get $active-len)
                                                 (i32.const 1)))
                             (br $trim-loop))
                            (else (br $trim-done)))))

           ;; An all-zero magnitude is canonically the fixnum zero.
           (if (i32.eqz (local.get $active-len))
               (then (return (ref.i31 (i32.const 0)))))

           ;; One-limb magnitudes may fit the positive or negative fixnum range.
           (if (i32.eq (local.get $active-len) (i32.const 1))
               (then
                (local.set $limb
                           (array.get $I32Array (local.get $limbs) (i32.const 0)))
                (if (i32.gt_s (local.get $sign) (i32.const 0))
                    (then
                     (if (i32.le_u (local.get $limb) (i32.const 536870911))
                         (then
                          (return
                           (ref.i31
                            (i32.shl (local.get $limb) (i32.const 1)))))))
                    (else
                     (if (i32.le_u (local.get $limb) (i32.const 536870912))
                         (then
                          (return
                           (ref.i31
                            (i32.shl
                             (i32.sub (i32.const 0) (local.get $limb))
                             (i32.const 1))))))))))

           ;; If no limbs were trimmed, reuse the original array in a bignum.
           (if (i32.eq (local.get $active-len) (local.get $len))
               (then
                (return
                 (struct.new $Bignum
                             (i32.const 0)
                             (select (i32.const 1)
                                     (i32.const -1)
                                     (i32.gt_s (local.get $sign) (i32.const 0)))
                             (local.get $limbs)))))

           ;; Otherwise copy only the active limbs into the normalized bignum.
           (local.set $trimmed
                      (array.new_default $I32Array (local.get $active-len)))
           (array.copy $I32Array $I32Array
                       (local.get $trimmed) (i32.const 0)
                       (local.get $limbs)   (i32.const 0)
                       (local.get $active-len))
           (struct.new $Bignum
                       (i32.const 0)
                       (select (i32.const 1)
                               (i32.const -1)
                               (i32.gt_s (local.get $sign) (i32.const 0)))
                       (local.get $trimmed)))

     ;; $nonzero-fixnum->bignum : fixnum? -> bignum?
     ;;   Box a nonzero WebRacket fixnum as a one-limb bignum.
     (func $nonzero-fixnum->bignum
           (param $x (ref eq))
           (result (ref $Bignum))

           (local $v         i32)
           (local $sign      i32)
           (local $magnitude i32)

           ;; Decode the tagged i31 fixnum payload.
           (local.set $v
                      (i32.shr_s
                       (i31.get_s (ref.cast (ref i31) (local.get $x)))
                       (i32.const 1)))

           ;; Separate the sign from the absolute one-limb magnitude.
           (if (i32.lt_s (local.get $v) (i32.const 0))
               (then
                (local.set $sign (i32.const -1))
                (local.set $magnitude
                           (i32.sub (i32.const 0) (local.get $v))))
               (else
                (local.set $sign (i32.const 1))
                (local.set $magnitude (local.get $v))))

           ;; Build a one-limb bignum directly; the input is known nonzero.
           (struct.new $Bignum
                       (i32.const 0)
                       (local.get $sign)
                       (array.new_fixed $I32Array 1
                                        (local.get $magnitude))))

     ;; $bignum-negate : bignum? -> exact-integer?
     ;;   Return the canonical additive inverse of a nonzero bignum.
     (func $bignum-negate
           (param $b (ref $Bignum))
           (result (ref eq))

           ;; Flip the sign and normalize so the result collapses if needed.
           ;; Since the fixnum range is asymmetrical, we need to normalize.
           (call $bignum-normalize
                 (i32.sub (i32.const 0)
                          (struct.get $Bignum $sign (local.get $b)))
                 (struct.get $Bignum $limbs (local.get $b))))

     ;;;
     ;;; Magnitude Arithmetic
     ;;;

     ;; $bignum-magnitude-compare/i32 : i32-array? i32-array? -> integer?
     ;;   Compare unsigned little-endian limb arrays, returning -1, 0, or 1.
     (func $bignum-magnitude-compare/i32
           (param $a (ref $I32Array))
           (param $b (ref $I32Array))
           (result i32)

           (local $a-len i32)
           (local $b-len i32)
           (local $i     i32)
           (local $av    i32)
           (local $bv    i32)

           ;; Magnitudes with fewer active limbs are smaller.
           (local.set $a-len (array.len (local.get $a)))
           (local.set $b-len (array.len (local.get $b)))
           (if (i32.lt_u (local.get $a-len) (local.get $b-len))
               (then (return (i32.const -1))))
           (if (i32.gt_u (local.get $a-len) (local.get $b-len))
               (then (return (i32.const 1))))

           ;; Equal-length magnitudes compare by scanning high limbs first.
           (local.set $i (local.get $a-len))
           (block $done
                  (loop $loop
                        (br_if $done (i32.eqz (local.get $i)))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (local.set $av
                                   (array.get $I32Array
                                              (local.get $a)
                                              (local.get $i)))
                        (local.set $bv
                                   (array.get $I32Array
                                              (local.get $b)
                                              (local.get $i)))
                        (if (i32.ne (local.get $av) (local.get $bv))
                            (then
                             (return
                              (select (i32.const 1)
                                      (i32.const -1)
                                      (i32.gt_u (local.get $av)
                                                (local.get $bv))))))
                        (br $loop)))
           (i32.const 0))

     ;; $bignum-add-magnitudes : i32-array? i32-array? -> i32-array?
     ;;   Add unsigned magnitudes, leaving possible leading zero cleanup to normalize.
     (func $bignum-add-magnitudes
           (param $a (ref $I32Array))
           (param $b (ref $I32Array))
           (result (ref $I32Array))

           (local $a-len i32)
           (local $b-len i32)
           (local $max-len i32)
           (local $out (ref $I32Array))
           (local $i i32)
           (local $acc i64)
           (local $carry i64)

           ;; Allocate one extra output limb for a possible final carry.
           (local.set $a-len (array.len (local.get $a)))
           (local.set $b-len (array.len (local.get $b)))
           (local.set $max-len
                      (select (local.get $a-len)
                              (local.get $b-len)
                              (i32.gt_u (local.get $a-len)
                                        (local.get $b-len))))
           (local.set $out
                      (array.new_default
                       $I32Array
                       (call $bignum-size-add/i32
                             (local.get $max-len)
                             (i32.const 1))))

           ;; Add matching limbs plus carry in base 2^32.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i) (local.get $max-len)))
                        (local.set $acc (local.get $carry))
                        (if (i32.lt_u (local.get $i) (local.get $a-len))
                            (then
                             (local.set $acc
                                        (i64.add
                                         (local.get $acc)
                                         (i64.extend_i32_u
                                          (array.get $I32Array
                                                     (local.get $a)
                                                     (local.get $i)))))))
                        (if (i32.lt_u (local.get $i) (local.get $b-len))
                            (then
                             (local.set $acc
                                        (i64.add
                                         (local.get $acc)
                                         (i64.extend_i32_u
                                          (array.get $I32Array
                                                     (local.get $b)
                                                     (local.get $i)))))))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $i)
                                   (i32.wrap_i64 (local.get $acc)))
                        (local.set $carry
                                   (i64.shr_u (local.get $acc) (i64.const 32)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; Store the final carry in the extra high limb.
           (array.set $I32Array
                      (local.get $out)
                      (local.get $max-len)
                      (i32.wrap_i64 (local.get $carry)))
           (local.get $out))

     ;; $bignum-sub-magnitudes : i32-array? i32-array? -> i32-array?
     ;;   Subtract unsigned magnitudes where the first is at least the second.
     (func $bignum-sub-magnitudes
           (param $a (ref $I32Array))
           (param $b (ref $I32Array))
           (result (ref $I32Array))

           (local $a-len i32)
           (local $b-len i32)
           (local $out (ref $I32Array))
           (local $i i32)
           (local $acc i64)
           (local $borrow i64)

           ;; The caller guarantees a >= b, so the output length is a's length.
           (local.set $a-len (array.len (local.get $a)))
           (local.set $b-len (array.len (local.get $b)))
           (local.set $out (array.new_default $I32Array (local.get $a-len)))

           ;; Subtract matching limbs in base 2^32 while propagating borrow.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i) (local.get $a-len)))
                        (local.set $acc
                                   (i64.sub
                                    (i64.extend_i32_u
                                     (array.get $I32Array
                                                (local.get $a)
                                                (local.get $i)))
                                    (local.get $borrow)))
                        (if (i32.lt_u (local.get $i) (local.get $b-len))
                            (then
                             (local.set $acc
                                        (i64.sub
                                         (local.get $acc)
                                         (i64.extend_i32_u
                                          (array.get $I32Array
                                                     (local.get $b)
                                                     (local.get $i)))))))
                        (if (i64.lt_s (local.get $acc) (i64.const 0))
                            (then
                             (local.set $acc
                                        (i64.add (local.get $acc)
                                                 (i64.const 4294967296))) ; 2^32
                             (local.set $borrow (i64.const 1)))
                            (else
                             (local.set $borrow (i64.const 0))))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $i)
                                   (i32.wrap_i64 (local.get $acc)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $out))

     ;; $bignum-add : bignum? bignum? -> exact-integer?
     ;;   Add two signed canonical bignums.
     (func $bignum-add
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-limbs (ref $I32Array))
           (local $b-limbs (ref $I32Array))
           (local $cmp i32)

           ;; Addition with equal signs is unsigned magnitude addition.
           (local.set $a-limbs (struct.get $Bignum $limbs (local.get $a)))
           (local.set $b-limbs (struct.get $Bignum $limbs (local.get $b)))
           (if (i32.eq (struct.get $Bignum $sign (local.get $a))
                       (struct.get $Bignum $sign (local.get $b)))
               (then
                (return
                 (call $bignum-normalize
                       (struct.get $Bignum $sign (local.get $a))
                       (call $bignum-add-magnitudes
                             (local.get $a-limbs)
                             (local.get $b-limbs))))))

           ;; Opposite signs subtract the smaller magnitude from the larger.
           (local.set $cmp
                      (call $bignum-magnitude-compare/i32
                            (local.get $a-limbs)
                            (local.get $b-limbs)))

           ;; Equal magnitudes with opposite signs cancel to fixnum zero.
           (if (i32.eqz (local.get $cmp))
               (then (return (ref.i31 (i32.const 0)))))

           ;; The larger magnitude determines the result sign.
           (if (result (ref eq))
               (i32.gt_s (local.get $cmp) (i32.const 0))
               (then
                (call $bignum-normalize
                      (struct.get $Bignum $sign (local.get $a))
                      (call $bignum-sub-magnitudes
                            (local.get $a-limbs)
                            (local.get $b-limbs))))
               (else
                (call $bignum-normalize
                      (struct.get $Bignum $sign (local.get $b))
                      (call $bignum-sub-magnitudes
                            (local.get $b-limbs)
                            (local.get $a-limbs))))))

     ;; $bignum-sub : bignum? bignum? -> exact-integer?
     ;;   Subtract two signed canonical bignums.
     (func $bignum-sub
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-limbs (ref $I32Array))
           (local $b-limbs (ref $I32Array))
           (local $cmp i32)

           ;; Subtraction with opposite signs is unsigned magnitude addition.
           (local.set $a-limbs (struct.get $Bignum $limbs (local.get $a)))
           (local.set $b-limbs (struct.get $Bignum $limbs (local.get $b)))
           (if (i32.ne (struct.get $Bignum $sign (local.get $a))
                       (struct.get $Bignum $sign (local.get $b)))
               (then
                (return
                 (call $bignum-normalize
                       (struct.get $Bignum $sign (local.get $a))
                       (call $bignum-add-magnitudes
                             (local.get $a-limbs)
                             (local.get $b-limbs))))))

           ;; Equal signs subtract the smaller magnitude from the larger.
           (local.set $cmp
                      (call $bignum-magnitude-compare/i32
                            (local.get $a-limbs)
                            (local.get $b-limbs)))

           ;; Equal magnitudes cancel to fixnum zero.
           (if (i32.eqz (local.get $cmp))
               (then (return (ref.i31 (i32.const 0)))))

           ;; The sign is either a's sign or its negation depending on magnitude order.
           (if (result (ref eq))
               (i32.gt_s (local.get $cmp) (i32.const 0))
               (then
                (call $bignum-normalize
                      (struct.get $Bignum $sign (local.get $a))
                      (call $bignum-sub-magnitudes
                            (local.get $a-limbs)
                            (local.get $b-limbs))))
               (else
                (call $bignum-normalize
                      (i32.sub (i32.const 0)
                               (struct.get $Bignum $sign (local.get $a)))
                      (call $bignum-sub-magnitudes
                            (local.get $b-limbs)
                            (local.get $a-limbs))))))

     ;; $bignum-compare/i32 : bignum? bignum? -> integer?
     ;;   Compare two signed canonical bignums, returning -1, 0, or 1.
     (func $bignum-compare/i32
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result i32)

           (local $a-sign i32)
           (local $b-sign i32)
           (local $cmp i32)

           ;; Different signs determine the result without looking at limbs.
           (local.set $a-sign (struct.get $Bignum $sign (local.get $a)))
           (local.set $b-sign (struct.get $Bignum $sign (local.get $b)))
           (if (i32.ne (local.get $a-sign) (local.get $b-sign))
               (then
                (return
                 (select (i32.const 1)
                         (i32.const -1)
                         (i32.gt_s (local.get $a-sign)
                                   (local.get $b-sign))))))

           ;; Equal signs compare magnitudes, reversing the order for negatives.
           (local.set $cmp
                      (call $bignum-magnitude-compare/i32
                            (struct.get $Bignum $limbs (local.get $a))
                            (struct.get $Bignum $limbs (local.get $b))))
           (if (result i32)
               (i32.gt_s (local.get $a-sign) (i32.const 0))
               (then (local.get $cmp))
               (else (i32.sub (i32.const 0) (local.get $cmp)))))

     ;;;
     ;;; Schoolbook Multiplication
     ;;;

     ;; $bignum-mul-u32 : bignum? i32 i32 -> exact-integer?
     ;;   Multiply a bignum magnitude by an unsigned 32-bit limb and apply sign.
     (func $bignum-mul-u32
           (param $b    (ref $Bignum))
           (param $m    i32)
           (param $sign i32)
           (result (ref eq))

           (local $limbs (ref $I32Array))
           (local $len   i32)
           (local $out   (ref $I32Array))
           (local $i     i32)
           (local $acc   i64)
           (local $carry i64)

           ;; Multiplication by zero canonically returns the fixnum zero.
           (if (i32.eqz (local.get $m))
               (then (return (ref.i31 (i32.const 0)))))

           ;; Allocate one extra high limb for the final carry.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len   (array.len (local.get $limbs)))
           (local.set $out   (array.new_default
                              $I32Array
                              (call $bignum-size-add/i32
                                    (local.get $len)
                                    (i32.const 1))))

           ;; Multiply each limb by m and add the carry from the previous limb.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i) (local.get $len)))
                        (local.set $acc
                                   (i64.add
                                    (i64.mul
                                     (i64.extend_i32_u
                                      (array.get $I32Array
                                                 (local.get $limbs)
                                                 (local.get $i)))
                                     (i64.extend_i32_u (local.get $m)))
                                    (local.get $carry)))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $i)
                                   (i32.wrap_i64 (local.get $acc)))
                        (local.set $carry
                                   (i64.shr_u (local.get $acc)
                                              (i64.const 32)))
                        (local.set $i
                                   (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; Store the final carry and normalize under the requested sign.
           (array.set $I32Array
                      (local.get $out)
                      (local.get $len)
                      (i32.wrap_i64 (local.get $carry)))
           (call $bignum-normalize
                 (local.get $sign)
                 (local.get $out)))

     ;; $bignum-mul-schoolbook-magnitude : bignum? bignum? -> exact-nonnegative-integer?
     ;;   Multiply magnitudes with rectangular schoolbook multiplication.
     (func $bignum-mul-schoolbook-magnitude
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-limbs     (ref $I32Array))
           (local $b-limbs     (ref $I32Array))
           (local $small-limbs (ref $I32Array))
           (local $large-limbs (ref $I32Array))
           (local $a-len       i32)
           (local $b-len       i32)
           (local $small-len   i32)
           (local $large-len   i32)
           (local $out-len     i32)
           (local $out         (ref $I32Array))
           (local $i           i32)
           (local $j           i32)
           (local $pos         i32)
           (local $small-limb  i32)
           (local $large-limb  i32)
           (local $acc         i64)
           (local $carry       i64)

           ;; Schoolbook multiplication iterates with the smaller operand outside.
           (local.set $a-limbs (struct.get $Bignum $limbs (local.get $a)))
           (local.set $b-limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $a-len   (array.len (local.get $a-limbs)))
           (local.set $b-len   (array.len (local.get $b-limbs)))
           (local.set $small-limbs (local.get $a-limbs))
           (local.set $small-len   (local.get $a-len))
           (local.set $large-limbs (local.get $b-limbs))
           (local.set $large-len   (local.get $b-len))
           (if (i32.gt_u (local.get $a-len) (local.get $b-len))
               (then
                (local.set $small-limbs (local.get $b-limbs))
                (local.set $small-len   (local.get $b-len))
                (local.set $large-limbs (local.get $a-limbs))
                (local.set $large-len   (local.get $a-len))))
           (local.set $out-len
                      (call $bignum-size-add/i32
                            (local.get $small-len)
                            (local.get $large-len)))
           (local.set $out (array.new_default $I32Array (local.get $out-len)))

           ;; Add each scaled row of the multiplication table into the output.
           (block $outer-done
                  (loop $outer
                        (br_if $outer-done
                               (i32.ge_u (local.get $i) (local.get $small-len)))
                        (local.set $small-limb
                                   (array.get $I32Array
                                              (local.get $small-limbs)
                                              (local.get $i)))
                        (if (i32.eqz (local.get $small-limb))
                            (then
                             (local.set $i (i32.add (local.get $i)
                                                    (i32.const 1)))
                             (br $outer)))
                        (local.set $carry (i64.const 0))
                        (local.set $j (i32.const 0))
                        (block $inner-done
                               (loop $inner
                                     (br_if $inner-done
                                            (i32.ge_u (local.get $j) (local.get $large-len)))
                                     (local.set $pos
                                                (i32.add (local.get $i)
                                                         (local.get $j)))
                                     (local.set $large-limb
                                                (array.get $I32Array
                                                           (local.get $large-limbs)
                                                           (local.get $j)))
                                     (if (i32.and
                                          (i32.eqz (local.get $large-limb))
                                          (i64.eqz (local.get $carry)))
                                         (then
                                          (local.set $j
                                                     (i32.add (local.get $j)
                                                              (i32.const 1)))
                                          (br $inner)))
                                     (local.set $acc
                                                (i64.add
                                                 (i64.add
                                                  (i64.extend_i32_u
                                                   (array.get $I32Array
                                                              (local.get $out)
                                                              (local.get $pos)))
                                                  (i64.mul
                                                   (i64.extend_i32_u
                                                    (local.get $small-limb))
                                                   (i64.extend_i32_u
                                                    (local.get $large-limb))))
                                                 (local.get $carry)))
                                     (array.set $I32Array
                                                (local.get $out)
                                                (local.get $pos)
                                                (i32.wrap_i64 (local.get $acc)))
                                     (local.set $carry
                                                (i64.shr_u (local.get $acc)
                                                           (i64.const 32)))
                                     (local.set $j
                                                (i32.add (local.get $j)
                                                         (i32.const 1)))
                                     (br $inner)))
                        (local.set $pos
                                   (i32.add (local.get $i) (local.get $large-len)))

                        ;; Propagate the row carry above the last large-operand limb.
                        (block $carry-done
                               (loop $carry-loop
                                     (br_if $carry-done (i64.eqz (local.get $carry)))
                                     (local.set $acc
                                                (i64.add
                                                 (i64.extend_i32_u
                                                  (array.get $I32Array
                                                             (local.get $out)
                                                             (local.get $pos)))
                                                 (local.get $carry)))
                                     (array.set $I32Array
                                                (local.get $out)
                                                (local.get $pos)
                                                (i32.wrap_i64 (local.get $acc)))
                                     (local.set $carry
                                                (i64.shr_u (local.get $acc)
                                                           (i64.const 32)))
                                     (local.set $pos
                                                (i32.add (local.get $pos)
                                                         (i32.const 1)))
                                     (br $carry-loop)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $outer)))

           ;; Schoolbook computes a magnitude; the dispatcher applies the sign.
           (call $bignum-normalize (i32.const 1) (local.get $out)))

     ;; $bignum-square-basecase : bignum? -> exact-integer?
     ;;   Square a bignum magnitude using one multiply for each off-diagonal pair.
     ;;   Algorithm:
     ;;      Treat the bignum as base-2^32 limbs.
     ;;      Add each limb squared at position 2*i,
     ;;      then add each different-limb product twice at position i+j.
     ;;   This works since if x = sum_i ai*B^i, then
     ;;
     ;;       x^2 = sum_i ai^2*B^(2*i) + sum_{i<j} 2*ai*aj*B^(i+j).
     ;;
     (func $bignum-square-basecase
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $limbs  (ref $I32Array))
           (local $len    i32)
           (local $out    (ref $I32Array))
           (local $i      i32)
           (local $j      i32)
           (local $ai     i32)
           (local $aj     i32)
           (local $pos    i32)
           (local $prod   i64)
           (local $acc    i64)
           (local $carry  i64)

           ;; A square of n limbs has at most 2n limbs.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $out
                      (array.new_default
                       $I32Array
                       (call $bignum-size-mul/i32
                             (local.get $len)
                             (i32.const 2))))

           ;; For each nonzero limb, add its diagonal square and off-diagonal doubles.
           (block $outer-done
                  (loop $outer
                        (br_if $outer-done
                               (i32.ge_u (local.get $i) (local.get $len)))
                        (local.set $ai
                                   (array.get $I32Array
                                              (local.get $limbs)
                                              (local.get $i)))
                        (if (i32.eqz (local.get $ai))
                            (then
                             (local.set $i
                                        (i32.add (local.get $i)
                                                 (i32.const 1)))
                             (br $outer)))
                        ;; Add ai^2 at output position 2i.
                        (local.set $prod
                                   (i64.mul
                                    (i64.extend_i32_u (local.get $ai))
                                    (i64.extend_i32_u (local.get $ai))))
                        (local.set $pos
                                   (i32.mul (local.get $i) (i32.const 2)))
                        (local.set $acc
                                   (i64.add
                                    (i64.extend_i32_u
                                     (array.get $I32Array
                                                (local.get $out)
                                                (local.get $pos)))
                                    (i64.and (local.get $prod)
                                             (i64.const 4294967295))))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $pos)
                                   (i32.wrap_i64 (local.get $acc)))
                        (local.set $carry
                                   (i64.add
                                    (i64.shr_u (local.get $prod) (i64.const 32))
                                    (i64.shr_u (local.get $acc) (i64.const 32))))
                        (local.set $pos
                                   (i32.add (local.get $pos) (i32.const 1)))

                        ;; Propagate the diagonal carry through following limbs.
                        (block $diag-carry-done
                               (loop $diag-carry-loop
                                     (br_if $diag-carry-done
                                            (i64.eqz (local.get $carry)))
                                     (local.set $acc
                                                (i64.add
                                                 (i64.extend_i32_u
                                                  (array.get $I32Array
                                                             (local.get $out)
                                                             (local.get $pos)))
                                                 (local.get $carry)))
                                     (array.set $I32Array
                                                (local.get $out)
                                                (local.get $pos)
                                                (i32.wrap_i64 (local.get $acc)))
                                     (local.set $carry
                                                (i64.shr_u (local.get $acc)
                                                           (i64.const 32)))
                                     (local.set $pos
                                                (i32.add (local.get $pos)
                                                         (i32.const 1)))
                                     (br $diag-carry-loop)))
                        (local.set $j
                                   (i32.add (local.get $i) (i32.const 1)))
                        (local.set $carry (i64.const 0))

                        ;; Add each off-diagonal product twice, because ai*aj and aj*ai match.
                        (block $inner-done
                               (loop $inner
                                     (br_if $inner-done
                                            (i32.ge_u (local.get $j)
                                                      (local.get $len)))
                                     (local.set $pos
                                                (i32.add (local.get $i)
                                                         (local.get $j)))
                                     (local.set $aj
                                                (array.get $I32Array
                                                           (local.get $limbs)
                                                           (local.get $j)))
                                     (if (i32.and
                                          (i32.eqz (local.get $aj))
                                          (i64.eqz (local.get $carry)))
                                         (then
                                          (local.set $j
                                                     (i32.add (local.get $j)
                                                              (i32.const 1)))
                                          (br $inner)))
                                     (local.set $prod
                                                (select
                                                 (i64.const 0)
                                                 (i64.mul
                                                  (i64.extend_i32_u (local.get $ai))
                                                  (i64.extend_i32_u (local.get $aj)))
                                                 (i32.eqz (local.get $aj))))
                                     (local.set $acc
                                                (i64.add
                                                 (i64.add
                                                  (i64.extend_i32_u
                                                   (array.get $I32Array
                                                              (local.get $out)
                                                              (local.get $pos)))
                                                  (i64.and
                                                   (i64.shl (local.get $prod)
                                                            (i64.const 1))
                                                   (i64.const 4294967295)))
                                                 (i64.and
                                                  (local.get $carry)
                                                  (i64.const 4294967295))))
                                     (array.set $I32Array
                                                (local.get $out)
                                                (local.get $pos)
                                                (i32.wrap_i64 (local.get $acc)))
                                     (local.set $carry
                                                (i64.add
                                                 (i64.add
                                                  (i64.shr_u (local.get $prod)
                                                             (i64.const 31))
                                                  (i64.shr_u (local.get $carry)
                                                             (i64.const 32)))
                                                 (i64.shr_u (local.get $acc)
                                                            (i64.const 32))))
                                     (local.set $j
                                                (i32.add (local.get $j)
                                                         (i32.const 1)))
                                     (br $inner)))
                        (local.set $pos
                                   (i32.add (local.get $i)
                                            (local.get $len)))

                        ;; Propagate any remaining cross-product carry.
                        (block $cross-carry-done
                               (loop $cross-carry-loop
                                     (br_if $cross-carry-done
                                            (i64.eqz (local.get $carry)))
                                     (local.set $acc
                                                (i64.add
                                                 (i64.extend_i32_u
                                                  (array.get $I32Array
                                                             (local.get $out)
                                                             (local.get $pos)))
                                                 (i64.and (local.get $carry)
                                                          (i64.const 4294967295))))
                                     (array.set $I32Array
                                                (local.get $out)
                                                (local.get $pos)
                                                (i32.wrap_i64 (local.get $acc)))
                                     (local.set $carry
                                                (i64.add
                                                 (i64.shr_u (local.get $carry)
                                                            (i64.const 32))
                                                 (i64.shr_u (local.get $acc)
                                                            (i64.const 32))))
                                     (local.set $pos
                                                (i32.add (local.get $pos)
                                                         (i32.const 1)))
                                     (br $cross-carry-loop)))
                        (local.set $i
                                   (i32.add (local.get $i) (i32.const 1)))
                        (br $outer)))

           ;; Squaring a magnitude is nonnegative; normalize the output limbs.
           (call $bignum-normalize
                 (i32.const 1)
                 (local.get $out)))

     ;;;
     ;;; Shifts and Limb Slices
     ;;;

     ;; $bignum-power-of-two-shift/i32 : bignum? -> integer?
     ;;   Return k for a magnitude of 2^k, or -1 when the magnitude is not a power of two.
     (func $bignum-power-of-two-shift/i32
           (param $b (ref $Bignum))
           (result i32)

           (local $limbs (ref $I32Array))
           (local $len   i32)
           (local $i     i32)
           (local $limb  i32)
           (local $seen  i32)
           (local $shift i32)
           (local $shift64 i64)

           ;; Scan limbs looking for exactly one set bit across the magnitude.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len   (array.len (local.get $limbs)))
           (local.set $shift (i32.const -1))
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i) (local.get $len)))
                        (local.set $limb
                                   (array.get $I32Array
                                              (local.get $limbs)
                                              (local.get $i)))

                        ;; A nonzero limb must itself be a power of two.
                        (if (i32.ne (local.get $limb) (i32.const 0))
                            (then
                             (if (local.get $seen)
                                 (then (return (i32.const -1))))
                             (if (i32.ne
                                  (i32.and
                                   (local.get $limb)
                                   (i32.sub (local.get $limb) (i32.const 1)))
                                  (i32.const 0))
                                 (then (return (i32.const -1))))
                             (local.set $seen (i32.const 1))
                             (local.set $shift64
                                        (i64.add
                                         (i64.mul
                                          (i64.extend_i32_u (local.get $i))
                                          (i64.const 32))
                                         (i64.extend_i32_u
                                          (i32.ctz (local.get $limb)))))
                             (if (i64.gt_u (local.get $shift64)
                                           (i64.const 2147483647))
                                 (then (return (i32.const -1))))
                             (local.set $shift
                                        (i32.wrap_i64 (local.get $shift64)))))
                        (local.set $i
                                   (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $shift))

     ;; $bignum-shl-by-i32/sign : bignum? integer? integer? -> exact-integer?
     ;;   Shift a bignum magnitude left by shift bits and apply sign.
     (func $bignum-shl-by-i32/sign
           (param $b     (ref $Bignum))
           (param $shift i32)
           (param $sign  i32)
           (result (ref eq))

           (local $limbs      (ref $I32Array))
           (local $len        i32)
           (local $word-shift i32)
           (local $bit-shift  i32)
           (local $out        (ref $I32Array))
           (local $i          i32)
           (local $pos        i32)
           (local $acc        i64)
           (local $carry      i64)

           ;; Split the bit count into a whole-limb shift and an intra-limb shift.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $word-shift
                      (i32.div_u (local.get $shift) (i32.const 32)))
           (local.set $bit-shift
                      (i32.rem_u (local.get $shift) (i32.const 32)))
           (local.set $out
                      (array.new_default
                       $I32Array
                       (call $bignum-size-add/i32
                             (call $bignum-size-add/i32
                                   (local.get $len)
                                   (local.get $word-shift))
                             (i32.const 1))))

           ;; Copy shifted limbs into their new positions while propagating carry.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i) (local.get $len)))
                        (local.set $pos
                                   (i32.add (local.get $i)
                                            (local.get $word-shift)))
                        (local.set $acc
                                   (i64.or
                                    (i64.shl
                                     (i64.extend_i32_u
                                      (array.get $I32Array
                                                 (local.get $limbs)
                                                 (local.get $i)))
                                     (i64.extend_i32_u (local.get $bit-shift)))
                                    (local.get $carry)))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $pos)
                                   (i32.wrap_i64 (local.get $acc)))
                        (local.set $carry
                                   (i64.shr_u (local.get $acc)
                                              (i64.const 32)))
                        (local.set $i
                                   (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; Store the final carry above the shifted source limbs.
           (array.set $I32Array
                      (local.get $out)
                      (call $bignum-size-add/i32
                            (local.get $word-shift)
                            (local.get $len))
                      (i32.wrap_i64 (local.get $carry)))
           (call $bignum-normalize
                 (local.get $sign)
                 (local.get $out)))

     ;; $integer-shl-by-i32/sign : exact-integer? integer? integer? -> exact-integer?
     ;;   Shift an exact integer magnitude left by shift bits and apply sign.
     (func $integer-shl-by-i32/sign
           (param $x     (ref eq))
           (param $shift i32)
           (param $sign  i32)
           (result (ref eq))

           ;; Shift fixnum magnitudes via a 64-bit mantissa path.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (return
                 (call $integer-apply-sign
                       (call $u64-shl->integer
                             (i64.extend_i32_u
                             (call $integer-abs-u32 (local.get $x)))
                             (local.get $shift))
                       (local.get $sign)))))

           ;; Shift bignum magnitudes directly by limbs and bits.
           (call $bignum-shl-by-i32/sign
                 (ref.cast (ref $Bignum) (local.get $x))
                 (local.get $shift)
                 (local.get $sign)))

     ;; $bignum-limb-slice : bignum? exact-nonnegative-integer? exact-nonnegative-integer? -> exact-nonnegative-integer?
     ;;   Copy a zero-extended little-endian limb range as a canonical magnitude.
     (func $bignum-limb-slice
           (param $b     (ref $Bignum))
           (param $start i32)
           (param $count i32)
           (result (ref eq))

           (local $limbs     (ref $I32Array))
           (local $len       i32)
           (local $available i32)
           (local $copy-len  i32)
           (local $out       (ref $I32Array))

           ;; An empty slice is the zero magnitude.
           (if (i32.eqz (local.get $count))
               (then (return (ref.i31 (i32.const 0)))))

           ;; Allocate a zero-filled destination so out-of-range limbs read as zero.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $out
                      (array.new_default $I32Array (local.get $count)))

           ;; A start beyond the source length leaves the zero-filled slice.
           (if (i32.ge_u (local.get $start) (local.get $len))
               (then
                (return
                 (call $bignum-normalize (i32.const 1) (local.get $out)))))

           ;; Copy only the source limbs that actually exist.
           (local.set $available
                      (i32.sub (local.get $len) (local.get $start)))
           (local.set $copy-len
                      (select (local.get $available)
                              (local.get $count)
                              (i32.lt_u (local.get $available)
                                        (local.get $count))))
           (array.copy $I32Array $I32Array
                       (local.get $out)   (i32.const 0)
                       (local.get $limbs) (local.get $start)
                       (local.get $copy-len))
           (call $bignum-normalize (i32.const 1) (local.get $out)))

     ;; $integer-shl-by-i32 : exact-integer? exact-nonnegative-integer? -> exact-integer?
     ;;   Shift an exact integer left while preserving its sign.
     (func $integer-shl-by-i32
           (param $x     (ref eq))
           (param $shift i32)
           (result (ref eq))

           ;; Shifting zero preserves the existing canonical zero value.
           (if (call $integer-zero?/i32 (local.get $x))
               (then (return (local.get $x))))

           ;; Otherwise shift the magnitude and reapply the original sign.
           (call $integer-shl-by-i32/sign
                 (local.get $x)
                 (local.get $shift)
                 (call $integer-sign/i32 (local.get $x))))

     ;; $integer-divexact-by-i32 : exact-integer? exact-positive-integer? -> exact-integer?
     ;;   Divide by a small positive divisor that is known to divide exactly.
     (func $integer-divexact-by-i32
           (param $n (ref eq))
           (param $d i32)
           (result (ref eq))

           (local $vals (ref $Values))
           (local $q    (ref eq))
           (local $r    (ref eq))

           ;; Use integer division by the tagged fixnum d.
           (local.set $vals
                      (call $integer-divmod
                            (local.get $n)
                            (ref.i31
                             (i32.shl (local.get $d) (i32.const 1)))))
           (local.set $q (array.get $Values (local.get $vals) (i32.const 0)))
           (local.set $r (array.get $Values (local.get $vals) (i32.const 1)))

           ;; The caller promises exact divisibility; a remainder is an internal bug.
           (if (i32.eqz (call $integer-zero?/i32 (local.get $r)))
               (then (unreachable)))
           (local.get $q))

     ;;;
     ;;; Karatsuba Multiplication
     ;;;

     ;; Karatsuba splits each operand into a low half and a high half:
     ;;
     ;;     x = x0 + x1*B
     ;;     y = y0 + y1*B
     ;;
     ;; A direct product uses four smaller multiplications:
     ;;
     ;;     x*y = x0*y0 + (x0*y1 + x1*y0)*B + x1*y1*B^2
     ;;
     ;; Karatsuba computes the middle term with one multiplication instead:
     ;;
     ;;     z0  = x0*y0
     ;;     z2  = x1*y1
     ;;     d   = (x1 - x0)*(y1 - y0)
     ;;     mid = z0 + z2 - d = x0*y1 + x1*y0
     ;;
     ;; Then it combines:
     ;;
     ;;     x*y = z0 + mid*B + z2*B^2

     ;; $bignum-mul-karatsuba-magnitude : bignum? bignum? -> exact-nonnegative-integer?
     ;;   Multiply magnitudes with the three-product Karatsuba identity.
     (func $bignum-mul-karatsuba-magnitude
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-len   i32)
           (local $b-len   i32)
           (local $max-len i32)
           (local $k       i32)
           (local $bits    i32)
           (local $x0      (ref eq))
           (local $x1      (ref eq))
           (local $y0      (ref eq))
           (local $y1      (ref eq))
           (local $z0      (ref eq))
           (local $z2      (ref eq))
           (local $d       (ref eq))
           (local $mid     (ref eq))
           (local $result  (ref eq))

           ;; Split both operands at k limbs, where k is half the larger length.
           (local.set $a-len   (array.len (struct.get $Bignum $limbs (local.get $a))))
           (local.set $b-len   (array.len (struct.get $Bignum $limbs (local.get $b))))
           (local.set $max-len (select (local.get $a-len)
                                       (local.get $b-len)
                                       (i32.gt_u (local.get $a-len)
                                                 (local.get $b-len))))
           (local.set $k    (i32.div_u
                             (call $bignum-size-add/i32
                                   (local.get $max-len)
                                   (i32.const 1))
                             (i32.const 2)))
           (local.set $bits
                      (call $bignum-size-mul/i32
                            (local.get $k)
                            (i32.const 32)))
           (local.set $x0   (call $bignum-limb-slice
                                  (local.get $a) (i32.const 0) (local.get $k)))
           (local.set $x1   (call $bignum-limb-slice
                                  (local.get $a) (local.get $k) (local.get $k)))
           (local.set $y0   (call $bignum-limb-slice
                                  (local.get $b) (i32.const 0) (local.get $k)))
           (local.set $y1   (call $bignum-limb-slice
                                  (local.get $b) (local.get $k) (local.get $k)))

           ;; Compute z0, z2, and the difference product for Karatsuba's middle term.
           (local.set $z0 (call $integer-mul/2 (local.get $x0) (local.get $y0)))
           (local.set $z2 (call $integer-mul/2 (local.get $x1) (local.get $y1)))
           (local.set $d  (call $integer-mul/2
                                (call $integer-sub/2
                                      (local.get $x1) (local.get $x0))
                                (call $integer-sub/2
                                      (local.get $y1) (local.get $y0))))
           (local.set $mid (call $integer-sub/2
                                 (call $integer-add/2
                                       (local.get $z0) (local.get $z2))
                                 (local.get $d)))

           ;; Recombine z0 + mid*B + z2*B^2 where B is 2^(32*k).
           (local.set $result (local.get $z0))
           (local.set $result
                      (call $integer-add/2
                            (local.get $result)
                            (call $integer-shl-by-i32
                                  (local.get $mid) (local.get $bits))))
           (local.set $result
                      (call $integer-add/2
                            (local.get $result)
                            (call $integer-shl-by-i32
                                  (local.get $z2)
                                  (call $bignum-size-mul/i32
                                        (local.get $bits)
                                        (i32.const 2)))))
           (local.get $result))

     ;; For a square, Karatsuba uses the same split:
     ;;
     ;;     x = x0 + x1*B
     ;;
     ;; A direct square is:
     ;;
     ;;     x^2 = x0^2 + 2*x0*x1*B + x1^2*B^2
     ;;
     ;; The middle term is found with one extra square:
     ;;
     ;;     z0  = x0^2
     ;;     z2  = x1^2
     ;;     d   = (x1 - x0)^2
     ;;     mid = z0 + z2 - d = 2*x0*x1
     ;;
     ;; Then it combines:
     ;;
     ;;     x^2 = z0 + mid*B + z2*B^2

     ;; $bignum-square-karatsuba : bignum? -> exact-nonnegative-integer?
     ;;   Square a magnitude with Karatsuba's three-square identity.
     (func $bignum-square-karatsuba
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $len    i32)
           (local $k      i32)
           (local $bits   i32)
           (local $x0     (ref eq))
           (local $x1     (ref eq))
           (local $z0     (ref eq))
           (local $z2     (ref eq))
           (local $d      (ref eq))
           (local $mid    (ref eq))
           (local $result (ref eq))

           ;; Split the operand at k limbs, where k is half the length.
           (local.set $len
                      (array.len
                       (struct.get $Bignum $limbs (local.get $b))))
           (local.set $k
                      (i32.div_u
                       (call $bignum-size-add/i32
                             (local.get $len)
                             (i32.const 1))
                       (i32.const 2)))
           (local.set $bits
                      (call $bignum-size-mul/i32
                            (local.get $k)
                            (i32.const 32)))
           (local.set $x0
                      (call $bignum-limb-slice
                            (local.get $b) (i32.const 0) (local.get $k)))
           (local.set $x1
                      (call $bignum-limb-slice
                            (local.get $b) (local.get $k) (local.get $k)))

           ;; Compute the low square, high square, and square of the difference.
           (local.set $z0
                      (call $integer-mul/2 (local.get $x0) (local.get $x0)))
           (local.set $z2
                      (call $integer-mul/2 (local.get $x1) (local.get $x1)))
           (local.set $d
                      (call $integer-mul/2
                            (call $integer-sub/2
                                  (local.get $x1) (local.get $x0))
                            (call $integer-sub/2
                                  (local.get $x1) (local.get $x0))))
           (local.set $mid
                      (call $integer-sub/2
                            (call $integer-add/2
                                  (local.get $z0) (local.get $z2))
                            (local.get $d)))

           ;; Recombine z0 + mid*B + z2*B^2 where B is 2^(32*k).
           (local.set $result (local.get $z0))
           (local.set $result
                      (call $integer-add/2
                            (local.get $result)
                            (call $integer-shl-by-i32
                                  (local.get $mid) (local.get $bits))))
           (local.set $result
                      (call $integer-add/2
                            (local.get $result)
                            (call $integer-shl-by-i32
                                  (local.get $z2)
                                  (call $bignum-size-mul/i32
                                        (local.get $bits)
                                        (i32.const 2)))))
           (local.get $result))

     ;;;
     ;;; Toom-Cook Multiplication
     ;;;

     ;; Toom-3 splits each operand into three chunks:
     ;;
     ;;     x = x0 + x1*B + x2*B^2
     ;;     y = y0 + y1*B + y2*B^2
     ;;
     ;; The product has five coefficients:
     ;;
     ;;     x*y = w0 + w1*B + w2*B^2 + w3*B^3 + w4*B^4
     ;;
     ;; Instead of computing all nine pairwise products, Toom-3 evaluates
     ;; x and y at 0, 1, -1, 2, and infinity, multiplies those values, then
     ;; interpolates the coefficients:
     ;;
     ;;     q0  = x(0)*y(0)               = w0
     ;;     q1  = x(1)*y(1)
     ;;     qm1 = x(-1)*y(-1)
     ;;     q2  = x(2)*y(2)
     ;;     q4  = x(infinity)*y(infinity) = w4
     ;;
     ;; The code recovers the middle coefficients with exact division:
     ;;
     ;;     s1   = q1  - q0 - q4  =  w1 + w2 + w3
     ;;     sm1  = qm1 - q0 - q4  = -w1 + w2 - w3
     ;;     w2   = (s1 + sm1)/2
     ;;     odd  = (s1 - sm1)/2   =  w1 + w3
     ;;     t    = (q2 - q0 - 16*q4 - 4*w2)/2 = w1 + 4*w3
     ;;     w3   = (t - odd)/3
     ;;     w1   = odd - w3
     ;;
     ;; Then it combines:
     ;;
     ;;     x*y = q0 + w1*B + w2*B^2 + w3*B^3 + q4*B^4

     ;; $bignum-mul-toom3-magnitude : bignum? bignum? -> exact-nonnegative-integer?
     ;;   Multiply magnitudes by evaluating and interpolating a three-way split.
     (func $bignum-mul-toom3-magnitude
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-len  i32)
           (local $b-len  i32)
           (local $max-len i32)
           (local $k      i32)
           (local $bits   i32)
           (local $x0     (ref eq))
           (local $x1     (ref eq))
           (local $x2     (ref eq))
           (local $y0     (ref eq))
           (local $y1     (ref eq))
           (local $y2     (ref eq))
           (local $p1     (ref eq))
           (local $pm1    (ref eq))
           (local $p2     (ref eq))
           (local $q1     (ref eq))
           (local $qm1    (ref eq))
           (local $q2     (ref eq))
           (local $q0     (ref eq))
           (local $q4     (ref eq))
           (local $s1     (ref eq))
           (local $sm1    (ref eq))
           (local $w1     (ref eq))
           (local $w2     (ref eq))
           (local $w3     (ref eq))
           (local $odd    (ref eq))
           (local $t      (ref eq))
           (local $result (ref eq))

           ;; Split both operands into three k-limb chunks.
           (local.set $a-len
                      (array.len
                       (struct.get $Bignum $limbs (local.get $a))))
           (local.set $b-len
                      (array.len
                       (struct.get $Bignum $limbs (local.get $b))))
           (local.set $max-len
                      (select (local.get $a-len)
                              (local.get $b-len)
                              (i32.gt_u (local.get $a-len)
                                        (local.get $b-len))))
           (local.set $k
                      (i32.div_u
                       (call $bignum-size-add/i32
                             (local.get $max-len)
                             (i32.const 2))
                       (i32.const 3)))
           (local.set $bits
                      (call $bignum-size-mul/i32
                            (local.get $k)
                            (i32.const 32)))
           (local.set $x0
                      (call $bignum-limb-slice
                            (local.get $a) (i32.const 0) (local.get $k)))
           (local.set $x1
                      (call $bignum-limb-slice
                            (local.get $a) (local.get $k) (local.get $k)))
           (local.set $x2
                      (call $bignum-limb-slice
                            (local.get $a)
                            (call $bignum-size-mul/i32
                                  (local.get $k)
                                  (i32.const 2))
                            (local.get $k)))
           (local.set $y0
                      (call $bignum-limb-slice
                            (local.get $b) (i32.const 0) (local.get $k)))
           (local.set $y1
                      (call $bignum-limb-slice
                            (local.get $b) (local.get $k) (local.get $k)))
           (local.set $y2
                      (call $bignum-limb-slice
                            (local.get $b)
                            (call $bignum-size-mul/i32
                                  (local.get $k)
                                  (i32.const 2))
                            (local.get $k)))

           ;; Evaluate and multiply at 0 and infinity.
           (local.set $q0
                      (call $integer-mul/2 (local.get $x0) (local.get $y0)))
           (local.set $q4
                      (call $integer-mul/2 (local.get $x2) (local.get $y2)))

           ;; Evaluate and multiply at 1.
           (local.set $p1
                      (call $integer-add/2
                            (call $integer-add/2
                                  (local.get $x0) (local.get $x1))
                            (local.get $x2)))
           (local.set $q1
                      (call $integer-mul/2
                            (local.get $p1)
                            (call $integer-add/2
                                  (call $integer-add/2
                                        (local.get $y0) (local.get $y1))
                                  (local.get $y2))))

           ;; Evaluate and multiply at -1.
           (local.set $pm1
                      (call $integer-add/2
                            (call $integer-sub/2
                                  (local.get $x0) (local.get $x1))
                            (local.get $x2)))
           (local.set $qm1
                      (call $integer-mul/2
                            (local.get $pm1)
                            (call $integer-add/2
                                  (call $integer-sub/2
                                        (local.get $y0) (local.get $y1))
                                  (local.get $y2))))

           ;; Evaluate and multiply at 2.
           (local.set $p2
                      (call $integer-add/2
                            (call $integer-add/2
                                  (local.get $x0)
                                  (call $integer-shl-by-i32
                                        (local.get $x1) (i32.const 1)))
                            (call $integer-shl-by-i32
                                  (local.get $x2) (i32.const 2))))
           (local.set $q2
                      (call $integer-mul/2
                            (local.get $p2)
                            (call $integer-add/2
                                  (call $integer-add/2
                                        (local.get $y0)
                                        (call $integer-shl-by-i32
                                              (local.get $y1) (i32.const 1)))
                                  (call $integer-shl-by-i32
                                        (local.get $y2) (i32.const 2)))))

           ;; Remove the known q0 and q4 contributions from q(1) and q(-1).
           (local.set $s1
                      (call $integer-sub/2
                            (call $integer-sub/2
                                  (local.get $q1) (local.get $q0))
                            (local.get $q4)))
           (local.set $sm1
                      (call $integer-sub/2
                            (call $integer-sub/2
                                  (local.get $qm1) (local.get $q0))
                            (local.get $q4)))

           ;; Recover the even middle coefficient contribution.
           (local.set $w2
                      (call $integer-divexact-by-i32
                            (call $integer-add/2
                                  (local.get $s1) (local.get $sm1))
                            (i32.const 2)))

           ;; Recover w1 + w3 from the odd part.
           (local.set $odd
                      (call $integer-divexact-by-i32
                            (call $integer-sub/2
                                  (local.get $s1) (local.get $sm1))
                            (i32.const 2)))

           ;; Use q(2) to isolate the remaining cubic contribution.
           (local.set $t
                      (call $integer-divexact-by-i32
                            (call $integer-sub/2
                                  (call $integer-sub/2
                                        (call $integer-sub/2
                                              (local.get $q2) (local.get $q0))
                                        (call $integer-shl-by-i32
                                              (local.get $q4) (i32.const 4)))
                                  (call $integer-shl-by-i32
                                        (local.get $w2) (i32.const 2)))
                            (i32.const 2)))
           (local.set $w3
                      (call $integer-divexact-by-i32
                            (call $integer-sub/2
                                  (local.get $t) (local.get $odd))
                            (i32.const 3)))
           (local.set $w1
                      (call $integer-sub/2
                            (local.get $odd) (local.get $w3)))

           ;; Recombine q0 + w1*B + w2*B^2 + w3*B^3 + q4*B^4.
           (local.set $result (local.get $q0))
           (local.set $result
                      (call $integer-add/2
                            (local.get $result)
                            (call $integer-shl-by-i32
                                  (local.get $w1) (local.get $bits))))
           (local.set $result
                      (call $integer-add/2
                            (local.get $result)
                            (call $integer-shl-by-i32
                                  (local.get $w2)
                                  (call $bignum-size-mul/i32
                                        (local.get $bits)
                                        (i32.const 2)))))
           (local.set $result
                      (call $integer-add/2
                            (local.get $result)
                            (call $integer-shl-by-i32
                                  (local.get $w3)
                                  (call $bignum-size-mul/i32
                                        (local.get $bits)
                                        (i32.const 3)))))
           (call $integer-add/2
                 (local.get $result)
                 (call $integer-shl-by-i32
                       (local.get $q4)
                       (call $bignum-size-mul/i32
                             (local.get $bits)
                             (i32.const 4)))))

     ;;;
     ;;; Multiplication Dispatch
     ;;;

     ;; $bignum-square : bignum? -> exact-nonnegative-integer?
     ;;   Select the tuned square algorithm for a bignum magnitude.
     (func $bignum-square
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $len i32)

           ;; Select the square algorithm by tuned limb thresholds.
           (local.set $len
                      (array.len
                       (struct.get $Bignum $limbs (local.get $b))))
           (if (i32.ge_u (local.get $len)
                         (i32.const ,bignum-sqr-toom3-threshold))
               (then
                (return
                 (call $bignum-mul-toom3-magnitude
                       (local.get $b) (local.get $b)))))
           (if (i32.ge_u (local.get $len)
                         (i32.const ,bignum-sqr-karatsuba-threshold))
               (then
                (return (call $bignum-square-karatsuba (local.get $b)))))
           (call $bignum-square-basecase (local.get $b)))

     ;; $bignum-mul : bignum? bignum? -> exact-integer?
     ;;   Select a tuned multiplication algorithm for signed canonical bignums.
     (func $bignum-mul
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-limbs (ref $I32Array))
           (local $b-limbs (ref $I32Array))
           (local $a-len i32)
           (local $b-len i32)
           (local $min-len i32)
           (local $max-len i32)
           (local $sign i32)
           (local $shift i32)

           ;; Load limb arrays and derive operand sizes and result sign.
           (local.set $a-limbs (struct.get $Bignum $limbs (local.get $a)))
           (local.set $b-limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $a-len   (array.len (local.get $a-limbs)))
           (local.set $b-len   (array.len (local.get $b-limbs)))
           (local.set $min-len (select (local.get $a-len)
                                       (local.get $b-len)
                                       (i32.lt_u (local.get $a-len)
                                                 (local.get $b-len))))
           (local.set $max-len (select (local.get $a-len)
                                       (local.get $b-len)
                                       (i32.gt_u (local.get $a-len)
                                                 (local.get $b-len))))
           (local.set $sign    (select (i32.const  1)
                                       (i32.const -1)
                                       (i32.eq (struct.get $Bignum $sign (local.get $a))
                                               (struct.get $Bignum $sign (local.get $b)))))

           ;; A one-limb operand uses the specialized bignum-by-u32 path.
           (if (i32.eq (local.get $a-len) (i32.const 1))
               (then
                (return
                 (call $bignum-mul-u32
                       (local.get $b)
                       (array.get $I32Array
                                  (local.get $a-limbs)
                                  (i32.const 0))
                       (local.get $sign)))))
           (if (i32.eq (local.get $b-len) (i32.const 1))
               (then
                (return
                 (call $bignum-mul-u32
                       (local.get $a)
                       (array.get $I32Array
                                  (local.get $b-limbs)
                                  (i32.const 0))
                       (local.get $sign)))))

           ;; Multiplication by a power of two is a signed left shift.
           (local.set $shift (call $bignum-power-of-two-shift/i32
                                   (local.get $a)))
           (if (i32.ge_s (local.get $shift) (i32.const 0))
               (then
                (return
                 (call $integer-shl-by-i32/sign
                       (local.get $b)
                       (local.get $shift)
                       (local.get $sign)))))
           (local.set $shift (call $bignum-power-of-two-shift/i32
                                   (local.get $b)))
           (if (i32.ge_s (local.get $shift) (i32.const 0))
               (then
                (return
                 (call $integer-shl-by-i32/sign
                       (local.get $a)
                       (local.get $shift)
                       (local.get $sign)))))

           ;; Smaller equal operands are not consistently faster with the
           ;; square-specific carry bookkeeping.
           (if (i32.and
                (i32.ge_u (local.get $a-len)
                          (i32.const ,bignum-sqr-basecase-threshold))
                (i32.and
                 (i32.gt_s (local.get $sign) (i32.const 0))
                 (i32.eqz
                  (call $bignum-magnitude-compare/i32
                        (local.get $a-limbs)
                        (local.get $b-limbs)))))
               (then
                (return
                 (call $bignum-square (local.get $a)))))
           ;; Recursive algorithms are only selected for comparably sized
           ;; operands. Rectangular schoolbook multiplication remains the
           ;; baseline for unbalanced inputs until separately tuned.
           (if (i32.and
                (i64.le_u
                 (i64.extend_i32_u (local.get $max-len))
                 (i64.mul
                  (i64.extend_i32_u (local.get $min-len))
                  (i64.const ,bignum-mul-max-balance-ratio)))
                (i32.ge_u (local.get $max-len)
                          (i32.const ,bignum-mul-toom3-threshold)))
               (then
                (return
                 (call $integer-apply-sign
                       (call $bignum-mul-toom3-magnitude
                             (local.get $a) (local.get $b))
                       (local.get $sign)))))
           (if (i32.and
                (i64.le_u
                 (i64.extend_i32_u (local.get $max-len))
                 (i64.mul
                  (i64.extend_i32_u (local.get $min-len))
                  (i64.const ,bignum-mul-max-balance-ratio)))
                (i32.ge_u (local.get $max-len)
                          (i32.const ,bignum-mul-karatsuba-threshold)))
               (then
                (return
                 (call $integer-apply-sign
                       (call $bignum-mul-karatsuba-magnitude
                             (local.get $a) (local.get $b))
                       (local.get $sign)))))

           ;; Final fallback: use schoolbook multiplication and apply the sign.
           (call $integer-apply-sign
                 (call $bignum-mul-schoolbook-magnitude
                       (local.get $a) (local.get $b))
                 (local.get $sign)))

     ;;;
     ;;; Exact Integer Arithmetic
     ;;;

     ;; $integer-add/2 : exact-integer? exact-integer? -> exact-integer?
     ;;   Add exact integers, promoting fixnum overflow to bignums.
     (func $integer-add/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $xv i64)
           (local $yv i64)

           ;; Fixnum plus fixnum uses i64 arithmetic so overflow can promote cleanly.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (ref.test (ref i31) (local.get $y))
                    (then
                     (local.set $xv
                                (i64.extend_i32_s
                                 (i32.shr_s
                                  (i31.get_s
                                   (ref.cast (ref i31) (local.get $x)))
                                  (i32.const 1))))
                     (local.set $yv
                                (i64.extend_i32_s
                                 (i32.shr_s
                                  (i31.get_s
                                   (ref.cast (ref i31) (local.get $y)))
                                  (i32.const 1))))
                     (return
                      (call $integer-from-i64
                            (i64.add (local.get $xv) (local.get $yv))))))
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (then (return (local.get $y))))

                ;; Nonzero fixnum plus bignum promotes the fixnum to one limb.
                (return
                 (call $bignum-add
                       (call $nonzero-fixnum->bignum (local.get $x))
                       (ref.cast (ref $Bignum) (local.get $y))))))

           ;; Bignum plus fixnum handles zero as an identity and otherwise promotes.
           (if (ref.test (ref i31) (local.get $y))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $y))))
                    (then (return (local.get $x))))
                (return
                 (call $bignum-add
                       (ref.cast (ref $Bignum) (local.get $x))
                       (call $nonzero-fixnum->bignum (local.get $y))))))

           ;; Bignum plus bignum delegates to the signed bignum helper.
           (call $bignum-add
                 (ref.cast (ref $Bignum) (local.get $x))
                 (ref.cast (ref $Bignum) (local.get $y))))

     ;; $integer-sub/2 : exact-integer? exact-integer? -> exact-integer?
     ;;   Subtract exact integers, promoting fixnum overflow to bignums.
     (func $integer-sub/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $xv i64)
           (local $yv i64)

           ;; Fixnum minus fixnum uses i64 arithmetic so overflow can promote cleanly.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (ref.test (ref i31) (local.get $y))
                    (then
                     (local.set $xv
                                (i64.extend_i32_s
                                 (i32.shr_s
                                  (i31.get_s
                                   (ref.cast (ref i31) (local.get $x)))
                                  (i32.const 1))))
                     (local.set $yv
                                (i64.extend_i32_s
                                 (i32.shr_s
                                  (i31.get_s
                                   (ref.cast (ref i31) (local.get $y)))
                                  (i32.const 1))))
                     (return
                      (call $integer-from-i64
                            (i64.sub (local.get $xv) (local.get $yv))))))
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (then
                     (return
                      (call $bignum-negate
                            (ref.cast (ref $Bignum) (local.get $y))))))

                ;; Nonzero fixnum minus bignum promotes the fixnum to one limb.
                (return
                 (call $bignum-sub
                       (call $nonzero-fixnum->bignum (local.get $x))
                       (ref.cast (ref $Bignum) (local.get $y))))))

           ;; Bignum minus fixnum handles zero as an identity and otherwise promotes.
           (if (ref.test (ref i31) (local.get $y))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $y))))
                    (then (return (local.get $x))))
                (return
                 (call $bignum-sub
                       (ref.cast (ref $Bignum) (local.get $x))
                       (call $nonzero-fixnum->bignum (local.get $y))))))

           ;; Bignum minus bignum delegates to the signed bignum helper.
           (call $bignum-sub
                 (ref.cast (ref $Bignum) (local.get $x))
                 (ref.cast (ref $Bignum) (local.get $y))))

     ;; $integer-mul/2 : exact-integer? exact-integer? -> exact-integer?
     ;;   Multiply exact integers, promoting fixnum overflow to bignums.
     (func $integer-mul/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $xv i64)
           (local $yv i64)
           (local $sign i32)
           (local $shift i32)

           ;; A zero fixnum operand makes the whole product fixnum zero.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (then (return (ref.i31 (i32.const 0)))))

                ;; Fixnum times fixnum uses i64 arithmetic so overflow can promote cleanly.
                (if (ref.test (ref i31) (local.get $y))
                    (then
                     (local.set $xv
                                (i64.extend_i32_s
                                 (i32.shr_s
                                  (i31.get_s
                                   (ref.cast (ref i31) (local.get $x)))
                                  (i32.const 1))))
                     (local.set $yv
                                (i64.extend_i32_s
                                 (i32.shr_s
                                  (i31.get_s
                                   (ref.cast (ref i31) (local.get $y)))
                                  (i32.const 1))))
                     (return
                     (call $integer-from-i64
                            (i64.mul (local.get $xv) (local.get $yv))))))

                ;; Fixnum times bignum uses a shift fast path for powers of two.
                (local.set $sign
                           (select (i32.const 1)
                                   (i32.const -1)
                                   (i32.eq (call $integer-sign/i32
                                                 (local.get $x))
                                           (call $integer-sign/i32
                                                 (local.get $y)))))
                (local.set $shift
                           (call $bignum-power-of-two-shift/i32
                                 (ref.cast (ref $Bignum) (local.get $y))))
                (if (i32.ge_s (local.get $shift) (i32.const 0))
                    (then
                     (return
                      (call $integer-shl-by-i32/sign
                            (local.get $x)
                            (local.get $shift)
                            (local.get $sign)))))
                (return
                 (call $bignum-mul-u32
                       (ref.cast (ref $Bignum) (local.get $y))
                       (call $integer-abs-u32 (local.get $x))
                       (local.get $sign)))))

           ;; Bignum times fixnum mirrors the fixnum-times-bignum cases.
           (if (ref.test (ref i31) (local.get $y))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $y))))
                    (then (return (ref.i31 (i32.const 0)))))
                (local.set $sign
                           (select (i32.const 1)
                                   (i32.const -1)
                                   (i32.eq (call $integer-sign/i32
                                                 (local.get $x))
                                           (call $integer-sign/i32
                                                 (local.get $y)))))
                (local.set $shift
                           (call $bignum-power-of-two-shift/i32
                                 (ref.cast (ref $Bignum) (local.get $x))))
                (if (i32.ge_s (local.get $shift) (i32.const 0))
                    (then
                     (return
                      (call $integer-shl-by-i32/sign
                            (local.get $y)
                            (local.get $shift)
                            (local.get $sign)))))
                (return
                 (call $bignum-mul-u32
                       (ref.cast (ref $Bignum) (local.get $x))
                       (call $integer-abs-u32 (local.get $y))
                       (local.get $sign)))))

           ;; Bignum times bignum uses the tuned multiplication dispatcher.
           (call $bignum-mul
                 (ref.cast (ref $Bignum) (local.get $x))
                 (ref.cast (ref $Bignum) (local.get $y))))

     ;;;
     ;;; Integer Utilities
     ;;;

     ;; $integer-zero?/i32 : exact-integer? -> i32
     ;;   Return 1 when x is exact zero, otherwise 0.
     (func $integer-zero?/i32
           (param $x (ref eq))
           (result i32)

           ;; Only the fixnum representation can be zero; bignums are nonzero.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (return
                 (i32.eqz
                  (i31.get_s (ref.cast (ref i31) (local.get $x)))))))
           (i32.const 0))

     ;; $integer-even?/i32 : exact-integer? -> i32
     ;;   Return 1 when x is even, otherwise 0.
     (func $integer-even?/i32
           (param $x (ref eq))
           (result i32)

           (local $bits i32)
           (local $bn   (ref $Bignum))

           ;; For fixnums, test the low value bit after untagging.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $bits
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (return
                 (i32.eqz
                  (i32.and (local.get $bits) (i32.const 1))))))

           ;; For bignums, evenness is determined by the low limb.
           (local.set $bn (ref.cast (ref $Bignum) (local.get $x)))
           (i32.eqz
            (i32.and
             (array.get $I32Array
                        (struct.get $Bignum $limbs (local.get $bn))
                        (i32.const 0))
             (i32.const 1))))

     ;; $integer-sign/i32 : exact-integer? -> i32
     ;;   Return -1, 0, or 1 according to the exact integer's sign.
     (func $integer-sign/i32
           (param $x (ref eq))
           (result i32)

           (local $v i32)

           ;; Fixnums need explicit zero handling before extracting +/-1.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $v
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (if (i32.eqz (local.get $v))
                    (then (return (i32.const 0))))
                (return
                 (select (i32.const 1)
                         (i32.const -1)
                         (i32.gt_s (local.get $v) (i32.const 0))))))

           ;; Bignums store their sign directly.
           (struct.get $Bignum $sign (ref.cast (ref $Bignum) (local.get $x))))

     ;; $integer-abs-u32 : exact-integer? -> i32
     ;;   Return the absolute magnitude when it fits one unsigned 32-bit limb.
     (func $integer-abs-u32
           (param $x (ref eq))
           (result i32)

           (local $v i32)

           ;; For fixnums, decode and conditionally negate the signed payload.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $v
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (return
                 (select (i32.sub (i32.const 0) (local.get $v))
                         (local.get $v)
                         (i32.lt_s (local.get $v) (i32.const 0))))))

           ;; The caller only asks this for one-limb bignums.
           (array.get $I32Array
                      (struct.get $Bignum $limbs
                                  (ref.cast (ref $Bignum) (local.get $x)))
                      (i32.const 0)))

     ;; $integer-single-limb?/i32 : exact-integer? -> i32
     ;;   Return 1 when the exact integer's magnitude fits one 32-bit limb.
     (func $integer-single-limb?/i32
           (param $x (ref eq))
           (result i32)

           ;; Every fixnum magnitude fits in one unsigned 32-bit limb.
           (if (ref.test (ref i31) (local.get $x))
               (then (return (i32.const 1))))

           ;; Bignums are single-limb exactly when their limb array length is one.
           (i32.eq
            (array.len
             (struct.get $Bignum $limbs
                         (ref.cast (ref $Bignum) (local.get $x))))
            (i32.const 1)))

     ;; $exact-nonnegative-integer->i32/saturating : any/c -> i32
     ;;   Decode exact nonnegative integers; return -1 on contract failures and saturate overflow.
     (func $exact-nonnegative-integer->i32/saturating
           (param $x (ref eq))
           (result i32)

           (local $bits  i32)
           (local $idx   i32)
           (local $bn    (ref $Bignum))
           (local $limbs (ref $I32Array))
           (local $len   i32)
           (local $limb  i32)

           ;; Decode a nonnegative fixnum, rejecting immediates and negatives.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                (if (i32.and (local.get $bits) (i32.const 1))
                    (then (return (i32.const -1))))
                (local.set $idx (i32.shr_s (local.get $bits) (i32.const 1)))
                (if (i32.lt_s (local.get $idx) (i32.const 0))
                    (then (return (i32.const -1))))
                (return (local.get $idx))))

           ;; Non-bignum values and negative bignums fail the contract.
           (if (i32.eqz (ref.test (ref $Bignum) (local.get $x)))
               (then (return (i32.const -1))))
           (local.set $bn (ref.cast (ref $Bignum) (local.get $x)))
           (if (i32.lt_s (struct.get $Bignum $sign (local.get $bn))
                         (i32.const 0))
               (then (return (i32.const -1))))

           ;; More than one limb, or one limb above INT32_MAX, saturates.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $bn)))
           (local.set $len (array.len (local.get $limbs)))
           (if (i32.eqz (local.get $len))
               (then (return (i32.const 0))))
           (if (i32.gt_u (local.get $len) (i32.const 1))
               (then (return (i32.const 2147483647))))
           (local.set $limb
                      (array.get $I32Array (local.get $limbs) (i32.const 0)))
           (if (i32.gt_u (local.get $limb) (i32.const 2147483647))
               (then (return (i32.const 2147483647))))
           (local.get $limb))

     ;; $integer-apply-sign : exact-integer? i32 -> exact-integer?
     ;;   Apply sign to a nonnegative exact integer magnitude.
     (func $integer-apply-sign
           (param $mag  (ref eq))
           (param $sign i32)
           (result (ref eq))

           ;; Negative signs negate fixnum magnitudes or rebuild bignums with sign -1.
           (if (i32.lt_s (local.get $sign) (i32.const 0))
               (then
                (if (ref.test (ref i31) (local.get $mag))
                    (then (return (call $integer-negate (local.get $mag)))))
                (return
                 (call $bignum-normalize
                       (i32.const -1)
                       (struct.get $Bignum $limbs
                                   (ref.cast (ref $Bignum)
                                             (local.get $mag)))))))

           ;; Positive signs leave the nonnegative magnitude unchanged.
           (local.get $mag))

     ;;;
     ;;; Bitwise Arithmetic
     ;;;

     ;; $integer-nonnegative-limb-count/i32 : exact-nonnegative-integer? -> i32
     ;;   Return the number of finite magnitude limbs needed for x.
     (func $integer-nonnegative-limb-count/i32
           (param $x (ref eq))
           (result i32)

           ;; Zero fixnums have no finite nonzero limbs; other fixnums have one.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (i32.eqz (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (then (return (i32.const 0))))
                (return (i32.const 1))))

           ;; Bignums expose their finite limb count directly.
           (array.len
            (struct.get $Bignum $limbs
                        (ref.cast (ref $Bignum) (local.get $x)))))

     ;; $integer-nonnegative-limb/u32 : exact-nonnegative-integer? i32 -> i32
     ;;   Return limb i of x, or 0 beyond x's finite magnitude.
     (func $integer-nonnegative-limb/u32
           (param $x (ref eq))
           (param $i i32)
           (result i32)

           (local $limbs (ref $I32Array))

           ;; Fixnums contribute one low limb and implicit zeros above it.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (i32.eqz (local.get $i))
                    (then
                     (return
                      (i32.shr_u
                       (i31.get_s (ref.cast (ref i31) (local.get $x)))
                        (i32.const 1)))))
                (return (i32.const 0))))

           ;; Bignums return stored limbs in range and implicit zeros beyond them.
           (local.set $limbs
                      (struct.get $Bignum $limbs
                                  (ref.cast (ref $Bignum) (local.get $x))))
           (if (i32.lt_u (local.get $i) (array.len (local.get $limbs)))
               (then
                (return
                 (array.get $I32Array
                            (local.get $limbs)
                            (local.get $i)))))
           (i32.const 0))

     ;; $integer-bitwise-and/nonnegative : exact-nonnegative-integer? exact-nonnegative-integer? -> exact-nonnegative-integer?
     ;;   Compute finite-limb bitwise and for nonnegative exact integers.
     (func $integer-bitwise-and/nonnegative
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-len   i32)
           (local $y-len   i32)
           (local $out-len i32)
           (local $out     (ref $I32Array))
           (local $i       i32)

           ;; AND only needs limbs present in both finite magnitudes.
           (local.set $x-len (call $integer-nonnegative-limb-count/i32
                                   (local.get $x)))
           (local.set $y-len (call $integer-nonnegative-limb-count/i32
                                   (local.get $y)))
           (local.set $out-len
                      (select (local.get $x-len)
                              (local.get $y-len)
                              (i32.lt_u (local.get $x-len)
                                        (local.get $y-len))))
           (if (i32.eqz (local.get $out-len))
               (then (return (ref.i31 (i32.const 0)))))
           (local.set $out (array.new_default $I32Array
                                              (local.get $out-len)))

           ;; Combine each finite limb pair with bitwise AND.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i)
                                         (local.get $out-len)))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $i)
                                   (i32.and
                                    (call $integer-nonnegative-limb/u32
                                          (local.get $x)
                                          (local.get $i))
                                    (call $integer-nonnegative-limb/u32
                                          (local.get $y)
                                          (local.get $i))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (call $bignum-normalize (i32.const 1) (local.get $out)))

     ;; $integer-bitwise-ior/nonnegative : exact-nonnegative-integer? exact-nonnegative-integer? -> exact-nonnegative-integer?
     ;;   Compute finite-limb bitwise inclusive-or for nonnegative exact integers.
     (func $integer-bitwise-ior/nonnegative
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-len   i32)
           (local $y-len   i32)
           (local $out-len i32)
           (local $out     (ref $I32Array))
           (local $i       i32)

           ;; IOR needs limbs up to the larger finite magnitude.
           (local.set $x-len (call $integer-nonnegative-limb-count/i32
                                   (local.get $x)))
           (local.set $y-len (call $integer-nonnegative-limb-count/i32
                                   (local.get $y)))
           (local.set $out-len
                      (select (local.get $x-len)
                              (local.get $y-len)
                              (i32.gt_u (local.get $x-len)
                                        (local.get $y-len))))
           (if (i32.eqz (local.get $out-len))
               (then (return (ref.i31 (i32.const 0)))))
           (local.set $out (array.new_default $I32Array
                                              (local.get $out-len)))

           ;; Combine each finite limb pair with bitwise inclusive-or.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i)
                                         (local.get $out-len)))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $i)
                                   (i32.or
                                    (call $integer-nonnegative-limb/u32
                                          (local.get $x)
                                          (local.get $i))
                                    (call $integer-nonnegative-limb/u32
                                          (local.get $y)
                                          (local.get $i))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (call $bignum-normalize (i32.const 1) (local.get $out)))

     ;; $integer-bitwise-xor/nonnegative : exact-nonnegative-integer? exact-nonnegative-integer? -> exact-nonnegative-integer?
     ;;   Compute finite-limb bitwise exclusive-or for nonnegative exact integers.
     (func $integer-bitwise-xor/nonnegative
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-len   i32)
           (local $y-len   i32)
           (local $out-len i32)
           (local $out     (ref $I32Array))
           (local $i       i32)

           ;; XOR needs limbs up to the larger finite magnitude.
           (local.set $x-len (call $integer-nonnegative-limb-count/i32
                                   (local.get $x)))
           (local.set $y-len (call $integer-nonnegative-limb-count/i32
                                   (local.get $y)))
           (local.set $out-len
                      (select (local.get $x-len)
                              (local.get $y-len)
                              (i32.gt_u (local.get $x-len)
                                        (local.get $y-len))))
           (if (i32.eqz (local.get $out-len))
               (then (return (ref.i31 (i32.const 0)))))
           (local.set $out (array.new_default $I32Array
                                              (local.get $out-len)))

           ;; Combine each finite limb pair with bitwise exclusive-or.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i)
                                         (local.get $out-len)))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $i)
                                   (i32.xor
                                    (call $integer-nonnegative-limb/u32
                                          (local.get $x)
                                          (local.get $i))
                                    (call $integer-nonnegative-limb/u32
                                          (local.get $y)
                                          (local.get $i))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (call $bignum-normalize (i32.const 1) (local.get $out)))

     ;; $integer-bitwise-andnot/nonnegative : exact-nonnegative-integer? exact-nonnegative-integer? -> exact-nonnegative-integer?
     ;;   Compute x & (bitwise-not y) for nonnegative exact integers.
     (func $integer-bitwise-andnot/nonnegative
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $out-len i32)
           (local $out     (ref $I32Array))
           (local $i       i32)

           ;; AND-NOT only needs limbs present in x's finite magnitude.
           (local.set $out-len
                      (call $integer-nonnegative-limb-count/i32
                            (local.get $x)))
           (if (i32.eqz (local.get $out-len))
               (then (return (ref.i31 (i32.const 0)))))
           (local.set $out (array.new_default $I32Array
                                              (local.get $out-len)))

           ;; Combine x with the limbwise complement of y.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $i)
                                         (local.get $out-len)))
                        (array.set $I32Array
                                   (local.get $out)
                                   (local.get $i)
                                   (i32.and
                                    (call $integer-nonnegative-limb/u32
                                          (local.get $x)
                                          (local.get $i))
                                    (i32.xor
                                     (call $integer-nonnegative-limb/u32
                                           (local.get $y)
                                           (local.get $i))
                                     (i32.const -1))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (call $bignum-normalize (i32.const 1) (local.get $out)))

     ;; $integer-bitwise-complement : exact-integer? -> exact-integer?
     ;;   Compute the infinite two's-complement bitwise not.
     (func $integer-bitwise-complement
           (param $x (ref eq))
           (result (ref eq))

           ;; In infinite two's-complement arithmetic, ~x is -1 - x.
           (call $integer-sub/2 (ref.i31 (i32.const -2)) (local.get $x)))

     ;; $integer-bitwise-and/2 : exact-integer? exact-integer? -> exact-integer?
     ;;   Compute infinite two's-complement bitwise and.
     (func $integer-bitwise-and/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-neg? i32)
           (local $y-neg? i32)
           (local $xc     (ref eq))
           (local $yc     (ref eq))

           ;; Track which operands are negative and preallocate complement slots.
           (local.set $xc (ref.i31 (i32.const 0)))
           (local.set $yc (ref.i31 (i32.const 0)))
           (local.set $x-neg? (i32.lt_s (call $integer-sign/i32 (local.get $x))
                                        (i32.const 0)))
           (local.set $y-neg? (i32.lt_s (call $integer-sign/i32 (local.get $y))
                                        (i32.const 0)))

           ;; Nonnegative operands can use finite-limb AND directly.
           (if (i32.eqz (i32.or (local.get $x-neg?) (local.get $y-neg?)))
               (then
                (return
                 (call $integer-bitwise-and/nonnegative
                       (local.get $x)
                       (local.get $y)))))

           ;; Convert negative operands to complemented nonnegative magnitudes.
           (if (local.get $x-neg?)
               (then (local.set $xc (call $integer-bitwise-complement
                                          (local.get $x)))))
           (if (local.get $y-neg?)
               (then (local.set $yc (call $integer-bitwise-complement
                                          (local.get $y)))))

           ;; Negative AND negative is the complement of finite OR of complements.
           (if (i32.and (local.get $x-neg?) (local.get $y-neg?))
               (then
                (return
                 (call $integer-bitwise-complement
                       (call $integer-bitwise-ior/nonnegative
                             (local.get $xc)
                             (local.get $yc))))))

           ;; Mixed signs use finite AND-NOT against the complemented negative.
           (if (local.get $x-neg?)
               (then
                (return
                 (call $integer-bitwise-andnot/nonnegative
                       (local.get $y)
                       (local.get $xc)))))
           (call $integer-bitwise-andnot/nonnegative
                 (local.get $x)
                 (local.get $yc)))

     ;; $integer-bitwise-ior/2 : exact-integer? exact-integer? -> exact-integer?
     ;;   Compute infinite two's-complement bitwise inclusive-or.
     (func $integer-bitwise-ior/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-neg? i32)
           (local $y-neg? i32)
           (local $xc     (ref eq))
           (local $yc     (ref eq))

           ;; Track which operands are negative and preallocate complement slots.
           (local.set $xc (ref.i31 (i32.const 0)))
           (local.set $yc (ref.i31 (i32.const 0)))
           (local.set $x-neg? (i32.lt_s (call $integer-sign/i32 (local.get $x))
                                        (i32.const 0)))
           (local.set $y-neg? (i32.lt_s (call $integer-sign/i32 (local.get $y))
                                        (i32.const 0)))

           ;; Nonnegative operands can use finite-limb IOR directly.
           (if (i32.eqz (i32.or (local.get $x-neg?) (local.get $y-neg?)))
               (then
                (return
                 (call $integer-bitwise-ior/nonnegative
                       (local.get $x)
                       (local.get $y)))))

           ;; Convert negative operands to complemented nonnegative magnitudes.
           (if (local.get $x-neg?)
               (then (local.set $xc (call $integer-bitwise-complement
                                          (local.get $x)))))
           (if (local.get $y-neg?)
               (then (local.set $yc (call $integer-bitwise-complement
                                          (local.get $y)))))

           ;; Negative IOR negative is the complement of finite AND of complements.
           (if (i32.and (local.get $x-neg?) (local.get $y-neg?))
               (then
                (return
                 (call $integer-bitwise-complement
                       (call $integer-bitwise-and/nonnegative
                             (local.get $xc)
                             (local.get $yc))))))

           ;; Mixed signs are complements of finite AND-NOT cases.
           (if (local.get $x-neg?)
               (then
                (return
                 (call $integer-bitwise-complement
                       (call $integer-bitwise-andnot/nonnegative
                             (local.get $xc)
                             (local.get $y))))))
           (call $integer-bitwise-complement
                 (call $integer-bitwise-andnot/nonnegative
                       (local.get $yc)
                       (local.get $x))))

     ;; $integer-bitwise-xor/2 : exact-integer? exact-integer? -> exact-integer?
     ;;   Compute infinite two's-complement bitwise exclusive-or.
     (func $integer-bitwise-xor/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $x-neg? i32)
           (local $y-neg? i32)
           (local $xc     (ref eq))
           (local $yc     (ref eq))

           ;; Track which operands are negative and preallocate complement slots.
           (local.set $xc (ref.i31 (i32.const 0)))
           (local.set $yc (ref.i31 (i32.const 0)))
           (local.set $x-neg? (i32.lt_s (call $integer-sign/i32 (local.get $x))
                                        (i32.const 0)))
           (local.set $y-neg? (i32.lt_s (call $integer-sign/i32 (local.get $y))
                                        (i32.const 0)))

           ;; Nonnegative operands can use finite-limb XOR directly.
           (if (i32.eqz (i32.or (local.get $x-neg?) (local.get $y-neg?)))
               (then
                (return
                 (call $integer-bitwise-xor/nonnegative
                       (local.get $x)
                       (local.get $y)))))

           ;; Convert negative operands to complemented nonnegative magnitudes.
           (if (local.get $x-neg?)
               (then (local.set $xc (call $integer-bitwise-complement
                                          (local.get $x)))))
           (if (local.get $y-neg?)
               (then (local.set $yc (call $integer-bitwise-complement
                                          (local.get $y)))))

           ;; Negative XOR negative is finite XOR of complements.
           (if (i32.and (local.get $x-neg?) (local.get $y-neg?))
               (then
                (return
                 (call $integer-bitwise-xor/nonnegative
                       (local.get $xc)
                       (local.get $yc)))))

           ;; Mixed signs are complements of finite XOR with the complemented negative.
           (if (local.get $x-neg?)
               (then
                (return
                 (call $integer-bitwise-complement
                       (call $integer-bitwise-xor/nonnegative
                             (local.get $xc)
                             (local.get $y))))))
           (call $integer-bitwise-complement
                 (call $integer-bitwise-xor/nonnegative
                       (local.get $x)
                       (local.get $yc))))

     ;;;
     ;;; Integer Square Roots
     ;;;

     ;; $integer-nonnegative-bit-length/i32 : exact-nonnegative-integer? -> i32
     ;;   Return the number of bits in x's finite magnitude.
     (func $integer-nonnegative-bit-length/i32
           (param $x (ref eq))
           (result i32)

           (local $bits  i32)
           (local $limbs (ref $I32Array))
           (local $len   i32)
           (local $top   i32)

           ;; Fixnum bit length is computed directly from the decoded payload.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $bits
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (if (i32.eqz (local.get $bits))
                    (then (return (i32.const 0))))
                (return
                 (i32.sub (i32.const 32)
                          (i32.clz (local.get $bits))))))

           ;; Bignum bit length is 32 bits per lower limb plus the top limb width.
           (local.set $limbs
                      (struct.get $Bignum $limbs
                                  (ref.cast (ref $Bignum) (local.get $x))))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $top
                      (array.get $I32Array
                                 (local.get $limbs)
                                 (i32.sub (local.get $len) (i32.const 1))))
           (call $bignum-size-add/i32
                 (call $bignum-size-mul/i32
                       (i32.sub (local.get $len) (i32.const 1))
                       (i32.const 32))
                 (i32.sub (i32.const 32) (i32.clz (local.get $top)))))

     ;; The square root is found by binary search. Keep an interval
     ;; [low, high) such that low^2 <= n < high^2. Start with a power
     ;; of two that is above the square root:
     ;;
     ;;     bits  = bit length of n
     ;;     high  = 2^ceil(bits/2)
     ;;
     ;; Repeatedly test the midpoint:
     ;;
     ;;     mid = floor((low + high)/2)
     ;;
     ;; If mid^2 <= n, move low up to mid. Otherwise move high down to mid.
     ;; When low and high are adjacent, low is floor(sqrt(n)).

     ;; $integer-sqrt/exact : exact-nonnegative-integer? -> exact-nonnegative-integer?
     ;;   Compute the exact floor square root by binary search.
     (func $integer-sqrt/exact
           (param $n (ref eq))
           (result (ref eq))

           (local $bits  i32)
           (local $shift i32)
           (local $low   (ref eq))
           (local $high  (ref eq))
           (local $mid   (ref eq))
           (local $sum   (ref eq))
           (local $sq    (ref eq))
           (local $vals  (ref $Values))

           ;; Initialize the binary-search interval [low, high).
           (local.set $low  (ref.i31 (i32.const 0)))
           (local.set $high (ref.i31 (i32.const 2)))
           (local.set $mid  (ref.i31 (i32.const 0)))
           (local.set $sum  (ref.i31 (i32.const 0)))
           (local.set $sq   (ref.i31 (i32.const 0)))
           (local.set $bits (call $integer-nonnegative-bit-length/i32
                                  (local.get $n)))
           (local.set $shift
                      (i32.shr_u
                       (call $bignum-size-add/i32
                             (local.get $bits)
                             (i32.const 1))
                       (i32.const 1)))
           (local.set $high
                      (call $u64-shl->integer
                            (i64.const 1)
                            (local.get $shift)))

           ;; Narrow the interval until low is the greatest value with low^2 <= n.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_s (call $integer-compare/i32
                                               (call $integer-add/2
                                                     (local.get $low)
                                                     (ref.i31 (i32.const 2)))
                                               (local.get $high))
                                         (i32.const 0)))
                        (local.set $sum  (call $integer-add/2
                                               (local.get $low)
                                               (local.get $high)))
                        (local.set $vals (call $integer-divmod
                                               (local.get $sum)
                                               (ref.i31 (i32.const 4))))
                        (local.set $mid  (array.get $Values
                                                    (local.get $vals)
                                                    (i32.const 0)))
                        (local.set $sq   (call $integer-mul/2
                                               (local.get $mid)
                                               (local.get $mid)))
                        (if (i32.le_s
                             (call $integer-compare/i32
                                   (local.get $sq)
                                   (local.get $n))
                             (i32.const 0))
                            (then (local.set $low (local.get $mid)))
                            (else (local.set $high (local.get $mid))))
                        (br $loop)))
           (local.get $low))

     ;; $integer-sqrt/remainder/exact : exact-nonnegative-integer? -> values
     ;;   Return integer square root and exact remainder.
     (func $integer-sqrt/remainder/exact
           (param $n (ref eq))
           (result (ref $Values))

           (local $s  (ref eq))
           (local $sq (ref eq))

           ;; Compute s = floor(sqrt(n)), then return n - s^2 as the remainder.
           (local.set $s  (call $integer-sqrt/exact (local.get $n)))
           (local.set $sq (call $integer-mul/2
                                (local.get $s)
                                (local.get $s)))
           (array.new_fixed $Values 2
                            (local.get $s)
                            (call $integer-sub/2
                                  (local.get $n)
                                  (local.get $sq))))

     ;;;
     ;;; Division
     ;;;

     ;; Division is implemented in two layers.

     ;; The top layer is $integer-divmod.
     ;; It handles signs, zero, and, small quotients.
     ;; The quotient is truncated toward zero,
     ;; and the remainder has the dividend's sign.
     ;;
     ;; The low-level helpers divide positive magnitudes only.
     ;; They treat a bignum as little-endian limbs in base B = 2^32,
     ;; compute nonnegative quotient and remainder magnitudes,
     ;; and normalize both results so they become fixnums whenever possible.
     ;;
     ;; There are two magnitude algorithms:
     ;;   - a short division path when the divisor fits in one 32-bit limb
     ;;   - normalized long division when both operands are multi-limb bignums


     ;; Single-limb division, n div d, is ordinary long division in base B = 2^32.
     ;; Walk from the high limb down to the low limb, carrying a remainder:
     ;;
     ;;     cur = rem*B + limb[i]
     ;;     q[i] = floor(cur/d)
     ;;     rem  = cur mod d
     ;;
     ;; Because rem < d and d fits in one limb, cur fits in 64 bits and each
     ;; quotient digit q[i] fits in one 32-bit limb.

     ;; $bignum-divmod-u32 : bignum? i32 -> values exact-integer? exact-integer?
     ;;   Divide a positive bignum magnitude by a nonzero unsigned 32-bit limb.
     (func $bignum-divmod-u32
           (param $n (ref $Bignum))
           (param $d i32)
           (result   (ref $Values))

           (local $limbs   (ref $I32Array))
           (local $q-limbs (ref $I32Array))
           (local $i       i32)
           (local $cur     i64)
           (local $rem     i64)
           (local $d64     i64)

           ;; Divide from high limb to low, carrying the remainder as the next high word.
           (local.set $limbs   (struct.get $Bignum $limbs (local.get $n)))
           (local.set $i       (array.len (local.get $limbs)))
           (local.set $q-limbs (array.new_default $I32Array (local.get $i)))
           (local.set $d64     (i64.extend_i32_u (local.get $d)))
           (block $done
                  (loop $loop
                        (br_if $done (i32.eqz (local.get $i)))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (local.set $cur
                                   (i64.add
                                    (i64.shl (local.get $rem) (i64.const 32))
                                    (i64.extend_i32_u
                                     (array.get $I32Array
                                                (local.get $limbs)
                                                (local.get $i)))))
                        (array.set $I32Array
                                   (local.get $q-limbs)
                                   (local.get $i)
                                   (i32.wrap_i64
                                    (i64.div_u (local.get $cur)
                                               (local.get $d64))))
                        (local.set $rem
                                   (i64.rem_u (local.get $cur)
                                              (local.get $d64)))
                        (br $loop)))

           ;; Return normalized quotient and the final one-limb remainder.
           (array.new_fixed $Values 2
                            (call $bignum-normalize
                                  (i32.const 1)
                                  (local.get $q-limbs))
                            (call $integer-from-i64 (local.get $rem))))

     ;; Multi-limb division uses normalized long division in base B = 2^32.
     ;; First shift both magnitudes left so the top divisor limb is at least
     ;; B/2. This makes quotient-digit estimates accurate enough to need only
     ;; a small correction.
     ;;
     ;; For each quotient position j, estimate the next digit from the top two
     ;; limbs of the current dividend window and the top divisor limb:
     ;;
     ;;     qhat = floor((u[j+n]*B + u[j+n-1]) / v[n-1])
     ;;
     ;; Then refine qhat with the next lower divisor limb, subtract qhat*v
     ;; from the dividend window, and if the subtraction borrowed, decrement
     ;; qhat and add v back. After all digits are processed, the remaining
     ;; dividend window is shifted right again to recover the true remainder.
     ;; $bignum-divmod-magnitudes : bignum? bignum? -> values
     ;;   Divide positive canonical magnitudes using normalized long division.
     (func $bignum-divmod-magnitudes
           (param $n (ref $Bignum))
           (param $d (ref $Bignum))
           (result (ref $Values))

           (local $n-limbs (ref $I32Array))
           (local $d-limbs (ref $I32Array))
           (local $u (ref $I32Array))
           (local $v (ref $I32Array))
           (local $q-limbs (ref $I32Array))
           (local $r-limbs (ref $I32Array))
           (local $n-len i32)
           (local $d-len i32)
           (local $q-len i32)
           (local $shift i32)
           (local $i i32)
           (local $j i32)
           (local $limb i32)
           (local $carry i64)
           (local $acc i64)
           (local $qhat i64)
           (local $rhat i64)
           (local $numer i64)
           (local $v-high i64)
           (local $prod i64)
           (local $rhs i64)
           (local $sub i64)
           (local $borrow i64)

           ;; Set up operand lengths and the maximum quotient length.
           (local.set $n-limbs (struct.get $Bignum $limbs (local.get $n)))
           (local.set $d-limbs (struct.get $Bignum $limbs (local.get $d)))
           (local.set $n-len   (array.len (local.get $n-limbs)))
           (local.set $d-len   (array.len (local.get $d-limbs)))
           (local.set $q-len
                      (call $bignum-size-add/i32
                            (i32.sub (local.get $n-len) (local.get $d-len))
                            (i32.const 1)))

           ;; Normalize so the divisor's high limb has its top bit set.
           (local.set $shift   (i32.clz
                                (array.get $I32Array
                                           (local.get $d-limbs)
                                           (i32.sub (local.get $d-len)
                                                    (i32.const 1)))))
           (local.set $u       (array.new_default
                                $I32Array
                                (call $bignum-size-add/i32
                                      (local.get $n-len)
                                      (i32.const 1))))
           (local.set $v       (array.new_default $I32Array (local.get $d-len)))
           (local.set $q-limbs (array.new_default $I32Array (local.get $q-len)))

           ;; Shift the divisor magnitude left by shift bits.
           (local.set $carry (i64.const 0))
           (block $normalize-done-v
                  (loop $normalize-loop-v
                        (br_if $normalize-done-v
                               (i32.ge_u (local.get $i) (local.get $d-len)))
                        (local.set $acc
                                   (i64.or
                                    (i64.shl
                                     (i64.extend_i32_u
                                      (array.get $I32Array
                                                 (local.get $d-limbs)
                                                 (local.get $i)))
                                     (i64.extend_i32_u (local.get $shift)))
                                    (local.get $carry)))
                        (array.set $I32Array
                                   (local.get $v)
                                   (local.get $i)
                                   (i32.wrap_i64 (local.get $acc)))
                        (local.set $carry
                                   (i64.shr_u (local.get $acc)
                                              (i64.const 32)))
                        (local.set $i
                                   (i32.add (local.get $i) (i32.const 1)))
                        (br $normalize-loop-v)))

           ;; Shift the dividend magnitude left by shift bits, with one guard limb.
           (local.set $i (i32.const 0))
           (local.set $carry (i64.const 0))
           (block $normalize-done-u
                  (loop $normalize-loop-u
                        (br_if $normalize-done-u
                               (i32.ge_u (local.get $i) (local.get $n-len)))
                        (local.set $acc
                                   (i64.or
                                    (i64.shl
                                     (i64.extend_i32_u
                                      (array.get $I32Array
                                                 (local.get $n-limbs)
                                                 (local.get $i)))
                                     (i64.extend_i32_u (local.get $shift)))
                                    (local.get $carry)))
                        (array.set $I32Array
                                   (local.get $u)
                                   (local.get $i)
                                   (i32.wrap_i64 (local.get $acc)))
                        (local.set $carry
                                   (i64.shr_u (local.get $acc)
                                              (i64.const 32)))
                        (local.set $i
                                   (i32.add (local.get $i) (i32.const 1)))
                        (br $normalize-loop-u)))
           (array.set $I32Array
                      (local.get $u)
                      (local.get $n-len)
                      (i32.wrap_i64 (local.get $carry)))

           ;; Process quotient digits from high to low.
           (local.set $v-high
                      (i64.extend_i32_u
                       (array.get $I32Array
                                  (local.get $v)
                                  (i32.sub (local.get $d-len) (i32.const 1)))))
           (local.set $j (local.get $q-len))
           (block $divide-done
                  (loop $divide-loop
                        (br_if $divide-done (i32.eqz (local.get $j)))
                        (local.set $j
                                   (i32.sub (local.get $j) (i32.const 1)))

                        ;; Estimate qhat from the top two dividend limbs.
                        (local.set $numer
                                   (i64.or
                                    (i64.shl
                                     (i64.extend_i32_u
                                      (array.get $I32Array
                                                 (local.get $u)
                                                 (i32.add (local.get $j)
                                                          (local.get $d-len))))
                                     (i64.const 32))
                                    (i64.extend_i32_u
                                     (array.get $I32Array
                                                (local.get $u)
                                                (i32.add
                                                 (local.get $j)
                                                 (i32.sub (local.get $d-len)
                                                          (i32.const 1)))))))
                        (if (i64.eq
                             (i64.extend_i32_u
                              (array.get $I32Array
                                         (local.get $u)
                                         (i32.add (local.get $j)
                                                  (local.get $d-len))))
                            (local.get $v-high))
                            (then
                             (local.set $qhat (i64.const 4294967295)))
                            (else
                             (local.set $qhat
                                        (i64.div_u (local.get $numer)
                                                   (local.get $v-high)))))
                        (local.set $rhat
                                   (i64.sub
                                    (local.get $numer)
                                    (i64.mul (local.get $qhat)
                                             (local.get $v-high))))

                        ;; Refine qhat using the next divisor and dividend limbs.
                        (if (i32.gt_u (local.get $d-len) (i32.const 1))
                            (then
                             (block $qhat-ready
                                    (loop $qhat-loop
                                          (br_if $qhat-ready
                                                 (i64.ge_u
                                                  (local.get $rhat)
                                                  (i64.const 4294967296)))
                                          (local.set $prod
                                                     (i64.mul
                                                      (local.get $qhat)
                                                      (i64.extend_i32_u
                                                       (array.get
                                                        $I32Array
                                                        (local.get $v)
                                                        (i32.sub
                                                         (local.get $d-len)
                                                         (i32.const 2))))))
                                          (local.set $rhs
                                                     (i64.or
                                                      (i64.shl
                                                       (local.get $rhat)
                                                       (i64.const 32))
                                                      (i64.extend_i32_u
                                                       (array.get
                                                        $I32Array
                                                        (local.get $u)
                                                        (i32.add
                                                         (local.get $j)
                                                         (i32.sub
                                                          (local.get $d-len)
                                                          (i32.const 2)))))))
                                          (br_if $qhat-ready
                                                 (i64.le_u
                                                  (local.get $prod)
                                                  (local.get $rhs)))
                                          (local.set $qhat
                                                     (i64.sub
                                                      (local.get $qhat)
                                                      (i64.const 1)))
                                          (local.set $rhat
                                                     (i64.add
                                                      (local.get $rhat)
                                                      (local.get $v-high)))
                                          (br_if $qhat-ready
                                                 (i64.ge_u
                                                  (local.get $rhat)
                                                  (i64.const 4294967296)))
                                          (br $qhat-loop)))))

                        ;; Subtract qhat*v from the current dividend window.
                        (local.set $i (i32.const 0))
                        (local.set $carry (i64.const 0))
                        (local.set $borrow (i64.const 0))
                        (block $subtract-done
                               (loop $subtract-loop
                                     (br_if $subtract-done
                                            (i32.ge_u (local.get $i)
                                                      (local.get $d-len)))
                                     (local.set $prod
                                                (i64.add
                                                 (i64.mul
                                                  (local.get $qhat)
                                                  (i64.extend_i32_u
                                                   (array.get $I32Array
                                                              (local.get $v)
                                                              (local.get $i))))
                                                 (local.get $carry)))
                                     (local.set $sub
                                                (i64.sub
                                                 (i64.sub
                                                  (i64.extend_i32_u
                                                   (array.get
                                                    $I32Array
                                                    (local.get $u)
                                                    (i32.add (local.get $j)
                                                             (local.get $i))))
                                                  (i64.and
                                                   (local.get $prod)
                                                   (i64.const 4294967295)))
                                                 (local.get $borrow)))
                                     (if (i64.lt_s (local.get $sub)
                                                   (i64.const 0))
                                         (then
                                          (array.set
                                           $I32Array
                                           (local.get $u)
                                           (i32.add (local.get $j)
                                                    (local.get $i))
                                           (i32.wrap_i64
                                            (i64.add
                                             (local.get $sub)
                                             (i64.const 4294967296))))
                                          (local.set $borrow (i64.const 1)))
                                         (else
                                          (array.set
                                           $I32Array
                                           (local.get $u)
                                           (i32.add (local.get $j)
                                                    (local.get $i))
                                           (i32.wrap_i64 (local.get $sub)))
                                          (local.set $borrow (i64.const 0))))
                                     (local.set $carry
                                                (i64.shr_u
                                                 (local.get $prod)
                                                 (i64.const 32)))
                                     (local.set $i
                                                (i32.add (local.get $i)
                                                         (i32.const 1)))
                                     (br $subtract-loop)))
                        (local.set $sub
                                   (i64.sub
                                    (i64.sub
                                     (i64.extend_i32_u
                                      (array.get
                                       $I32Array
                                       (local.get $u)
                                       (i32.add (local.get $j)
                                                (local.get $d-len))))
                                     (local.get $carry))
                                    (local.get $borrow)))
                        (array.set $I32Array
                                   (local.get $u)
                                   (i32.add (local.get $j)
                                            (local.get $d-len))
                                   (i32.wrap_i64 (local.get $sub)))

                        ;; If qhat was one too high, decrement it and add v back.
                        (if (i64.lt_s (local.get $sub) (i64.const 0))
                            (then
                             (local.set $qhat
                                        (i64.sub (local.get $qhat)
                                                 (i64.const 1)))
                             (local.set $i (i32.const 0))
                             (local.set $carry (i64.const 0))
                             (block $addback-done
                                    (loop $addback-loop
                                          (br_if $addback-done
                                                 (i32.ge_u (local.get $i)
                                                           (local.get $d-len)))
                                          (local.set $acc
                                                     (i64.add
                                (i64.add
                                 (i64.extend_i32_u
                                  (array.get
                                   $I32Array
                                                         (local.get $u)
                                                         (i32.add
                                                          (local.get $j)
                                                          (local.get $i))))
                                                       (i64.extend_i32_u
                                                        (array.get
                                                         $I32Array
                                                         (local.get $v)
                                                         (local.get $i))))
                                                      (local.get $carry)))
                                          (array.set
                                           $I32Array
                                           (local.get $u)
                                           (i32.add (local.get $j)
                                                    (local.get $i))
                                           (i32.wrap_i64 (local.get $acc)))
                                          (local.set $carry
                                                     (i64.shr_u
                                                      (local.get $acc)
                                                      (i64.const 32)))
                                          (local.set $i
                                                     (i32.add
                                                      (local.get $i)
                                                      (i32.const 1)))
                                          (br $addback-loop)))
                             (array.set
                              $I32Array
                              (local.get $u)
                              (i32.add (local.get $j) (local.get $d-len))
                              (i32.wrap_i64
                               (i64.add
                                (i64.extend_i32_u
                                 (array.get
                                  $I32Array
                                  (local.get $u)
                                  (i32.add (local.get $j)
                                           (local.get $d-len))))
                                 (local.get $carry))))))

                        ;; Store the corrected quotient limb.
                        (array.set $I32Array
                                   (local.get $q-limbs)
                                   (local.get $j)
                                   (i32.wrap_i64 (local.get $qhat)))
                        (br $divide-loop)))

           ;; Unnormalize the remaining dividend window to get the remainder.
           (local.set $r-limbs
                      (array.new_default $I32Array (local.get $d-len)))
           (if (i32.eqz (local.get $shift))
               (then
                (array.copy $I32Array $I32Array
                            (local.get $r-limbs) (i32.const 0)
                            (local.get $u) (i32.const 0)
                            (local.get $d-len)))
               (else
                (local.set $i (local.get $d-len))
                (local.set $carry (i64.const 0))
                (block $unnormalize-done
                       (loop $unnormalize-loop
                             (br_if $unnormalize-done
                                    (i32.eqz (local.get $i)))
                             (local.set $i
                                        (i32.sub (local.get $i)
                                                 (i32.const 1)))
                             (local.set $limb
                                        (array.get $I32Array
                                                   (local.get $u)
                                                   (local.get $i)))
                             (local.set $acc
                                        (i64.or
                                         (i64.shr_u
                                          (i64.extend_i32_u
                                           (local.get $limb))
                                          (i64.extend_i32_u
                                           (local.get $shift)))
                                         (i64.shl
                                          (local.get $carry)
                                          (i64.extend_i32_u
                                           (i32.sub (i32.const 32)
                                                    (local.get $shift))))))
                             (array.set $I32Array
                                        (local.get $r-limbs)
                                        (local.get $i)
                                        (i32.wrap_i64 (local.get $acc)))
                             (local.set $carry
                                        (i64.and
                                         (i64.extend_i32_u
                                          (local.get $limb))
                                         (i64.sub
                                          (i64.shl
                                           (i64.const 1)
                                           (i64.extend_i32_u
                                            (local.get $shift)))
                                          (i64.const 1))))
                             (br $unnormalize-loop)))))
           (array.new_fixed $Values 2
                            (call $bignum-normalize
                                  (i32.const 1)
                                  (local.get $q-limbs))
                            (call $bignum-normalize
                                  (i32.const 1)
                                  (local.get $r-limbs))))

     ;; $integer-divmod/single-limb : exact-integer? exact-integer? -> values
     ;;   Divide exact integers when the divisor magnitude fits one 32-bit limb.
     (func $integer-divmod/single-limb
           (param $n (ref eq))
           (param $m (ref eq))
           (result (ref $Values))

           (local $n-sign i32)
           (local $m-sign i32)
           (local $q-sign i32)
           (local $d i32)
           (local $nv i64)
           (local $q (ref eq))
           (local $r (ref eq))
           (local $vals (ref $Values))

           ;; Zero divided by anything yields zero quotient and zero remainder.
           (if (call $integer-zero?/i32 (local.get $n))
               (then
                (return
                 (array.new_fixed $Values 2
                                  (ref.i31 (i32.const 0))
                                  (ref.i31 (i32.const 0))))))

           ;; Compute quotient and remainder signs for truncating division.
           (local.set $n-sign (call $integer-sign/i32 (local.get $n)))
           (local.set $m-sign (call $integer-sign/i32 (local.get $m)))
           (local.set $q-sign
                      (select (i32.const 1)
                              (i32.const -1)
                              (i32.eq (local.get $n-sign)
                                      (local.get $m-sign))))
           (local.set $d (call $integer-abs-u32 (local.get $m)))

           ;; Fixnum dividends can divide in unsigned 64-bit arithmetic.
           (if (ref.test (ref i31) (local.get $n))
               (then
                (local.set $nv
                           (i64.extend_i32_u
                            (call $integer-abs-u32 (local.get $n))))
                (local.set $q
                           (call $integer-from-i64
                                 (i64.div_u
                                  (local.get $nv)
                                  (i64.extend_i32_u (local.get $d)))))
                (local.set $r
                           (call $integer-from-i64
                                 (i64.rem_u
                                  (local.get $nv)
                                  (i64.extend_i32_u (local.get $d)))))
                (return
                 (array.new_fixed $Values 2
                                  (call $integer-apply-sign
                                        (local.get $q)
                                        (local.get $q-sign))
                                  (call $integer-apply-sign
                                        (local.get $r)
                                        (local.get $n-sign))))))

           ;; Bignum dividends divide by the single-limb magnitude helper.
           (local.set $vals
                      (call $bignum-divmod-u32
                            (ref.cast (ref $Bignum) (local.get $n))
                            (local.get $d)))
           (local.set $q (array.get $Values (local.get $vals) (i32.const 0)))
           (local.set $r (array.get $Values (local.get $vals) (i32.const 1)))
           (array.new_fixed $Values 2
                            (call $integer-apply-sign
                                  (local.get $q)
                                  (local.get $q-sign))
                            (call $integer-apply-sign
                                  (local.get $r)
                                  (local.get $n-sign))))

     ;; $integer-divmod : exact-integer? exact-integer? -> values
     ;;   Divide exact integers with truncating quotient and dividend-sign remainder.
     (func $integer-divmod
           (param $n (ref eq))
           (param $m (ref eq))
           (result (ref $Values))

           (local $n-sign i32)
           (local $m-sign i32)
           (local $q-sign i32)
           (local $cmp i32)
           (local $q (ref eq))
           (local $r (ref eq))
           (local $vals (ref $Values))

           ;; Zero divided by anything yields zero quotient and zero remainder.
           (if (call $integer-zero?/i32 (local.get $n))
               (then
                (return
                 (array.new_fixed $Values 2
                                  (ref.i31 (i32.const 0))
                                  (ref.i31 (i32.const 0))))))

           ;; Compute result signs and compare absolute magnitudes.
           (local.set $n-sign (call $integer-sign/i32 (local.get $n)))
           (local.set $m-sign (call $integer-sign/i32 (local.get $m)))
           (local.set $q-sign
                      (select (i32.const 1)
                              (i32.const -1)
                              (i32.eq (local.get $n-sign)
                                      (local.get $m-sign))))
           (local.set $cmp
                      (call $integer-compare/i32
                            (call $integer-abs (local.get $n))
                            (call $integer-abs (local.get $m))))

           ;; A smaller dividend magnitude gives zero quotient and dividend remainder.
           (if (i32.lt_s (local.get $cmp) (i32.const 0))
               (then
                (return
                 (array.new_fixed $Values 2
                                  (ref.i31 (i32.const 0))
                                  (local.get $n)))))

           ;; Single-limb divisors use the small-divisor helper.
           (if (call $integer-single-limb?/i32 (local.get $m))
               (then
                (return
                 (call $integer-divmod/single-limb
                       (local.get $n)
                       (local.get $m)))))

           ;; Otherwise divide positive bignum magnitudes and reapply signs.
           (local.set $vals
                      (call $bignum-divmod-magnitudes
                            (ref.cast (ref $Bignum)
                                      (call $integer-abs (local.get $n)))
                            (ref.cast (ref $Bignum)
                                      (call $integer-abs (local.get $m)))))
           (local.set $q (array.get $Values (local.get $vals) (i32.const 0)))
           (local.set $r (array.get $Values (local.get $vals) (i32.const 1)))
           (array.new_fixed $Values 2
                            (call $integer-apply-sign
                                  (local.get $q)
                                  (local.get $q-sign))
                            (call $integer-apply-sign
                                  (local.get $r)
                                  (local.get $n-sign))))

     ;;;
     ;;; Integer Comparison
     ;;;

     ;; $integer-compare/i32 : exact-integer? exact-integer? -> integer?
     ;;   Compare exact integers, returning -1, 0, or 1.
     (func $integer-compare/i32
           (param $x (ref eq))
           (param $y (ref eq))
           (result i32)

           (local $xv i32)
           (local $yv i32)
           (local $yb (ref $Bignum))

           ;; Fixnum-vs-fixnum comparison uses decoded signed payloads.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $xv
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (if (ref.test (ref i31) (local.get $y))
                    (then
                     (local.set $yv
                                (i32.shr_s
                                 (i31.get_s
                                  (ref.cast (ref i31) (local.get $y)))
                                 (i32.const 1)))
                     (return
                      (if (result i32)
                          (i32.lt_s (local.get $xv) (local.get $yv))
                          (then (i32.const -1))
                          (else
                           (if (result i32)
                               (i32.gt_s (local.get $xv) (local.get $yv))
                               (then (i32.const 1))
                               (else (i32.const 0))))))))

                ;; Fixnum zero compares against bignum sign without boxing.
                (local.set $yb (ref.cast (ref $Bignum) (local.get $y)))
                (if (i32.eqz (local.get $xv))
                    (then
                     (return
                      (if (result i32)
                          (i32.gt_s (struct.get $Bignum $sign (local.get $yb))
                                    (i32.const 0))
                          (then (i32.const -1))
                          (else (i32.const 1))))))

                ;; Nonzero fixnums promote to one-limb bignums for mixed comparison.
                (return
                 (call $bignum-compare/i32
                       (call $nonzero-fixnum->bignum (local.get $x))
                       (local.get $yb)))))

           ;; Bignum-vs-fixnum mirrors the mixed comparison above.
           (if (ref.test (ref i31) (local.get $y))
               (then
                (local.set $yv
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $y)))
                            (i32.const 1)))
                (if (i32.eqz (local.get $yv))
                    (then
                     (return
                      (if (result i32)
                          (i32.gt_s
                           (struct.get $Bignum $sign
                                       (ref.cast (ref $Bignum) (local.get $x)))
                           (i32.const 0))
                          (then (i32.const 1))
                          (else (i32.const -1))))))
                (return
                 (call $bignum-compare/i32
                       (ref.cast (ref $Bignum) (local.get $x))
                       (call $nonzero-fixnum->bignum (local.get $y))))))

           ;; Bignum-vs-bignum delegates to signed bignum comparison.
           (call $bignum-compare/i32
                 (ref.cast (ref $Bignum) (local.get $x))
                 (ref.cast (ref $Bignum) (local.get $y))))

     ;; $u64-shl->integer : i64 i32 -> exact-integer?
     ;;   Build a canonical positive exact integer from an unsigned 64-bit
     ;;   mantissa shifted left by a nonnegative bit count.
     (func $u64-shl->integer
           (param $m i64)
           (param $shift i32)
           (result (ref eq))

           (local $low        i32)
           (local $high       i32)
           (local $word-shift i32)
           (local $bit-shift  i32)
           (local $out        (ref $I32Array))
           (local $pos        i32)
           (local $acc        i64)
           (local $carry      i64)

           ;; A zero mantissa shifted by any amount is canonical zero.
           (if (i64.eqz (local.get $m))
               (then (return (ref.i31 (i32.const 0)))))

           ;; Split the mantissa and shift count into limbs and bit offset.
           (local.set $low  (i32.wrap_i64 (local.get $m)))
           (local.set $high (i32.wrap_i64
                             (i64.shr_u (local.get $m) (i64.const 32))))
           (local.set $word-shift
                      (i32.div_u (local.get $shift) (i32.const 32)))
           (local.set $bit-shift
                      (i32.rem_u (local.get $shift) (i32.const 32)))
           (local.set $out
                      (array.new_default
                       $I32Array
                       (call $bignum-size-add/i32
                             (local.get $word-shift)
                             (i32.const 3))))

           ;; Place the shifted low limb at the word-shifted position.
           (local.set $pos (local.get $word-shift))
           (local.set $acc
                      (i64.shl
                       (i64.extend_i32_u (local.get $low))
                       (i64.extend_i32_u (local.get $bit-shift))))
           (array.set $I32Array
                      (local.get $out)
                      (local.get $pos)
                      (i32.wrap_i64 (local.get $acc)))
           (local.set $carry
                      (i64.shr_u (local.get $acc) (i64.const 32)))

           ;; Add the shifted high limb if present, then normalize.
           (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
           (if (i32.eqz (local.get $high))
               (then
                (array.set $I32Array
                           (local.get $out)
                           (local.get $pos)
                           (i32.wrap_i64 (local.get $carry))))
               (else
                (local.set $acc
                           (i64.add
                            (i64.shl
                             (i64.extend_i32_u (local.get $high))
                             (i64.extend_i32_u (local.get $bit-shift)))
                            (local.get $carry)))
                (array.set $I32Array
                           (local.get $out)
                           (local.get $pos)
                           (i32.wrap_i64 (local.get $acc)))
                (array.set $I32Array
                           (local.get $out)
                           (i32.add (local.get $pos) (i32.const 1))
                           (i32.wrap_i64
                            (i64.shr_u (local.get $acc) (i64.const 32))))))
           (call $bignum-normalize (i32.const 1) (local.get $out)))

     ;; $integer-flonum-abs-compare/i32 : exact-integer? f64 -> integer?
     ;;   Compare |x| against the exact positive finite f64 value, returning
     ;;   -1, 0, or 1.
     (func $integer-flonum-abs-compare/i32
           (param $x (ref eq))
           (param $y f64)
           (result i32)

           (local $bits      i64)
           (local $exp       i32)
           (local $shift     i32)
           (local $d         i32)
           (local $mantissa  i64)
           (local $floor     (ref eq))
           (local $cmp       i32)
           (local $frac-mask i64)

           ;; Any positive flonum below 1 is smaller than any nonzero integer magnitude.
           (if (f64.lt (local.get $y) (f64.const 1.0))
               (then (return (i32.const 1))))

           ;; Decode the f64 exponent and significand bits.
           (local.set $bits (i64.reinterpret_f64 (local.get $y)))
           (local.set $exp
                      (i32.wrap_i64
                       (i64.and
                        (i64.shr_u (local.get $bits) (i64.const 52))
                        (i64.const 2047))))
           (if (i32.eqz (local.get $exp))
               (then (return (i32.const 1))))
           (local.set $mantissa
                      (i64.or
                       (i64.and (local.get $bits)
                                (i64.const 4503599627370495))
                       (i64.const 4503599627370496)))
           (local.set $shift
                      (i32.sub (local.get $exp) (i32.const 1075)))

           ;; Nonnegative shifts make the flonum value an exact shifted integer.
           (if (i32.ge_s (local.get $shift) (i32.const 0))
               (then
                (return
                 (call $integer-compare/i32
                       (call $integer-abs (local.get $x))
                       (call $u64-shl->integer
                             (local.get $mantissa)
                             (local.get $shift))))))

           ;; Negative shifts compare against the integer floor of the flonum value.
           (local.set $d (i32.sub (i32.const 0) (local.get $shift)))
           (local.set $floor
                      (call $integer-from-i64
                            (i64.shr_u
                             (local.get $mantissa)
                             (i64.extend_i32_u (local.get $d)))))
           (local.set $cmp
                      (call $integer-compare/i32
                            (call $integer-abs (local.get $x))
                            (local.get $floor)))
           (if (i32.ne (local.get $cmp) (i32.const 0))
               (then (return (local.get $cmp))))

           ;; Equal floors need a fractional-bit check to distinguish equality.
           (local.set $frac-mask
                      (i64.sub
                       (i64.shl (i64.const 1)
                                (i64.extend_i32_u (local.get $d)))
                       (i64.const 1)))
           (if (result i32)
               (i64.eqz
                (i64.and (local.get $mantissa) (local.get $frac-mask)))
               (then (i32.const 0))
               (else (i32.const -1))))

     ;; $integer-flonum-compare/i32 : exact-integer? flonum? -> integer?
     ;;   Compare an exact integer against a flonum's exact binary value.
     ;;   Returns 2 for unordered NaN comparisons.
     (func $integer-flonum-compare/i32
           (param $x (ref eq))
           (param $y/fl (ref $Flonum))
           (result i32)

           (local $y f64)
           (local $xv i32)
           (local $x-sign i32)
           (local $y-sign i32)
           (local $cmp i32)

           ;; Handle unordered NaN and infinities before exact comparison.
           (local.set $y (struct.get $Flonum $v (local.get $y/fl)))
           (if (f64.ne (local.get $y) (local.get $y))
               (then (return (i32.const 2))))
           (if (f64.eq (local.get $y) (f64.const +inf))
               (then (return (i32.const -1))))
           (if (f64.eq (local.get $y) (f64.const -inf))
               (then (return (i32.const 1))))
           (if (f64.eq (local.get $y) (f64.const 0.0))
               (then
                (return
                 (call $integer-compare/i32
                       (local.get $x)
                       (ref.i31 (i32.const 0))))))

           ;; Determine the exact integer sign from its representation.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $xv
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (if (i32.eqz (local.get $xv))
                    (then (local.set $x-sign (i32.const 0)))
                    (else
                     (local.set $x-sign
                                (select (i32.const 1)
                                        (i32.const -1)
                                        (i32.gt_s (local.get $xv) (i32.const 0)))))))
               (else
                (local.set $x-sign
                           (struct.get $Bignum $sign
                                       (ref.cast (ref $Bignum)
                                                 (local.get $x))))))

           ;; Opposite signs determine the result without magnitude comparison.
           (local.set $y-sign
                      (select (i32.const 1)
                              (i32.const -1)
                              (f64.gt (local.get $y) (f64.const 0.0))))
           (if (i32.eqz (local.get $x-sign))
               (then
                (return
                 (select (i32.const -1)
                         (i32.const 1)
                         (i32.gt_s (local.get $y-sign) (i32.const 0))))))
           (if (i32.ne (local.get $x-sign) (local.get $y-sign))
               (then
                (return
                 (select (i32.const 1)
                         (i32.const -1)
                         (i32.gt_s (local.get $x-sign)
                                   (local.get $y-sign))))))

           ;; Equal signs compare absolute magnitudes and reverse for negatives.
           (local.set $cmp
                      (call $integer-flonum-abs-compare/i32
                            (local.get $x)
                            (f64.abs (local.get $y))))
           (if (result i32)
               (i32.gt_s (local.get $x-sign) (i32.const 0))
               (then (local.get $cmp))
               (else (i32.sub (i32.const 0) (local.get $cmp)))))

     ;;;
     ;;; Negation and Absolute Value
     ;;;

     ;; $integer-negate : exact-integer? -> exact-integer?
     ;;   Return the additive inverse, promoting the most-negative fixnum.
     (func $integer-negate
           (param $x (ref eq))
           (result (ref eq))

           ;; Negate fixnums through i64 so the most-negative fixnum can promote.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (return
                 (call $integer-from-i64
                       (i64.sub
                        (i64.const 0)
                        (i64.extend_i32_s
                         (i32.shr_s
                          (i31.get_s (ref.cast (ref i31) (local.get $x)))
                          (i32.const 1))))))))

           ;; Bignums negate by flipping their stored sign and normalizing.
           (call $bignum-negate (ref.cast (ref $Bignum) (local.get $x))))

     ;; $integer-abs : exact-integer? -> exact-integer?
     ;;   Return the exact absolute value, preserving bignums.
     (func $integer-abs
           (param $x (ref eq))
           (result (ref eq))

           (local $v i32)

           ;; Fixnum absolute value either returns x or its canonical negation.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $v
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (if (i32.lt_s (local.get $v) (i32.const 0))
                    (then (return (call $integer-negate (local.get $x))))
                    (else (return (local.get $x))))))

           ;; Negative bignums negate; nonnegative bignums are already absolute.
           (if (i32.lt_s
                (struct.get $Bignum $sign
                            (ref.cast (ref $Bignum) (local.get $x)))
                (i32.const 0))
               (then
                (return
                 (call $bignum-negate
                       (ref.cast (ref $Bignum) (local.get $x))))))
           (local.get $x))

     ;;;
     ;;; Inexact Conversion
     ;;;

     ;; $bignum-bit/i32 : bignum? i32 -> i32
     ;;   Return bit i of the bignum magnitude, or 0 outside the magnitude.
     (func $bignum-bit/i32
           (param $b   (ref $Bignum))
           (param $bit i32)
           (result i32)

           (local $limbs      (ref $I32Array))
           (local $limb-index i32)
           (local $bit-index  i32)

           ;; Negative bit indexes are outside the finite magnitude.
           (if (i32.lt_s (local.get $bit) (i32.const 0))
               (then (return (i32.const 0))))

           ;; Locate the base-2^32 limb and the bit inside that limb.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $limb-index
                      (i32.div_u (local.get $bit) (i32.const 32)))
           (local.set $bit-index
                      (i32.rem_u (local.get $bit) (i32.const 32)))

           ;; Missing high limbs are implicit zeros.
           (if (i32.ge_u (local.get $limb-index)
                         (array.len (local.get $limbs)))
               (then (return (i32.const 0))))

           ;; Extract the requested bit from the stored limb.
           (i32.and
            (i32.shr_u
             (array.get $I32Array
                        (local.get $limbs)
                        (local.get $limb-index))
             (local.get $bit-index))
            (i32.const 1)))

     ;; $bignum-any-bits-below?/i32 : bignum? i32 -> i32
     ;;   Return 1 if any magnitude bit below limit is set.
     (func $bignum-any-bits-below?/i32
           (param $b     (ref $Bignum))
           (param $limit i32)
           (result i32)

           (local $i i32)

           ;; An empty low-bit range has no sticky bit.
           (if (i32.le_s (local.get $limit) (i32.const 0))
               (then (return (i32.const 0))))

           ;; Scan bits 0 through limit-1.
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_s (local.get $i)
                                         (local.get $limit)))
                        (if (call $bignum-bit/i32
                                  (local.get $b)
                                  (local.get $i))
                            (then (return (i32.const 1))))
                        (local.set $i
                                   (i32.add (local.get $i)
                                            (i32.const 1)))
                        (br $loop)))
           (i32.const 0))

     ;; Convert by inspecting integer bits and rounding once. Let
     ;;
     ;;     bits = bit length of abs(b)
     ;;     e    = bits - 1
     ;;
     ;; The retained significand is the top 53 bits, shifted into an integer
     ;; in [2^52, 2^53). Bits below it provide the guard and sticky bits for
     ;; round-to-nearest, ties-to-even.
     ;; $bignum->f64 : bignum? -> f64
     ;;   Convert an exact bignum to the nearest host f64 value.
     (func $bignum->f64
           (param $b (ref $Bignum))
           (result f64)

           (local $bits      i32)
           (local $exponent  i32)
           (local $shift     i32)
           (local $k         i32)
           (local $src-bit   i32)
           (local $retained  i64)
           (local $out-bits  i64)
           (local $out       f64)

           ;; Find the unbiased binary exponent from the magnitude bit length.
           (local.set $bits
                      (call $integer-nonnegative-bit-length/i32
                            (local.get $b)))
           (local.set $exponent
                      (i32.sub (local.get $bits) (i32.const 1)))

           ;; Exact integers above the binary64 range overflow to infinity.
           (if (i32.gt_s (local.get $exponent) (i32.const 1023))
               (then
                (if (i32.lt_s (struct.get $Bignum $sign (local.get $b))
                              (i32.const 0))
                    (then (return (f64.const -inf)))
                    (else (return (f64.const +inf))))))

           ;; Extract the retained significand bits. A negative shift means
           ;; the integer has fewer than 53 bits and is shifted left exactly.
           (local.set $shift
                      (i32.sub (local.get $bits) (i32.const 53)))
           (block $done
                  (loop $loop
                        (br_if $done
                               (i32.ge_u (local.get $k) (i32.const 53)))
                        (local.set $src-bit
                                   (i32.add (local.get $shift)
                                            (local.get $k)))
                        (if (call $bignum-bit/i32
                                  (local.get $b)
                                  (local.get $src-bit))
                            (then
                             (local.set $retained
                                        (i64.or
                                         (local.get $retained)
                                         (i64.shl
                                          (i64.const 1)
                                          (i64.extend_i32_u
                                           (local.get $k)))))))
                        (local.set $k
                                   (i32.add (local.get $k)
                                            (i32.const 1)))
                        (br $loop)))

           ;; If bits were discarded, round once using guard and sticky bits.
           (if (i32.gt_s (local.get $shift) (i32.const 0))
               (then
                (if (i32.and
                     (call $bignum-bit/i32
                           (local.get $b)
                           (i32.sub (local.get $shift) (i32.const 1)))
                     (i32.or
                      (call $bignum-any-bits-below?/i32
                            (local.get $b)
                            (i32.sub (local.get $shift) (i32.const 1)))
                      (i32.wrap_i64
                       (i64.and (local.get $retained) (i64.const 1)))))
                    (then
                     (local.set $retained
                                (i64.add (local.get $retained)
                                         (i64.const 1)))))))

           ;; A carry out of the 53-bit significand increments the exponent.
           (if (i64.eq (local.get $retained)
                       (i64.const 9007199254740992))
               (then
                (local.set $retained (i64.const 4503599627370496))
                (local.set $exponent
                           (i32.add (local.get $exponent) (i32.const 1)))
                (if (i32.gt_s (local.get $exponent) (i32.const 1023))
                    (then
                     (if (i32.lt_s (struct.get $Bignum $sign (local.get $b))
                                   (i32.const 0))
                         (then (return (f64.const -inf)))
                         (else (return (f64.const +inf))))))))

           ;; Pack the biased exponent and fraction bits into a positive f64.
           (local.set $out-bits
                      (i64.or
                       (i64.shl
                        (i64.extend_i32_u
                         (i32.add (local.get $exponent) (i32.const 1023)))
                        (i64.const 52))
                       (i64.sub
                        (local.get $retained)
                        (i64.const 4503599627370496))))
           (local.set $out (f64.reinterpret_i64 (local.get $out-bits)))

           ;; Apply the bignum sign after magnitude conversion.
           (if (result f64)
               (i32.lt_s (struct.get $Bignum $sign (local.get $b))
                         (i32.const 0))
               (then (f64.neg (local.get $out)))
               (else (local.get $out))))

     ;; $integer->f64 : exact-integer? -> f64
     ;;   Convert a WebRacket exact integer to f64 for mixed inexact arithmetic.
     (func $integer->f64
           (param $x (ref eq))
           (result f64)

           ;; Fixnums convert directly from their decoded signed payload.
           (if (ref.test (ref i31) (local.get $x))
               (then
                (return
                 (f64.convert_i32_s
                  (i32.shr_s
                   (i31.get_s (ref.cast (ref i31) (local.get $x)))
                   (i32.const 1))))))

           ;; Bignums convert by extracting bits and rounding once.
           (call $bignum->f64 (ref.cast (ref $Bignum) (local.get $x))))

     ;;;
     ;;; Equality and Hashing
     ;;;

     ;; $bignum-eqv? : bignum? bignum? -> boolean?
     ;;   Compare canonical bignums by sign and unsigned little-endian limbs.
     (func $bignum-eqv?
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-limbs (ref $I32Array))
           (local $b-limbs (ref $I32Array))
           (local $len i32)
           (local $i i32)

           ;; Different signs or limb counts make canonical bignums unequal.
           (if (i32.ne (struct.get $Bignum $sign (local.get $a))
                       (struct.get $Bignum $sign (local.get $b)))
               (then (return (global.get $false))))
           (local.set $a-limbs (struct.get $Bignum $limbs (local.get $a)))
           (local.set $b-limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $a-limbs)))
           (if (i32.ne (local.get $len) (array.len (local.get $b-limbs)))
               (then (return (global.get $false))))

           ;; Equal signs and lengths compare each limb.
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                        (if (i32.ne (array.get $I32Array (local.get $a-limbs) (local.get $i))
                                    (array.get $I32Array (local.get $b-limbs) (local.get $i)))
                            (then (return (global.get $false))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (global.get $true))

     ;; $bignum-hash/i32 : bignum? -> i32
     ;;   Compute a value hash from sign and limbs, consistent with bignum eqv?.
     (func $bignum-hash/i32
           (param $b (ref $Bignum))
           (result i32)

           (local $limbs (ref $I32Array))
           (local $len i32)
           (local $i i32)
           (local $h i32)

           ;; Seed the hash with FNV offset basis mixed with the sign.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $h (i32.xor (i32.const 0x811c9dc5)
                                  (struct.get $Bignum $sign (local.get $b))))

           ;; Mix each limb with a small Murmur-style rotate/multiply step.
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                        (local.set $h
                                   (i32.mul
                                    (i32.rotl
                                     (i32.mul
                                      (i32.xor
                                       (local.get $h)
                                       (array.get $I32Array (local.get $limbs) (local.get $i)))
                                      (i32.const 0xcc9e2d51))
                                     (i32.const 15))
                                    (i32.const 0x1b873593)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))

           ;; Avoid zero as a cached hash sentinel.
           (if (result i32)
               (i32.eqz (local.get $h))
               (then (i32.const 2))
               (else (local.get $h))))

     ;;;
     ;;; Printing
     ;;;

     ;; $bignum->string : bignum? (or/c 2 8 10 16) -> string?
     ;;   Convert a canonical bignum by repeated division with an unsigned
     ;;   small radix. The working copy is mutated; the source limbs are not.
     (func $bignum->string
           (param $b (ref $Bignum))
           (param $radix i32)
           (result (ref $String))

           (local $limbs (ref $I32Array))
           (local $work (ref $I32Array))
           (local $len i32)
           (local $active-len i32)
           (local $max-len i32)
           (local $buf (ref $I32Array))
           (local $out (ref $I32Array))
           (local $i i32)
           (local $j i32)
           (local $carry i32)
           (local $digit i32)
           (local $acc i64)
           (local $q i64)
           (local $radix64 i64)
           (local $sign i32)
           (local $out-len i32)

           ;; Read the source limbs and choose a conservative output buffer size.
           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $active-len (local.get $len))
           (local.set $sign (struct.get $Bignum $sign (local.get $b)))

           (if (i32.eq (local.get $radix) (i32.const 2))
               (then (local.set $max-len
                                (call $bignum-size-add/i32
                                      (call $bignum-size-mul/i32
                                            (local.get $len)
                                            (i32.const 32))
                                      (i32.const 1))))
               (else
                (if (i32.eq (local.get $radix) (i32.const 8))
                    (then (local.set $max-len
                                     (call $bignum-size-add/i32
                                           (call $bignum-size-mul/i32
                                                 (local.get $len)
                                                 (i32.const 11))
                                           (i32.const 1))))
                    (else
                     (if (i32.eq (local.get $radix) (i32.const 16))
                         (then (local.set $max-len
                                          (call $bignum-size-add/i32
                                                (call $bignum-size-mul/i32
                                                      (local.get $len)
                                                      (i32.const 8))
                                                (i32.const 1))))
                        (else (local.set $max-len
                                          (call $bignum-size-add/i32
                                                (call $bignum-size-mul/i32
                                                      (local.get $len)
                                                      (i32.const 10))
                                                (i32.const 1)))))))))

           ;; Work on a mutable copy because repeated division destroys the magnitude.
           (local.set $work (array.new_default $I32Array (local.get $len)))
           (array.copy $I32Array $I32Array
                       (local.get $work) (i32.const 0)
                       (local.get $limbs) (i32.const 0)
                       (local.get $len))
           (local.set $buf (array.new_default $I32Array (local.get $max-len)))
           (local.set $i (local.get $max-len))
           (local.set $radix64 (i64.extend_i32_u (local.get $radix)))

           ;; Repeatedly divide by the radix; each remainder is the next digit.
           (block $digits-done
                  (loop $digit-loop
                        (br_if $digits-done (i32.eqz (local.get $active-len)))
                        (local.set $carry (i32.const 0))
                        (local.set $j (local.get $active-len))
                        (block $division-done
                               (loop $division-loop
                                     (br_if $division-done (i32.eqz (local.get $j)))
                                     (local.set $j (i32.sub (local.get $j) (i32.const 1)))
                                     (local.set $acc
                                                (i64.or
                                                 (i64.shl
                                                  (i64.extend_i32_u (local.get $carry))
                                                  (i64.const 32))
                                                 (i64.extend_i32_u
                                                  (array.get $I32Array
                                                             (local.get $work)
                                                             (local.get $j)))))
                                     (local.set $q (i64.div_u (local.get $acc)
                                                              (local.get $radix64)))
                                     (local.set $carry
                                                (i32.wrap_i64
                                                 (i64.rem_u (local.get $acc)
                                                            (local.get $radix64))))
                                    (array.set $I32Array
                                               (local.get $work)
                                               (local.get $j)
                                               (i32.wrap_i64 (local.get $q)))
                                     (br $division-loop)))

                        ;; Emit the digit as an ASCII code point in reverse order.
                        (local.set $digit (local.get $carry))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (array.set $I32Array
                                   (local.get $buf)
                                   (local.get $i)
                                   (select
                                    (i32.add (local.get $digit) (i32.const 48))
                                    (i32.add (local.get $digit) (i32.const 87))
                                    (i32.lt_u (local.get $digit) (i32.const 10))))

                        ;; Trim high zero limbs from the working magnitude.
                        (block $trim-done
                               (loop $trim-loop
                                     (br_if $trim-done (i32.eqz (local.get $active-len)))
                                     (if (i32.eqz
                                          (array.get $I32Array
                                                     (local.get $work)
                                                     (i32.sub (local.get $active-len) (i32.const 1))))
                                         (then
                                          (local.set $active-len
                                                     (i32.sub (local.get $active-len) (i32.const 1)))
                                          (br $trim-loop))
                                         (else (br $trim-done)))))
                        (br $digit-loop)))

           ;; Add a minus sign for negative bignums.
           (if (i32.lt_s (local.get $sign) (i32.const 0))
               (then
                (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                (array.set $I32Array (local.get $buf) (local.get $i) (i32.const 45))))

           ;; Copy the used suffix into an immutable WebRacket string.
           (local.set $out-len (i32.sub (local.get $max-len) (local.get $i)))
           (local.set $out (array.new_default $I32Array (local.get $out-len)))
           (array.copy $I32Array $I32Array
                       (local.get $out) (i32.const 0)
                       (local.get $buf) (local.get $i)
                       (local.get $out-len))
           (struct.new $String
                       (i32.const 0)
                       (i32.const 1)
                       (local.get $out))))))

;; bignum-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render bignum core helpers in runtime assembly order.
(define (bignum-core-runtime-helper-forms helper-index)
  (for/list ([helper (in-list bignum-core-runtime-helpers)])
    (core-runtime-helper-form helper-index
                              (core-runtime-helper-name helper))))

;; bignum-runtime-only-helpers : (listof core-runtime-helper?)
;;   Bignum support is currently core-only.
(define bignum-runtime-only-helpers '())
