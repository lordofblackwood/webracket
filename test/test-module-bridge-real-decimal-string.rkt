#lang racket/base

(require rackunit
         "../pkgs/webracket/private/decimal-string.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt")

(check-equal? (real->decimal-string -3.007177033492824 4)
              "-3.0072")

(check-equal? (real->decimal-string 42 2)
              "42.00")

(check-equal? (real->decimal-string -0.0 4)
              "-0.0000")

(check-equal?
 (compiled-primitive-alias-hint
  'decimal-core
  'real->decimal-string
  'real->decimal-string)
 '(webracket/private/decimal-string real->decimal-string))
