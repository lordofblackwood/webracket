#lang racket

(provide realm-runtime-symbol-constants
         realm-global-forms
         realm-initializer-forms)

(require "../../private/wasm-utils.rkt")

;; realm-runtime-symbol-constants : (listof symbol?)
;;   Declare commonly used runtime realm symbols.
(define realm-runtime-symbol-constants
  '(racket
    racket/primitive))

;; realm-global-forms : (listof datum?)
;;   Declare globals for commonly used runtime realm symbols.
(define realm-global-forms
  `(
         ;; Commonly used realms
         (global $the-racket-realm           (mut (ref eq)) ,(Undefined)) ; the symbol 'racket
         (global $the-racket/primitive-realm (mut (ref eq)) ,(Undefined)))) ; the symbol 'racket/primitive

;; realm-initializer-forms : (listof datum?)
;;   Initialize commonly used runtime realm symbols.
(define realm-initializer-forms
  '(
                     ;; ;; Initialize realm symbols
                     ;; (global.set $the-racket-realm
                     ;;             (call $string->symbol
                     ;;                   (ref.cast (ref $String)
                     ;;                             (global.get $string:racket))))
                     ;; (global.set $the-racket/primitive-realm
                     ;;             (call $string->symbol
                     ;;                   (ref.cast
                     ;;                    (ref $String)
                     ;;                    (global.get $string:racket/primitive))))
                     (global.set $the-racket-realm           (global.get $symbol:racket))
                     (global.set $the-racket/primitive-realm (global.get $symbol:racket/primitive))))
