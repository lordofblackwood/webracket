#lang racket/base

(provide delay
         delay/strict
         delay/sync
         delay/sync/proc
         force
         promise-forced?
         promise-running?
         promise?)

;; A compact promise provider for Goal 1. It caches ordinary values and
;; exceptions, but it does not yet implement the full family of lazy/name/sync
;; promise variants.

(struct webracket-promise (thunk result failed? forced? running?) #:mutable)

;; make-delayed-promise : (-> any) -> promise?
;;   Build a single-threaded WebRacket promise from a thunk.
(define (make-delayed-promise thunk)
  (webracket-promise thunk '() #f #f #f))

;; promise-result->values : (listof any/c) -> any
;;   Return cached promise results, preserving multiple values.
(define (promise-result->values results)
  (cond
    [(null? (cdr results)) (car results)]
    [else (apply values results)]))

;; delay : syntax -> promise?
;;   Delay body evaluation until the promise is forced.
(define-syntax-rule (delay body ...)
  (make-delayed-promise (lambda () (let () body ...))))

;; delay/strict : syntax -> promise?
;;   Create an already-forced promise for body.
(define-syntax-rule (delay/strict body ...)
  (call-with-values
   (lambda () (let () body ...))
   (lambda results
     (webracket-promise (lambda () (apply values results)) results #f #t #f))))

;; delay/sync/proc : (-> any) -> promise?
;;   Value-level form used by compiled racket/lazy-require. Racket's
;;   `delay/sync` is also a synchronizable event. WebRacket does not expose
;;   threads/events yet, so Goal 1 uses ordinary cached semantics.
(define (delay/sync/proc thunk)
  (make-delayed-promise thunk))

;; delay/sync : syntax -> promise?
;;   Source-level form for WebRacket code.
(define-syntax-rule (delay/sync body ...)
  ;; Racket's `delay/sync` is also a synchronizable event. WebRacket does not
  ;; expose threads/events yet, so Goal 1 uses the ordinary cached semantics.
  (delay body ...))

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
    [(and (webracket-promise-forced? p) (webracket-promise-failed? p))
     (raise (car (webracket-promise-result p)))]
    [(webracket-promise-forced? p)
     (promise-result->values (webracket-promise-result p))]
    [(webracket-promise-running? p)
     (error 'force "promise is already running")]
    [else
     (set-webracket-promise-running?! p #t)
     (define resume
       (call-with-escape-continuation
        (lambda (escape)
          (call-with-exception-handler
           (lambda (e)
             (set-webracket-promise-result! p (list e))
             (set-webracket-promise-failed?! p #t)
             (set-webracket-promise-forced?! p #t)
             (set-webracket-promise-running?! p #f)
             (escape (lambda () (raise e))))
           (lambda ()
             (call-with-values
              (webracket-promise-thunk p)
              (lambda results
                (set-webracket-promise-result! p results)
                (set-webracket-promise-forced?! p #t)
                (set-webracket-promise-running?! p #f)
                (lambda () (promise-result->values results)))))))))
     (resume)]))
