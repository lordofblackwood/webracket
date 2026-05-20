#lang racket/base

(require racket/file
         rackunit
         "../pkgs/webracket-lib/compiler/webify/io-format-deps.rkt")

(test-case "staged io/format files are copied from upstream"
  (for ([file (in-list io-format-staged-source-files)])
    (define staged (io-format-file->path file))
    (define upstream (build-path upstream-io-source-root file))
    (check-true (file-exists? staged) file)
    (check-true (file-exists? upstream) file)
    (check-equal? (file->bytes staged)
                  (file->bytes upstream)
                  file)))

(test-case "io/format parser sources do not use regexp"
  (for ([summary (in-list (io-format-summaries))])
    (check-equal? (io-format-source-summary-regexp-symbols summary)
                  '()
                  (io-format-source-summary-file summary))))

(test-case "io/format direct dependencies are the expected small slice"
  (define summaries (io-format-summaries))
  (define main-summary
    (for/first ([summary (in-list summaries)]
                #:when (equal? "format/main.rkt"
                               (io-format-source-summary-file summary)))
      summary))
  (define printf-summary
    (for/first ([summary (in-list summaries)]
                #:when (equal? "format/printf.rkt"
                               (io-format-source-summary-file summary)))
      summary))
  (check-not-false main-summary)
  (check-not-false printf-summary)
  (check-equal? (io-format-source-summary-direct-requires main-summary)
                '("../common/check.rkt"
                  "../port/output-port.rkt"
                  "../port/parameter.rkt"
                  "../port/string-port.rkt"
                  "../print/parameter.rkt"
                  "../string/convert.rkt"
                  "printf.rkt"))
  (check-equal? (io-format-source-summary-direct-requires printf-summary)
                '("../error/value-string.rkt"
                  "../port/output-port.rkt"
                  "../port/string-output.rkt"
                  "../print/main.rkt"
                  "../print/mode.rkt"))
  (check-equal? (io-format-source-summary-direct-require-specs printf-summary)
                '("../error/value-string.rkt"
                  "../port/output-port.rkt"
                  "../port/string-output.rkt"
                  "../print/main.rkt"
                  "../print/main.rkt submodule internal"
                  "../print/mode.rkt")))

(test-case "regexp is only an io/print hook in this staging slice"
  (check-equal? (io-print-regexp-hook-exports)
                '(printable-regexp? set-printable-regexp?!)))

(test-case "staged direct slice exposes remaining transitive dependencies"
  (define report (io-format-local-require-closure io-format-source-files))
  (for ([file (in-list io-format-source-files)])
    (check-not-false (member file (io-format-local-closure-report-present report))))
  (check-false (member "format/printf.rkt"
                       (io-format-local-closure-report-missing report)))
  (check-not-false (member "print/custom-write.rkt"
                           (io-format-local-closure-report-missing report)))
  (check-not-false
   (for/or ([path (in-list (io-format-local-closure-report-external report))])
     (regexp-match? #rx"/racket-src/common/check[.]rkt$" path))))

(test-case "printf adapter surface stays small"
  (check-equal? (io-format-printf-adapter-symbols)
                '(->core-output-port
                  PRINT-MODE/UNQUOTED
                  display-via-handler
                  do-display
                  do-print
                  do-write
                  error-print-width
                  error-value->string
                  print-unreadable
                  print-via-handler
                  write-string
                  write-via-handler)))

(test-case "adapted printf keeps upstream body"
  (check-equal? (io-format-normalized-printf-body "format/printf-web.rkt")
                (io-format-normalized-printf-body "format/printf.rkt")))

(module+ main
  (void))
