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
 (list "call-with-output-string procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (call-with-output-string 42))
         "call-with-output-string"
         "(output-port? . -> . any)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-output-string (lambda () 'bad)))
         "call-with-output-string"
         "(output-port? . -> . any)"
         "given:")))
 (list "make-output-port constructor contract errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt 42 (lambda () (void))))
         "make-output-port"
         "(or/c output-port? (procedure-arity-includes/c 5))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) 42))
         "make-output-port"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda (x) (void))))
         "make-output-port"
         "(procedure-arity-includes/c 0)"
         "given:")))
 (list "default output handlers validate output ports with who"
       (and
        (catch-contract/contains?
         (lambda () ((port-write-handler (open-output-string)) 'value 42))
         "default-port-write-handler"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () ((port-display-handler (open-output-string)) 'value 42))
         "default-port-display-handler"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () ((port-print-handler (open-output-string)) 'value 42 0))
         "default-port-print-handler"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () ((port-print-handler (open-output-string)) 'value (open-output-string) 2))
         "default-port-print-handler"
         "(or/c 0 1)"
         "given: 2")))
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
