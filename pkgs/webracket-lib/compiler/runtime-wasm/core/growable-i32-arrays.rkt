#lang racket

(provide growable-i32-array-core-runtime-helper-forms
         growable-i32-array-core-runtime-helper-names
         growable-i32-array-core-runtime-helpers)

(require "../core-helper.rkt")

;; growable-i32-array-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate I32GrowableArray helpers that can be emitted in core runtime.
(define growable-i32-array-core-runtime-helpers
  (list
   ;;;
   ;;; Growable Arrays of I32
   ;;;

   #;(type $I32Array (array (mut i32)))

   #;(type $I32GrowableArray
         (struct
           (field $arr (mut (ref $I32Array))) ;; underlying array
           (field $cap (mut i32))             ;; capacity
           (field $i   (mut i32))))           ;; current size

   (core-runtime-helper
    '$make-i32growable-array
    "$make-i32growable-array"
    (lambda ()
      `(func $make-i32growable-array (param $cap i32) (result (ref $I32GrowableArray))
             (local $initial-cap i32)
             (local.set $initial-cap (if (result i32) (i32.eqz (local.get $cap))
                                         (then (i32.const 16))
                                         (else (local.get $cap))))
             (struct.new $I32GrowableArray
                         (array.new_default $I32Array (local.get $initial-cap))
                         (local.get $initial-cap)
                         (i32.const 0)))))

   (core-runtime-helper
    '$i32growable-array-add!
    "$i32growable-array-add!"
    (lambda ()
      `(func $i32growable-array-add! (param $g (ref $I32GrowableArray)) (param $v i32)
             (local $i       i32)
             (local $cap     i32)
             (local $arr     (ref $I32Array))
             (local $new-cap i32)
             (local $new-arr (ref $I32Array))

             (local.set $i   (struct.get $I32GrowableArray $i   (local.get $g)))
             (local.set $cap (struct.get $I32GrowableArray $cap (local.get $g)))
             (local.set $arr (struct.get $I32GrowableArray $arr (local.get $g)))

             (if (i32.eq (local.get $i) (local.get $cap))
                 (then
                  (local.set $new-cap (i32.shl (local.get $cap) (i32.const 1)))
                  (local.set $new-arr (call $i32array-extend
                                            (local.get $arr) (local.get $new-cap) (i32.const 0)))
                  (struct.set $I32GrowableArray $arr (local.get $g) (local.get $new-arr))
                  (struct.set $I32GrowableArray $cap (local.get $g) (local.get $new-cap))
                  (local.set $arr (local.get $new-arr))))
             (array.set $I32Array (local.get $arr) (local.get $i) (local.get $v))
             (struct.set $I32GrowableArray $i (local.get $g) (i32.add (local.get $i) (i32.const 1))))))

   (core-runtime-helper
    '$i32growable-array-add-string!
    "$i32growable-array-add-string!"
    (lambda ()
      `(func $i32growable-array-add-string!
             (param $g (ref $I32GrowableArray))
             (param $s (ref $String))
             (local $arr (ref $I32Array))
             (local $len i32)
             (local $i   i32)
             (local.set $arr (struct.get $String $codepoints (local.get $s)))
             (local.set $len (array.len (local.get $arr)))
             (local.set $i   (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                          (call $i32growable-array-add!
                                (local.get $g)
                                (array.get $I32Array (local.get $arr) (local.get $i)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop))))))

   (core-runtime-helper
    '$i32growable-array-ref
    "$i32growable-array-ref"
    (lambda ()
      `(func $i32growable-array-ref (param $g (ref $I32GrowableArray)) (param $index i32) (result i32)
             (local $i i32)
             (local.set $i (struct.get $I32GrowableArray $i (local.get $g)))
             (if (result i32)
                 (i32.lt_u (local.get $index) (local.get $i))
                 (then (array.get $I32Array (struct.get $I32GrowableArray $arr (local.get $g)) (local.get $index)))
                 (else (i32.const 0)))))) ;; You might want to raise instead

   (core-runtime-helper
    '$i32growable-array-count
    "$i32growable-array-count"
    (lambda ()
      `(func $i32growable-array-count (param $g (ref $I32GrowableArray)) (result i32)
             (struct.get $I32GrowableArray $i (local.get $g)))))

   (core-runtime-helper
    '$i32growable-array->array
    "$i32growable-array->array"
    (lambda ()
      `(func $i32growable-array->array (param $g (ref $I32GrowableArray)) (result (ref $I32Array))
             (local $count i32)
             (local.set $count (struct.get $I32GrowableArray $i (local.get $g)))
             (call $i32array-copy (struct.get $I32GrowableArray $arr (local.get $g)) (i32.const 0) (local.get $count)))))

   (core-runtime-helper
    '$i32array->growable-array
    "$i32array->growable-array"
    (lambda ()
      `(func $i32array->growable-array (param $a (ref $I32Array)) (result (ref $I32GrowableArray))
             (local $n i32)
             (local.set $n (array.len (local.get $a)))
             (struct.new $I32GrowableArray (local.get $a) (local.get $n) (local.get $n)))))))

;; growable-i32-array-core-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for I32GrowableArray helpers.
(define growable-i32-array-core-runtime-helper-names
  '($make-i32growable-array
    $i32growable-array-add!
    $i32growable-array-add-string!
    $i32growable-array-ref
    $i32growable-array-count
    $i32growable-array->array
    $i32array->growable-array))

;; growable-i32-array-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render I32GrowableArray core helpers in runtime assembly order.
(define (growable-i32-array-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list growable-i32-array-core-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define growable-i32-array-helper-index
    (make-core-runtime-helper-index growable-i32-array-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name growable-i32-array-core-runtime-helpers)
   growable-i32-array-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (growable-i32-array-core-runtime-helper-forms growable-i32-array-helper-index))
   growable-i32-array-core-runtime-helper-names))
