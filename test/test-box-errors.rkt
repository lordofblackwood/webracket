;; Focused no-stdlib generated-output checks for box errors.
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
 (list "box accessors reject non-boxes with who"
       (and
        (catch-contract/contains?
         (lambda () (unbox 42))
         "unbox"
         "box?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (unbox* 42))
         "unbox*"
         "(and/c box? (not impersonator?))"
         "given: 42")))
 (list "box mutators reject non-boxes and immutable boxes with who"
       (and
        (catch-contract/contains?
         (lambda () (set-box! 42 'value))
         "set-box!"
         "(and/c box? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (set-box! (box-immutable 'value) 'new))
         "set-box!"
         "(and/c box? (not/c immutable?))"
         "given:")
        (catch-contract/contains?
         (lambda () (set-box*! 42 'value))
         "set-box*!"
         "(and/c box? (not immutable?) (not impersonator?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (set-box*! (box-immutable 'value) 'new))
         "set-box*!"
         "(and/c box? (not immutable?) (not impersonator?))"
         "given:")))
 (list "box-cas! rejects non-boxes and immutable boxes with who"
       (and
        (catch-contract/contains?
         (lambda () (box-cas! 42 'old 'new))
         "box-cas!"
         "(and/c box? (not/c immutable?))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (box-cas! (box-immutable 'old) 'old 'new))
         "box-cas!"
         "(and/c box? (not/c immutable?))"
         "given:")))
 (list "box contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (unbox 42))
                     "unbox"
                     "box?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (set-box! 42 'value))
                     "set-box!"
                     "(and/c box? (not/c immutable?))"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (box-cas! 42 'old 'new))
                     "box-cas!"
                     "(and/c box? (not/c immutable?))"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "weak-box-value rejects non-weak-boxes with who"
       (catch-contract/contains?
        (lambda () (weak-box-value 42))
        "weak-box-value"
        "weak-box?"
        "given: 42"))
 (list "box success cases still work"
       (let ([b (box 'old)]
             [wb (make-weak-box 'cached)])
         (and (box? b)
              (mutable-box? b)
              (not (immutable-box? b))
              (void? (set-box! b 'new))
              (equal? (unbox b) 'new)
              (not (box-cas! b 'old 'later))
              (box-cas! b 'new 'later)
              (equal? (unbox b) 'later)
              (weak-box? wb)
              (equal? (weak-box-value wb 'missing) 'cached)))))
