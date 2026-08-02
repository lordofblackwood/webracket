#lang racket

(provide multiple-value-runtime-helper-forms
         value-expectation-runtime-helper-forms
         continuation-runtime-helper-forms
         continuation-mark-runtime-helper-forms
         control-flow-runtime-string-constants
         control-flow-core-runtime-helpers
         multiple-value-runtime-symbol-constants
         continuation-runtime-symbol-constants
         control-flow-runtime-only-helpers)

(require "../core-helper.rkt")

;; control-flow-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by control-flow helpers.
(define control-flow-runtime-string-constants
  '((dynamic-require-unsupported "dynamic-require: dynamic module loading is not supported")
    (dynamic-require-failure-thunk "(or/c 'error (-> any))")
    (continuation-mark-set-or-false "(or/c continuation-mark-set? #f)")
    (continuation-prompt-tag? "continuation-prompt-tag?")
    (continuation? "continuation?")
    (procedure-arity-0 "(procedure-arity-includes/c 0)")
    (procedure-arity-1 "(procedure-arity-includes/c 1)")
    (value-result-arity-error:start
     "result arity mismatch;\n expected number of values not received\n  expected: ")
    (value-result-arity-error:received "\n  received: ")))

;; multiple-value-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for multiple-value helpers.
(define multiple-value-runtime-only-helper-names
  '($values
    $call-with-values))

;; value-expectation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for multiple-value expectation helpers.
(define value-expectation-runtime-only-helper-names
  '($raise-wrong-number-of-values-received
    $expect-zero-values
    $expect-one-value
    $expect-n-values))

;; multiple-value-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by multiple-value helpers.
(define multiple-value-runtime-symbol-constants
  '(values
    call-with-values))

;; continuation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for continuation helpers.
(define continuation-runtime-only-helper-names
  '($invoke-escape-continuation
    $check-procedure-arity/who
    $call-thunk/who
    $call-thunk
    $dynamic-wind
    $dynamic-require
    $call-with-continuation-barrier
    $call-with-escape-continuation
    $unsafe-root-continuation-prompt-tag))

;; continuation-mark-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for continuation-mark helpers.
(define continuation-mark-runtime-only-helper-names
  '($call-with-immediate-continuation-mark
    $make-continuation-mark-key
    $continuation-mark-key?
    $current-continuation-marks
    $continuation-mark-set?
    $continuation-prompt-available?
    $continuation-prompt-tag?
    $continuation?
    $continuation-mark-set-first))

;; continuation-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by continuation and continuation-mark helpers.
(define continuation-runtime-symbol-constants
  '(continuation-mark-set?
    continuation-mark-set-first
    current-continuation-marks
    continuation-prompt-available?
    continuation-prompt-tag?
    continuation?
    root-continuation-prompt-tag
    dynamic-wind
    dynamic-require
    call-with-continuation-barrier
    call-with-escape-continuation
    call-with-immediate-continuation-mark))

;; control-flow-helper-source : symbol? -> symbol?
;;   Return the helper source used when preserving monolithic control-flow order.
(define (control-flow-helper-source name)
  (if (hash-ref control-flow-core-runtime-helper-name-set name #f)
      'core
      'runtime))

;; control-flow-helper-forms : hasheq? hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given control-flow helper names from runtime-local or core indexes.
(define (control-flow-helper-forms runtime-helper-index core-runtime-helper-index names)
  (for/list ([name (in-list names)])
    (case (control-flow-helper-source name)
      [(core)    (core-runtime-helper-form core-runtime-helper-index name)]
      [(runtime) (core-runtime-helper-form runtime-helper-index name)]
      [else      (error 'control-flow-helper-forms
                        "unknown helper source for: ~a"
                        name)])))

;; value-expectation-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render multiple-value expectation helpers in runtime assembly order.
(define (value-expectation-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (control-flow-helper-forms runtime-helper-index
                             core-runtime-helper-index
                             value-expectation-runtime-only-helper-names))

;; multiple-value-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render multiple-value helpers in runtime assembly order.
(define (multiple-value-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (control-flow-helper-forms runtime-helper-index
                             core-runtime-helper-index
                             multiple-value-runtime-only-helper-names))

;; continuation-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render continuation helpers in runtime assembly order.
(define (continuation-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (control-flow-helper-forms runtime-helper-index
                             core-runtime-helper-index
                             continuation-runtime-only-helper-names))

;; continuation-mark-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render continuation-mark helpers in runtime assembly order.
(define (continuation-mark-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (control-flow-helper-forms runtime-helper-index
                             core-runtime-helper-index
                             continuation-mark-runtime-only-helper-names))

;; value-expectation-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate multiple-value expectation helpers used by compiler output.
(define value-expectation-runtime-only-helpers
  (function-forms->runtime-helpers
   'value-expectation-runtime-only-helpers
   '(
     (func $raise-wrong-number-of-values-received
           (param $expected i32)
           (param $received i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 4)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:value-result-arity-error:start))
           (call $growable-array-add! (local.get $out)
                 (call $i32->string (local.get $expected)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:value-result-arity-error:received))
           (call $growable-array-add! (local.get $out)
                 (call $i32->string (local.get $received)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (call $raise
                 (call $exn:fail:contract:arity/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $expect-zero-values
           (param $v (ref eq))
           (result (ref eq))
           (if (result (ref eq))
               (ref.test (ref $Values) (local.get $v))
               (then
                (if (i32.eqz
                     (i32.eq
                      (array.len (ref.cast (ref $Values) (local.get $v)))
                      (i32.const 0)))
                    (then (call $raise-wrong-number-of-values-received
                                (i32.const 0)
                                (array.len (ref.cast (ref $Values) (local.get $v))))
                          (unreachable)))
                (global.get $void))
               (else
                (call $raise-wrong-number-of-values-received
                      (i32.const 0)
                      (i32.const 1))
                (unreachable))))

     (func $expect-one-value
           (param $v (ref eq))
           (result (ref eq))
           (if (result (ref eq))
               (ref.test (ref $Values) (local.get $v))
               (then
                (if (i32.eqz
                     (i32.eq
                      (array.len (ref.cast (ref $Values) (local.get $v)))
                      (i32.const 1)))
                    (then (call $raise-wrong-number-of-values-received
                                (i32.const 1)
                                (array.len (ref.cast (ref $Values) (local.get $v))))
                          (unreachable)))
                (array.get $Values
                           (ref.cast (ref $Values) (local.get $v))
                           (i32.const 0)))
               (else
                (local.get $v))))

     (func $expect-n-values
           (param $v (ref eq))
           (param $n i32)
           (result (ref $Values))
           (if (result (ref $Values))
               (ref.test (ref $Values) (local.get $v))
               (then
                (if (i32.eqz
                     (i32.eq
                      (array.len (ref.cast (ref $Values) (local.get $v)))
                      (local.get $n)))
                    (then (call $raise-wrong-number-of-values-received
                                (local.get $n)
                                (array.len (ref.cast (ref $Values) (local.get $v))))
                          (unreachable)))
                (ref.cast (ref $Values) (local.get $v)))
               (else
                (call $raise-wrong-number-of-values-received
                      (local.get $n)
                      (i32.const 1))
                (unreachable))))
     )))

;; control-flow-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate control-flow helpers used by the monolithic runtime.
(define control-flow-all-runtime-helpers
  (append
   value-expectation-runtime-only-helpers
   (function-forms->runtime-helpers
    'control-flow-runtime-only-helpers
    '(
     (func $values (type $Prim>=0)
           (param $args (ref eq))
           (result      (ref eq))

           (local $use-args? i32)
           (local $as        (ref $Args))
           (local $arr       (ref $Array))
           (local $len       i32)
           (local $vals      (ref $Values))

           ;; Initialize non-defaultable locals.
           (local.set $as   (array.new $Args (global.get $null) (i32.const 0)))
           (local.set $arr  (call $make-array (i32.const 0) (global.get $null)))
           (local.set $vals (array.new $Values (global.get $null) (i32.const 0)))
           (local.set $len  (i32.const 0))

           ;; Determine whether the rest arguments are in an $Args array or a list.
           (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
           (if (local.get $use-args?)
               ;; -- $Args case --
               (then
                (local.set $as  (ref.cast (ref $Args) (local.get $args)))
                (local.set $len (array.len (local.get $as)))
                ;; Single argument -> return it directly.
                (if (i32.eq (local.get $len) (i32.const 1))
                    (then (return (array.get $Args (local.get $as) (i32.const 0)))))
                ;; No arguments -> return an empty $Values array (zero values).
                (if (i32.eqz (local.get $len))
                    (then (return (local.get $vals))))
                ;; Multiple arguments -> pack them into a new $Values array.
                (local.set $vals (array.new $Values (global.get $null) (local.get $len)))
                (array.copy $Values $Args
                            (local.get $vals) (i32.const 0)
                            (local.get $as)  (i32.const 0)
                            (local.get $len)))
               ;; -- list case --
               (else
                (local.set $arr (call $list->array (local.get $args)))
                (local.set $len (array.len (local.get $arr)))
                ;; Single argument -> return it directly.
                (if (i32.eq (local.get $len) (i32.const 1))
                    (then (return (array.get $Array (local.get $arr) (i32.const 0)))))
                ;; No arguments -> return an empty $Values array (zero values).
                (if (i32.eqz (local.get $len))
                    (then (return (local.get $vals))))
                ;; Multiple arguments -> pack them into a new $Values array.
                (local.set $vals (array.new $Values (global.get $null) (local.get $len)))
                (array.copy $Values $Array
                            (local.get $vals) (i32.const 0)
                            (local.get $arr) (i32.const 0)
                            (local.get $len))))

           (local.get $vals))


     (func $call-with-values (type $Prim2)
           (param $gen (ref eq))
           (param $rec (ref eq))
           (result     (ref eq))

           (local $g     (ref $Procedure))
           (local $r     (ref $Procedure))
           (local $ginv  (ref $ProcedureInvoker))
           (local $rinv  (ref $ProcedureInvoker))
           (local $vals  (ref eq))
           (local $vals* (ref $Values))
           (local $args  (ref $Args))
           (local $n     i32)

           ;; initialize $args to satisfy the validator; overwritten later
           (local.set $args (array.new $Args (global.get $null) (i32.const 0)))

           ;; Step 1: type check generator
           (if (ref.eq (call $procedure? (local.get $gen))
                         (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:call-with-values)
                           (local.get $gen))
                     (unreachable)))
           (local.set $g    (ref.cast (ref $Procedure) (local.get $gen)))

           ;; Step 2: type check receiver
           (if (ref.eq (call $procedure? (local.get $rec))
                         (global.get $false))
               (then (call $raise-argument-error:procedure-expected/who
                           (global.get $symbol:call-with-values)
                           (local.get $rec))
                     (unreachable)))
           (local.set $r    (ref.cast (ref $Procedure) (local.get $rec)))

           ;; Step 3: call generator with zero arguments
           (local.set $ginv (struct.get $Procedure $invoke (local.get $g)))
           (local.set $vals
                      (call_ref $ProcedureInvoker
                                (local.get $g)
                                (array.new $Args (global.get $null) (i32.const 0))
                                (local.get $ginv)))

           ;; Step 4: unpack returned values into argument array
           (if (ref.test (ref $Values) (local.get $vals))
               (then (local.set $vals* (ref.cast (ref $Values) (local.get $vals)))
                     (local.set $n     (array.len (local.get $vals*)))
                     (local.set $args  (array.new $Args (global.get $null) (local.get $n)))
                     (array.copy $Args $Values
                                 (local.get $args) (i32.const 0)
                                 (local.get $vals*) (i32.const 0)
                                 (local.get $n)))
               (else (local.set $args (array.new_fixed $Args 1 (local.get $vals)))))

           ;; Step 5: call receiver in tail position
           (local.set $rinv (struct.get $Procedure $invoke (local.get $r)))
           (return_call_ref $ProcedureInvoker
                            (local.get $r)
                            (local.get $args)
                            (local.get $rinv)))

     ;; invoke-escape-continuation : procedure-invoker
     ;;   Throw a private payload that call-with-escape-continuation catches.
     (func $invoke-escape-continuation (type $ProcedureInvoker)
           (param $proc (ref $Procedure))
           (param $args (ref $Args))
           (result      (ref eq))
           (throw $exn
                  (struct.new $EscapeContinuationJump
                              (i32.const 0)
                              (call $values (local.get $args))))
           (unreachable))

     ;; check-procedure-arity/who : symbol? string? any/c i32 -> procedure?
     ;;   Validate a public procedure arity contract and return the procedure.
     (func $check-procedure-arity/who
           (param $who      (ref eq))
           (param $expected (ref eq))
           (param $proc-raw (ref eq))
           (param $arity    i32)
           (result          (ref $Procedure))

           (local $proc (ref $Procedure))

           (if (ref.eq (call $procedure? (local.get $proc-raw))
                         (global.get $false))
               (then (call $raise-argument-error1
                           (local.get $who)
                           (local.get $expected)
                           (local.get $proc-raw))
                     (unreachable)))
           (local.set $proc (ref.cast (ref $Procedure) (local.get $proc-raw)))
           (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                              (local.get $proc)
                              (local.get $arity)))
               (then (call $raise-argument-error1
                           (local.get $who)
                           (local.get $expected)
                           (local.get $proc-raw))
                     (unreachable)))
           (local.get $proc))

     ;; $call-thunk/who : symbol? string? procedure? -> any/c
     ;;   Invoke a zero-argument procedure after public contract validation.
     (func $call-thunk/who
           (param $who       (ref eq))
           (param $expected  (ref eq))
           (param $thunk-raw (ref eq))
           (result           (ref eq))

           (local $thunk (ref $Procedure))
           (local $inv   (ref $ProcedureInvoker))

           (local.set $thunk
                      (call $check-procedure-arity/who
                            (local.get $who)
                            (local.get $expected)
                            (local.get $thunk-raw)
                            (i32.const 0)))
           (local.set $inv (struct.get $Procedure $invoke (local.get $thunk)))
           (call_ref $ProcedureInvoker
                     (local.get $thunk)
                     (array.new $Args (global.get $null) (i32.const 0))
                     (local.get $inv)))

     ;; $call-thunk : procedure? -> any/c
     ;;   Invoke a zero-argument procedure.
     (func $call-thunk
           (param $thunk-raw (ref eq)) ;; procedure?
           (result           (ref eq))

           (local $thunk (ref $Procedure))
           (local $inv   (ref $ProcedureInvoker))

           (if (ref.eq (call $procedure? (local.get $thunk-raw))
                         (global.get $false))
               (then (call $raise-argument-error:procedure-expected (local.get $thunk-raw))
                     (unreachable)))
           (local.set $thunk (ref.cast (ref $Procedure) (local.get $thunk-raw)))
           (local.set $inv   (struct.get $Procedure $invoke (local.get $thunk)))
           (call_ref $ProcedureInvoker
                     (local.get $thunk)
                     (array.new $Args (global.get $null) (i32.const 0))
                     (local.get $inv)))

     ;; dynamic-wind : (-> any/c) (-> any/c) (-> any/c) -> any/c
     ;;   Run before/body/after with exception-safe cleanup. This first
     ;;   WebRacket slice does not model continuation jumps, but it covers
     ;;   the expander namespace registry's lock discipline.
     (func $dynamic-wind (type $Prim3)
           (param $before (ref eq)) ;; before thunk
           (param $body   (ref eq)) ;; body thunk
           (param $after  (ref eq)) ;; after thunk
           (result        (ref eq))

           (local $res     (ref eq))
           (local $exn-val (ref eq))

           (drop (call $call-thunk/who
                       (global.get $symbol:dynamic-wind)
                       (global.get $string:procedure-arity-0)
                       (local.get $before)))
           (local.set $res
                      (block $done (result (ref eq))
                        (block $handler-block (result (ref eq))
                          (try_table (result (ref eq))
                                     (catch $exn $handler-block)
                                     (call $call-thunk/who
                                           (global.get $symbol:dynamic-wind)
                                           (global.get $string:procedure-arity-0)
                                           (local.get $body))
                                     (br $done)))
                        (local.set $exn-val)
                        (drop (call $call-thunk/who
                                    (global.get $symbol:dynamic-wind)
                                    (global.get $string:procedure-arity-0)
                                    (local.get $after)))
                        (throw $exn (local.get $exn-val))
                        (unreachable)))
           (drop (call $call-thunk/who
                       (global.get $symbol:dynamic-wind)
                       (global.get $string:procedure-arity-0)
                       (local.get $after)))
           (local.get $res))

     ;; dynamic-require : module-path? (or/c symbol? #f 0) [(-> any/c)] -> any/c
     ;;   WebRacket does not support runtime dynamic module loading yet.
     ;;   When callers supply the optional failure thunk, use it as the
     ;;   documented fallback; otherwise raise an unsupported-operation
     ;;   error. The module path and requested name are intentionally not
     ;;   interpreted in this bootstrap primitive.
     (func $dynamic-require (type $Prim23)
           (param $mod-path      (ref eq)) ;; module-path?; currently ignored
           (param $name          (ref eq)) ;; symbol?, #f, or 0; currently ignored
           (param $failure-thunk (ref eq)) ;; optional thunk, default = #f
           (result               (ref eq))

           (if (ref.eq (local.get $failure-thunk) (global.get $missing))
               (then (local.set $failure-thunk (global.get $false))))
           (if (ref.eq (local.get $failure-thunk) (global.get $false))
               (then
                (drop (call $raise
                            (call $exn:fail:unsupported/make
                                  (global.get $string:dynamic-require-unsupported)
                                  (call $current-continuation-marks
                                        (global.get $missing)))
                            (global.get $true)))
                (unreachable)))
           (if (result (ref eq))
               (ref.eq (call $procedure? (local.get $failure-thunk)) (global.get $true))
               (then
                (call $call-thunk/who
                      (global.get $symbol:dynamic-require)
                      (global.get $string:dynamic-require-failure-thunk)
                      (local.get $failure-thunk)))
               (else
                (call $raise-argument-error1
                      (global.get $symbol:dynamic-require)
                      (global.get $string:dynamic-require-failure-thunk)
                      (local.get $failure-thunk))
                (unreachable))))

     ;; call-with-continuation-barrier : (-> any/c) -> any/c
     ;;   Bootstrap approximation for the expander: WebRacket currently
     ;;   has no first-class continuation jumps, so there is no barrier to
     ;;   enforce yet. If call/cc or prompt abort support is reinstated,
     ;;   this must become a real delimiter for continuation jumps.
     (func $call-with-continuation-barrier (type $Prim1)
           (param $thunk (ref eq)) ;; procedure?
           (result       (ref eq))
           (call $call-thunk/who
                 (global.get $symbol:call-with-continuation-barrier)
                 (global.get $string:procedure-arity-0)
                 (local.get $thunk)))

     ;; call-with-escape-continuation : ((procedure? -> any/c) -> any/c) -> any/c
     ;;   Bootstrap implementation using a private Wasm exception. This
     ;;   supports the expander's `let/ec` patterns, including early return
     ;;   through the current call. It is still not a full Racket escape
     ;;   continuation: the escape procedure is not dynamically invalidated
     ;;   after return, and real continuation prompts/barriers are deferred.
     (func $call-with-escape-continuation (type $Prim1)
           (param $proc-raw (ref eq)) ;; procedure?
           (result          (ref eq))

           (local $proc    (ref $Procedure))
           (local $inv     (ref $ProcedureInvoker))
           (local $exn-val (ref eq))
           (local $jump    (ref $EscapeContinuationJump))

           (local.set $proc (global.get $dummy-closure))
           (local.set $inv  (ref.func $invoke-closure))
           (local.set $exn-val (global.get $false))
           (local.set $jump
                      (struct.new $EscapeContinuationJump
                                  (i32.const 0)
                                  (global.get $false)))

           (local.set $proc
                      (call $check-procedure-arity/who
                            (global.get $symbol:call-with-escape-continuation)
                            (global.get $string:procedure-arity-1)
                            (local.get $proc-raw)
                            (i32.const 1)))
           (local.set $inv  (struct.get $Procedure $invoke (local.get $proc)))
           (block $done (result (ref eq))
             (block $handler-block (result (ref eq))
               (try_table (result (ref eq))
                          (catch $exn $handler-block)
                          (call_ref $ProcedureInvoker
                                    (local.get $proc)
                                    (array.new_fixed $Args
                                                     1
                                                     (global.get $escape-continuation-closure))
                                    (local.get $inv))
                          (br $done)))
             (local.set $exn-val)
             (if (ref.test (ref $EscapeContinuationJump) (local.get $exn-val))
                 (then
                  (local.set $jump
                             (ref.cast (ref $EscapeContinuationJump)
                                       (local.get $exn-val)))
                  (return (struct.get $EscapeContinuationJump $value (local.get $jump)))))
             (throw $exn (local.get $exn-val))
             (unreachable)))

     ;; unsafe-root-continuation-prompt-tag : -> any/c
     ;;   Stable root prompt-tag placeholder. WebRacket does not implement
     ;;   continuation prompts yet, but expander startup code can obtain and
     ;;   compare this value without exercising prompt control behavior.
     (func $unsafe-root-continuation-prompt-tag (type $Prim0)
           (result (ref eq))
           (global.get $symbol:root-continuation-prompt-tag))

     ;; call-with-immediate-continuation-mark : any/c (any/c -> any/c) [any/c] -> any/c
     ;;   WebRacket currently erases with-continuation-mark frames, so the
     ;;   current frame has no mark to inspect. Follow the Reference's
     ;;   "not found" behavior and tail-call proc with default-v, whose
     ;;   optional default is #f.
     (func $call-with-immediate-continuation-mark (type $Prim23)
           (param $key       (ref eq)) ;; any/c, ignored until real marks exist
           (param $proc-raw  (ref eq)) ;; procedure?
           (param $default-v (ref eq)) ;; optional any/c, default = #f
           (result           (ref eq))

           (local $proc (ref $Procedure))
           (local $inv  (ref $ProcedureInvoker))
           (local $arg  (ref eq))

           (local.set $proc
                      (call $check-procedure-arity/who
                            (global.get $symbol:call-with-immediate-continuation-mark)
                            (global.get $string:procedure-arity-1)
                            (local.get $proc-raw)
                            (i32.const 1)))
           (local.set $inv  (struct.get $Procedure $invoke (local.get $proc)))
           (local.set $arg
                      (if (result (ref eq))
                          (ref.eq (local.get $default-v) (global.get $missing))
                          (then (global.get $false))
                          (else (local.get $default-v))))
           (return_call_ref $ProcedureInvoker
                            (local.get $proc)
                            (array.new_fixed $Args 1 (local.get $arg))
                            (local.get $inv)))

     ;; make-continuation-mark-key : [symbol?] -> continuation-mark-key?
     ;;   Allocate a fresh opaque key. The optional symbol defaults to #f
     ;;   in WebRacket for now; Racket uses it only for printing.
     (func $make-continuation-mark-key (type $Prim01)
           (param $name-raw (ref eq)) ;; optional symbol?, default = fresh print name
           (result          (ref eq))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $name-raw) (global.get $missing)))
                (i32.eqz (ref.test (ref $Symbol) (local.get $name-raw))))
               (then (call $raise-argument-error1
                           (global.get $symbol:make-continuation-mark-key)
                           (global.get $string:symbol?)
                           (local.get $name-raw))
                     (unreachable)))
           (struct.new $ContinuationMarkKey
                       (i32.const 0)
                       (if (result (ref eq))
                           (ref.eq (local.get $name-raw) (global.get $missing))
                           (then (global.get $false))
                           (else (local.get $name-raw)))))

     ;; continuation-mark-key? : any/c -> boolean?
     ;;   Recognize keys allocated by make-continuation-mark-key.
     (func $continuation-mark-key? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $ContinuationMarkKey) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     ;; current-continuation-marks : [continuation-prompt-tag?] -> continuation-mark-set?
     (func $current-continuation-marks (type $Prim01)
           ;; prompt-tag : continuation-prompt-tag? (optional, default = (default-continuation-prompt-tag))
           ;; NOTE: WebRacket currently lacks continuation marks, so this
           ;; stub returns a fresh empty mark set. Reinstating real marks
           ;; matters for mark-sensitive error reporting and protocols.
           (param $prompt-tag (ref eq))
           (result            (ref eq))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $prompt-tag) (global.get $missing)))
                (ref.eq (call $continuation-prompt-tag? (local.get $prompt-tag))
                        (global.get $false)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-continuation-marks)
                           (global.get $string:continuation-prompt-tag?)
                           (local.get $prompt-tag))
                     (unreachable)))
           (struct.new $ContinuationMarkSet (i32.const 0)))

     ;; continuation-mark-set? : any/c -> boolean?
     ;;   Recognize WebRacket's opaque empty mark-set placeholder.
     (func $continuation-mark-set? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.test (ref $ContinuationMarkSet) (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     ;; continuation-prompt-available? : continuation-prompt-tag? [continuation?] -> boolean?
     ;;   WebRacket does not implement prompt control yet. Returning #t is
     ;;   the permissive bootstrap choice for libraries that merely check
     ;;   whether an exception/control prompt is installed before raising.
     (func $continuation-prompt-available? (type $Prim12)
           (param $prompt-tag (ref eq)) ;; continuation-prompt-tag?
           (param $cont       (ref eq)) ;; optional continuation?
           (result            (ref eq))
           (if (ref.eq (call $continuation-prompt-tag? (local.get $prompt-tag))
                       (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:continuation-prompt-available?)
                           (global.get $string:continuation-prompt-tag?)
                           (local.get $prompt-tag))
                     (unreachable)))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $cont) (global.get $missing)))
                (ref.eq (call $continuation? (local.get $cont))
                        (global.get $false)))
               (then (call $raise-argument-error1
                           (global.get $symbol:continuation-prompt-available?)
                           (global.get $string:continuation?)
                           (local.get $cont))
                     (unreachable)))
           (global.get $true))

     ;; continuation-prompt-tag? : any/c -> boolean?
     ;;   Recognize WebRacket's stable root prompt placeholder. Full prompt
     ;;   tag allocation should introduce a distinct prompt-tag type later.
     (func $continuation-prompt-tag? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (result (ref eq))
               (ref.eq (local.get $v) (global.get $symbol:root-continuation-prompt-tag))
               (then (global.get $true))
               (else (global.get $false))))

     ;; continuation? : any/c -> boolean?
     ;;   WebRacket does not expose first-class continuations yet.
     (func $continuation? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (global.get $false))

     ;; continuation-mark-set-first : continuation-mark-set? any/c [any/c] [continuation-prompt-tag?] -> any/c
     ;;   Bootstrap-only approximation used while bringing up the Racket
     ;;   expander. Since `with-continuation-mark*` is currently erased by
     ;;   Webify, there is no mark stack to inspect. Returning the
     ;;   caller's `none-v` value (default #f) matches Racket's "not found"
     ;;   convention closely enough for startup probes, but real
     ;;   continuation marks should replace this before relying on
     ;;   mark-sensitive error reporting or dynamic protocols.
     (func $continuation-mark-set-first (type $Prim24)
           (param $marks      (ref eq)) ;; continuation-mark-set? or #f
           (param $key        (ref eq)) ;; any/c
           (param $none-v     (ref eq)) ;; optional any/c, default = #f
           (param $prompt-tag (ref eq)) ;; optional continuation-prompt-tag?
           (result            (ref eq))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $marks) (global.get $false)))
                (ref.eq (call $continuation-mark-set? (local.get $marks))
                        (global.get $false)))
               (then (call $raise-argument-error1
                           (global.get $symbol:continuation-mark-set-first)
                           (global.get $string:continuation-mark-set-or-false)
                           (local.get $marks))
                     (unreachable)))
           (if (i32.and
                (i32.eqz (ref.eq (local.get $prompt-tag) (global.get $missing)))
                (ref.eq (call $continuation-prompt-tag? (local.get $prompt-tag))
                        (global.get $false)))
               (then (call $raise-argument-error1
                           (global.get $symbol:continuation-mark-set-first)
                           (global.get $string:continuation-prompt-tag?)
                           (local.get $prompt-tag))
                     (unreachable)))
           (if (ref.eq (local.get $key) (global.get $parameterization-key))
               (then (return (global.get $current-parameterization-value))))
           (if (result (ref eq))
               (ref.eq (local.get $none-v) (global.get $missing))
               (then (global.get $false))
           (else (local.get $none-v))))))))

;; control-flow-core-runtime-helper-names : (listof symbol?)
;;   Name control-flow helpers available in the standalone core runtime.
(define control-flow-core-runtime-helper-names
  (append value-expectation-runtime-only-helper-names
          multiple-value-runtime-only-helper-names
          '($invoke-escape-continuation
            $check-procedure-arity/who
            $call-thunk/who
            $call-thunk
            $dynamic-wind
            $dynamic-require
            $call-with-continuation-barrier
            $unsafe-root-continuation-prompt-tag)
          continuation-mark-runtime-only-helper-names))

;; control-flow-core-runtime-helper-name-set : hasheq?
;;   Index control-flow helpers available in the standalone core runtime.
(define control-flow-core-runtime-helper-name-set
  (for/hasheq ([name (in-list control-flow-core-runtime-helper-names)])
    (values name #t)))

;; control-flow-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate control-flow helpers available in the standalone core runtime.
(define control-flow-core-runtime-helpers
  (select-runtime-helpers control-flow-all-runtime-helpers
                          control-flow-core-runtime-helper-names))

;; control-flow-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate control-flow helpers that remain program/runtime-local.
(define control-flow-runtime-only-helpers
  (remove-runtime-helpers control-flow-all-runtime-helpers
                          control-flow-core-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define control-flow-helper-index
    (make-core-runtime-helper-index
     (append control-flow-core-runtime-helpers
             control-flow-runtime-only-helpers)))

  (check-equal?
   (map form-name
        (value-expectation-runtime-helper-forms control-flow-helper-index
                                                control-flow-helper-index))
   value-expectation-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (multiple-value-runtime-helper-forms control-flow-helper-index
                                             control-flow-helper-index))
   multiple-value-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (continuation-runtime-helper-forms control-flow-helper-index
                                           control-flow-helper-index))
   continuation-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (continuation-mark-runtime-helper-forms control-flow-helper-index
                                                control-flow-helper-index))
   continuation-mark-runtime-only-helper-names))
