#lang webracket/base

;; Racket 9.3 expands `procedure-rename` through the `new:*` bindings from
;; `racket/private/kw`. The split-runtime browser smoke compiles and runs this
;; module with `--split-runtime-provider-runtime`, expecting `42` on stdout.
(define (rename identity)
  (procedure-rename identity 'identity))

(define answer
  ((rename (lambda (x) x)) 42))

;; Module expressions are discarded by the bridge, so log the observable
;; browser result as well as writing it to the current output port.
(js-log answer)
(displayln answer)
