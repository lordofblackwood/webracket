#lang racket

(provide ffi-import-name
         external-value-core-runtime-helper-forms
         external-value-core-runtime-helpers
         external-value-runtime-helper-forms
         ffi-core-runtime-helper-forms
         ffi-callback-global-forms
         ffi-entry-global-forms
         ffi-console-bridge-helper-names
         ffi-console-bridge-helper-forms
         ffi-runtime-only-helper-forms
         (struct-out runtime-ffi-state)
         make-current-runtime-ffi-state
         runtime-ffi-state-active-primitive-names
         runtime-ffi-state-filter-current-bindings!
         runtime-ffi-state-import-wrapper-helper-forms
         runtime-ffi-state-primitive-global-forms
         runtime-ffi-state-primitive-initializer-forms
         runtime-ffi-state-unsafe-primitive-helper-forms
         runtime-ffi-state-record-metrics!
         select-active-ffi-runtime-bindings
         select-current-ffi-runtime-bindings
         unsafe-ffi-primitive-table-global-forms
         runtime-ffi-foreign-fingerprint
         runtime-record-ffi-metrics!)

(require "../private/parameters.rkt"
         "../private/structs.rkt"
         "../private/wasm-utils.rkt"
         (only-in "module-forms.rkt"
                  module-func-name)
         (only-in "core/ffi.rkt"
                  external-value-core-runtime-helper-forms
                  external-value-core-runtime-helpers
                  external-value-runtime-helper-forms
                  ffi-core-runtime-helper-forms
                  ffi-callback-global-forms
                  ffi-entry-global-forms
                  ffi-console-bridge-helper-names
                  ffi-console-bridge-helper-forms
                  ffi-runtime-only-helper-forms
                  unsafe-ffi-primitive-table-global-forms
                  unsafe-ffi-runtime-only-helper-forms)
         (only-in "runtime-primitives.rkt"
                  runtime-ffi-primitive-global-forms
                  runtime-ffi-primitive-initializer-forms)
         (only-in "runtime-analysis.rkt"
                  list->eq-set)
         (only-in "runtime-metrics.rkt"
                  runtime-metric-add!))

;; ffi-import-name : foreign? -> symbol?
;;   Return the generated Wasm import wrapper name for a foreign primitive.
(define (ffi-import-name f)
  (string->symbol (~a "$" (foreign-racket-name f) "/imported")))

;; runtime-ffi-state :
;;   (listof foreign?) (listof foreign?) list? list? -> runtime-ffi-state?
;;   Store the current and selected FFI runtime bindings used during assembly.
(struct runtime-ffi-state
  (all-foreigns
   active-foreigns
   active-imports-wat
   active-funcs-wat)
  #:mutable
  #:transparent)

;; make-current-runtime-ffi-state : -> runtime-ffi-state?
;;   Snapshot the current compiler FFI parameters for runtime assembly.
(define (make-current-runtime-ffi-state)
  (define all-ffi-foreigns (current-ffi-foreigns))
  (runtime-ffi-state all-ffi-foreigns
                     all-ffi-foreigns
                     (current-ffi-imports-wat)
                     (current-ffi-funcs-wat)))

;; runtime-ffi-state-active-primitive-names : runtime-ffi-state? -> (listof symbol?)
;;   Return active FFI primitive names in foreign declaration order.
(define (runtime-ffi-state-active-primitive-names state)
  (for/list ([f (in-list (runtime-ffi-state-active-foreigns state))])
    (foreign-racket-name f)))

;; runtime-ffi-state-import-wrapper-helper-forms : runtime-ffi-state? #:unsafe-ffi-foreigns (listof foreign?) -> (listof datum?)
;;   Render active FFI host imports, generated wrappers, and unsafe lookup helpers.
(define (runtime-ffi-state-import-wrapper-helper-forms state
                                                       #:unsafe-ffi-foreigns
                                                       [unsafe-ffi-foreigns
                                                        (runtime-ffi-state-active-foreigns
                                                         state)])
  (append (runtime-ffi-state-active-imports-wat state)
          (runtime-ffi-state-active-funcs-wat state)
          (unsafe-ffi-runtime-only-helper-forms
           unsafe-ffi-foreigns)))

;; runtime-ffi-state-primitive-global-forms : runtime-ffi-state? -> (listof datum?)
;;   Declare globals that hold active FFI primitive procedure values.
(define (runtime-ffi-state-primitive-global-forms state)
  (runtime-ffi-primitive-global-forms
   (runtime-ffi-state-active-primitive-names state)))

;; runtime-ffi-state-primitive-initializer-forms : runtime-ffi-state? -> (listof datum?)
;;   Initialize active FFI primitive globals as procedure values.
(define (runtime-ffi-state-primitive-initializer-forms state)
  (runtime-ffi-primitive-initializer-forms
   (runtime-ffi-state-active-foreigns state)))

;; runtime-ffi-state-unsafe-primitive-helper-forms :
;;   runtime-ffi-state? [#:unsafe-ffi-foreigns (listof foreign?)] -> (listof datum?)
;;   Render unsafe FFI lookup helpers for the active FFI primitive set.
(define (runtime-ffi-state-unsafe-primitive-helper-forms
         state
         #:unsafe-ffi-foreigns
         [unsafe-ffi-foreigns (runtime-ffi-state-active-foreigns state)])
  (unsafe-ffi-runtime-only-helper-forms
   unsafe-ffi-foreigns))

;; active-ffi-primitive-names : (listof foreign?) (listof symbol?) boolean? -> (listof symbol?)
;;   Select the foreign primitive names needed by the current program.
(define (active-ffi-primitive-names all-ffi-foreigns used-primitives tree-shake?)
  (define ffi-primitive-name-set
    (for/hasheq ([f (in-list all-ffi-foreigns)])
      (values (foreign-racket-name f) #t)))
  (if (and tree-shake?
           (not (memq 'unsafe-ffi-primitive used-primitives)))
      (sort
       (filter (lambda (pr) (hash-ref ffi-primitive-name-set pr #f))
               (remove-duplicates used-primitives))
       symbol<?)
      (sort (hash-keys ffi-primitive-name-set) symbol<?)))

;; select-matching-module-forms : (listof any/c) (listof symbol?) -> (listof any/c)
;;   Keep named function forms whose names are in `wanted-names`, dropping duplicate names.
(define (select-matching-module-forms forms wanted-names)
  (define wanted-name-set (list->eq-set wanted-names))
  (remove-duplicates
   (for/list ([form (in-list forms)]
              #:do [(define name (module-func-name form))]
              #:when (and name
                          (hash-ref wanted-name-set name #f)))
     form)
   eq?
   #:key module-func-name))

;; select-active-ffi-runtime-bindings :
;;   (listof foreign?) (listof any/c) (listof any/c) (listof symbol?) boolean?
;;   -> (values (listof foreign?) (listof any/c) (listof any/c))
;;   Select active FFI foreigns and matching import/wrapper WAT forms.
(define (select-active-ffi-runtime-bindings all-ffi-foreigns
                                            all-ffi-imports-wat
                                            all-ffi-funcs-wat
                                            used-primitives
                                            tree-shake?)
  (define selected-names
    (active-ffi-primitive-names all-ffi-foreigns used-primitives tree-shake?))
  (define active-ffi-foreigns
    (for/list ([f (in-list all-ffi-foreigns)]
               #:when (memq (foreign-racket-name f) selected-names))
      f))
  (define active-ffi-imports-wat
    (select-matching-module-forms
     all-ffi-imports-wat
     (map ffi-import-name active-ffi-foreigns)))
  (define active-ffi-funcs-wat
    (select-matching-module-forms
     all-ffi-funcs-wat
     (map (lambda (f) ($ (foreign-racket-name f))) active-ffi-foreigns)))
  (values active-ffi-foreigns
          active-ffi-imports-wat
          active-ffi-funcs-wat))

;; select-current-ffi-runtime-bindings :
;;   (listof foreign?) (listof symbol?) -> (values (listof foreign?) (listof any/c) (listof any/c))
;;   Select active FFI bindings from the current compiler parameters.
(define (select-current-ffi-runtime-bindings all-ffi-foreigns used-primitives)
  (select-active-ffi-runtime-bindings
   all-ffi-foreigns
   (current-ffi-imports-wat)
   (current-ffi-funcs-wat)
   used-primitives
   (current-tree-shake?)))

;; runtime-ffi-state-filter-current-bindings! : runtime-ffi-state? (listof symbol?) -> void?
;;   Select active FFI runtime bindings from the current compiler parameters.
(define (runtime-ffi-state-filter-current-bindings! state used-primitives)
  (define-values (selected-ffi-foreigns
                  selected-ffi-imports-wat
                  selected-ffi-funcs-wat)
    (select-current-ffi-runtime-bindings
     (runtime-ffi-state-all-foreigns state)
     used-primitives))
  (set-runtime-ffi-state-active-foreigns! state selected-ffi-foreigns)
  (set-runtime-ffi-state-active-imports-wat! state selected-ffi-imports-wat)
  (set-runtime-ffi-state-active-funcs-wat! state selected-ffi-funcs-wat))

;; runtime-ffi-foreign-fingerprint : (listof foreign?) -> string?
;;   Return a compact fingerprint for the active FFI foreign names.
(define (runtime-ffi-foreign-fingerprint active-ffi-foreigns)
  (format "~x"
          (abs (equal-hash-code
                (sort (map foreign-racket-name active-ffi-foreigns)
                      symbol<?)))))

;; runtime-record-ffi-metrics! : (listof foreign?) -> void?
;;   Record selected FFI foreign count and fingerprint metrics.
(define (runtime-record-ffi-metrics! active-ffi-foreigns)
  (runtime-metric-add! "runtime:ffi-foreign-count"
                       (length active-ffi-foreigns))
  (runtime-metric-add! "runtime:ffi-foreign-fingerprint"
                       (runtime-ffi-foreign-fingerprint active-ffi-foreigns)))

;; runtime-ffi-state-record-metrics! : runtime-ffi-state? -> void?
;;   Record selected FFI metrics from the runtime FFI state.
(define (runtime-ffi-state-record-metrics! state)
  (runtime-record-ffi-metrics! (runtime-ffi-state-active-foreigns state)))

(module+ test
  (require rackunit)

  (define foreign-a (foreign 'a 'host 'a '() '()))
  (define foreign-b (foreign 'b 'host 'b '() '()))
  (define foreign-c (foreign 'c 'host 'c '() '()))
  (define sample-foreigns (list foreign-b foreign-a foreign-c))
  (define sample-imports
    '((func $a/imported)
      (func $b/imported)
      (func $a/imported)
      (func $not-ffi/imported)))
  (define sample-funcs
    '((func $a)
      (func $b)
      (func $a)
      (func $not-ffi)))
  (define (symbol-in? value wanted)
    (cond
      [(eq? value wanted) #t]
      [(pair? value)
       (or (symbol-in? (car value) wanted)
           (symbol-in? (cdr value) wanted))]
      [else #f]))

  (check-pred list? ffi-callback-global-forms)
  (check-pred list? ffi-entry-global-forms)
  (check-pred list? unsafe-ffi-primitive-table-global-forms)
  (check-pred list? (ffi-runtime-only-helper-forms '()))
  (check-pred procedure? external-value-runtime-helper-forms)

  (define-values (tree-shaken-foreigns
                  tree-shaken-imports
                  tree-shaken-funcs)
    (select-active-ffi-runtime-bindings sample-foreigns
                                        sample-imports
                                        sample-funcs
                                        '(a b a ignored)
                                        #t))
  (check-equal? (map foreign-racket-name tree-shaken-foreigns) '(b a))
  (check-equal? tree-shaken-imports '((func $a/imported) (func $b/imported)))
  (check-equal? tree-shaken-funcs '((func $a) (func $b)))

  (define-values (unsafe-foreigns
                  unsafe-imports
                  unsafe-funcs)
    (select-active-ffi-runtime-bindings sample-foreigns
                                        sample-imports
                                        sample-funcs
                                        '(unsafe-ffi-primitive)
                                        #t))
  (check-equal? (map foreign-racket-name unsafe-foreigns) '(b a c))
  (check-equal? unsafe-imports '((func $a/imported) (func $b/imported)))
  (check-equal? unsafe-funcs '((func $a) (func $b)))

  (define-values (unshaken-foreigns
                  unshaken-imports
                  unshaken-funcs)
    (select-active-ffi-runtime-bindings sample-foreigns
                                        sample-imports
                                        sample-funcs
                                        '()
                                        #f))
  (check-equal? (map foreign-racket-name unshaken-foreigns) '(b a c))
  (check-equal? unshaken-imports '((func $a/imported) (func $b/imported)))
  (check-equal? unshaken-funcs '((func $a) (func $b)))

  (parameterize ([current-ffi-imports-wat sample-imports]
                 [current-ffi-funcs-wat sample-funcs]
                 [current-tree-shake? #t])
    (define-values (current-foreigns
                    current-imports
                    current-funcs)
      (select-current-ffi-runtime-bindings sample-foreigns '(a ignored)))
    (check-equal? (map foreign-racket-name current-foreigns) '(a))
    (check-equal? current-imports '((func $a/imported)))
    (check-equal? current-funcs '((func $a))))

  (parameterize ([current-ffi-foreigns sample-foreigns]
                 [current-ffi-imports-wat sample-imports]
                 [current-ffi-funcs-wat sample-funcs]
                 [current-tree-shake? #t])
    (define state (make-current-runtime-ffi-state))
    (check-equal? (map foreign-racket-name
                       (runtime-ffi-state-all-foreigns state))
                  '(b a c))
    (check-equal? (runtime-ffi-state-active-primitive-names state)
                  '(b a c))
    (runtime-ffi-state-filter-current-bindings! state '(a ignored))
    (check-equal? (map foreign-racket-name
                       (runtime-ffi-state-active-foreigns state))
                  '(a))
    (check-equal? (runtime-ffi-state-active-imports-wat state)
                  '((func $a/imported)))
    (check-equal? (runtime-ffi-state-active-funcs-wat state)
                  '((func $a)))
    (define import-wrapper-helper-forms
      (runtime-ffi-state-import-wrapper-helper-forms state))
    (check-equal? (first import-wrapper-helper-forms) '(func $a/imported))
    (check-equal? (second import-wrapper-helper-forms) '(func $a))
    (check-true
     (for/or ([form (in-list import-wrapper-helper-forms)])
       (and (pair? form)
            (eq? (first form) 'func)
            (eq? (second form) '$unsafe-ffi-primitive))))
    (define split-direct-import-wrapper-helper-forms
      (runtime-ffi-state-import-wrapper-helper-forms
       state
       #:unsafe-ffi-foreigns '()))
    (check-equal? (first split-direct-import-wrapper-helper-forms)
                  '(func $a/imported))
    (check-equal? (second split-direct-import-wrapper-helper-forms)
                  '(func $a))
    (check-false
     (for/or ([form (in-list split-direct-import-wrapper-helper-forms)])
       (symbol-in? form '$prim:a)))
    (check-equal? (runtime-ffi-state-primitive-global-forms state)
                  '((global $prim:a (mut (ref eq)) (ref.i31 (i32.const 79)))))
    (check-match (runtime-ffi-state-primitive-initializer-forms state)
      (list `(global.set $prim:a
                         (struct.new $PrimitiveProcedure
                          (i32.const 0)
                          (global.get $symbol:a)
                          ,_
                          (global.get $the-racket/primitive-realm)
                          (ref.func ,_)
                          (ref.func $a)
                          ,_))))
    (parameterize ([current-runtime-metric-rows '()])
      (runtime-ffi-state-record-metrics! state)
      (define rows (current-runtime-metric-rows))
      (check-equal? (second (assoc "runtime:ffi-foreign-count" rows)) "1")
      (check-equal? (second (assoc "runtime:ffi-foreign-fingerprint" rows))
                    (runtime-ffi-foreign-fingerprint (list foreign-a)))))

  (check-equal? (runtime-ffi-foreign-fingerprint (list foreign-a))
                (runtime-ffi-foreign-fingerprint (list foreign-a)))
  (parameterize ([current-runtime-metric-rows '()])
    (runtime-record-ffi-metrics! (list foreign-a foreign-b))
    (define rows (current-runtime-metric-rows))
    (check-equal? (second (assoc "runtime:ffi-foreign-count" rows)) "2")
    (check-equal? (second (assoc "runtime:ffi-foreign-fingerprint" rows))
                  (runtime-ffi-foreign-fingerprint (list foreign-a foreign-b)))))
