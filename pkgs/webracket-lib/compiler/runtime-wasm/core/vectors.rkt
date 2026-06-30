#lang racket

(provide vector-core-runtime-helpers)

(require "../core-helper.rkt")

;; vector-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate vector helpers that can be emitted in core runtime.
(define vector-core-runtime-helpers
  (list
   ;; vector?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a vector, 0 otherwise.
   (core-runtime-helper
    '$vector?/i32
    "$vector?/i32"
    (lambda ()
      `(func $vector?/i32 (param $a (ref eq)) (result i32)
             (ref.test (ref $Vector) (local.get $a)))))))
