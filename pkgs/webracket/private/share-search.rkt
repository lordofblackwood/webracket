#lang racket/base

(provide share-find
         share-spec?)

;; share-spec? : any/c -> boolean?
;;   Recognize Racket runtime-path shared-data specifications.
(define (share-spec? p)
  (and (list? p)
       (= 2 (length p))
       (eq? 'share (car p))
       (string? (cadr p))))

;; share-find : any/c -> (or/c path? #f)
;;   WebRacket has no native shared-data directory search path.
(define (share-find _p)
  #f)
