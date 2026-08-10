#lang racket/base

;; thematic/token-contract : command-line -> void
;;   Print or write Thematic's generated web-easy token contract.

(provide main)

(require racket/cmdline
         "main.rkt")

;; main : -> void
;;   Parse command-line arguments and emit token-contract JSON.
(define (main)
  (define output-path #f)
  (command-line
   #:program "thematic-token-contract"
   #:once-each
   [("--output") path "Optional path for the token contract JSON."
                 (set! output-path path)])
  (if output-path
      (write-token-contract! output-path)
      (display (thematic-token-contract-json))))

(module+ main
  (main))
