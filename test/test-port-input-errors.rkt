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

(define (catch-fail/contains? thunk . needles)
  (let ([message
         (with-handlers ([exn:fail?
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

(struct port-input-plain ())

(define port-input-plain-given
  "given: #(struct port-input-plain)")

(list
 (list "basic input port contracts are catchable"
       (and
        (catch-contract/contains?
         (lambda () (current-input-port 42))
         "current-input-port"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (close-input-port 42))
         "close-input-port"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (port-count-lines! 42))
         "port-count-lines!"
         "port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (port-counts-lines? 42))
         "port-counts-lines?"
         "port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (file-position* 42))
         "file-position*"
         "port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (port-next-location 42))
         "port-next-location"
         "port?"
         "given: 42")))
 (list "basic input port contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(boolean? v) "CUSTOM-BOOLEAN"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (current-input-port 42))
                     "current-input-port"
                     "input-port?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (close-input-port #f))
                     "close-input-port"
                     "input-port?"
                     "given: CUSTOM-BOOLEAN")
                    (catch-contract/contains?
                     (lambda () (read-byte #f))
                     "read-byte"
                     "input-port?"
                     "given: CUSTOM-BOOLEAN")
                    (catch-contract/contains?
                     (lambda () (read-char 42))
                     "read-char"
                     "input-port?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "input string/byte port constructors reject bad source values"
       (and
        (catch-contract/contains?
         (lambda () (open-input-bytes 42))
         "open-input-bytes"
         "bytes?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (open-input-string 42))
         "open-input-string"
         "string?"
         "given: 42")))
 (list "closed input port location errors are catchable"
       (let ([port (open-input-string "abc")])
         (close-input-port port)
         (and
          (catch-fail/contains?
           (lambda () (port-count-lines! port))
           "port-count-lines!"
           "input port is closed")
          (equal? (port-counts-lines? port) #f)
          (catch-fail/contains?
           (lambda () (file-position* port))
           "file-position*"
           "input port is closed")
          (catch-fail/contains?
           (lambda () (port-next-location port))
           "port-next-location"
           "input port is closed"))))
 (list "make-input-port constructor contract errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (make-input-port 'custom 42 #f (lambda () (void))))
         "make-input-port"
         "(or/c (procedure-arity-includes/c 1) input-port?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom
                                     (port-input-plain)
                                     #f
                                     (lambda () (void))))
         "make-input-port"
         "(or/c (procedure-arity-includes/c 1) input-port?)"
         port-input-plain-given)
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (open-input-string "") 42 (lambda () (void))))
         "make-input-port"
         "(or/c (procedure-arity-includes/c 3) input-port? #f)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom
                                     (open-input-string "")
                                     (port-input-plain)
                                     (lambda () (void))))
         "make-input-port"
         "(or/c (procedure-arity-includes/c 3) input-port? #f)"
         port-input-plain-given)
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (open-input-string "") #f 42))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (lambda (bs) 0) #f (lambda (x) (void))))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "given:")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (lambda (bs) 0) #f (lambda () (void)) 42))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "#f"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (lambda (bs) 0) #f (lambda () (void)) #f 42))
         "make-input-port"
         "(procedure-arity-includes/c 3)"
         "#f"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (lambda (bs) 0) #f (lambda () (void)) #f #f 42))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "#f"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (lambda (bs) 0) #f (lambda () (void)) #f #f #f 42))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "#f"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom (lambda (bs) 0) #f (lambda () (void)) #f #f #f void #t))
         "make-input-port"
         "exact-positive-integer?"
         "port?"
         "(procedure-arity-includes/c 0)"
         "given: #t")
        (catch-contract/contains?
         (lambda () (make-input-port 'custom
                                     (lambda (bs) 0)
                                     #f
                                     (lambda () (void))
                                     #f
                                     #f
                                     #f
                                     void
                                     1
                                     (lambda () 'block)))
         "make-input-port"
         "(procedure-arity-includes/c 0)"
         "(procedure-arity-includes/c 1)"
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
 (list "special input wrappers validate optional contracts with who"
       (and
        (catch-contract/contains?
         (lambda () (read-byte-or-special 42))
         "read-byte-or-special"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (read-char-or-special 42))
         "read-char-or-special"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (read-byte-or-special (open-input-string "") 42))
         "read-byte-or-special"
         "(or/c #f (procedure-arity-includes/c 1))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (read-char-or-special (open-input-string "") (lambda () 0)))
         "read-char-or-special"
         "(or/c #f (procedure-arity-includes/c 1))"
         "given:")))
 (list "peek special wrappers validate optional contracts with who"
       (and
        (catch-contract/contains?
         (lambda () (peek-byte-or-special 42))
         "peek-byte-or-special"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (peek-char-or-special 42))
         "peek-char-or-special"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (peek-byte-or-special (open-input-string "") -1))
         "peek-byte-or-special"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (peek-char-or-special (open-input-string "") -1))
         "peek-char-or-special"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (peek-byte-or-special (open-input-string "") 0 'progress #f))
         "peek-byte-or-special"
         "(or/c #f evt?)"
         "given: 'progress")
        (catch-contract/contains?
         (lambda () (peek-byte-or-special (open-input-string "") 0 #f 42))
         "peek-byte-or-special"
         "(or/c (any/c -> any/c) #f 'special)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (peek-char-or-special (open-input-string "") 0 (lambda () 0)))
         "peek-char-or-special"
         "(or/c (any/c -> any/c) #f 'special)"
         "given:")))
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
 (list "input byte range errors use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(bytes? v) "CUSTOM-BYTES"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (catch-contract/contains?
                    (lambda ()
                      (read-bytes! (make-bytes 3 0)
                                   (open-input-bytes #"abc")
                                   4))
                    "read-bytes!"
                    "starting index is out of range"
                    "byte string:"
                    "CUSTOM-BYTES")])
           (error-value->string-handler old)
           ok)))
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
 (list "reader stubs validate input ports before unsupported errors"
       (and
        (catch-contract/contains?
         (lambda () (read 42))
         "read"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (read-syntax 'source 42))
         "read-syntax"
         "input-port?"
         "given: 42")))
 (list "default reader handlers validate input ports with who"
       (and
        (catch-contract/contains?
         (lambda () ((current-read-interaction) 'source 42))
         "default-read-interaction"
         "input-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () ((port-read-handler (open-input-string "")) 42))
         "default-port-read-handler"
         "input-port?"
         "given: 42")))
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
