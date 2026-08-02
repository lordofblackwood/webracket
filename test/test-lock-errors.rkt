;; Focused no-stdlib generated-output checks for uninterruptible-lock errors.
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
 (list "uninterruptible lock argument errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (unsafe-uninterruptible-lock-acquire 42))
         "unsafe-uninterruptible-lock-acquire"
         "uninterruptible-lock?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (unsafe-uninterruptible-lock-release 42))
         "unsafe-uninterruptible-lock-release"
         "uninterruptible-lock?"
         "given: 42")))
 (list "uninterruptible lock contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (unsafe-uninterruptible-lock-acquire 42))
                     "unsafe-uninterruptible-lock-acquire"
                     "uninterruptible-lock?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (unsafe-uninterruptible-lock-release 42))
                     "unsafe-uninterruptible-lock-release"
                     "uninterruptible-lock?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "uninterruptible lock success still works"
       (let ([lock (unsafe-make-uninterruptible-lock)])
         (and (void? (unsafe-uninterruptible-lock-acquire lock))
              (void? (unsafe-uninterruptible-lock-release lock))))))
