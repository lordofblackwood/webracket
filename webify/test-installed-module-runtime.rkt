#lang racket/base

(require racket/file
         racket/path
         racket/runtime-path
         racket/system
         rackunit
         "module-diagnostics.rkt"
         "test-module-support.rkt")

(define-runtime-path repo-root "..")
(define racket92-bin (build-path repo-root "../racket/racket/bin/racket"))

;; write-extractor-script! : path-string? path-string? -> void?
;;   Write a Racket 9.2 script that extracts a tiny installed-provider graph.
(define (write-extractor-script! script-path manifest-path)
  (call-with-output-file script-path
    (lambda (out)
      (display "#lang racket/base\n" out)
      (write
       `(begin
          (require (file ,(path->string (build-path repo-root "webify/module-extractor.rkt")))
                   (file ,(path->string (build-path repo-root "webify/module-input.rkt")))
                   (file ,(path->string (build-path repo-root "webify/module-protocol.rkt"))))
          (define inputs
            (webify-source-modules->discovered-resolved-linklet-inputs
             '((module use-bool racket/base
                 (require racket/bool)
                 (provide y)
                 (define y (boolean=? #t #t))))
             #:extra-reports (list webify-module-protocol-report)
             #:module-protocol-dependency webify-module-protocol-dependency))
          (call-with-output-file ,(path->string manifest-path)
            (lambda (out)
              (write
               `(webify-module-linklet-manifest
                 (roots (use-bool))
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

(when (file-exists? racket92-bin)
  (test-case "installed racket/bool graph reaches WebRacket runtime smoke"
    (define source-dir (make-temporary-file "webracket-installed-runtime-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-installed-runtime-dest-~a" 'directory))
    (define manifest-path (build-path source-dir "installed-inputs.rktd"))
    (define extractor-path (build-path source-dir "extract-installed.rkt"))
    (define program-path (build-path source-dir "installed-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (write-extractor-script! extractor-path manifest-path)
        (define extract-ok?
          (parameterize ([current-environment-variables
                          (environment-variables-copy (current-environment-variables))])
            (putenv "PLTCOMPILEDROOTS" (path->string (build-path source-dir "compiled")))
            (putenv "PLTCOLLECTS" (format "~a:" (path->string (simplify-path (build-path repo-root "..")))))
            (system* (path->string racket92-bin) (path->string extractor-path))))
        (check-true extract-ok?)
        (define manifest (read-webify-module-linklet-manifest manifest-path))
        (define registry (webify-module-linklet-manifest->registry manifest))
        (define loader (make-webify-module-loader registry))
        (webify-module-loader-instantiate!
         loader
         (webify-module-linklet-manifest-roots manifest)
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
         (webify-module-loader-observe loader '((use-bool y))))
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string program-path))
                         source-dir))
        (cond
          [(zero? status)
           (check-regexp-match #rx"(?m:^#t$)" output)]
          [else
           (define failure (webify-classify-runtime-output status output))
           (check-equal? (webify-module-failure-category failure)
                         'primitive-alias-collision)]))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(module+ main
  (void))
