#lang racket

(provide namespace-current-global-forms
         namespace-current-global-names
         namespace-initializer-forms
         namespace-module-registry-global-forms
         namespace-module-registry-global-names
         namespace-core-runtime-helpers
         namespace-runtime-string-constants
         namespace-runtime-symbol-constants
         namespace-runtime-only-helpers
         namespace-runtime-only-helper-names
         namespace-runtime-helper-forms
         namespace-top-level-global-forms
         namespace-top-level-global-names)

(require "../core-helper.rkt")

;; namespace-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by namespace helpers and namespace contract checks.
(define namespace-runtime-string-constants
  '((namespace? "namespace?")
    (namespace-variable-value-simple:undefined
     "namespace-variable-value-simple: given name is not defined\n  name: ")))

;; namespace-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by namespace contract checks.
(define namespace-runtime-symbol-constants
  '(namespace-variable-value-simple
    namespace-set-variable-value!
    namespace-undefine-variable!
    namespace-has-key?))

;; namespace-current-global-forms : (listof datum?)
;;   Declare the current namespace backing global.
(define namespace-current-global-forms
  '(
               (global $current-namespace-value (mut (ref eq)) (global.get $false))))

;; namespace-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a namespace global form.
(define (namespace-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'namespace-global-form-name
              "expected global form, got: ~s"
              form)]))

;; namespace-current-global-names : (listof symbol?)
;;   Enumerate current namespace globals shared by split modules.
(define namespace-current-global-names
  (map namespace-global-form-name namespace-current-global-forms))

;; namespace-top-level-global-forms : (listof datum?)
;;   Declare the top-level namespace global.
(define namespace-top-level-global-forms
  '(
         (global $top-level-namespace (mut (ref null $Namespace)) (ref.null $Namespace))))

;; namespace-top-level-global-names : (listof symbol?)
;;   Enumerate top-level namespace globals shared by split modules.
(define namespace-top-level-global-names
  (map namespace-global-form-name namespace-top-level-global-forms))

;; namespace-module-registry-global-forms : (listof datum?)
;;   Declare the empty namespace module registry value.
(define namespace-module-registry-global-forms
  '(
         ;; Module Registry
         (global $empty-module-registry (ref $ModuleRegistry)
                 (struct.new $ModuleRegistry
                             (i32.const 0)
                             (array.new $Array (global.get $null) (i32.const 0))))))

;; namespace-module-registry-global-names : (listof symbol?)
;;   Enumerate namespace registry constants shared by split modules.
(define namespace-module-registry-global-names
  (map namespace-global-form-name namespace-module-registry-global-forms))

;; namespace-initializer-forms : (listof datum?)
;;   Initialize the top-level and current namespaces.
(define namespace-initializer-forms
  '(
                     (global.set $top-level-namespace
                                 (ref.cast (ref $Namespace) (call $make-empty-namespace)))
                     (global.set $current-namespace-value
                                 (ref.cast (ref eq) (global.get $top-level-namespace)))))

;; namespace-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for namespace helpers.
(define namespace-runtime-only-helper-names
  '($make-empty-namespace
    $raise-undefined-top
    $raise-argument-error:namespace-expected
    $namespace-variable-value-simple
    $namespace-variable-value/checked
    $namespace-call-with-registry-lock
    $namespace-set-variable-value!
    $namespace-set-variable-value!/checked
    $namespace-undefine-variable!
    $namespace-undefine-variable!/checked
    $namespace-has-key?
    $namespace-has-key?/checked))

;; namespace-core-runtime-helper-names : (listof symbol?)
;;   Name namespace helpers available in the standalone core runtime.
(define namespace-core-runtime-helper-names
  '($make-empty-namespace
    $raise-argument-error:namespace-expected))

;; namespace-runtime-only-forms : (listof datum?)
;;   Enumerate namespace helpers used by the monolithic runtime.
(define namespace-runtime-only-forms
  '(
    (func $make-empty-namespace (type $Prim0)
          (result (ref eq)) ;; and (ref $Namespace)

          (struct.new $Namespace
                      (i32.const 0)                         ;; $hash
                      (global.get $false)                   ;; $name
                      (i32.const 0)                         ;; $base-phase
                      (ref.cast (ref $HashEqMutable)        ;; $table
                                (call $make-empty-hasheq))
                      (global.get $empty-module-registry)   ;; $modules
                      (i32.const 0)))                       ;; $protect

    ;; raise-undefined-top : symbol? -> never
    ;;   Raise a catchable variable exception for a missing top-level binding.
    (func $raise-undefined-top
          (param $sym (ref eq)) ;; missing symbol

          (call $raise
                (call $exn:fail:contract:variable/make
                      (call $string-append/2
                            (global.get $string:namespace-variable-value-simple:undefined)
                            (call $format/print
                                  (local.get $sym)
                                  (global.get $missing)))
                      (call $current-continuation-marks (global.get $missing))
                      (local.get $sym))
                (global.get $true))
          (unreachable))
    (func $raise-argument-error:namespace-expected
          (param $who (ref eq))
          (param $bad (ref eq))
          (call $raise-argument-error1
                (local.get $who)
                (global.get $string:namespace?)
                (local.get $bad))
          (unreachable))

    (func $namespace-variable-value-simple (type $Prim2)
          (param $ns  (ref eq))
          (param $sym (ref eq))
          (result     (ref eq))
          ;; 1) Check that $ns is a namespace
          (if (i32.eqz (ref.test (ref $Namespace) (local.get $ns)))
              (then (call $raise-argument-error:namespace-expected
                          (global.get $symbol:namespace-variable-value-simple)
                          (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-symbol-expected/who
                          (global.get $symbol:namespace-variable-value-simple)
                          (local.get $sym))
                    (unreachable)))
          ;; 3) Delegate to the checked implementation
          (call $namespace-variable-value/checked
                (ref.cast (ref $Namespace) (local.get $ns))
                (ref.cast (ref $Symbol)    (local.get $sym))))

    (func $namespace-variable-value/checked
          (param $ns  (ref $Namespace))
          (param $sym (ref $Symbol))
          (result     (ref eq))

          (local $tab (ref $HashEqMutable))
          (local $got (ref eq))
          (local $box (ref $Boxed))

          (local.set $tab (struct.get $Namespace $table (local.get $ns)))
          (local.set $got
                     (call $hasheq-ref
                           (ref.cast (ref eq) (local.get $tab))
                           (local.get $sym)
                           (global.get $false)))
          ;; Fail early if the binding is missing or not a $Boxed.
          (if (i32.eqz (ref.test (ref $Boxed) (local.get $got)))
              (then (call $raise-undefined-top (local.get $sym))
                    (unreachable)))
          ;; Cast and return the boxed value.
          (local.set $box (ref.cast (ref $Boxed) (local.get $got)))
          (struct.get $Boxed $v (local.get $box)))

    ;; namespace-call-with-registry-lock : namespace? (-> any/c) -> any/c
    ;;   Full Racket serializes access to a namespace's module
    ;;   registry. WebRacket's bootstrap namespace registry is not
    ;;   independently locked yet, so validate the namespace and
    ;;   thunk, then invoke the thunk directly.
    (func $namespace-call-with-registry-lock (type $Prim2)
          (param $ns    (ref eq)) ;; namespace?
          (param $thunk (ref eq)) ;; zero-argument procedure
          (result       (ref eq))

          (if (ref.eq (call $namespace? (local.get $ns)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:namespace-call-with-registry-lock)
                     (global.get $string:namespace?)
                     (local.get $ns))
               (unreachable)))
          (call $call-thunk/who
                (global.get $symbol:namespace-call-with-registry-lock)
                (global.get $string:procedure-arity-0)
                (local.get $thunk)))


    (func $namespace-set-variable-value!
          (param $ns  (ref eq))
          (param $sym (ref eq))
          (param $val (ref eq))
          (result     (ref eq))
          ;; 1) Check that $ns is a namespace
          (if (i32.eqz (ref.test (ref $Namespace) (local.get $ns)))
              (then (call $raise-argument-error:namespace-expected
                          (global.get $symbol:namespace-set-variable-value!)
                          (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-symbol-expected/who
                          (global.get $symbol:namespace-set-variable-value!)
                          (local.get $sym))
                    (unreachable)))
          ;; 3) Delegate to the checked implementation
          (call $namespace-set-variable-value!/checked
                (ref.cast (ref $Namespace) (local.get $ns))
                (ref.cast (ref $Symbol)    (local.get $sym))
                (local.get $val)))

    (func $namespace-set-variable-value!/checked
          ;; Racket semantics: set OR define
          ;; If `sym` is bound   => mutate the existing $Boxed.
          ;; If `sym` is unbound => install a fresh $Boxed with `val`.
          (param $ns  (ref $Namespace))
          (param $sym (ref $Symbol))
          (param $val (ref eq))
          (result     (ref eq))

          (local $tab (ref $HashEqMutable))
          (local $got (ref eq))
          (local $box (ref $Boxed))

          (local.set $tab (struct.get $Namespace $table (local.get $ns)))
          (local.set $got
                     (call $hasheq-ref
                           (ref.cast (ref eq) (local.get $tab))
                           (local.get $sym)
                           (global.get $false)))

          (if (ref.test (ref $Boxed) (local.get $got))
              (then
               ;; Binding exists => mutate in place
               (local.set $box (ref.cast (ref $Boxed) (local.get $got)))
               (struct.set $Boxed $v (local.get $box) (local.get $val))
               (return (global.get $void)))
              (else
               ;; Binding missing => create and insert new box
               (local.set $box (struct.new $Boxed (local.get $val)))
               (call $hasheq-set!/mutable/checked
                     (local.get $tab)
                     (local.get $sym)
                     (ref.cast (ref eq) (local.get $box)))
               (return (global.get $void))))
          (unreachable))

    (func $namespace-undefine-variable! (type $Prim2)
          (param $ns  (ref eq))
          (param $sym (ref eq))
          (result     (ref eq))
          ;; 1) Check that $ns is a namespace
          (if (i32.eqz (ref.test (ref $Namespace) (local.get $ns)))
              (then (call $raise-argument-error:namespace-expected
                          (global.get $symbol:namespace-undefine-variable!)
                          (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-symbol-expected/who
                          (global.get $symbol:namespace-undefine-variable!)
                          (local.get $sym))
                    (unreachable)))
          ;; 3) Delegate to the checked implementation
          (call $namespace-undefine-variable!/checked
                (ref.cast (ref $Namespace) (local.get $ns))
                (ref.cast (ref $Symbol)    (local.get $sym))))

    (func $namespace-undefine-variable!/checked
          (param $ns  (ref $Namespace))
          (param $sym (ref $Symbol))
          (result     (ref eq))

          (local $tab (ref $HashEqMutable))

          (local.set $tab (struct.get $Namespace $table (local.get $ns)))
           ; returns void
          (call $hasheq-remove!/mutable/checked (local.get $tab) (local.get $sym))
          (global.get $void))


    (func $namespace-has-key?
          (param $ns  (ref eq))
          (param $sym (ref eq))
          (result     (ref eq))
          ;; 1) Check that $ns is a namespace
          (if (i32.eqz (ref.test (ref $Namespace) (local.get $ns)))
              (then (call $raise-argument-error:namespace-expected
                          (global.get $symbol:namespace-has-key?)
                          (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-symbol-expected/who
                          (global.get $symbol:namespace-has-key?)
                          (local.get $sym))
                    (unreachable)))
          ;; 3) Delegate to the checked implementation
          (call $namespace-has-key?/checked
                (ref.cast (ref $Namespace) (local.get $ns))
                (ref.cast (ref $Symbol)    (local.get $sym))))

    (func $namespace-has-key?/checked
          (param $ns  (ref $Namespace))
          (param $sym (ref $Symbol))
          (result     (ref eq))

          (local $tab (ref $HashEqMutable))

          (local.set $tab (struct.get $Namespace $table (local.get $ns)))
          (call $hash-has-key? (ref.cast (ref eq) (local.get $tab)) (local.get $sym)))))

;; namespace-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate namespace helpers used by the monolithic runtime.
(define namespace-runtime-only-helpers
  (function-forms->runtime-helpers
   'namespace-runtime-only-helpers
   namespace-runtime-only-forms))

;; namespace-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate namespace helpers owned by the standalone core runtime.
(define namespace-core-runtime-helpers
  (select-runtime-helpers namespace-runtime-only-helpers
                          namespace-core-runtime-helper-names))

;; namespace-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render namespace helpers in runtime assembly order.
(define (namespace-runtime-helper-forms helper-index)
  (for/list ([name (in-list namespace-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define namespace-helper-index
    (make-core-runtime-helper-index namespace-runtime-only-helpers))

  (check-equal? namespace-current-global-names
                '($current-namespace-value))
  (check-equal? namespace-top-level-global-names
                '($top-level-namespace))
  (check-equal? namespace-module-registry-global-names
                '($empty-module-registry))
  (check-equal? (map core-runtime-helper-name namespace-core-runtime-helpers)
                namespace-core-runtime-helper-names)
  (check-equal?
   (map form-name (namespace-runtime-helper-forms namespace-helper-index))
   namespace-runtime-only-helper-names))
