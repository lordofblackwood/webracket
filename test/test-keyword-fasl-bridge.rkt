#lang webracket/base

(require browser/dom)

(define body (js-document-body))

(js-set-attribute! body "data-state" "starting")
(js-log '(#:attrs))
(js-append-child! body (js-create-text-node "keyword-fasl-bridge-ok"))
(js-set-attribute! body "data-state" "loaded")
