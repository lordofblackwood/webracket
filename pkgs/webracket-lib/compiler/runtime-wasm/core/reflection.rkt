#lang racket

(provide reflection-core-runtime-helpers
         reflection-core-runtime-helper-forms
         reflection-runtime-only-helper-names
         reflection-runtime-helper-forms
         reflection-runtime-string-constants
         reflection-runtime-symbol-constants
         reflection-runtime-only-helpers)

(require "../core-helper.rkt")

;; reflection-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by reflection and module-path helpers.
(define reflection-runtime-string-constants
  '((variable-reference?           "variable-reference?")
    (module-path?                  "module-path?")
    (module-path-or-false?         "(or/c #f module-path?)")
    (module-path-index?            "module-path-index?")
    (resolved-module-path?         "resolved-module-path?")
    (module-path-index-base        "(or/c #f resolved-module-path? module-path-index?)")
    (module-path-index-submod      "(or/c #f (non-empty-listof symbol?))")
    (module-path-index-combine-path-base
     "cannot combine #f path with non-#f base")
    (module-path-index-combine-path-submod
     "cannot combine #f submodule list with non-#f module path")
    (given-base                    "given base")
    (given-module-path             "given module path")
    (given-submodule-list          "given submodule list")
    (variable-reference->module-source "variable-reference->module-source")
    (variable-reference->resolved-module-path "variable-reference->resolved-module-path")))

;; reflection-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by reflection and module-path helpers.
(define reflection-runtime-symbol-constants
  '(namespace))

;; reflection-promoted-runtime-helper-names : (listof symbol?)
;;   Name reflection helpers that are available in the standalone core runtime.
(define reflection-promoted-runtime-helper-names
  '($compiled-expression?
    $compiled-module-expression?
    $readtable?
    $rename-transformer?
    $set!-transformer?
    $special-comment?
    $syntax-original?
    $syntax-tainted?
    $internal-definition-context?
    $liberal-define-context?
    $module-path-index?
    $resolved-module-path?
    $expander-namespace-struct?/i32
    $namespace?
    $variable-reference?
    $raise-unbound-variable-reference))

;; make-predicate-body : symbol? -> (listof datum?)
;;   Generate a standard WebRacket predicate body for ref-type.
(define (make-predicate-body ref-type)
  `((param $v (ref eq))
    (result   (ref eq))
    (if (result (ref eq))
        (ref.test (ref ,ref-type) (local.get $v))
        (then (global.get $true))
        (else (global.get $false)))))

;; reflection-runtime-only-forms : (listof datum?)
;;   Enumerate reflection, module-path, and variable-reference helpers.
(define reflection-runtime-only-forms
  `(
        ;; compiled-expression? : any/c -> boolean?
        ;;   Runtime WebRacket values are not compiled expressions; the build
        ;;   pipeline consumes compiled artifacts before Wasm generation.
        (func $compiled-expression? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; compiled-module-expression? : any/c -> boolean?
        ;;   WebRacket currently consumes compiled-module metadata at build
        ;;   time. Runtime values are not compiled module expressions yet.
        (func $compiled-module-expression? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; readtable? : any/c -> boolean?
        ;;   Custom readtables are not WebRacket runtime values yet.
        (func $readtable? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; rename-transformer? : any/c -> boolean?
        ;;   Rename transformers are compile-time transformer values produced
        ;;   by make-rename-transformer or struct properties. WebRacket does
        ;;   not currently expose transformer objects at runtime.
        (func $rename-transformer? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; make-rename-transformer : identifier? -> any/c
        ;;   Bootstrap identity representation. Full WebRacket expander support
        ;;   should replace this with a real rename-transformer value and update
        ;;   rename-transformer?/rename-transformer-target accordingly.
        (func $make-rename-transformer (type $Prim1)
              (param $id (ref eq)) ;; identifier?
              (result    (ref eq))
              (if (result (ref eq))
                  (ref.eq (call $identifier? (local.get $id)) (global.get $true))
                  (then (local.get $id))
                  (else
                   (call $raise-argument-error1
                         (global.get $symbol:make-rename-transformer)
                         (global.get $string:identifier?)
                         (local.get $id))
                   (unreachable))))

        ;; set!-transformer? : any/c -> boolean?
        ;;   Set!-transformers are compile-time transformer values produced
        ;;   by make-set!-transformer or struct properties. WebRacket does not
        ;;   currently expose such transformer values at runtime.
        (func $set!-transformer? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; set!-transformer-procedure : set!-transformer? -> procedure?
        ;;   Accessor placeholder until WebRacket represents assignment
        ;;   transformers and prop:set!-transformer values. Since
        ;;   set!-transformer? is currently always #f, this always raises the
        ;;   documented contract error.
        (func $set!-transformer-procedure (type $Prim1)
              (param $v (ref eq)) ;; set!-transformer?
              (result   (ref eq))
              (call $raise-argument-error1
                    (global.get $symbol:set!-transformer-procedure)
                    (global.get $string:set!-transformer?)
                    (local.get $v))
              (unreachable))

        ;; special-comment? : any/c -> boolean?
        ;;   Reader extensions can manufacture special-comment values in full
        ;;   Racket. WebRacket has no special-comment runtime value yet.
        (func $special-comment? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; syntax-original? : syntax? -> boolean?
        ;;   Full Racket tracks originalness as hidden syntax metadata. The
        ;;   current WebRacket syntax representation does not preserve that
        ;;   property, so runtime syntax is conservatively non-original.
        (func $syntax-original? (type $Prim1)
              (param $stx (ref eq)) ;; syntax?
              (result     (ref eq))
              (if (ref.eq (call $syntax? (local.get $stx)) (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:syntax-original?)
                              (global.get $string:syntax?)
                              (local.get $stx))
                        (unreachable)))
              (global.get $false))

        ;; syntax-tainted? : syntax? -> boolean?
        ;;   Tainted syntax protects values that came from syntax errors and
        ;;   macro expansion boundaries. WebRacket's syntax values do not yet
        ;;   track taint metadata, so current runtime syntax is never tainted.
        (func $syntax-tainted? (type $Prim1)
              (param $stx (ref eq)) ;; syntax?
              (result     (ref eq))
              (if (ref.eq (call $syntax? (local.get $stx)) (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:syntax-tainted?)
                              (global.get $string:syntax?)
                              (local.get $stx))
                        (unreachable)))
              (global.get $false))

        ;; internal-definition-context? : any/c -> boolean?
        ;;   Internal-definition contexts are expander-time scope/binding
        ;;   objects. WebRacket does not expose them as runtime values yet.
        (func $internal-definition-context? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; liberal-define-context? : any/c -> boolean?
        ;;   Liberal define contexts are expander metadata values. WebRacket
        ;;   does not expose those contexts as runtime values yet.
        (func $liberal-define-context? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (global.get $false))

        ;; module-path? : any/c -> boolean?
        ;;   Supports WebRacket's current lowered module-path values: symbols,
        ;;   strings, path values, and structured `(submod ...)` forms. The
        ;;   structured check is intentionally permissive for now; module path
        ;;   indexes only preserve the path datum and do not resolve modules.
        (func $module-path? (type $Prim1)
              (param $v (ref eq)) ;; any/c
              (result   (ref eq))
              (local $pair (ref $Pair))
              (if (ref.eq (call $symbol? (local.get $v)) (global.get $true))
                  (then (return (global.get $true))))
              (if (ref.eq (call $string? (local.get $v)) (global.get $true))
                  (then (return (global.get $true))))
              (if (ref.eq (call $path? (local.get $v)) (global.get $true))
                  (then (return (global.get $true))))
              (if (ref.test (ref $Pair) (local.get $v))
                  (then
                   (local.set $pair (ref.cast (ref $Pair) (local.get $v)))
                   (if (ref.eq (struct.get $Pair $a (local.get $pair))
                               (global.get $symbol:submod))
                       (then (return (global.get $true))))))
              (global.get $false))

        ;; module-path-index? : any/c -> boolean?
        ;;   Recognize WebRacket's small runtime module-path-index wrapper.
        (func $module-path-index? (type $Prim1)
              ,@(make-predicate-body '$ModulePathIndex))

        ;; non-empty-listof-symbol?/i32 : any/c -> i32
        ;;   Check the submodule-list contract for module-path-index-join.
        (func $non-empty-listof-symbol?/i32
              (param $v (ref eq))
              (result   i32)
              (local $cursor (ref eq))
              (local $pair   (ref $Pair))
              (if (i32.eqz (ref.test (ref $Pair) (local.get $v)))
                  (then (return (i32.const 0))))
              (local.set $cursor (local.get $v))
              (block $done
                     (loop $loop
                           (br_if $done
                                  (ref.eq (local.get $cursor)
                                          (global.get $null)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $cursor)))
                               (then (return (i32.const 0))))
                           (local.set $pair
                                      (ref.cast (ref $Pair) (local.get $cursor)))
                           (if (i32.eqz
                                (ref.test (ref $Symbol)
                                          (struct.get $Pair $a (local.get $pair))))
                               (then (return (i32.const 0))))
                           (local.set $cursor
                                      (struct.get $Pair $d (local.get $pair)))
                           (br $loop)))
              (i32.const 1))

        ;; module-path-index-join : (or/c module-path? #f) (or/c module-path-index? resolved-module-path? #f) [submod] -> module-path-index?
        ;;   Minimal MPI constructor for already-lowered module metadata. It
        ;;   preserves path/base/submodule fields but does not invoke a module
        ;;   name resolver.
        (func $module-path-index-join (type $Prim23)
              (param $path   (ref eq)) ;; (or/c module-path? #f)
              (param $base   (ref eq)) ;; (or/c module-path-index? resolved-module-path? #f)
              (param $submod (ref eq)) ;; optional (or/c #f (non-empty-listof symbol?)), default = #f
              (result        (ref eq))
              (if (ref.eq (local.get $submod) (global.get $missing))
                  (then (local.set $submod (global.get $false))))
              (if (i32.and
                   (i32.eqz (ref.eq (local.get $path) (global.get $false)))
                   (ref.eq (call $module-path? (local.get $path)) (global.get $false)))
                  (then
                   (call $raise-argument-error1
                         (global.get $symbol:module-path-index-join)
                         (global.get $string:module-path-or-false?)
                         (local.get $path))
                   (unreachable)))
              (if (i32.eqz
                   (i32.or
                    (ref.eq (local.get $base) (global.get $false))
                    (i32.or
                     (ref.test (ref $ModulePathIndex) (local.get $base))
                     (ref.test (ref $ResolvedModulePath) (local.get $base)))))
                  (then
                   (call $raise-argument-error1
                         (global.get $symbol:module-path-index-join)
                         (global.get $string:module-path-index-base)
                         (local.get $base))
                   (unreachable)))
              (if (i32.eqz (ref.eq (local.get $submod) (global.get $false)))
                  (then
                   (if (i32.eqz (call $non-empty-listof-symbol?/i32
                                       (local.get $submod)))
                       (then
                        (call $raise-argument-error1
                              (global.get $symbol:module-path-index-join)
                              (global.get $string:module-path-index-submod)
                              (local.get $submod))
                        (unreachable)))))
              (if (i32.and
                   (ref.eq (local.get $path) (global.get $false))
                   (i32.eqz (ref.eq (local.get $base) (global.get $false))))
                  (then
                   (call $raise-arguments-error
                         (global.get $symbol:module-path-index-join)
                         (global.get $string:module-path-index-combine-path-base)
                         (array.new_fixed $Args 2
                                          (global.get $string:given-base)
                                          (local.get $base)))
                   (unreachable)))
              (if (i32.and
                   (i32.eqz (ref.eq (local.get $path) (global.get $false)))
                   (i32.eqz (ref.eq (local.get $submod) (global.get $false))))
                  (then
                   (call $raise-arguments-error
                         (global.get $symbol:module-path-index-join)
                         (global.get $string:module-path-index-combine-path-submod)
                         (array.new_fixed $Args 4
                                          (global.get $string:given-module-path)
                                          (local.get $path)
                                          (global.get $string:given-submodule-list)
                                          (local.get $submod)))
                   (unreachable)))
              (struct.new $ModulePathIndex
                          (i32.const 0)
                          (local.get $path)
                          (local.get $base)
                          (local.get $submod)
                          (global.get $false)))

        ;; module-path-index-split : module-path-index? -> values path base
        ;;   Return the path/base fields preserved by module-path-index-join.
        (func $module-path-index-split
              (param $mpi (ref eq)) ;; module-path-index?
              (result (ref $Values))
              (if (i32.eqz (ref.test (ref $ModulePathIndex) (local.get $mpi)))
                  (then
                   (call $raise-argument-error1
                         (global.get $symbol:module-path-index-split)
                         (global.get $string:module-path-index?)
                         (local.get $mpi))
                   (unreachable)))
              (array.new_fixed $Values 2
                               (struct.get $ModulePathIndex $path
                                           (ref.cast (ref $ModulePathIndex) (local.get $mpi)))
                               (struct.get $ModulePathIndex $base
                                           (ref.cast (ref $ModulePathIndex) (local.get $mpi)))))

        ;; module-path-index-submodule : module-path-index? -> (or/c #f (non-empty-listof symbol?))
        ;;   Return a submodule list only for self/submodule indexes.
        (func $module-path-index-submodule (type $Prim1)
              (param $mpi (ref eq)) ;; module-path-index?
              (result     (ref eq))
              (local $idx (ref $ModulePathIndex))
              (if (i32.eqz (ref.test (ref $ModulePathIndex) (local.get $mpi)))
                  (then
                   (call $raise-argument-error1
                         (global.get $symbol:module-path-index-submodule)
                         (global.get $string:module-path-index?)
                         (local.get $mpi))
                   (unreachable)))
              (local.set $idx (ref.cast (ref $ModulePathIndex) (local.get $mpi)))
              (if (result (ref eq))
                  (i32.and
                   (ref.eq (struct.get $ModulePathIndex $path (local.get $idx)) (global.get $false))
                   (ref.eq (struct.get $ModulePathIndex $base (local.get $idx)) (global.get $false)))
                  (then (struct.get $ModulePathIndex $submod (local.get $idx)))
                  (else (global.get $false))))

        ;; module-path-index-resolve : module-path-index? [any/c] [syntax?/#f] -> resolved-module-path?
        ;;   Resolve only the already-lowered names used by Webify probes.
        ;;   Relative resolver, loading, and source-syntax behavior remain out
        ;;   of scope for now.
        (func $module-path-index-resolve (type $Prim13)
              (param $mpi   (ref eq)) ;; module-path-index?
              (param $load? (ref eq)) ;; optional any/c, default = #f
              (param $stx   (ref eq)) ;; optional (or/c syntax? #f), default = #f
              (result       (ref eq))
              (local $idx      (ref $ModulePathIndex))
              (local $resolved (ref eq))
              (local $path     (ref eq))
              (local $base     (ref eq))
              (if (i32.eqz (ref.test (ref $ModulePathIndex) (local.get $mpi)))
                  (then
                   (call $raise-argument-error1
                         (global.get $symbol:module-path-index-resolve)
                         (global.get $string:module-path-index?)
                         (local.get $mpi))
                   (unreachable)))
              (local.set $idx (ref.cast (ref $ModulePathIndex) (local.get $mpi)))
              (local.set $resolved (struct.get $ModulePathIndex $resolved (local.get $idx)))
              (if (ref.test (ref $ResolvedModulePath) (local.get $resolved))
                  (then (return (local.get $resolved))))
              (local.set $path (struct.get $ModulePathIndex $path (local.get $idx)))
              (local.set $base (struct.get $ModulePathIndex $base (local.get $idx)))
              (if (ref.test (ref $ResolvedModulePath) (local.get $base))
                  (then
                   (struct.set $ModulePathIndex $resolved
                               (local.get $idx)
                               (local.get $base))
                   (return (local.get $base))))
              (if (ref.eq (local.get $path) (global.get $false))
                  (then
                   (call $raise-argument-error1
                         (global.get $symbol:module-path-index-resolve)
                         (global.get $string:module-path?)
                         (local.get $path))
                   (unreachable)))
              (local.set $resolved
                         (struct.new $ResolvedModulePath
                                     (i32.const 0)
                                     (local.get $path)))
              (struct.set $ModulePathIndex $resolved (local.get $idx) (local.get $resolved))
              (local.get $resolved))

        ;; resolved-module-path? : any/c -> boolean?
        ;;   Recognize WebRacket's small resolved-module-path wrapper.
        (func $resolved-module-path? (type $Prim1)
              ,@(make-predicate-body '$ResolvedModulePath))

        ;; resolved-module-path-name : resolved-module-path? -> any/c
        ;;   Return the lowered module identity stored in a resolved wrapper.
        (func $resolved-module-path-name (type $Prim1)
              (param $module-path (ref eq)) ;; resolved-module-path?
              (result             (ref eq))
              (if (i32.eqz (ref.test (ref $ResolvedModulePath) (local.get $module-path)))
                  (then
                   (call $raise-argument-error1
                         (global.get $symbol:resolved-module-path-name)
                         (global.get $string:resolved-module-path?)
                         (local.get $module-path))
                   (unreachable)))
              (struct.get $ResolvedModulePath $name
                          (ref.cast (ref $ResolvedModulePath) (local.get $module-path))))

        ;; expander-namespace-struct?/i32 : any/c -> i32
        ;;   Recognize the expander's own authentic `namespace` struct. This is
        ;;   a bootstrap compatibility bridge: WebRacket also has a runtime
        ;;   $Namespace type, but the schemified expander carries its own
        ;;   namespace records through ordinary Racket structs.
        (func $expander-namespace-struct?/i32
              (param $v (ref eq)) ;; candidate value
              (result   i32)
              (local $s (ref $Struct))
              (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                  (then (return (i32.const 0))))
              (local.set $s (ref.cast (ref $Struct) (local.get $v)))
              (ref.eq
               (struct.get $StructType $name
                           (struct.get $Struct $type (local.get $s)))
               (global.get $symbol:namespace)))

        (func $namespace? (type $Prim1)
              (param $v (ref eq)) ;; candidate value
              (result   (ref eq))
              (if (result (ref eq))
                  (i32.or (ref.test (ref $Namespace) (local.get $v))
                          (call $expander-namespace-struct?/i32 (local.get $v)))
                  (then (global.get $true))
                  (else (global.get $false))))

        ; The form `#%variable-reference` can occur in fully expanded syntax,
        ; so the compiler builds $VariableReference instances directly.

        (func $variable-reference? (type $Prim1)
              ,@(make-predicate-body '$VariableReference))

        ;; variable-reference->instance : variable-reference? [any/c] -> any/c
        ;;   The expander bootstrap only needs the name to exist for now.
        ;;   WebRacket's variable-reference payload does not yet retain an
        ;;   enclosing module instance, so report that no instance is known.
        (func $variable-reference->instance (type $Prim12)
              (param $varref (ref eq)) ;; variable-reference?
              (param $ref-site? (ref eq)) ;; optional; default #f
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference->instance)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (global.get $false))

        ;; variable-reference->module-path-index : variable-reference? -> (or/c module-path-index? #f)
        ;;   WebRacket variable references do not yet retain module-path-index
        ;;   identity. Returning #f matches Racket's top-level-reference result.
        (func $variable-reference->module-path-index (type $Prim1)
              (param $varref (ref eq)) ;; variable-reference?
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference->module-path-index)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (global.get $false))

        ;; variable-reference->module-base-phase : variable-reference? -> exact-integer?
        ;;   WebRacket variable references do not yet retain namespace phase
        ;;   identity. Returning 0 matches Racket's non-module-reference result.
        (func $variable-reference->module-base-phase (type $Prim1)
              (param $varref (ref eq)) ;; variable-reference?
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference->module-base-phase)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (ref.i31 (i32.const 0)))

        ;; variable-reference->namespace : variable-reference? -> namespace?
        ;;   WebRacket variable references do not retain their source
        ;;   namespace. Return the program's top-level namespace, which is the
        ;;   namespace used by bootstrap helpers such as racket/lazy-require.
        (func $variable-reference->namespace (type $Prim1)
              (param $varref (ref eq)) ;; variable-reference?
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference->namespace)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (ref.cast (ref eq) (global.get $top-level-namespace)))

        ;; variable-reference->module-source : variable-reference? -> (or/c symbol? path? #f)
        ;;   WebRacket variable references do not yet retain source-module
        ;;   identity. Returning #f matches Racket's top-level-reference result.
        (func $variable-reference->module-source (type $Prim1)
              (param $varref (ref eq)) ;; variable-reference?
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference->module-source)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (global.get $false))

        ;; variable-reference->module-source/submod : variable-reference? -> any/c
        ;;   Mirror the `syntax/location` helper that combines a variable
        ;;   reference's source module with any resolved submodule suffix.
        (func $variable-reference->module-source/submod (type $Prim1)
              (param $varref (ref eq)) ;; variable-reference?
              (result        (ref eq))
              (local $src   (ref eq))
              (local $rname (ref eq))
              (local $name  (ref eq))
              (local.set $src
                         (call $variable-reference->module-source
                               (local.get $varref)))
              (local.set $rname
                         (call $variable-reference->resolved-module-path
                               (local.get $varref)))
              (local.set $name
                         (if (result (ref eq))
                             (ref.eq (local.get $rname) (global.get $false))
                             (then (global.get $false))
                             (else (call $resolved-module-path-name
                                         (local.get $rname)))))
              (if (result (ref eq))
                  (ref.eq (call $pair? (local.get $name)) (global.get $true))
                  (then
                   (call $cons
                         (local.get $src)
                         (call $cdr (local.get $name))))
                  (else (local.get $src))))

        ;; variable-reference->resolved-module-path : variable-reference? -> (or/c resolved-module-path? #f)
        ;;   WebRacket variable references do not yet retain module path identity.
        ;;   Returning #f matches Racket's top-level-reference result and is enough
        ;;   for provider code that only needs a best-effort source label.
        (func $variable-reference->resolved-module-path (type $Prim1)
              (param $varref (ref eq)) ;; variable-reference?
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference->resolved-module-path)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (global.get $false))

        ; This function determines if the variable stems from a module compiled in unsafe mode or not.
        (func $variable-reference-from-unsafe? (type $Prim1)
              (param  $varref (ref eq)) ;; variable-reference?
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference-from-unsafe?)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (struct.get $VariableReference $from-unsafe?
                          (ref.cast (ref $VariableReference) (local.get $varref))))

        (func $variable-reference-constant? (type $Prim1)
              (param $varref (ref eq)) ;; variable-reference?
              (result (ref eq))
              (if (i32.eqz (ref.test (ref $VariableReference) (local.get $varref)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:variable-reference-constant?)
                              (global.get $string:variable-reference?)
                              (local.get $varref))
                        (unreachable)))
              (struct.get $VariableReference $constant?
                          (ref.cast (ref $VariableReference) (local.get $varref))))

	        (func $raise-unbound-variable-reference (type $Prim1)
	              (param $name (ref eq))
	              (result (ref eq))
	              (drop (call $raise
	                          (call $exn:fail:contract:variable
	                                (call $symbol->string
	                                      (ref.cast (ref $Symbol)
	                                                (local.get $name)))
	                                (call $current-continuation-marks
	                                      (global.get $missing))
	                                (local.get $name))
	                          (global.get $true)))
	              (unreachable))
     ))

;; reflection-all-runtime-helpers : (listof core-runtime-helper?)
;;   Register reflection, module-path, and variable-reference helpers.
(define reflection-all-runtime-helpers
  (function-forms->runtime-helpers
   'reflection-runtime-only-helpers
   reflection-runtime-only-forms))

;; reflection-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate reflection helpers available in the standalone core runtime.
(define reflection-core-runtime-helpers
  (select-runtime-helpers reflection-all-runtime-helpers
                          reflection-promoted-runtime-helper-names))

;; reflection-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate reflection helpers that still depend on monolithic runtime state.
(define reflection-runtime-only-helpers
  (remove-runtime-helpers reflection-all-runtime-helpers
                          reflection-promoted-runtime-helper-names))

;; reflection-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted reflection helpers in runtime assembly order.
(define (reflection-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list reflection-promoted-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; reflection-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for reflection helpers.
(define reflection-runtime-only-helper-names
  (map core-runtime-helper-name reflection-runtime-only-helpers))

;; reflection-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render reflection helpers in runtime assembly order.
(define (reflection-runtime-helper-forms helper-index)
  (for/list ([name (in-list reflection-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define reflection-core-helper-index
    (make-core-runtime-helper-index reflection-core-runtime-helpers))

  (define reflection-helper-index
    (make-core-runtime-helper-index
     (append reflection-core-runtime-helpers
             reflection-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name reflection-core-runtime-helpers)
   reflection-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (reflection-core-runtime-helper-forms reflection-core-helper-index))
   reflection-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (reflection-runtime-helper-forms reflection-helper-index))
   reflection-runtime-only-helper-names))
