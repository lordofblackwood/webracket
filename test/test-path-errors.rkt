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
 (list "bytes->path source type errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (bytes->path 'bad))
         "bytes->path"
         "bytes?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (bytes->path-element 'bad))
         "bytes->path-element"
         "bytes?"
         "given: 'bad")))
 (list "bytes->path convention errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (bytes->path #"app/main.rkt" 42))
         "bytes->path"
         "(or/c"
         "'unix"
         "given: 42")
        (catch-contract/contains?
         (lambda () (bytes->path #"app/main.rkt" 'macosx))
         "bytes->path"
         "(or/c"
         "'unix"
         "macosx")))
 (list "bytes->path byte-string content errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (bytes->path #""))
         "bytes->path"
         "byte string is empty")
        (catch-contract/contains?
         (lambda () (bytes->path (bytes 97 0 98)))
         "bytes->path"
         "nul character"
         "byte string:")))
 (list "string->path path string content errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (string->path ""))
         "string->path"
         "path string is empty")
        (catch-contract/contains?
         (lambda () (string->path (string #\a #\nul #\b)))
         "string->path"
         "nul character"
         "path string:")))
 (list "path-element constructors reject empty path strings and bytes even with false mode"
       (and
        (catch-contract/contains?
         (lambda () (string->path-element "" #t))
         "string->path-element"
         "path string is empty")
        (catch-contract/contains?
         (lambda () (string->path-element (string #\a #\nul #\b) #t))
         "string->path-element"
         "nul character"
         "path string:")
        (catch-contract/contains?
         (lambda () (bytes->path-element #"" 'unix #t))
         "bytes->path-element"
         "byte string is empty")
        (catch-contract/contains?
         (lambda () (bytes->path-element (bytes 97 0 98) 'unix #t))
         "bytes->path-element"
         "nul character"
         "byte string:")))
 (list "path content errors use error-value->string-handler for rendered values"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(bytes? v) "CUSTOM-BYTES"]
              [(string? v) "CUSTOM-STRING"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (bytes->path (bytes 97 0 98)))
                     "bytes->path"
                     "nul character"
                     "byte string:"
                     "CUSTOM-BYTES")
                    (catch-contract/contains?
                     (lambda () (string->path (string #\a #\nul #\b)))
                     "string->path"
                     "nul character"
                     "path string:"
                     "CUSTOM-STRING")
                    (catch-contract/contains?
                     (lambda () (path->complete-path ""))
                     "path->complete-path"
                     "given:"
                     "CUSTOM-STRING")
                    (catch-contract/contains?
                     (lambda () (build-path "/app" "/abs"))
                     "build-path"
                     "absolute path cannot be added to a path"
                     "absolute path:"
                     "CUSTOM-STRING"))])
           (error-value->string-handler old)
           ok)))
 (list "bytes->path-element convention errors are catchable with who"
       (catch-contract/contains?
        (lambda () (bytes->path-element #"main.rkt" 42))
        "bytes->path-element"
        "(or/c"
        "'unix"
        "given: 42"))
 (list "string->some-system-path convention errors are catchable with who"
       (catch-contract/contains?
        (lambda () (string->some-system-path "app/main.rkt" 42))
        "string->some-system-path"
        "(or/c"
        "'unix"
        "given: 42"))
 (list "string->some-system-path delegates path content errors to bytes->path"
       (and
        (catch-contract/contains?
         (lambda () (string->some-system-path "" 'unix))
         "bytes->path"
         "byte string is empty")
        (catch-contract/contains?
         (lambda () (string->some-system-path (string #\a #\nul #\b) 'unix))
         "bytes->path"
         "nul character"
         "byte string:")))
 (list "path accessors type errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (path->bytes 42))
         "path->bytes"
         "path-for-some-system?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (path->string 42))
         "path->string"
         "path?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (some-system-path->string 42))
         "some-system-path->string"
         "path-for-some-system?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (path->string (bytes->path #"x" 'windows)))
         "path->string"
         "path?")))
 (list "path-string consumers reject invalid path strings with who"
       (and
        (catch-contract/contains?
         (lambda () (path->complete-path 42))
         "path->complete-path"
         "(or/c path-string? path-for-some-system?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (path->complete-path ""))
         "path->complete-path"
         "(or/c path-string? path-for-some-system?)"
         "given: \"\"")
        (catch-contract/contains?
         (lambda () (path->directory-path 42))
         "path->directory-path"
         "(or/c path-string? path-for-some-system?)"
         "given: 42")))
 (list "build-path rejects invalid path parts with who"
       (and
        (catch-contract/contains?
         (lambda () (build-path 42))
         "build-path"
         "(or/c path-string? path-for-some-system? 'up 'same)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (build-path ""))
         "build-path"
         "(or/c path-string? path-for-some-system? 'up 'same)"
         "given: \"\"")))
 (list "build-path rejects absolute paths after the first part with who"
       (and
        (catch-contract/contains?
         (lambda () (build-path "/app" "/abs"))
         "build-path"
         "absolute path cannot be added to a path"
         "absolute path: \"/abs\"")
        (catch-contract/contains?
         (lambda () (build-path/convention-type 'unix "/app" "/abs"))
         "build-path/convention-type"
         "absolute path cannot be added to a path"
         "absolute path: \"/abs\"")))
 (list "normalize-path rejects invalid wrt paths with who"
       (and
        (catch-contract/contains?
         (lambda () (normalize-path "x" 42))
         "normalize-path"
         "(and/c path-string? complete-path?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (normalize-path "x" "rel"))
         "normalize-path"
         "(and/c path-string? complete-path?)"
         "given: \"rel\"")))
 (list "path-only rejects invalid path strings with who"
       (and
        (catch-contract/contains?
         (lambda () (path-only 42))
         "path-only"
         "(or/c path-string? path-for-some-system?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (path-only ""))
         "path-only"
         "(or/c path-string? path-for-some-system?)"
         "given: \"\"")))
 (list "shrink-path-wrt rejects non-path inputs with who"
       (catch-contract/contains?
        (lambda () (shrink-path-wrt 42 null))
        "shrink-path-wrt"
        "path?"
        "given: 42"))
 (list "current-directory parameters complete relative paths"
       (let ([original-current (current-directory)]
             [original-user    (current-directory-for-user)])
         (let ([ok (and (void? (current-directory "rel/"))
                        (equal? (path->string (current-directory))
                                "/app/rel/")
                        (void? (current-directory original-current))
                        (void? (current-directory-for-user "user/"))
                        (equal? (path->string (current-directory-for-user))
                                "/app/user/"))])
           (current-directory original-current)
           (current-directory-for-user original-user)
           ok)))
 (list "current-directory parameters reject non-path values with who"
       (and
        (catch-contract/contains?
         (lambda () (current-directory 42))
         "current-directory"
         "(or/c path-string? path-for-some-system?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (current-directory-for-user 42))
         "current-directory-for-user"
         "(or/c path-string? path-for-some-system?)"
         "given: 42")))
 (list "path string conversion successes still work"
       (and (equal? (path->string (string->path "app/main.rkt"))
                    "app/main.rkt")
            (equal? (path-element->string (string->path-element "main.rkt"))
                    "main.rkt")
            (equal? (some-system-path->string (string->some-system-path "app/main.rkt" 'unix))
                    "app/main.rkt"))))
