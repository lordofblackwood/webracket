#lang racket

(provide i31-ref
         immediate-ref
         false-ref
         true-ref
         void-runtime-only-helper-names
         immediate-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/immediates.rkt")

;; i31-ref : integer? -> datum?
;;   Return WAT that injects bits into an i31 reference.
(define (i31-ref bits)
  `(ref.i31 (i32.const ,bits)))

;; immediate-ref : any/c -> datum?
;;   Return WAT that represents a WebRacket immediate value.
(define (immediate-ref v)
  (i31-ref (immediate-rep v)))

;; false-ref : datum?
;;   Return the WebRacket false immediate expression.
(define false-ref (immediate-ref #f))

;; true-ref : datum?
;;   Return the WebRacket true immediate expression.
(define true-ref (immediate-ref #t))

;; void-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for void helpers.
(define void-runtime-only-helper-names
  '($void?
    $void
    $make-void))

;; immediate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate immediate-value helpers used by the monolithic runtime.
(define immediate-runtime-only-helpers
  (function-forms->runtime-helpers
   'immediate-runtime-only-helpers
   '(
     (func $void? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $void))
               (then (global.get $true))
               (else (global.get $false))))

     (func $void (type $Prim>=0)
           (param $xs (ref eq))
           (result    (ref eq))

           (global.get $void))

     (func $make-void (type $Prim0) (result (ref eq)) ; no arguments
           (return (global.get $void))))))
