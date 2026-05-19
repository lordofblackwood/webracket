#lang racket/base

(provide generic-set?
         list->mutable-set
         list->mutable-setalw
         list->mutable-seteq
         list->mutable-seteqv
         list->set
         list->setalw
         list->seteq
         list->seteqv
         list->weak-set
         list->weak-setalw
         list->weak-seteq
         list->weak-seteqv
         mutable-set
         mutable-setalw
         mutable-seteq
         mutable-seteqv
         proper-subset?
         set
         set->list
         set->stream
         set-add
         set-add!
         set-clear
         set-clear!
         set-copy
         set-copy-clear
         set-count
         set-empty?
         set-eq?
         set-equal?
         set-equal-always?
         set-eqv?
         set-filter
         set-first
         set-for-each
         set-intersect
         set-intersect!
         set-map
         set-member?
         set-mutable?
         set-remove
         set-remove!
         set-rest
         set-subtract
         set-subtract!
         set-symmetric-difference
         set-symmetric-difference!
         set-union
         set-union!
         set-weak?
         set=?
         set?
         setalw
         seteq
         seteqv
         subset?
         weak-set
         weak-setalw
         weak-seteq
         weak-seteqv)

(require "stream.rkt")

;; A staged hash-set provider for Goal 1. It intentionally does not implement
;; Racket's set chaperone/impersonator, contract, or generic-extension surface.

(struct webracket-set (table kind storage))
;; kind    : 'equal | 'equal-always | 'eqv | 'eq
;; storage : 'immutable | 'mutable | 'weak

;; make-empty-table : symbol? symbol? -> hash?
;;   Create the backing hash table for a set kind and storage mode.
(define (make-empty-table kind storage)
  (case storage
    [(immutable)
     (case kind
       [(equal)        (hash)]
       [(equal-always) (hashalw)]
       [(eqv)          (hasheqv)]
       [(eq)           (hasheq)]
       [else (error 'make-empty-table "unknown set kind: ~s" kind)])]
    [(mutable)
     (case kind
       [(equal)        (make-hash)]
       [(equal-always) (make-hashalw)]
       [(eqv)          (make-hasheqv)]
       [(eq)           (make-hasheq)]
       [else (error 'make-empty-table "unknown set kind: ~s" kind)])]
    [(weak)
     (case kind
       [(equal)        (make-weak-hash)]
       [(equal-always) (make-weak-hashalw)]
       [(eqv)          (make-weak-hasheqv)]
       [(eq)           (make-weak-hasheq)]
       [else (error 'make-empty-table "unknown set kind: ~s" kind)])]
    [else (error 'make-empty-table "unknown set storage: ~s" storage)]))

;; make-empty-set : symbol? symbol? -> generic-set?
;;   Construct an empty staged set.
(define (make-empty-set kind storage)
  (webracket-set (make-empty-table kind storage) kind storage))

;; table-set : hash? any/c -> hash?
;;   Add key to an immutable hash table.
(define (table-set table key)
  (hash-set table key #t))

;; table-set! : hash? any/c -> void?
;;   Add key to a mutable or weak hash table.
(define (table-set! table key)
  (hash-set! table key #t))

;; list->set/kind : list? symbol? symbol? -> generic-set?
;;   Build a staged set from lst with the given comparator and storage mode.
(define (list->set/kind lst kind storage)
  (define st (make-empty-set kind storage))
  (case storage
    [(immutable)
     (webracket-set
      (let loop ([lst lst] [table (webracket-set-table st)])
        (cond
          [(null? lst) table]
          [else (loop (cdr lst) (table-set table (car lst)))]))
      kind
      storage)]
    [else
     (let loop ([lst lst])
       (cond
         [(null? lst) st]
         [else
          (table-set! (webracket-set-table st) (car lst))
          (loop (cdr lst))]))]))

;; list->set : list? -> set?
;;   Build an immutable equal?-based set from lst.
(define (list->set lst)
  (list->set/kind lst 'equal 'immutable))

;; list->setalw : list? -> set?
;;   Build an immutable equal-always?-based set from lst.
(define (list->setalw lst)
  (list->set/kind lst 'equal-always 'immutable))

;; list->seteqv : list? -> set?
;;   Build an immutable eqv?-based set from lst.
(define (list->seteqv lst)
  (list->set/kind lst 'eqv 'immutable))

;; list->seteq : list? -> set?
;;   Build an immutable eq?-based set from lst.
(define (list->seteq lst)
  (list->set/kind lst 'eq 'immutable))

;; list->mutable-set : list? -> set-mutable?
;;   Build a mutable equal?-based set from lst.
(define (list->mutable-set lst)
  (list->set/kind lst 'equal 'mutable))

;; list->mutable-setalw : list? -> set-mutable?
;;   Build a mutable equal-always?-based set from lst.
(define (list->mutable-setalw lst)
  (list->set/kind lst 'equal-always 'mutable))

;; list->mutable-seteqv : list? -> set-mutable?
;;   Build a mutable eqv?-based set from lst.
(define (list->mutable-seteqv lst)
  (list->set/kind lst 'eqv 'mutable))

;; list->mutable-seteq : list? -> set-mutable?
;;   Build a mutable eq?-based set from lst.
(define (list->mutable-seteq lst)
  (list->set/kind lst 'eq 'mutable))

;; list->weak-set : list? -> set-weak?
;;   Build a weak equal?-based set from lst.
(define (list->weak-set lst)
  (list->set/kind lst 'equal 'weak))

;; list->weak-setalw : list? -> set-weak?
;;   Build a weak equal-always?-based set from lst.
(define (list->weak-setalw lst)
  (list->set/kind lst 'equal-always 'weak))

;; list->weak-seteqv : list? -> set-weak?
;;   Build a weak eqv?-based set from lst.
(define (list->weak-seteqv lst)
  (list->set/kind lst 'eqv 'weak))

;; list->weak-seteq : list? -> set-weak?
;;   Build a weak eq?-based set from lst.
(define (list->weak-seteq lst)
  (list->set/kind lst 'eq 'weak))

;; set : any/c ... -> set?
;;   Build an immutable equal?-based set from the given values.
(define (set . vs)
  (list->set vs))

;; setalw : any/c ... -> set?
;;   Build an immutable equal-always?-based set from the given values.
(define (setalw . vs)
  (list->setalw vs))

;; seteqv : any/c ... -> set?
;;   Build an immutable eqv?-based set from the given values.
(define (seteqv . vs)
  (list->seteqv vs))

;; seteq : any/c ... -> set?
;;   Build an immutable eq?-based set from the given values.
(define (seteq . vs)
  (list->seteq vs))

;; mutable-set : any/c ... -> set-mutable?
;;   Build a mutable equal?-based set from the given values.
(define (mutable-set . vs)
  (list->mutable-set vs))

;; mutable-setalw : any/c ... -> set-mutable?
;;   Build a mutable equal-always?-based set from the given values.
(define (mutable-setalw . vs)
  (list->mutable-setalw vs))

;; mutable-seteqv : any/c ... -> set-mutable?
;;   Build a mutable eqv?-based set from the given values.
(define (mutable-seteqv . vs)
  (list->mutable-seteqv vs))

;; mutable-seteq : any/c ... -> set-mutable?
;;   Build a mutable eq?-based set from the given values.
(define (mutable-seteq . vs)
  (list->mutable-seteq vs))

;; weak-set : any/c ... -> set-weak?
;;   Build a weak equal?-based set from the given values.
(define (weak-set . vs)
  (list->weak-set vs))

;; weak-setalw : any/c ... -> set-weak?
;;   Build a weak equal-always?-based set from the given values.
(define (weak-setalw . vs)
  (list->weak-setalw vs))

;; weak-seteqv : any/c ... -> set-weak?
;;   Build a weak eqv?-based set from the given values.
(define (weak-seteqv . vs)
  (list->weak-seteqv vs))

;; weak-seteq : any/c ... -> set-weak?
;;   Build a weak eq?-based set from the given values.
(define (weak-seteq . vs)
  (list->weak-seteq vs))

;; generic-set? : any/c -> boolean?
;;   Recognize staged WebRacket set values.
(define (generic-set? v)
  (webracket-set? v))

;; set? : any/c -> boolean?
;;   Recognize immutable staged sets.
(define (set? v)
  (and (webracket-set? v)
       (eq? (webracket-set-storage v) 'immutable)))

;; set-mutable? : any/c -> boolean?
;;   Recognize mutable staged sets.
(define (set-mutable? v)
  (and (webracket-set? v)
       (eq? (webracket-set-storage v) 'mutable)))

;; set-weak? : any/c -> boolean?
;;   Recognize weak staged sets.
(define (set-weak? v)
  (and (webracket-set? v)
       (eq? (webracket-set-storage v) 'weak)))

;; set-equal? : any/c -> boolean?
;;   Recognize equal?-based staged sets.
(define (set-equal? v)
  (and (webracket-set? v)
       (eq? (webracket-set-kind v) 'equal)))

;; set-equal-always? : any/c -> boolean?
;;   Recognize equal-always?-based staged sets.
(define (set-equal-always? v)
  (and (webracket-set? v)
       (eq? (webracket-set-kind v) 'equal-always)))

;; set-eqv? : any/c -> boolean?
;;   Recognize eqv?-based staged sets.
(define (set-eqv? v)
  (and (webracket-set? v)
       (eq? (webracket-set-kind v) 'eqv)))

;; set-eq? : any/c -> boolean?
;;   Recognize eq?-based staged sets.
(define (set-eq? v)
  (and (webracket-set? v)
       (eq? (webracket-set-kind v) 'eq)))

;; check-set : symbol? any/c -> generic-set?
;;   Validate that v is a staged set.
(define (check-set who v)
  (cond
    [(webracket-set? v) v]
    [else (raise-argument-error who "generic-set?" v)]))

;; check-immutable-set : symbol? any/c -> set?
;;   Validate that v is an immutable staged set.
(define (check-immutable-set who v)
  (define st (check-set who v))
  (cond
    [(set? st) st]
    [else (raise-argument-error who "(not/c (or/c set-mutable? set-weak?))" v)]))

;; check-mutable-or-weak-set : symbol? any/c -> generic-set?
;;   Validate that v can be changed in place.
(define (check-mutable-or-weak-set who v)
  (define st (check-set who v))
  (cond
    [(or (set-mutable? st) (set-weak? st)) st]
    [else (raise-argument-error who "(or/c set-mutable? set-weak?)" v)]))

;; check-compatible-set : symbol? generic-set? any/c -> generic-set?
;;   Validate that candidate is a staged set using the base comparator.
(define (check-compatible-set who base candidate)
  (define st (check-set who candidate))
  (cond
    [(eq? (webracket-set-kind base) (webracket-set-kind st)) st]
    [else (error who "set arguments have incompatible equivalence predicates")]))

;; table-keys : hash? -> list?
;;   Return table keys by walking the hash iterator directly.
(define (table-keys table)
  (let loop ([pos (hash-iterate-first table)] [acc '()])
    (cond
      [(not pos) acc]
      [else (loop (hash-iterate-next table pos)
                  (cons (hash-iterate-key table pos) acc))])))

;; set->list : generic-set? -> list?
;;   Return the elements of st in hash iteration order.
(define (set->list st)
  (table-keys (webracket-set-table (check-set 'set->list st))))

;; list->stream : list? -> stream?
;;   Convert a list to a staged WebRacket stream.
(define (list->stream lst)
  (cond
    [(null? lst) empty-stream]
    [else (stream-cons (car lst) (list->stream (cdr lst)))]))

;; set->stream : generic-set? -> stream?
;;   Produce a stream of st's elements.
(define (set->stream st)
  (list->stream (set->list st)))

;; set-member? : generic-set? any/c -> boolean?
;;   Check whether v is in st.
(define (set-member? st v)
  (hash-has-key? (webracket-set-table (check-set 'set-member? st)) v))

;; set-count : generic-set? -> exact-nonnegative-integer?
;;   Count the elements of st.
(define (set-count st)
  (hash-count (webracket-set-table (check-set 'set-count st))))

;; set-empty? : generic-set? -> boolean?
;;   Check whether st has no elements.
(define (set-empty? st)
  (= (set-count st) 0))

;; set-add : set? any/c -> set?
;;   Return st with v included.
(define (set-add st v)
  (define checked (check-immutable-set 'set-add st))
  (webracket-set (table-set (webracket-set-table checked) v)
                 (webracket-set-kind checked)
                 'immutable))

;; set-add! : (or/c set-mutable? set-weak?) any/c -> void?
;;   Add v to st in place.
(define (set-add! st v)
  (define checked (check-mutable-or-weak-set 'set-add! st))
  (table-set! (webracket-set-table checked) v)
  (void))

;; set-remove : set? any/c -> set?
;;   Return st with v removed.
(define (set-remove st v)
  (define checked (check-immutable-set 'set-remove st))
  (webracket-set (hash-remove (webracket-set-table checked) v)
                 (webracket-set-kind checked)
                 'immutable))

;; set-remove! : (or/c set-mutable? set-weak?) any/c -> void?
;;   Remove v from st in place.
(define (set-remove! st v)
  (define checked (check-mutable-or-weak-set 'set-remove! st))
  (hash-remove! (webracket-set-table checked) v)
  (void))

;; set-copy-clear : generic-set? -> generic-set?
;;   Produce a new empty set with the same comparator and storage mode.
(define (set-copy-clear st)
  (define checked (check-set 'set-copy-clear st))
  (make-empty-set (webracket-set-kind checked)
                  (webracket-set-storage checked)))

;; set-clear : set? -> set?
;;   Return an empty immutable set of the same comparator.
(define (set-clear st)
  (define checked (check-immutable-set 'set-clear st))
  (make-empty-set (webracket-set-kind checked) 'immutable))

;; set-clear! : (or/c set-mutable? set-weak?) -> void?
;;   Remove all elements from st in place.
(define (set-clear! st)
  (define checked (check-mutable-or-weak-set 'set-clear! st))
  (hash-clear! (webracket-set-table checked))
  (void))

;; set-copy : generic-set? -> generic-set?
;;   Produce a new mutable or weak set with the same elements and comparator.
(define (set-copy st)
  (define checked (check-set 'set-copy st))
  (define storage
    (if (set-weak? checked) 'weak 'mutable))
  (list->set/kind (set->list checked)
                  (webracket-set-kind checked)
                  storage))

;; set-first : generic-set? -> any/c
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

;; add-elements : set? list? -> set?
;;   Add all keys to immutable acc.
(define (add-elements acc keys)
  (let loop ([keys keys] [acc acc])
    (cond
      [(null? keys) acc]
      [else (loop (cdr keys) (set-add acc (car keys)))])))

;; add-elements! : generic-set? list? -> void?
;;   Add all keys to mutable or weak acc.
(define (add-elements! acc keys)
  (let loop ([keys keys])
    (cond
      [(null? keys) (void)]
      [else
       (set-add! acc (car keys))
       (loop (cdr keys))])))

;; set-union : set? generic-set? ... -> set?
;;   Return the union of the given sets.
(define (set-union st0 . sets)
  (define base (check-immutable-set 'set-union st0))
  (let loop ([sets sets] [acc base])
    (cond
      [(null? sets) acc]
      [else
       (define st (check-compatible-set 'set-union base (car sets)))
       (loop (cdr sets) (add-elements acc (set->list st)))])))

;; set-union! : (or/c set-mutable? set-weak?) generic-set? ... -> void?
;;   Add elements from the later sets to st0 in place.
(define (set-union! st0 . sets)
  (define base (check-mutable-or-weak-set 'set-union! st0))
  (let loop ([sets sets])
    (cond
      [(null? sets) (void)]
      [else
       (define st (check-compatible-set 'set-union! base (car sets)))
       (add-elements! base (set->list st))
       (loop (cdr sets))])))

;; member-of-all? : any/c (listof generic-set?) -> boolean?
;;   Check whether v appears in every set in sets.
(define (member-of-all? v sets)
  (cond
    [(null? sets) #t]
    [(set-member? (car sets) v) (member-of-all? v (cdr sets))]
    [else #f]))

;; set-intersect : set? generic-set? ... -> set?
;;   Return the elements from st0 that appear in all later sets.
(define (set-intersect st0 . sets)
  (define base (check-immutable-set 'set-intersect st0))
  (define checked-sets
    (let loop ([sets sets] [acc '()])
      (cond
        [(null? sets) (reverse acc)]
        [else
         (loop (cdr sets)
               (cons (check-compatible-set 'set-intersect base (car sets))
                     acc))])))
  (let loop ([keys (set->list base)] [acc (set-clear base)])
    (cond
      [(null? keys) acc]
      [(member-of-all? (car keys) checked-sets)
       (loop (cdr keys) (set-add acc (car keys)))]
      [else (loop (cdr keys) acc)])))

;; set-intersect! : (or/c set-mutable? set-weak?) generic-set? ... -> void?
;;   Remove every element from st0 that is not in all later sets.
(define (set-intersect! st0 . sets)
  (define base (check-mutable-or-weak-set 'set-intersect! st0))
  (define checked-sets
    (let loop ([sets sets] [acc '()])
      (cond
        [(null? sets) (reverse acc)]
        [else
         (loop (cdr sets)
               (cons (check-compatible-set 'set-intersect! base (car sets))
                     acc))])))
  (let loop ([keys (set->list base)])
    (cond
      [(null? keys) (void)]
      [else
       (unless (member-of-all? (car keys) checked-sets)
         (set-remove! base (car keys)))
       (loop (cdr keys))])))

;; set-subtract : set? generic-set? ... -> set?
;;   Return st0 with all elements of later sets removed.
(define (set-subtract st0 . sets)
  (define base (check-immutable-set 'set-subtract st0))
  (let loop ([sets sets] [acc base])
    (cond
      [(null? sets) acc]
      [else
       (define st (check-compatible-set 'set-subtract base (car sets)))
       (let remove-loop ([keys (set->list st)] [acc acc])
         (cond
           [(null? keys) (loop (cdr sets) acc)]
           [else (remove-loop (cdr keys) (set-remove acc (car keys)))]))])))

;; set-subtract! : (or/c set-mutable? set-weak?) generic-set? ... -> void?
;;   Remove all elements of later sets from st0 in place.
(define (set-subtract! st0 . sets)
  (define base (check-mutable-or-weak-set 'set-subtract! st0))
  (let loop ([sets sets])
    (cond
      [(null? sets) (void)]
      [else
       (define st (check-compatible-set 'set-subtract! base (car sets)))
       (let remove-loop ([keys (set->list st)])
         (cond
           [(null? keys) (loop (cdr sets))]
           [else
            (set-remove! base (car keys))
            (remove-loop (cdr keys))]))])))

;; toggle-element : set? any/c -> set?
;;   Add key when absent and remove it when present.
(define (toggle-element st key)
  (if (set-member? st key)
      (set-remove st key)
      (set-add st key)))

;; toggle-element! : generic-set? any/c -> void?
;;   Add key when absent and remove it when present, mutating st.
(define (toggle-element! st key)
  (if (set-member? st key)
      (set-remove! st key)
      (set-add! st key)))

;; set-symmetric-difference : set? generic-set? ... -> set?
;;   Return elements that appear an odd number of times across the sets.
(define (set-symmetric-difference st0 . sets)
  (define base (check-immutable-set 'set-symmetric-difference st0))
  (let loop ([sets sets] [acc base])
    (cond
      [(null? sets) acc]
      [else
       (define st (check-compatible-set 'set-symmetric-difference base (car sets)))
       (let toggle-loop ([keys (set->list st)] [acc acc])
         (cond
           [(null? keys) (loop (cdr sets) acc)]
           [else (toggle-loop (cdr keys) (toggle-element acc (car keys)))]))])))

;; set-symmetric-difference! : (or/c set-mutable? set-weak?) generic-set? ... -> void?
;;   Mutate st0 so it contains elements that appear an odd number of times.
(define (set-symmetric-difference! st0 . sets)
  (define base (check-mutable-or-weak-set 'set-symmetric-difference! st0))
  (let loop ([sets sets])
    (cond
      [(null? sets) (void)]
      [else
       (define st (check-compatible-set 'set-symmetric-difference! base (car sets)))
       (let toggle-loop ([keys (set->list st)])
         (cond
           [(null? keys) (loop (cdr sets))]
           [else
            (toggle-element! base (car keys))
            (toggle-loop (cdr keys))]))])))

;; subset? : generic-set? generic-set? -> boolean?
;;   Check whether every element of st is in st2.
(define (subset? st st2)
  (define left (check-set 'subset? st))
  (define right (check-compatible-set 'subset? left st2))
  (let loop ([keys (set->list left)])
    (cond
      [(null? keys) #t]
      [(set-member? right (car keys)) (loop (cdr keys))]
      [else #f])))

;; proper-subset? : generic-set? generic-set? -> boolean?
;;   Check whether st is a strict subset of st2.
(define (proper-subset? st st2)
  (and (subset? st st2)
       (< (set-count st) (set-count st2))))

;; set=? : generic-set? generic-set? -> boolean?
;;   Check whether two staged sets have the same elements.
(define (set=? st st2)
  (and (= (set-count st) (set-count st2))
       (subset? st st2)))

;; set-map : generic-set? procedure? -> list?
;;   Map proc over st and collect results in a list, matching racket/set.
(define (set-map st proc)
  (let loop ([keys (set->list st)] [acc '()])
    (cond
      [(null? keys) (reverse acc)]
      [else (loop (cdr keys) (cons (proc (car keys)) acc))])))

;; set-for-each : generic-set? procedure? -> void?
;;   Apply proc to each element of st for side effects.
(define (set-for-each st proc)
  (let loop ([keys (set->list st)])
    (cond
      [(null? keys) (void)]
      [else
       (proc (car keys))
       (loop (cdr keys))])))

;; set-filter : generic-set? procedure? -> set?
;;   WebRacket extension: keep the elements of st for which proc returns true.
(define (set-filter st proc)
  (define checked (check-set 'set-filter st))
  (let loop ([keys (set->list checked)]
             [acc (make-empty-set (webracket-set-kind checked) 'immutable)])
    (cond
      [(null? keys) acc]
      [(proc (car keys)) (loop (cdr keys) (set-add acc (car keys)))]
      [else (loop (cdr keys) acc)])))
