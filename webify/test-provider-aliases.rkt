#lang racket/base

(require rackunit
         (only-in "../pkgs/webracket-lib/compiler/driver.rkt"
                  provider-owned-primitive-alias-symbols)
         "io-format-bridge.rkt"
         "read-provider.rkt"
         "regexp-provider.rkt")

(test-case "provider-owned aliases include regexp by default"
  (define aliases (provider-owned-primitive-alias-symbols))
  (for ([name (in-list webify-regexp-export-symbols)])
    (check-not-false (member name aliases)))
  (check-false (member 'read aliases))
  (check-false (member 'format aliases)))

(test-case "provider-owned aliases include read only when read provider is enabled"
  (define aliases
    (provider-owned-primitive-alias-symbols #:expander-read-provider? #t))
  (for ([name (in-list webify-read-public-alias-symbols)])
    (check-not-false (member name aliases)))
  (check-false (member 'format aliases)))

(test-case "provider-owned aliases include io/format only when io provider is enabled"
  (define aliases
    (provider-owned-primitive-alias-symbols #:io-format-provider? #t))
  (for ([name (in-list webify-io-format-export-symbols)])
    (check-not-false (member name aliases)))
  (check-false (member 'read aliases)))

(module+ main
  (void))
