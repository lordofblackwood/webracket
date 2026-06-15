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

(test-case "module linklet import resolver handles kernel-origin primitive hints"
  (define reverse-linklet
    '(linklet (([reverse reverse])) (y)
       (define-values (y) reverse)))
  (define-values (kernel-imports kernel-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     reverse-linklet
     '()
     #:module-name 'use-reverse
     #:reflection-hints '((use-reverse reverse #%kernel reverse))))
  (check-equal? kernel-imports '((reverse #%kernel reverse)))
  (check-equal? (map webify-module-resolution-outcome-status kernel-outcomes)
                '(resolved-by-reflection-hint))
  (check-exn
   #rx"unsupported kernel-origin binding"
   (lambda ()
     (webify-resolve-module-linklet-imports
      '(linklet (([unsupported-kernel unsupported-kernel])) (y)
         (define-values (y) unsupported-kernel))
      '()
      #:module-name 'use-unsupported-kernel
      #:reflection-hints
      '((use-unsupported-kernel unsupported-kernel #%kernel unsupported-kernel))))))

(test-case "module linklet import resolver uses supported kernel fallback"
  (define syntax-error-linklet
    '(linklet (([raise-syntax-error raise-syntax-error])) (y)
       (define-values (y) raise-syntax-error)))
  (define-values (kernel-imports kernel-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     syntax-error-linklet
     '()))
  (check-equal? kernel-imports
                '((raise-syntax-error #%kernel raise-syntax-error)))
  (check-equal? (map webify-module-resolution-outcome-status kernel-outcomes)
                '(resolved-by-export-scan)))

(test-case "module linklet import resolver ranks concrete providers above kernel fallback"
  (define syntax-linklet
    '(linklet (([syntax? syntax?])) (y)
       (define-values (y) syntax?)))
  (define-values (imports outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     syntax-linklet
     '((racket/private/pre-base (syntax?))
       (racket/private/base (syntax?)))))
  (check-equal? imports
                '((syntax? racket/private/pre-base syntax?)))
  (check-equal? (map webify-module-resolution-outcome-status outcomes)
                '(resolved-by-export-scan/provider-precedence)))

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

(test-case "dependency resolver prefers generated primary export for public imports"
  (check-equal?
   (webify-resolve-module-linklet-imports
    '(linklet (((string-join string-join))) (y)
       (define-values (y) string-join))
    '((racket/string (string-join9.1 string-join.2 string-join.1))))
   '((string-join racket/string string-join.1))))

(test-case "dependency resolver uses compiled alias export for explicit generated dependencies"
  (check-equal?
   (webify-resolve-module-linklet-imports
    '(linklet (((remove-duplicates28.1 remove-duplicates28.1))) (y)
       (define-values (y) remove-duplicates28.1))
    '((webracket/list (remove-duplicates46.1
                       remove-duplicates.2
                       remove-duplicates.1
                       remove-duplicates)))
    #:module-name 'racket/private/class-internal
    #:dependencies '((remove-duplicates28.1 webracket/list)))
   '((remove-duplicates28.1 webracket/list remove-duplicates))))

(test-case "dependency resolver lets compiled alias override private generated dependency"
  (check-equal?
   (webify-resolve-module-linklet-imports
    '(linklet (((remove-duplicates28.1 remove-duplicates28.1))) (y)
       (define-values (y) remove-duplicates28.1))
    '((racket/private/list (remove-duplicates46.1
                            remove-duplicates.2
                            remove-duplicates.1))
      (webracket/list (remove-duplicates)))
    #:module-name 'racket/private/class-internal
    #:dependencies '((remove-duplicates28.1 racket/private/list)))
   '((remove-duplicates28.1 webracket/list remove-duplicates))))

(test-case "dependency resolver prefers public base export for explicit generated dependencies"
  (check-equal?
   (webify-resolve-module-linklet-imports
    '(linklet (((remove-duplicates28.1 remove-duplicates28.1))) (y)
       (define-values (y) remove-duplicates28.1))
    '((racket/private/list (remove-duplicates46.1
                            remove-duplicates.2
                            remove-duplicates.1
                            remove-duplicates)))
    #:module-name 'racket/private/class-internal
    #:dependencies '((remove-duplicates28.1 racket/private/list)))
   '((remove-duplicates28.1 racket/private/list remove-duplicates))))

(test-case "dependency resolver prefers generated primary export for generated dependencies"
  (check-equal?
   (webify-resolve-module-linklet-imports
    '(linklet (((remove-duplicates28.1 remove-duplicates28.1))) (y)
       (define-values (y) remove-duplicates28.1))
    '((racket/private/list (remove-duplicates46.1
                            remove-duplicates.2
                            remove-duplicates.1)))
    #:module-name 'racket/private/class-internal
    #:dependencies '((remove-duplicates28.1 racket/private/list)))
   '((remove-duplicates28.1 racket/private/list remove-duplicates.1))))

(test-case "dependency resolver normalizes generated new: aliases"
  (define importer-linklet
    '(linklet (((new:procedure-reduce-arity-mask new:procedure-reduce-arity-mask))) (y)
       (define-values (y) new:procedure-reduce-arity-mask)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    importer-linklet
    '((racket/private/list (procedure-reduce-arity-mask))))
   '((new:procedure-reduce-arity-mask
      racket/private/list
      procedure-reduce-arity-mask))))

(test-case "dependency resolver normalizes generated new- aliases"
  (define importer-linklet
    '(linklet (((new-keyword-apply new-keyword-apply))) (y)
       (define-values (y) new-keyword-apply)))
  (check-equal?
   (webify-resolve-module-linklet-imports
    importer-linklet
    '((racket/private/list (keyword-apply))))
   '((new-keyword-apply
      racket/private/list
      keyword-apply))))

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
      '((racket/string (string-append.8)))
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
  (define-values (syntax-source-imports syntax-source-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([1/syntax-source syntax-source])) (y)
        (define-values (y) 1/syntax-source))
     '((webracket/primitives (syntax-source))
       (racket/linklet (syntax-source)))))
  (check-equal? syntax-source-imports
                '((1/syntax-source webracket/primitives syntax-source)))
  (check-equal? (map webify-module-resolution-outcome-status syntax-source-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (list-sort-imports list-sort-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([sort.1 sort.1]
                 [sort7.1 sort7.1])) (y)
        (define-values (y) sort.1))
     '((racket/private/list (sort.1 sort7.1))
       (racket/private/sort (sort)))
     #:module-name 'racket/list))
  (check-equal? list-sort-imports
                '((sort.1 racket/private/list sort.1)
                  (sort7.1 racket/private/list sort7.1)))
  (check-equal? (map webify-module-resolution-outcome-status list-sort-outcomes)
                '(resolved-by-export-scan/provider-precedence
                  resolved-by-export-scan/provider-precedence))
  (define-values (private-list-sort-imports private-list-sort-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([sort sort])) (y)
        (define-values (y) sort))
     '((racket/private/sort (sort))
       (webracket/private/sort-public (sort)))
     #:module-name 'racket/private/list))
  (check-equal? private-list-sort-imports
                '((sort webracket/private/sort-public sort)))
  (check-equal? (map webify-module-resolution-outcome-status private-list-sort-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (webracket-list-sort-imports webracket-list-sort-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([sort.1 sort.1])) (y)
        (define-values (y) sort.1))
     '((racket/private/list (sort.1 sort7.1))
       (webracket/private/sort-public (sort)))))
  (check-equal? webracket-list-sort-imports
                '((sort.1 webracket/private/sort-public sort)))
  (check-equal? (map webify-module-resolution-outcome-status
                     webracket-list-sort-outcomes)
                '(resolved-by-export-scan/provider-precedence))
  (define-values (list-check-list-imports list-check-list-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([check-list7 check-list])) (y)
        (define-values (y) check-list7))
     '((racket/private/for (check-list))
       (racket/private/list (check-list))
       (#%kernel (check-list)))
     #:module-name 'racket/list
     #:dependencies '((check-list7 racket/private/for))))
  (check-equal? list-check-list-imports
                '((check-list7 #%kernel check-list)))
  (check-equal? (map webify-module-resolution-outcome-status
                     list-check-list-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (list-check-list-alias-imports list-check-list-alias-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([check-list7 check-list])) (y)
        (define-values (y) check-list7))
     '((racket/private/for (check-list))
       (#%kernel (check-list)))
     #:module-name 'racket/list
     #:import-aliases '((check-list7 racket/private/for check-list))))
  (check-equal? list-check-list-alias-imports
                '((check-list7 #%kernel check-list)))
  (check-equal? (map webify-module-resolution-outcome-status
                     list-check-list-alias-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (for ([module-name (in-list '(webracket/list racket/private/list))])
    (define-values (staged-list-check-imports staged-list-check-outcomes)
      (webify-resolve-module-linklet-imports/outcomes
       '(linklet (([1/check-list check-list])) (y)
          (define-values (y) 1/check-list))
       '((racket/private/for (check-list))
         (#%kernel (check-list)))
       #:module-name module-name
       #:import-aliases '((1/check-list racket/private/for check-list))))
    (check-equal? staged-list-check-imports
                  '((1/check-list #%kernel check-list)))
    (check-equal? (map webify-module-resolution-outcome-status
                       staged-list-check-outcomes)
                  '(resolved-by-compiled-primitive-alias)))
  (define-values (exact-contract-export-imports exact-contract-export-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([id-partially-applied42.1 id-partially-applied42.1])) (y)
        (define-values (y) id-partially-applied42.1))
     '((racket/dict (id-partially-applied42.1))
       (racket/contract/base (id-partially-applied)))))
  (check-equal? exact-contract-export-imports
                '((id-partially-applied42.1
                   racket/dict
                   id-partially-applied42.1)))
  (check-equal? (map webify-module-resolution-outcome-status
                     exact-contract-export-outcomes)
                '(resolved-by-export-scan/provider-precedence))
  (define-values (directory-list-imports directory-list-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([directory-list.1 directory-list78.1])) (y)
        (define-values (y) directory-list.1))
     '()
     #:module-name 'webracket/private/for))
  (check-equal? directory-list-imports
                '((directory-list.1 #%kernel webracket-directory-list-build-first)))
  (check-equal? (map webify-module-resolution-outcome-status directory-list-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (racket-for-directory-list-imports _racket-for-directory-list-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([directory-list.1 directory-list78.1])) (y)
        (define-values (y) directory-list.1))
     '()
     #:module-name 'racket/private/for))
  (check-equal? racket-for-directory-list-imports
                '((directory-list.1 #%kernel webracket-directory-list-build-first)))
  (define-values (class-coerce-imports class-coerce-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([coerce-contract.1 coerce-contract])) (y)
        (define-values (y) coerce-contract.1))
     '((racket/contract/private/guts (coerce-contract))
       (racket/contract/combinator (coerce-contract))
       (racket/contract (coerce-contract))
       (racket/contract/private/misc (coerce-contract)))
     #:module-name 'racket/private/class-internal))
  (check-equal? class-coerce-imports
                '((coerce-contract.1 racket/contract/private/guts coerce-contract)))
  (check-equal? (map webify-module-resolution-outcome-status class-coerce-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (class-apply-imports class-apply-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([apply-contract.1 apply-contract])) (y)
        (define-values (y) apply-contract.1))
     '((racket/contract/private/guts (apply-contract))
       (racket/contract/base (apply-contract))
       (racket/contract (apply-contract))
       (racket/contract/private/misc (apply-contract)))
     #:module-name 'racket/private/class-internal))
  (check-equal? class-apply-imports
                '((apply-contract.1 racket/contract/private/guts apply-contract)))
  (check-equal? (map webify-module-resolution-outcome-status class-apply-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (class-blame-imports class-blame-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([blame-swap.1 blame-swap])) (y)
        (define-values (y) blame-swap.1))
     '((racket/contract/private/blame (blame-swap))
       (racket/contract/combinator (blame-swap))
       (racket/contract/private/guts (blame-swap))
       (racket/contract/private/misc (blame-swap)))
     #:module-name 'racket/private/class-internal))
  (check-equal? class-blame-imports
                '((blame-swap.1 racket/contract/private/blame blame-swap)))
  (check-equal? (map webify-module-resolution-outcome-status class-blame-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (class-raise-blame-imports _class-raise-blame-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([raise-blame-error.1 raise-blame-error.1])) (y)
        (define-values (y) raise-blame-error.1))
     '((racket/contract/private/blame (raise-blame-error))
       (racket/contract/combinator (raise-blame-error))
       (racket/contract/private/guts (raise-blame-error)))
     #:module-name 'racket/private/class-internal))
  (check-equal? class-raise-blame-imports
                '((raise-blame-error.1 racket/contract/private/blame raise-blame-error)))
  (define-values (class-region-imports _class-region-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([current-contract-region.1 current-contract-region.1])) (y)
        (define-values (y) current-contract-region.1))
     '((racket/contract/region (current-contract-region))
       (racket/contract (current-contract-region))
       (racket/contract/base (current-contract-region)))
     #:module-name 'racket/private/class-internal))
  (check-equal? class-region-imports
                '((current-contract-region.1
                   racket/contract/region
                   current-contract-region)))
  (define-values (class-keyword-method-imports _class-keyword-method-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([struct:keyword-method/arity-error
                  struct:keyword-method/arity-error]))
        (y)
        (define-values (y) struct:keyword-method/arity-error))
     '((racket/private/kw (struct:keyword-method/arity-error)))
     #:module-name 'main))
  (check-equal? class-keyword-method-imports
                '((struct:keyword-method/arity-error
                   racket/private/kw
                   struct:keyword-method/arity-error)))
  (define-values (keyword-new-prop-imports keyword-new-prop-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([new-prop:procedure new-prop:procedure])) (y)
        (define-values (y) new-prop:procedure))
     '()
     #:module-name 'racket/private/kw))
  (check-equal? keyword-new-prop-imports
                '((new-prop:procedure #%kernel prop:procedure)))
  (check-equal? (map webify-module-resolution-outcome-status
                     keyword-new-prop-outcomes)
                '(resolved-by-compiled-primitive-alias))
  (define-values (class-runtime-imports _class-runtime-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([do-make-object do-make-object])) (y)
        (define-values (y) do-make-object))
     '((racket/private/class-internal (do-make-object)))
     #:module-name 'main))
  (check-equal? class-runtime-imports
                '((do-make-object
                   racket/private/class-internal
                   do-make-object)))
  (define-values (class-unsafe-undefined-imports _class-unsafe-undefined-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([1/prop:chaperone-unsafe-undefined prop:chaperone-unsafe-undefined]))
        (y)
        (define-values (y) 1/prop:chaperone-unsafe-undefined))
     '((racket/unsafe/undefined (prop:chaperone-unsafe-undefined)))
     #:module-name 'racket/private/class-internal))
  (check-equal? class-unsafe-undefined-imports
                '((1/prop:chaperone-unsafe-undefined
                   racket/unsafe/undefined
                   prop:chaperone-unsafe-undefined)))
  (define-values (generic-unsafe-undefined-imports _generic-unsafe-undefined-outcomes)
    (webify-resolve-module-linklet-imports/outcomes
     '(linklet (([1/unsafe-undefined unsafe-undefined])) (y)
        (define-values (y) 1/unsafe-undefined))
     '((racket/unsafe/undefined (unsafe-undefined)))
     #:module-name 'main))
  (check-equal? generic-unsafe-undefined-imports
                '((1/unsafe-undefined
                   racket/unsafe/undefined
                   unsafe-undefined)))
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
