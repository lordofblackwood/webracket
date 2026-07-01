#lang racket

(provide bytes-core-runtime-helpers
         bytes-mutability-runtime-only-helper-names
         bytes-runtime-only-helpers)

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

;; bytes-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for bytes mutability predicates.
(define bytes-mutability-runtime-only-helper-names
  '($mutable-bytes?
    $immutable-bytes?))

;; bytes-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate bytes helpers that still depend on monolithic runtime globals.
(define bytes-runtime-only-helpers
  (function-forms->runtime-helpers
   'bytes-runtime-only-helpers
   '(
         (func $mutable-bytes? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Bytes) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Bytes $immutable
                                                 (ref.cast (ref $Bytes) (local.get $v)))
                                     (i32.const 0))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $immutable-bytes? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Bytes) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Bytes $immutable
                                                 (ref.cast (ref $Bytes) (local.get $v)))
                                     (i32.const 1))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))


     )))
