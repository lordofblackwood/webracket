#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/temp))

(provide temp-x
         temp-set-x!)

;; temp-x : external? -> any/c
;;   Read the benchmark property directly.
(define (temp-x obj)
  (unsafe:js-temp-x obj))

;; temp-set-x! : external? any/c -> void?
;;   Set the benchmark property directly.
(define (temp-set-x! obj value)
  (unsafe:js-temp-set-x! obj value)
  (void))
