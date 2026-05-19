#lang racket/base

(provide delay
         delay/strict
         force
         promise-forced?
         promise-running?
         promise?)

;; A compact promise provider for Goal 1. It implements ordinary single-value
;; delayed evaluation; exception caching and multiple-value caching are still
;; future work.

(struct webracket-promise (thunk value forced? running?) #:mutable)

;; delay : syntax -> promise?
;;   Delay body evaluation until the promise is forced.
(define-syntax-rule (delay body ...)
  (webracket-promise (lambda () (let () body ...)) #f #f #f))

;; delay/strict : syntax -> promise?
;;   Create an already-forced promise for body.
(define-syntax-rule (delay/strict body ...)
  (let ([v (let () body ...)])
    (webracket-promise (lambda () v) v #t #f)))

;; promise? : any/c -> boolean?
;;   Recognize staged WebRacket promises.
(define (promise? v)
  (webracket-promise? v))

;; promise-forced? : promise? -> boolean?
;;   Check whether p has been forced.
(define (promise-forced? p)
  (cond
    [(webracket-promise? p) (webracket-promise-forced? p)]
    [else (raise-argument-error 'promise-forced? "promise?" p)]))

;; promise-running? : promise? -> boolean?
;;   Check whether p is currently being forced.
(define (promise-running? p)
  (cond
    [(webracket-promise? p) (webracket-promise-running? p)]
    [else (raise-argument-error 'promise-running? "promise?" p)]))

;; force : any/c -> any/c
;;   Force p when it is a promise; otherwise return p unchanged.
(define (force p)
  (cond
    [(not (webracket-promise? p)) p]
    [(webracket-promise-forced? p) (webracket-promise-value p)]
    [(webracket-promise-running? p)
     (error 'force "promise is already running")]
    [else
     (set-webracket-promise-running?! p #t)
     (define v ((webracket-promise-thunk p)))
     (set-webracket-promise-value! p v)
     (set-webracket-promise-forced?! p #t)
     (set-webracket-promise-running?! p #f)
     v]))
