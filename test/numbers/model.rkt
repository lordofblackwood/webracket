#lang racket/base

(require racket/list
         "../number-tower/cases.rkt")

(provide (struct-out number-port-source)
         (struct-out number-port-case)
         (struct-out number-port-skip)
         number-port-case->number-tower-case
         selected-by-symbols?)

(struct number-port-source
  (id path line-count note)
  #:transparent)

(struct number-port-case
  (id source line kind group expr comparison gate? note)
  #:transparent)

(struct number-port-skip
  (source line kind reason datum)
  #:transparent)

;; number-port-case->number-tower-case : number-port-case? -> number-tower-case?
;;   Convert a source-backed number port case to the oracle runner case shape.
(define (number-port-case->number-tower-case c)
  (number-tower-case
   (number-port-case-id c)
   (number-port-case-group c)
   (number-port-case-expr c)
   (number-port-case-comparison c)
   (number-port-case-gate? c)
   (number-port-case-note c)))

;; selected-by-symbols? : (any/c -> symbol?) (listof symbol?) any/c -> boolean?
;;   Check whether a symbol filter accepts v.
(define (selected-by-symbols? selector allowed v)
  (or (null? allowed)
      (memq (selector v) allowed)))
