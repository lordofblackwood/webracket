#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/webify/module-phase-policy.rkt")

(test-case "default module phase policy documents current bridge boundary"
  (check-true (webify-module-phase-policy? webify-default-module-phase-policy))
  (check-equal? (webify-module-phase-policy-supported-phases
                 webify-default-module-phase-policy)
                '(0))
  (check-equal? (webify-module-phase-policy-transformer-policy
                 webify-default-module-phase-policy)
                'metadata-visible-not-executed)
  (check-equal? (webify-module-phase-policy-set-transformer-policy
                 webify-default-module-phase-policy)
                'runtime-no-op)
  (check-equal? (webify-module-phase-policy-get-syntax-literal-policy
                 webify-default-module-phase-policy)
                'runtime-placeholder-syntax-and-source-location-data))

(module+ main
  (void))
