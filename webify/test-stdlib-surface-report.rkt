#lang racket/base

(require rackunit
         "stdlib-surface-report.rkt"
         "webracket-base-surface.rkt")

(test-case "staged io/format names are not temporary stdlib-owned aliases"
  (for ([name (in-list '(format fprintf printf eprintf))])
    (check-false (memq name temporary-stdlib-owned)
                 (symbol->string name))))

(test-case "webracket/base ownership report keeps racket/base as foundation"
  (check-not-false (memq webracket-base-foundation webracket-base-owned))
  (check-false (memq webracket-base-foundation webracket-base-addon-libraries))
  (check-not-false (memq 'racket/format webracket-base-owned)))

(module+ main
  (void))
