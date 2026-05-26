#lang racket/base

(provide make-do-sequence
         make-sequence
         prop:sequence
         sequence?
         sequence-generate
         sequence-generate*
         in-bytes
         in-hash
         in-hash-keys
         in-hash-values
         in-hash-pairs
         in-immutable-hash
         in-immutable-hash-keys
         in-immutable-hash-values
         in-immutable-hash-pairs
         in-mutable-hash
         in-mutable-hash-keys
         in-mutable-hash-values
         in-mutable-hash-pairs
         in-indexed
         in-producer
         in-value
         check-in-hash
         check-in-hash-keys
         check-in-hash-values
         check-in-hash-pairs
         check-in-immutable-hash
         check-bytes
         check-list)

;; A small WebRacket-owned subset of `racket/private/for`.
;;
;; The full Racket provider contains many sequence forms and stream helpers.
;; Goal 1 currently needs the generic protocol pieces that expanded `for` forms
;; import and the six-value `make-do-sequence` shape used by modules such as
;; `data/queue`.

(define-values (prop:sequence sequence-via-prop? sequence-ref)
  (make-struct-type-property 'sequence))

(struct do-sequence (thunk))

;; make-do-sequence : (-> values) -> sequence?
;;   Wrap a sequence initiation thunk.
(define (make-do-sequence thunk)
  (unless (procedure? thunk)
    (raise-argument-error 'make-do-sequence "procedure?" thunk))
  (do-sequence thunk))

;; sequence? : any/c -> boolean?
;;   Recognize the sequence shapes covered by this staged provider.
(define (sequence? v)
  (or (exact-nonnegative-integer? v)
      (list? v)
      (vector? v)
      (string? v)
      (bytes? v)
      (hash? v)
      (do-sequence? v)
      (and (sequence-via-prop? v) #t)))

;; check-list : any/c -> void?
;;   Validate list sequences imported by expanded installed providers.
(define (check-list v)
  (unless (list? v)
    (raise-argument-error 'in-list "list?" v)))

;; check-in-hash : any/c -> void?
;;   Validate generic hash sequences imported by installed providers.
(define (check-in-hash v)
  (unless (hash? v)
    (raise-argument-error 'in-hash "hash?" v)))

;; check-in-hash-keys : any/c -> void?
;;   Validate generic hash-key sequences imported by installed providers.
(define (check-in-hash-keys v)
  (unless (hash? v)
    (raise-argument-error 'in-hash-keys "hash?" v)))

;; check-in-hash-values : any/c -> void?
;;   Validate generic hash-value sequences imported by installed providers.
(define (check-in-hash-values v)
  (unless (hash? v)
    (raise-argument-error 'in-hash-values "hash?" v)))

;; check-in-hash-pairs : any/c -> void?
;;   Validate generic hash-pair sequences imported by installed providers.
(define (check-in-hash-pairs v)
  (unless (hash? v)
    (raise-argument-error 'in-hash-pairs "hash?" v)))

;; check-in-immutable-hash : any/c -> void?
;;   Validate immutable hash sequences imported by installed providers.
(define (check-in-immutable-hash v)
  (unless (and (hash? v) (immutable? v))
    (raise-argument-error 'in-immutable-hash "(and/c hash? immutable?)" v)))

;; check-bytes : any/c -> void?
;;   Validate byte-string sequences imported by expanded code.
(define (check-bytes v)
  (unless (bytes? v)
    (raise-argument-error 'in-bytes "bytes?" v)))

;; byte-stop : bytes? (or/c exact-integer? #f) -> exact-integer?
;;   Resolve #f stop to the byte string length.
(define (byte-stop bstr stop)
  (if stop stop (bytes-length bstr)))

;; check-in-bytes : bytes? exact-nonnegative-integer? (or/c exact-integer? #f) exact-integer? -> void?
;;   Validate in-bytes arguments.
(define (check-in-bytes bstr start stop step)
  (unless (bytes? bstr)
    (raise-argument-error 'in-bytes "bytes?" bstr))
  (unless (exact-nonnegative-integer? start)
    (raise-argument-error 'in-bytes "exact-nonnegative-integer?" start))
  (unless (or (not stop) (exact-integer? stop))
    (raise-argument-error 'in-bytes "(or/c exact-integer? #f)" stop))
  (unless (and (exact-integer? step) (not (zero? step)))
    (raise-argument-error 'in-bytes "(and/c exact-integer? (not/c zero?))" step)))

;; in-bytes : bytes? [exact-nonnegative-integer?] [(or/c exact-integer? #f)] [nonzero-exact-integer?] -> sequence?
;;   Return a byte sequence. Optional start defaults to 0, stop to length, step to 1.
(define (in-bytes bstr [start 0] [stop #f] [step 1])
  (check-in-bytes bstr start stop step)
  (define end (byte-stop bstr stop))
  (let loop ([i start])
    (cond
      [(if (positive? step) (< i end) (> i end))
       (cons (bytes-ref bstr i) (loop (+ i step)))]
      [else null])))

;; maybe-bad-index : any/c -> any/c
;;   Placeholder for Racket's weak/concurrent hash bad-index value.
(define (maybe-bad-index v)
  v)

;; in-hash : hash? [any/c] -> sequence?
;;   Return a two-value hash sequence. The optional bad-index value is accepted but ignored.
(define (in-hash ht [bad-index-v (maybe-bad-index #f)])
  (check-in-hash ht)
  ht)

;; in-hash-keys : hash? [any/c] -> sequence?
;;   Return a sequence of hash keys. The optional bad-index value is accepted but ignored.
(define (in-hash-keys ht [bad-index-v (maybe-bad-index #f)])
  (check-in-hash-keys ht)
  (hash-keys ht))

;; in-hash-values : hash? [any/c] -> sequence?
;;   Return a sequence of hash values. The optional bad-index value is accepted but ignored.
(define (in-hash-values ht [bad-index-v (maybe-bad-index #f)])
  (check-in-hash ht)
  (hash-values ht))

;; in-hash-pairs : hash? [any/c] -> sequence?
;;   Return a sequence of key-value pairs. The optional bad-index value is accepted but ignored.
(define (in-hash-pairs ht [bad-index-v (maybe-bad-index #f)])
  (check-in-hash ht)
  (map (lambda (key) (cons key (hash-ref ht key))) (hash-keys ht)))

;; check-mutable-hash : symbol? any/c -> void?
;;   Validate mutable hash variants.
(define (check-mutable-hash who ht)
  (unless (and (hash? ht) (not (immutable? ht)))
    (raise-argument-error who "(and/c hash? (not/c immutable?))" ht)))

;; in-immutable-hash : immutable-hash? [any/c] -> sequence?
;;   Return a two-value immutable-hash sequence.
(define (in-immutable-hash ht [bad-index-v (maybe-bad-index #f)])
  (check-in-immutable-hash ht)
  (in-hash ht bad-index-v))

;; in-immutable-hash-keys : immutable-hash? [any/c] -> sequence?
;;   Return immutable-hash keys.
(define (in-immutable-hash-keys ht [bad-index-v (maybe-bad-index #f)])
  (check-in-immutable-hash ht)
  (in-hash-keys ht bad-index-v))

;; in-immutable-hash-values : immutable-hash? [any/c] -> sequence?
;;   Return immutable-hash values.
(define (in-immutable-hash-values ht [bad-index-v (maybe-bad-index #f)])
  (check-in-immutable-hash ht)
  (in-hash-values ht bad-index-v))

;; in-immutable-hash-pairs : immutable-hash? [any/c] -> sequence?
;;   Return immutable-hash key-value pairs.
(define (in-immutable-hash-pairs ht [bad-index-v (maybe-bad-index #f)])
  (check-in-immutable-hash ht)
  (in-hash-pairs ht bad-index-v))

;; in-mutable-hash : mutable-hash? [any/c] -> sequence?
;;   Return a two-value mutable-hash sequence.
(define (in-mutable-hash ht [bad-index-v (maybe-bad-index #f)])
  (check-mutable-hash 'in-mutable-hash ht)
  (in-hash ht bad-index-v))

;; in-mutable-hash-keys : mutable-hash? [any/c] -> sequence?
;;   Return mutable-hash keys.
(define (in-mutable-hash-keys ht [bad-index-v (maybe-bad-index #f)])
  (check-mutable-hash 'in-mutable-hash-keys ht)
  (in-hash-keys ht bad-index-v))

;; in-mutable-hash-values : mutable-hash? [any/c] -> sequence?
;;   Return mutable-hash values.
(define (in-mutable-hash-values ht [bad-index-v (maybe-bad-index #f)])
  (check-mutable-hash 'in-mutable-hash-values ht)
  (in-hash-values ht bad-index-v))

;; in-mutable-hash-pairs : mutable-hash? [any/c] -> sequence?
;;   Return mutable-hash key-value pairs.
(define (in-mutable-hash-pairs ht [bad-index-v (maybe-bad-index #f)])
  (check-mutable-hash 'in-mutable-hash-pairs ht)
  (in-hash-pairs ht bad-index-v))

;; thunk->make-sequence-values : symbol? (-> values) -> values
;;   Normalize a make-do-sequence thunk to the seven-value protocol.
(define (thunk->make-sequence-values who thunk)
  (define vals (call-with-values thunk list))
  (case (length vals)
    [(6)
     (apply values
            (list (list-ref vals 0)
                  #f
                  (list-ref vals 1)
                  (list-ref vals 2)
                  (list-ref vals 3)
                  (list-ref vals 4)
                  (list-ref vals 5)))]
    [(7) (apply values vals)]
    [else
     (raise-arguments-error who
                            "sequence initiation thunk returned the wrong number of values"
                            "expected" "6 or 7"
                            "received" (length vals))]))

;; make-sequence : symbol? any/c -> values
;;   Initiate a supported sequence for expanded `for` forms.
(define (make-sequence who v)
  (cond
    [(exact-nonnegative-integer? v)
     (values (lambda (pos) pos)
             #f
             add1
             0
             (lambda (pos) (< pos v))
             #f
             #f)]
    [(list? v)
     (values car
             #f
             cdr
             v
             pair?
             #f
             #f)]
    [(vector? v)
     (values (lambda (pos) (vector-ref v pos))
             #f
             add1
             0
             (lambda (pos) (< pos (vector-length v)))
             #f
             #f)]
    [(string? v)
     (values (lambda (pos) (string-ref v pos))
             #f
             add1
             0
             (lambda (pos) (< pos (string-length v)))
             #f
             #f)]
    [(bytes? v)
     (values (lambda (pos) (bytes-ref v pos))
             #f
             add1
             0
             (lambda (pos) (< pos (bytes-length v)))
             #f
             #f)]
    [(hash? v)
     (values (lambda (pos) (hash-iterate-key+value v pos #f))
             #f
             (lambda (pos) (hash-iterate-next v pos))
             (hash-iterate-first v)
             values
             #f
             #f)]
    [(do-sequence? v)
     (thunk->make-sequence-values who (do-sequence-thunk v))]
    [(sequence-via-prop? v)
     (make-sequence who ((sequence-ref v) v))]
    [else
     (raise-argument-error who "sequence?" v)]))

;; sequence-position-active? : any/c (any/c -> any/c) (or/c #f procedure?) -> boolean?
;;   Check whether a sequence position should produce another element.
(define (sequence-position-active? pos pos-cont? all-cont?)
  (and (pos-cont? pos)
       (if all-cont? (all-cont? pos) #t)))

;; sequence-position-values : procedure? any/c (or/c #f procedure?) -> list?
;;   Extract one element's values as a list, respecting val-cont? when supplied.
(define (sequence-position-values pos->vals pos val-cont?)
  (define vals (call-with-values (lambda () (pos->vals pos)) list))
  (cond
    [(and val-cont? (not (apply val-cont? vals))) #f]
    [else vals]))

;; sequence-next-position : any/c (or/c #f procedure?) procedure? -> any/c
;;   Advance a sequence position.
(define (sequence-next-position pos pre-pos-next pos-next)
  (when pre-pos-next (pre-pos-next pos))
  (pos-next pos))

;; sequence-generate : sequence? -> (values (-> boolean?) (-> any))
;;   Return stateful thunks that test for and produce the next sequence element.
(define (sequence-generate seq)
  (unless (sequence? seq)
    (raise-argument-error 'sequence-generate "sequence?" seq))
  (define-values (pos->vals pre-pos-next pos-next init pos-cont? val-cont? all-cont?)
    (make-sequence 'sequence-generate seq))
  (define pos init)
  (define cached? #f)
  (define cached-values #f)
  (define exhausted? #f)
  (define (fill-cache!)
    (unless cached?
      (let loop ()
        (cond
          [(not (sequence-position-active? pos pos-cont? all-cont?))
           (set! exhausted? #t)
           (set! cached-values #f)
           (set! cached? #t)]
          [else
           (define vals (sequence-position-values pos->vals pos val-cont?))
           (define next-pos (sequence-next-position pos pre-pos-next pos-next))
           (set! pos next-pos)
           (cond
             [vals
              (set! cached-values vals)
              (set! cached? #t)]
             [else (loop)])]))))
  (define (more?)
    (fill-cache!)
    (not exhausted?))
  (define (next)
    (fill-cache!)
    (cond
      [exhausted?
       (raise-arguments-error 'sequence-generate "sequence is exhausted")]
      [else
       (define vals cached-values)
       (set! cached? #f)
       (apply values vals)]))
  (values more? next))

;; sequence-generate* : sequence? -> (values (or/c list? #f) (-> values))
;;   Return the first element values and a thunk for the rest of the sequence.
(define (sequence-generate* seq)
  (define-values (more? next) (sequence-generate seq))
  (define first-values (and (more?) (call-with-values next list)))
  (values first-values
          (lambda ()
            (sequence-generate* (make-do-sequence
                                 (lambda ()
                                   (define-values (more?/rest next/rest)
                                     (values more? next))
                                   (values (lambda (_pos)
                                             (apply values
                                                    (call-with-values next/rest list)))
                                           (lambda (_pos) _pos)
                                           #t
                                           (lambda (_pos) (more?/rest))
                                           #f
                                           #f)))))))

;; in-indexed : sequence? -> sequence?
;;   Return a two-value sequence of element and index.
(define (in-indexed seq)
  (unless (sequence? seq)
    (raise-argument-error 'in-indexed "sequence?" seq))
  (make-do-sequence
   (lambda ()
     (define-values (more? next) (sequence-generate seq))
     (values (lambda (pos)
               (values (car pos) (cdr pos)))
             (lambda (pos)
               (and (more?) (cons (next) (+ (cdr pos) 1))))
             (and (more?) (cons (next) 0))
             values
             (lambda (value index) #t)
             (lambda (pos value index) #t)))))

;; stop-value? : any/c any/c -> boolean?
;;   Decide whether an in-producer value stops the sequence.
(define (stop-value? stop value)
  (cond
    [(not stop) #f]
    [(procedure? stop) (stop value)]
    [else (eq? stop value)]))

;; in-producer : procedure? [any/c any/c ...] -> sequence?
;;   Return a sequence that repeatedly calls producer; stop defaults to no stop.
(define (in-producer producer [stop #f] . args)
  (unless (procedure? producer)
    (raise-argument-error 'in-producer "procedure?" producer))
  (make-do-sequence
   (lambda ()
     (define (produce) (apply producer args))
     (values values
             (lambda (_pos) (produce))
             (produce)
             (lambda (pos) (not (stop-value? stop pos)))
             #f
             #f))))

;; in-value : any/c -> sequence?
;;   Return a one-element sequence.
(define (in-value v)
  (list v))
