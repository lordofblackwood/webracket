#lang racket/base

(require racket/match)

(provide primitive-module-name?
         primitive-module-names
         kernel-provider-name?)

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

(define kernel-provider-module-names
  '(#%kernel
    #%runtime))

;; primitive-module-name? : any/c -> boolean?
;;   Recognize primitive/predefined module names used by Racket's expander.
(define (primitive-module-name? name)
  (and (symbol? name)
       (memq name primitive-module-names)
       #t))

;; kernel-provider-name? : any/c -> boolean?
;;   Recognize primitive providers that should use kernel-specific bridge policy.
(define (kernel-provider-name? name)
  (cond
    [(symbol? name)
     (and (memq name kernel-provider-module-names) #t)]
    [(pair? name)
     (match name
       [`(quote ,inner) (kernel-provider-name? inner)]
       [_ #f])]
    [else
     #f]))
