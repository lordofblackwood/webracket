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

(require "promise.rkt"
         (only-in racket/private/for prop:sequence))

;; A small finite-stream provider for Goal 1. It covers the common constructor
;; and selector surface without importing the full `racket/stream` library.

(struct webracket-empty-stream ()
  #:property prop:sequence (lambda (_self) null))
(struct webracket-stream (first-promise rest-promise)
  #:property prop:sequence (lambda (self) (in-stream self)))

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
  (webracket-stream (delay first) (delay rest)))

;; stream : syntax -> stream?
;;   Build a finite stream lazily, like racket/stream.
(define-syntax stream
  (syntax-rules ()
    [(_) empty-stream]
    [(_ first rest ...) (stream-cons first (stream rest ...))]))

;; stream-first : stream? -> any/c
;;   Return the first element of a non-empty stream.
(define (stream-first st)
  (cond
    [(webracket-stream? st) (force (webracket-stream-first-promise st))]
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
