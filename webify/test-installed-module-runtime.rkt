#lang racket/base

(require racket/file
         racket/match
         racket/path
         racket/runtime-path
         racket/system
         rackunit
         "module-diagnostics.rkt"
         "test-module-support.rkt")

(define-runtime-path repo-root "..")
(define racket92-bin (build-path repo-root "../racket/racket/bin/racket"))

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
             #:module-protocol-dependency webify-module-protocol-dependency))
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

(struct installed-runtime-smoke
  (name
   module-data
   observations
   expected-output
   allowed-failures
   expected-failure)
  #:transparent)

(define installed-runtime-smokes
  (list
   (installed-runtime-smoke
    "installed racket/bool graph reaches WebRacket runtime smoke"
    '((module use-bool racket/base
        (require racket/bool)
        (provide y)
        (define y (boolean=? #t #t))))
    '((use-bool y))
    #rx"(?m:^(#t|true)$)"
    '()
    '())
   (installed-runtime-smoke
    "installed racket/fixnum graph reaches WebRacket runtime smoke"
    '((module use-fixnum racket/base
        (require racket/fixnum)
        (provide y)
        (define y (fx+ 1 2))))
    '((use-fixnum y))
    #rx"(?m:^3$)"
    '()
    '())
   (installed-runtime-smoke
    "installed racket/list graph reaches WebRacket runtime smoke"
    '((module use-list racket/base
        (require racket/list)
        (provide y)
        (define y (first '(#t #f)))))
    '((use-list y))
    #rx"(?m:^(#t|true)$)"
    '(unresolved-import)
    #rx"import: '1/reverse\n  export: 'reverse")
   (installed-runtime-smoke
    "installed racket/string graph reaches WebRacket runtime smoke"
    '((module use-string racket/base
        (require racket/string)
        (provide y)
        (define y (string-join '("a" "b") ","))))
    '((use-string y))
    #rx"(?m:^a,b$)"
    '(unresolved-import syntax-literal unsupported-runtime unknown)
    #f)))

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

(when (file-exists? racket92-bin)
  (for ([smoke (in-list installed-runtime-smokes)])
    (test-case (installed-runtime-smoke-name smoke)
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
             (define registry (webify-module-linklet-manifest->registry manifest))
             (define loader (make-webify-module-loader registry))
             (webify-module-loader-instantiate!
              loader
              (webify-module-linklet-manifest-roots manifest)
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
                (define failure (webify-classify-runtime-output status output))
                (check-not-equal? (webify-module-failure-category failure)
                                  'primitive-alias-collision)
                (unless (memq (webify-module-failure-category failure)
                              (installed-runtime-smoke-allowed-failures smoke))
                  (fail-check (webify-module-failure-message failure)))
                (when (installed-runtime-smoke-expected-failure smoke)
                  (check-regexp-match
                   (installed-runtime-smoke-expected-failure smoke)
                   (webify-module-failure-message failure)))])]
            [else
             (define failure (webify-classify-runtime-output extract-status extract-output))
             (unless (memq (webify-module-failure-category failure)
                           (installed-runtime-smoke-allowed-failures smoke))
               (fail-check (webify-module-failure-message failure)))
             (when (installed-runtime-smoke-expected-failure smoke)
               (check-regexp-match
                (installed-runtime-smoke-expected-failure smoke)
                (webify-module-failure-message failure)))]))
        (lambda ()
          (for ([dir (in-list (list source-dir dest-dir))])
            (with-handlers ([exn:fail:filesystem? void])
              (delete-directory/files dir))))))))

(module+ main
  (void))
