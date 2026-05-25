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
         webracket-repo-root
         webracket-collection-parent
         webracket-collection-env-value
         call-with-webracket-collection-path
         comp
         current-compiler-progress?
         current-closure-conversion-progress?
         current-closure-conversion-progress-interval
         current-enable-cc-analysis?
         current-enable-simplify?
         current-letrec-strategy
         label-map-include-form?
         webify-module-instances-export-cell-id
         (all-from-out "../pkgs/webracket-lib/compiler/webify/known.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-adapter.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-composer.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-diagnostics.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-input.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-instance.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-loader.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-phase-policy.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-protocol.rkt")
         (all-from-out "../pkgs/webracket-lib/compiler/webify/module-registry.rkt"))

(require racket/match
         racket/file
         racket/path
         racket/port
         racket/runtime-path
         racket/system
         (only-in "../pkgs/webracket-lib/compiler/compiler.rkt"
                  comp
                  current-compiler-progress?
                  current-closure-conversion-progress?
                  current-closure-conversion-progress-interval
                  label-map-include-form?)
         (only-in "../pkgs/webracket-lib/compiler/private/parameters.rkt"
                  current-enable-cc-analysis?
                  current-enable-simplify?
                  current-letrec-strategy)
         "../pkgs/webracket-lib/compiler/webify/known.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-adapter.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-composer.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-diagnostics.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-extractor.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-input.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-instance.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-loader.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-phase-policy.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-protocol.rkt"
         "../pkgs/webracket-lib/compiler/webify/module-registry.rkt")

(define-runtime-path webracket-rkt "../webracket.rkt")
(define-runtime-path webracket-repo-root* "..")

(define webracket-repo-root
  (simplify-path webracket-repo-root*))

(define path-list-separator
  (if (eq? (system-type 'os) 'windows) ";" ":"))

;; package-collection-root-ready? : path? -> boolean?
;;   Detect when the phased package migration has moved collection files.
(define (package-collection-root-ready? package-root)
  (and (directory-exists? package-root)
       (file-exists? (build-path package-root "base.rkt"))
       (file-exists? (build-path package-root "info.rkt"))))

;; webracket-collection-parent : -> path?
;;   Return the collection parent to put on PLTCOLLECTS for this checkout.
(define (webracket-collection-parent)
  (define package-root (build-path webracket-repo-root "pkgs" "webracket"))
  (if (package-collection-root-ready? package-root)
      (build-path webracket-repo-root "pkgs")
      (raise-arguments-error
       'webracket-collection-parent
       "package collection root is not ready"
       "expected" package-root)))

;; webracket-collection-env-value : -> string?
;;   Build a PLTCOLLECTS value that exposes collection `webracket`.
(define (webracket-collection-env-value)
  (format "~a~a~a"
          (path->string (webracket-collection-parent))
          path-list-separator
          (or (getenv "PLTCOLLECTS") "")))

;; call-with-webracket-collection-path : (-> any/c) -> any/c
;;   Run thunk with collection `webracket` visible to host Racket.
(define (call-with-webracket-collection-path thunk)
  (parameterize ([current-library-collection-paths
                  (cons (webracket-collection-parent)
                        (current-library-collection-paths))])
    (thunk)))

;; test-prim-knowns : hash?
;;   Minimal primitive facts for first-slice top-level adapter tests.
(define test-prim-knowns
  (hasheq '+ (known-procedure/folding (procedure-arity-mask +))))

;; test-primitives : hash?
;;   Runtime values used by primitive constant folding.
(define test-primitives
  (hasheq '+ +))

;; run-first-slice-top-level : any/c keyword-args -> values
;;   Webify, lower, and top-level-wrap a hand-written linklet.
(define (run-first-slice-top-level lk #:define-export-aliases? [define-export-aliases? #t])
  (webify-linklet-first-slice-top-level
   lk
   #:define-export-aliases? define-export-aliases?
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

;; current-racket-executable : -> path?
;;   Resolve the Racket executable that is running this test process.
(define (current-racket-executable)
  (define exec-file (find-system-path 'exec-file))
  (cond
    [(and (path? exec-file)
          (complete-path? exec-file))
     exec-file]
    [(and (path? exec-file)
          (file-exists? exec-file))
     (path->complete-path exec-file)]
    [else
     (or (find-executable-path (path->string exec-file))
         (find-executable-path "racket"))]))

;; run-webracket : (listof string?) path? [#:timeout-seconds ...] [#:memory-mb ...] -> values
;;   Run the local webracket command and capture combined output.
(define (run-webracket args cwd
                       #:timeout-seconds [timeout-seconds #f]
                       #:memory-mb [memory-mb #f])
  (define racket-bin (current-racket-executable))
  (unless racket-bin
    (error 'run-webracket "could not find current racket executable"))
	  (cond
	    [(or timeout-seconds memory-mb)
	     (define stdout-path (make-temporary-file "webracket-stdout-~a.txt"))
	     (define stderr-path (make-temporary-file "webracket-stderr-~a.txt"))
	     (define stdout (open-output-file stdout-path #:exists 'truncate))
	     (define stderr (open-output-file stderr-path #:exists 'truncate))
	     (define command-args
       (if memory-mb
	           (append
	            (list "-c"
	                  "ulimit -v \"$1\" 2>/dev/null || ulimit -m \"$1\" 2>/dev/null || true; shift; exec \"$@\""
	                  "run-webracket-memory-limit"
                  (number->string (* memory-mb 1024))
                  (path->string racket-bin)
                  (path->string webracket-rkt))
            args)
           (append (list (path->string webracket-rkt)) args)))
	     (define command
       (if memory-mb
           "/bin/sh"
           (path->string racket-bin)))
     (when timeout-seconds
       (printf "run-webracket-stage: spawn timeout=~a\n" timeout-seconds)
       (flush-output))
     (define-values (proc child-out child-in child-err)
       (parameterize ([current-directory cwd])
         (apply subprocess stdout #f stderr 'new command command-args)))
     (when timeout-seconds
       (printf "run-webracket-stage: spawned\n")
       (flush-output))
     (when child-out (close-input-port child-out))
     (when child-in  (close-output-port child-in))
     (when child-err (close-input-port child-err))
     (when timeout-seconds
       (printf "run-webracket-stage: wait\n")
       (flush-output))
     (define completed
       (if timeout-seconds
           (sync/timeout timeout-seconds proc)
           (begin (subprocess-wait proc) #t)))
     (when timeout-seconds
       (printf "run-webracket-stage: wait-done completed=~a\n" (and completed #t))
       (flush-output))
     (define killed-and-waited?
       (cond
         [completed
          (subprocess-wait proc)
          #t]
         [else
          (when timeout-seconds
            (printf "run-webracket-stage: kill\n")
            (flush-output))
          (subprocess-kill proc #t)
          (define waited? (and (sync/timeout 2 proc) #t))
          (when timeout-seconds
            (printf "run-webracket-stage: kill-wait-done waited=~a\n" waited?)
            (flush-output))
          waited?]))
	     (close-output-port stdout)
	     (close-output-port stderr)
	     (define status (subprocess-status proc))
	     (define output
	       (string-append (file->string stdout-path)
	                      (file->string stderr-path)
	                      (if completed
	                          ""
	                          (format "\nrun-webracket-timeout-seconds: ~a\n"
	                                  timeout-seconds))))
	     (with-handlers ([exn:fail? void])
	       (delete-file stdout-path))
	     (with-handlers ([exn:fail? void])
	       (delete-file stderr-path))
	     (values (cond
               [(not completed) 124]
               [(not killed-and-waited?) 124]
               [(integer? status) status]
               [else 1])
             output)]
    [else
  (define stdout (open-output-string))
  (define stderr (open-output-string))
  (define status
    (parameterize ([current-output-port stdout]
                   [current-error-port stderr]
                   [current-directory cwd])
      (apply system*/exit-code
             racket-bin
             (path->string webracket-rkt)
             args)))
  (values status
          (string-append (get-output-string stdout)
                         (get-output-string stderr)))]))

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
