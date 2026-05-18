#lang racket/base

(require racket/file
         rackunit
         "io-print-deps.rkt"
         "io-print-provider.rkt")

(test-case "io/print direct dependency map preserves the upstream main shape"
  (check-equal? (io-print-direct-require-specs "print/main.rkt")
                '("../common/check.rkt"
                  "../error/message.rkt"
                  "../port/bytes-output.rkt"
                  "../port/bytes-port.rkt"
                  "../port/input-port.rkt"
                  "../port/output-port.rkt"
                  "../port/parameter.rkt"
                  "../port/string-output.rkt"
                  "bytes.rkt"
                  "char.rkt"
                  "config.rkt"
                  "custom-write.rkt"
                  "graph.rkt"
                  "hash.rkt"
                  "list.rkt"
                  "mlist.rkt"
                  "mode.rkt"
                  "named.rkt"
                  "parameter.rkt"
                  "recur-handler.rkt"
                  "regexp.rkt"
                  "string.rkt"
                  "symbol.rkt"
                  "vector.rkt"
                  "write-with-max.rkt")))

(test-case "first io/print helper slice is staged"
  (for ([file (in-list io-print-first-helper-slice)])
    (check-true (file-exists? (io-print-file->path file)) file)
    (check-not-false (member file io-print-staged-source-files) file)))

(test-case "io/print closure reports remaining missing helpers"
  (define closure (io-print-local-require-closure io-print-source-files))
  (for ([file (in-list '("print/main.rkt"
                         "print/custom-write.rkt"
                         "print/write-with-max.rkt"
                         "print/string.rkt"
                         "print/bytes.rkt"
                         "print/symbol.rkt"
                         "print/char.rkt"
                         "print/config.rkt"
                         "print/more-pending.rkt"))])
    (check-not-false
     (member file (io-print-local-closure-report-present closure))
     file))
  (for ([file (in-list '("print/graph.rkt"
                         "print/hash.rkt"
                         "print/list.rkt"
                         "print/mlist.rkt"
                         "print/named.rkt"
                         "print/recur-handler.rkt"
                         "print/vector.rkt"))])
    (check-not-false
     (member file (io-print-local-closure-report-missing closure))
     file)))

(module+ main
  (void))
