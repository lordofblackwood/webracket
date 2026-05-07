#lang racket/base

(provide webify-module-loader
         webify-module-loader?
         make-webify-module-loader
         webify-module-loader-registry
         webify-module-loader-roots
         webify-module-loader-composition
         webify-module-loader-instantiate!
         webify-module-loader-instantiate-roots!
         webify-module-loader-lookup-export-cell
         webify-module-loader-export-cell-id
         webify-module-loader-compose-program
         webify-module-loader-observe
         webify-module-loader-with-tail)

(require racket/match
         "module-registry.rkt")

(struct webify-module-loader (registry [roots #:mutable] [composition #:mutable])
  #:transparent)

;; make-webify-module-loader : webify-module-registry? -> webify-module-loader?
;;   Create a loader facade over a registry and composition payload.
(define (make-webify-module-loader registry)
  (unless (webify-module-registry? registry)
    (raise-argument-error 'make-webify-module-loader
                          "webify-module-registry?"
                          registry))
  (webify-module-loader registry #f #f))

;; validate-loader! : symbol? any/c -> void?
;;   Reject values that cannot act as module loaders.
(define (validate-loader! who loader)
  (unless (webify-module-loader? loader)
    (raise-argument-error who "webify-module-loader?" loader)))

;; validate-roots! : symbol? any/c -> void?
;;   Reject root lists that cannot identify a loader composition.
(define (validate-roots! who roots)
  (unless (and (list? roots)
               (andmap symbol? roots))
    (raise-argument-error who "(listof symbol?)" roots)))

;; validate-observations! : symbol? any/c -> void?
;;   Reject loader observation requests with malformed shape.
(define (validate-observations! who observations)
  (unless (list? observations)
    (raise-argument-error who "(listof (list/c symbol? symbol?))" observations))
  (for ([observation (in-list observations)])
    (match observation
      [(list (? symbol?) (? symbol?))
       (void)]
      [_
       (raise-argument-error who "(list/c symbol? symbol?)" observation)])))

;; webify-module-loader-instantiate-roots! : webify-module-loader? (listof symbol?) keyword-args ... -> webify-module-composition?
;;   Compose roots once and reuse the same composition for repeated requests.
(define (webify-module-loader-instantiate-roots! loader
                                                 roots
                                                 #:tail                  [tail-forms '((void))]
                                                 #:define-export-aliases? [define-export-aliases? #t]
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
  (define who 'webify-module-loader-instantiate-roots!)
  (validate-loader! who loader)
  (validate-roots! who roots)
  (define existing-roots (webify-module-loader-roots loader))
  (define existing-composition (webify-module-loader-composition loader))
  (cond
    [(and existing-roots existing-composition)
     (unless (equal? existing-roots roots)
       (raise-arguments-error who
                              "module loader already instantiated different roots"
                              "existing roots" existing-roots
                              "requested roots" roots))
     existing-composition]
    [else
     (define composition
       (webify-compose-module-registry/roots/composition
        (webify-module-loader-registry loader)
        roots
        #:tail                  tail-forms
        #:define-export-aliases? define-export-aliases?
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
     (set-webify-module-loader-roots! loader roots)
     (set-webify-module-loader-composition! loader composition)
     composition]))

;; webify-module-loader-instantiate! : webify-module-loader? (listof symbol?) keyword-args ... -> webify-module-composition?
;;   Facade name for composing and memoizing a loader's root module graph.
(define webify-module-loader-instantiate!
  webify-module-loader-instantiate-roots!)

;; webify-module-loader-export-cell-id : webify-module-loader? symbol? symbol? -> symbol?
;;   Look up one export cell in an instantiated loader.
(define (webify-module-loader-export-cell-id loader name export)
  (define who 'webify-module-loader-export-cell-id)
  (validate-loader! who loader)
  (define composition (webify-module-loader-composition loader))
  (unless composition
    (raise-arguments-error who
                           "module loader has not been instantiated"))
  (webify-module-composition-export-cell-id composition name export))

;; webify-module-loader-lookup-export-cell : webify-module-loader? symbol? symbol? -> symbol?
;;   Facade name for looking up one instantiated module export cell.
(define webify-module-loader-lookup-export-cell
  webify-module-loader-export-cell-id)

;; webify-module-loader-with-tail : webify-module-loader? (listof any/c) -> any/c
;;   Rebuild the instantiated loader's composed datum with a caller-supplied tail.
(define (webify-module-loader-with-tail loader tail-forms)
  (define who 'webify-module-loader-with-tail)
  (validate-loader! who loader)
  (define composition (webify-module-loader-composition loader))
  (unless composition
    (raise-arguments-error who
                           "module loader has not been instantiated"))
  (webify-module-composition-with-tail composition tail-forms))

;; webify-module-loader-compose-program : webify-module-loader? (listof any/c) -> any/c
;;   Facade name for rebuilding the instantiated top-level program with a tail.
(define webify-module-loader-compose-program
  webify-module-loader-with-tail)

;; webify-module-loader-observe : webify-module-loader? (listof observation?) -> any/c
;;   Compose a top-level program that observes module exports through cells.
(define (webify-module-loader-observe loader
                                      observations
                                      #:observer [observer 'js-log]
                                      #:tail [tail-forms '((void))])
  (define who 'webify-module-loader-observe)
  (validate-loader! who loader)
  (validate-observations! who observations)
  (unless (symbol? observer)
    (raise-argument-error who "symbol?" observer))
  (define observation-tail
    (for/list ([observation (in-list observations)])
      (match-define (list name export) observation)
      `(,observer
        (module-variable-ref
         ,(webify-module-loader-lookup-export-cell loader name export)))))
  (webify-module-loader-compose-program
   loader
   (append observation-tail tail-forms)))
