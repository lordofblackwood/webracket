#lang racket/base

(provide webify-module-linklet-input
         webify-module-linklet-input?
         webify-module-linklet-input-name
         webify-module-linklet-input-linklet
         webify-module-linklet-input-imports
         webify-module-linklet-manifest
         webify-module-linklet-manifest?
         webify-module-linklet-manifest-inputs
         webify-module-linklet-manifest-roots
         datum->webify-module-linklet-manifest
         read-webify-module-linklet-manifest
         webify-module-linklet-manifest->registry
         webify-register-module-linklet-input!
         webify-module-linklet-inputs->registry)

(require racket/match
         "module-registry.rkt")

(struct webify-module-linklet-input (name linklet imports) #:transparent)
(struct webify-module-linklet-manifest (inputs roots) #:transparent)

;; validate-roots! : symbol? any/c -> void?
;;   Reject manifest roots that cannot identify module-linklet inputs.
(define (validate-roots! who roots)
  (unless (and (list? roots)
               (andmap symbol? roots))
    (raise-argument-error who "(listof symbol?)" roots)))

;; datum->webify-module-linklet-input : any/c -> webify-module-linklet-input?
;;   Parse one manifest input clause.
(define (datum->webify-module-linklet-input datum)
  (match datum
    [`(input ,(? symbol? name) ,linklet (imports ,imports))
     (webify-module-linklet-input name linklet imports)]
    [_
     (raise-arguments-error 'datum->webify-module-linklet-manifest
                            "expected module-linklet input clause"
                            "clause" datum)]))

;; datum->webify-module-linklet-manifest : any/c -> webify-module-linklet-manifest?
;;   Parse a datum handoff format for extracted module-linklet inputs.
(define (datum->webify-module-linklet-manifest datum)
  (match datum
    [`(webify-module-linklet-manifest
       (roots ,roots)
       ,input-clauses ...)
     (validate-roots! 'datum->webify-module-linklet-manifest roots)
     (webify-module-linklet-manifest
      (map datum->webify-module-linklet-input input-clauses)
      roots)]
    [_
     (raise-arguments-error 'datum->webify-module-linklet-manifest
                            "expected webify module-linklet manifest datum"
                            "datum" datum)]))

;; read-webify-module-linklet-manifest : path-string? -> webify-module-linklet-manifest?
;;   Read one module-linklet manifest datum from a file.
(define (read-webify-module-linklet-manifest path)
  (call-with-input-file path
    (lambda (in)
      (datum->webify-module-linklet-manifest (read in)))))

;; webify-register-module-linklet-input! : webify-module-registry? webify-module-linklet-input? -> void?
;;   Register one extracted module-linklet input in a module registry.
(define (webify-register-module-linklet-input! registry input)
  (define who 'webify-register-module-linklet-input!)
  (unless (webify-module-linklet-input? input)
    (raise-argument-error who "webify-module-linklet-input?" input))
  (webify-module-registry-add!
   registry
   (webify-module-linklet-input-name input)
   (webify-module-linklet-input-linklet input)
   #:imports (webify-module-linklet-input-imports input)))

;; webify-module-linklet-inputs->registry : (listof webify-module-linklet-input?) -> webify-module-registry?
;;   Build a registry from already-extracted module-linklet inputs.
(define (webify-module-linklet-inputs->registry inputs)
  (define who 'webify-module-linklet-inputs->registry)
  (unless (list? inputs)
    (raise-argument-error who "(listof webify-module-linklet-input?)" inputs))
  (define registry (make-webify-module-registry))
  (for ([input (in-list inputs)])
    (webify-register-module-linklet-input! registry input))
  registry)

;; webify-module-linklet-manifest->registry : webify-module-linklet-manifest? -> webify-module-registry?
;;   Build a registry from a parsed module-linklet manifest.
(define (webify-module-linklet-manifest->registry manifest)
  (unless (webify-module-linklet-manifest? manifest)
    (raise-argument-error 'webify-module-linklet-manifest->registry
                          "webify-module-linklet-manifest?"
                          manifest))
  (webify-module-linklet-inputs->registry
   (webify-module-linklet-manifest-inputs manifest)))
