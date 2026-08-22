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
