#lang racket

(provide namespace-runtime-only-helpers
         namespace-runtime-only-helper-names)

(require "../core-helper.rkt")

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
    ;;   Log the missing top-level binding before throwing, so large
    ;;   generated programs expose the next runtime gap directly.
    (func $raise-undefined-top
          (param $sym (ref eq)) ;; missing symbol

          (call $js-log (global.get $string:missing-binding))
          (call $js-log (local.get $sym))
          (unreachable))
    (func $raise-argument-error:namespace-expected (unreachable))

    (func $namespace-variable-value-simple (type $Prim2)
          (param $ns  (ref eq))
          (param $sym (ref eq))
          (result     (ref eq))
          ;; 1) Check that $ns is a namespace
          (if (i32.eqz (ref.test (ref $Namespace) (local.get $ns)))
              (then (call $raise-argument-error:namespace-expected (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-check-symbol (local.get $sym))
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
          (call $call-thunk (local.get $thunk)))


    (func $namespace-set-variable-value!
          (param $ns  (ref eq))
          (param $sym (ref eq))
          (param $val (ref eq))
          (result     (ref eq))
          ;; 1) Check that $ns is a namespace
          (if (i32.eqz (ref.test (ref $Namespace) (local.get $ns)))
              (then (call $raise-argument-error:namespace-expected (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-check-symbol (local.get $sym))
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
              (then (call $raise-argument-error:namespace-expected (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-check-symbol (local.get $sym))
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
              (then (call $raise-argument-error:namespace-expected (local.get $ns))
                    (unreachable)))
          ;; 2) Check that $sym is a symbol
          (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
              (then (call $raise-check-symbol (local.get $sym))
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
