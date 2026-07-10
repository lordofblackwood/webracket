;; Focused no-stdlib generated-output checks for treelist errors.
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
 (list "treelist index range errors are catchable with range details"
       (let ([tl (treelist 1 2)])
         (and
          (catch-contract/contains?
           (lambda () (treelist-ref tl 2))
           "treelist-ref"
           "index is out of range"
           "index: 2"
           "valid range: [0, 1]"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-set tl 2 'x))
           "treelist-set"
           "index is out of range"
           "index: 2"
           "valid range: [0, 1]"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-insert tl 3 'x))
           "treelist-insert"
           "index is out of range"
           "index: 3"
           "valid range: [0, 2]"
           "treelist length: 2")
          (catch-contract/contains?
           (lambda () (treelist-delete tl 2))
           "treelist-delete"
           "index is out of range"
           "index: 2"
           "valid range: [0, 1]"
           "treelist length: 2"))))
 (list "treelist index success still works"
       (let ([tl (treelist 1 2)])
         (and (equal? (treelist-ref tl 1) 2)
              (equal? (treelist-ref (treelist-set tl 1 'x) 1) 'x)
              (equal? (treelist-ref (treelist-insert tl 2 'x) 2) 'x)
              (equal? (treelist->list (treelist-delete tl 1)) '(1))))))
