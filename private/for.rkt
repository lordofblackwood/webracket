#lang racket/base

(provide make-do-sequence
         make-sequence
         prop:sequence
         sequence?
         check-in-hash
         check-in-hash-keys
         check-in-immutable-hash
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

;; check-in-immutable-hash : any/c -> void?
;;   Validate immutable hash sequences imported by installed providers.
(define (check-in-immutable-hash v)
  (unless (and (hash? v) (immutable? v))
    (raise-argument-error 'in-immutable-hash "(and/c hash? immutable?)" v)))

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
