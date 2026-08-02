;; Focused no-stdlib generated-output checks for number conversion errors.
;;
;; Compile this file with `--no-stdlib`.

(list
 (list "generic number errors are catchable"
       (let ([catch-number-contract?
              (lambda (thunk given)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message "number?")
                       (string-contains? message given))))])
         (and
          (catch-number-contract?
           (lambda () (zero? #f))
           "given: #f")
          (catch-number-contract?
           (lambda () (expt 2 #f))
           "given: #f"))))
	 (list "arithmetic number errors preserve who"
	       (let ([catch-number-contract/who?
	              (lambda (who thunk given)
	                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message who)
                       (string-contains? message "number?")
                       (string-contains? message given))))])
         (and
          (catch-number-contract/who?
           "+"
           (lambda () (+ 1 #f))
           "given: #f")
          (catch-number-contract/who?
           "-"
           (lambda () (- 1 #f))
           "given: #f")
          (catch-number-contract/who?
           "*"
           (lambda () (* #f 1))
           "given: #f")
	          (catch-number-contract/who?
	           "/"
	           (lambda () (/ 1 #f))
	           "given: #f"))))
	 (list "numeric primitive errors preserve who and contracts"
	       (let ([catch-contract/who?
	              (lambda (who expected given thunk)
	                (let ([message
	                       (with-handlers ([exn:fail:contract?
	                                        (lambda (exn)
	                                          (exn-message exn))])
	                         (thunk)
	                         #f)])
	                  (and message
	                       (string-contains? message who)
	                       (string-contains? message expected)
	                       (string-contains? message given))))])
	         (and
	          (catch-contract/who?
	           "zero?"
	           "number?"
	           "given: #f"
	           (lambda () (zero? #f)))
	          (catch-contract/who?
	           "add1"
	           "number?"
	           "given: #f"
	           (lambda () (add1 #f)))
	          (catch-contract/who?
	           "sqrt"
	           "number?"
	           "given: #f"
	           (lambda () (sqrt #f)))
	          (catch-contract/who?
	           "sin"
	           "number?"
	           "given: #f"
	           (lambda () (sin #f)))
	          (catch-contract/who?
	           "atan"
	           "number?"
	           "given: #f"
	           (lambda () (atan #f)))
	          (catch-contract/who?
	           "positive?"
	           "real?"
	           "given: #f"
	           (lambda () (positive? #f)))
	          (catch-contract/who?
	           "abs"
	           "real?"
	           "given: #f"
	           (lambda () (abs #f)))
	          (catch-contract/who?
	           "degrees->radians"
	           "real?"
	           "given: #f"
	           (lambda () (degrees->radians #f)))
	          (catch-contract/who?
	           "even?"
	           "integer?"
	           "given: #f"
	           (lambda () (even? #f)))
	          (catch-contract/who?
	           "odd?"
	           "integer?"
	           "given: #f"
	           (lambda () (odd? #f)))
	          (catch-contract/who?
	           "quotient"
	           "integer?"
	           "given: #f"
	           (lambda () (quotient 1 #f)))
	          (catch-contract/who?
	           "modulo"
	           "integer?"
	           "given: #f"
	           (lambda () (modulo #f 1)))
	          (catch-contract/who?
	           "integer-sqrt"
	           "integer?"
	           "given: #f"
	           (lambda () (integer-sqrt #f)))
	          (catch-contract/who?
	           "exact-round"
	           "rational?"
	           "given: #f"
	           (lambda () (exact-round #f)))
	          (catch-contract/who?
	           "="
	           "number?"
	           "given: #f"
	           (lambda () (= #f)))
	          (catch-contract/who?
	           "<"
	           "real?"
	           "given: #f"
	           (lambda () (< 1 #f)))
	          (catch-contract/who?
	           ">"
	           "real?"
	           "given: #f"
	           (lambda () (> #f 1)))
	          (catch-contract/who?
	           "<="
	           "real?"
	           "given: #f"
	           (lambda () (<= #f)))
	          (catch-contract/who?
	           ">="
	           "real?"
	           "given: #f"
	           (lambda () (>= 1 #f)))
	          (catch-contract/who?
	           "min"
	           "real?"
	           "given: #f"
	           (lambda () (min #f)))
	          (catch-contract/who?
	           "max"
	           "real?"
	           "given: #f"
	           (lambda () (max 1 #f)))
	          (catch-contract/who?
	           "positive?"
	           "real?"
	           "given: 'bad"
	           (lambda () (positive? 'bad))))))
	 (list "number->string errors are catchable with who"
	       (let ([catch-contract/who+expected+given?
	              (lambda (expected given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message "number->string")
                       (string-contains? message expected)
                       (string-contains? message given))))])
         (and
          (catch-contract/who+expected+given?
           "number?"
           "given: #f"
           (lambda () (number->string #f)))
          (catch-contract/who+expected+given?
           "(or/c 2 8 10 16)"
           "given: 3"
           (lambda () (number->string 1 3))))))
 (list "string->number errors are catchable with who"
       (let ([catch-contract/who+expected+given?
              (lambda (expected given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message "string->number")
                       (string-contains? message expected)
                       (string-contains? message given))))])
         (and
          (catch-contract/who+expected+given?
           "string?"
           "given: 42"
           (lambda () (string->number 42)))
          (catch-contract/who+expected+given?
           "(integer-in 2 16)"
           "given: #f"
           (lambda () (string->number "1" #f)))
          (catch-contract/who+expected+given?
           "(integer-in 2 16)"
           "given: 1"
           (lambda () (string->number "1" 1)))
          (catch-contract/who+expected+given?
           "(integer-in 2 16)"
           "given: 17"
           (lambda () (string->number "1" 17))))))
 (list "floating-point byte conversion real errors preserve who"
       (let ([catch-contract/who+expected+given?
              (lambda (expected given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message "real->floating-point-bytes")
                       (string-contains? message expected)
                       (string-contains? message given))))])
	         (catch-contract/who+expected+given?
	          "real?"
	          "given: #f"
	          (lambda () (real->floating-point-bytes #f 8)))))
 (list "floating-point byte range errors use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(bytes? v) "CUSTOM-BYTES"]
              [else "CUSTOM-VALUE"])))
         (let ([catch-contract/contains?
                (lambda (thunk . needles)
                  (let ([message
                         (with-handlers ([exn:fail:contract?
                                          (lambda (exn)
                                            (exn-message exn))])
                           (thunk)
                           #f)])
                    (and message
                         (andmap (lambda (needle)
                                   (string-contains? message needle))
                                 needles))))])
           (let ([ok (and
                      (catch-contract/contains?
                       (lambda () (floating-point-bytes->real #"abc" #t 4 8))
                       "floating-point-bytes->real"
                       "starting index is out of range"
                       "index: CUSTOM-BYTES")
                      (catch-contract/contains?
                       (lambda () (floating-point-bytes->real #"abc" #t 0 4))
                       "floating-point-bytes->real"
                       "ending index is out of range"
                       "index: CUSTOM-BYTES")
                      (catch-contract/contains?
                       (lambda () (floating-point-bytes->real #"abc" #t 2 1))
                       "floating-point-bytes->real"
                       "ending index is smaller than starting index"
                       "index: CUSTOM-BYTES"))])
             (error-value->string-handler old)
             ok))))
 (list "real contract errors print non-self-rendering values"
       (let ([catch-contract/who+expected+given?
              (lambda (who expected given thunk)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (thunk)
                         #f)])
                  (and message
                       (string-contains? message who)
                       (string-contains? message expected)
                       (string-contains? message given))))])
         (and
          (catch-contract/who+expected+given?
           "real->double-flonum"
           "real?"
           "given: \"x\""
           (lambda () (real->double-flonum "x")))
          (catch-contract/who+expected+given?
           "abs"
           "real?"
           "given: 'bad"
           (lambda () (abs 'bad))))))
 (list "exact->inexact errors are catchable with number contract"
       (let ([message
              (with-handlers ([exn:fail:contract?
                               (lambda (exn)
                                 (exn-message exn))])
                (exact->inexact #f)
                #f)])
         (and message
              (string-contains? message "exact->inexact")
              (string-contains? message "number?")
              (string-contains? message "given: #f"))))
 (list "exact->inexact accepts complex values"
       (equal? (number->string (exact->inexact 1+2i))
               "1.0+2.0i"))
 (list "inexact->exact non-finite errors report no exact representation"
       (let ([catch-domain-error?
              (lambda (value rendered)
                (let ([message
                       (with-handlers ([exn:fail:contract?
                                        (lambda (exn)
                                          (exn-message exn))])
                         (inexact->exact value)
                         #f)])
                  (and message
                       (string-contains? message "inexact->exact")
                       (string-contains? message "no exact representation")
                       (string-contains? message rendered))))])
         (and
          (catch-domain-error? +nan.0 "+nan.0")
          (catch-domain-error? +inf.0 "+inf.0")
          (catch-domain-error? -inf.0 "-inf.0"))))
 (list "number conversion basics still work"
       (and (equal? (number->string 42) "42")
            (equal? (number->string 16 16) "10")
            (equal? (number->string 1.25) "1.25")
            (equal? (string->number "42") 42)
            (equal? (string->number "111" 7) 57)
            (equal? (string->number ".") #f))))
