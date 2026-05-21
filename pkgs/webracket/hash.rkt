#lang racket/base

(provide hash-union
         hash-union!
         hash-intersect
         hash-filter
         hash-filter-values
         hash-filter-keys)

;; A small contract-free `racket/hash` substitute for Goal 1 module programs.
;; It intentionally covers the ordinary immutable/mutable operations needed by
;; current smokes without pulling in `racket/contract/base`.

;; check-hash : symbol? any/c -> hash?
;;   Validate a hash-table argument.
(define (check-hash who value)
  (unless (hash? value)
    (raise-argument-error who "hash?" value))
  value)

;; check-immutable-hash : symbol? any/c -> hash?
;;   Validate an immutable hash-table argument.
(define (check-immutable-hash who value)
  (define ht (check-hash who value))
  (when (immutable? ht)
    ht)
  (unless (immutable? ht)
    (raise-argument-error who "(and/c hash? immutable?)" value))
  ht)

;; check-mutable-hash : symbol? any/c -> hash?
;;   Validate a mutable hash-table argument.
(define (check-mutable-hash who value)
  (define ht (check-hash who value))
  (when (immutable? ht)
    (raise-argument-error who "(and/c hash? (not/c immutable?))" value))
  ht)

;; hash-duplicate-error : symbol? -> procedure?
;;   Build the default duplicate-key merge failure.
(define ((hash-duplicate-error who) key value1 value2)
  (error who "duplicate values for key ~e: ~e and ~e" key value1 value2))

;; hash-for-each-entry : hash? procedure? -> void?
;;   Iterate over hash entries using fixed-shape primitives.
(define (hash-for-each-entry ht proc)
  (let loop ([pos (hash-iterate-first ht)])
    (cond
      [(not pos) (void)]
      [else
       (proc (hash-iterate-key ht pos)
             (hash-iterate-value ht pos))
       (loop (hash-iterate-next ht pos))])))

;; merge : hash? hash? procedure? -> hash?
;;   Merge `two` into immutable hash `one`.
(define (merge one two combine/key)
  (check-hash 'hash-union two)
  (let ([result one])
    (hash-for-each-entry
     two
     (lambda (key value)
       (set! result
             (hash-set result
                       key
                       (if (hash-has-key? result key)
                           (combine/key key (hash-ref result key) value)
                           value)))))
    result))

;; hash-union : hash? hash? ... -> hash?
;;   Combine immutable hash tables, with optional Racket-compatible keywords.
(define (hash-union #:combine [combine #f]
                    #:combine/key [combine/key
                                   (if combine
                                       (lambda (_key left right) (combine left right))
                                       (hash-duplicate-error 'hash-union))]
                    one
                    . rest)
  (define first (check-immutable-hash 'hash-union one))
  (let loop ([result first] [tables rest])
    (cond
      [(null? tables) result]
      [else (loop (merge result (car tables) combine/key)
                  (cdr tables))])))

;; hash-union! : hash? hash? ... -> void?
;;   Mutably combine hash tables, with optional Racket-compatible keywords.
(define (hash-union! #:combine [combine #f]
                     #:combine/key [combine/key
                                    (if combine
                                        (lambda (_key left right) (combine left right))
                                        (hash-duplicate-error 'hash-union!))]
                     one
                     . rest)
  (define target (check-mutable-hash 'hash-union! one))
  (let loop ([tables rest])
    (cond
      [(null? tables) (void)]
      [else
       (define source (check-hash 'hash-union! (car tables)))
       (hash-for-each-entry
        source
        (lambda (key value)
          (hash-set! target
                     key
                     (if (hash-has-key? target key)
                         (combine/key key (hash-ref target key) value)
                         value))))
       (loop (cdr tables))])))

;; in-all-hashes? : any/c (listof hash?) -> boolean?
;;   Check whether key appears in each hash.
(define (in-all-hashes? key tables)
  (let loop ([tables tables])
    (cond
      [(null? tables) #t]
      [(hash-has-key? (car tables) key) (loop (cdr tables))]
      [else #f])))

;; hash-intersect : hash? hash? ... -> hash?
;;   Intersect immutable hash tables, combining values for shared keys.
(define (hash-intersect #:combine [combine #f]
                        #:combine/key [combine/key
                                       (if combine
                                           (lambda (_key left right) (combine left right))
                                           (hash-duplicate-error 'hash-intersect))]
                        one
                        . rest)
  (define first (check-immutable-hash 'hash-intersect one))
  (let loop ([tables rest])
    (unless (null? tables)
      (check-hash 'hash-intersect (car tables))
      (loop (cdr tables))))
  (let ([result (hash-clear first)])
    (hash-for-each-entry
     first
     (lambda (key value)
       (when (in-all-hashes? key rest)
         (let combine-loop ([tables rest] [acc value])
           (cond
             [(null? tables)
              (set! result (hash-set result key acc))]
             [else
              (combine-loop (cdr tables)
                            (combine/key key acc (hash-ref (car tables) key)))])))))
    result))

;; hash-filter : hash? procedure? -> hash?
;;   Keep entries for which pred accepts key and value.
(define (hash-filter ht pred)
  (define source (check-hash 'hash-filter ht))
  (cond
    [(immutable? source)
     (let ([result (hash-clear source)])
       (hash-for-each-entry
        source
        (lambda (key value)
          (when (pred key value)
            (set! result (hash-set result key value)))))
       result)]
    [else
     (define result (hash-clear source))
     (hash-for-each-entry
      source
      (lambda (key value)
        (when (pred key value)
          (hash-set! result key value))))
     result]))

;; hash-filter-keys : hash? procedure? -> hash?
;;   Keep entries whose key satisfies pred.
(define (hash-filter-keys ht pred)
  (hash-filter ht (lambda (key _value) (pred key))))

;; hash-filter-values : hash? procedure? -> hash?
;;   Keep entries whose value satisfies pred.
(define (hash-filter-values ht pred)
  (hash-filter ht (lambda (_key value) (pred value))))
