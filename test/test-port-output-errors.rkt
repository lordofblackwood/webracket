;; Focused no-stdlib generated-output checks for output-port wrapper errors.
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

(struct sink (port) #:property prop:output-port 0)

(list
 (list "write-bytes discards unusable prop:output-port wrappers"
       (and (output-port? (sink 42))
            (equal? (write-bytes #"abc" (sink 42)) 3)
            (equal? (write-bytes #"abc" (sink 42) 1 3) 2)))
 (list "write-bytes still validates ranges for discard wrappers"
       (catch-contract/contains?
        (lambda () (write-bytes #"abc" (sink 42) 4))
        "write-bytes"
        "starting index is out of range"))
 (list "write-bytes resolves prop:output-port wrappers with real targets"
       (let* ([underlying (open-output-bytes)]
              [wrapped (sink underlying)])
         (and (equal? (write-bytes #"abc" wrapped 1 3) 2)
              (equal? (get-output-bytes underlying) #"bc")))))
