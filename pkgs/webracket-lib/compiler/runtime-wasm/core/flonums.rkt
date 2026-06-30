#lang racket

(provide flonum-core-runtime-helpers)

(require "../core-helper.rkt")

;; flonum-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate flonum helpers that can be emitted in core runtime.
(define flonum-core-runtime-helpers
  (list
   ;; fl?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a flonum, 0 otherwise.
   (core-runtime-helper
    '$fl?/i32
    "$fl?/i32"
    (lambda ()
      `(func $fl?/i32 (param $a (ref eq)) (result i32)
             (ref.test (ref $Flonum) (local.get $a)))))))
