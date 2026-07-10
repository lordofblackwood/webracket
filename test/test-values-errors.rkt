;; Focused no-stdlib generated-output checks for multiple-value errors.
;;
;; Compile this file with `--no-stdlib`.

(define (catch-result-arity/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:contract:arity?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(list
 (list "let-values result arity errors are catchable"
       (and
        (catch-result-arity/contains?
         (lambda () (let-values ([() 1]) 'missed))
         "result arity mismatch"
         "expected: 0"
         "received: 1")
        (catch-result-arity/contains?
         (lambda () (let-values ([(x) (values 1 2)]) x))
         "result arity mismatch"
         "expected: 1"
         "received: 2")
        (catch-result-arity/contains?
         (lambda () (let-values ([(x y) 1]) x))
         "result arity mismatch"
         "expected: 2"
         "received: 1")
        (catch-result-arity/contains?
         (lambda () (let-values ([(x y) (values 1 2 3)]) x))
         "result arity mismatch"
         "expected: 2"
         "received: 3")))
 (list "let-values success still works"
       (and (let-values ([() (values)]) #t)
            (let-values ([(x) 1]) (equal? x 1))
            (let-values ([(x y) (values 1 2)])
              (and (equal? x 1) (equal? y 2))))))
