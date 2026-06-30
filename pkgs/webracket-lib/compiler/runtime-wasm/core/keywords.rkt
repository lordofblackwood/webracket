#lang racket

(provide keyword-core-runtime-helpers)

(require "../core-helper.rkt")

;; keyword-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate keyword helpers that can be emitted in core runtime.
(define keyword-core-runtime-helpers
  (list
   ;; keyword?/i32 : (ref eq) -> i32
   ;;   Return 1 if the value is a keyword, 0 otherwise.
   (core-runtime-helper
    '$keyword?/i32
    "$keyword?/i32"
    (lambda ()
      `(func $keyword?/i32
             (param $v (ref eq))
             (result i32)
             (ref.test (ref $Keyword) (local.get $v)))))))
