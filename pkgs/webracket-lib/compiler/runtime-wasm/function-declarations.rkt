#lang racket

(provide runtime-function-declaration-forms
         runtime-fixed-function-declarations)

(require "../private/wasm-utils.rkt"
         (only-in "core/procedures.rkt"
                  shape->invoker))

;; runtime-fixed-function-declarations : (listof datum?)
;;   Declare fixed runtime functions that are referenced by ref.func.
(define runtime-fixed-function-declarations
  '((ref.func $struct-constructor/no-guard)       ; closure body
    (ref.func $struct-constructor/with-guard)     ; closure body
    (ref.func $struct-accessor)                   ; closure body
    (ref.func $struct-mutator)                    ; closure body
    (ref.func $struct-predicate)                  ; closure body
    (ref.func $struct-field-accessor/specialized) ; closure body
    (ref.func $struct-mutator/specialized)
    (ref.func $struct-type-property-predicate)    ; closure body
    (ref.func $struct-type-property-accessor)     ; closure body
    (ref.func $equal+hash-recur/equal)            ; closure body
    (ref.func $equal+hash-recur/equal-always)     ; closure body
    (ref.func $equal+hash-recur/hash)             ; closure body
    (ref.func $equal+hash-recur/hash-always)      ; closure body
    (ref.func $invoke-struct)
    (ref.func $primitive-invoke)
    (ref.func $invoke-reduced-procedure)
    (ref.func $invoke-composed-procedure)
    (ref.func $sort/keyword-apply)
    (ref.func $vector-sort/keyword-apply)
    (ref.func $vector-sort!/keyword-apply)
    (ref.func $code:case-lambda-dispatch)
    (ref.func $invoke-case-closure)
    (ref.func $default-error-syntax->name-handler)
    (ref.func $default-error-value->string-handler)
    (ref.func $default-error-syntax->string-handler)
    (ref.func $default-error-module-path->string-handler)
    (ref.func $default-current-read-interaction)
    (ref.func $default-port-read-handler)
    (ref.func $default-port-read-handler/1)
    (ref.func $default-port-write-handler)
    (ref.func $default-port-display-handler)
    (ref.func $default-port-print-handler)
    (ref.func $syntax-introducer)
    (ref.func $syntax-delta-introducer)))

;; runtime-function-declaration-forms : (listof exact-nonnegative-integer?) (listof symbol?) (listof symbol?) -> (listof datum?)
;;   Generate elem declarations for fixed runtime functions and active primitive wrappers.
(define (runtime-function-declaration-forms primitive-shapes
                                            primitive-names
                                            ffi-primitive-names)
  `((elem declare funcref
          ,@runtime-fixed-function-declarations
          ;; Primitive invokers for the different shapes
          ,@(for/list ([shape (in-list primitive-shapes)])
              `(ref.func ,($ (shape->invoker shape))))
          ;; Declare all primitives
          ,@(for/list ([pr (in-list primitive-names)])
              `(ref.func ,($ pr)))
          ;; Declare FFI-backed primitive wrappers.
          ,@(for/list ([pr (in-list ffi-primitive-names)])
              `(ref.func ,($ pr))))))

(module+ test
  (require rackunit)

  (define declaration
    (first (runtime-function-declaration-forms '(0 31)
                                               '(fx+)
                                               '(js-alert))))

  (check-equal? (take declaration 3)
                '(elem declare funcref))
  (check-not-false (member '(ref.func $struct-constructor/no-guard)
                           declaration))
  (check-not-false (member '(ref.func $primitive-invoke:shape-0)
                           declaration))
  (check-not-false (member '(ref.func $primitive-invoke:shape-31)
                           declaration))
  (check-not-false (member '(ref.func $fx+)
                           declaration))
  (check-not-false (member '(ref.func $js-alert)
                           declaration)))
