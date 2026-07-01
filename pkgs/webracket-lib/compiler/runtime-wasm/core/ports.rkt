#lang racket

(provide port-runtime-only-helpers)

(require "../core-helper.rkt")

;; port-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate port predicate and wrapper-recognition helpers.
(define port-predicate-runtime-only-helpers
  (function-forms->runtime-helpers
   'port-predicate-runtime-only-helpers
   '(
     (func $raise-check-string-port (param $x (ref eq)) (unreachable))
     (func $raise-check-port-or-false (param $x (ref eq)) (unreachable))

     (func $string-port? (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))
           (if (result (ref eq))
               (i32.or (ref.test (ref $InputStringPort)  (local.get $v))
                       (ref.test (ref $OutputStringPort) (local.get $v)))
               (then (global.get $true))
               (else (global.get $false))))

     ;; struct-has-property?/i32 : any/c struct-type-property? -> i32
     ;;   Check whether a struct instance's type has a property.
     (func $struct-has-property?/i32
           (param $v    (ref eq))
           (param $prop (ref $StructTypeProperty))
           (result      i32)

           (local $type     (ref $StructType))
           (local $sentinel (ref eq))
           (local $prop-val (ref eq))

           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (return (i32.const 0))))
           (local.set $type
                      (struct.get $Struct $type
                                  (ref.cast (ref $Struct) (local.get $v))))
           (local.set $sentinel (call $cons (global.get $false)
                                      (global.get $false)))
           (local.set $prop-val
                      (call $struct-type-property-lookup
                            (local.get $type)
                            (local.get $prop)
                            (local.get $sentinel)))
           (i32.eqz (ref.eq (local.get $prop-val) (local.get $sentinel))))

     ;; input-port-like?/i32 : any/c -> i32
     ;;   Recognize native input ports and prop:input-port wrappers.
     (func $input-port-like?/i32
           (param $v (ref eq))
           (result   i32)
           (if (ref.test (ref $InputPort) (local.get $v))
               (then (return (i32.const 1))))
           (call $struct-has-property?/i32
                 (local.get $v)
                 (ref.cast (ref $StructTypeProperty)
                           (global.get $prop:input-port))))

     ;; output-port-like?/i32 : any/c -> i32
     ;;   Recognize native output ports and prop:output-port wrappers.
     (func $output-port-like?/i32
           (param $v (ref eq))
           (result   i32)
           (if (ref.test (ref $OutputPort) (local.get $v))
               (then (return (i32.const 1))))
           (call $struct-has-property?/i32
                 (local.get $v)
                 (ref.cast (ref $StructTypeProperty)
                           (global.get $prop:output-port))))

     ;; prop-output-port-target : any/c -> (or/c output-port? #f)
     ;;   Resolve a prop:output-port wrapper to its underlying output port.
     ;;   The Reference allows either a direct output port or a field index
     ;;   whose immutable field contains an output port. If the property is
     ;;   present but unusable, Racket uses a discard port; WebRacket has no
     ;;   discard-port subtype yet, so return #f and let callers follow their
     ;;   existing unsupported-output-port path.
     (func $prop-output-port-target
           (param $v (ref eq))
           (result   (ref eq))

           (local $struct   (ref $Struct))
           (local $type     (ref $StructType))
           (local $sentinel (ref eq))
           (local $prop-val (ref eq))
           (local $raw      i32)
           (local $idx      i32)
           (local $fields   (ref $Array))
           (local $field-v  (ref eq))

           (if (ref.test (ref $OutputPort) (local.get $v))
               (then (return (local.get $v))))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (return (global.get $false))))
           (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
           (local.set $type   (struct.get $Struct $type (local.get $struct)))
           (local.set $sentinel (call $cons (global.get $false)
                                      (global.get $false)))
           (local.set $prop-val
                      (call $struct-type-property-lookup
                            (local.get $type)
                            (ref.cast (ref $StructTypeProperty)
                                      (global.get $prop:output-port))
                            (local.get $sentinel)))
           (if (ref.eq (local.get $prop-val) (local.get $sentinel))
               (then (return (global.get $false))))
           (if (ref.test (ref $OutputPort) (local.get $prop-val))
               (then (return (local.get $prop-val))))
           (if (i32.eqz (ref.test (ref i31) (local.get $prop-val)))
               (then (return (global.get $false))))
           (local.set $raw (i31.get_u (ref.cast (ref i31) (local.get $prop-val))))
           (if (i32.and (local.get $raw) (i32.const 1))
               (then (return (global.get $false))))
           (local.set $idx (i32.shr_u (local.get $raw) (i32.const 1)))
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (if (i32.ge_u (local.get $idx) (array.len (local.get $fields)))
               (then (return (global.get $false))))
           (local.set $field-v (array.get $Array (local.get $fields) (local.get $idx)))
           (if (result (ref eq))
               (ref.test (ref $OutputPort) (local.get $field-v))
               (then (local.get $field-v))
               (else (global.get $false))))

     ;; port-like?/i32 : any/c -> i32
     ;;   Recognize native ports and prop:input-port/prop:output-port wrappers.
     (func $port-like?/i32
           (param $v (ref eq))
           (result   i32)
           (if (ref.test (ref $Port) (local.get $v))
               (then (return (i32.const 1))))
           (i32.or (call $input-port-like?/i32 (local.get $v))
                   (call $output-port-like?/i32 (local.get $v))))

     (func $port? (type $Prim1)
           (param $v (ref eq)) ;; any/c
           (result   (ref eq))
           (if (result (ref eq))
               (call $port-like?/i32 (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     (func $input-port? (type $Prim1)
           (param $v (ref eq)) ;; any/c
           (result   (ref eq))
           (if (result (ref eq))
               (call $input-port-like?/i32 (local.get $v))
               (then (global.get $true))
               (else (global.get $false))))

     ;; file-stream-port? : any/c -> boolean?
     ;;   Recognize VFS-backed file ports. WebRacket currently represents
     ;;   input files as input-string ports with a path source name, while
     ;;   output files have a dedicated OutputFilePort subtype.
     (func $file-stream-port? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq))

           (local $in (ref $InputStringPort))

           (if (ref.test (ref $OutputFilePort) (local.get $v))
               (then (return (global.get $true))))
           (if (ref.test (ref $InputStringPort) (local.get $v))
               (then
                (local.set $in (ref.cast (ref $InputStringPort) (local.get $v)))
                (if (ref.test (ref $Path)
                              (struct.get $InputStringPort $name (local.get $in)))
                    (then (return (global.get $true))))))
           (global.get $false))

     ;; terminal-port? : any/c -> boolean?
     ;;   WebRacket currently has string/VFS/browser ports, but no
     ;;   interactive terminal port. The predicate is intentionally false
     ;;   until a terminal-backed port subtype exists.
     (func $terminal-port? (type $Prim1)
           (param $v (ref eq)) ;; any value
           (result   (ref eq))
           (global.get $false))

     (func $output-port? (type $Prim1)
           (param $v (ref eq)) ;; any/c
           (result   (ref eq))
           (if (result (ref eq))
               (call $output-port-like?/i32 (local.get $v))
               (then (global.get $true))
               (else (global.get $false)))))))

;; port-state-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate port status, current-port, flush, and close helpers.
(define port-state-runtime-only-helpers
  (function-forms->runtime-helpers
   'port-state-runtime-only-helpers
   '(
     (func $port-closed? (type $Prim1)
           (param $p (ref eq)) ;; port?
           (result   (ref eq))

           (local $port (ref $Port))

           (if (i32.eqz (ref.test (ref $Port) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:port-closed?)
                           (global.get $string:port?)
                           (local.get $p))
                     (unreachable)))
           (local.set $port (ref.cast (ref $Port) (local.get $p)))
           (if (result (ref eq))
               (struct.get $Port $closed (local.get $port))
               (then (global.get $true))
               (else (global.get $false))))

     ;; close-input-port : input-port? -> void?
     ;;   Call a custom input port's close thunk once, then mark the port closed.
     (func $close-input-port (type $Prim1)
           (param $p (ref eq)) ;; input-port?
           (result   (ref eq))

           (local $port       (ref $InputPort))
           (local $custom     (ref $CustomInputPort))
           (local $close-proc (ref eq))
           (local $f          (ref $Procedure))
           (local $finv       (ref $ProcedureInvoker))
           (local $args       (ref $Args))

           (if (i32.eqz (ref.test (ref $InputPort) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:close-input-port)
                           (global.get $string:input-port?)
                           (local.get $p))
                     (unreachable)))
           (local.set $port (ref.cast (ref $InputPort) (local.get $p)))
           (if (struct.get $InputPort $closed (local.get $port))
               (then (return (global.get $void))))
           (if (ref.test (ref $CustomInputPort) (local.get $p))
               (then
                (local.set $custom (ref.cast (ref $CustomInputPort) (local.get $p)))
                (local.set $close-proc
                           (struct.get $CustomInputPort $close-proc
                                       (local.get $custom)))
                (if (ref.test (ref $Procedure) (local.get $close-proc))
                    (then
                     (local.set $f (ref.cast (ref $Procedure)
                                             (local.get $close-proc)))
                     (local.set $finv
                                (struct.get $Procedure $invoke (local.get $f)))
                     (local.set $args (array.new_fixed $Args 0))
                     (drop (call_ref $ProcedureInvoker
                                     (local.get $f)
                                     (local.get $args)
                                     (local.get $finv)))))))
           (struct.set $InputPort $closed (local.get $port) (i32.const 1))
           (global.get $void))

     ;; current-input-port : [input-port?] -> input-port? or void?
     ;;   Get or set the runtime current input port.
     (func $current-input-port (type $Prim01)
           (param $p (ref eq)) ;; optional input-port?
           (result   (ref eq))

           (if (ref.eq (local.get $p) (global.get $missing))
               (then (return (global.get $current-input-port-value))))
           (if (i32.eqz (ref.test (ref $InputPort) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-input-port)
                           (global.get $string:input-port?)
                           (local.get $p))
                     (unreachable)))
           (global.set $current-input-port-value (local.get $p))
           (global.get $void))

     ;; current-output-port : [output-port?] -> output-port? or void?
     ;;   Get or set the runtime current output port.
     (func $current-output-port (type $Prim01)
           (param $p (ref eq)) ;; optional output-port?
           (result   (ref eq))

           (if (ref.eq (local.get $p) (global.get $missing))
               (then (return (global.get $current-output-port-value))))
           (if (i32.eqz (ref.test (ref $OutputPort) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-output-port)
                           (global.get $string:output-port?)
                           (local.get $p))
                     (unreachable)))
           (global.set $current-output-port-value (local.get $p))
           (global.get $void))

     ;; current-error-port : [output-port?] -> output-port? or void?
     ;;   Get or set the runtime current error port.
     (func $current-error-port (type $Prim01)
           (param $p (ref eq)) ;; optional output-port?
           (result   (ref eq))

           (if (ref.eq (local.get $p) (global.get $missing))
               (then (return (global.get $current-error-port-value))))
           (if (i32.eqz (ref.test (ref $OutputPort) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:current-error-port)
                           (global.get $string:output-port?)
                           (local.get $p))
                     (unreachable)))
           (global.set $current-error-port-value (local.get $p))
           (global.get $void))

     ;; reset-current-input-port! : -> void?
     ;;   Reset the runtime current input port to an empty string port.
     (func $reset-current-input-port! (type $Prim0)
           (result (ref eq))

           (global.set $current-input-port-value
                       (call $open-input-string
                             (global.get $string:empty)
                             (global.get $missing)))
           (global.get $void))

     ;; reset-current-output-port! : -> void?
     ;;   Reset the runtime current output port to a fresh output string port.
     (func $reset-current-output-port! (type $Prim0)
           (result (ref eq))

           (global.set $current-output-port-value
                       (call $open-output-string (global.get $missing)))
           (global.get $void))

     ;; reset-current-error-port! : -> void?
     ;;   Reset the runtime current error port to a fresh output string port.
     (func $reset-current-error-port! (type $Prim0)
           (result (ref eq))

           (global.set $current-error-port-value
                       (call $open-output-string (global.get $missing)))
           (global.get $void))

     ;; flush-output : [output-port?] -> void?
     ;;   Flush a VFS output file port; string and bytes output ports are no-ops.
     (func $flush-output (type $Prim01)
           (param $p (ref eq)) ;; optional output-port?, default = current output port
           (result   (ref eq))

           (local $port      (ref $OutputPort))
           (local $file-port (ref $OutputFilePort))

           (if (ref.eq (local.get $p) (global.get $missing))
               (then (local.set $p (call $current-output-port
                                         (global.get $missing)))))
           (if (i32.eqz (ref.test (ref $OutputPort) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:flush-output)
                           (global.get $string:output-port?)
                           (local.get $p))
                     (unreachable)))
           (local.set $port (ref.cast (ref $OutputPort) (local.get $p)))
           (if (struct.get $OutputPort $closed (local.get $port))
               (then (call $raise-output-port-closed
                           (global.get $string:flush-output:output-port-closed))
                     (unreachable)))
           (if (ref.test (ref $OutputFilePort) (local.get $p))
               (then
                (local.set $file-port (ref.cast (ref $OutputFilePort) (local.get $p)))
                (drop (call $webracket-vfs-write-file
                            (struct.get $OutputFilePort $path (local.get $file-port))
                            (call $get-output-bytes
                                  (local.get $p)
                                  (global.get $missing)
                                  (global.get $missing)
                                  (global.get $missing))))))
           (global.get $void))

     ;; close-output-port : output-port? -> void?
     ;;   Flush a VFS file output port if needed, then mark the port closed.
     (func $close-output-port (type $Prim1)
           (param $p (ref eq)) ;; output-port?
           (result   (ref eq))

           (local $port       (ref $OutputPort))
           (local $custom     (ref $CustomOutputPort))
           (local $close-proc (ref eq))
           (local $f          (ref $Procedure))
           (local $finv       (ref $ProcedureInvoker))

           (if (i32.eqz (ref.test (ref $OutputPort) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:close-output-port)
                           (global.get $string:output-port?)
                           (local.get $p))
                     (unreachable)))
           (local.set $port (ref.cast (ref $OutputPort) (local.get $p)))
           (if (struct.get $OutputPort $closed (local.get $port))
               (then (return (global.get $void))))
           (drop (call $flush-output (local.get $p)))
           (if (ref.test (ref $CustomOutputPort) (local.get $p))
               (then
                (local.set $custom (ref.cast (ref $CustomOutputPort) (local.get $p)))
                (local.set $close-proc
                           (struct.get $CustomOutputPort $close-proc (local.get $custom)))
                (local.set $f (ref.cast (ref $Procedure) (local.get $close-proc)))
                (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
                (drop (call_ref $ProcedureInvoker
                                (local.get $f)
                                (array.new_fixed $Args 0)
                                (local.get $finv)))))
           (struct.set $OutputPort $closed (local.get $port) (i32.const 1))
           (global.get $void)))))

;; port-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate port helpers used by the monolithic runtime.
(define port-runtime-only-helpers
  (append port-predicate-runtime-only-helpers
          port-state-runtime-only-helpers))
