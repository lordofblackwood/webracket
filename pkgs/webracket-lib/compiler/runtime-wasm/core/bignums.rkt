#lang racket

(provide bignum-core-runtime-helpers
         bignum-core-runtime-helper-forms
         bignum-runtime-only-helpers)

(require "../core-helper.rkt")

;; bignum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Runtime support for exact integers outside the i31 fixnum range.
(define bignum-core-runtime-helpers
  (function-forms->runtime-helpers
   'bignum-core-runtime-helpers
   '(
     ;; $integer-from-i64 : i64 -> exact-integer?
     ;;   Build a canonical exact integer from a signed 64-bit value.
     (func $integer-from-i64
           (param $v i64)
           (result (ref eq))

           (local $sign i32)
           (local $abs  i64)
           (local $low  i32)
           (local $high i32)

           (if (i32.and
                (i64.ge_s (local.get $v) (i64.const -536870912))
                (i64.le_s (local.get $v) (i64.const  536870911)))
               (then
                (return
                 (ref.i31
                  (i32.shl (i32.wrap_i64 (local.get $v)) (i32.const 1))))))

           (if (i64.lt_s (local.get $v) (i64.const 0))
               (then
                (local.set $sign (i32.const -1))
                (local.set $abs (i64.sub (i64.const 0) (local.get $v))))
               (else
                (local.set $sign (i32.const 1))
                (local.set $abs (local.get $v))))
           (local.set $low (i32.wrap_i64 (local.get $abs)))
           (local.set $high (i32.wrap_i64
                             (i64.shr_u (local.get $abs) (i64.const 32))))
           (if (i32.eqz (local.get $high))
               (then
                (return
                 (call $bignum-normalize
                       (local.get $sign)
                       (array.new_fixed $I32Array 1 (local.get $low))))))
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

           (local.set $len (array.len (local.get $limbs)))
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
           (if (i32.eqz (local.get $active-len))
               (then (return (ref.i31 (i32.const 0)))))

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

           (if (i32.eq (local.get $active-len) (local.get $len))
               (then
                (return
                 (struct.new $Bignum
                             (i32.const 0)
                             (select (i32.const 1)
                                     (i32.const -1)
                                     (i32.gt_s (local.get $sign) (i32.const 0)))
                             (local.get $limbs)))))
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

           (local.set $v
                      (i32.shr_s
                       (i31.get_s (ref.cast (ref i31) (local.get $x)))
                       (i32.const 1)))
           (if (i32.lt_s (local.get $v) (i32.const 0))
               (then
                (local.set $sign (i32.const -1))
                (local.set $magnitude
                           (i32.sub (i32.const 0) (local.get $v))))
               (else
                (local.set $sign (i32.const 1))
                (local.set $magnitude (local.get $v))))
           (struct.new $Bignum
                       (i32.const 0)
                       (local.get $sign)
                       (array.new_fixed $I32Array 1
                                        (local.get $magnitude))))

     ;; $bignum-negate : bignum? -> bignum?
     ;;   Return the canonical additive inverse of a nonzero bignum.
     (func $bignum-negate
           (param $b (ref $Bignum))
           (result (ref eq))

           (struct.new $Bignum
                       (i32.const 0)
                       (i32.sub (i32.const 0)
                                (struct.get $Bignum $sign (local.get $b)))
                       (struct.get $Bignum $limbs (local.get $b))))

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

           (local.set $a-len (array.len (local.get $a)))
           (local.set $b-len (array.len (local.get $b)))
           (if (i32.lt_u (local.get $a-len) (local.get $b-len))
               (then (return (i32.const -1))))
           (if (i32.gt_u (local.get $a-len) (local.get $b-len))
               (then (return (i32.const 1))))
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
                       (i32.add (local.get $max-len) (i32.const 1))))
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

           (local.set $a-len (array.len (local.get $a)))
           (local.set $b-len (array.len (local.get $b)))
           (local.set $out (array.new_default $I32Array (local.get $a-len)))
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
                                                 (i64.const 4294967296)))
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
           (local.set $cmp
                      (call $bignum-magnitude-compare/i32
                            (local.get $a-limbs)
                            (local.get $b-limbs)))
           (if (i32.eqz (local.get $cmp))
               (then (return (ref.i31 (i32.const 0)))))
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
           (local.set $cmp
                      (call $bignum-magnitude-compare/i32
                            (local.get $a-limbs)
                            (local.get $b-limbs)))
           (if (i32.eqz (local.get $cmp))
               (then (return (ref.i31 (i32.const 0)))))
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

           (local.set $a-sign (struct.get $Bignum $sign (local.get $a)))
           (local.set $b-sign (struct.get $Bignum $sign (local.get $b)))
           (if (i32.ne (local.get $a-sign) (local.get $b-sign))
               (then
                (return
                 (select (i32.const 1)
                         (i32.const -1)
                         (i32.gt_s (local.get $a-sign)
                                   (local.get $b-sign))))))
           (local.set $cmp
                      (call $bignum-magnitude-compare/i32
                            (struct.get $Bignum $limbs (local.get $a))
                            (struct.get $Bignum $limbs (local.get $b))))
           (if (result i32)
               (i32.gt_s (local.get $a-sign) (i32.const 0))
               (then (local.get $cmp))
               (else (i32.sub (i32.const 0) (local.get $cmp)))))

     ;; $bignum-mul : bignum? bignum? -> exact-integer?
     ;;   Multiply two signed canonical bignums with schoolbook limbs.
     (func $bignum-mul
           (param $a (ref $Bignum))
           (param $b (ref $Bignum))
           (result (ref eq))

           (local $a-limbs (ref $I32Array))
           (local $b-limbs (ref $I32Array))
           (local $a-len i32)
           (local $b-len i32)
           (local $out-len i32)
           (local $out (ref $I32Array))
           (local $sign i32)
           (local $i i32)
           (local $j i32)
           (local $pos i32)
           (local $acc i64)
           (local $carry i64)

           (local.set $a-limbs (struct.get $Bignum $limbs (local.get $a)))
           (local.set $b-limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $a-len (array.len (local.get $a-limbs)))
           (local.set $b-len (array.len (local.get $b-limbs)))
           (local.set $out-len (i32.add (local.get $a-len) (local.get $b-len)))
           (local.set $out (array.new_default $I32Array (local.get $out-len)))
           (local.set $sign
                      (select (i32.const 1)
                              (i32.const -1)
                              (i32.eq (struct.get $Bignum $sign (local.get $a))
                                      (struct.get $Bignum $sign (local.get $b)))))
           (block $outer-done
                  (loop $outer
                        (br_if $outer-done
                               (i32.ge_u (local.get $i) (local.get $a-len)))
                        (local.set $carry (i64.const 0))
                        (local.set $j (i32.const 0))
                        (block $inner-done
                               (loop $inner
                                     (br_if $inner-done
                                            (i32.ge_u (local.get $j) (local.get $b-len)))
                                     (local.set $pos
                                                (i32.add (local.get $i)
                                                         (local.get $j)))
                                     (local.set $acc
                                                (i64.add
                                                 (i64.add
                                                  (i64.extend_i32_u
                                                   (array.get $I32Array
                                                              (local.get $out)
                                                              (local.get $pos)))
                                                  (i64.mul
                                                   (i64.extend_i32_u
                                                    (array.get $I32Array
                                                               (local.get $a-limbs)
                                                               (local.get $i)))
                                                   (i64.extend_i32_u
                                                    (array.get $I32Array
                                                               (local.get $b-limbs)
                                                               (local.get $j)))))
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
                                   (i32.add (local.get $i) (local.get $b-len)))
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
           (call $bignum-normalize (local.get $sign) (local.get $out)))

     ;; $integer-add/2 : exact-integer? exact-integer? -> exact-integer?
     ;;   Add exact integers, promoting fixnum overflow to bignums.
     (func $integer-add/2
           (param $x (ref eq))
           (param $y (ref eq))
           (result (ref eq))

           (local $xv i64)
           (local $yv i64)

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
                (return
                 (call $bignum-add
                       (call $nonzero-fixnum->bignum (local.get $x))
                       (ref.cast (ref $Bignum) (local.get $y))))))
           (if (ref.test (ref i31) (local.get $y))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $y))))
                    (then (return (local.get $x))))
                (return
                 (call $bignum-add
                       (ref.cast (ref $Bignum) (local.get $x))
                       (call $nonzero-fixnum->bignum (local.get $y))))))
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
                (return
                 (call $bignum-sub
                       (call $nonzero-fixnum->bignum (local.get $x))
                       (ref.cast (ref $Bignum) (local.get $y))))))
           (if (ref.test (ref i31) (local.get $y))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $y))))
                    (then (return (local.get $x))))
                (return
                 (call $bignum-sub
                       (ref.cast (ref $Bignum) (local.get $x))
                       (call $nonzero-fixnum->bignum (local.get $y))))))
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

           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (then (return (ref.i31 (i32.const 0)))))
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
                (return
                       (call $bignum-mul
                             (call $nonzero-fixnum->bignum (local.get $x))
                             (ref.cast (ref $Bignum) (local.get $y))))))
           (if (ref.test (ref i31) (local.get $y))
               (then
                (if (i32.eqz
                     (i31.get_s (ref.cast (ref i31) (local.get $y))))
                    (then (return (ref.i31 (i32.const 0)))))
                (return
                 (call $bignum-mul
                       (ref.cast (ref $Bignum) (local.get $x))
                       (call $nonzero-fixnum->bignum (local.get $y))))))
           (call $bignum-mul
                 (ref.cast (ref $Bignum) (local.get $x))
                 (ref.cast (ref $Bignum) (local.get $y))))

     ;; $integer-zero?/i32 : exact-integer? -> i32
     ;;   Return 1 when x is exact zero, otherwise 0.
     (func $integer-zero?/i32
           (param $x (ref eq))
           (result i32)

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

           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $bits
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (return
                 (i32.eqz
                  (i32.and (local.get $bits) (i32.const 1))))))
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
           (struct.get $Bignum $sign (ref.cast (ref $Bignum) (local.get $x))))

     ;; $integer-abs-u32 : exact-integer? -> i32
     ;;   Return the absolute magnitude when it fits one unsigned 32-bit limb.
     (func $integer-abs-u32
           (param $x (ref eq))
           (result i32)

           (local $v i32)

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
           (array.get $I32Array
                      (struct.get $Bignum $limbs
                                  (ref.cast (ref $Bignum) (local.get $x)))
                      (i32.const 0)))

     ;; $integer-single-limb?/i32 : exact-integer? -> i32
     ;;   Return 1 when the exact integer's magnitude fits one 32-bit limb.
     (func $integer-single-limb?/i32
           (param $x (ref eq))
           (result i32)

           (if (ref.test (ref i31) (local.get $x))
               (then (return (i32.const 1))))
           (i32.eq
            (array.len
             (struct.get $Bignum $limbs
                         (ref.cast (ref $Bignum) (local.get $x))))
            (i32.const 1)))

     ;; $integer-apply-sign : exact-integer? i32 -> exact-integer?
     ;;   Apply sign to a nonnegative exact integer magnitude.
     (func $integer-apply-sign
           (param $mag  (ref eq))
           (param $sign i32)
           (result (ref eq))

           (if (i32.lt_s (local.get $sign) (i32.const 0))
               (then (return (call $integer-negate (local.get $mag)))))
           (local.get $mag))

     ;; $integer-nonnegative-limb-count/i32 : exact-nonnegative-integer? -> i32
     ;;   Return the number of finite magnitude limbs needed for x.
     (func $integer-nonnegative-limb-count/i32
           (param $x (ref eq))
           (result i32)

           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (i32.eqz (i31.get_s (ref.cast (ref i31) (local.get $x))))
                    (then (return (i32.const 0))))
                (return (i32.const 1))))
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

           (if (ref.test (ref i31) (local.get $x))
               (then
                (if (i32.eqz (local.get $i))
                    (then
                     (return
                      (i32.shr_u
                       (i31.get_s (ref.cast (ref i31) (local.get $x)))
                       (i32.const 1)))))
                (return (i32.const 0))))
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

           (local.set $out-len
                      (call $integer-nonnegative-limb-count/i32
                            (local.get $x)))
           (if (i32.eqz (local.get $out-len))
               (then (return (ref.i31 (i32.const 0)))))
           (local.set $out (array.new_default $I32Array
                                              (local.get $out-len)))
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

           (local.set $xc (ref.i31 (i32.const 0)))
           (local.set $yc (ref.i31 (i32.const 0)))
           (local.set $x-neg? (i32.lt_s (call $integer-sign/i32 (local.get $x))
                                        (i32.const 0)))
           (local.set $y-neg? (i32.lt_s (call $integer-sign/i32 (local.get $y))
                                        (i32.const 0)))
           (if (i32.eqz (i32.or (local.get $x-neg?) (local.get $y-neg?)))
               (then
                (return
                 (call $integer-bitwise-and/nonnegative
                       (local.get $x)
                       (local.get $y)))))
           (if (local.get $x-neg?)
               (then (local.set $xc (call $integer-bitwise-complement
                                          (local.get $x)))))
           (if (local.get $y-neg?)
               (then (local.set $yc (call $integer-bitwise-complement
                                          (local.get $y)))))
           (if (i32.and (local.get $x-neg?) (local.get $y-neg?))
               (then
                (return
                 (call $integer-bitwise-complement
                       (call $integer-bitwise-ior/nonnegative
                             (local.get $xc)
                             (local.get $yc))))))
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

           (local.set $xc (ref.i31 (i32.const 0)))
           (local.set $yc (ref.i31 (i32.const 0)))
           (local.set $x-neg? (i32.lt_s (call $integer-sign/i32 (local.get $x))
                                        (i32.const 0)))
           (local.set $y-neg? (i32.lt_s (call $integer-sign/i32 (local.get $y))
                                        (i32.const 0)))
           (if (i32.eqz (i32.or (local.get $x-neg?) (local.get $y-neg?)))
               (then
                (return
                 (call $integer-bitwise-ior/nonnegative
                       (local.get $x)
                       (local.get $y)))))
           (if (local.get $x-neg?)
               (then (local.set $xc (call $integer-bitwise-complement
                                          (local.get $x)))))
           (if (local.get $y-neg?)
               (then (local.set $yc (call $integer-bitwise-complement
                                          (local.get $y)))))
           (if (i32.and (local.get $x-neg?) (local.get $y-neg?))
               (then
                (return
                 (call $integer-bitwise-complement
                       (call $integer-bitwise-and/nonnegative
                             (local.get $xc)
                             (local.get $yc))))))
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

           (local.set $xc (ref.i31 (i32.const 0)))
           (local.set $yc (ref.i31 (i32.const 0)))
           (local.set $x-neg? (i32.lt_s (call $integer-sign/i32 (local.get $x))
                                        (i32.const 0)))
           (local.set $y-neg? (i32.lt_s (call $integer-sign/i32 (local.get $y))
                                        (i32.const 0)))
           (if (i32.eqz (i32.or (local.get $x-neg?) (local.get $y-neg?)))
               (then
                (return
                 (call $integer-bitwise-xor/nonnegative
                       (local.get $x)
                       (local.get $y)))))
           (if (local.get $x-neg?)
               (then (local.set $xc (call $integer-bitwise-complement
                                          (local.get $x)))))
           (if (local.get $y-neg?)
               (then (local.set $yc (call $integer-bitwise-complement
                                          (local.get $y)))))
           (if (i32.and (local.get $x-neg?) (local.get $y-neg?))
               (then
                (return
                 (call $integer-bitwise-xor/nonnegative
                       (local.get $xc)
                       (local.get $yc)))))
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

     ;; $bignum-divmod-u32 : bignum? i32 -> values exact-integer? exact-integer?
     ;;   Divide a positive bignum magnitude by a nonzero unsigned 32-bit limb.
     (func $bignum-divmod-u32
           (param $n (ref $Bignum))
           (param $d i32)
           (result (ref $Values))

           (local $limbs (ref $I32Array))
           (local $q-limbs (ref $I32Array))
           (local $i i32)
           (local $cur i64)
           (local $rem i64)
           (local $d64 i64)

           (local.set $limbs (struct.get $Bignum $limbs (local.get $n)))
           (local.set $i (array.len (local.get $limbs)))
           (local.set $q-limbs (array.new_default $I32Array (local.get $i)))
           (local.set $d64 (i64.extend_i32_u (local.get $d)))
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
           (array.new_fixed $Values 2
                            (call $bignum-normalize
                                  (i32.const 1)
                                  (local.get $q-limbs))
                            (call $integer-from-i64 (local.get $rem))))

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

           (local.set $n-limbs (struct.get $Bignum $limbs (local.get $n)))
           (local.set $d-limbs (struct.get $Bignum $limbs (local.get $d)))
           (local.set $n-len (array.len (local.get $n-limbs)))
           (local.set $d-len (array.len (local.get $d-limbs)))
           (local.set $q-len
                      (i32.add
                       (i32.sub (local.get $n-len) (local.get $d-len))
                       (i32.const 1)))

           (local.set $shift
                      (i32.clz
                       (array.get $I32Array
                                  (local.get $d-limbs)
                                  (i32.sub (local.get $d-len)
                                           (i32.const 1)))))
           (local.set $u
                      (array.new_default
                       $I32Array
                       (i32.add (local.get $n-len) (i32.const 1))))
           (local.set $v (array.new_default $I32Array (local.get $d-len)))
           (local.set $q-limbs
                      (array.new_default $I32Array (local.get $q-len)))

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
                             (local.set $qhat (i64.const 4294967295))
                             (local.set $rhat
                                        (i64.extend_i32_u
                                         (array.get $I32Array
                                                    (local.get $u)
                                                    (i32.add
                                                     (local.get $j)
                                                     (i32.sub
                                                      (local.get $d-len)
                                                      (i32.const 1)))))))
                            (else
                             (local.set $qhat
                                        (i64.div_u (local.get $numer)
                                                   (local.get $v-high)))
                             (local.set $rhat
                                        (i64.rem_u (local.get $numer)
                                                   (local.get $v-high)))))
                        (if (i32.gt_u (local.get $d-len) (i32.const 1))
                            (then
                             (block $qhat-ready
                                    (loop $qhat-loop
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
                        (array.set $I32Array
                                   (local.get $q-limbs)
                                   (local.get $j)
                                   (i32.wrap_i64 (local.get $qhat)))
                        (br $divide-loop)))

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

           (if (call $integer-zero?/i32 (local.get $n))
               (then
                (return
                 (array.new_fixed $Values 2
                                  (ref.i31 (i32.const 0))
                                  (ref.i31 (i32.const 0))))))
           (local.set $n-sign (call $integer-sign/i32 (local.get $n)))
           (local.set $m-sign (call $integer-sign/i32 (local.get $m)))
           (local.set $q-sign
                      (select (i32.const 1)
                              (i32.const -1)
                              (i32.eq (local.get $n-sign)
                                      (local.get $m-sign))))
           (local.set $d (call $integer-abs-u32 (local.get $m)))

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

           (if (call $integer-zero?/i32 (local.get $n))
               (then
                (return
                 (array.new_fixed $Values 2
                                  (ref.i31 (i32.const 0))
                                  (ref.i31 (i32.const 0))))))
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
           (if (i32.lt_s (local.get $cmp) (i32.const 0))
               (then
                (return
                 (array.new_fixed $Values 2
                                  (ref.i31 (i32.const 0))
                                  (local.get $n)))))
           (if (call $integer-single-limb?/i32 (local.get $m))
               (then
                (return
                 (call $integer-divmod/single-limb
                       (local.get $n)
                       (local.get $m)))))

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

     ;; $integer-compare/i32 : exact-integer? exact-integer? -> integer?
     ;;   Compare exact integers, returning -1, 0, or 1.
     (func $integer-compare/i32
           (param $x (ref eq))
           (param $y (ref eq))
           (result i32)

           (local $xv i32)
           (local $yv i32)
           (local $yb (ref $Bignum))

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
                (local.set $yb (ref.cast (ref $Bignum) (local.get $y)))
                (if (i32.eqz (local.get $xv))
                    (then
                     (return
                      (if (result i32)
                          (i32.gt_s (struct.get $Bignum $sign (local.get $yb))
                                    (i32.const 0))
                          (then (i32.const -1))
                          (else (i32.const 1))))))
                (return
                 (call $bignum-compare/i32
                       (call $nonzero-fixnum->bignum (local.get $x))
                       (local.get $yb)))))

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

           (if (i64.eqz (local.get $m))
               (then (return (ref.i31 (i32.const 0)))))

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
                       (i32.add (local.get $word-shift) (i32.const 3))))

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

           (if (f64.lt (local.get $y) (f64.const 1.0))
               (then (return (i32.const 1))))

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

           (if (i32.ge_s (local.get $shift) (i32.const 0))
               (then
                (return
                 (call $integer-compare/i32
                       (call $integer-abs (local.get $x))
                       (call $u64-shl->integer
                             (local.get $mantissa)
                             (local.get $shift))))))

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

           (local.set $cmp
                      (call $integer-flonum-abs-compare/i32
                            (local.get $x)
                            (f64.abs (local.get $y))))
           (if (result i32)
               (i32.gt_s (local.get $x-sign) (i32.const 0))
               (then (local.get $cmp))
               (else (i32.sub (i32.const 0) (local.get $cmp)))))

     ;; $integer-negate : exact-integer? -> exact-integer?
     ;;   Return the additive inverse, promoting the most-negative fixnum.
     (func $integer-negate
           (param $x (ref eq))
           (result (ref eq))

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
           (call $bignum-negate (ref.cast (ref $Bignum) (local.get $x))))

     ;; $integer-abs : exact-integer? -> exact-integer?
     ;;   Return the exact absolute value, preserving bignums.
     (func $integer-abs
           (param $x (ref eq))
           (result (ref eq))

           (local $v i32)

           (if (ref.test (ref i31) (local.get $x))
               (then
                (local.set $v
                           (i32.shr_s
                            (i31.get_s (ref.cast (ref i31) (local.get $x)))
                            (i32.const 1)))
                (if (i32.lt_s (local.get $v) (i32.const 0))
                    (then (return (call $integer-negate (local.get $x))))
                    (else (return (local.get $x))))))
           (if (i32.lt_s
                (struct.get $Bignum $sign
                            (ref.cast (ref $Bignum) (local.get $x)))
                (i32.const 0))
               (then
                (return
                 (call $bignum-negate
                       (ref.cast (ref $Bignum) (local.get $x))))))
           (local.get $x))

     ;; $bignum->f64 : bignum? -> f64
     ;;   Convert an exact bignum to the nearest host f64 value.
     (func $bignum->f64
           (param $b (ref $Bignum))
           (result f64)

           (local $limbs (ref $I32Array))
           (local $i i32)
           (local $out f64)

           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $i (array.len (local.get $limbs)))
           (block $done
                  (loop $loop
                        (br_if $done (i32.eqz (local.get $i)))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (local.set $out
                                   (f64.add
                                    (f64.mul (local.get $out)
                                             (f64.const 4294967296.0))
                                    (f64.convert_i32_u
                                     (array.get $I32Array
                                                (local.get $limbs)
                                                (local.get $i)))))
                        (br $loop)))
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

           (if (ref.test (ref i31) (local.get $x))
               (then
                (return
                 (f64.convert_i32_s
                  (i32.shr_s
                   (i31.get_s (ref.cast (ref i31) (local.get $x)))
                   (i32.const 1))))))
           (call $bignum->f64 (ref.cast (ref $Bignum) (local.get $x))))

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

           (if (i32.ne (struct.get $Bignum $sign (local.get $a))
                       (struct.get $Bignum $sign (local.get $b)))
               (then (return (global.get $false))))
           (local.set $a-limbs (struct.get $Bignum $limbs (local.get $a)))
           (local.set $b-limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $a-limbs)))
           (if (i32.ne (local.get $len) (array.len (local.get $b-limbs)))
               (then (return (global.get $false))))
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

           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $h (i32.xor (i32.const 0x811c9dc5)
                                  (struct.get $Bignum $sign (local.get $b))))
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
           (if (result i32)
               (i32.eqz (local.get $h))
               (then (i32.const 2))
               (else (local.get $h))))

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

           (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
           (local.set $len (array.len (local.get $limbs)))
           (local.set $active-len (local.get $len))
           (local.set $sign (struct.get $Bignum $sign (local.get $b)))

           (if (i32.eq (local.get $radix) (i32.const 2))
               (then (local.set $max-len
                                (i32.add (i32.mul (local.get $len) (i32.const 32))
                                         (i32.const 1))))
               (else
                (if (i32.eq (local.get $radix) (i32.const 8))
                    (then (local.set $max-len
                                     (i32.add (i32.mul (local.get $len) (i32.const 11))
                                              (i32.const 1))))
                    (else
                     (if (i32.eq (local.get $radix) (i32.const 16))
                         (then (local.set $max-len
                                          (i32.add (i32.mul (local.get $len) (i32.const 8))
                                                   (i32.const 1))))
                         (else (local.set $max-len
                                          (i32.add (i32.mul (local.get $len) (i32.const 10))
                                                   (i32.const 1)))))))))
           (local.set $work (array.new_default $I32Array (local.get $len)))
           (array.copy $I32Array $I32Array
                       (local.get $work) (i32.const 0)
                       (local.get $limbs) (i32.const 0)
                       (local.get $len))
           (local.set $buf (array.new_default $I32Array (local.get $max-len)))
           (local.set $i (local.get $max-len))
           (local.set $radix64 (i64.extend_i32_u (local.get $radix)))

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
                        (local.set $digit (local.get $carry))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (array.set $I32Array
                                   (local.get $buf)
                                   (local.get $i)
                                   (select
                                    (i32.add (local.get $digit) (i32.const 48))
                                    (i32.add (local.get $digit) (i32.const 87))
                                    (i32.lt_u (local.get $digit) (i32.const 10))))
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

           (if (i32.lt_s (local.get $sign) (i32.const 0))
               (then
                (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                (array.set $I32Array (local.get $buf) (local.get $i) (i32.const 45))))
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
