#lang racket/base

(require "../unsafe/temp.rkt")

(provide temp-x
         temp-set-x!)

;; temp-x : external? -> any/c
;;   Read the benchmark property directly.
(define (temp-x obj)
  (js-temp-x obj))

;; temp-set-x! : external? any/c -> void?
;;   Set the benchmark property directly.
(define (temp-set-x! obj value)
  (js-temp-set-x! obj value)
  (void))
