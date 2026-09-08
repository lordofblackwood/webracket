#lang webracket/base

;; Racket 9.3 expands `procedure-rename` through the `new:*` bindings from
;; `racket/private/kw`. Renaming must preserve a keyword procedure's dispatcher
;; rather than sending its struct value to the raw kernel primitive.
(define (rename keyword-procedure)
  (procedure-rename keyword-procedure 'keyword-identity))

(define answer
  ((rename (lambda (#:value value) value)) #:value 42))

;; Module expressions are discarded by the bridge, so log the observable
;; browser result as well as writing it to the current output port.
(js-log answer)
(displayln answer)
