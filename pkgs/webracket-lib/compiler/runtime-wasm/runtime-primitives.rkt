#lang racket

(provide runtime-described-primitives
         runtime-active-primitives-sorted
         runtime-active-described-primitives-sorted
         runtime-console-bridge-primitive-names
         runtime-ffi-primitive-names
         runtime-primitive-func->symbol
         runtime-primitive-global->symbol
         runtime-ffi-global->symbol
         runtime-primitive-initializer-bindings
         runtime-ffi-primitive-initializer-bindings
         runtime-primitive-global-forms
         runtime-ffi-primitive-global-forms
         runtime-primitive-initializer-forms
         runtime-ffi-primitive-initializer-forms)

(require "../private/priminfo.rkt"
         "../private/structs.rkt"
         "../private/wasm-utils.rkt"
         (only-in "core/procedures.rkt"
                  procedure-primitive-global-forms
                  procedure-ffi-primitive-global-forms
                  procedure-primitive-initializer-forms
                  procedure-ffi-primitive-initializer-forms))

;; runtime-described-primitives : (listof symbol?) -> (listof symbol?)
;;   Keep primitives with compiler-visible primitive descriptions.
(define (runtime-described-primitives primitives)
  (filter primitive->description primitives))

;; runtime-active-primitives-sorted : (listof symbol?) -> (listof symbol?)
;;   Sort active primitives in stable runtime emission order.
(define (runtime-active-primitives-sorted active-primitives)
  (sort active-primitives symbol<?))

;; runtime-active-described-primitives-sorted : (listof symbol?) (listof symbol?) -> (listof symbol?)
;;   Sort active described primitives, excluding primitives handled elsewhere.
(define (runtime-active-described-primitives-sorted active-primitives todo-handle-later)
  (for/list ([pr (in-list (runtime-active-primitives-sorted active-primitives))]
             #:unless (memq pr todo-handle-later)
             #:when (primitive->description pr))
    pr))

;; runtime-ffi-primitive-names : (listof foreign?) -> (listof symbol?)
;;   Return active FFI primitive names in foreign declaration order.
(define (runtime-ffi-primitive-names active-ffi-foreigns)
  (for/list ([f (in-list active-ffi-foreigns)])
    (foreign-racket-name f)))

;; runtime-console-bridge-primitive-names : list? -> (listof symbol?)
;;   Return primitive names requested by console bridge bindings.
(define (runtime-console-bridge-primitive-names console-bridge-bindings)
  (for/list ([binding (in-list console-bridge-bindings)]
             #:do [(define kind (first binding))]
             #:when (eq? kind 'primitive))
    (second binding)))

;; runtime-primitive-func->symbol : (listof symbol?) -> hasheq?
;;   Map generated primitive function names back to Racket primitive names.
(define (runtime-primitive-func->symbol described-primitives)
  (for/hasheq ([pr (in-list described-primitives)])
    (values ($ pr) pr)))

;; runtime-primitive-global->symbol : (listof symbol?) -> hasheq?
;;   Map generated primitive global names back to Racket primitive names.
(define (runtime-primitive-global->symbol described-primitives)
  (for/hasheq ([pr (in-list described-primitives)])
    (values ($ (prim: pr)) pr)))

;; runtime-ffi-global->symbol : (listof foreign?) -> hasheq?
;;   Map generated FFI primitive global names back to Racket primitive names.
(define (runtime-ffi-global->symbol all-ffi-foreigns)
  (for/hasheq ([f (in-list all-ffi-foreigns)])
    (define pr (foreign-racket-name f))
    (values ($ (prim: pr)) pr)))

;; runtime-primitive-initializer-bindings : (listof symbol?) -> (listof list?)
;;   Return primitive global initializer metadata in runtime emission order.
(define (runtime-primitive-initializer-bindings active-described-primitives)
  (for/list ([pr (in-list active-described-primitives)]
             #:do [(define desc (primitive->description pr))])
    (list pr
          (primitive-description-arity desc)
          (primitive-description-result-arity desc))))

;; runtime-ffi-primitive-initializer-bindings : (listof foreign?) -> (listof list?)
;;   Return FFI primitive global initializer metadata in active foreign order.
(define (runtime-ffi-primitive-initializer-bindings active-ffi-foreigns)
  (for/list ([f (in-list active-ffi-foreigns)])
    (list (foreign-racket-name f)
          (length (foreign-argument-types f)))))

;; runtime-primitive-global-forms : (listof symbol?) -> (listof datum?)
;;   Declare globals that hold runtime primitive procedure values.
(define (runtime-primitive-global-forms active-described-primitives)
  (procedure-primitive-global-forms active-described-primitives))

;; runtime-ffi-primitive-global-forms : (listof symbol?) -> (listof datum?)
;;   Declare globals that hold runtime FFI primitive procedure values.
(define (runtime-ffi-primitive-global-forms active-ffi-primitive-names)
  (procedure-ffi-primitive-global-forms active-ffi-primitive-names))

;; runtime-primitive-initializer-forms : (listof symbol?) -> (listof datum?)
;;   Initialize runtime primitive globals as procedure values.
(define (runtime-primitive-initializer-forms active-described-primitives)
  (procedure-primitive-initializer-forms
   (runtime-primitive-initializer-bindings active-described-primitives)))

;; runtime-ffi-primitive-initializer-forms : (listof foreign?) -> (listof datum?)
;;   Initialize runtime FFI primitive globals as procedure values.
(define (runtime-ffi-primitive-initializer-forms active-ffi-foreigns)
  (procedure-ffi-primitive-initializer-forms
   (runtime-ffi-primitive-initializer-bindings active-ffi-foreigns)))

(module+ test
  (require rackunit)

  (define sample-foreigns
    (list (foreign 'ffi-a 'host 'a '(i32) '())
          (foreign 'ffi-b 'host 'b '(i32 i32) '(i32))))

  (check-equal? (runtime-active-primitives-sorted '(cdr car cons))
                '(car cdr cons))
  (check-equal? (runtime-active-described-primitives-sorted '(cdr car cons) '(cdr))
                '(car cons))
  (check-equal? (runtime-described-primitives '(car cons))
                '(car cons))
  (check-equal? (runtime-ffi-primitive-names sample-foreigns) '(ffi-a ffi-b))
  (check-equal? (runtime-console-bridge-primitive-names
                 '((primitive cons)
                   (foreign document)
                   (primitive display)))
                '(cons display))
  (check-equal? (hash-ref (runtime-primitive-func->symbol '(cons)) '$cons)
                'cons)
  (check-equal? (hash-ref (runtime-primitive-global->symbol '(cons)) '$prim:cons)
                'cons)
  (check-equal? (hash-ref (runtime-ffi-global->symbol sample-foreigns) '$prim:ffi-a)
                'ffi-a)
  (check-equal? (runtime-primitive-initializer-bindings '(cons))
                (list (list 'cons
                            (primitive-description-arity (primitive->description 'cons))
                            (primitive-description-result-arity (primitive->description 'cons)))))
  (check-equal? (runtime-ffi-primitive-initializer-bindings sample-foreigns)
                '((ffi-a 1)
                  (ffi-b 2)))
  (check-equal? (runtime-primitive-global-forms '(cons))
                '((global $prim:cons (mut (ref eq)) (ref.i31 (i32.const 79)))))
  (check-equal? (runtime-ffi-primitive-global-forms '(ffi-a))
                '((global $prim:ffi-a (mut (ref eq)) (ref.i31 (i32.const 79)))))
  (check-match (runtime-primitive-initializer-forms '(cons))
    (list `(global.set $prim:cons
                       (struct.new $PrimitiveProcedure
                        (i32.const 0)
                        (global.get $symbol:cons)
                        ,_
                        (global.get $the-racket/primitive-realm)
                        (ref.func ,_)
                        (ref.func $cons)
                        ,_))))
  (check-match (runtime-ffi-primitive-initializer-forms (list (first sample-foreigns)))
    (list `(global.set $prim:ffi-a
                       (struct.new $PrimitiveProcedure
                        (i32.const 0)
                        (global.get $symbol:ffi-a)
                        ,_
                        (global.get $the-racket/primitive-realm)
                        (ref.func ,_)
                        (ref.func $ffi-a)
                        ,_)))))
