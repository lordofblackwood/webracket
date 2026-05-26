#lang racket/base

(provide empty-stream
         in-stream
         stream
         stream->list
         stream-cons
         stream-empty?
         stream-first
         stream-rest
         stream?)

(require "promise.rkt")

;; A small finite-stream provider for Goal 1. It covers the common constructor
;; and selector surface without importing the full `racket/stream` library.

(struct webracket-empty-stream ())
(struct webracket-stream (first rest-promise))

(define empty-stream (webracket-empty-stream))

;; stream? : any/c -> boolean?
;;   Recognize staged WebRacket streams.
(define (stream? v)
  (or (webracket-empty-stream? v)
      (webracket-stream? v)))

;; stream-empty? : stream? -> boolean?
;;   Check whether st is empty.
(define (stream-empty? st)
  (cond
    [(webracket-empty-stream? st) #t]
    [(webracket-stream? st) #f]
    [else (raise-argument-error 'stream-empty? "stream?" st)]))

;; stream-cons : syntax -> stream?
;;   Lazily construct a stream pair.
(define-syntax-rule (stream-cons first rest)
  (webracket-stream first (delay rest)))

;; list->stream : list? -> stream?
;;   Build a finite stream from lst.
(define (list->stream lst)
  (cond
    [(null? lst) empty-stream]
    [else (webracket-stream (car lst) (delay (list->stream (cdr lst))))]))

;; stream : any/c ... -> stream?
;;   Build a finite stream from the given values.
(define (stream . values)
  (list->stream values))

;; stream-first : stream? -> any/c
;;   Return the first element of a non-empty stream.
(define (stream-first st)
  (cond
    [(webracket-stream? st) (webracket-stream-first st)]
    [(webracket-empty-stream? st) (error 'stream-first "expected a non-empty stream")]
    [else (raise-argument-error 'stream-first "stream?" st)]))

;; stream-rest : stream? -> stream?
;;   Return the rest of a non-empty stream.
(define (stream-rest st)
  (cond
    [(webracket-stream? st) (force (webracket-stream-rest-promise st))]
    [(webracket-empty-stream? st) (error 'stream-rest "expected a non-empty stream")]
    [else (raise-argument-error 'stream-rest "stream?" st)]))

;; stream->list : stream? -> list?
;;   Convert a finite staged stream to a list.
(define (stream->list st)
  (let loop ([st st] [acc '()])
    (cond
      [(stream-empty? st) (reverse acc)]
      [else (loop (stream-rest st) (cons (stream-first st) acc))])))

;; in-stream : stream? -> sequence?
;;   Expose a staged stream to `for` forms through its finite list view.
(define (in-stream st)
  (stream->list st))
