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
         append*
         map
         andmap
         ormap
         for-each
         foldl
         foldr
         filter
         filter-not
         filter-map
         append-map
         count
         partition
         take
         drop
         split-at
         takef
         dropf
         splitf-at
         take-right
         drop-right
         split-at-right
         takef-right
         dropf-right
         splitf-at-right
         remove
         remove*
         remf
         remf*
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
         empty
         empty?
         flatten
         index-of
         index-where
         indexes-of
         indexes-where
         range
         inclusive-range)

;; A Goal 1 `racket/list` replacement. Most callable list utilities already
;; live in `racket/base`; this module makes them available through the external
;; provider graph and fills common `racket/list` gaps.
;;
;; Prefer source definitions here instead of re-exporting WebRacket primitives:
;; primitive aliases introduce extra provider candidates during reflection.

(define first car)
(define rest cdr)
(define empty null)
(define empty? null?)
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
(define append-map
  (case-lambda
    [(f xs) (apply append (map f xs))]
    [(f xs ys) (apply append (map f xs ys))]
    [(f xs . xss) (apply append (apply map f xs xss))]))

;; append* : list? ... list? -> list?
;;   Append a list of lists, optionally preceded by lists.
(define append*
  (case-lambda
    [(xs) (apply append xs)]
    [(xs ys) (apply append xs ys)]
    [(xs ys zs) (apply append xs ys zs)]
    [(xs ys zs ws) (apply append xs ys zs ws)]
    [(xs . xss) (apply apply append xs xss)]))

;; count : procedure? list? ... -> exact-nonnegative-integer?
;;   Count tuples for which f returns a true value.
(define (count f . xss)
  (let loop ([xss xss] [n 0])
    (cond
      [(ormap null? xss) n]
      [(apply f (map car xss)) (loop (map cdr xss) (add1 n))]
      [else (loop (map cdr xss) n)])))

;; filter-not : (any/c -> any/c) list? -> list?
;;   Keep elements for which pred returns #f.
(define (filter-not pred xs)
  (let loop ([xs xs] [acc null])
    (cond
      [(null? xs) (reverse acc)]
      [(pred (car xs)) (loop (cdr xs) acc)]
      [else (loop (cdr xs) (cons (car xs) acc))])))

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

;; takef : any/c procedure? -> list?
;;   Take leading pair-chain elements while pred returns true.
(define (takef xs pred)
  (let loop ([xs xs] [acc null])
    (cond
      [(not (pair? xs)) (reverse acc)]
      [(pred (car xs)) (loop (cdr xs) (cons (car xs) acc))]
      [else (reverse acc)])))

;; dropf : any/c procedure? -> any/c
;;   Drop leading pair-chain elements while pred returns true.
(define (dropf xs pred)
  (cond
    [(not (pair? xs)) xs]
    [(pred (car xs)) (dropf (cdr xs) pred)]
    [else xs]))

;; splitf-at : any/c procedure? -> (values list? any/c)
;;   Split xs at the first element for which pred returns #f.
(define (splitf-at xs pred)
  (values (takef xs pred) (dropf xs pred)))

;; take-right : list? exact-nonnegative-integer? -> list?
;;   Return the final n elements of xs using the lead-pointer strategy.
(define (take-right xs n)
  (let loop ([xs xs] [lead (drop xs n)])
    (cond
      [(pair? lead) (loop (cdr xs) (cdr lead))]
      [else xs])))

;; drop-right : list? exact-nonnegative-integer? -> list?
;;   Drop the final n elements of xs using the lead-pointer strategy.
(define (drop-right xs n)
  (let loop ([xs xs] [lead (drop xs n)])
    (cond
      [(pair? lead) (cons (car xs) (loop (cdr xs) (cdr lead)))]
      [else null])))

;; split-at-right : list? exact-nonnegative-integer? -> (values list? list?)
;;   Split xs before the final n elements.
(define (split-at-right xs n)
  (let loop ([xs xs] [lead (drop xs n)] [acc null])
    (cond
      [(pair? lead) (loop (cdr xs) (cdr lead) (cons (car xs) acc))]
      [else (values (reverse acc) xs)])))

;; count-from-right : symbol? list? procedure? -> exact-nonnegative-integer?
;;   Count the split point before the longest suffix satisfying pred.
(define (count-from-right who xs pred)
  (let loop ([xs xs] [rev null] [n 0])
    (cond
      [(pair? xs) (loop (cdr xs) (cons (car xs) rev) (add1 n))]
      [else
       (let scan ([n n] [xs rev])
         (cond
           [(and (pair? xs) (pred (car xs))) (scan (sub1 n) (cdr xs))]
           [else n]))])))

;; takef-right : list? procedure? -> list?
;;   Keep the longest suffix whose elements satisfy pred.
(define (takef-right xs pred)
  (drop xs (count-from-right 'takef-right xs pred)))

;; dropf-right : list? procedure? -> list?
;;   Drop the longest suffix whose elements satisfy pred.
(define (dropf-right xs pred)
  (take xs (count-from-right 'dropf-right xs pred)))

;; splitf-at-right : list? procedure? -> (values list? list?)
;;   Split xs before the longest suffix whose elements satisfy pred.
(define (splitf-at-right xs pred)
  (split-at xs (count-from-right 'splitf-at-right xs pred)))

;; remove : any/c list? [procedure?] -> list?
;;   Remove the first element matching v. The comparator defaults to equal?.
(define (remove v xs [same? equal?])
  (define original xs)
  (let loop ([xs xs] [acc null])
    (cond
      [(null? xs) original]
      [(same? v (car xs)) (append (reverse acc) (cdr xs))]
      [else (loop (cdr xs) (cons (car xs) acc))])))

;; remove* : list? list? [procedure?] -> list?
;;   Remove elements matching any value in vs. The comparator defaults to equal?.
(define (remove* vs xs [same? equal?])
  (define original xs)
  (let loop ([xs xs] [acc null] [removed? #f])
    (cond
      [(null? xs) (if removed? (reverse acc) original)]
      [(ormap (lambda (v) (same? v (car xs))) vs)
       (loop (cdr xs) acc #t)]
      [else
       (loop (cdr xs) (cons (car xs) acc) removed?)])))

;; remf : procedure? list? -> list?
;;   Remove the first element for which pred returns true.
(define (remf pred xs)
  (define original xs)
  (let loop ([xs xs] [acc null])
    (cond
      [(null? xs) original]
      [(pred (car xs)) (append (reverse acc) (cdr xs))]
      [else (loop (cdr xs) (cons (car xs) acc))])))

;; remf* : procedure? list? -> list?
;;   Remove every element for which pred returns true.
(define (remf* pred xs)
  (define original xs)
  (let loop ([xs xs] [acc null] [removed? #f])
    (cond
      [(null? xs) (if removed? (reverse acc) original)]
      [(pred (car xs)) (loop (cdr xs) acc #t)]
      [else (loop (cdr xs) (cons (car xs) acc) removed?)])))

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

;; index-where : list? procedure? -> (or/c exact-nonnegative-integer? #f)
;;   Return the first index whose element satisfies pred.
(define (index-where xs pred)
  (let loop ([xs xs] [i 0])
    (cond
      [(null? xs) #f]
      [(pred (car xs)) i]
      [else (loop (cdr xs) (add1 i))])))

;; index-of : list? any/c [procedure?] -> (or/c exact-nonnegative-integer? #f)
;;   Return the first index whose element matches v.
(define (index-of xs v [same? equal?])
  (index-where xs (lambda (x) (same? v x))))

;; indexes-where : list? procedure? -> (listof exact-nonnegative-integer?)
;;   Return every index whose element satisfies pred.
(define (indexes-where xs pred)
  (let loop ([xs xs] [i 0] [acc null])
    (cond
      [(null? xs) (reverse acc)]
      [(pred (car xs)) (loop (cdr xs) (add1 i) (cons i acc))]
      [else (loop (cdr xs) (add1 i) acc)])))

;; indexes-of : list? any/c [procedure?] -> (listof exact-nonnegative-integer?)
;;   Return every index whose element matches v.
(define (indexes-of xs v [same? equal?])
  (indexes-where xs (lambda (x) (same? v x))))

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

;; flatten : any/c -> list?
;;   Flatten pair trees, omitting null leaves.
(define (flatten v)
  (let loop ([v v] [acc null])
    (cond
      [(null? v) acc]
      [(pair? v) (loop (car v) (loop (cdr v) acc))]
      [else (cons v acc)])))

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
