#lang racket/base

(require racket/list
         rackunit
         "../pkgs/webracket-lib/compiler/driver.rkt"
         "../pkgs/webracket-lib/compiler/private/parameters.rkt"
         "../pkgs/webracket-lib/compiler/webify/bridge-stats.rkt"
         "../pkgs/webracket-lib/compiler/webify/first-slice.rkt"
         "../pkgs/webracket-lib/compiler/webify/known.rkt"
         "../pkgs/webracket-lib/compiler/webify/lower.rkt"
         (only-in "../pkgs/webracket-lib/compiler/webify/module-input.rkt"
                  module-phase0-exported?
                  compiled-primitive-alias-hint)
         "../pkgs/webracket-lib/compiler/webify/module-adapter.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-composer.rkt"
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

(test-case "value-backed constant checks guard plain imports"
  (check-equal?
   (lower-module-variable-ops
    '(variable-reference-constant?
      (module-variable-reference instance imported)))
   '(if (if (module-variable? imported)
          (module-variable-constance imported)
          #f)
      #t
      #f)))

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

(test-case "nested body export definitions materialize late"
  (define exports '(out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (let-values (((tmp) 42))
          (module-variable-define! out-cell tmp 'constant)
          (module-variable-ref/no-check out-cell)))
     exports
     #:module-name 'demo/nested-out))
  (check-true
   (datum-contains? datum
                    `(define-values (,value-id)
                       (webify-linklet-proc$0 (#%variable-reference) (void)))))
  (check-true
   (datum-contains? datum
                    `(module-variable-define! ,cell-id ,value-id 'constant)))
  (check-false
   (datum-contains? datum
                    '(module-variable-define! out-cell tmp 'constant))))

(test-case "export-cell imports block late materialization"
  (define exports '(out))
  (define proc-id
    (car (first-slice-top-level-helper-ids exports)))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (first-slice->top-level-datum/imports
     '(lambda (instance in-cell out-cell)
        (module-variable-define! out-cell 42 'constant)
        (module-variable-ref/no-check out-cell))
     (list cell-id)
     exports
     #:module-name 'demo/self-import
     #:importss '((in))))
  (check-false
   (datum-contains? datum
                    '(define webify-late-export-local-value0$0 (void))))
  (check-true
   (datum-contains? datum
                    `(define ,cell-id (module-variable-make 'out))))
  (check-true
   (datum-contains? datum
                    `(,proc-id (#%variable-reference) ,cell-id ,cell-id)))
  (check-true
   (datum-contains? datum
                    `(define ,value-id (module-variable-ref ,cell-id)))))

(test-case "pre-base apply helper imports primitive apply instead of itself"
  (check-equal?
   (compiled-primitive-alias-hint 'webracket/private/pre-base-apply
                                  '1/new-apply-proc
                                  'new-apply-proc)
   '(#%kernel apply)))

(test-case "Racket 9.3 keyword shim avoids a self-provider import"
  (for* ([module-name (in-list '(racket/private/kw webracket/private/kw))]
         [binding (in-list '((new:procedure-reduce-arity . procedure-reduce-arity)
                             (new:procedure-reduce-arity-mask . procedure-reduce-arity-mask)
                             (new:procedure->method . procedure->method)
                             (new:procedure-rename . procedure-rename)
                             (new:procedure-realm . procedure-realm)
                             (new-prop:procedure . prop:procedure)))])
    (check-equal?
     (compiled-primitive-alias-hint module-name
                                    (car binding)
                                    (car binding))
     (list '#%kernel (cdr binding)))))

(test-case "Racket class wrapper provider follows its host export table"
  (define class-struct-available?
    (with-handlers ([exn:fail? (lambda (_exn) #f)])
      (dynamic-require 'racket/private/class-struct #f)
      #t))
  (if class-struct-available?
      (check-true
       (module-phase0-exported?
        'racket/private/class-struct
        'object/c-wrapper-info-blame+neg-party))
      (check-false
       (module-phase0-exported?
        'racket/private/class-struct
        'object/c-wrapper-info-blame+neg-party))))

(test-case "late-materialization locals avoid lowered helper name collisions"
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (define webify-export-local-value0$0 17)
        (module-variable-define! out-cell 42 'constant)
        (module-variable-ref/no-check out-cell))
     '(out)
     #:module-name 'demo/collision))
  (check-false
   (datum-contains? datum
                    '(define webify-export-local-value0$0 (void)))))

(test-case "bridged define materialization updates late local instead of rebinding it"
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (define out
          (begin
            (module-variable-define! out-cell 42 'constant)
            (void)))
        out)
     '(out)
     #:module-name 'demo/bridged-define))
  (check-true
   (datum-contains? datum
                    '(set! webify-late-export-local-value0$0 42)))
  (check-false
   (datum-contains? datum
                    '(define webify-late-export-local-value0$0 42))))

(test-case "forward export reads stay cell-backed instead of late materialized"
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (define captured
          (lambda ()
            (module-variable-ref/no-check out-cell)))
        (module-variable-define! out-cell 42 'constant)
        captured)
     '(out)
     #:module-name 'demo/forward-export-read))
  (check-false
   (datum-contains? datum
                    '(define webify-late-export-local-value0$0 (void))))
  (check-true
   (datum-contains? datum
                    '(module-variable-define! webify-export-cell0$0 42 'constant))))

(test-case "define-values rhs export reads stay cell-backed"
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (define-values (internal-cache)
          (unboxed out-cell))
        (module-variable-define! out-cell 42 'constant)
        internal-cache)
     '(out)
     #:module-name 'demo/define-values-forward-export-read))
  (check-false
   (datum-contains? datum
                    '(define webify-late-export-local-value0$0 (void))))
  (check-true
   (datum-contains? datum
                    '(module-variable-define! webify-export-cell0$0 42 'constant))))

(test-case "placeholder void exports stay cell-backed"
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (module-variable-define! out-cell (boxed (void)) 'constant)
        (module-variable-ref/no-check out-cell))
     '(out)
     #:module-name 'demo/placeholder-export))
  (check-false
   (datum-contains? datum
                    '(define webify-late-export-local-value0$0 (void))))
  (check-true
   (datum-contains? datum
                    '(module-variable-define! webify-export-cell0$0 (boxed (void)) 'constant))))

(test-case "export writes before later definitions stay cell-backed"
  (define datum
    (first-slice->top-level-datum
     '(lambda (instance out-cell)
        (module-variable-define! out-cell (make-hasheq) 'constant)
        (define cache (module-variable-ref/no-check out-cell))
        (define (lookup key)
          (hash-ref cache key #f))
        lookup)
     '(out)
     #:module-name 'demo/export-write-before-definitions))
  (check-false
   (datum-contains? datum
                    '(define webify-late-export-local-value0$0 (void))))
  (check-true
   (datum-contains? datum
                    '(module-variable-define! webify-export-cell0$0 (make-hasheq) 'constant))))

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
  (check-false (hash-ref meta 'plain-value-base-candidate? #t))
  (check-false (hash-ref meta 'plain-value-policy-eligible? #t))
  (check-false (hash-ref meta 'forced-cell? #t))
  (check-equal? (hash-ref meta 'selected-export-kind 'missing) 'cell)
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

(test-case "read-before-definition keeps public export cells"
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids '(out)) 'out))
  (define stats (make-hash))
  (define datum
    (parameterize ([current-webify-bridge-stats stats])
      (first-slice->top-level-datum/imports
       '(lambda (instance out-cell)
          (module-variable-ref/no-check out-cell)
          (module-variable-define! out-cell 42 'constant)
          (module-variable-ref/no-check out-cell))
       '()
       '(out)
       #:module-name 'demo/read-before-definition)))
  (define meta
    (for/or ([(key value) (in-hash stats)])
      (and (equal? key '(bridge-export-cell-meta demo/read-before-definition out))
           value)))
  (check-true (hash-ref meta 'immutable? #f))
  (check-true (hash-ref meta 'read-before-definition? #f))
  (check-false (hash-ref meta 'undefined-sensitive? #t))
  (check-false (hash-ref meta 'plain-value-base-candidate? #t))
  (check-equal? (hash-ref meta 'selected-export-kind 'missing) 'cell)
  (check-true
   (datum-contains? datum
                    `(module-variable-ref/no-check ,cell-id))))

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
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #t
                   'plain-value-policy-eligible? #t
                   'forced-cell? #f
                   'selected-export-kind 'value))
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
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #f
                   'plain-value-policy-eligible? #t
                   'forced-cell? #f
                   'selected-export-kind 'cell))
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
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #f
                   'plain-value-policy-eligible? #t
                   'forced-cell? #f
                   'selected-export-kind 'cell))
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
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #f
                   'plain-value-policy-eligible? #t
                   'forced-cell? #f
                   'selected-export-kind 'cell)))))
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

(test-case "candidate-not-elided diagnostics separate policy and importer blockers"
  (define stats
    (make-hash
     `(((bridge-export-cell-meta demo/local out)
        . ,(hasheq 'module-name 'demo/local
                   'export 'out
                   'public-boundary? #t
                   'immutable? #t
                   'reexport? #f
                   'mutated? #f
                   'undefined-sensitive? #f
                   'reflection-visible? #f
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #t
                   'plain-value-policy-eligible? #t
                   'forced-cell? #t
                   'selected-export-kind 'cell))
       ((bridge-export-cell-meta web-easy helper)
        . ,(hasheq 'module-name 'web-easy
                   'export 'helper
                   'public-boundary? #t
                   'immutable? #t
                   'reexport? #f
                   'mutated? #f
                   'undefined-sensitive? #f
                   'reflection-visible? #f
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #t
                   'plain-value-policy-eligible? #f
                   'forced-cell? #f
                   'selected-export-kind 'cell))
       ((bridge-export-cell-meta racket/private/kw keyword-apply)
        . ,(hasheq 'module-name 'racket/private/kw
                   'export 'keyword-apply
                   'public-boundary? #t
                   'immutable? #t
                   'reexport? #f
                   'mutated? #f
                   'undefined-sensitive? #f
                   'reflection-visible? #f
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #t
                   'plain-value-policy-eligible? #f
                   'forced-cell? #f
                   'selected-export-kind 'cell))
       ((bridge-export-cell-meta demo/elided ok)
        . ,(hasheq 'module-name 'demo/elided
                   'export 'ok
                   'public-boundary? #t
                   'immutable? #t
                   'reexport? #f
                   'mutated? #f
                   'undefined-sensitive? #f
                   'reflection-visible? #f
                   'dynamic-require-sensitive? #f
                   'phase0-value-space-only? #t
                   'plain-value-base-candidate? #t
                   'plain-value-policy-eligible? #t
                   'forced-cell? #f
                   'selected-export-kind 'value)))))
  (define graph
    (webracket/base-local-module-graph
     'demo/root
     '()
     #f
     (hasheq 'demo/local 'local-user
             'web-easy 'support-provider
             'racket/private/kw 'installed-provider
             'demo/elided 'local-user)))
  (define counts
    (bridge-public-cell-candidate-not-elided-counts graph stats))
  (check-equal? (hash-ref counts 'candidate-not-elided 0) 3)
  (check-equal? (hash-ref counts 'candidate-not-elided-local-only-policy 0) 2)
  (check-equal? (hash-ref counts 'candidate-not-elided-provider-export 0) 2)
  (check-equal? (hash-ref counts 'candidate-not-elided-support-provider 0) 1)
  (check-equal? (hash-ref counts 'candidate-not-elided-installed-provider 0) 1)
  (check-equal? (hash-ref counts 'candidate-not-elided-importer-needs-cell 0) 1)
  (check-equal? (hash-ref counts 'candidate-not-elided-registry-shape 0) 0)
  (check-equal? (hash-ref counts 'candidate-not-elided-unknown 0) 0)
  (check-true
   (for/or ([(name count) (in-hash (bridge-public-cell-candidate-not-elided-module-counts graph stats))])
     (and (eq? name 'web-easy)
          (= count 1))))
  (check-true
   (for/or ([(name count) (in-hash (bridge-public-cell-candidate-not-elided-name-counts graph stats))])
     (and (eq? name 'helper)
          (= count 1)))))

(test-case "experimental public-cell elision keeps candidate exports as plain values"
  (define exports '(out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'demo-elide-out 'local-user)])
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

(test-case "late-materialized export rewriting covers nested refs and respects shadowing"
  (define exports '(out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'demo-late-rewrite 'local-user)])
      (first-slice->top-level-datum
       '(lambda (instance out-cell)
          (module-variable-define! out-cell 41 'constant)
          (define direct out-cell)
          (define nested-let
            (let-values (((tmp) out-cell))
              tmp))
          (define nested-begin
            (begin out-cell))
          (define nested-app
            (list out-cell))
          (define shadowed
            (let-values (((out-cell) 99))
              out-cell))
          direct)
       exports
       #:module-name 'demo-late-rewrite)))
  (check-true
   (datum-contains? datum
                    '(define shadowed
                       (let-values (((out-cell) 99))
                         out-cell))))
  (check-true
   (datum-contains? datum
                    `(define out ,value-id)))
  (check-false
   (datum-contains? datum
                    '(define direct out-cell)))
  (check-false
   (datum-contains? datum
                    '(define nested-let
                       (let-values (((tmp) out-cell))
                         tmp))))
  (check-false
   (datum-contains? datum
                    '(define nested-begin
                       (begin out-cell))))
  (check-false
   (datum-contains? datum
                    '(define nested-app
                       (list out-cell)))))

(test-case "delayed closure captures do not count as read-before-definition"
  (define exports '(out))
  (define stats (make-hash))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define datum
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'demo-delayed-capture 'local-user)]
                   [current-webify-bridge-stats stats])
      (first-slice->top-level-datum
       '(lambda (instance out-cell)
          (module-variable-define! out-cell 41 'constant)
          (define thunk
            (lambda ()
              out-cell))
          (module-variable-ref/no-check out-cell))
       exports
       #:module-name 'demo-delayed-capture)))
  (define meta
    (for/or ([(key value) (in-hash stats)])
      (and (equal? key '(bridge-export-cell-meta demo-delayed-capture out))
           value)))
  (check-false (hash-ref meta 'read-before-definition? #f))
  (check-equal? (hash-ref meta 'selected-export-kind 'missing) 'value)
  (check-true
   (datum-contains? datum
                    `(define-values (,value-id)
                       (webify-linklet-proc$0 (#%variable-reference) (void)))))
  (check-false
   (datum-contains? datum
                    `(define ,cell-id (module-variable-make 'out)))))

(test-case "top-level init helper materializations keep public export cells"
  (define exports '(out))
  (define stats (make-hash))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define datum
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'demo-init-helper 'local-user)]
                   [current-webify-bridge-stats stats])
      (first-slice->top-level-datum
       '(lambda (instance out-cell)
          (define effect
            (begin
              (let-values (((out)
                            (call-with-values (lambda () 41) values)))
                (module-variable-define! out-cell out 'constant))
              (void)))
          (define out (module-variable-ref/no-check out-cell))
          out)
       exports
       #:module-name 'demo-init-helper)))
  (define meta
    (for/or ([(key value) (in-hash stats)])
      (and (equal? key '(bridge-export-cell-meta demo-init-helper out))
           value)))
  (check-false (hash-ref meta 'read-before-definition? #f))
  (check-true (hash-ref meta 'definition-materialization-before-definition? #f))
  (check-equal? (hash-ref meta 'selected-export-kind 'missing) 'cell)
  (check-true
   (datum-contains? datum
                    `(define ,cell-id (module-variable-make 'out))))
  (check-true
   (datum-contains? datum
                    `(define ,value-id (module-variable-ref ,cell-id)))))

(test-case "boxed init helper materializations keep public export cells"
  (define exports '(out))
  (define stats (make-hash))
  (define cell-id
    (hash-ref (first-slice-top-level-export-cell-ids exports) 'out))
  (define datum
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'demo-boxed-init-helper 'local-user)]
                   [current-webify-bridge-stats stats])
      (first-slice->top-level-datum
       '(lambda (instance out-cell)
          (define effect
            (begin
              (set-boxed! out-cell 41)
              (void)))
          (define after-effect (void))
          after-effect)
       exports
       #:module-name 'demo-boxed-init-helper)))
  (define meta
    (for/or ([(key value) (in-hash stats)])
      (and (equal? key '(bridge-export-cell-meta demo-boxed-init-helper out))
           value)))
  (check-true (hash-ref meta 'definition-materialization-before-definition? #f))
  (check-equal? (hash-ref meta 'selected-export-kind 'missing) 'cell)
  (check-true
   (datum-contains? datum
                    `(define ,cell-id (module-variable-make 'out)))))

(test-case "late-materialized export rewriting covers lowered #%top refs"
  (define exports '(out))
  (define value-id
    (hash-ref (first-slice-top-level-export-value-ids exports) 'out))
  (define datum
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'demo-late-top-rewrite 'local-user)])
      (first-slice->top-level-datum
       '(lambda (instance out-cell)
          (module-variable-define! out-cell 41 'constant)
          (define via-top (#%top . out-cell))
          via-top)
       exports
       #:module-name 'demo-late-top-rewrite)))
  (check-true
   (datum-contains? datum
                    `(define out ,value-id)))
  (check-false
   (datum-contains? datum
                    '(define via-top (#%top . out-cell))))
  (check-false
   (datum-contains? datum
                    '(define via-top out-cell))))

(test-case "module instances expose plain public exports to value-safe importers"
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'provider 'local-user)])
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
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'provider 'local-user)])
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

(test-case "support-provider exports can elide public cells for value-safe importers"
  (define stats (make-hash))
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'web-easy 'support-provider)]
                   [current-webify-bridge-stats stats])
      (make-webify-module-instance
       'web-easy
       '(helper)
       #:expr
       '(lambda (instance helper-cell)
          (module-variable-define! helper-cell 41 'constant)
          (module-variable-ref/no-check helper-cell))
       #:module-name 'web-easy)))
  (define provider-entry
    (webify-module-instance-export-entry provider 'helper))
  (define provider-value-id
    (webify-module-instance-export-value-id provider 'helper))
  (define-values (datum _instance)
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'web-easy 'support-provider)]
                   [current-webify-bridge-stats stats])
      (first-slice->module-instance-datum/imports
       'consumer
       '(lambda (instance import-arg out-cell)
          imported)
       '((imported))
       (list (hasheq 'imported
                     (webify-module-instance-export-boundary-expression provider 'helper)))
       '(out)
       #:imports-abis '((#t)))))
  (check-true (bridge-export-entry-plain-value? provider-entry))
  (check-true
   (datum-contains? datum
                    `(webify-linklet-proc$0 (#%variable-reference) ,provider-value-id webify-export-cell0$0)))
  (check-false
   (datum-contains? datum
                    '(define imported (module-variable-ref import-arg)))))

(test-case "abi-only knowns classify imports without app/value or added import groups"
  (define-values (expr _importss _exports revised-import-keys imports-abis _exports-info)
    (parameterize ([current-webify-knowns-mode 'abi-only])
      (webify-linklet-first-slice
       '(linklet (((helper helper))) ()
          (helper 'ok))
       #:serializable?-box #f
       #:datum-intern? #f
       #:target #f
       #:allow-set!-undefined? #f
       #:unsafe-mode? #f
       #:enforce-constant? #t
       #:allow-inline? #t
       #:no-prompt? #f
       #:prim-knowns (hasheq)
       #:primitives (hasheq)
       #:compiler-query (lambda (_v) #f)
       #:get-import-knowns
       (lambda (_key)
         (values (hasheq 'helper (known-procedure/single-valued 2)) #f #f))
       #:import-keys '#(demo/provider))))
  (check-equal? revised-import-keys '#(demo/provider))
  (check-equal? imports-abis '((proc)))
  (check-false (datum-contains? expr '#%app/value)))

(test-case "composer rekeys abi-only knowns for uninterned import names"
  (define theme-import
    (string->uninterned-symbol "theme4.1"))
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (webify-compose-linklet-first-slices
     (list
      (webify-linklet-slice-spec
       'provider
       '(linklet () (theme4.1)
          (define-values (theme4.1) (lambda (x) x)))
       '())
      (webify-linklet-slice-spec
       'consumer
       `(linklet (((,theme-import ,theme-import))) ()
          (,theme-import 'ok))
       (list (list theme-import 'provider 'theme4.1))))
     #:tail '((void))
     #:define-export-aliases? #f
     #:serializable?-box #f
     #:datum-intern? #f
     #:target #f
     #:allow-set!-undefined? #f
     #:unsafe-mode? #f
     #:enforce-constant? #t
     #:allow-inline? #t
     #:no-prompt? #f
     #:prim-knowns (hasheq)
     #:primitives (hasheq)
     #:compiler-query (lambda (_v) #f)
     #:get-import-knowns (lambda (_key) (values #f #f #f))
     #:import-keys #f))
  (check-equal?
   (hash-ref stats 'bridge-import-abi-resolved-from-prior-export-knowns-count 0)
   1)
  (define meta
    (for/or ([(key value) (in-hash stats)])
      (and (list? key)
           (<= 5 (length key))
           (equal? (take key 5)
                   (list 'bridge-import-abi-meta
                         'consumer
                         'provider
                         theme-import
                         'theme4.1))
           value)))
  (check-not-false meta)
  (check-equal? (hash-ref meta 'abi #f) 'proc)
  (check-true (hash-ref meta 'prior-export-known? #f)))

(test-case "composer merges abi-only knowns across mixed-provider import groups"
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (webify-compose-linklet-first-slices
     (list
      (webify-linklet-slice-spec
       'kw-provider
       '(linklet () (keyword-apply)
          (define-values (keyword-apply) (lambda (x) x)))
       '())
      (webify-linklet-slice-spec
       'helper-provider
       '(linklet () (helper)
          (define-values (helper) 'ok))
       '())
      (webify-linklet-slice-spec
       'consumer
       '(linklet (((keyword-apply keyword-apply)
                   (helper helper)))
          ()
          helper
          (keyword-apply 'ok))
       '((keyword-apply kw-provider keyword-apply)
         (helper helper-provider helper))))
     #:tail '((void))
     #:define-export-aliases? #f
     #:serializable?-box #f
     #:datum-intern? #f
     #:target #f
     #:allow-set!-undefined? #f
     #:unsafe-mode? #f
     #:enforce-constant? #t
     #:allow-inline? #t
     #:no-prompt? #f
     #:prim-knowns (hasheq)
     #:primitives (hasheq)
     #:compiler-query (lambda (_v) #f)
     #:get-import-knowns (lambda (_key) (values #f #f #f))
     #:import-keys #f))
  (check-equal?
   (hash-ref stats 'bridge-import-abi-resolved-from-prior-export-knowns-count 0)
   2)
  (define keyword-meta
    (for/or ([(key value) (in-hash stats)])
      (and (pair? key)
           (equal? key
                   '(bridge-import-abi-meta consumer kw-provider keyword-apply keyword-apply))
           value)))
  (check-not-false keyword-meta)
  (check-equal? (hash-ref keyword-meta 'abi #f) 'proc))

(test-case "kernel provider imports resolve through the narrow kernel-known table"
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (webify-compose-linklet-first-slices
     (list
      (webify-linklet-slice-spec
       'consumer
       '(linklet (((displayln displayln))) ()
          (displayln 'ok))
       '((displayln #%kernel displayln))))
     #:tail '((void))
     #:define-export-aliases? #f
     #:serializable?-box #f
     #:datum-intern? #f
     #:target #f
     #:allow-set!-undefined? #f
     #:unsafe-mode? #f
     #:enforce-constant? #t
     #:allow-inline? #t
     #:no-prompt? #f
     #:prim-knowns (hasheq)
     #:primitives (hasheq)
     #:compiler-query (lambda (_v) #f)
     #:get-import-knowns (lambda (_key) (values #f #f #f))
     #:import-keys #f))
  (check-equal?
   (hash-ref stats 'bridge-import-abi-resolved-from-kernel-knowns-count 0)
   1)
  (define meta
    (hash-ref stats
              '(bridge-import-abi-meta consumer #%kernel displayln displayln)
              #f))
  (check-not-false meta)
  (check-equal? (hash-ref meta 'provider-kind #f) 'kernel-provider)
  (check-true (hash-ref meta 'kernel-known? #f))
  (check-true (hash-ref meta 'prior-export-known? #f))
  (check-equal? (hash-ref meta 'baseline-abi #f) #f)
  (check-equal? (hash-ref meta 'abi #f) #t))

(test-case "kernel provider error imports resolve through the kernel-known table"
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (webify-compose-linklet-first-slices
     (list
      (webify-linklet-slice-spec
       'consumer
       '(linklet (((error error))) ()
          (error 'consumer "boom"))
       '((error #%kernel error))))
     #:tail '((void))
     #:define-export-aliases? #f
     #:serializable?-box #f
     #:datum-intern? #f
     #:target #f
     #:allow-set!-undefined? #f
     #:unsafe-mode? #f
     #:enforce-constant? #t
     #:allow-inline? #t
     #:no-prompt? #f
     #:prim-knowns (hasheq)
     #:primitives (hasheq)
     #:compiler-query (lambda (_v) #f)
     #:get-import-knowns (lambda (_key) (values #f #f #f))
     #:import-keys #f))
  (check-equal?
   (hash-ref stats 'bridge-import-abi-resolved-from-kernel-knowns-count 0)
   1)
  (define meta
    (hash-ref stats
              '(bridge-import-abi-meta consumer #%kernel error error)
              #f))
  (check-not-false meta)
  (check-equal? (hash-ref meta 'provider-kind #f) 'kernel-provider)
  (check-true (hash-ref meta 'kernel-known? #f))
  (check-true (hash-ref meta 'prior-export-known? #f))
  (check-equal? (hash-ref meta 'baseline-abi #f) #f)
  (check-equal? (hash-ref meta 'abi #f) #t))

(test-case "unknown kernel imports stay conservative after classification"
  (define stats (make-hash))
  (parameterize ([current-webify-bridge-stats stats])
    (webify-compose-linklet-first-slices
     (list
      (webify-linklet-slice-spec
       'consumer
       '(linklet (((car car))) ()
          (car 'ok))
       '((car #%kernel car))))
     #:tail '((void))
     #:define-export-aliases? #f
     #:serializable?-box #f
     #:datum-intern? #f
     #:target #f
     #:allow-set!-undefined? #f
     #:unsafe-mode? #f
     #:enforce-constant? #t
     #:allow-inline? #t
     #:no-prompt? #f
     #:prim-knowns (hasheq)
     #:primitives (hasheq)
     #:compiler-query (lambda (_v) #f)
     #:get-import-knowns (lambda (_key) (values #f #f #f))
     #:import-keys #f))
  (check-equal? (hash-ref stats 'bridge-import-abi-false-kernel-provider-count 0) 1)
  (define meta
    (hash-ref stats
              '(bridge-import-abi-meta consumer #%kernel car car)
              #f))
  (check-not-false meta)
  (check-equal? (hash-ref meta 'provider-kind #f) 'kernel-provider)
  (check-false (hash-ref meta 'kernel-known? #f))
  (check-equal? (hash-ref meta 'abi #f) #f)
  (check-equal? (hash-ref meta 'false-reason #f) 'missing-export-info))

(test-case "installed-provider exports stay cell-backed in first provider milestone"
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'racket/private/kw 'installed-provider)])
      (make-webify-module-instance
       'racket/private/kw
       '(keyword-apply)
       #:expr
       '(lambda (instance keyword-apply-cell)
          (module-variable-define! keyword-apply-cell 41 'constant)
          (module-variable-ref/no-check keyword-apply-cell))
       #:module-name 'racket/private/kw)))
  (check-true
   (bridge-export-entry-cell-backed?
    (webify-module-instance-export-entry provider 'keyword-apply))))

(test-case "webracket-owned installed-provider exports can elide under experimental policy"
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'webracket/unsafe/dom 'installed-provider)]
                   [current-module-bridge-elidable-module-names
                    '(webracket/unsafe/dom)])
      (make-webify-module-instance
       'webracket/unsafe/dom
       '(node)
       #:expr
       '(lambda (instance node-cell)
          (module-variable-define! node-cell 41 'constant)
          (module-variable-ref/no-check node-cell))
       #:module-name 'webracket/unsafe/dom)))
  (check-true
   (bridge-export-entry-plain-value?
    (webify-module-instance-export-entry provider 'node))))

(test-case "allowlisted racket installed-provider exports can elide under experimental policy"
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'racket/list 'installed-provider)]
                   [current-module-bridge-elidable-module-names
                    '(racket/list)])
      (make-webify-module-instance
       'racket/list
       '(first)
       #:expr
       '(lambda (instance first-cell)
          (module-variable-define! first-cell 41 'constant)
          (module-variable-ref/no-check first-cell))
       #:module-name 'racket/list)))
  (check-true
   (bridge-export-entry-plain-value?
    (webify-module-instance-export-entry provider 'first))))

(test-case "non-allowlisted installed providers stay cell-backed"
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'racket/vector 'installed-provider)])
      (make-webify-module-instance
       'racket/vector
       '(vector-copy)
       #:expr
       '(lambda (instance vector-copy-cell)
          (module-variable-define! vector-copy-cell 41 'constant)
          (module-variable-ref/no-check vector-copy-cell))
       #:module-name 'racket/vector)))
  (check-true
   (bridge-export-entry-cell-backed?
    (webify-module-instance-export-entry provider 'vector-copy))))

(test-case "unsafe allowlisted racket installed-provider exports stay cell-backed"
  (define provider
    (parameterize ([current-module-bridge-elide-public-cells? #t]
                   [current-module-bridge-module-kinds
                    (hasheq 'racket/list 'installed-provider)]
                   [current-module-bridge-elidable-module-names
                    '(racket/list)])
      (make-webify-module-instance
       'racket/list
       '(first)
       #:expr
       '(lambda (instance first-cell)
          (module-variable-set! first-cell 41)
          (module-variable-ref/no-check first-cell))
       #:module-name 'racket/list)))
  (check-true
   (bridge-export-entry-cell-backed?
    (webify-module-instance-export-entry provider 'first))))

(test-case "installed-provider candidate audit splits policy classes"
  (define stats
    (hasheq
     '(bridge-export-cell-meta webracket/unsafe/dom node)
     (hasheq 'module-name 'webracket/unsafe/dom
             'export 'node
             'public-boundary? #t
             'immutable? #t
             'reexport? #f
             'mutated? #f
             'undefined-sensitive? #f
             'reflection-visible? #f
             'dynamic-require-sensitive? #f
             'phase0-value-space-only? #t
             'plain-value-base-candidate? #t
             'plain-value-policy-eligible? #f
             'forced-cell? #f
             'selected-export-kind 'cell)
     '(bridge-export-cell-meta racket/list first)
     (hasheq 'module-name 'racket/list
             'export 'first
             'public-boundary? #t
             'immutable? #t
             'reexport? #f
             'mutated? #f
             'undefined-sensitive? #f
             'reflection-visible? #f
             'dynamic-require-sensitive? #f
             'phase0-value-space-only? #t
             'plain-value-base-candidate? #t
             'plain-value-policy-eligible? #f
             'forced-cell? #f
             'selected-export-kind 'cell)
     '(bridge-export-cell-meta some/pkg value)
     (hasheq 'module-name 'some/pkg
             'export 'value
             'public-boundary? #t
             'immutable? #t
             'reexport? #f
             'mutated? #f
             'undefined-sensitive? #f
             'reflection-visible? #f
             'dynamic-require-sensitive? #f
             'phase0-value-space-only? #t
             'plain-value-base-candidate? #t
             'plain-value-policy-eligible? #f
             'forced-cell? #f
             'selected-export-kind 'cell)
     '(bridge-import-abi-meta consumer webracket/unsafe/dom node node)
     (hasheq 'importer-module 'consumer
             'provider-module 'webracket/unsafe/dom
             'import-name 'node
             'export-name 'node
             'abi #t)
     '(bridge-import-abi-meta consumer racket/list first first)
     (hasheq 'importer-module 'consumer
             'provider-module 'racket/list
             'import-name 'first
             'export-name 'first
             'abi #t)
     '(bridge-import-abi-meta consumer some/pkg value value)
     (hasheq 'importer-module 'consumer
             'provider-module 'some/pkg
             'import-name 'value
             'export-name 'value
             'abi #t)))
  (define graph
    (webracket/base-local-module-graph
     'demo/root
     '()
     #f
     (hasheq 'webracket/unsafe/dom 'installed-provider
             'racket/list 'installed-provider
             'some/pkg 'installed-provider)))
  (define counts
    (bridge-installed-provider-candidate-class-counts graph stats))
  (check-equal?
   (hash-ref counts 'webracket-owned-installed-provider 0)
   1)
  (check-equal?
   (hash-ref counts 'racket-installed-provider 0)
   1)
  (check-equal?
   (hash-ref counts 'third-party-installed-provider 0)
   1)
  (check-equal?
   (hash-ref counts 'unknown-installed-provider 0)
   0)
  (check-true
   (regexp-match?
    #rx"racket/list/first"
    (bridge-installed-provider-candidate-class-details
     graph
     stats
     'racket-installed-provider))))

(module+ main
  (void))
