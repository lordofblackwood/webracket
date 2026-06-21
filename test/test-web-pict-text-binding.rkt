#lang webracket/base

(require browser/dom
         web-pict)

(define status (js-create-element "div"))
(js-set-attribute! status "id" "status")
(js-set-attribute! status "data-state" "loading")
(js-set! status "textContent" "loading")
(js-append-child! (js-document-body) status)

(with-handlers ([exn:fail?
                 (lambda (e)
                   (js-set-attribute! status "data-state" "error")
                   (js-set! status "textContent" (exn-message e)))])
  (define v text)
  (js-set-attribute! status "data-state" "loaded")
  (js-set! status "textContent" (if v "web-pict-text-binding-ok" "missing")))
