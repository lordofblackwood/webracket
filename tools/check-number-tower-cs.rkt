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
         run-number-tower-oracle
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

(define default-cs-executable
  "/Users/soegaard/Dropbox/GitHub/racket/racket/bin/racket")

(define application-racket-cs-executable
  "/Applications/Racket v9.3.0.2/bin/racket")

(define-runtime-path repo-root* "..")

(define repo-root (simplify-path repo-root*))

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
  (define dir (make-temporary-file prefix 'directory))
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
  (define stdout-path (make-temporary-file "number-tower-stdout-~a.txt"))
  (define stderr-path (make-temporary-file "number-tower-stderr-~a.txt"))
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

          (define (number-tower-flasinh x)
            (log (+ x (sqrt (+ (* x x) 1.0)))))

          (define (number-tower-flacosh x)
            (if (< x 1.0)
                +nan.0
                (log (+ x (* (sqrt (+ x 1.0))
                             (sqrt (- x 1.0)))))))

          (define (number-tower-flatanh x)
            (cond [(= x 1.0) +inf.0]
                  [(= x -1.0) -inf.0]
                  [(or (< x -1.0) (> x 1.0)) +nan.0]
                  [else (* 0.5 (- (log (+ 1.0 x))
                                  (log (- 1.0 x))))]))

          (define (asinh x)
            (cond [(flonum? x) (number-tower-flasinh x)]
                  [(eqv? x 0) 0]
                  [(real? x) (number-tower-flasinh (real->double-flonum x))]
                  [(number-tower-float-complex? x)
                   (log (+ x (sqrt (+ (* x x) 1.0))))]
                  [else
                   (log (+ x (sqrt (+ (* x x) 1))))]))

          (define (acosh x)
            (cond [(flonum? x) (number-tower-flacosh x)]
                  [(eqv? x 1) 0]
                  [(and (real? x) (>= x 1))
                   (number-tower-flacosh (real->double-flonum x))]
                  [(number-tower-float-complex? x)
                   (log (+ x (* (sqrt (+ x 1.0)) (sqrt (- x 1.0)))))]
                  [else
                   (log (+ x (* (sqrt (+ x 1)) (sqrt (- x 1)))))]))

          (define (atanh x)
            (cond [(flonum? x) (number-tower-flatanh x)]
                  [(eqv? x 0) 0]
                  [(real? x) (number-tower-flatanh (real->double-flonum x))]
                  [(number-tower-float-complex? x)
                   (* 0.5 (- (log (+ 1.0 x)) (log (- 1.0 x))))]
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

;; records-match? : symbol? any/c any/c -> boolean?
;;   Compare two normalized records according to the case comparison mode.
(define (records-match? comparison cs-record wr-record)
  (case comparison
    [(exact) (equal? cs-record wr-record)]
    [(ignore-fixnum-width)
     (equal? (record-ignore-fixnum-width cs-record)
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
  (define cs-info (query-number-tower-cs-info cs-path))
  (validate-number-tower-cs-info! cs-info)
  (define cases
    (select-number-tower-cases #:groups groups
                               #:ids ids
                               #:include-non-gates? include-non-gates?))
  (when (null? cases)
    (error 'run-number-tower-oracle "no number-tower cases selected"))
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
