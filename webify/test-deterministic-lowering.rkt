#lang racket/base

(require rackunit
         "../pkgs/webracket-lib/compiler/webify/lower.rkt")

;; datum->cache-bytes : any/c -> bytes?
;;   Serialize a lowered datum exactly as the provider-cache fingerprint does.
(define (datum->cache-bytes datum)
  (define out (open-output-bytes))
  (write datum out)
  (get-output-bytes out))

;; generated-name-input : any/c
;;   Exercise every lowering pass that introduces temporary binding names.
(define generated-name-input
  '(begin
     (variable-reference-constant?
      (module-variable-reference instance-variable-reference cell))
     (make-parameter initial-value)
     (check-not-unsafe-undefined value 'value)
     (with-continuation-mark* push key value body)))

(test-case "lowering-generated names have stable cache bytes"
  (check-equal?
   (datum->cache-bytes (lower-module-first-slice generated-name-input))
   (datum->cache-bytes (lower-module-first-slice generated-name-input))))
