#lang webracket/base

(require browser/dom
         racket/port)

(define basic
  (call-with-output-string
   (lambda (out)
     (display "abc" out))))

(define sequenced
  (call-with-output-string
   (lambda (out)
     (display "a" out)
     (display "b" out))))

(define body (js-document-body))

(js-set-attribute! body "data-state" "starting")
(js-append-child! body (js-create-text-node (string-append basic "|" sequenced)))
(js-set-attribute! body "data-state" "loaded")
