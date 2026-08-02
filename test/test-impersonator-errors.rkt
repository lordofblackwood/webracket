;; Focused no-stdlib generated-output checks for impersonator/chaperone errors.
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

(define (catch-unsupported/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail:unsupported?
                          (lambda (exn)
                            (exn-message exn))])
           (thunk)
           #f)])
    (and message
         (andmap (lambda (needle)
                   (string-contains? message needle))
                 needles))))

(define (p2 a b) 'ok)
(define (p3 a b c) 'ok)

(struct impersonator-plain ())

(define (impersonator-plain-given)
  (impersonator-plain))

(list
 (list "impersonator-val unsupported path is catchable"
       (catch-unsupported/contains?
        (lambda () (impersonator-val 42))
        "impersonators are not supported by WebRacket"))
 (list "impersonator property errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (make-impersonator-property 42))
         "make-impersonator-property"
         "symbol?"
         "given: 42")
        (let-values ([(prop pred acc) (make-impersonator-property 'demo)])
          (and (impersonator-property? prop)
               (procedure? pred)
               (procedure? acc)
               (equal? (pred 42) #f)
               (equal? (acc 42 'fallback) 'fallback)
               (equal? (acc 42 (lambda () 'fallback-proc)) 'fallback-proc)
               (catch-contract/contains?
                (lambda () (acc 42))
                "webracket-impersonator-property-accessor"
                "impersonator-property?"
                "given: 42")))))
 (list "chaperone-procedure rejects invalid contracts"
       (and
        (catch-contract/contains?
         (lambda () (chaperone-procedure 42 #f))
         "chaperone-procedure"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-procedure p2 42))
         "chaperone-procedure"
         "(or/c procedure? #f)"
         "given: 42")))
 (list "unsafe procedure chaperones reject invalid contracts"
       (and
        (catch-contract/contains?
         (lambda () (unsafe-chaperone-procedure 42 p2))
         "unsafe-chaperone-procedure"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (unsafe-chaperone-procedure p2 42))
         "unsafe-chaperone-procedure"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (unsafe-impersonate-procedure 42 p2))
         "unsafe-impersonate-procedure"
         "procedure?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (unsafe-impersonate-procedure p2 42))
         "unsafe-impersonate-procedure"
	         "procedure?"
	         "given: 42")))
 (list "chaperone validators reject plain structs as non-procedures"
       (and
        (catch-contract/contains?
         (lambda () (chaperone-procedure (impersonator-plain-given) #f))
         "chaperone-procedure"
         "procedure?"
         "given:")
        (catch-contract/contains?
         (lambda () (chaperone-procedure p2 (impersonator-plain-given)))
         "chaperone-procedure"
         "(or/c procedure? #f)"
         "given:")
        (catch-contract/contains?
         (lambda () (unsafe-chaperone-procedure (impersonator-plain-given) p2))
         "unsafe-chaperone-procedure"
         "procedure?"
         "given:")
        (catch-contract/contains?
         (lambda () (chaperone-vector (vector 1) (impersonator-plain-given) #f))
         "chaperone-vector"
         "(or/c (procedure-arity-includes/c 3) #f)"
         "given:")
        (catch-contract/contains?
         (lambda () (chaperone-box (box 1) (impersonator-plain-given) p2))
         "chaperone-box"
         "(procedure-arity-includes/c 2)"
         "given:")
        (catch-contract/contains?
         (lambda () (chaperone-hash (hash) p2 (impersonator-plain-given) p3 p3))
         "chaperone-hash"
         "(procedure-arity-includes/c 3)"
         "given:")))
 (list "chaperone-vector rejects invalid interposers"
       (and
        (catch-contract/contains?
         (lambda () (chaperone-vector 42 #f #f))
         "chaperone-vector"
         "vector?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-vector (vector 1) 42 #f))
         "chaperone-vector"
         "(or/c (procedure-arity-includes/c 3) #f)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-vector (vector 1) #f 42))
         "chaperone-vector"
         "(or/c (procedure-arity-includes/c 3) #f)"
         "given: 42")))
 (list "chaperone-box rejects invalid interposers"
       (and
        (catch-contract/contains?
         (lambda () (chaperone-box 42 p2 p2))
         "chaperone-box"
         "box?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-box (box 1) 42 p2))
         "chaperone-box"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-box (box 1) p2 #f))
         "chaperone-box"
         "(procedure-arity-includes/c 2)"
         "given: #f")))
 (list "chaperone-hash rejects invalid interposers"
       (and
        (catch-contract/contains?
         (lambda () (chaperone-hash 42 p2 p3 p3 p3))
         "chaperone-hash"
         "hash?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-hash (hash) 42 p3 p3 p3))
         "chaperone-hash"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-hash (hash) p2 42 p3 p3))
         "chaperone-hash"
         "(procedure-arity-includes/c 3)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-hash (hash) p2 p3 42 p3))
         "chaperone-hash"
         "(procedure-arity-includes/c 2)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (chaperone-hash (hash) p2 p3 p2 42))
         "chaperone-hash"
         "(procedure-arity-includes/c 2)"
         "given: 42")))
 (list "identity chaperone bridges still succeed"
       (let ([v (vector 1)]
             [b (box 1)]
             [h (hash)])
         (and (eq? (chaperone-vector v #f #f) v)
              (eq? (chaperone-vector v p3 p3) v)
              (eq? (chaperone-box b p2 p2) b)
              (eq? (chaperone-hash h p2 p3 p2 p2) h)
              (eq? (chaperone-procedure p2 #f) p2)
              (eq? (chaperone-procedure p2 p3) p3)))))
