;; Focused no-stdlib generated-output checks for syntax primitive errors.
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

(define (syntax-contract-error? thunk . needles)
  (apply catch-contract/contains? thunk needles))

(define id-a (datum->syntax #f 'a))
(define id-b (datum->syntax #f 'b))

(list
 (list "syntax phase arguments reject non-phase values"
       (and
        (syntax-contract-error?
         (lambda () (identifier-binding id-a 'bad))
         "identifier-binding"
         "phase?"
         "given: 'bad")
        (syntax-contract-error?
         (lambda () (free-identifier=? id-a id-b 'bad 0))
         "free-identifier=?"
         "phase?"
         "given: 'bad")
        (syntax-contract-error?
         (lambda () (free-identifier=? id-a id-b 0 'bad))
         "free-identifier=?"
         "phase?"
         "given: 'bad")
        (syntax-contract-error?
         (lambda () (bound-identifier=? id-a id-b 'bad))
         "bound-identifier=?"
         "phase?"
         "given: 'bad")
        (syntax-contract-error?
         (lambda () (make-syntax-delta-introducer id-a #f 'bad))
         "make-syntax-delta-introducer"
         "phase?"
         "given: 'bad")))
 (list "syntax phase arguments accept #f and exact integers"
       (and
        (equal? (identifier-binding id-a #f) #f)
        (equal? (identifier-binding id-a -1) #f)
        (equal? (free-identifier=? id-a id-a #f #f) #t)
        (equal? (free-identifier=? id-a id-b -1 -1) #f)
        (equal? (bound-identifier=? id-a id-a #f) #t)
        (procedure? (make-syntax-delta-introducer id-a #f #f))
        (procedure? (make-syntax-delta-introducer id-a #f -1)))))
