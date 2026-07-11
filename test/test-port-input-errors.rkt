;; Focused no-stdlib generated-output checks for input-port wrapper errors.
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

(define (proxy-input)
  (let ([base (open-input-string "abcd")])
    (make-input-port 'proxy base base (lambda () (void)))))

(list
 (list "make-input-port constructor contract errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (make-input-port 'custom 42 #f (lambda () (void))))
         "make-input-port"
         "(or/c (procedure-arity-includes/c 1) input-port?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (open-input-string "") 42 (lambda () (void))))
         "make-input-port"
         "(or/c (procedure-arity-includes/c 3) input-port? #f)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (open-input-string "") #f 42))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (lambda (bs) 0) #f (lambda (x) (void))))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "given:")))
 (list "single byte and char readers reject non-input ports with who"
       (and
        (catch-contract/contains?
         (lambda () (read-byte 42))
         "read-byte"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (read-char 42))
         "read-char"
         "input-port?"
         "given: 42")))
 (list "peek-bytes-avail! progress errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda ()
           (peek-bytes-avail! (make-bytes 4 0)
                              0
                              'progress
                              (open-input-bytes #"abcd")
                              0
                              2))
         "peek-bytes-avail!"
         "(or/c #f progress-evt?)"
         "given: 'progress")
        (catch-contract/contains?
         (lambda ()
           (peek-bytes-avail!* (make-bytes 4 0)
                               0
                               'progress
                               (open-input-bytes #"abcd")
                               0
                               2))
         "peek-bytes-avail!*"
         "(or/c #f progress-evt?)"
         "given: 'progress")))
 (list "custom input-port peek backends are catchable unsupported errors"
       (and
        (catch-unsupported/contains?
         (lambda ()
           (peek-bytes! (make-bytes 2 0) 0 (proxy-input) 0 2))
         "peek-bytes!"
         "only string-backed ports are supported by WebRacket")
        (catch-unsupported/contains?
         (lambda ()
           (peek-string! (make-string 2 #\_) 0 (proxy-input) 0 2))
         "peek-string!"
         "only string-backed ports are supported by WebRacket")
        (catch-unsupported/contains?
         (lambda ()
           (peek-bytes 1 0 (proxy-input)))
         "peek-bytes"
         "only string-backed ports are supported by WebRacket")
        (catch-unsupported/contains?
         (lambda ()
           (peek-string 1 0 (proxy-input)))
         "peek-string"
         "only string-backed ports are supported by WebRacket")))
 (list "reader stubs are catchable unsupported errors"
       (and
        (catch-unsupported/contains?
         (lambda () (read))
         "read"
         "Racket reader is not supported by WebRacket")
        (catch-unsupported/contains?
         (lambda () (read-syntax 'source (open-input-string "1")))
         "read-syntax"
         "Racket reader is not supported by WebRacket"))))
