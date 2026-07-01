#lang racket

(provide impersonator-runtime-only-helpers)

(require "../core-helper.rkt")

;; impersonator-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate inert impersonator and chaperone support helpers.
(define impersonator-runtime-only-helpers
  (function-forms->runtime-helpers
   'impersonator-runtime-only-helpers
   '(
     (func $impersonator? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq)) ;; always #f; WebRacket has no impersonators
           (global.get $false))

     ;; procedure-impersonator*? : any/c -> boolean?
     ;;   Recognize procedure impersonators, including those created through
     ;;   prop:impersonator-of. WebRacket has no impersonators yet, so the
     ;;   conservative result is always #f.
     (func $procedure-impersonator*? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq))
           (global.get $false))

     (func $chaperone? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq)) ;; always #f; WebRacket has no chaperones
           (global.get $false))

     (func $impersonator-val (type $Prim1)
           (param $v (ref eq)) ;; unsupported impersonator value
           (result   (ref eq))
           (unreachable))

     ;; make-impersonator-property : symbol? -> values impersonator-property? procedure? procedure?
     ;;   Allocate a property descriptor and return inert predicate/accessor
     ;;   procedures. WebRacket has no impersonators yet, so the predicate
     ;;   always returns #f and the accessor only supports the documented
     ;;   fallback path.
     (func $make-impersonator-property (type $Prim1)
           (param $name (ref eq)) ;; symbol?
           (result      (ref eq)) ;; three values

           (if (ref.eq (call $symbol? (local.get $name)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:make-impersonator-property)
                           (global.get $string:symbol?)
                           (local.get $name))
                     (unreachable)))
           (array.new_fixed $Values 3
                            (struct.new $ImpersonatorProperty
                                        (i32.const 0)
                                        (local.get $name))
                            (global.get $prim:webracket-impersonator-property-predicate)
                            (global.get $prim:webracket-impersonator-property-accessor)))

     ;; impersonator-property? : any/c -> boolean?
     ;;   Recognize WebRacket's inert impersonator-property descriptors.
     (func $impersonator-property? (type $Prim1)
           (param $v (ref eq)) ;; candidate value
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $ImpersonatorProperty) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     ;; impersonator-property-accessor-procedure? : any/c -> boolean?
     ;;   The only accessor procedure WebRacket can currently produce is
     ;;   the inert fallback accessor returned by make-impersonator-property.
     (func $impersonator-property-accessor-procedure? (type $Prim1)
           (param $v (ref eq)) ;; candidate value
           (result   (ref eq))
           (if (result (ref eq))
               (ref.eq (local.get $v)
                       (global.get $prim:webracket-impersonator-property-accessor))
               (then (global.get $true))
               (else (global.get $false))))

     ;; webracket-impersonator-property-predicate : any/c -> boolean?
     ;;   Inert predicate for the no-impersonator runtime.
     (func $webracket-impersonator-property-predicate (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq))
           (global.get $false))

     ;; webracket-impersonator-property-accessor : any/c [any/c] -> any/c
     ;;   Inert accessor. With no fallback, Racket raises; with a fallback
     ;;   procedure it tail-calls the procedure with zero arguments,
     ;;   otherwise it returns the fallback value.
     (func $webracket-impersonator-property-accessor (type $Prim12)
           (param $v        (ref eq)) ;; any value
           (param $fallback (ref eq)) ;; optional fallback, default = raise
           (result          (ref eq))

           (local $proc (ref $Procedure))
           (local $inv  (ref $ProcedureInvoker))

           (if (ref.eq (local.get $fallback) (global.get $missing))
               (then (call $raise-argument-error1
                           (global.get $symbol:webracket-impersonator-property-accessor)
                           (global.get $string:impersonator-property?)
                           (local.get $v))
                     (unreachable)))
           (if (ref.eq (call $procedure? (local.get $fallback)) (global.get $true))
               (then
                (local.set $proc (ref.cast (ref $Procedure) (local.get $fallback)))
                (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
                (return_call_ref $ProcedureInvoker
                                 (local.get $proc)
                                 (array.new_fixed $Args 0)
                                 (local.get $inv))))
           (local.get $fallback)))))
