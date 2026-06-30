#lang racket

(provide list-core-runtime-helpers)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; list-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate list helpers that can be emitted in core runtime.
(define list-core-runtime-helpers
  (list
   ;; make-list/checked : i32 (ref eq) -> (ref eq)
   ;;   Build a proper list after the caller has validated the element count.
   (core-runtime-helper
    '$make-list/checked
    "$make-list/checked"
    (lambda ()
      `(func $make-list/checked
             (param $n i32)             ;; number of elements
             (param $v (ref eq))        ;; value to repeat
             (result (ref eq))          ;; proper list

             (local $i i32)
             (local $acc (ref eq))

             (local.set $i   (i32.const 0))
             (local.set $acc ,(Imm '()))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                          (local.set $acc
                                     (struct.new $Pair
                                                 (i32.const 0)
                                                 (local.get $v)
                                                 (local.get $acc)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $acc))))))
