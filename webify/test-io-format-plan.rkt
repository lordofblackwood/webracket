#lang racket/base

(require rackunit
         "io-format-deps.rkt")

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

(module+ main
  (void))
