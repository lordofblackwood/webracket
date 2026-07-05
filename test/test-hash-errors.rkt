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
         "given: (x)")
        (catch-contract/contains?
         (lambda () (make-hasheqv '(x)))
         "make-hasheqv"
         "(listof pair?)"
         "given: (x)")
        (catch-contract/contains?
         (lambda () (make-hashalw '(x)))
         "make-hashalw"
         "(listof pair?)"
         "given: (x)")))
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
         "given: (x)")
        (catch-contract/contains?
         (lambda () (make-immutable-hasheqv '(x)))
         "make-immutable-hasheqv"
         "(listof pair?)"
         "given: (x)")
        (catch-contract/contains?
         (lambda () (make-immutable-hashalw '(x)))
         "make-immutable-hashalw"
         "(listof pair?)"
         "given: (x)")))
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
           "hash-iterate-key"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (hash-iterate-value i 99))
           "hash-iterate-value"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (hash-iterate-pair i 99))
           "hash-iterate-pair"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda ()
             (call-with-values
              (lambda () (hash-iterate-key+value i 99))
              cons))
           "hash-iterate-key+value"
           "no element at index"
           "index: 99")
          (catch-contract/contains?
           (lambda () (hash-iterate-key m 99))
           "hash-iterate-key"
           "no element at index"
           "index: 99"))))
 (list "hash iteration position contract errors preserve who"
       (let ([i (hash 'a 1)]
             [m (make-hash '((a . 1)))])
         (and
          (catch-contract/contains?
           (lambda () (hash-iterate-next i 'x))
           "hash-iterate-next"
           "exact-nonnegative-integer?"
           "given: x")
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
