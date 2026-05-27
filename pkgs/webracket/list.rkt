#lang racket/base

(provide first
         rest
         second
         third
         fourth
         fifth
         sixth
         seventh
         eighth
         ninth
         tenth
         last
         last-pair
         list-ref
         list-tail
         length
         reverse
         append
         map
         andmap
         ormap
         for-each
         foldl
         foldr
         filter
         filter-map
         append-map
         partition
         take
         drop
         split-at
         take-right
         drop-right
         split-at-right
         remove
         remove*
         remq
         remv
         remw
         memf
         findf
         member
         memq
         memv
         assf
         assoc
         assq
         assv
         make-list
         build-list
         range
         inclusive-range)

;; A Goal 1 `racket/list` replacement. Most callable list utilities already
;; live in `racket/base`; this module makes them available through the external
;; provider graph and fills the common `range`/`inclusive-range` gap.

(define first car)
(define rest cdr)
(define (second xs) (list-ref xs 1))
(define (third xs) (list-ref xs 2))
(define (fourth xs) (list-ref xs 3))
(define (fifth xs) (list-ref xs 4))
(define (sixth xs) (list-ref xs 5))
(define (seventh xs) (list-ref xs 6))
(define (eighth xs) (list-ref xs 7))
(define (ninth xs) (list-ref xs 8))
(define (tenth xs) (list-ref xs 9))

;; last-pair : pair? -> pair?
;;   Return the final pair in a non-empty proper or improper list.
(define (last-pair xs)
  (cond
    [(pair? (cdr xs)) (last-pair (cdr xs))]
    [else xs]))

;; last : pair? -> any/c
;;   Return the car of the final pair in a non-empty list.
(define (last xs)
  (car (last-pair xs)))

;; filter : (any/c -> any/c) list? -> list?
;;   Keep elements for which pred returns a true value.
(define (filter pred xs)
  (let loop ([xs xs])
    (cond
      [(null? xs) null]
      [(pred (car xs)) (cons (car xs) (loop (cdr xs)))]
      [else (loop (cdr xs))])))

;; filter-map : procedure? list? ... -> list?
;;   Map and keep true results.
(define (filter-map f . xss)
  (let loop ([xss xss])
    (cond
      [(ormap null? xss) null]
      [else
       (define v (apply f (map car xss)))
       (define rest-xss (map cdr xss))
       (if v
           (cons v (loop rest-xss))
           (loop rest-xss))])))

;; append-map : procedure? list? ... -> list?
;;   Map f and append the resulting lists.
(define (append-map f . xss)
  (apply append (apply map f xss)))

;; partition : (any/c -> any/c) list? -> (values list? list?)
;;   Split xs according to pred, applying pred once per element.
(define (partition pred xs)
  (let loop ([xs xs] [yes null] [no null])
    (cond
      [(null? xs) (values (reverse yes) (reverse no))]
      [(pred (car xs)) (loop (cdr xs) (cons (car xs) yes) no)]
      [else (loop (cdr xs) yes (cons (car xs) no))])))

;; take : list? exact-nonnegative-integer? -> list?
;;   Return the first n elements of xs.
(define (take xs n)
  (cond
    [(zero? n) null]
    [else (cons (car xs) (take (cdr xs) (sub1 n)))]))

;; drop : list? exact-nonnegative-integer? -> list?
;;   Drop the first n elements of xs.
(define (drop xs n)
  (cond
    [(zero? n) xs]
    [else (drop (cdr xs) (sub1 n))]))

;; split-at : list? exact-nonnegative-integer? -> (values list? list?)
;;   Split xs after n elements.
(define (split-at xs n)
  (values (take xs n) (drop xs n)))

;; take-right : list? exact-nonnegative-integer? -> list?
;;   Return the final n elements of xs.
(define (take-right xs n)
  (drop xs (- (length xs) n)))

;; drop-right : list? exact-nonnegative-integer? -> list?
;;   Drop the final n elements of xs.
(define (drop-right xs n)
  (take xs (- (length xs) n)))

;; split-at-right : list? exact-nonnegative-integer? -> (values list? list?)
;;   Split xs before the final n elements.
(define (split-at-right xs n)
  (values (drop-right xs n) (take-right xs n)))

;; remove : any/c list? [procedure?] -> list?
;;   Remove the first element matching v. The comparator defaults to equal?.
(define (remove v xs [same? equal?])
  (let loop ([xs xs])
    (cond
      [(null? xs) null]
      [(same? v (car xs)) (cdr xs)]
      [else (cons (car xs) (loop (cdr xs)))])))

;; remove* : list? list? [procedure?] -> list?
;;   Remove elements matching any value in vs. The comparator defaults to equal?.
(define (remove* vs xs [same? equal?])
  (filter (lambda (x)
            (not (ormap (lambda (v) (same? v x)) vs)))
          xs))

(define (remq v xs) (remove v xs eq?))
(define (remv v xs) (remove v xs eqv?))
(define (remw v xs) (remove v xs equal-always?))

;; memf : (any/c -> any/c) list? -> (or/c pair? #f)
;;   Return the first tail whose car satisfies pred.
(define (memf pred xs)
  (cond
    [(null? xs) #f]
    [(pred (car xs)) xs]
    [else (memf pred (cdr xs))]))

;; findf : (any/c -> any/c) list? -> any/c
;;   Return the first element satisfying pred, or #f.
(define (findf pred xs)
  (define tail (memf pred xs))
  (and tail (car tail)))

;; member : any/c list? [procedure?] -> (or/c pair? #f)
;;   Return the first tail whose car matches v. The comparator defaults to equal?.
(define (member v xs [same? equal?])
  (memf (lambda (x) (same? v x)) xs))

;; assf : (any/c -> any/c) list? -> (or/c pair? #f)
;;   Return the first association whose key satisfies pred.
(define (assf pred xs)
  (cond
    [(null? xs) #f]
    [(pred (caar xs)) (car xs)]
    [else (assf pred (cdr xs))]))

;; assoc : any/c list? [procedure?] -> (or/c pair? #f)
;;   Return the first association whose key matches v.
(define (assoc v xs [same? equal?])
  (assf (lambda (x) (same? v x)) xs))

(define (assq v xs) (assoc v xs eq?))
(define (assv v xs) (assoc v xs eqv?))

;; make-list : exact-nonnegative-integer? any/c -> list?
;;   Construct a list of n copies of v.
(define (make-list n v)
  (let loop ([n n] [acc null])
    (cond
      [(zero? n) acc]
      [else (loop (sub1 n) (cons v acc))])))

;; build-list : exact-nonnegative-integer? procedure? -> list?
;;   Construct a list by applying f to indices from 0 to n-1.
(define (build-list n f)
  (let loop ([i 0] [acc null])
    (cond
      [(= i n) (reverse acc)]
      [else (loop (add1 i) (cons (f i) acc))])))

;; range : real? [real?] [real?] -> list?
;;   Build a list like `in-range`; step defaults to 1 and start defaults to 0.
(define range
  (case-lambda
    [(end) (range 0 end 1)]
    [(start end) (range start end 1)]
    [(start end step)
     (when (zero? step)
       (raise-argument-error 'range "non-zero real?" step))
     (let loop ([n start] [acc null])
       (cond
         [(if (positive? step) (>= n end) (<= n end)) (reverse acc)]
         [else (loop (+ n step) (cons n acc))]))]))

;; inclusive-range : real? real? [real?] -> list?
;;   Build a list like `in-inclusive-range`.
(define inclusive-range
  (case-lambda
    [(start end) (inclusive-range start end 1)]
    [(start end step)
     (when (zero? step)
       (raise-argument-error 'inclusive-range "non-zero real?" step))
     (let loop ([n start] [acc null])
       (cond
         [(if (positive? step) (> n end) (< n end)) (reverse acc)]
         [else (loop (+ n step) (cons n acc))]))]))
