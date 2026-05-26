#lang racket/base

(require (for-syntax racket/base))

(provide yield
         generator
         generator-state
         in-generator
         infinite-generator
         sequence->generator
         sequence->repeated-generator
         generator?)

;; A Goal 1 shim for `racket/generator`.
;;
;; The original implementation depends on continuation prompts and composable
;; continuations. WebRacket does not support those yet, so this module keeps
;; provider graphs moving without pretending that generator semantics work.

(struct webracket-generator (state))

;; generator? : any/c -> boolean?
;;   Recognize WebRacket's no-op generator shim values.
(define (generator? v)
  (webracket-generator? v))

;; generator-state : generator? -> symbol?
;;   Return the shim state.
(define (generator-state gen)
  (unless (generator? gen)
    (raise-argument-error 'generator-state "generator?" gen))
  (webracket-generator-state gen))

;; yield : any/c ... -> void?
;;   Ignore yielded values in the no-op generator shim.
(define (yield . _vs)
  (void))

;; generator : syntax -> generator?
;;   Build a no-op generator instead of capturing continuations.
(define-syntax-rule (generator formals body ...)
  (webracket-generator 'done))

;; infinite-generator : syntax -> generator?
;;   Build a no-op infinite-generator shim.
(define-syntax-rule (infinite-generator body ...)
  (webracket-generator 'done))

;; in-generator : syntax -> sequence?
;;   Produce an empty sequence instead of running generator body.
(define-syntax (in-generator stx)
  #'null)

;; sequence->generator : sequence? -> generator?
;;   Return a no-op generator shim.
(define (sequence->generator _sequence)
  (webracket-generator 'done))

;; sequence->repeated-generator : sequence? -> generator?
;;   Return a no-op repeated-generator shim.
(define (sequence->repeated-generator _sequence)
  (webracket-generator 'done))
