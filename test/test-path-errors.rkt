;; Focused no-stdlib generated-output checks for path errors.
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
 (list "string->path type errors are catchable with who"
       (catch-contract/contains?
        (lambda () (string->path 42))
        "string->path"
        "string?"
        "given: 42"))
 (list "string->path-element type errors are catchable with who"
       (catch-contract/contains?
        (lambda () (string->path-element 42))
        "string->path-element"
        "string?"
        "given: 42"))
 (list "string->some-system-path type errors are catchable with who"
       (catch-contract/contains?
        (lambda () (string->some-system-path 42 'unix))
        "string->some-system-path"
        "string?"
        "given: 42"))
 (list "path string conversion successes still work"
       (and (equal? (path->string (string->path "app/main.rkt"))
                    "app/main.rkt")
            (equal? (path-element->string (string->path-element "main.rkt"))
                    "main.rkt")
            (equal? (some-system-path->string (string->some-system-path "app/main.rkt" 'unix))
                    "app/main.rkt"))))
