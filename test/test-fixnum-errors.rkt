;; Focused no-stdlib generated-output checks for fixnum errors.
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
 (list "fixnum division errors are catchable with who"
       (let ([catch-division?
              (lambda (who thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message who)
                       (string-contains? message "divide by zero"))))])
         (and
          (catch-division? "fxquotient"
                           (lambda () (fxquotient 1 0)))
          (catch-division? "fxremainder"
                           (lambda () (fxremainder 1 0)))
          (catch-division? "fxmodulo"
                           (lambda () (fxmodulo 1 0))))))
 (list "fixnum remainder/modulo argument errors are catchable with who"
       (let ([catch-fixnum?
              (lambda (who thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message who)
                       (string-contains? message "fixnum")
                       (string-contains? message "1.0"))))])
         (and
          (catch-fixnum? "fxquotient"
                         (lambda () (fxquotient 1.0 1)))
          (catch-fixnum? "fxremainder"
                         (lambda () (fxremainder 1.0 1)))
          (catch-fixnum? "fxmodulo"
                         (lambda () (fxmodulo 1.0 1))))))
 (list "fixnum diagnostics use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (fx+ 536870911 1))
                     "fx+"
                     "fixnum overflow"
                     "CUSTOM-NUMBER and CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (fxquotient 1.0 1))
                     "fxquotient"
                     "fixnum"
                     "CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "fx-/wraparound arity errors are catchable with who"
       (catch-contract/contains?
        (lambda () (fx-/wraparound 1 2 3))
        "fx-/wraparound"
        "arity mismatch"
        "given: 3")))
