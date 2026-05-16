#lang racket/base

(require rackunit
         "io-format-provider.rkt"
         (prefix-in web: "../racket-src/io/format/main-web.rkt")
         "../stdlib/module-exports.rkt")

(test-case "staged original io/format provider exports the format family"
  (check-true (io-format-provider-ready?))
  (check-equal? io-format-provider-symbols
                '(format fprintf printf eprintf))
  (check-equal? (map car (io-format-provider-status))
                io-format-provider-symbols))

(test-case "staged original io/format provider covers directives missing from bootstrap primitive"
  (check-equal? (web:format "hex=~x oct=~o bin=~b char=~c"
                            255 9 5 #\A)
                "hex=ff oct=11 bin=101 char=A")
  (define out (open-output-string))
  (check-equal? (web:fprintf out "value=~a/~s~n" 'ok '(1 2))
                (void))
  (check-equal? (get-output-string out)
                "value=ok/(1 2)\n"))

(test-case "format family is not owned by the temporary WebRacket stdlib"
  (define node-exports (stdlib-module-export-symbols #f))
  (for ([name (in-list io-format-provider-symbols)])
    (check-false (memq name node-exports)
                 (format "~a should not be a temporary stdlib export" name))))

(module+ main
  (void))
