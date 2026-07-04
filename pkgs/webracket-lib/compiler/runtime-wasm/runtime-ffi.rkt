#lang racket

(provide ffi-import-name
         select-active-ffi-runtime-bindings
         select-current-ffi-runtime-bindings
         runtime-ffi-foreign-fingerprint
         runtime-record-ffi-metrics!)

(require "../private/parameters.rkt"
         "../private/structs.rkt"
         "../private/wasm-utils.rkt"
         (only-in "module-forms.rkt"
                  module-func-name)
         (only-in "runtime-analysis.rkt"
                  list->eq-set)
         (only-in "runtime-metrics.rkt"
                  runtime-metric-add!))

;; ffi-import-name : foreign? -> symbol?
;;   Return the generated Wasm import wrapper name for a foreign primitive.
(define (ffi-import-name f)
  (string->symbol (~a "$" (foreign-racket-name f) "/imported")))

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

  (check-equal? (runtime-ffi-foreign-fingerprint (list foreign-a))
                (runtime-ffi-foreign-fingerprint (list foreign-a)))
  (parameterize ([current-runtime-metric-rows '()])
    (runtime-record-ffi-metrics! (list foreign-a foreign-b))
    (define rows (current-runtime-metric-rows))
    (check-equal? (second (assoc "runtime:ffi-foreign-count" rows)) "2")
    (check-equal? (second (assoc "runtime:ffi-foreign-fingerprint" rows))
                  (runtime-ffi-foreign-fingerprint (list foreign-a foreign-b)))))
