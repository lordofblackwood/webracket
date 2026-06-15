#lang webracket/base

(require browser/dom)

(define body (js-document-body))

(js-set-attribute! body "data-state" "starting")
(js-append-child! body (js-create-text-node (format "~a" 42)))
(js-set-attribute! body "data-state" "loaded")
