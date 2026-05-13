#lang racket/base

(require racket/file
         racket/path
         rackunit
         "test-module-support.rkt")

;; extracted-module-inputs : (listof webify-module-linklet-input?)
;;   A tiny module graph in the shape a future linklet extractor should produce.
(define extracted-module-inputs
  (list
   (webify-module-linklet-input
    'a
    '(linklet () (x)
       (define-values (x) 10))
    '())
   (webify-module-linklet-input
    'b
    '(linklet (([ext-x x])) (y)
       (define-values (y) (+ x 1)))
    '((ext-x a x)))))

(test-case "module linklet inputs build a registry"
  (define registry
    (webify-module-linklet-inputs->registry extracted-module-inputs))
  (check-equal? (webify-module-registry-names registry) '(a b))
  (check-equal? (webify-module-registry-plan registry '(b)) '(a b))
  (define b-entry (webify-module-registry-ref registry 'b))
  (check-equal? (webify-module-registry-entry-imports b-entry)
                '((ext-x a x)))
  (check-equal? (webify-module-registry-entry-exports b-entry) '(y)))

(test-case "module linklet manifest parses inputs and roots"
  (define manifest
    (datum->webify-module-linklet-manifest
     '(webify-module-linklet-manifest
       (roots (b))
       (input a
              (linklet () (x)
                (define-values (x) 10))
              (imports ()))
       (input b
              (linklet (([ext-x x])) (y)
                (define-values (y) (+ x 1)))
              (imports ((ext-x a x)))))))
  (check-equal? (webify-module-linklet-manifest-roots manifest) '(b))
  (check-equal? (map webify-module-linklet-input-name
                     (webify-module-linklet-manifest-inputs manifest))
                '(a b))
  (define registry (webify-module-linklet-manifest->registry manifest))
  (check-equal? (webify-module-registry-plan
                 registry
                 (webify-module-linklet-manifest-roots manifest))
                '(a b)))

(test-case "module linklet manifest reads from a file"
  (define source-dir (make-temporary-file "webracket-input-manifest-src-~a" 'directory))
  (define manifest-path (build-path source-dir "inputs.rktd"))
  (dynamic-wind
    void
    (lambda ()
      (call-with-output-file manifest-path
        (lambda (out)
          (write
           '(webify-module-linklet-manifest
             (roots (b))
             (input a
                    (linklet () (x)
                      (define-values (x) 10))
                    (imports ()))
             (input b
                    (linklet (([ext-x x])) (y)
                      (define-values (y) (+ x 1)))
                    (imports ((ext-x a x)))))
           out)
          (newline out))
        #:exists 'truncate/replace)
      (define manifest (read-webify-module-linklet-manifest manifest-path))
      (check-equal? (webify-module-linklet-manifest-roots manifest) '(b))
      (check-equal? (webify-module-registry-names
                     (webify-module-linklet-manifest->registry manifest))
                    '(a b)))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))

(test-case "module linklet import resolver derives flat triples"
  (define b-linklet
    '(linklet (([ext-x x])) (y)
       (define-values (y) (+ x 1))))
  (check-equal?
   (webify-resolve-module-linklet-imports b-linklet '((a (x))))
   '((ext-x a x)))
  (check-equal?
   (webify-resolve-module-linklet-imports b-linklet
                                          '((a (x)) (other (x)))
                                          #:dependencies '((ext-x a)))
   '((ext-x a x)))
  (define input
    (webify-module-linklet-input/resolve-imports 'b
                                                 b-linklet
                                                 '((a (x)))))
  (check-equal? (webify-module-linklet-input-imports input)
                '((ext-x a x))))

(test-case "module linklet import resolver honors reflection hints"
  (define linklet
    '(linklet (([ext-x x])) (y)
       (define-values (y) ext-x)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    linklet
    '((a (x)) (other (x)))
    #:module-name 'b
    #:reflection-hints '((b ext-x a x)))
   '((ext-x a x)))
  (define-values (imports outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     linklet
     '((a (x)) (other (x)))
     #:module-name 'b
     #:reflection-hints '((b ext-x a x))))
  (check-equal? imports '((ext-x a x)))
  (check-equal? (map webify-module-resolution-outcome-status outcomes)
                '(resolved-by-reflection-hint))
  (check-exn
   #rx"dependency does not export hinted name"
   (lambda ()
     (webify-resolve-module-linklet-imports
      linklet
      '((a (not-x)) (other (x)))
      #:module-name 'b
      #:reflection-hints '((b ext-x a x))))))

(test-case "dependency exports derive from provider compiled exports"
  (define string-provider
    (webify-module-linklet-input
     'racket/string
     '(linklet () (string-join.1 string-join9.1)
        (define-values (string-join.1) 'join)
        (define-values (string-join9.1) 'join9))
     '()))
  (define importer-linklet
    '(linklet (((string-join.1 string-join.1)
                (string-join9.1 string-join9.1)))
       (y)
       (define-values (y) string-join.1)))
  (check-equal?
   (webify-module-linklet-input-dependency-exports string-provider)
   '(racket/string (string-join.1 string-join9.1)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    importer-linklet
    (list (webify-module-linklet-input-dependency-exports string-provider)))
   '((string-join.1 racket/string string-join.1)
     (string-join9.1 racket/string string-join9.1))))

(test-case "dependency exports normalize paired provider exports"
  (define provider
    (webify-module-linklet-input
     'racket/private/pico
     '(linklet () ((1/reverse reverse))
        (define-values (1/reverse) 'reverse-proc))
     '()))
  (check-equal?
   (webify-module-linklet-input-dependency-exports provider)
   '(racket/private/pico (reverse))))

(test-case "dependency resolver carries provider export symbols by printed name"
  (define provider-export (string->uninterned-symbol "string-join.1"))
  (define importer-export (string->uninterned-symbol "string-join.1"))
  (check-false (eq? provider-export importer-export))
  (define importer-linklet
    `(linklet (((,importer-export ,importer-export))) (y)
       (define-values (y) ,importer-export)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    importer-linklet
    `((racket/string (,provider-export))))
   `((,importer-export racket/string ,provider-export)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    importer-linklet
    `((racket/string (,provider-export)))
    #:dependencies `((,importer-export racket/string)))
   `((,importer-export racket/string ,provider-export))))

(test-case "dependency resolver honors explicit internal export aliases"
  (define importer-local 'string-join.1)
  (define importer-external 'string-join)
  (define provider-export 'string-join.9)
  (define importer-linklet
    `(linklet (((,importer-local ,importer-external))) (y)
       (define-values (y) ,importer-local)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    importer-linklet
    `((racket/string (,provider-export)))
    #:import-aliases `((,importer-local racket/string ,provider-export)))
   `((,importer-local racket/string ,provider-export)))
  (check-exn
   #rx"dependency does not export aliased name"
   (lambda ()
     (webify-resolve-module-linklet-imports
      importer-linklet
      '((racket/string (string-join.8)))
      #:import-aliases `((,importer-local racket/string ,provider-export))))))

(test-case "dependency export tables derive from provider inputs"
  (define providers
    (list
     (webify-module-linklet-input
      'a
      '(linklet () (x)
         (define-values (x) 10))
      '())
     (webify-module-linklet-input
      'racket/string
      '(linklet () (string-join.1 string-join9.1)
         (define-values (string-join.1) 'join)
         (define-values (string-join9.1) 'join9))
      '())))
  (define dependency-exports
    (webify-module-linklet-inputs-dependency-exports providers))
  (check-equal? dependency-exports
                '((a (x))
                  (racket/string (string-join.1 string-join9.1))))
  (check-equal?
   (webify-resolve-module-linklet-imports
    '(linklet (((string-join.1 string-join.1))) (y)
       (define-values (y) string-join.1))
    dependency-exports)
   '((string-join.1 racket/string string-join.1)))
  (check-exn
   #rx"duplicate dependency export entries"
   (lambda ()
     (webify-module-linklet-inputs-dependency-exports
      (list (webify-module-linklet-input 'a '(linklet () (x) (void)) '())
            (webify-module-linklet-input 'a '(linklet () (y) (void)) '()))))))

(test-case "module linklet manifest derives imports"
  (define manifest
    (datum->webify-module-linklet-manifest
     '(webify-module-linklet-manifest
       (roots (b))
       (input a
              (linklet () (x)
                (define-values (x) 10))
              (imports ()))
       (input b
              (linklet (([ext-x x])) (y)
                (define-values (y) (+ x 1)))
              (resolve-imports
               (dependency-exports ((a (x)))))))))
  (define inputs (webify-module-linklet-manifest-inputs manifest))
  (check-equal? (map webify-module-linklet-input-imports inputs)
                '(() ((ext-x a x)))))

(test-case "module linklet manifest resolves ambiguous imports with dependencies"
  (define manifest
    (datum->webify-module-linklet-manifest
     '(webify-module-linklet-manifest
       (roots (b))
       (input a
              (linklet () (x)
                (define-values (x) 10))
              (imports ()))
       (input other
              (linklet () (x)
                (define-values (x) 99))
              (imports ()))
       (input b
              (linklet (([ext-x x])) (y)
                (define-values (y) (+ x 1)))
              (resolve-imports
               (dependency-exports ((a (x)) (other (x))))
               (dependencies ((ext-x a))))))))
  (define b-input
    (for/first ([input (in-list (webify-module-linklet-manifest-inputs manifest))]
                #:when (eq? (webify-module-linklet-input-name input) 'b))
      input))
  (check-equal? (webify-module-linklet-input-imports b-input)
                '((ext-x a x))))

(test-case "module linklet inputs validate through registry registration"
  (check-exn
   #rx"webify-module-linklet-input\\?"
   (lambda ()
     (webify-register-module-linklet-input!
      (make-webify-module-registry)
      'not-an-input)))
  (check-exn
   #rx"expected a linklet datum"
   (lambda ()
     (webify-module-linklet-inputs->registry
      (list (webify-module-linklet-input 'bad '(not-a-linklet) '())))))
  (check-exn
   #rx"registry imports are missing linklet imports"
   (lambda ()
     (webify-module-linklet-inputs->registry
      (list (webify-module-linklet-input
             'bad
             '(linklet (([ext-x x])) (y)
                (define-values (y) x))
             '()))))))
  (check-exn
   #rx"expected webify module-linklet manifest datum"
   (lambda ()
     (datum->webify-module-linklet-manifest '(not-a-manifest))))
  (check-exn
   #rx"expected module-linklet input clause"
   (lambda ()
     (datum->webify-module-linklet-manifest
      '(webify-module-linklet-manifest
        (roots (bad))
        (bad-input)))))
  (check-exn
   #rx"missing-after-reflection"
   (lambda ()
     (webify-resolve-module-linklet-imports
      '(linklet (([ext-x x])) (y)
         (define-values (y) x))
      '((a (not-x))))))
  (check-exn
   #rx"ambiguous-after-reflection"
   (lambda ()
     (webify-resolve-module-linklet-imports
      '(linklet (([ext-x x])) (y)
         (define-values (y) x))
      '((a (x)) (b (x))))))
  (check-exn
   #rx"candidate reasons"
   (lambda ()
     (webify-resolve-module-linklet-imports
      '(linklet (([ext-x x])) (y)
         (define-values (y) x))
      '((a (x)) (b (x))))))
  (define-values (preferred-imports preferred-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([1/syntax? syntax?])) (y)
        (define-values (y) 1/syntax?))
     '((racket/private/pre-base (syntax?))
       (racket/private/base (syntax?))
       (racket/base (syntax?)))))
  (check-equal? preferred-imports
                '((1/syntax? racket/private/pre-base syntax?)))
  (check-equal? (map webify-module-resolution-outcome-status preferred-outcomes)
                '(resolved-by-export-scan/provider-precedence))
  (check-exn
   #rx"dependency does not export required name"
   (lambda ()
     (webify-resolve-module-linklet-imports
      '(linklet (([ext-x x])) (y)
         (define-values (y) x))
      '((a (not-x)))
      #:dependencies '((ext-x a)))))
  (check-exn
   #rx"references a name not imported by the linklet"
   (lambda ()
     (webify-resolve-module-linklet-imports
      '(linklet (([ext-x x])) (y)
         (define-values (y) x))
      '((a (x)))
      #:dependencies '((missing a)))))

(test-case "module linklet inputs feed the loader bridge"
  (define registry
    (webify-module-linklet-inputs->registry extracted-module-inputs))
  (define loader (make-webify-module-loader registry))
  (define composition
    (webify-module-loader-instantiate-roots!
     loader
     '(b)
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
  (check-true (webify-module-composition? composition))
  (check-equal? (webify-module-loader-export-cell-id loader 'a 'x)
                'webify-export-cell0$0)
  (check-equal? (webify-module-loader-export-cell-id loader 'b 'y)
                'webify-export-cell0$1)
  (define combined
    (webify-module-loader-with-tail
     loader
     `((js-log (module-variable-ref
                ,(webify-module-loader-export-cell-id loader 'a 'x)))
       (js-log (module-variable-ref
                ,(webify-module-loader-export-cell-id loader 'b 'y))))))
  (check-not-false
   (member '("js-log" ("module-variable-ref" "webify-export-cell0$0"))
           (normalize-symbols combined)))
  (check-not-false
   (member '("js-log" ("module-variable-ref" "webify-export-cell0$1"))
           (normalize-symbols combined))))

(unless (or (getenv "WEBIFY_SKIP_CLI_SMOKE")
            (getenv "WEBIFY_SKIP_RUNTIME_SMOKE"))
  (test-case "module linklet manifest file drives WebRacket output"
    (define source-dir (make-temporary-file "webracket-manifest-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-manifest-run-dest-~a" 'directory))
    (define manifest-path (build-path source-dir "inputs.rktd"))
    (define source-path (build-path source-dir "manifest-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (call-with-output-file manifest-path
          (lambda (out)
            (write
             '(webify-module-linklet-manifest
               (roots (b))
               (input a
                      (linklet () (x)
                        (define-values (x) 10))
                      (imports ()))
               (input b
                      (linklet (([ext-x x])) (y)
                        (define-values (y) (+ x 1)))
                      (resolve-imports
                       (dependency-exports ((a (x)))))))
             out)
            (newline out))
          #:exists 'truncate/replace)
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
        (define combined
          (webify-module-loader-observe loader '((a x) (b y))))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^10$)" output)
        (check-regexp-match #rx"(?m:^11$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir))))))

  (test-case "module linklet input output runs through WebRacket"
    (define source-dir (make-temporary-file "webracket-input-run-src-~a" 'directory))
    (define dest-dir   (make-temporary-file "webracket-input-run-dest-~a" 'directory))
    (define source-path (build-path source-dir "input-run.rkt"))
    (dynamic-wind
      void
      (lambda ()
        (define registry
          (webify-module-linklet-inputs->registry extracted-module-inputs))
        (define loader (make-webify-module-loader registry))
        (webify-module-loader-instantiate-roots!
         loader
         '(b)
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
        (define combined
          (webify-module-loader-with-tail
           loader
           `((js-log (module-variable-ref
                      ,(webify-module-loader-export-cell-id loader 'a 'x)))
             (js-log (module-variable-ref
                      ,(webify-module-loader-export-cell-id loader 'b 'y))))))
        (write-datum-program! source-path combined)
        (define-values (status output)
          (run-webracket (list "--no-stdlib"
                               "-r"
                               "--dest" (path->string dest-dir)
                               (path->string source-path))
                         source-dir))
        (check-equal? status 0 output)
        (check-regexp-match #rx"(?m:^10$)" output)
        (check-regexp-match #rx"(?m:^11$)" output))
      (lambda ()
        (for ([dir (in-list (list source-dir dest-dir))])
          (with-handlers ([exn:fail:filesystem? void])
            (delete-directory/files dir)))))))

(module+ main
  (void))
