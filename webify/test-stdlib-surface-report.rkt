#lang racket/base

(require rackunit
         "stdlib-surface-report.rkt"
         "webracket-base-surface.rkt"
         "webracket-full-surface.rkt")

(test-case "staged io/format names are not temporary stdlib-owned aliases"
  (for ([name (in-list '(format fprintf printf eprintf))])
    (check-false (memq name temporary-stdlib-owned)
                 (symbol->string name))
    (check-equal? (stdlib-symbol-owner name)
                  'replace-with-original-racket-provider
                  (symbol->string name))
    (check-equal? (stdlib-symbol-replacement name)
                  'racket-src/io/format
                  (symbol->string name))))

(test-case "provider-owned public names are explicit"
  (check-equal? (sort provider-owned-public-symbols symbol<?)
                '(eprintf format fprintf printf read read-syntax)))

(test-case "stdlib file ownership records obsolete and mixed areas"
  (define by-file
    (for/hasheq ([row (in-list stdlib-file-ownership-rows)])
      (values (string->symbol (stdlib-file-ownership-row-file row)) row)))
  (check-equal? (stdlib-file-ownership-row-owner
                 (hash-ref by-file 'regexp.rkt))
                'obsolete)
  (check-equal? (stdlib-file-ownership-row-replacement
                 (hash-ref by-file 'regexp.rkt))
                'regexp-provider)
  (check-equal? (stdlib-file-ownership-row-owner
                 (hash-ref by-file 'writing.rkt))
                'mixed-runtime-and-legacy)
  (check-equal? (stdlib-file-ownership-row-replacement
                 (hash-ref by-file 'formatting-numbers.rkt))
                'racket-src/io/format))

(test-case "read ownership points away from stdlib"
  (check-equal? (stdlib-symbol-owner 'read)
                'replace-with-original-racket-provider)
  (check-equal? (stdlib-symbol-replacement 'read) 'expander/read)
  (check-equal? (stdlib-symbol-owner 'read-syntax)
                'replace-with-original-racket-provider)
  (check-equal? (stdlib-symbol-replacement 'read-syntax) 'expander/read)
  (check-equal? (stdlib-symbol-owner 'unsafe-intmap-ref) 'temporary-stdlib-owned))

(test-case "writing and printing ownership is split"
  (for ([name (in-list '(current-print print-syntax-width print-unreadable))])
    (check-equal? (stdlib-symbol-owner name)
                  'runtime-writing-substrate
                  (symbol->string name))
    (check-equal? (stdlib-symbol-replacement name)
                  'runtime-primitive
                  (symbol->string name)))
  (for ([name (in-list '(write display print))])
    (check-equal? (stdlib-symbol-owner name)
                  'replace-with-original-racket-provider
                  (symbol->string name))
    (check-equal? (stdlib-symbol-replacement name)
                  'racket-src/io/print
                  (symbol->string name))))

(test-case "webracket/base ownership report keeps racket/base as foundation"
  (check-not-false (memq webracket-base-foundation webracket-base-owned))
  (check-false (memq webracket-base-foundation webracket-base-addon-libraries))
  (check-false (memq 'racket/format webracket-base-owned)))

(test-case "webracket/full ownership report carries the curated add-ons"
  (check-not-false (memq webracket-full-foundation webracket-full-owned))
  (check-false (memq webracket-full-foundation webracket-full-addon-libraries))
  (check-not-false (memq 'racket/format webracket-full-owned)))

(module+ main
  (void))
