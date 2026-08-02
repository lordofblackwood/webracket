;; Focused no-stdlib generated-output checks for thread/thread-cell errors.
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
 (list "thread predicate contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (thread-dead? 42))
                     "thread-dead?"
                     "thread?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (thread-running? 42))
                     "thread-running?"
                     "thread?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "thread-cell contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(boolean? v) "CUSTOM-BOOLEAN"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (thread-cell-ref #f))
                     "thread-cell-ref"
                     "thread-cell?"
                     "given: CUSTOM-BOOLEAN")
                    (catch-contract/contains?
                     (lambda () (thread-cell-set! #f 'value))
                     "thread-cell-set!"
                     "thread-cell?"
                     "given: CUSTOM-BOOLEAN"))])
           (error-value->string-handler old)
           ok)))
 (list "thread-group contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (current-thread-group 42))
                     "current-thread-group"
                     "thread-group?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (make-thread-group 42))
                     "make-thread-group"
                     "thread-group?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok))))
