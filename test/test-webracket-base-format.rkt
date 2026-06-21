#lang webracket/base

(require browser/dom
         racket/port)

(define body (js-document-body))
(define formatted (format "~a" 42))
(define written
  (call-with-output-string
   (lambda (out)
     (fprintf out "value=~a" 42))))

(js-set-attribute! body "data-state" "starting")
(js-append-child! body
                  (js-create-text-node
                   (string-append formatted "|" written)))
(js-set-attribute! body "data-state" "loaded")
