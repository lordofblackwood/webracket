#lang racket

(provide compile-parameter-global-forms
         compile-parameter-global-names
         promoted-parameter-primitive-global-forms
         promoted-parameter-primitive-global-names
         parameter-runtime-string-constants
         parameter-runtime-symbol-constants
         compile-parameter-core-runtime-helper-forms
         compile-parameter-runtime-helper-forms
         current-security-guard-core-runtime-helper-forms
         current-security-guard-runtime-helper-forms
         current-custodian-core-runtime-helper-forms
         current-custodian-runtime-helper-forms
         current-pseudo-random-generator-core-runtime-helper-forms
         current-pseudo-random-generator-runtime-helper-forms
         current-environment-variables-runtime-helper-forms
         current-print-runtime-helper-forms
         current-readtable-core-runtime-helper-forms
         current-readtable-runtime-helper-forms
         current-read-interaction-runtime-helper-forms
         current-load-relative-directory-runtime-helper-forms
         parameterization-runtime-helper-forms
         namespace-parameter-core-runtime-helper-forms
         namespace-parameter-runtime-helper-forms
         parameterization-binding-runtime-helper-forms
         parameterization-binding-core-runtime-helper-forms
         parameter-core-runtime-helpers
         parameterization-call-runtime-helper-forms
         parameterization-global-forms
         parameterization-global-names
         parameterization-initializer-forms
         parameter-runtime-only-helpers
         parameter-width-core-runtime-helper-forms
         parameter-width-runtime-helper-forms
         parameter-error-rendering-runtime-helper-forms
         parameter-directory-runtime-helper-forms
         environment-parameter-global-forms
         environment-parameter-global-names
         environment-parameter-initializer-forms
         error-rendering-handler-global-forms
         error-rendering-handler-global-names
         error-value-handler-late-initializer-forms
         error-syntax-handler-late-initializer-forms
         print-read-parameter-global-forms
         print-read-parameter-global-names
         print-read-parameter-late-initializer-forms
         reader-printer-policy-parameter-global-forms
         reader-printer-policy-parameter-global-names
         reader-printer-policy-parameter-primitive-global-forms
         reader-printer-policy-parameter-primitive-global-names
         reader-printer-policy-parameter-helper-forms)

(require "../core-helper.rkt")

;; parameter-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by parameter and parameterization helpers.
(define parameter-runtime-string-constants
  '((parameter?        "parameter?")
    (parameterization? "parameterization?")
    (cache-configuration-index "(integer-in 0 7)")
    (current-print:procedure-arity-1 "(procedure-arity-includes/c 1)")
    (readtable-or-false "(or/c readtable? #f)")
    (current-environment-variables:environment-variables? "environment-variables?")))

;; parameter-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by reader, printer, and compile parameters.
(define parameter-runtime-symbol-constants
  '(load-on-demand-enabled
    call-with-parameterization-primitive-entry
    arg1-name
    arg1-debug-id
    read-square-bracket-as-paren
    read-curly-brace-as-paren
    read-square-bracket-with-tag
    read-curly-brace-with-tag
    read-accept-reader
    read-accept-lang
    read-accept-compiled
    read-accept-box
    read-accept-bar-quote
    read-accept-graph
    read-syntax-accept-graph
    read-accept-dot
    read-accept-infix-dot
    read-accept-quasiquote
    read-cdot
    read-single-flonum
    read-decimal-as-inexact
    read-case-sensitive
    print-syntax-width
    error-print-width
    error-print-source-location
    break-enabled-key
    exception-handler-key
    parameterization-key
    current-compile-target-machine
    current-compile-realm
    current-print
    current-environment-variables))

;; reader-printer-policy-parameter-specs : (listof (list symbol? symbol? symbol? symbol?))
;;   Describe the boolean reader/printing policy parameters with their
;;   function, error-name symbol, global value cell, and primitive procedure.
(define reader-printer-policy-parameter-specs
  '(( $load-on-demand-enabled
      $symbol:load-on-demand-enabled
      $load-on-demand-enabled-value
      $prim:load-on-demand-enabled)
    ( $use-user-specific-search-paths
      $symbol:use-user-specific-search-paths
      $use-user-specific-search-paths-value
      $prim:use-user-specific-search-paths)
    ( $read-square-bracket-as-paren
      $symbol:read-square-bracket-as-paren
      $read-square-bracket-as-paren-value
      $prim:read-square-bracket-as-paren)
    ( $read-curly-brace-as-paren
      $symbol:read-curly-brace-as-paren
      $read-curly-brace-as-paren-value
      $prim:read-curly-brace-as-paren)
    ( $read-square-bracket-with-tag
      $symbol:read-square-bracket-with-tag
      $read-square-bracket-with-tag-value
      $prim:read-square-bracket-with-tag)
    ( $read-curly-brace-with-tag
      $symbol:read-curly-brace-with-tag
      $read-curly-brace-with-tag-value
      $prim:read-curly-brace-with-tag)
    ( $read-accept-reader
      $symbol:read-accept-reader
      $read-accept-reader-value
      $prim:read-accept-reader)
    ( $read-accept-lang
      $symbol:read-accept-lang
      $read-accept-lang-value
      $prim:read-accept-lang)
    ( $read-accept-compiled
      $symbol:read-accept-compiled
      $read-accept-compiled-value
      $prim:read-accept-compiled)
    ( $read-accept-box
      $symbol:read-accept-box
      $read-accept-box-value
      $prim:read-accept-box)
    ( $read-accept-bar-quote
      $symbol:read-accept-bar-quote
      $read-accept-bar-quote-value
      $prim:read-accept-bar-quote)
    ( $read-accept-graph
      $symbol:read-accept-graph
      $read-accept-graph-value
      $prim:read-accept-graph)
    ( $read-syntax-accept-graph
      $symbol:read-syntax-accept-graph
      $read-syntax-accept-graph-value
      $prim:read-syntax-accept-graph)
    ( $read-accept-dot
      $symbol:read-accept-dot
      $read-accept-dot-value
      $prim:read-accept-dot)
    ( $read-accept-infix-dot
      $symbol:read-accept-infix-dot
      $read-accept-infix-dot-value
      $prim:read-accept-infix-dot)
    ( $read-accept-quasiquote
      $symbol:read-accept-quasiquote
      $read-accept-quasiquote-value
      $prim:read-accept-quasiquote)
    ( $read-cdot
      $symbol:read-cdot
      $read-cdot-value
      $prim:read-cdot)
    ( $read-single-flonum
      $symbol:read-single-flonum
      $read-single-flonum-value
      $prim:read-single-flonum)
    ( $read-decimal-as-inexact
      $symbol:read-decimal-as-inexact
      $read-decimal-as-inexact-value
      $prim:read-decimal-as-inexact)
    ( $read-case-sensitive
      $symbol:read-case-sensitive
      $read-case-sensitive-value
      $prim:read-case-sensitive)
    ( $print-pair-curly-braces
      $symbol:print-pair-curly-braces
      $print-pair-curly-braces-value
      $prim:print-pair-curly-braces)
    ( $print-mpair-curly-braces
      $symbol:print-mpair-curly-braces
      $print-mpair-curly-braces-value
      $prim:print-mpair-curly-braces)
    ( $print-unreadable
      $symbol:print-unreadable
      $print-unreadable-value
      $prim:print-unreadable)
    ( $print-graph
      $symbol:print-graph
      $print-graph-value
      $prim:print-graph)
    ( $print-struct
      $symbol:print-struct
      $print-struct-value
      $prim:print-struct)
    ( $print-box
      $symbol:print-box
      $print-box-value
      $prim:print-box)
    ( $print-vector-length
      $symbol:print-vector-length
      $print-vector-length-value
      $prim:print-vector-length)
    ( $print-hash-table
      $symbol:print-hash-table
      $print-hash-table-value
      $prim:print-hash-table)
    ( $print-boolean-long-form
      $symbol:print-boolean-long-form
      $print-boolean-long-form-value
      $prim:print-boolean-long-form)
    ( $print-reader-abbreviations
      $symbol:print-reader-abbreviations
      $print-reader-abbreviations-value
      $prim:print-reader-abbreviations)
    ( $print-as-expression
      $symbol:print-as-expression
      $print-as-expression-value
      $prim:print-as-expression)
    ( $error-print-source-location
      $symbol:error-print-source-location
      $error-print-source-location-value
      $prim:error-print-source-location)))

;; parameter-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a parameter backing-cell form.
(define (parameter-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'parameter-global-form-name
              "expected global form, got: ~s"
              form)]))

;; environment-parameter-global-forms : (listof datum?)
;;   Declare the global backing cell for current-environment-variables.
(define environment-parameter-global-forms
  '(
               (global $current-environment-variables-value (mut (ref eq)) (ref.i31 (i32.const 0)))))

;; environment-parameter-global-names : (listof symbol?)
;;   Enumerate current-environment-variables globals shared by split modules.
(define environment-parameter-global-names
  (map parameter-global-form-name environment-parameter-global-forms))

;; environment-parameter-initializer-forms : (listof datum?)
;;   Initialize the current-environment-variables backing value.
(define environment-parameter-initializer-forms
  '(
                     (global.set $current-environment-variables-value
                                 (struct.new $EnvironmentVariables
                                             (i32.const 0)))))

;; print-read-parameter-global-forms : (listof datum?)
;;   Declare globals backing current-print and current-read-interaction.
(define print-read-parameter-global-forms
  '(
               (global $current-print-value       (mut (ref eq)) (global.get $false))
               (global $current-read-interaction-value (mut (ref eq)) (global.get $false))))

;; print-read-parameter-global-names : (listof symbol?)
;;   Enumerate current-print/current-read-interaction globals shared by split modules.
(define print-read-parameter-global-names
  (map parameter-global-form-name print-read-parameter-global-forms))

;; print-read-parameter-late-initializer-forms : (listof datum?)
;;   Initialize current-read-interaction after primitive globals are ready.
(define print-read-parameter-late-initializer-forms
  '(
                    (global.set $current-read-interaction-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:default-read-interaction)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-current-read-interaction)
                                            (global.get $false)))))

;; error-rendering-handler-global-forms : (listof datum?)
;;   Declare globals backing error-rendering handler parameters.
(define error-rendering-handler-global-forms
  '(
               (global $error-value->string-handler-value (mut (ref eq)) (global.get $false))
               (global $error-syntax->string-handler-value (mut (ref eq)) (global.get $false))
               (global $error-syntax->name-handler-value (mut (ref eq)) (global.get $false))
               (global $error-module-path->string-handler-value (mut (ref eq)) (global.get $false))))

;; error-rendering-handler-global-names : (listof symbol?)
;;   Enumerate error-rendering handler globals shared by split modules.
(define error-rendering-handler-global-names
  (map parameter-global-form-name error-rendering-handler-global-forms))

;; error-value-handler-late-initializer-forms : (listof datum?)
;;   Initialize error-value->string-handler after primitive globals are ready.
(define error-value-handler-late-initializer-forms
  '(
                    (global.set $error-value->string-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-value->string-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-error-value->string-handler)
                                            (global.get $false)))))

;; error-syntax-handler-late-initializer-forms : (listof datum?)
;;   Initialize syntax and module-path error-rendering handlers.
(define error-syntax-handler-late-initializer-forms
  '(
                    (global.set $error-syntax->string-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-syntax->string-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-error-syntax->string-handler)
                                            (global.get $false)))
                    (global.set $error-syntax->name-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-syntax->name-handler)
                                            (ref.i31 (i32.const 2))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-1)
                                            (ref.func $default-error-syntax->name-handler)
                                            (global.get $false)))
                    (global.set $error-module-path->string-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:error-module-path->string-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-error-module-path->string-handler)
                                            (global.get $false)))))

;; reader-printer-policy-parameter-global-forms : (listof datum?)
;;   Declare reader, printer, and error-rendering policy parameter globals.
(define reader-printer-policy-parameter-global-forms
  '(
               (global $load-on-demand-enabled-value (mut (ref eq)) (global.get $true))
               (global $use-user-specific-search-paths-value (mut (ref eq)) (global.get $true))
               (global $read-square-bracket-as-paren-value (mut (ref eq)) (global.get $true))
               (global $read-curly-brace-as-paren-value   (mut (ref eq)) (global.get $true))
               (global $read-square-bracket-with-tag-value (mut (ref eq)) (global.get $false))
               (global $read-curly-brace-with-tag-value   (mut (ref eq)) (global.get $false))
               (global $read-accept-reader-value       (mut (ref eq)) (global.get $true))
               (global $read-accept-lang-value         (mut (ref eq)) (global.get $true))
               (global $read-accept-compiled-value     (mut (ref eq)) (global.get $false))
               (global $read-accept-box-value          (mut (ref eq)) (global.get $true))
               (global $read-accept-bar-quote-value    (mut (ref eq)) (global.get $true))
               (global $read-accept-graph-value        (mut (ref eq)) (global.get $true))
               (global $read-syntax-accept-graph-value (mut (ref eq)) (global.get $false))
               (global $read-accept-dot-value          (mut (ref eq)) (global.get $true))
               (global $read-accept-infix-dot-value    (mut (ref eq)) (global.get $true))
               (global $read-accept-quasiquote-value   (mut (ref eq)) (global.get $true))
               (global $read-cdot-value                (mut (ref eq)) (global.get $false))
               (global $read-single-flonum-value       (mut (ref eq)) (global.get $false))
               (global $read-decimal-as-inexact-value  (mut (ref eq)) (global.get $true))
               (global $read-case-sensitive-value      (mut (ref eq)) (global.get $true))
               (global $current-readtable-value        (mut (ref eq)) (global.get $false))
               (global $print-pair-curly-braces-value       (mut (ref eq)) (global.get $false))
               (global $print-mpair-curly-braces-value      (mut (ref eq)) (global.get $true))
               (global $print-unreadable-value              (mut (ref eq)) (global.get $true))
               (global $print-graph-value                   (mut (ref eq)) (global.get $false))
               (global $print-struct-value                  (mut (ref eq)) (global.get $true))
               (global $print-box-value                     (mut (ref eq)) (global.get $true))
               (global $print-vector-length-value           (mut (ref eq)) (global.get $false))
               (global $print-hash-table-value              (mut (ref eq)) (global.get $true))
               (global $print-boolean-long-form-value       (mut (ref eq)) (global.get $false))
               (global $print-reader-abbreviations-value    (mut (ref eq)) (global.get $false))
               (global $print-as-expression-value           (mut (ref eq)) (global.get $true))
               (global $print-syntax-width-value       (mut (ref eq)) (ref.i31 (i32.const 512)))
               (global $error-print-width-value        (mut (ref eq)) (ref.i31 (i32.const 512)))
               (global $error-print-source-location-value (mut (ref eq)) (global.get $true))))

;; reader-printer-policy-parameter-global-names : (listof symbol?)
;;   Enumerate reader/printer policy parameter globals shared by split modules.
(define reader-printer-policy-parameter-global-names
  (map parameter-global-form-name reader-printer-policy-parameter-global-forms))

;; reader-printer-policy-parameter-primitive-global-forms : (listof datum?)
;;   Declare primitive procedure globals used by reader/printer policy parameters.
(define reader-printer-policy-parameter-primitive-global-forms
  (for/list ([spec (in-list reader-printer-policy-parameter-specs)])
    (match-define (list _name _symbol _global primitive) spec)
    `(global ,primitive (mut (ref eq)) (global.get $undefined))))

;; reader-printer-policy-parameter-primitive-global-names : (listof symbol?)
;;   Enumerate reader/printer policy primitive procedure globals shared by split modules.
(define reader-printer-policy-parameter-primitive-global-names
  (map parameter-global-form-name
       reader-printer-policy-parameter-primitive-global-forms))

;; reader-printer-policy-parameter-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generated policy parameters.
(define reader-printer-policy-parameter-helper-names
  (map first reader-printer-policy-parameter-specs))

;; compile-parameter-global-forms : (listof datum?)
;;   Declare globals backing compile metadata parameters.
(define compile-parameter-global-forms
  '(
               (global $current-compile-target-machine-value (mut (ref eq)) (global.get $false))
               (global $current-compile-realm-value (mut (ref eq)) (global.get $false))))

;; compile-parameter-global-names : (listof symbol?)
;;   Enumerate compile metadata parameter globals shared by split modules.
(define compile-parameter-global-names
  (map parameter-global-form-name compile-parameter-global-forms))

;; promoted-parameter-primitive-global-forms : (listof datum?)
;;   Declare primitive procedure globals needed by promoted parameter helpers.
(define promoted-parameter-primitive-global-forms
  '(
               (global $prim:js-log                       (mut (ref eq)) (global.get $undefined))
               (global $prim:current-input-port           (mut (ref eq)) (global.get $undefined))
               (global $prim:current-output-port          (mut (ref eq)) (global.get $undefined))
               (global $prim:current-error-port           (mut (ref eq)) (global.get $undefined))
               (global $prim:current-print                (mut (ref eq)) (global.get $undefined))
               (global $prim:current-read-interaction     (mut (ref eq)) (global.get $undefined))
               (global $prim:error-value->string-handler  (mut (ref eq)) (global.get $undefined))
               (global $prim:error-syntax->string-handler (mut (ref eq)) (global.get $undefined))
               (global $prim:error-module-path->string-handler (mut (ref eq)) (global.get $undefined))
               (global $prim:current-compile-target-machine (mut (ref eq)) (global.get $undefined))
               (global $prim:current-compile-realm          (mut (ref eq)) (global.get $undefined))
               (global $prim:current-logger                 (mut (ref eq)) (global.get $undefined))
               (global $prim:current-thread-group           (mut (ref eq)) (global.get $undefined))
               (global $prim:current-security-guard         (mut (ref eq)) (global.get $undefined))
               (global $prim:current-custodian              (mut (ref eq)) (global.get $undefined))
               (global $prim:current-readtable              (mut (ref eq)) (global.get $undefined))
               (global $prim:current-namespace              (mut (ref eq)) (global.get $undefined))
               (global $prim:print-syntax-width             (mut (ref eq)) (global.get $undefined))
               (global $prim:error-print-width              (mut (ref eq)) (global.get $undefined))))

;; promoted-parameter-primitive-global-names : (listof symbol?)
;;   Enumerate primitive procedure globals needed by promoted parameter helpers.
(define promoted-parameter-primitive-global-names
  (map parameter-global-form-name promoted-parameter-primitive-global-forms))

;; parameterization-global-forms : (listof datum?)
;;   Declare the current parameterization backing global and #%paramz support state.
(define parameterization-global-forms
  '(
               (global $current-parameterization-value (mut (ref eq)) (global.get $false))
               (global $break-enabled-key             (mut (ref eq)) (global.get $void))
               (global $exception-handler-key         (mut (ref eq)) (global.get $void))
               (global $parameterization-key          (mut (ref eq)) (global.get $void))
               (global $cache-configuration-values    (mut (ref eq)) (global.get $void))))

;; parameterization-global-names : (listof symbol?)
;;   Enumerate parameterization state globals shared by split core/program modules.
(define parameterization-global-names
  '($current-parameterization-value
    $break-enabled-key
    $exception-handler-key
    $parameterization-key
    $cache-configuration-values))

;; parameterization-initializer-forms : (listof datum?)
;;   Initialize #%paramz keys and the current parameterization backing value.
(define parameterization-initializer-forms
  '(
                     (global.set $break-enabled-key
                                 (global.get $symbol:break-enabled-key))
                     (global.set $exception-handler-key
                                 (global.get $symbol:exception-handler-key))
                     (global.set $parameterization-key
                                 (global.get $symbol:parameterization-key))
                     (global.set $current-parameterization-value
                                 (struct.new $Parameterization
                                             (i32.const 0)
                                             (global.get $false)
                                             (global.get $null)))))

;; compile-parameter-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for compile metadata parameters.
(define compile-parameter-helper-names
  '($current-compile-target-machine/get
    $current-compile-target-machine/set
    $current-compile-target-machine
    $current-compile-realm/get
    $current-compile-realm/set
    $current-compile-realm))

;; compile-parameter-core-runtime-helper-names : (listof symbol?)
;;   Name compile metadata parameter helpers available in core runtime.
(define compile-parameter-core-runtime-helper-names
  compile-parameter-helper-names)

;; compile-parameter-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only compile metadata parameter emission order.
(define compile-parameter-runtime-only-helper-names
  (remove* compile-parameter-core-runtime-helper-names
           compile-parameter-helper-names
           eq?))

;; parameterization-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for parameterization predicates and accessors.
(define parameterization-runtime-only-helper-names
  '($current-parameterization
    $parameterization?
    $parameter?
    $reparameterize))

;; namespace-parameter-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-namespace parameter helpers.
(define namespace-parameter-helper-names
  '($current-namespace/get
    $current-namespace/set
    $current-namespace))

;; namespace-parameter-core-runtime-helper-names : (listof symbol?)
;;   Name current-namespace parameter helpers available in core runtime.
(define namespace-parameter-core-runtime-helper-names
  namespace-parameter-helper-names)

;; namespace-parameter-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only current-namespace parameter emission order.
(define namespace-parameter-runtime-only-helper-names
  (remove* namespace-parameter-core-runtime-helper-names
           namespace-parameter-helper-names
           eq?))

;; parameterization-binding-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for parameterization binding helpers.
(define parameterization-binding-helper-names
  '($build-parameterization-bindings
    $extend-parameterization
    $parameterization-ref
    $parameter-value-or-global
    $parameterization-set!
    $extend-current-parameterization!))

;; parameterization-binding-promoted-runtime-helper-names : (listof symbol?)
;;   Name standalone parameterization binding helpers promoted to core runtime.
(define parameterization-binding-promoted-runtime-helper-names
  '($parameterization-ref
    $parameter-value-or-global
    $parameterization-set!
    $extend-current-parameterization!))

;; parameterization-binding-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for parameterization binding helpers.
(define parameterization-binding-runtime-only-helper-names
  (remove* parameterization-binding-promoted-runtime-helper-names
           parameterization-binding-helper-names
           eq?))

;; parameterization-call-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for parameterization call/configuration helpers.
(define parameterization-call-runtime-only-helper-names
  '($call-with-parameterization
    $cache-configuration))

;; parameter-width-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for printer width parameters.
(define parameter-width-helper-names
  '($print-syntax-width
    $error-print-width))

;; parameter-width-core-runtime-helper-names : (listof symbol?)
;;   Name printer width parameters available in core runtime.
(define parameter-width-core-runtime-helper-names
  parameter-width-helper-names)

;; parameter-width-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only printer width parameter emission order.
(define parameter-width-runtime-only-helper-names
  (remove* parameter-width-core-runtime-helper-names
           parameter-width-helper-names
           eq?))

;; parameter-error-rendering-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for error rendering parameters.
(define parameter-error-rendering-runtime-only-helper-names
  '($error-syntax->name-handler
    $error-value->string-handler
    $error-syntax->string-handler
    $error-module-path->string-handler))

;; parameter-directory-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current directory parameters.
(define parameter-directory-runtime-only-helper-names
  '($current-directory
    $current-directory-for-user))

;; current-security-guard-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-security-guard.
(define current-security-guard-helper-names
  '($current-security-guard))

;; current-security-guard-core-runtime-helper-names : (listof symbol?)
;;   Name current-security-guard helpers available in core runtime.
(define current-security-guard-core-runtime-helper-names
  current-security-guard-helper-names)

;; current-security-guard-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only current-security-guard emission order.
(define current-security-guard-runtime-only-helper-names
  (remove* current-security-guard-core-runtime-helper-names
           current-security-guard-helper-names
           eq?))

;; current-custodian-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-custodian.
(define current-custodian-helper-names
  '($current-custodian))

;; current-custodian-core-runtime-helper-names : (listof symbol?)
;;   Name current-custodian helpers available in core runtime.
(define current-custodian-core-runtime-helper-names
  current-custodian-helper-names)

;; current-custodian-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only current-custodian emission order.
(define current-custodian-runtime-only-helper-names
  (remove* current-custodian-core-runtime-helper-names
           current-custodian-helper-names
           eq?))

;; current-pseudo-random-generator-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-pseudo-random-generator.
(define current-pseudo-random-generator-helper-names
  '($current-pseudo-random-generator))

;; current-pseudo-random-generator-core-runtime-helper-names : (listof symbol?)
;;   Name current-pseudo-random-generator helpers available in core runtime.
(define current-pseudo-random-generator-core-runtime-helper-names
  current-pseudo-random-generator-helper-names)

;; current-pseudo-random-generator-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only current-pseudo-random-generator emission order.
(define current-pseudo-random-generator-runtime-only-helper-names
  (remove* current-pseudo-random-generator-core-runtime-helper-names
           current-pseudo-random-generator-helper-names
           eq?))

;; current-environment-variables-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-environment-variables.
(define current-environment-variables-runtime-only-helper-names
  '($current-environment-variables))

;; current-print-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-print.
(define current-print-helper-names
  '($current-print))

;; current-print-core-runtime-helper-names : (listof symbol?)
;;   Name current-print helpers available in core runtime.
(define current-print-core-runtime-helper-names
  current-print-helper-names)

;; current-print-runtime-only-helper-names : (listof symbol?)
;;   Preserve the monolithic runtime emission order for current-print.
(define current-print-runtime-only-helper-names
  current-print-helper-names)

;; current-readtable-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-readtable.
(define current-readtable-helper-names
  '($current-readtable))

;; current-readtable-core-runtime-helper-names : (listof symbol?)
;;   Name current-readtable helpers available in core runtime.
(define current-readtable-core-runtime-helper-names
  current-readtable-helper-names)

;; current-readtable-runtime-only-helper-names : (listof symbol?)
;;   Preserve runtime-only current-readtable emission order.
(define current-readtable-runtime-only-helper-names
  (remove* current-readtable-core-runtime-helper-names
           current-readtable-helper-names
           eq?))

;; current-read-interaction-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-read-interaction.
(define current-read-interaction-runtime-only-helper-names
  '($current-read-interaction))

;; current-load-relative-directory-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for current-load-relative-directory.
(define current-load-relative-directory-runtime-only-helper-names
  '($current-load-relative-directory))

;; parameter-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given parameter helper names from a helper index.
(define (parameter-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; compile-parameter-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render compile metadata parameter helpers in runtime assembly order.
(define (compile-parameter-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index compile-parameter-runtime-only-helper-names))

;; compile-parameter-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render compile metadata parameter helpers shared with core runtime.
(define (compile-parameter-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index compile-parameter-core-runtime-helper-names))

;; current-security-guard-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-security-guard in runtime assembly order.
(define (current-security-guard-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-security-guard-runtime-only-helper-names))

;; current-security-guard-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-security-guard helpers shared with core runtime.
(define (current-security-guard-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-security-guard-core-runtime-helper-names))

;; current-custodian-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-custodian in runtime assembly order.
(define (current-custodian-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-custodian-runtime-only-helper-names))

;; current-custodian-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-custodian helpers shared with core runtime.
(define (current-custodian-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-custodian-core-runtime-helper-names))

;; current-pseudo-random-generator-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-pseudo-random-generator in runtime assembly order.
(define (current-pseudo-random-generator-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-pseudo-random-generator-runtime-only-helper-names))

;; current-pseudo-random-generator-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-pseudo-random-generator helpers shared with core runtime.
(define (current-pseudo-random-generator-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-pseudo-random-generator-core-runtime-helper-names))

;; current-environment-variables-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-environment-variables in runtime assembly order.
(define (current-environment-variables-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-environment-variables-runtime-only-helper-names))

;; current-print-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-print in runtime assembly order.
(define (current-print-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-print-runtime-only-helper-names))

;; current-readtable-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-readtable in runtime assembly order.
(define (current-readtable-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-readtable-runtime-only-helper-names))

;; current-readtable-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-readtable helpers shared with core runtime.
(define (current-readtable-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-readtable-core-runtime-helper-names))

;; current-read-interaction-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-read-interaction in runtime assembly order.
(define (current-read-interaction-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-read-interaction-runtime-only-helper-names))

;; current-load-relative-directory-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-load-relative-directory in runtime assembly order.
(define (current-load-relative-directory-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index current-load-relative-directory-runtime-only-helper-names))

;; parameterization-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render parameterization predicate and accessor helpers in runtime assembly order.
(define (parameterization-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index parameterization-runtime-only-helper-names))

;; namespace-parameter-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-namespace parameter helpers in runtime assembly order.
(define (namespace-parameter-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index namespace-parameter-runtime-only-helper-names))

;; namespace-parameter-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current-namespace parameter helpers shared with core runtime.
(define (namespace-parameter-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index namespace-parameter-core-runtime-helper-names))

;; parameterization-binding-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render parameterization binding helpers in runtime assembly order.
(define (parameterization-binding-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index parameterization-binding-runtime-only-helper-names))

;; parameterization-binding-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted parameterization binding helpers in runtime assembly order.
(define (parameterization-binding-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index
                          parameterization-binding-promoted-runtime-helper-names))

;; parameterization-call-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render parameterization call and configuration helpers in runtime assembly order.
(define (parameterization-call-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index parameterization-call-runtime-only-helper-names))

;; parameter-width-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render printer width parameter helpers in runtime assembly order.
(define (parameter-width-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index parameter-width-runtime-only-helper-names))

;; parameter-width-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render printer width parameter helpers shared with core runtime.
(define (parameter-width-core-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index parameter-width-core-runtime-helper-names))

;; parameter-error-rendering-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render error rendering parameter helpers in runtime assembly order.
(define (parameter-error-rendering-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index parameter-error-rendering-runtime-only-helper-names))

;; parameter-directory-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render current directory parameter helpers in runtime assembly order.
(define (parameter-directory-runtime-helper-forms helper-index)
  (parameter-helper-forms helper-index parameter-directory-runtime-only-helper-names))

;; reader-printer-policy-parameter-helper-forms : hasheq? -> (listof datum?)
;;   Render generated reader and printer policy parameter helpers in runtime assembly order.
(define (reader-printer-policy-parameter-helper-forms helper-index)
  (parameter-helper-forms helper-index reader-printer-policy-parameter-helper-names))

;; reader-printer-policy-parameter-form : symbol? symbol? symbol? symbol? -> datum?
;;   Generate one boolean reader/printing policy parameter function.
(define (reader-printer-policy-parameter-form name symbol global primitive)
  `(func ,name (type $Prim01)
         (param $v (ref eq)) ;; optional boolean?
         (result   (ref eq))

         (if (ref.eq (local.get $v) (global.get $missing))
             (then (return (call $parameter-value-or-global
                                 (global.get ,primitive)
                                 (global.get ,global)))))
         (if (ref.eq (call $boolean? (local.get $v)) (global.get $false))
             (then (call $raise-argument-error1
                         (global.get ,symbol)
                         (global.get $string:boolean?)
                         (local.get $v))
                   (unreachable)))
         (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                              (global.get $false)))
             (then (return (call $extend-current-parameterization!
                                 (global.get ,primitive)
                                 (local.get $v)))))
         (global.set ,global (local.get $v))
         (global.get $void)))

;; reader-printer-policy-parameter-forms : (listof datum?)
;;   Generate the reader/printing policy parameter function forms.
(define reader-printer-policy-parameter-forms
  (for/list ([spec (in-list reader-printer-policy-parameter-specs)])
    (apply reader-printer-policy-parameter-form spec)))

;; parameter-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate parameterization helpers shared by core and monolithic runtime.
(define parameter-runtime-helpers
  (append
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
           (if (ref.eq (call $procedure? (local.get $thunk-raw))
                         (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:call-with-parameterization)
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

     ;; cache-configuration : (integer-in 0 7) (-> any/c) -> any/c
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

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $index-raw))
                       (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:cache-configuration)
                           (global.get $string:cache-configuration-index)
                           (local.get $index-raw))
                     (unreachable)))
           (local.set $index (call $fixnum->i32 (local.get $index-raw)))
           (if (i32.ge_u (local.get $index) (i32.const 8))
               (then (call $raise-argument-error1
                           (global.get $symbol:cache-configuration)
                           (global.get $string:cache-configuration-index)
                           (local.get $index-raw))
                     (unreachable)))
           (if (ref.eq (call $procedure? (local.get $thunk-raw))
                         (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:cache-configuration)
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
           (local $printer (ref $Procedure))
           (if (ref.eq (local.get $printer-raw) (global.get $missing))
               (then
                (if (ref.eq (global.get $current-print-value) (global.get $false))
                    (then (return (global.get $prim:js-log)))
                    (else (return (global.get $current-print-value))))))
           (if (ref.eq (call $procedure? (local.get $printer-raw))
                         (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-print)
                           (global.get $string:current-print:procedure-arity-1)
                           (local.get $printer-raw))
                     (unreachable)))
           (local.set $printer (ref.cast (ref $Procedure) (local.get $printer-raw)))
           (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                              (local.get $printer)
                              (i32.const 1)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-print)
                           (global.get $string:current-print:procedure-arity-1)
                           (local.get $printer-raw))
                     (unreachable)))
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
           (if (ref.eq (call $procedure? (local.get $reader-raw))
                         (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-read-interaction)
                           (global.get $string:procedure?)
                           (local.get $reader-raw))
                     (unreachable)))
           (global.set $current-read-interaction-value (local.get $reader-raw))
           (global.get $void))

     ;; current-pseudo-random-generator : [pseudo-random-generator?] -> any/c
     ;;   Poor-man parameter for the current generator.
     (func $current-pseudo-random-generator (type $Prim01)
           (param $gen (ref eq)) ;; optional pseudo-random-generator?
           (result     (ref eq))
           (if (ref.eq (local.get $gen) (global.get $missing))
               (then (return (global.get $current-pseudo-random-generator-value))))
           (if (i32.eqz (ref.test (ref $PseudoRandomGenerator) (local.get $gen)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-pseudo-random-generator)
                           (global.get $string:pseudo-random-generator?)
                           (local.get $gen))
                     (unreachable)))
           (global.set $current-pseudo-random-generator-value (local.get $gen))
           (global.get $void))

     ;; current-environment-variables : [environment-variables?] -> environment-variables?
     ;;   Get or set the current environment-variable set. WebRacket
     ;;   starts with an empty set instead of host OS variables.
     (func $current-environment-variables (type $Prim01)
           (param $env-raw (ref eq)) ;; optional environment-variables?, default current set
           (result (ref eq))
           (if (ref.eq (local.get $env-raw) (global.get $missing))
               (then (return (global.get $current-environment-variables-value))))
           (if (i32.eqz (ref.test (ref $EnvironmentVariables) (local.get $env-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-environment-variables)
                           (global.get $string:current-environment-variables:environment-variables?)
                           (local.get $env-raw))
                     (unreachable)))
           (global.set $current-environment-variables-value (local.get $env-raw))
           (global.get $void))

     ;; current-directory : [path-string?] -> path? or void?
     ;;   Get or set WebRacket's current absolute path.
     (func $current-directory (type $Prim01)
           (param $path-raw (ref eq)) ;; optional path-string?
           (result          (ref eq))

           (local $path (ref $Path))

           (if (ref.eq (local.get $path-raw) (global.get $missing))
               (then (return (global.get $current-directory-path))))
           (local.set $path
                      (call $path-string->path/checked
                            (global.get $symbol:current-directory)
                            (local.get $path-raw)))
           (if (i32.eqz (call $path-bytes-absolute?
                              (struct.get $Path $bytes (local.get $path))))
               (then (local.set $path
                                (ref.cast (ref $Path)
                                          (call $path->complete-path
                                                (local.get $path)
                                                (global.get $missing))))))
           (global.set $current-directory-path (local.get $path))
           (global.get $void))

     ;; current-directory-for-user : [path-string?] -> path? or void?
     ;;   Get or set the user-facing current absolute path.
     (func $current-directory-for-user (type $Prim01)
           (param $path-raw (ref eq)) ;; optional path-string?
           (result          (ref eq))

           (local $path (ref $Path))

           (if (ref.eq (local.get $path-raw) (global.get $missing))
               (then (return (global.get $current-directory-for-user-path))))
           (local.set $path
                      (call $path-string->path/checked
                            (global.get $symbol:current-directory-for-user)
                            (local.get $path-raw)))
           (if (i32.eqz (call $path-bytes-absolute?
                              (struct.get $Path $bytes (local.get $path))))
               (then (local.set $path
                                (ref.cast (ref $Path)
                                          (call $path->complete-path
                                                (local.get $path)
                                                (global.get $missing))))))
           (global.set $current-directory-for-user-path (local.get $path))
           (global.get $void))

     ;; current-load-relative-directory : [(or/c path-string? #f)] -> (or/c path? #f) or void?
     ;;   Reference: this parameter defaults to #f; when set to a path
     ;;   or string, it is immediately converted to a complete path.
     (func $current-load-relative-directory (type $Prim01)
           (param $path-raw (ref eq)) ;; optional path-string?/#f, default = current value
           (result          (ref eq))

           (local $path (ref $Path))

           (if (ref.eq (local.get $path-raw) (global.get $missing))
               (then (return (global.get $current-load-relative-directory-path))))
           (if (ref.eq (local.get $path-raw) (global.get $false))
               (then
                (global.set $current-load-relative-directory-path
                            (global.get $false))
                (return (global.get $void))))
           (local.set $path
                      (call $path-string->path/checked
                            (global.get $symbol:current-load-relative-directory)
                            (local.get $path-raw)))
           (if (i32.eqz (call $path-bytes-absolute?
                              (struct.get $Path $bytes (local.get $path))))
               (then (local.set $path
                                (ref.cast (ref $Path)
                                          (call $path->complete-path
                                                (local.get $path)
                                                (global.get $missing))))))
           (global.set $current-load-relative-directory-path
                       (local.get $path))
           (global.get $void))

     ;; print-syntax-width : [(or/c +inf.0 0 exact-integer>=3)] -> any/c
     ;;   Bootstrap parameter for syntax-object printing. It accepts
     ;;   exact fixnums 0 or >= 3, which covers the default and the
     ;;   expander startup path; +inf.0 can be added with broader
     ;;   numeric printer-parameter support.
     (func $print-syntax-width (type $Prim01)
           (param $v (ref eq)) ;; optional width, default = current value
           (result   (ref eq))

           (local $raw i32)
           (local $n   i32)

           (if (ref.eq (local.get $v) (global.get $missing))
               (then (return (call $parameter-value-or-global
                                   (global.get $prim:print-syntax-width)
                                   (global.get $print-syntax-width-value)))))
           (if (i32.eqz (ref.test (ref i31) (local.get $v)))
               (then (call $raise-argument-error1
                           (global.get $symbol:print-syntax-width)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $v))
                     (unreachable)))
           (local.set $raw (i31.get_u (ref.cast (ref i31) (local.get $v))))
           (if (i32.ne (i32.and (local.get $raw) (i32.const 1)) (i32.const 0))
               (then (call $raise-argument-error1
                           (global.get $symbol:print-syntax-width)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $v))
                     (unreachable)))
           (local.set $n (i32.shr_u (local.get $raw) (i32.const 1)))
           (if (i32.and
                (i32.ne (local.get $n) (i32.const 0))
                (i32.lt_u (local.get $n) (i32.const 3)))
               (then (call $raise-argument-error1
                           (global.get $symbol:print-syntax-width)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $v))
                     (unreachable)))
           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:print-syntax-width)
                                   (local.get $v)))))
           (global.set $print-syntax-width-value (local.get $v))
           (global.get $void))

     ;; error-print-width : [exact-integer>=3] -> any/c
     ;;   Bootstrap parameter used by error and syntax printers.
     (func $error-print-width (type $Prim01)
           (param $v (ref eq)) ;; optional width, default = current value
           (result   (ref eq))

           (local $raw i32)
           (local $n   i32)

           (if (ref.eq (local.get $v) (global.get $missing))
               (then (return (call $parameter-value-or-global
                                   (global.get $prim:error-print-width)
                                   (global.get $error-print-width-value)))))
           (if (i32.eqz (ref.test (ref i31) (local.get $v)))
               (then (call $raise-argument-error1
                           (global.get $symbol:error-print-width)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $v))
                     (unreachable)))
           (local.set $raw (i31.get_u (ref.cast (ref i31) (local.get $v))))
           (if (i32.ne (i32.and (local.get $raw) (i32.const 1)) (i32.const 0))
               (then (call $raise-argument-error1
                           (global.get $symbol:error-print-width)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $v))
                     (unreachable)))
           (local.set $n (i32.shr_u (local.get $raw) (i32.const 1)))
           (if (i32.lt_u (local.get $n) (i32.const 3))
               (then (call $raise-argument-error1
                           (global.get $symbol:error-print-width)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $v))
                     (unreachable)))
           (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                (global.get $false)))
               (then (return (call $extend-current-parameterization!
                                   (global.get $prim:error-print-width)
                                   (local.get $v)))))
           (global.set $error-print-width-value (local.get $v))
           (global.get $void))

     ;; error-syntax->name-handler : [procedure?] -> procedure? or void?
     ;;   Parameter used by raise-syntax-error to infer form names.
     ;;   The default handler returns #f; richer syntax extraction is
     ;;   deferred until the expander is running further.
     (func $error-syntax->name-handler (type $Prim01)
           (param $handler-raw (ref eq)) ;; optional procedure?, default current handler
           (result (ref eq))
           (if (ref.eq (local.get $handler-raw) (global.get $missing))
               (then (return (global.get $error-syntax->name-handler-value))))
           (if (ref.eq (call $procedure? (local.get $handler-raw))
                         (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:error-syntax->name-handler)
                           (global.get $string:procedure?)
                           (local.get $handler-raw))
                     (unreachable)))
           (global.set $error-syntax->name-handler-value (local.get $handler-raw))
           (global.get $void))

     ;; error-value->string-handler : [procedure?] -> procedure? or void?
     ;;   Parameter used to render arbitrary values in error messages.
     (func $error-value->string-handler (type $Prim01)
           (param $handler-raw (ref eq)) ;; optional procedure?, default current handler
           (result (ref eq))
           (if (ref.eq (local.get $handler-raw) (global.get $missing))
               (then (return (global.get $error-value->string-handler-value))))
           (if (ref.eq (call $procedure? (local.get $handler-raw))
                         (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:error-value->string-handler)
                           (global.get $string:procedure?)
                           (local.get $handler-raw))
                     (unreachable)))
           (global.set $error-value->string-handler-value (local.get $handler-raw))
           (global.get $void))

     ;; error-syntax->string-handler : [procedure?] -> procedure? or void?
     ;;   Parameter used to render syntax values in error messages.
     (func $error-syntax->string-handler (type $Prim01)
           (param $handler-raw (ref eq)) ;; optional procedure?, default current handler
           (result (ref eq))
           (if (ref.eq (local.get $handler-raw) (global.get $missing))
               (then (return (global.get $error-syntax->string-handler-value))))
           (if (ref.eq (call $procedure? (local.get $handler-raw))
                         (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:error-syntax->string-handler)
                           (global.get $string:procedure?)
                           (local.get $handler-raw))
                     (unreachable)))
           (global.set $error-syntax->string-handler-value (local.get $handler-raw))
           (global.get $void))

     ;; error-module-path->string-handler : [procedure?] -> procedure? or void?
     ;;   Parameter used to render module paths in error messages.
     (func $error-module-path->string-handler (type $Prim01)
           (param $handler-raw (ref eq)) ;; optional procedure?, default current handler
           (result (ref eq))
           (if (ref.eq (local.get $handler-raw) (global.get $missing))
               (then (return (global.get $error-module-path->string-handler-value))))
           (if (ref.eq (call $procedure? (local.get $handler-raw))
                         (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:error-module-path->string-handler)
                           (global.get $string:procedure?)
                           (local.get $handler-raw))
                     (unreachable)))
           (global.set $error-module-path->string-handler-value (local.get $handler-raw))
           (global.get $void))))
   (function-forms->runtime-helpers
    'reader-printer-policy-parameter-forms
    reader-printer-policy-parameter-forms)))

;; parameter-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate parameterization helpers available in the standalone core runtime.
(define parameter-core-runtime-helpers
  (select-runtime-helpers parameter-runtime-helpers
                          (append parameterization-binding-promoted-runtime-helper-names
                                  current-pseudo-random-generator-core-runtime-helper-names
                                  compile-parameter-core-runtime-helper-names
                                  current-security-guard-core-runtime-helper-names
                                  current-custodian-core-runtime-helper-names
                                  current-print-core-runtime-helper-names
                                  current-readtable-core-runtime-helper-names
                                  namespace-parameter-core-runtime-helper-names
                                  parameter-width-core-runtime-helper-names)))

;; parameter-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate parameterization helpers used only by the monolithic runtime.
(define parameter-runtime-only-helpers
  (remove-runtime-helpers parameter-runtime-helpers
                          (append parameterization-binding-promoted-runtime-helper-names
                                  current-pseudo-random-generator-core-runtime-helper-names
                                  compile-parameter-core-runtime-helper-names
                                  current-security-guard-core-runtime-helper-names
                                  current-custodian-core-runtime-helper-names
                                  current-print-core-runtime-helper-names
                                  current-readtable-core-runtime-helper-names
                                  namespace-parameter-core-runtime-helper-names
                                  parameter-width-core-runtime-helper-names)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define parameter-helper-index
    (make-core-runtime-helper-index
     (append parameter-core-runtime-helpers
             parameter-runtime-only-helpers)))

  (check-equal?
   (map form-name (compile-parameter-runtime-helper-forms parameter-helper-index))
   compile-parameter-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-security-guard-runtime-helper-forms parameter-helper-index))
   current-security-guard-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-custodian-runtime-helper-forms parameter-helper-index))
   current-custodian-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-pseudo-random-generator-runtime-helper-forms parameter-helper-index))
   current-pseudo-random-generator-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-environment-variables-runtime-helper-forms parameter-helper-index))
   current-environment-variables-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-print-runtime-helper-forms parameter-helper-index))
   current-print-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-readtable-runtime-helper-forms parameter-helper-index))
   current-readtable-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-read-interaction-runtime-helper-forms parameter-helper-index))
   current-read-interaction-runtime-only-helper-names)

  (check-equal?
   (map form-name (current-load-relative-directory-runtime-helper-forms parameter-helper-index))
   current-load-relative-directory-runtime-only-helper-names)

  (check-equal?
   (map form-name (parameterization-runtime-helper-forms parameter-helper-index))
   parameterization-runtime-only-helper-names)

  (check-equal?
   (map form-name (namespace-parameter-runtime-helper-forms parameter-helper-index))
   namespace-parameter-runtime-only-helper-names)

  (check-equal?
   (map form-name (parameterization-binding-runtime-helper-forms parameter-helper-index))
   parameterization-binding-runtime-only-helper-names)

  (define parameter-core-helper-index
    (make-core-runtime-helper-index parameter-core-runtime-helpers))

  (check-equal?
   (map form-name (compile-parameter-core-runtime-helper-forms
                   parameter-core-helper-index))
   compile-parameter-core-runtime-helper-names)

  (check-equal?
   (map form-name (current-security-guard-core-runtime-helper-forms
                   parameter-core-helper-index))
   current-security-guard-core-runtime-helper-names)

  (check-equal?
   (map form-name (current-custodian-core-runtime-helper-forms
                   parameter-core-helper-index))
   current-custodian-core-runtime-helper-names)

  (check-equal?
   (map form-name (current-pseudo-random-generator-core-runtime-helper-forms
                   parameter-core-helper-index))
   current-pseudo-random-generator-core-runtime-helper-names)

  (check-equal?
   (map form-name (current-readtable-core-runtime-helper-forms
                   parameter-core-helper-index))
   current-readtable-core-runtime-helper-names)

  (check-equal?
   (map form-name (namespace-parameter-core-runtime-helper-forms
                   parameter-core-helper-index))
   namespace-parameter-core-runtime-helper-names)

  (check-equal?
   (map form-name (parameter-width-core-runtime-helper-forms
                   parameter-core-helper-index))
   parameter-width-core-runtime-helper-names)

  (check-equal?
   (map form-name (parameterization-binding-core-runtime-helper-forms
                   parameter-core-helper-index))
   parameterization-binding-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (parameterization-call-runtime-helper-forms parameter-helper-index))
   parameterization-call-runtime-only-helper-names)

  (check-equal?
   (map form-name (reader-printer-policy-parameter-helper-forms parameter-helper-index))
   reader-printer-policy-parameter-helper-names)

  (check-equal?
   (map form-name (parameter-width-runtime-helper-forms parameter-helper-index))
   parameter-width-runtime-only-helper-names)

  (check-equal?
   (map form-name (parameter-error-rendering-runtime-helper-forms parameter-helper-index))
   parameter-error-rendering-runtime-only-helper-names)

  (check-equal?
   (map form-name (parameter-directory-runtime-helper-forms parameter-helper-index))
   parameter-directory-runtime-only-helper-names)

  (check-equal?
   environment-parameter-global-names
   '($current-environment-variables-value))

  (check-equal?
   print-read-parameter-global-names
   '($current-print-value
     $current-read-interaction-value))

  (check-equal?
   error-rendering-handler-global-names
   '($error-value->string-handler-value
     $error-syntax->string-handler-value
     $error-syntax->name-handler-value
     $error-module-path->string-handler-value))

  (check-equal?
   compile-parameter-global-names
   '($current-compile-target-machine-value
     $current-compile-realm-value))

  (for ([name (in-list '($prim:current-input-port
                         $prim:current-output-port
                         $prim:current-error-port
                         $prim:js-log
                         $prim:current-print
                         $prim:current-read-interaction
                         $prim:error-value->string-handler
                         $prim:error-syntax->string-handler
                         $prim:error-module-path->string-handler))])
    (check-not-false
     (member name promoted-parameter-primitive-global-names)))

  (check-not-false
   (member '$print-as-expression-value
           reader-printer-policy-parameter-global-names))
  (check-not-false
   (member '$print-mpair-curly-braces-value
           reader-printer-policy-parameter-global-names))
  (check-not-false
   (member '$current-readtable-value
           reader-printer-policy-parameter-global-names))
  (check-not-false
   (member '$prim:print-as-expression
           reader-printer-policy-parameter-primitive-global-names))
  (check-not-false
   (member '$prim:print-mpair-curly-braces
           reader-printer-policy-parameter-primitive-global-names))
  (check-equal?
   (length reader-printer-policy-parameter-primitive-global-names)
   (length reader-printer-policy-parameter-specs))

  (check-equal?
   parameterization-global-names
   '($current-parameterization-value
     $break-enabled-key
     $exception-handler-key
     $parameterization-key
     $cache-configuration-values)))
