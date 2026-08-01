#lang racket

(provide bootstrap-error-runtime-helper-forms
         exception-core-runtime-helpers
         exception-tag-forms
         exception-struct-type-bindings
         exception-struct-type-cache-global-names
         exception-struct-type-cache-global-forms
         exception-struct-type-global-forms
         exception-struct-type-initializer-forms
         exception-read-primitive-global-forms
         exception-read-primitive-global-names
         exception-runtime-string-constants
         exception-runtime-symbol-constants
         exception-fail-runtime-symbol-constants
         exception-break-runtime-symbol-constants
         exception-contract-runtime-helper-forms
         exception-contract-runtime-only-helpers
         exception-runtime-helper-forms
         exception-runtime-only-helpers)

(require "../core-helper.rkt")

;; exception-tag-forms : (listof datum?)
;;   Declare the exception tag used to throw Racket values.
(define exception-tag-forms
  '(
         (tag $exn (param (ref eq)))  ; an exception that that carries an value
         ))

;; exception-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by exception helpers.
(define exception-runtime-string-constants
  '((exn:srclocs?   "exn:srclocs?")
    (listof-srcloc? "(listof srcloc?)")
    (listof-syntax? "(listof syntax?)")
    (catch*-matching-lengths "same number of handlers as predicates")
    (filesystem-errno "(cons/c exact-integer? (or/c 'posix 'windows 'gai))")
    (valid-argument "valid argument")
    (argument-position-prefix "\n  argument position: ")
    (argument-position-st "st")
    (argument-position-nd "nd")
    (argument-position-rd "rd")
    (argument-position-th "th")
    (other-arguments-prefix "\n  other arguments...:")
    (other-argument-line "\n   ")
    (argument-field-prefix "\n  ")
    (argument-field-separator ": ")
    (contract-result-prefix "\n  result: ")
    (raise-arguments-error-missing-value "missing value after field string")
    (raise-arguments-error-string "string")
    (error-prefix "error: ")
    (uncaught-exception "uncaught exception: ")))

;; exception-runtime-symbol-constants : (listof symbol?)
;;   Declare base and syntax-exception symbols referenced directly by runtime helpers.
(define exception-runtime-symbol-constants
  '(exn
    exn?
    exn-message
    exn-continuation-marks
    catch
    catch*
    call-with-exception-handler
    exn:fail
    exn:fail?
    make-exn
    make-exn:fail
    exn:fail:contract
    exn:fail:contract?
    make-exn:fail:contract
    exn:fail:contract:arity
    exn:fail:contract:arity?
    make-exn:fail:contract:arity
    exn:fail:contract:divide-by-zero
    exn:fail:contract:divide-by-zero?
    make-exn:fail:contract:divide-by-zero
    exn:fail:contract:non-fixnum-result
    exn:fail:contract:non-fixnum-result?
    make-exn:fail:contract:non-fixnum-result
    exn:fail:contract:variable
    exn:fail:contract:variable?
    make-exn:fail:contract:variable
    exn:fail:contract:variable-id
    exn:fail:read
    exn:fail:read?
    make-exn:fail:read
    exn:fail:read-srclocs
    exn:fail:read:eof
    exn:fail:read:eof?
    make-exn:fail:read:eof
    exn:fail:read:non-char
    exn:fail:read:non-char?
    make-exn:fail:read:non-char
    exn:fail:filesystem
    exn:fail:filesystem?
    make-exn:fail:filesystem
    exn:fail:syntax
    exn:fail:syntax?
    make-exn:fail:syntax
    exn:fail:syntax-exprs
    exn:fail:syntax:missing-module
    exn:fail:syntax:missing-module?
    make-exn:fail:syntax:missing-module
    exn:fail:syntax:missing-module-path
    exn:fail:syntax:unbound
    exn:fail:syntax:unbound?
    make-exn:fail:syntax:unbound
    raise-argument-error
    raise-argument-error*
    raise-arguments-error))

;; exception-fail-runtime-symbol-constants : (listof symbol?)
;;   Declare fail-exception symbols referenced directly by runtime helpers.
(define exception-fail-runtime-symbol-constants
  '(exn:fail:contract:continuation
    exn:fail:contract:continuation?
    make-exn:fail:contract:continuation
    exn:fail:filesystem:exists
    exn:fail:filesystem:exists?
    make-exn:fail:filesystem:exists
    exn:fail:filesystem:version
    exn:fail:filesystem:version?
    make-exn:fail:filesystem:version
    exn:fail:filesystem:errno
    exn:fail:filesystem:errno?
    make-exn:fail:filesystem:errno
    exn:fail:filesystem:errno-errno
    exn:fail:filesystem:missing-module
    exn:fail:filesystem:missing-module?
    make-exn:fail:filesystem:missing-module
    exn:fail:filesystem:missing-module-path
    exn:fail:network
    exn:fail:network?
    make-exn:fail:network
    exn:fail:network:errno
    exn:fail:network:errno?
    make-exn:fail:network:errno
    exn:fail:network:errno-errno
    exn:fail:out-of-memory
    exn:fail:out-of-memory?
    make-exn:fail:out-of-memory
    exn:fail:unsupported
    exn:fail:unsupported?
    make-exn:fail:unsupported
    exn:fail:user
    exn:fail:user?
    make-exn:fail:user))

;; exception-break-runtime-symbol-constants : (listof symbol?)
;;   Declare break-exception and exn:srclocs symbols referenced by runtime helpers.
(define exception-break-runtime-symbol-constants
  '(exn:break
    exn:break?
    make-exn:break
    exn:break-continuation
    exn:break:hang-up
    exn:break:hang-up?
    make-exn:break:hang-up
    exn:break:terminate
    exn:break:terminate?
    make-exn:break:terminate
    exn:srclocs?
    exn:srclocs-accessor))

;; exception-struct-type-bindings : (listof (list symbol? symbol?))
;;   Map exported exception structure type names to their ensure helpers.
(define exception-struct-type-bindings
  '((struct:exn                                 ensure-exn-type)
    (struct:exn:break                           ensure-exn:break-type)
    (struct:exn:break:hang-up                   ensure-exn:break:hang-up-type)
    (struct:exn:break:terminate                 ensure-exn:break:terminate-type)
    (struct:exn:fail                            ensure-exn:fail-type)
    (struct:exn:fail:contract                   ensure-exn:fail:contract-type)
    (struct:exn:fail:contract:arity             ensure-exn:fail:contract:arity-type)
    (struct:exn:fail:contract:continuation      ensure-exn:fail:contract:continuation-type)
    (struct:exn:fail:contract:divide-by-zero    ensure-exn:fail:contract:divide-by-zero-type)
    (struct:exn:fail:contract:non-fixnum-result ensure-exn:fail:contract:non-fixnum-result-type)
    (struct:exn:fail:contract:variable          ensure-exn:fail:contract:variable-type)
    (struct:exn:fail:read                       ensure-exn:fail:read-type)
    (struct:exn:fail:read:eof                   ensure-exn:fail:read:eof-type)
    (struct:exn:fail:read:non-char              ensure-exn:fail:read:non-char-type)
    (struct:exn:fail:filesystem                 ensure-exn:fail:filesystem-type)
    (struct:exn:fail:filesystem:exists          ensure-exn:fail:filesystem:exists-type)
    (struct:exn:fail:filesystem:version         ensure-exn:fail:filesystem:version-type)
    (struct:exn:fail:filesystem:errno           ensure-exn:fail:filesystem:errno-type)
    (struct:exn:fail:network                    ensure-exn:fail:network-type)
    (struct:exn:fail:network:errno              ensure-exn:fail:network:errno-type)
    (struct:exn:fail:out-of-memory              ensure-exn:fail:out-of-memory-type)
    (struct:exn:fail:unsupported                ensure-exn:fail:unsupported-type)
    (struct:exn:fail:user                       ensure-exn:fail:user-type)
    (struct:exn:fail:syntax                     ensure-exn:fail:syntax-type)
    (struct:exn:fail:syntax:missing-module      ensure-exn:fail:syntax:missing-module-type)
    (struct:exn:fail:syntax:unbound             ensure-exn:fail:syntax:unbound-type)))

;; exception-struct-type->global-name : symbol? -> symbol?
;;   Convert a Racket exception struct type name to its Wasm global name.
(define (exception-struct-type->global-name name)
  (string->symbol (~a "$" (symbol->string name))))

;; exception-struct-type->ensure-name : symbol? -> symbol?
;;   Convert an exception ensure helper name to its Wasm function name.
(define (exception-struct-type->ensure-name name)
  (string->symbol (~a "$" (symbol->string name))))

;; exception-struct-type-cache-global-forms : (listof datum?)
;;   Declare cached kernel exception struct type descriptors.
(define exception-struct-type-cache-global-forms
  '(
         ;; Cached kernel exception struct type descriptors
         (global $exn-type                              (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:break-type                        (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:break:hang-up-type                (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:break:terminate-type              (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail-type                         (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:contract-type                (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:arity-type          (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:continuation-type   (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:divide-by-zero-type (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:non-fixnum-result-type (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:contract:variable-type       (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:read-type                    (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:read:eof-type                (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:read:non-char-type           (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:filesystem-type              (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:exists-type       (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:version-type      (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:errno-type        (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:filesystem:missing-module-type (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:network-type                 (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:network:errno-type           (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:out-of-memory-type           (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:unsupported-type             (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:user-type                    (mut (ref null $StructType)) (ref.null $StructType))

         (global $exn:fail:syntax-type                  (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:syntax:missing-module-type   (mut (ref null $StructType)) (ref.null $StructType))
         (global $exn:fail:syntax:unbound-type          (mut (ref null $StructType)) (ref.null $StructType))))

;; exception-struct-type-cache-global-names : (listof symbol?)
;;   Enumerate cached kernel exception struct type descriptor globals.
(define exception-struct-type-cache-global-names
  (for/list ([form (in-list exception-struct-type-cache-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'exception-struct-type-cache-global-names
                "expected global form, got: ~s"
                form)])))

;; exception-struct-type-global-forms : (listof datum?)
;;   Declare exported exception struct type descriptor value globals.
(define exception-struct-type-global-forms
  (for/list ([binding (in-list exception-struct-type-bindings)])
    (define name  (car binding))
    (define $name (exception-struct-type->global-name name))
    `(global ,$name (mut (ref eq)) (global.get $undefined))))

;; exception-struct-type-initializer-forms : (listof datum?)
;;   Populate exported exception struct type descriptor value globals.
(define exception-struct-type-initializer-forms
  (for/list ([binding (in-list exception-struct-type-bindings)])
    (define name    (car binding))
    (define ensure  (cadr binding))
    (define $name   (exception-struct-type->global-name name))
    (define $ensure (exception-struct-type->ensure-name ensure))
    `(global.set ,$name (call ,$ensure))))

;; exception-read-primitive-global-forms : (listof datum?)
;;   Declare primitive procedure globals needed by core read-exception metadata.
(define exception-read-primitive-global-forms
  '((global $prim:exn:fail:read-srclocs (mut (ref eq)) (global.get $undefined))))

;; exception-read-primitive-global-names : (listof symbol?)
;;   Enumerate primitive procedure globals needed by core read-exception metadata.
(define exception-read-primitive-global-names
  '($prim:exn:fail:read-srclocs))

;; bootstrap-error-runtime-only-forms : (listof datum?)
;;   Enumerate early error helpers used before the main exception section.
(define bootstrap-error-runtime-only-forms
  '(
         (func $raise-unexpected-argument
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:unsafe-ffi-primitive)
                     (global.get $string:unsafe-ffi-primitive:expected)
                     (local.get $bad))
               (unreachable))

         ;; Convert a host exception caught at an FFI boundary into a
         ;; regular WebRacket exn:fail so `with-handlers` can catch it.
         (func $raise-ffi-host-exception
               (param $host externref)
               (local $message (ref eq))

               (local.set $message
                          (call $linear-memory->string
                                (call $js-external-string->string
                                      (local.get $host))))
               (drop (call $raise
                           (call $make-exn:fail
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-input-port-closed : string? -> none
         ;;   Raise an exn:fail for an operation on a closed input port.
         (func $raise-input-port-closed
               (param $message (ref eq))

               (drop (call $raise
                           (call $make-exn:fail
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-output-port-closed : string? -> none
         ;;   Raise an exn:fail for an operation on a closed output port.
         (func $raise-output-port-closed
               (param $message (ref eq))

               (drop (call $raise
                           (call $make-exn:fail
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-vfs-file-error : string? -> none
         ;;   Raise a catchable exn:fail:filesystem for VFS filesystem errors.
         (func $raise-vfs-file-error
               (param $message (ref eq))

               (drop (call $raise
                           (call $make-exn:fail:filesystem
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         (func $raise-argument-error1
               (param $who      (ref eq))      ;; symbol
               (param $expected (ref eq))      ;; expected description
               (param $got      (ref eq))      ;; received value

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:contract-violation:prefix))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String) (local.get $expected)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:arity-error:given))
               (call $growable-array-add! (local.get $out)
                     (call $format/print
                           (local.get $got)
                           (global.get $missing)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))

               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))))

;; exception-runtime-only-forms : (listof datum?)
;;   Enumerate exception, exception-structure, and reader-error helpers.
(define exception-runtime-only-forms
  '(
         ; Note:
         ;  The WebRacket version of `raise` ignores the `barrier?` argument.
         (func $raise (type $Prim12)
               (param $v        (ref eq)) ; any/c
               (param $barrier? (ref eq)) ; any/c, optional with default #t
               (result          (ref eq))

               ; Handle optional barrier? with default $t
               #;(if (ref.eq (local.get $barrier?) (global.get $missing))
                   (then (local.set $barrier? (global.get $true))))

               #;(call $js-log (global.get $string:uncaught-exception))
               #;(call $js-log (local.get  $v))
               (throw $exn (local.get $v)))

         (func $call-with-exception-handler:procedure-expected-as-handler
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:call-with-exception-handler)
                     (local.get $v)))
         (func $call-with-exception-handler:procedure-expected-as-thunk
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:call-with-exception-handler)
                     (local.get $v)))

         (func $call-with-exception-handler (type $Prim2)
               (param $handler (ref eq)) ;; procedure?
               (param $thunk   (ref eq)) ;; (-> any)
               (result         (ref eq))

               (local $handler-proc   (ref $Procedure))
               (local $handler-inv    (ref $ProcedureInvoker))
               (local $handler-args   (ref $Args))
               (local $thunk-proc     (ref $Procedure))
               (local $thunk-inv      (ref $ProcedureInvoker))
               (local $thunk-args     (ref $Args))
               (local $exn-val        (ref eq))
               (local $handler-result (ref eq))

               ;; Validate handler argument.
               (if (ref.eq (call $procedure? (local.get $handler))
                           (global.get $false))
                   (then (call $call-with-exception-handler:procedure-expected-as-handler
                               (local.get $handler))
                         (unreachable)))

               ;; Validate thunk argument.
               (if (ref.eq (call $procedure? (local.get $thunk))
                           (global.get $false))
                   (then (call $call-with-exception-handler:procedure-expected-as-thunk
                               (local.get $thunk))
                         (unreachable)))

               (local.set $handler-proc
                          (ref.cast (ref $Procedure) (local.get $handler)))
               (local.set $handler-inv
                          (struct.get $Procedure $invoke (local.get $handler-proc)))
               (local.set $thunk-proc
                          (ref.cast (ref $Procedure) (local.get $thunk)))
               (local.set $thunk-inv
                          (struct.get $Procedure $invoke (local.get $thunk-proc)))

               (local.set $handler-args (array.new $Args (global.get $null) (i32.const 1)))
               (local.set $thunk-args   (array.new $Args (global.get $null) (i32.const 0)))

               (block $done (result (ref eq))
                      (block $handler-block (result (ref eq))
                             (try_table (result (ref eq))
                                        (catch $exn $handler-block)

                                        (call_ref $ProcedureInvoker
                                                  (local.get $thunk-proc)
                                                  (local.get $thunk-args)
                                                  (local.get $thunk-inv))
                                        (br $done)))
                      (local.set $exn-val)
                      (array.set $Args (local.get $handler-args) (i32.const 0)
                                 (local.get $exn-val))
                      ;; WebRacket currently ignores breaks, so this handler runs without break parameterization.
                      (local.set $handler-result
                                 (call_ref $ProcedureInvoker
                                           (local.get $handler-proc)
                                           (local.get $handler-args)
                                           (local.get $handler-inv)))
                      ;; Returning from the handler propagates the exception to enclosing handlers.
                      (throw $exn (local.get $handler-result))
                      (unreachable)))


         (func $catch:procedure-expected-for-predicate
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:catch)
                     (local.get $v)))
         (func $catch:procedure-expected-for-handler
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:catch)
                     (local.get $v)))
         (func $catch:procedure-expected-for-thunk
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:catch)
                     (local.get $v)))

         (func $catch (type $Prim3)
               (param $pred    (ref eq))
               (param $handler (ref eq))
               (param $thunk   (ref eq))
               (result         (ref eq))

               (local $pred-proc    (ref $Procedure))
               (local $handler-proc (ref $Procedure))
               (local $thunk-proc   (ref $Procedure))
               (local $pred-inv     (ref $ProcedureInvoker))
               (local $handler-inv  (ref $ProcedureInvoker))
               (local $thunk-inv    (ref $ProcedureInvoker))
               (local $pred-args    (ref $Args))
               (local $handler-args (ref $Args))
               (local $thunk-args   (ref $Args))
               (local $pred-result  (ref eq))
               (local $exn-val      (ref eq))

               ;; Validate the predicate, handler, and thunk arguments.
               (if (ref.eq (call $procedure? (local.get $pred))
                           (global.get $false))
                   (then (call $catch:procedure-expected-for-predicate
                               (local.get $pred))
                         (unreachable)))
               (if (ref.eq (call $procedure? (local.get $handler))
                           (global.get $false))
                   (then (call $catch:procedure-expected-for-handler
                               (local.get $handler))
                         (unreachable)))
               (if (ref.eq (call $procedure? (local.get $thunk))
                           (global.get $false))
                   (then (call $catch:procedure-expected-for-thunk
                               (local.get $thunk))
                         (unreachable)))

               ;; Extract procedures and their invokers.
               (local.set $pred-proc
                          (ref.cast (ref $Procedure) (local.get $pred)))
               (local.set $pred-inv
                       (struct.get $Procedure $invoke (local.get $pred-proc)))
               (local.set $handler-proc
                          (ref.cast (ref $Procedure) (local.get $handler)))
               (local.set $handler-inv
                       (struct.get $Procedure $invoke (local.get $handler-proc)))
               (local.set $thunk-proc
                          (ref.cast (ref $Procedure) (local.get $thunk)))
               (local.set $thunk-inv
                        (struct.get $Procedure $invoke (local.get $thunk-proc)))

               ;; Preallocate argument arrays.
               (local.set $pred-args    (array.new $Args (global.get $null) (i32.const 1)))
               (local.set $handler-args (array.new $Args (global.get $null) (i32.const 1)))
               (local.set $thunk-args   (array.new $Args (global.get $null) (i32.const 0)))

               (block $done (result (ref eq))
                      (block $handler-block (result (ref eq))
                             (try_table (result (ref eq))
                                        (catch $exn $handler-block)

                                        (call_ref $ProcedureInvoker
                                                  (local.get $thunk-proc)
                                                  (local.get $thunk-args)
                                                  (local.get $thunk-inv))
                                        (br $done)))
                      ; handler block
                      (local.set $exn-val) ; gets value from stack
                      (array.set $Args (local.get $pred-args) (i32.const 0)
                                 (local.get $exn-val))
                      (local.set $pred-result
                                 (call_ref $ProcedureInvoker
                                           (local.get $pred-proc)
                                           (local.get $pred-args)
                                           (local.get $pred-inv)))
                      (if (ref.eq (local.get $pred-result) (global.get $false))
                          (then (throw $exn (local.get $exn-val))))
                      (array.set $Args (local.get $handler-args) (i32.const 0)
                                 (local.get $exn-val))
                      (br $done
                          (return_call_ref $ProcedureInvoker
                                           (local.get $handler-proc)
                                           (local.get $handler-args)
                                           (local.get $handler-inv))))
               ; done block
               ;   - fall through to return the value
               )

         (func $catch*:procedure-expected-for-predicate
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:catch*)
                     (local.get $v)))
         (func $catch*:procedure-expected-for-handler
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:catch*)
                     (local.get $v)))
         (func $catch*:procedure-expected-for-thunk
               (param $v (ref eq))
               (call $raise-argument-error:procedure-expected/who
                     (global.get $symbol:catch*)
                     (local.get $v)))

         (func $catch* (type $Prim3)
               (param $preds    (ref eq))
               (param $handlers (ref eq))
               (param $thunk    (ref eq))
               (result          (ref eq))

               (local $thunk-proc   (ref $Procedure))
               (local $thunk-inv    (ref $ProcedureInvoker))
               (local $thunk-args   (ref $Args))
               (local $pred-args    (ref $Args))
               (local $handler-args (ref $Args))
               (local $pred-node    (ref eq))
               (local $handler-node (ref eq))
               (local $pred-pair    (ref $Pair))
               (local $handler-pair (ref $Pair))
               (local $pred-val     (ref eq))
               (local $handler-val  (ref eq))
               (local $pred-tail    (ref eq))
               (local $handler-tail (ref eq))
               (local $pred-proc    (ref $Procedure))
               (local $handler-proc (ref $Procedure))
               (local $pred-inv     (ref $ProcedureInvoker))
               (local $handler-inv  (ref $ProcedureInvoker))
               (local $pred-result  (ref eq))
               (local $exn-val      (ref eq))

               ;; Validate thunk argument.
               (if (ref.eq (call $procedure? (local.get $thunk))
                           (global.get $false))
                   (then (call $catch*:procedure-expected-for-thunk (local.get $thunk))
                         (unreachable)))

               ;; Validate predicate and handler lists.
               (local.set $pred-node    (local.get $preds))
               (local.set $handler-node (local.get $handlers))
               (block $validated
                      (loop $validate
                            (if (ref.eq (local.get $pred-node) (global.get $null))
                                (then (if (ref.eq (local.get $handler-node) (global.get $null))
                                          (then (br $validated)))
                                      (if (i32.eqz (ref.test (ref $Pair) (local.get $handler-node)))
                                          (then (call $raise-list-expected/who
                                                      (global.get $symbol:catch*)
                                                      (local.get $handler-node))
                                                (unreachable)))
                                      (call $raise-argument-error1
                                            (global.get $symbol:catch*)
                                            (global.get $string:catch*-matching-lengths)
                                            (local.get $handlers))
                                      (unreachable)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $pred-node)))
                                (then (call $raise-list-expected/who
                                            (global.get $symbol:catch*)
                                            (local.get $pred-node))
                                      (unreachable)))
                            (if (ref.eq (local.get $handler-node) (global.get $null))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:catch*)
                                            (global.get $string:catch*-matching-lengths)
                                            (local.get $handlers))
                                      (unreachable)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $handler-node)))
                                (then (call $raise-list-expected/who
                                            (global.get $symbol:catch*)
                                            (local.get $handler-node))
                                      (unreachable)))
                            (local.set $pred-pair (ref.cast (ref $Pair) (local.get $pred-node)))
                            (local.set $handler-pair (ref.cast (ref $Pair) (local.get $handler-node)))
                            (local.set $pred-val (struct.get $Pair $a (local.get $pred-pair)))
                            (local.set $handler-val (struct.get $Pair $a (local.get $handler-pair)))

                            (if (ref.eq (call $procedure? (local.get $pred-val))
                                        (global.get $false))
                                (then (call $catch*:procedure-expected-for-predicate (local.get $pred-val))
                                      (unreachable)))
                            (if (ref.eq (call $procedure? (local.get $handler-val))
                                        (global.get $false))
                                (then (call $catch*:procedure-expected-for-handler (local.get $handler-val))
                                      (unreachable)))
                            (local.set $pred-node (struct.get $Pair $d (local.get $pred-pair)))
                            (local.set $handler-node (struct.get $Pair $d (local.get $handler-pair)))
                            (br $validate)))

               ;; Prepare invokers and argument arrays.
               (local.set $thunk-proc   (ref.cast (ref $Procedure) (local.get $thunk)))
               (local.set $thunk-inv    (struct.get $Procedure $invoke (local.get $thunk-proc)))
               (local.set $thunk-args   (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $pred-args    (array.new $Args (global.get $null) (i32.const 1)))
               (local.set $handler-args (array.new $Args (global.get $null) (i32.const 1)))

               (block $done (result (ref eq))
                      (block $handler (result (ref eq))
                             (try_table (result (ref eq))
                                        (catch $exn $handler)

                                        (call_ref $ProcedureInvoker
                                                  (local.get $thunk-proc)
                                                  (local.get $thunk-args)
                                                  (local.get $thunk-inv))
                                        (br $done)))
                      ;; handler block
                      ;;   - find predicate and handler to use
                      (local.set $exn-val)     ; uses value on stack
                      (local.set $pred-node    (local.get $preds))
                      (local.set $handler-node (local.get $handlers))

                      (loop $search
                            ; rethrow if no predicates return true
                            (if (ref.eq (local.get $pred-node) (global.get $null))
                                (then (throw $exn (local.get $exn-val))))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $pred-node)))
                                (then (call $raise-list-expected/who
                                            (global.get $symbol:catch*)
                                            (local.get $pred-node))
                                      (unreachable)))
                            (if (ref.eq (local.get $handler-node) (global.get $null))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:catch*)
                                            (global.get $string:catch*-matching-lengths)
                                            (local.get $handlers))
                                      (unreachable)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $handler-node)))
                                (then (call $raise-list-expected/who
                                            (global.get $symbol:catch*)
                                            (local.get $handler-node))
                                      (unreachable)))

                            (local.set $pred-pair    (ref.cast (ref $Pair) (local.get $pred-node)))
                            (local.set $handler-pair (ref.cast (ref $Pair) (local.get $handler-node)))
                            (local.set $pred-val     (struct.get $Pair $a  (local.get $pred-pair)))
                            (local.set $handler-val  (struct.get $Pair $a  (local.get $handler-pair)))
                            (local.set $pred-tail    (struct.get $Pair $d  (local.get $pred-pair)))
                            (local.set $handler-tail (struct.get $Pair $d  (local.get $handler-pair)))

                            (if (ref.eq (call $procedure? (local.get $pred-val))
                                        (global.get $false))
                                (then (call $catch*:procedure-expected-for-predicate (local.get $pred-val))
                                      (unreachable)))
                            (if (ref.eq (call $procedure? (local.get $handler-val))
                                        (global.get $false))
                                (then (call $catch*:procedure-expected-for-handler (local.get $handler-val))
                                      (unreachable)))

                            (local.set $pred-proc (ref.cast (ref $Procedure) (local.get $pred-val)))
                            (local.set $pred-inv  (struct.get $Procedure $invoke (local.get $pred-proc)))
                            (array.set $Args (local.get $pred-args) (i32.const 0) (local.get $exn-val))
                            (local.set $pred-result
                                       (call_ref $ProcedureInvoker
                                                 (local.get $pred-proc)
                                                 (local.get $pred-args)
                                                 (local.get $pred-inv)))

                            (if (ref.eq (local.get $pred-result) (global.get $false))
                                (then (local.set $pred-node    (local.get $pred-tail))
                                      (local.set $handler-node (local.get $handler-tail))
                                      (br $search))
                                (else
                                 (local.set $pred-node    (local.get $pred-tail))
                                 (local.set $handler-node (local.get $handler-tail))
                                 (local.set $handler-proc (ref.cast (ref $Procedure) (local.get $handler-val)))
                                 (local.set $handler-inv  (struct.get $Procedure $invoke (local.get $handler-proc)))
                                 (array.set $Args (local.get $handler-args) (i32.const 0) (local.get $exn-val))
                                 (return_call_ref $ProcedureInvoker
                                                  (local.get $handler-proc)
                                                  (local.get $handler-args)
                                                  (local.get $handler-inv)))))
                      (unreachable)))

         ;;;
         ;;; Exception Structires
         ;;;

         ;; kernel-exn-struct-type : symbol? (or/c struct-type? #f) i32 list? list? symbol? -> struct-type?
         ;;   Construct trusted kernel exception struct type descriptors without public validation.
         (func $kernel-exn-struct-type
               (param $name             (ref $Symbol))
               (param $super            (ref eq))
               (param $field-count      i32)
               (param $init-indices     (ref eq))
               (param $immutables       (ref eq))
               (param $constructor-name (ref $Symbol))
               (result                  (ref $StructType))

               (struct.new $StructType
                           (i32.const 0)
                           (local.get $name)
                           (local.get $super)
                           (local.get $field-count)
                           (local.get $init-indices)
                           (global.get $null)
                           (global.get $null)
                           (ref.cast (ref eq) (call $struct-type-property-table-empty))
                           (global.get $false)
                           (local.get $immutables)
                           (global.get $false)
                           (local.get $constructor-name)))

         ;; invoke-kernel-exn-struct : procedure? args-array? -> none
         ;;   Raise a catchable exception if a core-created exception struct is applied.
         (func $invoke-kernel-exn-struct (type $ProcedureInvoker)
               (param $proc (ref $Procedure))
               (param $args (ref $Args))
               (result      (ref eq))

               (call $raise
                     (call $exn:fail:contract/make
                           (global.get $string:application:not-procedure)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         ;; Exception base struct type descriptor cache
         (func $ensure-exn-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $indices  (ref eq))

               (local.set $existing (global.get $exn-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $indices
                               (call $cons
                                     (ref.i31 (i32.const 0))
                                     (call $cons
                                           (ref.i31 (i32.const 2))
                                           (global.get $null))))
                    (local.set $std
                               (call $kernel-exn-struct-type
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn))
                                     (global.get $false)
                                     (i32.const 2)
                                     (local.get $indices)
                                     (local.get $indices)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn))))
                    (global.set $exn-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception break struct type descriptor cache
         (func $ensure-exn:break-type
               (result (ref $StructType))

               (local $existing     (ref null $StructType))
               (local $std          (ref $StructType))
               (local $super        (ref $StructType))
               (local $immut        (ref eq))
               (local $super-count  i32)
               (local $new-immut    (ref eq))

               (local.set $existing (global.get $exn:break-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:break))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:break))))
                    (global.set $exn:break-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception break:hang-up struct type descriptor cache
         (func $ensure-exn:break:hang-up-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:break:hang-up-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:break-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:break:hang-up))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:break:hang-up))))
                    (global.set $exn:break:hang-up-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception break:terminate struct type descriptor cache
         (func $ensure-exn:break:terminate-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:break:terminate-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:break-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:break:terminate))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:break:terminate))))
                    (global.set $exn:break:terminate-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail struct type descriptor cache
         (func $ensure-exn:fail-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $kernel-exn-struct-type
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail))
                                     (ref.cast (ref eq) (local.get $super))
                                     (struct.get $StructType $field-count (local.get $super))
                                     (struct.get $StructType $init-indices (local.get $super))
                                     (local.get $immut)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail))))
                    (global.set $exn:fail-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Ensure message argument is a string
         (func $exn-ensure-message
               (param $who      (ref eq)) ; symbol
               (param $message  (ref eq)) ; any/c
               (result (ref eq))

               (if (i32.eqz (ref.test (ref $String) (local.get $message)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:string?)
                               (local.get $message))
                         (unreachable)))
               (local.get $message))

         ;; Validate that a value is a kernel exception
         (func $exn-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result     (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Validate that a value is a kernel break exception
         (func $exn:break-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result     (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:break-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Construct a kernel exception instance
         (func $exn/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)     ; <-- a name symbol !?
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:break instance
         (func $exn:break/make
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:break-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $continuation)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:break:hang-up instance
         (func $exn:break:hang-up/make
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:break:hang-up-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $continuation)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:break:terminate instance
         (func $exn:break:terminate/make
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:break:terminate-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $continuation)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail instance
         (func $exn:fail/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn : string? continuation-mark-set? -> exn
         (func $exn (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn/make
                               (call $exn-ensure-message (global.get $symbol:exn) (local.get $message))
                               (local.get $marks))))

         ;; make-exn : string? continuation-mark-set? -> exn
         (func $make-exn (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn/make
                               (call $exn-ensure-message (global.get $symbol:make-exn) (local.get $message))
                               (local.get $marks))))

         ;; exn? : any/c -> boolean?
         (func $exn? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn-message : exn -> string?
         (func $exn-message (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct (call $exn-ensure (global.get $symbol:exn-message) (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 0)))

         ;; exn-continuation-marks : exn -> continuation-mark-set?
         (func $exn-continuation-marks (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct (call $exn-ensure
                                            (global.get $symbol:exn-continuation-marks)
                                            (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 1)))

         ;; ---

         ;; exn:break : string? continuation-mark-set? continuation? -> exn:break
         ;;   WebRacket stores the continuation field without enforcing full
         ;;   continuation semantics; break delivery itself is still separate.
         (func $exn:break (type $Prim3)
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:break/make
                               (call $exn-ensure-message (global.get $symbol:exn:break) (local.get $message))
                               (local.get $marks)
                               (local.get $continuation))))

         ;; make-exn:break : string? continuation-mark-set? continuation? -> exn:break
         (func $make-exn:break (type $Prim3)
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:break/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:break) (local.get $message))
                               (local.get $marks)
                               (local.get $continuation))))

         ;; exn:break? : any/c -> boolean?
         (func $exn:break? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:break-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:break-continuation : exn:break -> continuation?
         (func $exn:break-continuation (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:break-ensure
                                (global.get $symbol:exn:break-continuation)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         ;; exn:break:hang-up : string? continuation-mark-set? continuation? -> exn:break:hang-up
         (func $exn:break:hang-up (type $Prim3)
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:break:hang-up/make
                               (call $exn-ensure-message (global.get $symbol:exn:break:hang-up) (local.get $message))
                               (local.get $marks)
                               (local.get $continuation))))

         ;; make-exn:break:hang-up : string? continuation-mark-set? continuation? -> exn:break:hang-up
         (func $make-exn:break:hang-up (type $Prim3)
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:break:hang-up/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:break:hang-up) (local.get $message))
                               (local.get $marks)
                               (local.get $continuation))))

         ;; exn:break:hang-up? : any/c -> boolean?
         (func $exn:break:hang-up? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:break:hang-up-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:break:terminate : string? continuation-mark-set? continuation? -> exn:break:terminate
         (func $exn:break:terminate (type $Prim3)
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:break:terminate/make
                               (call $exn-ensure-message (global.get $symbol:exn:break:terminate) (local.get $message))
                               (local.get $marks)
                               (local.get $continuation))))

         ;; make-exn:break:terminate : string? continuation-mark-set? continuation? -> exn:break:terminate
         (func $make-exn:break:terminate (type $Prim3)
               (param $message      (ref eq)) ; string
               (param $marks        (ref eq)) ; continuation-mark-set?
               (param $continuation (ref eq)) ; continuation?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:break:terminate/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:break:terminate) (local.get $message))
                               (local.get $marks)
                               (local.get $continuation))))

         ;; exn:break:terminate? : any/c -> boolean?
         (func $exn:break:terminate? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:break:terminate-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; ---

         ;; exn:fail : string? continuation-mark-set? -> exn:fail
         (func $exn:fail (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail : string? continuation-mark-set? -> exn:fail
         (func $make-exn:fail (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail? : any/c -> boolean?
         (func $exn:fail? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ; Kernel exception fail:contract struct type descriptor cache
         (func $ensure-exn:fail:contract-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:contract-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $kernel-exn-struct-type
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract))
                                     (ref.cast (ref eq) (local.get $super))
                                     (struct.get $StructType $field-count (local.get $super))
                                     (struct.get $StructType $init-indices (local.get $super))
                                     (local.get $immut)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract))))
                    (global.set $exn:fail:contract-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:contract:arity struct type descriptor cache
         (func $ensure-exn:fail:contract:arity-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:contract:arity-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:contract-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $kernel-exn-struct-type
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:arity))
                                     (ref.cast (ref eq) (local.get $super))
                                     (struct.get $StructType $field-count (local.get $super))
                                     (struct.get $StructType $init-indices (local.get $super))
                                     (local.get $immut)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:arity))))
                    (global.set $exn:fail:contract:arity-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:contract:continuation struct type descriptor cache
         (func $ensure-exn:fail:contract:continuation-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:contract:continuation-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:contract-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:continuation))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:continuation))))
                    (global.set $exn:fail:contract:continuation-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:contract:divide-by-zero struct type descriptor cache
         (func $ensure-exn:fail:contract:divide-by-zero-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:contract:divide-by-zero-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:contract-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:divide-by-zero))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:divide-by-zero))))
                    (global.set $exn:fail:contract:divide-by-zero-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:contract:non-fixnum-result struct type descriptor cache
         (func $ensure-exn:fail:contract:non-fixnum-result-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:contract:non-fixnum-result-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:contract-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:non-fixnum-result))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:non-fixnum-result))))
                    (global.set $exn:fail:contract:non-fixnum-result-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:contract:variable struct type descriptor cache
         (func $ensure-exn:fail:contract:variable-type
               (result (ref $StructType))

               (local $existing     (ref null $StructType))
               (local $std          (ref $StructType))
               (local $super        (ref $StructType))
               (local $immut        (ref eq))
               (local $super-count  i32)
               (local $new-immut    (ref eq))

               (local.set $existing (global.get $exn:fail:contract:variable-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:contract-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:variable))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:contract:variable))))
                    (global.set $exn:fail:contract:variable-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Validate that a value is a kernel exception:fail:contract
         (func $exn:fail:contract-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Validate that a value is a kernel exception:fail:contract:variable
         (func $exn:fail:contract:variable-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract:variable-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Validate that the id argument is a symbol
         (func $exn:fail:contract:variable-ensure-id
               (param $who (ref eq)) ; symbol
               (param $id  (ref eq)) ; any/c
               (result (ref eq))

               (if (i32.eqz (ref.test (ref $Symbol) (local.get $id)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:symbol?)
                               (local.get $id))
                         (unreachable)))
               (local.get $id))

         ;; Construct a kernel exception:fail:contract instance
         (func $exn:fail:contract/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:contract-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-kernel-exn-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:contract:arity instance
         (func $exn:fail:contract:arity/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:contract:arity-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-kernel-exn-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:contract:continuation instance
         (func $exn:fail:contract:continuation/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:contract:continuation-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:contract:divide-by-zero instance
         (func $exn:fail:contract:divide-by-zero/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:contract:divide-by-zero-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:contract:non-fixnum-result instance
         (func $exn:fail:contract:non-fixnum-result/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:contract:non-fixnum-result-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:contract:variable instance
         (func $exn:fail:contract:variable/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $id      (ref eq)) ; symbol
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:contract:variable-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $id)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:contract : string? continuation-mark-set? -> exn:fail:contract
         (func $exn:fail:contract (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:contract) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:contract : string? continuation-mark-set? -> exn:fail:contract
         (func $make-exn:fail:contract (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:contract) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:contract? : any/c -> boolean?
         (func $exn:fail:contract? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:contract:arity : string? continuation-mark-set? -> exn:fail:contract:arity
         (func $exn:fail:contract:arity (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:arity/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:contract:arity) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:contract:arity : string? continuation-mark-set? -> exn:fail:contract:arity
         (func $make-exn:fail:contract:arity (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:arity/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:contract:arity) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:contract:arity? : any/c -> boolean?
         (func $exn:fail:contract:arity? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract:arity-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:contract:continuation : string? continuation-mark-set? -> exn:fail:contract:continuation
         (func $exn:fail:contract:continuation (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:continuation/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:contract:continuation) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:contract:continuation : string? continuation-mark-set? -> exn:fail:contract:continuation
         (func $make-exn:fail:contract:continuation (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:continuation/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:contract:continuation) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:contract:continuation? : any/c -> boolean?
         (func $exn:fail:contract:continuation? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract:continuation-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:contract:divide-by-zero : string? continuation-mark-set? -> exn:fail:contract:divide-by-zero
         (func $exn:fail:contract:divide-by-zero (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:divide-by-zero/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:contract:divide-by-zero) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:contract:divide-by-zero : string? continuation-mark-set? -> exn:fail:contract:divide-by-zero
         (func $make-exn:fail:contract:divide-by-zero (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:divide-by-zero/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:contract:divide-by-zero) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:contract:divide-by-zero? : any/c -> boolean?
         (func $exn:fail:contract:divide-by-zero? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract:divide-by-zero-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:contract:non-fixnum-result : string? continuation-mark-set? -> exn:fail:contract:non-fixnum-result
         (func $exn:fail:contract:non-fixnum-result (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:non-fixnum-result/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:contract:non-fixnum-result) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:contract:non-fixnum-result : string? continuation-mark-set? -> exn:fail:contract:non-fixnum-result
         (func $make-exn:fail:contract:non-fixnum-result (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:non-fixnum-result/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:contract:non-fixnum-result) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:contract:non-fixnum-result? : any/c -> boolean?
         (func $exn:fail:contract:non-fixnum-result? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract:non-fixnum-result-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:contract:variable : string? continuation-mark-set? symbol? -> exn:fail:contract:variable
         (func $exn:fail:contract:variable (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $id      (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:variable/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:contract:variable) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:contract:variable-ensure-id
                                     (global.get $symbol:exn:fail:contract:variable)
                                     (local.get $id)))))

         ;; make-exn:fail:contract:variable : string? continuation-mark-set? symbol? -> exn:fail:contract:variable
         (func $make-exn:fail:contract:variable (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $id      (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:contract:variable/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:contract:variable) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:contract:variable-ensure-id
                                     (global.get $symbol:make-exn:fail:contract:variable)
                                     (local.get $id)))))

         ;; exn:fail:contract:variable? : any/c -> boolean?
         (func $exn:fail:contract:variable? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:contract:variable-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:contract:variable-id : exn:fail:contract:variable -> symbol?
         (func $exn:fail:contract:variable-id (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:fail:contract:variable-ensure
                                (global.get $symbol:exn:fail:contract:variable-id)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         ;; Kernel exception fail:read struct type descriptor cache
         (func $exn:srclocs-property-list
               (result (ref eq))

               (call $cons
                     (call $cons
                           (global.get $prop:exn:srclocs)
                           (global.get $prim:exn:fail:read-srclocs))
                     (global.get $null)))

         (func $ensure-exn:fail:read-type
               (result (ref $StructType))

               (local $existing    (ref null $StructType))
               (local $std         (ref $StructType))
               (local $super       (ref $StructType))
               (local $immut       (ref eq))
               (local $super-count i32)
               (local $new-immut   (ref eq))

               (local.set $existing (global.get $exn:fail:read-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:read))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:read))))
                    (global.set $exn:fail:read-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:read:eof struct type descriptor cache
         (func $ensure-exn:fail:read:eof-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:read:eof-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:read-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:read:eof))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (call $exn:srclocs-property-list)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:read:eof))))
                    (global.set $exn:fail:read:eof-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:read:non-char struct type descriptor cache
         (func $ensure-exn:fail:read:non-char-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:read:non-char-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:read-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:read:non-char))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:read:non-char))))
                    (global.set $exn:fail:read:non-char-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Validate that srclocs is a (listof srcloc?)
         (func $exn:fail:read-ensure-srclocs
               (param $who      (ref eq)) ; symbol
               (param $srclocs  (ref eq)) ; any/c
               (result (ref eq))

               (local $rest  (ref eq))
               (local $pair  (ref $Pair))
               (local $car   (ref eq))

               (local.set $rest (local.get $srclocs))
               (block $done
                 (loop $loop
                   (if (ref.eq (local.get $rest) (global.get $null))
                       (then (br $done)))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                       (then (call $raise-argument-error1
                                   (local.get $who)
                                   (global.get $string:listof-srcloc?)
                                   (local.get $srclocs))
                             (unreachable)))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                   (local.set $car (struct.get $Pair $a (local.get $pair)))
                   (if (ref.eq (call $srcloc? (local.get $car)) (global.get $true))
                       (then (nop))
                       (else (call $raise-argument-error1
                                   (local.get $who)
                                   (global.get $string:listof-srcloc?)
                                   (local.get $srclocs))
                             (unreachable)))
                   (local.set $rest (struct.get $Pair $d (local.get $pair)))
                   (br $loop)))
               (local.get $srclocs))

         ;; Validate that a value is a kernel exception:fail:read
         (func $exn:fail:read-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:read-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Construct a kernel exception:fail:read instance
         (func $exn:fail:read/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; (listof srcloc?)
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:read-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $srclocs)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:read:eof instance
         (func $exn:fail:read:eof/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; (listof srcloc?)
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:read:eof-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $srclocs)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:read:non-char instance
         (func $exn:fail:read:non-char/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; (listof srcloc?)
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:read:non-char-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $srclocs)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:read : string? continuation-mark-set? (listof srcloc?) -> exn:fail:read
         (func $exn:fail:read (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:read/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:read) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:read-ensure-srclocs
                                     (global.get $symbol:exn:fail:read)
                                     (local.get $srclocs)))))

         ;; make-exn:fail:read : string? continuation-mark-set? (listof srcloc?) -> exn:fail:read
         (func $make-exn:fail:read (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:read/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:read) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:read-ensure-srclocs
                                     (global.get $symbol:make-exn:fail:read)
                                     (local.get $srclocs)))))

         ;; exn:fail:read? : any/c -> boolean?
         (func $exn:fail:read? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:read-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:read-srclocs : exn:fail:read -> (listof srcloc?)
         (func $exn:fail:read-srclocs (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:fail:read-ensure
                                (global.get $symbol:exn:fail:read-srclocs)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         ;; exn:srclocs? : any/c -> boolean?
         ;;   Recognize values whose struct type has prop:exn:srclocs.
         (func $exn:srclocs? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std      (ref $StructType))
               (local $struct   (ref $Struct))
               (local $sentinel (ref eq))
               (local $val      (ref eq))

               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (return (global.get $false))))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $std (struct.get $Struct $type (local.get $struct)))
               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
               (local.set $val
                          (call $struct-type-property-lookup
                                (local.get $std)
                                (ref.cast (ref $StructTypeProperty) (global.get $prop:exn:srclocs))
                                (local.get $sentinel)))
               ;; Some kernel exception descriptors can be forced during
               ;; runtime initialization before the property table is fully
               ;; populated. Keep the built-in read-exception family aligned
               ;; with Racket's `set-exn-srcloc-properties!` in that case.
               (if (ref.eq (local.get $val) (local.get $sentinel))
                   (then
                    (if (ref.eq (call $exn:fail:read? (local.get $v)) (global.get $true))
                        (then (return (global.get $true))))))
               (if (result (ref eq))
                   (ref.eq (local.get $val) (local.get $sentinel))
                   (then (global.get $false))
                   (else (global.get $true))))

         ;; exn:srclocs-accessor : exn:srclocs? -> procedure?
         ;;   Return the source-location accessor procedure stored in prop:exn:srclocs.
         (func $exn:srclocs-accessor (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std      (ref $StructType))
               (local $struct   (ref $Struct))
               (local $sentinel (ref eq))
               (local $val      (ref eq))

               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:exn:srclocs-accessor)
                               (global.get $string:exn:srclocs?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $std (struct.get $Struct $type (local.get $struct)))
               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
               (local.set $val
                          (call $struct-type-property-lookup
                                (local.get $std)
                                (ref.cast (ref $StructTypeProperty) (global.get $prop:exn:srclocs))
                                (local.get $sentinel)))
               (if (ref.eq (local.get $val) (local.get $sentinel))
                   (then
                    (if (ref.eq (call $exn:fail:read? (local.get $v)) (global.get $true))
                        (then (return (global.get $prim:exn:fail:read-srclocs))))
                    (call $raise-argument-error1
                          (global.get $symbol:exn:srclocs-accessor)
                          (global.get $string:exn:srclocs?)
                          (local.get $v))
                    (unreachable)))
               (local.get $val))

         ;; exn:fail:read:eof : string? continuation-mark-set? (listof srcloc?) -> exn:fail:read:eof
         (func $exn:fail:read:eof (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:read:eof/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:read:eof) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:read-ensure-srclocs
                                     (global.get $symbol:exn:fail:read:eof)
                                     (local.get $srclocs)))))

         ;; make-exn:fail:read:eof : string? continuation-mark-set? (listof srcloc?) -> exn:fail:read:eof
         (func $make-exn:fail:read:eof (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:read:eof/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:read:eof) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:read-ensure-srclocs
                                     (global.get $symbol:make-exn:fail:read:eof)
                                     (local.get $srclocs)))))

         ;; exn:fail:read:eof? : any/c -> boolean?
         (func $exn:fail:read:eof? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:read:eof-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:read:non-char : string? continuation-mark-set? (listof srcloc?) -> exn:fail:read:non-char
         (func $exn:fail:read:non-char (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:read:non-char/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:read:non-char) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:read-ensure-srclocs
                                     (global.get $symbol:exn:fail:read:non-char)
                                     (local.get $srclocs)))))

         ;; make-exn:fail:read:non-char : string? continuation-mark-set? (listof srcloc?) -> exn:fail:read:non-char
         (func $make-exn:fail:read:non-char (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $srclocs (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:read:non-char/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:read:non-char) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:read-ensure-srclocs
                                     (global.get $symbol:make-exn:fail:read:non-char)
                                     (local.get $srclocs)))))

         ;; exn:fail:read:non-char? : any/c -> boolean?
         (func $exn:fail:read:non-char? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:read:non-char-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:filesystem struct type descriptor cache
         (func $ensure-exn:fail:filesystem-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:filesystem-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem))))
                    (global.set $exn:fail:filesystem-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Construct a kernel exception:fail:filesystem instance
         (func $exn:fail:filesystem/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:filesystem-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:filesystem : string? continuation-mark-set? -> exn:fail:filesystem
         (func $exn:fail:filesystem (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:filesystem) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:filesystem : string? continuation-mark-set? -> exn:fail:filesystem
         (func $make-exn:fail:filesystem (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:filesystem) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:filesystem? : any/c -> boolean?
         (func $exn:fail:filesystem? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:filesystem-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:filesystem:exists struct type descriptor cache
         (func $ensure-exn:fail:filesystem:exists-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:filesystem:exists-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:filesystem-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:exists))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:exists))))
                    (global.set $exn:fail:filesystem:exists-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Construct a kernel exception:fail:filesystem:exists instance
         (func $exn:fail:filesystem:exists/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:filesystem:exists-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:filesystem:exists : string? continuation-mark-set? -> exn:fail:filesystem:exists
         (func $exn:fail:filesystem:exists (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:exists/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:filesystem:exists) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:filesystem:exists : string? continuation-mark-set? -> exn:fail:filesystem:exists
         (func $make-exn:fail:filesystem:exists (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:exists/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:filesystem:exists) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:filesystem:exists? : any/c -> boolean?
         (func $exn:fail:filesystem:exists? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:filesystem:exists-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:filesystem:version struct type descriptor cache
         (func $ensure-exn:fail:filesystem:version-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:filesystem:version-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:filesystem-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:version))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:version))))
                    (global.set $exn:fail:filesystem:version-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Construct a kernel exception:fail:filesystem:version instance
         (func $exn:fail:filesystem:version/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:filesystem:version-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:filesystem:version : string? continuation-mark-set? -> exn:fail:filesystem:version
         (func $exn:fail:filesystem:version (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:version/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:filesystem:version) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:filesystem:version : string? continuation-mark-set? -> exn:fail:filesystem:version
         (func $make-exn:fail:filesystem:version (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:version/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:filesystem:version) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:filesystem:version? : any/c -> boolean?
         (func $exn:fail:filesystem:version? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:filesystem:version-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:filesystem:errno struct type descriptor cache
         (func $ensure-exn:fail:filesystem:errno-type
               (result (ref $StructType))

               (local $existing     (ref null $StructType))
               (local $std          (ref $StructType))
               (local $super        (ref $StructType))
               (local $immut        (ref eq))
               (local $super-count  i32)
               (local $new-immut    (ref eq))

               (local.set $existing (global.get $exn:fail:filesystem:errno-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:filesystem-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:errno))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:errno))))
                    (global.set $exn:fail:filesystem:errno-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Validate that a value is a kernel exception:fail:filesystem:errno
         (func $exn:fail:filesystem:errno-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:filesystem:errno-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Validate the errno field documented as (cons/c exact-integer? (or/c 'posix 'windows 'gai)).
         (func $exn:fail:filesystem:errno-ensure-errno
               (param $who   (ref eq)) ; symbol
               (param $errno (ref eq)) ; any/c
               (result (ref eq))

               (local $pair (ref $Pair))
               (local $code (ref eq))
               (local $kind (ref eq))

               (if (i32.eqz (ref.test (ref $Pair) (local.get $errno)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:filesystem-errno)
                               (local.get $errno))
                         (unreachable)))
               (local.set $pair (ref.cast (ref $Pair) (local.get $errno)))
               (local.set $code (struct.get $Pair $a (local.get $pair)))
               (local.set $kind (struct.get $Pair $d (local.get $pair)))
               (if (ref.eq (call $exact-integer? (local.get $code)) (global.get $false))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:filesystem-errno)
                               (local.get $errno))
                         (unreachable)))
               (if (i32.eqz
                    (i32.or
                     (ref.eq (local.get $kind) (global.get $symbol:posix))
                     (i32.or
                      (ref.eq (local.get $kind) (global.get $symbol:windows))
                      (ref.eq (local.get $kind) (global.get $symbol:gai)))))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:filesystem-errno)
                               (local.get $errno))
                         (unreachable)))
               (local.get $errno))

         ;; Construct a kernel exception:fail:filesystem:errno instance
         (func $exn:fail:filesystem:errno/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $errno   (ref eq)) ; (cons/c exact-integer? (or/c 'posix 'windows 'gai))
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:filesystem:errno-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $errno)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:filesystem:errno : string? continuation-mark-set? (cons/c exact-integer? (or/c 'posix 'windows 'gai)) -> exn:fail:filesystem:errno
         (func $exn:fail:filesystem:errno (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $errno   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:errno/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:filesystem:errno) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:filesystem:errno-ensure-errno
                                     (global.get $symbol:exn:fail:filesystem:errno)
                                     (local.get $errno)))))

         ;; make-exn:fail:filesystem:errno : string? continuation-mark-set? (cons/c exact-integer? (or/c 'posix 'windows 'gai)) -> exn:fail:filesystem:errno
         (func $make-exn:fail:filesystem:errno (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $errno   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:errno/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:filesystem:errno) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:filesystem:errno-ensure-errno
                                     (global.get $symbol:make-exn:fail:filesystem:errno)
                                     (local.get $errno)))))

         ;; exn:fail:filesystem:errno? : any/c -> boolean?
         (func $exn:fail:filesystem:errno? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:filesystem:errno-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:filesystem:errno-errno : exn:fail:filesystem:errno -> (cons/c exact-integer? (or/c 'posix 'windows 'gai))
         (func $exn:fail:filesystem:errno-errno (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:fail:filesystem:errno-ensure
                                (global.get $symbol:exn:fail:filesystem:errno-errno)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         ;; Kernel exception fail:filesystem:missing-module struct type descriptor cache
         (func $ensure-exn:fail:filesystem:missing-module-type
               (result (ref $StructType))

               (local $existing     (ref null $StructType))
               (local $std          (ref $StructType))
               (local $super        (ref $StructType))
               (local $immut        (ref eq))
               (local $super-count  i32)
               (local $new-immut    (ref eq))

               (local.set $existing (global.get $exn:fail:filesystem:missing-module-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:filesystem-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:missing-module))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:filesystem:missing-module))))
                    (global.set $exn:fail:filesystem:missing-module-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Validate that a value is a kernel exception:fail:filesystem:missing-module
         (func $exn:fail:filesystem:missing-module-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:filesystem:missing-module-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Construct a kernel exception:fail:filesystem:missing-module instance
         (func $exn:fail:filesystem:missing-module/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $path    (ref eq)) ; module-path?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:filesystem:missing-module-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $path)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:filesystem:missing-module : string? continuation-mark-set? module-path? -> exn:fail:filesystem:missing-module
         (func $exn:fail:filesystem:missing-module (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $path    (ref eq)) ; module-path?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:missing-module/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:filesystem:missing-module) (local.get $message))
                               (local.get $marks)
                               (local.get $path))))

         ;; make-exn:fail:filesystem:missing-module : string? continuation-mark-set? module-path? -> exn:fail:filesystem:missing-module
         (func $make-exn:fail:filesystem:missing-module (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $path    (ref eq)) ; module-path?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:filesystem:missing-module/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:filesystem:missing-module) (local.get $message))
                               (local.get $marks)
                               (local.get $path))))

         ;; exn:fail:filesystem:missing-module? : any/c -> boolean?
         (func $exn:fail:filesystem:missing-module? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:filesystem:missing-module-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:filesystem:missing-module-path : exn:fail:filesystem:missing-module -> module-path?
         (func $exn:fail:filesystem:missing-module-path (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:fail:filesystem:missing-module-ensure
                                (global.get $symbol:exn:fail:filesystem:missing-module-path)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         ;; Kernel exception fail:network struct type descriptor cache
         (func $ensure-exn:fail:network-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:network-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:network))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:network))))
                    (global.set $exn:fail:network-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Construct a kernel exception:fail:network instance
         (func $exn:fail:network/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:network-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:network : string? continuation-mark-set? -> exn:fail:network
         (func $exn:fail:network (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:network/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:network) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:network : string? continuation-mark-set? -> exn:fail:network
         (func $make-exn:fail:network (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:network/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:network) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:network? : any/c -> boolean?
         (func $exn:fail:network? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:network-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:network:errno struct type descriptor cache
         (func $ensure-exn:fail:network:errno-type
               (result (ref $StructType))

               (local $existing     (ref null $StructType))
               (local $std          (ref $StructType))
               (local $super        (ref $StructType))
               (local $immut        (ref eq))
               (local $super-count  i32)
               (local $new-immut    (ref eq))

               (local.set $existing (global.get $exn:fail:network:errno-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:network-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:network:errno))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:network:errno))))
                    (global.set $exn:fail:network:errno-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Validate that a value is a kernel exception:fail:network:errno
         (func $exn:fail:network:errno-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:network:errno-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Construct a kernel exception:fail:network:errno instance
         (func $exn:fail:network:errno/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $errno   (ref eq)) ; (cons/c exact-integer? (or/c 'posix 'windows 'gai))
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:network:errno-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $errno)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:network:errno : string? continuation-mark-set? (cons/c exact-integer? (or/c 'posix 'windows 'gai)) -> exn:fail:network:errno
         (func $exn:fail:network:errno (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $errno   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:network:errno/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:network:errno) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:filesystem:errno-ensure-errno
                                     (global.get $symbol:exn:fail:network:errno)
                                     (local.get $errno)))))

         ;; make-exn:fail:network:errno : string? continuation-mark-set? (cons/c exact-integer? (or/c 'posix 'windows 'gai)) -> exn:fail:network:errno
         (func $make-exn:fail:network:errno (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $errno   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:network:errno/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:network:errno) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:filesystem:errno-ensure-errno
                                     (global.get $symbol:make-exn:fail:network:errno)
                                     (local.get $errno)))))

         ;; exn:fail:network:errno? : any/c -> boolean?
         (func $exn:fail:network:errno? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:network:errno-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:network:errno-errno : exn:fail:network:errno -> (cons/c exact-integer? (or/c 'posix 'windows 'gai))
         (func $exn:fail:network:errno-errno (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:fail:network:errno-ensure
                                (global.get $symbol:exn:fail:network:errno-errno)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         ;; Kernel exception fail:out-of-memory struct type descriptor cache
         (func $ensure-exn:fail:out-of-memory-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:out-of-memory-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:out-of-memory))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:out-of-memory))))
                    (global.set $exn:fail:out-of-memory-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Construct a kernel exception:fail:out-of-memory instance
         (func $exn:fail:out-of-memory/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:out-of-memory-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:out-of-memory : string? continuation-mark-set? -> exn:fail:out-of-memory
         (func $exn:fail:out-of-memory (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:out-of-memory/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:out-of-memory) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:out-of-memory : string? continuation-mark-set? -> exn:fail:out-of-memory
         (func $make-exn:fail:out-of-memory (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:out-of-memory/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:out-of-memory) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:out-of-memory? : any/c -> boolean?
         (func $exn:fail:out-of-memory? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:out-of-memory-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:unsupported struct type descriptor cache
         (func $ensure-exn:fail:unsupported-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:unsupported-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:unsupported))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:unsupported))))
                    (global.set $exn:fail:unsupported-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Construct a kernel exception:fail:unsupported instance
         (func $exn:fail:unsupported/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:unsupported-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:unsupported : string? continuation-mark-set? -> exn:fail:unsupported
         (func $exn:fail:unsupported (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:unsupported/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:unsupported) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:unsupported : string? continuation-mark-set? -> exn:fail:unsupported
         (func $make-exn:fail:unsupported (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:unsupported/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:unsupported) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:unsupported? : any/c -> boolean?
         (func $exn:fail:unsupported? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:unsupported-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:user struct type descriptor cache
         (func $ensure-exn:fail:user-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:user-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:user))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:user))))
                    (global.set $exn:fail:user-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Construct a kernel exception:fail:user instance
         (func $exn:fail:user/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:user-type))
               (local.set $fields
                          (array.new_fixed $Array 2
                                           (local.get $message)
                                           (local.get $marks)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:user : string? continuation-mark-set? -> exn:fail:user
         (func $exn:fail:user (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:user/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:user) (local.get $message))
                               (local.get $marks))))

         ;; make-exn:fail:user : string? continuation-mark-set? -> exn:fail:user
         (func $make-exn:fail:user (type $Prim2)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:user/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:user) (local.get $message))
                               (local.get $marks))))

         ;; exn:fail:user? : any/c -> boolean?
         (func $exn:fail:user? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:user-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; Kernel exception fail:syntax struct type descriptor cache
         (func $ensure-exn:fail:syntax-type
               (result (ref $StructType))

               (local $existing    (ref null $StructType))
               (local $std         (ref $StructType))
               (local $super       (ref $StructType))
               (local $immut       (ref eq))
               (local $super-count i32)
               (local $new-immut   (ref eq))

               (local.set $existing (global.get $exn:fail:syntax-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:syntax))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:syntax))))
                    (global.set $exn:fail:syntax-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:syntax:missing-module struct type descriptor cache
         (func $ensure-exn:fail:syntax:missing-module-type
               (result (ref $StructType))

               (local $existing    (ref null $StructType))
               (local $std         (ref $StructType))
               (local $super       (ref $StructType))
               (local $immut       (ref eq))
               (local $super-count i32)
               (local $new-immut   (ref eq))

               (local.set $existing (global.get $exn:fail:syntax:missing-module-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:syntax-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $super-count (struct.get $StructType $field-count (local.get $super)))
                    (local.set $new-immut
                               (call $append/2
                                     (local.get $immut)
                                     (call $list-from-range/checked
                                           (local.get $super-count)
                                           (i32.add (local.get $super-count) (i32.const 1)))))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:syntax:missing-module))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 1)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $new-immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:syntax:missing-module))))
                    (global.set $exn:fail:syntax:missing-module-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Kernel exception fail:syntax:unbound struct type descriptor cache
         (func $ensure-exn:fail:syntax:unbound-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $super    (ref $StructType))
               (local $immut    (ref eq))

               (local.set $existing (global.get $exn:fail:syntax:unbound-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $super (call $ensure-exn:fail:syntax-type))
                    (local.set $immut (struct.get $StructType $immutables (local.get $super)))
                    (local.set $std
                               (call $make-struct-type-descriptor/checked
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:syntax:unbound))
                                     (ref.cast (ref eq) (local.get $super))
                                     (i32.const 0)
                                     (i32.const 0)
                                     (global.get $false)
                                     (global.get $null)
                                     (global.get $false)
                                     (global.get $false)
                                     (local.get $immut)
                                     (global.get $false)
                                     (ref.cast (ref $Symbol) (global.get $symbol:exn:fail:syntax:unbound))))
                    (global.set $exn:fail:syntax:unbound-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         ;; Validate that exprs is a (listof syntax?)
         (func $exn:fail:syntax-ensure-exprs
               (param $who   (ref eq)) ; symbol
               (param $exprs (ref eq)) ; any/c
               (result (ref eq))

               (local $rest (ref eq))
               (local $pair (ref $Pair))
               (local $car  (ref eq))

               (local.set $rest (local.get $exprs))
               (block $done
                 (loop $loop
                   (if (ref.eq (local.get $rest) (global.get $null))
                       (then (br $done)))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                       (then (call $raise-argument-error1
                                   (local.get $who)
                                   (global.get $string:listof-syntax?)
                                   (local.get $exprs))
                             (unreachable)))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                   (local.set $car (struct.get $Pair $a (local.get $pair)))
                   (if (ref.eq (call $syntax? (local.get $car)) (global.get $true))
                       (then (nop))
                       (else (call $raise-argument-error1
                                   (local.get $who)
                                   (global.get $string:listof-syntax?)
                                   (local.get $exprs))
                             (unreachable)))
                   (local.set $rest (struct.get $Pair $d (local.get $pair)))
                   (br $loop)))
               (local.get $exprs))

         ;; Validate that a value is a kernel exception:fail:syntax
         (func $exn:fail:syntax-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:syntax-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Validate that a value is a kernel exception:fail:syntax:missing-module
         (func $exn:fail:syntax:missing-module-ensure
               (param $who (ref eq)) ; symbol
               (param $v   (ref eq)) ; any/c
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:syntax:missing-module-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $ok (call $struct-type-is-a?/i32
                                        (struct.get $Struct $type (local.get $struct))
                                        (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:struct?)
                               (local.get $v))
                         (unreachable)))
               (local.get $struct))

         ;; Construct a kernel exception:fail:syntax instance
         (func $exn:fail:syntax/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; (listof syntax?)
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:syntax-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $exprs)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:syntax:missing-module instance
         (func $exn:fail:syntax:missing-module/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; (listof syntax?)
               (param $path    (ref eq)) ; module-path?
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:syntax:missing-module-type))
               (local.set $fields
                          (array.new_fixed $Array 4
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $exprs)
                                           (local.get $path)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; Construct a kernel exception:fail:syntax:unbound instance
         (func $exn:fail:syntax:unbound/make
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; (listof syntax?)
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-exn:fail:syntax:unbound-type))
               (local.set $fields
                          (array.new_fixed $Array 3
                                           (local.get $message)
                                           (local.get $marks)
                                           (local.get $exprs)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         ;; exn:fail:syntax : string? continuation-mark-set? (listof syntax?) -> exn:fail:syntax
         (func $exn:fail:syntax (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:syntax/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:syntax) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:syntax-ensure-exprs
                                     (global.get $symbol:exn:fail:syntax)
                                     (local.get $exprs)))))

         ;; make-exn:fail:syntax : string? continuation-mark-set? (listof syntax?) -> exn:fail:syntax
         (func $make-exn:fail:syntax (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:syntax/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:syntax) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:syntax-ensure-exprs
                                     (global.get $symbol:make-exn:fail:syntax)
                                     (local.get $exprs)))))

         ;; exn:fail:syntax? : any/c -> boolean?
         (func $exn:fail:syntax? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:syntax-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:syntax-exprs : exn:fail:syntax -> (listof syntax?)
         (func $exn:fail:syntax-exprs (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:fail:syntax-ensure
                                (global.get $symbol:exn:fail:syntax-exprs)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         ;; exn:fail:syntax:missing-module : string? continuation-mark-set? (listof syntax?) module-path? -> exn:fail:syntax:missing-module
         (func $exn:fail:syntax:missing-module (type $Prim4)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; any/c
               (param $path    (ref eq)) ; module-path?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:syntax:missing-module/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:syntax:missing-module) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:syntax-ensure-exprs
                                     (global.get $symbol:exn:fail:syntax:missing-module)
                                     (local.get $exprs))
                               (local.get $path))))

         ;; make-exn:fail:syntax:missing-module : string? continuation-mark-set? (listof syntax?) module-path? -> exn:fail:syntax:missing-module
         (func $make-exn:fail:syntax:missing-module (type $Prim4)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; any/c
               (param $path    (ref eq)) ; module-path?
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:syntax:missing-module/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:syntax:missing-module) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:syntax-ensure-exprs
                                     (global.get $symbol:make-exn:fail:syntax:missing-module)
                                     (local.get $exprs))
                               (local.get $path))))

         ;; exn:fail:syntax:missing-module? : any/c -> boolean?
         (func $exn:fail:syntax:missing-module? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:syntax:missing-module-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))

         ;; exn:fail:syntax:missing-module-path : exn:fail:syntax:missing-module -> module-path?
         (func $exn:fail:syntax:missing-module-path (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $struct (ref $Struct))
               (local $fields (ref $Array))

               (local.set $struct
                          (call $exn:fail:syntax:missing-module-ensure
                                (global.get $symbol:exn:fail:syntax:missing-module-path)
                                (local.get $v)))
               (local.set $fields (struct.get $Struct $fields (local.get $struct)))
               (array.get $Array (local.get $fields) (i32.const 3)))

         ;; exn:fail:syntax:unbound : string? continuation-mark-set? (listof syntax?) -> exn:fail:syntax:unbound
         (func $exn:fail:syntax:unbound (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:syntax:unbound/make
                               (call $exn-ensure-message (global.get $symbol:exn:fail:syntax:unbound) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:syntax-ensure-exprs
                                     (global.get $symbol:exn:fail:syntax:unbound)
                                     (local.get $exprs)))))

         ;; make-exn:fail:syntax:unbound : string? continuation-mark-set? (listof syntax?) -> exn:fail:syntax:unbound
         (func $make-exn:fail:syntax:unbound (type $Prim3)
               (param $message (ref eq)) ; string
               (param $marks   (ref eq)) ; continuation-mark-set?
               (param $exprs   (ref eq)) ; any/c
               (result (ref eq))

               (ref.cast (ref eq)
                         (call $exn:fail:syntax:unbound/make
                               (call $exn-ensure-message (global.get $symbol:make-exn:fail:syntax:unbound) (local.get $message))
                               (local.get $marks)
                               (call $exn:fail:syntax-ensure-exprs
                                     (global.get $symbol:make-exn:fail:syntax:unbound)
                                     (local.get $exprs)))))

         ;; exn:fail:syntax:unbound? : any/c -> boolean?
         (func $exn:fail:syntax:unbound? (type $Prim1)
               (param $v (ref eq)) ; any/c
               (result (ref eq))

               (local $std    (ref $StructType))
               (local $struct (ref $Struct))
               (local $ok     i32)

               (local.set $std (call $ensure-exn:fail:syntax:unbound-type))
               (if (result (ref eq))
                   (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $ok (call $struct-type-is-a?/i32
                                             (struct.get $Struct $type (local.get $struct))
                                             (local.get $std)))
                    (if (result (ref eq))
                        (local.get $ok)
                        (then (global.get $true))
                        (else (global.get $false))))
                   (else (global.get $false))))


         ;; raise-read-error : string? any/c (or/c exact-positive-integer? #f)
         ;;                    (or/c exact-nonnegative-integer? #f)
         ;;                    (or/c exact-positive-integer? #f)
         ;;                    (or/c exact-nonnegative-integer? #f)
         ;;                    [#:extra-srclocs (listof srcloc?)] -> none
         (func $raise-read-error (type $Prim67)
               (param $message  (ref eq)) ; string
               (param $source   (ref eq)) ; (or/c path-string? symbol? #f)
               (param $line     (ref eq)) ; (or/c exact-positive-integer? #f)
               (param $column   (ref eq)) ; (or/c exact-nonnegative-integer? #f)
               (param $position (ref eq)) ; (or/c exact-positive-integer? #f)
               (param $span     (ref eq)) ; (or/c exact-nonnegative-integer? #f)
               (param $extra    (ref eq)) ; optional (listof srcloc?), default = '()
               (result (ref eq))

               (local $who             (ref eq))
               (local $message-checked (ref eq))
               (local $line-checked    (ref eq))
               (local $column-checked  (ref eq))
               (local $position-checked (ref eq))
               (local $span-checked    (ref eq))
               (local $extra-checked   (ref eq))
               (local $srcloc          (ref eq))
               (local $srclocs         (ref eq))

               (local.set $who (global.get $symbol:raise-read-error))
               (local.set $message-checked
                          (call $exn-ensure-message (local.get $who) (local.get $message)))
               (local.set $line-checked
                          (call $srcloc-check-positive (local.get $who) (local.get $line)))
               (local.set $column-checked
                          (call $srcloc-check-nonnegative (local.get $who) (local.get $column)))
               (local.set $position-checked
                          (call $srcloc-check-positive (local.get $who) (local.get $position)))
               (local.set $span-checked
                          (call $srcloc-check-nonnegative (local.get $who) (local.get $span)))
               (local.set $extra-checked
                          (if (result (ref eq))
                              (ref.eq (local.get $extra) (global.get $missing))
                              (then (global.get $null))
                              (else (call $exn:fail:read-ensure-srclocs
                                          (local.get $who)
                                          (local.get $extra)))))
               (local.set $srcloc
                          (call $make-srcloc
                                (local.get $source)
                                (local.get $line-checked)
                                (local.get $column-checked)
                                (local.get $position-checked)
                                (local.get $span-checked)))
               (local.set $srclocs
                          (call $cons (local.get $srcloc) (local.get $extra-checked)))
               (call $raise
                     (call $exn:fail:read
                           (local.get $message-checked)
                           (global.get $false)
                           (local.get $srclocs))
                     (global.get $true))
               (unreachable))

         ;; raise-read-eof-error : string? any/c (or/c exact-positive-integer? #f)
         ;;                         (or/c exact-nonnegative-integer? #f)
         ;;                         (or/c exact-positive-integer? #f)
         ;;                         (or/c exact-nonnegative-integer? #f)
         ;;                         [#:extra-srclocs (listof srcloc?)] -> none
         (func $raise-read-eof-error (type $Prim67)
               (param $message  (ref eq)) ; string
               (param $source   (ref eq)) ; (or/c path-string? symbol? #f)
               (param $line     (ref eq)) ; (or/c exact-positive-integer? #f)
               (param $column   (ref eq)) ; (or/c exact-nonnegative-integer? #f)
               (param $position (ref eq)) ; (or/c exact-positive-integer? #f)
               (param $span     (ref eq)) ; (or/c exact-nonnegative-integer? #f)
               (param $extra    (ref eq)) ; optional (listof srcloc?), default = '()
               (result (ref eq))

               (local $who              (ref eq))
               (local $message-checked  (ref eq))
               (local $line-checked     (ref eq))
               (local $column-checked   (ref eq))
               (local $position-checked (ref eq))
               (local $span-checked     (ref eq))
               (local $extra-checked    (ref eq))
               (local $srclocs          (ref eq))

               (local.set $who (global.get $symbol:raise-read-eof-error))
               (local.set $message-checked
                          (call $exn-ensure-message (local.get $who) (local.get $message)))
               (local.set $line-checked
                          (call $srcloc-check-positive (local.get $who) (local.get $line)))
               (local.set $column-checked
                          (call $srcloc-check-nonnegative (local.get $who) (local.get $column)))
               (local.set $position-checked
                          (call $srcloc-check-positive (local.get $who) (local.get $position)))
               (local.set $span-checked
                          (call $srcloc-check-nonnegative (local.get $who) (local.get $span)))
               (local.set $extra-checked
                          (if (result (ref eq))
                              (ref.eq (local.get $extra) (global.get $missing))
                              (then (global.get $null))
                              (else (call $exn:fail:read-ensure-srclocs
                                          (local.get $who)
                                          (local.get $extra)))))
               (local.set $srclocs
                          (call $cons
                                (call $srcloc
                                      (local.get $source)
                                      (local.get $line-checked)
                                      (local.get $column-checked)
                                      (local.get $position-checked)
                                      (local.get $span-checked))
                                (local.get $extra-checked)))
               (call $raise
                     (call $exn:fail:read:eof
                           (local.get $message-checked)
                           (global.get $false)
                           (local.get $srclocs))
                     (global.get $true))
               (unreachable))
     ))

;; exception-contract-runtime-only-forms : (listof datum?)
;;   Enumerate generic contract-error helpers used by the monolithic runtime.
(define exception-contract-runtime-only-forms
  '(
         (func $raise-argument-error/internal
               (param $x (ref eq))

               (call $raise-argument-error1
                     (global.get $symbol:error)
                     (global.get $string:valid-argument)
                     (local.get $x)))

         ;; raise-result-error : symbol? string? any/c -> none
         ;;   Raise a contract error for a bad callback result.
         (func $raise-result-error
               (param $who      (ref eq))
               (param $expected (ref eq))
               (param $result   (ref eq))

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:contract-violation:prefix))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String) (local.get $expected)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:contract-result-prefix))
               (call $growable-array-add! (local.get $out)
                     (call $format/print
                           (local.get $result)
                           (global.get $missing)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))

               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $raise-argument-error/position
               (param $who       (ref eq))
               (param $expected  (ref eq))
               (param $pos       i32)
               (param $got       (ref eq))
               (param $rest-args (ref $Args))

               (local $out           (ref $GrowableArray))
               (local $message       (ref $String))
               (local $argument-no   i32)
               (local $argument-mod10 i32)
               (local $argument-mod100 i32)
               (local $len           i32)
               (local $i             i32)

               (local.set $out
                          (call $make-growable-array (i32.const 16)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:contract-violation:prefix))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String) (local.get $expected)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:arity-error:given))
               (call $growable-array-add! (local.get $out)
                     (call $format/print
                           (local.get $got)
                           (global.get $missing)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:argument-position-prefix))
               (local.set $argument-no (i32.add (local.get $pos) (i32.const 1)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $argument-no) (i32.const 1)))))
               (local.set $argument-mod100
                          (i32.rem_s (local.get $argument-no) (i32.const 100)))
               (local.set $argument-mod10
                          (i32.rem_s (local.get $argument-no) (i32.const 10)))
               (if (i32.and
                    (i32.ge_s (local.get $argument-mod100) (i32.const 11))
                    (i32.le_s (local.get $argument-mod100) (i32.const 13)))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:argument-position-th)))
                   (else
                    (if (i32.eq (local.get $argument-mod10) (i32.const 1))
                        (then
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:argument-position-st)))
                        (else
                         (if (i32.eq (local.get $argument-mod10) (i32.const 2))
                             (then
                              (call $growable-array-add! (local.get $out)
                                    (global.get $string:argument-position-nd)))
                             (else
                              (if (i32.eq (local.get $argument-mod10) (i32.const 3))
                                  (then
                                   (call $growable-array-add! (local.get $out)
                                         (global.get $string:argument-position-rd)))
                                  (else
                                   (call $growable-array-add! (local.get $out)
                                         (global.get $string:argument-position-th))))))))))
               (local.set $len (array.len (local.get $rest-args)))
               (if (i32.gt_u (local.get $len) (i32.const 1))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:other-arguments-prefix))
                    (local.set $i (i32.const 0))
                    (block $done
                           (loop $loop
                                 (br_if $done
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (if (i32.ne (local.get $i) (local.get $pos))
                                     (then
                                      (call $growable-array-add! (local.get $out)
                                            (global.get $string:other-argument-line))
                                      (call $growable-array-add! (local.get $out)
                                            (call $format/print
                                                  (array.get $Args
                                                             (local.get $rest-args)
                                                             (local.get $i))
                                                  (global.get $missing)))))
                                 (local.set $i
                                            (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))

               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks
                                 (global.get $missing)))
                     (global.get $true))
               (unreachable))

         ;; raise-argument-error/value-or-position :
         ;;   symbol? symbol? string? any/c any/c ... -> none
         ;;   Shared implementation for argument errors where the bad value may
         ;;   be supplied directly or selected by zero-based argument position.
         (func $raise-argument-error/value-or-position
               (param $who      (ref eq)) ;; symbol?
               (param $position-who (ref eq)) ;; symbol?
               (param $expected (ref eq)) ;; string?
               (param $third    (ref eq)) ;; bad value or bad argument index
               (param $rest     (ref eq)) ;; rest arguments as $Args
               (local $got      (ref eq))
               (local $rest-args (ref $Args))
               (local $pos      i32)
               (local.set $got (local.get $third))
               (if (ref.test (ref $Args) (local.get $rest))
                   (then
                    (local.set $rest-args (ref.cast (ref $Args) (local.get $rest)))
                    (if (i32.gt_u (array.len (local.get $rest-args)) (i32.const 0))
                        (then
                         (if (i32.eqz (call $fx?/i32 (local.get $third)))
                             (then (call $raise-argument-error1
                                         (local.get $position-who)
                                         (global.get $string:exact-nonnegative-integer?)
                                         (local.get $third))
                                   (unreachable)))
                         (local.set $pos
                                    (i32.shr_s
                                     (i31.get_s (ref.cast (ref i31) (local.get $third)))
                                     (i32.const 1)))
                         (if (i32.lt_s (local.get $pos) (i32.const 0))
                             (then (call $raise-argument-error1
                                         (local.get $position-who)
                                         (global.get $string:exact-nonnegative-integer?)
                                         (local.get $third))
                                   (unreachable)))
                         (if (i32.ge_u (local.get $pos)
                                       (array.len (local.get $rest-args)))
                             (then (call $raise-argument-error1
                                         (local.get $who)
                                         (local.get $expected)
                                         (array.get $Args
                                                    (local.get $rest-args)
                                                    (i32.const 0)))
                                   (unreachable)))
                         (local.set $got
                                    (array.get $Args
                                               (local.get $rest-args)
                                               (local.get $pos)))
                         (if (i32.eq (array.len (local.get $rest-args)) (i32.const 1))
                             (then (call $raise-argument-error1
                                         (local.get $who)
                                         (local.get $expected)
                                         (local.get $got))
                                   (unreachable)))
                         (call $raise-argument-error/position
                               (local.get $who)
                               (local.get $expected)
                               (local.get $pos)
                               (local.get $got)
                               (local.get $rest-args))
                         (unreachable)))))
               (call $raise-argument-error1
                     (local.get $who)
                     (local.get $expected)
                     (local.get $got))
               (unreachable))

         ;; raise-argument-error : symbol? string? any/c any/c ... -> none
         ;;   Public primitive used by compiled library code to report
         ;;   contract violations.
         (func $raise-argument-error (type $Prim>=3)
               (param $who      (ref eq)) ;; symbol?
               (param $expected (ref eq)) ;; string?
               (param $third    (ref eq)) ;; bad value or bad argument index
               (param $rest     (ref eq)) ;; rest arguments as $Args
               (result          (ref eq)) ;; unreachable

               (call $raise-argument-error/value-or-position
                     (local.get $who)
                     (global.get $symbol:raise-argument-error)
                     (local.get $expected)
                     (local.get $third)
                     (local.get $rest))
               (unreachable))

         ;; raise-argument-error* : symbol? symbol? string? any/c any/c ... -> none
         ;;   Realm-aware variant of raise-argument-error. WebRacket does not
         ;;   yet adjust error messages by realm, so the realm argument is
         ;;   validated by compiled code but ignored here.
         (func $raise-argument-error* (type $Prim>=4)
               (param $who      (ref eq)) ;; symbol?
               (param $realm    (ref eq)) ;; symbol?, currently ignored
               (param $expected (ref eq)) ;; string?
               (param $fourth   (ref eq)) ;; bad value or bad argument index
               (param $rest     (ref eq)) ;; rest arguments as $Args
               (result          (ref eq)) ;; unreachable
               (local $rest-args        (ref $Args))
               (local $compat-rest-args (ref $Args))

               (if (i32.eqz (ref.test (ref $String) (local.get $expected)))
                   (then
                    (if (i32.eqz (ref.test (ref $String) (local.get $realm)))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:raise-argument-error*)
                                    (global.get $string:string?)
                                    (local.get $expected))
                              (unreachable)))
                    (if (ref.test (ref $Args) (local.get $rest))
                        (then
                         (local.set $rest-args (ref.cast (ref $Args) (local.get $rest)))
                         (if (i32.gt_u (array.len (local.get $rest-args)) (i32.const 0))
                             (then
                              (call $raise-argument-error/value-or-position
                                    (local.get $who)
                                    (global.get $symbol:raise-argument-error)
                                    (local.get $realm)
                                    (local.get $expected)
                                    (local.get $rest))
                              (unreachable)))))
                    (local.set $compat-rest-args
                               (array.new $Args
                                          (global.get $missing)
                                          (i32.const 1)))
                    (array.set $Args
                               (local.get $compat-rest-args)
                               (i32.const 0)
                               (local.get $fourth))
                    (call $raise-argument-error/value-or-position
                          (local.get $who)
                          (global.get $symbol:raise-argument-error)
                          (local.get $realm)
                          (local.get $expected)
                          (local.get $compat-rest-args))
                    (unreachable)))
               (call $raise-argument-error/value-or-position
                     (local.get $who)
                     (global.get $symbol:raise-argument-error*)
                     (local.get $expected)
                     (local.get $fourth)
                     (local.get $rest))
               (unreachable))

         ;; error : (or/c symbol? string?) any/c ... -> none
         ;;   Raise a catchable exn:fail using Racket's main error message
         ;;   shapes for symbol and string initial arguments.
         (func $error (type $Prim>=1)
               (param $init (ref eq))
               (param $args (ref eq))
               (result      (ref eq))

               (local $out       (ref $GrowableArray))
               (local $message   (ref $String))
               (local $args*     (ref eq))
               (local $arg-pair  (ref $Pair))
               (local $fmt       (ref eq))
               (local $formatted (ref eq))

               (local.set $message (ref.cast (ref $String) (global.get $string:empty)))

               (if (ref.test (ref $Symbol) (local.get $init))
                   (then
                    (if (ref.eq (local.get $args) (global.get $null))
                        (then
                         (local.set $out (call $make-growable-array (i32.const 2)))
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:error-prefix))
                         (call $growable-array-add! (local.get $out)
                               (call $symbol->string (local.get $init)))
                         (local.set $message
                                    (call $growable-array-of-strings->string
                                          (local.get $out))))
                        (else
                         (if (i32.eqz (ref.test (ref $Pair) (local.get $args)))
                             (then (call $raise-argument-error1
                                         (global.get $symbol:error)
                                         (global.get $string:list?)
                                         (local.get $args))
                                   (unreachable)))
                         (local.set $arg-pair
                                    (ref.cast (ref $Pair) (local.get $args)))
                         (local.set $fmt
                                    (struct.get $Pair $a (local.get $arg-pair)))
                         (if (i32.eqz (ref.test (ref $String) (local.get $fmt)))
                             (then (call $raise-argument-error1
                                         (global.get $symbol:error)
                                         (global.get $string:string?)
                                         (local.get $fmt))
                                   (unreachable)))
                         (local.set $formatted
                                    (call $format
                                          (local.get $fmt)
                                          (struct.get $Pair $d
                                                      (local.get $arg-pair))))
                         (local.set $out (call $make-growable-array (i32.const 3)))
                         (call $growable-array-add! (local.get $out)
                               (call $symbol->string (local.get $init)))
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:argument-field-separator))
                         (call $growable-array-add! (local.get $out)
                               (local.get $formatted))
                         (local.set $message
                                    (call $growable-array-of-strings->string
                                          (local.get $out)))))
                    (drop (call $raise
                                (call $make-exn:fail
                                      (local.get $message)
                                      (call $current-continuation-marks
                                            (global.get $missing)))
                                (global.get $true)))
                    (unreachable)))

               (if (i32.eqz (ref.test (ref $String) (local.get $init)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:error)
                               (global.get $string:symbol-or-string?)
                               (local.get $init))
                         (unreachable)))
               (local.set $out (call $make-growable-array (i32.const 4)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String) (local.get $init)))
               (local.set $args* (local.get $args))
               (block $done
                      (loop $loop
                            (br_if $done
                                   (ref.eq (local.get $args*)
                                           (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:error)
                                            (global.get $string:list?)
                                            (local.get $args*))
                                      (unreachable)))
                            (local.set $arg-pair
                                       (ref.cast (ref $Pair) (local.get $args*)))
                            (call $growable-array-add! (local.get $out)
                                  (global.get $string:space))
                            (call $growable-array-add! (local.get $out)
                                  (call $format/print
                                        (struct.get $Pair $a
                                                    (local.get $arg-pair))
                                        (global.get $missing)))
                            (local.set $args*
                                       (struct.get $Pair $d
                                                   (local.get $arg-pair)))
                            (br $loop)))
               (local.set $message
                          (call $growable-array-of-strings->string
                                (local.get $out)))
               (drop (call $raise
                           (call $make-exn:fail
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-arguments-error : symbol? string? any/c ... -> none
         ;;   Report a multi-argument contract error with field/value details.
         (func $raise-arguments-error (type $Prim>=2)
               (param $who     (ref eq)) ;; symbol?
               (param $message (ref eq)) ;; string?
               (param $rest    (ref eq)) ;; field/value details as $Args
               (result         (ref eq)) ;; unreachable
               (local $out       (ref $GrowableArray))
               (local $full-message (ref $String))
               (local $rest-args (ref $Args))
               (local $len       i32)
               (local $i         i32)
               (local $field     (ref eq))

               (local.set $out (call $make-growable-array (i32.const 12)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:contract-violation:prefix))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $message)))

               (if (ref.test (ref $Args) (local.get $rest))
                   (then
                    (local.set $rest-args (ref.cast (ref $Args) (local.get $rest)))
                    (local.set $len (array.len (local.get $rest-args)))
                    (local.set $i (i32.const 0))
                    (block $done
                           (loop $loop
                                 (br_if $done
                                        (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $field
                                            (array.get $Args
                                                       (local.get $rest-args)
                                                       (local.get $i)))
                                 (if (i32.eqz (ref.test (ref $String) (local.get $field)))
                                     (then (call $raise-argument-error1
                                                 (global.get $symbol:raise-arguments-error)
                                                 (global.get $string:string?)
                                                 (local.get $field))
                                           (unreachable)))
                                 (if (i32.ge_u
                                      (i32.add (local.get $i) (i32.const 1))
                                      (local.get $len))
                                     (then (local.set $out
                                                      (call $make-growable-array
                                                            (i32.const 6)))
                                           (call $growable-array-add! (local.get $out)
                                                 (call $format/display
                                                       (global.get $symbol:raise-arguments-error)))
                                           (call $growable-array-add! (local.get $out)
                                                 (global.get $string:contract-violation:prefix))
                                           (call $growable-array-add! (local.get $out)
                                                 (global.get $string:raise-arguments-error-missing-value))
                                           (call $growable-array-add! (local.get $out)
                                                 (global.get $string:argument-field-prefix))
                                           (call $growable-array-add! (local.get $out)
                                                 (global.get $string:raise-arguments-error-string))
                                           (call $growable-array-add! (local.get $out)
                                                 (global.get $string:argument-field-separator))
                                           (call $growable-array-add! (local.get $out)
                                                 (call $format/print
                                                       (local.get $field)
                                                       (global.get $missing)))
                                           (local.set $full-message
                                                      (call $growable-array-of-strings->string
                                                            (local.get $out)))
                                           (drop (call $raise
                                                       (call $exn:fail:contract/make
                                                             (local.get $full-message)
                                                             (call $current-continuation-marks
                                                                   (global.get $missing)))
                                                       (global.get $true)))
                                           (unreachable)))
                                 (call $growable-array-add! (local.get $out)
                                       (global.get $string:argument-field-prefix))
                                 (call $growable-array-add! (local.get $out)
                                       (ref.cast (ref $String) (local.get $field)))
                                 (call $growable-array-add! (local.get $out)
                                       (global.get $string:argument-field-separator))
                                 (call $growable-array-add! (local.get $out)
                                       (call $format/print
                                             (array.get $Args
                                                        (local.get $rest-args)
                                                        (i32.add (local.get $i) (i32.const 1)))
                                             (global.get $missing)))
                                 (local.set $i
                                            (i32.add (local.get $i) (i32.const 2)))
                                 (br $loop)))))
               (local.set $full-message
                          (call $growable-array-of-strings->string (local.get $out)))
               (drop (call $raise
                           (call $exn:fail:contract/make
                                 (local.get $full-message)
                                 (call $current-continuation-marks (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         (func $raise-expected-fixnum
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:fixnum?)
                     (global.get $string:fixnum?)
                     (local.get $x))
               (unreachable))))

;; exception-contract-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register generic contract-error helpers.
(define exception-contract-runtime-only-helpers
  (function-forms->runtime-helpers
   'exception-contract-runtime-only-helpers
   exception-contract-runtime-only-forms))

;; exception-contract-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic contract-error helpers.
(define exception-contract-runtime-only-helper-names
  (map core-runtime-helper-name exception-contract-runtime-only-helpers))

;; bootstrap-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register early bootstrap error helpers.
(define bootstrap-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'bootstrap-error-runtime-only-helpers
   bootstrap-error-runtime-only-forms))

;; bootstrap-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for bootstrap error helpers.
(define bootstrap-error-runtime-only-helper-names
  (map core-runtime-helper-name bootstrap-error-runtime-only-helpers))

;; exception-main-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register exception, exception-structure, and reader-error helpers.
(define exception-main-runtime-only-helpers
  (function-forms->runtime-helpers
   'exception-runtime-only-helpers
   exception-runtime-only-forms))

;; exception-main-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for exception helpers.
(define exception-main-runtime-helper-names
  (map core-runtime-helper-name exception-main-runtime-only-helpers))

;; exception-all-runtime-helpers : (listof core-runtime-helper?)
;;   Register exception, exception-structure, and reader-error helpers.
(define exception-all-runtime-helpers
  (append bootstrap-error-runtime-only-helpers
          exception-main-runtime-only-helpers))

;; exception-control-runtime-only-helper-names : (listof symbol?)
;;   Keep compiler-special exception control operators runtime-local for now.
(define exception-control-runtime-only-helper-names
  '($call-with-exception-handler:procedure-expected-as-handler
    $call-with-exception-handler:procedure-expected-as-thunk
    $call-with-exception-handler
    $catch:procedure-expected-for-predicate
    $catch:procedure-expected-for-handler
    $catch:procedure-expected-for-thunk
    $catch
    $catch*:procedure-expected-for-predicate
    $catch*:procedure-expected-for-handler
    $catch*:procedure-expected-for-thunk
    $catch*))

;; exception-promoted-main-runtime-helper-names : (listof symbol?)
;;   Promote ordinary exception helpers while leaving special control operators local.
(define exception-promoted-main-runtime-helper-names
  (remove* exception-control-runtime-only-helper-names
           exception-main-runtime-helper-names))

;; exception-core-runtime-helper-names : (listof symbol?)
;;   Name exception helpers available in the standalone core runtime.
(define exception-core-runtime-helper-names
  (remove-duplicates
   (append
    '($raise-input-port-closed
      $raise
      $kernel-exn-struct-type
      $invoke-kernel-exn-struct
      $ensure-exn-type
      $exn-ensure
      $ensure-exn:break-type
      $ensure-exn:break:hang-up-type
      $ensure-exn:break:terminate-type
      $exn/make
      $exn:break/make
      $exn:break:hang-up/make
      $exn:break:terminate/make
      $ensure-exn:fail-type
      $ensure-exn:fail:contract-type
      $ensure-exn:fail:contract:arity-type
      $ensure-exn:fail:contract:continuation-type
      $ensure-exn:fail:contract:divide-by-zero-type
      $ensure-exn:fail:contract:non-fixnum-result-type
      $ensure-exn:fail:contract:variable-type
      $ensure-exn:fail:filesystem-type
      $exn:fail:contract/make
      $exn:fail:contract:arity/make
      $exn:fail:contract:continuation/make
      $exn:fail:contract:divide-by-zero/make
      $exn:fail:contract:non-fixnum-result/make
      $exn:fail:contract:variable-ensure
      $exn:fail:contract:variable-ensure-id
      $exn:fail:contract:variable/make
      $exn:fail:contract:variable
      $make-exn:fail:contract:variable
      $exn:fail:contract:variable?
      $exn:fail:contract:variable-id
      $exn:fail:filesystem/make
      $ensure-exn:fail:filesystem:exists-type
      $exn:fail:filesystem:exists/make
      $ensure-exn:fail:filesystem:version-type
      $exn:fail:filesystem:version/make
      $ensure-exn:fail:filesystem:errno-type
      $exn:fail:filesystem:errno/make
      $ensure-exn:fail:filesystem:missing-module-type
      $exn:fail:filesystem:missing-module/make
      $ensure-exn:fail:network-type
      $exn:fail:network/make
      $ensure-exn:fail:network:errno-type
      $exn:fail:network:errno/make
      $ensure-exn:fail:user-type
      $exn:fail:user/make
      $make-exn:fail:filesystem
      $raise-vfs-file-error
      $exn:fail:filesystem:errno-ensure-errno
      $ensure-exn:fail:read-type
      $ensure-exn:fail:read:eof-type
      $ensure-exn:fail:read:non-char-type
      $exn:srclocs-property-list
      $exn:fail:read-ensure-srclocs
      $exn:fail:read-ensure
      $exn:fail:read/make
      $exn:fail:read
      $make-exn:fail:read
      $exn:fail:read?
      $exn:fail:read-srclocs
      $exn:srclocs?
      $exn:srclocs-accessor
      $exn:fail:read:eof/make
      $exn:fail:read:eof
      $make-exn:fail:read:eof
      $exn:fail:read:eof?
      $exn:fail:read:non-char/make
      $exn:fail:read:non-char
      $make-exn:fail:read:non-char
      $exn:fail:read:non-char?
      $raise-read-error
      $raise-read-eof-error
      $ensure-exn:fail:syntax-type
      $ensure-exn:fail:syntax:missing-module-type
      $ensure-exn:fail:syntax:unbound-type
      $exn:fail:syntax/make
      $exn:fail:syntax:missing-module/make
      $exn:fail:syntax:unbound/make
      $exn:fail:syntax-ensure-exprs
      $exn?
      $exn-message
      $error
      $raise-result-error
      $raise-arguments-error
      $raise-expected-fixnum)
    bootstrap-error-runtime-only-helper-names
    exception-promoted-main-runtime-helper-names)))

;; exception-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate exception helpers available in the standalone core runtime.
(define exception-core-runtime-helpers
  (select-runtime-helpers (append exception-contract-runtime-only-helpers
                                  exception-all-runtime-helpers)
                          exception-core-runtime-helper-names))

;; exception-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate exception helpers that remain program/runtime-local.
(define exception-runtime-only-helpers
  (remove-runtime-helpers exception-all-runtime-helpers
                          exception-core-runtime-helper-names))

;; exception-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for exception helpers.
(define exception-runtime-only-helper-names
  exception-main-runtime-helper-names)

;; exception-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given exception helper names from a helper index.
(define (exception-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; exception-contract-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render generic contract-error helpers in runtime assembly order.
(define (exception-contract-runtime-helper-forms helper-index)
  (exception-helper-forms helper-index exception-contract-runtime-only-helper-names))

;; bootstrap-error-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render early bootstrap error helpers in runtime assembly order.
(define (bootstrap-error-runtime-helper-forms helper-index)
  (exception-helper-forms helper-index bootstrap-error-runtime-only-helper-names))

;; exception-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render exception, exception-structure, and reader-error helpers in runtime assembly order.
(define (exception-runtime-helper-forms helper-index)
  (exception-helper-forms helper-index exception-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define exception-helper-index
    (make-core-runtime-helper-index
     (append exception-core-runtime-helpers
             (remove-runtime-helpers exception-contract-runtime-only-helpers
                                     exception-core-runtime-helper-names)
             exception-runtime-only-helpers)))

  (check-equal? exception-tag-forms
                '((tag $exn (param (ref eq)))))

  (check-equal? exception-read-primitive-global-names
                '($prim:exn:fail:read-srclocs))

  (check-equal? exception-read-primitive-global-forms
                '((global $prim:exn:fail:read-srclocs
                         (mut (ref eq))
                         (global.get $undefined))))

  (check-equal?
   (map form-name (exception-contract-runtime-helper-forms exception-helper-index))
   exception-contract-runtime-only-helper-names)

  (check-equal?
   (map form-name (bootstrap-error-runtime-helper-forms exception-helper-index))
   bootstrap-error-runtime-only-helper-names)

  (check-equal?
   (map form-name (exception-runtime-helper-forms exception-helper-index))
   exception-runtime-only-helper-names))
