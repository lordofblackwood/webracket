#lang racket/base

(provide dict?
         dict-implements?
         dict-mutable?
         dict-can-remove-keys?
         dict-can-functional-set?
         dict-ref
         dict-ref!
         dict-set!
         dict-set
         dict-set*!
         dict-set*
         dict-remove!
         dict-remove
         dict-update!
         dict-update
         dict-map/copy
         dict-has-key?
         dict-empty?
         dict-count
         dict-copy
         dict-clear
         dict-clear!
         dict-iterate-first
         dict-iterate-next
         dict-iterate-key
         dict-iterate-value
         dict-map
         dict-for-each
         dict-keys
         dict-values
         dict->list
         in-dict
         in-dict-keys
         in-dict-values
         in-dict-pairs)

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

;; mutable-hash? : any/c -> boolean?
;;   Check for mutable hashes without depending on hash-specific predicates.
(define (mutable-hash? v)
  (and (hash? v) (not (immutable? v))))

;; mutable-vector? : any/c -> boolean?
;;   Check for mutable vectors without depending on vector-specific predicates.
(define (mutable-vector? v)
  (and (vector? v) (not (immutable? v))))

;; missing-key : symbol? any/c -> any
;;   Raise a compact missing-key error.
(define (missing-key who key)
  (error who "no value found for key: ~e" key))

;; dict-implements? : dict? symbol? ... -> boolean?
;;   Report support for the staged dictionary operations.
(define (dict-implements? dict . methods)
  (unless (dict? dict)
    (raise-argument-error 'dict-implements? "dict?" dict))
  (define (supported? method)
    (case method
      [(dict-ref dict-count dict-iterate-first dict-iterate-next
        dict-iterate-key dict-iterate-value)
       #t]
      [(dict-set!) (or (mutable-hash? dict) (mutable-vector? dict))]
      [(dict-set) (or (and (hash? dict) (immutable? dict)) (list? dict))]
      [(dict-remove!) (mutable-hash? dict)]
      [(dict-remove) (or (and (hash? dict) (immutable? dict)) (list? dict))]
      [(dict-clear!) (mutable-hash? dict)]
      [(dict-clear) (or (hash? dict) (list? dict))]
      [else #f]))
  (andmap supported? methods))

;; dict-mutable? : dict? -> boolean?
;;   Check whether the dictionary supports dict-set!.
(define (dict-mutable? dict)
  (dict-implements? dict 'dict-set!))

;; dict-can-remove-keys? : dict? -> boolean?
;;   Check whether the dictionary supports removing keys.
(define (dict-can-remove-keys? dict)
  (or (dict-implements? dict 'dict-remove!)
      (dict-implements? dict 'dict-remove)))

;; dict-can-functional-set? : dict? -> boolean?
;;   Check whether the dictionary supports functional updates.
(define (dict-can-functional-set? dict)
  (dict-implements? dict 'dict-set))

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
    [(mutable-hash? dict) (hash-set! dict key value)]
    [(mutable-vector? dict) (vector-set! dict key value)]
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
    [(and (hash? dict) (immutable? dict)) (hash-set dict key value)]
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

;; dict-set*! : mutable-dict? any/c any/c ... -> void?
;;   Mutably set key/value pairs from left to right.
(define (dict-set*! dict . kvs)
  (let loop ([kvs kvs])
    (cond
      [(null? kvs) (void)]
      [(null? (cdr kvs))
       (raise-argument-error 'dict-set*! "even number of key/value arguments" kvs)]
      [else
       (dict-set! dict (car kvs) (cadr kvs))
       (loop (cddr kvs))])))

;; dict-set* : immutable-dict? any/c any/c ... -> dict?
;;   Functionally set key/value pairs from left to right.
(define (dict-set* dict . kvs)
  (let loop ([dict dict] [kvs kvs])
    (cond
      [(null? kvs) dict]
      [(null? (cdr kvs))
       (raise-argument-error 'dict-set* "even number of key/value arguments" kvs)]
      [else (loop (dict-set dict (car kvs) (cadr kvs)) (cddr kvs))])))

;; dict-remove! : mutable-dict? any/c -> void?
;;   Mutably remove a key when the supported dictionary shape allows it.
(define (dict-remove! dict key)
  (cond
    [(mutable-hash? dict) (hash-remove! dict key)]
    [else (raise-argument-error 'dict-remove! "(and/c dict? (not/c immutable?))" dict)]))

;; dict-remove : immutable-dict? any/c -> dict?
;;   Functionally remove a key when the supported dictionary shape allows it.
(define (dict-remove dict key)
  (cond
    [(and (hash? dict) (immutable? dict)) (hash-remove dict key)]
    [(list? dict)
     (let loop ([entries dict])
       (cond
         [(null? entries) null]
         [(and (pair? (car entries))
               (equal? key (caar entries)))
          (cdr entries)]
         [else (cons (car entries) (loop (cdr entries)))]))]
    [else (raise-argument-error 'dict-remove "dict?" dict)]))

;; dict-ref! : mutable-dict? any/c any/c -> any/c
;;   Return an existing value or insert a fallback value/thunk result.
(define (dict-ref! dict key to-set)
  (cond
    [(dict-has-key? dict key) (dict-ref dict key)]
    [else
     (define value (if (procedure? to-set) (to-set) to-set))
     (dict-set! dict key value)
     value]))

;; dict-update! : mutable-dict? any/c procedure? [any/c] -> void?
;;   Mutably update a value using the optional dict-ref fallback.
(define dict-update!
  (case-lambda
    [(dict key updater)
     (dict-update! dict key updater (lambda () (missing-key 'dict-update! key)))]
    [(dict key updater failure-result)
     (unless (procedure? updater)
       (raise-argument-error 'dict-update! "procedure?" updater))
     (dict-set! dict key (updater (dict-ref dict key failure-result)))]))

;; dict-update : dict? any/c procedure? [any/c] -> dict?
;;   Functionally update a value using the optional dict-ref fallback.
(define dict-update
  (case-lambda
    [(dict key updater)
     (dict-update dict key updater (lambda () (missing-key 'dict-update key)))]
    [(dict key updater failure-result)
     (unless (procedure? updater)
       (raise-argument-error 'dict-update "procedure?" updater))
     (dict-set dict key (updater (dict-ref dict key failure-result)))]))

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

;; dict-empty? : dict? -> boolean?
;;   Report whether the dictionary has no mappings.
(define (dict-empty? dict)
  (not (dict-iterate-first dict)))

;; dict-copy : dict? -> dict?
;;   Copy supported mutable shapes; lists intentionally match racket/dict's gap.
(define (dict-copy dict)
  (cond
    [(hash? dict) (hash-copy dict)]
    [(vector? dict) (vector-copy* dict)]
    [else (raise-argument-error 'dict-copy "(or/c hash? vector?)" dict)]))

;; dict-clear : dict? -> dict?
;;   Functionally clear supported dictionary shapes.
(define (dict-clear dict)
  (cond
    [(hash? dict) (hash-clear dict)]
    [(list? dict) null]
    [else (raise-argument-error 'dict-clear "(or/c hash? list?)" dict)]))

;; dict-clear! : mutable-dict? -> void?
;;   Mutably clear supported dictionary shapes.
(define (dict-clear! dict)
  (cond
    [(mutable-hash? dict) (hash-clear! dict)]
    [else (raise-argument-error 'dict-clear! "(and/c dict? (not/c immutable?))" dict)]))

;; dict-iterate-first : dict? -> any/c
;;   Produce the first supported dictionary iteration position, or #f.
(define (dict-iterate-first dict)
  (cond
    [(hash? dict) (hash-iterate-first dict)]
    [(vector? dict) (and (positive? (vector-length dict)) 0)]
    [(list? dict) (and (pair? dict) dict)]
    [else (raise-argument-error 'dict-iterate-first "dict?" dict)]))

;; dict-iterate-next : dict? any/c -> any/c
;;   Advance a supported dictionary iteration position, or return #f.
(define (dict-iterate-next dict pos)
  (cond
    [(hash? dict) (hash-iterate-next dict pos)]
    [(vector? dict)
     (define next (+ pos 1))
     (and (< next (vector-length dict)) next)]
    [(list? dict)
     (define next (cdr pos))
     (and (pair? next) next)]
    [else (raise-argument-error 'dict-iterate-next "dict?" dict)]))

;; dict-iterate-key : dict? any/c -> any/c
;;   Return the key at a supported dictionary iteration position.
(define (dict-iterate-key dict pos)
  (cond
    [(hash? dict) (hash-iterate-key dict pos)]
    [(vector? dict) pos]
    [(list? dict) (caar pos)]
    [else (raise-argument-error 'dict-iterate-key "dict?" dict)]))

;; dict-iterate-value : dict? any/c -> any/c
;;   Return the value at a supported dictionary iteration position.
(define (dict-iterate-value dict pos)
  (cond
    [(hash? dict) (hash-iterate-value dict pos)]
    [(vector? dict) (vector-ref dict pos)]
    [(list? dict) (cdar pos)]
    [else (raise-argument-error 'dict-iterate-value "dict?" dict)]))

;; dict-map : dict? (any/c any/c -> any/c) -> list?
;;   Map a procedure over supported dictionary entries in iteration order.
(define (dict-map dict proc)
  (unless (procedure? proc)
    (raise-argument-error 'dict-map "procedure?" proc))
  (let loop ([pos (dict-iterate-first dict)])
    (cond
      [(not pos) null]
      [else
       (cons (proc (dict-iterate-key dict pos)
                   (dict-iterate-value dict pos))
             (loop (dict-iterate-next dict pos)))])))

;; dict-for-each : dict? (any/c any/c -> any/c) -> void?
;;   Apply a procedure to supported dictionary entries for effects.
(define (dict-for-each dict proc)
  (unless (procedure? proc)
    (raise-argument-error 'dict-for-each "procedure?" proc))
  (let loop ([pos (dict-iterate-first dict)])
    (cond
      [(not pos) (void)]
      [else
       (proc (dict-iterate-key dict pos)
             (dict-iterate-value dict pos))
       (loop (dict-iterate-next dict pos))])))

;; dict-map/copy : dict? (any/c any/c -> values any/c any/c) -> dict?
;;   Map entries into a cleared dictionary of the same supported kind.
(define (dict-map/copy dict proc)
  (unless (procedure? proc)
    (raise-argument-error 'dict-map/copy "procedure?" proc))
  (cond
    [(dict-can-functional-set? dict)
     (let loop ([out (dict-clear dict)] [pos (dict-iterate-first dict)])
       (cond
         [(not pos) out]
         [else
          (define-values (key value)
            (proc (dict-iterate-key dict pos)
                  (dict-iterate-value dict pos)))
          (loop (dict-set out key value)
                (dict-iterate-next dict pos))]))]
    [(dict-mutable? dict)
     (define out (dict-copy dict))
     (dict-clear! out)
     (dict-for-each dict
                    (lambda (key value)
                      (define-values (new-key new-value) (proc key value))
                      (dict-set! out new-key new-value)))
     out]
    [else (raise-argument-error 'dict-map/copy "dict with copyable update support" dict)]))

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

;; in-dict : dict? -> sequence?
;;   Return a pair sequence; full two-value sequence support is postponed.
(define (in-dict dict)
  (dict->list dict))

;; in-dict-keys : dict? -> sequence?
;;   Return a list sequence of dictionary keys.
(define (in-dict-keys dict)
  (dict-keys dict))

;; in-dict-values : dict? -> sequence?
;;   Return a list sequence of dictionary values.
(define (in-dict-values dict)
  (dict-values dict))

;; in-dict-pairs : dict? -> sequence?
;;   Return a list sequence of key-value pairs.
(define (in-dict-pairs dict)
  (dict->list dict))
