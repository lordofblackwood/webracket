#lang racket/base

(provide test-prim-knowns
         test-primitives
         run-first-slice-top-level
         run-first-slice-top-level/imports
         compose-linklet-first-slices
         compose-module-registry
         compose-module-registry/composition
         compose-module-registry/roots
         compose-module-registry/roots/composition
         compose-module-registry/roots+observations
         wat-string
         run-webracket
         write-datum-program!
         append-top-level-form
         begin-body
         normalize-symbols
         webracket-rkt
         comp
         webify-module-instances-export-cell-id
         (all-from-out "known.rkt")
         (all-from-out "module-adapter.rkt")
         (all-from-out "module-composer.rkt")
         (all-from-out "module-instance.rkt")
         (all-from-out "module-loader.rkt")
         (all-from-out "module-registry.rkt"))

(require racket/match
         racket/file
         racket/path
         racket/runtime-path
         racket/system
         (only-in "../compiler.rkt" comp)
         "known.rkt"
         "module-adapter.rkt"
         "module-composer.rkt"
         "module-instance.rkt"
         "module-loader.rkt"
         "module-registry.rkt")

(define-runtime-path webracket-rkt "../webracket.rkt")

;; test-prim-knowns : hash?
;;   Minimal primitive facts for first-slice top-level adapter tests.
(define test-prim-knowns
  (hasheq '+ (known-procedure/folding (procedure-arity-mask +))))

;; test-primitives : hash?
;;   Runtime values used by primitive constant folding.
(define test-primitives
  (hasheq '+ +))

;; run-first-slice-top-level : any/c -> values
;;   Webify, lower, and top-level-wrap a hand-written linklet.
(define (run-first-slice-top-level lk)
  (webify-linklet-first-slice-top-level
   lk
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; run-first-slice-top-level/imports : any/c (listof any/c) #:reserved (listof symbol?) -> values
;;   Webify, lower, and top-level-wrap a hand-written linklet with import cells.
(define (run-first-slice-top-level/imports lk import-args #:reserved [reserved '()])
  (webify-linklet-first-slice-top-level/imports
   lk
   import-args
   #:reserved             reserved
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; compose-linklet-first-slices : (listof webify-linklet-slice-spec?) #:tail (listof any/c) -> values
;;   Compose hand-written linklets with the same minimal compiler context as adapter tests.
(define (compose-linklet-first-slices specs #:tail [tail-forms '((void))])
  (webify-compose-linklet-first-slices
   specs
   #:tail                  tail-forms
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; compose-module-registry : webify-module-registry? (listof symbol?) #:tail (listof any/c) -> values
;;   Compose registry entries with the same minimal compiler context as adapter tests.
(define (compose-module-registry registry order #:tail [tail-forms '((void))])
  (webify-compose-module-registry
   registry
   order
   #:tail                  tail-forms
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; compose-module-registry/composition : webify-module-registry? (listof symbol?) #:tail (listof any/c) -> webify-module-composition?
;;   Compose registry entries into a reusable payload with test defaults.
(define (compose-module-registry/composition registry order #:tail [tail-forms '((void))])
  (webify-compose-module-registry/composition
   registry
   order
   #:tail                  tail-forms
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; compose-module-registry/roots : webify-module-registry? (listof symbol?) #:tail (listof any/c) -> values
;;   Plan and compose registry roots with the minimal adapter-test compiler context.
(define (compose-module-registry/roots registry roots #:tail [tail-forms '((void))])
  (webify-compose-module-registry/roots
   registry
   roots
   #:tail                  tail-forms
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; compose-module-registry/roots/composition : webify-module-registry? (listof symbol?) #:tail (listof any/c) -> webify-module-composition?
;;   Plan and compose registry roots into a reusable payload with test defaults.
(define (compose-module-registry/roots/composition registry roots #:tail [tail-forms '((void))])
  (webify-compose-module-registry/roots/composition
   registry
   roots
   #:tail                  tail-forms
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; compose-module-registry/roots+observations : webify-module-registry? (listof symbol?) (listof observation?) -> values
;;   Compose registry roots and observe selected exports through module cells.
(define (compose-module-registry/roots+observations registry
                                                    roots
                                                    observations
                                                    #:observer [observer 'js-log]
                                                    #:tail [tail-forms '((void))])
  (webify-compose-module-registry/roots+observations
   registry
   roots
   observations
   #:observer              observer
   #:tail                  tail-forms
   #:serializable?-box     #f
   #:datum-intern?         #f
   #:target                #f
   #:allow-set!-undefined? #f
   #:unsafe-mode?          #f
   #:enforce-constant?     #t
   #:allow-inline?         #t
   #:no-prompt?            #f
   #:prim-knowns           test-prim-knowns
   #:primitives            test-primitives
   #:compiler-query        (lambda (v) #f)
   #:get-import-knowns     (lambda (key) (values #f #f #f))
   #:import-keys           #f))

;; wat-string : any/c -> string?
;;   Render compiler output into a string for focused smoke assertions.
(define (wat-string wat)
  (format "~s" wat))

;; run-webracket : (listof string?) path? -> (values exact-integer? string?)
;;   Run the local webracket command and capture combined output.
(define (run-webracket args cwd)
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr]
                   [current-directory cwd])
      (apply system*/exit-code
             (find-executable-path "racket")
             (path->string webracket-rkt)
             args)))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr))))

;; write-datum-program! : path-string? any/c -> void?
;;   Write one generated top-level datum as a source file.
(define (write-datum-program! path datum)
  (call-with-output-file path
    (lambda (out)
      (write datum out)
      (newline out))
    #:exists 'truncate/replace))

;; append-top-level-form : any/c any/c -> any/c
;;   Append one observable form to a generated top-level begin program.
(define (append-top-level-form datum form)
  (match datum
    [`(begin ,body ...)
     `(begin ,@body ,form)]
    [_
     (error 'append-top-level-form
            "expected generated adapter datum to be a begin form")]))

;; begin-body : any/c -> (listof any/c)
;;   Extract body forms from a generated top-level begin program.
(define (begin-body datum)
  (match datum
    [`(begin ,body ...)
     body]
    [_
     (error 'begin-body
            "expected generated adapter datum to be a begin form")]))

;; normalize-symbols : any/c -> any/c
;;   Compare generated top-level datums by symbol spelling instead of identity.
(define (normalize-symbols v)
  (cond
    [(symbol? v) (symbol->string v)]
    [(pair? v)   (cons (normalize-symbols (car v))
                       (normalize-symbols (cdr v)))]
    [(vector? v) (list->vector (map normalize-symbols (vector->list v)))]
    [else        v]))
