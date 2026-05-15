;; Hash/HAMT regression tests for WebRacket.
;;
;; This file is intentionally separate from test-basics.rkt. It should stay
;; focused on public hash behavior and small internal HAMT/stencil-vector
;; invariants that protect the immutable hash implementation.
;;
;; Compile this file with `--no-stdlib`.

(define (insert-range n empty make-key make-val)
  (let loop ([i 0] [h empty])
    (if (equal? i n)
        h
        (loop (+ i 1)
              (hash-set h (make-key i) (make-val i))))))

(define (all? pred xs)
  (cond
    [(null? xs) #t]
    [else (and (pred (car xs)) (all? pred (cdr xs)))]))

(define (contains-equal? xs v)
  (cond
    [(null? xs) #f]
    [(equal? (car xs) v) #t]
    [else (contains-equal? (cdr xs) v)]))

(define (list-subset-equal? xs ys)
  (all? (lambda (x) (contains-equal? ys x)) xs))

(define (same-values? xs ys)
  (and (equal? (length xs) (length ys))
       (list-subset-equal? xs ys)
       (list-subset-equal? ys xs)))

(define (collision/subtree-lookup-and-remove)
  (struct a (hash n)
    #:property prop:equal+hash
    (list
     (lambda (self other recur)
       (and (a? other)
            (equal? (a-hash self) (a-hash other))
            (equal? (a-n self) (a-n other))))
     (lambda (self hash) (a-hash self))
     (lambda (self hash) (a-hash self))))
  (define ht0 (hash (a 1 0) #t))
  (define ht1 (hash (a 1 0) #t
                    (a 1 2) #t))
  (define ht2 (hash (a 1 0) #t
                    (a 1 2) #t
                    (a 33 0) #t))
  (define ht3 (hash (a 1 0) #t
                    (a 33 0) #t))
  (define ht2* (hash-remove ht2 (a 1 2)))
  (and (equal? (hash-count ht0) 1)
       (equal? (hash-count ht1) 2)
       (equal? (hash-count ht2) 3)
       (equal? (hash-count ht3) 2)
       (hash-has-key? ht2 (a 1 0))
       (hash-has-key? ht2 (a 1 2))
       (hash-has-key? ht2 (a 33 0))
       (equal? (hash-ref ht2 (a 1 0)) #t)
       (equal? (hash-ref ht2 (a 1 2)) #t)
       (equal? (hash-ref ht2 (a 33 0)) #t)
       (equal? (hash-count ht2*) 2)
       (not (hash-has-key? ht2* (a 1 2)))
       (hash-has-key? ht2* (a 1 0))
       (hash-has-key? ht2* (a 33 0))))

(define (shifted-integer-immutable-stress)
  (define expected
    (let loop ([i 1] [acc '()])
      (if (equal? i 101)
          (reverse acc)
          (loop (+ i 1) (cons i acc)))))
  (define (exercise shift)
    (define h
      (let loop ([j 0] [h (hash)])
        (if (equal? j 100)
            h
            (loop (+ j 1)
                  (hash-set h (arithmetic-shift j shift) (+ j 1))))))
    (same-values? (hash-values h) expected))
  (and (exercise 0)
       (exercise 1)
       (exercise 5)
       (exercise 7)
       (exercise 12)))

(define (immutable-iterator-invalid-index-defaults)
  (define h (hash 'a 1 'b 2))
  (define pos (hash-iterate-first h))
  (and (fixnum? pos)
       (equal? (hash-iterate-key h 999 'bad) 'bad)
       (equal? (hash-iterate-value h 999 'bad) 'bad)
       (equal? (hash-iterate-pair h 999 'bad) '(bad . bad))
       (equal? (call-with-values
                (lambda () (hash-iterate-key+value h 999 'bad))
                cons)
               '(bad . bad))))

(define (hash-ref-key-retains-equal-key)
  (define k1 (list 'same))
  (define k2 (list 'same))
  (define h (hash-set (hash) k1 'value))
  (and (not (eq? k1 k2))
       (equal? k1 k2)
       (equal? (hash-ref h k2) 'value)
       (eq? (hash-ref-key h k2) k1)))

(define (immutable-hash-constructor-kinds)
  (define h (make-immutable-hash '((a . 1) (b . 2))))
  (define heq (make-immutable-hasheq '((a . 1) (b . 2))))
  (define heqv (make-immutable-hasheqv '((1 . one) (2 . two))))
  (define halw (make-immutable-hashalw '((a . 1) (b . 2))))
  (and (immutable-hash? h)
       (hash-equal? h)
       (hash-eq? heq)
       (hash-eqv? heqv)
       (hash-equal-always? halw)
       (equal? (hash-ref h 'a) 1)
       (equal? (hash-ref heq 'b) 2)
       (equal? (hash-ref heqv 2) 'two)
       (equal? (hash-ref halw 'a) 1)))

(define (cross-kind-persistent-update/remove)
  (define expected '(0 2 3 5 6 8 9 11 12 14 15))
  (define (keep? i)
    (not (equal? (remainder i 3) 1)))
  (define (exercise empty make-key same-key?)
    (define built (insert-range 16 empty make-key (lambda (i) (* i 10))))
    (define trimmed
      (let loop ([i 0] [h built])
        (cond
          [(equal? i 16) h]
          [(keep? i) (loop (+ i 1) h)]
          [else (loop (+ i 1) (hash-remove h (make-key i)))])))
    (define pairs (hash->list trimmed))
    (and (equal? (hash-count built) 16)
         (equal? (hash-count trimmed) (length expected))
         (all? (lambda (i)
                 (and (hash-has-key? trimmed (make-key i))
                      (equal? (hash-ref trimmed (make-key i)) (* i 10))
                      (same-key? (hash-ref-key trimmed (make-key i))
                                 (make-key i))))
               expected)
         (all? (lambda (i)
                 (not (hash-has-key? trimmed (make-key i))))
               '(1 4 7 10 13))
         (same-values? (map cdr pairs)
                       (map (lambda (i) (* i 10)) expected))))
  (and (exercise (hasheq)
                 (lambda (i)
                   (list-ref '(k0 k1 k2 k3 k4 k5 k6 k7
                                  k8 k9 k10 k11 k12 k13 k14 k15)
                             i))
                 eq?)
       (exercise (hasheqv) (lambda (i) i) equal?)
       (exercise (hash) (lambda (i) (list i)) equal?)
       (exercise (hashalw) (lambda (i) (list i)) equal?)))

(define (stencil-vector-update-basics)
  (define sv (stencil-vector #b101 'a 'b))
  (define added (stencil-vector-update sv #b0 #b10 'x))
  (define removed (stencil-vector-update added #b100 #b0))
  (define system ($system-stencil-vector #b111 'a 'b 'c))
  ($system-stencil-vector-truncate! system #b011)
  (and (stencil-vector? sv)
       (not (stencil-vector? system))
       ($system-stencil-vector? system)
       (equal? (stencil-vector-mask sv) #b101)
       (equal? (stencil-vector-length sv) 2)
       (equal? (stencil-vector-ref sv 0) 'a)
       (equal? (stencil-vector-ref sv 1) 'b)
       (equal? (stencil-vector-mask added) #b111)
       (equal? (stencil-vector-length added) 3)
       (equal? (stencil-vector-ref added 1) 'x)
       (equal? (stencil-vector-mask removed) #b011)
       (equal? (stencil-vector-length removed) 2)
       (equal? ($stencil-vector-mask system) #b011)
       (equal? ($stencil-vector-length system) 2)))

(list
 (list "immutable hash upstream-derived HAMT regressions"
       (list
        (list "collision/subtree lookup and remove"
              (collision/subtree-lookup-and-remove))
        (list "shifted integer immutable stress"
              (shifted-integer-immutable-stress))
        (list "immutable iterator invalid index defaults"
              (immutable-iterator-invalid-index-defaults))
        (list "hash-ref-key retained key for equal immutable hash"
              (hash-ref-key-retains-equal-key))
        (list "immutable hash constructor kinds"
              (immutable-hash-constructor-kinds))
        (list "cross-kind persistent update/remove"
              (cross-kind-persistent-update/remove))
        (list "stencil-vector update basics"
              (stencil-vector-update-basics)))))
