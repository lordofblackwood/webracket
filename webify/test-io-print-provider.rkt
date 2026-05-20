#lang racket/base

(require racket/file
         racket/runtime-path
         racket/string
         rackunit
         "../pkgs/webracket-lib/compiler/webify/io-print-provider.rkt")

(define-runtime-path staged-io-root "../racket-src/io")
(define-runtime-path upstream-io-root "../../racket/racket/src/io")

;; normalized-source-bytes : path-string? -> bytes?
;;   Compare staged upstream copies modulo whitespace-only cleanup.
(define (normalized-source-bytes path)
  (define text (bytes->string/utf-8 (file->bytes path)))
  (define lines
    (for/list ([line (in-list (string-split text "\n" #:trim? #f))])
      (regexp-replace #rx"[ \t]+$" line "")))
  (define normalized-lines
    (let loop ([lines lines])
      (cond
        [(and (pair? lines)
              (string=? (car (reverse lines)) ""))
         (loop (reverse (cdr (reverse lines))))]
        [else lines])))
  (string->bytes/utf-8
   (string-append (string-join normalized-lines "\n") "\n")))

(test-case "staged io/print seed files are copied from upstream"
  (for ([file (in-list (append io-print-staged-source-files
                               io-print-staged-port-source-files))])
    (define staged (build-path staged-io-root file))
    (define upstream (build-path upstream-io-root file))
    (check-true (file-exists? staged) file)
    (unless (equal? file "print/main-web.rkt")
      (check-true (file-exists? upstream) file)
      (check-equal? (normalized-source-bytes staged)
                    (normalized-source-bytes upstream)
                    file))))

(test-case "high-level printing has staged io ownership"
  (check-equal? io-print-provider-symbols
                '(display displayln newline print println write writeln))
  (check-false (io-print-provider-ready?))
  (check-false (assoc 'missing-staged-closure
                      io-print-bootstrap-blockers))
  (check-not-false (assoc 'port-substrate-adapter
                          io-print-bootstrap-blockers))
  (check-not-false (assoc 'custom-write-properties
                          io-print-bootstrap-blockers))
  (check-not-false (assoc 'graph-and-sharing
                          io-print-bootstrap-blockers))
  (for ([row (in-list (io-print-provider-status))])
    (check-equal? (cadr row) 'staged-original-planned)))

(test-case "runtime substrate stays separate from high-level printing"
  (for ([name (in-list '(current-output-port
                         open-output-string
                         get-output-string
                         port-display-handler
                         port-write-handler
                         write-string))])
    (check-not-false (memq name io-print-runtime-substrate-symbols)
                     (symbol->string name))
    (check-false (memq name io-print-provider-symbols)
                 (symbol->string name))))

(module+ main
  (void))
