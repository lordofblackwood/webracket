#lang racket/base

(require racket/file
         racket/path
         racket/runtime-path
         rackunit
         syntax/modread
         (only-in "../driver.rkt" read-top-level-from-file)
         "test-module-support.rkt"
         "webracket-base-surface.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

(define repo-parent
  (let-values ([(base name must-be-dir?) (split-path repo-root)])
    base))

(define path-list-separator
  (if (eq? (system-type 'os) 'windows) ";" ":"))

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
     (call-with-input-file path
       (lambda (in)
         (port-count-lines! in)
         (with-module-reading-parameterization
           (lambda ()
             (read-syntax path in))))))))

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

(test-case "#lang webracket/base exposes the first curated add-on surface"
  (define source-dir (make-temporary-file "webracket-base-surface-src-~a" 'directory))
  (define source-path (build-path source-dir "surface-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
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
                   `(module surface-smoke webracket/base . ,_))
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
      (check-match lowered
                   `(begin
                      (define answer 42)
                      (begin
                        (define webify-module-export-cell$export_cell$answer
                          (module-variable-make 'answer))
                        (module-variable-define!
                         webify-module-export-cell$export_cell$answer
                         answer
                         'constant)))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "webracket/base surface manifest distinguishes foundation and add-ons"
  (check-equal? webracket-base-foundation 'racket/base)
  (check-false (memq 'racket/base webracket-base-addon-libraries))
  (for ([name (in-list '(racket/list racket/string racket/vector racket/function
                                     racket/bool racket/promise racket/sequence
                                     racket/set racket/match racket/format))])
    (check-not-false (memq name webracket-base-addon-libraries)
                     (symbol->string name)))
  (check-not-false (assoc 'racket/format webracket-base-surface-statuses))
  (check-not-false (assoc 'racket/list webracket-base-surface-statuses)))

(test-case "webracket/base surface statuses cover every curated add-on"
  (define status-names (map car webracket-base-surface-statuses))
  (for ([name (in-list webracket-base-addon-libraries)])
    (check-not-false (memq name status-names)
                     (symbol->string name)))
  (check-equal? (assoc 'racket/format webracket-base-surface-statuses)
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
