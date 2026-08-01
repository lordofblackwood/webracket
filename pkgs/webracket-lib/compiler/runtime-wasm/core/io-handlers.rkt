#lang racket

(provide io-handler-reader-printer-runtime-only-helper-names
         io-handler-reader-printer-runtime-helper-forms
         io-handler-environment-predicate-runtime-helper-forms
         io-handler-environment-ref-runtime-helper-forms
         io-handler-default-port-global-forms
         io-handler-default-port-global-names
         io-handler-default-port-late-initializer-forms
         io-handler-runtime-string-constants
         io-handler-runtime-symbol-constants
         io-handler-port-runtime-only-helper-names
         io-handler-port-runtime-helper-forms
         io-handler-error-runtime-only-helper-names
         io-handler-error-runtime-helper-forms
         io-handler-runtime-only-helpers)

(require "../core-helper.rkt")

;; io-handler-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by bootstrap reader and printer handlers.
(define io-handler-runtime-string-constants
  '((read-unsupported        "read: the Racket reader is not supported by WebRacket yet")
    (read-syntax-unsupported "read-syntax: the Racket reader is not supported by WebRacket yet")
    (reader-unsupported      "the Racket reader is not supported by WebRacket yet")
    (print-quote-depth       "(or/c 0 1)")
    (environment-variables-ref:environment-variables? "environment-variables?")
    (bytes-environment-variable-name? "bytes-environment-variable-name?")))

;; io-handler-default-port-global-forms : (listof datum?)
;;   Declare globals for default port read, write, display, and print handlers.
(define io-handler-default-port-global-forms
  '(
               (global $default-port-read-handler-value (mut (ref eq)) (global.get $false))
               (global $default-port-write-handler-value (mut (ref eq)) (global.get $false))
               (global $default-port-display-handler-value (mut (ref eq)) (global.get $false))
               (global $default-port-print-handler-value (mut (ref eq)) (global.get $false))))

;; io-handler-default-port-global-names : (listof symbol?)
;;   Enumerate default port handler globals shared by split modules.
(define io-handler-default-port-global-names
  (map second io-handler-default-port-global-forms))

;; io-handler-default-port-late-initializer-forms : (listof datum?)
;;   Initialize default port handler globals after primitive support is ready.
(define io-handler-default-port-late-initializer-forms
  '(
                    (global.set $default-port-read-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:default-port-read-handler)
                                            (ref.i31 (i32.const 2))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-1)
                                            (ref.func $default-port-read-handler/1)
                                            (global.get $false)))
                    (global.set $default-port-write-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:default-port-write-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-port-write-handler)
                                            (global.get $false)))
                    (global.set $default-port-display-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:default-port-display-handler)
                                            (ref.i31 (i32.const 4))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-2)
                                            (ref.func $default-port-display-handler)
                                            (global.get $false)))
                    (global.set $default-port-print-handler-value
                                (struct.new $PrimitiveProcedure
                                            (i32.const 0)
                                            (global.get $symbol:default-port-print-handler)
                                            (ref.i31 (i32.const 12))
                                            (global.get $the-racket/primitive-realm)
                                            (ref.func $primitive-invoke:shape-14)
                                            (ref.func $default-port-print-handler)
                                            (global.get $false)))))

;; io-handler-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by port handler accessors.
(define io-handler-runtime-symbol-constants
  '(read
    read-syntax
    default-read-interaction
    default-port-read-handler
    default-port-write-handler
    default-port-display-handler
    default-port-print-handler
    port-read-handler
    port-write-handler
    port-display-handler
    port-print-handler
    environment-variables-ref))

;; make-predicate-body : symbol? -> (listof datum?)
;;   Generate a standard WebRacket predicate body for ref-type.
(define (make-predicate-body ref-type)
  `((param $v (ref eq))
    (result   (ref eq))
    (if (result (ref eq))
        (ref.test (ref ,ref-type) (local.get $v))
        (then (global.get $true))
        (else (global.get $false)))))

;; io-handler-reader-printer-runtime-only-helper-names : (listof symbol?)
;;   Preserve emission order for bootstrap reader and printer helpers.
(define io-handler-reader-printer-runtime-only-helper-names
  '($print-values
    $default-current-read-interaction
    $default-port-read-handler
    $default-port-read-handler/1
    $read
    $read-syntax))

;; io-handler-port-runtime-only-helper-names : (listof symbol?)
;;   Preserve emission order for port handler helpers.
(define io-handler-port-runtime-only-helper-names
  '($port-read-handler
    $default-port-write-handler
    $default-port-display-handler
    $default-port-print-handler
    $port-write-handler
    $port-display-handler
    $port-print-handler))

;; io-handler-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve emission order for default error rendering helpers.
(define io-handler-error-runtime-only-helper-names
  '($default-error-syntax->name-handler
    $default-error-value->string-handler
    $default-error-syntax->string-handler
    $default-error-module-path->string-handler))

;; io-handler-environment-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for environment-variables?.
(define io-handler-environment-predicate-runtime-only-helper-names
  '($environment-variables?))

;; io-handler-environment-ref-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for environment-variables-ref.
(define io-handler-environment-ref-runtime-only-helper-names
  '($environment-variables-ref))

;; io-handler-runtime-only-forms : (listof datum?)
;;   Enumerate bootstrap environment, reader, port, and error handler helpers.
(define io-handler-runtime-only-forms
  `(
               ;; environment-variables? : any/c -> boolean?
               ;;   Check whether a value is WebRacket's environment-variable set.
               (func $environment-variables? (type $Prim1)
                     ,@(make-predicate-body '$EnvironmentVariables))
               ;; environment-variables-ref : environment-variables? bytes? -> (or/c bytes? #f)
               ;;   Look up a variable in WebRacket's empty environment.
               (func $environment-variables-ref (type $Prim2)
                     (param $env-raw  (ref eq)) ;; environment-variable set
                     (param $name-raw (ref eq)) ;; byte string name
                     (result (ref eq))
                     (local $name (ref $Bytes))
                     (local $bs   (ref $I8Array))
                     (local $len  i32)
                     (local $i    i32)
                     (local $ch   i32)

                     (if (i32.eqz (ref.test (ref $EnvironmentVariables) (local.get $env-raw)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:environment-variables-ref)
                                     (global.get $string:environment-variables-ref:environment-variables?)
                                     (local.get $env-raw))
                               (unreachable)))
                     (if (i32.eqz (ref.test (ref $Bytes) (local.get $name-raw)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:environment-variables-ref)
                                     (global.get $string:bytes-environment-variable-name?)
                                     (local.get $name-raw))
                               (unreachable)))
                     (local.set $name (ref.cast (ref $Bytes) (local.get $name-raw)))
                     (local.set $bs   (struct.get $Bytes $bs (local.get $name)))
                     (local.set $len  (array.len (local.get $bs)))
                     (local.set $i    (i32.const 0))
                     (block $done
                            (loop $loop
                                  (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                  (local.set $ch (array.get_u $I8Array
                                                              (local.get $bs)
                                                              (local.get $i)))
                                  (if (i32.or
                                       (i32.eq (local.get $ch) (i32.const 0))
                                       (i32.eq (local.get $ch) (i32.const 61)))
                                      (then (call $raise-argument-error1
                                                  (global.get $symbol:environment-variables-ref)
                                                  (global.get $string:bytes-environment-variable-name?)
                                                  (local.get $name-raw))
                                            (unreachable)))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $loop)))
                     (global.get $false))
               ;; print-values : any/c ... -> any/c ...
               ;;   Module-begin helper from racket/private/modbeg. It prints
               ;;   each result through current-print and returns the original
               ;;   values unchanged.
               (func $print-values (type $Prim>=0)
                     (param $args-raw (ref eq)) ;; rest arguments as $Args
                     (result          (ref eq))

                     (local $args    (ref $Args))
                     (local $arr     (ref $Array))
                     (local $printer (ref $Procedure))
                     (local $inv     (ref $ProcedureInvoker))
                     (local $one     (ref $Args))
                     (local $len     i32)
                     (local $i       i32)
                     (local $v       (ref eq))

                     (local.set $args (array.new $Args (global.get $null) (i32.const 0)))
                     (local.set $arr  (call $make-array (i32.const 0) (global.get $null)))
                     (if (ref.test (ref $Args) (local.get $args-raw))
                         (then
                          (local.set $args (ref.cast (ref $Args) (local.get $args-raw)))
                          (local.set $len  (array.len (local.get $args)))
                          (local.set $arr  (call $make-array (local.get $len) (global.get $null)))
                          (array.copy $Array $Args
                                      (local.get $arr) (i32.const 0)
                                      (local.get $args) (i32.const 0)
                                      (local.get $len)))
                         (else
                          (local.set $arr (call $list->array (local.get $args-raw)))
                          (local.set $len (array.len (local.get $arr)))))
                     (local.set $printer
                                (ref.cast (ref $Procedure)
                                          (call $current-print (global.get $missing))))
                     (local.set $inv (struct.get $Procedure $invoke (local.get $printer)))
                     (local.set $i   (i32.const 0))
                     (block $done
                            (loop $loop
                                  (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                  (local.set $v (array.get $Array (local.get $arr) (local.get $i)))
                                  (local.set $one (array.new_fixed $Args 1 (local.get $v)))
                                  (drop (call_ref $ProcedureInvoker
                                                  (local.get $printer)
                                                  (local.get $one)
                                                  (local.get $inv)))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $loop)))

                     (call $values (local.get $args-raw)))

               ;; default-current-read-interaction : any/c input-port? -> eof-object?
               ;;   Bootstrap reader used by current-read-interaction. The
               ;;   full interactive reader is outside the current WebRacket
               ;;   startup bridge; returning EOF lets expander boot code
               ;;   install the parameter without attempting REPL reads.
               (func $default-current-read-interaction (type $Prim2)
                     (param $source-name (ref eq)) ;; source name, currently ignored
                     (param $in          (ref eq)) ;; input-port?
                     (result             (ref eq))
                     (if (i32.eqz (call $input-port-like?/i32 (local.get $in)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:default-read-interaction)
                                     (global.get $string:input-port?)
                                     (local.get $in))
                               (unreachable)))
                     (global.get $eof))

               ;; default-port-read-handler : input-port? [any/c] -> eof-object?
               ;;   Bootstrap port reader used until WebRacket has its own
               ;;   reader. This unblocks expander code that expects a valid
               ;;   port-read-handler protocol; it intentionally does not parse.
               (func $default-port-read-handler (type $Prim12)
                     (param $in     (ref eq)) ;; input-port?
                     (param $source (ref eq)) ;; optional source name, ignored
                     (result        (ref eq))
                     (if (i32.eqz (call $input-port-like?/i32 (local.get $in)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:default-port-read-handler)
                                     (global.get $string:input-port?)
                                     (local.get $in))
                               (unreachable)))
                     (global.get $eof))

               (func $default-port-read-handler/1 (type $Prim1)
                     (param $in (ref eq)) ;; input-port?
                     (result    (ref eq))
                     (if (i32.eqz (call $input-port-like?/i32 (local.get $in)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:default-port-read-handler)
                                     (global.get $string:input-port?)
                                     (local.get $in))
                               (unreachable)))
                     (global.get $eof))

               ;; read : [input-port?] -> any/c
               ;;   Full `read` parses Racket datums from a port. WebRacket has
               ;;   byte/string input helpers, but not the Racket reader yet.
               ;;   Keep this as a loud link-time bridge for provider code that
               ;;   imports `read` without calling it.
               (func $read (type $Prim01)
                     (param $in (ref eq)) ;; optional input-port?, default = current-input-port
                     (result    (ref eq))
                     (if (i32.and (i32.eqz (ref.eq (local.get $in) (global.get $missing)))
                                  (i32.eqz (call $input-port-like?/i32 (local.get $in))))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:read)
                                     (global.get $string:input-port?)
                                     (local.get $in))
                               (unreachable)))
                     (drop (call $raise
                                 (call $exn:fail:unsupported/make
                                       (global.get $string:read-unsupported)
                                       (call $current-continuation-marks
                                             (global.get $missing)))
                                 (global.get $true)))
                     (unreachable))

               ;; read-syntax : [any/c] [input-port?] -> syntax?
               ;;   See `read`: syntax-producing reader support is intentionally
               ;;   absent until the reader subsystem is implemented.
               (func $read-syntax (type $Prim02)
                     (param $source-name (ref eq)) ;; optional source name
                     (param $in          (ref eq)) ;; optional input-port?, default = current-input-port
                     (result             (ref eq))
                     (if (i32.and (i32.eqz (ref.eq (local.get $in) (global.get $missing)))
                                  (i32.eqz (call $input-port-like?/i32 (local.get $in))))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:read-syntax)
                                     (global.get $string:input-port?)
                                     (local.get $in))
                               (unreachable)))
                     (drop (call $raise
                                 (call $exn:fail:unsupported/make
                                       (global.get $string:read-syntax-unsupported)
                                       (call $current-continuation-marks
                                             (global.get $missing)))
                                 (global.get $true)))
                     (unreachable))
               ;; port-read-handler : input-port? -> procedure?
               ;;   Get the Racket-level read handler attached to an input
               ;;   port. The setter form is deferred until WebRacket has a
               ;;   robust optional-argument primitive path for [1 2] arities.
               ;;   File/device substrate may later come from rktio-like host
               ;;   support, but this hook belongs to the Racket port layer.
               (func $port-read-handler (type $Prim1)
                     (param $in-raw (ref eq)) ;; input-port?
                     (result        (ref eq))

                     (local $in      (ref $InputPort))
                     (local $handler (ref eq))

                     (if (i32.eqz (ref.test (ref $InputPort) (local.get $in-raw)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:port-read-handler)
                                     (global.get $string:input-port?)
                                     (local.get $in-raw))
                               (unreachable)))
                     (local.set $in (ref.cast (ref $InputPort) (local.get $in-raw)))
                     (local.set $handler
                                (struct.get $InputPort $read-handler (local.get $in)))
                     (if (ref.eq (local.get $handler) (global.get $false))
                         (then (return (global.get $default-port-read-handler-value)))
                         (else (return (local.get $handler))))
                     (unreachable))

               ;; default-port-write-handler : any/c output-port? -> void?
               ;;   Minimal default write handler. It uses WebRacket's narrow
               ;;   write-mode formatter so strings are quoted for `~s` and
               ;;   other write-through-handler paths.
               (func $default-port-write-handler (type $Prim2)
                     (param $v   (ref eq)) ;; any/c
                     (param $out (ref eq)) ;; output-port?
                     (result     (ref eq))
                     (if (i32.eqz (call $output-port-like?/i32 (local.get $out)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:default-port-write-handler)
                                     (global.get $string:output-port?)
                                     (local.get $out))
                               (unreachable)))
                     (drop (call $write-string
                                 (call $format/write (local.get $v))
                                 (local.get $out)
                                 (global.get $missing)
                                 (global.get $missing)))
                     (global.get $void))

               ;; default-port-display-handler : any/c output-port? -> void?
               ;;   Minimal default display handler using WebRacket's existing
               ;;   generic value renderer. Despite the helper name, that
               ;;   renderer is not a complete implementation of Racket display.
               (func $default-port-display-handler (type $Prim2)
                     (param $v   (ref eq)) ;; any/c
                     (param $out (ref eq)) ;; output-port?
                     (result     (ref eq))
                     (if (i32.eqz (call $output-port-like?/i32 (local.get $out)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:default-port-display-handler)
                                     (global.get $string:output-port?)
                                     (local.get $out))
                               (unreachable)))
                     (drop (call $write-string
                                 (call $format/display (local.get $v))
                                 (local.get $out)
                                 (global.get $missing)
                                 (global.get $missing)))
                     (global.get $void))

               ;; default-port-print-handler : any/c output-port? [0-or-1] -> void?
               ;;   Minimal default print handler. The optional quote-depth
               ;;   argument is accepted for Racket's port-print-handler shape.
               ;;   The current formatter handles the first print-as-expression
               ;;   quoting step and otherwise falls back to write mode.
               (func $default-port-print-handler (type $Prim23)
                     (param $v           (ref eq)) ;; any/c
                     (param $out         (ref eq)) ;; output-port?
                     (param $quote-depth (ref eq)) ;; optional (or/c 0 1)
                     (result             (ref eq))
                     (local $depth-raw i32)
                     (if (i32.eqz (call $output-port-like?/i32 (local.get $out)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:default-port-print-handler)
                                     (global.get $string:output-port?)
                                     (local.get $out))
                               (unreachable)))
                     (if (i32.eqz (ref.eq (local.get $quote-depth) (global.get $missing)))
                         (then
                          (if (i32.eqz (ref.test (ref i31) (local.get $quote-depth)))
                              (then (call $raise-argument-error1
                                          (global.get $symbol:default-port-print-handler)
                                          (global.get $string:print-quote-depth)
                                          (local.get $quote-depth))
                                    (unreachable)))
                          (local.set $depth-raw
                                     (i31.get_s (ref.cast (ref i31) (local.get $quote-depth))))
                          (if (i32.eqz (i32.or (i32.eq (local.get $depth-raw) (i32.const 0))
                                               (i32.eq (local.get $depth-raw) (i32.const 2))))
                              (then (call $raise-argument-error1
                                          (global.get $symbol:default-port-print-handler)
                                          (global.get $string:print-quote-depth)
                                          (local.get $quote-depth))
                                    (unreachable)))))
                     (drop (call $write-string
                                 (call $format/print
                                       (local.get $v)
                                       (local.get $quote-depth))
                                 (local.get $out)
                                 (global.get $missing)
                                 (global.get $missing)))
                     (global.get $void))

               ;; port-write-handler : output-port? [procedure?] -> procedure? or void?
               ;;   WebRacket accepts the setter protocol but currently keeps
               ;;   string ports on the default handler. This is enough for
               ;;   libraries that copy handlers while constructing ports. A
               ;;   prop:output-port wrapper is accepted when it resolves to an
               ;;   underlying native output port; full per-port handler storage
               ;;   should be added with richer ports.
               (func $port-write-handler (type $Prim12)
                     (param $out-raw     (ref eq)) ;; output-port?
                     (param $handler-raw (ref eq)) ;; optional procedure?
                     (result             (ref eq))
                     (local $out (ref eq))
                     (local.set $out
                                (if (result (ref eq))
                                    (ref.test (ref $OutputPort) (local.get $out-raw))
                                    (then (local.get $out-raw))
                                    (else (call $prop-output-port-target
                                                (local.get $out-raw)))))
                     (if (i32.eqz (ref.test (ref $OutputPort) (local.get $out)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:port-write-handler)
                                     (global.get $string:output-port?)
                                     (local.get $out-raw))
                               (unreachable)))
                     (if (ref.eq (local.get $handler-raw) (global.get $missing))
                         (then (return (global.get $default-port-write-handler-value))))
                     (if (ref.eq (call $procedure? (local.get $handler-raw))
                                 (global.get $false))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:port-write-handler)
                                     (global.get $string:procedure?)
                                     (local.get $handler-raw))
                               (unreachable)))
                     (global.get $void))

               ;; port-display-handler : output-port? [procedure?] -> procedure? or void?
               ;;   See port-write-handler for the current setter limitation.
               (func $port-display-handler (type $Prim12)
                     (param $out-raw     (ref eq)) ;; output-port?
                     (param $handler-raw (ref eq)) ;; optional procedure?
                     (result             (ref eq))
                     (local $out (ref eq))
                     (local.set $out
                                (if (result (ref eq))
                                    (ref.test (ref $OutputPort) (local.get $out-raw))
                                    (then (local.get $out-raw))
                                    (else (call $prop-output-port-target
                                                (local.get $out-raw)))))
                     (if (i32.eqz (ref.test (ref $OutputPort) (local.get $out)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:port-display-handler)
                                     (global.get $string:output-port?)
                                     (local.get $out-raw))
                               (unreachable)))
                     (if (ref.eq (local.get $handler-raw) (global.get $missing))
                         (then (return (global.get $default-port-display-handler-value))))
                     (if (ref.eq (call $procedure? (local.get $handler-raw))
                                 (global.get $false))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:port-display-handler)
                                     (global.get $string:procedure?)
                                     (local.get $handler-raw))
                               (unreachable)))
                     (global.get $void))

               ;; port-print-handler : output-port? [procedure?] -> procedure? or void?
               ;;   WebRacket does not yet store handlers per port. The setter
               ;;   updates the process-wide print handler, which is enough for
               ;;   the staged io/format `~v` path to honor print handling.
               (func $port-print-handler (type $Prim12)
                     (param $out-raw     (ref eq)) ;; output-port?
                     (param $handler-raw (ref eq)) ;; optional procedure?
                     (result             (ref eq))
                     (local $out (ref eq))
                     (local.set $out
                                (if (result (ref eq))
                                    (ref.test (ref $OutputPort) (local.get $out-raw))
                                    (then (local.get $out-raw))
                                    (else (call $prop-output-port-target
                                                (local.get $out-raw)))))
                     (if (i32.eqz (ref.test (ref $OutputPort) (local.get $out)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:port-print-handler)
                                     (global.get $string:output-port?)
                                     (local.get $out-raw))
                               (unreachable)))
                     (if (ref.eq (local.get $handler-raw) (global.get $missing))
                         (then (return (global.get $default-port-print-handler-value))))
                     (if (ref.eq (call $procedure? (local.get $handler-raw))
                                 (global.get $false))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:port-print-handler)
                                     (global.get $string:procedure?)
                                     (local.get $handler-raw))
                               (unreachable)))
                     (global.set $default-port-print-handler-value
                                 (local.get $handler-raw))
                     (global.get $void))
               ;; default-error-syntax->name-handler : syntax? -> #f
               ;;   Bootstrap default for error-syntax->name-handler.
               (func $default-error-syntax->name-handler (type $Prim1)
                     (param $stx (ref eq)) ;; syntax object, currently ignored
                     (result     (ref eq))
                     (global.get $false))

               ;; default-error-value->string-handler : any/c exact-nonnegative-integer? -> string?
               ;;   Bootstrap default for error-value->string-handler.
               (func $default-error-value->string-handler (type $Prim2)
                     (param $v   (ref eq)) ;; value to render
                     (param $len (ref eq)) ;; maximum length, currently ignored
                     (result     (ref eq))
                     (call $format/display (local.get $v)))

               ;; default-error-syntax->string-handler : any/c (or/c exact-nonnegative-integer? #f) -> string?
               ;;   Bootstrap default for error-syntax->string-handler.
               (func $default-error-syntax->string-handler (type $Prim2)
                     (param $v   (ref eq)) ;; syntax object or S-expression
                     (param $len (ref eq)) ;; maximum length or #f, currently ignored
                     (result     (ref eq))
                     (call $format/display (local.get $v)))

               ;; default-error-module-path->string-handler : any/c exact-nonnegative-integer? -> string?
               ;;   Bootstrap default for error-module-path->string-handler.
               (func $default-error-module-path->string-handler (type $Prim2)
                     (param $v   (ref eq)) ;; module path value
                     (param $len (ref eq)) ;; maximum length, currently ignored
                     (result     (ref eq))
                     (call $format/display (local.get $v)))
     ))

;; io-handler-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register bootstrap environment, reader, port, and error handler helpers.
(define io-handler-runtime-only-helpers
  (function-forms->runtime-helpers
   'io-handler-runtime-only-helpers
   io-handler-runtime-only-forms))

;; io-handler-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given I/O handler names from the runtime helper index.
(define (io-handler-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; io-handler-reader-printer-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render bootstrap reader and printer helpers in runtime assembly order.
(define (io-handler-reader-printer-runtime-helper-forms helper-index)
  (io-handler-helper-forms helper-index io-handler-reader-printer-runtime-only-helper-names))

;; io-handler-environment-predicate-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render environment-variables? in runtime assembly order.
(define (io-handler-environment-predicate-runtime-helper-forms helper-index)
  (io-handler-helper-forms helper-index io-handler-environment-predicate-runtime-only-helper-names))

;; io-handler-environment-ref-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render environment-variables-ref in runtime assembly order.
(define (io-handler-environment-ref-runtime-helper-forms helper-index)
  (io-handler-helper-forms helper-index io-handler-environment-ref-runtime-only-helper-names))

;; io-handler-port-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render port handler helpers in runtime assembly order.
(define (io-handler-port-runtime-helper-forms helper-index)
  (io-handler-helper-forms helper-index io-handler-port-runtime-only-helper-names))

;; io-handler-error-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render default error rendering helpers in runtime assembly order.
(define (io-handler-error-runtime-helper-forms helper-index)
  (io-handler-helper-forms helper-index io-handler-error-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define io-handler-helper-index
    (make-core-runtime-helper-index io-handler-runtime-only-helpers))

  ;; tree-member? : any/c any/c -> boolean?
  ;;   Check whether a datum appears anywhere in a tree.
  (define (tree-member? needle tree)
    (cond
      [(equal? needle tree) #t]
      [(pair? tree)
       (or (tree-member? needle (car tree))
           (tree-member? needle (cdr tree)))]
      [else #f]))

  (check-equal? (map second io-handler-default-port-late-initializer-forms)
                '($default-port-read-handler-value
                  $default-port-write-handler-value
                  $default-port-display-handler-value
                  $default-port-print-handler-value))
  (check-equal? io-handler-default-port-global-names
                '($default-port-read-handler-value
                  $default-port-write-handler-value
                  $default-port-display-handler-value
                  $default-port-print-handler-value))
  (check-true (tree-member? '(global.get $symbol:default-port-read-handler)
                            io-handler-default-port-late-initializer-forms))
  (check-true (tree-member? '(global.get $symbol:default-port-write-handler)
                            io-handler-default-port-late-initializer-forms))
  (check-true (tree-member? '(global.get $symbol:default-port-display-handler)
                            io-handler-default-port-late-initializer-forms))
  (check-true (tree-member? '(global.get $symbol:default-port-print-handler)
                            io-handler-default-port-late-initializer-forms))

  (check-equal?
   (map form-name
        (io-handler-reader-printer-runtime-helper-forms io-handler-helper-index))
   io-handler-reader-printer-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (io-handler-environment-predicate-runtime-helper-forms io-handler-helper-index))
   io-handler-environment-predicate-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (io-handler-environment-ref-runtime-helper-forms io-handler-helper-index))
   io-handler-environment-ref-runtime-only-helper-names)

  (check-equal?
   (map form-name (io-handler-port-runtime-helper-forms io-handler-helper-index))
   io-handler-port-runtime-only-helper-names)

  (check-equal?
   (map form-name (io-handler-error-runtime-helper-forms io-handler-helper-index))
   io-handler-error-runtime-only-helper-names))
