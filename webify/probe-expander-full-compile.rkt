#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/pretty
         racket/runtime-path
         racket/set
         racket/system
         racket/cmdline
         (only-in "../compiler.rkt" label-map->sexp)
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
(define compile-label-map-forms?    (make-parameter #f))
(define write-racket-control-path (make-parameter #f))
(define write-racket-expand-control-path (make-parameter #f))
(define write-racket-expand-datum-path (make-parameter #f))
(define write-map-path                 (make-parameter #f))
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
 [("--label-map-forms")
  "Include source form strings in the compiler label map"
  (compile-label-map-forms? #t)]
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
               (run-first-slice-top-level datum #:define-export-aliases? #f))))
    (define clean-webified
      (timed 'clean-webified-syntax
             (lambda ()
               (datum->syntax #f (syntax->datum webified)))))
    (printf "exports: ~a\n" (length exports))
    (when (write-racket-control-path)
      (timed 'write-racket-control
             (lambda ()
               (write-racket-control!
                (write-racket-control-path)
                (syntax->datum clean-webified)))))
    (when (write-racket-expand-control-path)
      (timed 'write-racket-expand-control
             (lambda ()
               (write-racket-expand-control!
                (write-racket-expand-control-path)
                (write-racket-expand-datum-path)
                (syntax->datum clean-webified)))))
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
                                    (compile-enable-simplify?)])
                      (label-map-include-form? (compile-label-map-forms?))
                      (define wat (wat-string (comp clean-webified)))
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
