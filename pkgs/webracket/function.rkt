#lang racket/base

(provide compose
         compose1
         conjoin
         const
         const*
         curry
         curryr
         disjoin
         identity
         negate
         thunk
         thunk*)

;; A small contract-free `racket/function` substitute for Goal 1 module
;; programs. It covers the pure combinators used by browser-friendly libraries.
;; Keyword-preserving arity metadata remains a later compatibility milestone.

;; identity : any/c -> any/c
;;   Return v unchanged.
(define (identity v)
  v)

;; const : any/c -> procedure?
;;   Return a procedure that ignores positional arguments and returns v.
(define ((const v) . _args)
  v)

;; const* : any/c ... -> procedure?
;;   Return a procedure that ignores positional arguments and returns vs.
(define ((const* . vs) . _args)
  (apply values vs))

;; compose-two : procedure? procedure? -> procedure?
;;   Compose f after g, preserving multiple values between them.
(define ((compose-two f g) . args)
  (call-with-values (lambda () (apply g args)) f))

;; compose : procedure? ... -> procedure?
;;   Compose procedures right-to-left; the zero-argument case is values.
(define (compose . procs)
  (let loop ([procs procs])
    (cond
      [(null? procs) values]
      [(null? (cdr procs)) (car procs)]
      [else (compose-two (car procs) (loop (cdr procs)))])))

;; compose1-two : procedure? procedure? -> procedure?
;;   Compose f after g for the common single-value path.
(define ((compose1-two f g) . args)
  (f (apply g args)))

;; compose1 : procedure? ... -> procedure?
;;   Compose procedures right-to-left with single-value intermediate results.
(define (compose1 . procs)
  (let loop ([procs procs])
    (cond
      [(null? procs) values]
      [(null? (cdr procs)) (car procs)]
      [else (compose1-two (car procs) (loop (cdr procs)))])))

;; negate : procedure? -> procedure?
;;   Return a procedure that negates proc's result with not.
(define ((negate proc) . args)
  (not (apply proc args)))

;; conjoin : procedure? ... -> procedure?
;;   Combine predicate results with and.
(define ((conjoin . procs) . args)
  (let loop ([procs procs])
    (cond
      [(null? procs) #t]
      [else (and (apply (car procs) args)
                 (loop (cdr procs)))])))

;; disjoin : procedure? ... -> procedure?
;;   Combine predicate results with or.
(define ((disjoin . procs) . args)
  (let loop ([procs procs])
    (cond
      [(null? procs) #f]
      [else (or (apply (car procs) args)
                (loop (cdr procs)))])))

;; enough-arguments? : procedure? list? -> boolean?
;;   Check whether proc can accept the accumulated positional arguments.
(define (enough-arguments? proc args)
  (procedure-arity-includes? proc (length args)))

;; curry* : procedure? list? boolean? -> procedure?
;;   Accumulate positional arguments until proc's arity accepts them.
(define (curry* proc args append-to-end?)
  (if (enough-arguments? proc args)
      (apply proc args)
      (lambda more
        (curry* proc
                (if append-to-end?
                    (append args more)
                    (append more args))
                append-to-end?))))

;; curry : procedure? any/c ... -> any
;;   Accumulate positional arguments from left to right.
(define (curry proc . args)
  (curry* proc args #t))

;; curryr : procedure? any/c ... -> any
;;   Accumulate positional arguments on the right.
(define (curryr proc . args)
  (curry* proc args #f))

;; thunk : syntax -> procedure?
;;   Create a nullary procedure.
(define-syntax-rule (thunk body ...)
  (lambda () body ...))

;; thunk* : syntax -> procedure?
;;   Create a procedure that ignores positional arguments.
(define-syntax-rule (thunk* body ...)
  (lambda _args body ...))
