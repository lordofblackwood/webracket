;; Focused no-stdlib generated-output checks for output-port wrapper errors.
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

(struct sink (port) #:property prop:output-port 0)
(struct port-handler-plain ())

(define port-handler-plain-given
  "given: #(struct port-handler-plain)")
(define too-large-port-index 536870912)

(list
 (list "basic output port contracts are catchable"
       (and
        (catch-contract/contains?
         (lambda () (current-output-port 42))
         "current-output-port"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (current-error-port 42))
         "current-error-port"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (flush-output 42))
         "flush-output"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (close-output-port 42))
         "close-output-port"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (port-writes-atomic? 42))
         "port-writes-atomic?"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (port-writes-special? 42))
         "port-writes-special?"
         "output-port?"
         "given: 42")))
 (list "closed output port location errors are catchable"
       (let ([port (open-output-string)])
         (close-output-port port)
         (and
          (catch-fail/contains?
           (lambda () (port-count-lines! port))
           "port-count-lines!"
           "output port is closed")
          (equal? (port-counts-lines? port) #f)
          (catch-fail/contains?
           (lambda () (file-position* port))
           "file-position*"
           "output port is closed")
          (catch-fail/contains?
           (lambda () (port-next-location port))
           "port-next-location"
           "output port is closed")
          (catch-fail/contains?
           (lambda () (flush-output port))
           "flush-output"
           "output port is closed"))))
 (list "call-with-output-string procedure errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (call-with-output-string 42))
         "call-with-output-string"
         "(output-port? . -> . any)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (call-with-output-string (lambda () 'bad)))
         "call-with-output-string"
         "(output-port? . -> . any)"
         "given:")))
 (list "make-output-port constructor contract errors are catchable"
       (and
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt 42 (lambda () (void))))
         "make-output-port"
         "(or/c output-port? (procedure-arity-includes/c 5))"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom
                                      always-evt
                                      (port-handler-plain)
                                      (lambda () (void))))
         "make-output-port"
         "(or/c output-port? (procedure-arity-includes/c 5))"
         port-handler-plain-given)
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) 42))
         "make-output-port"
         "(procedure-arity-includes/c 0)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda (x) (void))))
         "make-output-port"
         "(procedure-arity-includes/c 0)"
         "given:")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom 42 (lambda (bs start end nonblock? breakable?) 0) (lambda () (void))))
         "make-output-port"
         "evt?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda () (void)) 42))
         "make-output-port"
         "output-port?"
         "(procedure-arity-includes/c 3)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda () (void)) #f 42))
         "make-output-port"
         "(procedure-arity-includes/c 3)"
         "#f"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda () (void)) #f #f 42))
         "make-output-port"
         "(procedure-arity-includes/c 1)"
         "#f"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda () (void)) #f #f #f 42))
         "make-output-port"
         "(procedure-arity-includes/c 0)"
         "#f"
         "given: 42")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda () (void)) #f #f #f #f #f))
         "make-output-port"
         "(procedure-arity-includes/c 0)"
         "given: #f")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom always-evt (lambda (bs start end nonblock? breakable?) 0) (lambda () (void)) #f #f #f #f void #t))
         "make-output-port"
         "exact-positive-integer?"
         "port?"
         "(procedure-arity-includes/c 0)"
         "given: #t")
        (catch-contract/contains?
         (lambda () (make-output-port 'custom
                                      always-evt
                                      (lambda (bs start end nonblock? breakable?) 0)
                                      (lambda () (void))
                                      #f
                                      #f
                                      #f
                                      #f
                                      void
                                      1
                                      (lambda () 'block)))
         "make-output-port"
         "(procedure-arity-includes/c 0)"
         "(procedure-arity-includes/c 1)"
         "given:")))
 (list "make-output-port preserves bignum init position"
       (let ([port (make-output-port 'custom
                                     always-evt
                                     (lambda (bs start end nonblock? breakable?) 0)
                                     (lambda () (void))
                                     #f
                                     #f
                                     #f
                                     #f
                                     (lambda () (void))
                                     too-large-port-index)])
         (let-values ([(line col pos) (port-next-location port)])
           (and (not line)
                (not col)
                (= pos too-large-port-index)))))
 (list "default output handlers validate output ports with who"
       (and
        (catch-contract/contains?
         (lambda () ((port-write-handler (open-output-string)) 'value 42))
         "default-port-write-handler"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () ((port-display-handler (open-output-string)) 'value 42))
         "default-port-display-handler"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () ((port-print-handler (open-output-string)) 'value 42 0))
         "default-port-print-handler"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () ((port-print-handler (open-output-string)) 'value (open-output-string) 2))
         "default-port-print-handler"
         "(or/c 0 1)"
         "given: 2")))
 (list "port handler setters reject plain structs as non-procedures"
       (and
        (catch-contract/contains?
         (lambda () (port-write-handler (open-output-string)
                                        (port-handler-plain)))
         "port-write-handler"
         "procedure?"
         port-handler-plain-given)
        (catch-contract/contains?
         (lambda () (port-display-handler (open-output-string)
                                          (port-handler-plain)))
         "port-display-handler"
         "procedure?"
         port-handler-plain-given)
        (catch-contract/contains?
         (lambda () (port-print-handler (open-output-string)
                                        (port-handler-plain)))
         "port-print-handler"
         "procedure?"
         port-handler-plain-given)))
 (list "single byte and char writers reject bad arguments with who"
       (and
        (catch-contract/contains?
         (lambda () (write-byte 'bad (open-output-bytes)))
         "write-byte"
         "byte?"
         "given: 'bad")
        (catch-contract/contains?
         (lambda () (write-byte -1 (open-output-bytes)))
         "write-byte"
         "byte?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (write-byte 256 (open-output-bytes)))
         "write-byte"
         "byte?"
         "given: 256")
        (catch-contract/contains?
         (lambda () (write-byte 65 42))
         "write-byte"
         "output-port?"
         "given: 42")
        (catch-contract/contains?
         (lambda () (write-char 65 (open-output-string)))
         "write-char"
         "char?"
         "given: 65")
        (catch-contract/contains?
         (lambda () (write-char #\A 42))
         "write-char"
         "output-port?"
         "given: 42")))
 (list "basic output port contracts use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(number? v) "CUSTOM-NUMBER"]
              [(boolean? v) "CUSTOM-BOOLEAN"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (current-output-port 42))
                     "current-output-port"
                     "output-port?"
                     "given: CUSTOM-NUMBER")
                    (catch-contract/contains?
                     (lambda () (write-byte 65 #f))
                     "write-byte"
                     "output-port?"
                     "given: CUSTOM-BOOLEAN")
                    (catch-contract/contains?
                     (lambda () (write-char 65 (open-output-string)))
                     "write-char"
                     "char?"
                     "given: CUSTOM-NUMBER"))])
           (error-value->string-handler old)
           ok)))
 (list "get-output-bytes errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (get-output-bytes 42))
         "get-output-bytes"
         "(and/c output-port? string-port?)"
         "given: 42")
        (catch-contract/contains?
         (lambda () (get-output-bytes (open-output-bytes) #f -1))
         "get-output-bytes"
         "exact-nonnegative-integer?"
         "given: -1")
        (catch-contract/contains?
         (lambda () (get-output-bytes (open-output-bytes) #f 0 -1))
         "get-output-bytes"
         "(or/c exact-nonnegative-integer? #f)"
         "given: -1")
        (catch-contract/contains?
         (lambda ()
           (let ([port (open-output-bytes)])
             (write-bytes #"abc" port)
             (get-output-bytes port #f 4)))
         "get-output-bytes"
         "starting index is out of range")
        (catch-contract/contains?
         (lambda ()
           (let ([port (open-output-bytes)])
             (write-bytes #"abc" port)
             (get-output-bytes port #f too-large-port-index)))
         "get-output-bytes"
         "starting index is out of range")
        (catch-contract/contains?
         (lambda ()
           (let ([port (open-output-bytes)])
             (write-bytes #"abc" port)
             (get-output-bytes port #f 1 4)))
         "get-output-bytes"
         "ending index is out of range")
        (catch-contract/contains?
         (lambda ()
           (let ([port (open-output-bytes)])
             (write-bytes #"abc" port)
             (get-output-bytes port #f 1 too-large-port-index)))
         "get-output-bytes"
         "ending index is out of range")))
 (list "write-bytes discards unusable prop:output-port wrappers"
       (and (output-port? (sink 42))
            (equal? (write-bytes #"abc" (sink 42)) 3)
            (equal? (write-bytes #"abc" (sink 42) 1 3) 2)))
 (list "write-bytes still validates ranges for discard wrappers"
       (catch-contract/contains?
        (lambda () (write-bytes #"abc" (sink 42) 4))
        "write-bytes"
        "starting index is out of range"))
 (list "output byte/string bignum range errors are catchable with who"
       (and
        (catch-contract/contains?
         (lambda () (write-bytes #"abc" (sink 42) too-large-port-index))
         "write-bytes"
         "starting index is out of range")
        (catch-contract/contains?
         (lambda () (write-bytes #"abc" (sink 42) 0 too-large-port-index))
         "write-bytes"
         "ending index is out of range")
        (catch-contract/contains?
         (lambda () (write-string "abc" (open-output-string) too-large-port-index))
         "write-string"
         "starting index is out of range")
        (catch-contract/contains?
         (lambda () (write-string "abc" (open-output-string) 0 too-large-port-index))
         "write-string"
         "ending index is out of range")))
 (list "output byte/string range errors use error-value->string-handler"
       (let ([old (error-value->string-handler)])
         (error-value->string-handler
          (lambda (v _width)
            (cond
              [(bytes? v) "CUSTOM-BYTES"]
              [(string? v) "CUSTOM-STRING"]
              [else "CUSTOM-VALUE"])))
         (let ([ok (and
                    (catch-contract/contains?
                     (lambda () (write-bytes #"abc" (sink 42) 4))
                     "write-bytes"
                     "starting index is out of range"
                     "byte string:"
                     "CUSTOM-BYTES")
                    (catch-contract/contains?
                     (lambda () (write-string "abc" (open-output-string) 4))
                     "write-string"
                     "starting index is out of range"
                     "byte string:"
                     "CUSTOM-STRING"))])
           (error-value->string-handler old)
           ok)))
 (list "write-bytes resolves prop:output-port wrappers with real targets"
       (let* ([underlying (open-output-bytes)]
              [wrapped (sink underlying)])
         (and (equal? (write-bytes #"abc" wrapped 1 3) 2)
              (equal? (get-output-bytes underlying) #"bc")))))
