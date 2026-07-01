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
           (global.get $void))

     ;; call-with-parameterization : parameterization? (-> any/c) -> any/c
     ;;   Install a poor-man parameterization while thunk runs. This is the
     ;;   dynamic-scoping half that the with-continuation-mark erasure lacks.
     (func $call-with-parameterization (type $Prim2)
           (param $paramz-raw (ref eq)) ;; parameterization?
           (param $thunk-raw  (ref eq)) ;; procedure?
           (result            (ref eq))

           (local $thunk   (ref $Procedure))
           (local $inv     (ref $ProcedureInvoker))
           (local $args    (ref $Args))
           (local $old     (ref eq))
           (local $res     (ref eq))
           (local $exn-val (ref eq))
           (local $thunk-name (ref eq))
           (local $thunk-debug-id (ref eq))

           (if (i32.eqz (ref.test (ref $Parameterization) (local.get $paramz-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:call-with-parameterization)
                           (global.get $string:parameterization?)
                           (local.get $paramz-raw))
                     (unreachable)))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $thunk-raw)))
               (then (call $raise-argument-error:procedure-expected
                           (local.get $thunk-raw))
                     (unreachable)))
           (local.set $thunk (ref.cast (ref $Procedure) (local.get $thunk-raw)))
           (local.set $inv   (struct.get $Procedure $invoke (local.get $thunk)))
           (local.set $args  (array.new $Args (global.get $null) (i32.const 0)))
           (if (i32.gt_u (global.get $debug-invoke-budget) (i32.const 0))
               (then
                (if (i32.le_u (global.get $debug-label102683-count) (i32.const 12))
                    (then
                     (local.set $thunk-name
                                (struct.get $Procedure $name (local.get $thunk)))
                     (local.set $thunk-debug-id (global.get $false))
                     (if (ref.test (ref $Closure) (local.get $thunk-raw))
                         (then
                          (local.set $thunk-debug-id
                                     (struct.get $Closure $debug-id
                                                 (ref.cast (ref $Closure)
                                                           (local.get $thunk-raw))))))
                     (drop (call $js-log
                                 (global.get $symbol:call-with-parameterization-primitive-entry)))
                     (drop (call $js-log
                                 (call $cons
                                       (call $cons (global.get $symbol:arg1-name)
                                             (call $cons (local.get $thunk-name)
                                                   (global.get $null)))
                                       (global.get $null))))
                     (drop (call $js-log
                                 (call $cons
                                       (call $cons (global.get $symbol:arg1-debug-id)
                                             (call $cons (local.get $thunk-debug-id)
                                                   (global.get $null)))
                                       (global.get $null))))))))
           (local.set $old   (global.get $current-parameterization-value))
           (global.set $current-parameterization-value (local.get $paramz-raw))
           (local.set $res
                      (block $done (result (ref eq))
                             (block $handler-block (result (ref eq))
                                    (try_table (result (ref eq))
                                               (catch $exn $handler-block)
                                               (call_ref $ProcedureInvoker
                                                         (local.get $thunk)
                                                         (local.get $args)
                                                         (local.get $inv))
                                               (br $done)))
                             (local.set $exn-val)
                             (global.set $current-parameterization-value
                                         (local.get $old))
                             (throw $exn (local.get $exn-val))
                             (unreachable)))
           (global.set $current-parameterization-value (local.get $old))
           (local.get $res))

     ;; cache-configuration : exact-nonnegative-integer? (-> any/c) -> any/c
     ;;   Small #%paramz cache used by racket/private/config during
     ;;   expander startup. Racket CS records these once per place; WebRacket
     ;;   keeps an eight-slot cache, enough for the current configuration
     ;;   slots 0, 1, 3, and 4.
     (func $cache-configuration (type $Prim2)
           (param $index-raw (ref eq)) ;; exact-nonnegative-integer?
           (param $thunk-raw (ref eq)) ;; procedure?
           (result           (ref eq))
           (local $index i32)
           (local $cache (ref $Array))
           (local $thunk (ref $Procedure))
           (local $cached (ref eq))
           (local $invoke (ref $ProcedureInvoker))

           (local.set $index (call $fixnum->i32 (local.get $index-raw)))
           (if (i32.ge_u (local.get $index) (i32.const 8))
               (then (call $raise-argument-error1
                           (global.get $symbol:cache-configuration)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $index-raw))
                     (unreachable)))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $thunk-raw)))
               (then (call $raise-argument-error:procedure-expected
                           (local.get $thunk-raw))
                     (unreachable)))
           (local.set $thunk (ref.cast (ref $Procedure) (local.get $thunk-raw)))
           (if (i32.eqz (ref.test (ref $Array)
                                   (global.get $cache-configuration-values)))
               (then
                (global.set $cache-configuration-values
                            (array.new $Array
                                       (global.get $missing)
                                       (i32.const 8)))))
           (local.set $cache
                      (ref.cast (ref $Array)
                                (global.get $cache-configuration-values)))
           (local.set $cached (array.get $Array (local.get $cache) (local.get $index)))
           (if (i32.eqz (ref.eq (local.get $cached) (global.get $missing)))
               (then (return (local.get $cached))))
           (local.set $invoke (struct.get $Procedure $invoke (local.get $thunk)))
           (local.set $cached
                      (call_ref $ProcedureInvoker
                                (local.get $thunk)
                                (array.new $Args
                                           (global.get $null)
                                           (i32.const 0))
                                (local.get $invoke)))
           (array.set $Array (local.get $cache) (local.get $index) (local.get $cached))
           (local.get $cached))

     ;; current-compile-target-machine : [any/c] -> any/c
     ;;   Bootstrap compiler target parameter. WebRacket currently has one
     ;;   target, so the default matches `(system-type 'target-machine)`.
     ;;   The setter accepts any value for expander/compiler compatibility.
     (func $current-compile-target-machine/get (type $Prim0)
           (result (ref eq))
           (local $v (ref eq))

           (local.set $v
                      (call $parameterization-ref
                            (global.get $current-parameterization-value)
                            (global.get $prim:current-compile-target-machine)))
           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $missing))
               (then
                (if (result (ref eq))
                    (ref.eq (global.get $current-compile-target-machine-value)
                            (global.get $false))
                    (then (global.get $symbol:webracket))
                    (else (global.get $current-compile-target-machine-value))))
               (else (local.get $v))))

     (func $current-compile-target-machine/set (type $Prim1)
           (param $v (ref eq)) ;; target machine value
           (result   (ref eq))

           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:current-compile-target-machine)
                                   (local.get $v)))))
           (global.set $current-compile-target-machine-value (local.get $v))
           (global.get $void))

     (func $current-compile-target-machine (type $Prim01)
           (param $v (ref eq)) ;; optional target machine value
           (result   (ref eq))

           (if (ref.eq (local.get $v) (global.get $missing))
               (then (return (call $current-compile-target-machine/get))))
           (call $current-compile-target-machine/set (local.get $v)))

     ;; current-compile-realm : [symbol?] -> symbol?
     ;;   Bootstrap parameter for expander compilation. Racket uses this
     ;;   realm to annotate generated procedures and module code; WebRacket
     ;;   defaults to 'racket and supports parameterize-style overrides.
     (func $current-compile-realm/get (type $Prim0)
           (result (ref eq))
           (local $v (ref eq))

           (local.set $v
                      (call $parameterization-ref
                            (global.get $current-parameterization-value)
                            (global.get $prim:current-compile-realm)))
           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $missing))
               (then
                (if (result (ref eq))
                    (ref.eq (global.get $current-compile-realm-value)
                            (global.get $false))
                    (then (global.get $symbol:racket))
                    (else (global.get $current-compile-realm-value))))
               (else (local.get $v))))

     (func $current-compile-realm/set (type $Prim1)
           (param $v (ref eq)) ;; realm symbol
           (result   (ref eq))

           (if (i32.eqz (ref.test (ref $Symbol) (local.get $v)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-compile-realm)
                           (global.get $string:symbol?)
                           (local.get $v))
                     (unreachable)))
           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:current-compile-realm)
                                   (local.get $v)))))
           (global.set $current-compile-realm-value (local.get $v))
           (global.get $void))

     (func $current-compile-realm (type $Prim01)
           (param $v (ref eq)) ;; optional realm symbol, default 'racket
           (result   (ref eq))

           (if (ref.eq (local.get $v) (global.get $missing))
               (then (return (call $current-compile-realm/get))))
           (call $current-compile-realm/set (local.get $v)))

     ;; current-security-guard : [security-guard?] -> security-guard? or void?
     ;;   Parameter-like current security guard. Access checks are not wired
     ;;   into the browser VFS/network layer yet, but the value protocol is
     ;;   enough for racket/base provider initialization.
     (func $current-security-guard (type $Prim01)
           (param $guard-raw (ref eq)) ;; optional security-guard?
           (result           (ref eq))
           (if (ref.eq (local.get $guard-raw) (global.get $missing))
               (then (return (call $parameter-value-or-global
                                   (global.get $prim:current-security-guard)
                                   (global.get $current-security-guard-value)))))
           (if (i32.eqz (ref.test (ref $SecurityGuard) (local.get $guard-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-security-guard)
                           (global.get $string:security-guard?)
                           (local.get $guard-raw))
                     (unreachable)))
           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                 (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:current-security-guard)
                                   (local.get $guard-raw)))))
           (global.set $current-security-guard-value (local.get $guard-raw))
           (global.get $void))

     ;; current-custodian : [custodian?] -> custodian? or void?
     ;;   Parameter-like current custodian. This currently determines the
     ;;   custodian attached to byte converters and custodian boxes; full
     ;;   resource ownership belongs with the future scheduler/rktio layer.
     (func $current-custodian (type $Prim01)
           (param $cust-raw (ref eq)) ;; optional custodian?
           (result          (ref eq))
           (if (ref.eq (local.get $cust-raw) (global.get $missing))
               (then (return (call $parameter-value-or-global
                                   (global.get $prim:current-custodian)
                                   (global.get $current-custodian-value)))))
           (if (i32.eqz (ref.test (ref $Custodian) (local.get $cust-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-custodian)
                           (global.get $string:custodian?)
                           (local.get $cust-raw))
                     (unreachable)))
           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                 (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:current-custodian)
                                   (local.get $cust-raw)))))
           (global.set $current-custodian-value (local.get $cust-raw))
           (global.get $void))

     ;; current-print : [procedure?] -> procedure?
     ;;   Get or set the top-level printer. The default printer logs
     ;;   the value through `js-log`, which is sufficient for probes.
     (func $current-print (type $Prim01)
           (param $printer-raw (ref eq)) ;; optional procedure?, default current printer
           (result (ref eq))
           (if (ref.eq (local.get $printer-raw) (global.get $missing))
               (then
                (if (ref.eq (global.get $current-print-value) (global.get $false))
                    (then (return (global.get $prim:js-log)))
                    (else (return (global.get $current-print-value))))))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $printer-raw)))
               (then (return (global.get $error))))
           (global.set $current-print-value (local.get $printer-raw))
           (global.get $void))

     ;; current-readtable : [(or/c readtable? #f)] -> (or/c readtable? #f) or void?
     ;;   WebRacket has no readtable values yet, so #f is the only
     ;;   supported setting. This keeps provider code linkable while
     ;;   making real custom-readtable use fail clearly.
     (func $current-readtable (type $Prim01)
           (param $v (ref eq)) ;; optional (or/c readtable? #f), default = current value
           (result   (ref eq))
           (if (ref.eq (local.get $v) (global.get $missing))
               (then (return (call $parameter-value-or-global
                                   (global.get $prim:current-readtable)
                                   (global.get $current-readtable-value)))))
           (if (i32.eqz (ref.eq (local.get $v) (global.get $false)))
               (then
                (call $raise-argument-error1
                      (global.get $symbol:current-readtable)
                      (global.get $string:readtable-or-false)
                      (local.get $v))
                (unreachable)))
           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:current-readtable)
                                   (local.get $v)))))
           (global.set $current-readtable-value (local.get $v))
           (global.get $void))

     ;; current-read-interaction : [procedure?] -> procedure? or void?
     ;;   Parameter for the interactive reader. The default returns
     ;;   EOF, which is enough for expander startup probes that only
     ;;   need the binding to exist.
     (func $current-read-interaction (type $Prim01)
           (param $reader-raw (ref eq)) ;; optional procedure?, default current reader
           (result (ref eq))
           (if (ref.eq (local.get $reader-raw) (global.get $missing))
               (then (return (global.get $current-read-interaction-value))))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $reader-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-read-interaction)
                           (global.get $string:procedure?)
                           (local.get $reader-raw))
                     (unreachable)))
           (global.set $current-read-interaction-value (local.get $reader-raw))
           (global.get $void)))))
