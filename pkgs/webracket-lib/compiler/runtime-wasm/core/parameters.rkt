#lang racket

(provide parameter-runtime-only-helpers)

(require "../core-helper.rkt")

;; parameter-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate parameterization helpers used by the monolithic runtime.
(define parameter-runtime-only-helpers
  (function-forms->runtime-helpers
   'parameter-runtime-only-helpers
   '(
     ;; current-parameterization : -> parameterization?
     ;;   Return the current poor-man parameterization overlay.
     (func $current-parameterization (type $Prim0)
           (result (ref eq))
           (global.get $current-parameterization-value))

     ;; parameterization? : any/c -> boolean?
     ;;   Recognize WebRacket's lightweight parameterization overlays.
     (func $parameterization? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $Parameterization) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     ;; parameter? : any/c -> boolean?
     ;;   Recognize the built-in parameter procedures currently modeled by
     ;;   WebRacket. User-created parameters need make-parameter support.
     (func $parameter? (type $Prim1)
           (param $v (ref eq)) ;; any/c
           (result   (ref eq))

           (if (ref.eq (local.get $v) (global.get $prim:current-input-port))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-output-port))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-error-port))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-logger))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-thread-group))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-security-guard))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-custodian))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-print))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-readtable))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-read-interaction))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-namespace))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-compile-target-machine))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:current-compile-realm))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:print-syntax-width))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:error-print-width))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:error-print-source-location))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:error-value->string-handler))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:error-syntax->string-handler))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:error-module-path->string-handler))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:load-on-demand-enabled))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:use-user-specific-search-paths))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-square-bracket-as-paren))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-curly-brace-as-paren))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-square-bracket-with-tag))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-curly-brace-with-tag))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-reader))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-lang))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-compiled))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-box))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-bar-quote))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-graph))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-syntax-accept-graph))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-dot))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-infix-dot))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-accept-quasiquote))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-cdot))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-single-flonum))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-decimal-as-inexact))
               (then (return (global.get $true))))
           (if (ref.eq (local.get $v) (global.get $prim:read-case-sensitive))
               (then (return (global.get $true))))
           (global.get $false))

     ;; reparameterize : any/c -> any/c
     ;;   Bootstrap identity for the extracted expander. The scoped
     ;;   installation operation is modeled by call-with-parameterization.
     (func $reparameterize (type $Prim1)
           (param $p (ref eq)) ;; parameterization
           (result   (ref eq))
           (local.get $p))

     ;; current-namespace : [namespace?] -> namespace?
     ;;   Built-in parameter for the active namespace. WebRacket uses a
     ;;   lightweight namespace for module/bootstrap code; parameterize
     ;;   works through the same poor-man parameterization overlay as the
     ;;   other built-in parameters.
     (func $current-namespace/get (type $Prim0)
           (result (ref eq))
           (call $parameter-value-or-global
                 (global.get $prim:current-namespace)
                 (global.get $current-namespace-value)))

     (func $current-namespace/set (type $Prim1)
           (param $ns (ref eq)) ;; namespace?
           (result    (ref eq))

           (if (ref.eq (call $namespace? (local.get $ns)) (global.get $true))
               (then (nop))
               (else
                (call $raise-argument-error1
                      (global.get $symbol:current-namespace)
                      (global.get $string:namespace?)
                      (local.get $ns))
                (unreachable)))
           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:current-namespace)
                                   (local.get $ns)))))
           (global.set $current-namespace-value (local.get $ns))
           (global.get $void))

     (func $current-namespace (type $Prim01)
           (param $ns (ref eq)) ;; optional namespace?, default = current value
           (result    (ref eq))

           (if (ref.eq (local.get $ns) (global.get $missing))
               (then (return (call $current-namespace/get))))
           (call $current-namespace/set (local.get $ns)))

     ;; $build-parameterization-bindings : list? -> list?
     ;;   Reverse parameter/value pairs so lookup can stop at the first
     ;;   match while still giving later extend-parameterization arguments
     ;;   precedence.
     (func $build-parameterization-bindings
           (param $args (ref eq)) ;; parameter/value rest list
           (result      (ref eq))
           (local $rest  (ref eq))
           (local $pair  (ref $Pair))
           (local $param (ref eq))
           (local $val   (ref eq))
           (local $out   (ref eq))

           (local.set $rest (local.get $args))
           (local.set $out  (global.get $null))
           (block $done
                  (loop $loop
                        (if (ref.eq (local.get $rest) (global.get $null))
                            (then (br $done)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                            (then (call $raise-argument-error1
                                        (global.get $symbol:extend-parameterization)
                                        (global.get $string:list?)
                                        (local.get $args))
                                  (unreachable)))
                        (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                        (local.set $param (struct.get $Pair $a (local.get $pair)))
                        (local.set $rest  (struct.get $Pair $d (local.get $pair)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                            (then (call $raise-argument-error1
                                        (global.get $symbol:extend-parameterization)
                                        (global.get $string:list?)
                                        (local.get $args))
                                  (unreachable)))
                        (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                        (local.set $val  (struct.get $Pair $a (local.get $pair)))
                        (local.set $rest (struct.get $Pair $d (local.get $pair)))
                        (local.set $out
                                   (struct.new $Pair
                                               (i32.const 0)
                                               (local.get $param)
                                               (struct.new $Pair
                                                           (i32.const 0)
                                                           (local.get $val)
                                                           (local.get $out))))
                        (br $loop)))
           (local.get $out))

     ;; extend-parameterization : any/c any/c ... -> parameterization?
     ;;   Build a lightweight overlay. The base parameterization is not
     ;;   mutated, and duplicate parameters are resolved by the later
     ;;   argument winning, matching Racket's parameterize behavior.
     (func $extend-parameterization (type $Prim>=1)
           (param $p    (ref eq)) ;; base parameterization or #f
           (param $args (ref eq)) ;; parameter/value rest list
           (result      (ref eq))
           (struct.new $Parameterization
                       (i32.const 0)
                       (local.get $p)
                       (call $build-parameterization-bindings
                             (local.get $args))))

     ;; $parameterization-ref : any/c any/c -> any/c
     ;;   Look up a parameter procedure in an overlay chain; returns
     ;;   $missing when no scoped binding exists.
     (func $parameterization-ref
           (param $paramz (ref eq)) ;; parameterization or #f
           (param $param  (ref eq)) ;; parameter procedure
           (result        (ref eq))
           (local $p        (ref eq))
           (local $bindings (ref eq))
           (local $pair     (ref $Pair))
           (local $key      (ref eq))
           (local $val      (ref eq))

           (local.set $p (local.get $paramz))
           (block $not-found
                  (loop $paramz-loop
                        (if (i32.eqz (ref.test (ref $Parameterization) (local.get $p)))
                            (then (br $not-found)))
                        (local.set $bindings
                                   (struct.get $Parameterization $bindings
                                               (ref.cast (ref $Parameterization)
                                                         (local.get $p))))
                        (block $bindings-done
                               (loop $bindings-loop
                                     (if (ref.eq (local.get $bindings) (global.get $null))
                                         (then (br $bindings-done)))
                                     (local.set $pair
                                                (ref.cast (ref $Pair) (local.get $bindings)))
                                     (local.set $key (struct.get $Pair $a (local.get $pair)))
                                     (local.set $bindings (struct.get $Pair $d (local.get $pair)))
                                     (local.set $pair
                                                (ref.cast (ref $Pair) (local.get $bindings)))
                                     (local.set $val (struct.get $Pair $a (local.get $pair)))
                                     (local.set $bindings (struct.get $Pair $d (local.get $pair)))
                                     (if (ref.eq (local.get $key) (local.get $param))
                                         (then (return (local.get $val))))
                                     (br $bindings-loop)))
                        (local.set $p
                                   (struct.get $Parameterization $base
                                               (ref.cast (ref $Parameterization)
                                                         (local.get $p))))
                        (br $paramz-loop)))
           (global.get $missing))

     ;; $parameter-value-or-global : procedure? any/c -> any/c
     ;;   Read a parameter from the current overlay, falling back to its
     ;;   global default cell.
     (func $parameter-value-or-global
           (param $param  (ref eq)) ;; parameter procedure
           (param $global (ref eq)) ;; fallback global value
           (result        (ref eq))
           (local $v (ref eq))
           (local.set $v
                      (call $parameterization-ref
                            (global.get $current-parameterization-value)
                            (local.get $param)))
           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $missing))
               (then (local.get $global))
               (else (local.get $v))))

     ;; $parameterization-set! : any/c any/c any/c -> i32
     ;;   Mutate the first scoped binding for param in paramz. Returns 1
     ;;   when an existing scoped binding was updated, otherwise 0.
     (func $parameterization-set!
           (param $paramz (ref eq)) ;; parameterization or #f
           (param $param  (ref eq)) ;; parameter procedure
           (param $val    (ref eq)) ;; new value
           (result        i32)
           (local $p        (ref eq))
           (local $bindings (ref eq))
           (local $pair     (ref $Pair))
           (local $val-pair (ref $Pair))
           (local $key      (ref eq))

           (local.set $p (local.get $paramz))
           (block $not-found
                  (loop $paramz-loop
                        (if (i32.eqz (ref.test (ref $Parameterization) (local.get $p)))
                            (then (br $not-found)))
                        (local.set $bindings
                                   (struct.get $Parameterization $bindings
                                               (ref.cast (ref $Parameterization)
                                                         (local.get $p))))
                        (block $bindings-done
                               (loop $bindings-loop
                                     (if (ref.eq (local.get $bindings) (global.get $null))
                                         (then (br $bindings-done)))
                                     (local.set $pair
                                                (ref.cast (ref $Pair) (local.get $bindings)))
                                     (local.set $key (struct.get $Pair $a (local.get $pair)))
                                     (local.set $bindings (struct.get $Pair $d (local.get $pair)))
                                     (local.set $val-pair
                                                (ref.cast (ref $Pair) (local.get $bindings)))
                                     (local.set $bindings
                                                (struct.get $Pair $d (local.get $val-pair)))
                                     (if (ref.eq (local.get $key) (local.get $param))
                                         (then
                                          (struct.set $Pair $a
                                                      (local.get $val-pair)
                                                      (local.get $val))
                                          (return (i32.const 1))))
                                     (br $bindings-loop)))
                        (local.set $p
                                   (struct.get $Parameterization $base
                                               (ref.cast (ref $Parameterization)
                                                         (local.get $p))))
                        (br $paramz-loop)))
           (i32.const 0))

     ;; $set-parameter-value-or-global! : procedure? any/c global-index -> void?
     ;;   Mutating a parameter inside a scoped overlay shadows that overlay;
     ;;   without an overlay, callers update the global cell themselves.
     (func $extend-current-parameterization!
           (param $param (ref eq)) ;; parameter procedure
           (param $val   (ref eq)) ;; new value
           (result       (ref eq))
           (if (call $parameterization-set!
                     (global.get $current-parameterization-value)
                     (local.get $param)
                     (local.get $val))
               (then (return (global.get $void))))
           (global.set $current-parameterization-value
                       (struct.new $Parameterization
                                   (i32.const 0)
                                   (global.get $current-parameterization-value)
                                   (struct.new $Pair
                                               (i32.const 0)
                                               (local.get $param)
                                               (struct.new $Pair
                                                           (i32.const 0)
                                                           (local.get $val)
                                                           (global.get $null)))))
           (global.get $void)))))
