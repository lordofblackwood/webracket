#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/pretty
         racket/runtime-path
         racket/set
         racket/string
         racket/system
         racket/cmdline
         (only-in "../compiler.rkt"
                  current-console-bridge-top-binding-names
                  label-map->sexp
                  label-map-form-labels
                  primitives)
         (only-in "../parameters.rkt"
                  current-console-bridge?
                  current-runtime-primitive-report-path)
         "../wat-identifiers.rkt"
         "module-diagnostics.rkt"
         "test-module-support.rkt")

(define-runtime-path repo-root "..")

(define racket-root (simplify-path (build-path repo-root "../racket/racket")))
(define racket-bin  (build-path racket-root "bin/racket"))
(define bootstrap-run-rkt
  (build-path racket-root "src/expander/bootstrap-run.rkt"))
(define expander-main-rkt
  (build-path racket-root "src/expander/main.rkt"))

(define compile-timeout-seconds (make-parameter 300))
(define compile-memory-mb       (make-parameter #f))
(define compile-progress-interval (make-parameter #f))
(define compile-letrec-strategy (make-parameter #f))
(define compile-enable-cc-analysis? (make-parameter #f))
(define compile-enable-simplify?    (make-parameter #f))
(define compile-console-bridge?     (make-parameter #t))
(define compile-label-map-forms?    (make-parameter #f))
(define compile-label-map-form-labels (make-parameter '()))
(define write-racket-control-path (make-parameter #f))
(define write-racket-expand-control-path (make-parameter #f))
(define write-racket-expand-datum-path (make-parameter #f))
(define write-map-path                 (make-parameter #f))
(define write-primitive-report-path    (make-parameter #f))
(define write-wat-path                 (make-parameter #f))
(define write-wasm-path                (make-parameter #f))
(define validate-wat?                  (make-parameter #f))
(define skip-webracket-compile?   (make-parameter #f))

(struct compile-result (wat label-map) #:transparent)

(define special-forms
  '(begin
    begin0
    case-lambda
    define
    define-values
    if
    lambda
    let
    let*
    let-values
    let*-values
    letrec
    letrec-values
    quote
    quote-syntax
    set!
    with-continuation-mark))

(define base-bound-symbols
  (let ([ns (make-base-namespace)])
    (parameterize ([current-namespace ns])
      (namespace-require 'racket/base)
      (list->seteq (namespace-mapped-symbols)))))

(define primitive-symbols (list->seteq primitives))

;; console-bridge-export-alias? : symbol? -> boolean?
;;   Avoid redefining WebRacket primitives while keeping inspectable exports.
(define (console-bridge-export-alias? export)
  (not (set-member? primitive-symbols export)))

;; expander-probe-alias-id : symbol? -> symbol?
;;   Build a non-primitive top-level alias for an expander export.
(define (expander-probe-alias-id export)
  (string->symbol (format "webify-expander:~a" export)))

;; expander-probe-alias-definitions : (listof symbol?) -> (listof any/c)
;;   Expose selected expander exports whose public names collide with WebRacket primitives.
(define (expander-probe-alias-definitions exports)
  (define selected
    '(datum->syntax
      expand
      compile
      current-namespace
      datum->kernel-syntax
      maybe-syntax->datum
      make-namespace
      namespace-attach-module
      namespace-module-identifier
      namespace-require
      namespace-datum-introduce
      namespace-syntax-introduce
      syntax?
      syntax->datum))
  (define export-cells (first-slice-top-level-export-cell-ids exports))
  (for/list ([export (in-list selected)]
             #:when (hash-has-key? export-cells export))
    `(define ,(expander-probe-alias-id export)
       (module-variable-ref ,(hash-ref export-cells export)))))

;; datum-formals->symbols : any/c -> (listof symbol?)
;;   Collect bindings introduced by lambda-like formals.
(define (datum-formals->symbols formals)
  (cond
    [(symbol? formals) (list formals)]
    [(null? formals) '()]
    [(pair? formals)
     (append (datum-formals->symbols (car formals))
             (datum-formals->symbols (cdr formals)))]
    [else '()]))

;; datum-pattern-bindings : any/c -> (listof symbol?)
;;   Collect simple binding ids from generated binding clauses.
(define (datum-pattern-bindings ids)
  (cond
    [(symbol? ids) (list ids)]
    [(list? ids)   (filter symbol? ids)]
    [else          '()]))

;; generated-top-level-defines : any/c -> (listof symbol?)
;;   Collect top-level definitions emitted by the source-shaped adapter.
(define (generated-top-level-defines datum)
  (define defs '())
  (define (top! sym)
    (set! defs (cons sym defs)))
  (define (visit-top form)
    (match form
      [`(begin ,body ...)
       (for-each visit-top body)]
      [`(define ,id ,_rhs)
       #:when (symbol? id)
       (top! id)]
      [`(define (,id . ,_formals) ,_body ...)
       #:when (symbol? id)
       (top! id)]
      [`(define-values ,ids ,_rhs)
       (for-each top! (datum-pattern-bindings ids))]
      [_ (void)]))
  (visit-top datum)
  (remove-duplicates defs eq?))

;; generated-free-identifiers : any/c -> (listof symbol?)
;;   Conservatively collect free references that need control-file stubs.
(define (generated-free-identifiers datum)
  (define top-defs (list->seteq (generated-top-level-defines datum)))
  (define free '())
  (define (free! sym bound)
    (unless (or (set-member? bound sym)
                (set-member? top-defs sym)
                (memq sym special-forms))
      (set! free (cons sym free))))
  (define (visit expr bound)
    (cond
      [(symbol? expr) (free! expr bound)]
      [(pair? expr)
       (match expr
         [`(quote ,_) (void)]
         [`(quote-syntax ,_) (void)]
         [`(lambda ,formals ,body ...)
          (define bound* (set-union bound (list->seteq (datum-formals->symbols formals))))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(case-lambda [,formals ,body ...] ...)
          (for ([formals (in-list formals)]
                [body    (in-list body)])
            (define bound* (set-union bound (list->seteq (datum-formals->symbols formals))))
            (for-each (lambda (e) (visit e bound*)) body))]
         [`(define ,id ,rhs)
          (visit rhs bound)]
         [`(define (,id . ,formals) ,body ...)
          (define bound* (set-union bound (list->seteq (datum-formals->symbols formals))))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(define-values ,ids ,rhs)
          (visit rhs bound)]
         [`(set! ,id ,rhs)
          (when (symbol? id) (free! id bound))
          (visit rhs bound)]
         [`(if ,tst ,thn ,els)
          (for-each (lambda (e) (visit e bound)) (list tst thn els))]
         [`(begin ,body ...)
          (for-each (lambda (e) (visit e bound)) body)]
         [`(begin0 ,body ...)
          (for-each (lambda (e) (visit e bound)) body)]
         [`(let ,loop-name ,bindings ,body ...)
          #:when (symbol? loop-name)
          (define ids (for/list ([binding (in-list bindings)]
                                 #:when (and (pair? binding) (symbol? (car binding))))
                        (car binding)))
          (for ([binding (in-list bindings)]
                #:when (and (pair? binding) (pair? (cdr binding))))
            (visit (cadr binding) bound))
          (define bound* (set-union (set-add bound loop-name) (list->seteq ids)))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(let ,bindings ,body ...)
          (define ids (for/list ([binding (in-list bindings)]
                                 #:when (and (pair? binding) (symbol? (car binding))))
                        (car binding)))
          (for ([binding (in-list bindings)]
                #:when (and (pair? binding) (pair? (cdr binding))))
            (visit (cadr binding) bound))
          (define bound* (set-union bound (list->seteq ids)))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(let* ,bindings ,body ...)
          (define bound*
            (for/fold ([bound bound]) ([binding (in-list bindings)])
              (when (and (pair? binding) (pair? (cdr binding)))
                (visit (cadr binding) bound))
              (if (and (pair? binding) (symbol? (car binding)))
                  (set-add bound (car binding))
                  bound)))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(letrec ,bindings ,body ...)
          (define ids (for/list ([binding (in-list bindings)]
                                 #:when (and (pair? binding) (symbol? (car binding))))
                        (car binding)))
          (define bound* (set-union bound (list->seteq ids)))
          (for ([binding (in-list bindings)]
                #:when (and (pair? binding) (pair? (cdr binding))))
            (visit (cadr binding) bound*))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(let-values ,bindings ,body ...)
          (for ([binding (in-list bindings)]
                #:when (and (pair? binding) (pair? (cdr binding))))
            (visit (cadr binding) bound))
          (define ids (append* (for/list ([binding (in-list bindings)]
                                          #:when (pair? binding))
                                 (datum-pattern-bindings (car binding)))))
          (define bound* (set-union bound (list->seteq ids)))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(let*-values ,bindings ,body ...)
          (define bound*
            (for/fold ([bound bound]) ([binding (in-list bindings)])
              (when (and (pair? binding) (pair? (cdr binding)))
                (visit (cadr binding) bound))
              (if (pair? binding)
                  (set-union bound (list->seteq (datum-pattern-bindings (car binding))))
                  bound)))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(letrec-values ,bindings ,body ...)
          (define ids (append* (for/list ([binding (in-list bindings)]
                                          #:when (pair? binding))
                                 (datum-pattern-bindings (car binding)))))
          (define bound* (set-union bound (list->seteq ids)))
          (for ([binding (in-list bindings)]
                #:when (and (pair? binding) (pair? (cdr binding))))
            (visit (cadr binding) bound*))
          (for-each (lambda (e) (visit e bound*)) body)]
         [`(with-continuation-mark ,key ,val ,body)
          (for-each (lambda (e) (visit e bound)) (list key val body))]
         [_
          (for-each (lambda (e) (visit e bound)) expr)])]
      [(vector? expr)
       (for-each (lambda (e) (visit e bound)) (vector->list expr))]
      [else (void)]))
  (visit datum (seteq))
  (sort (remove-duplicates free eq?) symbol<?))

;; add-console-bridge-probe-helpers : syntax? (listof symbol?) -> syntax?
;;   Add probe-only top-level helpers that compose retained primitives.
(define (add-console-bridge-probe-helpers stx exports)
  (datum->syntax
   #f
   `(begin
      ,(syntax->datum stx)
      ,@(expander-probe-alias-definitions exports)
      (define (webify-probe-read-string text)
        (read (open-input-string text)))
      (define (webify-probe-read-syntax-string source text)
        (read-syntax source (open-input-string text)))
      (define (webify-probe-read-syntax-phase-string source text)
        (js-log "probe:open-input-string:start")
        (let ([in (open-input-string text)])
          (js-log "probe:read-syntax:start")
          (let ([stx (read-syntax source in)])
            (js-log "probe:read-syntax:done")
            "read-syntax:returned")))
      (define (webify-probe-read-syntax-class-string source text)
        (js-log "probe:class:open-input-string:start")
        (let ([in (open-input-string text)])
          (js-log "probe:class:read-syntax:start")
          (let ([stx (read-syntax source in)])
            (js-log "probe:class:read-syntax:done")
            (if (syntax? stx)
                (begin
                  (js-log "probe:class:syntax?:true")
                  "syntax")
                (begin
                  (js-log "probe:class:syntax?:false")
                  "not-syntax")))))
      (define (webify-probe-read-syntax-inspect-string source text)
        (js-log "probe:inspect:open-input-string:start")
        (let ([in (open-input-string text)])
          (js-log "probe:inspect:read-syntax:start")
          (let ([stx (read-syntax source in)])
            (js-log "probe:inspect:read-syntax:done")
            (list (list 'eof-object? (eof-object? stx))
                  (list 'syntax? (syntax? stx))
                  (list 'correlated? (correlated? stx))
                  (list 'struct? (struct? stx))
                  (list 'vector? (vector? stx))
                  (list 'procedure? (procedure? stx))))))
      (define (webify-probe-read-syntax-safe-datum-string source text)
        (js-log "probe:safe-datum:open-input-string:start")
        (let ([in (open-input-string text)])
          (js-log "probe:safe-datum:read-syntax:start")
          (let ([stx (read-syntax source in)])
            (js-log "probe:safe-datum:read-syntax:done")
            (cond
              [(eof-object? stx)
               (list 'eof)]
              [(syntax? stx)
               (list 'datum (syntax->datum stx))]
              [else
               (list 'foreign-syntax
                     (list 'syntax? (syntax? stx))
                     (list 'correlated? (correlated? stx))
                     (list 'struct? (struct? stx))
                     (list 'vector? (vector? stx))
                     (list 'procedure? (procedure? stx)))]))))
      (define (webify-probe-read-syntax-expander-datum-string source text)
        (js-log "probe:expander-datum:open-input-string:start")
        (let ([in (open-input-string text)])
          (js-log "probe:expander-datum:read-syntax:start")
          (let ([stx (read-syntax source in)])
            (js-log "probe:expander-datum:read-syntax:done")
            (let ([datum (maybe-syntax->datum stx)])
              (js-log "probe:expander-datum:maybe-syntax->datum:done")
              (list 'expander-datum datum)))))
      (define (webify-probe-read-syntax-expander-summary-string source text)
        (js-log "probe:expander-summary:open-input-string:start")
        (let ([in (open-input-string text)])
          (js-log "probe:expander-summary:read-syntax:start")
          (let ([stx (read-syntax source in)])
            (js-log "probe:expander-summary:read-syntax:done")
            (let* ([vec (struct->vector stx '...)]
                   [loc (vector-ref vec 5)]
                   [debug-info (syntax-debug-info stx 0 #f)]
                   [context (hash-ref debug-info 'context null)])
              (list (list 'datum (maybe-syntax->datum stx))
                    (list 'source (and (srcloc? loc) (srcloc-source loc)))
                    (list 'line (and (srcloc? loc) (srcloc-line loc)))
                    (list 'column (and (srcloc? loc) (srcloc-column loc)))
                    (list 'position (and (srcloc? loc) (srcloc-position loc)))
                    (list 'span (and (srcloc? loc) (srcloc-span loc)))
                    (list 'debug-known-keys '(context))
                    (list 'debug-context-count (length context)))))))
      (define (webify-probe-read-syntax-procedure-shape-string source text)
        (js-log "probe:procedure-shape:open-input-string:start")
        (let ([in (open-input-string text)])
          (js-log "probe:procedure-shape:read-syntax:start")
          (let ([stx (read-syntax source in)])
            (js-log "probe:procedure-shape:read-syntax:done")
            (let ([vec (struct->vector stx '...)])
              (list (list 'object-name (object-name stx))
                    (list 'procedure? (procedure? stx))
                    (list 'procedure-arity (procedure-arity stx))
                    (list 'struct-vector-length (vector-length vec))
                    (list 'struct-vector-tag (vector-ref vec 0)))))))
      (define (webify-probe-read-syntax-lang-parameterized-string source text)
        (js-log "probe:lang-param:open-input-string:start")
        (let ([paramz (extend-parameterization
                       (current-parameterization)
                       read-accept-lang
                       #t)])
          (call-with-parameterization
           paramz
           (lambda ()
             (let ([in (open-input-string text)])
               (js-log "probe:lang-param:read-syntax:start")
               (let ([stx (read-syntax source in)])
                 (js-log "probe:lang-param:read-syntax:done")
                 (list 'expander-datum (maybe-syntax->datum stx))))))))
      (define (webify-probe-namespace-lock-sanity-string n)
        (js-log "probe:namespace-lock-sanity:start")
        (let loop ([i n])
          (if (= i 0)
              (begin
                (js-log "probe:namespace-lock-sanity:done")
                "namespace-lock-sanity:ok")
              (let ([sema (make-semaphore)])
                (dynamic-wind
                  void
                  (lambda ()
                    (let ([peek (semaphore-peek-evt sema)])
                      (and (not (sync/timeout 0 peek))
                           (begin
                             (semaphore-post sema)
                             (sync/timeout 0 peek)))))
                  (lambda ()
                    (semaphore-post sema)))
                (loop (- i 1))))))
      (define (webify-probe-eval-checkpoint datum)
        (js-log "probe:eval:entered")
        (js-log "probe:eval:before-call")
        (let ([v (eval datum)])
          (js-log "probe:eval:after-call")
          v))
      (define (webify-probe-eval-checkpoint/compile datum)
        (js-log "probe:eval-compile:entered")
        (js-log (if (syntax? datum)
                    "probe:eval-compile:datum-syntax?:true"
                    "probe:eval-compile:datum-syntax?:false"))
        (js-log "probe:eval-compile:before-call")
        (let ([v (eval datum
                       (current-namespace)
                       (lambda (s ns)
                         (js-log "probe:eval-compile:compile-entered")
                         (js-log (if (syntax? s)
                                     "probe:eval-compile:compile-syntax?:true"
                                     "probe:eval-compile:compile-syntax?:false"))
                         (js-log "probe:eval-compile:before-compile")
                         (let ([c (compile s ns #f)])
                           (js-log "probe:eval-compile:after-compile")
                           c)))])
          (js-log "probe:eval-compile:after-call")
          v))
      (define (webify-probe-eval-self-evaluating)
        (webify-probe-eval-checkpoint 42))
      (define (webify-probe-eval-self-evaluating/compile)
        (webify-probe-eval-checkpoint/compile 42))
      (define (webify-probe-eval-self-evaluating-introduced/compile)
        (webify-probe-eval-checkpoint/compile
         (namespace-syntax-introduce
          (datum->syntax #f 42)
          (current-namespace))))
      (define (webify-probe-eval-self-evaluating-expander-syntax/compile)
        (webify-probe-eval-checkpoint/compile
         (webify-expander:datum->syntax #f 42)))
      (define (webify-probe-compile-self-evaluating/expand)
        (js-log "probe:compile-expand:entered")
        (js-log "probe:compile-expand:before-compile")
        (let ([c (compile 42
                          (current-namespace)
                          #f
                          (lambda (s ns observable? to-parsed? serializable? to-correlated-linklet?)
                            (js-log "probe:compile-expand:expand-entered")
                            (js-log (if (syntax? s)
                                        "probe:compile-expand:expand-syntax?:true"
                                        "probe:compile-expand:expand-syntax?:false"))
                            (js-log "probe:compile-expand:before-expand")
                            (let ([expanded (expand s ns observable? to-parsed? serializable? to-correlated-linklet?)])
                              (js-log "probe:compile-expand:after-expand")
                              expanded)))])
          (js-log "probe:compile-expand:after-compile")
          (if c "compile:returned" "compile:false")))
      (define (webify-probe-expand-self-evaluating/datum->syntax)
        (js-log "probe:expand-step:datum->syntax:before")
        (let ([stx (datum->syntax #f 42)])
          (js-log "probe:expand-step:datum->syntax:after")
          (if (syntax? stx)
              "datum->syntax:syntax"
              "datum->syntax:not-syntax")))
      (define (webify-probe-expand-self-evaluating/namespace-introduce)
        (js-log "probe:expand-step:introduce:before-datum->syntax")
        (let ([stx (datum->syntax #f 42)])
          (js-log "probe:expand-step:introduce:before-introduce")
          (let ([introduced (namespace-syntax-introduce stx (current-namespace))])
            (js-log "probe:expand-step:introduce:after-introduce")
            (if (syntax? introduced)
                "introduce:syntax"
                "introduce:not-syntax"))))
      (define (webify-probe-expand-self-evaluating/namespace-args)
        (js-log "probe:expand-step:namespace-args:before")
        (let ([stx (datum->syntax #f 42)]
              [ns (current-namespace)])
          (js-log "probe:expand-step:namespace-args:after-values")
          (list (list 'syntax? (syntax? stx))
                (list 'stx-struct? (struct? stx))
                (list 'stx-procedure? (procedure? stx))
                (list 'stx-object-name (object-name stx))
                (list 'namespace? (namespace? ns))
                (list 'ns-struct? (struct? ns))
                (list 'ns-procedure? (procedure? ns))
                (list 'ns-object-name (object-name ns)))))
      (define (webify-probe-value-shape v)
        (let ([vec (and (struct? v) (struct->vector v '...))])
          (list (list 'syntax? (syntax? v))
                (list 'struct? (struct? v))
                (list 'procedure? (procedure? v))
                (list 'object-name (object-name v))
                (list 'struct-vector-length (and vec (vector-length vec)))
                (list 'struct-vector-tag (and vec (vector-ref vec 0)))
                (list 'maybe-syntax->datum
                      (let ([datum (maybe-syntax->datum v)])
                        (cond
                          [(eq? datum v) 'self]
                          [(syntax? datum) 'syntax]
                          [else datum]))))))
      (define (webify-probe-expander-value-shape v)
        (let ([vec (and (struct? v) (struct->vector v '...))])
          (list (list 'expander-syntax? (webify-expander:syntax? v))
                (list 'runtime-syntax? (syntax? v))
                (list 'struct? (struct? v))
                (list 'procedure? (procedure? v))
                (list 'object-name (object-name v))
                (list 'struct-vector-length (and vec (vector-length vec)))
                (list 'struct-vector-tag (and vec (vector-ref vec 0)))
                (list 'expander-maybe-syntax->datum
                      (let ([datum (webify-expander:maybe-syntax->datum v)])
                        (cond
                          [(eq? datum v) 'self]
                          [(webify-expander:syntax? datum) 'expander-syntax]
                          [(syntax? datum) 'runtime-syntax]
                          [else datum]))))))
      (define (webify-probe-expand-self-evaluating/syntax-binding-shape)
        (list (list 'syntax?-object-name (object-name syntax?))
              (list 'syntax?-procedure? (procedure? syntax?))
              (list 'syntax?-arity (procedure-arity syntax?))
              (list 'datum->syntax-object-name (object-name datum->syntax))
              (list 'maybe-syntax->datum-object-name (object-name maybe-syntax->datum))
              (list 'expander-syntax?-object-name (object-name webify-expander:syntax?))
              (list 'expander-datum->syntax-object-name
                    (object-name webify-expander:datum->syntax))
              (list 'expander-maybe-syntax->datum-object-name
                    (object-name webify-expander:maybe-syntax->datum))))
      (define (webify-probe-expand-self-evaluating/syntax-shape-comparison)
        (js-log "probe:expand-step:syntax-shape-comparison:before")
        (let* ([raw (datum->syntax #f 42)]
               [expander-raw (webify-expander:datum->syntax #f 42)]
               [introduced (namespace-datum-introduce 42)])
          (js-log "probe:expand-step:syntax-shape-comparison:after-values")
          (list (list 'raw (webify-probe-value-shape raw))
                (list 'raw/expander (webify-probe-expander-value-shape raw))
                (list 'expander-raw
                      (webify-probe-expander-value-shape expander-raw))
                (list 'introduced
                      (webify-probe-expander-value-shape introduced)))))
      (define (webify-probe-expand-self-evaluating/expander-namespace-introduce)
        (js-log "probe:expand-step:expander-introduce:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:expand-step:expander-introduce:before-introduce")
          (let ([introduced (webify-expander:namespace-syntax-introduce
                             stx
                             (current-namespace))])
            (js-log "probe:expand-step:expander-introduce:after-introduce")
            (webify-probe-expander-value-shape introduced))))
      (define (webify-probe-expand-self-evaluating/full-expander-syntax)
        (js-log "probe:expand-step:full-expander-syntax:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:expand-step:full-expander-syntax:before-expand")
          (let ([v (webify-expander:expand stx)])
            (js-log "probe:expand-step:full-expander-syntax:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/full-expander-syntax/invoke-budget budget)
        (js-log "probe:full-expander-syntax/invoke-budget:before-budget")
        (webracket-debug-invoke-budget! budget)
        (js-log "probe:full-expander-syntax/invoke-budget:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:full-expander-syntax/invoke-budget:before-expand")
          (let ([v (webify-expander:expand stx)])
            (js-log "probe:full-expander-syntax/invoke-budget:after-expand")
            (list (list 'result (webify-probe-expander-value-shape v))
                  (list 'counters (webracket-debug-allocation-counters))))))
      (define (webify-probe-expand-self-evaluating/full-runtime-syntax)
        (js-log "probe:expand-step:full-runtime-syntax:before-datum->syntax")
        (let ([stx (datum->syntax #f 42)])
          (js-log "probe:expand-step:full-runtime-syntax:before-expand")
          (let ([v (webify-expander:expand stx)])
            (js-log "probe:expand-step:full-runtime-syntax:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/compile-expander-syntax)
        (js-log "probe:compile-expander-syntax:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:compile-expander-syntax:before-compile")
          (let ([c (webify-expander:compile stx)])
            (js-log "probe:compile-expander-syntax:after-compile")
            (if c "compile-expander-syntax:returned" "compile-expander-syntax:false"))))
      (define (webify-probe-expand-self-evaluating/compile-expander-syntax/invoke-budget budget)
        (js-log "probe:compile-expander-syntax/invoke-budget:before-budget")
        (webracket-debug-invoke-budget! budget)
        (js-log "probe:compile-expander-syntax/invoke-budget:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:compile-expander-syntax/invoke-budget:before-compile")
          (let ([c (webify-expander:compile stx)])
            (js-log "probe:compile-expander-syntax/invoke-budget:after-compile")
            (list (list 'result
                        (if c
                            "compile-expander-syntax/invoke-budget:returned"
                            "compile-expander-syntax/invoke-budget:false"))
                  (list 'counters (webracket-debug-allocation-counters))))))
      (define (webify-probe-expand-self-evaluating/pre-expand-state)
        (js-log "probe:pre-expand-state:before")
        (let* ([ns (current-namespace)]
               [raw (webify-expander:datum->syntax #f 42)]
               [introduced (webify-expander:namespace-syntax-introduce raw ns)]
               [module-id (webify-expander:namespace-module-identifier ns)])
          (js-log "probe:pre-expand-state:after")
          (list (list 'namespace (webify-probe-value-shape ns))
                (list 'raw (webify-probe-expander-value-shape raw))
                (list 'introduced (webify-probe-expander-value-shape introduced))
                (list 'module-id (webify-probe-expander-value-shape module-id)))))
      (define (webify-probe-expand-self-evaluating/direct-expand-default)
        (js-log "probe:direct-expand-default:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:direct-expand-default:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-default:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-observable)
        (js-log "probe:direct-expand-observable:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:direct-expand-observable:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #t #f #f #f)])
            (js-log "probe:direct-expand-observable:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-to-parsed)
        (js-log "probe:direct-expand-to-parsed:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:direct-expand-to-parsed:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #t #f #f)])
            (js-log "probe:direct-expand-to-parsed:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-quote)
        (js-log "probe:direct-expand-quote:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f '(quote 42))])
          (js-log "probe:direct-expand-quote:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-quote:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-datum)
        (js-log "probe:direct-expand-kernel-datum:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax 42)])
          (js-log "probe:direct-expand-kernel-datum:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-datum:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-quote)
        (js-log "probe:direct-expand-kernel-quote:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax '(quote 42))])
          (js-log "probe:direct-expand-kernel-quote:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-quote:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-let)
        (js-log "probe:direct-expand-kernel-let:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax '(let ([x 1]) x))])
          (js-log "probe:direct-expand-kernel-let:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-let:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-let-values)
        (js-log "probe:direct-expand-kernel-let-values:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax
                    '(let-values ([(x) (quote 1)]) x))])
          (js-log "probe:direct-expand-kernel-let-values:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-let-values:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-if)
        (js-log "probe:direct-expand-kernel-if:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax
                    '(if #t (quote yes) (quote no)))])
          (js-log "probe:direct-expand-kernel-if:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-if:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-lambda)
        (js-log "probe:direct-expand-kernel-lambda:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax '(lambda (x) x))])
          (js-log "probe:direct-expand-kernel-lambda:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-lambda:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-primitive-app)
        (js-log "probe:direct-expand-kernel-primitive-app:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax '(+ 1 2))])
          (js-log "probe:direct-expand-kernel-primitive-app:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-primitive-app:after-expand")
            (webify-probe-expander-value-shape v))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-datum/invoke-budget budget)
        (js-log "probe:direct-expand-kernel-datum/invoke-budget:before-budget")
        (webracket-debug-invoke-budget! budget)
        (js-log "probe:direct-expand-kernel-datum/invoke-budget:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax 42)])
          (js-log "probe:direct-expand-kernel-datum/invoke-budget:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-datum/invoke-budget:after-expand")
            (list (list 'result (webify-probe-expander-value-shape v))
                  (list 'counters (webracket-debug-allocation-counters))))))
      (define (webify-probe-expand-self-evaluating/direct-expand-kernel-quote/invoke-budget budget)
        (js-log "probe:direct-expand-kernel-quote/invoke-budget:before-budget")
        (webracket-debug-invoke-budget! budget)
        (js-log "probe:direct-expand-kernel-quote/invoke-budget:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax '(quote 42))])
          (js-log "probe:direct-expand-kernel-quote/invoke-budget:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-kernel-quote/invoke-budget:after-expand")
            (list (list 'result (webify-probe-expander-value-shape v))
                  (list 'counters (webracket-debug-allocation-counters))))))
      (define (webify-probe-expand-self-evaluating/direct-expand-budget budget)
        (js-log "probe:direct-expand-budget:before-budget")
        (webracket-debug-allocation-budget! budget)
        (js-log "probe:direct-expand-budget:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:direct-expand-budget:before-expand")
          (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
            (js-log "probe:direct-expand-budget:after-expand")
            (list (list 'result (webify-probe-expander-value-shape v))
                  (list 'counters (webracket-debug-allocation-counters))))))
      (define (webify-probe-expand-self-evaluating/direct-expand-no-source-location)
        (js-log "probe:direct-expand-no-source-location:before-parameter")
        (error-print-source-location #f)
        (js-log "probe:direct-expand-no-source-location:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (with-handlers ([exn:fail?
                           (lambda (exn)
                             (js-log "probe:direct-expand-no-source-location:caught")
                             (list (list 'raised? #t)
                                   (list 'message (exn-message exn))))])
            (js-log "probe:direct-expand-no-source-location:before-expand")
            (let ([v (webify-expander:expand stx (current-namespace) #f #f #f #f)])
              (js-log "probe:direct-expand-no-source-location:after-expand")
              (list (list 'raised? #f)
                    (list 'result (webify-probe-expander-value-shape v)))))))
      (define (webify-probe-expand-self-evaluating/pre-expand-budget budget)
        (js-log "probe:pre-expand-budget:before-budget")
        (webracket-debug-allocation-budget! budget)
        (js-log "probe:pre-expand-budget:before")
        (let* ([ns (current-namespace)]
               [raw (webify-expander:datum->syntax #f 42)]
               [introduced (webify-expander:namespace-syntax-introduce raw ns)]
               [module-id (webify-expander:namespace-module-identifier ns)])
          (js-log "probe:pre-expand-budget:after")
          (list (list 'namespace (webify-probe-value-shape ns))
                (list 'raw (webify-probe-expander-value-shape raw))
                (list 'introduced (webify-probe-expander-value-shape introduced))
                (list 'module-id (webify-probe-expander-value-shape module-id))
                (list 'counters (webracket-debug-allocation-counters)))))
      (define (webify-probe-expand-self-evaluating/compile-expander-syntax/nonserializable)
        (js-log "probe:compile-expander-syntax/nonserializable:before-datum->syntax")
        (let ([stx (webify-expander:datum->syntax #f 42)])
          (js-log "probe:compile-expander-syntax/nonserializable:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-expander-syntax/nonserializable:after-compile")
            (if c
                "compile-expander-syntax/nonserializable:returned"
                "compile-expander-syntax/nonserializable:false"))))
      (define (webify-probe-expand-self-evaluating/compile-kernel-datum)
        (js-log "probe:compile-kernel-datum:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax 42)])
          (js-log "probe:compile-kernel-datum:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-kernel-datum:after-compile")
            (if c "compile-kernel-datum:returned" "compile-kernel-datum:false"))))
      (define (webify-probe-expand-self-evaluating/compile-kernel-quote)
        (js-log "probe:compile-kernel-quote:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax '(quote 42))])
          (js-log "probe:compile-kernel-quote:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-kernel-quote:after-compile")
            (if c "compile-kernel-quote:returned" "compile-kernel-quote:false"))))
      (define (webify-probe-expand-self-evaluating/compile-kernel-let-values)
        (js-log "probe:compile-kernel-let-values:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax
                    '(let-values ([(x) 1]) x))])
          (js-log "probe:compile-kernel-let-values:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-kernel-let-values:after-compile")
            (if c "compile-kernel-let-values:returned" "compile-kernel-let-values:false"))))
      (define (webify-probe-expand-self-evaluating/compile-kernel-if)
        (js-log "probe:compile-kernel-if:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax
                    '(if #t 1 2))])
          (js-log "probe:compile-kernel-if:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-kernel-if:after-compile")
            (if c "compile-kernel-if:returned" "compile-kernel-if:false"))))
      (define (webify-probe-expand-self-evaluating/compile-kernel-lambda)
        (js-log "probe:compile-kernel-lambda:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax
                    '(lambda (x) x))])
          (js-log "probe:compile-kernel-lambda:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-kernel-lambda:after-compile")
            (if c "compile-kernel-lambda:returned" "compile-kernel-lambda:false"))))
      (define (webify-probe-expand-self-evaluating/compile-kernel-primitive-app)
        (js-log "probe:compile-kernel-primitive-app:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax
                    '(+ 1 2))])
          (js-log "probe:compile-kernel-primitive-app:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-kernel-primitive-app:after-compile")
            (if c "compile-kernel-primitive-app:returned" "compile-kernel-primitive-app:false"))))
      (define (webify-probe-expand-self-evaluating/compile-kernel-datum/invoke-budget budget)
        (js-log "probe:compile-kernel-datum/invoke-budget:before-budget")
        (webracket-debug-invoke-budget! budget)
        (js-log "probe:compile-kernel-datum/invoke-budget:before-kernel-syntax")
        (let ([stx (webify-expander:datum->kernel-syntax 42)])
          (js-log "probe:compile-kernel-datum/invoke-budget:before-compile")
          (let ([c (webify-expander:compile stx (current-namespace) #f webify-expander:expand)])
            (js-log "probe:compile-kernel-datum/invoke-budget:after-compile")
            (if c
                "compile-kernel-datum/invoke-budget:returned"
                "compile-kernel-datum/invoke-budget:false"))))
      (define (webify-probe-expand-self-evaluating/wrap-counts)
        (js-log "probe:wrap-counts:before")
        (let* ([runtime-raw (datum->syntax #f 42)]
               [expander-raw (webify-expander:datum->syntax #f 42)]
               [introduced (webify-expander:namespace-syntax-introduce
                            expander-raw
                            (current-namespace))]
               [datum-introduced (webify-expander:namespace-datum-introduce 42)])
          (js-log "probe:wrap-counts:after")
          (list (list 'runtime-raw (webify-probe-value-shape runtime-raw))
                (list 'expander-raw (webify-probe-expander-value-shape expander-raw))
                (list 'introduced (webify-probe-expander-value-shape introduced))
                (list 'datum-introduced
                      (webify-probe-expander-value-shape datum-introduced)))))
      (define (webify-probe-expand-self-evaluating/namespace-introduce-shape)
        (js-log "probe:expand-step:introduce-shape:before-datum->syntax")
        (let ([stx (datum->syntax #f 42)]
              [ns (current-namespace)])
          (js-log "probe:expand-step:introduce-shape:before-introduce")
          (with-handlers ([exn:fail?
                           (lambda (exn)
                             (list (list 'raised? #t)
                                   (list 'message (exn-message exn))
                                   (list 'stx-shape (webify-probe-value-shape stx))
                                   (list 'ns-shape (webify-probe-value-shape ns))))])
            (let ([introduced (namespace-syntax-introduce stx ns)])
              (js-log "probe:expand-step:introduce-shape:after-introduce")
              (list (list 'raised? #f)
                    (list 'introduced-shape
                          (webify-probe-value-shape introduced)))))))
      (define (webify-probe-expand-self-evaluating/namespace-introduce-no-ns)
        (js-log "probe:expand-step:introduce-no-ns:before-datum->syntax")
        (let ([stx (datum->syntax #f 42)])
          (js-log "probe:expand-step:introduce-no-ns:before-introduce")
          (let ([introduced (namespace-syntax-introduce stx)])
            (js-log "probe:expand-step:introduce-no-ns:after-introduce")
            (if (syntax? introduced)
                "introduce-no-ns:syntax"
                "introduce-no-ns:not-syntax"))))
      (define (webify-probe-expand-self-evaluating/namespace-datum-introduce)
        (js-log "probe:expand-step:datum-introduce:before")
        (let ([introduced (namespace-datum-introduce 42)])
          (js-log "probe:expand-step:datum-introduce:after")
          (if (syntax? introduced)
              "datum-introduce:syntax"
              "datum-introduce:not-syntax")))
      (define (webify-probe-expand-self-evaluating/namespace-datum-introduce-shape)
        (js-log "probe:expand-step:datum-introduce-shape:before")
        (with-handlers ([exn:fail?
                         (lambda (exn)
                           (list (list 'raised? #t)
                                 (list 'message (exn-message exn))))])
          (let ([introduced (namespace-datum-introduce 42)])
            (js-log "probe:expand-step:datum-introduce-shape:after")
            (list (list 'raised? #f)
                  (list 'introduced-shape
                        (webify-probe-value-shape introduced))))))
      (define (webify-probe-expand-self-evaluating/expand-syntax)
        (js-log "probe:expand-step:expand-syntax:before-datum->syntax")
        (let ([stx (datum->syntax #f 42)])
          (js-log "probe:expand-step:expand-syntax:before-expand")
          (let ([v (expand stx)])
            (js-log "probe:expand-step:expand-syntax:after-expand")
            (if (syntax? v)
                "expand-syntax:syntax"
                "expand-syntax:not-syntax"))))
      (define (webify-probe-expand-self-evaluating/expand-once)
        (js-log "probe:expand-step:expand-once:before")
        (let ([v (expand-once 42)])
          (js-log "probe:expand-step:expand-once:after")
          (if (syntax? v)
              "expand-once:syntax"
              "expand-once:not-syntax")))
      (define (webify-probe-expand-self-evaluating/top-form)
        (js-log "probe:expand-step:top-form:before")
        (let ([v (expand-to-top-form 42)])
          (js-log "probe:expand-step:top-form:after")
          (if (syntax? v)
              "top-form:syntax"
              "top-form:not-syntax")))
      (define (webify-probe-expand-self-evaluating/full)
        (js-log "probe:expand-step:full:before")
        (let ([v (expand 42)])
          (js-log "probe:expand-step:full:after")
          (if (syntax? v)
              "expand:syntax"
              "expand:not-syntax")))
      (define (webify-probe-eval-quoted-symbol)
        (webify-probe-eval-checkpoint '(quote a)))
      (define (webify-probe-eval-primitive-app)
        (webify-probe-eval-checkpoint '(+ 1 2)))
      (define (webify-probe-eval-local-let)
        (webify-probe-eval-checkpoint '(let ([x 1]) x)))
      (define (webify-probe-read-syntax-datum-string source text)
        (syntax->datum (read-syntax source (open-input-string text))))
      (define (webify-probe-read-syntax-summary-string source text)
        (let ([stx (read-syntax source (open-input-string text))])
          (list (syntax->datum stx)
                (syntax-source stx)
                (syntax-line stx)
                (syntax-column stx)
                (syntax-position stx)
                (syntax-span stx))))
      (define (webify-probe-parameterization-pressure-string n)
        (let ([original (error-print-width)])
          (let ([paramz (extend-parameterization
                         (current-parameterization)
                         error-print-width
                         original)])
            (call-with-parameterization
             paramz
             (lambda ()
               (let loop ([i n])
                 (if (= i 0)
                     (if (= (error-print-width) original)
                         "parameterization-pressure:ok"
                         "parameterization-pressure:wrong-value")
                     (begin
                       (error-print-width 80)
                       (error-print-width original)
                       (loop (- i 1)))))))))))))

;; write-racket-control! : path-string? any/c -> void?
;;   Write a normal Racket module that controls for ordinary expansion cost.
(define (write-racket-control! path datum)
  (define stubs
    (filter (lambda (sym)
              (not (set-member? base-bound-symbols sym)))
            (generated-free-identifiers datum)))
  (call-with-output-file path
    (lambda (out)
      (fprintf out "#lang racket/base\n\n")
      (fprintf out "(require (file ~s))\n\n"
               (path->string
                (simplify-path
                 (path->complete-path "webify/module-variable.rkt" repo-root))))
      (fprintf out "(define (webify-control-stub . _args) (void))\n")
      (for ([sym (in-list stubs)])
        (fprintf out "(define ~s webify-control-stub)\n" sym))
      (newline out)
      (write datum out)
      (newline out))
    #:exists 'truncate/replace)
  (printf "racket-control-path: ~a\n" path)
  (printf "racket-control-stubs: ~a\n" (length stubs)))

;; write-racket-expand-control! : path-string? path-string? any/c -> void?
;;   Write a normal Racket top-level expansion control script and datum file.
(define (write-racket-expand-control! script-path datum-path datum)
  (define stubs
    (filter (lambda (sym)
              (not (set-member? base-bound-symbols sym)))
            (generated-free-identifiers datum)))
  (call-with-output-file datum-path
    (lambda (out)
      (write datum out)
      (newline out))
    #:exists 'truncate/replace)
  (call-with-output-file script-path
    (lambda (out)
      (fprintf out "#lang racket/base\n\n")
      (fprintf out "(require racket/file\n")
      (fprintf out "         syntax/toplevel)\n\n")
      (fprintf out "(define datum-path ~s)\n"
               (path->string (simplify-path (path->complete-path datum-path))))
      (fprintf out "(define module-variable-path ~s)\n\n"
               (path->string
                (simplify-path
                 (path->complete-path "webify/module-variable.rkt" repo-root))))
      (fprintf out "(define stub-names '~s)\n\n" stubs)
      (fprintf out "(define (timed label thunk)\n")
      (fprintf out "  (define start (current-inexact-milliseconds))\n")
      (fprintf out "  (with-handlers ([exn:fail?\n")
      (fprintf out "                   (lambda (exn)\n")
      (display "                     (printf \"~a-failure-message:\\n~a\\n\" label (exn-message exn))\n" out)
      (display "                     (printf \"~a-ms: ~a\\n\" label (inexact->exact (round (- (current-inexact-milliseconds) start))))\n" out)
      (fprintf out "                     'failed)])\n")
      (fprintf out "    (define v (thunk))\n")
      (display "    (printf \"~a-ms: ~a\\n\" label (inexact->exact (round (- (current-inexact-milliseconds) start))))\n" out)
      (fprintf out "    v))\n\n")
      (fprintf out "(define datum (timed 'read-datum (lambda () (call-with-input-file datum-path read))))\n")
      (fprintf out "(define (make-control-namespace)\n")
      (fprintf out "  (define ns (make-base-namespace))\n")
      (fprintf out "  (parameterize ([current-namespace ns])\n")
      (fprintf out "    (namespace-require 'racket/base)\n")
      (fprintf out "    (namespace-require `(file ,module-variable-path))\n")
      (fprintf out "    (for ([name (in-list stub-names)])\n")
      (fprintf out "      (namespace-set-variable-value! name (lambda args (void)) #t)))\n")
      (fprintf out "  ns)\n\n")
      (fprintf out "(define (raw-syntax) (datum->syntax #f datum))\n")
      (fprintf out "(define (introduced-syntax)\n")
      (fprintf out "  (namespace-syntax-introduce (datum->syntax #f datum)))\n\n")
      (fprintf out "(define (run-expand label make-stx proc)\n")
      (fprintf out "  (collect-garbage)\n")
      (fprintf out "  (parameterize ([current-namespace (make-control-namespace)]\n")
      (fprintf out "                 [eval-jit-enabled #f])\n")
      (fprintf out "    (define result\n")
      (fprintf out "      (timed label\n")
      (fprintf out "             (lambda ()\n")
      (fprintf out "               (proc (make-stx)))))\n")
      (display "    (printf \"~a-result: ~a\\n\" label (if (eq? result 'failed) 'failed 'ok))))\n\n" out)
      (fprintf out "(run-expand 'expand-syntax/raw raw-syntax expand-syntax)\n")
      (fprintf out "(run-expand 'expand-syntax/introduced introduced-syntax expand-syntax)\n")
      (fprintf out "(run-expand 'expand-top-level-with-compile-time-evals/raw\n")
      (fprintf out "            raw-syntax\n")
      (fprintf out "            expand-top-level-with-compile-time-evals)\n")
      (fprintf out "(run-expand 'expand-top-level-with-compile-time-evals/introduced\n")
      (fprintf out "            introduced-syntax\n")
      (fprintf out "            expand-top-level-with-compile-time-evals)\n"))
    #:exists 'truncate/replace)
  (printf "racket-expand-control-path: ~a\n" script-path)
  (printf "racket-expand-datum-path: ~a\n" datum-path)
  (printf "racket-expand-control-stubs: ~a\n" (length stubs)))

;; expander-extraction-args : path? -> (listof string?)
;;   Build the standalone expander extraction command from src/expander/main.zuo.
(define (expander-extraction-args out-dir)
  (define out-rktl (build-path out-dir "expander.rktl"))
  (define dep-rktd (build-path out-dir "expander-dep.rktd"))
  (define cache-dir (build-path out-dir "cache-src"))
  (list
   (path->string bootstrap-run-rkt)
   "-t" (path->string expander-main-rkt)
   "-c" (path->string cache-dir)
   "--depends" (path->string dep-rktd)
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/api.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/primitive-parameter.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/readtable-parameter.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/readtable.rkt"))
   "++knot" "read" (path->string (build-path racket-root "src/expander/read/number.rkt"))
   "++direct" "linklet"
   "++direct" "kernel"
   "++disallow" "make-optional-keyword-procedure"
   "--no-global"
   "++global-ok" "core-forms"
   "++global-ok" "core-primitives"
   "++global-ok" "built-in-symbols"
   "++global-ok" "default-read-handler"
   "++global-ok" "current-previously-unbound"
   "++global-ok" "keep-source-locations?"
   "++global-ok" "rx:path-list"
   "++global-ok" "load-configure-expand"
   "-k" (path->string racket-root)
   "-s" "-x"
   "-o" (path->string out-rktl)))

;; timed : symbol? (-> any/c) -> any/c
;;   Run thunk and print elapsed time for the diagnostic transcript.
(define (timed label thunk)
  (define start (current-inexact-milliseconds))
  (call-with-values
   thunk
   (lambda results
     (define elapsed-ms (- (current-inexact-milliseconds) start))
     (printf "~a-ms: ~a\n" label (inexact->exact (round elapsed-ms)))
     (apply values results))))

;; call-with-timeout/limit : exact-positive-integer? (or/c #f exact-positive-integer?) (-> any/c) -> (values symbol? any/c)
;;   Run thunk in a bounded worker thread and report timeout or memory exhaustion.
(define (call-with-timeout/limit seconds memory-bytes thunk)
  (define ch (make-channel))
  (define cust (make-custodian))
  (when memory-bytes
    ;; Use the same custodian for limit and shutdown, so a single huge
    ;; allocation raises `exn:fail:out-of-memory` in the compile worker.
    (custodian-limit-memory cust memory-bytes cust))
  (define worker
    (parameterize ([current-custodian cust])
      (thread
       (lambda ()
         (channel-put
          ch
          (with-handlers ([exn:fail:out-of-memory?
                           (lambda (exn) (list 'memory exn))]
                          [exn:fail?
                           (lambda (exn) (list 'exn exn))])
            (list 'value (thunk))))))))
  (define result (sync/timeout seconds ch))
  (cond
    [result (apply values result)]
    [else
     (kill-thread worker)
     (custodian-shutdown-all cust)
     (values 'timeout #f)]))

;; write-compiled-wat! : path-string? string? -> void?
;;   Write compiler output in the same textual shape accepted by wasm-tools.
(define (write-compiled-wat! path wat)
  (call-with-output-file path
    (lambda (out)
      (displayln ";; This file was generated by webify/probe-expander-full-compile.rkt." out)
      (display (rewrite-wat-identifiers wat) out))
    #:exists 'truncate/replace)
  (printf "compile-wat-path: ~a\n" path))

;; wasm-tools-parse! : path-string? path-string? -> exact-integer?
;;   Parse/assemble WAT with wasm-tools, returning its exit status.
(define (wasm-tools-parse! wat-path wasm-path)
  (define wasm-tools (find-executable-path "wasm-tools"))
  (unless wasm-tools
    (error 'probe-expander-full-compile
           "required executable `wasm-tools` was not found in PATH"))
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (system*/exit-code wasm-tools "parse" wat-path "-o" wasm-path)))
  (define output (string-append (get-output-string stdout)
                                (get-output-string stderr)))
  (printf "wasm-tools-parse-status: ~a\n" status)
  (unless (string=? output "")
    (printf "wasm-tools-parse-output:\n~a\n" output))
  status)

(command-line
 #:program "probe-expander-full-compile"
 #:once-each
 [("--compile-timeout") seconds
  "Maximum seconds to spend in full WebRacket compilation"
  (compile-timeout-seconds (string->number seconds))]
 [("--compile-memory-mb") mb
  "Maximum MB charged to the full WebRacket compilation worker"
  (compile-memory-mb (string->number mb))]
 [("--compile-progress-interval") n
  "Print closure-conversion progress every N lifted closures"
  (compile-progress-interval (string->number n))]
 [("--compile-letrec-basic")
  "Compile with the basic letrec lowering strategy"
  (compile-letrec-strategy 'basic)]
 [("--compile-letrec-waddell")
  "Compile with the Waddell letrec lowering strategy"
  (compile-letrec-strategy 'waddell)]
 [("--compile-letrec-scc")
  "Compile with the SCC letrec lowering strategy"
  (compile-letrec-strategy 'scc)]
 [("--enable-cc-analysis")
  "Enable the closure-conversion analysis during WebRacket compilation"
  (compile-enable-cc-analysis? #t)]
 [("--enable-simplify")
  "Enable the early simplify-LFE pass during WebRacket compilation"
  (compile-enable-simplify? #t)]
 [("--no-console-bridge")
  "Do not expose first-slice exports through the generated wr-* console bridge"
  (compile-console-bridge? #f)]
 [("--label-map-forms")
  "Include source form strings in the compiler label map"
  (compile-label-map-forms? #t)]
 [("--label-map-form-labels") labels
  "Include source form strings for comma-separated generated labels, e.g. label.97083,label.97084"
  (compile-label-map-form-labels
   (append (string-split labels "," #:trim? #t)
           (compile-label-map-form-labels)))]
 [("--no-label-map-forms")
  "Omit source form strings from the compiler label map, the probe default"
  (compile-label-map-forms? #f)]
 [("--write-racket-control") path
  "Write the lowered generated program as a #lang racket/base control file"
  (write-racket-control-path path)]
 [("--write-racket-expand-control") path
  "Write a normal Racket script that times top-level expansion of the generated datum"
  (write-racket-expand-control-path path)]
 [("--write-racket-expand-datum") path
  "Write the generated datum consumed by --write-racket-expand-control"
  (write-racket-expand-datum-path path)]
 [("--write-map") path
  "Write the compiler label map to path"
  (write-map-path path)]
 [("--write-primitive-report") path
  "Write the runtime primitive reachability report to path"
  (write-primitive-report-path path)]
 [("--write-wat") path
  "Write the compiled expander WAT to path"
  (write-wat-path path)]
 [("--write-wasm") path
  "Assemble the compiled expander WAT to a wasm binary at path"
  (write-wasm-path path)]
 [("--validate-wat")
  "Validate the compiled expander WAT with wasm-tools parse"
  (validate-wat? #t)]
 [("--skip-webracket-compile")
  "Stop after extraction/lowering/control-file output"
  (skip-webracket-compile? #t)])

(when (and (write-racket-expand-control-path)
           (not (write-racket-expand-datum-path)))
  (write-racket-expand-datum-path
   (path->string
    (path-replace-extension
     (string->path (write-racket-expand-control-path))
     #".datum"))))

(unless (and (file-exists? racket-bin)
             (file-exists? bootstrap-run-rkt)
             (file-exists? expander-main-rkt))
  (error 'probe-expander-full-compile
         "expected Racket checkout under ../racket/racket"))

(define out-dir (make-temporary-file "webracket-expander-full-compile-~a" 'directory))

(dynamic-wind
  void
  (lambda ()
    (define status
      (timed 'extract
             (lambda ()
               (define stdout (open-output-string))
               (define stderr (open-output-string))
               (define status
                 (parameterize ([current-output-port stdout]
                                [current-error-port stderr])
                   (apply system*/exit-code
                          (path->string racket-bin)
                          (expander-extraction-args out-dir))))
               (define output (string-append (get-output-string stdout)
                                             (get-output-string stderr)))
               (for ([pattern (in-list '(#rx"Traversed [0-9]+ modules"
                                          #rx"Need [0-9]+ of those linklets"
                                          #rx"Can remove [^\n]+"
                                          #rx"Flattened code is [0-9]+ bytes"))])
                 (define m (regexp-match pattern output))
                 (when m (displayln (car m))))
               status)))
    (unless (zero? status)
      (error 'probe-expander-full-compile "extraction failed with status ~a" status))
    (define out-rktl (build-path out-dir "expander.rktl"))
    (define datum (timed 'read-linklet (lambda () (call-with-input-file out-rktl read))))
    (define-values (webified exports _exports-info)
      (timed 'webify-lower
             (lambda ()
               (run-first-slice-top-level
                datum
                ;; The JS startup probe uses wr-names/wr-ref/wr-call to inspect
                ;; linklet exports. Those bridge functions can only expose
                ;; compiler-visible top-level variables, so keep export aliases
                ;; for non-primitive exports when the bridge is enabled.
                #:define-export-aliases?
                (and (compile-console-bridge?)
                     console-bridge-export-alias?)))))
    (define clean-webified
      (timed 'clean-webified-syntax
             (lambda ()
               (datum->syntax #f (syntax->datum webified)))))
    (define bridged-webified
      (if (compile-console-bridge?)
          (add-console-bridge-probe-helpers clean-webified exports)
          clean-webified))
    (printf "exports: ~a\n" (length exports))
    (when (write-racket-control-path)
      (timed 'write-racket-control
             (lambda ()
               (write-racket-control!
                (write-racket-control-path)
                (syntax->datum bridged-webified)))))
    (when (write-racket-expand-control-path)
      (timed 'write-racket-expand-control
             (lambda ()
               (write-racket-expand-control!
                (write-racket-expand-control-path)
                (write-racket-expand-datum-path)
                (syntax->datum bridged-webified)))))
    (when (skip-webracket-compile?)
      (exit 0))
    (define-values (compile-status wat-or-failure)
      (timed 'compile
             (lambda ()
               (call-with-timeout/limit
                (compile-timeout-seconds)
                (and (compile-memory-mb)
                     (* (compile-memory-mb) 1024 1024))
                (lambda ()
                  (with-handlers ([exn:fail:out-of-memory?
                                   (lambda (exn) (raise exn))]
                                  [exn:fail?
                                   (lambda (exn)
                                     (webify-classify-module-exn 'compile exn))])
                    (parameterize ([current-compiler-progress?
                                    (and (compile-progress-interval) #t)]
                                   [current-closure-conversion-progress?
                                    (and (compile-progress-interval) #t)]
                                   [current-closure-conversion-progress-interval
                                    (or (compile-progress-interval) 1000)]
                                   [current-letrec-strategy
                                    (or (compile-letrec-strategy)
                                        (current-letrec-strategy))]
                                   [current-enable-cc-analysis?
                                    (compile-enable-cc-analysis?)]
                                   [current-enable-simplify?
                                    (compile-enable-simplify?)]
                                   [current-console-bridge?
                                    (compile-console-bridge?)]
                                   [current-console-bridge-top-binding-names
                                    exports]
                                   [current-runtime-primitive-report-path
                                    (write-primitive-report-path)])
                      (label-map-include-form? (compile-label-map-forms?))
                      (label-map-form-labels (compile-label-map-form-labels))
                      (define wat (wat-string (comp bridged-webified)))
                      (compile-result wat
                                      (and (write-map-path)
                                           (label-map->sexp))))))))))
    (cond
      [(eq? compile-status 'timeout)
       (printf "compile-timeout-seconds: ~a\n" (compile-timeout-seconds))
       (exit 124)]
      [(eq? compile-status 'memory)
       (printf "compile-memory-mb: ~a\n" (compile-memory-mb))
       (printf "compile-memory-message:\n~a\n" (exn-message wat-or-failure))
       (exit 125)]
      [(eq? compile-status 'exn)
       (raise wat-or-failure)]
      [(webify-module-failure? wat-or-failure)
       (printf "compile-failure-category: ~a\n"
               (webify-module-failure-category wat-or-failure))
       (printf "compile-failure-message:\n~a\n"
               (webify-module-failure-message wat-or-failure))
       (exit 1)]
      [else
       (define compiled-wat (compile-result-wat wat-or-failure))
       (printf "compile-wat-bytes: ~a\n" (string-length compiled-wat))
       (when (write-map-path)
         (call-with-output-file (write-map-path)
           (lambda (out) (pretty-write (compile-result-label-map wat-or-failure) out))
           #:exists 'replace)
         (printf "compile-map-path: ~a\n" (write-map-path))
         (printf "compile-map-bytes: ~a\n" (file-size (write-map-path))))
       (when (write-primitive-report-path)
         (printf "compile-primitive-report-path: ~a\n" (write-primitive-report-path))
         (printf "compile-primitive-report-bytes: ~a\n"
                 (file-size (write-primitive-report-path))))
       (when (or (write-wat-path)
                 (write-wasm-path)
                 (validate-wat?))
         (define wat-path
           (or (write-wat-path)
               (path->string
                (build-path out-dir "expander.wat"))))
         (timed 'write-wat
                (lambda ()
                  (write-compiled-wat! wat-path compiled-wat)))
         (when (or (write-wasm-path) (validate-wat?))
           (define wasm-path
             (or (write-wasm-path)
                 (path->string
                  (build-path out-dir "expander.wasm"))))
           (define parse-status
             (timed 'wasm-tools-parse
                    (lambda ()
                      (wasm-tools-parse! wat-path wasm-path))))
           (when (zero? parse-status)
             (printf "compile-wasm-path: ~a\n" wasm-path)
             (printf "compile-wasm-bytes: ~a\n" (file-size wasm-path)))
           (unless (zero? parse-status)
             (exit parse-status))))
       (exit 0)]))
  (lambda ()
    (with-handlers ([exn:fail:filesystem? void])
      (delete-directory/files out-dir))))
