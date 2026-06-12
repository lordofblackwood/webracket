#lang racket/base

(provide current-webify-bridge-stats
         webify-bridge-stats-inc!
         webify-bridge-stats-set!
         webify-bridge-stats-ref)

;; current-webify-bridge-stats : (parameterof (or/c hash? #f))
;;   Optional mutable counter table for bridge-generation diagnostics.
(define current-webify-bridge-stats
  (make-parameter #f))

;; webify-bridge-stats-inc! : symbol? [real?] -> void?
;;   Increment one bridge-generation counter when diagnostics are active.
(define (webify-bridge-stats-inc! key [delta 1])
  (define stats (current-webify-bridge-stats))
  (when stats
    (hash-update! stats key (lambda (n) (+ n delta)) 0)))

;; webify-bridge-stats-set! : any/c any/c -> void?
;;   Record one bridge-generation datum when diagnostics are active.
(define (webify-bridge-stats-set! key value)
  (define stats (current-webify-bridge-stats))
  (when stats
    (hash-set! stats key value)))

;; webify-bridge-stats-ref : symbol? [any/c] -> any/c
;;   Read one bridge-generation counter with a default when inactive.
(define (webify-bridge-stats-ref key [default 0])
  (define stats (current-webify-bridge-stats))
  (if stats
      (hash-ref stats key default)
      default))
