#lang webracket/base

;; Browser smoke for FFI `string/symbol` parameters.

(require browser/dom)

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

(define body (js-document-body))
(define obj
  (js-eval
   "({
      width: 17,
      height: 23,
      nested: { value: 42 },
      greet(name) { return 'hello ' + name; }
    })"))

(check-equal (js-ref obj "width") 17 "string property key")
(check-equal (js-ref obj 'width) 17 "symbol property key")
(check-equal (js-ref obj 'height) 23 "symbol property key 2")
(check-equal (js-ref (js-ref/extern obj 'nested) 'value) 42 "nested symbol property key")
(check-equal (js-send/value obj 'greet (vector "world")) "hello world" "symbol method name")

(js-assign! 'WebRacketStringSymbolFFITest "assigned")
(check-equal (js-ref (js-global-this) 'WebRacketStringSymbolFFITest)
             "assigned"
             "symbol global assignment")

(js-set-attribute! body "data-state" "loaded")
(js-append-child! body (js-create-text-node "js-string-symbol-ffi-ok"))
