#lang racket/base

(provide dict?
         dict-ref
         dict-set!
         dict-set
         dict-has-key?
         dict-count
         dict-keys
         dict-values
         dict->list)

;; A small contract-free `racket/dict` substitute for Goal 1 module programs.
;; It covers hash tables, vectors, and association lists, which are the common
;; dictionary shapes used by the current browser-friendly module surface.

;; assq* : any/c list? -> (or/c pair? #f)
;;   Find a key in an association list using equal?.
(define (assq* key entries)
  (cond
    [(null? entries) #f]
    [(and (pair? (car entries))
          (equal? key (caar entries)))
     (car entries)]
    [else (assq* key (cdr entries))]))

;; dict? : any/c -> boolean?
;;   Recognize the supported WebRacket dictionary shapes.
(define (dict? v)
  (or (hash? v)
      (vector? v)
      (and (list? v)
           (let loop ([entries v])
             (cond
               [(null? entries) #t]
               [(pair? (car entries)) (loop (cdr entries))]
               [else #f])))))

;; missing-key : symbol? any/c -> any
;;   Raise a compact missing-key error.
(define (missing-key who key)
  (error who "no value found for key: ~e" key))

;; dict-ref : dict? any/c [any/c] -> any/c
;;   Look up key, using a value or thunk fallback when supplied.
(define dict-ref
  (case-lambda
    [(dict key) (dict-ref dict key (lambda () (missing-key 'dict-ref key)))]
    [(dict key failure-result)
     (cond
       [(hash? dict)
        (hash-ref dict key failure-result)]
       [(vector? dict)
        (if (and (exact-integer? key)
                 (<= 0 key)
                 (< key (vector-length dict)))
            (vector-ref dict key)
            (if (procedure? failure-result)
                (failure-result)
                failure-result))]
       [(list? dict)
        (cond
          [(assq* key dict) => cdr]
          [(procedure? failure-result) (failure-result)]
          [else failure-result])]
       [else
        (raise-argument-error 'dict-ref "dict?" dict)])]))

;; dict-set! : mutable-dict? any/c any/c -> void?
;;   Mutably set a hash-table or vector entry.
(define (dict-set! dict key value)
  (cond
    [(hash? dict) (hash-set! dict key value)]
    [(vector? dict) (vector-set! dict key value)]
    [else (raise-argument-error 'dict-set! "(and/c dict? (not/c immutable?))" dict)]))

;; vector-copy* : vector? -> vector?
;;   Copy a vector without depending on `racket/vector`.
(define (vector-copy* vec)
  (let ([copy (make-vector (vector-length vec))])
    (let loop ([i 0])
      (cond
        [(= i (vector-length vec)) copy]
        [else
         (vector-set! copy i (vector-ref vec i))
         (loop (+ i 1))]))))

;; dict-set : immutable-dict? any/c any/c -> dict?
;;   Functionally set a hash-table, vector, or association-list entry.
(define (dict-set dict key value)
  (cond
    [(hash? dict) (hash-set dict key value)]
    [(vector? dict)
     (define copy (vector-copy* dict))
     (vector-set! copy key value)
     copy]
    [(list? dict)
     (let loop ([entries dict] [changed? #f])
       (cond
         [(null? entries)
          (if changed? null (list (cons key value)))]
         [(and (pair? (car entries))
               (equal? key (caar entries)))
          (cons (cons key value) (cdr entries))]
         [else
          (cons (car entries)
                (loop (cdr entries) changed?))]))]
    [else (raise-argument-error 'dict-set "dict?" dict)]))

;; dict-has-key? : dict? any/c -> boolean?
;;   Check whether key is present.
(define (dict-has-key? dict key)
  (cond
    [(hash? dict) (hash-has-key? dict key)]
    [(vector? dict)
     (and (exact-integer? key) (<= 0 key) (< key (vector-length dict)))]
    [(list? dict) (and (assq* key dict) #t)]
    [else (raise-argument-error 'dict-has-key? "dict?" dict)]))

;; dict-count : dict? -> exact-nonnegative-integer?
;;   Count entries in the supported dictionary shapes.
(define (dict-count dict)
  (cond
    [(hash? dict) (hash-count dict)]
    [(vector? dict) (vector-length dict)]
    [(list? dict) (length dict)]
    [else (raise-argument-error 'dict-count "dict?" dict)]))

;; dict-keys : dict? -> list?
;;   Return dictionary keys in unspecified order.
(define (dict-keys dict)
  (cond
    [(hash? dict) (hash-keys dict)]
    [(vector? dict)
     (let loop ([i 0])
       (if (= i (vector-length dict))
           null
           (cons i (loop (+ i 1)))))]
    [(list? dict) (map car dict)]
    [else (raise-argument-error 'dict-keys "dict?" dict)]))

;; dict-values : dict? -> list?
;;   Return dictionary values in unspecified order.
(define (dict-values dict)
  (cond
    [(hash? dict) (hash-values dict)]
    [(vector? dict) (vector->list dict)]
    [(list? dict) (map cdr dict)]
    [else (raise-argument-error 'dict-values "dict?" dict)]))

;; dict->list : dict? -> list?
;;   Return dictionary entries as key-value pairs.
(define (dict->list dict)
  (cond
    [(hash? dict)
     (map (lambda (key) (cons key (hash-ref dict key))) (hash-keys dict))]
    [(vector? dict)
     (let loop ([i 0])
       (if (= i (vector-length dict))
           null
           (cons (cons i (vector-ref dict i))
                 (loop (+ i 1)))))]
    [(list? dict) dict]
    [else (raise-argument-error 'dict->list "dict?" dict)]))
