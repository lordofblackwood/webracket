#lang racket/base

;;; Bounded phase probe for #lang webracket/base provider bridge programs.

(require racket/cmdline
         racket/file
         racket/list
         racket/match
         racket/path
         racket/runtime-path
         racket/string
         (only-in "../compiler.rkt" comp)
         (only-in "../driver.rkt"
                  webracket/base-external-provider-names
                  webracket/base-file->local-module-reports
                  webracket/base-language-provider-name?)
         "module-extractor.rkt"
         "module-input.rkt"
         "module-protocol.rkt"
         "module-registry.rkt"
         "test-module-support.rkt"
         "provider-trials.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

;; now-ms : -> real?
;;   Current wall-clock time in milliseconds.
(define (now-ms)
  (current-inexact-milliseconds))

;; call-with-timeout : real? symbol? (-> any/c) -> values
;;   Run thunk in a worker and return status plus result/error.
(define (call-with-timeout timeout-seconds stage thunk)
  (define ch (make-channel))
  (define paramz (current-parameterization))
  (define worker
    (thread
     (lambda ()
       (call-with-parameterization
        paramz
        (lambda ()
          (channel-put
           ch
           (with-handlers ([exn:fail?
                            (lambda (exn) (list 'failed exn))])
             (call-with-values thunk
               (lambda values (cons 'ok values))))))))))
  (define result (sync/timeout timeout-seconds ch))
  (cond
    [result
     (match result
       [(list* 'ok stage-values) (values 'ok stage-values)]
       [(list 'failed exn) (values 'failed exn)])]
    [else
     (kill-thread worker)
     (values 'timeout stage)]))

;; write-trial-source! : webify-provider-trial? path-string? -> void?
;;   Write a tiny #lang webracket/base source that demands the trial provider.
(define (write-trial-source! trial path)
  (call-with-output-file path
    (lambda (out)
      (fprintf out "#lang webracket/base\n")
      (fprintf out "(require (only-in ~a ~a))\n"
               (webify-provider-trial-module trial)
               (string-join (map symbol->string
                                 (webify-provider-trial-exports trial))
                            " "))
      (fprintf out "(provide answer)\n")
      (fprintf out "(define answer (list ~a))\n"
               (string-join (map symbol->string
                                 (webify-provider-trial-exports trial))
                            " ")))
    #:exists 'truncate/replace))

;; compose-registry : registry root -> syntax?
;;   Compose a bridge registry the same way the driver does, but stop before running.
(define (compose-registry registry root)
  (define composition
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
     #:prim-knowns           (hasheq)
     #:primitives            (hasheq)
     #:compiler-query        (lambda (v) #f)
     #:get-import-knowns     (lambda (key) (values #f #f #f))
     #:import-keys           #f))
  (datum->syntax
   #f
   (webify-module-composition-with-tail composition '((void)))))

;; run-stage! : symbol? real? (-> any/c) -> any/c
;;   Run and print one bounded stage.
(define (run-stage! stage timeout-seconds thunk)
  (define start (now-ms))
  (printf "stage-start\t~a\n" stage)
  (flush-output)
  (define-values (status result)
    (call-with-timeout timeout-seconds stage thunk))
  (define elapsed (- (now-ms) start))
  (printf "stage-result\t~a\t~a\t~a\n" stage status elapsed)
  (flush-output)
  (case status
    [(ok) (apply values result)]
    [(failed) (raise result)]
    [(timeout) (exit 124)]))

;; run-provider-discovery-stage! : real? box? exact-nonnegative-integer? thunk -> any/c
;;   Run provider discovery and print traces even when the stage fails.
(define (run-provider-discovery-stage! timeout-seconds trace-box trace-limit thunk)
  (define start (now-ms))
  (printf "stage-start\tdiscover-provider-graph\n")
  (flush-output)
  (define-values (status result)
    (call-with-timeout timeout-seconds 'discover-provider-graph thunk))
  (define elapsed (- (now-ms) start))
  (printf "stage-result\tdiscover-provider-graph\t~a\t~a\n" status elapsed)
  (print-trace-counters! (unbox trace-box))
  (print-trace! (unbox trace-box) trace-limit)
  (flush-output)
  (case status
    [(ok) (apply values result)]
    [(failed) (raise result)]
    [(timeout) (exit 124)]))

;; print-trace! : (listof trace-event?) exact-nonnegative-integer? -> void?
;;   Print a compact provider discovery trace prefix.
(define (print-trace! trace limit)
  (for ([event (in-list (take trace (min limit (length trace))))])
    (printf "provider-trace\t~a\t~a\t~a\t~a\t~a\t~a\t~a\n"
            (webify-module-provider-discovery-trace-event-provider event)
            (webify-module-provider-discovery-trace-event-demander event)
            (webify-module-provider-discovery-trace-event-depth event)
            (webify-module-provider-discovery-trace-event-cached? event)
            (webify-module-provider-discovery-trace-event-reason event)
            (webify-module-provider-discovery-trace-event-status event)
            (webify-module-provider-discovery-trace-event-elapsed-ms event)))
  (when (> (length trace) limit)
    (printf "provider-trace-truncated\t~a\t~a\n" limit (length trace))))

;; print-trace-counters! : (listof trace-event?) -> void?
;;   Print compact trace counters grouped by reason, status, and cache mode.
(define (print-trace-counters! trace)
  (define counts (make-hash))
  (for ([event (in-list trace)])
    (define key
      (list (webify-module-provider-discovery-trace-event-reason event)
            (webify-module-provider-discovery-trace-event-status event)
            (if (webify-module-provider-discovery-trace-event-cached? event)
                'cached
                'uncached)))
    (hash-update! counts key add1 0))
  (for ([key (in-list (sort (hash-keys counts)
                            string<?
                            #:key (lambda (key) (format "~s" key))))])
    (match-define (list reason status cache-status) key)
    (printf "provider-trace-count\t~a\t~a\t~a\t~a\n"
            reason
            status
            cache-status
            (hash-ref counts key))))

;; print-stage-timings! : alist? -> void?
;;   Print split provider-discovery substep timings.
(define (print-stage-timings! timings)
  (for ([timing (in-list timings)])
    (printf "provider-substage\t~a\t~a\n" (car timing) (cdr timing))))

;; print-provider-demand-summary! : (listof report?) -> void?
;;   Print the local/language/external split in initial provider demand.
(define (print-provider-demand-summary! reports)
  (define local-names (map webify-module-report-name reports))
  (define required-names
    (remove-duplicates
     (append*
      (for/list ([report (in-list reports)])
        (webify-module-report-required-provider-names report)))
     eq?))
  (define local-demanded
    (filter (lambda (name) (memq name local-names)) required-names))
  (define language-demanded
    (filter webracket/base-language-provider-name? required-names))
  (define external-demanded
    (webracket/base-external-provider-names reports))
  (printf "provider-demand-count\tlocal\t~a\n" (length local-demanded))
  (printf "provider-demand-count\tlanguage-root\t~a\n" (length language-demanded))
  (printf "provider-demand-count\texternal\t~a\n" (length external-demanded))
  (for ([name (in-list external-demanded)])
    (printf "provider-demand\texternal\t~a\n" name))
  (for ([name (in-list language-demanded)])
    (printf "provider-demand\tlanguage-root\t~a\n" name)))

(module+ main
  (define trial-name 'racket/bool)
  (define timeout-seconds 120)
  (define frontier-limit #f)
  (define trace-limit 40)
  (define cut-language-root? #t)
  (command-line
   #:program "probe-webracket-base-provider-phases"
   #:once-each
   [("--trial") name "provider trial module name"
                (set! trial-name (string->symbol name))]
   [("--timeout") seconds "seconds per phase before stopping"
                (set! timeout-seconds (string->number seconds))]
   [("--frontier-limit") n "stop provider discovery after N providers"
                         (set! frontier-limit (string->number n))]
   [("--trace-limit") n "provider trace rows to print"
                      (set! trace-limit (string->number n))]
   [("--cut-language-root") "cut webracket/base language providers from external discovery (default)"
                            (set! cut-language-root? #t)]
   [("--include-language-root") "experiment: include webracket/base language providers in external discovery"
                                (set! cut-language-root? #f)])
  (define trial (webify-provider-trial-ref trial-name))
  (define source-dir (make-temporary-file "webracket-base-provider-phase-src-~a" 'directory))
  (define source-path (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-trial-source! trial source-path)
      (parameterize ([current-library-collection-paths
                      (cons (webracket-collection-parent)
                            (current-library-collection-paths))]
                     [current-directory source-dir])
        (define-values (root reports)
          (run-stage! 'extract-local-reports
                      timeout-seconds
                      (lambda ()
                        (webracket/base-file->local-module-reports source-path))))
        (print-provider-demand-summary! reports)
        (define trace-box (box '()))
        (define stages
          (run-provider-discovery-stage!
           timeout-seconds
           trace-box
           trace-limit
           (lambda ()
             (webify-module-provider-discovery-run-stages
              reports
              #:extra-reports (list webify-module-protocol-report)
              #:module-protocol-dependency webify-module-protocol-dependency
              #:demand-slice? #t
              #:trace-box trace-box
              #:frontier-limit frontier-limit
              #:skip-provider?
              (lambda (name)
                (and cut-language-root?
                     (webracket/base-language-provider-name? name)))))))
        (print-stage-timings!
         (webify-module-provider-discovery-stages-timings stages))
        (define registry
          (run-stage! 'build-module-registry
                      timeout-seconds
                      (lambda ()
                        (webify-module-linklet-inputs->registry
                         (webify-module-provider-discovery-stages-inputs stages)))))
        (define stx
          (run-stage! 'compose-module-graph
                      timeout-seconds
                      (lambda ()
                        (compose-registry registry root))))
        (void
         (run-stage! 'compile-to-wat
                     timeout-seconds
                     (lambda ()
                       (comp stx))))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))
