#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         rackunit
         syntax/modread
         (only-in "../driver.rkt"
                  cached-installed-provider-report
                  current-provider-cache-dir
                  current-provider-cache-force?
                  read-top-level-from-file
                  webracket/base-external-provider-names
                  webracket/base-file->local-module-graph
                  webracket/base-file->local-module-reports
                  webracket/base-local-module-graph-root
                  webracket/base-local-module-graph-reports
                  webracket/base-local-module-graph-registry
                  webracket/base-reports->module-graph
                  webracket/base-reports-demand-external-providers?)
         (only-in "module-extractor.rkt"
                  webify-compile-module-report)
         (only-in "provider-trials.rkt"
                  webify-provider-trial-module-allowlist
                  webify-provider-trial-module-allowed?)
         "test-module-support.rkt"
         "webracket-base-surface.rkt"
         "webracket-full-surface.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

(define repo-parent
  (let-values ([(base name must-be-dir?) (split-path repo-root)])
    base))

(define path-list-separator
  (if (eq? (system-type 'os) 'windows) ";" ":"))

;; sorted-symbols : (listof symbol?) -> (listof symbol?)
;;   Compare provider-name sets without depending on discovery order.
(define (sorted-symbols symbols)
  (sort symbols symbol<?))

;; webracket-collection-env : -> (listof string?)
;;   Make child Racket processes resolve this checkout as collection `webracket`.
(define (webracket-collection-env)
  (list (format "PLTCOLLECTS=~a~a~a"
                (path->string repo-parent)
                path-list-separator
                (or (getenv "PLTCOLLECTS") ""))))

;; run-webracket/base : args path? -> values
;;   Run webracket with an explicit collection path, mirroring user installation.
(define (run-webracket/base args cwd)
  (parameterize ([current-environment-variables
                  (environment-variables-copy
                   (current-environment-variables))])
    (for ([entry (in-list (webracket-collection-env))])
      (define parts (regexp-match #rx"^([^=]+)=(.*)$" entry))
      (environment-variables-set!
       (current-environment-variables)
       (string->bytes/utf-8 (cadr parts))
       (string->bytes/utf-8 (caddr parts))))
    (run-webracket args
                   cwd
                   #:timeout-seconds 120
                   #:memory-mb 1024)))

;; run-webracket/no-collection : args path? -> values
;;   Run webracket without an explicit collection path for negative smokes.
(define (run-webracket/no-collection args cwd)
  (parameterize ([current-environment-variables
                  (environment-variables-copy
                   (current-environment-variables))])
    (environment-variables-set!
     (current-environment-variables)
     #"PLTCOLLECTS"
     #f)
    (run-webracket args
                   cwd
                   #:timeout-seconds 120
                   #:memory-mb 1024)))

;; call-with-webracket-collection-path : (-> any/c) -> any/c
;;   Make the checkout visible as collection `webracket` for #lang tests.
(define (call-with-webracket-collection-path thunk)
  (parameterize ([current-library-collection-paths
                  (cons repo-parent (current-library-collection-paths))])
    (thunk)))

;; read-module-file : path-string? -> syntax?
;;   Read a #lang module through host Racket with the checkout on the collection path.
(define (read-module-file path)
  (call-with-webracket-collection-path
   (lambda ()
     (define resolved (simplify-path (path->complete-path path)))
     (parameterize ([current-directory (or (path-only resolved)
                                           (current-directory))])
       (call-with-input-file resolved
         (lambda (in)
           (port-count-lines! in)
           (with-module-reading-parameterization
             (lambda ()
               (read-syntax resolved in)))))))))

;; compile-module-file-report : path-string? -> webify-module-report?
;;   Compile one module file while resolving relative requires from its directory.
(define (compile-module-file-report path)
  (call-with-webracket-collection-path
   (lambda ()
     (define resolved (simplify-path (path->complete-path path)))
     (parameterize ([current-directory (or (path-only resolved)
                                           (current-directory))])
       (webify-compile-module-report
        (syntax->datum (read-module-file resolved)))))))

;; synthetic-provider-report : symbol? (listof symbol?) -> webify-module-report?
;;   Build a tiny provider report for bridge graph-composition tests.
(define (synthetic-provider-report name exports)
  (webify-module-report
   name
   '(#f)
   '(0)
   '()
   '()
   exports
   `(linklet () ,exports
      ,@(for/list ([export (in-list exports)])
          `(define-values (,export) ',export)))
   #t
   '()))

;; js-log-module-variable-ref-observation? : any/c -> boolean?
;;   Recognize a normalized observation that reads a composed module export cell.
(define (js-log-module-variable-ref-observation? datum)
  (and (list? datum)
       (= (length datum) 2)
       (equal? (car datum) "js-log")
       (let ([arg (cadr datum)])
         (and (list? arg)
              (= (length arg) 2)
              (equal? (car arg) "module-variable-ref")
              (string? (cadr arg))))))

;; module-runtime-export-symbols : symbol? -> (listof symbol?)
;;   List phase-0 value exports for an already-loadable module path.
(define (module-runtime-export-symbols module-path)
  (call-with-webracket-collection-path
   (lambda ()
     (parameterize ([current-namespace (make-base-namespace)])
       (current-library-collection-paths
        (cons repo-parent (current-library-collection-paths)))
       (namespace-require module-path)
       (define-values (value-exports _syntax-exports)
         (module->exports module-path))
       (define phase-0 (assoc 0 value-exports))
       (if phase-0
           (map car (cdr phase-0))
           '())))))

(test-case "#lang webracket/base reads as a real module"
  (define source-dir (make-temporary-file "webracket-base-lang-src-~a" 'directory))
  (define source-path (build-path source-dir "base-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(provide answer)\n(define answer (+ 40 2))\n" out))
        #:exists 'truncate/replace)
      (define module-stx (read-module-file source-path))
      (check-match (syntax->datum module-stx)
                   `(module base-smoke webracket/base . ,_))
      (define report
        (call-with-webracket-collection-path
         (lambda ()
           (webify-compile-module-report (syntax->datum module-stx)))))
      (check-equal? (webify-module-report-name report) 'base-smoke)
      (check-not-false (member 'answer
                               (webify-module-report-phase0-exports report))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/full exposes the curated add-on surface"
  (define source-dir (make-temporary-file "webracket-full-surface-src-~a" 'directory))
  (define source-path (build-path source-dir "surface-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/full\n"
            "(provide joined matched set-size forced formatted vec-pos bool-ok bytes-len)\n"
            "(define joined (string-join (map number->string (list 1 2 3)) \",\"))\n"
            "(define matched (match '(a b) [(list x y) (symbol->string y)]))\n"
            "(define set-size (set-count (set 1 2 2)))\n"
            "(define forced (force (delay (+ 20 22))))\n"
            "(define formatted (~a 'web))\n"
            "(define vec-pos (vector-member 'b '#(a b c)))\n"
            "(define bool-ok (boolean=? #t (not #f)))\n"
            "(define bytes-len (bytes-length #\"web\"))\n")
           out))
        #:exists 'truncate/replace)
      (define module-stx (read-module-file source-path))
      (check-match (syntax->datum module-stx)
                   `(module surface-smoke webracket/full . ,_))
      (define report
        (call-with-webracket-collection-path
         (lambda ()
           (webify-compile-module-report (syntax->datum module-stx)))))
      (for ([name (in-list '(joined matched set-size forced formatted
                                    vec-pos bool-ok bytes-len))])
        (check-not-false (member name
                                 (webify-module-report-phase0-exports report))
                         (symbol->string name))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base does not export full-only library bindings"
  (define base-exports (module-runtime-export-symbols 'webracket/base))
  (define full-exports (module-runtime-export-symbols 'webracket/full))
  (for ([name (in-list '(vector-member boolean=? bytes-join identity set-count))])
    (check-false (memq name base-exports)
                 (symbol->string name))
    (check-not-false (memq name full-exports)
                     (symbol->string name))))

(test-case "#lang webracket/base runs through the driver as module-language input"
  (define source-dir (make-temporary-file "webracket-base-driver-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-driver-dest-~a" 'directory))
  (define source-path (build-path source-dir "base-driver-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(js-log (+ 40 2))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/full runs through the driver as module-language input"
  (define source-dir (make-temporary-file "webracket-full-driver-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-full-driver-dest-~a" 'directory))
  (define source-path (build-path source-dir "full-driver-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/full\n(js-log (+ 40 2))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base fails clearly without collection resolution"
  (define source-dir (make-temporary-file "webracket-base-no-collection-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-no-collection-dest-~a" 'directory))
  (define source-path (build-path source-dir "base-no-collection.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(js-log 42)\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/no-collection
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-not-equal? status 0 output)
      (check-true
       (or (regexp-match? #rx"cannot resolve #lang webracket/base" output)
           (regexp-match? #rx"collection not found" output))
       output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base reaches staged format provider through the driver"
  (define source-dir (make-temporary-file "webracket-base-format-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-format-dest-~a" 'directory))
  (define source-path (build-path source-dir "base-format-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(js-log (format \"fmt ~a ~s ~e\" 'ok 'write '(err)))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^fmt ok write \\(err\\)$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge reaches staged format provider"
  (define source-dir (make-temporary-file "webracket-base-bridge-format-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-bridge-format-dest-~a" 'directory))
  (define source-path (build-path source-dir "base-bridge-format-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(js-log (format \"fmt ~a ~s\" 'ok 'write))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib"
               "--webracket-base-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^fmt ok write$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base supports a simple local string require"
  (define source-dir (make-temporary-file "webracket-base-local-require-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-local-require-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files dir))))))

(test-case "#lang webracket/base defaults local-only programs to module bridge"
  (define source-dir (make-temporary-file "webracket-base-default-bridge-src-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define lowered
        (call-with-webracket-collection-path
         (lambda ()
           (syntax->datum
            (read-top-level-from-file main-path
                                      #:webracket-base-module-bridge? #f)))))
      (check-true
       (let loop ([v lowered])
         (cond
           [(eq? v 'module-variable-ref) #t]
           [(pair? v) (or (loop (car v)) (loop (cdr v)))]
           [(vector? v) (for/or ([elem (in-vector v)]) (loop elem))]
           [else #f]))
       (format "~s" lowered)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base rejects unsupported transitional require specs"
  (define source-dir (make-temporary-file "webracket-base-unsupported-require-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-unsupported-require-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require (except-in \"lib.rkt\" add2))\n(js-log (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-not-equal? status 0 output)
      (check-regexp-match #rx"(unsupported #lang webracket/base local require spec|unbound identifier)"
                          output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base local require hides unprovided private bindings"
  (define source-dir (make-temporary-file "webracket-base-private-require-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-private-require-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(provide add2)\n"
            "(define (helper x) (+ x 2))\n"
            "(define (add2 x) (helper x))\n")
           out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (helper 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-not-equal? status 0 output)
      (check-regexp-match #rx"helper" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base local modules extract as module reports"
  (define source-dir (make-temporary-file "webracket-base-report-graph-src-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(provide answer)\n(define answer (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define lib-report (compile-module-file-report lib-path))
      (define main-report (compile-module-file-report main-path))
      (check-equal? (webify-module-report-name lib-report) 'lib)
      (check-equal? (webify-module-report-name main-report) 'main)
      (check-not-false (member 'add2 (webify-module-report-phase0-exports lib-report)))
      (check-not-false (member 'answer (webify-module-report-phase0-exports main-report))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base local files extract as a module graph"
  (define source-dir (make-temporary-file "webracket-base-local-graph-src-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(provide answer)\n(define answer (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define graph
        (call-with-webracket-collection-path
         (lambda ()
           (webracket/base-file->local-module-graph main-path))))
      (check-equal? (webracket/base-local-module-graph-root graph) 'main)
      (check-equal?
       (map webify-module-report-name
            (webracket/base-local-module-graph-reports graph))
       '(lib main))
      (check-equal?
       (webify-module-registry-plan
        (webracket/base-local-module-graph-registry graph)
        '(main))
       '(module-protocol lib main)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base bridge leaves collection requires for provider discovery"
  (define source-dir (make-temporary-file "webracket-base-provider-route-src-~a" 'directory))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require (only-in racket/list first))\n(provide answer)\n(define answer first)\n" out))
        #:exists 'truncate/replace)
      (define-values (root reports)
        (call-with-webracket-collection-path
         (lambda ()
           (webracket/base-file->local-module-reports main-path))))
      (check-equal? root 'main)
      (check-equal? (map webify-module-report-name reports) '(main))
      (check-not-false
       (member 'racket/list
               (webify-module-report-required-provider-names (car reports))))
      (define list-report
        (webify-module-report
         'racket/list
         '(#f)
         '(0)
         '()
         '()
         '(first)
         '(linklet () (first)
            (define-values (first) 'first))
         #t
         '()))
      (define registry
        (webify-module-reports->discovered-registry
         reports
         #:extra-reports (list webify-module-protocol-report)
         #:fetch-provider (lambda (name)
                            (check-equal? name 'racket/list)
                            list-report)
         #:module-protocol-dependency webify-module-protocol-dependency))
      (check-equal? (webify-module-registry-plan registry '(main))
                    '(module-protocol racket/list main)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base classifies external provider demands"
  (define source-dir (make-temporary-file "webracket-base-provider-classifier-src-~a" 'directory))
  (define plain-path (build-path source-dir "plain.rkt"))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define local-path (build-path source-dir "local.rkt"))
  (define list-path  (build-path source-dir "list.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file plain-path
        (lambda (out)
          (display "#lang webracket/base\n(js-log 42)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide answer)\n(define answer 42)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file local-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(js-log answer)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file list-path
        (lambda (out)
          (display "#lang webracket/base\n(require racket/list)\n(js-log (first '(42 99)))\n" out))
        #:exists 'truncate/replace)
      (define (reports path)
        (call-with-webracket-collection-path
         (lambda ()
           (define-values (_root reports) (webracket/base-file->local-module-reports path))
           reports)))
      (check-equal? (webracket/base-external-provider-names (reports plain-path)) '())
      (check-false (webracket/base-reports-demand-external-providers? (reports plain-path)))
      (check-equal? (webracket/base-external-provider-names (reports local-path)) '())
      (check-false (webracket/base-reports-demand-external-providers? (reports local-path)))
      (check-equal? (webracket/base-external-provider-names (reports list-path))
                    '(racket/list))
      (check-true (webracket/base-reports-demand-external-providers? (reports list-path))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base provider discovery composes with a tiny allowlisted provider"
  (define source-dir (make-temporary-file "webracket-base-provider-allowlist-src-~a" 'directory))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require (only-in racket/list first))\n(provide answer)\n(define answer first)\n" out))
        #:exists 'truncate/replace)
      (define-values (root reports)
        (call-with-webracket-collection-path
         (lambda ()
           (webracket/base-file->local-module-reports main-path))))
      (define list-report
        (webify-module-report
         'racket/list
         '(#f)
         '(0)
         '()
         '()
         '(first)
         '(linklet () (first)
            (define-values (first) 'first))
         #t
         '()))
      (define graph
        (webracket/base-reports->module-graph
         root
         reports
         #:fetch-provider
         (lambda (name)
           (check-equal? name 'racket/list)
           list-report)))
      (check-equal? (webify-module-registry-plan
                     (webracket/base-local-module-graph-registry graph)
                     '(main))
                    '(module-protocol racket/list main))
      (check-equal?
       (webify-module-report-import-export-demands
        (car reports)
        (list list-report)
        #:module-protocol-dependency webify-module-protocol-dependency)
       (list (webify-module-export-demand 'module-protocol
                                           '(.get-syntax-literal! .set-transformer!))
             (webify-module-export-demand 'racket/list '(first)))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base provider discovery cuts language-root providers"
  (call-with-webracket-collection-path
   (lambda ()
     (define list-report
       (webify-compile-module-report
        '(module racket/list racket/base
           (require webracket/base/main)
           (provide first)
           (define first 'first))))
     (define fetched '())
     (define graph
       (webracket/base-reports->module-graph
        'racket/list
        (list list-report)
        #:fetch-provider
        (lambda (name)
          (set! fetched (append fetched (list name)))
          (error 'fetch-provider "unexpected fetch: ~s" name))))
     (check-equal? fetched '())
     (check-equal? (webify-module-registry-plan
                    (webracket/base-local-module-graph-registry graph)
                    '(racket/list))
                   '(module-protocol racket/list)))))

(test-case "#lang webracket/base provider discovery rejects providers outside the trial allowlist"
  (define source-dir (make-temporary-file "webracket-base-provider-reject-src-~a" 'directory))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require (only-in racket/math sqr))\n(provide answer)\n(define answer sqr)\n" out))
        #:exists 'truncate/replace)
      (define-values (root reports)
        (call-with-webracket-collection-path
         (lambda ()
           (webracket/base-file->local-module-reports main-path))))
      (check-exn
       #rx"external provider is not in the Goal 1 trial allowlist"
       (lambda ()
         (webracket/base-reports->module-graph root reports))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base installed provider reports are disk-cached"
  (define cache-dir (make-temporary-file "webracket-provider-report-cache-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define fetch-count 0)
      (define (fetch name)
        (set! fetch-count (add1 fetch-count))
        (synthetic-provider-report name '(answer)))
      (parameterize ([current-provider-cache-dir cache-dir]
                     [current-provider-cache-force? #f])
        (define report-1 (cached-installed-provider-report 'racket/list fetch))
        (define report-2 (cached-installed-provider-report 'racket/list fetch))
        (check-equal? fetch-count 1)
        (check-equal? (webify-module-report-name report-1) 'racket/list)
        (check-equal? (webify-module-report-name report-2) 'racket/list)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files cache-dir)))))

(test-case "#lang webracket/base provider allowlist covers current Goal 1 trials"
  (for ([name (in-list '(racket/list
                         racket/string
                         racket/bool
                         racket/vector
                         racket/function))])
    (check-not-false (memq name webify-provider-trial-module-allowlist)
                     (symbol->string name))
    (check-true (webify-provider-trial-module-allowed? name)
                (symbol->string name)))
  (check-false (webify-provider-trial-module-allowed? 'racket/promise))
  (check-false (webify-provider-trial-module-allowed? 'racket/private/promise))
  (check-false (webify-provider-trial-module-allowed? 'racket/private/for))
  (check-false (webify-provider-trial-module-allowed? 'racket/private/set))
  (check-false (webify-provider-trial-module-allowed? 'racket/math)))

(test-case "#lang webracket/base classifies curated installed provider demands"
  (define source-dir (make-temporary-file "webracket-base-curated-providers-src-~a" 'directory))
  (define cases
    '((vector   racket/vector   "(require (only-in racket/vector vector-member))\n(provide answer)\n(define answer vector-member)\n")
      (function racket/function "(require (only-in racket/function identity))\n(provide answer)\n(define answer identity)\n")
      (promise  (racket/promise racket/private/promise) "(require (only-in racket/promise force))\n(provide answer)\n(define answer force)\n")
      (stream   (racket/stream racket/private/for) "(require (only-in racket/stream stream-first))\n(provide answer)\n(define answer stream-first)\n")
      (set      (racket/set racket/private/set) "(require (only-in racket/set set-count))\n(provide answer)\n(define answer set-count)\n")))
  (dynamic-wind
    void
    (lambda ()
      (for ([case-row (in-list cases)])
        (match-define (list label expected-provider body) case-row)
        (define source-path
          (build-path source-dir (format "~a.rkt" label)))
        (call-with-output-file source-path
          (lambda (out)
            (fprintf out "#lang webracket/base\n~a" body))
          #:exists 'truncate/replace)
        (define reports
          (call-with-webracket-collection-path
           (lambda ()
             (define-values (_root reports)
               (webracket/base-file->local-module-reports source-path))
             reports)))
        (check-equal? (sorted-symbols (webracket/base-external-provider-names reports))
                      (sorted-symbols
                       (if (list? expected-provider)
                           expected-provider
                           (list expected-provider))))
        (check-true (webracket/base-reports-demand-external-providers? reports))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base composes a local module plus curated installed providers"
  (define source-dir (make-temporary-file "webracket-base-local-installed-src-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide local-answer)\n(define local-answer 40)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(require \"lib.rkt\"\n"
            "         (only-in racket/vector vector-member)\n"
            "         (only-in racket/function identity))\n"
            "(provide answer)\n"
            "(define answer (list local-answer vector-member identity))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (root reports)
        (call-with-webracket-collection-path
         (lambda ()
           (webracket/base-file->local-module-reports main-path))))
      (check-equal? root 'main)
      (define external-names
        (sorted-symbols (webracket/base-external-provider-names reports)))
      (cond
        [(null? external-names)
         ;; Some host-expander/linklet versions inline these small providers
         ;; enough that the bridge sees only the local graph.
         (check-false (webracket/base-reports-demand-external-providers? reports))]
        [else
         (check-equal? external-names
                       (sorted-symbols
                        '(racket/vector
                          racket/function)))
         (define fetched '())
         (define graph
           (webracket/base-reports->module-graph
            root
            reports
            #:fetch-provider
            (lambda (name)
              (set! fetched (append fetched (list name)))
              (case name
                [(racket/vector)   (synthetic-provider-report name '(vector-member))]
                [(racket/function) (synthetic-provider-report name '(identity))]
                [else (error 'fetch-provider "unexpected fetch: ~s" name)]))))
         (when (pair? fetched)
           (check-equal? (sorted-symbols fetched)
                         (sorted-symbols
                          '(racket/vector
                            racket/function))))
         (define plan
           (webify-module-registry-plan
            (webracket/base-local-module-graph-registry graph)
            '(main)))
         (check-equal? (last plan) 'main)
         (for ([name (in-list '(module-protocol
                                lib
                                racket/vector
                                racket/function))])
           (check-not-false (memq name plan)
                            (symbol->string name)))]))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base bridge discovers require-transformer local dependency from metadata"
  (define source-dir (make-temporary-file "webracket-base-require-syntax-src-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide answer)\n(define answer 42)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(require racket/require-syntax (for-syntax racket/base))\n"
            "(define-require-syntax local-lib\n"
            "  (lambda (stx) (datum->syntax stx \"lib.rkt\")))\n"
            "(require (local-lib))\n"
            "(provide answer)\n")
           out))
        #:exists 'truncate/replace)
      (define-values (root reports)
        (call-with-webracket-collection-path
         (lambda ()
           (webracket/base-file->local-module-reports main-path))))
      (check-equal? root 'main)
      (check-equal?
       (map webify-module-report-name reports)
       '(lib main)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "equivalent local graph composes through module registry"
  (define module-data
    '((module lib racket/base
        (provide add2)
        (define (add2 x) (+ x 2)))
      (module main racket/base
        (require 'lib)
        (provide answer)
        (define answer (add2 40)))))
  (define registry
    (webify-module-linklet-inputs->registry
     (cons webify-module-protocol-input
           (webify-source-modules->resolved-linklet-inputs
            module-data
            #:module-protocol-dependency webify-module-protocol-dependency))))
  (check-equal? (webify-module-registry-plan registry '(main))
                '(module-protocol lib main))
  (define-values (observed _fragments _exports _exports-info)
    (compose-module-registry/roots+observations registry '(main) '((main answer))))
  (check-not-false
   (for/or ([datum (in-list (normalize-symbols observed))])
     (js-log-module-variable-ref-observation? datum)))
  (check-true (string-contains? (wat-string (comp (datum->syntax #f observed)))
                                "$module-variable-ref")))

(test-case "flattened and composed two-module paths both observe answer"
  (define source-dir (make-temporary-file "webracket-base-flat-vs-composed-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-flat-vs-composed-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide answer)\n(define answer 42)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(js-log answer)\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output)
      (define registry
        (webify-module-linklet-inputs->registry
         (cons webify-module-protocol-input
               (webify-source-modules->resolved-linklet-inputs
                '((module lib racket/base
                    (provide answer)
                    (define answer 42)))
                #:module-protocol-dependency webify-module-protocol-dependency))))
      (define-values (observed _fragments _exports _exports-info)
        (compose-module-registry/roots+observations registry '(lib) '((lib answer))))
      (check-not-false
       (for/or ([datum (in-list (normalize-symbols observed))])
         (js-log-module-variable-ref-observation? datum))))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge flag runs a local require graph"
  (define source-dir (make-temporary-file "webracket-base-bridge-run-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-bridge-run-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-base-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base flattening and bridge agree on simple local require"
  (define source-dir (make-temporary-file "webracket-base-bridge-agree-src-~a" 'directory))
  (define flat-dir   (make-temporary-file "webracket-base-bridge-agree-flat-dest-~a" 'directory))
  (define bridge-dir (make-temporary-file "webracket-base-bridge-agree-bridge-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"lib.rkt\")\n(js-log (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (flat-status flat-output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string flat-dir)
               (path->string main-path))
         source-dir))
      (define-values (bridge-status bridge-output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-base-module-bridge"
               "--dest" (path->string bridge-dir)
               (path->string main-path))
         source-dir))
      (check-equal? flat-status 0 flat-output)
      (check-equal? bridge-status 0 bridge-output)
      (check-regexp-match #rx"(?m:^42$)" flat-output)
      (check-regexp-match #rx"(?m:^42$)" bridge-output))
    (lambda ()
      (for ([dir (in-list (list source-dir flat-dir bridge-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge handles only-in local require"
  (define source-dir (make-temporary-file "webracket-base-bridge-only-in-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-bridge-only-in-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2 ignored)\n(define (add2 x) (+ x 2))\n(define ignored 0)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require (only-in \"lib.rkt\" add2))\n(js-log (add2 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-base-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge handles rename-in local require"
  (define source-dir (make-temporary-file "webracket-base-bridge-rename-in-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-bridge-rename-in-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require (rename-in \"lib.rkt\" [add2 plus2]))\n(js-log (plus2 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-base-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge handles prefix-in local require"
  (define source-dir (make-temporary-file "webracket-base-bridge-prefix-in-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-bridge-prefix-in-dest-~a" 'directory))
  (define lib-path   (build-path source-dir "lib.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file lib-path
        (lambda (out)
          (display "#lang webracket/base\n(provide add2)\n(define (add2 x) (+ x 2))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require (prefix-in lib: \"lib.rkt\"))\n(js-log (lib:add2 40))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-base-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base supports multiple local requires with shared dependency"
  (define source-dir (make-temporary-file "webracket-base-multi-require-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-multi-require-dest-~a" 'directory))
  (define core-path  (build-path source-dir "core.rkt"))
  (define a-path     (build-path source-dir "a.rkt"))
  (define b-path     (build-path source-dir "b.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file core-path
        (lambda (out)
          (display "#lang webracket/base\n(provide base)\n(define base 20)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file a-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"core.rkt\")\n(provide a-val)\n(define a-val (+ base 1))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file b-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"core.rkt\")\n(provide b-val)\n(define b-val (+ base 1))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"a.rkt\" \"b.rkt\")\n(js-log (+ a-val b-val))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge handles shared local dependency"
  (define source-dir (make-temporary-file "webracket-base-bridge-multi-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-bridge-multi-dest-~a" 'directory))
  (define core-path  (build-path source-dir "core.rkt"))
  (define a-path     (build-path source-dir "a.rkt"))
  (define b-path     (build-path source-dir "b.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file core-path
        (lambda (out)
          (display "#lang webracket/base\n(provide base)\n(define base 20)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file a-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"core.rkt\")\n(provide a-val)\n(define a-val (+ base 1))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file b-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"core.rkt\")\n(provide b-val)\n(define b-val (+ base 1))\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"a.rkt\" \"b.rkt\")\n(js-log (+ a-val b-val))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-base-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base supports one local re-export hop"
  (define source-dir (make-temporary-file "webracket-base-reexport-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-reexport-dest-~a" 'directory))
  (define a-path     (build-path source-dir "a.rkt"))
  (define b-path     (build-path source-dir "b.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file a-path
        (lambda (out)
          (display "#lang webracket/base\n(provide answer)\n(define answer 42)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file b-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"a.rkt\")\n(provide answer)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"b.rkt\")\n(js-log answer)\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge handles one local re-export hop"
  (define source-dir (make-temporary-file "webracket-base-bridge-reexport-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-bridge-reexport-dest-~a" 'directory))
  (define a-path     (build-path source-dir "a.rkt"))
  (define b-path     (build-path source-dir "b.rkt"))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file a-path
        (lambda (out)
          (display "#lang webracket/base\n(provide answer)\n(define answer 42)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file b-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"a.rkt\")\n(provide answer)\n" out))
        #:exists 'truncate/replace)
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(require \"b.rkt\")\n(js-log answer)\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-base-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base preserves simple provides as module-variable cells"
  (define source-dir (make-temporary-file "webracket-base-export-cell-src-~a" 'directory))
  (define source-path (build-path source-dir "export_cell.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(provide answer)\n(define answer 42)\n" out))
        #:exists 'truncate/replace)
      (define lowered
        (call-with-webracket-collection-path
         (lambda ()
           (syntax->datum (read-top-level-from-file source-path)))))
      (check-true
       (let loop ([v lowered])
         (cond
           [(eq? v 'module-variable-define!) #t]
           [(pair? v) (or (loop (car v)) (loop (cdr v)))]
           [(vector? v) (for/or ([elem (in-vector v)]) (loop elem))]
           [else #f]))
       (format "~s" lowered)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "webracket/base surface manifest stays small"
  (check-equal? webracket-base-foundation 'racket/base)
  (check-equal? webracket-base-addon-libraries '())
  (check-equal? webracket-base-surface-statuses
                '((racket/base exported extracts partial partial)))
  (for ([name (in-list '(racket/list racket/string racket/vector racket/function
                                     racket/bool racket/promise racket/sequence
                                     racket/set racket/match racket/format))])
    (check-not-false (memq name webracket-base-deferred-libraries)
                     (symbol->string name))))

(test-case "webracket/full surface manifest distinguishes foundation and add-ons"
  (check-equal? webracket-full-foundation 'racket/base)
  (check-false (memq 'racket/base webracket-full-addon-libraries))
  (for ([name (in-list '(racket/list racket/string racket/vector racket/function
                                     racket/bool racket/promise racket/sequence
                                     racket/set racket/match racket/format))])
    (check-not-false (memq name webracket-full-addon-libraries)
                     (symbol->string name)))
  (check-not-false (assoc 'racket/format webracket-full-surface-statuses))
  (check-not-false (assoc 'racket/list webracket-full-surface-statuses)))

(test-case "webracket/full surface statuses cover every curated add-on"
  (define status-names (map car webracket-full-surface-statuses))
  (for ([name (in-list webracket-full-addon-libraries)])
    (check-not-false (memq name status-names)
                     (symbol->string name)))
  (check-equal? (assoc 'racket/format webracket-full-surface-statuses)
                '(racket/format exported extracts partial runs)))

(test-case "#lang webracket remains script-compatible in the driver"
  (define source-dir (make-temporary-file "webracket-script-lang-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-script-lang-dest-~a" 'directory))
  (define source-path (build-path source-dir "script-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket\n(js-log (+ 40 2))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket (list "-r" "--no-stdlib"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir
                       #:timeout-seconds 120
                       #:memory-mb 1024))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(module+ main
  (void))
