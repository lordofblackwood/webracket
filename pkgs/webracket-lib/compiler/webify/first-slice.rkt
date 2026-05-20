#lang racket/base

(require "lower.rkt"
         "webify.rkt")

(provide webify-linklet-first-slice)

;; webify-linklet-first-slice : linklet keyword-args ... -> values
;;   Webify a linklet and lower the supported first module slice.
(define (webify-linklet-first-slice lk
                                    #:serializable?-box     serializable?-box
                                    #:datum-intern?         datum-intern?
                                    #:target                target
                                    #:allow-set!-undefined? allow-set!-undefined?
                                    #:unsafe-mode?          unsafe-mode?
                                    #:enforce-constant?     enforce-constant?
                                    #:allow-inline?         allow-inline?
                                    #:no-prompt?            no-prompt?
                                    #:prim-knowns           prim-knowns
                                    #:primitives            primitives
                                    #:compiler-query        compiler-query
                                    #:get-import-knowns     get-import-knowns
                                    #:import-keys           import-keys)
  (define-values (webified importss exports revised-import-keys imports-abis exports-info)
    (webify-linklet lk
                    #:serializable?-box     serializable?-box
                    #:datum-intern?         datum-intern?
                    #:target                target
                    #:allow-set!-undefined? allow-set!-undefined?
                    #:unsafe-mode?          unsafe-mode?
                    #:enforce-constant?     enforce-constant?
                    #:allow-inline?         allow-inline?
                    #:no-prompt?            no-prompt?
                    #:prim-knowns           prim-knowns
                    #:primitives            primitives
                    #:compiler-query        compiler-query
                    #:get-import-knowns     get-import-knowns
                    #:import-keys           import-keys))
  (values (lower-module-first-slice webified)
          importss
          exports
          revised-import-keys
          imports-abis
          exports-info))
