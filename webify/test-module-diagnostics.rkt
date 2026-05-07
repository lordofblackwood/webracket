#lang racket/base

(require rackunit
         "module-diagnostics.rkt")

(test-case "module diagnostics classify extraction and resolution exceptions"
  (define missing-decompile
    (webify-classify-module-exn
     'extract
     (exn:fail "source module did not produce a decompilable phase-0 linklet datum"
               (current-continuation-marks))))
  (check-equal? (webify-module-failure-stage missing-decompile) 'extract)
  (check-equal? (webify-module-failure-category missing-decompile) 'missing-decompile)
  (define unresolved
    (webify-classify-module-exn
     'resolve
     (exn:fail "webify-resolve-module-linklet-imports: could not resolve import dependency"
               (current-continuation-marks))))
  (check-equal? (webify-module-failure-category unresolved) 'unresolved-import))

(test-case "module diagnostics classify missing alias exports as unresolved imports"
  (define missing-alias-export
    (webify-classify-runtime-output
     1
     "webify-resolve-module-linklet-imports: dependency does not export aliased name"))
  (check-equal? (webify-module-failure-category missing-alias-export)
                'unresolved-import))

(test-case "module diagnostics classify runtime output"
  (define primitive-collision
    (webify-classify-runtime-output
     1
     "alpha-rename: In webracket it is not allowed to redefine a primitive at the top-level"))
  (check-true (webify-module-failure? primitive-collision))
  (check-equal? (webify-module-failure-stage primitive-collision) 'runtime)
  (check-equal? (webify-module-failure-category primitive-collision)
                'primitive-alias-collision)
  (define syntax-literal
    (webify-classify-runtime-output
     1
     ".get-syntax-literal!: syntax literals are not supported by WebRacket module protocol yet"))
  (check-equal? (webify-module-failure-category syntax-literal)
                'syntax-literal)
  (check-false (webify-classify-runtime-output 0 "#t\n")))

(module+ main
  (void))
