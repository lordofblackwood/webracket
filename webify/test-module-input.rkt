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
