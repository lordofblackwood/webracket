#lang racket

(provide boolean-runtime-string-constants
         boolean-runtime-only-helpers
         boolean-runtime-only-helper-names)

(require "../core-helper.rkt"
         "../../private/immediates.rkt")

;; boolean-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by boolean predicates and contract checks.
(define boolean-runtime-string-constants
  '((boolean? "boolean?")))

;; boolean-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for boolean helpers.
(define boolean-runtime-only-helper-names
  '($boolean?
    $boolean=?
    $false?
    $not
    $xor))

;; boolean-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate concrete boolean helpers.
(define boolean-runtime-only-helpers
  (function-forms->runtime-helpers
   'boolean-runtime-only-helpers
   `(
         ; todo: Benchmark the two implementations of $boolean? below

         (func $boolean? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.eq (local.get $v) (global.get $true))
                   (then (global.get $true))
                   (else (if (result (ref eq))
                             (ref.eq (local.get $v) (global.get $false))
                             (then (global.get $true))
                             (else (global.get $false))))))
         ; see comment above
         #;(func $boolean? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test i31ref (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (i32.and (i31.get_s (ref.cast i31ref (local.get $v)))
                                              (i32.const ,boolean-mask))
                                     (i32.const ,boolean-tag))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $boolean=? (type $Prim2)
               (param $x (ref eq)) (param $y (ref eq))
               (result (ref eq))

               ;; Type checks
               (if (ref.eq (call $boolean? (local.get $x)) (global.get $false))
                   (then (call $raise-argument-error/internal (local.get $x)) (unreachable)))
               (if (ref.eq (call $boolean? (local.get $y)) (global.get $false))
                   (then (call $raise-argument-error/internal (local.get $y)) (unreachable)))

               ;; Compare booleans
               (if (result (ref eq))
                   (ref.eq (local.get $x) (local.get $y))
                   (then (global.get $true))
                   (else (global.get $false))))

        (func $false? (type $Prim1) (param $v (ref eq)) (result (ref eq))
              (if (result (ref eq))
                  (ref.eq (local.get $v) (global.get $false))
                  (then (global.get $true))
                  (else (global.get $false))))

        (func $not (type $Prim1) (param $v (ref eq)) (result (ref eq))
              (if (result (ref eq))
                  (ref.eq (local.get $v) (global.get $false))
                  (then (global.get $true))
                   (else (global.get $false))))

        (func $xor (type $Prim2) (param $b1 (ref eq)) (param $b2 (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.eq (local.get $b1) (global.get $false))
                   (then (if (result (ref eq))
                             (ref.eq (local.get $b2) (global.get $false))
                             (then (global.get $false))
                             (else (local.get $b2))))
                   (else (if (result (ref eq))
                             (ref.eq (local.get $b2) (global.get $false))
                             (then (local.get $b1))
                             (else (global.get $false))))))


     )))
