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
	           (lambda () (exact-round #f))))))
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
 (list "number conversion basics still work"
       (and (equal? (number->string 42) "42")
            (equal? (number->string 16 16) "10")
            (equal? (number->string 1.25) "1.25")
            (equal? (string->number "42") 42)
            (equal? (string->number "111" 7) 57)
            (equal? (string->number ".") #f))))
