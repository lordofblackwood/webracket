;; Focused no-stdlib generated-output checks for vector constructor errors.
;;
;; Compile this file with `--no-stdlib`.

(define (catch-contract/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:contract?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(list
 (list "make-vector length errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (make-vector #f))
         "make-vector"
         "valid-vector-length?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (make-vector -1))
         "make-vector"
         "valid-vector-length?"
         "given: -1")))
 (list "build-vector length errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (build-vector #f values))
         "build-vector"
         "exact-nonnegative-integer?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (build-vector -1 values))
         "build-vector"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "build-vector procedure errors are catchable with who"
       (catch-contract/contains?
        (lambda () (build-vector 1 #f))
        "build-vector"
        "(exact-nonnegative-integer? . -> . any/c)"
        "given: #f"))
 (list "vector map/count procedure errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (vector-map #f '#(1)))
         "vector-map"
         "procedure?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (vector-map! #f (vector 1)))
         "vector-map!"
         "procedure?"
         "given: #f")
        (catch-contract/contains?
         (lambda () (vector-count #f '#(1)))
         "vector-count"
         "procedure?"
         "given: #f")))
 (list "vector map/count vector errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (vector-map add1 42))
         "vector-map"
         "vector?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (vector-map! add1 42))
         "vector-map!"
         "(and/c vector? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (vector-count values 42))
         "vector-count"
         "vector?"
         "given: 42")))
 (list "vector map/count length errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (vector-map + '#(1) '#(2 3)))
         "vector-map"
         "all vectors must have same size")
        (catch-contract/contains?
         (lambda () (vector-map! + (vector 1) '#(2 3)))
         "vector-map!"
         "all vectors must have same size")
        (catch-contract/contains?
         (lambda () (vector-count + '#(1) '#(2 3)))
         "vector-count"
         "all vectors must have same size")))
 (list "vector argmin/argmax errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (vector-argmin #f '#(1)))
         "vector-argmin"
         "(any/c . -> . real?)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (vector-argmax values '#()))
         "vector-argmax"
         "(and/c vector? (lambda (v) (positive? (vector-length v))))"
         "given: '#()")))
 (list "vector filter/search procedure errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (vector-filter #f '#(1)))
         "vector-filter"
         "(any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (vector-filter-not #f '#(1)))
         "vector-filter-not"
         "(any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (vector-member 1 '#(1) #f))
         "vector-member"
         "procedure?"
         "given: #f")))
 (list "vector sort procedure errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (vector-sort '#(1) #f))
         "vector-sort"
         "(any/c any/c . -> . any/c)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (vector-sort! (vector 1) #f))
         "vector-sort!"
         "(any/c any/c . -> . any/c)"
         "given: #f")))
 (list "negative vector element indexes preserve the public contract"
       (and
        (catch-contract/contains?
         (lambda () (vector-ref '#(a b) -1))
         "vector-ref"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector*-ref '#(a b) -1))
         "vector*-ref"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-set! (vector 'a 'b) -1 'x))
         "vector-set!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector*-set! (vector 'a 'b) -1 'x))
         "vector*-set!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-set/copy '#(a b) -1 'x))
         "vector-set/copy"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "positive vector element indexes report range details"
       (and
        (catch-contract/contains?
         (lambda () (vector-ref '#(a b) 2))
         "vector-ref"
         "index is out of range"
         "index: 2"
         "valid range: [0, 1]"
         "vector:")
        (catch-contract/contains?
         (lambda () (vector-ref '#() 0))
         "vector-ref"
         "index is out of range for empty vector"
         "index: 0"
         "vector:")
        (catch-contract/contains?
         (lambda () (vector-set! (vector 'a 'b) 2 'x))
         "vector-set!"
         "index is out of range"
         "index: 2"
         "valid range: [0, 1]"
         "vector:")
        (catch-contract/contains?
         (lambda () (vector-set/copy '#(a b) 2 'x))
         "vector-set/copy"
         "index is out of range"
         "index: 2"
         "valid range: [0, 1]"
         "vector:")))
 (list "negative vector range indexes preserve the public contract"
       (and
        (catch-contract/contains?
         (lambda () (vector-copy '#(a b) -1))
         "vector-copy"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-copy '#(a b) 0 -1))
         "vector-copy"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-copy! (vector 'a 'b) -1 '#(x)))
         "vector-copy!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-copy! (vector 'a 'b) 0 '#(x y) -1))
         "vector-copy!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-copy! (vector 'a 'b) 0 '#(x y) 0 -1))
         "vector-copy!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector->values '#(a b) -1))
         "vector->values"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector->values '#(a b) 0 -1))
         "vector->values"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-sort '#(2 1) < -1))
         "vector-sort"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-sort '#(2 1) < 0 -1))
         "vector-sort"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-sort! (vector 2 1) < -1))
         "vector-sort!"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-sort! (vector 2 1) < 0 -1))
         "vector-sort!"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "negative vector slice indexes preserve the public contract"
       (and
        (catch-contract/contains?
         (lambda () (vector-take '#(a b) -1))
         "vector-take"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-drop '#(a b) -1))
         "vector-drop"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-take-right '#(a b) -1))
         "vector-take-right"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-drop-right '#(a b) -1))
         "vector-drop-right"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-split-at '#(a b) -1))
         "vector-split-at"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (vector-split-at-right '#(a b) -1))
         "vector-split-at-right"
         "exact-nonnegative-integer?"
         "given: -1")))
 (list "positive vector slice indexes report range details"
       (and
        (catch-contract/contains?
         (lambda () (vector-take '#(a b) 3))
         "vector-take"
         "index is out of range"
         "index: 3"
         "valid range: [0, 2]"
         "vector:")
        (catch-contract/contains?
         (lambda () (vector-drop '#(a b) 3))
         "vector-drop"
         "index is out of range"
         "index: 3"
         "valid range: [0, 2]"
         "vector:")
        (catch-contract/contains?
         (lambda () (vector-split-at '#() 1))
         "vector-split-at"
         "index is out of range"
         "index: 1"
         "valid range: [0, 0]"
         "vector:")
        (catch-contract/contains?
         (lambda () (vector-split-at-right '#(a b) 3))
         "vector-split-at-right"
         "index is out of range"
         "index: 3"
         "valid range: [0, 2]"
         "vector:")))
 (list "vector constructors still work"
       (and (equal? (make-vector 3 'x) '#(x x x))
            (equal? (build-vector 3 values) '#(0 1 2)))))
