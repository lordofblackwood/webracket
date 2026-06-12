#lang racket/base

(require racket/file
         racket/list
         racket/match
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system)

;; mode-result : string? hash? string? -> mode-result?
;;   Collected timing/profile summary for one example and simplify mode.
(struct mode-result (mode metrics output)
  #:transparent)

;; example-config : string? path? -> example-config?
;;   One module example to compile and compare.
(struct example-config (name source)
  #:transparent)

(define-runtime-path repo-root "..")

;; maybe-local-racket-path : -> (or/c path? #f)
;;   Prefer the sibling local Racket checkout when present.
(define (maybe-local-racket-path)
  (define p
    (simplify-path
     (build-path repo-root 'up "racket" "racket" "bin" "racket")))
  (and (file-exists? p) p))

;; maybe-local-raco-path : -> (or/c path? #f)
;;   Prefer the sibling local Racket checkout when present.
(define (maybe-local-raco-path)
  (define p
    (simplify-path
     (build-path repo-root 'up "racket" "racket" "bin" "raco")))
  (and (file-exists? p) p))

;; racket-path : path?
;;   Pick one Racket executable for the whole run.
(define racket-path
  (or (maybe-local-racket-path)
      (find-executable-path "racket")))

;; raco-path : path?
;;   Pick one `raco` executable for the whole run.
(define raco-path
  (or (maybe-local-raco-path)
      (find-executable-path "raco")))

;; collects-root : path?
;;   Derive the matching collects root for the selected toolchain.
(define collects-root
  (cond
    [(maybe-local-racket-path)
     (simplify-path
      (build-path repo-root 'up "racket" "racket" "collects"))]
    [else
     (find-system-path 'collects-dir)]))

;; fail! : string? -> none
;;   Abort with a helpful message.
(define (fail! msg)
  (error 'measure-simplify-module-builds "~a" msg))

(unless racket-path
  (fail! "could not find a Racket executable"))

(unless raco-path
  (fail! "could not find a raco executable"))

;; make-temp-dir : string? -> path?
;;   Create a fresh temporary directory for one measurement run.
(define (make-temp-dir template)
  (make-temporary-file template 'directory))

;; build-env : path? -> environment-variables?
;;   Construct a pinned subprocess environment for compiler checks.
(define (build-env compiled-root)
  (define env (environment-variables-copy (current-environment-variables)))
  (environment-variables-set!
   env
   #"PLTCOLLECTS"
   (string->bytes/utf-8
    (format "~a:~a"
            (path->string (build-path repo-root "pkgs"))
            (path->string collects-root))))
  (environment-variables-set!
   env
   #"PLTCOMPILEDROOTS"
   (string->bytes/utf-8 (path->string compiled-root)))
  env)

;; run/collect : path? (listof string?) path? environment-variables? exact-positive-integer? -> values
;;   Run one subprocess and capture stdout/stderr together.
(define (run/collect exe args cwd env timeout-seconds)
  (parameterize ([current-directory cwd]
                 [current-environment-variables env])
    (define-values (proc out in err)
      (apply subprocess #f #f #f (path->string exe) args))
    (close-output-port in)
    (define out-ch (make-channel))
    (define err-ch (make-channel))
    (thread (lambda ()
              (channel-put
               out-ch
               (with-handlers ([exn:fail? (lambda (_e) "")])
                 (port->string out)))))
    (thread (lambda ()
              (channel-put
               err-ch
               (with-handlers ([exn:fail? (lambda (_e) "")])
                 (port->string err)))))
    (define done? (sync/timeout timeout-seconds proc))
    (unless done?
      (subprocess-kill proc #t)
      (sync proc)
      (fail! (format "subprocess timed out: ~a" args)))
    (subprocess-wait proc)
    (values (subprocess-status proc)
            (string-append (channel-get out-ch)
                           (channel-get err-ch)))))

;; precompile-webracket! : environment-variables? -> void
;;   Build `webracket.rkt` once under the isolated compiled-root environment.
(define (precompile-webracket! env)
  (define-values (status output)
    (run/collect raco-path
                 (list "make" "webracket.rkt")
                 repo-root
                 env
                 300))
  (unless (zero? status)
    (fail! (format "precompile failed\n~a" output))))

;; metric-number : string? string? -> (or/c number? #f)
;;   Extract a numeric timing/profile metric from the transcript.
(define (metric-number output key)
  (for/or ([line (in-list (string-split output "\n"))])
    (define trimmed (string-trim line))
    (define prefix (string-append key ":"))
    (and (string-prefix? trimmed prefix)
         (let* ([raw (string-trim (substring trimmed (string-length prefix)))]
                [n   (and (string-suffix? raw "s")
                          (string->number
                           (substring raw 0 (sub1 (string-length raw)))))])
           n))))

;; profile-number : string? string? -> (or/c number? #f)
;;   Extract a numeric simplify profile counter from the transcript.
(define (profile-number output key)
  (for/or ([line (in-list (string-split output "\n"))])
    (define fields
      (string-split (string-trim line) "\t"))
    (and (= (length fields) 2)
         (string=? (car fields) key)
         (string->number (cadr fields)))))

;; collect-metrics : string? -> hash?
;;   Parse the timing/profile metrics we care about from one compile transcript.
(define (collect-metrics output)
  (hash 'driver-total                 (metric-number output "driver total")
        'compile-pipeline            (metric-number output "compile-pipeline")
        'compile-subtotal            (metric-number output "compile subtotal")
        'simplify-LFE                (metric-number output "simplify-LFE")
        'lower-letrec-values         (metric-number output "lower-letrec-values")
        'closure-conversion          (metric-number output "closure-conversion")
        'generate-code               (metric-number output "generate-code")
        'input-nodes                 (profile-number output "input-nodes")
        'output-nodes                (profile-number output "output-nodes")
        'nodes-removed               (profile-number output "nodes-removed")
        'free-var-summary-root-ms    (profile-number output "free-var-summary-root-ms")
        'free-var-summary-inclusive-ms
                                     (profile-number output "free-var-summary-total-inclusive-ms")
        'let-unused-pure-candidates  (profile-number output "let-unused-pure-candidates")
        'let-unused-pure-membership-checks
                                     (profile-number output "let-unused-pure-membership-checks")))

;; compile-args : path? path? path? boolean? -> (listof string?)
;;   Construct one webracket compile command.
(define (compile-args source dest provider-cache-dir simplify?)
  (append
   (list (path->string (build-path repo-root "webracket.rkt"))
         "--browser"
         "--dest" (path->string dest)
         "--timings"
         "--provider-cache-dir" (path->string provider-cache-dir))
   (if simplify?
       (list "--enable-simplify" "--simplify-profile")
       '())
   (list (path->string source))))

;; run-mode : example-config? symbol? path? environment-variables? -> mode-result?
;;   Warm one mode once, then rerun and capture the measured transcript.
(define (run-mode example mode temp-root env)
  (define simplify?
    (eq? mode 'simplify))
  (define example-root
    (build-path temp-root (example-config-name example)))
  (define provider-cache-dir
    (build-path example-root "provider-cache"))
  (define warm-dest
    (build-path example-root
                (format "~a-warm" (symbol->string mode))))
  (define measured-dest
    (build-path example-root
                (format "~a-measured" (symbol->string mode))))
  (make-directory* provider-cache-dir)
  (make-directory* warm-dest)
  (make-directory* measured-dest)
  (define warm-args
    (compile-args (example-config-source example) warm-dest provider-cache-dir simplify?))
  (define-values (warm-status warm-output)
    (run/collect racket-path warm-args repo-root env 300))
  (unless (zero? warm-status)
    (fail! (format "warmup failed for ~a ~a\n~a"
                   (example-config-name example)
                   mode
                   warm-output)))
  (define measured-args
    (compile-args (example-config-source example) measured-dest provider-cache-dir simplify?))
  (define-values (status output)
    (run/collect racket-path measured-args repo-root env 300))
  (unless (zero? status)
    (fail! (format "measured run failed for ~a ~a\n~a"
                   (example-config-name example)
                   mode
                   output)))
  (mode-result mode
               (collect-metrics output)
               output))

;; metric-ref : mode-result? symbol? -> (or/c number? #f)
;;   Look up one parsed metric from a mode result.
(define (metric-ref result key)
  (hash-ref (mode-result-metrics result) key #f))

;; metric-delta-string : (or/c number? #f) (or/c number? #f) -> string?
;;   Format a signed delta or `n/a`.
(define (metric-delta-string new old)
  (cond
    [(and new old)
     (format "~a" (- new old))]
    [else
     "n/a"]))

;; print-comparison : example-config? mode-result? mode-result? -> void
;;   Print the requested timing comparison for one example.
(define (print-comparison example baseline simplify)
  (printf "~a\n" (example-config-name example))
  (printf "  nodes removed: ~a\n" (or (metric-ref simplify 'nodes-removed) "n/a"))
  (printf "  simplify time: ~a\n" (or (metric-ref simplify 'simplify-LFE) "n/a"))
  (printf "  lower-letrec delta: ~a\n"
          (metric-delta-string (metric-ref simplify 'lower-letrec-values)
                               (metric-ref baseline 'lower-letrec-values)))
  (printf "  closure-conversion delta: ~a\n"
          (metric-delta-string (metric-ref simplify 'closure-conversion)
                               (metric-ref baseline 'closure-conversion)))
  (printf "  generate-code delta: ~a\n"
          (metric-delta-string (metric-ref simplify 'generate-code)
                               (metric-ref baseline 'generate-code)))
  (printf "  compile subtotal delta: ~a\n"
          (metric-delta-string (metric-ref simplify 'compile-subtotal)
                               (metric-ref baseline 'compile-subtotal)))
  (printf "  driver total delta: ~a\n"
          (metric-delta-string (metric-ref simplify 'driver-total)
                               (metric-ref baseline 'driver-total)))
  (printf "  free-var-summary-root-ms: ~a\n"
          (or (metric-ref simplify 'free-var-summary-root-ms) "n/a"))
  (printf "  free-var-summary-total-inclusive-ms: ~a\n"
          (or (metric-ref simplify 'free-var-summary-inclusive-ms) "n/a"))
  (printf "  let-unused-pure-membership-checks: ~a\n"
          (or (metric-ref simplify 'let-unused-pure-membership-checks) "n/a"))
  (newline))

(define examples
  (list
   (example-config
    "hello-world"
    (build-path repo-root "pkgs" "web-easy" "examples" "hello-world" "hello-world.rkt"))
   (example-config
    "single-counter"
    (build-path repo-root "pkgs" "web-easy" "examples" "single-counter" "single-counter.rkt"))))

(module+ main
  (define requested-names
    (vector->list (current-command-line-arguments)))
  (define selected-examples
    (if (null? requested-names)
        examples
        (filter (λ (example)
                  (member (example-config-name example) requested-names))
                examples)))
  (when (null? selected-examples)
    (fail! (format "no matching examples requested: ~a" requested-names)))
  (define temp-root
    (make-temp-dir "webracket-simplify-module-builds~a"))
  (define compiled-root
    (build-path temp-root "compiled"))
  (make-directory* compiled-root)
  (define env
    (build-env compiled-root))
  (precompile-webracket! env)
  (for ([example (in-list selected-examples)])
    (define baseline
      (run-mode example 'baseline temp-root env))
    (define simplify
      (run-mode example 'simplify temp-root env))
    (print-comparison example baseline simplify)
    (flush-output)))
