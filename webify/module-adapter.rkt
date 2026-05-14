#lang racket/base

(provide strip-correlated
         first-slice-import-cell-args
         first-slice-top-level-helper-ids
         first-slice-top-level-export-cell-ids
         first-slice->top-level-datum
         first-slice->top-level-datum/imports
         first-slice->top-level-syntax
         webify-linklet-first-slice-top-level/imports
         webify-linklet-first-slice-top-level)

(require racket/list
         racket/match
         "first-slice.rkt"
         "wrap.rkt")

;; strip-correlated : any/c -> any/c
;;   Remove correlated wrappers so compiler terms can become source datums.
(define (strip-correlated v)
  (let ([v (unwrap v)])
    (cond
      [(pair? v)   (cons (strip-correlated (car v))
                         (strip-correlated (cdr v)))]
      [(vector? v) (list->vector (map strip-correlated (vector->list v)))]
      [else        v])))

;; validate-top-level-exports! : symbol? any/c -> void?
;;   Reject export lists the current top-level adapter cannot represent safely.
(define (validate-top-level-exports! who exports)
  (unless (and (list? exports)
               (andmap symbol? exports))
    (raise-argument-error who "(listof symbol?)" exports))
  (define duplicate (check-duplicates exports))
  (when duplicate
    (raise-arguments-error who
                           "duplicate exports are not supported by the top-level adapter"
                           "export" duplicate)))

;; validate-first-slice-lambda! : symbol? any/c exact-nonnegative-integer? (listof symbol?) -> void?
;;   Reject lowered values that cannot be invoked with instance plus export cells.
(define (validate-first-slice-lambda! who expr import-count exports)
  (match expr
    [`(lambda ,args ,_body ...)
     (unless (list? args)
       (raise-arguments-error who
                              "expected lowered first-slice lambda to have fixed arity"
                              "form" expr))
     (unless (andmap symbol? args)
       (raise-arguments-error who
                              "expected lowered first-slice lambda formals to be symbols"
                              "formals" args))
     (define duplicate-arg (check-duplicates args))
     (when duplicate-arg
       (raise-arguments-error who
                              "duplicate lowered first-slice lambda formals are not supported"
                              "formal" duplicate-arg))
     (define expected-arity (+ 1 import-count (length exports)))
     (define actual-arity   (length args))
     (unless (= actual-arity expected-arity)
       (raise-arguments-error who
                              "lowered first-slice lambda arity does not match imports and exports"
                              "expected arity" expected-arity
                              "actual arity" actual-arity
                              "import count" import-count
                              "exports" exports))]
    [_
     (raise-arguments-error who
                            "expected lowered first-slice value to be a lambda"
                            "form" expr)]))

;; validate-importss! : symbol? any/c -> void?
;;   Reject grouped import names that cannot become lexical bindings.
(define (validate-importss! who importss)
  (unless (and (list? importss)
               (for/and ([group (in-list importss)])
                 (and (list? group)
                      (andmap symbol? group))))
    (raise-argument-error who "(listof (listof symbol?))" importss))
  (define duplicate (check-duplicates (flatten-groups importss)))
  (when duplicate
    (raise-arguments-error who
                           "duplicate import names are not supported"
                           "import" duplicate)))

;; bind-import-cells : any/c (listof (listof symbol?)) exact-nonnegative-integer? -> any/c
;;   Introduce lexical imports by reading the corresponding module-variable cells.
(define (bind-import-cells expr importss import-count)
  (validate-importss! 'bind-import-cells importss)
  (define import-names (flatten-groups importss))
  (unless (= (length import-names) import-count)
    (raise-arguments-error 'bind-import-cells
                           "import metadata count does not match lowered lambda"
                           "metadata count" (length import-names)
                           "lambda import count" import-count
                           "imports" importss))
  (match expr
    [`(lambda ,args ,body ...)
     (define import-cell-args (take (cdr args) import-count))
     (define duplicate (check-duplicates (append import-names args)))
     (when duplicate
       (raise-arguments-error 'bind-import-cells
                              "import name collides with generated lambda argument"
                              "name" duplicate))
     `(lambda ,args
        ,@(for/list ([name (in-list import-names)]
                     [cell (in-list import-cell-args)])
            `(define ,name (module-variable-ref ,cell)))
        ,@body)]
    [_
     (raise-arguments-error 'bind-import-cells
                            "expected lowered first-slice value to be a lambda"
                            "form" expr)]))

;; fresh-internal-id : symbol? (listof symbol?) -> symbol?
;;   Build a deterministic helper name that does not collide with exports.
(define (fresh-internal-id base reserved)
  (let loop ([n 0])
    (define candidate
      (string->symbol (format "~a$~a" base n)))
    (if (memq candidate reserved)
        (loop (add1 n))
        candidate)))

;; generated-linklet-proc-id : (listof symbol?) -> symbol?
;;   Build an internal binding name for the lowered linklet procedure.
(define (generated-linklet-proc-id reserved)
  (fresh-internal-id 'webify-linklet-proc reserved))

;; generated-cell-id : exact-nonnegative-integer? (listof symbol?) -> symbol?
;;   Build an internal cell binding name for an export argument.
(define (generated-cell-id index reserved)
  (fresh-internal-id (string->symbol (format "webify-export-cell~a" index))
                     reserved))

;; validate-reserved-ids! : symbol? any/c -> void?
;;   Reject reserved-name lists that cannot be used for deterministic avoidance.
(define (validate-reserved-ids! who reserved)
  (unless (and (list? reserved)
               (andmap symbol? reserved))
    (raise-argument-error who "(listof symbol?)" reserved)))

;; flatten-groups : (listof list?) -> list?
;;   Flatten grouped import metadata while preserving group order.
(define (flatten-groups groups)
  (apply append groups))

;; all-cell-import-abis? : any/c -> boolean?
;;   Check whether import ABI metadata says every import is passed as a cell.
(define (all-cell-import-abis? imports-abis)
  (and (list? imports-abis)
       (for/and ([group (in-list imports-abis)])
         (and (list? group)
              (andmap not group)))))

;; first-slice-import-cell-args : (listof (listof symbol?)) (listof hash?) -> (listof any/c)
;;   Resolve grouped import metadata to the flat import-cell argument order.
(define (first-slice-import-cell-args importss import-cell-envs)
  (define who 'first-slice-import-cell-args)
  (unless (and (list? importss)
               (for/and ([group (in-list importss)])
                 (and (list? group)
                      (andmap symbol? group))))
    (raise-argument-error who "(listof (listof symbol?))" importss))
  (unless (and (list? import-cell-envs)
               (andmap hash? import-cell-envs))
    (raise-argument-error who "(listof hash?)" import-cell-envs))
  (unless (= (length importss) (length import-cell-envs))
    (raise-arguments-error who
                           "import cell environment count does not match import groups"
                           "expected count" (length importss)
                           "actual count" (length import-cell-envs)
                           "imports" importss))
  (apply
   append
   (for/list ([imports (in-list importss)]
              [env     (in-list import-cell-envs)])
     (for/list ([import (in-list imports)])
       (hash-ref env
                 import
                 (lambda ()
                   (raise-arguments-error who
                                          "missing import cell"
                                          "import" import
                                          "available imports" (hash-keys env))))))))

;; first-slice-top-level-helper-ids : (listof symbol?) [#:reserved (listof symbol?)] -> (listof symbol?)
;;   Return the internal helper ids that the adapter would reserve for exports.
(define (first-slice-top-level-helper-ids exports #:reserved [reserved '()])
  (define who 'first-slice-top-level-helper-ids)
  (validate-top-level-exports! who exports)
  (validate-reserved-ids! who reserved)
  (define reserved* (append exports reserved))
  (define proc-id (generated-linklet-proc-id reserved*))
  (define cell-ids
    (for/list ([_export (in-list exports)]
               [index   (in-naturals)])
      (generated-cell-id index (append (list proc-id) reserved*))))
  (cons proc-id cell-ids))

;; first-slice-top-level-export-cell-ids : (listof symbol?) [#:reserved (listof symbol?)] -> hasheq?
;;   Map export names to the internal cell ids that the adapter would create.
(define (first-slice-top-level-export-cell-ids exports #:reserved [reserved '()])
  (define cell-ids (cdr (first-slice-top-level-helper-ids exports #:reserved reserved)))
  (for/hasheq ([export  (in-list exports)]
               [cell-id (in-list cell-ids)])
    (values export cell-id)))

;; export-alias-enabled? : any/c symbol? -> boolean?
;;   Decide whether to define a top-level alias for an exported cell.
(define (export-alias-enabled? mode export)
  (cond
    [(procedure? mode) (and (mode export) #t)]
    [else             (and mode #t)]))

;; first-slice->top-level-datum : any/c (listof symbol?) -> any/c
;;   Wrap a lowered import-free first-slice lambda in top-level forms.
(define (first-slice->top-level-datum expr
                                      exports
                                      #:reserved [reserved '()]
                                      #:define-export-aliases? [define-export-aliases? #t])
  (first-slice->top-level-datum/imports
   expr
   '()
   exports
   #:reserved reserved
   #:define-export-aliases? define-export-aliases?))

;; first-slice->top-level-datum/imports : any/c (listof any/c) (listof symbol?) -> any/c
;;   Wrap a lowered first-slice lambda with explicit import argument expressions.
(define (first-slice->top-level-datum/imports expr
                                             import-args
                                             exports
                                             #:reserved [reserved '()]
                                             #:importss [importss #f]
                                             #:define-export-aliases? [define-export-aliases? #t])
  (unless (list? import-args)
    (raise-argument-error 'first-slice->top-level-datum/imports "list?" import-args))
  (validate-top-level-exports! 'first-slice->top-level-datum exports)
  (validate-reserved-ids! 'first-slice->top-level-datum reserved)
  (define clean-expr (strip-correlated expr))
  (validate-first-slice-lambda! 'first-slice->top-level-datum clean-expr (length import-args) exports)
  (define adapted-expr
    (if importss
        (bind-import-cells clean-expr importss (length import-args))
        clean-expr))
  (define helper-ids (first-slice-top-level-helper-ids exports #:reserved reserved))
  (define proc-id (car helper-ids))
  (define cell-ids (cdr helper-ids))
  `(begin
     (define ,proc-id ,adapted-expr)
     ,@(for/list ([cell-id (in-list cell-ids)]
                  [export  (in-list exports)])
         `(define ,cell-id (module-variable-make ',export)))
     (,proc-id (#%variable-reference) ,@import-args ,@cell-ids)
     ,@(for/list ([cell-id (in-list cell-ids)]
                  [export  (in-list exports)]
                  #:when (export-alias-enabled? define-export-aliases? export))
         `(define ,export (module-variable-ref ,cell-id)))
     (void)))

;; first-slice->top-level-syntax : any/c (listof symbol?) keyword-args -> syntax?
;;   Convert a lowered first-slice expression to top-level syntax for `comp`.
(define (first-slice->top-level-syntax expr
                                       exports
                                       #:reserved [reserved '()]
                                       #:define-export-aliases? [define-export-aliases? #t])
  (datum->syntax
   #f
   (first-slice->top-level-datum
    expr
    exports
    #:reserved reserved
    #:define-export-aliases? define-export-aliases?)))

;; webify-linklet-first-slice-top-level/imports : linklet (listof any/c) keyword-args ... -> syntax?
;;   Webify, lower, and wrap a first-slice linklet with explicit import cells.
(define (webify-linklet-first-slice-top-level/imports lk
                                                       import-args
                                                       #:reserved             [reserved '()]
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
  (unless (list? import-args)
    (raise-argument-error 'webify-linklet-first-slice-top-level/imports
                          "list?"
                          import-args))
  (define-values (expr importss exports new-import-keys imports-abis exports-info)
    (webify-linklet-first-slice
     lk
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
  (when new-import-keys
    (error 'webify-linklet-first-slice-top-level/imports
           "inlining-added import groups are not supported by the explicit-import adapter yet"))
  (unless (all-cell-import-abis? imports-abis)
    (error 'webify-linklet-first-slice-top-level/imports
           "value import ABIs are not supported by the explicit-import adapter yet"))
  (define import-count (length (flatten-groups importss)))
  (unless (= import-count (length import-args))
    (raise-arguments-error 'webify-linklet-first-slice-top-level/imports
                           "explicit import cell count does not match linklet imports"
                           "expected count" import-count
                           "actual count" (length import-args)
                           "imports" importss))
  (values (datum->syntax
           #f
           (first-slice->top-level-datum/imports
            expr
            import-args
            exports
            #:reserved reserved
            #:importss importss
            #:define-export-aliases? define-export-aliases?))
          importss
          exports
          exports-info))

;; webify-linklet-first-slice-top-level : linklet keyword-args ... -> syntax?
;;   Webify, lower, and wrap an import-free first-slice linklet as top-level forms.
(define (webify-linklet-first-slice-top-level lk
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
  (define-values (expr importss exports new-import-keys imports-abis exports-info)
    (webify-linklet-first-slice
     lk
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
  (unless (and (null? importss)
               (not new-import-keys)
               (null? imports-abis))
    (error 'webify-linklet-first-slice-top-level
           "imported linklets are not supported by the first top-level adapter yet"))
  (values (first-slice->top-level-syntax
           expr
           exports
           #:define-export-aliases? define-export-aliases?)
          exports
          exports-info))
