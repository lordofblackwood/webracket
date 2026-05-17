#lang racket/base

;;; Probe support for the separate staged original-Racket `read-syntax` track.

(provide webify-read-syntax-provider-source
         webify-read-syntax-export-symbols
         webify-read-syntax-demod-command
         webify-read-syntax-demod!)

(require racket/file
         racket/path
         racket/runtime-path
         racket/system)

(define-runtime-path repo-root "..")

(define racket-root
  (simplify-path (build-path repo-root "../racket/racket")))

(define racket-bin
  (build-path racket-root "bin/racket"))

(define bootstrap-run-rkt
  (build-path racket-root "src/expander/bootstrap-run.rkt"))

(define webify-read-syntax-provider-source
  (build-path repo-root "racket-src/expander/read-syntax-provider-root.rkt"))

(define webify-read-syntax-export-symbols
  '(webify-expander-read-syntax
    webify-expander-read-syntax/recursive
    webify-expander-syntax->datum
    webify-expander-syntax-source
    webify-expander-syntax-line
    webify-expander-syntax-column
    webify-expander-syntax-position))

;; webify-read-syntax-demod-command : path-string? -> (listof string?)
;;   Build the demodularizer command for the isolated read-syntax probe.
(define (webify-read-syntax-demod-command cache-root)
  (define root (if (path? cache-root) cache-root (string->path cache-root)))
  (list (path->string racket-bin)
        (path->string bootstrap-run-rkt)
        "-t" (path->string webify-read-syntax-provider-source)
        "-c" (path->string (build-path root "bootstrap-cache"))
        "-k" (path->string racket-root)
        "-s" "-x"
        "--depends" (path->string (build-path root "read-syntax-dep.rktd"))
        "--no-global"
        ;; The upstream reader caches the default input-port handler in this
        ;; global. Keep the allowance private to the provider extraction.
        "++global-ok" "default-read-handler"
        "-o" (path->string (build-path root "read-syntax.rktl"))))

;; webify-read-syntax-demod! : path-string? -> (values exact-integer? string?)
;;   Run the first read-syntax demod probe and return status plus combined logs.
(define (webify-read-syntax-demod! cache-root)
  (make-directory* cache-root)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define command (webify-read-syntax-demod-command cache-root))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr])
      (apply system*/exit-code command)))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))
