#lang racket/base

;; The base expander names this private provider directly for the four list
;; traversals. Racket's provider exports private linklet names (`map2`, etc.)
;; and renames them to the public bindings. Keep the iterative helpers here:
;; importing `webracket/list` would make this provider depend on the public
;; list facade, which itself reaches back to this private provider.

;; reverse-list : list? -> list?
;;   Reverse xs without relying on the public list provider.
(define (reverse-list xs)
  (let loop ([remaining xs] [reversed null])
    (if (null? remaining)
        reversed
        (loop (cdr remaining) (cons (car remaining) reversed)))))

;; check-traversal-inputs : symbol? any/c list? -> void?
;;   Check a traversal procedure and each of its proper-list inputs.
(define (check-traversal-inputs who proc inputs)
  (unless (procedure? proc)
    (raise-argument-error who "procedure?" proc))
  (let loop ([remaining inputs])
    (cond
      [(null? remaining) (void)]
      [(list? (car remaining)) (loop (cdr remaining))]
      [else (raise-argument-error who "list?" (car remaining))])))

;; traversal-input-state : list? -> symbol?
;;   Classify equal-length traversal inputs without recursing through an input.
(define (traversal-input-state inputs)
  (let loop ([remaining inputs] [saw-empty? #f] [saw-pair? #f])
    (cond
      [(null? remaining)
       (cond
         [(and saw-empty? saw-pair?) 'mismatched]
         [saw-empty? 'finished]
         [else 'continue])]
      [(null? (car remaining))
       (loop (cdr remaining) #t saw-pair?)]
      [else (loop (cdr remaining) saw-empty? #t)])))

;; traversal-input-cars : list? -> list?
;;   Collect the current element from each non-empty input list.
(define (traversal-input-cars inputs)
  (let loop ([remaining inputs] [reversed null])
    (if (null? remaining)
        (reverse-list reversed)
        (loop (cdr remaining) (cons (caar remaining) reversed)))))

;; traversal-input-cdrs : list? -> list?
;;   Collect the remaining tail from each non-empty input list.
(define (traversal-input-cdrs inputs)
  (let loop ([remaining inputs] [reversed null])
    (if (null? remaining)
        (reverse-list reversed)
        (loop (cdr remaining) (cons (cdar remaining) reversed)))))

;; raise-traversal-length-error : symbol? list? -> none/c
;;   Report Racket's equal-length requirement for parallel list traversals.
(define (raise-traversal-length-error who inputs)
  (raise-arguments-error who "all lists must have the same size"
                         "lists" inputs))

;; map2 : procedure? list? ... -> list?
;;   Implement Racket's private map binding with a stack-safe traversal.
(define (map2 proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'map proc inputs)
  (let loop ([lists inputs] [reversed null])
    (define state (traversal-input-state lists))
    (cond
      [(eq? state 'finished) (reverse-list reversed)]
      [(eq? state 'mismatched)
       (raise-traversal-length-error 'map inputs)]
      [else
       (loop (traversal-input-cdrs lists)
             (cons (apply proc (traversal-input-cars lists)) reversed))])))

;; for-each2 : procedure? list? ... -> void?
;;   Implement Racket's private for-each binding with a stack-safe traversal.
(define (for-each2 proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'for-each proc inputs)
  (let loop ([lists inputs])
    (define state (traversal-input-state lists))
    (cond
      [(eq? state 'finished) (void)]
      [(eq? state 'mismatched)
       (raise-traversal-length-error 'for-each inputs)]
      [else
       (apply proc (traversal-input-cars lists))
       (loop (traversal-input-cdrs lists))])))

;; andmap2 : procedure? list? ... -> any/c
;;   Implement Racket's private andmap binding with a stack-safe traversal.
(define (andmap2 proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'andmap proc inputs)
  (let loop ([lists inputs] [last-value #t])
    (define state (traversal-input-state lists))
    (cond
      [(eq? state 'finished) last-value]
      [(eq? state 'mismatched)
       (raise-traversal-length-error 'andmap inputs)]
      [else
       (define value (apply proc (traversal-input-cars lists)))
       (if value
           (loop (traversal-input-cdrs lists) value)
           #f)])))

;; ormap2 : procedure? list? ... -> any/c
;;   Implement Racket's private ormap binding with a stack-safe traversal.
(define (ormap2 proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'ormap proc inputs)
  (let loop ([lists inputs])
    (define state (traversal-input-state lists))
    (cond
      [(eq? state 'finished) #f]
      [(eq? state 'mismatched)
       (raise-traversal-length-error 'ormap inputs)]
      [else
       (define value (apply proc (traversal-input-cars lists)))
       (if value
           value
           (loop (traversal-input-cdrs lists)))])))

(provide (rename-out [andmap2 andmap]
                     [for-each2 for-each]
                     [map2 map]
                     [ormap2 ormap]))
