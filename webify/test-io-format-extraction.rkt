#lang racket/base

(require racket/file
         racket/list
         racket/string
         rackunit
         "io-format-provider.rkt"
         "test-module-support.rkt")

(define io-format-main-name
  'racket-src/io/format/main-web.rkt)

(define io-format-printf-name
  'racket-src/io/format/printf-web.rkt)

(define io-format-adapter-name
  'racket-src/io/format/printf-adapter.rkt)

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

(define map-shim-module
  '(module map-shim racket/base
     (provide map2)
     (define (map2 f xs)
       (if (null? xs)
           null
           (cons (f (car xs)) (map2 f (cdr xs)))))))

;; module-protocol-input : -> webify-module-linklet-input?
;;   Minimal module protocol provider for compiled source-module linklets.
(define (module-protocol-input)
  (webify-module-linklet-input
   'module-protocol
   '(linklet () (.get-syntax-literal! .set-transformer!)
      (define-values (.get-syntax-literal!) (lambda xs #f))
      (define-values (.set-transformer!) (lambda xs (void))))
   '()))

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

;; staged-io-format-reports : -> values
;;   Extract reports for the adapted original-Racket io/format graph.
(define (staged-io-format-reports)
  (values
   (webify-module-path->report (string->path "racket-src/io/format/printf-adapter.rkt"))
   (webify-module-path->report (string->path "racket-src/io/format/printf-web.rkt"))
   (webify-module-path->report (string->path "racket-src/io/format/main-web.rkt"))
   (webify-compile-module-report map-shim-module)))

;; staged-io-format-inputs : -> (listof input?)
;;   Resolve staged io/format reports into registry-ready inputs.
(define (staged-io-format-inputs)
  (define-values (adapter-report printf-report main-report map-report)
    (staged-io-format-reports))
  (list
   (module-protocol-input)
   (webify-module-report->resolved-linklet-input/providers
    map-report
    '()
    #:module-protocol-dependency 'module-protocol)
   (webify-module-report->resolved-linklet-input/providers
    adapter-report
    '()
    #:module-protocol-dependency 'module-protocol)
   (webify-module-report->resolved-linklet-input/providers
    printf-report
    (list adapter-report map-report)
    #:dependencies '((map2 map-shim))
    #:module-protocol-dependency 'module-protocol)
   (webify-module-report->resolved-linklet-input/providers
    main-report
    (list adapter-report printf-report)
    #:module-protocol-dependency 'module-protocol)))

(test-case "synthetic provider source extracts to registry-ready linklet input"
  (define report (webify-compile-module-report synthetic-provider-module))
  (check-true (webify-module-report-manifest-ready? report))
  (check-equal? (webify-module-report-phase0-exports report)
                '(eprintf printf fprintf format))
  (define input
    (webify-module-report->resolved-linklet-input/providers
     report
     '()
     #:module-protocol-dependency 'module-protocol))
  (check-equal? (webify-module-linklet-input-name input)
                'synthetic-format-provider)
  (check-equal?
   (webify-module-linklet-input-imports input)
   '((.get-syntax-literal! module-protocol .get-syntax-literal!)
     (.set-transformer! module-protocol .set-transformer!))))

(test-case "synthetic extracted provider runs through module-variable cells"
  (define provider-input
    (webify-module-report->resolved-linklet-input/providers
     (webify-compile-module-report synthetic-provider-module)
     '()
     #:module-protocol-dependency 'module-protocol))
  (define composition
    (compose-inputs/no-aliases
     (list (module-protocol-input) provider-input)
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
   (member 'racket-src/io/format/printf-web
           (webify-module-report-required-provider-names report)))
  (check-not-false
   (member 'racket-src/io/format/printf-adapter
           (webify-module-report-required-provider-names report)))
  (check-not-false
   (member "compiled module import metadata still includes module protocol plumbing"
           (webify-module-report-notes report))))

(test-case "staged io/format provider graph resolves into registry-ready inputs"
  (define inputs (staged-io-format-inputs))
  (define registry (webify-module-linklet-inputs->registry inputs))
  (check-equal? (webify-module-registry-plan registry (list io-format-main-name))
                (list 'module-protocol
                      io-format-adapter-name
                      'map-shim
                      io-format-printf-name
                      io-format-main-name))
  (define printf-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input)
                            io-format-printf-name))
      input))
  (check-not-false
   (member '(map2 map-shim map2)
           (webify-module-linklet-input-imports printf-input)))
  (define main-input
    (for/first ([input (in-list inputs)]
                #:when (eq? (webify-module-linklet-input-name input)
                            io-format-main-name))
      input))
  (check-not-false
   (member `(do-printf ,io-format-printf-name do-printf)
           (webify-module-linklet-input-imports main-input))))

(test-case "staged io/format extracted graph composes cell-only but is not retirement-ready"
  (define composition (compose-inputs/no-aliases (staged-io-format-inputs) io-format-main-name))
  (define format-cell
    (webify-module-composition-export-cell-id composition io-format-main-name 'format))
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
  (check-false (io-format-bootstrap-retirement-ready?))
  (check-exn #rx"bootstrap format primitives are not ready to retire"
             check-io-format-bootstrap-retirement-ready!))

(module+ main
  (void))
