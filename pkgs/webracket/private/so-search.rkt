#lang racket/base

(provide so-find
         so-spec?)

;; so-spec? : any/c -> boolean?
;;   Recognize Racket runtime-path shared-object specifications.
(define (so-spec? p)
  (and (list? p)
       (or (= 2 (length p))
           (= 3 (length p)))
       (eq? 'so (car p))
       (string? (cadr p))
       (or (= 2 (length p))
           (let ([s (caddr p)])
             (define (version? v)
               (or (not v) (string? v)))
             (or (version? s)
                 (and (list? s) (andmap version? s)))))))

;; so-find : any/c [any/c] [any/c] -> (or/c path? #f)
;;   WebRacket has no native shared-library search path.
(define (so-find _p [so-suffix #f] [lib-search-dirs #f])
  #f)
