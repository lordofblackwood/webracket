;; Focused no-stdlib generated-output checks for hash errors.
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

(define (catch-unsupported/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:unsupported?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(struct hash-plain ())

(define hash-plain-given "given: #(struct hash-plain)")

(list
 (list "hash-ref missing key errors are catchable with key detail"
       (and
        (catch-contract/contains?
         (lambda () (hash-ref (make-hash) 42))
         "hash-ref"
         "no value found for key"
         "key: 42")
        (catch-contract/contains?
         (lambda () (hash-ref (hash) 42))
         "hash-ref"
         "no value found for key"
         "key: 42")
        (catch-contract/contains?
         (lambda () (hash-ref-key (make-hash) 42))
         "hash-ref-key"
         "hash does not contain key"
         "key: 42")
        (catch-contract/contains?
         (lambda () (hash-ref-key (hash) 42))
         "hash-ref-key"
         "hash does not contain key"
         "key: 42")
        (catch-contract/contains?
         (lambda () (hash-update! (make-hash) 42 add1))
         "hash-update!"
         "no value found for key: 42")))
 (list "hash-ref success and failure defaults still work"
       (let ([m (make-hash '((a . 1)))]
             [i (hash 'a 1)])
         (and (equal? (hash-ref m 'a) 1)
              (equal? (hash-ref i 'a) 1)
              (equal? (hash-ref m 'missing 'fallback) 'fallback)
              (equal? (hash-ref i 'missing (lambda () 'fallback)) 'fallback)
              (begin
                (hash-update! m 'a add1)
                (equal? (hash-ref m 'a) 2)))))
 (list "make-reader-graph unsupported hash placeholders are catchable"
       (catch-unsupported/contains?
        (lambda () (make-reader-graph (make-hash-placeholder '((a . 1)))))
        "make-reader-graph"
        "hash placeholders are not supported"))
 (list "immutable hash map/copy and filters work without traps"
       (let* ([h       (hash 'a 1 'b 2 'c 3)]
              [copy    (hash-map/copy h (lambda (k v) (values k (+ v 10))))]
              [by-pair (hash-filter h (lambda (k v) (< v 3)))]
              [by-key  (hash-filter-keys h (lambda (k) (or (eq? k 'a) (eq? k 'c))))]
              [by-val  (hash-filter-values h (lambda (v) (< v 3)))]
              [eqh     (hasheq 'a 1 'b 2)]
              [eqf     (hash-filter eqh (lambda (k v) (eq? k 'a)))])
         (and (immutable-hash? copy)
              (hash-equal? copy)
              (equal? (hash-count copy) 3)
              (equal? (hash-ref copy 'a) 11)
              (equal? (hash-ref copy 'b) 12)
              (immutable-hash? by-pair)
              (hash-equal? by-pair)
              (equal? (hash-count by-pair) 2)
              (equal? (hash-ref by-pair 'a) 1)
              (equal? (hash-ref by-pair 'b) 2)
              (equal? (hash-ref by-pair 'c #f) #f)
              (immutable-hash? by-key)
              (equal? (hash-count by-key) 2)
              (equal? (hash-ref by-key 'a) 1)
              (equal? (hash-ref by-key 'c) 3)
              (equal? (hash-ref by-key 'b #f) #f)
              (immutable-hash? by-val)
              (equal? (hash-count by-val) 2)
              (equal? (hash-ref by-val 'a) 1)
              (equal? (hash-ref by-val 'b) 2)
              (equal? (hash-ref by-val 'c #f) #f)
              (immutable-hash? eqf)
              (hash-eq? eqf)
              (equal? (hash-count eqf) 1)
              (equal? (hash-ref eqf 'a) 1))))
 (list "immutable hash varargs odd argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (hash 'a))
         "hash"
         "key does not have a value"
         "key: a")
        (catch-contract/contains?
         (lambda () (hasheq 'a))
         "hasheq"
         "key does not have a value"
         "key: a")
        (catch-contract/contains?
         (lambda () (hasheqv 'a))
         "hasheqv"
         "key does not have a value"
         "key: a")
        (catch-contract/contains?
         (lambda () (hashalw 'a))
         "hashalw"
         "key does not have a value"
         "key: a")))
 (list "mutable hash constructor alist errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (make-hash 42))
         "make-hash"
         "(listof pair?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-hasheq '(x)))
         "make-hasheq"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-hasheqv '(x)))
         "make-hasheqv"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-hashalw '(x)))
         "make-hashalw"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-hasheq (list (mcons 'x 'y))))
         "make-hasheq"
         "(listof pair?)"
         "given:"
         "x"
         "y")))
 (list "immutable hash constructor alist errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (make-immutable-hash 42))
         "make-immutable-hash"
         "(listof pair?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-immutable-hasheq '(x)))
         "make-immutable-hasheq"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-immutable-hasheqv '(x)))
         "make-immutable-hasheqv"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-immutable-hashalw '(x)))
         "make-immutable-hashalw"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-immutable-hasheq (list (mcons 'x 'y))))
         "make-immutable-hasheq"
         "(listof pair?)"
         "given:"
         "x"
         "y")))
 (list "weak and ephemeron hash constructor alist errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (make-weak-hash 42))
         "make-weak-hash"
         "(listof pair?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-weak-hasheq 42))
         "make-weak-hasheq"
         "(listof pair?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-weak-hasheqv 42))
         "make-weak-hasheqv"
         "(listof pair?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-weak-hashalw 42))
         "make-weak-hashalw"
         "(listof pair?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-ephemeron-hasheq 42))
         "make-ephemeron-hasheq"
         "(listof pair?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-weak-hasheq '(x)))
         "make-weak-hasheq"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-ephemeron-hasheq '(x)))
         "make-ephemeron-hasheq"
         "(listof pair?)"
         "given: '(x)")
        (catch-contract/contains?
         (lambda () (make-weak-hasheq (list (mcons 'x 'y))))
         "make-weak-hasheq"
         "(listof pair?)"
         "given:"
         "x"
         "y")))
 (list "weak and ephemeron hash constructors keep strong fallback behavior"
       (let ([weak-equal (make-weak-hash '((a . 1)))]
             [weak-eq    (make-weak-hasheq '((a . 1)))]
             [weak-eqv   (make-weak-hasheqv '((1 . one)))]
             [weak-alw   (make-weak-hashalw '((a . 1)))]
             [eph-eq     (make-ephemeron-hasheq '((a . 1)))])
         (and (hash? weak-equal)
              (hash? weak-eq)
              (hash? weak-eqv)
              (hash? weak-alw)
              (hash? eph-eq)
              (not (hash-weak? weak-equal))
              (not (hash-weak? eph-eq))
              (equal? (hash-ref weak-equal 'a) 1)
              (equal? (hash-ref weak-eq 'a) 1)
              (equal? (hash-ref weak-eqv 1) 'one)
              (equal? (hash-ref weak-alw 'a) 1)
              (equal? (hash-ref eph-eq 'a) 1))))
 (list "read-only hash argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (hash-ref 42 'x))
         "hash-ref"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-ref-key 42 'x))
         "hash-ref-key"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-has-key? 42 'x))
         "hash-has-key?"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-count 42))
         "hash-count"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-empty? 42))
         "hash-empty?"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash->list 42))
         "hash->list"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-keys 42))
         "hash-keys"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-values 42))
         "hash-values"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-copy 42))
         "hash-copy"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-eq? 42))
         "hash-eq?"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-eqv? 42))
         "hash-eqv?"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-equal? 42))
         "hash-equal?"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-equal-always? 42))
         "hash-equal-always?"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-for-each 42 (lambda (k v) #t)))
         "hash-for-each"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-map 42 (lambda (k v) k)))
         "hash-map"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-map/copy 42 (lambda (k v) (values k v))))
         "hash-map/copy"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-filter 42 (lambda (k v) #t)))
         "hash-filter"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-filter-keys 42 (lambda (k) #t)))
         "hash-filter-keys"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-filter-values 42 (lambda (v) #t)))
         "hash-filter-values"
         "hash?"
         "given: 42")))
 (list "hash-map/copy callback result arity errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (hash-map/copy (make-hash '((a . 1))) (lambda (k v) k)))
         "result arity mismatch"
         "expected: 2"
         "received: 1")
        (catch-contract/contains?
         (lambda () (hash-map/copy (hash 'a 1) (lambda (k v) (values k v 'extra))))
         "result arity mismatch"
         "expected: 2"
         "received: 3")))
 (list "hash iteration type errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (hash-iterate-first 42))
         "hash-iterate-first:"
         "expected: hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-iterate-next 42 0))
         "hash-iterate-next:"
         "expected: hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-iterate-key 42 0))
         "hash-iterate-key:"
         "expected: hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-iterate-value 42 0))
         "hash-iterate-value:"
         "expected: hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-iterate-pair 42 0))
         "hash-iterate-pair:"
         "expected: hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda ()
           (call-with-values
            (lambda () (hash-iterate-key+value 42 0))
            cons))
         "hash-iterate-key+value:"
         "expected: hash?"
         "given: 42")))
 (list "higher-order hash procedure errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (hash-for-each (make-hash '((a . 1))) 42))
         "hash-for-each"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-for-each (hash 'a 1) 42))
         "hash-for-each"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-map (make-hash '((a . 1))) 42))
         "hash-map"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-map (hash 'a 1) 42))
         "hash-map"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-map/copy (make-hash '((a . 1))) 42))
         "hash-map/copy"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-map/copy (hash 'a 1) 42))
         "hash-map/copy"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-filter (make-hash '((a . 1))) 42))
         "hash-filter"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-filter (hash 'a 1) 42))
         "hash-filter"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-filter-keys (make-hash '((a . 1))) 42))
         "hash-filter-keys"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-filter-values (hash 'a 1) 42))
         "hash-filter-values"
         "procedure?"
         "given: 42")))
 (list "higher-order hash procedure positions reject plain structs"
       (and
        (catch-contract/contains?
         (lambda () (hash-for-each (make-hash '((a . 1))) (hash-plain)))
         "hash-for-each"
         "(procedure-arity-includes/c 2)"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-for-each (hash 'a 1) (hash-plain)))
         "hash-for-each"
         "(procedure-arity-includes/c 2)"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-map (make-hash '((a . 1))) (hash-plain)))
         "hash-map"
         "(procedure-arity-includes/c 2)"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-map (hash 'a 1) (hash-plain)))
         "hash-map"
         "(procedure-arity-includes/c 2)"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-map/copy (make-hash '((a . 1))) (hash-plain)))
         "hash-map/copy"
         "(procedure-arity-includes/c 2)"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-map/copy (hash 'a 1) (hash-plain)))
         "hash-map/copy"
         "(procedure-arity-includes/c 2)"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-filter (make-hash '((a . 1))) (hash-plain)))
         "hash-filter"
         "procedure?"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-filter (hash 'a 1) (hash-plain)))
         "hash-filter"
         "procedure?"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-filter-keys (make-hash '((a . 1))) (hash-plain)))
         "hash-filter-keys"
         "procedure?"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-filter-values (hash 'a 1) (hash-plain)))
         "hash-filter-values"
         "procedure?"
         hash-plain-given)))
 (list "hash callback arity errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (hash-for-each (hash 'a 1) (lambda (x) x)))
         "hash-for-each"
         "(procedure-arity-includes/c 2)"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-map (hash 'a 1) (lambda (x) x)))
         "hash-map"
         "(procedure-arity-includes/c 2)"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-map/copy (hash 'a 1) (lambda (x) x)))
         "hash-map/copy"
         "(procedure-arity-includes/c 2)"
         "given:")))
 (list "hash update procedure errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (hash-update (hash 'a 1) 'a 42))
         "hash-update"
         "(any/c . -> . any/c)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-update! (make-hash '((a . 1))) 'a 42))
         "hash-update!"
         "(any/c . -> . any/c)"
         "given: 42")))
 (list "hash update procedure positions reject plain structs"
       (and
        (catch-contract/contains?
         (lambda () (hash-update (hash 'a 1) 'a (hash-plain)))
         "hash-update"
         "(any/c . -> . any/c)"
         hash-plain-given)
        (catch-contract/contains?
         (lambda () (hash-update! (make-hash '((a . 1))) 'a (hash-plain)))
         "hash-update!"
         "(any/c . -> . any/c)"
         hash-plain-given)))
 (list "hash update callback arity errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (hash-update (hash 'a 1) 'a (lambda () 2)))
         "hash-update"
         "(any/c . -> . any/c)"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-update! (make-hash '((a . 1))) 'a (lambda () 2)))
         "hash-update!"
         "(any/c . -> . any/c)"
         "given:")))
 (list "hash failure defaults treat plain structs as values"
       (let ([m (make-hash)]
             [plain (hash-plain)])
         (and
          (eq? (hash-ref m 'missing plain) plain)
          (eq? (hash-ref (hash) 'missing plain) plain)
          (eq? (hash-ref-key m 'missing plain) plain)
          (eq? (hash-ref-key (hash) 'missing plain) plain)
          (eq? (hash-ref! m 'inserted plain) plain)
          (eq? (hash-ref m 'inserted) plain)
          (let ([m2 (make-hash)])
            (hash-update! m2 'x values plain)
            (eq? (hash-ref m2 'x) plain))
          (let ([h2 (hash-update (hash) 'x values plain)])
            (eq? (hash-ref h2 'x) plain)))))
 (list "immutable hash operation mutability errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (hash-set 42 'x 1))
         "hash-set"
         "(and/c hash? immutable?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-set (make-hash) 'x 1))
         "hash-set"
         "(and/c hash? immutable?)"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-remove (make-hash) 'x))
         "hash-remove"
         "(and/c hash? immutable?)"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-update (make-hash) 'x add1 0))
         "hash-update"
         "(and/c hash? immutable?)"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-clear (make-hash)))
         "hash-clear"
         "(and/c hash? immutable?)"
         "given:")))
 (list "mutable hash argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (hash-set! 42 'x 1))
         "hash-set!"
         "(and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-set! (hash 'a 1) 'x 1))
         "hash-set!"
         "(and/c hash? (not/c immutable?))"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-ref! 42 'x 1))
         "hash-ref!"
         "(and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-ref! (hash 'a 1) 'x 1))
         "hash-ref!"
         "(and/c hash? (not/c immutable?))"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-update! 42 'x add1))
         "hash-update!"
         "(and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-update! (hash 'a 1) 'a add1))
         "hash-update!"
         "(and/c hash? (not/c immutable?))"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-remove! 42 'x))
         "hash-remove!"
         "(and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-remove! (hash 'a 1) 'a))
         "hash-remove!"
         "(and/c hash? (not/c immutable?))"
         "given:")
        (catch-contract/contains?
         (lambda () (hash-clear! 42))
         "hash-clear!"
         "(and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (hash-clear! (hash 'a 1)))
         "hash-clear!"
         "(and/c hash? (not/c immutable?))"
         "given:")))
 (list "hash iteration bad-index errors are catchable with who"
       (let ([i (hash 'a 1)]
             [m (make-hash '((a . 1)))])
         (and
          (catch-contract/contains?
           (lambda () (hash-iterate-key i 99))
           "hash-iterate-key: no element at index"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (hash-iterate-value i 99))
           "hash-iterate-value: no element at index"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (hash-iterate-pair i 99))
           "hash-iterate-pair: no element at index"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda ()
             (call-with-values
              (lambda () (hash-iterate-key+value i 99))
              cons))
           "hash-iterate-key+value: no element at index"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (hash-iterate-key m 99))
           "hash-iterate-key: no element at index"
           "no element at index"
           "index: 99"))))
 (list "mutable hash iteration position errors preserve who"
       (let ([m (make-hash '((a . 1)))])
         (and
          (catch-contract/contains?
           (lambda () (mutable-hash-iterate-next m -1))
           "mutable-hash-iterate-next:"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (mutable-hash-iterate-key m #f))
           "mutable-hash-iterate-key:"
           "exact-nonnegative-integer?"
           "given: #f")
          (catch-contract/contains?
           (lambda () (mutable-hash-iterate-value m -1))
           "mutable-hash-iterate-value:"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (mutable-hash-iterate-pair m -1))
           "mutable-hash-iterate-pair:"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda ()
             (call-with-values
              (lambda () (mutable-hash-iterate-key+value m -1))
              cons))
           "mutable-hash-iterate-key+value:"
           "exact-nonnegative-integer?"
           "given: -1"))))
 (list "mutable hash iteration bad-index errors preserve who"
       (let ([m (make-hash '((a . 1)))])
         (and
          (catch-contract/contains?
           (lambda () (mutable-hash-iterate-key m 99))
           "mutable-hash-iterate-key: no element at index"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (mutable-hash-iterate-value m 99))
           "mutable-hash-iterate-value: no element at index"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (mutable-hash-iterate-pair m 99))
           "mutable-hash-iterate-pair: no element at index"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda ()
             (call-with-values
              (lambda () (mutable-hash-iterate-key+value m 99))
              cons))
           "mutable-hash-iterate-key+value: no element at index"
           "no element at index"
           "index: 99"))))
 (list "mutable hash iteration type errors preserve who"
       (and
        (catch-contract/contains?
         (lambda () (mutable-hash-iterate-first 42))
         "mutable-hash-iterate-first:"
         "expected: (and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (mutable-hash-iterate-next 42 0))
         "mutable-hash-iterate-next:"
         "expected: (and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (mutable-hash-iterate-key 42 0))
         "mutable-hash-iterate-key:"
         "expected: (and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (mutable-hash-iterate-value 42 0))
         "mutable-hash-iterate-value:"
         "expected: (and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (mutable-hash-iterate-pair 42 0))
         "mutable-hash-iterate-pair:"
         "expected: (and/c hash? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda ()
           (call-with-values
            (lambda () (mutable-hash-iterate-key+value 42 0))
            cons))
         "mutable-hash-iterate-key+value:"
         "expected: (and/c hash? (not/c immutable?))"
         "given: 42")))
 (list "hash iteration position contract errors preserve who"
       (let ([i (hash 'a 1)]
             [m (make-hash '((a . 1)))])
         (and
          (catch-contract/contains?
           (lambda () (hash-iterate-next i 'x))
           "hash-iterate-next"
           "exact-nonnegative-integer?"
           "given: 'x")
          (catch-contract/contains?
           (lambda () (hash-iterate-next m -1))
           "hash-iterate-next"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (hash-iterate-key i #f))
           "hash-iterate-key"
           "exact-nonnegative-integer?"
           "given: #f")
          (catch-contract/contains?
           (lambda () (hash-iterate-value i -1))
           "hash-iterate-value"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (hash-iterate-pair i -1))
           "hash-iterate-pair"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda ()
             (call-with-values
              (lambda () (hash-iterate-key+value i -1))
              cons))
           "hash-iterate-key+value"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (hash-iterate-key m -1))
           "hash-iterate-key"
           "exact-nonnegative-integer?"
           "given: -1")))))
