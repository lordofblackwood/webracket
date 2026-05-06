#lang racket/base

(provide webify-module-registry
         webify-module-registry?
         make-webify-module-registry
         webify-module-registry-entry
         webify-module-registry-entry?
         webify-module-registry-entry-name
         webify-module-registry-entry-linklet
         webify-module-registry-entry-imports
         webify-module-registry-add!
         webify-module-registry-ref
         webify-module-registry-names
         webify-compose-module-registry)

(require racket/list
         racket/match
         "module-composer.rkt")

(struct webify-module-registry (entries) #:transparent)
(struct webify-module-registry-entry (name linklet imports) #:transparent)

;; make-webify-module-registry : -> webify-module-registry?
;;   Create an empty mutable registry of named linklet slices.
(define (make-webify-module-registry)
  (webify-module-registry (make-hasheq)))

;; validate-registry! : symbol? any/c -> void?
;;   Reject values that cannot store webify module registry entries.
(define (validate-registry! who registry)
  (unless (webify-module-registry? registry)
    (raise-argument-error who "webify-module-registry?" registry)))

;; validate-entry-name! : symbol? any/c -> void?
;;   Reject module registry names that cannot be used for composition.
(define (validate-entry-name! who name)
  (unless (symbol? name)
    (raise-argument-error who "symbol?" name)))

;; validate-import-source! : symbol? any/c -> void?
;;   Reject flat import-source triples for registry entries.
(define (validate-import-source! who source)
  (match source
    [(list (? symbol?) (? symbol?) (? symbol?))
     (void)]
    [_
     (raise-argument-error who "(list/c symbol? symbol? symbol?)" source)]))

;; validate-imports! : symbol? any/c -> void?
;;   Reject registry import metadata before composition.
(define (validate-imports! who imports)
  (unless (list? imports)
    (raise-argument-error who "(listof (list/c symbol? symbol? symbol?))" imports))
  (for ([source (in-list imports)])
    (validate-import-source! who source))
  (define duplicate (check-duplicates (map car imports)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate registry import names are not supported"
                           "import" duplicate)))

;; webify-module-registry-add! : webify-module-registry? symbol? any/c [#:imports (listof source?)] -> void?
;;   Add a named linklet slice and its flat import-source metadata.
(define (webify-module-registry-add! registry name linklet #:imports [imports '()])
  (define who 'webify-module-registry-add!)
  (validate-registry! who registry)
  (validate-entry-name! who name)
  (validate-imports! who imports)
  (define entries (webify-module-registry-entries registry))
  (when (hash-has-key? entries name)
    (raise-arguments-error who
                           "duplicate module registry entries are not supported"
                           "name" name))
  (hash-set! entries name (webify-module-registry-entry name linklet imports))
  (void))

;; webify-module-registry-ref : webify-module-registry? symbol? -> webify-module-registry-entry?
;;   Look up one named registry entry.
(define (webify-module-registry-ref registry name)
  (define who 'webify-module-registry-ref)
  (validate-registry! who registry)
  (validate-entry-name! who name)
  (hash-ref (webify-module-registry-entries registry)
            name
            (lambda ()
              (raise-arguments-error who
                                     "unknown module registry entry"
                                     "name" name
                                     "available names" (webify-module-registry-names registry)))))

;; webify-module-registry-names : webify-module-registry? -> (listof symbol?)
;;   Return registered module names in deterministic order.
(define (webify-module-registry-names registry)
  (validate-registry! 'webify-module-registry-names registry)
  (sort (hash-keys (webify-module-registry-entries registry)) symbol<?))

;; entry->slice-spec : webify-module-registry-entry? -> webify-linklet-slice-spec?
;;   Convert one registry entry to the composer spec shape.
(define (entry->slice-spec entry)
  (webify-linklet-slice-spec
   (webify-module-registry-entry-name entry)
   (webify-module-registry-entry-linklet entry)
   (webify-module-registry-entry-imports entry)))

;; validate-compose-order! : webify-module-registry? (listof symbol?) -> void?
;;   Reject composition orders that reference missing entries or duplicate names.
(define (validate-compose-order! registry order)
  (define who 'webify-compose-module-registry)
  (unless (and (list? order)
               (andmap symbol? order))
    (raise-argument-error who "(listof symbol?)" order))
  (define duplicate (check-duplicates order))
  (when duplicate
    (raise-arguments-error who
                           "duplicate module names in composition order are not supported"
                           "name" duplicate))
  (for ([name (in-list order)])
    (webify-module-registry-ref registry name))
  (for/fold ([seen (hasheq)])
            ([name (in-list order)])
    (define entry (webify-module-registry-ref registry name))
    (for ([source (in-list (webify-module-registry-entry-imports entry))])
      (match-define (list import dependency export) source)
      (unless (hash-has-key? seen dependency)
        (raise-arguments-error who
                               "registry import dependency must appear earlier in the composition order"
                               "name" name
                               "import" import
                               "dependency" dependency
                               "export" export)))
    (hash-set seen name #t)))

;; webify-compose-module-registry : webify-module-registry? (listof symbol?) keyword-args ... -> values
;;   Compose named registry entries through the linklet first-slice composer.
(define (webify-compose-module-registry registry
                                        order
                                        #:tail                  [tail-forms '((void))]
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
  (define who 'webify-compose-module-registry)
  (validate-registry! who registry)
  (validate-compose-order! registry order)
  (webify-compose-linklet-first-slices
   (for/list ([name (in-list order)])
     (entry->slice-spec (webify-module-registry-ref registry name)))
   #:tail                  tail-forms
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
