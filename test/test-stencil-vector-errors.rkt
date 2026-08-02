;; Focused no-stdlib generated-output checks for stencil-vector errors.
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
 (list "stencil-vector constructor mask errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (stencil-vector 'bad))
         "stencil-vector"
         "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () ($system-stencil-vector 'bad))
         "$system-stencil-vector"
         "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (stencil-vector -1))
         "stencil-vector"
         "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
         "given: -1")))
 (list "stencil-vector constructor value-count errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (stencil-vector #b101 'a))
         "stencil-vector"
         "mask does not match given number of items")
        (catch-contract/contains?
         (lambda () ($system-stencil-vector #b101 'a))
         "$system-stencil-vector"
         "mask does not match given number of items")))
 (list "stencil-vector accessors check stencil-vector values"
       (and
        (catch-contract/contains?
         (lambda () (stencil-vector-length 'bad))
         "stencil-vector-length"
         "stencil-vector?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (stencil-vector-mask 'bad))
         "stencil-vector-mask"
         "stencil-vector?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (stencil-vector-ref 'bad 0))
         "stencil-vector-ref"
         "stencil-vector?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (stencil-vector-set! 'bad 0 'x))
         "stencil-vector-set!"
         "stencil-vector?"
         "given: 'bad")))
 (list "stencil-vector contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(symbol? v) "CUSTOM-SYMBOL"]
              [else "CUSTOM-VALUE"])))
         (let ([sv (stencil-vector #b11 'a 'b)])
           (let ([ok (and
                      (catch-contract/contains?
                       (lambda () (stencil-vector 'bad))
                       "stencil-vector"
                       "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
                       "given: CUSTOM-SYMBOL")
                      (catch-contract/contains?
                       (lambda () (stencil-vector-length 'bad))
                       "stencil-vector-length"
                       "stencil-vector?"
                       "given: CUSTOM-SYMBOL")
                      (catch-contract/contains?
                       (lambda () (stencil-vector-ref sv 'bad))
                       "stencil-vector-ref"
                       "exact-nonnegative-integer?"
                       "given: CUSTOM-SYMBOL")
                      (catch-contract/contains?
                       (lambda () (stencil-vector-ref sv 3))
                       "stencil-vector-ref"
                       "valid vector index"
                       "given: CUSTOM-NUMBER")
                      (catch-contract/contains?
                       (lambda () (stencil-vector-update sv 'bad #b0))
                       "stencil-vector-update"
                       "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
                       "given: CUSTOM-SYMBOL"))])
             (error-value->string-handler old)
             ok))))
 (list "stencil-vector index errors are catchable"
       (let ([sv (stencil-vector #b11 'a 'b)])
         (and
          (catch-contract/contains?
           (lambda () (stencil-vector-ref sv 'bad))
           "stencil-vector-ref"
           "exact-nonnegative-integer?"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () (stencil-vector-ref sv -1))
           "stencil-vector-ref"
           "exact-nonnegative-integer?"
           "given: -1")
          (catch-contract/contains?
           (lambda () (stencil-vector-ref sv 3))
           "stencil-vector-ref"
           "valid vector index"
           "given: 3")
          (catch-contract/contains?
           (lambda () (stencil-vector-set! sv 'bad 'x))
           "stencil-vector-set!"
           "exact-nonnegative-integer?"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () (stencil-vector-set! sv 3 'x))
           "stencil-vector-set!"
           "valid vector index"
           "given: 3"))))
 (list "stencil-vector-update argument errors are catchable"
       (let ([sv (stencil-vector #b101 'a 'b)])
         (and
          (catch-contract/contains?
           (lambda () (stencil-vector-update 'bad #b0 #b0))
           "stencil-vector-update"
           "stencil-vector?"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () (stencil-vector-update sv 'bad #b0))
           "stencil-vector-update"
           "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () (stencil-vector-update sv #b0 'bad))
           "stencil-vector-update"
           "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
           "given: 'bad"))))
 (list "stencil-vector-update shape errors are catchable"
       (let ([sv (stencil-vector #b101 'a 'b)])
         (and
          (catch-contract/contains?
           (lambda () (stencil-vector-update sv #b010 #b0))
           "stencil-vector-update"
           "mask of stencil vector does not have all bits in removal mask")
          (catch-contract/contains?
           (lambda () (stencil-vector-update sv #b0 #b100))
           "stencil-vector-update"
           "mask of stencil vector already has bits in addition mask")
          (catch-contract/contains?
           (lambda () (stencil-vector-update sv #b0 #b010))
           "stencil-vector-update"
           "addition mask does not match given number of items")
          (catch-contract/contains?
           (lambda () (stencil-vector-update sv #b0 #b010 'x 'y))
           "stencil-vector-update"
           "addition mask does not match given number of items"))))
 (list "system stencil-vector update and truncate errors are catchable"
       (let ([sv ($system-stencil-vector #b1 'a)])
         (and
          (catch-contract/contains?
           (lambda () ($system-stencil-vector-update 'bad #b0 #b0))
           "$system-stencil-vector-update"
           "stencil-vector?"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () ($system-stencil-vector-update sv 'bad #b0))
           "$system-stencil-vector-update"
           "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () ($system-stencil-vector-truncate! 'bad #b0))
           "$system-stencil-vector-truncate!"
           "stencil-vector?"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () ($system-stencil-vector-truncate! sv 'bad))
           "$system-stencil-vector-truncate!"
           "(integer-in 0 (sub1 (expt 2 (stencil-vector-mask-width))))"
           "given: 'bad")
          (catch-contract/contains?
           (lambda () ($system-stencil-vector-truncate! sv #b11))
           "$system-stencil-vector-truncate!"
           "new mask has more slots than stencil vector"))))
 (list "stencil-vector success still works"
       (let* ([sv      (stencil-vector #b101 'a 'b)]
              [updated (stencil-vector-update sv #b001 #b010 'x)]
              [system  ($system-stencil-vector #b111 'a 'b 'c)])
         ($system-stencil-vector-truncate! system #b011)
         (and (stencil-vector? sv)
              (not (stencil-vector? system))
              ($stencil-vector? system)
              ($system-stencil-vector? system)
              (equal? (stencil-vector-mask-width) 26)
              (equal? (stencil-vector-mask sv) #b101)
              (equal? (stencil-vector-length sv) 2)
              (equal? (stencil-vector-ref sv 0) 'a)
              (equal? (stencil-vector-ref sv 1) 'b)
              (begin
                (stencil-vector-set! sv 1 'c)
                (equal? (stencil-vector-ref sv 1) 'c))
              (equal? (stencil-vector-mask updated) #b110)
              (equal? (stencil-vector-ref updated 0) 'x)
              (equal? (stencil-vector-ref updated 1) 'b)
              (equal? ($stencil-vector-mask system) #b011)
              (equal? ($stencil-vector-length system) 2)))))
