#lang racket/base

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         "../test/number-tower/cases.rkt")

(provide default-racket-cs-path
         default-webracket-racket-path
         query-number-tower-cs-info
         validate-number-tower-cs-info!
         run-number-tower-cases
         run-number-tower-oracle
         flonum-ulp-distance
         records-match?
         number-tower-self-check-mismatch-detected?
         print-number-tower-summary
         summary-failure-count
         summary-recorded-count
         (struct-out number-tower-cs-info)
         (struct-out number-tower-outcome)
         (struct-out number-tower-summary))

(struct number-tower-cs-info
  (path version vm)
  #:transparent)

(struct number-tower-outcome
  (case cs-record webracket-record status message)
  #:transparent)

(struct number-tower-summary
  (cs-info outcomes)
  #:transparent)

(define default-flonum-ulps 4)
(define sign-bit-mask #x8000000000000000)
(define all-bits-mask #xffffffffffffffff)

(define default-cs-executable
  "/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket")

(define application-racket-cs-executable
  "/Applications/Racket v9.3.0.2/bin/racket")

(define-runtime-path repo-root* "..")

(define repo-root (simplify-path repo-root*))
(define number-tower-temp-root (build-path repo-root "tmp"))

;; ensure-number-tower-temp-root! : -> void?
;;   Ensure number-tower scratch files stay inside the repository tmp/ directory.
(define (ensure-number-tower-temp-root!)
  (make-directory* number-tower-temp-root))

;; make-number-tower-temporary-file : string? -> path?
;;   Create a temporary file below tmp/ for oracle subprocess capture.
(define (make-number-tower-temporary-file template)
  (ensure-number-tower-temp-root!)
  (make-temporary-file template #:base-dir number-tower-temp-root))

;; make-number-tower-temporary-directory : string? -> path?
;;   Create a temporary directory below tmp/ for generated oracle programs.
(define (make-number-tower-temporary-directory template)
  (ensure-number-tower-temp-root!)
  (make-temporary-directory template #:base-dir number-tower-temp-root))

;; default-racket-cs-path : -> path-string?
;;   Return the configured Racket CS executable path for oracle runs.
(define (default-racket-cs-path)
  (or (getenv "WEBRACKET_RACKET_CS")
      (and (file-exists? application-racket-cs-executable)
           application-racket-cs-executable)
      default-cs-executable))

;; default-webracket-racket-path : -> path-string?
;;   Return the Racket executable used to compile and run WebRacket snippets.
(define (default-webracket-racket-path)
  (or (getenv "WEBRACKET_RACKET")
      (let ([p (find-executable-path "racket")])
        (and p (path->string p)))
      default-cs-executable))

;; call-with-temp-directory : string? (path? -> any/c) -> any/c
;;   Create a temporary directory, pass it to thunk, and remove it afterward.
(define (call-with-temp-directory prefix thunk)
  (define dir (make-number-tower-temporary-directory prefix))
  (dynamic-wind
    void
    (lambda () (thunk dir))
    (lambda ()
      (with-handlers ([exn:fail? void])
        (delete-directory/files dir)))))

;; read-single-datum : string? -> any/c
;;   Read exactly one datum from text.
(define (read-single-datum text)
  (define in (open-input-string text))
  (define datum (read in))
  (when (eof-object? datum)
    (error 'read-single-datum "expected one datum, got empty output"))
  (define trailing (read in))
  (unless (eof-object? trailing)
    (error 'read-single-datum "expected one datum, got trailing output: ~s" trailing))
  datum)

;; run-command/capture : path? path-string? (listof string?) -> (values exact-integer? string? string?)
;;   Run a subprocess with stdout and stderr captured in temporary files.
(define (run-command/capture cwd command args #:timeout-seconds [timeout-seconds 60])
  (define stdout-path (make-number-tower-temporary-file "number-tower-stdout-~a.txt"))
  (define stderr-path (make-number-tower-temporary-file "number-tower-stderr-~a.txt"))
  (define stdout (open-output-file stdout-path #:exists 'truncate))
  (define stderr (open-output-file stderr-path #:exists 'truncate))
  (define-values (proc child-out child-in child-err)
    (parameterize ([current-directory cwd])
      (apply subprocess stdout #f stderr 'new command args)))
  (when child-out (close-input-port child-out))
  (when child-in (close-output-port child-in))
  (when child-err (close-input-port child-err))
  (define completed? (sync/timeout timeout-seconds proc))
  (unless completed?
    (subprocess-kill proc #t))
  (subprocess-wait proc)
  (close-output-port stdout)
  (close-output-port stderr)
  (define status (subprocess-status proc))
  (define stdout-text (file->string stdout-path))
  (define stderr-text (file->string stderr-path))
  (with-handlers ([exn:fail? void])
    (delete-file stdout-path))
  (with-handlers ([exn:fail? void])
    (delete-file stderr-path))
  (values (cond
            [(not completed?) 124]
            [(integer? status) status]
            [else 1])
          stdout-text
          stderr-text))

;; query-number-tower-cs-info : [path-string?] -> number-tower-cs-info?
;;   Ask the selected executable for its version and VM identity.
(define (query-number-tower-cs-info [cs-path (default-racket-cs-path)])
  (define-values (status stdout stderr)
    (run-command/capture
     repo-root
     cs-path
     (list "-e" "(write (list (version) (system-type 'vm)))")
     #:timeout-seconds 30))
  (unless (zero? status)
    (error 'query-number-tower-cs-info
           "could not query Racket executable ~a; status ~a\n~a~a"
           cs-path status stdout stderr))
  (match (read-single-datum stdout)
    [(list (? string? version) vm)
     (number-tower-cs-info cs-path version vm)]
    [other
     (error 'query-number-tower-cs-info
            "unexpected CS info payload: ~s" other)]))

;; validate-number-tower-cs-info! : number-tower-cs-info? -> void?
;;   Refuse non-CS VMs so BC behavior cannot become the oracle accidentally.
(define (validate-number-tower-cs-info! info)
  (unless (eq? (number-tower-cs-info-vm info) 'chez-scheme)
    (error 'validate-number-tower-cs-info!
           "WEBRACKET_RACKET_CS must be Racket CS; got VM ~s from ~a"
           (number-tower-cs-info-vm info)
           (number-tower-cs-info-path info))))

;; normalizer-expression : any/c -> any/c
;;   Build a source expression that normalizes one result or exception.
(define (normalizer-expression expr)
  `(letrec ([find-colon
             (lambda (s i n)
               (cond
                 [(>= i n) #f]
                 [(char=? (string-ref s i) #\:) i]
                 [else (find-colon s (+ i 1) n)]))]
            [message-who
             (lambda (s)
               (let ([i (find-colon s 0 (string-length s))])
                 (if i
                     (substring s 0 i)
                     #f)))]
            [string-codepoints
             (lambda (s)
               (let loop ([i 0])
                 (if (= i (string-length s))
                     '()
                     (cons (char->integer (string-ref s i))
                           (loop (+ i 1))))))]
            [exception-category
             (lambda (exn)
               (cond
                 [(exn:fail:contract? exn) 'contract]
                 [(exn:fail? exn) 'fail]
                 [else 'exn]))]
            [safe-number->string
             (lambda (z)
               (with-handlers ([exn:fail?
                                (lambda (exn)
                                  (list 'exception
                                        (exception-category exn)
                                        (message-who (exn-message exn))))])
                 (list 'text
                       (string-codepoints (number->string z)))))]
            [real-category
             (lambda (x)
               (cond
                 [(not (real? x)) 'non-real]
                 [(and (inexact? x) (eqv? x +nan.0)) 'nan]
                 [(and (inexact? x) (eqv? x -inf.0)) 'negative-infinity]
                 [(and (inexact? x) (eqv? x +inf.0)) 'positive-infinity]
                 [(and (inexact? x) (zero? x) (eqv? x -0.0)) 'negative-zero]
                 [(and (inexact? x) (zero? x)) 'positive-zero]
                 [else 'ordinary]))]
            [simple-value
             (lambda (v)
               (cond
                 [(boolean? v) (list 'boolean v)]
                 [(symbol? v) (list 'symbol v)]
                 [(string? v) (list 'string (string-codepoints v))]
                 [(void? v) (list 'void)]
                 [else (list 'unsupported-value)]))]
            [normalize-number
             (lambda (z depth)
               (list 'number
                     (safe-number->string z)
                     (number? z)
                     (complex? z)
                     (real? z)
                     (rational? z)
                     (integer? z)
                     (exact-integer? z)
                     (exact? z)
                     (inexact? z)
                     (fixnum? z)
                     (real-category z)
                     (if (and (number? z)
                              (not (real? z))
                              (< depth 2))
                         (list (normalize-number (real-part z) (+ depth 1))
                               (normalize-number (imag-part z) (+ depth 1)))
                         '())))]
            [normalize-value
             (lambda (v)
               (if (number? v)
                   (normalize-number v 0)
                   (simple-value v)))]
            [normalize-thunk
             (lambda (thunk)
               (with-handlers ([exn:fail?
                                (lambda (exn)
                                  (list 'exception
                                        (exception-category exn)
                                        (message-who (exn-message exn))
                                        (exn-message exn)))])
                 (list 'value (normalize-value (thunk)))))])
     (normalize-thunk (lambda () ,expr))))

;; cases-expression : (listof number-tower-case?) -> any/c
;;   Build a source expression that evaluates and records each selected case.
(define (cases-expression cases)
  `(list
    ,@(for/list ([c (in-list cases)])
        `(list ',(number-tower-case-id c)
               ,(normalizer-expression (number-tower-case-expr c))))))

;; write-cs-cases-program! : path? (listof number-tower-case?) -> void?
;;   Materialize one CS oracle program for all selected cases.
(define (write-cs-cases-program! path cases)
  (call-with-output-file path
    (lambda (out)
      (display "#lang racket/base\n" out)
      (display "(require racket/math)\n" out)
      (display "(require racket/fasl)\n" out)
      (write
       '(begin
          (define (number-tower-float-complex? x)
            (and (complex? x)
                 (not (real? x))
                 (flonum? (real-part x))
                 (flonum? (imag-part x))))

          (define number-tower-log2 (log 2.0))

          (define (number-tower-log1p x)
            (cond [(eqv? x +inf.0) +inf.0]
                  [else
                   (let ([u (+ 1.0 x)])
                     (if (= u 1.0)
                         x
                         (* (log u) (/ x (- u 1.0)))))]))

          (define (number-tower-flasinh-positive a)
            (cond [(< a 1e-8) a]
                  [(> a 1e154) (+ (log a) number-tower-log2)]
                  [else
                   (number-tower-log1p
                    (+ a (/ (* a a)
                            (+ 1.0 (sqrt (+ 1.0 (* a a)))))))]))

          (define (number-tower-flasinh x)
            (cond [(zero? x) x]
                  [(negative? x) (- (number-tower-flasinh-positive (- x)))]
                  [else (number-tower-flasinh-positive x)]))

          (define (number-tower-flacosh x)
            (if (< x 1.0)
                +nan.0
                (cond [(= x 1.0) 0.0]
                      [(> x 1e154) (+ (log x) number-tower-log2)]
                      [else
                       (number-tower-log1p
                        (+ (- x 1.0)
                           (* (sqrt (- x 1.0))
                              (sqrt (+ x 1.0)))))])))

          (define (number-tower-flatanh x)
            (cond [(= x 1.0) +inf.0]
                  [(= x -1.0) -inf.0]
                  [(or (< x -1.0) (> x 1.0)) +nan.0]
                  [else (* 0.5 (- (number-tower-log1p x)
                                  (number-tower-log1p (- x))))]))

          (define (number-tower-negated-flonum? x)
            (or (< x 0.0)
                (eqv? x -0.0)))

          (define number-tower-atanh-theta 3.351951982485649e153)
          (define number-tower-atanh-rho 2.983336292480083e-154)
          (define number-tower-pi/2 (atan 1.0 0.0))

          (define (number-tower-cflatanh-core x y)
            ;; Match Chez Scheme's Kahan-style cflatanh helper.
            (define ay (abs y))
            (cond
              [(or (> x number-tower-atanh-theta)
                   (> ay number-tower-atanh-theta))
               (make-rectangular
                (if (>= x ay)
                    (/ 1.0 (+ x (* (/ y x) y)))
                    (let ([r (/ x y)])
                      (/ r (+ y (* r x)))))
                (if (number-tower-negated-flonum? y)
                    number-tower-pi/2
                    (- number-tower-pi/2)))]
              [(= x 1.0)
               (define k (+ ay number-tower-atanh-rho))
               (make-rectangular
                (log (/ (sqrt (sqrt (+ 4.0 (* y y))))
                        (sqrt k)))
                (/ (+ number-tower-pi/2 (atan (/ k 2.0)))
                   (if (number-tower-negated-flonum? y) 2.0 -2.0)))]
              [else
               (define 1-x (- 1.0 x))
               (define k (let ([k (+ ay number-tower-atanh-rho)])
                           (* k k)))
               (make-rectangular
                (/ (number-tower-log1p
                    (/ (* 4.0 x)
                       (+ (* 1-x 1-x) k)))
                   4.0)
                (/ (atan (* 2.0 y)
                         (- (* 1-x (+ 1.0 x)) k))
                   -2.0))]))

          (define (number-tower-cflatanh z)
            (define x (real-part z))
            (define y (imag-part z))
            (if (number-tower-negated-flonum? x)
                (- (number-tower-cflatanh-core (- x) y))
                (number-tower-cflatanh-core x (- y))))

          (define (number-tower-cflacosh z)
            (let* ([z- (sqrt (- z 1.0))]
                   [z+ (sqrt (+ z 1.0))]
                   [a  (real-part z-)]
                   [b  (imag-part z-)]
                   [c  (real-part z+)]
                   [d  (imag-part z+)])
              (make-rectangular
               (number-tower-flasinh (+ (* a c) (* b d)))
               (* 2.0 (atan (/ b c))))))

          (define (asinh x)
            (cond [(flonum? x) (number-tower-flasinh x)]
                  [(eqv? x 0) 0]
                  [(real? x) (number-tower-flasinh (real->double-flonum x))]
                  [(number-tower-float-complex? x)
                   (/ (asin (* +i x)) +i)]
                  [else
                   (log (+ x (sqrt (+ (* x x) 1))))]))

          (define (acosh x)
            (cond [(flonum? x) (number-tower-flacosh x)]
                  [(eqv? x 1) 0]
                  [(and (real? x) (>= x 1))
                   (number-tower-flacosh (real->double-flonum x))]
                  [(number-tower-float-complex? x)
                   (number-tower-cflacosh x)]
                  [else
                   (log (+ x (* (sqrt (+ x 1)) (sqrt (- x 1)))))]))

          (define (atanh x)
            (cond [(flonum? x) (number-tower-flatanh x)]
                  [(eqv? x 0) 0]
                  [(real? x) (number-tower-flatanh (real->double-flonum x))]
                  [(number-tower-float-complex? x)
                   (number-tower-cflatanh x)]
                  [else
                   (* 1/2 (- (log (+ 1 x)) (log (- 1 x))))])))
       out)
      (newline out)
      (write `(begin
                (write ,(cases-expression cases))
                (newline))
             out)
      (newline out))
    #:exists 'truncate/replace))

;; write-webracket-cases-program! : path? (listof number-tower-case?) -> void?
;;   Materialize one WebRacket no-stdlib program for all selected cases.
(define (write-webracket-cases-program! path cases)
  (call-with-output-file path
    (lambda (out)
      (write (cases-expression cases) out)
      (newline out))
    #:exists 'truncate/replace))

;; records-list->hash : symbol? any/c -> hash?
;;   Convert a generated `(list (list id record) ...)` payload to a hash.
(define (records-list->hash who payload)
  (define h (make-hasheq))
  (for ([entry (in-list payload)])
    (match entry
      [(list (? symbol? id) record)
       (hash-set! h id record)]
      [_
       (error who "unexpected record entry: ~s" entry)]))
  h)

;; external-exception-records : (listof number-tower-case?) symbol? any/c -> hash?
;;   Return a hash that maps every case to the same external failure record.
(define (external-exception-records cases source failure)
  (for/hasheq ([c (in-list cases)])
    (values (number-tower-case-id c)
            (list 'external-exception source failure))))

;; run-cs-cases : (listof number-tower-case?) path-string? path? -> hash?
;;   Run selected cases under Racket CS and return id -> normalized record.
(define (run-cs-cases cases cs-path temp-dir)
  (define source (build-path temp-dir "cs-cases.rkt"))
  (write-cs-cases-program! source cases)
  (define-values (status stdout stderr)
    (run-command/capture
     repo-root
     cs-path
     (list (path->string source))
     #:timeout-seconds 20))
  (if (zero? status)
      (records-list->hash 'run-cs-cases (read-single-datum stdout))
      (external-exception-records cases
                                  'cs
                                  (list status (string-append stdout stderr)))))

;; run-webracket-cases : (listof number-tower-case?) path-string? path? -> hash?
;;   Run selected cases under WebRacket and return id -> normalized record.
(define (run-webracket-cases cases racket-path temp-dir)
  (define source (build-path temp-dir "wr-cases.rkt"))
  (define dest (build-path temp-dir "wr-out"))
  (make-directory* dest)
  (write-webracket-cases-program! source cases)
  (define-values (status stdout stderr)
    (run-command/capture
     repo-root
     racket-path
     (list "-S" (path->string (build-path repo-root "pkgs"))
           (path->string (build-path repo-root "webracket.rkt"))
           "--no-stdlib"
           "--no-io-format-provider"
           "--no-split-runtime"
           "-n"
           "-r"
           "--dest" (path->string dest)
           (path->string source))
     #:timeout-seconds 180))
  (if (zero? status)
      (with-handlers ([exn:fail?
                       (lambda (exn)
                         (external-exception-records
                          cases
                          'webracket-output
                          (list status (exn-message exn) stdout stderr)))])
        (records-list->hash 'run-webracket-cases (read-single-datum stdout)))
      (external-exception-records cases
                                  'webracket
                                  (list status (string-append stdout stderr)))))

;; record-ignore-fixnum-width : any/c -> any/c
;;   Mask the implementation-specific fixnum? slot in normalized number records.
(define (record-ignore-fixnum-width record)
  (match record
    [(list 'value v)
     (list 'value (record-ignore-fixnum-width v))]
    [(list 'number text number? complex? real? rational? integer?
           exact-integer? exact? inexact? _fixnum? real-category parts)
     (list 'number
           text
           number?
           complex?
           real?
           rational?
           integer?
           exact-integer?
           exact?
           inexact?
           'implementation-specific
           real-category
           (map record-ignore-fixnum-width parts))]
    [(? list? xs)
     (map record-ignore-fixnum-width xs)]
    [_
     record]))

;; codepoints->string : (listof exact-integer?) -> string?
;;   Rebuild a string from the normalizer's character-code representation.
(define (codepoints->string codepoints)
  (list->string (map integer->char codepoints)))

;; normalized-text->string : any/c -> (or/c string? #f)
;;   Extract the string payload from a normalized numeric text record.
(define (normalized-text->string text)
  (match text
    [(list 'text codepoints)
     (codepoints->string codepoints)]
    [_ #f]))

;; normalized-real->number : any/c -> (or/c number? #f)
;;   Parse a normalized real number record back into a host Racket number.
(define (normalized-real->number record)
  (match record
    [(list 'number text _number? _complex? #t _rational? _integer?
           _exact-integer? _exact? _inexact? _fixnum? _real-category _parts)
     (define s (normalized-text->string text))
     (and s (string->number s))]
    [_ #f]))

;; flonum->ordered-integer : flonum? -> exact-nonnegative-integer?
;;   Map an IEEE double to an integer ordered by numeric value.
(define (flonum->ordered-integer x)
  (define bits
    (integer-bytes->integer (real->floating-point-bytes x 8 #t) #f #t))
  (if (zero? (bitwise-and bits sign-bit-mask))
      (+ bits sign-bit-mask)
      (- all-bits-mask bits)))

;; flonum-ulp-distance : flonum? flonum? -> exact-nonnegative-integer?
;;   Compute the distance in representable doubles between two finite flonums.
(define (flonum-ulp-distance x y)
  (abs (- (flonum->ordered-integer x)
          (flonum->ordered-integer y))))

;; comparison-spec : any/c -> (values symbol? exact-nonnegative-integer?)
;;   Decode a comparison mode and its ULP tolerance.
(define (comparison-spec comparison)
  (match comparison
    ['exact
     (values 'exact 0)]
    ['ignore-fixnum-width
     (values 'ignore-fixnum-width 0)]
    ;; Docs-only assertion for cases where the selected CS executable lags the
    ;; reference documentation.
    ['webracket-true
     (values 'webracket-true 0)]
    ['flonum-ulps
     (values 'flonum-ulps default-flonum-ulps)]
    ['complex-ulps
     (values 'complex-ulps default-flonum-ulps)]
    [`(flonum-ulps ,(? exact-nonnegative-integer? ulps))
     (values 'flonum-ulps ulps)]
    [`(complex-ulps ,(? exact-nonnegative-integer? ulps))
     (values 'complex-ulps ulps)]
    [_
     (error 'comparison-spec
            "unsupported comparison mode: ~s"
            comparison)]))

;; normalized-real-ulps-match? : exact-nonnegative-integer? any/c any/c -> boolean?
;;   Compare two normalized real number records with a ULP tolerance.
(define (normalized-real-ulps-match? max-ulps cs-record wr-record)
  (match* (cs-record wr-record)
    [((list 'number _ctext _cnumber? _ccomplex? #t _crational? _cinteger?
            _cexact-integer? _cexact? #t _cfixnum? ccategory _cparts)
      (list 'number _wtext _wnumber? _wcomplex? #t _wrational? _winteger?
            _wexact-integer? _wexact? #t _wfixnum? wcategory _wparts))
     (and (eq? ccategory wcategory)
          (case ccategory
            [(ordinary)
             (define cs-value (normalized-real->number cs-record))
             (define wr-value (normalized-real->number wr-record))
             (and (flonum? cs-value)
                  (flonum? wr-value)
                  (<= (flonum-ulp-distance cs-value wr-value) max-ulps))]
            [(nan positive-infinity negative-infinity positive-zero negative-zero)
             #t]
            [else
             #f]))]
    [(_ _) #f]))

;; normalized-number-ulps-match? : exact-nonnegative-integer? any/c any/c -> boolean?
;;   Compare normalized number records, using ULP tolerance for inexact reals.
(define (normalized-number-ulps-match? max-ulps cs-record wr-record)
  (match* (cs-record wr-record)
    [((list 'number ctext cnumber? ccomplex? creal? crational? cinteger?
            cexact-integer? cexact? cinexact? _cfixnum? ccategory cparts)
      (list 'number wtext wnumber? wcomplex? wreal? wrational? winteger?
            wexact-integer? wexact? winexact? _wfixnum? wcategory wparts))
     (and (equal? (list cnumber? ccomplex? creal? crational? cinteger?
                        cexact-integer? cexact? cinexact? ccategory)
                  (list wnumber? wcomplex? wreal? wrational? winteger?
                        wexact-integer? wexact? winexact? wcategory))
          (cond
            [(and ccomplex? (not creal?))
             (and (= (length cparts) 2)
                  (= (length wparts) 2)
                  (record-ulps-match? max-ulps (car cparts) (car wparts))
                  (record-ulps-match? max-ulps (cadr cparts) (cadr wparts)))]
            [(and creal? cinexact?)
             (normalized-real-ulps-match? max-ulps cs-record wr-record)]
            [else
             (equal? ctext wtext)]))]
    [(_ _) #f]))

;; record-ulps-match? : exact-nonnegative-integer? any/c any/c -> boolean?
;;   Compare normalized records recursively with tolerant inexact-number leaves.
(define (record-ulps-match? max-ulps cs-record wr-record)
  (match* (cs-record wr-record)
    [((list 'value cs-value)
      (list 'value wr-value))
     (record-ulps-match? max-ulps cs-value wr-value)]
    [((list 'number _ ...)
      (list 'number _ ...))
     (normalized-number-ulps-match? max-ulps cs-record wr-record)]
    [((? list? cs-list)
      (? list? wr-list))
     (and (= (length cs-list) (length wr-list))
          (for/and ([cs-part (in-list cs-list)]
                    [wr-part (in-list wr-list)])
            (record-ulps-match? max-ulps cs-part wr-part)))]
    [(_ _)
     (equal? cs-record wr-record)]))

;; records-match? : symbol? any/c any/c -> boolean?
;;   Compare two normalized records according to the case comparison mode.
(define (records-match? comparison cs-record wr-record)
  (define-values (mode max-ulps) (comparison-spec comparison))
  (case mode
    [(exact)
     (equal? cs-record wr-record)]
    [(ignore-fixnum-width)
     (equal? (record-ignore-fixnum-width cs-record)
             (record-ignore-fixnum-width wr-record))]
    [(webracket-true)
     (equal? wr-record '(value (boolean #t)))]
    [(flonum-ulps complex-ulps)
     (record-ulps-match? max-ulps
                         (record-ignore-fixnum-width cs-record)
                         (record-ignore-fixnum-width wr-record))]
    [else
     (error 'records-match?
            "unsupported comparison mode: ~s"
            comparison)]))

;; outcome-status : number-tower-case? boolean? -> symbol?
;;   Classify a comparison result as gating or recorded.
(define (outcome-status c match?)
  (cond
    [(and (number-tower-case-gate? c) match?) 'pass]
    [(number-tower-case-gate? c) 'fail]
    [match? 'recorded-match]
    [else 'recorded-mismatch]))

;; make-outcome : number-tower-case? any/c any/c -> number-tower-outcome?
;;   Compare records and build an outcome.
(define (make-outcome c cs-record wr-record)
  (define match?
    (records-match? (number-tower-case-comparison c) cs-record wr-record))
  (number-tower-outcome
   c
   cs-record
   wr-record
   (outcome-status c match?)
   (number-tower-case-note c)))

;; run-with-fresh-racket-env : (-> any/c) -> any/c
;;   Avoid writing compiled artifacts into the checkout during oracle runs.
(define (run-with-fresh-racket-env thunk)
  (call-with-temp-directory
   "number-tower-compiled-~a"
   (lambda (compiled-root)
     (define env (environment-variables-copy (current-environment-variables)))
     (environment-variables-set! env #"PLTCOMPILEDROOTS" (path->bytes compiled-root))
     (environment-variables-set! env #"WEBRACKET_EXEC_PATH_FROM_SHELL_QUIET" #"1")
     (parameterize ([current-environment-variables env])
       (thunk)))))

;; run-number-tower-cases :
;;   (listof number-tower-case?) keyword args -> number-tower-summary?
;;   Run explicit CS/WebRacket cases and return a comparison summary.
(define (run-number-tower-cases cases
                                #:cs-path [cs-path (default-racket-cs-path)]
                                #:webracket-racket-path [webracket-racket-path
                                                         (default-webracket-racket-path)]
                                #:self-check-mismatch? [self-check-mismatch? #f])
  (define cs-info (query-number-tower-cs-info cs-path))
  (validate-number-tower-cs-info! cs-info)
  (when (null? cases)
    (error 'run-number-tower-cases "no number-tower cases selected"))
  (run-with-fresh-racket-env
   (lambda ()
     (call-with-temp-directory
      "number-tower-cases-~a"
      (lambda (temp-dir)
        (define cs-records (run-cs-cases cases cs-path temp-dir))
        (define wr-records
          (cond
            [(and self-check-mismatch? (= (length cases) 1))
             (hasheq (number-tower-case-id (car cases)) '(deliberate-mismatch))]
            [else
             (run-webracket-cases cases webracket-racket-path temp-dir)]))
        (define outcomes
          (for/list ([c (in-list cases)]
                     [index (in-naturals)])
            (define id (number-tower-case-id c))
            (define cs-record (hash-ref cs-records id '(missing-cs-record)))
            (define wr-record
              (if (and self-check-mismatch? (zero? index))
                  '(deliberate-mismatch)
                  (hash-ref wr-records id '(missing-webracket-record))))
            (make-outcome c cs-record wr-record)))
        (number-tower-summary cs-info outcomes))))))

;; run-number-tower-oracle :
;;   keyword args -> number-tower-summary?
;;   Run selected CS/WebRacket cases and return a comparison summary.
(define (run-number-tower-oracle #:cs-path [cs-path (default-racket-cs-path)]
                                 #:webracket-racket-path [webracket-racket-path
                                                          (default-webracket-racket-path)]
                                 #:groups [groups '()]
                                 #:ids [ids '()]
                                 #:include-non-gates? [include-non-gates? #f]
                                 #:self-check-mismatch? [self-check-mismatch? #f])
  (define cases
    (select-number-tower-cases #:groups groups
                               #:ids ids
                               #:include-non-gates? include-non-gates?))
  (run-number-tower-cases cases
                          #:cs-path cs-path
                          #:webracket-racket-path webracket-racket-path
                          #:self-check-mismatch? self-check-mismatch?))

;; summary-failure-count : number-tower-summary? -> exact-nonnegative-integer?
;;   Count enabled-gate failures.
(define (summary-failure-count summary)
  (count (lambda (outcome)
           (eq? (number-tower-outcome-status outcome) 'fail))
         (number-tower-summary-outcomes summary)))

;; summary-recorded-count : number-tower-summary? -> exact-nonnegative-integer?
;;   Count non-gating recorded mismatches.
(define (summary-recorded-count summary)
  (count (lambda (outcome)
           (eq? (number-tower-outcome-status outcome) 'recorded-mismatch))
         (number-tower-summary-outcomes summary)))

;; one-line-record : any/c -> string?
;;   Render a compact normalized record for human reports.
(define (one-line-record record)
  (define text (format "~s" record))
  (if (> (string-length text) 220)
      (string-append (substring text 0 220) "...")
      text))

;; print-number-tower-summary : number-tower-summary? -> void?
;;   Print an oracle report for command-line use.
(define (print-number-tower-summary summary)
  (define info (number-tower-summary-cs-info summary))
  (printf "number-tower-cs: ~a version ~a vm ~a\n"
          (number-tower-cs-info-path info)
          (number-tower-cs-info-version info)
          (number-tower-cs-info-vm info))
  (for ([outcome (in-list (number-tower-summary-outcomes summary))])
    (define c (number-tower-outcome-case outcome))
    (define status (number-tower-outcome-status outcome))
    (printf "~a ~a/~a\n"
            status
            (number-tower-case-group c)
            (number-tower-case-id c))
    (when (memq status '(fail recorded-mismatch recorded-match))
      (printf "  note: ~a\n" (number-tower-outcome-message outcome))
      (printf "  expr: ~s\n" (number-tower-case-expr c))
      (printf "  cs:   ~a\n" (one-line-record (number-tower-outcome-cs-record outcome)))
      (printf "  wr:   ~a\n" (one-line-record (number-tower-outcome-webracket-record outcome))))))

;; number-tower-self-check-mismatch-detected? : [path-string? path-string?] -> boolean?
;;   Return true when the runner reports an intentionally injected mismatch.
(define (number-tower-self-check-mismatch-detected?
         [cs-path (default-racket-cs-path)]
         [webracket-racket-path (default-webracket-racket-path)])
  (define summary
    (run-number-tower-oracle #:cs-path cs-path
                             #:webracket-racket-path webracket-racket-path
                             #:groups '(oracle-smoke)
                             #:ids '(oracle-fixnum-add)
                             #:self-check-mismatch? #t))
  (= (summary-failure-count summary) 1))

;; parse-symbol-list : string? -> (listof symbol?)
;;   Parse a comma-separated command-line symbol list.
(define (parse-symbol-list s)
  (filter values
          (for/list ([part (in-list (string-split s ","))])
            (define trimmed (string-trim part))
            (and (not (string=? trimmed ""))
                 (string->symbol trimmed)))))

;; main : -> void?
;;   Command-line entry point.
(define (main)
  (define cs-path (default-racket-cs-path))
  (define webracket-racket-path (default-webracket-racket-path))
  (define groups '())
  (define ids '())
  (define include-non-gates? #f)
  (define list-groups? #f)
  (define list-cases? #f)
  (define self-check-mismatch? #f)
  (command-line
   #:program "check-number-tower-cs"
   #:once-each
   [("--cs") path "Racket CS executable path"
             (set! cs-path path)]
   [("--webracket-racket") path "Racket executable for WebRacket compilation"
                           (set! webracket-racket-path path)]
   [("--all") "Run recorded non-gating cases as well as gates"
              (set! include-non-gates? #t)]
   [("--list-groups") "List oracle groups and exit"
                      (set! list-groups? #t)]
   [("--list-cases") "List cases and exit"
                     (set! list-cases? #t)]
   [("--self-check-mismatch") "Succeed only if a deliberate mismatch is detected"
                              (set! self-check-mismatch? #t)]
   #:multi
   [("--group") group "Run one group or a comma-separated list of groups"
               (set! groups (append groups (parse-symbol-list group)))]
   [("--case") id "Run one case id or a comma-separated list of case ids"
              (set! ids (append ids (parse-symbol-list id)))])
  (cond
    [list-groups?
     (for ([group (in-list (number-tower-groups))])
       (printf "~a\n" group))]
    [list-cases?
     (for ([c (in-list number-tower-cases)])
       (printf "~a\t~a\tgate=~a\n"
               (number-tower-case-group c)
               (number-tower-case-id c)
               (number-tower-case-gate? c)))]
    [self-check-mismatch?
     (unless (number-tower-self-check-mismatch-detected?
              cs-path
              webracket-racket-path)
       (error 'check-number-tower-cs
              "deliberate mismatch was not detected"))
     (printf "deliberate mismatch detected\n")]
    [else
     (define summary
       (run-number-tower-oracle #:cs-path cs-path
                                #:webracket-racket-path webracket-racket-path
                                #:groups groups
                                #:ids ids
                                #:include-non-gates? include-non-gates?))
     (print-number-tower-summary summary)
     (unless (zero? (summary-failure-count summary))
       (exit 1))]))

(module+ main
  (main))
