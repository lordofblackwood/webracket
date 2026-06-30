#lang racket

(provide growable-array-core-runtime-helpers)

(require "arrays.rkt"
         "immediates.rkt"
         "../core-helper.rkt")

;; growable-array-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate generic growable array helpers that can be emitted in core runtime.
(define growable-array-core-runtime-helpers
  (list
   ;;;
   ;;; Growable Arrays
   ;;;

   ;; A growable array is like an array, but the length can change over time.
   ;; They are modelled over "growable vectors" from `racket/data`.

   (core-runtime-helper
    '$make-growable-array
    "$make-growable-array"
    (lambda ()
      `(func $make-growable-array (param $cap i32) (result (ref $GrowableArray))
             (local $initial-cap i32)
             (local.set $initial-cap
                        (if (result i32)
                            (i32.eqz (local.get $cap))
                            (then (i32.const 16))
                            (else (local.get $cap))))
             (struct.new $GrowableArray
                         ,(make-array `(local.get $initial-cap) false-ref)
                         (local.get $initial-cap)
                         (i32.const 0)))))

   (core-runtime-helper
    '$growable-array??
    "$growable-array??"
    (lambda ()
      `(func $growable-array?? (param $x (ref eq)) (result i32)
             ; 0 = false, 1 = true
             (ref.test (ref $GrowableArray) (local.get $x)))))

   (core-runtime-helper
    '$growable-array?
    "$growable-array?"
    (lambda ()
      `(func $growable-array? (param $x (ref eq)) (result (ref eq))
             (if (result (ref eq)) (ref.test (ref $GrowableArray) (local.get $x))
                 (then ,true-ref)
                 (else ,false-ref)))))

   (core-runtime-helper
    '$growable-array-ref
    "$growable-array-ref"
    (lambda ()
      `(func $growable-array-ref (param $g (ref $GrowableArray)) (param $index i32) (result (ref eq))
             (local $i i32)
             (local.set $i (struct.get $GrowableArray $i (local.get $g)))
             (if (result (ref eq))
                 (i32.lt_u (local.get $index) (local.get $i))
                 (then (array.get $Array (struct.get $GrowableArray $arr (local.get $g)) (local.get $index)))
                 (else ,false-ref)))))

   (core-runtime-helper
    '$growable-array-ref/default
    "$growable-array-ref/default"
    (lambda ()
      `(func $growable-array-ref/default (param $g (ref $GrowableArray)) (param $index i32) (param $default (ref eq)) (result (ref eq))
             (local $i i32)
             (local.set $i (struct.get $GrowableArray $i (local.get $g)))
             (if (result (ref eq))
                 (i32.lt_u (local.get $index) (local.get $i))
                 (then (array.get $Array (struct.get $GrowableArray $arr (local.get $g)) (local.get $index)))
                 (else (local.get $default))))))

   (core-runtime-helper
    '$growable-array-add!
    "$growable-array-add!"
    (lambda ()
      `(func $growable-array-add! (param $g (ref $GrowableArray)) (param $v (ref eq))
             (local $i i32)
             (local $cap i32)
             (local $arr (ref $Array))
             (local $new-cap i32)
             (local $new-arr (ref $Array))
             (local.set $i   (struct.get $GrowableArray $i   (local.get $g)))
             (local.set $cap (struct.get $GrowableArray $cap (local.get $g)))
             (local.set $arr (struct.get $GrowableArray $arr (local.get $g)))
             (if (i32.eq (local.get $i) (local.get $cap))
                 (then
                  (local.set $new-cap (i32.shl (local.get $cap) (i32.const 1))) ;; new-cap = cap * 2
                  ,@(array-extend '$new-arr
                                  `(local.get $arr)
                                  `(local.get $new-cap)
                                  false-ref
                                  `(local.get $cap))
                  (struct.set $GrowableArray $arr (local.get $g) (local.get $new-arr))
                  (struct.set $GrowableArray $cap (local.get $g) (local.get $new-cap))
                  (local.set $arr (local.get $new-arr))))
             (array.set $Array (local.get $arr) (local.get $i) (local.get $v))
             (struct.set $GrowableArray $i (local.get $g) (i32.add (local.get $i) (i32.const 1))))))

   (core-runtime-helper
    '$growable-array-insert!
    "$growable-array-insert!"
    (lambda ()
      `(func $growable-array-insert! (param $g (ref $GrowableArray)) (param $index i32) (param $value (ref eq))
             (local $i i32)
             (local $arr (ref $Array))
             (local.set $i (struct.get $GrowableArray $i (local.get $g)))
             (if (i32.eq (local.get $index) (local.get $i))
                 (then (call $growable-array-add! (local.get $g) (local.get $value)))
                 (else
                  (call $growable-array-add! (local.get $g) ,false-ref)
                  (local.set $arr (struct.get $GrowableArray $arr (local.get $g)))
                  ,(array-copy! `(local.get $arr) `(i32.add (local.get $index) (i32.const 1))
                                `(local.get $arr) `(local.get $index)
                                `(i32.sub (local.get $i) (local.get $index)))
                  (array.set $Array (local.get $arr) (local.get $index) (local.get $value)))))))

   (core-runtime-helper
    '$growable-array-set!
    "$growable-array-set!"
    (lambda ()
      `(func $growable-array-set! (param $g (ref $GrowableArray)) (param $index i32) (param $value (ref eq))
             (local $i i32)
             (local.set $i (struct.get $GrowableArray $i (local.get $g)))
             (if (i32.eq (local.get $index) (local.get $i))
                 (then (call $growable-array-add! (local.get $g) (local.get $value)))
                 (else
                  (array.set $Array (struct.get $GrowableArray $arr (local.get $g)) (local.get $index) (local.get $value)))))))

   (core-runtime-helper
    '$growable-array-remove!
    "$growable-array-remove!"
    (lambda ()
      `(func $growable-array-remove! (param $g (ref $GrowableArray)) (param $index i32)
             (local $i i32)
             (local.set $i (struct.get $GrowableArray $i (local.get $g)))
             ,(array-copy! `(struct.get $GrowableArray $arr (local.get $g)) `(local.get $index)
                           `(struct.get $GrowableArray $arr (local.get $g)) `(i32.add (local.get $index) (i32.const 1))
                           `(i32.sub (local.get $i) (i32.add (local.get $index) (i32.const 1))))
             (struct.set $GrowableArray $i (local.get $g) (i32.sub (local.get $i) (i32.const 1))))))

   (core-runtime-helper
    '$growable-array-remove-last!
    "$growable-array-remove-last!"
    (lambda ()
      `(func $growable-array-remove-last! (param $g (ref $GrowableArray)) (result (ref eq))
             (local $i i32)
             (local.set $i (struct.get $GrowableArray $i (local.get $g)))
             (struct.set $GrowableArray $i (local.get $g) (i32.sub (local.get $i) (i32.const 1)))
             (array.get $Array (struct.get $GrowableArray $arr (local.get $g)) (i32.sub (local.get $i) (i32.const 1))))))

   (core-runtime-helper
    '$growable-array-count
    "$growable-array-count"
    (lambda ()
      `(func $growable-array-count (param $g (ref $GrowableArray)) (result i32)
             (struct.get $GrowableArray $i (local.get $g)))))

   (core-runtime-helper
    '$growable-array->array
    "$growable-array->array"
    (lambda ()
      `(func $growable-array->array (param $g (ref $GrowableArray)) (result (ref $Array))
             (local $count i32)
             (local $res (ref $Array))
             (local.set $count (struct.get $GrowableArray $i (local.get $g)))
             ,@(array-extend '$res
                             `(struct.get $GrowableArray $arr (local.get $g))
                             `(local.get $count)
                             false-ref
                             `(local.get $count))
             (local.get $res))))

   (core-runtime-helper
    '$array->growable-array
    "$array->growable-array"
    (lambda ()
      `(func $array->growable-array (param $a (ref $Array)) (result (ref $GrowableArray))
             ; Note: This wraps the array in a growable array. It does not make a copy.
             (local $n i32)
             (local.set $n (array.len (local.get $a)))
             (struct.new $GrowableArray (local.get $a) (local.get $n) (local.get $n)))))))
