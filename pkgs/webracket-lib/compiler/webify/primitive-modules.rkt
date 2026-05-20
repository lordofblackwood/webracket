#lang racket/base

(provide primitive-module-name?
         primitive-module-names)

;; primitive-module-names : (listof symbol?)
;;   Known primitive/predefined modules whose imports are supplied by the runtime.
(define primitive-module-names
  '(#%kernel
    #%core
    #%runtime
    #%main
    #%read
    #%utils
    #%boot
    #%unsafe
    #%linklet
    #%linklet-primitive
    #%linklet-expander
    #%expobs
    #%place-struct
    #%bootstrap-linklet
    webracket/primitives))

;; primitive-module-name? : any/c -> boolean?
;;   Recognize primitive/predefined module names used by Racket's expander.
(define (primitive-module-name? name)
  (and (symbol? name)
       (memq name primitive-module-names)
       #t))
