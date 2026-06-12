#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/driver.rkt"
         "../pkgs/webracket-lib/compiler/private/parameters.rkt"
         "../pkgs/webracket-lib/compiler/webify/bridge-stats.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-adapter.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-instance.rkt")

;; datum-contains? : any/c any/c -> boolean?
;;   Check whether target appears anywhere within datum.
(define (datum-contains? datum target)
  (or (equal? datum target)
      (cond
        [(pair? datum)
         (or (datum-contains? (car datum) target)
             (datum-contains? (cdr datum) target))]
        [(vector? datum)
         (for/or ([entry (in-vector datum)])
           (datum-contains? entry target))]
        [else
         #f])))

(test-case "cell-backed imports still read module-variable cells"
  (define datum
    (first-slice->top-level-datum/imports
     '(lambda (instance import-arg out-cell)
        imported)
     '(provider-cell)
     '(out)
     #:importss '((imported))
     #:imports-abis '((#f))))
  (check-true
   (datum-contains? datum
                    '(define imported (module-variable-ref import-arg))))
  (check-false
   (datum-contains? datum
                    '(define imported import-arg))))

(test-case "value-backed imports bind direct lexical values"
  (define datum
    (first-slice->top-level-datum/imports
     '(lambda (instance import-arg out-cell)
        imported)
     '(provider-value)
     '(out)
     #:importss '((imported))
     #:imports-abis '((#t))))
  (check-true
   (datum-contains? datum
                    '(define imported import-arg)))
  (check-false
   (datum-contains? datum
                    '(define imported (module-variable-ref import-arg)))))

(test-case "top-level export aliases reuse internal cached values"
  (define exports '(out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell) (void))
     exports))
  (check-true
   (datum-contains? datum
                    `(define ,value-id (module-variable-ref ,cell-id))))
  (check-true
   (datum-contains? datum
                    `(define out ,value-id))))

(test-case "simple public exports can materialize cells after execution"
  (define exports '(out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (variable-set!/define out-cell 42 constant)
        (void))
     exports
     #:module-name 'demo/out))
  (check-true
   (datum-contains? datum
                    `(define-values (,value-id)
                       (webify-linklet-proc$0 (#%variable-reference) (void)))))
  (check-true
   (datum-contains? datum
                    `(module-variable-define! ,cell-id ,value-id 'constant)))
  (check-false
   (datum-contains? datum
                    `(define ,value-id (module-variable-ref ,cell-id)))))

(test-case "real bridge-style export definitions can materialize late"
  (define exports '(out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (module-variable-define! out-cell 42 'constant)
        (module-variable-ref/no-check out-cell))
     exports
     #:module-name 'demo/real-out))
  (check-true
   (datum-contains? datum
                    `(define-values (,value-id)
                       (webify-linklet-proc$0 (#%variable-reference) (void)))))
  (check-true
   (datum-contains? datum
                    `(module-variable-define! ,cell-id ,value-id 'constant)))
  (check-false
   (datum-contains? datum
                    `(define ,value-id (module-variable-ref ,cell-id)))))

(test-case "module instances expose direct value ids for value-safe imports"
  (define provider
    (make-webify-module-instance 'provider '(x)))
  (define provider-value-id
    (webify-module-instance-export-value-id provider 'x))
  (define provider-cell-id
    (webify-module-instance-export-cell-id provider 'x))
  (define-values (datum _instance)
    (first-slice->module-instance-datum/imports
     'consumer
     '(lambda (instance import-arg out-cell)
        imported)
     '((imported))
     (list (hasheq 'imported provider-value-id))
     '(out)
     #:imports-abis '((#t))))
  (check-true
   (datum-contains? datum
                    '(define imported import-arg)))
  (check-true
   (datum-contains? datum
                    `(webify-linklet-proc$0 (#%variable-reference) ,provider-value-id webify-export-cell0$0)))
  (check-false
   (datum-contains? datum
                    `(webify-linklet-proc$0 (#%variable-reference) ,provider-cell-id webify-export-cell0$0))))

(test-case "bridge stats count direct and cell-backed import decisions"
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (first-slice->top-level-datum/imports
     '(lambda (instance cell-arg value-arg out-cell)
        imported-cell
        imported-value)
     '(provider-cell provider-value)
     '(out)
     #:importss '((imported-cell imported-value))
     #:imports-abis '((#f #t))))
  (check-equal? (hash-ref stats 'bridge-import-cell-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-direct-import-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-cell-elision-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-export-cell-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-module-variable-make-count 0) 1))

(test-case "bridge stats record conservative export-cell metadata"
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (first-slice->top-level-datum/imports
     '(lambda (instance imported out-cell)
        (module-variable-reference instance out-cell)
        (variable-set!/check-undefined out-cell 1)
        (variable-ref out-cell)
        imported)
     '(provider-cell)
     '(out)
     #:module-name 'demo/provider
     #:importss '((out))
     #:imports-abis '((#f))))
  (define meta
    (for/or ([(key value) (in-hash stats)])
      (and (equal? key '(bridge-export-cell-meta demo/provider out))
           value)))
  (check-true (hash-ref meta 'public-boundary? #f))
  (check-false (hash-ref meta 'immutable? #t))
  (check-true (hash-ref meta 'reexport? #f))
  (check-true (hash-ref meta 'mutated? #f))
  (check-true (hash-ref meta 'undefined-sensitive? #f))
  (check-true (hash-ref meta 'reflection-visible? #f))
  (check-true (hash-ref meta 'phase0-value-space-only? #f))
  (check-false (hash-ref meta 'dynamic-require-sensitive? #t))
  (check-equal? (hash-ref stats 'bridge-export-cell-public-boundary-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-export-cell-reexport-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-export-cell-mutated-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-export-cell-undefined-sensitive-count 0) 1)
  (check-equal? (hash-ref stats 'bridge-export-cell-reflection-visible-count 0) 1)
  (check-true
   (for/or ([(key value) (in-hash stats)])
     (and (equal? key '(bridge-export-cell-module demo/provider))
          (= value 1))))
  (check-true
   (for/or ([(key value) (in-hash stats)])
     (and (equal? key '(bridge-export-cell-name out))
          (= value 1)))))

(test-case "late-materialization candidates allow refs after define"
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (module-variable-define! out-cell 42 'constant)
        (module-variable-ref/no-check out-cell))
     '(out)
     #:module-name 'demo/out))
  (define meta
    (for/or ([(key value) (in-hash stats)])
      (and (equal? key '(bridge-export-cell-meta demo/out out))
           value)))
  (check-false (hash-ref meta 'mutated? #f))
  (check-false (hash-ref meta 'undefined-sensitive? #f))
  (check-equal?
   (hash-ref stats 'bridge-export-cell-late-materialization-candidate-count 0)
   1))

(test-case "public cell classification distinguishes candidates and blockers"
  (define stats
    (make-hash
     `(((bridge-export-cell-meta demo/candidate out)
        . ,(hasheq 'module-name 'demo/candidate
                   'export 'out
                   'public-boundary? #t
                   'immutable? #t
                   'reexport? #f
                   'mutated? #f
                   'undefined-sensitive? #f
                   'reflection-visible? #f
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t))
       ((bridge-export-cell-meta demo/reexport out)
        . ,(hasheq 'module-name 'demo/reexport
                   'export 'out
                   'public-boundary? #t
                   'immutable? #t
                   'reexport? #t
                   'mutated? #f
                   'undefined-sensitive? #f
                   'reflection-visible? #f
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t))
       ((bridge-export-cell-meta demo/mutated state)
        . ,(hasheq 'module-name 'demo/mutated
                   'export 'state
                   'public-boundary? #t
                   'immutable? #f
                   'reexport? #f
                   'mutated? #t
                   'undefined-sensitive? #f
                   'reflection-visible? #f
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t))
       ((bridge-export-cell-meta demo/reflective ref)
        . ,(hasheq 'module-name 'demo/reflective
                   'export 'ref
                   'public-boundary? #t
                   'immutable? #t
                   'reexport? #f
                   'mutated? #f
                   'undefined-sensitive? #f
                   'reflection-visible? #t
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t)))))
  (define graph
    (webracket/base-local-module-graph
     'demo/root
     '()
     #f
     (hasheq 'demo/candidate 'local-user
             'demo/reexport 'local-user
             'demo/mutated 'local-user
             'demo/reflective 'support-provider)))
  (define counts
    (bridge-public-cell-required-counts graph stats))
  (check-equal? (hash-ref counts 'plain-value-candidate 0) 1)
  (check-equal? (hash-ref counts 'required-reexport 0) 1)
  (check-equal? (hash-ref counts 'required-mutation 0) 1)
  (check-equal? (hash-ref counts 'required-reflection 0) 1)
  (check-equal?
   (bridge-public-cell-classification
    graph
    (hash-ref stats '(bridge-export-cell-meta demo/candidate out)))
   'plain-value-candidate)
  (check-true
   (for/or ([(name count) (in-hash (bridge-public-cell-candidate-module-counts graph stats))])
     (and (eq? name 'demo/candidate)
          (= count 1))))
  (check-true
   (for/or ([(name count) (in-hash (bridge-public-cell-candidate-name-counts graph stats))])
     (and (eq? name 'out)
          (= count 1)))))

(test-case "experimental public-cell elision keeps candidate exports as plain values"
  (define exports '(out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (parameterize ([current-module-bridge-elide-public-cells? #t])
      (first-slice->top-level-datum
       '(lambda (instance out-cell)
       (module-variable-define! out-cell 42 'constant)
       (module-variable-ref/no-check out-cell))
       exports
       #:module-name 'demo-elide-out)))
  (check-true
   (datum-contains? datum
                    `(define-values (,value-id)
                       (webify-linklet-proc$0 (#%variable-reference) (void)))))
  (check-true
   (datum-contains? datum
                    `(define out ,value-id)))
  (check-false
   (datum-contains? datum
                    `(define ,cell-id (module-variable-make 'out))))
  (check-false
   (datum-contains? datum
                    `(module-variable-define! ,cell-id ,value-id 'constant))))

(test-case "module instances expose plain public exports to value-safe importers"
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t])
      (make-webify-module-instance
       'provider
       '(x)
       #:expr
       '(lambda (instance x-cell)
          (module-variable-define! x-cell 41 'constant)
          (module-variable-ref/no-check x-cell))
       #:module-name 'provider)))
  (define provider-entry
    (webify-module-instance-export-entry provider 'x))
  (define provider-value-id
    (webify-module-instance-export-value-id provider 'x))
  (define-values (datum _instance)
    (parameterize ([current-module-bridge-elide-public-cells? #t])
      (first-slice->module-instance-datum/imports
       'consumer
       '(lambda (instance import-arg out-cell)
          imported)
       '((imported))
       (list (hasheq 'imported
                     (webify-module-instance-export-boundary-expression provider 'x)))
       '(out)
       #:imports-abis '((#t)))))
  (check-true (bridge-export-entry-plain-value? provider-entry))
  (check-true
   (datum-contains? datum
                    `(webify-linklet-proc$0 (#%variable-reference) ,provider-value-id webify-export-cell0$0)))
  (check-false
   (datum-contains? datum
                    '(define imported (module-variable-ref import-arg)))))

(module+ main
  (void))
