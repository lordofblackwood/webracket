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

(define bignum-source-location-index 536870912)

(define id-a (datum->syntax #f 'a))
(define id-b (datum->syntax #f 'b))

(list
 (list "syntax accessors reject non-syntax values with who"
       (and
        (syntax-contract-error?
         (lambda () (syntax-e 42))
         "syntax-e"
         "syntax?"
         "given: 42")
        (syntax-contract-error?
         (lambda () (syntax->datum 42))
         "syntax->datum"
         "syntax?"
         "given: 42")
        (syntax-contract-error?
         (lambda () (syntax-source 42))
         "syntax-source"
         "syntax?"
         "given: 42")
        (syntax-contract-error?
         (lambda () (syntax-property 42 'k))
         "syntax-property"
         "syntax?"
         "given: 42")))
 (list "datum->syntax rejects bad context and optional sources"
       (and
        (syntax-contract-error?
         (lambda () (datum->syntax 42 'a))
         "datum->syntax"
         "syntax?"
         "#f"
         "given: 42")
        (syntax-contract-error?
         (lambda () (datum->syntax #f 'a 42))
         "datum->syntax"
         "srcloc?"
         "given: 42")
        (syntax-contract-error?
         (lambda () (datum->syntax #f 'a (list 'src 0 2 3 4)))
         "datum->syntax"
         "list/c"
         "given:")
        (syntax-contract-error?
         (lambda () (datum->syntax #f 'a (vector 'src 1 2 3)))
         "datum->syntax"
         "vector/c"
         "given:")
        (syntax-contract-error?
         (lambda () (datum->syntax #f 'a #f 42))
         "datum->syntax"
         "syntax?"
         "#f"
         "given: 42")))
 (list "datum->syntax copies context syntax metadata"
       (let* ([ctx (datum->syntax #f 'ctx (srcloc 'src 1 2 3 4))]
              [stx (datum->syntax ctx 'x)])
         (and
          (equal? (syntax-e stx) 'x)
          (equal? (syntax-source stx) 'src)
          (equal? (syntax-line stx) 1)
          (equal? (syntax-column stx) 2)
          (equal? (syntax-position stx) 3)
          (equal? (syntax-span stx) 4))))
 (list "datum->syntax accepts list and vector source locations"
       (let ([from-list (datum->syntax #f 'x (list 'src 1 2 3 4))]
             [from-vector (datum->syntax #f 'x (vector 'src 5 6 7 8))])
         (and
          (equal? (list (syntax-source from-list)
                        (syntax-line from-list)
                        (syntax-column from-list)
                        (syntax-position from-list)
                        (syntax-span from-list))
                  '(src 1 2 3 4))
          (equal? (list (syntax-source from-vector)
                        (syntax-line from-vector)
                        (syntax-column from-vector)
                        (syntax-position from-vector)
                        (syntax-span from-vector))
                  '(src 5 6 7 8)))))
 (list "datum->syntax preserves bignum source-location fields"
       (let* ([n bignum-source-location-index]
              [from-list (datum->syntax #f 'x (list 'src n n n n))]
              [from-vector (datum->syntax #f 'x (vector 'src n n n n))])
         (and
          (equal? (syntax-source from-list) 'src)
          (= (syntax-line from-list) n)
          (= (syntax-column from-list) n)
          (= (syntax-position from-list) n)
          (= (syntax-span from-list) n)
          (equal? (syntax-source from-vector) 'src)
          (= (syntax-line from-vector) n)
          (= (syntax-column from-vector) n)
          (= (syntax-position from-vector) n)
          (= (syntax-span from-vector) n))))
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
 (list "syntax phase arguments accept false and exact integers"
       (and
        (equal? (identifier-binding id-a #f) #f)
        (equal? (identifier-binding id-a -1) #f)
        (equal? (free-identifier=? id-a id-a #f #f) #t)
        (equal? (free-identifier=? id-a id-b -1 -1) #f)
        (equal? (bound-identifier=? id-a id-a #f) #t)
        (procedure? (make-syntax-delta-introducer id-a #f #f))
        (procedure? (make-syntax-delta-introducer id-a #f -1)))))
