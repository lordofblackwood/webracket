#lang racket/base

(require (only-in webracket/primitives
                  [sort primitive-sort]))

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
         eleventh
         twelfth
         thirteenth
         fourteenth
         fifteenth
         last
         last-pair
         cons?
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
         list-set
         list-update
         empty
         empty?
         flatten
         list-prefix?
         split-common-prefix
         take-common-prefix
         drop-common-prefix
         add-between
         remove-duplicates
         check-duplicates
         index-of
         index-where
         indexes-of
         indexes-where
         argmin
         argmax
         group-by
         cartesian-product
         combinations
         in-combinations
         permutations
         in-permutations
         shuffle
         sort
         range
         inclusive-range)

;; A Goal 1 `racket/list` replacement. Most callable list utilities already
;; live in `racket/base`; this module makes them available through the external
;; provider graph and fills common `racket/list` gaps.
;;
;; Prefer source definitions here instead of re-exporting WebRacket primitives:
;; primitive aliases introduce extra provider candidates during reflection.
;; `sort` is the one intentional exception for now: routing `racket/list`'s
;; public sort through this Goal 1 replacement avoids the installed-provider
;; keyword-procedure path, which currently mis-materializes imported `sort`.
;; Keep the exported wrapper plain 2-arity, because `web-pict` and the current
;; Goal 1 examples only need the common positional form.

;; check-list : symbol? any/c -> void?
;;   Raise a Racket-style argument error when v is not a proper list.
(define (check-list who v)
  (unless (list? v)
    (raise-argument-error who "list?" v)))

;; check-procedure : symbol? any/c -> void?
;;   Raise a Racket-style argument error when v is not callable.
(define (check-procedure who v)
  (unless (procedure? v)
    (raise-argument-error who "procedure?" v)))

;; check-index : symbol? any/c -> void?
;;   Raise a Racket-style argument error when v is not a nonnegative index.
(define (check-index who v)
  (unless (exact-nonnegative-integer? v)
    (raise-argument-error who "exact-nonnegative-integer?" v)))

(define first car)
(define rest cdr)
(define empty null)
(define empty? null?)
(define (sort xs less-than?)
  (primitive-sort xs less-than?))

(define (second xs) (list-ref xs 1))
(define (third xs) (list-ref xs 2))
(define (fourth xs) (list-ref xs 3))
(define (fifth xs) (list-ref xs 4))
(define (sixth xs) (list-ref xs 5))
(define (seventh xs) (list-ref xs 6))
(define (eighth xs) (list-ref xs 7))
(define (ninth xs) (list-ref xs 8))
(define (tenth xs) (list-ref xs 9))
(define (eleventh xs) (list-ref xs 10))
(define (twelfth xs) (list-ref xs 11))
(define (thirteenth xs) (list-ref xs 12))
(define (fourteenth xs) (list-ref xs 13))
(define (fifteenth xs) (list-ref xs 14))

;; cons? : any/c -> boolean?
;;   Check for non-empty lists.
(define (cons? v)
  (and (pair? v) (list? v)))

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

;; check-traversal-inputs : symbol? any/c list? -> void?
;;   Check a traversal procedure and each of its proper-list inputs.
(define (check-traversal-inputs who proc inputs)
  (check-procedure who proc)
  (let loop ([remaining inputs])
    (cond
      [(null? remaining) (void)]
      [else
       (check-list who (car remaining))
       (loop (cdr remaining))])))

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
        (reverse reversed)
        (loop (cdr remaining) (cons (caar remaining) reversed)))))

;; traversal-input-cdrs : list? -> list?
;;   Collect the remaining tail from each non-empty input list.
(define (traversal-input-cdrs inputs)
  (let loop ([remaining inputs] [reversed null])
    (if (null? remaining)
        (reverse reversed)
        (loop (cdr remaining) (cons (cdar remaining) reversed)))))

;; raise-traversal-length-error : symbol? list? -> none/c
;;   Report Racket's equal-length requirement for parallel list traversals.
(define (raise-traversal-length-error who inputs)
  (raise-arguments-error who "all lists must have the same size"
                         "lists" inputs))

;; map : procedure? list? ... -> list?
;;   Transform equally sized lists without growing the Wasm stack.
(define (map proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'map proc inputs)
  (let loop ([lists inputs] [reversed null])
    (cond
      [(eq? (traversal-input-state lists) 'finished) (reverse reversed)]
      [(eq? (traversal-input-state lists) 'mismatched)
       (raise-traversal-length-error 'map inputs)]
      [else
       (loop (traversal-input-cdrs lists)
             (cons (apply proc (traversal-input-cars lists)) reversed))])))

;; andmap : procedure? list? ... -> any/c
;;   Return the first false result or the last true result without growing the Wasm stack.
(define (andmap proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'andmap proc inputs)
  (let loop ([lists inputs] [last-value #t])
    (cond
      [(eq? (traversal-input-state lists) 'finished) last-value]
      [(eq? (traversal-input-state lists) 'mismatched)
       (raise-traversal-length-error 'andmap inputs)]
      [else
       (define value (apply proc (traversal-input-cars lists)))
       (if value
           (loop (traversal-input-cdrs lists) value)
           #f)])))

;; ormap : procedure? list? ... -> any/c
;;   Return the first true result or #f without growing the Wasm stack.
(define (ormap proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'ormap proc inputs)
  (let loop ([lists inputs])
    (cond
      [(eq? (traversal-input-state lists) 'finished) #f]
      [(eq? (traversal-input-state lists) 'mismatched)
       (raise-traversal-length-error 'ormap inputs)]
      [else
       (define value (apply proc (traversal-input-cars lists)))
       (if value
           value
           (loop (traversal-input-cdrs lists)))])))

;; for-each : procedure? list? ... -> void?
;;   Apply proc left-to-right without growing the Wasm stack.
(define (for-each proc first . rest)
  (define inputs (cons first rest))
  (check-traversal-inputs 'for-each proc inputs)
  (let loop ([lists inputs])
    (cond
      [(eq? (traversal-input-state lists) 'finished) (void)]
      [(eq? (traversal-input-state lists) 'mismatched)
       (raise-traversal-length-error 'for-each inputs)]
      [else
       (apply proc (traversal-input-cars lists))
       (loop (traversal-input-cdrs lists))])))

;; filter : (any/c -> any/c) list? -> list?
;;   Keep elements for which pred returns a true value without growing the Wasm stack.
(define (filter pred xs)
  (let loop ([remaining xs] [reversed null])
    (cond
      [(null? remaining) (reverse reversed)]
      [(pred (car remaining))
       (loop (cdr remaining) (cons (car remaining) reversed))]
      [else (loop (cdr remaining) reversed)])))

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

;; shuffle : list? -> list?
;;   Return a randomly shuffled list with the same elements as xs.
(define (shuffle xs)
  (check-list 'shuffle xs)
  (define len (length xs))
  (define a (make-vector len))
  (for ([x (in-list xs)] [i (in-naturals)])
    (define j (random (add1 i)))
    (unless (= j i)
      (vector-set! a i (vector-ref a j)))
    (vector-set! a j x))
  (vector->list a))

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
  (check-index 'make-list n)
  (let loop ([n n] [acc null])
    (cond
      [(zero? n) acc]
      [else (loop (sub1 n) (cons v acc))])))

;; build-list : exact-nonnegative-integer? procedure? -> list?
;;   Construct a list by applying f to indices from 0 to n-1.
(define (build-list n f)
  (check-index 'build-list n)
  (check-procedure 'build-list f)
  (let loop ([i 0] [acc null])
    (cond
      [(= i n) (reverse acc)]
      [else (loop (add1 i) (cons (f i) acc))])))

;; list-update : list? exact-nonnegative-integer? procedure? -> list?
;;   Return xs with element n replaced by applying f.
(define (list-update xs n f)
  (check-list 'list-update xs)
  (check-index 'list-update n)
  (check-procedure 'list-update f)
  (cond
    [(zero? n) (cons (f (car xs)) (cdr xs))]
    [else
     (let loop ([xs xs] [n n])
       (cond
         [(zero? n) (cons (f (car xs)) (cdr xs))]
         [else (cons (car xs) (loop (cdr xs) (sub1 n)))]))]))

;; list-set : list? exact-nonnegative-integer? any/c -> list?
;;   Return xs with element n replaced by v.
(define (list-set xs n v)
  (check-list 'list-set xs)
  (check-index 'list-set n)
  (list-update xs n (lambda (_) v)))

;; flatten : any/c -> list?
;;   Flatten pair trees, omitting null leaves.
(define (flatten v)
  (let loop ([v v] [acc null])
    (cond
      [(null? v) acc]
      [(pair? v) (loop (car v) (loop (cdr v) acc))]
      [else (cons v acc)])))

;; list-prefix? : list? list? [procedure?] -> boolean?
;;   Check whether xs is a prefix of ys under same?.
(define (list-prefix? xs ys [same? equal?])
  (check-list 'list-prefix? xs)
  (check-list 'list-prefix? ys)
  (check-procedure 'list-prefix? same?)
  (let loop ([xs xs] [ys ys])
    (or (null? xs)
        (and (pair? ys)
             (same? (car xs) (car ys))
             (loop (cdr xs) (cdr ys))))))

;; split-common-prefix/internal : list? list? procedure? boolean? -> values
;;   Shared implementation for common-prefix helpers.
(define (split-common-prefix/internal xs ys same? keep-prefix?)
  (check-list 'split-common-prefix xs)
  (check-list 'split-common-prefix ys)
  (check-procedure 'split-common-prefix same?)
  (let loop ([xs xs] [ys ys])
    (cond
      [(and (pair? xs) (pair? ys) (same? (car xs) (car ys)))
       (define-values (prefix xs-tail ys-tail)
         (loop (cdr xs) (cdr ys)))
       (values (and keep-prefix? (cons (car xs) prefix))
               xs-tail
               ys-tail)]
      [else (values null xs ys)])))

;; split-common-prefix : list? list? [procedure?] -> values
;;   Return the common prefix and both remaining tails.
(define (split-common-prefix xs ys [same? equal?])
  (split-common-prefix/internal xs ys same? #t))

;; take-common-prefix : list? list? [procedure?] -> list?
;;   Return the common prefix of xs and ys.
(define (take-common-prefix xs ys [same? equal?])
  (define-values (prefix xs-tail ys-tail)
    (split-common-prefix/internal xs ys same? #t))
  prefix)

;; drop-common-prefix : list? list? [procedure?] -> values
;;   Return both tails after dropping the common prefix.
(define (drop-common-prefix xs ys [same? equal?])
  (define-values (prefix xs-tail ys-tail)
    (split-common-prefix/internal xs ys same? #f))
  (values xs-tail ys-tail))

;; add-between : list? any/c [#:splice? any/c] ... -> list?
;;   Add separators between elements, including Racket's keyword variants.
(define (add-between xs sep
                     #:splice? [splice? #f]
                     #:before-first [before-first null]
                     #:before-last [before-last sep]
                     #:after-last [after-last null])
  (check-list 'add-between xs)
  (cond
    [splice?
     (unless (list? sep)
       (raise-argument-error 'add-between "list? in splicing mode" sep))
     (unless (list? before-first)
       (raise-argument-error 'add-between "list? in splicing mode for #:before-first" before-first))
     (unless (list? before-last)
       (raise-argument-error 'add-between "list? in splicing mode for #:before-last" before-last))
     (unless (list? after-last)
       (raise-argument-error 'add-between "list? in splicing mode for #:after-last" after-last))]
    [else
     (unless (null? before-first)
       (raise-argument-error 'add-between "#:before-first only in splicing mode" before-first))
     (unless (null? after-last)
       (raise-argument-error 'add-between "#:after-last only in splicing mode" after-last))])
  (cond
    [(or (null? xs) (null? (cdr xs)))
     (if splice?
         (append before-first xs after-last)
         xs)]
    [splice?
     (append before-first
             (let loop ([xs xs])
               (cond
                 [(null? (cdr xs)) (append before-last (list (car xs)) after-last)]
                 [(null? (cddr xs)) (append (list (car xs)) before-last (list (cadr xs)) after-last)]
                 [else (append (list (car xs)) sep (loop (cdr xs)))])))]
    [else
     (let loop ([xs xs])
       (cond
         [(null? (cdr xs)) (list (car xs))]
         [(null? (cddr xs)) (cons (car xs) (cons before-last (loop (cdr xs))))]
         [else (cons (car xs) (cons sep (loop (cdr xs))))]))]))

;; remove-duplicates : list? [procedure?] [#:key (or/c procedure? #f)] -> list?
;;   Remove later duplicates, preserving the first occurrence.
(define (remove-duplicates xs [same? equal?] #:key [key #f])
  (check-list 'remove-duplicates xs)
  (check-procedure 'remove-duplicates same?)
  (when key
    (check-procedure 'remove-duplicates key))
  (let loop ([xs xs] [seen null])
    (cond
      [(null? xs) null]
      [else
       (define x (car xs))
       (define k (if key (key x) x))
       (if (ormap (lambda (old) (same? k old)) seen)
           (loop (cdr xs) seen)
           (cons x (loop (cdr xs) (cons k seen))))])))

;; check-duplicates : list? [procedure?] [#:key procedure?] [#:default any/c] -> any/c
;;   Return the first duplicate item, or the default result.
(define (check-duplicates xs
                          [same? equal?]
                          #:key [key (lambda (x) x)]
                          #:default [failure-result (lambda () #f)])
  (check-list 'check-duplicates xs)
  (check-procedure 'check-duplicates same?)
  (check-procedure 'check-duplicates key)
  (let loop ([xs xs] [seen null])
    (cond
      [(null? xs)
       (if (procedure? failure-result)
           (failure-result)
           failure-result)]
      [else
       (define x (car xs))
       (define k (key x))
       (if (ormap (lambda (old) (same? k old)) seen)
           x
           (loop (cdr xs) (cons k seen)))])))

;; better-by : procedure? procedure? list? -> any/c
;;   Shared implementation for argmin and argmax.
(define (better-by better? f xs)
  (let loop ([best (car xs)] [best-key (f (car xs))] [xs (cdr xs)])
    (cond
      [(null? xs) best]
      [else
       (define x (car xs))
       (define k (f x))
       (if (better? k best-key)
           (loop x k (cdr xs))
           (loop best best-key (cdr xs)))])))

;; argmin : procedure? non-empty-list? -> any/c
;;   Return the first element with the smallest key.
(define (argmin f xs)
  (check-procedure 'argmin f)
  (check-list 'argmin xs)
  (when (null? xs)
    (raise-argument-error 'argmin "(and/c list? (not/c empty?))" xs))
  (better-by < f xs))

;; argmax : procedure? non-empty-list? -> any/c
;;   Return the first element with the largest key.
(define (argmax f xs)
  (check-procedure 'argmax f)
  (check-list 'argmax xs)
  (when (null? xs)
    (raise-argument-error 'argmax "(and/c list? (not/c empty?))" xs))
  (better-by > f xs))

;; group-by : procedure? list? [procedure?] -> (listof list?)
;;   Group elements by key, preserving first-key and per-group order.
(define (group-by key xs [same? equal?])
  (define (add groups x)
    (define k (key x))
    (let loop ([groups groups])
      (cond
        [(null? groups) (list (cons k (list x)))]
        [(same? k (caar groups))
         (cons (cons (caar groups) (cons x (cdar groups)))
               (cdr groups))]
        [else (cons (car groups) (loop (cdr groups)))])))
  (let loop ([xs xs] [groups null])
    (cond
      [(null? xs) (map reverse (map cdr groups))]
      [else (loop (cdr xs) (add groups (car xs)))])))

;; cartesian-product : list? ... -> (listof list?)
;;   Return the cartesian product in left-to-right order.
(define (cartesian-product . xss)
  (define (prepend-all xs acc)
    (apply append
           (map (lambda (x)
                  (map (lambda (ys) (cons x ys)) acc))
                xs)))
  (foldr prepend-all (list null) xss))

;; combinations/k : list? exact-nonnegative-integer? -> (listof list?)
;;   Return combinations with exactly k elements.
(define (combinations/k xs k)
  (cond
    [(zero? k) (list null)]
    [(null? xs) null]
    [else
     (append (map (lambda (ys) (cons (car xs) ys))
                  (combinations/k (cdr xs) (sub1 k)))
             (combinations/k (cdr xs) k))]))

;; combinations/all : list? -> (listof list?)
;;   Return combinations of every size.
(define (combinations/all xs)
  (cond
    [(null? xs) (list null)]
    [else
     (define rest (combinations/all (cdr xs)))
     (append (map (lambda (ys) (cons (car xs) ys)) rest)
             rest)]))

;; combinations : list? [exact-nonnegative-integer?] -> (listof list?)
;;   Return combinations of xs, optionally restricted to size k.
(define combinations
  (case-lambda
    [(xs) (combinations/all xs)]
    [(xs k) (combinations/k xs k)]))

;; in-combinations : list? [exact-nonnegative-integer?] -> sequence?
;;   A list is a sequence in WebRacket's staged `for` support.
(define in-combinations combinations)

;; remove-one : any/c list? -> list?
;;   Remove the first equal? occurrence of x from xs.
(define (remove-one x xs)
  (cond
    [(null? xs) null]
    [(equal? x (car xs)) (cdr xs)]
    [else (cons (car xs) (remove-one x (cdr xs)))]))

;; permutations : list? -> (listof list?)
;;   Return permutations in Racket's tested order for small Goal 1 programs.
(define (permutations xs)
  (cond
    [(null? xs) (list null)]
    [else
     (apply append
            (map (lambda (x)
                   (map (lambda (ys) (cons x ys))
                        (permutations (remove-one x xs))))
                 xs))]))

;; in-permutations : list? -> sequence?
;;   A list is a sequence in WebRacket's staged `for` support.
(define in-permutations permutations)

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
