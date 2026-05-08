#lang racket/base

(require racket/file
         racket/list
         racket/path
         racket/runtime-path
         racket/system
         racket/cmdline
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

;; call-with-timeout : exact-positive-integer? (-> any/c) -> (values symbol? any/c)
;;   Run thunk in a worker thread and report timeout without waiting forever.
(define (call-with-timeout seconds thunk)
  (define ch (make-channel))
  (define worker
    (thread
     (lambda ()
       (channel-put
        ch
        (with-handlers ([exn:fail? (lambda (exn) (list 'exn exn))])
          (list 'value (thunk)))))))
  (define result (sync/timeout seconds ch))
  (cond
    [result (apply values result)]
    [else
     (kill-thread worker)
     (values 'timeout #f)]))

(command-line
 #:program "probe-expander-full-compile"
 #:once-each
 [("--compile-timeout") seconds
  "Maximum seconds to spend in full WebRacket compilation"
  (compile-timeout-seconds (string->number seconds))])

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
    (printf "exports: ~a\n" (length exports))
    (define-values (compile-status wat-or-failure)
      (timed 'compile
             (lambda ()
               (call-with-timeout
                (compile-timeout-seconds)
                (lambda ()
                  (with-handlers ([exn:fail?
                                   (lambda (exn)
                                     (webify-classify-module-exn 'compile exn))])
                    (wat-string (comp webified))))))))
    (cond
      [(eq? compile-status 'timeout)
       (printf "compile-timeout-seconds: ~a\n" (compile-timeout-seconds))
       (exit 124)]
      [(eq? compile-status 'exn)
       (raise wat-or-failure)]
      [(webify-module-failure? wat-or-failure)
       (printf "compile-failure-category: ~a\n"
               (webify-module-failure-category wat-or-failure))
       (printf "compile-failure-message:\n~a\n"
               (webify-module-failure-message wat-or-failure))
       (exit 1)]
      [else
       (printf "compile-wat-bytes: ~a\n" (string-length wat-or-failure))
       (exit 0)]))
  (lambda ()
    (with-handlers ([exn:fail:filesystem? void])
      (delete-directory/files out-dir))))
