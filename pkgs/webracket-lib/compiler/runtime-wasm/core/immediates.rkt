#lang racket

(provide i31-ref
         immediate-ref
         false-ref
         true-ref
         singleton-global-names
         singleton-global-forms
         void-runtime-helper-forms
         eof-object-runtime-helper-forms
         immediate-core-runtime-helpers)

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

;; singleton-global-names : (listof symbol?)
;;   Name stable singleton globals that can also live in the core runtime.
(define singleton-global-names
  '($null
    $undefined
    $unsafe-undefined
    $void
    $false
    $true
    $eof
    $error
    $missing
    $tombstone))

;; singleton-global-forms : (listof datum?)
;;   Declare globals for singleton and internal immediate values.
(define singleton-global-forms
  `(
         ;;;
         ;;; Singletons
         ;;;

         (global $null              (ref eq) ,(immediate-ref '()))
         (global $undefined         (ref eq) ,(immediate-ref (undefined)))         ;  79
         (global $unsafe-undefined  (ref eq) ,(immediate-ref (unsafe-undefined)))  ; 335
         (global $void              (ref eq) ,(immediate-ref (void)))
         (global $false             (ref eq) ,false-ref)  ; (ref.i31 (i32.const ?))
         (global $true              (ref eq) ,true-ref)
         (global $eof               (ref eq) ,(immediate-ref eof))
         (global $error             (ref eq) ,(i31-ref 77))
         (global $missing           (ref eq) ,(i31-ref missing-value))   ; #x7fffffff
         (global $tombstone         (ref eq) ,(i31-ref tombstone-value)))) ; #x3fffffff"

;; void-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for void helpers.
(define void-runtime-only-helper-names
  '($void?
    $void
    $make-void))

;; eof-object-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for EOF object helpers.
(define eof-object-runtime-only-helper-names
  '($eof-object?))

;; immediate-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given immediate helper names from a helper index.
(define (immediate-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; void-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render void helpers in runtime assembly order.
(define (void-runtime-helper-forms helper-index)
  (immediate-helper-forms helper-index void-runtime-only-helper-names))

;; eof-object-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render EOF object helpers in runtime assembly order.
(define (eof-object-runtime-helper-forms helper-index)
  (immediate-helper-forms helper-index eof-object-runtime-only-helper-names))

;; eof-object-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate EOF object helpers available in the standalone core runtime.
(define eof-object-core-runtime-helpers
  (function-forms->runtime-helpers
   'eof-object-core-runtime-helpers
   `(
     (func $eof-object? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (if (result (ref eq))
               (ref.eq (local.get $v) ,(immediate-ref eof))
               (then ,true-ref)
               (else ,false-ref))))))

;; immediate-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate immediate-value helpers available in the standalone core runtime.
(define immediate-core-runtime-helpers
  (append
   eof-object-core-runtime-helpers
   (function-forms->runtime-helpers
    'immediate-core-runtime-helpers
    `(
      (func $void? (type $Prim1)
            (param $v (ref eq))
            (result   (ref eq))

            (if (result (ref eq))
                (ref.eq (local.get $v) ,(immediate-ref (void)))
                (then ,true-ref)
                (else ,false-ref)))

      (func $void (type $Prim>=0)
            (param $xs (ref eq))
            (result    (ref eq))

            ,(immediate-ref (void)))

      (func $make-void (type $Prim0) (result (ref eq)) ; no arguments
            (return ,(immediate-ref (void))))))))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define immediate-helper-index
    (make-core-runtime-helper-index immediate-core-runtime-helpers))

  (check-equal?
   (map form-name (void-runtime-helper-forms immediate-helper-index))
   void-runtime-only-helper-names)

  (check-equal?
   (map form-name (eof-object-runtime-helper-forms immediate-helper-index))
   eof-object-runtime-only-helper-names))
