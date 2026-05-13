#lang racket/base

(provide installed-runtime-smoke
         installed-runtime-smoke?
         installed-runtime-smoke-name
         installed-runtime-smoke-module-data
         installed-runtime-smoke-observations
         installed-runtime-smoke-expected-output
         installed-runtime-smoke-allowed-failures
         installed-runtime-smoke-expected-failure
         racket92-bin
         installed-runtime-inputs-missing-primitive-demands
         run-installed-runtime-smoke)

(require racket/file
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         racket/system
         rackunit
         "module-diagnostics.rkt"
         "primitive-demands.rkt"
         "test-module-support.rkt")

(define-runtime-path repo-root "..")
(define racket92-bin (build-path repo-root "../racket/racket/bin/racket"))

(struct installed-runtime-smoke
  (name
   module-data
   observations
   expected-output
   allowed-failures
   expected-failure)
  #:transparent)

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
          (call-with-output-file ,(path->string manifest-path)
            (lambda (out)
              (write
               `(webify-module-linklet-manifest
                 (roots ,root-names)
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

;; check-installed-runtime-failure : installed-runtime-smoke? webify-module-failure? -> void?
;;   Validate an expected extraction, bridge, compiler, or runtime failure.
(define (check-installed-runtime-failure smoke failure)
  (check-not-equal? (webify-module-failure-category failure)
                    'primitive-alias-collision)
  (unless (memq (webify-module-failure-category failure)
                (installed-runtime-smoke-allowed-failures smoke))
    (fail-check (webify-module-failure-message failure)))
  (when (installed-runtime-smoke-expected-failure smoke)
    (check-regexp-match
     (installed-runtime-smoke-expected-failure smoke)
     (webify-module-failure-message failure))))

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
      (putenv "PLTCOLLECTS" (format "~a:" (path->string (simplify-path (build-path repo-root "..")))))
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

;; run-installed-runtime-smoke : installed-runtime-smoke? -> void?
;;   Extract, compose, compile, and run one installed-module WebRacket smoke.
(define (run-installed-runtime-smoke smoke)
  (unless (installed-runtime-smoke? smoke)
    (raise-argument-error 'run-installed-runtime-smoke
                          "installed-runtime-smoke?"
                          smoke))
  (define source-dir (make-temporary-file "webracket-installed-runtime-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-installed-runtime-dest-~a" 'directory))
  (define manifest-path (build-path source-dir "installed-inputs.rktd"))
  (define extractor-path (build-path source-dir "extract-installed.rkt"))
  (define program-path (build-path source-dir "installed-run.rkt"))
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
         (define inputs (webify-module-linklet-manifest-inputs manifest))
         (check-primitive-demands! inputs)
         (define registry (webify-module-linklet-manifest->registry manifest))
         (define loader (make-webify-module-loader registry))
         (with-handlers ([exn:fail?
                          (lambda (exn)
                            (check-installed-runtime-failure
                             smoke
                             (webify-classify-module-exn 'runtime exn)))])
           (instantiate-loader!
            loader
            (webify-module-linklet-manifest-roots manifest))
           (write-datum-program!
            program-path
            (webify-module-loader-observe
             loader
             (installed-runtime-smoke-observations smoke)))
           (define-values (status output)
             (run-webracket (list "--no-stdlib"
                                  "-r"
                                  "--dest" (path->string dest-dir)
                                  (path->string program-path))
                            source-dir))
           (cond
             [(zero? status)
              (check-regexp-match (installed-runtime-smoke-expected-output smoke) output)]
             [else
              (check-installed-runtime-failure
               smoke
               (webify-classify-runtime-output status output))]))]
        [else
         (define failure (webify-classify-runtime-output extract-status extract-output))
         (check-installed-runtime-failure smoke failure)]))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))
