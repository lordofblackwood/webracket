#lang racket/base

(require racket/file
         racket/list
         racket/string
         rackunit
         "../pkgs/webracket-lib/compiler/webify/io-format-bridge.rkt"
         "../pkgs/webracket-lib/compiler/webify/io-format-provider.rkt"
         "test-module-support.rkt")

(define synthetic-provider-module
  '(module synthetic-format-provider racket/base
     (provide format fprintf printf eprintf)
     (define (format fmt v)
       (string-append "fmt:" fmt ":" v))
     (define (fprintf out fmt v)
       (void))
     (define (printf fmt v)
       (format fmt v))
     (define (eprintf fmt v)
       (format fmt v))))

;; compose-inputs/no-aliases : (listof input?) symbol? -> composition?
;;   Compose extracted inputs without public aliases, avoiding `format` collision.
(define (compose-inputs/no-aliases inputs root)
  (define registry (webify-module-linklet-inputs->registry inputs))
  (webify-compose-module-registry/roots/composition
   registry
   (list root)
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
   #:import-keys           #f))

(test-case "synthetic provider source extracts to registry-ready linklet input"
  (define report (webify-compile-module-report synthetic-provider-module))
  (check-true (webify-module-report-manifest-ready? report))
  (check-equal? (webify-module-report-phase0-exports report)
                '(eprintf printf fprintf format))
  (define input
    (webify-module-report->resolved-linklet-input/providers
     report
     '()
     #:module-protocol-dependency webify-io-format-module-protocol-name))
  (check-equal? (webify-module-linklet-input-name input)
                'synthetic-format-provider)
  (check-equal?
   (webify-module-linklet-input-imports input)
   `((.get-syntax-literal! ,webify-io-format-module-protocol-name .get-syntax-literal!)
     (.set-transformer! ,webify-io-format-module-protocol-name .set-transformer!))))

(test-case "synthetic extracted provider runs through module-variable cells"
  (define provider-input
    (webify-module-report->resolved-linklet-input/providers
     (webify-compile-module-report synthetic-provider-module)
     '()
     #:module-protocol-dependency webify-io-format-module-protocol-name))
  (define composition
    (compose-inputs/no-aliases
     (list (webify-io-format-module-protocol-input) provider-input)
     'synthetic-format-provider))
  (define format-cell
    (webify-module-composition-export-cell-id
     composition
     'synthetic-format-provider
     'format))
  (define source-dir (make-temporary-file "webracket-extracted-format-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-extracted-format-dest-~a" 'directory))
  (define source-path (build-path source-dir "extracted-format.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-datum-program!
       source-path
       (webify-module-composition-with-tail
        composition
        `((define provided-format (module-variable-ref ,format-cell))
          (js-log (provided-format "hello" "world")))))
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "--no-io-format-provider"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir
                       #:timeout-seconds 120
                       #:memory-mb 1024))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^fmt:hello:world$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(test-case "staged io/format main-web extraction classifies current blockers"
  (define report
    (webify-module-path->report (string->path "racket-src/io/format/main-web.rkt")))
  (check-true (webify-module-report-manifest-ready? report))
  (check-equal? (webify-module-report-phase0-exports report)
                '(format simple-format general-format eprintf printf fprintf check))
  (check-not-false
   (ormap (lambda (name)
            (member name (webify-module-report-required-provider-names report)))
          (list webify-io-format-printf-name
                'racket-src/io/format/printf-web)))
  (check-not-false
   (ormap (lambda (name)
            (member name (webify-module-report-required-provider-names report)))
          (list webify-io-format-adapter-name
                'racket-src/io/format/printf-adapter)))
  (check-not-false
   (member "compiled module import metadata still includes module protocol plumbing"
           (webify-module-report-notes report))))

(test-case "staged io/format provider graph resolves into registry-ready inputs"
  (define inputs (webify-io-format-inputs))
  (define registry (webify-module-linklet-inputs->registry inputs))
  (check-equal? (webify-module-registry-plan registry (list webify-io-format-root-name))
                (list webify-io-format-module-protocol-name
                      webify-io-format-adapter-name
                      webify-io-format-map-shim-name
                      webify-io-format-printf-name
                      webify-io-format-root-name))
  (define printf-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input)
                            webify-io-format-printf-name))
      input))
  (check-not-false
   (member `(map2 ,webify-io-format-map-shim-name map2)
           (webify-module-linklet-input-imports printf-input)))
  (define main-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input)
                            webify-io-format-root-name))
      input))
  (check-not-false
   (member `(do-printf ,webify-io-format-printf-name do-printf)
           (webify-module-linklet-input-imports main-input))))

(test-case "staged io/format extracted graph composes cell-only and is retirement-ready"
  (define composition
    (compose-inputs/no-aliases (webify-io-format-inputs) webify-io-format-root-name))
  (define format-cell
    (webify-module-composition-export-cell-id composition webify-io-format-root-name 'format))
  (check-true (symbol? format-cell))
  (check-true (string-contains?
               (wat-string
                (comp
                 (datum->syntax
                  #f
                  (webify-module-composition-with-tail
                   composition
                   `((define provided-format (module-variable-ref ,format-cell))
                     (void provided-format))))))
               "$module-variable-ref"))
  (check-true (io-format-bootstrap-retirement-ready?))
  (check-not-exn check-io-format-bootstrap-retirement-ready!))

(test-case "staged io/format bridge provides private stdlib cells"
  (define composition
    (compose-inputs/no-aliases (webify-io-format-inputs) webify-io-format-root-name))
  (define alias-forms (webify-io-format-private-alias-forms composition))
  (check-equal? (map cadr alias-forms)
                (map webify-io-format-private-cell-symbol
                     webify-io-format-export-symbols))
  (for ([form (in-list alias-forms)])
    (check-match form `(define ,(? symbol?) ,(? symbol?)))))

(test-case "staged io/format extracted graph runs through module-variable cells"
  (define composition
    (compose-inputs/no-aliases (webify-io-format-inputs) webify-io-format-root-name))
  (define format-cell
    (webify-module-composition-export-cell-id composition webify-io-format-root-name 'format))
  (define source-dir (make-temporary-file "webracket-io-format-staged-src-~a" 'directory))
  (define dest-dir   (make-temporary-file "webracket-io-format-staged-dest-~a" 'directory))
  (define source-path (build-path source-dir "io-format-staged.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-datum-program!
       source-path
       (webify-module-composition-with-tail
        composition
        `(,@(webify-io-format-private-alias-forms composition)
          (define provided-format
            (module-variable-ref ,(webify-io-format-private-cell-symbol 'format)))
          (js-log (provided-format "A=~a S=~s T=~~ X=~x O=~o B=~b C=~c"
                                   "hello"
                                   "hi"
                                   255
                                   8
                                   5
                                   #\Z))
          (js-log (provided-format "V=~v E=~e N=~nP=~%Q" "vv" '(err)))
          (js-log (provided-format "left~\n    right")))))
      (define-values (status output)
        (run-webracket (list "--no-stdlib"
                             "--no-io-format-provider"
                             "-r"
                             "--dest" (path->string dest-dir)
                             (path->string source-path))
                       source-dir
                       #:timeout-seconds 120
                       #:memory-mb 1024))
      (check-equal? status 0 output)
      (check-regexp-match #rx"(?m:^A=hello S=hi T=~ X=ff O=10 B=101 C=Z$)" output)
      (check-true (string-contains? output "V=vv E=(err) N=\nP=\nQ")
                  output)
      (check-regexp-match #rx"(?m:^leftright$)" output))
    (lambda ()
      (for ([dir (in-list (list source-dir dest-dir))])
        (with-handlers ([exn:fail:filesystem? void])
          (delete-directory/files dir))))))

(module+ main
  (void))
