#lang racket

(provide checker-runtime-string-constants
         checker-runtime-symbol-constants
         checker-runtime-helper-forms
         checker-runtime-only-helpers
         checker-runtime-only-helper-names)

(require "../core-helper.rkt")

;; checker-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by match and sequence checker helpers.
(define checker-runtime-string-constants
  '((match-error:prefix ": no matching clause for ")))

;; checker-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by sequence and match checker helpers.
(define checker-runtime-symbol-constants
  '(in-list
    in-vector
    in-mlist
    in-range
    in-naturals
    in-string
    match))

;; checker-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for match and sequence checker helpers.
(define checker-runtime-only-helper-names
  '($match:error
    $check-list
    $check-vector
    $check-string
    $check-mlist
    $check-range
    $check-range-generic
    $check-naturals))

;; checker-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given checker helper names from a helper index.
(define (checker-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; checker-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render checker helpers in runtime assembly order.
(define (checker-runtime-helper-forms helper-index)
  (checker-helper-forms helper-index checker-runtime-only-helper-names))

;; checker-runtime-only-forms : (listof datum?)
;;   Enumerate match and sequence checker helpers used by the monolithic runtime.
(define checker-runtime-only-forms
  '(
         ;;;
         ;;; RUNTIME SUPPORT FOR MATCH
         ;;;

         (func $match:error (type $Prim3)
               (param $val       (ref eq))
               (param $srclocs   (ref eq))
               (param $form-name (ref eq))
               (result           (ref eq))

               (local $name-str (ref eq))
               (local $prefix   (ref eq))
               (local $val-str  (ref eq))

               (local.set $name-str
                          (block $done (result (ref eq))
                            (if (ref.eq (call $symbol? (local.get $form-name))
                                         (global.get $true))
                                (then (br $done (call $symbol->immutable-string
                                                       (local.get $form-name)))))
                            (if (ref.eq (local.get $form-name) (global.get $false))
                                (then (br $done (call $symbol->immutable-string
                                                       (global.get $symbol:match)))))
                            (if (ref.eq (call $string? (local.get $form-name))
                                         (global.get $true))
                                (then (br $done (local.get $form-name))))
                            (br $done (call $format/display (local.get $form-name)))))

               (local.set $prefix
                          (call $string-append/2
                                (local.get $name-str)
                                (global.get $string:match-error:prefix)))

               (local.set $val-str
                          (call $format/error-value->string
                                (local.get $val)))

               (call $raise
                     (call $exn:fail/make
                           (call $string-append/2 (local.get $prefix) (local.get $val-str))
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))

               (unreachable))

         ;;;
         ;;; Checkers
         ;;;

         (func $check-list (type $Prim12)
               (param $a (ref eq)) ;; list, or who when b is supplied
               (param $b (ref eq)) ;; optional list; defaults to $missing
               (result   (ref eq))
               (local $who (ref eq))
               (local $l   (ref eq))
               (local.set $who (local.get $a))
               (local.set $l   (local.get $a))
               (if (ref.eq (local.get $b) (global.get $missing))
                   (then
                    (local.set $who (global.get $symbol:in-list))
                    (local.set $l   (local.get $a)))
                   (else
                    (local.set $who (local.get $a))
                    (local.set $l   (local.get $b))))
               (if (result (ref eq))
                   (ref.eq (call $list? (local.get $l)) (global.get $true))
                   (then (global.get $void))
                   (else (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:list?)
                               (local.get $l))
                         (unreachable))))

         (func $check-vector (type $Prim1)
               (param $v (ref eq)) ;; vector
               (result   (ref eq))
               (if (result (ref eq))
                   (ref.eq (call $vector? (local.get $v)) (global.get $true))
                   (then (global.get $void))
                   (else (call $raise-argument-error1
                               (global.get $symbol:in-vector)
                               (global.get $string:vector?)
                               (local.get $v))
                         (unreachable))))


         (func $check-string (type $Prim1)
               (param $s (ref eq)) ;; string
               (result   (ref eq))
               (if (result (ref eq))
                   (ref.eq (call $string? (local.get $s)) (global.get $true))
                   (then (global.get $void))
                   (else (call $raise-argument-error1
                               (global.get $symbol:in-string)
                               (global.get $string:string?)
                               (local.get $s))
                         (unreachable))))

         ;; Racket's check-mlist accepts only mutable pairs or null.
         (func $check-mlist (type $Prim1)
               (param $l (ref eq))                 ;; mutable list
               (result (ref eq))
               (if (result (ref eq))
                   (ref.eq (local.get $l) (global.get $null))
                   (then (global.get $void))
                   (else (if (result (ref eq))
                             (ref.test (ref $MPair) (local.get $l))
                             (then (global.get $void))
                             (else (call $raise-argument-error1
                                         (global.get $symbol:in-mlist)
                                         (global.get $string:mpair-or-null)
                                         (local.get $l))
                                   (unreachable))))))

         (func $check-range (type $Prim3)
               (param $a (ref eq))     ;; start
               (param $b (ref eq))     ;; end
               (param $step (ref eq))  ;; step
               (result (ref eq))
               (call $check-range-generic (global.get $symbol:in-range)
                     (local.get $a)
                     (local.get $b)
                     (local.get $step)))

         (func $check-range-generic
               (param $who  (ref eq))  ;; symbol
               (param $a    (ref eq))  ;; start
               (param $b    (ref eq))  ;; end
               (param $step (ref eq))  ;; step
               (result (ref eq))
               (if (result (ref eq))
                   (ref.eq (call $real? (local.get $a)) (global.get $true))
                   (then (if (result (ref eq))
                             (ref.eq (call $real? (local.get $b)) (global.get $true))
                             (then (if (result (ref eq))
                                       (ref.eq (call $real? (local.get $step)) (global.get $true))
                                       (then (global.get $void))
                                       (else (call $raise-argument-error1
                                                   (local.get $who) (global.get $string:real?) (local.get $step))
                                             (unreachable))))
                             (else (call $raise-argument-error1
                                         (local.get $who) (global.get $string:real?) (local.get $b))
                                   (unreachable))))
                   (else (call $raise-argument-error1
                               (local.get $who) (global.get $string:real?) (local.get $a))
                         (unreachable))))

         (func $check-naturals (type $Prim1)
               (param $n (ref eq))   ;; n
               (result (ref eq))
               (if (result (ref eq))
                   (ref.eq (call $exact-nonnegative-integer? (local.get $n))
                           (global.get $true))
                   (then (global.get $void))
                   (else (call $raise-argument-error1
                               (global.get $symbol:in-naturals)
                               (global.get $string:exact-nonnegative-integer?)
                               (local.get $n))
                         (unreachable))))


    ))

(define checker-runtime-only-helpers
  (function-forms->runtime-helpers
   'checker-runtime-only-helpers
   checker-runtime-only-forms))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define checker-helper-index
    (make-core-runtime-helper-index checker-runtime-only-helpers))

  (check-equal?
   (map form-name (checker-runtime-helper-forms checker-helper-index))
   checker-runtime-only-helper-names))
