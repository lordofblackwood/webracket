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
 (list "vector constructors still work"
       (and (equal? (make-vector 3 'x) '#(x x x))
            (equal? (build-vector 3 values) '#(0 1 2)))))
