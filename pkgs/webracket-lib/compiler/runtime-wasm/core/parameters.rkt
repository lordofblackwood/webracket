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
           (local.get $p)))))
