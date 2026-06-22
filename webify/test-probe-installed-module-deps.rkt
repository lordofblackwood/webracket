#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
         "probe-installed-module-deps.rkt")

(test-case "class Goal 1 cases seed unsafe undefined support reports"
  (define class-reports (extract-case-extra-reports 'class-require))
  (define plain-reports (extract-case-extra-reports 'set-require))
  (define class-names (map webify-module-report-name class-reports))
  (define plain-names (map webify-module-report-name plain-reports))
  (check-equal? (car class-names) 'module-protocol)
  (check-not-false (member 'webracket/contract class-names))
  (check-not-false (member 'webracket/unsafe/undefined class-names))
  (check-not-false (member 'racket/unsafe/undefined class-names))
  (check-equal? plain-names '(module-protocol)))
