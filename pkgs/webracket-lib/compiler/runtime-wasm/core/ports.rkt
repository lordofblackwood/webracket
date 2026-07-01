#lang racket

(provide port-runtime-only-helpers)

(require "../core-helper.rkt")

;; port-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate port predicate and wrapper-recognition helpers.
(define port-runtime-only-helpers
  (function-forms->runtime-helpers
   'port-runtime-only-helpers
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
