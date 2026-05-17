#lang racket/base

(require racket/file
         racket/path
         racket/runtime-path
         rackunit
         syntax/modread
         "test-module-support.rkt"
         "webracket-base-surface.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

(define repo-parent
  (let-values ([(base name must-be-dir?) (split-path repo-root)])
    base))

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
