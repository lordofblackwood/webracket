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
 (list "uninterruptible lock success still works"
       (let ([lock (unsafe-make-uninterruptible-lock)])
         (and (void? (unsafe-uninterruptible-lock-acquire lock))
              (void? (unsafe-uninterruptible-lock-release lock))))))
