#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         (except-in rackunit test-case)
         (only-in rackunit [test-case wr-rackunit-test-case])
         syntax/modread
         (prefix-in staged-promise: "../pkgs/webracket/promise.rkt")
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  cached-installed-provider-report
                  current-provider-cache-dir
                  current-provider-cache-force?
                  module-file->module-bridge-top-level
                  provider-report-cache-entries
                  provider-compile-stub-safe?
                  read-top-level-from-file
                  webracket/base-external-provider-names
                  webracket/base-file->local-module-graph
                  webracket/base-file->local-module-reports
                  webracket/base-local-module-graph-root
                  webracket/base-local-module-graph-reports
                  webracket/base-local-module-graph-registry
                  webracket/base-provider-substitute
                  webracket/base-provider-substitution-pairs
                  webracket/base-reports->module-graph
                  webracket/base-reports-demand-external-providers?)
         (only-in "../pkgs/webracket-lib/compiler/private/parameters.rkt"
                  current-runtime-cache-dir)
         (only-in "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
                  webify-compile-module-report)
         (only-in "../pkgs/webracket-lib/compiler/webify/provider-trials.rkt"
                  webify-provider-trial-default-bridge-module-allowed?
                  webify-provider-trial-module-allowlist
                  webify-provider-trial-module-allowed?)
         "../pkgs/webracket-lib/compiler/webify/ffi-module-registry.rkt"
         "../pkgs/webracket-lib/compiler/webify/unsafe-ffi-module.rkt"
         "ffi-migration-status.rkt"
         "test-module-support.rkt"
         "../pkgs/webracket-lib/compiler/webify/webracket-base-surface.rkt"
         "webracket-full-dashboard.rkt"
         "../pkgs/webracket-lib/compiler/webify/webracket-full-surface.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

;; selected-test-substrings : (listof string?)
;;   Optional comma-separated filter for quick local runs of this large suite.
(define selected-test-substrings
  (let ([raw (getenv "WEBRACKET_BASE_LANG_TEST_FILTER")])
    (if (and raw (not (string=? raw "")))
        (filter non-empty-string? (string-split raw ","))
        '())))

;; selected-test? : string? -> boolean?
;;   Keep tests enabled by default, or run cases whose names contain a filter.
(define (selected-test? name)
  (or (null? selected-test-substrings)
      (for/or ([needle (in-list selected-test-substrings)])
        (regexp-match? (regexp-quote needle) name))))

(define-syntax-rule (test-case name body ...)
  (wr-rackunit-test-case name
    (when (selected-test? name)
      body ...)))

;; sorted-symbols : (listof symbol?) -> (listof symbol?)
;;   Compare provider-name sets without depending on discovery order.
(define (sorted-symbols symbols)
  (sort symbols symbol<?))

;; webracket-collection-env : -> (listof string?)
;;   Make child Racket processes resolve this checkout as collection `webracket`.
(define (webracket-collection-env)
  (list (format "PLTCOLLECTS=~a" (webracket-collection-env-value))))

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

;; timing-parse-node-count : string? -> (or/c exact-nonnegative-integer? #f)
;;   Extract the parse node count from the compiler timing table.
(define (timing-parse-node-count output)
  (for/or ([line (in-list (string-split output "\n"))])
    (match (regexp-match #rx"^  parse[ ]+:.*[ ]([0-9]+)$" line)
      [(list _ count) (string->number count)]
      [_ #f])))

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
  (define linklet-datum
    `(linklet () ,exports
       ,@(for/list ([export (in-list exports)])
           `(define-values (,export) ',export))))
  (webify-module-report
   name
   '(#f)
   '(0)
   (list (webify-module-bundle-entry
          0
          'linklet
          '()
          exports
          linklet-datum
          #f))
   '()
   exports
   linklet-datum
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

;; datum-contains-symbol? : any/c symbol? -> boolean?
;;   Search a lowered datum tree for a symbol.
(define (datum-contains-symbol? datum needle)
  (cond
    [(eq? datum needle) #t]
    [(pair? datum)
     (or (datum-contains-symbol? (car datum) needle)
         (datum-contains-symbol? (cdr datum) needle))]
    [(vector? datum)
     (for/or ([elem (in-vector datum)])
       (datum-contains-symbol? elem needle))]
    [else #f]))

;; datum-contains-module-print-values-discard? : any/c -> boolean?
;;   Search for the module bridge's discard implementation of print-values.
(define (datum-contains-module-print-values-discard? datum)
  (cond
    [(match datum
       [`(module-variable-define! ,_cell (lambda values (void)) 'constant) #t]
       [_ #f])
     #t]
    [(pair? datum)
     (or (datum-contains-module-print-values-discard? (car datum))
         (datum-contains-module-print-values-discard? (cdr datum)))]
    [(vector? datum)
     (for/or ([elem (in-vector datum)])
       (datum-contains-module-print-values-discard? elem))]
    [else #f]))

;; module-runtime-export-symbols : symbol? -> (listof symbol?)
;;   List phase-0 value exports for an already-loadable module path.
(define (module-runtime-export-symbols module-path)
  (call-with-webracket-collection-path
   (lambda ()
     (parameterize ([current-namespace (make-base-namespace)])
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

(test-case "#lang webracket/base 42 stays on the tiny module bridge path"
  (define source-dir (make-temporary-file "webracket-base-timing-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-timing-dest-~a" 'directory))
  (define source-path (build-path source-dir "base42.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n42\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "--timings"
               "--no-stdlib"
               "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"=== Read Source Details ===" output)
      (for ([label (in-list '("module-bridge-extract"
                              "module-bridge-compose"))])
        (check-regexp-match (regexp (regexp-quote label)) output))
      (define parse-nodes (timing-parse-node-count output))
      (check-not-false parse-nodes output)
      ;; This guards against accidental order-of-magnitude growth; the backend
      ;; still parses the assembled runtime, so the count is not just user code.
      (check-true (< parse-nodes 120000)
                  (format "parse node count unexpectedly grew: ~a" parse-nodes)))
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

(test-case "#lang webracket/full runs representative curated libraries"
  (define source-dir (make-temporary-file "webracket-full-curated-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-full-curated-dest-~a" 'directory))
  (define source-path (build-path source-dir "full-curated-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/full\n"
            "(define joined (string-join (map number->string '(1 2 3)) \"\"))\n"
            "(define picked (match '(alpha beta) [(list _ y) y]))\n"
            "(define vec-pos (vector-member 'b '#(a b c)))\n"
            "(define bytes-len (bytes-length #\"abc\"))\n"
            "(define bool-bonus (if (boolean=? #t (not #f)) 3 0))\n"
            "(js-log (+ (string-length joined) vec-pos bytes-len bool-bonus))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^10$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/full exposes racket/class"
  (define source-dir (make-temporary-file "webracket-full-class-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-full-class-dest-~a" 'directory))
  (define source-path (build-path source-dir "full-class-smoke.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/full\n"
            "(define point%\n"
            "  (class object%\n"
            "    (super-new)\n"
            "    (define/public (value) 42)))\n"
            "(js-log (send (new point%) value))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/full callable exports stay usable through the bridge"
  (define source-dir (make-temporary-file "webracket-full-callable-exports-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-full-callable-exports-dest-~a" 'directory))
  (define source-path (build-path source-dir "full-callable-exports.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/full\n"
            "(define pos (vector-member 'b '#(a b c)))\n"
            "(define f identity)\n"
            "(define s (set-add (set 'a) 'b))\n"
            "(define h (hash 'x 37))\n"
            "(js-log (+ pos (f 2) (set-count s) (hash-ref h 'x)))\n")
           out))
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

(test-case "#lang webracket/full uses staged set and promise providers"
  (define source-dir (make-temporary-file "webracket-full-staged-set-promise-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-full-staged-set-promise-dest-~a" 'directory))
  (define source-path (build-path source-dir "full-staged-set-promise.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/full\n"
            "(define s (set-add (set 1 2 2) 3))\n"
            "(define intersect-count (set-count (set-intersect s (set 2 3 4))))\n"
            "(define relation-bonus (+ (if (subset? (set 2 3) s) 1 0)\n"
            "                          (if (proper-subset? (set 2) s) 1 0)\n"
            "                          (if (set=? s (set 3 2 1)) 1 0)))\n"
            "(define filter-count (set-count (set-filter s odd?)))\n"
            "(define map-count (length (set-map s add1)))\n"
            "(define p (delay (+ (set-count s) 39)))\n"
            "(define before (promise-forced? p))\n"
            "(define value (force p))\n"
            "(js-log (+ value intersect-count relation-bonus filter-count map-count\n"
            "           (if before 100 0) (if (set-member? s 2) 1 0)))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^53$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/full staged set exposes list conversion operations"
  (define source-dir (make-temporary-file "webracket-full-staged-set-list-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-full-staged-set-list-dest-~a" 'directory))
  (define source-path (build-path source-dir "full-staged-set-list.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/full\n"
            "(define s (set 'a 'b 'c))\n"
            "(define r (set-rest s))\n"
            "(js-log (+ (length (set->list s))\n"
            "           (set-count r)\n"
            "           (if (set-member? s (set-first s)) 10 0)))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^15$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base can require staged stream provider by default"
  (define source-dir (make-temporary-file "webracket-full-staged-stream-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-full-staged-stream-dest-~a" 'directory))
  (define source-path (build-path source-dir "full-staged-stream.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(require webracket/stream)\n"
            "(define s (stream 10 20 12))\n"
            "(define r (stream-rest s))\n"
            "(js-log (+ (stream-first s) (stream-first r) (stream-first (stream-rest r))))\n")
           out))
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

(test-case "staged set and stream providers share a stream module instance"
  (define source-dir (make-temporary-file "webracket-set-stream-instance-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-set-stream-instance-dest-~a" 'directory))
  (define cache-dir  (make-temporary-file "webracket-set-stream-instance-cache-~a" 'directory))
  (define source-path (build-path source-dir "set-stream-instance.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(require racket/set webracket/stream)\n"
            "(define stream-sum (for/sum ([x (in-stream (stream 1 2 3))]) x))\n"
            "(define set-sum (for/sum ([x (in-set (set 10 20 12))]) x))\n"
            "(js-log (+ stream-sum set-sum))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--provider-cache-dir" (path->string cache-dir)
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^48$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir cache-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "staged promise provider caches multiple values and exceptions"
  (define multi (staged-promise:delay (values 20 22)))
  (define multi-sum
    (call-with-values (lambda () (staged-promise:force multi)) +))
  (check-equal? multi-sum 42)
  (check-true (staged-promise:promise-forced? multi))
  (define attempts 0)
  (define failing
    (staged-promise:delay
      (set! attempts (add1 attempts))
      (error 'promise-smoke "boom")))
  (for ([i (in-range 2)])
    (check-exn #rx"boom" (lambda () (staged-promise:force failing))))
  (check-equal? attempts 1)
  (check-true (staged-promise:promise-forced? failing)))

(test-case "#lang webracket/base reports clearly or uses installed collection without explicit env"
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
      (cond
        [(zero? status)
         (check-regexp-match #rx"(?m:^42$)" output)]
        [else
         (check-true
          (or (regexp-match? #rx"cannot resolve #lang webracket/base" output)
              (regexp-match? #rx"collection not found" output))
          output)]))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base composes staged format provider"
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

(test-case "#lang webracket/base forced bridge composes staged format provider"
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
               "--webracket-module-bridge"
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
                                      #:webracket-module-bridge? #f)))))
      (check-true
       (datum-contains-symbol? lowered 'module-variable-ref)
       (format "~s" lowered)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base module bridge discards module body expression values"
  (define source-dir (make-temporary-file "webracket-base-discard-values-src-~a" 'directory))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/base\n(cons 1 2)\n(cons 3 4)\n" out))
        #:exists 'truncate/replace)
      (define lowered
        (call-with-webracket-collection-path
         (lambda ()
           (parameterize ([current-directory source-dir])
             (syntax->datum
              (module-file->module-bridge-top-level main-path))))))
      (check-true
       (datum-contains-symbol? lowered 'module-variable-make)
       (format "~s" lowered))
      (check-true
       (datum-contains-symbol? lowered 'print-values)
       (format "~s" lowered))
      (check-true
       (datum-contains-symbol? lowered 'module-variable-define!)
       (format "~s" lowered))
      (check-true
       (datum-contains-module-print-values-discard? lowered)
       (format "~s" lowered)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "#lang webracket/base module path skips stdlib even when flags request it"
  (define source-dir (make-temporary-file "webracket-base-stdlib-skip-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-stdlib-skip-dest-~a" 'directory))
  (define source-path (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(js-log 42)\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-v" "-r" "--stdlib"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"Ignoring legacy stdlib root for module-language input"
                          output)
      (check-regexp-match
       #rx"Skipping staged io/format provider for module-language input; module providers resolve racket/format directly"
       output)
      (check-regexp-match #rx"legacy-stdlib-mode[ ]*:[ ]*ignored-module-input"
                          output)
      (check-regexp-match #rx"io-format-provider-mode[ ]*:[ ]*skipped-module-input"
                          output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base provider-first lowered form has no stdlib cells"
  (define source-dir (make-temporary-file "webracket-base-provider-first-src-~a" 'directory))
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
      (define lowered
        (call-with-webracket-collection-path
         (lambda ()
           (syntax->datum
            (read-top-level-from-file main-path
                                      #:webracket-module-bridge? #f)))))
      (check-true (datum-contains-symbol? lowered 'module-variable-ref)
                  (format "~s" lowered))
      (check-false (datum-contains-symbol? lowered 'webify-stdlib-export-cell$0)
                   (format "~s" lowered))
      (check-false (datum-contains-symbol? lowered 'webify-io-format-export-cell$format)
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

(test-case "#lang webracket/base transitional reader ignores external provider requires"
  (define source-dir (make-temporary-file "webracket-base-external-require-src-~a" 'directory))
  (define main-path  (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file main-path
        (lambda (out)
          (display "#lang webracket/full\n(require racket/list racket/dict racket/pretty racket/sequence racket/format)\n(js-log 42)\n" out))
        #:exists 'truncate/replace)
      (check-not-exn
       (lambda ()
         (read-top-level-from-file main-path
                                   #:webracket-module-bridge? #f))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

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

(test-case "#lang webracket/base bridge preserves real collection requires for provider discovery"
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
                    '(main:syntax-literals module-protocol racket/list main)))
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

(test-case "#lang webracket/base compile stubs reject syntax-exporting providers"
  (for ([name (in-list '(racket/list
                         racket/string
                         racket/dict
                         racket/sequence
                         racket/private/for
                         racket/private/kw))])
    (check-false (provider-compile-stub-safe? name)
                 (symbol->string name)))
  (check-true (provider-compile-stub-safe? 'racket/unsafe/undefined)))

(test-case "#lang webracket/full treats racket/private/base as language-root metadata"
  (define source-dir (make-temporary-file "webracket-full-private-base-src-~a" 'directory))
  (define source-path (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/full\n"
            "(define immutable (seteq 'a 'b))\n"
            "(define mutable (mutable-seteq 'b 'c))\n"
            "(set-add! mutable 'd)\n"
            "(define symmetric (set-symmetric-difference immutable mutable))\n"
            "(define copied (set-copy immutable))\n"
            "(set-add! copied 'z)\n"
            "(define weak-ok (and (set-weak? (weak-seteq 'w))\n"
            "                     (set-eq? (weak-seteq 'w))))\n"
            "(js-log (+ (set-count symmetric)\n"
            "           (set-count copied)\n"
            "           (if weak-ok 10 0)))\n")
           out))
        #:exists 'truncate/replace)
      (define reports
        (call-with-webracket-collection-path
         (lambda ()
           (define-values (_root reports)
             (webracket/base-file->local-module-reports source-path))
           reports)))
      (check-false (memq 'racket/private/base
                         (webracket/base-external-provider-names reports))))
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
           (case name
             [(racket/list) list-report]
             [(webracket/contract) (synthetic-provider-report name '(contract))]
             [(webracket/private/format) (synthetic-provider-report name '(format))]
             [(webracket/private/kw) (synthetic-provider-report name '(keyword-apply))]
             [(webracket/unsafe/undefined) (synthetic-provider-report name '(unsafe-undefined))]
             [else (error 'fetch-provider "unexpected fetch: ~s" name)]))))
      (define plan
        (webify-module-registry-plan
         (webracket/base-local-module-graph-registry graph)
         '(main)))
      (check-equal? (last plan) 'main)
      (for ([name (in-list '(main:syntax-literals
                             module-protocol
                             racket/list))])
        (check-not-false (memq name plan)
                         (symbol->string name)))
      (check-equal?
       (webify-module-report-import-export-demands
        (car reports)
        (list list-report)
        #:module-protocol-dependency webify-module-protocol-dependency)
       (list (webify-module-export-demand 'main:syntax-literals
                                           '(.get-syntax-literal!))
             (webify-module-export-demand 'module-protocol
                                           '(.set-transformer!))
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
          (display "#lang webracket/base\n(require (only-in racket/tcp tcp-listen))\n(provide answer)\n(define answer tcp-listen)\n" out))
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

(test-case "#lang webracket/base installed provider reports use the shared runtime cache"
  (define project-cache-dir-1
    (make-temporary-file "webracket-provider-project-cache-~a" 'directory))
  (define project-cache-dir-2
    (make-temporary-file "webracket-provider-project-cache-~a" 'directory))
  (define runtime-cache-dir
    (make-temporary-file "webracket-provider-runtime-cache-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define fetch-count 0)
      (define (fetch name)
        (set! fetch-count (add1 fetch-count))
        (synthetic-provider-report name '(answer)))
      (parameterize ([current-runtime-cache-dir runtime-cache-dir]
                     [current-provider-cache-dir project-cache-dir-1]
                     [current-provider-cache-force? #f])
        (define report-1 (cached-installed-provider-report 'racket/list fetch))
        (define report-2
          (parameterize ([current-provider-cache-dir project-cache-dir-2])
            (cached-installed-provider-report 'racket/list fetch)))
        (check-equal? fetch-count 1)
        (check-equal? (webify-module-report-name report-1) 'racket/list)
        (check-equal? (webify-module-report-name report-2) 'racket/list)
        (check-true
         (andmap webify-module-bundle-entry?
                 (webify-module-report-bundle-entries report-2)))
        (define entries (provider-report-cache-entries))
        (check-equal? (length entries) 1)
        (match (call-with-input-file (caar entries) read)
          [(list (list 'installed-provider-report-cache
                       9
                       'racket/list
                       _racket-version
                       _provider-source
                       (list 'provider-report-extractor _ _ ...))
                 _payload)
           (void)]
          [other
           (fail-check
            (format "provider cache fingerprint omits extractor metadata: ~s"
                    other))])
        (check-regexp-match #rx"racket_list[.]rktd$"
                            (path->string (caar entries)))))
    (lambda ()
      (for ([dir (in-list (list project-cache-dir-1
                                 project-cache-dir-2
                                 runtime-cache-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "webracket/full dashboard tracks curated provider rows"
  (define rows (webracket-full-dashboard-rows))
  (for ([name (in-list '(racket/list racket/string racket/vector racket/function))])
    (check-not-false (assoc name rows)
                     (symbol->string name)))
  (define list-row (assoc 'racket/list rows))
  (define string-row (assoc 'racket/string rows))
  (define vector-row (assoc 'racket/vector rows))
  (define contract-row (assoc 'webracket/contract rows))
  (define hash-row (assoc 'webracket/hash rows))
  (define js-row (assoc 'webracket/js rows))
  (define promise-row (assoc 'webracket/promise rows))
  (define set-row (assoc 'webracket/set rows))
  (check-equal? (list-ref list-row 6) 'composes)
  (check-equal? (list-ref list-row 10) 'none)
  (check-equal? (list-ref string-row 3) 'real-racket-string-coverage)
  (check-equal? (list-ref string-row 6) 'composes)
  (check-equal? (list-ref string-row 10) 'none)
  (check-equal? (length vector-row) 11)
  (check-equal? (list-ref vector-row 1) 'racket/vector)
  (check-equal? (list-ref vector-row 2) 'real-provider-proven)
  (check-equal? (list-ref vector-row 3) 'installed-racket-vector-coverage)
  (check-equal? (list-ref vector-row 6) 'composes)
  (check-equal? (list-ref vector-row 8) 'allowlisted)
  (check-equal? (list-ref vector-row 9) 'passes)
  (check-equal? (list-ref vector-row 10) 'none)
  (check-equal? (list-ref contract-row 2) 'webracket-owned)
  (check-equal? (list-ref contract-row 8) 'allowlisted)
  (check-equal? (list-ref contract-row 9) 'passes)
  (check-equal? (list-ref hash-row 1) 'webracket/hash)
  (check-equal? (list-ref hash-row 2) 'webracket-owned)
  (check-equal? (list-ref js-row 1) 'webracket/js)
  (check-equal? (list-ref js-row 2) 'webracket-owned)
  (check-equal? (list-ref promise-row 8) 'allowlisted)
  (check-equal? (list-ref promise-row 9) 'passes)
  (check-equal? (list-ref set-row 8) 'allowlisted)
  (check-equal? (list-ref set-row 9) 'passes))

(test-case "#lang webracket/base provider allowlist covers current Goal 1 trials"
  (for ([name (in-list '(racket/list
                         racket/string
                         racket/bool
                         racket/bytes
                         racket/vector
                         racket/function
                         racket/math
                         racket/path))])
    (check-not-false (memq name webify-provider-trial-module-allowlist)
                     (symbol->string name))
    (check-true (webify-provider-trial-module-allowed? name)
                (symbol->string name)))
  (check-false (webify-provider-trial-module-allowed? 'racket/promise))
  (check-false (webify-provider-trial-module-allowed? 'racket/private/promise))
  (check-true (webify-provider-trial-module-allowed? 'racket/private/for))
  (check-true (webify-provider-trial-module-allowed? 'racket/private/sort))
  (check-false (webify-provider-trial-module-allowed? 'racket/private/set))
  (check-true (webify-provider-trial-module-allowed? 'racket/contract))
  (for ([name (in-list '(racket/bool racket/list racket/string racket/vector
                         racket/function racket/bytes racket/hash racket/set racket/match
                         racket/contract racket/math racket/path webracket/js
                         webracket/contract webracket/set webracket/promise webracket/sequence webracket/stream
                         racket/private/sort js/console js/math js/performance))])
    (check-true (webify-provider-trial-default-bridge-module-allowed? name)
                (symbol->string name)))
  (for ([row (in-list ffi-module-registry-rows)])
    (define module-name (ffi-module-registry-row-module row))
    (check-true (webify-provider-trial-default-bridge-module-allowed? module-name)
                (format "~a should be default-bridge allowlisted when backed by ~a"
                        module-name
                        (ffi-module-registry-row-ffi-filename row))))
  (for ([name (in-list '(racket/promise))])
    (check-false (webify-provider-trial-default-bridge-module-allowed? name)
                 (symbol->string name))))

(test-case "#lang webracket/base provider substitutions are deliberate"
  (define expected
    '((racket/contract . webracket/contract)
      (racket/contract/base . webracket/contract)
      (racket/contract/combinator . webracket/contract)
      (racket/contract/region . webracket/contract)
      (racket/contract/private/list . webracket/contract)
      (racket/contract/private/misc . webracket/contract)
      (racket/file . webracket/file)
      (racket/format . webracket/private/format)
      (racket/generator . webracket/generator)
      (racket/hash . webracket/hash)
      (racket/mpair . webracket/mpair)
      (racket/port . webracket/port)
      (racket/promise . webracket/promise)
      (racket/set . webracket/set)
      (racket/stream . webracket/stream)
      (racket/unsafe/undefined . webracket/unsafe/undefined)
      (syntax/contract . webracket/syntax/contract)))
  (check-equal? webracket/base-provider-substitution-pairs expected)
  (for ([entry (in-list expected)])
    (check-equal? (webracket/base-provider-substitute (car entry))
                  (cdr entry)))
  (for ([name (in-list '(racket/vector racket/match racket/math racket/function
                         racket/class racket/dict racket/list racket/pretty
                         racket/sequence racket/string
                         racket/private/for racket/private/kw))])
    (check-equal? (webracket/base-provider-substitute name) name)))

(test-case "webracket/full dashboard counts substituted providers as allowlisted"
  (define rows (webracket-full-dashboard-rows))
  (define (row-ref name)
    (or (assoc name rows)
        (error 'row-ref "missing full-dashboard row: ~a" name)))
  (check-equal? (list-ref (row-ref 'racket/port) 8)
                'allowlisted-via-substitution)
  (check-equal? (list-ref (row-ref 'racket/dict) 8)
                'allowlisted)
  (check-equal? (list-ref (row-ref 'racket/math) 8)
                'allowlisted)
  (check-equal? (list-ref (row-ref 'racket/path) 8)
                'allowlisted)
  (check-equal? (list-ref (row-ref 'racket/bytes) 8)
                'allowlisted))

(test-case "#lang webracket/base runs an allowlisted provider without stdlib"
  (define source-dir (make-temporary-file "webracket-base-provider-only-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-base-provider-only-dest-~a" 'directory))
  (define source-path (build-path source-dir "provider-only.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(require (only-in racket/bool xor))\n"
            "(js-log (xor #t #f))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^true$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base classifies curated installed provider demands"
  (define source-dir (make-temporary-file "webracket-base-curated-providers-src-~a" 'directory))
  (define cases
    '((vector   racket/vector      "(require (only-in racket/vector vector-member))\n(provide answer)\n(define answer vector-member)\n")
      (function racket/function    "(require (only-in racket/function identity))\n(provide answer)\n(define answer identity)\n")
      (promise  webracket/promise  "(require (only-in racket/promise force))\n(provide answer)\n(define answer force)\n")
      (stream   webracket/stream   "(require (only-in racket/stream stream-first))\n(provide answer)\n(define answer stream-first)\n")
      (set      webracket/set      "(require (only-in racket/set set-count))\n(provide answer)\n(define answer set-count)\n")))
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
                [(webracket/contract) (synthetic-provider-report name '(contract))]
                [(webracket/private/format) (synthetic-provider-report name '(format))]
                [(webracket/private/kw) (synthetic-provider-report name '(keyword-apply))]
                [(webracket/unsafe/undefined) (synthetic-provider-report name '(unsafe-undefined))]
                [else (error 'fetch-provider "unexpected fetch: ~s" name)]))))
         (when (pair? fetched)
           (check-equal? (sorted-symbols fetched)
                         (sorted-symbols
                          '(racket/vector
                            webracket/contract
                            webracket/private/format
                            racket/function
                            webracket/private/kw
                            webracket/unsafe/undefined))))
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
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base default bridge and forced bridge agree on simple local require"
  (define source-dir (make-temporary-file "webracket-base-bridge-agree-src-~a" 'directory))
  (define default-dir (make-temporary-file "webracket-base-bridge-agree-default-dest-~a" 'directory))
  (define forced-dir  (make-temporary-file "webracket-base-bridge-agree-forced-dest-~a" 'directory))
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
      (define-values (default-status default-output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--dest" (path->string default-dir)
               (path->string main-path))
         source-dir))
      (define-values (forced-status forced-output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--dest" (path->string forced-dir)
               (path->string main-path))
         source-dir))
      (check-equal? default-status 0 default-output)
      (check-equal? forced-status 0 forced-output)
      (check-regexp-match #rx"(?m:^42$)" default-output)
      (check-regexp-match #rx"(?m:^42$)" forced-output))
    (lambda ()
      (for ([dir (in-list (list source-dir default-dir forced-dir))])
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
               "--webracket-module-bridge"
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
               "--webracket-module-bridge"
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
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string main-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^42$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base module bridge preserves repeated external provider names"
  (define source-dir (make-temporary-file "webracket-base-repeated-provider-src-~a" 'directory))
  (define source-path (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(require (prefix-in ui: web-easy)\n"
            "         (prefix-in pict: (except-in web-pict text)))\n"
            "(define v (list ui:text pict:rectangle))\n"
            "(void v)\n")
           out))
        #:exists 'truncate/replace)
      (define report (compile-module-file-report source-path))
      (define import-map (webify-module-report-import-map report))
      (check-equal?
       (webify-module-import-map-import-aliases import-map)
       '((text web-easy text)
         (rectangle web-pict rectangle))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

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
               "--webracket-module-bridge"
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
               "--webracket-module-bridge"
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

(test-case "webracket/js owns the explicit JS debug binding"
  (define js-exports (module-runtime-export-symbols 'webracket/js))
  (define base-exports (module-runtime-export-symbols 'webracket/base))
  (check-not-false (memq 'js-log js-exports))
  (check-not-false (memq 'js-log base-exports)))

(test-case "js/console wraps the unsafe console layer"
  (define console-exports (module-runtime-export-symbols 'js/console))
  (define unsafe-exports (module-runtime-export-symbols 'webracket/unsafe/console))
  (check-not-false (memq 'console-log console-exports))
  (check-not-false (memq 'js-console-log unsafe-exports)))

(test-case "webracket/unsafe/console exports match ffi/console.ffi declarations"
  (define unsafe-exports (module-runtime-export-symbols 'webracket/unsafe/console))
  (define declared-exports (unsafe-console-ffi-export-symbols))
  (check-equal? (sorted-symbols unsafe-exports)
                (sorted-symbols declared-exports))
  (for ([name (in-list declared-exports)])
    (check-not-false (memq name unsafe-exports)
                     (symbol->string name))))

(test-case "unsafe FFI generator records export and arity metadata"
  (define math-ffi-path (module-provider->ffi-path 'webracket/unsafe/math))
  (check-not-false math-ffi-path)
  (define binding-datums (ffi-file->unsafe-binding-datums math-ffi-path))
  (check-not-false (member '(js-math-random () (f64)) binding-datums))
  (check-not-false (member '(js-math-atan2 (f64 f64) (f64)) binding-datums))
  (define generated
    (ffi-file->unsafe-module-source math-ffi-path
                                    'webracket/unsafe/math
                                    "../pkgs/webracket/primitives.rkt"))
  (check-true (string-contains? generated "(provide\n js-math-abs"))
  (check-true (string-contains? generated "\n js-math-sqrt\n"))
  (check-true (string-contains? generated
                                 "(define js-math-atan2 (unsafe-ffi-primitive 'js-math-atan2)")))

(test-case "migrated unsafe FFI modules match their .ffi declarations"
  (define rows
    (call-with-webracket-collection-path unsafe-ffi-module-parity-rows))
  (for ([name (in-list '(webracket/unsafe/console
                         webracket/unsafe/math
                         webracket/unsafe/performance
                         webracket/unsafe/standard
                         webracket/unsafe/window
                         webracket/unsafe/xtermjs))])
    (check-not-false (memq name (map unsafe-ffi-module-parity-row-module rows))
                     (symbol->string name)))
  (for ([row (in-list rows)])
    (check-true (unsafe-ffi-module-parity-row-ok? row)
                (format "~a missing=~s extra=~s"
                        (unsafe-ffi-module-parity-row-module row)
                        (unsafe-ffi-module-parity-row-missing row)
                        (unsafe-ffi-module-parity-row-extra row)))))

(test-case "js/array, js/math, js/performance, js/standard, and js/temp have public wrappers"
  (define array-exports (module-runtime-export-symbols 'js/array))
  (define domrect-exports (module-runtime-export-symbols 'browser/domrect))
  (define iterator-exports (module-runtime-export-symbols 'js/iterator))
  (define math-exports (module-runtime-export-symbols 'js/math))
  (define performance-exports (module-runtime-export-symbols 'js/performance))
  (define standard-exports (module-runtime-export-symbols 'js/standard))
  (define temp-exports (module-runtime-export-symbols 'js/temp))
  (for ([name (in-list '(array?
                         array-wrap
                         array-unwrap
                         array-of
                         array->vector
                         array->list
                         vector->array
                         list->array
                         array-push!
                         array-push
                         array-set-length!
                         array-to-spliced))])
    (check-not-false (memq name array-exports)
                     (symbol->string name)))
  (for ([name (in-list '(dom-rect?
                         dom-rect-wrap
                         dom-rect-unwrap
                         dom-rect-left
                         dom-rect-top
                         dom-rect-width
                         dom-rect-height))])
    (check-not-false (memq name domrect-exports)
                     (symbol->string name)))
  (for ([name (in-list '(iterator?
                         make-iterator
                         iterator-unwrap
                         iterator-from
                         iterator-next
                         iterator-map
                         iterator-filter
                         iterator->vector
                         iterator-zip-options?
                         make-iterator-zip-options))])
    (check-not-false (memq name iterator-exports)
                     (symbol->string name)))
  (check-not-false (memq 'math-sqrt math-exports))
  (check-not-false (memq 'math-random math-exports))
  (for ([name (in-list '(performance-event-counts-info?
                         performance-event-counts
                         performance-event-count-map-size
                         performance-event-count-map-entries
                         performance-event-count-map-has?
                         performance-interaction-count
                         performance-memory-info?
                         performance-memory
                         performance-memory-info-used-js-heap-size
                         performance-measure-user-agent-specific-memory
                         performance-now
                         performance-time-origin))])
    (check-not-false (memq name performance-exports)
                     (symbol->string name)))
  (check-not-false (memq 'standard-parse-int standard-exports))
  (check-not-false (memq 'standard-encode-uri-component standard-exports))
  (check-not-false (memq 'standard-object standard-exports))
  (check-not-false (memq 'temp-x temp-exports))
  (check-not-false (memq 'temp-set-x! temp-exports)))

(test-case "FFI module registry maps public and unsafe providers to bundles"
  (for ([row (in-list '((js/console console.ffi)
                        (webracket/unsafe/console console.ffi)
                        (browser/window window.ffi)
                        (webracket/unsafe/window window.ffi)
                        (browser/websocket websocket.ffi)
                        (webracket/unsafe/websocket websocket.ffi)
                        (js/array array.ffi)
                        (js/iterator array.ffi)
                        (webracket/unsafe/array array.ffi)
                        (js/math math.ffi)
                        (webracket/unsafe/math math.ffi)
                        (js/performance performance.ffi)
                        (webracket/unsafe/performance performance.ffi)
                        (js/standard standard.ffi)
                        (webracket/unsafe/standard standard.ffi)
                        (js/temp temp.ffi)
                        (jsxgraph jsxgraph.ffi)
                        (xterm xtermjs.ffi)
                        (webracket/unsafe/temp temp.ffi)))])
    (check-equal? (module-provider->ffi-filename (car row))
                  (symbol->string (cadr row))
                  (symbol->string (car row)))
    (check-not-false (module-provider->ffi-path (car row))
                     (symbol->string (car row)))))

(test-case "FFI README records the current module-call performance boundary"
  (define ffi-readme (build-path repo-root
                                 "pkgs" "webracket-lib" "compiler" "ffi" "README.md"))
  (define doc (file->string ffi-readme))
  (for ([needle (in-list '("Performance note"
                           "composability over direct-call performance"
                           "unsafe-ffi-primitive"
                           "ordinary closure/module-variable path"
                           "direct primitive call"
                           "future optimization"))])
    (check-not-false (regexp-match? (regexp (regexp-quote needle)) doc)
                     needle)))

(test-case "FFI migration matrix records migrated and browser-policy rows"
  (define migration-doc
    (build-path repo-root "pkgs" "webracket-lib" "compiler" "ffi" "MIGRATION.md"))
  (define doc (file->string migration-doc))
  (for ([needle (in-list '("FFI Migration Matrix"
                           "standard.ffi"
                           "webracket/unsafe/standard"
                           "js/standard"
                           "browser/*"
                           "Phase 1: Close Existing Migrated Gaps"
                           "Phase 4: Establish Browser Namespace"
                           "Phase 7: FFI Call Efficiency"
                           "direct-call optimization"))])
    (check-not-false (regexp-match? (regexp (regexp-quote needle)) doc)
                     needle)))

(test-case "FFI migration status report tracks migrated standard provider"
  (define rows (ffi-migration-status-rows))
  (define (row-for filename)
    (for/first ([row (in-list rows)]
                #:when (string=? (ffi-migration-status-row-ffi-filename row)
                                 filename))
      row))
  (define standard-row
    (row-for "standard.ffi"))
  (check-not-false standard-row)
  (check-equal? (ffi-migration-status-row-unsafe-module standard-row)
                'webracket/unsafe/standard)
  (check-equal? (ffi-migration-status-row-public-module standard-row)
                'js/standard)
  (check-true (ffi-migration-status-row-bundle-inference? standard-row))
  (check-true (ffi-migration-status-row-dashboard? standard-row))
  (check-equal? (ffi-migration-status-row-status standard-row)
                'migrated-covered)
  (define js-row (row-for "js.ffi"))
  (check-not-false js-row)
  (check-equal? (ffi-migration-status-row-public-module js-row) 'js/array)
  (check-equal? (ffi-migration-status-row-status js-row) 'included-by-array)
  (for ([filename (in-list '("performance.ffi" "temp.ffi"))])
    (define row (row-for filename))
    (check-not-false row filename)
    (check-true (ffi-migration-status-row-dashboard? row) filename)))

(test-case "FFI module registry ignores declarations without migrated modules"
  (for ([module-name (in-list '(js/canvas
                                js/document
                                js/dom
                                js/domrect
                                js/element
                                js/event
                                js/jsxgraph
                                js/window
                                js/xtermjs))])
    (check-false (module-provider->ffi-filename module-name)
                 (symbol->string module-name))
    (check-false (webify-provider-trial-default-bridge-module-allowed? module-name)
                 (symbol->string module-name))))

(test-case "package info declares the public collection"
  (define info-path (build-path repo-root "pkgs" "webracket" "info.rkt"))
  (define source (file->string info-path))
  (check-true (string-contains? source "(define collection \"webracket\")")))

(test-case "#lang webracket/base can require the explicit JS FFI provider"
  (define source-dir (make-temporary-file "webracket-js-provider-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-js-provider-dest-~a" 'directory))
  (define source-path (build-path source-dir "use-js.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(require webracket/js)\n(js-log \"ffi-module\")\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^ffi-module$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base infers ffi/math from required js/math"
  (define source-dir (make-temporary-file "webracket-js-math-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-js-math-dest-~a" 'directory))
  (define source-path (build-path source-dir "use-math.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(require js/math)\n(js-log (math-sqrt 9.0))\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(^|[\r\n])3([\r\n]|$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base infers ffi/console from required js/console"
  (define source-dir (make-temporary-file "webracket-js-console-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-js-console-dest-~a" 'directory))
  (define source-path (build-path source-dir "use-console.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display "#lang webracket/base\n(require js/console)\n(console-log \"console-module\")\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"console-module" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "#lang webracket/base can opt into webracket/unsafe/console"
  (define source-dir (make-temporary-file "webracket-unsafe-console-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-unsafe-console-dest-~a" 'directory))
  (define source-path (build-path source-dir "use-unsafe-console.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file source-path
        (lambda (out)
          (display
           (string-append
            "#lang webracket/base\n"
            "(require webracket/unsafe/console)\n"
            "(js-console-log (vector \"raw-console-module\"))\n")
           out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r" "--no-stdlib" "--no-io-format-provider"
               "--webracket-module-bridge"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"raw-console-module" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "legacy include-lib console remains usable during module migration"
  (define source-dir
    (build-path repo-root
                "tmp"
                (format "webracket-legacy-console-src-~a"
                        (current-inexact-milliseconds))))
  (define dest-dir
    (build-path repo-root
                "tmp"
                (format "webracket-legacy-console-dest-~a"
                        (current-inexact-milliseconds))))
  (define source-path (build-path source-dir "legacy-console.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (make-directory* source-dir)
      (make-directory* dest-dir)
      (call-with-output-file source-path
        (lambda (out)
          (display "(include-lib console)\n(console-log \"legacy-console\")\n" out))
        #:exists 'truncate/replace)
      (define-values (status output)
        (run-webracket/base
         (list "-r"
               "--dest" (path->string dest-dir)
               (path->string source-path))
         source-dir))
      (check-equal? status 0 output)
      (check-regexp-match #rx"legacy-console" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

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
                                     racket/bool racket/sequence webracket/promise
                                     webracket/set racket/stream racket/match
                                     racket/format webracket/file webracket/hash
                                     racket/class webracket/js webracket/pretty
                                     webracket/sequence))])
    (check-not-false (memq name webracket-full-addon-libraries)
                     (symbol->string name)))
  (check-not-false (assoc 'racket/format webracket-full-surface-statuses))
  (check-not-false (assoc 'racket/list webracket-full-surface-statuses))
  (check-false (memq 'racket/promise webracket-full-addon-libraries))
  (check-false (memq 'racket/set webracket-full-addon-libraries)))

(test-case "webracket/full surface statuses cover every curated add-on"
  (define status-names (map car webracket-full-surface-statuses))
  (define audit-names (map car webracket-full-surface-audit))
  (for ([name (in-list webracket-full-addon-libraries)])
    (check-not-false (memq name status-names)
                     (symbol->string name))
    (check-not-false (memq name audit-names)
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
