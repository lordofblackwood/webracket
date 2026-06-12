#lang racket/base

(provide strip-correlated
         first-slice-import-args
         first-slice-import-cell-args
         first-slice-top-level-helper-ids
         first-slice-top-level-export-cell-ids
         first-slice-top-level-export-value-ids
         first-slice->top-level-datum
         first-slice->top-level-datum/imports
         first-slice->top-level-syntax
         webify-linklet-first-slice-top-level/imports
         webify-linklet-first-slice-top-level)

(require racket/list
         racket/match
         "bridge-stats.rkt"
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

;; validate-imports-abis! : symbol? any/c (listof (listof symbol?)) -> void?
;;   Reject import ABI metadata that does not match grouped import names.
(define (validate-imports-abis! who imports-abis importss)
  (define valid?
    (and (list? imports-abis)
         (= (length imports-abis) (length importss))
         (for/and ([group      (in-list imports-abis)]
                   [name-group (in-list importss)])
           (and (list? group)
                (= (length group) (length name-group))))))
  (unless valid?
    (raise-arguments-error who
                           "import ABI metadata does not match grouped imports"
                           "imports-abis" imports-abis
                           "imports" importss)))

;; default-imports-abis : (listof (listof symbol?)) -> (listof (listof #f))
;;   Treat every import as a cell-backed binding when no ABI metadata is present.
(define (default-imports-abis importss)
  (for/list ([group (in-list importss)])
    (for/list ([name (in-list group)])
      #f)))

;; bind-imports : any/c (listof (listof symbol?)) any/c exact-nonnegative-integer? -> any/c
;;   Introduce lexical imports from either direct values or module-variable cells.
(define (bind-imports expr importss imports-abis import-count)
  (validate-importss! 'bind-imports importss)
  (validate-imports-abis! 'bind-imports imports-abis importss)
  (define import-names (flatten-groups importss))
  (define import-abis  (flatten-groups imports-abis))
  (define direct-import-count
    (for/sum ([abi (in-list import-abis)])
      (if abi 1 0)))
  (define cell-import-count
    (- (length import-abis) direct-import-count))
  (webify-bridge-stats-inc! 'bridge-direct-import-count direct-import-count)
  (webify-bridge-stats-inc! 'bridge-import-cell-count cell-import-count)
  (webify-bridge-stats-inc! 'bridge-cell-elision-count direct-import-count)
  (unless (= (length import-names) import-count)
    (raise-arguments-error 'bind-imports
                           "import metadata count does not match lowered lambda"
                           "metadata count" (length import-names)
                           "lambda import count" import-count
                           "imports" importss))
  (match expr
    [`(lambda ,args ,body ...)
     (define import-args (take (cdr args) import-count))
     (define duplicate (check-duplicates (append import-names args)))
     (when duplicate
       (raise-arguments-error 'bind-imports
                              "import name collides with generated lambda argument"
                              "name" duplicate))
     `(lambda ,args
        ,@(for/list ([name (in-list import-names)]
                     [arg  (in-list import-args)]
                     [abi  (in-list import-abis)])
            `(define ,name ,(if abi
                                arg
                                `(module-variable-ref ,arg))))
        ,@body)]
    [_
     (raise-arguments-error 'bind-imports
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

;; generated-value-id : exact-nonnegative-integer? (listof symbol?) -> symbol?
;;   Build an internal lexical binding name for one exported value.
(define (generated-value-id index reserved)
  (fresh-internal-id (string->symbol (format "webify-export-value~a" index))
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

;; first-slice-import-args : (listof (listof symbol?)) (listof hash?) -> (listof any/c)
;;   Resolve grouped import metadata to the flat explicit-import argument order.
(define (first-slice-import-args importss import-envs)
  (define who 'first-slice-import-args)
  (unless (and (list? importss)
               (for/and ([group (in-list importss)])
                 (and (list? group)
                      (andmap symbol? group))))
    (raise-argument-error who "(listof (listof symbol?))" importss))
  (unless (and (list? import-envs)
               (andmap hash? import-envs))
    (raise-argument-error who "(listof hash?)" import-envs))
  (unless (= (length importss) (length import-envs))
    (raise-arguments-error who
                           "import argument environment count does not match import groups"
                           "expected count" (length importss)
                           "actual count" (length import-envs)
                           "imports" importss))
  (apply
   append
   (for/list ([imports (in-list importss)]
              [env     (in-list import-envs)])
     (for/list ([import (in-list imports)])
       (hash-ref env
                 import
                 (lambda ()
                   (raise-arguments-error who
                                          "missing import argument"
                                          "import" import
                                          "available imports" (hash-keys env))))))))

;; first-slice-import-cell-args : (listof (listof symbol?)) (listof hash?) -> (listof any/c)
;;   Backward-compatible alias for explicit import argument resolution.
(define first-slice-import-cell-args
  first-slice-import-args)

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

;; first-slice-top-level-export-value-ids : (listof symbol?) [#:reserved (listof symbol?)] -> hasheq?
;;   Map export names to internal lexical bindings that cache exported values.
(define (first-slice-top-level-export-value-ids exports #:reserved [reserved '()])
  (define helper-ids (first-slice-top-level-helper-ids exports #:reserved reserved))
  (define reserved* (append exports reserved helper-ids))
  (define value-ids
    (for/list ([_export (in-list exports)]
               [index   (in-naturals)])
      (generated-value-id index reserved*)))
  (for/hasheq ([export   (in-list exports)]
               [value-id (in-list value-ids)])
    (values export value-id)))

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
                                             #:imports-abis [imports-abis #f]
                                             #:define-export-aliases? [define-export-aliases? #t])
  (unless (list? import-args)
    (raise-argument-error 'first-slice->top-level-datum/imports "list?" import-args))
  (validate-top-level-exports! 'first-slice->top-level-datum exports)
  (validate-reserved-ids! 'first-slice->top-level-datum reserved)
  (define clean-expr (strip-correlated expr))
  (validate-first-slice-lambda! 'first-slice->top-level-datum clean-expr (length import-args) exports)
  (define adapted-expr
    (if importss
        (bind-imports clean-expr
                      importss
                      (or imports-abis
                          (default-imports-abis importss))
                      (length import-args))
        clean-expr))
  (define helper-ids (first-slice-top-level-helper-ids exports #:reserved reserved))
  (define proc-id (car helper-ids))
  (define cell-ids (cdr helper-ids))
  (define value-id-map
    (first-slice-top-level-export-value-ids exports #:reserved reserved))
  (define value-ids
    (for/list ([export (in-list exports)])
      (hash-ref value-id-map export)))
  (webify-bridge-stats-inc! 'bridge-export-cell-count (length cell-ids))
  (webify-bridge-stats-inc! 'bridge-module-variable-make-count (length cell-ids))
  `(begin
     (define ,proc-id ,adapted-expr)
     ,@(for/list ([cell-id (in-list cell-ids)]
                  [export  (in-list exports)])
         `(define ,cell-id (module-variable-make ',export)))
     (,proc-id (#%variable-reference) ,@import-args ,@cell-ids)
     ,@(for/list ([cell-id   (in-list cell-ids)]
                  [value-id  (in-list value-ids)])
         `(define ,value-id (module-variable-ref ,cell-id)))
     ,@(for/list ([cell-id (in-list cell-ids)]
                  [export  (in-list exports)]
                  [value-id (in-list value-ids)]
                  #:when (export-alias-enabled? define-export-aliases? export))
         `(define ,export ,value-id))
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
            #:imports-abis imports-abis
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
