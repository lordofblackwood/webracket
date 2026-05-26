#lang racket/base

(provide empty-stream
         in-stream
         stream
         stream->list
         stream-cons
         stream-empty?
         stream-first
         stream-length
         stream-ref
         stream-tail
         stream-take
         stream-append
         stream-map
         stream-filter
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

;; stream-length : stream? -> exact-nonnegative-integer?
;;   Count the elements in a finite staged stream.
(define (stream-length st)
  (unless (stream? st)
    (raise-argument-error 'stream-length "stream?" st))
  (let loop ([st st] [len 0])
    (cond
      [(stream-empty? st) len]
      [else (loop (stream-rest st) (add1 len))])))

;; stream-ref : stream? exact-nonnegative-integer? -> any/c
;;   Return the element at index n.
(define (stream-ref st n)
  (unless (stream? st)
    (raise-argument-error 'stream-ref "stream?" st))
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'stream-ref "exact-nonnegative-integer?" n))
  (let loop ([st st] [n n])
    (cond
      [(stream-empty? st)
       (raise-arguments-error 'stream-ref "index reaches past the end of the stream" "index" n)]
      [(zero? n) (stream-first st)]
      [else (loop (stream-rest st) (sub1 n))])))

;; stream-tail : stream? exact-nonnegative-integer? -> stream?
;;   Drop n elements from st.
(define (stream-tail st n)
  (unless (stream? st)
    (raise-argument-error 'stream-tail "stream?" st))
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'stream-tail "exact-nonnegative-integer?" n))
  (let loop ([st st] [n n])
    (cond
      [(zero? n) st]
      [(stream-empty? st)
       (raise-arguments-error 'stream-tail "index reaches past the end of the stream" "index" n)]
      [else (loop (stream-rest st) (sub1 n))])))

;; stream-take : stream? exact-nonnegative-integer? -> stream?
;;   Return a lazy prefix of n elements.
(define (stream-take st n)
  (unless (stream? st)
    (raise-argument-error 'stream-take "stream?" st))
  (unless (exact-nonnegative-integer? n)
    (raise-argument-error 'stream-take "exact-nonnegative-integer?" n))
  (cond
    [(zero? n) empty-stream]
    [(stream-empty? st)
     (raise-arguments-error 'stream-take "stream ended before index" "index" n)]
    [else (stream-cons (stream-first st)
                       (stream-take (stream-rest st) (sub1 n)))]))

;; stream-append : stream? ... -> stream?
;;   Append finite staged streams.
(define (stream-append . streams)
  (define (check-streams streams)
    (for ([st (in-list streams)])
      (unless (stream? st)
        (raise-argument-error 'stream-append "stream?" st))))
  (check-streams streams)
  (let append-loop ([streams streams])
    (cond
      [(null? streams) empty-stream]
      [(stream-empty? (car streams)) (append-loop (cdr streams))]
      [else
       (stream-cons (stream-first (car streams))
                    (append-loop (cons (stream-rest (car streams))
                                       (cdr streams))))])))

;; stream-map : procedure? stream? stream? ... -> stream?
;;   Map proc over one or more finite staged streams.
(define (stream-map proc st . streams)
  (unless (procedure? proc)
    (raise-argument-error 'stream-map "procedure?" proc))
  (define all-streams (cons st streams))
  (for ([st (in-list all-streams)])
    (unless (stream? st)
      (raise-argument-error 'stream-map "stream?" st)))
  (cond
    [(ormap stream-empty? all-streams) empty-stream]
    [else
     (stream-cons (apply proc (map stream-first all-streams))
                  (apply stream-map proc (map stream-rest all-streams)))]))

;; stream-filter : procedure? stream? -> stream?
;;   Keep elements of st for which pred returns true.
(define (stream-filter pred st)
  (unless (procedure? pred)
    (raise-argument-error 'stream-filter "procedure?" pred))
  (unless (stream? st)
    (raise-argument-error 'stream-filter "stream?" st))
  (let loop ([st st])
    (cond
      [(stream-empty? st) empty-stream]
      [(pred (stream-first st))
       (stream-cons (stream-first st) (loop (stream-rest st)))]
      [else (loop (stream-rest st))])))
