#lang racket/base

(require racket/list
         "../number-tower/cases.rkt"
         "generated/simple-cases.rkt"
         "model.rkt"
         "sources.rkt")

(provide number-port-sources
         number-port-cases
         number-port-skips
         number-port-groups
         select-number-port-cases
         select-number-port-skips
         number-port-cases->number-tower-cases
         (all-from-out "model.rkt"))

;; existing-number-tower-case->port-case : number-tower-case? -> number-port-case?
;;   Treat the existing handwritten oracle corpus as the first gated number port.
(define (existing-number-tower-case->port-case c)
  (define id
    (string->symbol
     (format "number-tower:~a" (number-tower-case-id c))))
  (number-port-case
   id
   'webracket-number-tower
   #f
   'handwritten-oracle
   (number-tower-case-group c)
   (number-tower-case-expr c)
   (number-tower-case-comparison c)
   (number-tower-case-gate? c)
   (string-append "Existing WebRacket number-tower oracle case. "
                  (number-tower-case-note c))))

;; number-port-cases : (listof number-port-case?)
;;   All number port cases. Generated upstream cases are recorded by default;
;;   handwritten oracle cases are the current gate set.
(define number-port-cases
  (append (map existing-number-tower-case->port-case number-tower-cases)
          generated-number-port-cases))

;; number-port-skips : (listof number-port-skip?)
;;   Upstream test-like forms that are accounted for but not yet executable ports.
(define number-port-skips
  generated-number-port-skips)

;; number-port-groups : -> (listof symbol?)
;;   Return all groups in stable display order.
(define (number-port-groups)
  (remove-duplicates (map number-port-case-group number-port-cases)))

;; select-number-port-cases :
;;   [#:sources (listof symbol?)] [#:groups (listof symbol?)] [#:ids (listof symbol?)]
;;   [#:include-non-gates? boolean?] -> (listof number-port-case?)
;;   Select number port cases for a runner invocation.
(define (select-number-port-cases #:sources [sources '()]
                                  #:groups [groups '()]
                                  #:ids [ids '()]
                                  #:include-non-gates? [include-non-gates? #f])
  (filter
   (lambda (c)
     (and (selected-by-symbols? number-port-case-source sources c)
          (selected-by-symbols? number-port-case-group groups c)
          (selected-by-symbols? number-port-case-id ids c)
          (or include-non-gates?
              (number-port-case-gate? c))))
   number-port-cases))

;; select-number-port-skips :
;;   [#:sources (listof symbol?)] -> (listof number-port-skip?)
;;   Select recorded upstream skips.
(define (select-number-port-skips #:sources [sources '()])
  (filter
   (lambda (s)
     (selected-by-symbols? number-port-skip-source sources s))
   number-port-skips))

;; number-port-cases->number-tower-cases :
;;   (listof number-port-case?) -> (listof number-tower-case?)
;;   Convert selected number port cases to the oracle runner case shape.
(define (number-port-cases->number-tower-cases cases)
  (map number-port-case->number-tower-case cases))
