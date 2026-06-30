#lang racket

(provide growable-bytes-core-runtime-helpers)

(require "../core-helper.rkt")

;; growable-bytes-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate GrowableBytes helpers that can be emitted in core runtime.
(define growable-bytes-core-runtime-helpers
  (list
   ;;;
   ;;; Growable Arrays of Bytes
   ;;;

   (core-runtime-helper
    '$make-growable-bytes
    "$make-growable-bytes"
    (lambda ()
      `(func $make-growable-bytes (param $capacity i32) (result (ref $GrowableBytes))
             (struct.new $GrowableBytes
                         (call $i8make-array (local.get $capacity) (i32.const 0))
                         (local.get $capacity)
                         (i32.const 0)))))

   (core-runtime-helper
    '$growable-bytes-add!
    "$growable-bytes-add!"
    (lambda ()
      `(func $growable-bytes-add! (param $g (ref $GrowableBytes)) (param $b i32)
             (local $i i32)
             (local $cap i32)
             (local $arr (ref $I8Array))

             (local.set $i   (struct.get $GrowableBytes $i   (local.get $g)))
             (local.set $cap (struct.get $GrowableBytes $cap (local.get $g)))
             (local.set $arr (struct.get $GrowableBytes $arr (local.get $g)))

             ;; Grow if necessary
             (if (i32.eq (local.get $i) (local.get $cap))
                 (then
                  (local.set $cap (i32.shl (local.get $cap) (i32.const 1))) ; double
                  (local.set $arr (call $i8array-extend (local.get $arr) (local.get $cap) (i32.const 0)))
                  (struct.set $GrowableBytes $arr (local.get $g) (local.get $arr))
                  (struct.set $GrowableBytes $cap (local.get $g) (local.get $cap))))

             ;; Set byte
             (array.set  $I8Array (local.get $arr) (local.get $i) (local.get $b))
             (struct.set $GrowableBytes $i (local.get $g) (i32.add (local.get $i) (i32.const 1))))))

   (core-runtime-helper
    '$growable-bytes->bytes
    "$growable-bytes->bytes"
    (lambda ()
      `(func $growable-bytes->bytes (param $g (ref $GrowableBytes)) (result (ref $Bytes))
             (local $src (ref $I8Array))
             (local $n   i32)
             (local $dst (ref $I8Array))

             ;; Extract fields
             (local.set $src (struct.get $GrowableBytes $arr (local.get $g)))
             (local.set $n   (struct.get $GrowableBytes $i   (local.get $g)))
             ;; Allocate new array of length $n
             (local.set $dst (array.new_default $I8Array (local.get $n)))
             ;; Copy from $src to $dst using array.copy
             (array.copy $I8Array $I8Array
                         (local.get $dst)  ;; dst array
                         (i32.const 0)     ;; dst offset
                         (local.get $src)  ;; src array
                         (i32.const 0)     ;; src offset
                         (local.get $n))   ;; length
             ;; Construct and return new Bytes struct
             (struct.new $Bytes
                         (i32.const 0)       ;; hash = 0
                         (local.get $n)      ;; length
                         (local.get $dst)))))))  ;; copied byte array
