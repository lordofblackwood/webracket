#lang racket/base

(require racket/file
         racket/runtime-path
         rackunit
         "io-print-provider.rkt")

(define-runtime-path staged-io-root "../racket-src/io")
(define-runtime-path upstream-io-root "../../racket/racket/src/io")

(test-case "staged io/print seed files are copied from upstream"
  (for ([file (in-list io-print-staged-source-files)])
    (define staged (build-path staged-io-root file))
    (define upstream (build-path upstream-io-root file))
    (check-true (file-exists? staged) file)
    (unless (equal? file "print/main-web.rkt")
      (check-true (file-exists? upstream) file)
      (check-equal? (file->bytes staged)
                    (file->bytes upstream)
                    file))))

(test-case "high-level printing has staged io ownership"
  (check-equal? io-print-provider-symbols
                '(display displayln newline print println write writeln))
  (check-false (io-print-provider-ready?))
  (check-not-false (assoc 'missing-staged-closure
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
