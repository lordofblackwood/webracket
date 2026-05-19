#lang racket/base

(provide generic-set?
         list->set
         set
         set?
         set-add
         set-clear
         set-count
         set-empty?
         set-eq?
         set-equal?
         set-eqv?
         set-filter
         set-first
         set-intersect
         set-map
         set-member?
         set-mutable?
         set-remove
         set-rest
         set-subtract
         set-union
         set-weak?
         set=?
         proper-subset?
         subset?
         set->list)

;; A small immutable hash-set surface for Goal 1. This intentionally covers the
;; common immutable `racket/set` operations without pulling in contracts,
;; generics, or mutable/weak set variants.

(struct webracket-set (table))

;; list->set : list? -> set?
;;   Build an immutable equal?-based set from lst.
(define (list->set lst)
  (let loop ([lst lst] [table (hash)])
    (cond
      [(null? lst) (webracket-set table)]
      [else (loop (cdr lst) (hash-set table (car lst) #t))])))

;; set : any/c ... -> set?
;;   Build an immutable equal?-based set from the given values.
(define (set . vs)
  (list->set vs))

;; generic-set? : any/c -> boolean?
;;   Recognize WebRacket's staged immutable set values.
(define (generic-set? v)
  (webracket-set? v))

;; set? : any/c -> boolean?
;;   Recognize WebRacket's staged immutable set values.
(define (set? v)
  (webracket-set? v))

;; set-mutable? : any/c -> boolean?
;;   WebRacket's staged set provider currently implements immutable sets only.
(define (set-mutable? v)
  (and (set? v) #f))

;; set-weak? : any/c -> boolean?
;;   Weak sets are intentionally outside the staged Goal 1 provider.
(define (set-weak? v)
  (and (set? v) #f))

;; set-equal? : any/c -> boolean?
;;   Staged sets use equal?-based immutable hashes.
(define (set-equal? v)
  (set? v))

;; set-eqv? : any/c -> boolean?
;;   Eqv-based sets are not implemented by this staged provider.
(define (set-eqv? v)
  (and (set? v) #f))

;; set-eq? : any/c -> boolean?
;;   Eq-based sets are not implemented by this staged provider.
(define (set-eq? v)
  (and (set? v) #f))

;; check-set : symbol? any/c -> set?
;;   Validate that v is a staged set.
(define (check-set who v)
  (cond
    [(webracket-set? v) v]
    [else (raise-argument-error who "set?" v)]))

;; table-keys : hash? -> list?
;;   Return table keys by walking the hash iterator directly.
(define (table-keys table)
  (let loop ([pos (hash-iterate-first table)] [acc '()])
    (cond
      [(not pos) acc]
      [else (loop (hash-iterate-next table pos)
                  (cons (hash-iterate-key table pos) acc))])))

;; set-member? : set? any/c -> boolean?
;;   Check whether v is in st.
(define (set-member? st v)
  (hash-has-key? (webracket-set-table (check-set 'set-member? st)) v))

;; set-count : set? -> exact-nonnegative-integer?
;;   Count the elements of st.
(define (set-count st)
  (hash-count (webracket-set-table (check-set 'set-count st))))

;; set-empty? : set? -> boolean?
;;   Check whether st has no elements.
(define (set-empty? st)
  (= (set-count st) 0))

;; set-add : set? any/c -> set?
;;   Return st with v included.
(define (set-add st v)
  (define checked (check-set 'set-add st))
  (webracket-set (hash-set (webracket-set-table checked) v #t)))

;; set-remove : set? any/c -> set?
;;   Return st with v removed.
(define (set-remove st v)
  (define checked (check-set 'set-remove st))
  (webracket-set (hash-remove (webracket-set-table checked) v)))

;; set-clear : set? -> set?
;;   Return an empty set of the same staged kind.
(define (set-clear st)
  (check-set 'set-clear st)
  (webracket-set (hash)))

;; set->list : set? -> list?
;;   Return the elements of st in hash iteration order.
(define (set->list st)
  (table-keys (webracket-set-table (check-set 'set->list st))))

;; set-first : set? -> any/c
;;   Return one element from non-empty st.
(define (set-first st)
  (define keys (set->list st))
  (cond
    [(null? keys) (error 'set-first "expected a non-empty set")]
    [else (car keys)]))

;; set-rest : set? -> set?
;;   Return st without one element.
(define (set-rest st)
  (set-remove st (set-first st)))

;; set-intersect : set? set? ... -> set?
;;   Return a set containing elements that appear in all given sets.
(define (set-intersect st . sets)
  (define checked (check-set 'set-intersect st))
  (define (member-of-all? v sets)
    (cond
      [(null? sets) #t]
      [(set-member? (car sets) v) (member-of-all? v (cdr sets))]
      [else #f]))
  (define (add-matching keys acc)
    (cond
      [(null? keys) acc]
      [(member-of-all? (car keys) sets)
       (add-matching (cdr keys) (set-add acc (car keys)))]
      [else (add-matching (cdr keys) acc)]))
  (add-matching (table-keys (webracket-set-table checked)) (set)))

;; set-union : set? ... -> set?
;;   Return the union of the given sets.
(define (set-union . sets)
  (define (add-list keys acc)
    (cond
      [(null? keys) acc]
      [else (add-list (cdr keys) (set-add acc (car keys)))]))
  (let loop ([sets sets] [acc (set)])
    (cond
      [(null? sets) acc]
      [else (loop (cdr sets) (add-list (set->list (car sets)) acc))])))

;; set-subtract : set? set? ... -> set?
;;   Return st with all elements of the later sets removed.
(define (set-subtract st . sets)
  (define (remove-list keys acc)
    (cond
      [(null? keys) acc]
      [else (remove-list (cdr keys) (set-remove acc (car keys)))]))
  (let loop ([sets sets] [acc (check-set 'set-subtract st)])
    (cond
      [(null? sets) acc]
      [else (loop (cdr sets) (remove-list (set->list (car sets)) acc))])))

;; subset? : set? set? -> boolean?
;;   Check whether every element of st is in st2.
(define (subset? st st2)
  (define keys (set->list st))
  (check-set 'subset? st2)
  (let loop ([keys keys])
    (cond
      [(null? keys) #t]
      [(set-member? st2 (car keys)) (loop (cdr keys))]
      [else #f])))

;; proper-subset? : set? set? -> boolean?
;;   Check whether st is a strict subset of st2.
(define (proper-subset? st st2)
  (and (subset? st st2)
       (< (set-count st) (set-count st2))))

;; set=? : set? set? -> boolean?
;;   Check whether two staged sets have the same elements.
(define (set=? st st2)
  (and (= (set-count st) (set-count st2))
       (subset? st st2)))

;; set-map : set? procedure? -> set?
;;   Map proc over st and collect results in a staged set.
(define (set-map st proc)
  (define keys (set->list st))
  (let loop ([keys keys] [acc (set)])
    (cond
      [(null? keys) acc]
      [else (loop (cdr keys) (set-add acc (proc (car keys))))])))

;; set-filter : set? procedure? -> set?
;;   Keep the elements of st for which proc returns a true value.
(define (set-filter st proc)
  (define keys (set->list st))
  (let loop ([keys keys] [acc (set)])
    (cond
      [(null? keys) acc]
      [(proc (car keys)) (loop (cdr keys) (set-add acc (car keys)))]
      [else (loop (cdr keys) acc)])))
