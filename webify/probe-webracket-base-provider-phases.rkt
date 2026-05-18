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
                  webracket/base-file->local-module-reports
                  webracket/base-local-module-graph-registry
                  webracket/base-local-module-graph-root
                  webracket/base-reports->module-graph)
         "module-registry.rkt"
         "provider-trials.rkt")

(define-runtime-path repo-root* "..")
(define repo-root (simplify-path repo-root*))

;; repo-parent : path?
;;   Parent collection path that exposes this checkout as collection `webracket`.
(define repo-parent
  (let-values ([(base _name _must-be-dir?) (split-path repo-root)])
    base))

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

;; compose-graph : graph -> syntax?
;;   Compose a bridge graph the same way the driver does, but stop before running.
(define (compose-graph graph)
  (define composition
    (webify-compose-module-registry/roots/composition
     (webracket/base-local-module-graph-registry graph)
     (list (webracket/base-local-module-graph-root graph))
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

(module+ main
  (define trial-name 'racket/bool)
  (define timeout-seconds 120)
  (command-line
   #:program "probe-webracket-base-provider-phases"
   #:once-each
   [("--trial") name "provider trial module name"
                (set! trial-name (string->symbol name))]
   [("--timeout") seconds "seconds per phase before stopping"
                (set! timeout-seconds (string->number seconds))])
  (define trial (webify-provider-trial-ref trial-name))
  (define source-dir (make-temporary-file "webracket-base-provider-phase-src-~a" 'directory))
  (define source-path (build-path source-dir "main.rkt"))
  (dynamic-wind
    void
    (lambda ()
      (write-trial-source! trial source-path)
      (parameterize ([current-library-collection-paths
                      (cons repo-parent (current-library-collection-paths))]
                     [current-directory source-dir])
        (define-values (root reports)
          (run-stage! 'extract-local-reports
                      timeout-seconds
                      (lambda ()
                        (webracket/base-file->local-module-reports source-path))))
        (define graph
          (run-stage! 'discover-provider-graph
                      timeout-seconds
                      (lambda ()
                        (webracket/base-reports->module-graph root reports))))
        (define stx
          (run-stage! 'compose-module-graph
                      timeout-seconds
                      (lambda ()
                        (compose-graph graph))))
        (void
         (run-stage! 'compile-to-wat
                     timeout-seconds
                     (lambda ()
                       (comp stx))))))
    (lambda ()
      (with-handlers ([exn:fail:filesystem? void])
        (delete-directory/files source-dir)))))
