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

;; port-location-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate port line-count, position, and location helpers.
(define port-location-runtime-only-helpers
  (function-forms->runtime-helpers
   'port-location-runtime-only-helpers
   '(
     ;; Note:
     ;;   WebRacket's current string ports always track line and column
     ;;   information, so enabling line counting is a no-op.
     ;;
     ;;   For now the primitives port-count-lines! and port-counts-lines?
     ;;   exists to preserve compatibility with Racket
     ;;   programs that explicitly request line counting.
     ;;
     ;;   When support for file ports is added, these functions needs
     ;;   to be revised.

     (func $port-count-lines! (type $Prim1)
           (param $p (ref eq))
           (result   (ref eq))
           (global.get $void))

     ;; Note:
     ;;   See previous note.
     (func $port-counts-lines? (type $Prim1)
           (param $p (ref eq))
           (result   (ref eq))
           (global.get $true))

     ;; file-position* : port? -> (or/c exact-nonnegative-integer? #f)
     ;;   Return the known byte position for WebRacket string/VFS ports.
     ;;   Other future port kinds should return #f when the position is
     ;;   unknown instead of raising.
     (func $file-position* (type $Prim1)
           (param $p (ref eq)) ;; port?
           (result   (ref eq))

           (local $port (ref $Port))

           (if (i32.eqz (ref.test (ref $Port) (local.get $p)))
               (then (call $raise-argument-error1
                           (global.get $symbol:file-position*)
                           (global.get $string:port?)
                           (local.get $p))
                     (unreachable)))
           (local.set $port (ref.cast (ref $Port) (local.get $p)))
           (if (struct.get $Port $closed (local.get $port))
               (then (call $raise-argument-error1
                           (global.get $symbol:file-position*)
                           (global.get $string:port?)
                           (local.get $p))
                     (unreachable)))
           (if (ref.test (ref $InputPort) (local.get $p))
               (then (return (ref.i31
                              (i32.shl
                               (struct.get $InputPort $idx
                                           (ref.cast (ref $InputPort) (local.get $p)))
                               (i32.const 1))))))
           (if (ref.test (ref $OutputPort) (local.get $p))
               (then (return (ref.i31
                              (i32.shl
                               (struct.get $OutputPort $idx
                                           (ref.cast (ref $OutputPort) (local.get $p)))
                               (i32.const 1))))))
           (global.get $false))

     (func $port-next-location (type $Prim1)
           (param $p (ref eq))
           (result   (ref eq))

           (local $port (ref null $Port))
           (local $loc  (ref null $Location))
           ;; 1. Check and cast $p to (ref $Port). Some Goal 1 formatter
           ;; paths can pass higher-level port wrappers before WebRacket
           ;; fully models prop:input-port/prop:output-port. Preserve the
           ;; Reference-mandated three-result shape; when possible, resolve
           ;; prop:output-port to the underlying native port first.
           (if (ref.test (ref $Port) (local.get $p))
               (then (local.set $port (ref.cast (ref $Port) (local.get $p))))
               (else
                (local.set $p (call $prop-output-port-target (local.get $p)))
                (if (ref.test (ref $Port) (local.get $p))
                    (then (local.set $port (ref.cast (ref $Port) (local.get $p))))
                    (else (return (array.new_fixed $Values 3
                                                   (global.get $false)
                                                   (global.get $false)
                                                   (global.get $false)))))))
           ;; 2. Get location struct from the port
           (local.set $loc (struct.get $Port $loc (local.get $port)))
           ;; 3. Extract and return as fixed array of 3 elements
           (array.new_fixed $Values 3
                            (struct.get $Location $line (local.get $loc))
                            (struct.get $Location $col  (local.get $loc))
                            (struct.get $Location $pos  (local.get $loc)))))))

;; port-byte-string-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate byte/string port constructors and byte extraction helpers.
(define port-byte-string-runtime-only-helpers
  (function-forms->runtime-helpers
   'port-byte-string-runtime-only-helpers
   '(
     (func $open-input-bytes (type $Prim12)
           (param $bstr-raw (ref eq)) ;; bytes?
           (param $name     (ref eq)) ;; optional any/c, default = 'string
           (result          (ref eq))

           (local $bstr      (ref $Bytes))
           (local $port-bs   (ref $Bytes))
           (local $name-val  (ref eq))
           (local $src-arr   (ref $I8Array))
           (local $arr       (ref $I8Array))
           (local $len       i32)
           (local $loc       (ref $Location))
           (local $immutable i32)

           ;; --- Initialize non-defaultable locals ---
           (local.set $bstr    (ref.cast (ref $Bytes) (global.get $bytes:empty)))
           (local.set $port-bs (ref.cast (ref $Bytes) (global.get $bytes:empty)))
           ;; --- Validate byte string argument ---
           (if (i32.eqz (ref.test (ref $Bytes) (local.get $bstr-raw)))
               (then (call $raise-check-bytes (local.get $bstr-raw))))
           (local.set $bstr (ref.cast (ref $Bytes) (local.get $bstr-raw)))
           ;; --- Determine port name, honoring optional argument ---
           (local.set $name-val
                      (if (result (ref eq))
                          (ref.eq (local.get $name) (global.get $missing))
                          (then (global.get $symbol:string))
                          (else (local.get $name))))
           ;; --- Ensure the port holds an immutable copy of the bytes ---
           (local.set $immutable (struct.get $Bytes $immutable (local.get $bstr)))
           (local.set $src-arr (struct.get $Bytes $bs (local.get $bstr)))
           (if (i32.eq (local.get $immutable) (i32.const 1))
               (then (local.set $port-bs (local.get $bstr)))
               (else
                (local.set $port-bs
                           (struct.new $Bytes
                                       (struct.get $Bytes $hash (local.get $bstr))
                                       (i32.const 1)
                                       (call $i8array-copy
                                             (local.get $src-arr)
                                             (i32.const 0)
                                             (call $i8array-length (local.get $src-arr)))))))
           ;; --- Cache backing array and byte length ---
           (local.set $arr (struct.get $Bytes $bs (local.get $port-bs)))
           (local.set $len (array.len (local.get $arr)))
           ;; --- Initialize location and construct the port ---
           (local.set $loc (ref.cast (ref $Location) (call $make-initial-location)))
           (struct.new $InputStringPort
                       (i32.const 0)         ;; $hash
                       (local.get $name-val) ;; $name
                       (i32.const 0)         ;; $closed
                       (local.get $port-bs)  ;; $bytes
                       (local.get $len)      ;; $len
                       (i32.const 0)         ;; $idx
                       (local.get $loc)      ;; $loc
                       (global.get $false)   ;; $read-handler
                       (i32.const 0)         ;; $utf8-len
                       (i32.const 0)         ;; $utf8-left
                       (i32.const 0)))       ;; $utf8-bytes

     (func $open-input-string (type $Prim12)
           (param $str-raw (ref eq)) ;; string?
           (param $name    (ref eq)) ;; optional any/c, default = 'string
           (result         (ref eq))

           (local $str      (ref $String))
           (local $name-val (ref eq))
           (local $bytes    (ref $Bytes))
           (local $arr      (ref $I8Array))
           (local $len      i32)
           (local $loc      (ref $Location))

           ;; --- Validate string argument ---
           (if (i32.eqz (ref.test (ref $String) (local.get $str-raw)))
               (then (call $raise-check-string (local.get $str-raw))))
           (local.set $str (ref.cast (ref $String) (local.get $str-raw)))
           ;; --- Determine port name, honoring optional argument ---
           (local.set $name-val
                      (if (result (ref eq))
                          (ref.eq (local.get $name) (global.get $missing))
                          (then (global.get $symbol:string))
                          (else (local.get $name))))
           ;; --- Convert string contents to immutable UTF-8 bytes ---
           (local.set $bytes
                      (ref.cast (ref $Bytes)
                                (call $string->bytes/utf-8
                                      (local.get $str)
                                      (global.get $false)
                                      (global.get $false)
                                      (global.get $false))))
           (local.set $arr (struct.get $Bytes $bs (local.get $bytes)))
           (local.set $len (array.len (local.get $arr)))
           ;; --- Initialize location and construct the port ---
           (local.set $loc (ref.cast (ref $Location) (call $make-initial-location)))
           (struct.new $InputStringPort
                       (i32.const 0)          ;; $hash
                       (local.get $name-val)  ;; $name
                       (i32.const 0)          ;; $closed
                       (local.get $bytes)     ;; $bytes
                       (local.get $len)       ;; $len (byte length)
                       (i32.const 0)          ;; $idx
                       (local.get $loc)       ;; $loc
                       (global.get $false)    ;; $read-handler
                       (i32.const 0)          ;; $utf8-len
                       (i32.const 0)          ;; $utf8-left
                       (i32.const 0)))        ;; $utf8-bytes


     (func $open-output-bytes (type $Prim01)
           (param $name (ref eq)) ;; optional any/c, default = 'string
           (result (ref eq))

           (local $bs       (ref $Bytes))
           (local $loc      (ref $Location))
           (local $name-val (ref eq))
           (local $port     (ref $OutputStringPort))
           ;; Step 1: Allocate the backing I8Array with capacity 32 and fill with 0
           (local.set $bs
                      (struct.new $Bytes
                        (i32.const 0)                                       ;; hash = 0
                        (i32.const 0)                                       ;; mutable = false
                        (call $i8make-array (i32.const 32) (i32.const 0)))) ;; backing array
           ;; Step 2: Make initial location: (line 1, col 0, pos 1)
           (local.set $loc (ref.cast (ref $Location) (call $make-initial-location)))
           ;; Step 3: Determine the port name, defaulting to 'string
           (local.set $name-val
                      (if (result (ref eq))
                          (ref.eq (local.get $name) (global.get $missing))
                          (then (global.get $symbol:string))
                          (else (local.get $name))))
           ;; Step 4: Construct and return the StringPort
           (local.set $port
                      (struct.new $OutputStringPort
                                  (i32.const 0)                 ;; $hash
                                  (local.get $name-val)         ;; $name  : (ref eq)
                                  (i32.const 0)                 ;; $closed
                                  (local.get $bs)               ;; $bytes : (ref $Bytes)
                                  (i32.const 32)                ;; $len   : i32
                                  (i32.const 0)                 ;; $idx   : i32
                                  (local.get $loc)              ;; $loc   : (ref $Location)
                                  (i32.const 0)                 ;; $utf8-len
                                  (i32.const 0)                 ;; $utf8-left
                                  (i32.const 0)))               ;; $utf8-bytes
           (local.get $port))

     (func $open-output-string (type $Prim01)
           (param $name (ref eq)) ;; optional any/c, default = 'string
           (result (ref eq))

           (local $port     (ref $OutputStringPort))
           (local $name-val (ref eq))
           ;; Determine the port name, defaulting to 'string when omitted
           (local.set $name-val
                      (if (result (ref eq))
                          (ref.eq (local.get $name) (global.get $missing))
                          (then (global.get $symbol:string))
                          (else (local.get $name))))
           ;; Reuse the byte-backed string port and update its name field
           (local.set $port (ref.cast (ref $OutputStringPort)
                                      (call $open-output-bytes (global.get $missing))))
           (struct.set $OutputStringPort $name (local.get $port) (local.get $name-val))
           (local.get $port))

     (func $get-output-bytes (type $Prim14)
           (param $out    (ref eq))
           (param $reset? (ref eq)) ;; optional any/c, default = #f
           (param $start  (ref eq)) ;; optional exact-nonnegative-integer?, default = 0
           (param $end    (ref eq)) ;; optional exact-nonnegative-integer?, default = current output length
           (result        (ref eq))

           (local $sp   (ref null $OutputStringPort))
           (local $bs   (ref $Bytes))
           (local $idx  i32)
           (local $from i32)
           (local $to   i32)
           (local $src  (ref $I8Array))
           (local $dest (ref $I8Array))
           (local $res  (ref $Bytes))
           ;; 1. Check that $out is a StringPort
           (if (ref.test (ref $OutputStringPort) (local.get $out))
               (then (local.set $sp (ref.cast (ref $OutputStringPort) (local.get $out))))
               (else (call $raise-check-string-port (local.get $out)) (unreachable)))
           ;; 2. Get internal byte string and index
           (local.set $bs  (struct.get $OutputStringPort $bytes (local.get $sp)))
           (local.set $idx (struct.get $OutputStringPort $idx   (local.get $sp)))
           ;; 3. Extract the I8Array from the Bytes object
           (local.set $src (struct.get $Bytes $bs (local.get $bs)))
           ;; 4. Decode the optional slice bounds. The visible content is
           ;;    the written prefix [0, idx), not the backing capacity.
           (if (ref.eq (local.get $start) (global.get $missing))
               (then (local.set $from (i32.const 0)))
               (else (if (ref.test (ref i31) (local.get $start))
                         (then
                          (local.set $from (i31.get_u (ref.cast (ref i31) (local.get $start))))
                          (if (i32.eqz (i32.and (local.get $from) (i32.const 1)))
                              (then (local.set $from (i32.shr_u (local.get $from) (i32.const 1))))
                              (else (call $raise-check-fixnum (local.get $start)) (unreachable))))
                         (else (call $raise-check-fixnum (local.get $start)) (unreachable)))))
           (if (ref.eq (local.get $end) (global.get $missing))
               (then (local.set $to (local.get $idx)))
               (else (if (ref.test (ref i31) (local.get $end))
                         (then
                          (local.set $to (i31.get_u (ref.cast (ref i31) (local.get $end))))
                          (if (i32.eqz (i32.and (local.get $to) (i32.const 1)))
                              (then (local.set $to (i32.shr_u (local.get $to) (i32.const 1))))
                              (else (call $raise-check-fixnum (local.get $end)) (unreachable))))
                         (else (call $raise-check-fixnum (local.get $end)) (unreachable)))))
           (if (i32.gt_u (local.get $from) (local.get $to))
               (then (call $raise-bad-bytes-range (local.get $out) (local.get $from) (local.get $to)) (unreachable)))
           (if (i32.gt_u (local.get $to) (local.get $idx))
               (then (call $raise-bad-bytes-range (local.get $out) (local.get $from) (local.get $to)) (unreachable)))
           ;; 5. Allocate a new array for the requested slice.
           (local.set $dest (call $i8make-array
                                  (i32.sub (local.get $to) (local.get $from))
                                  (i32.const 0)))
           ;; 6. Copy contents into the new array
           (drop (call $i8array-copy!/error
                       (local.get $dest)            ;; dest
                       (i32.const 0)                ;; dest-start
                       (local.get $src)             ;; src
                       (local.get $from)             ;; src-start
                       (local.get $to)))             ;; src-end
           ;; 7. Construct new Bytes object
           (local.set $res
                      (struct.new $Bytes
                                  (i32.const 0)              ;; hash
                                  (i32.const 1)              ;; immutable
                                  (local.get $dest)))        ;; backing array
           ;; 8. A true reset? clears the visible output but keeps capacity.
           (if (i32.and
                (i32.eqz (ref.eq (local.get $reset?) (global.get $false)))
                (i32.eqz (ref.eq (local.get $reset?) (global.get $missing))))
               (then (struct.set $OutputStringPort $idx (local.get $sp) (i32.const 0))
                     (struct.set $OutputStringPort $utf8-len (local.get $sp) (i32.const 0))
                     (struct.set $OutputStringPort $utf8-left (local.get $sp) (i32.const 0))
                     (struct.set $OutputStringPort $utf8-bytes (local.get $sp) (i32.const 0))))
           ;; 9. Return the new Bytes
           (local.get $res)))))

;; port-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate port helpers used by the monolithic runtime.
(define port-runtime-only-helpers
  (append port-predicate-runtime-only-helpers
          port-state-runtime-only-helpers
          port-location-runtime-only-helpers
          port-byte-string-runtime-only-helpers))
