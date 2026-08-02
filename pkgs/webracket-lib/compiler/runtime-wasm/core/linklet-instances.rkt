#lang racket

(provide linklet-instance-runtime-only-helper-names
         linklet-instance-core-runtime-helpers
         linklet-instance-core-runtime-helper-forms
         linklet-instance-runtime-helper-forms
         linklet-instance-runtime-string-constants
         linklet-instance-runtime-symbol-constants
         linklet-instance-runtime-only-helpers)

(require "../core-helper.rkt")

;; linklet-instance-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by linklet instance and module-variable helpers.
(define linklet-instance-runtime-string-constants
  '((instance?                     "instance?")
    (missing-variable-value        "missing variable value")
    (missing-binding               "missing binding:")
    (link:missing-binding          "link: missing binding\n  name: ")
    (instance-variable-box:missing-binding
     "instance-variable-box: missing binding\n  name: ")
    (instance-variable-not-found   "instance variable not found:")
    (instance-variable-value:not-found
     "instance-variable-value: instance variable not found\n  name: ")
    (cannot-modify-constant        "cannot modify a constant")
    (at-most-one-optional-argument "expected at most one optional argument")
    (instance-mode?                "(or/c #f 'constant 'consistent)")
    (module-variable?              "module-variable?")
    (module-variable-reference?    "module-variable-reference?")
    (module-variable-same-length-vectors
     "value vector with the same length as the cell vector")
    (module-prompts-unsupported
     "module-call-with-prompt: module prompts are not supported by WebRacket yet")))

;; linklet-instance-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by linklet instance mutation modes.
(define linklet-instance-runtime-symbol-constants
  '(constant
    consistent
    instance
    instance-name
    instance-data
    instance-variable-box
    instance-variable-names
    instance-variable-value
    instance-set-variable-value!
    instance-unset-variable!
    make-instance))

;; make-predicate-body : symbol? -> (listof datum?)
;;   Generate a standard WebRacket predicate body for ref-type.
(define (make-predicate-body ref-type)
  `((param $v (ref eq))
    (result   (ref eq))
    (if (result (ref eq))
        (ref.test (ref ,ref-type) (local.get $v))
        (then (global.get $true))
        (else (global.get $false)))))

;; linklet-instance-runtime-only-forms : (listof datum?)
;;   Enumerate linklet instance and module-variable helpers.
(define linklet-instance-runtime-only-forms
  `(
         ;; Instances

         (func $raise-argument-error:instance-expected
               (param $got (ref eq))   ;; value that was not an instance

               (call $raise-argument-error1
                     (global.get $symbol:instance)
                     (global.get $string:instance?)
                     (local.get $got))
               (unreachable))

         (func $raise-make-instance-missing-value
               (param $sym (ref eq))   ;; offending variable name

               (call $raise-argument-error1
                     (global.get $symbol:make-instance)
                     (global.get $string:missing-variable-value)
                     (local.get $sym))
               (unreachable))

         (func $raise-linklet-variable-error
               (param $prefix (ref eq)) ;; message prefix
               (param $sym    (ref eq)) ;; missing symbol

               (call $raise
                     (call $exn:fail:contract:variable/make
                           (call $string-append/2
                                 (local.get $prefix)
                                 (call $format/print
                                       (local.get $sym)
                                       (global.get $missing)))
                           (call $current-continuation-marks (global.get $missing))
                           (local.get $sym))
                     (global.get $true))
               (unreachable))

         (func $raise-link-missing-binding
               (param $sym (ref eq))   ;; missing symbol

               (call $raise-linklet-variable-error
                     (global.get $string:link:missing-binding)
                     (local.get $sym)))

         (func $raise-instance-variable-box-missing-binding
               (param $sym (ref eq))   ;; missing symbol

               (call $raise-linklet-variable-error
                     (global.get $string:instance-variable-box:missing-binding)
                     (local.get $sym)))

         (func $raise-instance-variable-not-found
               (param $sym (ref eq))   ;; missing symbol

               (call $raise-linklet-variable-error
                     (global.get $string:instance-variable-value:not-found)
                     (local.get $sym)))

         (func $raise-instance-variable-constant
               (param $sym (ref eq))   ;; constant symbol

               (call $raise-argument-error1
                     (global.get $symbol:instance-set-variable-value!)
                     (global.get $string:cannot-modify-constant)
                     (local.get $sym))
               (unreachable))

         (func $raise-instance-optional-argument
               (param $who  (ref eq))  ;; symbol naming the primitive
               (param $rest (ref eq))  ;; unexpected arguments

               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:at-most-one-optional-argument)
                     (local.get $rest))
               (unreachable))

         (func $instance? (type $Prim1)
               (param $v (ref eq))  ;; value to check
               (result   (ref eq))

               (if (result (ref eq))
                   (ref.test (ref $Instance) (local.get $v))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $instance-name (type $Prim1)
               (param $inst (ref eq))  ;; instance
               (result (ref eq))

               (local $instance (ref $Instance))

               (if (i32.eqz (ref.test (ref $Instance) (local.get $inst)))
                   (then (call $raise-argument-error:instance-expected (local.get $inst))
                         (unreachable)))
               (local.set $instance (ref.cast (ref $Instance) (local.get $inst)))
               (struct.get $Instance $name (local.get $instance)))

         (func $instance-data (type $Prim1)
               (param $inst (ref eq))  ;; instance
               (result (ref eq))

               (local $instance (ref $Instance))

               (if (i32.eqz (ref.test (ref $Instance) (local.get $inst)))
                   (then (call $raise-argument-error:instance-expected (local.get $inst))
                         (unreachable)))
               (local.set $instance (ref.cast (ref $Instance) (local.get $inst)))
               (struct.get $Instance $data (local.get $instance)))

         (func $make-instance (type $Prim>=1)
               (param $name (ref eq))  ;; instance name
               (param $rest (ref eq))  ;; [data #f] [mode #f] variable bindings
               (result (ref eq))

               (local $data     (ref eq))
               (local $mode     (ref eq))
               (local $content  (ref eq))
               (local $node     (ref eq))
               (local $pair     (ref $Pair))
               (local $sym      (ref eq))
               (local $sym-val  (ref $Symbol))
               (local $value    (ref eq))
               (local $inst     (ref $Instance))
               (local $vars     (ref $HashEqMutable))
               (local $constants (ref $HashEqMutable))
               (local $box      (ref $Box))

               (local.set $data (global.get $false))    ;; optional data defaults to #f
               (local.set $mode (global.get $false))    ;; optional mode defaults to #f
               (local.set $content (local.get $rest))

               ;; Extract optional data argument when present.
               (if (ref.eq (local.get $content) (global.get $null))
                   (then (nop))
                   (else
                    (local.set $pair
                               (block $ok (result (ref $Pair))
                                     (br_on_cast $ok (ref eq) (ref $Pair) (local.get $content))
                                     (call $raise-pair-expected (local.get $content))
                                     (unreachable)))
                    (local.set $data (struct.get $Pair $a (local.get $pair)))
                    (local.set $content (struct.get $Pair $d (local.get $pair)))
                    ;; Extract optional mode argument when present.
                    (if (ref.eq (local.get $content) (global.get $null))
                        (then (nop))
                        (else
                         (local.set $pair
                                    (block $ok (result (ref $Pair))
                                          (br_on_cast $ok (ref eq) (ref $Pair) (local.get $content))
                                          (call $raise-pair-expected (local.get $content))
                                          (unreachable)))
                         (local.set $mode (struct.get $Pair $a (local.get $pair)))
                         (local.set $content (struct.get $Pair $d (local.get $pair)))))))

               ;; Racket accepts only the three linklet instance modes here.
               (if (i32.eqz
                    (i32.or (ref.eq (local.get $mode) (global.get $false))
                            (i32.or (ref.eq (local.get $mode) (global.get $symbol:constant))
                                    (ref.eq (local.get $mode) (global.get $symbol:consistent)))))
                   (then (call $raise-argument-error1
                               (global.get $symbol:make-instance)
                               (global.get $string:instance-mode?)
                               (local.get $mode))
                         (unreachable)))

               ;; Allocate the instance and its variable table.
               (local.set $vars (ref.cast (ref $HashEqMutable) (call $make-empty-hasheq)))
               (local.set $constants (ref.cast (ref $HashEqMutable) (call $make-empty-hasheq)))
               (local.set $inst (struct.new $Instance
                                            (i32.const 0)
                                            (local.get $name)
                                            (local.get $data)
                                            (local.get $vars)
                                            (local.get $constants)))

               ;; Populate variables from the remaining content list.
               (local.set $node (local.get $content))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            (local.set $pair
                                       (block $ok (result (ref $Pair))
                                             (br_on_cast $ok (ref eq) (ref $Pair) (local.get $node))
                                             (call $raise-pair-expected (local.get $node))
                                             (unreachable)))
                            (local.set $sym (struct.get $Pair $a (local.get $pair)))
                            (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:make-instance)
                                            (global.get $string:symbol?)
                                            (local.get $sym))
                                      (unreachable)))
                            (local.set $sym-val (ref.cast (ref $Symbol) (local.get $sym)))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (if (ref.eq (local.get $node) (global.get $null))
                                (then (call $raise-make-instance-missing-value (local.get $sym))
                                      (unreachable)))
                            (local.set $pair
                                       (block $ok (result (ref $Pair))
                                             (br_on_cast $ok (ref eq) (ref $Pair) (local.get $node))
                                             (call $raise-pair-expected (local.get $node))
                                             (unreachable)))
                            (local.set $value (struct.get $Pair $a (local.get $pair)))
                            (local.set $node (struct.get $Pair $d (local.get $pair)))
                            (local.set $box
                                       (ref.cast (ref $Box)
                                                 (call $instance-variable-box
                                                       (ref.cast (ref eq) (local.get $inst))
                                                       (local.get $sym-val)
                                                       (global.get $true))))
                            (call $set-box!
                                  (ref.cast (ref eq) (local.get $box))
                                  (local.get $value))
                            (if (i32.eqz (ref.eq (local.get $mode) (global.get $false)))
                                (then (call $hasheq-set!/mutable/checked
                                            (local.get $constants)
                                            (local.get $sym-val)
                                            (global.get $true))))
                            (br $loop)))
               (ref.cast (ref eq) (local.get $inst)))

         (func $instance-variable-names (type $Prim1)
               (param $inst (ref eq))  ;; instance
               (result      (ref eq))

               (local $instance (ref $Instance))
               (local $vars     (ref $HashEqMutable))
               (local $keys     (ref eq))
               (local $acc      (ref eq))
               (local $pair     (ref $Pair))
               (local $key      (ref eq))
               (local $got      (ref eq))
               (local $box      (ref $Box))
               (local $val      (ref eq))

               ;; Type check arguments
               (if (i32.eqz (ref.test (ref $Instance) (local.get $inst)))
                   (then (call $raise-argument-error:instance-expected (local.get $inst))
                         (unreachable)))

               ;; Get all variables in the hash table
               (local.set $instance (ref.cast (ref $Instance) (local.get $inst)))
               (local.set $vars     (struct.get $Instance $variables (local.get $instance)))
               (local.set $keys
                          (call $hasheq-keys
                                (ref.cast (ref eq) (local.get $vars))
                                (global.get $false)))

               ;; Discard unset variables
               (local.set $acc (global.get $null))
               (block $done
                      (loop $loop
                            ; done?
                            (br_if $done (ref.eq (local.get $keys) (global.get $null)))
                            ; get next variable
                            (local.set $pair (ref.cast (ref $Pair) (local.get $keys)))
                            (local.set $key  (struct.get $Pair $a (local.get $pair)))
                            (local.set $keys (struct.get $Pair $d (local.get $pair)))

                            (local.set $got (call $hasheq-ref
                                                  (ref.cast (ref eq) (local.get $vars))
                                                  (local.get $key)
                                                  (global.get $false)))
                            ; is it unset or not?
                            (if (ref.test (ref $Box) (local.get $got))
                                (then
                                 (local.set $box (ref.cast (ref $Box) (local.get $got)))
                                 (local.set $val (struct.get $Box $v (local.get $box)))
                                 (if (i32.eqz (ref.eq (local.get $val) (global.get $undefined)))
                                     (then
                                      (local.set $acc
                                                 (call $cons
                                                       (local.get $key)
                                                       (local.get $acc)))))))
                            (br $loop)))
               (local.get $acc))


         (func $instance-variable-box (type $Prim3)
               (param $inst        (ref eq)) ;; instance
               (param $sym         (ref eq)) ;; symbol
               (param $can-create? (ref eq)) ;; boolean, #f => do not create
               (result             (ref eq))

               (local $instance (ref $Instance))
               (local $symbol   (ref $Symbol))
               (local $vars     (ref $HashEqMutable))
               (local $got      (ref eq))
               (local $box      (ref $Box))
               (local $create?  i32)

               (if (i32.eqz (ref.test (ref $Instance) (local.get $inst)))
                   (then (call $raise-argument-error:instance-expected (local.get $inst))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instance-variable-box)
                               (global.get $string:symbol?)
                               (local.get $sym))
                         (unreachable)))

               (local.set $instance (ref.cast (ref $Instance) (local.get $inst)))
               (local.set $symbol   (ref.cast (ref $Symbol) (local.get $sym)))
               (local.set $vars     (struct.get $Instance $variables (local.get $instance)))
               (local.set $got
                          (call $hasheq-ref
                                (ref.cast (ref eq) (local.get $vars))
                                (local.get $symbol)
                                (global.get $false)))
               (if (ref.test (ref $Box) (local.get $got))
                   (then (return (local.get $got))))
               (local.set $create?
                          (i32.eqz (ref.eq (local.get $can-create?) (global.get $false))))
               (if (i32.eqz (local.get $create?))
                   (then (call $raise-instance-variable-box-missing-binding  (local.get $sym))
                         (unreachable)))
               (local.set $box (ref.cast (ref $Box) (call $box (global.get $undefined))))
               (call $hasheq-set!/mutable/checked
                     (local.get $vars)
                     (local.get $symbol)
                     (ref.cast (ref eq) (local.get $box)))
               (ref.cast (ref eq) (local.get $box)))

         (func $instance-set-variable-value! (type $Prim>=3)
               (param $inst (ref eq))  ;; instance
               (param $sym  (ref eq))  ;; symbol
               (param $val  (ref eq))  ;; value
               (param $rest (ref eq))  ;; optional mode (#f by default)
               (result (ref eq))

               (local $mode     (ref eq))
               (local $pair     (ref $Pair))
               (local $extra    (ref eq))
               (local $instance (ref $Instance))
               (local $constants (ref $HashEqMutable))
               (local $constant? (ref eq))
               (local $box      (ref $Box))

               (if (i32.eqz (ref.test (ref $Instance) (local.get $inst)))
                   (then (call $raise-argument-error:instance-expected (local.get $inst))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instance-set-variable-value!)
                               (global.get $string:symbol?)
                               (local.get $sym))
                         (unreachable)))

               (local.set $mode (global.get $false)) ;; optional mode defaults to #f
               (local.set $extra (local.get $rest))
               (if (ref.eq (local.get $extra) (global.get $null))
                   (then (nop))
                   (else
                    (local.set $pair
                               (block $ok (result (ref $Pair))
                                     (br_on_cast $ok (ref eq) (ref $Pair) (local.get $extra))
                                     (call $raise-pair-expected (local.get $extra))
                                     (unreachable)))
                    (local.set $mode (struct.get $Pair $a (local.get $pair)))
                    (local.set $extra (struct.get $Pair $d (local.get $pair)))
                    (if (ref.eq (local.get $extra) (global.get $null))
                        (then (nop))
                        (else (call $raise-instance-optional-argument
                                    (global.get $symbol:instance-set-variable-value!)
                                    (local.get $extra))
                              (unreachable)))))

               ;; Racket accepts only the three linklet instance modes here.
               (if (i32.eqz
                    (i32.or (ref.eq (local.get $mode) (global.get $false))
                            (i32.or (ref.eq (local.get $mode) (global.get $symbol:constant))
                                    (ref.eq (local.get $mode) (global.get $symbol:consistent)))))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instance-set-variable-value!)
                               (global.get $string:instance-mode?)
                               (local.get $mode))
                         (unreachable)))

               (local.set $instance (ref.cast (ref $Instance) (local.get $inst)))
               (local.set $constants (struct.get $Instance $constants (local.get $instance)))
               (local.set $constant?
                          (call $hasheq-ref
                                (ref.cast (ref eq) (local.get $constants))
                                (local.get $sym)
                                (global.get $false)))
               ;; The expander bootstrap re-installs some already-constant
               ;; namespace bindings with an explicit constance mode. Reject
               ;; ordinary mutation of constants, but allow a constant or
               ;; consistent re-definition to replace the value and preserve
               ;; the binding's constance.
               (if (i32.and
                    (i32.eqz (ref.eq (local.get $constant?) (global.get $false)))
                    (ref.eq (local.get $mode) (global.get $false)))
                   (then (call $raise-instance-variable-constant (local.get $sym))
                         (unreachable)))

               (local.set $box
                          (ref.cast (ref $Box)
                                    (call $instance-variable-box
                                          (local.get $inst)
                                          (local.get $sym)
                                          (global.get $true))))
               (drop (call $set-box!
                           (ref.cast (ref eq) (local.get $box))
                           (local.get $val)))
               (if (i32.eqz (ref.eq (local.get $mode) (global.get $false)))
                   (then (call $hasheq-set!/mutable/checked
                               (local.get $constants)
                               (local.get $sym)
                               (global.get $true))))
               (global.get $void))

         (func $instance-unset-variable! (type $Prim2)
               (param $inst (ref eq)) ;; instance
               (param $sym  (ref eq)) ;; symbol
               (result (ref eq))

               (local $box (ref $Box))

               (if (i32.eqz (ref.test (ref $Instance) (local.get $inst)))
                   (then (call $raise-argument-error:instance-expected (local.get $inst))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instance-unset-variable!)
                               (global.get $string:symbol?)
                               (local.get $sym))
                         (unreachable)))

               (local.set $box
                          (ref.cast (ref $Box)
                                    (call $instance-variable-box
                                          (local.get $inst)
                                          (local.get $sym)
                                          (global.get $true))))
               (drop (call $set-box!
                           (ref.cast (ref eq) (local.get $box))
                           (global.get $undefined)))
               (global.get $void))

         ;; instance-describe-variable! : instance? symbol? any/c -> void?
         ;;   Description metadata is for diagnostics and optimization in the
         ;;   host linklet layer. WebRacket currently ignores it.
         (func $instance-describe-variable! (type $Prim3)
               (param $inst (ref eq)) ;; instance
               (param $sym  (ref eq)) ;; variable name
               (param $desc (ref eq)) ;; description metadata
               (result      (ref eq))
               (global.get $void))

         (func $instance-variable-value (type $Prim>=2)
               (param $inst (ref eq)) ;; instance
               (param $sym  (ref eq)) ;; symbol
               (param $rest (ref eq)) ;; optional failure result/procedure
               (result      (ref eq))

               (local $instance (ref $Instance))
               (local $symbol   (ref $Symbol))
               (local $vars     (ref $HashEqMutable))
               (local $got      (ref eq))
               (local $box      (ref $Box))
               (local $val      (ref eq))
               (local $fail     (ref eq))
               (local $pair     (ref $Pair))
               (local $proc     (ref $Procedure))
               (local $inv      (ref $ProcedureInvoker))
               (local $noargs   (ref $Args))

               (if (i32.eqz (ref.test (ref $Instance) (local.get $inst)))
                   (then (call $raise-argument-error:instance-expected (local.get $inst))
                         (unreachable)))
               (if (i32.eqz (ref.test (ref $Symbol) (local.get $sym)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:instance-variable-value)
                               (global.get $string:symbol?)
                               (local.get $sym))
                         (unreachable)))

               (local.set $instance (ref.cast (ref $Instance) (local.get $inst)))
               (local.set $symbol   (ref.cast (ref $Symbol)   (local.get $sym)))
               (local.set $vars     (struct.get $Instance $variables (local.get $instance)))

               (local.set $fail (global.get $missing)) ;; sentinel meaning raise error
               (if (ref.eq (local.get $rest) (global.get $null))
                   (then (nop))
                   (else
                    (local.set $pair
                               (block $ok (result (ref $Pair))
                                     (br_on_cast $ok (ref eq) (ref $Pair) (local.get $rest))
                                     (call $raise-pair-expected (local.get $rest))
                                     (unreachable)))
                    (local.set $fail (struct.get $Pair $a (local.get $pair)))
                    (local.set $rest (struct.get $Pair $d (local.get $pair)))
                    (if (ref.eq (local.get $rest) (global.get $null))
                        (then (nop))
                        (else (call $raise-instance-optional-argument
                                    (global.get $symbol:instance-variable-value)
                                    (local.get $rest))
                              (unreachable)))))

               (local.set $got (call $hasheq-ref
                                     (ref.cast (ref eq) (local.get $vars))
                                     (local.get $symbol)
                                     (global.get $false)))
               (if (ref.test (ref $Box) (local.get $got))
                   (then
                    (local.set $box (ref.cast (ref $Box) (local.get $got)))
                    (local.set $val (struct.get $Box $v (local.get $box)))
                    (if (ref.eq (local.get $val) (global.get $unsafe-undefined))
                        (then (call $raise-instance-variable-not-found (local.get $sym))
                              (unreachable)))
                    (if (i32.eqz (ref.eq (local.get $val) (global.get $undefined)))
                        (then (return (local.get $val))))))

	               (if (result (ref eq))
	                   (ref.eq (local.get $fail) (global.get $missing))
	                   (then (call $raise-instance-variable-not-found (local.get $sym))
	                         (unreachable))
	                   (else (if (result (ref eq))
	                             (ref.eq (call $procedure? (local.get $fail))
                                         (global.get $true))
	                             (then
	                              (local.set $proc (ref.cast (ref $Procedure) (local.get $fail)))
	                              (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
	                              (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
	                              (return_call_ref $ProcedureInvoker
	                                               (local.get $proc)
	                                               (local.get $noargs)
	                                               (local.get $inv)))
	                             (else (local.get $fail))))))

	         ;; Lowered module-variable cells. These are the Wasm counterpart
	         ;; of `webracket/private/module-variable.rkt`'s reference implementation.

	         (func $raise-argument-error:module-variable-expected
	               (param $who (ref eq))  ;; primitive name symbol
	               (param $got (ref eq))  ;; value that was not a module variable

	               (call $raise-argument-error1
	                     (local.get $who)
	                     (global.get $string:module-variable?)
	                     (local.get $got))
	               (unreachable))

	         (func $module-variable-cast
	               (param $who (ref eq))  ;; primitive name symbol
	               (param $cell (ref eq)) ;; expected module-variable cell
	               (result (ref $ModuleVariable))

	               (if (i32.eqz (ref.test (ref $ModuleVariable) (local.get $cell)))
	                   (then (call $raise-argument-error:module-variable-expected
	                               (local.get $who)
	                               (local.get $cell))
	                         (unreachable)))
	               (ref.cast (ref $ModuleVariable) (local.get $cell)))

	         (func $module-variable? (type $Prim1)
	               ,@(make-predicate-body '$ModuleVariable))

	         (func $module-variable-name (type $Prim1)
	               (param $cell (ref eq)) ;; module-variable?
	               (result (ref eq))

	               (struct.get $ModuleVariable $name
	                           (call $module-variable-cast
	                                 (global.get $symbol:module-variable-name)
	                                 (local.get $cell))))

	         (func $module-variable-constance (type $Prim1)
	               (param $cell (ref eq)) ;; module-variable?
	               (result (ref eq))

	               (struct.get $ModuleVariable $constance
	                           (call $module-variable-cast
	                                 (global.get $symbol:module-variable-constance)
	                                 (local.get $cell))))

	         (func $module-variable-initialized? (type $Prim1)
	               (param $cell (ref eq)) ;; module-variable?
	               (result (ref eq))

	               (if (result (ref eq))
	                   (ref.eq (struct.get $ModuleVariable $value
	                                       (call $module-variable-cast
	                                             (global.get $symbol:module-variable-initialized?)
	                                             (local.get $cell)))
	                           (global.get $undefined))
	                   (then (global.get $false))
	                   (else (global.get $true))))

	         (func $module-variable-make (type $Prim1)
	               (param $name (ref eq)) ;; symbol naming the module variable
	               (result (ref eq))

	               (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
	                   (then (call $raise-argument-error1
	                               (global.get $symbol:module-variable-make)
	                               (global.get $string:symbol?)
	                               (local.get $name))
	                         (unreachable)))
	               (struct.new $ModuleVariable
	                           (i32.const 0)
	                           (local.get $name)
	                           (global.get $undefined)
	                           (global.get $false)))

	         (func $module-variable-ref (type $Prim1)
	               (param $cell (ref eq)) ;; module-variable?
	               (result (ref eq))

	               (local $mv  (ref $ModuleVariable))
	               (local $val (ref eq))

	               (local.set $mv
	                          (call $module-variable-cast
	                                (global.get $symbol:module-variable-ref)
	                                (local.get $cell)))
	               (local.set $val (struct.get $ModuleVariable $value (local.get $mv)))
	               ;; Module-variable cells use `$undefined` as the runtime
	               ;; uninitialized sentinel. `$unsafe-undefined` is a real
	               ;; Racket value that modules such as `racket/unsafe/undefined`
	               ;; can export and clients must be able to read.
	               (if (ref.eq (local.get $val) (global.get $undefined))
	                   (then (drop (call $raise-unbound-variable-reference
	                                     (struct.get $ModuleVariable $name (local.get $mv))))
	                         (unreachable)))
	               (local.get $val))

	         (func $module-variable-ref/no-check (type $Prim1)
	               (param $cell (ref eq)) ;; module-variable?
	               (result (ref eq))
	               (local $mv (ref $ModuleVariable))
	               (local $val (ref eq))
	               (local.set $mv
	                          (call $module-variable-cast
	                                (global.get $symbol:module-variable-ref/no-check)
	                                (local.get $cell)))
	               (local.set $val (struct.get $ModuleVariable $value (local.get $mv)))
	               (if (ref.eq (local.get $val) (global.get $undefined))
	                   (then
	                    (drop (call $raise-unbound-variable-reference
	                                  (struct.get $ModuleVariable $name (local.get $mv))))
	                    (unreachable)))
	               (local.get $val))

	         (func $module-variable-set! (type $Prim2)
	               (param $cell (ref eq)) ;; module-variable?
	               (param $val  (ref eq)) ;; any/c
	               (result (ref eq))

	               (struct.set $ModuleVariable $value
	                           (call $module-variable-cast
	                                 (global.get $symbol:module-variable-set!)
	                                 (local.get $cell))
	                           (local.get $val))
	               (global.get $void))

	         (func $module-variable-set!/check-undefined! (type $Prim2)
	               (param $cell (ref eq)) ;; module-variable?
	               (param $val  (ref eq)) ;; any/c
	               (result (ref eq))

	               (local $mv (ref $ModuleVariable))

	               (local.set $mv
	                          (call $module-variable-cast
	                                (global.get $symbol:module-variable-set!/check-undefined!)
	                                (local.get $cell)))
	               (if (ref.eq (struct.get $ModuleVariable $value (local.get $mv))
	                           (global.get $undefined))
	                   (then (drop (call $raise-unbound-variable-reference
	                                     (struct.get $ModuleVariable $name (local.get $mv))))))
	               (struct.set $ModuleVariable $value (local.get $mv) (local.get $val))
	               (global.get $void))

	         (func $module-variable-define! (type $Prim3)
	               (param $cell      (ref eq)) ;; module-variable?
	               (param $val       (ref eq)) ;; any/c
	               (param $constance (ref eq)) ;; #f, 'constant, or 'consistent
	               (result (ref eq))

	               (local $mv (ref $ModuleVariable))

	               (local.set $mv
	                          (call $module-variable-cast
	                                (global.get $symbol:module-variable-define!)
	                                (local.get $cell)))
	               (struct.set $ModuleVariable $value (local.get $mv) (local.get $val))
	               (struct.set $ModuleVariable $constance (local.get $mv) (local.get $constance))
	               (global.get $void))

	         (func $module-variables-define-consistent! (type $Prim2)
	               (param $cells (ref eq)) ;; vectorof module-variable?
	               (param $vals  (ref eq)) ;; vectorof any/c
	               (result (ref eq))

	               (local $cell-vec (ref $Vector))
	               (local $val-vec  (ref $Vector))
	               (local $cell-arr (ref $Array))
	               (local $val-arr  (ref $Array))
	               (local $len      i32)
	               (local $i        i32)

	               (if (i32.eqz (ref.test (ref $Vector) (local.get $cells)))
	                   (then (call $raise-check-vector (local.get $cells))
	                         (unreachable)))
	               (if (i32.eqz (ref.test (ref $Vector) (local.get $vals)))
	                   (then (call $raise-check-vector (local.get $vals))
	                         (unreachable)))
	               (local.set $cell-vec (ref.cast (ref $Vector) (local.get $cells)))
	               (local.set $val-vec  (ref.cast (ref $Vector) (local.get $vals)))
	               (local.set $cell-arr (struct.get $Vector $arr (local.get $cell-vec)))
	               (local.set $val-arr  (struct.get $Vector $arr (local.get $val-vec)))
	               (local.set $len (array.len (local.get $cell-arr)))
	               (if (i32.ne (local.get $len) (array.len (local.get $val-arr)))
	                   (then (call $raise-argument-error1
	                               (global.get $symbol:module-variables-define-consistent!)
	                               (global.get $string:module-variable-same-length-vectors)
	                               (local.get $vals))
	                         (unreachable)))
	               (local.set $i (i32.const 0))
	               (block $done
	                      (loop $loop
	                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
	                            (drop (call $module-variable-define!
	                                        (array.get $Array (local.get $cell-arr) (local.get $i))
	                                        (array.get $Array (local.get $val-arr) (local.get $i))
	                                        (global.get $symbol:consistent)))
	                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
	                            (br $loop)))
	               (global.get $void))

	         (func $module-variable-reference? (type $Prim1)
	               ,@(make-predicate-body '$ModuleVariableReference))

	         (func $raise-argument-error:module-variable-reference-expected
	               (param $who (ref eq))  ;; primitive name symbol
	               (param $got (ref eq))  ;; value that was not a module-variable reference

	               (call $raise-argument-error1
	                     (local.get $who)
	                     (global.get $string:module-variable-reference?)
	                     (local.get $got))
	               (unreachable))

	         (func $module-variable-reference-cast
	               (param $who (ref eq)) ;; primitive name symbol
	               (param $ref (ref eq)) ;; expected module-variable-reference?
	               (result (ref $ModuleVariableReference))

	               (if (i32.eqz (ref.test (ref $ModuleVariableReference) (local.get $ref)))
	                   (then (call $raise-argument-error:module-variable-reference-expected
	                               (local.get $who)
	                               (local.get $ref))
	                         (unreachable)))
	               (ref.cast (ref $ModuleVariableReference) (local.get $ref)))

	         (func $module-variable-reference (type $Prim2)
	               (param $instance (ref eq)) ;; any/c, usually an instance
	               (param $cell     (ref eq)) ;; module-variable?
	               (result (ref eq))

	               (drop (call $module-variable-cast
	                           (global.get $symbol:module-variable-reference)
	                           (local.get $cell)))
	               (struct.new $ModuleVariableReference
	                           (i32.const 0)
	                           (local.get $instance)
	                           (local.get $cell)))

	         (func $module-variable-reference-instance (type $Prim1)
	               (param $ref (ref eq)) ;; module-variable-reference?
	               (result (ref eq))

	               (struct.get $ModuleVariableReference $instance
	                           (call $module-variable-reference-cast
	                                 (global.get $symbol:module-variable-reference-instance)
	                                 (local.get $ref))))

	         (func $module-variable-reference-variable (type $Prim1)
	               (param $ref (ref eq)) ;; module-variable-reference?
	               (result (ref eq))

	               (struct.get $ModuleVariableReference $variable
	                           (call $module-variable-reference-cast
	                                 (global.get $symbol:module-variable-reference-variable)
	                                 (local.get $ref))))

	         (func $module-call-with-prompt (type $Prim>=1)
	               (param $thunk (ref eq)) ;; thunk, currently unsupported
	               (param $rest  (ref eq)) ;; prompt metadata
	               (result (ref eq))

	               (drop (call $raise
	                           (call $exn:fail:unsupported/make
	                                 (global.get $string:module-prompts-unsupported)
	                                 (call $current-continuation-marks
	                                       (global.get $missing)))
	                           (global.get $true)))
	               (unreachable))
     ))

;; linklet-instance-all-runtime-helpers : (listof core-runtime-helper?)
;;   Register linklet instance and module-variable helpers.
(define linklet-instance-all-runtime-helpers
  (function-forms->runtime-helpers
   'linklet-instance-runtime-only-helpers
   linklet-instance-runtime-only-forms))

;; linklet-instance-promoted-runtime-helper-names : (listof symbol?)
;;   Name linklet instance helpers available in the standalone core runtime.
(define linklet-instance-promoted-runtime-helper-names
  '($raise-argument-error:instance-expected
    $raise-linklet-variable-error
    $raise-instance-variable-box-missing-binding
    $raise-instance-variable-not-found
    $raise-instance-variable-constant
    $raise-instance-optional-argument
    $instance-variable-box
    $instance-set-variable-value!
    $instance-variable-value
    $raise-argument-error:module-variable-expected
    $module-variable-cast
    $module-variable?
    $module-variable-name
    $module-variable-constance
    $module-variable-initialized?
    $module-variable-make
    $module-variable-ref
    $module-variable-ref/no-check
    $module-variable-set!
    $module-variable-set!/check-undefined!
    $module-variable-define!
    $module-variables-define-consistent!
    $module-variable-reference?
    $raise-argument-error:module-variable-reference-expected
    $module-variable-reference-cast
    $module-variable-reference
    $module-variable-reference-instance
    $module-variable-reference-variable))

;; linklet-instance-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate linklet instance helpers available in the standalone core runtime.
(define linklet-instance-core-runtime-helpers
  (select-runtime-helpers linklet-instance-all-runtime-helpers
                          linklet-instance-promoted-runtime-helper-names))

;; linklet-instance-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate linklet instance helpers that still depend on monolithic runtime state.
(define linklet-instance-runtime-only-helpers
  (remove-runtime-helpers linklet-instance-all-runtime-helpers
                          linklet-instance-promoted-runtime-helper-names))

;; linklet-instance-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for linklet instance helpers.
(define linklet-instance-runtime-only-helper-names
  (map core-runtime-helper-name linklet-instance-runtime-only-helpers))

;; linklet-instance-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted linklet instance helpers in runtime assembly order.
(define (linklet-instance-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list linklet-instance-promoted-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; linklet-instance-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render linklet instance and module-variable helpers in runtime assembly order.
(define (linklet-instance-runtime-helper-forms helper-index)
  (for/list ([name (in-list linklet-instance-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define linklet-instance-helper-index
    (make-core-runtime-helper-index
     (append linklet-instance-core-runtime-helpers
             linklet-instance-runtime-only-helpers)))

  (define linklet-instance-core-helper-index
    (make-core-runtime-helper-index linklet-instance-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name linklet-instance-core-runtime-helpers)
   linklet-instance-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (linklet-instance-core-runtime-helper-forms linklet-instance-core-helper-index))
   linklet-instance-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (linklet-instance-runtime-helper-forms linklet-instance-helper-index))
   linklet-instance-runtime-only-helper-names))
