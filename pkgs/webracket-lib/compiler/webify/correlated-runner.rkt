#lang racket/base

(provide webify-correlated-top-level-import-groups
         webify-correlated-top-level-import-cell-envs
         webify-correlated-begin-directory-description?
         webify-correlated-begin-directory-keys
         webify-correlated-linklet-export-names
         webify-correlated-standalone-definition-linklet?
         webify-correlated-top-level-ref
         webify-correlated-linklet-first-slice
         webify-correlated-linklet-runner
         webify-run-correlated-top-level-linklet
         webify-run-correlated-top-level-linklet/exports
         webify-run-correlated-top-level-linklets/exports
         webify-run-correlated-begin-directory/exports)

(require "correlated-linklet.rkt"
         "first-slice.rkt"
         "module-variable.rkt"
         racket/list
         racket/match)

;; webify-correlated-top-level-import-groups : (listof (listof symbol?))
;;   Import groups emitted by the expander for simple phase-0 top-level linklets.
(define webify-correlated-top-level-import-groups
  '((.top-level-bind! .top-level-require!)
    (.mpi-vector .syntax-literals)
    (.namespace .phase .self .inspector .bulk-binding-registry .set-transformer!)))

;; webify-correlated-begin-directory-description? : any/c -> boolean?
;;   Recognize the observed `(begin definition expression)` directory summary.
(define (webify-correlated-begin-directory-description? v)
  (equal? (webify-correlated-begin-directory-keys v) '(data 0 1)))

;; webify-correlated-begin-directory-keys : any/c -> (or/c (listof any/c) #f)
;;   Extract directory keys from the expander-side probe summary format.
(define (webify-correlated-begin-directory-keys v)
  (and (list? v)
       (let ([entry (assoc 'directory-keys v)])
         (and entry
              (let ([keys (cadr entry)])
                (if (and (list? keys)
                         (member 'data keys)
                         (member 0 keys)
                         (member 1 keys))
                    '(data 0 1)
                    keys))))))

;; make-defined-module-variable : symbol? any/c -> module-variable?
;;   Create an initialized module-variable cell for a linklet import.
(define (make-defined-module-variable name value)
  (define cell (module-variable-make name))
  (module-variable-define! cell value 'constant)
  cell)

;; webify-correlated-linklet-export-names : any/c -> (listof symbol?)
;;   Extract export names from a correlated or plain linklet datum.
(define (webify-correlated-linklet-export-names lk)
  (match (or (webify-correlated-linklet->datum/catch lk) lk)
    [`(linklet ,_imports ,exports ,_body ...)
     (unless (and (list? exports) (andmap symbol? exports))
       (raise-argument-error 'webify-correlated-linklet-export-names
                             "(listof symbol?)"
                             exports))
     exports]
    [other
     (raise-argument-error 'webify-correlated-linklet-export-names
                           "linklet datum?"
                           other)]))

;; webify-correlated-standalone-definition-linklet? : any/c -> boolean?
;;   Recognize the current standalone top-level definition shape from the expander.
(define (webify-correlated-standalone-definition-linklet? lk)
  (match (or (webify-correlated-linklet->datum/catch lk) lk)
    [`(linklet ,imports ,exports ,body ...)
     (and (equal? imports webify-correlated-top-level-import-groups)
          (list? exports)
          (andmap symbol? exports)
          (for/or ([form (in-list body)])
            (match form
              [`(.top-level-bind! ,_id ,_mpi ,_pos ,_phase ,_namespace ,_name ,_transformer? ,_mode) #t]
              [`(begin ,subforms ...)
               (for/or ([subform (in-list subforms)])
                 (match subform
                   [`(.top-level-bind! ,_id ,_mpi ,_pos ,_phase ,_namespace ,_name ,_transformer? ,_mode) #t]
                   [_ #f]))]
              [_ #f])))]
    [_ #f]))

;; webify-correlated-top-level-ref : symbol? hash? (listof hash?) -> any/c
;;   Resolve a bridge top-level binding through its exported module-variable cell.
(define (webify-correlated-top-level-ref external-name binding-env export-envs)
  (define binding (hash-ref binding-env external-name #f))
  (define internal-name
    (and (list? binding)
         (let ([entry (assoc 'name (cdr binding))])
           (and entry (cadr entry)))))
  (unless internal-name
    (raise-arguments-error 'webify-correlated-top-level-ref
                           "no bridge top-level binding"
                           "external name" external-name))
  (define cell
    (for/or ([export-env (in-list export-envs)])
      (hash-ref export-env internal-name #f)))
  (unless cell
    (raise-arguments-error 'webify-correlated-top-level-ref
                           "no export cell for bridge top-level binding"
                           "external name" external-name
                           "internal name" internal-name))
  (module-variable-ref cell))

;; webify-correlated-top-level-import-cell-envs : [hash?] #:mpi-vector vector? #:syntax-literals vector? -> (listof hash?)
;;   Build import-cell environments for extracted top-level expander linklets.
(define (webify-correlated-top-level-import-cell-envs [top-level-env (make-hasheq)]
                                                      #:mpi-vector [mpi-vector '#()]
                                                      #:syntax-literals [syntax-literals '#()])
  (define (top-level-bind! id mpi pos phase namespace name transformer? mode)
    (hash-set! top-level-env
               id
               (list 'top-level-binding
                     (list 'mpi mpi)
                     (list 'position pos)
                     (list 'phase phase)
                     (list 'namespace namespace)
                     (list 'name name)
                     (list 'transformer? transformer?)
                     (list 'mode mode)))
    (void))
  (define (top-level-require! . _args)
    (void))
  (define (set-transformer! id value)
    (hash-set! top-level-env id value)
    (void))
  (list
   (hasheq '.top-level-bind!    (make-defined-module-variable '.top-level-bind! top-level-bind!)
           '.top-level-require! (make-defined-module-variable '.top-level-require! top-level-require!))
   (hasheq '.mpi-vector         (make-defined-module-variable '.mpi-vector mpi-vector)
           '.syntax-literals    (make-defined-module-variable '.syntax-literals syntax-literals))
   (hasheq '.namespace          (make-defined-module-variable '.namespace 'webify-namespace)
           '.phase              (make-defined-module-variable '.phase 0)
           '.self               (make-defined-module-variable '.self 'webify-self)
           '.inspector          (make-defined-module-variable '.inspector #f)
           '.bulk-binding-registry
           (make-defined-module-variable '.bulk-binding-registry (make-hasheq))
           '.set-transformer!   (make-defined-module-variable '.set-transformer! set-transformer!))))

;; webify-correlated-linklet-first-slice : any/c keyword-args ... -> values
;;   Extract a correlated-linklet-shaped value when needed, then lower it.
(define (webify-correlated-linklet-first-slice lk
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
  (webify-linklet-first-slice
   (or (webify-correlated-linklet->datum/catch lk) lk)
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

;; webify-correlated-linklet-runner : procedure? (listof hash?) -> procedure?
;;   Adapt a lowered no-export phase-0 linklet procedure to a thunk.
(define (webify-correlated-linklet-runner proc import-cell-envs)
  (define import-args
    (apply
     append
     (for/list ([env   (in-list import-cell-envs)]
                [names (in-list webify-correlated-top-level-import-groups)])
       (for/list ([name (in-list names)])
         (hash-ref env name)))))
  (lambda ()
    (apply proc 'webify-correlated-top-level-instance import-args)))

;; webify-run-correlated-top-level-linklet : procedure? [hash?] -> any/c
;;   Run a lowered real expander top-level expression linklet with default imports.
(define (webify-run-correlated-top-level-linklet proc [top-level-env (make-hasheq)])
  ((webify-correlated-linklet-runner
    proc
    (webify-correlated-top-level-import-cell-envs top-level-env))))

;; webify-run-correlated-top-level-linklet/exports : procedure? (listof symbol?) [hash?] keyword-args ... -> values
;;   Run a lowered top-level linklet that has export cells, returning result, exports, and bindings.
(define (webify-run-correlated-top-level-linklet/exports proc
                                                         exports
                                                         [top-level-env (make-hasheq)]
                                                         #:mpi-vector [mpi-vector '#()]
                                                         #:syntax-literals [syntax-literals '#()])
  (define import-cell-envs
    (webify-correlated-top-level-import-cell-envs top-level-env
                                                 #:mpi-vector mpi-vector
                                                 #:syntax-literals syntax-literals))
  (define export-env
    (for/hasheq ([name (in-list exports)])
      (values name (module-variable-make name))))
  (define import-args
    (apply
     append
     (for/list ([env   (in-list import-cell-envs)]
                [names (in-list webify-correlated-top-level-import-groups)])
       (for/list ([name (in-list names)])
         (hash-ref env name)))))
  (define export-args
    (for/list ([name (in-list exports)])
      (hash-ref export-env name)))
  (define result
    (apply proc 'webify-correlated-top-level-instance
           (append import-args export-args)))
  (values result export-env top-level-env))

;; webify-run-correlated-top-level-linklets/exports : list? [hash?] keyword-args ... -> values
;;   Run lowered top-level linklets in order, preserving the shared binding table.
(define (webify-run-correlated-top-level-linklets/exports steps
                                                          [top-level-env (make-hasheq)]
                                                          #:mpi-vector [mpi-vector '#()]
                                                          #:syntax-literals [syntax-literals '#()])
  (define export-envs '())
  (define last-result (void))
  (for ([step (in-list steps)])
    (match-define (list proc exports) step)
    (define-values (result export-env _binding-env)
      (webify-run-correlated-top-level-linklet/exports
       proc
       exports
       top-level-env
       #:mpi-vector mpi-vector
       #:syntax-literals syntax-literals))
    (set! last-result result)
    (set! export-envs (cons export-env export-envs)))
  (values last-result (reverse export-envs) top-level-env))

;; webify-run-correlated-begin-directory/exports : any/c list? [hash?] keyword-args ... -> values
;;   Run lowered linklets for an observed begin-directory summary in data-key order.
(define (webify-run-correlated-begin-directory/exports directory-summary
                                                       steps
                                                       [top-level-env (make-hasheq)]
                                                       #:mpi-vector [mpi-vector '#()]
                                                       #:syntax-literals [syntax-literals '#()])
  (unless (webify-correlated-begin-directory-description? directory-summary)
    (raise-argument-error 'webify-run-correlated-begin-directory/exports
                          "webify-correlated-begin-directory-description?"
                          directory-summary))
  (unless (= (length steps) 2)
    (raise-arguments-error 'webify-run-correlated-begin-directory/exports
                           "expected one definition step and one expression step"
                           "steps" steps))
  (webify-run-correlated-top-level-linklets/exports
   steps
   top-level-env
   #:mpi-vector mpi-vector
   #:syntax-literals syntax-literals))
