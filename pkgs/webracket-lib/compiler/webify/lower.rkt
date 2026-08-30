#lang racket/base

(require "gensym.rkt"
         "match.rkt"
         "wrap.rkt")

(provide lower-module-variable-ops
         simplify-compatibility-apps
         lower-simple-parameters
         lower-trivial-continuation-prompts
         lower-trivial-continuation-marks
         lower-unsafe-undefined-checks
         lower-hash-iteration-ops
         simplify-trivial-module-prompts
         lower-module-first-slice
         schemify-module-variable-free?
         assert-schemify-module-variable-free
         first-slice-unsupported-free?
         assert-first-slice-unsupported-free
         module-prompt-free?
         assert-module-prompt-free)

;; lower-module-variable-ops : any/c -> any/c
;;   Lower schemify-shaped module variable operations to WebRacket helper forms.
(define (lower-module-variable-ops v)
  (with-deterministic-gensym
    ;; lower-module-variable-constance-check : any/c -> any/c
    ;;   Guard constant checks so value-backed imports stay plain values.
    (define (lower-module-variable-constance-check cell)
      (define lowered-cell (lower cell))
      (define cell-id (deterministic-gensym 'module-variable-constance-cell))
      `(let ([,cell-id ,lowered-cell])
         (if (if (module-variable? ,cell-id)
                 (module-variable-constance ,cell-id)
                 (if (eq? ,cell-id 'mutable) #f #t))
             #t
             #f)))

    (define (lower v)
      (reannotate
       v
       (match v
       [`(make-internal-variable ,name)
        `(module-variable-make ,(lower name))]
       [`(variable-ref ,cell)
        `(module-variable-ref ,(lower cell))]
       [`(variable-ref/no-check ,cell)
        `(module-variable-ref/no-check ,(lower cell))]
       [`(variable-set! ,cell ,rhs)
        `(module-variable-set! ,(lower cell) ,(lower rhs))]
       [`(variable-set!/check-undefined ,cell ,rhs)
        `(module-variable-set!/check-undefined! ,(lower cell) ,(lower rhs))]
       [`(variable-set!/define ,cell ,rhs ,constance)
        `(module-variable-define! ,(lower cell) ,(lower rhs) ,(lower constance))]
       [`(set-consistent-variables!/define ,cells ,rhss)
        `(module-variables-define-consistent! ,(lower cells) ,(lower rhss))]
       [`(variable-reference-constant?
          (make-instance-variable-reference ,_instance ,cell))
        (lower-module-variable-constance-check cell)]
       [`(variable-reference-constant?
          (module-variable-reference ,_instance ,cell))
        (lower-module-variable-constance-check cell)]
       [`(variable-reference-from-unsafe?
          (make-instance-variable-reference ,_instance ,_cell))
        #f]
       [`(variable-reference-from-unsafe?
          (module-variable-reference ,_instance ,_cell))
        #f]
       [`(make-instance-variable-reference ,instance ,cell)
        `(module-variable-reference ,(lower instance) ,(lower cell))]
       [`(call-with-module-prompt ,thunk . ,args)
        `(module-call-with-prompt ,(lower thunk) . ,(lower-list args))]
       [`(#%app ,rator . ,args)
        `(,(lower rator) . ,(lower-list args))]
       [`(lambda ,formals . ,body)
        `(lambda ,formals . ,(lower-list body))]
       [`(case-lambda [,formalss . ,bodyss] ...)
        `(case-lambda ,@(for/list ([formals (in-list formalss)]
                                   [body (in-list bodyss)])
                          `[,formals . ,(lower-list body)]))]
       [`(quote ,_)
        v]
       [`(,_ . ,_)
        (lower-list v)]
         [`,_
          v])))

    ;; lower-list : list? -> list?
    ;;   Lower each wrapped list element.
    (define (lower-list l)
      (cond
        [(wrap-null? l) '()]
        [(wrap-pair? l) (cons (lower (wrap-car l))
                              (lower-list (wrap-cdr l)))]
        [else (lower l)]))

    (lower v)))

;; lower-trivial-continuation-prompts : any/c -> any/c
;;   Lower prompt allocation/use needed by non-error startup paths.
(define (lower-trivial-continuation-prompts v)
  (define (lower v)
    (reannotate
     v
     (match v
       [`(make-continuation-prompt-tag)
        ''webracket-continuation-prompt-tag]
       [`(make-continuation-prompt-tag ,name)
        (lower name)]
      [`(call-with-continuation-prompt ,thunk . ,args)
       ;; WebRacket has no prompt/control substrate yet, but Racket still
       ;; applies the prompt thunk to arguments after the tag and handler.
       ;; Preserving those arguments keeps expander helper thunks arity-correct.
       (define thunk-args
         (if (>= (length args) 2)
             (cddr args)
             '()))
       `(,(lower thunk) ,@(map lower thunk-args))]
       [`(unsafe-make-place-local ,value)
        `(box ,(lower value))]
       [`(unsafe-place-local-ref ,cell)
        `(unbox ,(lower cell))]
       [`(unsafe-place-local-set! ,cell ,value)
        `(set-box! ,(lower cell) ,(lower value))]
       [`(lambda ,formals . ,body)
        `(lambda ,formals . ,(lower-list body))]
       [`(case-lambda [,formalss . ,bodyss] ...)
        `(case-lambda ,@(for/list ([formals (in-list formalss)]
                                   [body (in-list bodyss)])
                          `[,formals . ,(lower-list body)]))]
       [`(quote ,_)
        v]
       [`(,_ . ,_)
        (lower-list v)]
       [`,_
        v])))

  ;; lower-list : list? -> list?
  ;;   Lower each wrapped list element.
  (define (lower-list l)
    (cond
      [(wrap-null? l) '()]
      [(wrap-pair? l) (cons (lower (wrap-car l))
                            (lower-list (wrap-cdr l)))]
      [else (lower l)]))

  (lower v))

;; simplify-compatibility-apps : any/c -> any/c
;;   Erase Schemify compatibility application markers for normal calls.
(define (simplify-compatibility-apps v)
  (define (simplify v)
    (reannotate
     v
     (match v
       [`(#%app ,rator . ,args)
        `(,(simplify rator) . ,(simplify-list args))]
       [`(#%app/no-return ,rator . ,args)
        ;; Chez uses #%app/no-return as a control-flow/type-analysis marker:
        ;; the call is operationally an application, but its result type is
        ;; bottom. WebRacket does not currently use this marker, so the bridge
        ;; erases it for now. Reintroduce a real marker/helper if WebRacket grows
        ;; bottom-aware optimization, better unreachable-code validation, or
        ;; precise source-location/error reporting for paths expected to abort.
        `(,(simplify rator) . ,(simplify-list args))]
       [`(lambda ,formals . ,body)
        `(lambda ,formals . ,(simplify-list body))]
       [`(case-lambda [,formalss . ,bodyss] ...)
        `(case-lambda ,@(for/list ([formals (in-list formalss)]
                                   [body (in-list bodyss)])
                          `[,formals . ,(simplify-list body)]))]
       [`(quote ,_)
        v]
       [`(,_ . ,_)
        (simplify-list v)]
       [`,_
        v])))

  ;; simplify-list : list? -> list?
  ;;   Simplify each wrapped list element.
  (define (simplify-list l)
    (cond
      [(wrap-null? l) '()]
      [(wrap-pair? l) (cons (simplify (wrap-car l))
                            (simplify-list (wrap-cdr l)))]
      [else (simplify l)]))

  (simplify v))

;; lower-simple-parameters : any/c -> any/c
;;   Lower make-parameter calls to a local mutable closure without parameterize.
(define (lower-simple-parameters v)
  (with-deterministic-gensym
    (define (parameter-form init guard)
      (define cell (deterministic-gensym 'parameter-cell))
      (define guard-var (deterministic-gensym 'parameter-guard))
      (define value (deterministic-gensym 'parameter-value))
      `(let ([,cell ,init]
             [,guard-var ,guard])
         (case-lambda
           [() ,cell]
           [(,value)
            (set! ,cell (if ,guard-var (,guard-var ,value) ,value))
            (void)])))

    (define (lower v)
      (reannotate
       v
       (match v
       [`(make-parameter ,init)
        (parameter-form (lower init) #f)]
       [`(make-parameter ,init ,guard)
        (parameter-form (lower init) (lower guard))]
       [`(make-parameter ,init ,guard ,_name)
        (parameter-form (lower init) (lower guard))]
       [`(make-parameter ,init ,guard ,_name ,_realm)
        (parameter-form (lower init) (lower guard))]
       [`(lambda ,formals . ,body)
        `(lambda ,formals . ,(lower-list body))]
       [`(case-lambda [,formalss . ,bodyss] ...)
        `(case-lambda ,@(for/list ([formals (in-list formalss)]
                                   [body (in-list bodyss)])
                          `[,formals . ,(lower-list body)]))]
       [`(quote ,_)
        v]
       [`(,_ . ,_)
        (lower-list v)]
         [`,_
          v])))

    ;; lower-list : list? -> list?
    ;;   Lower each wrapped list element.
    (define (lower-list l)
      (cond
        [(wrap-null? l) '()]
        [(wrap-pair? l) (cons (lower (wrap-car l))
                              (lower-list (wrap-cdr l)))]
        [else (lower l)]))

    (lower v)))

;; lower-hash-iteration-ops : any/c -> any/c
;;   Lower stdlib hash iteration names to runtime primitives for no-stdlib slices.
(define (lower-hash-iteration-ops v)
  (define (lower-rator rator)
    (case (unwrap rator)
      [(hash-iterate-first)     'mutable-hash-iterate-first]
      [(hash-iterate-next)      'mutable-hash-iterate-next]
      [(hash-iterate-key)       'mutable-hash-iterate-key]
      [(hash-iterate-value)     'mutable-hash-iterate-value]
      [(hash-iterate-pair)      'mutable-hash-iterate-pair]
      [(hash-iterate-key+value) 'mutable-hash-iterate-key+value]
      [else                     (lower rator)]))

  (define (lower v)
    (reannotate
     v
     (match v
       [`(hash-iterate-key ,ht ,pos)
        `(mutable-hash-iterate-key ,(lower ht) ,(lower pos) unsafe-undefined)]
       [`(hash-iterate-value ,ht ,pos)
        `(mutable-hash-iterate-value ,(lower ht) ,(lower pos) unsafe-undefined)]
       [`(hash-iterate-pair ,ht ,pos)
        `(mutable-hash-iterate-pair ,(lower ht) ,(lower pos) unsafe-undefined)]
       [`(hash-iterate-key+value ,ht ,pos)
        `(mutable-hash-iterate-key+value ,(lower ht) ,(lower pos) unsafe-undefined)]
      [`(quote ,_)
       v]
       [`(,rator . ,args)
        `(,(lower-rator rator) . ,(lower-list args))]
       [`,_
        v])))

  ;; lower-list : list? -> list?
  ;;   Lower each wrapped list element.
  (define (lower-list l)
    (cond
      [(wrap-null? l) '()]
      [(wrap-pair? l) (cons (lower (wrap-car l))
                            (lower-list (wrap-cdr l)))]
      [else (lower l)]))

  (lower v))

;; lower-unsafe-undefined-checks : any/c -> any/c
;;   Lower Schemify unsafe-undefined guards to explicit runtime checks.
(define (lower-unsafe-undefined-checks v)
  (with-deterministic-gensym
    (define (guard v sym message)
      (define val (deterministic-gensym 'unsafe-undefined-val))
      `(let ([,val ,(lower v)])
         (if (eq? ,val unsafe-undefined)
             (raise-arguments-error ,(lower sym) ,message)
             ,val)))

    (define (lower v)
      (reannotate
       v
       (match v
       [`(check-not-unsafe-undefined ,v ,sym)
        (guard v sym "undefined; use before initialization")]
       [`(check-not-unsafe-undefined/assign ,v ,sym)
        (guard v sym "undefined; assignment before initialization")]
       [`(lambda ,formals . ,body)
        `(lambda ,formals . ,(lower-list body))]
       [`(case-lambda [,formalss . ,bodyss] ...)
        `(case-lambda ,@(for/list ([formals (in-list formalss)]
                                   [body (in-list bodyss)])
                          `[,formals . ,(lower-list body)]))]
       [`(quote ,_)
        v]
       [`(,_ . ,_)
        (lower-list v)]
         [`,_
          v])))

    ;; lower-list : list? -> list?
    ;;   Lower each wrapped list element.
    (define (lower-list l)
      (cond
        [(wrap-null? l) '()]
        [(wrap-pair? l) (cons (lower (wrap-car l))
                              (lower-list (wrap-cdr l)))]
        [else (lower l)]))

    (lower v)))

;; simplify-trivial-module-prompts : any/c -> any/c
;;   Erase direct module-prompt markers that do not need prompt behavior.
(define (simplify-trivial-module-prompts v)
  ;; simplify-metadata-prompt : any/c list? list? list? -> any/c
  ;;   Rewrite direct module-result assignment prompts to explicit cell writes.
  (define (simplify-metadata-prompt rhs ids constances cells)
    (unless (= (length ids) (length constances) (length cells))
      (error 'webify "module prompt metadata arity mismatch"))
    (if (= (length ids) 1)
        `(module-variable-define! ,(simplify (car cells)) ,(simplify rhs) ',(car constances))
        `(let-values ([(,@ids) ,(simplify rhs)])
           ,@(for/list ([id (in-list ids)]
                        [constance (in-list constances)]
                        [cell (in-list cells)])
               `(module-variable-define! ,(simplify cell) ,id ',constance))
           (void))))

  (define (simplify v)
    (reannotate
     v
     (match v
       [`(module-call-with-prompt (lambda () ,body) '(,id) '(,constance) ,cell)
        (simplify-metadata-prompt body (list id) (list constance) (list cell))]
       [`(module-call-with-prompt (lambda () ,body0 ,bodys ...) '(,id) '(,constance) ,cell)
        `(module-variable-define! ,(simplify cell) (let () ,@(simplify-list (cons body0 bodys))) ',constance)]
       [`(module-call-with-prompt (lambda () ,body) '(,ids ...) '(,constances ...) ,cells ...)
        (simplify-metadata-prompt body ids constances cells)]
       [`(module-call-with-prompt (lambda () ,body))
        (simplify body)]
       [`(module-call-with-prompt (lambda () ,body0 ,bodys ...))
        `(let () ,@(simplify-list (cons body0 bodys)))]
       [`(lambda ,formals . ,body)
        `(lambda ,formals . ,(simplify-list body))]
       [`(case-lambda [,formalss . ,bodyss] ...)
        `(case-lambda ,@(for/list ([formals (in-list formalss)]
                                   [body (in-list bodyss)])
                          `[,formals . ,(simplify-list body)]))]
       [`(quote ,_)
        v]
       [`(,_ . ,_)
        (simplify-list v)]
       [`,_
        v])))

  ;; simplify-list : list? -> list?
  ;;   Simplify each wrapped list element.
  (define (simplify-list l)
    (cond
      [(wrap-null? l) '()]
      [(wrap-pair? l) (cons (simplify (wrap-car l))
                            (simplify-list (wrap-cdr l)))]
      [else (simplify l)]))

  (simplify v))

;; lower-module-first-slice : any/c -> any/c
;;   Lower the currently supported module-variable subset and reject prompts.
(define (lower-module-first-slice v)
  (assert-module-prompt-free
   (assert-schemify-module-variable-free
    (assert-first-slice-unsupported-free
     (lower-trivial-continuation-marks
      (simplify-trivial-module-prompts
       (lower-unsafe-undefined-checks
        (lower-hash-iteration-ops
         (lower-trivial-continuation-prompts
          (lower-simple-parameters
           (simplify-compatibility-apps
            (lower-module-variable-ops v))))))))))))

;; lower-trivial-continuation-marks : any/c -> any/c
;;   Erase continuation marks while preserving key/value effects and order.
(define (lower-trivial-continuation-marks v)
  (with-deterministic-gensym
    (define (lower v)
      (match v
      [`(with-continuation-mark* ,_mode parameterization-key ,val ,body)
       `(call-with-parameterization
         ,(lower val)
         (lambda () ,(lower body)))]
        [`(with-continuation-mark* ,_mode ,key ,val ,body)
         (define key-id (deterministic-gensym 'ignored-continuation-mark-key))
         (define val-id (deterministic-gensym 'ignored-continuation-mark-val))
       `(let ([,key-id ,(lower key)])
          (let ([,val-id ,(lower val)])
            ,(lower body)))]
      [`(quote ,_)
       v]
      [`(,rator . ,_)
       (lower-list v)]
        [`,_
         v]))

    ;; lower-list : list? -> list?
    ;;   Lower each element in a possibly wrapped list.
    (define (lower-list l)
      (cond
        [(wrap-null? l) '()]
        [(wrap-pair? l) (cons (lower (wrap-car l))
                              (lower-list (wrap-cdr l)))]
        [else (lower l)]))

    (lower v)))

;; schemify-module-variable-free? : any/c -> boolean?
;;   Check that schemify-shaped module variable forms have been lowered.
(define (schemify-module-variable-free? v)
  (let loop ([v v])
    (match v
      [`(quote ,_)
       #t]
      [`(,rator . ,_)
       (and (not (schemify-module-variable-rator? (unwrap rator)))
            (walk-list loop v))]
      [`,_
       #t])))

;; assert-schemify-module-variable-free : any/c -> any/c
;;   Reject output that still contains pre-lowering module variable forms.
(define (assert-schemify-module-variable-free v)
  (unless (schemify-module-variable-free? v)
    (error 'webify "schemify module variable forms remain after lowering"))
  v)

;; module-prompt-free? : any/c -> boolean?
;;   Check whether v has no lowered module prompt marker.
(define (module-prompt-free? v)
  (let loop ([v v])
    (match v
      [`(module-call-with-prompt . ,_)
       #f]
      [`(quote ,_)
       #t]
      [`(,_ . ,_)
       (walk-list loop v)]
      [`,_
       #t])))

;; assert-module-prompt-free : any/c -> any/c
;;   Reject lowered output that still requires unsupported prompt semantics.
(define (assert-module-prompt-free v)
  (unless (module-prompt-free? v)
    (error 'webify "module prompts are not supported by WebRacket yet"))
  v)

;; first-slice-unsupported-free? : any/c -> boolean?
;;   Check for schemify compatibility forms outside the first module slice.
(define (first-slice-unsupported-free? v)
  (not (first-slice-unsupported-rator v)))

;; first-slice-unsupported-rator : any/c -> (or/c symbol? #f)
;;   Return the first unsupported compatibility form rator, if any.
(define (first-slice-unsupported-rator v)
  (let loop ([v v])
    (define (loop-list l)
      (cond
        [(wrap-null? l) #f]
        [(wrap-pair? l) (or (loop (wrap-car l))
                            (loop-list (wrap-cdr l)))]
        [else (loop l)]))
    (match v
      [`(quote ,_)
       #f]
      [`(,rator . ,_)
       (or (and (first-slice-unsupported-rator? (unwrap rator))
                (unwrap rator))
           (loop-list v))]
      [`,_
       #f])))

;; assert-first-slice-unsupported-free : any/c -> any/c
;;   Reject known compatibility forms that the first slice cannot lower.
(define (assert-first-slice-unsupported-free v)
  (define bad (first-slice-unsupported-rator v))
  (when bad
    (error 'webify "unsupported webify compatibility form remains after lowering: ~a" bad))
  v)

;; schemify-module-variable-rator? : any/c -> boolean?
;;   Recognize the schemify helper forms handled by this lowering slice.
(define (schemify-module-variable-rator? v)
  (memq v '(make-internal-variable
            variable-ref
            variable-ref/no-check
            variable-set!
            variable-set!/check-undefined
            variable-set!/define
            set-consistent-variables!/define
            make-instance-variable-reference
            call-with-module-prompt)))

;; first-slice-unsupported-rator? : any/c -> boolean?
;;   Recognize compatibility forms that need later WebRacket support/lowering.
(define (first-slice-unsupported-rator? v)
  (memq v '(#%app
            #%app/value
            make-record-type-descriptor
            make-record-constructor-descriptor
            record-constructor
            record-predicate
            record-accessor
            record-mutator
            make-struct-type-install-properties
            structure-type-lookup-prefab-uid
            struct-type-constructor-add-guards
            #%nongenerative-uid
            #%struct-constructor
            #%struct-predicate
            #%struct-field-accessor
            #%struct-field-mutator
            unsafe-struct
            impersonate-ref
            impersonate-set!
            #%struct-ref-error
            #%struct-set!-error)))

;; walk-list : (any/c -> boolean?) any/c -> boolean?
;;   Apply pred to each element in a wrapped list.
(define (walk-list pred l)
  (cond
    [(wrap-null? l) #t]
    [(wrap-pair? l) (and (pred (wrap-car l))
                         (walk-list pred (wrap-cdr l)))]
    [else (pred l)]))
