#lang racket/base

(require racket/cmdline
         racket/match
         racket/port
         racket/string)

;; run-probe : path-string? string? string? -> (values exact-integer? string?)
;;   Run one bounded expander probe against a compiled expander wasm.
(define (run-probe wasm-path export-name json-args)
  (define node (or (find-executable-path "node")
                   (error 'check-expander-kernel-smoke "node not found")))
  (define-values (proc out in err)
    (subprocess #f #f #f
                node
                "--experimental-wasm-exnref"
                "webify/probe-expander-instantiate.js"
                wasm-path
                "--bounded-call-json"
                "20000"
                export-name
                json-args))
  (close-output-port in)
  (define stdout (port->string out))
  (define stderr (port->string err))
  (subprocess-wait proc)
  (define status (subprocess-status proc))
  (values status (string-append stdout stderr)))

;; require-output : string? string? -> void?
;;   Fail unless needle appears in output.
(define (require-output output needle)
  (unless (string-contains? output needle)
    (error 'check-expander-kernel-smoke
           "expected output to contain ~s\noutput:\n~a"
           needle
           output)))

;; reject-output : string? string? -> void?
;;   Fail if needle appears in output.
(define (reject-output output needle)
  (when (string-contains? output needle)
    (error 'check-expander-kernel-smoke
           "expected output not to contain ~s\noutput:\n~a"
           needle
           output)))

;; require-any-output : string? (listof string?) -> void?
;;   Fail unless at least one needle appears in output.
(define (require-any-output output needles)
  (unless (for/or ([needle (in-list needles)])
            (string-contains? output needle))
    (error 'check-expander-kernel-smoke
           "expected output to contain one of ~s\noutput:\n~a"
           needles
           output)))

(define wasm-path
  (command-line
   #:program "check-expander-kernel-smoke"
   #:args ([wasm-path "/private/tmp/webracket-expander-startup.wasm"])
   wasm-path))

(unless (file-exists? wasm-path)
  (error 'check-expander-kernel-smoke
         "compiled expander wasm not found: ~a"
         wasm-path))

(define (check-ok-probe export-name json-args after-marker expected-datum-fragment)
  (define-values (status output)
    (run-probe wasm-path export-name json-args))
  (unless (zero? status)
    (error 'check-expander-kernel-smoke
           "probe ~a failed with status ~a\noutput:\n~a"
           export-name
           status
           output))
  (require-output output after-marker)
  (require-output output expected-datum-fragment)
  (void))

;; check-failing-probe : string? string? (listof string?) (listof string?) -> void?
;;   Require a known frontier failure and reject old internal failure modes.
(define (check-failing-probe export-name json-args required-fragments rejected-fragments)
  (define-values (status output)
    (run-probe wasm-path export-name json-args))
  (when (zero? status)
    (error 'check-expander-kernel-smoke
           "probe ~a unexpectedly succeeded\noutput:\n~a"
           export-name
           output))
  (for ([fragment (in-list required-fragments)])
    (require-output output fragment))
  (for ([fragment (in-list rejected-fragments)])
    (reject-output output fragment))
  (void))

(define-values (quote-status quote-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/direct-expand-kernel-quote"
             "[]"))
(unless (zero? quote-status)
  (error 'check-expander-kernel-smoke
         "quote probe failed with status ~a\noutput:\n~a"
         quote-status
         quote-output))
(require-output quote-output "probe:direct-expand-kernel-quote:after-expand")
(require-output quote-output "(quote 42)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-datum"
 "[]"
 "probe:direct-expand-kernel-datum:after-expand"
 "(quote 42)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-let"
 "[]"
 "probe:direct-expand-kernel-let:after-expand"
 "(#%top . let)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-let-values"
 "[]"
 "probe:direct-expand-kernel-let-values:after-expand"
 "(let-values")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-if"
 "[]"
 "probe:direct-expand-kernel-if:after-expand"
 "(if (quote #t)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-lambda"
 "[]"
 "probe:direct-expand-kernel-lambda:after-expand"
 "(lambda (x) x)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/direct-expand-kernel-primitive-app"
 "[]"
 "probe:direct-expand-kernel-primitive-app:after-expand"
 "(#%top . +)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/ordinary-kernel-datum"
 "[]"
 "probe:ordinary-kernel-datum:after-expand"
 "(quote 42)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/ordinary-kernel-primitive-app"
 "[]"
 "probe:ordinary-kernel-primitive-app:after-expand"
 "(#%app + (quote 1) (quote 2))")

(check-ok-probe
 "webify-probe-expand-self-evaluating/ordinary-kernel-if"
 "[]"
 "probe:ordinary-kernel-if:after-expand"
 "(if (quote #t) (quote 1) (quote 2))")

(define-values (ordinary-binding-status ordinary-binding-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/ordinary-kernel-binding-audit"
             "[]"))
(unless (zero? ordinary-binding-status)
  (error 'check-expander-kernel-smoke
         "ordinary binding audit failed with status ~a\noutput:\n~a"
         ordinary-binding-status
         ordinary-binding-output))
(require-output ordinary-binding-output "probe:ordinary-kernel-binding-audit:after-require")
(require-output ordinary-binding-output "(#%datum #t)")
(for ([fragment (in-list '("(#%app #t)"
                           "(quote #t)"
                           "(if #t)"
                           "(lambda #t)"
                           "(let-values #t)"
                           "(+ #t)"))])
  (require-output ordinary-binding-output fragment))

(define-values (ordinary-binding-shapes-status ordinary-binding-shapes-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/ordinary-kernel-binding-shapes"
             "[]"))
(unless (zero? ordinary-binding-shapes-status)
  (error 'check-expander-kernel-smoke
         "ordinary binding shape probe failed with status ~a\noutput:\n~a"
         ordinary-binding-shapes-status
         ordinary-binding-shapes-output))
(require-output ordinary-binding-shapes-output "probe:ordinary-kernel-binding-shapes:after-require")
(for ([fragment (in-list '("(#%datum (module-binding (internal #%datum) (external #%datum) (core? #t) (runtime? #f)))"
                           "(#%app (module-binding (internal #%app) (external #%app) (core? #t) (runtime? #f)))"
                           "(quote (module-binding (internal quote) (external quote) (core? #t) (runtime? #f)))"
                           "(if (module-binding (internal if) (external if) (core? #t) (runtime? #f)))"
                           "(lambda (module-binding (internal lambda) (external lambda) (core? #t) (runtime? #f)))"
                           "(let-values (module-binding (internal let-values) (external let-values) (core? #t) (runtime? #f)))"
                           "(+ (module-binding (internal +) (external +) (core? #f) (runtime? #t)))"))])
  (require-output ordinary-binding-shapes-output fragment))

(define-values (compile-status compile-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/compile-kernel-datum"
             "[]"))
(unless (zero? compile-status)
  (error 'check-expander-kernel-smoke
         "compile kernel datum probe failed with status ~a\noutput:\n~a"
         compile-status
         compile-output))
(require-output compile-output "probe:compile-kernel-datum:before-compile")
(require-output compile-output "probe:compile-kernel-datum:after-compile")
(require-output compile-output "compile-kernel-datum:returned")

(for ([probe (in-list
              '("webify-probe-expand-self-evaluating/compile-kernel-quote"
                "webify-probe-expand-self-evaluating/compile-kernel-let-values"
                "webify-probe-expand-self-evaluating/compile-kernel-if"
                "webify-probe-expand-self-evaluating/compile-kernel-lambda"
                "webify-probe-expand-self-evaluating/compile-kernel-primitive-app"))])
  (define marker
    (string-replace
     (substring probe
                (string-length "webify-probe-expand-self-evaluating/"))
     "/" ":"))
  (define-values (status output) (run-probe wasm-path probe "[]"))
  (unless (zero? status)
    (error 'check-expander-kernel-smoke
           "compile matrix probe ~a failed with status ~a\noutput:\n~a"
           probe
           status
           output))
  (require-output output (format "probe:~a:after-compile" marker))
  (require-output output (format "~a:returned" marker)))

(for ([probe (in-list
              '("webify-probe-expand-self-evaluating/compile-ordinary-kernel-datum"
                "webify-probe-expand-self-evaluating/compile-ordinary-kernel-primitive-app"
                "webify-probe-expand-self-evaluating/compile-ordinary-kernel-if"
                "webify-probe-expand-self-evaluating/compile-ordinary-kernel-lambda"))])
  (define marker
    (string-replace
     (substring probe
                (string-length "webify-probe-expand-self-evaluating/"))
     "/" ":"))
  (define-values (status output) (run-probe wasm-path probe "[]"))
  (unless (zero? status)
    (error 'check-expander-kernel-smoke
           "ordinary compile matrix probe ~a failed with status ~a\noutput:\n~a"
           probe
           status
           output))
  (require-output output (format "probe:~a:after-compile" marker))
  (require-output output (format "~a:returned" marker)))

(check-ok-probe
 "webify-probe-expand-self-evaluating/compile-ordinary-kernel-summary"
 "[]"
 "probe:compile-ordinary-kernel-summary:after-compile"
 "object-name compiled-in-memory")

(define-values (compiled-fields-status compiled-fields-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/compiled-in-memory-fields"
             "[]"))
(unless (zero? compiled-fields-status)
  (error 'check-expander-kernel-smoke
         "compiled-in-memory field probe failed with status ~a\noutput:\n~a"
         compiled-fields-status
         compiled-fields-output))
(require-output compiled-fields-output "probe:compiled-in-memory-fields:after-compile")
(require-output compiled-fields-output "object-name linklet-directory")
(require-output compiled-fields-output "object-name namespace-scopes")

(define-values (compiled-directory-status compiled-directory-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/compiled-linklet-directory-hash"
             "[]"))
(unless (zero? compiled-directory-status)
  (error 'check-expander-kernel-smoke
         "compiled linklet-directory hash probe failed with status ~a\noutput:\n~a"
         compiled-directory-status
         compiled-directory-output))
(require-output compiled-directory-output "probe:compiled-linklet-directory-hash:after-compile")
(require-output compiled-directory-output "(hash-count 1)")
(require-output compiled-directory-output "(#f ((syntax? #f) (struct? #t) (procedure? #f) (object-name linklet-bundle)")
(require-output compiled-directory-output "(main-entry-payload ((hash? #t) (hash-count 3)")
(require-output compiled-directory-output "original-phase")
(require-output compiled-directory-output "max-phase")

(check-ok-probe
 "webify-probe-expand-self-evaluating/compiled-directory-adapter/catch"
 "[]"
 "probe:compiled-directory-adapter/catch:caught"
 "(adapter-failed (message hash->linklet-directory: contract violation")

(define-values (phase0-status phase0-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/compiled-phase0-payload-matrix"
             "[]"))
(unless (zero? phase0-status)
  (error 'check-expander-kernel-smoke
         "compiled phase-0 payload matrix probe failed with status ~a\noutput:\n~a"
         phase0-status
         phase0-output))
(require-output phase0-output "probe:compiled-phase0-payload-matrix:after")
(for ([fragment (in-list '("(datum 42)"
                           "(datum (+ 1 2))"
                           "(datum (lambda (x) x))"
                           "(datum (let-values (((x) 1)) x))"
                           "(bundle-payload ((hash? #t) (hash-count 3)"
                           "original-phase"
                           "max-phase"
                           "(phase-0 ((syntax? #f)"
                           "(bytes? #f)"
                           "(pair? #f)"
                           "(vector? #f)"
                           "(hash? #f)"))])
  (require-output phase0-output fragment))

(define-values (correlated-phase0-status correlated-phase0-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/correlated-phase0-payload-matrix"
             "[]"))
(unless (zero? correlated-phase0-status)
  (error 'check-expander-kernel-smoke
         "correlated phase-0 payload matrix probe failed with status ~a\noutput:\n~a"
         correlated-phase0-status
         correlated-phase0-output))
(require-output correlated-phase0-output "probe:correlated-phase0-payload-matrix:after")
(for ([fragment (in-list '("(datum 42)"
                           "(datum (+ 1 2))"
                           "(datum (lambda (x) x))"
                           "(datum (let-values (((x) 1)) x))"
                           "(target-machine #f)"
                           "(bundle-payload ((hash? #t) (hash-count 4)"
                           "original-phase"
                           "max-phase"
                           "(link ((syntax? #f) (struct? #t) (procedure? #f) (object-name correlated-linklet)"
                           "(phase-0 ((syntax? #f) (struct? #t) (procedure? #f) (object-name correlated-linklet)"
                           "(struct-vector-length 4)"
                           "(struct-vector-tag struct:correlated-linklet)"))])
  (require-output correlated-phase0-output fragment))

(define-values (correlated-linklet-datum-status correlated-linklet-datum-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/correlated-phase0-linklet-datum-matrix"
             "[]"))
(unless (zero? correlated-linklet-datum-status)
  (error 'check-expander-kernel-smoke
         "correlated phase-0 linklet datum matrix probe failed with status ~a\noutput:\n~a"
         correlated-linklet-datum-status
         correlated-linklet-datum-output))
(require-output correlated-linklet-datum-output
                "probe:correlated-phase0-linklet-datum-matrix:after")
(for ([fragment (in-list '("(linklet-datum (linklet ((.top-level-bind! .top-level-require!)"
                           "(.namespace .phase .self .inspector .bulk-binding-registry .set-transformer!)"
                           "(linklet-datum (linklet ((.top-level-bind! .top-level-require!) (.mpi-vector .syntax-literals) (.namespace .phase .self .inspector .bulk-binding-registry .set-transformer!)) () 42))"
                           "(linklet-datum (linklet ((.top-level-bind! .top-level-require!) (.mpi-vector .syntax-literals) (.namespace .phase .self .inspector .bulk-binding-registry .set-transformer!)) () (+ 1 2)))"
                           "(lambda (arg_1) arg_1)"
                           "(let-values (((loc_2) 1)) loc_2)"))])
  (require-output correlated-linklet-datum-output fragment))

(check-ok-probe
 "webify-probe-expand-self-evaluating/correlated-accessor-smoke"
 "[]"
 "probe:correlated-accessor-smoke:after"
 "(linklet-datum (linklet ((.top-level-bind! .top-level-require!)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/correlated-definition-linklet/catch"
 "[]"
 "probe:correlated-definition-linklet/catch:after"
 "(linklet-datum #f)")

(define-values (correlated-definition-payload-status correlated-definition-payload-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/correlated-definition-payload-details"
             "[]"))
(unless (zero? correlated-definition-payload-status)
  (error 'check-expander-kernel-smoke
         "correlated definition payload probe failed with status ~a\noutput:\n~a"
         correlated-definition-payload-status
         correlated-definition-payload-output))
(require-output correlated-definition-payload-output
                "probe:correlated-definition-payload-details:after")
(for ([fragment (in-list '("(datum (define-values (webify-top-x) 1))"
                           "(bundle-entries"
                           "(directory-keys (#f))"
                           "(linklet-summary ((linklet? #t) (import-group-count 3) (export-count 1)"
                           "(datum (begin (define-values (webify-top-x) 1) webify-top-x))"
                           "(bundle-object-name #f)"
                           "(bundle-entries #f)"))])
  (require-output correlated-definition-payload-output fragment))
(require-any-output correlated-definition-payload-output
                    '("(directory-keys (data"
                      "(directory-keys (1 0 data)"))

(check-ok-probe
 "webify-probe-expand-self-evaluating/eval-ordinary-kernel-primitive-app"
 "[]"
 "probe:eval-ordinary-kernel-primitive-app:after-eval"
 "wr-call-json-webify-probe-expand-self-evaluating/eval-ordinary-kernel-primitive-app-printed: 3")

(define-values (eval-status eval-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/eval-ordinary-kernel-primitive-app"
             "[]"))
(unless (zero? eval-status)
  (error 'check-expander-kernel-smoke
         "eval ordinary kernel primitive app probe failed with status ~a\noutput:\n~a"
         eval-status
         eval-output))
(require-output eval-output "probe:eval-compile:after-call")
(reject-output eval-output "failure-detail: #f: arity mismatch;")
(reject-output eval-output "literal data is not allowed")
(reject-output eval-output "exception-handler-key")

(check-ok-probe
 "webify-probe-expand-self-evaluating/correlated-tiny-module-compile/catch"
 "[]"
 "probe:correlated-tiny-module-compile/catch:after-compile"
 "object-name compiled-in-memory")

(check-ok-probe
 "webify-probe-expand-self-evaluating/module-name-resolver-audit"
 "[]"
 "probe:module-name-resolver-audit:unavailable"
 "(resolver-unavailable")

(check-ok-probe
 "webify-probe-expand-self-evaluating/tiny-module-require/catch"
 "[]"
 "probe:tiny-module-require/catch:after-require"
 "(require-ok (module-binding (internal webify-tiny-value.1) (external webify-tiny-value)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/tiny-module-value/catch"
 "[]"
 "probe:tiny-module-value/catch:after-require"
 "(value 42)")

(check-ok-probe
 "webify-probe-expand-self-evaluating/tiny-module-instance-audit/catch"
 "[]"
 "probe:tiny-module-instance-audit/catch:after-require"
 "(module-mapped-symbols")

(define-values (tiny-instance-status tiny-instance-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/tiny-module-instance-audit/catch"
             "[]"))
(unless (zero? tiny-instance-status)
  (error 'check-expander-kernel-smoke
         "tiny module instance audit failed with status ~a\noutput:\n~a"
         tiny-instance-status
         tiny-instance-output))
(for ([fragment (in-list '("module->namespace-alias?"
                           "module-declared?"
                           "internal-interned?"
                           "internal-eq-instance-key?"
                           "(module-instance-actual-key-value . (42"
                           "(current-namespace-external-value . (42"))])
  (require-output tiny-instance-output fragment))

(check-ok-probe
 "webify-probe-expand-self-evaluating/tiny-module-reflect/catch"
 "[]"
 "probe:tiny-module-reflect/catch:after-require"
 "(exports ((variables ((0 (webify-tiny-value () webify-tiny-value.1)))) (syntaxes ())))")

(check-ok-probe
 "webify-probe-expand-self-evaluating/tiny-module-private-helper/catch"
 "[]"
 "probe:tiny-module-private-helper/catch:after-require"
 "(private-binding-in-requirer (unbound))")

(define-values (tiny-private-status tiny-private-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/tiny-module-private-helper/catch"
             "[]"))
(unless (zero? tiny-private-status)
  (error 'check-expander-kernel-smoke
         "tiny private helper probe failed with status ~a\noutput:\n~a"
         tiny-private-status
         tiny-private-output))
(for ([fragment (in-list '("(public-value 5)"
                           "(private-value-in-requirer missing)"
                           "(public-instance-value 5)"
                           "(private-instance-value 5)"))])
  (require-output tiny-private-output fragment))

(define-values (tiny-two-module-status tiny-two-module-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/tiny-two-module-require/catch"
             "[]"))
(unless (zero? tiny-two-module-status)
  (error 'check-expander-kernel-smoke
         "tiny two-module require probe failed with status ~a\noutput:\n~a"
         tiny-two-module-status
         tiny-two-module-output))
(for ([fragment (in-list '("probe:tiny-two-module-require/catch:after-require"
                           "(provider-declared? #t)"
                           "(consumer-declared? #t)"
                           "(consumer-exports ((variables ((0 (webify-b-value () webify-b-value.1)))) (syntaxes ())))"
                           "(consumer-binding (module-binding (internal webify-b-value.1) (external webify-b-value)"
                           "(provider-binding-in-requirer (unbound))"
                           "(consumer-value 41)"
                           "(provider-value-in-requirer missing)"
                           "(consumer-instance-value 41)"))])
  (require-output tiny-two-module-output fragment))

(define-values (tiny-chain-status tiny-chain-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/tiny-three-module-chain/catch"
             "[]"))
(unless (zero? tiny-chain-status)
  (error 'check-expander-kernel-smoke
         "tiny three-module chain probe failed with status ~a\noutput:\n~a"
         tiny-chain-status
         tiny-chain-output))
(for ([fragment (in-list '("probe:tiny-three-module-chain/catch:after-require"
                           "(a-declared? #t)"
                           "(b-declared? #t)"
                           "(c-declared? #t)"
                           "(c-exports ((variables ((0 (webify-c-value () webify-c-value.1)))) (syntaxes ())))"
                           "(c-value 17)"
                           "(a-value-in-requirer missing)"
                           "(c-instance-value 17)"))])
  (require-output tiny-chain-output fragment))

(define-values (tiny-rename-status tiny-rename-output)
  (run-probe wasm-path
             "webify-probe-expand-self-evaluating/tiny-rename-reprovide/catch"
             "[]"))
(unless (zero? tiny-rename-status)
  (error 'check-expander-kernel-smoke
         "tiny rename reprovide probe failed with status ~a\noutput:\n~a"
         tiny-rename-status
         tiny-rename-output))
(for ([fragment (in-list '("probe:tiny-rename-reprovide/catch:after-require"
                           "(consumer-exports ((variables ((0 (webify-public-value"
                           "webify-internal-value.1"
                           "(public-binding (module-binding (internal webify-internal-value.1) (external webify-public-value)"
                           "(internal-binding-in-requirer (unbound))"
                           "(public-value 23)"
                           "(internal-value-in-requirer missing)"
                           "(public-instance-value missing)"))])
  (require-output tiny-rename-output fragment))

(check-ok-probe
 "webify-probe-expand-self-evaluating/tiny-module-dynamic-value/catch"
 "[]"
 "probe:tiny-module-dynamic-value/catch:after-require"
 "(require-ok ((binding (unbound)) (value 42)))")

(for ([probe+fragments (in-list
                        '(("webify-probe-expand-self-evaluating/kernel-require/catch"
                           "probe:kernel-require/catch:after-require"
                           "(require-ok"
                           "(#%datum (module-binding")
                          ("webify-probe-expand-self-evaluating/paramz-require/catch"
                           "probe:paramz-require/catch:after-require"
                           "(require-ok"
                           "(parameterization-key (module-binding")))])
  (match-define (list probe marker ok-fragment binding-fragment) probe+fragments)
  (define-values (status output) (run-probe wasm-path probe "[]"))
  (unless (zero? status)
    (error 'check-expander-kernel-smoke
           "small require probe ~a failed with status ~a\noutput:\n~a"
           probe
           status
           output))
  (require-output output marker)
  (require-output output ok-fragment)
  (require-output output binding-fragment))

(for ([probe+marker (in-list
                     '(("webify-probe-expand-self-evaluating/racket-base-require/catch"
                        "probe:racket-base-require/catch:caught")
                       ("webify-probe-expand-self-evaluating/racket-bool-require/catch"
                        "probe:racket-bool-require/catch:caught")
                       ("webify-probe-expand-self-evaluating/racket-base-via-kernel-then-base/catch"
                        "probe:racket-base-via-kernel/catch:caught")))])
  (match-define (list probe marker) probe+marker)
  (define-values (status output) (run-probe wasm-path probe "[]"))
  (unless (zero? status)
    (error 'check-expander-kernel-smoke
           "require frontier probe ~a failed with status ~a\noutput:\n~a"
           probe
           status
           output))
  (require-output output marker)
  (require-output output "(require-failed (message require: contract violation")
  (require-output output "expected: unknown module")
  (require-output output "object-name exn:fail:contract")
  (reject-output output "raise-arguments-error")
  (reject-output output "heap out of memory")
  (reject-output output "exception-handler-key"))

(check-ok-probe
 "webify-probe-expand-self-evaluating/linklet-boundary-audit"
 "[]"
 "probe:linklet-boundary-audit:after-build"
 "((compiled ((linklet? #t) (imports ((x))) (exports (y)))) (bundle? #t) (directory? #t) (instance? #t))")

(check-failing-probe
 "webify-probe-expand-self-evaluating/racket-base-require"
 "[]"
 '("probe:racket-base-require:before-require"
   "failure-category: bridge-call-failure"
   "failure-detail: require: contract violation")
 '("raise-arguments-error"
   "heap out of memory"
   "exception-handler-key"))

(check-failing-probe
 "webify-probe-expand-self-evaluating/full-expander-syntax/invoke-budget"
 "[20000]"
 '("probe:full-expander-syntax/invoke-budget:before-expand"
   "failure-detail: ?: literal data is not allowed;")
 '("procedure-arity-frontier"
   "failure-detail: exception-handler-key"
   "heap out of memory"))

(check-failing-probe
 "webify-probe-expand-self-evaluating/compile-expander-syntax/invoke-budget"
 "[20000]"
 '("probe:compile-expander-syntax/invoke-budget:before-compile"
   "failure-detail: ?: literal data is not allowed;")
 '("procedure-arity-frontier"
   "failure-detail: exception-handler-key"
   "heap out of memory"))

(printf "expander-kernel-smoke: kernel, ordinary #%kernel, and racket/base frontier probes ok\n")
