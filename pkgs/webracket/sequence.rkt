#lang racket/base

(require racket/private/for)
(require (for-syntax racket/base))

(provide empty-sequence
         sequence->list
         sequence-length
         sequence-ref
         sequence-tail
         sequence-append
         sequence-map
         sequence-andmap
         sequence-ormap
         sequence-for-each
         sequence-fold
         sequence-count
         sequence-filter
         sequence-add-between
         in-slice
         in-syntax
         initiate-sequence
         (all-from-out racket/private/for))

;; A small public `racket/sequence` replacement for Goal 1. The private `for`
;; provider owns the sequence protocol; this module owns the public helpers that
;; otherwise pull in real contract machinery from installed Racket.

(define empty-sequence null)

;; check-sequence-helper : symbol? any/c -> void?
;;   Validate public sequence-helper arguments.
(define (check-sequence-helper who seq)
  (unless (sequence? seq)
    (raise-argument-error who "sequence?" seq)))

;; check-sequences : symbol? (listof any/c) -> void?
;;   Validate public sequence-helper rest arguments.
(define (check-sequences who seqs)
  (for-each (lambda (seq)
              (check-sequence-helper who seq))
            seqs))

;; check-sequence-index : symbol? any/c -> void?
;;   Validate public sequence indices.
(define (check-sequence-index who i)
  (unless (exact-nonnegative-integer? i)
    (raise-argument-error who "exact-nonnegative-integer?" i)))

;; next-single-value : symbol? procedure? -> any/c
;;   Extract one sequence element that must produce exactly one value.
(define (next-single-value who next)
  (define vals (call-with-values next list))
  (unless (= (length vals) 1)
    (raise-arguments-error who
                           "sequence element did not produce exactly one value"
                           "received" (length vals)))
  (car vals))

;; sequence->list : sequence? -> list?
;;   Return the single-valued elements of seq as a list.
(define (sequence->list seq)
  (check-sequence-helper 'sequence->list seq)
  (define-values (more? next) (sequence-generate seq))
  (let loop ([acc null])
    (cond
      [(more?) (loop (cons (next-single-value 'sequence->list next) acc))]
      [else (reverse acc)])))

;; sequence-length : sequence? -> exact-nonnegative-integer?
;;   Count seq by extracting and discarding its elements.
(define (sequence-length seq)
  (check-sequence-helper 'sequence-length seq)
  (define-values (more? next) (sequence-generate seq))
  (let loop ([n 0])
    (cond
      [(more?)
       (call-with-values next (lambda vals (void)))
       (loop (add1 n))]
      [else n])))

;; sequence-ref : sequence? exact-nonnegative-integer? -> any
;;   Return element i from seq.
(define (sequence-ref seq i)
  (check-sequence-helper 'sequence-ref seq)
  (check-sequence-index 'sequence-ref i)
  (define-values (more? next) (sequence-generate seq))
  (let loop ([n i])
    (cond
      [(not (more?))
       (raise-arguments-error 'sequence-ref
                              "index reaches past the end of the sequence"
                              "index" i)]
      [(zero? n) (next)]
      [else
       (call-with-values next (lambda vals (void)))
       (loop (sub1 n))])))

;; sequence-tail : sequence? exact-nonnegative-integer? -> sequence?
;;   Return a sequence that skips the first i elements of seq on initiation.
(define (sequence-tail seq i)
  (check-sequence-helper 'sequence-tail seq)
  (check-sequence-index 'sequence-tail i)
  (make-do-sequence
   (lambda ()
     (define-values (more? next) (sequence-generate seq))
     (let loop ([n i])
       (when (positive? n)
         (unless (more?)
           (raise-arguments-error 'sequence-tail
                                  "index reaches past the end of the sequence"
                                  "index" i))
         (call-with-values next (lambda vals (void)))
         (loop (sub1 n))))
     (values (lambda (_pos) (next))
             (lambda (pos) pos)
             #t
             (lambda (_pos) (more?))
             #f
             #f))))

;; sequence-append : sequence? ... -> sequence?
;;   Append sequences in order.
(define (sequence-append . seqs)
  (check-sequences 'sequence-append seqs)
  (apply in-sequences seqs))

;; sequence-map : procedure? sequence? -> sequence?
;;   Lazily map f over seq.
(define (sequence-map f seq)
  (unless (procedure? f)
    (raise-argument-error 'sequence-map "procedure?" f))
  (check-sequence-helper 'sequence-map seq)
  (make-do-sequence
   (lambda ()
     (define-values (more? next) (sequence-generate seq))
     (values (lambda (_pos)
               (apply f (call-with-values next list)))
             (lambda (pos) pos)
             #t
             (lambda (_pos) (more?))
             #f
             #f))))

;; sequence-andmap : procedure? sequence? -> boolean?
;;   Test whether f returns true for every element of seq.
(define (sequence-andmap f seq)
  (unless (procedure? f)
    (raise-argument-error 'sequence-andmap "procedure?" f))
  (check-sequence-helper 'sequence-andmap seq)
  (define-values (more? next) (sequence-generate seq))
  (let loop ()
    (cond
      [(not (more?)) #t]
      [(apply f (call-with-values next list)) (loop)]
      [else #f])))

;; sequence-ormap : procedure? sequence? -> boolean?
;;   Test whether f returns true for some element of seq.
(define (sequence-ormap f seq)
  (unless (procedure? f)
    (raise-argument-error 'sequence-ormap "procedure?" f))
  (check-sequence-helper 'sequence-ormap seq)
  (define-values (more? next) (sequence-generate seq))
  (let loop ()
    (cond
      [(not (more?)) #f]
      [else
       (define result (apply f (call-with-values next list)))
       (if result result (loop))])))

;; sequence-for-each : procedure? sequence? -> void?
;;   Apply f to every element of seq.
(define (sequence-for-each f seq)
  (unless (procedure? f)
    (raise-argument-error 'sequence-for-each "procedure?" f))
  (check-sequence-helper 'sequence-for-each seq)
  (define-values (more? next) (sequence-generate seq))
  (let loop ()
    (when (more?)
      (apply f (call-with-values next list))
      (loop))))

;; sequence-fold : procedure? any/c sequence? -> any/c
;;   Fold f over seq with init as the initial accumulator.
(define (sequence-fold f init seq)
  (unless (procedure? f)
    (raise-argument-error 'sequence-fold "procedure?" f))
  (check-sequence-helper 'sequence-fold seq)
  (define-values (more? next) (sequence-generate seq))
  (let loop ([acc init])
    (cond
      [(more?) (loop (apply f acc (call-with-values next list)))]
      [else acc])))

;; sequence-count : procedure? sequence? -> exact-nonnegative-integer?
;;   Count elements for which f returns true.
(define (sequence-count f seq)
  (unless (procedure? f)
    (raise-argument-error 'sequence-count "procedure?" f))
  (check-sequence-helper 'sequence-count seq)
  (define-values (more? next) (sequence-generate seq))
  (let loop ([n 0])
    (cond
      [(not (more?)) n]
      [(apply f (call-with-values next list)) (loop (add1 n))]
      [else (loop n)])))

;; sequence-filter : procedure? sequence? -> sequence?
;;   Lazily keep elements for which f returns true.
(define (sequence-filter f seq)
  (unless (procedure? f)
    (raise-argument-error 'sequence-filter "procedure?" f))
  (check-sequence-helper 'sequence-filter seq)
  (make-do-sequence
   (lambda ()
     (define-values (more? next) (sequence-generate seq))
     (define cached? #f)
     (define exhausted? #f)
     (define cached-values #f)
     (define (fill-cache!)
       (unless cached?
         (let loop ()
           (cond
             [(not (more?))
              (set! exhausted? #t)
              (set! cached-values #f)
              (set! cached? #t)]
             [else
              (define vals (call-with-values next list))
              (cond
                [(apply f vals)
                 (set! cached-values vals)
                 (set! cached? #t)]
                [else (loop)])]))))
     (values (lambda (_pos) (apply values cached-values))
             (lambda (pos)
               (set! cached? #f)
               pos)
             #t
             (lambda (_pos)
               (fill-cache!)
               (not exhausted?))
             #f
             #f))))

;; sequence-add-between : sequence? any/c -> sequence?
;;   Lazily return seq's elements with e inserted between each pair.
(define (sequence-add-between seq e)
  (check-sequence-helper 'sequence-add-between seq)
  (make-do-sequence
   (lambda ()
     (define-values (more? next) (sequence-generate seq))
     (define (read-next)
       (and (more?) (cons 'value (call-with-values next list))))
     (define first (read-next))
     (values (lambda (state)
               (if (eq? (car state) 'between)
                   e
                   (apply values (cdr state))))
             (lambda (state)
               (cond
                 [(eq? (car state) 'between) (cdr state)]
                 [else
                  (define next-state (read-next))
                  (and next-state (cons 'between next-state))]))
             first
             values
             #f
             #f))))

;; in-slice : exact-positive-integer? sequence? -> sequence?
;;   Group seq into lists of length n; the final group may be shorter.
(define (in-slice n seq)
  (unless (exact-positive-integer? n)
    (raise-argument-error 'in-slice "exact-positive-integer?" n))
  (check-sequence-helper 'in-slice seq)
  (make-do-sequence
   (lambda ()
     (define-values (more? next) (sequence-generate seq))
     (define cached? #f)
     (define exhausted? #f)
     (define cached-slice #f)
     (define (read-slice!)
       (let loop ([i 0] [acc null])
         (cond
           [(or (= i n) (not (more?))) (reverse acc)]
           [else
            (loop (add1 i)
                  (cons (next-single-value 'in-slice next) acc))])))
     (define (fill-cache!)
       (unless cached?
         (define slice (read-slice!))
         (set! cached-slice slice)
         (set! exhausted? (null? slice))
         (set! cached? #t)))
     (values (lambda (_pos) cached-slice)
             (lambda (pos)
               (set! cached? #f)
               pos)
             #t
             (lambda (_pos)
               (fill-cache!)
               (not exhausted?))
             #f
             #f))))

;; in-syntax : syntax? -> sequence?
;;   Sequence over the immediate subparts of a syntax list.
(define (in-syntax stx)
  (unless (syntax? stx)
    (raise-argument-error 'in-syntax "syntax?" stx))
  (define xs (syntax->list stx))
  (unless xs
    (raise-argument-error 'in-syntax "syntax list?" stx))
  (in-list xs))

;; initiate-sequence : keyword protocol -> values
;;   Expand the public sequence protocol wrapper without runtime keyword dispatch.
(define-syntax (initiate-sequence stx)
  (define args (syntax->list stx))
  (unless args
    (raise-syntax-error 'initiate-sequence "expected keyword arguments" stx))
  (define seen null)
  (define parsed (make-hasheq))
  (define (record! kw expr kw-stx)
    (when (memq kw seen)
      (raise-syntax-error 'initiate-sequence "duplicate keyword" stx kw-stx))
    (unless (memq kw '(#:pos->element
                       #:early-next-pos
                       #:next-pos
                       #:init-pos
                       #:continue-with-pos?
                       #:continue-with-val?
                       #:continue-after-pos+val?))
      (raise-syntax-error 'initiate-sequence "unknown keyword" stx kw-stx))
    (set! seen (cons kw seen))
    (hash-set! parsed kw expr))
  (let loop ([args (cdr args)])
    (cond
      [(null? args) (void)]
      [(null? (cdr args))
       (raise-syntax-error 'initiate-sequence "keyword missing an expression" stx (car args))]
      [else
       (define kw-stx (car args))
       (define kw (syntax-e kw-stx))
       (unless (keyword? kw)
         (raise-syntax-error 'initiate-sequence "expected keyword" stx kw-stx))
       (record! kw (cadr args) kw-stx)
       (loop (cddr args))]))
  (define (required kw)
    (hash-ref parsed
              kw
              (lambda ()
                (raise-syntax-error 'initiate-sequence
                                    (format "missing required keyword ~a" kw)
                                    stx))))
  (define (optional kw)
    (hash-ref parsed kw (lambda () #'#f)))
  (with-syntax ([pos->element              (required '#:pos->element)]
                [early-next-pos            (optional '#:early-next-pos)]
                [next-pos                  (required '#:next-pos)]
                [init-pos                  (required '#:init-pos)]
                [continue-with-pos?        (optional '#:continue-with-pos?)]
                [continue-with-val?        (optional '#:continue-with-val?)]
                [continue-after-pos+val?   (optional '#:continue-after-pos+val?)])
    #'(values pos->element
              early-next-pos
              next-pos
              init-pos
              continue-with-pos?
              continue-with-val?
              continue-after-pos+val?)))
