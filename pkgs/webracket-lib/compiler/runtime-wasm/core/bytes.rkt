#lang racket

(provide bytes-core-runtime-helpers)

(require "../core-helper.rkt")

;; bytes-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate byte helpers that can be emitted in core runtime.
(define bytes-core-runtime-helpers
  (list
   (core-runtime-helper
    '$i8array->bytes
    "$i8array->bytes"
    (lambda ()
      `(func $i8array->bytes (param $arr (ref $I8Array)) (result (ref $Bytes))
             ;; Constructs a mutable $Bytes object (immutable = 0, hash = 0).
             (struct.new $Bytes
                         (i32.const 0)      ;; hash = 0
                         (i32.const 0)      ;; immutable = false
                         (local.get $arr))))) ;; the backing I8Array

   (core-runtime-helper
    '$i8array->immutable-bytes
    "$i8array->immutable-bytes"
    (lambda ()
      `(func $i8array->immutable-bytes (param $arr (ref $I8Array))
             (result (ref $Bytes))
             ;; Constructs an immutable $Bytes object (immutable = 1, hash = 0).
             (struct.new $Bytes
                         (i32.const 0)      ;; hash = 0
                         (i32.const 1)      ;; immutable = true
                         (local.get $arr))))))) ;; the backing I8Array
