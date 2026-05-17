#lang racket/base

(require racket/cmdline
         racket/file
         "read-syntax-provider.rkt")

(module+ main
  (define cache-root
    (make-temporary-file "webracket-read-syntax-provider-~a" 'directory))
  (command-line
   #:program "check-read-syntax-provider"
   #:once-each
   [("--cache-dir") dir "cache directory for demod artifacts"
                    (set! cache-root (string->path dir))])
  (define-values (status output)
    (webify-read-syntax-demod! cache-root))
  (printf "read-syntax-demod-status: ~a\n" status)
  (unless (string=? output "")
    (display output))
  (exit status))
