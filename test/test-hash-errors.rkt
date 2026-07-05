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
                (equal? (hash-ref m 'a) 2))))))
