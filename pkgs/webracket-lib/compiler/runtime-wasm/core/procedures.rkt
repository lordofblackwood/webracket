#lang racket

(provide procedure-core-runtime-helpers
         procedure-basic-runtime-only-helper-names
         procedure-arity-at-least-runtime-only-helper-names
         procedure-arity-field-runtime-only-helper-names
         procedure-composition-runtime-only-helper-names
         procedure-reduction-runtime-only-helper-names
         procedure-arity-runtime-only-helper-names
         procedure-result-arity-runtime-only-helper-names
         procedure-arity-mask-runtime-only-helper-names
         primitive-reflection-runtime-only-helper-names
         procedure-application-error-runtime-only-helper-names
         procedure-invocation-error-runtime-only-helper-names
         procedure-invoker-runtime-only-helper-names
         procedure-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; procedure-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate procedure-call helpers that can be emitted in core runtime.
(define procedure-core-runtime-helpers
  (list
   ;; rest-arguments->list : (ref $Args) i32 -> (ref eq)
   ;;   Copy arguments from index n onward into a freshly allocated list.
   (core-runtime-helper
    '$rest-arguments->list
    "$rest-arguments->list"
    (lambda ()
      `(func $rest-arguments->list
             (param $args (ref $Args))
             (param $n    i32)
             (result      (ref eq))

             (local $len  i32)
             (local $i    i32)
             (local $x    (ref eq))
             (local $xs   (ref eq))
             ;; Compute length of args
             (local.set $len (array.len (local.get $args)))
             ;; Return empty list if n >= len
             (if (i32.ge_u (local.get $n) (local.get $len))
                 (then (return ,(Imm '()))))
             ;; Start with empty list
             (local.set $xs ,(Imm '()))
             ;; Start loop from len - 1 down to n (inclusive)
             (local.set $i (i32.sub (local.get $len) (i32.const 1)))
             (block $done
                    (loop $rev
                          ;; x = args[i]
                          (local.set $x (array.get $Args (local.get $args) (local.get $i)))
                          ;; xs = (cons x xs)
                          (local.set $xs
                                     (struct.new $Pair
                                                 (i32.const 0)        ;; dummy hash
                                                 (local.get $x)       ;; car
                                                 (local.get $xs)))    ;; cdr
                          ;; Stop when i == n
                          (br_if $done (i32.eq (local.get $i) (local.get $n)))
                          ;; i--
                          (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                          (br $rev)))
             (local.get $xs))))

   ;; rest-arguments->args : (ref $Args) i32 -> (ref $Args)
   ;;   Copy arguments from index n onward into a fresh argument array.
   (core-runtime-helper
    '$rest-arguments->args
    "$rest-arguments->args"
    (lambda ()
      `(func $rest-arguments->args
             (param $args (ref $Args))
             (param $n    i32)
             (result      (ref $Args))

             (local $len   i32)
             (local $count i32)
             (local $res   (ref $Args))

             (local.set $len (array.len (local.get $args)))
             (if (i32.ge_u (local.get $n) (local.get $len))
                 (then (return (array.new $Args ,(Imm '()) (i32.const 0)))))
             (local.set $count (i32.sub (local.get $len) (local.get $n)))
             (local.set $res (array.new $Args ,(Imm '()) (local.get $count)))
             (array.copy $Args $Args
                         (local.get $res)
                         (i32.const 0)
                         (local.get $args)
                         (local.get $n)
                         (local.get $count))
             (local.get $res))))))

;; procedure-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic procedure helpers.
(define procedure-basic-runtime-only-helper-names
  '($procedure?
    $procedure-specialize
    $apply
    $procedure->method
    $procedure-rename
    $procedure-realm
    $raise-argument-error:procedure-expected/who
    $raise-argument-error:procedure-expected))

;; procedure-arity-at-least-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for arity-at-least helpers.
(define procedure-arity-at-least-runtime-only-helper-names
  '($ensure-arity-at-least-type
    $arity-at-least/make
    $make-arity-at-least
    $arity-at-least
    $raise-argument-error:arity-at-least-expected
    $arity-at-least-unwrap
    $arity-at-least?
    $arity-at-least-value))

;; procedure-arity-field-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure arity field helpers.
(define procedure-arity-field-runtime-only-helper-names
  '($procedure-arity-entry->marker/i32
    $procedure-arity?
    $procedure-arity-value->field
    $procedure-arity-field->mask/i32
    $procedure-arity-mask-value->field))

;; procedure-composition-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure composition helpers.
(define procedure-composition-runtime-only-helper-names
  '($make-composed-procedure
    $compose
    $compose1
    $procedure-extract-target))

;; procedure-reduction-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure arity reduction helpers.
(define procedure-reduction-runtime-only-helper-names
  '($procedure-reduce-arity
    $procedure-reduce-arity-mask))

;; procedure-arity-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure arity accessors.
(define procedure-arity-runtime-only-helper-names
  '($procedure-arity
    $procedure-arity/checked))

;; procedure-result-arity-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure result arity helpers.
(define procedure-result-arity-runtime-only-helper-names
  '($procedure-result-arity))

;; procedure-arity-mask-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure arity mask helpers.
(define procedure-arity-mask-runtime-only-helper-names
  '($procedure-arity-mask
    $procedure-arity-mask/checked/i32
    $raise-argument-error:fixnum-expected
    $procedure-arity-includes?
    $procedure-arity-includes?/checked/i32))

;; primitive-reflection-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for primitive reflection helpers.
(define primitive-reflection-runtime-only-helper-names
  '($raise-argument-error:primitive-procedure-expected
    $primitive?
    $primitive-result-arity
    $primitive-closure?))

;; procedure-invocation-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure invocation error helpers.
(define procedure-invocation-error-runtime-only-helper-names
  '($raise-arity-mismatch
    $procedure-arity->expected-string
    $raise-arity-mismatch/proc
    $raise-arity-mismatch/name+given
    $result-arity-count
    $raise-result-arity-error/internal
    $raise-binding-result-arity-error
    $raise-definition-result-arity-error))

;; procedure-application-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure application error helpers.
(define procedure-application-error-runtime-only-helper-names
  '($raise-application-not-procedure
    $raise-apply-final-arg-not-list
    $raise-struct-type-property-accessor-contract))

;; procedure-invoker-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for procedure invoker helpers.
(define procedure-invoker-runtime-only-helper-names
  '($invoke-closure
    $invoke-reduced-procedure
    $invoke-composed-procedure
    $invoke-case-closure))

;; procedure-invocation-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate procedure invocation error helpers used by the monolithic runtime.
(define procedure-invocation-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'procedure-invocation-error-runtime-only-helpers
   '(
        (func $raise-arity-mismatch (unreachable))

        (func $procedure-arity->expected-string
              (param $proc (ref $Procedure))
              (result (ref $String))
              (local $a         (ref eq))
              (local $arity/tag i32)
              (local $arity     i32)

              (local.set $a (struct.get $Procedure $arity (local.get $proc)))

              (if (ref.test (ref i31) (local.get $a))
                  (then
                   (local.set $arity/tag (i31.get_s (ref.cast (ref i31) (local.get $a))))
                   (local.set $arity (i32.shr_s (local.get $arity/tag) (i32.const 1)))
                   (return (call $arity-i32->string (local.get $arity)))))

              (ref.cast (ref $String)
                        (call $format/display (call $procedure-arity (local.get $proc)))))

        (func $raise-arity-mismatch/proc
              (param $proc (ref $Procedure))
              (param $argc i32)
              (local $name         (ref eq))
              (local $debug-id     (ref eq))
              (local $expected-str (ref $String))
              (local $received-str (ref $String))
              (local $out          (ref $GrowableArray))
              (local $message      (ref $String))

              (local.set $name
                         (struct.get $Procedure $name (local.get $proc)))
              (local.set $debug-id (global.get $false))
              (if (ref.test (ref $Closure) (local.get $proc))
                  (then
                   (local.set $debug-id
                              (struct.get $Closure $debug-id
                                          (ref.cast (ref $Closure) (local.get $proc))))))

              (local.set $expected-str
                         (call $procedure-arity->expected-string (local.get $proc)))
              (local.set $received-str
                         (call $i32->string (local.get $argc)))

              (if (i32.gt_u (global.get $debug-invoke-budget) (i32.const 0))
                  (then
                   (drop (call $js-log (global.get $symbol:procedure-arity-frontier)))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:name)
                                           (call $cons (local.get $name)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:debug-id)
                                           (call $cons (local.get $debug-id)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:expected-count)
                                           (call $cons (local.get $expected-str)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:received-count)
                                           (call $cons (local.get $received-str)
                                                 (global.get $null)))
                                     (global.get $null))))))

              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $name)))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:start))
              (call $growable-array-add! (local.get $out) (local.get $expected-str))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out) (local.get $received-str))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract:arity/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-arity-mismatch/name+given
              (param $name (ref eq))
              (param $argc i32)
              (local $received-str (ref $String))
              (local $out          (ref $GrowableArray))
              (local $message      (ref $String))

              ;; TODO: include "arguments..." block like Racket.
              (local.set $received-str
                         (call $i32->string (local.get $argc)))
              (local.set $out
                         (call $make-growable-array (i32.const 3)))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $name)))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:start/no-expected))
              (call $growable-array-add! (local.get $out) (local.get $received-str))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract:arity/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        ;; result-arity-count : (or/c exact-integer? list? values?) -> i32
        ;;   Compute counts for Schemify's result-arity helper primitives.
        (func $result-arity-count
              (param $v (ref eq))
              (result i32)

              (if (ref.test (ref i31) (local.get $v))
                  (then (return (i32.shr_s
                                 (i31.get_s (ref.cast (ref i31) (local.get $v)))
                                 (i32.const 1)))))
              (if (ref.test (ref $Values) (local.get $v))
                  (then (return (array.len (ref.cast (ref $Values) (local.get $v))))))
              (call $length/i32 (local.get $v)))

        ;; raise-result-arity-error/internal : symbol? any/c any/c -> none
        ;;   Raise a catchable result-arity error for internal Schemify checks.
        (func $raise-result-arity-error/internal
              (param $who      (ref eq))      ;; symbol
              (param $expected (ref eq))      ;; expected count or identifier list
              (param $args     (ref eq))      ;; received values as list or $Values
              (result          (ref eq))

              (local $out          (ref $GrowableArray))
              (local $message      (ref $String))

              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $who)))
              (call $growable-array-add! (local.get $out) (global.get $string:result-arity-error:start))
              (call $growable-array-add! (local.get $out)
                    (call $i32->string (call $result-arity-count (local.get $expected))))
              (call $growable-array-add! (local.get $out) (global.get $string:result-arity-error:received))
              (call $growable-array-add! (local.get $out)
                    (call $i32->string (call $result-arity-count (local.get $args))))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract:arity/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        ;; raise-binding-result-arity-error : any/c any/c -> none
        ;;   Report a local-binding result-arity mismatch from Schemify output.
        (func $raise-binding-result-arity-error
              (type $Prim2)
              (param $expected (ref eq))
              (param $args     (ref eq))
              (result          (ref eq))

              (local $caller-proc     (ref eq))
              (local $caller-name     (ref eq))
              (local $caller-debug-id (ref eq))

              (if (i32.gt_u (global.get $debug-invoke-budget) (i32.const 0))
                  (then
                   (local.set $caller-proc (global.get $debug-current-procedure))
                   (local.set $caller-name (global.get $debug-current-procedure-name))
                   (local.set $caller-debug-id (global.get $false))
                   (if (ref.test (ref $Procedure) (local.get $caller-proc))
                       (then
                        (local.set $caller-name
                                   (struct.get $Procedure $name
                                               (ref.cast (ref $Procedure)
                                                         (local.get $caller-proc))))))
                   (if (ref.test (ref $Closure) (local.get $caller-proc))
                       (then
                        (local.set $caller-debug-id
                                   (struct.get $Closure $debug-id
                                               (ref.cast (ref $Closure)
                                                         (local.get $caller-proc))))))
                   (drop (call $js-log
                               (global.get $symbol:binding-result-arity-frontier)))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:expected-count)
                                           (call $cons
                                                 (call $i32->string
                                                       (call $result-arity-count
                                                             (local.get $expected)))
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:received-count)
                                           (call $cons
                                                 (call $i32->string
                                                       (call $result-arity-count
                                                             (local.get $args)))
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-name)
                                           (call $cons (local.get $caller-name)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-debug-id)
                                           (call $cons (local.get $caller-debug-id)
                                                 (global.get $null)))
                                     (global.get $null))))))
              (call $raise-result-arity-error/internal
                    (global.get $symbol:raise-binding-result-arity-error)
                    (local.get $expected)
                    (local.get $args)))

        ;; raise-definition-result-arity-error : any/c any/c -> none
        ;;   Report a define-values result-arity mismatch from Schemify output.
        (func $raise-definition-result-arity-error
              (type $Prim2)
              (param $expected (ref eq))
              (param $args     (ref eq))
              (result          (ref eq))
              (call $raise-result-arity-error/internal
                    (global.get $symbol:raise-definition-result-arity-error)
                    (local.get $expected)
                    (local.get $args)))
     )))

;; procedure-application-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate procedure application error helpers used by the monolithic runtime.
(define procedure-application-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'procedure-application-error-runtime-only-helpers
   '(
        (func $raise-application-not-procedure
              (param $v (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))
              (local $caller-proc (ref eq))
              (local $caller-name (ref eq))
              (local $caller-debug-id (ref eq))
              (local $got-struct-type (ref eq))

              (if (i32.gt_u (global.get $debug-invoke-budget) (i32.const 0))
                  (then
                   (local.set $caller-proc (global.get $debug-current-procedure))
                   (local.set $caller-name (global.get $debug-current-procedure-name))
                   (local.set $caller-debug-id (global.get $false))
                   (local.set $got-struct-type (global.get $false))
                   (if (ref.test (ref $Procedure) (local.get $caller-proc))
                       (then
                        (local.set $caller-name
                                   (struct.get $Procedure $name
                                               (ref.cast (ref $Procedure)
                                                         (local.get $caller-proc))))))
                   (if (ref.test (ref $Closure) (local.get $caller-proc))
                       (then
                        (local.set $caller-debug-id
                                   (struct.get $Closure $debug-id
                                               (ref.cast (ref $Closure)
                                                         (local.get $caller-proc))))))
                   (if (ref.test (ref $Struct) (local.get $v))
                       (then
                        (local.set $got-struct-type
                                   (struct.get $StructType $name
                                               (struct.get $Struct $type
                                                           (ref.cast (ref $Struct)
                                                                     (local.get $v)))))))
                   (drop (call $js-log
                               (global.get $symbol:application-not-procedure-frontier)))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:got-struct-type)
                                           (call $cons (local.get $got-struct-type)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:got-procedure?)
                                           (call $cons (call $procedure? (local.get $v))
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-name)
                                           (call $cons (local.get $caller-name)
                                                 (global.get $null)))
                                     (global.get $null))))
                   (drop (call $js-log
                               (call $cons
                                     (call $cons (global.get $symbol:caller-debug-id)
                                           (call $cons (local.get $caller-debug-id)
                                                 (global.get $null)))
                                     (global.get $null))))))

              (local.set $out
                         (call $make-growable-array (i32.const 2)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:application:not-procedure))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $v)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-apply-final-arg-not-list
              (param $v (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              ;; TODO: include "argument position: last" and "other arguments..." block like Racket.
              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (global.get $symbol:apply)))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:list?))
              (call $growable-array-add! (local.get $out)
                    (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $v)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))

        (func $raise-struct-type-property-accessor-contract
              (param $prop (ref $StructTypeProperty))
              (param $v    (ref eq))
              (local $accessor-name     (ref $String))
              (local $prop-name-str     (ref $String))
              (local $expected-str      (ref $String))
              (local $out               (ref $GrowableArray))
              (local $message           (ref $String))

              (local.set $prop-name-str
                         (ref.cast (ref $String)
                                   (call $symbol->string
                                         (struct.get $StructTypeProperty $name (local.get $prop)))))
              (local.set $accessor-name
                         (call $string-append/2
                               (local.get $prop-name-str)
                               (global.get $string:accessor-suffix)))
              (local.set $expected-str
                         (call $string-append/2
                               (local.get $prop-name-str)
                               (global.get $string:question)))

              (local.set $out
                         (call $make-growable-array (i32.const 5)))
              (call $growable-array-add! (local.get $out) (local.get $accessor-name))
              (call $growable-array-add! (local.get $out) (global.get $string:contract-violation:prefix))
              (call $growable-array-add! (local.get $out) (local.get $expected-str))
              (call $growable-array-add! (local.get $out) (global.get $string:arity-error:given))
              (call $growable-array-add! (local.get $out) (call $format/display (local.get $v)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))

              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))
     )))

;; procedure-invoker-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate procedure invoker helpers used by the monolithic runtime.
(define procedure-invoker-runtime-only-helpers
  (function-forms->runtime-helpers
   'procedure-invoker-runtime-only-helpers
   '(
         (func $invoke-closure
               (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))      ;; array of (ref eq)
               (result      (ref eq))

               (local $clos          (ref $Closure))
               (local $code          (ref $ClosureCode))
               (local $arity-i31     (ref i31))
               (local $arity-i32     i32)
               (local $arg-count     i32)
               (local $args-repacked (ref $Args))

               (global.set $debug-current-procedure (local.get $proc))
               (call $debug-invoke-tick)
               ;; Step 1: cast proc to closure and extract code
               (local.set $clos (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $code (struct.get $Closure $code (local.get $clos)))
               ;; Step 2: get arity as signed i32
               (local.set $arity-i31
                          (ref.cast (ref i31) (struct.get $Procedure $arity (local.get $clos))))
               (local.set $arity-i32
                          (i32.shr_s (i31.get_s (local.get $arity-i31)) (i32.const 1)))
               ;; Step 3: get argument count
               (local.set $arg-count (array.len (local.get $args)))
               ;; Debug: log argument count and expected arity
               ; (drop (call $js-log (local.get $proc)))
               ;; Step 4: check arity match
               (if (i32.eqz
                    (call $procedure-arity-includes?/checked/i32
                          (local.get $clos)
                          (local.get $arg-count)))
                   (then
                    (call $raise-arity-mismatch/proc (local.get $clos) (local.get $arg-count))))
               ;; Step 5: repack arguments (if variadic)
               (local.set $args-repacked
                          (call $repack-arguments
                                (local.get $args)
                                (local.get $arity-i32)))
               ;; Step 6: invoke
               (return_call_ref $ClosureCode
                                (local.get $clos)
                                (local.get $args-repacked)
                                (local.get $code)))

         (func $invoke-reduced-procedure
               (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))
               (result      (ref eq))

               (local $wrapper  (ref $Closure))
               (local $original (ref $Procedure))
               (local $arg-count i32)

               (local.set $wrapper (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $original
                          (ref.cast (ref $Procedure)
                                    (array.get $Free
                                               (struct.get $Closure $free (local.get $wrapper))
                                               (i32.const 0))))
               (local.set $arg-count (array.len (local.get $args)))
               (if (i32.eqz
                    (call $procedure-arity-includes?/checked/i32
                          (local.get $wrapper)
                          (local.get $arg-count)))
                   (then
                    (call $raise-arity-mismatch/proc (local.get $wrapper) (local.get $arg-count))))
               (return_call_ref $ProcedureInvoker
                                (local.get $original)
                                (local.get $args)
                                (struct.get $Procedure $invoke (local.get $original))))

         ;; invoke-composed-procedure : procedure? args-array? -> any
         ;;   Invoke a compose/compose1 wrapper from right to left.
         (func $invoke-composed-procedure
               (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))
               (result      (ref eq))

               (local $wrapper (ref $Closure))
               (local $free    (ref $Free))
               (local $procs   (ref $Array))
               (local $single? (ref eq))
               (local $p       (ref $Procedure))
               (local $inv     (ref $ProcedureInvoker))
               (local $result  (ref eq))
               (local $vals    (ref $Values))
               (local $next    (ref $Args))
               (local $i       i32)
               (local $n       i32)
               (local $m       i32)

               (local.set $p      (global.get $dummy-closure))
               (local.set $inv    (ref.func $invoke-closure))
               (local.set $result (global.get $false))
               (local.set $vals   (array.new $Values (global.get $null) (i32.const 0)))
               (local.set $next   (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $wrapper (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $free    (struct.get $Closure $free (local.get $wrapper)))
               (local.set $procs   (ref.cast (ref $Array)
                                              (array.get $Free (local.get $free) (i32.const 0))))
               (local.set $single? (array.get $Free (local.get $free) (i32.const 1)))
               (local.set $n       (array.len (local.get $procs)))
               (if (i32.eqz (local.get $n))
                   (then (return_call $values (local.get $args))))

               (local.set $i (i32.sub (local.get $n) (i32.const 1)))
               (local.set $p (ref.cast (ref $Procedure)
                                        (array.get $Array (local.get $procs) (local.get $i))))
               (local.set $inv (struct.get $Procedure $invoke (local.get $p)))
               (local.set $result
                          (call_ref $ProcedureInvoker
                                    (local.get $p)
                                    (local.get $args)
                                    (local.get $inv)))

               (block $done
                      (loop $loop
                            (br_if $done (i32.eqz (local.get $i)))
                            (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                            (if (ref.eq (local.get $single?) (global.get $true))
                                (then
                                 (local.set $result (call $expect-one-value (local.get $result)))
                                 (local.set $next (array.new_fixed $Args 1 (local.get $result))))
                                (else
                                 (if (ref.test (ref $Values) (local.get $result))
                                     (then
                                      (local.set $vals (ref.cast (ref $Values) (local.get $result)))
                                      (local.set $m    (array.len (local.get $vals)))
                                      (local.set $next (array.new $Args (global.get $null) (local.get $m)))
                                      (array.copy $Args $Values
                                                  (local.get $next) (i32.const 0)
                                                  (local.get $vals) (i32.const 0)
                                                  (local.get $m)))
                                     (else
                                      (local.set $next
                                                 (array.new_fixed $Args 1 (local.get $result)))))))
                            (local.set $p (ref.cast (ref $Procedure)
                                                    (array.get $Array
                                                               (local.get $procs)
                                                               (local.get $i))))
                            (local.set $inv (struct.get $Procedure $invoke (local.get $p)))
                            (local.set $result
                                       (call_ref $ProcedureInvoker
                                                 (local.get $p)
                                                 (local.get $next)
                                                 (local.get $inv)))
                            (br $loop)))
               (local.get $result))

         ;; Invoker for case-lambda closures.
         ;; - $args is the vector of *user* arguments (no [closure, tail?] header).
         ;; - Arity checking + repacking are handled by the closure's code
         ;;   ($code:case-lambda-dispatch), so we just tail-call it.
         ; Note: In principle we could use $invoke-closure,
         ;       but that leads to checking the arity multiple times.
         (func $invoke-case-closure (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))
               (result      (ref eq))

               (local $clos (ref $Closure))
               (local $code (ref $ClosureCode))
               (global.set $debug-current-procedure (local.get $proc))
               (call $debug-invoke-tick)
               ;; Cast and fetch code pointer
               (local.set $clos (ref.cast (ref $Closure) (local.get $proc)))
               (local.set $code (struct.get $Closure $code (local.get $clos)))
               ;; Tail-call the dispatcher
               (return_call_ref $ClosureCode
                                (local.get $clos)
                                (local.get $args)
                                (local.get $code)))
     )))

;; procedure-basic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate basic procedure helpers used by the monolithic runtime.
(define procedure-basic-runtime-only-helpers
  (function-forms->runtime-helpers
   'procedure-basic-runtime-only-helpers
   '(
     ;; procedure? : any/c -> boolean?
     ;;   Recognize procedures semantically; non-applicable structs are not procedures.
     (func $procedure? (type $Prim1)
           (param $v (ref eq)) ;; candidate value
           (result   (ref eq))
           (if (ref.test (ref $Struct) (local.get $v))
               (then (return (if (result (ref eq))
                                 (i32.or
                                  (call $applicable-struct?/i32 (local.get $v))
                                  (call $checked-procedure-struct?/i32 (local.get $v)))
                                 (then (global.get $true))
                                 (else (global.get $false))))))
           (if (result (ref eq))
               (ref.test (ref $Procedure) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     ;; procedure-specialize : procedure? -> procedure?
     ;;   Validate and return the procedure. Racket uses this as an
     ;;   optimization hint; WebRacket currently has no procedure
     ;;   specializer to invoke.
     (func $procedure-specialize (type $Prim1)
           (param $proc (ref eq)) ;; procedure?
           (result      (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (local.get $proc))

     ; Notes: repacking of arguments are done in $invoke-closure,
     ;        so no repacking is needed in $apply.

     (func $apply (type $Prim>=1)
           (param $proc      (ref eq)) ;; procedure to apply
           (param $args-list (ref eq)) ;; list of arguments (direct args + final list)
           (result           (ref eq))

           (local $p             (ref $Procedure))
           (local $args-array    (ref $Array))
           (local $final-array   (ref $Array))
           (local $result-array  (ref $Array))
           (local $final-list    (ref eq))
           (local $total-count   i32)
           (local $direct-count  i32)
           (local $final-count   i32)
           (local $i             i32)
           (local $val           (ref eq))

           ;; Initialize non-defaultable locals.
           (local.set $args-array   (call $make-array (i32.const 0) (global.get $null)))
           (local.set $final-array  (call $make-array (i32.const 0) (global.get $null)))
           (local.set $result-array (call $make-array (i32.const 0) (global.get $null)))
           (local.set $final-list   (global.get $null))
           (local.set $total-count  (i32.const 0))
           (local.set $direct-count (i32.const 0))
           (local.set $final-count  (i32.const 0))
           (local.set $i            (i32.const 0))
           (local.set $val          (global.get $null))

           ;; Step 1: ensure $proc is a semantic procedure. Structs are
           ;; represented under $Procedure for fast application, but only
           ;; structs with prop:procedure are Racket procedures.
           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))

           ;; Step 2: convert arguments list into arrays for indexed access
           (if (ref.eq (call $list? (local.get $args-list)) (global.get $false))
               (then (call $raise-apply-final-arg-not-list (local.get $args-list))
                     (unreachable)))
           (local.set $args-array  (call $list->array (local.get $args-list)))
           (local.set $total-count (array.len (local.get $args-array)))
           ;; The final element of $args-array is the list of trailing arguments.
           (local.set $final-list
                      (array.get $Array
                                 (local.get $args-array)
                                 (i32.sub (local.get $total-count) (i32.const 1))))
           (if (ref.eq (call $list? (local.get $final-list)) (global.get $false))
               (then (call $raise-apply-final-arg-not-list (local.get $final-list))
                     (unreachable)))
           (local.set $final-array (call $list->array (local.get $final-list)))
           (local.set $final-count (array.len (local.get $final-array)))
           (local.set $direct-count (i32.sub (local.get $total-count) (i32.const 1)))

           ;; Step 3: allocate the combined argument array
           (local.set $result-array
                      (call $make-array
                            (i32.add (local.get $direct-count) (local.get $final-count))
                            (global.get $null)))


           ;; Step 4: copy direct arguments
           (local.set $i (i32.const 0))
           (block $direct-done
                  (loop $direct
                        (if (i32.ge_u (local.get $i) (local.get $direct-count))
                            (then (br $direct-done)))
                        (local.set $val
                                   (array.get $Array (local.get $args-array)
                                              (local.get $i)))
                        (call $array-set!
                              (local.get $result-array)
                              (local.get $i)
                              (local.get $val))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $direct)))

           ;; Step 5: append values from the final list
           (local.set $i (i32.const 0))
           (block $append-done
                  (loop $append
                        (if (i32.ge_u (local.get $i) (local.get $final-count))
                            (then (br $append-done)))
                        (local.set $val
                                   (array.get $Array (local.get $final-array)
                                              (local.get $i)))
                        (call $array-set!
                              (local.get $result-array)
                              (i32.add (local.get $i) (local.get $direct-count))
                              (local.get $val))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $append)))

           ;; Step 6: apply via the procedure's invoke field
           (return_call_ref $ProcedureInvoker
                            (local.get $p)
                            (local.get $result-array)
                            (struct.get $Procedure $invoke (local.get $p))))

     ;; procedure->method : procedure? -> procedure?
     ;;   Racket uses method procedures to adjust arity errors by hiding
     ;;   the implicit receiver argument. WebRacket does not model that
     ;;   method-wrapper distinction yet, so preserve the callable while
     ;;   still enforcing the documented procedure? contract.
     (func $procedure->method (type $Prim1)
           (param $proc (ref eq)) ; procedure?
           (result      (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:procedure->method)
                           (global.get $string:procedure?)
                           (local.get $proc))
                     (unreachable)))
           (local.get $proc))

     (func $procedure-rename (type $Prim23)
           (param $proc  (ref eq))   ;; any procedure
           (param $name  (ref eq))   ;; symbol
           (param $realm (ref eq))   ;; symbol or $missing
           (result (ref eq))

           (local $arity      (ref eq))
           (local $invoke     (ref $ProcedureInvoker))
           (local $realm*     (ref eq))
           (local $case-proc  (ref $CaseClosure))

           ;; Step 1: If realm is #f, replace with 'racket
           (local.set $realm*
                      (if (result (ref eq))
                          (ref.eq (local.get $realm) (global.get $missing))
                          (then (global.get $symbol:racket))
                          (else (local.get $realm))))
           ;; Step 2: If $proc is a CaseClosure, preserve its arms and arity table
           (if (ref.test (ref $CaseClosure) (local.get $proc))
               (then
                (local.set $case-proc (ref.cast (ref $CaseClosure) (local.get $proc)))
                 (return
                 (struct.new $CaseClosure
                             (i32.const 0)                                 ;; hash
                             (local.get $name)
                             (struct.get $CaseClosure $arity   (local.get $case-proc))
                             (local.get $realm*)
                             (struct.get $CaseClosure $invoke  (local.get $case-proc))
                             (struct.get $CaseClosure $debug-id (local.get $case-proc))
                             (struct.get $CaseClosure $code    (local.get $case-proc))
                             (struct.get $CaseClosure $free    (local.get $case-proc))
                             (struct.get $CaseClosure $arities (local.get $case-proc))
                             (struct.get $CaseClosure $arms    (local.get $case-proc))))))
           ;; Step 3: If $proc is a Closure
           (if (ref.test (ref $Closure) (local.get $proc))
               (then
                (return
                (struct.new $Closure
                            (i32.const 0)                                 ;; hash
                            (local.get $name)
                            (struct.get $Closure $arity  (ref.cast (ref $Closure) (local.get $proc)))
                            (local.get $realm*)
                            (struct.get $Closure $invoke (ref.cast (ref $Closure) (local.get $proc)))
                            (struct.get $Closure $debug-id (ref.cast (ref $Closure) (local.get $proc)))
                            (struct.get $Closure $code   (ref.cast (ref $Closure) (local.get $proc)))
                            (struct.get $Closure $free   (ref.cast (ref $Closure) (local.get $proc)))))))
           ;; Step 4: If $proc is a PrimitiveClosure
           (if (ref.test (ref $PrimitiveClosure) (local.get $proc))
               (then
                (return
                (struct.new $PrimitiveClosure
                            (i32.const 0)
                            (local.get $name)
                            (struct.get $PrimitiveClosure $arity  (ref.cast (ref $PrimitiveClosure) (local.get $proc)))
                            (local.get $realm*)
                            (struct.get $PrimitiveClosure $invoke (ref.cast (ref $PrimitiveClosure) (local.get $proc)))
                            (struct.get $PrimitiveClosure $code (ref.cast (ref $PrimitiveClosure) (local.get $proc)))
                            (struct.get $PrimitiveClosure $result-arity
                                        (ref.cast (ref $PrimitiveClosure) (local.get $proc)))))))
           ;; Step 5: If $proc is a PrimitiveProcedure
           (if (ref.test (ref $PrimitiveProcedure) (local.get $proc))
               (then
                (return
                (struct.new $PrimitiveProcedure
                            (i32.const 0)
                            (local.get $name)
                            (struct.get $PrimitiveProcedure $arity  (ref.cast (ref $PrimitiveProcedure) (local.get $proc)))
                            (local.get $realm*)
                            (struct.get $PrimitiveProcedure $invoke (ref.cast (ref $PrimitiveProcedure) (local.get $proc)))
                            (struct.get $PrimitiveProcedure $code   (ref.cast (ref $PrimitiveProcedure) (local.get $proc)))
                            (struct.get $PrimitiveProcedure $result-arity
                                        (ref.cast (ref $PrimitiveProcedure) (local.get $proc)))))))
           ;; Step 6: Not a supported procedure type
           (call $raise-argument-error:procedure-expected (local.get $proc))
           (unreachable))

     ;; procedure-realm : procedure? -> symbol?
     ;;   Return a procedure's realm, defaulting to 'racket when WebRacket
     ;;   represents an applicable value without richer realm metadata.
     (func $procedure-realm (type $Prim1)
           (param $proc (ref eq)) ; procedure?
           (result      (ref eq))

           (local $p     (ref $Procedure))
           (local $realm (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:procedure-realm)
                           (global.get $string:procedure?)
                           (local.get $proc))
                     (unreachable)))

           (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))
           (local.set $realm (struct.get $Procedure $realm (local.get $p)))
           (if (result (ref eq))
               (ref.eq (local.get $realm) (global.get $false))
               (then (global.get $symbol:racket))
               (else (local.get $realm))))


     (func $raise-argument-error:procedure-expected/who
           (param $who (ref eq))
           (param $got (ref eq))

           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:procedure?)
                 (local.get $got)))

     (func $raise-argument-error:procedure-expected
           (param $got (ref eq))

           (call $raise-argument-error:procedure-expected/who
                 (global.get $symbol:procedure)
                 (local.get $got)))
     )))

;; procedure-arity-and-reflection-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate procedure arity and reflection helpers used by the monolithic runtime.
(define procedure-arity-and-reflection-runtime-only-helpers
  (function-forms->runtime-helpers
   'procedure-arity-and-reflection-runtime-only-helpers
   '(
     ;; Support for the arity-at-least structure used by procedure-arity.
     (func $ensure-arity-at-least-type
           (result (ref $StructType))

           (local $existing (ref null $StructType))
           (local $std      (ref $StructType))
           (local $indices  (ref eq))

           (local.set $existing (global.get $arity-at-least-type))
           (if (ref.is_null (local.get $existing))
               (then
                (local.set $indices (call $list-from-range/checked (i32.const 0) (i32.const 1)))
                (local.set $std
                           (struct.new $StructType
                                       (i32.const 0)
                                       (ref.cast (ref $Symbol) (global.get $symbol:arity-at-least))
                                       (global.get $false)
                                       (i32.const 1)
                                       (local.get $indices)
                                       (global.get $null)
                                       (global.get $null)
                                       (ref.cast (ref eq) (call $struct-type-property-table-empty))
                                       (global.get $false)
                                       (local.get $indices)
                                       (global.get $false)
                                       (ref.cast (ref $Symbol) (global.get $symbol:arity-at-least))))
                (global.set $arity-at-least-type (local.get $std))
                (local.set $existing (local.get $std))))
           (ref.as_non_null (local.get $existing)))

     (func $arity-at-least/make
           (param $value i32)   ;; exact non-negative integer
           (result (ref eq))

           (local $std    (ref $StructType))
           (local $fields (ref $Array))

           (local.set $std (call $ensure-arity-at-least-type))
           (local.set $fields
                      (array.new_fixed $Array 1
                                       (ref.i31 (i32.shl (local.get $value) (i32.const 1)))))
           (ref.cast (ref eq)
                     (struct.new $Struct
                                 (i32.const 0)
                                 (global.get $false)
                                 (ref.i31 (i32.const 0))
                                 (global.get $false)
                                 (ref.func $invoke-struct)
                                 (local.get $std)
                                 (local.get $fields))))

     (func $make-arity-at-least (type $Prim1)
           (param $value (ref eq)) ; exact-nonnegative-integer?
           (result (ref eq))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $value)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:make-arity-at-least)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $value))
                     (unreachable)))
           (call $arity-at-least/make
                 (i32.shr_s
                  (i31.get_s (ref.cast (ref i31) (local.get $value)))
                  (i32.const 1))))

     (func $arity-at-least (type $Prim1)
           (param $value (ref eq)) ; exact-nonnegative-integer?
           (result (ref eq))

           (return_call $make-arity-at-least (local.get $value)))

     (func $raise-argument-error:arity-at-least-expected
           (param $who (ref eq))
           (param $got (ref eq))

           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:arity-at-least?)
                 (local.get $got)))

     (func $arity-at-least-unwrap
           (param $who (ref eq))
           (param $v   (ref eq))
           (result (ref $Struct))

           (local $struct (ref $Struct))
           (local $type   (ref eq))
           (local $std    (ref $StructType))
           (local $ok     i32)

           (local.set $std (call $ensure-arity-at-least-type))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (call $raise-argument-error:arity-at-least-expected (local.get $who) (local.get $v))
                     (unreachable)))
           (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
           (local.set $type   (struct.get $Struct $type (local.get $struct)))
           (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
           (if (i32.eqz (local.get $ok))
               (then (call $raise-argument-error:arity-at-least-expected (local.get $who) (local.get $v))
                     (unreachable)))
           (local.get $struct))

     (func $arity-at-least? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $struct (ref $Struct))
           (local $type   (ref eq))
           (local $std    (ref $StructType))
           (local $ok     i32)

           (local.set $std (call $ensure-arity-at-least-type))
           (if (result (ref eq))
               (ref.test (ref $Struct) (local.get $v))
               (then
                (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                (local.set $type   (struct.get $Struct $type (local.get $struct)))
                (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
                (if (result (ref eq))
                    (local.get $ok)
                    (then (global.get $true))
                    (else (global.get $false))))
               (else (global.get $false))))

     (func $arity-at-least-value (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))

           (local $struct (ref $Struct))
           (local $fields (ref $Array))

           (local.set $struct (call $arity-at-least-unwrap
                                     (global.get $symbol:arity-at-least-value)
                                     (local.get $v)))
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (array.get $Array (local.get $fields) (i32.const 0)))

     (func $procedure-arity-entry->marker/i32
           (param $who (ref eq))
           (param $v   (ref eq))
           (result i32)

           (local $struct (ref $Struct))
           (local $fields (ref $Array))
           (local $value  (ref eq))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $v)) (global.get $true))
               (then
                (return
                 (i32.shr_s
                  (i31.get_s (ref.cast (ref i31) (local.get $v)))
                  (i32.const 1)))))
           (if (ref.eq (call $arity-at-least? (local.get $v)) (global.get $true))
               (then
                (local.set $struct (call $arity-at-least-unwrap (local.get $who) (local.get $v)))
                (local.set $fields (struct.get $Struct $fields (local.get $struct)))
                (local.set $value  (array.get $Array (local.get $fields) (i32.const 0)))
                (return
                 (i32.sub
                  (i32.const -1)
                  (i32.shr_s
                   (i31.get_s (ref.cast (ref i31) (local.get $value)))
                   (i32.const 1))))))
           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:procedure-arity?)
                 (local.get $v))
           (unreachable))

     ;; procedure-arity? : any/c -> boolean?
     ;;   A procedure arity is an exact nonnegative integer, an
     ;;   arity-at-least value, or a proper list of those values.
     (func $procedure-arity? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $node  (ref eq))
           (local $entry (ref eq))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $v))
                       (global.get $true))
               (then (return (global.get $true))))
           (if (ref.eq (call $arity-at-least? (local.get $v))
                       (global.get $true))
               (then (return (global.get $true))))
           (if (ref.eq (call $list? (local.get $v)) (global.get $false))
               (then (return (global.get $false))))
           (local.set $node (local.get $v))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $node)
                                             (global.get $null)))
                        (local.set $entry
                                   (struct.get $Pair $a
                                               (ref.cast (ref $Pair)
                                                         (local.get $node))))
                        (if (ref.eq (call $exact-nonnegative-integer?
                                          (local.get $entry))
                                    (global.get $false))
                            (then
                             (if (ref.eq (call $arity-at-least?
                                               (local.get $entry))
                                         (global.get $false))
                                 (then (return (global.get $false))))))
                        (local.set $node
                                   (struct.get $Pair $d
                                               (ref.cast (ref $Pair)
                                                         (local.get $node))))
                        (br $loop)))
           (global.get $true))

     (func $procedure-arity-value->field
           (param $who   (ref eq))
           (param $arity (ref eq))
           (result (ref eq))

           (local $len    i32)
           (local $arr    (ref $I32Array))
           (local $i      i32)
           (local $node   (ref eq))
           (local $entry  (ref eq))
           (local $marker i32)

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $arity)) (global.get $true))
               (then (return (local.get $arity))))
           (if (ref.eq (call $arity-at-least? (local.get $arity)) (global.get $true))
               (then
                (local.set $marker (call $procedure-arity-entry->marker/i32
                                         (local.get $who)
                                         (local.get $arity)))
                (return (ref.i31 (i32.shl (local.get $marker) (i32.const 1))))))
           (if (ref.eq (call $list? (local.get $arity)) (global.get $false))
               (then
                (call $raise-argument-error1
                      (local.get $who)
                      (global.get $string:procedure-arity?)
                      (local.get $arity))
                (unreachable)))
           (local.set $len (call $length/i32 (local.get $arity)))
           (if (i32.eqz (local.get $len))
               (then
                (return (ref.cast (ref eq)
                                  (array.new_fixed $I32Array 0)))))
           (if (i32.eq (local.get $len) (i32.const 1))
               (then
                (return
                 (ref.i31
                  (i32.shl
                   (call $procedure-arity-entry->marker/i32
                         (local.get $who)
                         (call $car (local.get $arity)))
                   (i32.const 1))))))
           (local.set $arr (call $i32array-make (local.get $len) (i32.const 0)))
           (local.set $node (local.get $arity))
           (local.set $i    (i32.const 0))
           (block $done
                  (loop $fill
                        (br_if $done (ref.eq (local.get $node) (global.get $null)))
                        (local.set $entry (struct.get $Pair $a
                                                      (ref.cast (ref $Pair) (local.get $node))))
                        (local.set $marker (call $procedure-arity-entry->marker/i32
                                                 (local.get $who)
                                                 (local.get $entry)))
                        (call $i32array-set! (local.get $arr) (local.get $i) (local.get $marker))
                        (local.set $node (struct.get $Pair $d
                                                     (ref.cast (ref $Pair) (local.get $node))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $fill)))
           (ref.cast (ref eq) (local.get $arr)))

     (func $procedure-arity-field->mask/i32
           (param $a (ref eq))
           (result i32)

           (local $arr   (ref $I32Array))
           (local $i     i32)
           (local $n     i32)
           (local $m     i32)
           (local $arity i32)
           (local $mask  i32)
           (local $start i32)

           (if (ref.test (ref i31) (local.get $a))
               (then
                (local.set $arity (i32.shr_s
                                   (i31.get_s
                                    (ref.cast (ref i31) (local.get $a)))
                                   (i32.const 1)))
                (return
                 (if (result i32)
                     (i32.ge_s (local.get $arity) (i32.const 0))
                     (then (i32.shl (i32.const 1) (local.get $arity)))
                     (else (i32.shl (i32.const -1)
                                    (i32.sub (i32.const -1) (local.get $arity))))))))
           (local.set $arr (ref.cast (ref $I32Array) (local.get $a)))
           (local.set $n   (array.len (local.get $arr)))
           (local.set $i   (i32.const 0))
           (local.set $mask (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                        (local.set $m
                                   (array.get $I32Array (local.get $arr) (local.get $i)))
                        (if (i32.ge_s (local.get $m) (i32.const 0))
                            (then
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const 1) (local.get $m)))))
                            (else
                             (local.set $start
                                        (i32.sub (i32.const -1) (local.get $m)))
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const -1) (local.get $start))))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $mask))

     (func $procedure-arity-mask-value->field
           (param $who      (ref eq))
           (param $mask-raw (ref eq)) ; exact-integer?
           (result (ref eq))

           (local $mask          i32)
           (local $negative?     i32)
           (local $at-least-from i32)
           (local $limit         i32)
           (local $i             i32)
           (local $len           i32)
           (local $out           i32)
           (local $marker        i32)
           (local $arr           (ref $I32Array))

           (if (ref.eq (call $exact-integer? (local.get $mask-raw)) (global.get $false))
               (then
                (call $raise-argument-error1
                      (local.get $who)
                      (global.get $string:exact-integer?)
                      (local.get $mask-raw))
                (unreachable)))
           (local.set $mask
                      (i32.shr_s
                       (i31.get_s (ref.cast (ref i31) (local.get $mask-raw)))
                       (i32.const 1)))
           (local.set $negative? (i32.lt_s (local.get $mask) (i32.const 0)))
           (local.set $at-least-from (i32.const 31))
           (local.set $limit (i32.const 31))
           (if (local.get $negative?)
               (then
                ;; Negative masks represent exact arities below the first
                ;; all-ones suffix plus an arity-at-least marker.
                (local.set $at-least-from (i32.const 0))
                (block $found
                       (loop $find
                             (if (i32.eq (i32.shr_s
                                          (local.get $mask)
                                          (local.get $at-least-from))
                                         (i32.const -1))
                                 (then (br $found)))
                             (local.set $at-least-from
                                        (i32.add (local.get $at-least-from)
                                                 (i32.const 1)))
                             (br $find)))
                (local.set $limit (local.get $at-least-from))))

           (local.set $i (i32.const 0))
           (block $count-done
                  (loop $count
                        (br_if $count-done (i32.ge_u (local.get $i) (local.get $limit)))
                        (if (i32.ne (i32.and (local.get $mask)
                                             (i32.shl (i32.const 1) (local.get $i)))
                                    (i32.const 0))
                            (then
                             (local.set $marker (local.get $i))
                             (local.set $len (i32.add (local.get $len) (i32.const 1)))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $count)))
           (if (local.get $negative?)
               (then
                (local.set $marker
                           (i32.sub (i32.const -1) (local.get $at-least-from)))
                (local.set $len (i32.add (local.get $len) (i32.const 1)))))
           (if (i32.eqz (local.get $len))
               (then
                (return (ref.cast (ref eq)
                                  (array.new_fixed $I32Array 0)))))
           (if (i32.eq (local.get $len) (i32.const 1))
               (then
                (return (ref.i31 (i32.shl (local.get $marker) (i32.const 1))))))

           (local.set $arr (call $i32array-make (local.get $len) (i32.const 0)))
           (local.set $i (i32.const 0))
           (local.set $out (i32.const 0))
           (block $fill-done
                  (loop $fill
                        (br_if $fill-done (i32.ge_u (local.get $i) (local.get $limit)))
                        (if (i32.ne (i32.and (local.get $mask)
                                             (i32.shl (i32.const 1) (local.get $i)))
                                    (i32.const 0))
                            (then
                             (call $i32array-set!
                                   (local.get $arr)
                                   (local.get $out)
                                   (local.get $i))
                             (local.set $out (i32.add (local.get $out) (i32.const 1)))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $fill)))
           (if (local.get $negative?)
               (then
                (call $i32array-set!
                      (local.get $arr)
                      (local.get $out)
                      (i32.sub (i32.const -1) (local.get $at-least-from)))))
           (ref.cast (ref eq) (local.get $arr)))

     ;; make-composed-procedure : list? boolean? -> procedure?
     ;;   Build the procedure returned by compose or compose1.
     (func $make-composed-procedure
           (param $args    (ref eq))
           (param $single? (ref eq))
           (result         (ref eq))

           (local $procs (ref $Array))
           (local $n     i32)
           (local $i     i32)
           (local $p     (ref $Procedure))
           (local $free  (ref $Free))

           (local.set $procs (call $list->array (local.get $args)))
           (local.set $n     (array.len (local.get $procs)))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                        (if (i32.eqz
                             (ref.test (ref $Procedure)
                                       (array.get $Array
                                                  (local.get $procs)
                                                  (local.get $i))))
                            (then
                             (call $raise-argument-error:procedure-expected
                                   (array.get $Array
                                              (local.get $procs)
                                              (local.get $i)))
                             (unreachable)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (if (i32.eq (local.get $n) (i32.const 1))
               (then (return (array.get $Array (local.get $procs) (i32.const 0)))))
           (if (i32.eqz (local.get $n))
               (then
                (local.set $free
                           (array.new_fixed $Free
                                            2
                                            (ref.cast (ref eq) (local.get $procs))
                                            (local.get $single?)))
                (return
                 (struct.new $Closure
                             (i32.const 0)
                             (global.get $symbol:compose)
                             (ref.i31 (i32.const -2))
                             (global.get $the-racket-realm)
                             (ref.func $invoke-composed-procedure)
                             (global.get $symbol:compose)
                             (ref.func $dummy-code)
                             (local.get $free)))))
           (local.set $p (ref.cast (ref $Procedure)
                                    (array.get $Array
                                               (local.get $procs)
                                               (i32.sub (local.get $n) (i32.const 1)))))
           (local.set $free
                      (array.new_fixed $Free
                                       2
                                       (ref.cast (ref eq) (local.get $procs))
                                       (local.get $single?)))
           (struct.new $Closure
                       (i32.const 0)
                       (global.get $symbol:compose)
                       (struct.get $Procedure $arity (local.get $p))
                       (global.get $the-racket-realm)
                       (ref.func $invoke-composed-procedure)
                       (global.get $symbol:compose)
                       (ref.func $dummy-code)
                       (local.get $free)))

     (func $compose (type $Prim>=0)
           (param $args (ref eq))
           (result      (ref eq))
           (call $make-composed-procedure (local.get $args) (global.get $false)))

     (func $compose1 (type $Prim>=0)
           (param $args (ref eq))
           (result      (ref eq))
           (call $make-composed-procedure (local.get $args) (global.get $true)))

     (func $procedure-extract-target (type $Prim1)
           (param $proc (ref eq)) ; procedure?
           (result      (ref eq))
           ;; Racket extracts a target procedure from a struct procedure
           ;; whose prop:procedure value names a field. WebRacket does
           ;; not yet expose that internal target, so ordinary procedures
           ;; conservatively return #f for now.
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (global.get $false))

     (func $procedure-reduce-arity (type $Prim24)
           (param $proc  (ref eq)) ; procedure?
           (param $arity (ref eq)) ; procedure-arity?
           (param $name  (ref eq)) ; (or/c symbol? #f), default #f
           (param $realm (ref eq)) ; symbol?, default 'racket
           (result (ref eq))

           (local $p          (ref $Procedure))
           (local $new-arity  (ref eq))
           (local $new-mask   i32)
           (local $old-mask   i32)
           (local $new-name   (ref eq))
           (local $new-realm  (ref eq))
           (local $free       (ref $Free))

           (local.set $new-arity (global.get $false))
           (local.set $new-name  (global.get $false))
           (local.set $new-realm (global.get $false))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))
           (local.set $new-arity (call $procedure-arity-value->field
                                       (global.get $symbol:procedure-reduce-arity)
                                       (local.get $arity)))
           (local.set $new-mask (call $procedure-arity-field->mask/i32 (local.get $new-arity)))
           (local.set $old-mask (call $procedure-arity-mask/checked/i32 (local.get $p)))
           (if (i32.ne (i32.and (local.get $new-mask)
                                (i32.xor (local.get $old-mask) (i32.const -1)))
                       (i32.const 0))
               (then
                (call $raise-argument-error1
                      (global.get $symbol:procedure-reduce-arity)
                      (global.get $string:procedure-arity?)
                      (local.get $arity))
                (unreachable)))

           (if (ref.eq (local.get $name) (global.get $missing))
               (then (local.set $name (global.get $false))))
           (if (ref.eq (local.get $name) (global.get $false))
               (then
                (local.set $new-name  (struct.get $Procedure $name (local.get $p)))
                (local.set $new-realm (struct.get $Procedure $realm (local.get $p))))
               (else
                (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
                    (then
                     (call $raise-argument-error1
                           (global.get $symbol:procedure-reduce-arity)
                           (global.get $string:symbol?)
                           (local.get $name))
                     (unreachable)))
                (local.set $new-name (local.get $name))
                (if (ref.eq (local.get $realm) (global.get $missing))
                    (then (local.set $new-realm (global.get $symbol:racket)))
                    (else
                     (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm)))
                         (then
                          (call $raise-argument-error1
                                (global.get $symbol:procedure-reduce-arity)
                                (global.get $string:symbol?)
                                (local.get $realm))
                          (unreachable)))
                     (local.set $new-realm (local.get $realm))))))

           ;; Keep the original procedure as payload. The reduced wrapper
           ;; checks its new arity, then forwards the original user args.
           (local.set $free (array.new_fixed $Free 1 (local.get $p)))
           (struct.new $Closure
                       (i32.const 0)
                       (local.get $new-name)
                       (local.get $new-arity)
                       (local.get $new-realm)
                       (ref.func $invoke-reduced-procedure)
                       (local.get $new-name)
                       (ref.func $dummy-code)
                       (local.get $free)))

     (func $procedure-reduce-arity-mask (type $Prim24)
           (param $proc  (ref eq)) ; procedure?
           (param $mask  (ref eq)) ; exact-integer?
           (param $name  (ref eq)) ; (or/c symbol? #f), default #f
           (param $realm (ref eq)) ; symbol?, default 'racket
           (result (ref eq))

           (local $p          (ref $Procedure))
           (local $new-arity  (ref eq))
           (local $new-mask   i32)
           (local $old-mask   i32)
           (local $new-name   (ref eq))
           (local $new-realm  (ref eq))
           (local $free       (ref $Free))

           (local.set $new-arity (global.get $false))
           (local.set $new-name  (global.get $false))
           (local.set $new-realm (global.get $false))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))
           (local.set $new-arity
                      (call $procedure-arity-mask-value->field
                            (global.get $symbol:procedure-reduce-arity-mask)
                            (local.get $mask)))
           (local.set $new-mask (call $procedure-arity-field->mask/i32 (local.get $new-arity)))
           (local.set $old-mask (call $procedure-arity-mask/checked/i32 (local.get $p)))
           (if (i32.ne (i32.and (local.get $new-mask)
                                (i32.xor (local.get $old-mask) (i32.const -1)))
                       (i32.const 0))
               (then
                (call $raise-argument-error1
                      (global.get $symbol:procedure-reduce-arity-mask)
                      (global.get $string:exact-integer?)
                      (local.get $mask))
                (unreachable)))

           (if (ref.eq (local.get $name) (global.get $missing))
               (then (local.set $name (global.get $false))))
           (if (ref.eq (local.get $name) (global.get $false))
               (then
                (local.set $new-name  (struct.get $Procedure $name (local.get $p)))
                (local.set $new-realm (struct.get $Procedure $realm (local.get $p))))
               (else
                (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
                    (then
                     (call $raise-argument-error1
                           (global.get $symbol:procedure-reduce-arity-mask)
                           (global.get $string:symbol?)
                           (local.get $name))
                     (unreachable)))
                (local.set $new-name (local.get $name))
                (if (ref.eq (local.get $realm) (global.get $missing))
                    (then (local.set $new-realm (global.get $symbol:racket)))
                    (else
                     (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm)))
                         (then
                          (call $raise-argument-error1
                                (global.get $symbol:procedure-reduce-arity-mask)
                                (global.get $string:symbol?)
                                (local.get $realm))
                          (unreachable)))
                     (local.set $new-realm (local.get $realm))))))

           (local.set $free (array.new_fixed $Free 1 (local.get $p)))
           (struct.new $Closure
                       (i32.const 0)
                       (local.get $new-name)
                       (local.get $new-arity)
                       (local.get $new-realm)
                       (ref.func $invoke-reduced-procedure)
                       (local.get $new-name)
                       (ref.func $dummy-code)
                       (local.get $free)))

     (func $procedure-arity (type $Prim1)
           ; Wrapper: accepts any value, checks that it’s a procedure, then delegates
           ; to the checked version that expects (ref $Procedure).
           (param $proc (ref eq))
           (result      (ref eq))
          ;; 1. Check that $proc is a semantic procedure. Structs are
          ;; represented under $Procedure for fast application, but only
          ;; structs with prop:procedure are Racket procedures.
          (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
              (then (call $raise-argument-error:procedure-expected (local.get $proc))
                    (unreachable)))
           ;; 2. Delegate to the checked implementation
           (return_call $procedure-arity/checked
                        (ref.cast (ref $Procedure) (local.get $proc))))

     (func $procedure-arity/checked
           ; Produces normalized arity information: exact integers or arity-at-least structs.
           (param $p (ref $Procedure))
           (result (ref eq))

           (local $a         (ref eq))
           (local $arr       (ref $I32Array))
           (local $n         i32)
           (local $i         i32)
           (local $m         i32)
           (local $list      (ref eq))
           (local $fx        (ref i31))
           (local $elem      (ref eq))
           (local $arity-i32 i32)
           (local $value     i32)
           (local $delegate  (ref eq))

           ;; Initialize non-defaultable locals
           (local.set $elem (global.get $false))
           (local.set $delegate (global.get $false))

           ;; Applicable structs should reflect the arity of their
           ;; field-based prop:procedure delegate, not their wrapper
           ;; struct's internal zero-arity application shell.
           (if (ref.test (ref $Struct) (local.get $p))
               (then
                (local.set $delegate (call $struct-procedure-delegate
                                           (local.get $p)))
                (if (ref.test (ref $Procedure) (local.get $delegate))
                    (then (return_call $procedure-arity/checked
                                       (ref.cast (ref $Procedure)
                                                 (local.get $delegate)))))))

           ;; 1. Extract arity field (either a fixnum (ref i31) or an $I32Array of markers)
           (local.set $a (struct.get $Procedure $arity (local.get $p)))
           ;; 2. If it’s a single-arity fixnum, normalize negatives to arity-at-least
           (if (ref.test (ref i31) (local.get $a))
               (then (local.set $fx       (ref.cast (ref i31) (local.get $a)))
                     (local.set $arity-i32 (i32.shr_s (i31.get_s (local.get $fx)) (i32.const 1)))
                     (if (i32.ge_s (local.get $arity-i32) (i32.const 0))
                         (then (return (local.get $a)))
                         (else (local.set $value (i32.sub (i32.const -1) (local.get $arity-i32)))
                               (return (call $arity-at-least/make (local.get $value)))))))
           ;; 3. Otherwise, cast to $I32Array and build a list of ALL markers (incl. negatives)
           (local.set $arr (ref.cast (ref $I32Array) (local.get $a)))
           (local.set $n   (array.len (local.get $arr)))
           (local.set $list (global.get $null))
           ;;    Iterate right-to-left so that consing preserves original order
           (local.set $i (i32.sub (local.get $n) (i32.const 1)))
           (loop $rev
                 ;; 4. If done, return the accumulated list
                 (if (i32.lt_s (local.get $i) (i32.const 0))
                     (then (return (local.get $list))))
                 ;; 5. Read marker m at index i and normalize it
                 (local.set $m (array.get $I32Array (local.get $arr) (local.get $i)))
                 (if (i32.ge_s (local.get $m) (i32.const 0))
                     (then (local.set $elem (ref.i31 (i32.shl (local.get $m) (i32.const 1)))))
                     (else (local.set $value (i32.sub (i32.const -1) (local.get $m)))
                           (local.set $elem (call $arity-at-least/make (local.get $value)))))
                 (local.set $list (call $cons (local.get $elem) (local.get $list)))
                 ;; 6. Decrement i and continue
                 (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                 (br $rev))
           (unreachable))

     ;; procedure-result-arity : procedure? -> (or/c #f procedure-arity?)
     ;;   Return known result arity. WebRacket currently does not track
     ;;   result arity for closures, so report #f conservatively except
     ;;   for primitive procedures, which store explicit metadata.
     (func $procedure-result-arity (type $Prim1)
           (param $proc (ref eq)) ;; procedure?
           (result      (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (if (ref.test (ref $PrimitiveProcedure) (local.get $proc))
               (then
                (return
                 (struct.get $PrimitiveProcedure $result-arity
                             (ref.cast (ref $PrimitiveProcedure)
                                       (local.get $proc))))))
           (global.get $false))

     (func $procedure-arity-mask (type $Prim1)
           ; TODO: Only tested with closures.
           ;       Also test with primitives and case-lambda
           (param $proc (ref eq))
           (result (ref eq))

           (local $p     (ref null $Procedure))
           (local $mask  i32)

          ;; Step 1: type check and cast. Use semantic procedure-ness so
          ;; plain structs do not expose their internal application fields.
          (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
              (then (call $raise-argument-error:procedure-expected (local.get $proc))
                    (unreachable)))
          (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))
           ;; Step 2: compute mask in checked helper
           (local.set $mask
                      (call $procedure-arity-mask/checked/i32
                            (ref.cast (ref $Procedure) (local.get $p))))
           ;; Step 4: return as fixnum
           (ref.i31 (i32.shl (local.get $mask) (i32.const 1))))

     (func $procedure-arity-mask/checked/i32
           ; TODO: Only tested with closures.
           ;       Also test with primitives and case-lambda
           (param $proc (ref $Procedure))
           (result      i32)

           (local $a     (ref eq))
           (local $arr   (ref $I32Array))
           (local $i     i32)
           (local $n     i32)
           (local $m     i32)
           (local $arity i32)
           (local $mask  i32)
           (local $start i32)
           (local $delegate (ref eq))

           (local.set $delegate (global.get $false))
           (if (ref.test (ref $Struct) (local.get $proc))
               (then
                (local.set $delegate (call $struct-procedure-delegate
                                           (local.get $proc)))
                (if (ref.test (ref $Procedure) (local.get $delegate))
                    (then (return_call $procedure-arity-mask/checked/i32
                                       (ref.cast (ref $Procedure)
                                                 (local.get $delegate)))))))

           ;; Step 1: inspect the procedure arity representation
           (local.set $a (struct.get $Procedure $arity (local.get $proc)))

           ;; Step 2: single arity marker stored as fixnum
           (if (ref.test (ref i31) (local.get $a))
               (then
                (local.set $arity (i32.shr_s
                                   (i31.get_s
                                    (ref.cast (ref i31) (local.get $a)))
                                   (i32.const 1)))
                (local.set $mask
                           (if (result i32)
                               (i32.ge_s (local.get $arity) (i32.const 0))
                               ;; If arity ≥ 0, mask = 1 << arity
                               (then (i32.shl (i32.const 1) (local.get $arity)))
                               ;; If arity < 0, mask = -1 << (-1 - arity)
                               (else (i32.shl (i32.const -1)
                                              (i32.sub (i32.const -1) (local.get $arity))))))
                (return (local.get $mask))))

           ;; Step 3: arity set stored as $I32Array of markers
           (local.set $arr (ref.cast (ref $I32Array) (local.get $a)))
           (local.set $n   (array.len (local.get $arr)))
           (local.set $i   (i32.const 0))
           (local.set $mask (i32.const 0))

           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                        (local.set $m
                                   (array.get $I32Array (local.get $arr) (local.get $i)))
                        (if (i32.ge_s (local.get $m) (i32.const 0))
                            (then
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const 1) (local.get $m)))))
                            (else
                             (local.set $start
                                        (i32.sub (i32.const -1) (local.get $m)))
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const -1) (local.get $start))))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $mask))

     (func $raise-argument-error:fixnum-expected (unreachable))

     (func $procedure-arity-includes?
           (param $proc    (ref eq))
           (param $k       (ref eq))    ;; fixnum
           (param $kws-ok? (ref eq))    ;; fixnum or #f
           (result         (ref eq))    ;; returns #true or #false

           (local $k-fx    (ref i31))
           (local $k-i32   i32)
           (local $mask-fx (ref i31))
           (local $mask    i32)

           ;; Step 1: type check and decode k
           (if (ref.test (ref i31) (local.get $k))
               (then
                (local.set $k-fx (ref.cast (ref i31) (local.get $k)))
                (local.set $k-i32 (i32.shr_u (i31.get_u (local.get $k-fx)) (i32.const 1))))
               (else
                (call $raise-argument-error:fixnum-expected)
                (unreachable)))
           ;; Step 2: call procedure-arity-mask
           (local.set $mask-fx (ref.cast (ref i31)
                                         (call $procedure-arity-mask (local.get $proc))))
           (local.set $mask    (i32.shr_u (i31.get_u (local.get $mask-fx)) (i32.const 1)))
           ;; Step 3: check if bit $k-i32 is set in $mask
           (if (i32.ne (i32.and (local.get $mask)
                                (i32.shl (i32.const 1) (local.get $k-i32)))
                       (i32.const 0))
               (then (return (global.get $true)))
               (else (return (global.get $false))))
           (unreachable))

     (func $procedure-arity-includes?/checked/i32
           (param $proc    (ref $Procedure))
           (param $k-i32   i32)
           ; (param $kws-ok? (ref eq))          ;; we don't use this yet
           (result         i32)

           (local $mask i32)

           ;; Step 1: get the arity mask
           (local.set $mask (call $procedure-arity-mask/checked/i32
                                  (local.get $proc)))
           ;; Step 2: check if bit $k-i32 is set in $mask
           (i32.ne (i32.and (local.get $mask)
                            (i32.shl (i32.const 1) (local.get $k-i32)))
                   (i32.const 0)))

     (func $raise-argument-error:primitive-procedure-expected (unreachable))

     (func $primitive? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $PrimitiveProcedure) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     (func $primitive-result-arity (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))

           (local $p (ref $PrimitiveProcedure))
           ;; Step 1: Validate type
           (if (i32.eqz (ref.test (ref $PrimitiveProcedure) (local.get $v)))
               (then (call $raise-argument-error:primitive-procedure-expected)))
           ;; Step 2: Cast after validation
           (local.set $p (ref.cast (ref $PrimitiveProcedure) (local.get $v)))
           ;; Step 3: Return result-arity field
           (struct.get $PrimitiveProcedure $result-arity (local.get $p)))


     (func $primitive-closure? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $PrimitiveClosure) (local.get $v))
               (then (global.get $true))
               (else (global.get $false)))))))

;; procedure-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate all procedure helpers used by the monolithic runtime.
(define procedure-runtime-only-helpers
  (append procedure-invocation-error-runtime-only-helpers
          procedure-application-error-runtime-only-helpers
          procedure-invoker-runtime-only-helpers
          procedure-basic-runtime-only-helpers
          procedure-arity-and-reflection-runtime-only-helpers))
