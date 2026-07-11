;; Focused no-stdlib generated-output checks for system/runtime helper errors.
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
 (list "system-type rejects invalid modes with who"
       (and
        (catch-contract/contains?
         (lambda () (system-type 'bad))
         "system-type"
         "(or/c 'os 'os* 'arch"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (system-type 42))
         "system-type"
         "(or/c 'os 'os* 'arch"
         "given: 42")))
 (list "get-installation-name rejects non-hash configuration with who"
       (catch-contract/contains?
        (lambda () (get-installation-name 42))
        "get-installation-name"
        "hash?"
        "given: 42"))
 (list "system helper success cases still work"
       (and (equal? (system-type) 'unix)
            (equal? (system-type 'os) 'unix)
            (equal? (system-type 'arch) 'wasm32)
            (equal? (system-type 'word) 32)
            (string? (system-type 'machine))
            (string? (get-installation-name))
            (equal? (get-installation-name (hash 'installation-name "custom"))
                    "custom"))))
