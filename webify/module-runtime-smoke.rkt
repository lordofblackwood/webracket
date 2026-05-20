#lang racket/base

(provide installed-runtime-smoke
         installed-runtime-smoke?
         installed-runtime-smoke-category
         installed-runtime-smoke-name
         installed-runtime-smoke-module-data
         installed-runtime-smoke-observations
         installed-runtime-smoke-expected-output
         installed-runtime-smoke-allowed-failures
         installed-runtime-smoke-expected-failure
         local-runtime-smoke
         local-runtime-smoke?
         local-runtime-smoke-name
         local-runtime-smoke-inputs
         local-runtime-smoke-roots
         local-runtime-smoke-observations
         local-runtime-smoke-expected-output
         local-runtime-smoke-allowed-failures
         local-runtime-smoke-expected-failure
         runtime-smoke-graph-audit
         runtime-smoke-graph-audit?
         runtime-smoke-graph-audit-roots
         runtime-smoke-graph-audit-input-names
         runtime-smoke-graph-audit-plan
         runtime-smoke-graph-audit-imports
         runtime-smoke-graph-audit-primitive-demands
         runtime-smoke-graph-audit-missing-primitive-demands
         racket92-bin
         current-runtime-smoke-preserve-dir
         current-runtime-smoke-extra-webracket-args
         installed-runtime-inputs-missing-primitive-demands
         webify-module-linklet-manifest->runtime-smoke-graph-audit
         run-installed-runtime-smoke
         run-installed-runtime-smokes
         run-local-runtime-smoke)

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         rackunit
         "module-diagnostics.rkt"
         "module-composer.rkt"
         "primitive-demands.rkt"
         "read-provider.rkt"
         "test-module-support.rkt")

(define-runtime-path repo-root "..")
(define racket92-bin (build-path repo-root "../racket/racket/bin/racket"))
(define current-runtime-smoke-preserve-dir (make-parameter #f))
(define current-runtime-smoke-extra-webracket-args (make-parameter '()))

;; runtime-smoke-primitive-import-overrides : -> hasheq?
;;   Route primitive import cells to staged providers when their driver flag is active.
(define (runtime-smoke-primitive-import-overrides)
  (if (member "--expander-read-provider" (current-runtime-smoke-extra-webracket-args))
      (hasheq 'read
              (webify-read-private-cell-symbol 'webify-expander-read))
      (hasheq)))

(struct installed-runtime-smoke
  (category
   name
   module-data
   observations
   expected-output
   allowed-failures
   expected-failure)
  #:transparent)

(struct local-runtime-smoke
  (name
   inputs
   roots
   observations
   expected-output
   allowed-failures
   expected-failure)
  #:transparent)

(struct runtime-smoke-graph-audit
  (roots
   input-names
   plan
   imports
   primitive-demands
   missing-primitive-demands)
  #:transparent)

;; preserve-runtime-directory! : symbol? path-string? -> void?
;;   Copy a temporary runtime-smoke directory into the requested transcript area.
(define (preserve-runtime-directory! label dir)
  (define base (current-runtime-smoke-preserve-dir))
  (when base
    (make-directory* base)
    (define label-text
      (regexp-replace* #rx"[^A-Za-z0-9_.-]"
                       (format "~a" label)
                       "-"))
    (let loop ([n 0])
      (define dest
        (build-path base
                    (if (zero? n)
                        label-text
                        (format "~a-~a" label-text n))))
      (cond
        [(or (file-exists? dest) (directory-exists? dest))
         (loop (add1 n))]
        [else
         (copy-directory/files dir dest)
         (printf "runtime-smoke-preserved: ~a\n" dest)]))))

;; write-extractor-script! : path-string? path-string? any/c -> void?
;;   Write a Racket 9.2 script that extracts a tiny installed-provider graph.
(define (write-extractor-script! script-path manifest-path module-data)
  (define root-names
    (for/list ([datum (in-list module-data)])
      (match datum
        [`(module ,(? symbol? name) . ,_) name]
        [_ (raise-arguments-error 'write-extractor-script!
                                  "expected source module datum"
                                  "module" datum)])))
  (call-with-output-file script-path
    (lambda (out)
      (display "#lang racket/base\n" out)
      (write
       `(begin
          (require (file ,(path->string (build-path repo-root "webify/module-extractor.rkt")))
                   (file ,(path->string (build-path repo-root "webify/module-input.rkt")))
                   (file ,(path->string (build-path repo-root "webify/module-protocol.rkt"))))
          (define root-names ',root-names)
          (define inputs
            (webify-source-modules->discovered-resolved-linklet-inputs
             ',module-data
             #:extra-reports (list webify-module-protocol-report)
             #:module-protocol-dependency webify-module-protocol-dependency
             #:demand-slice? #t))
          (define manifest-root-names
            (map webify-module-linklet-input-name inputs))
          (call-with-output-file ,(path->string manifest-path)
            (lambda (out)
              (write
               `(webify-module-linklet-manifest
                 (roots ,manifest-root-names)
                 ,@(for/list ([input (in-list inputs)])
                     `(input ,(webify-module-linklet-input-name input)
                             ,(webify-module-linklet-input-linklet input)
                             (imports ,(webify-module-linklet-input-imports input)))))
               out)
              (newline out))
            #:exists 'truncate/replace))
       out)
      (newline out))
    #:exists 'truncate/replace))

;; check-runtime-failure : symbol? (listof symbol?) (or/c regexp? #f) webify-module-failure? -> void?
;;   Validate an expected extraction, bridge, compiler, or runtime failure.
(define (check-runtime-failure who allowed-failures expected-failure failure)
  (check-not-equal? (webify-module-failure-category failure)
                    'primitive-alias-collision)
  (unless (memq (webify-module-failure-category failure)
                allowed-failures)
    (error 'check-runtime-failure
           "~a failed as ~a:\n~a"
           who
           (webify-module-failure-category failure)
           (webify-module-failure-message failure)))
  (when expected-failure
    (unless (regexp-match? expected-failure
                           (webify-module-failure-message failure))
      (error 'check-runtime-failure
             "~a failure message did not match expected regexp\nexpected: ~s\nmessage:\n~a"
             who
             expected-failure
             (webify-module-failure-message failure)))))

;; assert-runtime-output-match! : regexp? string? -> void?
;;   Treat observed-output mismatches as hard probe failures, not soft RackUnit logs.
(define (assert-runtime-output-match! expected-output output)
  (unless (regexp-match? expected-output output)
    (error 'run-composed-runtime-smoke
           "WebRacket output did not match expected regexp\nexpected: ~s\noutput:\n~a"
           expected-output
           output)))

;; check-installed-runtime-failure : installed-runtime-smoke? webify-module-failure? -> void?
;;   Validate an expected installed-module smoke failure.
(define (check-installed-runtime-failure smoke failure)
  (check-runtime-failure
   (installed-runtime-smoke-name smoke)
   (installed-runtime-smoke-allowed-failures smoke)
   (installed-runtime-smoke-expected-failure smoke)
   failure))

;; check-local-runtime-failure : local-runtime-smoke? webify-module-failure? -> void?
;;   Validate an expected hand-authored module-linklet smoke failure.
(define (check-local-runtime-failure smoke failure)
  (check-runtime-failure
   (local-runtime-smoke-name smoke)
   (local-runtime-smoke-allowed-failures smoke)
   (local-runtime-smoke-expected-failure smoke)
   failure))

;; run-racket92/extract : path-string? path-string? -> values
;;   Run a Racket 9.2 extractor script while capturing combined output.
(define (run-racket92/extract racket-bin script-path compiled-root)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr]
                   [current-environment-variables
                    (environment-variables-copy (current-environment-variables))])
      (putenv "PLTCOMPILEDROOTS" (path->string compiled-root))
      (putenv "PLTCOLLECTS" (webracket-collection-env-value))
      (system*/exit-code (path->string racket-bin) (path->string script-path))))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))

;; format-primitive-demands : webify-primitive-demand-report? -> string?
;;   Render primitive demands compactly for installed-module smoke diagnostics.
(define (format-primitive-demands report)
  (define demands
    (for/list ([demand (in-list (webify-primitive-demand-report-demands report))])
      (format "~a:~a from ~s"
              (webify-primitive-demand-module demand)
              (webify-primitive-demand-name demand)
              (webify-primitive-demand-sources demand))))
  (define table-requests
    (for/list ([request (in-list (webify-primitive-demand-report-table-requests report))])
      (format "~a table from ~s"
              (webify-primitive-table-request-module request)
              (webify-primitive-table-request-sources request))))
  (string-join (append demands table-requests) "\n"))

;; installed-runtime-inputs-missing-primitive-demands : inputs -> demands
;;   Report primitive-table names that are absent before a runtime smoke runs.
(define (installed-runtime-inputs-missing-primitive-demands inputs)
  (define report (webify-module-linklet-inputs->primitive-demands inputs))
  (webify-primitive-demand-report-missing report))

;; primitive-demand->summary : webify-primitive-demand? -> list?
;;   Convert one primitive demand to a stable diagnostic datum.
(define (primitive-demand->summary demand)
  (list (webify-primitive-demand-module demand)
        (webify-primitive-demand-name demand)
        (webify-primitive-demand-sources demand)))

;; print-runtime-smoke-failure-summary : manifest? -> void?
;;   Print compact graph context for a failed bounded installed-module probe.
(define (print-runtime-smoke-failure-summary manifest)
  (define audit (webify-module-linklet-manifest->runtime-smoke-graph-audit manifest))
  (define plan (runtime-smoke-graph-audit-plan audit))
  (define missing (runtime-smoke-graph-audit-missing-primitive-demands audit))
  (fprintf (current-error-port)
           "runtime-smoke-failure-roots: ~s\n"
           (runtime-smoke-graph-audit-roots audit))
  (fprintf (current-error-port)
           "runtime-smoke-failure-plan-prefix: ~s\n"
           (take plan (min 12 (length plan))))
  (fprintf (current-error-port)
           "runtime-smoke-failure-missing-primitive-count: ~a\n"
           (length missing))
  (unless (null? missing)
    (fprintf (current-error-port)
             "runtime-smoke-failure-missing-primitives: ~s\n"
             missing))
  (when (current-runtime-smoke-preserve-dir)
    (fprintf (current-error-port)
             "runtime-smoke-failure-preserve-dir: ~a\n"
             (current-runtime-smoke-preserve-dir))))

;; module-linklet-inputs-module-plan : (listof webify-module-linklet-input?) (listof symbol?) -> (listof symbol?)
;;   Compute a dependency-first plan while ignoring primitive-module imports.
(define (module-linklet-inputs-module-plan inputs roots)
  (define who 'module-linklet-inputs-module-plan)
  (define input-table
    (for/hasheq ([input (in-list inputs)])
      (values (webify-module-linklet-input-name input) input)))
  (define planned '())
  (define permanent (hasheq))
  (define temporary (hasheq))
  (define (input-ref name)
    (hash-ref input-table
              name
              (lambda ()
                (raise-arguments-error who
                                       "unknown module-linklet input"
                                       "name" name
                                       "available names" (hash-keys input-table)))))
  (define (visit name path)
    (input-ref name)
    (cond
      [(hash-has-key? permanent name)
       (void)]
      [(hash-has-key? temporary name)
       (raise-arguments-error who
                              "cyclic module-linklet dependencies are not supported"
                              "name" name
                              "path" (reverse (cons name path)))]
      [else
       (set! temporary (hash-set temporary name #t))
       (define input (input-ref name))
       (for ([source (in-list (webify-module-linklet-input-imports input))])
         (match-define (list _local dependency _export) source)
         (unless (or (primitive-module-name? dependency)
                     (eq? dependency name))
           (visit dependency (cons name path))))
       (set! temporary (hash-remove temporary name))
       (set! permanent (hash-set permanent name #t))
       (set! planned (cons name planned))]))
  (for ([root (in-list roots)])
    (visit root '()))
  (reverse planned))

;; webify-module-linklet-manifest->runtime-smoke-graph-audit : webify-module-linklet-manifest? -> runtime-smoke-graph-audit?
;;   Summarize a module-linklet manifest before runtime-smoke compilation.
(define (webify-module-linklet-manifest->runtime-smoke-graph-audit manifest)
  (unless (webify-module-linklet-manifest? manifest)
    (raise-argument-error 'webify-module-linklet-manifest->runtime-smoke-graph-audit
                          "webify-module-linklet-manifest?"
                          manifest))
  (define inputs   (webify-module-linklet-manifest-inputs manifest))
  (define roots    (webify-module-linklet-manifest-roots manifest))
  (define report   (webify-module-linklet-inputs->primitive-demands inputs))
  (runtime-smoke-graph-audit
   roots
   (map webify-module-linklet-input-name inputs)
   (module-linklet-inputs-module-plan inputs roots)
   (for/list ([input (in-list inputs)])
     (list (webify-module-linklet-input-name input)
           (webify-module-linklet-input-imports input)))
   (map primitive-demand->summary
        (webify-primitive-demand-report-demands report))
   (map primitive-demand->summary
        (webify-primitive-demand-report-missing report))))

;; check-primitive-demands! : (listof webify-module-linklet-input?) -> void?
;;   Fail early when resolved inputs demand names absent from the primitive table.
(define (check-primitive-demands! inputs)
  (define missing (installed-runtime-inputs-missing-primitive-demands inputs))
  (unless (null? missing)
    (fail-check
     (format "missing primitive-table entries before runtime smoke:\n~a"
             (format-primitive-demands
              (webify-primitive-demand-report missing '()))))))

;; instantiate-loader! : webify-module-loader? (listof symbol?) -> void?
;;   Instantiate a module loader with the standard Goal 1 smoke compiler settings.
(define (instantiate-loader! loader roots)
  (webify-module-loader-instantiate!
   loader
   roots
   #:define-export-aliases? #f
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f)
  (void))

;; run-composed-runtime-smoke/output : webify-module-linklet-manifest? (loader -> datum?) -> string?
;;   Compose a resolved manifest, run it with WebRacket, and return observed output.
(define (run-composed-runtime-smoke/output manifest build-program)
  (define source-dir (make-temporary-file "webracket-module-runtime-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-module-runtime-dest-~a" 'directory))
  (define program-path (build-path source-dir "module-runtime-run.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (define inputs (webify-module-linklet-manifest-inputs manifest))
      (check-primitive-demands! inputs)
      (define registry (webify-module-linklet-manifest->registry manifest))
      (define loader (make-webify-module-loader registry))
      (parameterize ([current-composer-primitive-import-cell-overrides
                      (runtime-smoke-primitive-import-overrides)])
        (instantiate-loader! loader (webify-module-linklet-manifest-roots manifest)))
      (write-datum-program!
       program-path
       (build-program loader))
      (define webracket-args
        (append (current-runtime-smoke-extra-webracket-args)
                (list "--no-stdlib"
                      "-r"
                      "--dest" (path->string dest-dir)
                      (path->string program-path))))
      (define-values (status output)
        (run-webracket webracket-args source-dir))
      (unless (zero? status)
        (error 'run-composed-runtime-smoke
               "WebRacket exited with status ~a\n~a"
               status
               output))
      (when (member "--timings" webracket-args)
        (display output))
      output)
    (lambda ()
      (preserve-runtime-directory! 'composed-source source-dir)
      (preserve-runtime-directory! 'composed-dest dest-dir)
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

;; run-composed-runtime-smoke : webify-module-linklet-manifest? observations regexp? -> void?
;;   Compose a resolved manifest, run it with WebRacket, and check observed output.
(define (run-composed-runtime-smoke manifest observations expected-output)
  (define output
    (run-composed-runtime-smoke/output
     manifest
     (lambda (loader)
       (webify-module-loader-observe loader observations))))
  (assert-runtime-output-match! expected-output output))

;; run-local-runtime-smoke : local-runtime-smoke? -> void?
;;   Run one hand-authored module-linklet manifest through the WebRacket runtime.
(define (run-local-runtime-smoke smoke)
  (unless (local-runtime-smoke? smoke)
    (raise-argument-error 'run-local-runtime-smoke
                          "local-runtime-smoke?"
                          smoke))
  (with-handlers ([exn:fail?
                   (lambda (exn)
                     (check-local-runtime-failure
                      smoke
                      (webify-classify-module-exn 'runtime exn)))])
    (run-composed-runtime-smoke
     (webify-module-linklet-manifest
      (local-runtime-smoke-inputs smoke)
      (local-runtime-smoke-roots smoke))
     (local-runtime-smoke-observations smoke)
     (local-runtime-smoke-expected-output smoke))
    (when (pair? (local-runtime-smoke-allowed-failures smoke))
      (fail-check
       (format "expected local runtime smoke failure in ~a"
               (local-runtime-smoke-name smoke))))))

;; run-installed-runtime-smoke : installed-runtime-smoke? -> void?
;;   Extract, compose, compile, and run one installed-module WebRacket smoke.
(define (run-installed-runtime-smoke smoke)
  (unless (installed-runtime-smoke? smoke)
    (raise-argument-error 'run-installed-runtime-smoke
                          "installed-runtime-smoke?"
                          smoke))
  (define source-dir (make-temporary-file "webracket-installed-runtime-src-~a" 'directory))
  (define manifest-path (build-path source-dir "installed-inputs.rktd"))
  (define extractor-path (build-path source-dir "extract-installed.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-extractor-script!
       extractor-path
       manifest-path
       (installed-runtime-smoke-module-data smoke))
      (define-values (extract-status extract-output)
        (run-racket92/extract
         racket92-bin
         extractor-path
         (build-path source-dir "compiled")))
      (cond
        [(zero? extract-status)
         (define manifest (read-webify-module-linklet-manifest manifest-path))
         (with-handlers ([exn:fail?
                          (lambda (exn)
                            (print-runtime-smoke-failure-summary manifest)
                            (check-installed-runtime-failure
                             smoke
                             (webify-classify-module-exn 'runtime exn)))])
           (run-composed-runtime-smoke
            manifest
            (installed-runtime-smoke-observations smoke)
            (installed-runtime-smoke-expected-output smoke)))]
        [else
         (define failure (webify-classify-runtime-output extract-status extract-output))
         (check-installed-runtime-failure smoke failure)]))
    (lambda ()
      (preserve-runtime-directory! 'installed-source source-dir)
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

;; batch-marker : exact-nonnegative-integer? installed-runtime-smoke? -> string?
;;   Build a unique output marker for one smoke inside a batched runtime run.
(define (batch-marker i smoke)
  (format "__WEBRACKET_RUNTIME_SMOKE_BEGIN__~a__~a"
          i
          (installed-runtime-smoke-category smoke)))

;; output-after-marker : string? string? (or/c string? #f) -> string?
;;   Extract the output segment following marker and before next-marker.
(define (output-after-marker output marker next-marker)
  (define start-match
    (regexp-match-positions (regexp-quote marker) output))
  (unless start-match
    (error 'run-installed-runtime-smokes
           "batched smoke output did not contain marker ~s\noutput:\n~a"
           marker
           output))
  (define start (cdr (car start-match)))
  (define end
    (cond
      [next-marker
       (define next-match
         (regexp-match-positions (regexp-quote next-marker) output start))
       (if next-match (caar next-match) (string-length output))]
      [else
       (string-length output)]))
  (substring output start end))

;; check-batched-output! : (listof installed-runtime-smoke?) string? -> void?
;;   Check each smoke's expected output in its marker-delimited segment.
(define (check-batched-output! smokes output)
  (define markers
    (for/list ([smoke (in-list smokes)]
               [i (in-naturals)])
      (batch-marker i smoke)))
  (for ([smoke (in-list smokes)]
        [marker (in-list markers)]
        [next-marker (in-list (append (cdr markers) (list #f)))])
    (define segment (output-after-marker output marker next-marker))
    (unless (regexp-match? (installed-runtime-smoke-expected-output smoke)
                           segment)
      (error 'run-installed-runtime-smokes
             "batched smoke ~a output did not match expected regexp\nexpected: ~s\nsegment:\n~a\nfull output:\n~a"
             (installed-runtime-smoke-name smoke)
             (installed-runtime-smoke-expected-output smoke)
             segment
             output))))

;; run-installed-runtime-smokes : (listof installed-runtime-smoke?) -> void?
;;   Extract, compose, compile, and run a batch of expected-pass smokes together.
(define (run-installed-runtime-smokes smokes)
  (when (null? smokes)
    (raise-argument-error 'run-installed-runtime-smokes
                          "non-empty list?"
                          smokes))
  (for ([smoke (in-list smokes)])
    (unless (installed-runtime-smoke? smoke)
      (raise-argument-error 'run-installed-runtime-smokes
                            "installed-runtime-smoke?"
                            smoke))
    (unless (and (null? (installed-runtime-smoke-allowed-failures smoke))
                 (not (installed-runtime-smoke-expected-failure smoke)))
      (raise-arguments-error 'run-installed-runtime-smokes
                             "batched smokes must be expected-pass cases"
                             "smoke" (installed-runtime-smoke-name smoke))))
  (define source-dir (make-temporary-file "webracket-installed-runtime-batch-src-~a" 'directory))
  (define manifest-path (build-path source-dir "installed-inputs.rktd"))
  (define extractor-path (build-path source-dir "extract-installed.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-extractor-script!
       extractor-path
       manifest-path
       (append-map installed-runtime-smoke-module-data smokes))
      (define-values (extract-status extract-output)
        (run-racket92/extract
         racket92-bin
         extractor-path
         (build-path source-dir "compiled")))
      (unless (zero? extract-status)
        (define failure (webify-classify-runtime-output extract-status extract-output))
        (error 'run-installed-runtime-smokes
               "batched extraction failed as ~a:\n~a"
               (webify-module-failure-category failure)
               (webify-module-failure-message failure)))
      (define manifest (read-webify-module-linklet-manifest manifest-path))
      (define output
        (with-handlers ([exn:fail?
                         (lambda (exn)
                           (print-runtime-smoke-failure-summary manifest)
                           (raise exn))])
          (run-composed-runtime-smoke/output
           manifest
           (lambda (loader)
             (define tail-forms
               (append
                (append-map
                 (lambda (smoke i)
                   (append
                    `((js-log ,(batch-marker i smoke)))
                    (for/list ([observation (in-list (installed-runtime-smoke-observations smoke))])
                      (match-define (list name export) observation)
                      `(js-log
                        (module-variable-ref
                         ,(webify-module-loader-lookup-export-cell loader name export))))))
                 smokes
                 (range (length smokes)))
                '((void))))
             (webify-module-loader-compose-program loader tail-forms)))))
      (check-batched-output! smokes output))
    (lambda ()
      (preserve-runtime-directory! 'installed-batch-source source-dir)
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))
