#lang racket

(provide printer-extension-runtime-helper-forms
         formatting-core-runtime-helpers
         printer-prefix-formatting-runtime-string-constants
         immediate-value-formatting-runtime-string-constants
         opaque-value-formatting-runtime-string-constants
         character-notation-formatting-runtime-string-constants
         arrow-formatting-runtime-string-constants
         hash-less-formatting-runtime-string-constants
         formatting-runtime-symbol-constants
         formatting-runtime-string-constants
         struct-type-property-formatting-runtime-string-constants
         unquoted-printing-string-core-runtime-helper-forms
         unquoted-printing-string-runtime-helper-forms
         display-formatting-core-runtime-helper-forms
         formatting-runtime-helper-forms
         numeric-display-formatting-runtime-helper-forms
         formatting-runtime-only-helpers)

(require "../core-helper.rkt"
         (only-in "paths.rkt"
                  path-display-formatting-runtime-string-constants
                  path-display-formatting-runtime-only-forms)
         "../../private/wasm-utils.rkt"
         (only-in "../../private/immediates.rkt"
                  char-mask
                  char-shift
                  char-tag))

;; printer-prefix-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used as prefixes or literal markers by printers.
(define printer-prefix-formatting-runtime-string-constants
  '((hash-variable-reference    "#<variable-reference>")
    (box-prefix                 "#&")
    (bytes-prefix               "#\"")
    (backslash                  "\\")
    (double-quote               "\"")
    (single-quote               "'")
    (hash-t                     "#t")
    (hash-f                     "#f")
    (hash-hash                  "#hash")
    (hash-hasheq                "#hasheq")
    (hash-hasheqv               "#hasheqv")
    (hash-hashalw               "#hashalw")
    (hash-rx                    "#rx")
    (hash-px                    "#px")))

;; immediate-value-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used to format immediate singleton values.
(define immediate-value-formatting-runtime-string-constants
  '((null                       "()")
    (eof                        "#<eof>")
    (void                       "#<void>")
    (unspecified                "#<unspecified>")
    (undefined                  "#<undefined>")
    (unsafe-undefined           "#<unsafe-undefined>")))

;; opaque-value-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used to format opaque runtime values.
(define opaque-value-formatting-runtime-string-constants
  '((closure                    "#<closure>")
    (external                   "#<external>")
    (external-null              "#<external-null>")
    (linklet                    "#<linklet>")
    (instance                   "#<instance>")
    (namespace                  "#<namespace>")
    (continuation-mark-set      "#<continuation-mark-set>")))

;; character-notation-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by character and keyword notation printers.
(define character-notation-formatting-runtime-string-constants
  '((hash-colon                 "#:")
    (hash-backslash             "#\\")
    (hash-backslash-u           "#\\u")
    (hash-backslash-U           "#\\U")
    (word-newline               "newline")
    (word-tab                   "tab")
    (word-return                "return")
    (word-backspace             "backspace")
    (word-space                 "space")
    (word-rubout                "rubout")
    (word-nul                   "nul")
    (unknown                    "unknown")))

;; arrow-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare the arrow marker used by formatting helpers.
(define arrow-formatting-runtime-string-constants
  '((->                         ">")))

;; hash-less-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used to format unreadable values.
(define hash-less-formatting-runtime-string-constants
  (append
   '((syntax-open                "#<syntax ")
     (syntax-close               ">")
     (hash-less-boxed-colon      "#<boxed:")
     (hash-less-namespace-colon  "#<namespace:")
     (hash-less-procedure-colon  "#<procedure:")
     (hash-less-primitive-colon  "#<primitive:"))
   path-display-formatting-runtime-string-constants
   '((hash-less-input-port       "#<input-port>")
     (hash-less-output-port      "#<output-port>")
     (hash-less-ephemeron        "#<ephemeron>")
     (hash-less-placeholder      "#<placeholder>")
     (hash-less-hash-placeholder "#<hash-placeholder>")
     (hash-less-treelist         "#<treelist>")
     (hash-less-treelist-colon-space "#<treelist: ")
     (hash-less-semaphore        "#<semaphore>")
     (hash-less-semaphore-peek-evt "#<semaphore-peek-evt>")
     (hash-less-always-evt       "#<always-evt>")
     (hash-less-never-evt        "#<never-evt>")
     (hash-less-channel          "#<channel>")
     (hash-less-channel-put-evt  "#<channel-put-evt>")
     (hash-less-handle-evt       "#<handle-evt>")
     (hash-less-will-executor    "#<will-executor>")
     (hash-less-logger           "#<logger>")
     (hash-less-log-receiver     "#<log-receiver>")
     (hash-less-bytes-converter  "#<bytes-converter>")
     (hash-less-pseudo-random-generator "#<pseudo-random-generator>")
     (hash-less-uninterruptible-lock "#<uninterruptible-lock>")
     (hash-less-weak-box         "#<weak-box>")
     (hash-less-thread           "#<thread>")
     (hash-less-thread-group     "#<thread-group>")
     (hash-less-thread-cell      "#<thread-cell>")
     (hash-less-continuation-mark-key "#<continuation-mark-key>")
     (hash-less-custodian        "#<custodian>")
     (hash-less-custodian-box    "#<custodian-box>")
     (hash-less-security-guard   "#<security-guard>")
     (hash-less-parameterization "#<parameterization>")
     (hash-less-impersonator-property "#<impersonator-property>")
     (hash-less-environment-variables "#<environment-variables>")
     (hash-less-module-path-index "#<module-path-index>")
     (hash-less-resolved-module-path "#<resolved-module-path>")
     (hash-less-regexp           "#<regexp>"))))

;; formatting-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by formatting and printer-extension helpers.
(define formatting-runtime-symbol-constants
  '(format
    fprintf))

;; formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by formatting and printer-extension helpers.
(define formatting-runtime-string-constants
  '((custom-write?              "custom-write?")
    (custom-print-quotable?     "custom-print-quotable?")
    (format-displayable-value?  "known printable value?")
    (missing                    "#<missing>")
    (open-paren                 "(")
    (close-paren                ")")
    (open-brace                 "{")
    (close-brace                "}")
    (mcons-prefix               "(mcons ")
    (dot-space                  ". ")
    (space-dot-space            " . ")
    (date-prefix                "#(struct:date ")
    (date-star-prefix           "#(struct:date* ")
    (srcloc-prefix              "#(struct:srcloc ")
    (stencil-prefix             "#<stencil ")
    (stencil-prefix-colon-space ": ")
    (vector-prefix              "#(")
    (values-prefix              "(values")
    (unquoted-printing-string?  "unquoted-printing-string?")
    (colon                      ":")
    (dash                       "-")
    (bang                       "!")
    (backslash-x                "\\x")
    (set                        "set")
    (format-arg-count-prefix    "format: format string requires ")
    (format-arg-count-mid       " arguments, given ")
    (format-arg-count-args      "; arguments were:")
    (format-bad-character-prefix "format: format string requires a character, given something else\n  bad argument: ")
    (format-bad-exact-integer-prefix "format: format string requires a exact integer, given something else\n  bad argument: ")
    (format-ill-formed-prefix   "format: ill-formed pattern string\n  explanation: ")
    (format-ill-formed-dangling "cannot end in `~`")
    (format-ill-formed-tag-prefix "tag `~")
    (format-ill-formed-tag-suffix "` not allowed")
    (format-ill-formed-dot      "tag `~.` not followed by `a`, `s`, or `v`")
    (format-ellipsis            "...")
    (format-display:got-boxed   "internal formatter encountered boxed value")
    (format-display:got-box     "internal formatter encountered box value")
    (format-display:got-values  "internal formatter encountered values")
    (format-display:expected-vector "internal formatter expected vector")
    (format-display:expected-values "internal formatter expected values")))

;; struct-type-property-formatting-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by struct type property formatting.
(define struct-type-property-formatting-runtime-string-constants
  '((hash-less-struct-type-property-colon "#<struct-type-property:")))

;; Half : datum? -> datum?
;;   Decode a tagged fixnum expression to an i32 payload.
(define (Half x)
  `(i32.shr_s ,x (i32.const 1)))

;; printer-extension-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate printer-extension helpers used by the monolithic runtime.
(define printer-extension-runtime-only-helpers
  (function-forms->runtime-helpers
   'printer-extension-runtime-only-helpers
   '(
         (func $custom-write? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $type      (ref null $StructType))
               (local $struct    (ref $Struct))
               (local $sentinel  (ref eq))
               (local $prop-name (ref $Symbol))
               (local $prop-val  (ref eq))

               (if (ref.test (ref $Struct) (local.get $v))
                   (then (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                         (local.set $type   (struct.get $Struct $type (local.get $struct))))
                   (else (if (ref.test (ref $StructType) (local.get $v))
                             (then (local.set $type (ref.cast (ref $StructType) (local.get $v))))
                             (else (return (global.get $false))))))

               (local.set $prop-name
                          (ref.cast (ref $Symbol) (global.get $symbol:prop:custom-write)))
               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (ref.as_non_null (local.get $type))
                                (local.get $prop-name)
                                (local.get $sentinel)))

               (if (result (ref eq))
                   (ref.eq (local.get $prop-val) (local.get $sentinel))
                   (then (global.get $false))
                   (else (global.get $true))))

         (func $custom-write-accessor (type $Prim12)
               (param $v        (ref eq))
               (param $fallback (ref eq)) ;; optional fallback result, default = contract error
               (result          (ref eq))

               (local $type      (ref null $StructType))
               (local $struct    (ref $Struct))
               (local $sentinel  (ref eq))
               (local $prop-name (ref $Symbol))
               (local $prop-val  (ref eq))

               (local.set $sentinel (call $cons (global.get $false)
                                                (global.get $false)))

               (if (ref.test (ref $Struct) (local.get $v))
                   (then (local.set $struct (ref.cast (ref $Struct)
                                                      (local.get $v)))
                         (local.set $type (struct.get $Struct $type
                                                      (local.get $struct))))
                   (else
                    (if (ref.test (ref $StructType) (local.get $v))
                        (then (local.set $type (ref.cast (ref $StructType)
                                                         (local.get $v))))
                        (else
                         (if (ref.eq (local.get $fallback) (global.get $missing))
                             (then (call $raise-argument-error1
                                         (global.get
                                          $symbol:custom-write-accessor)
                                         (global.get $string:custom-write?)
                                         (local.get $v))
                                   (unreachable))
                             (else (return (local.get $fallback))))))))

               (local.set $prop-name
                          (ref.cast (ref $Symbol)
                                    (global.get $symbol:prop:custom-write)))
               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (ref.as_non_null (local.get $type))
                                (local.get $prop-name)
                                (local.get $sentinel)))

               (if (ref.eq (local.get $prop-val) (local.get $sentinel))
                   (then
                    (if (ref.eq (local.get $fallback) (global.get $missing))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:custom-write-accessor)
                                    (global.get $string:custom-write?)
                                    (local.get $v))
                              (unreachable))
                        (else (return (local.get $fallback))))))

               (local.get $prop-val))

         (func $custom-print-quotable? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $type      (ref null $StructType))
               (local $struct    (ref $Struct))
               (local $sentinel  (ref eq))
               (local $prop-name (ref $Symbol))
               (local $prop-val  (ref eq))

               (if (ref.test (ref $Struct) (local.get $v))
                   (then (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                         (local.set $type   (struct.get $Struct $type (local.get $struct))))
                   (else (if (ref.test (ref $StructType) (local.get $v))
                             (then (local.set $type (ref.cast (ref $StructType) (local.get $v))))
                             (else (return (global.get $false))))))

               (local.set $prop-name
                          (ref.cast (ref $Symbol) (global.get $symbol:prop:custom-print-quotable)))
               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (ref.as_non_null (local.get $type))
                                (local.get $prop-name)
                                (local.get $sentinel)))

               (if (result (ref eq))
                   (ref.eq (local.get $prop-val) (local.get $sentinel))
                   (then (global.get $false))
                   (else (global.get $true))))

         (func $custom-print-quotable-accessor (type $Prim12)
               (param $v        (ref eq))
               (param $fallback (ref eq)) ;; optional fallback result, default = contract error
               (result          (ref eq))

               (local $type      (ref null $StructType))
               (local $struct    (ref $Struct))
               (local $sentinel  (ref eq))
               (local $prop-name (ref $Symbol))
               (local $prop-val  (ref eq))

               (local.set $sentinel (call $cons (global.get $false) (global.get $false)))
               (if (ref.test (ref $Struct) (local.get $v))
                   (then (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                         (local.set $type (struct.get $Struct $type (local.get $struct))))
                   (else (if (ref.test (ref $StructType) (local.get $v))
                             (then (local.set $type (ref.cast (ref $StructType) (local.get $v))))
                             (else
                              (if (ref.eq (local.get $fallback) (global.get $missing))
                                  (then (call $raise-argument-error1
                                              (global.get $symbol:custom-print-quotable-accessor)
                                              (global.get $string:custom-print-quotable?)
                                              (local.get $v))
                                        (unreachable))
                                  (else (return (local.get $fallback))))))))

               (local.set $prop-name
                          (ref.cast (ref $Symbol)
                                    (global.get $symbol:prop:custom-print-quotable)))
               (local.set $prop-val
                          (call $struct-type-property-lookup-by-name
                                (ref.as_non_null (local.get $type))
                                (local.get $prop-name)
                                (local.get $sentinel)))

               (if (ref.eq (local.get $prop-val) (local.get $sentinel))
                   (then
                    (if (ref.eq (local.get $fallback) (global.get $missing))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:custom-print-quotable-accessor)
                                    (global.get $string:custom-print-quotable?)
                                    (local.get $v))
                              (unreachable))
                        (else (return (local.get $fallback))))))

               (local.get $prop-val))

         (func $format/struct/custom-write
               (param $s    (ref $Struct))
               (param $proc (ref $Procedure))
               (param $mode (ref eq))
               (result      (ref $String))

               (local $port (ref $OutputStringPort))
               (local $args (ref $Args))
               (local $inv  (ref $ProcedureInvoker))

               (local.set $port
                          (ref.cast (ref $OutputStringPort)
                                    (call $open-output-string (global.get $missing))))
               (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
               (local.set $args (array.new $Args (global.get $null) (i32.const 3)))
               (array.set $Args (local.get $args) (i32.const 0) (local.get $s))
               (array.set $Args (local.get $args) (i32.const 1) (local.get $port))
               (array.set $Args (local.get $args) (i32.const 2) (local.get $mode))
               (drop (call_ref $ProcedureInvoker
                               (local.get $proc)
                               (local.get $args)
                               (local.get $inv)))
               (ref.cast (ref $String)
                         (call $get-output-string (local.get $port)))))))

;; printer-extension-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for printer-extension helpers.
(define printer-extension-runtime-only-helper-names
  (map core-runtime-helper-name printer-extension-runtime-only-helpers))

;; formatting-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given formatting helper names from a helper index.
(define (formatting-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; printer-extension-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render printer-extension helpers in runtime assembly order.
(define (printer-extension-runtime-helper-forms helper-index)
  (formatting-helper-forms helper-index printer-extension-runtime-only-helper-names))

;; unquoted-printing-string-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register unquoted printing string helpers used by the monolithic runtime.
(define unquoted-printing-string-runtime-only-helpers
  (function-forms->runtime-helpers
   'unquoted-printing-string-runtime-only-helpers
   '(
         ;; Unquoted printing strings wrap a string but should display without
         ;; additional quoting, matching the behavior of the underlying string.
         (func $unquoted-printing-string? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $UnquotedPrintingString) (local.get $v))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $unquoted-printing-string (type $Prim1)
               (param $s (ref eq))    ;; string?
               (result   (ref eq))    ;; unquoted-printing-string?

               (local $str (ref $String))

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected (local.get $s))
                         (unreachable)))

               (local.set $str (ref.cast (ref $String) (local.get $s)))

               (struct.new $UnquotedPrintingString
                           (i32.const 0)
                           (local.get $str)))

         (func $raise-argument-error:unquoted-printing-string-expected
               (param $got (ref eq))

               (call $raise-argument-error1
                     (global.get $symbol:unquoted-printing-string-value)
                     (global.get $string:unquoted-printing-string?)
                     (local.get $got)))

         (func $unquoted-printing-string-value (type $Prim1)
               (param $ups (ref eq))  ;; unquoted-printing-string?
               (result     (ref eq))  ;; string?

               (local $wrapped (ref $UnquotedPrintingString))

               (if (i32.eqz (ref.test (ref $UnquotedPrintingString) (local.get $ups)))
                   (then (call $raise-argument-error:unquoted-printing-string-expected
                               (local.get $ups))
                         (unreachable)))

               (local.set $wrapped (ref.cast (ref $UnquotedPrintingString) (local.get $ups)))
               (struct.get $UnquotedPrintingString $value (local.get $wrapped)))
     )))

;; unquoted-printing-string-promoted-runtime-helper-names : (listof symbol?)
;;   Name unquoted-printing-string helpers available in the standalone core runtime.
(define unquoted-printing-string-promoted-runtime-helper-names
  (map core-runtime-helper-name unquoted-printing-string-runtime-only-helpers))

;; unquoted-printing-string-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate unquoted-printing-string helpers available in standalone core runtime.
(define unquoted-printing-string-core-runtime-helpers
  (select-runtime-helpers unquoted-printing-string-runtime-only-helpers
                          unquoted-printing-string-promoted-runtime-helper-names))

;; unquoted-printing-string-runtime-only-helpers* : (listof core-runtime-helper?)
;;   Enumerate unquoted-printing-string helpers that still depend on monolithic runtime globals.
(define unquoted-printing-string-runtime-only-helpers*
  (remove-runtime-helpers unquoted-printing-string-runtime-only-helpers
                          unquoted-printing-string-promoted-runtime-helper-names))

;; unquoted-printing-string-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for unquoted printing string helpers.
(define unquoted-printing-string-runtime-only-helper-names
  (map core-runtime-helper-name unquoted-printing-string-runtime-only-helpers*))

;; unquoted-printing-string-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted unquoted-printing-string helpers in runtime assembly order.
(define (unquoted-printing-string-core-runtime-helper-forms helper-index)
  (formatting-helper-forms helper-index
                           unquoted-printing-string-promoted-runtime-helper-names))

;; unquoted-printing-string-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render unquoted printing string helpers in runtime assembly order.
(define (unquoted-printing-string-runtime-helper-forms helper-index)
  (formatting-helper-forms helper-index unquoted-printing-string-runtime-only-helper-names))

;; numeric-display-formatting-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register numeric display helpers used by the monolithic runtime.
(define numeric-display-formatting-runtime-only-helpers
  (function-forms->runtime-helpers
   'numeric-display-formatting-runtime-only-helpers
   '(
         (func $format/display:flonum
               (param $val (ref $Flonum))
               (result     (ref $String))
               (call $flonum->string (local.get $val)))

         (func $format/display:complex
               (param $val (ref $Complex))
               (result     (ref $String))

               (local $real-str (ref $String))
               (local $imag-str (ref $String))
               (local $plus     (ref $String))
               (local $suffix   (ref $String))
               (local $imag-len i32)

               (local.set $real-str
                          (ref.cast (ref $String)
                                    (call $number->string
                                          (struct.get $Complex $real (local.get $val))
                                          (global.get $false))))
               (local.set $imag-str
                          (ref.cast (ref $String)
                                    (call $number->string
                                          (struct.get $Complex $imag (local.get $val))
                                          (global.get $false))))
               (local.set $suffix (call $make-string/checked (i32.const 1) (i32.const 105))) ;; "i"
               (local.set $imag-len (call $string-length/checked/i32 (local.get $imag-str)))
               (if (i32.and
                    (i32.gt_u (local.get $imag-len) (i32.const 0))
                    (i32.or
                     (i32.eq (call $string-ref/checked/i32 (local.get $imag-str) (i32.const 0))
                             (i32.const 45)) ;; "-"
                     (i32.eq (call $string-ref/checked/i32 (local.get $imag-str) (i32.const 0))
                             (i32.const 43)))) ;; "+"
                   (then (return (call $string-append/2
                                       (call $string-append/2 (local.get $real-str)
                                                             (local.get $imag-str))
                                       (local.get $suffix)))))
               (local.set $plus (call $make-string/checked (i32.const 1) (i32.const 43))) ;; "+"
               (call $string-append/2
                     (call $string-append/2
                           (call $string-append/2 (local.get $real-str)
                                                 (local.get $plus))
                           (local.get $imag-str))
                     (local.get $suffix)))
     )))

;; numeric-display-formatting-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for numeric display helpers.
(define numeric-display-formatting-runtime-only-helper-names
  (map core-runtime-helper-name numeric-display-formatting-runtime-only-helpers))

;; numeric-display-formatting-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render numeric display formatting helpers in runtime assembly order.
(define (numeric-display-formatting-runtime-helper-forms helper-index)
  (formatting-helper-forms helper-index numeric-display-formatting-runtime-only-helper-names))

;; display-formatting-runtime-only-forms : (listof datum?)
;;   Enumerate formatting and display helpers used by the monolithic runtime.
(define display-formatting-runtime-only-forms
  `(
         (func $raise-format/display:unknown-datatype
               (param $v (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:format)
                     (global.get $string:format-displayable-value?)
                     (local.get $v))
               (unreachable))

         (func $raise-format/display:got-boxed
               (call $raise-arguments-error
                     (global.get $symbol:format)
                     (global.get $string:format-display:got-boxed)
                     (array.new_fixed $Args 0))
               (unreachable))
         (func $raise-format/display:got-box
               (call $raise-arguments-error
                     (global.get $symbol:format)
                     (global.get $string:format-display:got-box)
                     (array.new_fixed $Args 0))
               (unreachable))
         (func $raise-format/display:got-values
               (call $raise-arguments-error
                     (global.get $symbol:format)
                     (global.get $string:format-display:got-values)
                     (array.new_fixed $Args 0))
               (unreachable))

         ;; format/add-arguments-summary! : growable-array? exact-integer? list? -> void?
         ;;   Append the Racket-style "; arguments were:" suffix to a format error.
         (func $format/add-arguments-summary!
               (param $out   (ref $GrowableArray))
               (param $given i32)
               (param $args  (ref eq))

               (local $scan     (ref eq))
               (local $arg-pair (ref $Pair))

               (if (i32.gt_u (local.get $given) (i32.const 0))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (ref.cast (ref $String)
                                    (global.get $string:format-arg-count-args)))
                    (local.set $scan (local.get $args))
                    (block $done
                           (loop $loop
                                 (br_if $done (ref.eq (local.get $scan)
                                                      (global.get $null)))
                                 (if (i32.eqz (ref.test (ref $Pair)
                                                        (local.get $scan)))
                                     (then (br $done)))
                                 (local.set $arg-pair
                                            (ref.cast (ref $Pair)
                                                      (local.get $scan)))
                                 (call $growable-array-add! (local.get $out)
                                       (ref.cast (ref $String)
                                                 (global.get $string:space)))
                                 (call $growable-array-add! (local.get $out)
                                       (call $format/error-value->string
                                             (struct.get $Pair $a
                                                         (local.get $arg-pair))))
                                 (local.set $scan
                                            (struct.get $Pair $d
                                                        (local.get $arg-pair)))
                                 (br $loop))))))

         ;; raise-format:bad-argument-count : i32 i32 list? -> none
         ;;   Report a Racket-style format argument-count error.
         (func $raise-format:bad-argument-count
               (param $required i32)
               (param $given    i32)
               (param $args     (ref eq))

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out (call $make-growable-array (i32.const 10)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:format-arg-count-prefix)))
               (call $growable-array-add! (local.get $out)
                     (call $i32->string (local.get $required)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:format-arg-count-mid)))
               (call $growable-array-add! (local.get $out)
                     (call $i32->string (local.get $given)))
               (call $format/add-arguments-summary!
                     (local.get $out)
                     (local.get $given)
                     (local.get $args))
               (local.set $message
                          (call $growable-array-of-strings->string
                                (local.get $out)))
               (drop (call $raise
                           (call $exn:fail:contract/make
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-format:ill-formed-pattern : string? i32 list? -> none
         ;;   Report a Racket-style ill-formed format pattern error.
         (func $raise-format:ill-formed-pattern
               (param $explanation (ref $String))
               (param $given       i32)
               (param $args        (ref eq))

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:format-ill-formed-prefix)))
               (call $growable-array-add! (local.get $out)
                     (local.get $explanation))
               (call $format/add-arguments-summary!
                     (local.get $out)
                     (local.get $given)
                     (local.get $args))
               (local.set $message
                          (call $growable-array-of-strings->string
                                (local.get $out)))
               (drop (call $raise
                           (call $exn:fail:contract/make
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; raise-format:bad-directive-argument : string? any/c i32 list? -> none
         ;;   Report a Racket-style format directive argument-type error.
         (func $raise-format:bad-directive-argument
               (param $prefix (ref $String))
               (param $bad    (ref eq))
               (param $given  i32)
               (param $args   (ref eq))

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                     (local.get $prefix))
               (call $growable-array-add! (local.get $out)
                     (call $format/error-value->string
                           (local.get $bad)))
               (call $format/add-arguments-summary!
                     (local.get $out)
                     (local.get $given)
                     (local.get $args))
               (local.set $message
                          (call $growable-array-of-strings->string
                                (local.get $out)))
               (drop (call $raise
                           (call $exn:fail:contract/make
                                 (local.get $message)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         ;; format/truncate-to-width : string? any/c -> string?
         ;;   Truncate a rendered value according to an explicit width.
         (func $format/truncate-to-width
               (param $text (ref $String))
               (param $width-raw (ref eq))
               (result      (ref $String))

               (local $width      i32)
               (local $len        i32)
               (local $prefix-len i32)

               (if (i32.eqz (ref.test (ref i31) (local.get $width-raw)))
                   (then (return (local.get $text))))
               (local.set $width
                          (i32.shr_s
                           (i31.get_s
                            (ref.cast (ref i31) (local.get $width-raw)))
                           (i32.const 1)))
               (if (i32.lt_s (local.get $width) (i32.const 3))
                   (then (return (local.get $text))))
               (local.set $len (call $string-length/checked/i32
                                     (local.get $text)))
               (if (i32.le_u (local.get $len) (local.get $width))
                   (then (return (local.get $text))))
               (if (i32.le_u (local.get $width) (i32.const 3))
                   (then
                    (return
                     (ref.cast (ref $String)
                               (call $substring
                                     (global.get $string:format-ellipsis)
                                     ,(Imm 0)
                                     (ref.i31
                                      (i32.shl (local.get $width)
                                               (i32.const 1))))))))
               (local.set $prefix-len
                          (i32.sub (local.get $width) (i32.const 3)))
               (call $string-append/2
                     (call $substring
                           (local.get $text)
                           ,(Imm 0)
                           (ref.i31
                            (i32.shl (local.get $prefix-len)
                                     (i32.const 1))))
                     (global.get $string:format-ellipsis)))

         ;; format/truncate-to-error-print-width : string? -> string?
         ;;   Truncate a rendered value according to the current error-print-width.
         (func $format/truncate-to-error-print-width
               (param $text (ref $String))
               (result      (ref $String))

               (call $format/truncate-to-width
                     (local.get $text)
                     (call $error-print-width (global.get $missing))))

         ;; format/error-value->string : any/c -> string?
         ;;   Render a value with the current error-value->string-handler.
         (func $format/error-value->string
               (param $v (ref eq))
               (result   (ref $String))

               (local $handler (ref $Procedure))
               (local $result  (ref eq))

               (local.set $handler
                          (ref.cast (ref $Procedure)
                                    (call $error-value->string-handler
                                          (global.get $missing))))
               (local.set $result
                          (call_ref $ProcedureInvoker
                                    (local.get $handler)
                                    (array.new_fixed $Args 2
                                                     (local.get $v)
                                                     (call $error-print-width
                                                           (global.get $missing)))
                                    (struct.get $Procedure $invoke
                                                (local.get $handler))))
               (if (ref.test (ref $String) (local.get $result))
                   (then
                    (return
                     (call $format/truncate-to-error-print-width
                           (ref.cast (ref $String) (local.get $result))))))
               (if (ref.test (ref $Bytes) (local.get $result))
                   (then
                    (return
                     (call $format/truncate-to-error-print-width
                           (call $bytes->string/utf-8/defaults
                                 (ref.cast (ref $Bytes)
                                           (local.get $result)))))))
               (ref.cast (ref $String)
                         (global.get $string:format-ellipsis)))

         ;; format : string? any/c ... -> string?
         ;;   Small runtime formatter for bootstrap/error paths. It supports
         ;;   `~a`/`~A` via WebRacket's existing generic value renderer,
         ;;   `~e`/`~E` via the current error-value->string-handler,
         ;;   `~s`/`~S` through a narrow write-like path, and
         ;;   `~v`/`~V` through the print-like path, plus character, integer
         ;;   radix, and truncating `~.` directives used by error paths. Full
         ;;   Racket `format` semantics should come from the staged io/format
         ;;   provider.
         (func $format (type $Prim>=1)
               (param $fmt-raw (ref eq)) ;; format string
               (param $args    (ref eq)) ;; rest values
               (result         (ref eq))

               (local $fmt      (ref $String))
               (local $fmt-arr  (ref $I32Array))
               (local $out      (ref $I32GrowableArray))
               (local $args*    (ref eq))
               (local $scan     (ref eq))
               (local $arg-pair (ref $Pair))
               (local $value    (ref eq))
               (local $part     (ref $String))
               (local $radix    (ref eq))
               (local $len      i32)
               (local $i        i32)
               (local $cp       i32)
               (local $next     i32)
               (local $needed   i32)
               (local $given    i32)
               (local $tag-out  (ref $I32GrowableArray))

               (if (i32.eqz (ref.test (ref $String) (local.get $fmt-raw)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:format)
                               (global.get $string:string?)
                               (local.get $fmt-raw))
                         (unreachable)))
               (local.set $fmt     (ref.cast (ref $String) (local.get $fmt-raw)))
               (local.set $fmt-arr (struct.get $String $codepoints (local.get $fmt)))
               (local.set $len     (array.len (local.get $fmt-arr)))
               (local.set $out     (call $make-i32growable-array (local.get $len)))
               (local.set $args*   (local.get $args))
               (local.set $i       (i32.const 0))
               (local.set $needed  (i32.const 0))
               (local.set $given   (i32.const 0))
               (local.set $scan    (local.get $args))
               (block $count-done
                      (loop $count-loop
                            (br_if $count-done
                                   (ref.eq (local.get $scan) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $scan)))
                                (then (call $raise-argument-error1
                                            (global.get $symbol:format)
                                            (global.get $string:list?)
                                            (local.get $scan))
                                      (unreachable)))
                            (local.set $arg-pair
                                       (ref.cast (ref $Pair)
                                                 (local.get $scan)))
                            (local.set $given
                                       (i32.add (local.get $given) (i32.const 1)))
                            (local.set $scan
                                       (struct.get $Pair $d
                                                   (local.get $arg-pair)))
                            (br $count-loop)))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $cp
                                       (array.get $I32Array
                                                  (local.get $fmt-arr)
                                                  (local.get $i)))
                            (if (i32.ne (local.get $cp) (i32.const 126)) ;; '~'
                                (then
                                 (call $i32growable-array-add!
                                       (local.get $out)
                                       (local.get $cp))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (if (i32.ge_u (local.get $i) (local.get $len))
                                (then
                                 (call $raise-format:ill-formed-pattern
                                       (ref.cast (ref $String)
                                                 (global.get $string:format-ill-formed-dangling))
                                       (local.get $given)
                                       (local.get $args))
                                 (unreachable)))
                            (local.set $next
                                       (array.get $I32Array
                                                  (local.get $fmt-arr)
                                                  (local.get $i)))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))

                            (if (i32.eq (local.get $next) (i32.const 126)) ;; '~~'
                                (then
                                 (call $i32growable-array-add!
                                       (local.get $out)
                                       (i32.const 126))
                                 (br $loop)))
                            (if (i32.or
                                 (i32.eq (local.get $next) (i32.const 110)) ;; '~n'
                                 (i32.eq (local.get $next) (i32.const 37))) ;; '~%'
                                (then
                                 (call $i32growable-array-add!
                                       (local.get $out)
                                       (i32.const 10))
                                 (br $loop)))
                            (if (i32.or
                                 (i32.eq (local.get $next) (i32.const 99))  ;; '~c'
                                 (i32.eq (local.get $next) (i32.const 67))) ;; '~C'
                                (then
                                 (local.set $needed
                                            (i32.add (local.get $needed) (i32.const 1)))
                                 (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                                     (then (call $raise-format:bad-argument-count
                                                 (local.get $needed)
                                                 (local.get $given)
                                                 (local.get $args))
                                           (unreachable)))
                                 (local.set $arg-pair
                                            (ref.cast (ref $Pair) (local.get $args*)))
                                 (local.set $value
                                            (struct.get $Pair $a
                                                        (local.get $arg-pair)))
                                 (if (ref.eq (call $char? (local.get $value))
                                             (global.get $false))
                                     (then
                                      (call $raise-format:bad-directive-argument
                                            (ref.cast (ref $String)
                                                      (global.get $string:format-bad-character-prefix))
                                            (local.get $value)
                                            (local.get $given)
                                            (local.get $args))
                                      (unreachable)))
                                 (local.set $part
                                            (call $format/display:char
                                                  (local.get $value)))
                                 (call $i32growable-array-add-string!
                                       (local.get $out)
                                       (local.get $part))
                                 (local.set $args*
                                            (struct.get $Pair $d
                                                        (local.get $arg-pair)))
                                 (br $loop)))
                            (if (i32.or
                                 (i32.or
                                  (i32.eq (local.get $next) (i32.const 98))  ;; '~b'
                                  (i32.eq (local.get $next) (i32.const 66))) ;; '~B'
                                 (i32.or
                                  (i32.or
                                   (i32.eq (local.get $next) (i32.const 111)) ;; '~o'
                                   (i32.eq (local.get $next) (i32.const 79))) ;; '~O'
                                  (i32.or
                                   (i32.eq (local.get $next) (i32.const 120)) ;; '~x'
                                   (i32.eq (local.get $next) (i32.const 88))))) ;; '~X'
                                (then
                                 (local.set $needed
                                            (i32.add (local.get $needed) (i32.const 1)))
                                 (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                                     (then (call $raise-format:bad-argument-count
                                                 (local.get $needed)
                                                 (local.get $given)
                                                 (local.get $args))
                                           (unreachable)))
                                 (local.set $arg-pair
                                            (ref.cast (ref $Pair) (local.get $args*)))
                                 (local.set $value
                                            (struct.get $Pair $a
                                                        (local.get $arg-pair)))
                                 (if (ref.eq (call $exact-integer? (local.get $value))
                                             (global.get $false))
                                     (then
                                      (call $raise-format:bad-directive-argument
                                            (ref.cast (ref $String)
                                                      (global.get $string:format-bad-exact-integer-prefix))
                                            (local.get $value)
                                            (local.get $given)
                                            (local.get $args))
                                      (unreachable)))
                                 (local.set $radix
                                            (if (result (ref eq))
                                                (i32.or
                                                 (i32.eq (local.get $next) (i32.const 98))
                                                 (i32.eq (local.get $next) (i32.const 66)))
                                                (then ,(Imm 2))
                                                (else
                                                 (if (result (ref eq))
                                                     (i32.or
                                                      (i32.eq (local.get $next) (i32.const 111))
                                                      (i32.eq (local.get $next) (i32.const 79)))
                                                     (then ,(Imm 8))
                                                     (else ,(Imm 16))))))
                                 (local.set $part
                                            (ref.cast (ref $String)
                                                      (call $number->string
                                                            (local.get $value)
                                                            (local.get $radix))))
                                 (call $i32growable-array-add-string!
                                       (local.get $out)
                                       (local.get $part))
                                 (local.set $args*
                                            (struct.get $Pair $d
                                                        (local.get $arg-pair)))
                                 (br $loop)))
                            (if (i32.eq (local.get $next) (i32.const 46)) ;; '~.'
                                (then
                                 (if (i32.ge_u (local.get $i) (local.get $len))
                                     (then
                                      (call $raise-format:ill-formed-pattern
                                            (ref.cast (ref $String)
                                                      (global.get $string:format-ill-formed-dot))
                                            (local.get $given)
                                            (local.get $args))
                                      (unreachable)))
                                 (local.set $next
                                            (array.get $I32Array
                                                       (local.get $fmt-arr)
                                                       (local.get $i)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (if (i32.or
                                      (i32.or
                                       (i32.eq (local.get $next) (i32.const 97))  ;; '~.a'
                                       (i32.eq (local.get $next) (i32.const 65))) ;; '~.A'
                                      (i32.or
                                       (i32.or
                                        (i32.eq (local.get $next) (i32.const 115)) ;; '~.s'
                                        (i32.eq (local.get $next) (i32.const 83))) ;; '~.S'
                                       (i32.or
                                        (i32.eq (local.get $next) (i32.const 118)) ;; '~.v'
                                        (i32.eq (local.get $next) (i32.const 86))))) ;; '~.V'
                                     (then
                                      (local.set $needed
                                                 (i32.add (local.get $needed) (i32.const 1)))
                                      (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                                          (then (call $raise-format:bad-argument-count
                                                      (local.get $needed)
                                                      (local.get $given)
                                                      (local.get $args))
                                                (unreachable)))
                                      (local.set $arg-pair
                                                 (ref.cast (ref $Pair) (local.get $args*)))
                                      (local.set $value
                                                 (struct.get $Pair $a
                                                             (local.get $arg-pair)))
                                      (local.set $part
                                                 (if (result (ref $String))
                                                     (i32.or
                                                      (i32.eq (local.get $next)
                                                              (i32.const 97))
                                                      (i32.eq (local.get $next)
                                                              (i32.const 65)))
                                                     (then (call $format/display
                                                                 (local.get $value)))
                                                     (else
                                                      (if (result (ref $String))
                                                          (i32.or
                                                           (i32.eq (local.get $next)
                                                                   (i32.const 118))
                                                           (i32.eq (local.get $next)
                                                                   (i32.const 86)))
                                                          (then (call $format/print
                                                                      (local.get $value)
                                                                      (global.get $missing)))
                                                          (else (call $format/write
                                                                      (local.get $value)))))))
                                      (call $i32growable-array-add-string!
                                            (local.get $out)
                                            (call $format/truncate-to-error-print-width
                                                  (local.get $part)))
                                      (local.set $args*
                                                 (struct.get $Pair $d
                                                             (local.get $arg-pair)))
                                      (br $loop)))
                                 (call $raise-format:ill-formed-pattern
                                       (ref.cast (ref $String)
                                                 (global.get $string:format-ill-formed-dot))
                                       (local.get $given)
                                       (local.get $args))
                                 (unreachable)))
                            (if (i32.or
                                 (i32.or
                                  (i32.eq (local.get $next) (i32.const 97))  ;; '~a'
                                  (i32.eq (local.get $next) (i32.const 65))) ;; '~A'
                                 (i32.or
                                  (i32.eq (local.get $next) (i32.const 101)) ;; '~e'
                                  (i32.eq (local.get $next) (i32.const 69)))) ;; '~E'
                                (then
                                 (local.set $needed
                                            (i32.add (local.get $needed) (i32.const 1)))
                                 (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                                     (then (call $raise-format:bad-argument-count
                                                 (local.get $needed)
                                                 (local.get $given)
                                                 (local.get $args))
                                           (unreachable)))
                                 (local.set $arg-pair
                                            (ref.cast (ref $Pair) (local.get $args*)))
                                 (local.set $value
                                            (struct.get $Pair $a
                                                        (local.get $arg-pair)))
                                 (local.set $part
                                            (if (result (ref $String))
                                                (i32.or
                                                 (i32.eq (local.get $next)
                                                         (i32.const 97))
                                                 (i32.eq (local.get $next)
                                                         (i32.const 65)))
                                                (then (call $format/display
                                                            (local.get $value)))
                                                (else (call $format/error-value->string
                                                            (local.get $value)))))
                                 (call $i32growable-array-add-string!
                                       (local.get $out)
                                       (local.get $part))
                                 (local.set $args*
                                            (struct.get $Pair $d
                                                        (local.get $arg-pair)))
                                 (br $loop)))
                            (if (i32.or
                                 (i32.or
                                  (i32.eq (local.get $next) (i32.const 115)) ;; '~s'
                                  (i32.eq (local.get $next) (i32.const 83))) ;; '~S'
                                 (i32.or
                                  (i32.eq (local.get $next) (i32.const 118)) ;; '~v'
                                  (i32.eq (local.get $next) (i32.const 86)))) ;; '~V'
                                (then
                                 (local.set $needed
                                            (i32.add (local.get $needed) (i32.const 1)))
                                 (if (i32.eqz (ref.test (ref $Pair) (local.get $args*)))
                                     (then (call $raise-format:bad-argument-count
                                                 (local.get $needed)
                                                 (local.get $given)
                                                 (local.get $args))
                                           (unreachable)))
                                 (local.set $arg-pair
                                            (ref.cast (ref $Pair) (local.get $args*)))
                                 (local.set $part
                                            (if (result (ref $String))
                                                (i32.or
                                                 (i32.eq (local.get $next)
                                                         (i32.const 118))
                                                 (i32.eq (local.get $next)
                                                         (i32.const 86)))
                                                (then (call $format/print
                                                            (struct.get $Pair $a
                                                                        (local.get $arg-pair))
                                                            (global.get $missing)))
                                                (else (call $format/write
                                                            (struct.get $Pair $a
                                                                        (local.get $arg-pair))))))
                                 (call $i32growable-array-add-string!
                                       (local.get $out)
                                       (local.get $part))
                                 (local.set $args*
                                            (struct.get $Pair $d
                                                        (local.get $arg-pair)))
                                 (br $loop)))

                            (local.set $tag-out
                                       (call $make-i32growable-array (i32.const 16)))
                            (call $i32growable-array-add-string!
                                  (local.get $tag-out)
                                  (ref.cast (ref $String)
                                            (global.get $string:format-ill-formed-tag-prefix)))
                            (call $i32growable-array-add!
                                  (local.get $tag-out)
                                  (local.get $next))
                            (call $i32growable-array-add-string!
                                  (local.get $tag-out)
                                  (ref.cast (ref $String)
                                            (global.get $string:format-ill-formed-tag-suffix)))
                            (call $raise-format:ill-formed-pattern
                                  (call $i32growable-array->immutable-string
                                        (local.get $tag-out))
                                  (local.get $given)
                                  (local.get $args))
                            (unreachable)))

               (if (i32.gt_u (local.get $given) (local.get $needed))
                   (then (call $raise-format:bad-argument-count
                               (local.get $needed)
                               (local.get $given)
                               (local.get $args))
                         (unreachable)))

               (call $i32growable-array->immutable-string (local.get $out)))

         ;; fprintf : output-port? string? any/c ... -> void?
         ;;   Bootstrap formatter: format into a string, write it to the port,
         ;;   and return void. The supported escapes are inherited from $format.
         (func $fprintf (type $Prim>=2)
               (param $out     (ref eq)) ;; output-port?
               (param $fmt-raw (ref eq)) ;; format string
               (param $args    (ref eq)) ;; rest values
               (result         (ref eq))

               (if (ref.eq (call $output-port? (local.get $out))
                           (global.get $false))
                   (then (call $raise-argument-error1
                               (global.get $symbol:fprintf)
                               (global.get $string:output-port?)
                               (local.get $out))
                         (unreachable)))
               (drop (call $write-string
                           (call $format
                                 (local.get $fmt-raw)
                                 (local.get $args))
                           (local.get $out)
                           (global.get $missing)
                           (global.get $missing)))
               (global.get $void))

         (func $format/display
               (param $v (ref eq))
               (result   (ref $String))

               (local $s             (ref $String))
               (local $i31           (ref i31))
               (local $n             i32)
               (local $struct        (ref $Struct))
               (local $struct-type   (ref $StructType))
               (local $cw-sentinel   (ref eq))
               (local $cw-name       (ref $Symbol))
               (local $cw-val        (ref eq))
               (local $cw-proc       (ref $Procedure))
               (local $hash          (ref $Hash))
               ;; --- Case: fixnum ---
               (if (ref.test (ref i31) (local.get $v))
                   (then (local.set $i31 (ref.cast (ref i31) (local.get $v)))
                         (local.set $n (i31.get_u (local.get $i31)))
                         (if (i32.eqz (i32.and (local.get $n) (i32.const 1))) ;; check lsb = 0
                             (then (return (ref.cast (ref $String)
                                                     (call $number->string (local.get $v) ,(Imm 10))))))))
               ;; --- Case: null ---
               (if (ref.eq (local.get $v) (global.get $null))
                   (then (return (ref.cast (ref $String) (global.get $string:null)))))
               ;; --- Case: true ---
               (if (ref.eq (local.get $v) (global.get $true))
                   (then (return (ref.cast (ref $String) (global.get $string:hash-t)))))
               ;; --- Case: false ---
               (if (ref.eq (local.get $v) (global.get $false))
                   (then (return (ref.cast (ref $String) (global.get $string:hash-f)))))
               ;; --- Case: void ---
               (if (ref.eq (local.get $v) (global.get $void))
                   (then (return (ref.cast (ref $String) (global.get $string:void)))))
               ;; --- Case: eof ---
               (if (ref.eq (local.get $v) (global.get $eof))
                   (then (return (ref.cast (ref $String) (global.get $string:eof)))))
               ;; --- Case: missing ---
               (if (ref.eq (local.get $v) (global.get $missing))
                   (then (return (ref.cast (ref $String) (global.get $string:missing)))))
               ;; --- Case: undefined ---
               (if (ref.eq (local.get $v) (global.get $undefined))
                   (then (return (ref.cast (ref $String) (global.get $string:undefined)))))
               ;; --- Case: unsafe-undefined ---
               (if (ref.eq (local.get $v) (global.get $unsafe-undefined))
                   (then (return (ref.cast (ref $String) (global.get $string:unsafe-undefined)))))
               ;; --- Case: syntax ---
               (if (ref.eq (call $syntax? (local.get $v)) (global.get $true))
                   (then (return (call $format/display:syntax (local.get $v)))))
               ;; --- Case: srcloc (must appear before generic struct) ---
               (if (ref.eq (call $srcloc? (local.get $v)) (global.get $true))
                   (then (return (call $format/display:srcloc (local.get $v)))))
               ;; --- Case: struct (must appear before procedure) ---
               (if (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct      (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $struct-type (struct.get $Struct $type (local.get $struct)))
                    (local.set $cw-name     (ref.cast (ref $Symbol)
                                                      (global.get $symbol:prop:custom-write)))
                    (local.set $cw-sentinel (call $cons (global.get $false) (global.get $false)))
                    (local.set $cw-val      (call $struct-type-property-lookup-by-name
                                                  (local.get $struct-type)
                                                  (local.get $cw-name)
                                                  (local.get $cw-sentinel)))
                    (if (i32.eqz (ref.eq (local.get $cw-val) (local.get $cw-sentinel)))
                        (then (if (ref.eq (call $procedure? (local.get $cw-val))
                                          (global.get $true))
                                  (then (local.set $cw-proc
                                                   (ref.cast (ref $Procedure)
                                                             (local.get $cw-val)))
                                        (return (call $format/struct/custom-write
                                                      (local.get $struct)
                                                      (local.get $cw-proc)
                                                      (global.get $false))))))
                        (else (return (call $format/display:struct (local.get $struct)))))))
               ;; --- Case: closure ---
               (if (ref.test (ref $Closure) (local.get $v))
                   (then (return (call $format/display:procedure
                                       (ref.cast (ref $Procedure) (local.get $v))))))
               ;; --- Case: case-lambda ---
               (if (ref.test (ref $CaseClosure) (local.get $v))
                   (then (return (call $format/display:procedure
                                       (ref.cast (ref $Procedure) (local.get $v))))))
               ;; --- Case: primitive ---
               (if (ref.test (ref $PrimitiveProcedure) (local.get $v))
                   (then (return (call $format/display:primitive-procedure
                                       (ref.cast (ref $PrimitiveProcedure) (local.get $v))))))
               ;; --- Case: procedure ---
               (if (ref.eq (call $procedure? (local.get $v))
                           (global.get $true))
                   (then (return (call $format/display:procedure
                                       (ref.cast (ref $Procedure) (local.get $v))))))
               ;; --- Case: string ---
               (if (ref.test (ref $String) (local.get $v))
                   (then (return (ref.cast (ref $String) (local.get $v)))))
               ;; --- Case: bytes ---
               (if (ref.test (ref $Bytes) (local.get $v))
                   (then (return (call $format/display:bytes
                                       (ref.cast (ref $Bytes) (local.get $v))))))
               ;; --- Case: pair ---
               (if (ref.test (ref $Pair) (local.get $v))
                   (then (return (call $format/display:pair
                                       (ref.cast (ref $Pair) (local.get $v))))))
               ;; --- Case: mutable pair ---
               (if (ref.test (ref $MPair) (local.get $v))
                   (then (return (call $format/display:mpair
                                       (ref.cast (ref $MPair) (local.get $v))))))
               ;; --- Case: vector ---
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (return (call $format/display:vector
                                       (ref.cast (ref $Vector) (local.get $v))))))
               ;; --- Case: stencil vector ---
               (if (ref.test (ref $StencilVector) (local.get $v))
                   (then (return (call $format/display:stencil-vector
                                       (ref.cast (ref $StencilVector) (local.get $v))))))
               ;; --- Case: treelist ---
               (if (ref.test (ref $Treelist) (local.get $v))
                   (then (return (call $format/display:treelist
                                       (ref.cast (ref $Treelist) (local.get $v))))))
               ;; --- Case: box ---
               (if (ref.test (ref $Box) (local.get $v))
                   (then (return (call $format/display:box
                                       (ref.cast (ref $Box) (local.get $v))))))
               ;; --- Case: weak box ---
               (if (ref.test (ref $WeakBox) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-weak-box)))))
               ;; --- Case: symbol ---
               (if (ref.test (ref $Symbol) (local.get $v))
                   (then (return (call $format/display:symbol
                                       (ref.cast (ref $Symbol) (local.get $v))))))
               ;; --- Case: keyword ---
               (if (ref.test (ref $Keyword) (local.get $v))
                   (then (return (call $format/display:keyword
                                       (ref.cast (ref $Keyword) (local.get $v))))))
               ;; --- Case: bignum ---
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then (return (call $bignum->string
                                       (ref.cast (ref $Bignum) (local.get $v))
                                       (i32.const 10)))))
               ;; --- Case: rational ---
               (if (ref.test (ref $Rational) (local.get $v))
                   (then (return (call $rational->string
                                       (ref.cast (ref $Rational) (local.get $v))
                                       (i32.const 10)))))
               ;; --- Case: flonum ---
               (if (ref.test (ref $Flonum) (local.get $v))
                   (then (return (call $format/display:flonum
                                       (ref.cast (ref $Flonum) (local.get $v))))))
               ;; --- Case: complex ---
               (if (ref.test (ref $Complex) (local.get $v))
                   (then (return (call $format/display:complex
                                       (ref.cast (ref $Complex) (local.get $v))))))
               ;; --- Case: date* (must appear before date) ---
               (if (ref.test (ref $DateStar) (local.get $v))
                   (then (return (call $format/display:date-star
                                       (ref.cast (ref $DateStar) (local.get $v))))))
               ;; --- Case: date ---
               (if (ref.test (ref $Date) (local.get $v))
                   (then (return (call $format/display:date
                                       (ref.cast (ref $Date) (local.get $v))))))
               ;; --- Case: values ---
               (if (ref.test (ref $Values) (local.get $v))
                   (then (return (call $format/display:values
                                       (ref.cast (ref $Values) (local.get $v))))))
               ;; --- Case: external ---
               (if (ref.test (ref $External) (local.get $v))
                   (then (return (call $format/display:external
                                       (ref.cast (ref $External) (local.get $v))))))
               ;; --- Case: ephemeron ---
               (if (ref.test (ref $Ephemeron) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-ephemeron)))))
               ;; --- Case: regexp ---
               (if (ref.test (ref $Regexp) (local.get $v))
                   (then (return (call $format/display:regexp
                                       (ref.cast (ref $Regexp) (local.get $v))))))
               ;; --- Case: char ---
               (if (ref.test (ref i31) (local.get $v))
                   (then (local.set $i31 (ref.cast (ref i31) (local.get $v)))
                         (local.set $n   (i31.get_u (local.get $i31)))
                         (if (i32.eq (i32.and (local.get $n) (i32.const ,char-mask))
                                     (i32.const ,char-tag))
                             (then (return (call $format/display:char (local.get $v)))))))
               ;; --- Case: hash table ---
               (if (ref.test (ref $Hash) (local.get $v))
                   (then (local.set $hash (ref.cast (ref $Hash) (local.get $v)))
                         (return (call $format/display:hash (local.get $hash)))))
               ;; --- Case: reader graph placeholders ---
               (if (ref.test (ref $HashPlaceholder) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-hash-placeholder)))))
               (if (ref.test (ref $Placeholder) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-placeholder)))))
               ;; --- Case: namespace ---
               (if (ref.test (ref $Namespace) (local.get $v))
                   (then (return (call $format/display:namespace
                                       (ref.cast (ref $Namespace) (local.get $v))))))
               ;; --- Case: continuation-mark-set ---
               (if (ref.test (ref $ContinuationMarkSet) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:continuation-mark-set)))))
               ;; --- Case: continuation-mark-key ---
               (if (ref.test (ref $ContinuationMarkKey) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-continuation-mark-key)))))
               ;; --- Case: variable-reference ---
               (if (ref.test (ref $VariableReference) (local.get $v))
                   (then (return (call $format/display:variable-reference
                                       (ref.cast (ref $VariableReference) (local.get $v))))))
               (if (ref.test (ref $ModulePathIndex) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-module-path-index)))))
               (if (ref.test (ref $ResolvedModulePath) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-resolved-module-path)))))
               ;; --- Case: struct-type-property ---
               (if (ref.test (ref $StructTypeProperty) (local.get $v))
                   (then (return (call $format/display:struct-type-property
                                       (ref.cast (ref $StructTypeProperty) (local.get $v))))))
               ;; --- Case: impersonator-property ---
               (if (ref.test (ref $ImpersonatorProperty) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-impersonator-property)))))
               ;; --- Case: linklet ---
               (if (ref.test (ref $Linklet) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:linklet)))))
               ;; --- Case: instance ---
               (if (ref.test (ref $Instance) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:instance)))))
               ;; --- Case: unquoted-printing-string ---
               (if (ref.test (ref $UnquotedPrintingString) (local.get $v))
                   (then (return (call $format/display:unquoted-printing-string
                                       (ref.cast (ref $UnquotedPrintingString) (local.get $v))))))
               ;; --- Internal data types ---
               ;; These shouldn't leak to the outside, but nice to know if it happens.
               ;; --- Case: boxed --- (shouldn't happen)
               (if (ref.test (ref $Boxed) (local.get $v))
                   #;(then (call $raise-format/display:got-boxed))
                   (then (return (call $format/display:boxed
                                       (ref.cast (ref $Boxed) (local.get $v))))))
               ;; --- Case: path ---
               (if (ref.test (ref $Path) (local.get $v))
                   (then (return (call $format/display:path
                                           (ref.cast (ref $Path) (local.get $v))))))
               ;; --- Case: string ports ---
               (if (ref.test (ref $InputPort) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-input-port)))))
               (if (ref.test (ref $OutputPort) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-output-port)))))
               ;; --- Case: opaque runtime values ---
               (if (ref.test (ref $AlwaysEvt) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-always-evt)))))
               (if (ref.test (ref $NeverEvt) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-never-evt)))))
               (if (ref.test (ref $Channel) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-channel)))))
               (if (ref.test (ref $ChannelPutEvt) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-channel-put-evt)))))
               (if (ref.test (ref $HandleEvt) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-handle-evt)))))
               (if (ref.test (ref $Semaphore) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-semaphore)))))
               (if (ref.test (ref $SemaphorePeekEvt) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-semaphore-peek-evt)))))
               (if (ref.test (ref $WillExecutor) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-will-executor)))))
               (if (ref.test (ref $Logger) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-logger)))))
               (if (ref.test (ref $LogReceiver) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-log-receiver)))))
               (if (ref.test (ref $BytesConverter) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-bytes-converter)))))
               (if (ref.test (ref $PseudoRandomGenerator) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-pseudo-random-generator)))))
               (if (ref.test (ref $UninterruptibleLock) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-uninterruptible-lock)))))
               (if (ref.test (ref $Thread) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-thread)))))
               (if (ref.test (ref $ThreadGroup) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-thread-group)))))
               (if (ref.test (ref $ThreadCell) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-thread-cell)))))
               (if (ref.test (ref $Custodian) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-custodian)))))
               (if (ref.test (ref $CustodianBox) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-custodian-box)))))
               (if (ref.test (ref $SecurityGuard) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-security-guard)))))
               (if (ref.test (ref $Parameterization) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-parameterization)))))
               (if (ref.test (ref $EnvironmentVariables) (local.get $v))
                   (then (return (ref.cast (ref $String)
                                           (global.get $string:hash-less-environment-variables)))))
               ;; --- Fallback ---
               (call $raise-format/display:unknown-datatype (local.get $v))
               (unreachable))

         ;; format/display:regexp : regexp? -> string?
         ;;   Render compact regexp values using the source carried by the
         ;;   runtime object.
         (func $format/display:regexp
               (param $rx (ref $Regexp))
               (result    (ref $String))

               (local $kind   i32)
               (local $source (ref eq))
               (local $prefix (ref $String))

               (local.set $kind (struct.get $Regexp $kind (local.get $rx)))
               (local.set $source (struct.get $Regexp $source (local.get $rx)))
               (local.set $prefix
                          (ref.cast (ref $String)
                                    (global.get $string:hash-rx)))
               (if (i32.eq (local.get $kind) (i32.const 1))
                   (then (local.set $prefix
                                    (ref.cast (ref $String)
                                              (global.get $string:hash-px))))
                   (else (if (i32.eq (local.get $kind) (i32.const 3))
                             (then (local.set $prefix
                                              (ref.cast (ref $String)
                                                        (global.get $string:hash-px)))))))
               (if (ref.test (ref $String) (local.get $source))
                   (then (return (call $string-append/2
                                       (local.get $prefix)
                                       (call $format/write:string
                                             (ref.cast (ref $String)
                                                       (local.get $source)))))))
               (if (ref.test (ref $Bytes) (local.get $source))
                   (then (return (call $string-append/2
                                       (local.get $prefix)
                                       (call $format/write:bytes
                                             (ref.cast (ref $Bytes)
                                                       (local.get $source)))))))
               (ref.cast (ref $String) (global.get $string:hash-less-regexp)))

         ;; format/add-field! : growable-array? any/c boolean? -> void?
         ;;   Append one field using display mode or write mode.
         (func $format/add-field!
               (param $out    (ref $GrowableArray))
               (param $v      (ref eq))
               (param $write? i32)
               (if (local.get $write?)
                   (then (call $growable-array-add! (local.get $out)
                               (call $format/write (local.get $v))))
                   (else (call $growable-array-add! (local.get $out)
                               (call $format/display (local.get $v))))))

         ;; format/add-space-field! : growable-array? any/c boolean? -> void?
         ;;   Append a field preceded by the struct field separator.
         (func $format/add-space-field!
               (param $out    (ref $GrowableArray))
               (param $v      (ref eq))
               (param $write? i32)
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:space)))
               (call $format/add-field!
                     (local.get $out)
                     (local.get $v)
                     (local.get $write?)))

         ;; format/date-fields-into! : growable-array? date? boolean? -> void?
         ;;   Append the fields shared by date and date* in Racket's struct order.
         (func $format/date-fields-into!
               (param $out    (ref $GrowableArray))
               (param $d      (ref $Date))
               (param $write? i32)
               (call $format/add-field!
                     (local.get $out)
                     (struct.get $Date $second (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $minute (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $hour (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $day (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $month (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $year (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $week-day (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $year-day (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $dst? (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $Date $time-zone-offset (local.get $d))
                     (local.get $write?)))

         ;; format/display:date : date? -> string?
         ;;   Render date values using Racket's transparent struct notation.
         (func $format/display:date
               (param $d (ref $Date))
               (result   (ref $String))

               (local $out (ref $GrowableArray))

               (local.set $out (call $make-growable-array (i32.const 16)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:date-prefix)))
               (call $format/date-fields-into!
                     (local.get $out)
                     (local.get $d)
                     (i32.const 0))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/date-star : date*? boolean? -> string?
         ;;   Render date* values, writing the timezone string when requested by ~s.
         (func $format/date-star
               (param $d      (ref $DateStar))
               (param $write? i32)
               (result        (ref $String))

               (local $out (ref $GrowableArray))

               (local.set $out (call $make-growable-array (i32.const 20)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:date-star-prefix)))
               (call $format/date-fields-into!
                     (local.get $out)
                     (local.get $d)
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $DateStar $nanosecond (local.get $d))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (struct.get $DateStar $time-zone-name (local.get $d))
                     (local.get $write?))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/display:date-star : date*? -> string?
         ;;   Render date* values in display mode.
         (func $format/display:date-star
               (param $d (ref $DateStar))
               (result   (ref $String))
               (call $format/date-star
                     (local.get $d)
                     (i32.const 0)))

         ;; format/write:date-star : date*? -> string?
         ;;   Render date* values in write mode.
         (func $format/write:date-star
               (param $d (ref $DateStar))
               (result   (ref $String))
               (call $format/date-star
                     (local.get $d)
                     (i32.const 1)))

         ;; format/srcloc : srcloc? boolean? -> string?
         ;;   Render srcloc values using Racket's transparent struct notation.
         (func $format/srcloc
               (param $loc    (ref eq))
               (param $write? i32)
               (result        (ref $String))

               (local $out (ref $GrowableArray))

               (local.set $out (call $make-growable-array (i32.const 12)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:srcloc-prefix)))
               (call $format/add-field!
                     (local.get $out)
                     (call $srcloc-source (local.get $loc))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (call $srcloc-line (local.get $loc))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (call $srcloc-column (local.get $loc))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (call $srcloc-position (local.get $loc))
                     (local.get $write?))
               (call $format/add-space-field!
                     (local.get $out)
                     (call $srcloc-span (local.get $loc))
                     (local.get $write?))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/display:srcloc : srcloc? -> string?
         ;;   Render srcloc values in display mode.
         (func $format/display:srcloc
               (param $loc (ref eq))
               (result     (ref $String))
               (call $format/srcloc
                     (local.get $loc)
                     (i32.const 0)))

         ;; format/write:srcloc : srcloc? -> string?
         ;;   Render srcloc values in write mode.
         (func $format/write:srcloc
               (param $loc (ref eq))
               (result     (ref $String))
               (call $format/srcloc
                     (local.get $loc)
                     (i32.const 1)))

         ;; format/stencil-vector : stencil-vector? boolean? -> string?
         ;;   Render stencil vectors using Racket's #<stencil ...> convention.
         (func $format/stencil-vector
               (param $sv     (ref $StencilVector))
               (param $write? i32)
               (result        (ref $String))

               (local $out  (ref $GrowableArray))
               (local $arr  (ref $Array))
               (local $len  i32)
               (local $mask i32)
               (local $i    i32)

               (local.set $arr  (struct.get $StencilVector $slots (local.get $sv)))
               (local.set $len  (array.len (local.get $arr)))
               (local.set $mask (struct.get $StencilVector $mask (local.get $sv)))
               (local.set $out  (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:stencil-prefix)))
               (call $growable-array-add! (local.get $out)
                     (call $i32->string (local.get $mask)))
               (if (i32.ne (local.get $mask) (i32.const 0))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (ref.cast (ref $String)
                                    (global.get $string:stencil-prefix-colon-space)))))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (call $format/add-field!
                                  (local.get $out)
                                  (array.get $Array (local.get $arr) (local.get $i))
                                  (local.get $write?))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (if (i32.lt_u (local.get $i) (local.get $len))
                                (then
                                 (call $growable-array-add! (local.get $out)
                                       (ref.cast (ref $String)
                                                 (global.get $string:space)))))
                            (br $loop)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:syntax-close)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/display:stencil-vector : stencil-vector? -> string?
         ;;   Render stencil vectors in display mode.
         (func $format/display:stencil-vector
               (param $sv (ref $StencilVector))
               (result    (ref $String))
               (call $format/stencil-vector
                     (local.get $sv)
                     (i32.const 0)))

         ;; format/write:stencil-vector : stencil-vector? -> string?
         ;;   Render stencil vectors in write mode.
         (func $format/write:stencil-vector
               (param $sv (ref $StencilVector))
               (result    (ref $String))
               (call $format/stencil-vector
                     (local.get $sv)
                     (i32.const 1)))

         ;; format/write : any/c -> string?
         ;;   Render a value using the subset of write/print-like conventions
         ;;   needed by bootstrap `format` for `~s` and `~v`. Values without a
         ;;   distinct write representation still fall back to WebRacket's
         ;;   existing generic value renderer.
         (func $format/write
               (param $v (ref eq))
               (result   (ref $String))

               (if (ref.test (ref $String) (local.get $v))
                   (then (return (call $format/write:string
                                       (ref.cast (ref $String) (local.get $v))))))
               (if (ref.test (ref $Bytes) (local.get $v))
                   (then (return (call $format/write:bytes
                                       (ref.cast (ref $Bytes) (local.get $v))))))
               (if (ref.eq (call $char? (local.get $v)) (global.get $true))
                   (then (return (call $format/write:char (local.get $v)))))
               (if (ref.test (ref $Symbol) (local.get $v))
                   (then (return (call $format/write:symbol
                                       (ref.cast (ref $Symbol) (local.get $v))))))
               (if (ref.test (ref $Keyword) (local.get $v))
                   (then (return (call $format/write:keyword
                                       (ref.cast (ref $Keyword) (local.get $v))))))
               (if (ref.test (ref $Pair) (local.get $v))
                   (then (return (call $format/write:pair
                                       (local.get $v)))))
               (if (ref.test (ref $MPair) (local.get $v))
                   (then (return (call $format/write:mpair
                                       (ref.cast (ref $MPair) (local.get $v))))))
               (if (ref.test (ref $Vector) (local.get $v))
                   (then (return (call $format/write:vector
                                       (ref.cast (ref $Vector) (local.get $v))))))
               (if (ref.test (ref $StencilVector) (local.get $v))
                   (then (return (call $format/write:stencil-vector
                                       (ref.cast (ref $StencilVector) (local.get $v))))))
               (if (ref.test (ref $Treelist) (local.get $v))
                   (then (return (call $format/write:treelist
                                       (ref.cast (ref $Treelist) (local.get $v))))))
               (if (ref.eq (call $srcloc? (local.get $v)) (global.get $true))
                   (then (return (call $format/write:srcloc (local.get $v)))))
               (if (ref.test (ref $Struct) (local.get $v))
                   (then (return (call $format/write:struct
                                       (ref.cast (ref $Struct) (local.get $v))))))
               (if (ref.test (ref $Box) (local.get $v))
                   (then (return (call $format/write:box
                                       (ref.cast (ref $Box) (local.get $v))))))
               (if (ref.test (ref $Hash) (local.get $v))
                   (then (return (call $format/write:hash
                                       (ref.cast (ref $Hash) (local.get $v))))))
               (if (ref.test (ref $DateStar) (local.get $v))
                   (then (return (call $format/write:date-star
                                       (ref.cast (ref $DateStar) (local.get $v))))))
               (if (ref.test (ref $Date) (local.get $v))
                   (then (return (call $format/display:date
                                       (ref.cast (ref $Date) (local.get $v))))))
               (call $format/display (local.get $v)))

         ;; format/print : any/c [0-or-1] -> string?
         ;;   Render the subset of print mode controlled by print-as-expression.
         ;;   When print-as-expression is true and quote depth is 0, quotable
         ;;   values receive a leading quote; otherwise print falls back to
         ;;   write-like rendering.
         (func $format/print
               (param $v           (ref eq))
               (param $quote-depth (ref eq))
               (result             (ref $String))

               (local $quote? i32)
               (local $text   (ref $String))
               (local $struct      (ref $Struct))
               (local $struct-type (ref $StructType))
               (local $cw-sentinel (ref eq))
               (local $cw-name     (ref $Symbol))
               (local $cw-val      (ref eq))
               (local $cw-proc     (ref $Procedure))

               (local.set $quote? (i32.const 0))
               (if (ref.eq (call $parameter-value-or-global
                                  (global.get $prim:print-as-expression)
                                  (global.get $print-as-expression-value))
                            (global.get $true))
                   (then
                    (if (ref.eq (local.get $quote-depth) (global.get $missing))
                        (then (local.set $quote? (i32.const 1)))
                        (else
                         (if (ref.test (ref i31) (local.get $quote-depth))
                             (then
                              (if (i32.eqz (call $fixnum->i32 (local.get $quote-depth)))
                                  (then (local.set $quote? (i32.const 1))))))))))
               (if (ref.test (ref $Struct) (local.get $v))
                   (then
                    (local.set $struct      (ref.cast (ref $Struct) (local.get $v)))
                    (local.set $struct-type (struct.get $Struct $type (local.get $struct)))
                    (local.set $cw-name     (ref.cast (ref $Symbol)
                                                      (global.get $symbol:prop:custom-write)))
                    (local.set $cw-sentinel (call $cons (global.get $false) (global.get $false)))
                    (local.set $cw-val      (call $struct-type-property-lookup-by-name
                                                  (local.get $struct-type)
                                                  (local.get $cw-name)
                                                  (local.get $cw-sentinel)))
                    (if (i32.eqz (ref.eq (local.get $cw-val) (local.get $cw-sentinel)))
                        (then
                         (if (ref.eq (call $procedure? (local.get $cw-val))
                                     (global.get $true))
                             (then
                              (local.set $cw-proc
                                         (ref.cast (ref $Procedure)
                                                   (local.get $cw-val)))
                              (return (call $format/struct/custom-write
                                            (local.get $struct)
                                            (local.get $cw-proc)
                                            ,(Imm 0)))))))))
               (if (ref.test (ref $MPair) (local.get $v))
                   (then (return (call $format/print:mpair
                                       (ref.cast (ref $MPair) (local.get $v))))))
               (local.set $text (call $format/write (local.get $v)))
               (if (i32.and
                    (local.get $quote?)
                    (i32.or
                     (ref.eq (local.get $v) (global.get $null))
                     (i32.or
                      (ref.test (ref $Symbol) (local.get $v))
                      (i32.or
                       (ref.test (ref $Keyword) (local.get $v))
                       (i32.or
                        (ref.test (ref $Pair) (local.get $v))
                        (i32.or
                         (ref.test (ref $Vector) (local.get $v))
                         (i32.or
                          (ref.test (ref $Hash) (local.get $v))
                          (ref.test (ref $Box) (local.get $v)))))))))
                   (then
                    (return
                     (call $string-append/2
                           (global.get $string:single-quote)
                           (local.get $text)))))
               (local.get $text))

         ;; format/write:string : string? -> string?
         ;;   Quote strings for write/print mode, including common escapes.
         (func $format/write:string
               (param $str (ref $String))
               (result     (ref $String))

               (local $arr (ref $I32Array))
               (local $out (ref $I32GrowableArray))
               (local $len i32)
               (local $i   i32)
               (local $cp  i32)

               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $len (array.len (local.get $arr)))
               (local.set $out (call $make-i32growable-array
                                      (i32.add (i32.const 2)
                                               (i32.mul (local.get $len) (i32.const 2)))))
               (call $i32growable-array-add! (local.get $out) (i32.const 34)) ;; '"'
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $cp
                                       (array.get $I32Array
                                                  (local.get $arr)
                                                  (local.get $i)))
                            (if (i32.eq (local.get $cp) (i32.const 34)) ;; '"'
                                (then
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92))
                                 (call $i32growable-array-add! (local.get $out) (i32.const 34))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (i32.eq (local.get $cp) (i32.const 92)) ;; '\'
                                (then
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92))
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (i32.eq (local.get $cp) (i32.const 10)) ;; newline
                                (then
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92))
                                 (call $i32growable-array-add! (local.get $out) (i32.const 110))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (i32.eq (local.get $cp) (i32.const 13)) ;; return
                                (then
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92))
                                 (call $i32growable-array-add! (local.get $out) (i32.const 114))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (i32.eq (local.get $cp) (i32.const 9)) ;; tab
                                (then
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92))
                                 (call $i32growable-array-add! (local.get $out) (i32.const 116))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (call $i32growable-array-add! (local.get $out) (local.get $cp))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (call $i32growable-array-add! (local.get $out) (i32.const 34)) ;; '"'
               (call $i32growable-array->immutable-string (local.get $out)))

         ;; format/symbol-simple-bare-char?/i32 : codepoint -> boolean
         ;;   Check the common non-delimiting characters that Racket writes
         ;;   without vertical bars in symbol names.
         (func $format/symbol-simple-bare-char?/i32
               (param $cp i32)
               (result    i32)

               (if (i32.and (i32.ge_u (local.get $cp) (i32.const 65))
                            (i32.le_u (local.get $cp) (i32.const 90)))
                   (then (return (i32.const 1))))
               (if (i32.and (i32.ge_u (local.get $cp) (i32.const 97))
                            (i32.le_u (local.get $cp) (i32.const 122)))
                   (then (return (i32.const 1))))
               (if (i32.and (i32.ge_u (local.get $cp) (i32.const 48))
                            (i32.le_u (local.get $cp) (i32.const 57)))
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 33))  ;; !
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 35))  ;; #
                   (then (return (i32.const 1))))
               (if (i32.and (i32.ge_u (local.get $cp) (i32.const 36))
                            (i32.le_u (local.get $cp) (i32.const 38))) ;; $ % &
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 42))  ;; *
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 43))  ;; +
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 45))  ;; -
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 46))  ;; .
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 47))  ;; /
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 58))  ;; :
                   (then (return (i32.const 1))))
               (if (i32.and (i32.ge_u (local.get $cp) (i32.const 60))
                            (i32.le_u (local.get $cp) (i32.const 64))) ;; < = > ? @
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 94))  ;; ^
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 95))  ;; _
                   (then (return (i32.const 1))))
               (if (i32.eq (local.get $cp) (i32.const 126)) ;; ~
                   (then (return (i32.const 1))))
               (i32.const 0))

         ;; format/symbol-write-style/i32 : string? -> exact-integer?
         ;;   Return 0 for bare, 1 for backslash-escaped bare, and 2 for
         ;;   vertical-bar quoted symbol output.
         (func $format/symbol-write-style/i32
               (param $name (ref $String))
               (result      i32)

               (local $arr   (ref $I32Array))
               (local $len   i32)
               (local $i     i32)
               (local $cp    i32)
               (local $first i32)
               (local $style i32)

               (local.set $arr (struct.get $String $codepoints (local.get $name)))
               (local.set $len (array.len (local.get $arr)))
               (if (i32.eqz (local.get $len))
                   (then (return (i32.const 2))))
               (local.set $first (array.get $I32Array (local.get $arr) (i32.const 0)))
               (if (i32.eq (local.get $first) (i32.const 35)) ;; #
                   (then (return (i32.const 2))))
               (if (i32.and (i32.eq (local.get $len) (i32.const 1))
                            (i32.or
                             (i32.eq (local.get $first) (i32.const 46)) ;; .
                             (i32.and (i32.ge_u (local.get $first) (i32.const 48))
                                      (i32.le_u (local.get $first) (i32.const 57)))))
                   (then (return (i32.const 2))))
               (if (i32.and (i32.ge_u (local.get $first) (i32.const 48))
                            (i32.le_u (local.get $first) (i32.const 57)))
                   (then (return (i32.const 2)))) ;; conservative numeric/readable case
               (local.set $style (i32.const 0))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $cp
                                       (array.get $I32Array
                                                  (local.get $arr)
                                                  (local.get $i)))
                            (if (i32.eq (local.get $cp) (i32.const 124)) ;; |
                                (then
                                 (local.set $style (i32.const 1))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (i32.eqz (call $format/symbol-simple-bare-char?/i32
                                               (local.get $cp)))
                                (then (return (i32.const 2))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (local.get $style))

         ;; format/write:symbol : symbol? -> string?
         ;;   Render symbols for write/print mode, including common reader
         ;;   escapes used in Racket error messages.
         (func $format/write:symbol
               (param $sym (ref $Symbol))
               (result     (ref $String))

               (local $name  (ref $String))
               (local $arr   (ref $I32Array))
               (local $out   (ref $I32GrowableArray))
               (local $len   i32)
               (local $i     i32)
               (local $cp    i32)
               (local $style i32)

               (local.set $name (ref.cast (ref $String)
                                           (call $symbol->string (local.get $sym))))
               (local.set $style (call $format/symbol-write-style/i32 (local.get $name)))
               (if (i32.eqz (local.get $style))
                   (then (return (local.get $name))))

               (local.set $arr (struct.get $String $codepoints (local.get $name)))
               (local.set $len (array.len (local.get $arr)))
               (local.set $out (call $make-i32growable-array
                                      (i32.add (i32.const 2)
                                               (i32.mul (local.get $len) (i32.const 2)))))
               (if (i32.eq (local.get $style) (i32.const 2))
                   (then (call $i32growable-array-add! (local.get $out) (i32.const 124)))) ;; |
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $cp
                                       (array.get $I32Array
                                                  (local.get $arr)
                                                  (local.get $i)))
                            (if (i32.eq (local.get $cp) (i32.const 124)) ;; |
                                (then
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92)) ;; \
                                 (call $i32growable-array-add! (local.get $out) (local.get $cp))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (call $i32growable-array-add! (local.get $out) (local.get $cp))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (if (i32.eq (local.get $style) (i32.const 2))
                   (then (call $i32growable-array-add! (local.get $out) (i32.const 124)))) ;; |
               (call $i32growable-array->immutable-string (local.get $out)))

         ;; format/keyword-write-style/i32 : string? -> exact-integer?
         ;;   Return 0 for bare, 1 for backslash-escaped bare, and 2 for
         ;;   vertical-bar quoted keyword-name output.
         (func $format/keyword-write-style/i32
               (param $name (ref $String))
               (result      i32)

               (local $arr   (ref $I32Array))
               (local $len   i32)
               (local $i     i32)
               (local $cp    i32)
               (local $first i32)
               (local $style i32)

               (local.set $arr (struct.get $String $codepoints (local.get $name)))
               (local.set $len (array.len (local.get $arr)))
               (if (i32.eqz (local.get $len))
                   (then (return (i32.const 0))))
               (local.set $first (array.get $I32Array (local.get $arr) (i32.const 0)))
               (if (i32.eq (local.get $first) (i32.const 35)) ;; #
                   (then (return (i32.const 2))))
               (if (i32.and (i32.eq (local.get $len) (i32.const 1))
                            (i32.eq (local.get $first) (i32.const 46))) ;; .
                   (then (return (i32.const 2))))
               (local.set $style (i32.const 0))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $cp
                                       (array.get $I32Array
                                                  (local.get $arr)
                                                  (local.get $i)))
                            (if (i32.eq (local.get $cp) (i32.const 124)) ;; |
                                (then
                                 (local.set $style (i32.const 1))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (i32.eqz (call $format/symbol-simple-bare-char?/i32
                                               (local.get $cp)))
                                (then (return (i32.const 2))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (local.get $style))

         ;; format/write:keyword : keyword? -> string?
         ;;   Render keywords for write/print mode.
         (func $format/write:keyword
               (param $kw (ref $Keyword))
               (result    (ref $String))

               (local $name  (ref $String))
               (local $arr   (ref $I32Array))
               (local $out   (ref $I32GrowableArray))
               (local $len   i32)
               (local $i     i32)
               (local $cp    i32)
               (local $style i32)

               (local.set $name (struct.get $Keyword $str (local.get $kw)))
               (local.set $style (call $format/keyword-write-style/i32 (local.get $name)))
               (if (i32.eqz (local.get $style))
                   (then (return (call $string-append/2
                                       (global.get $string:hash-colon)
                                       (local.get $name)))))

               (local.set $arr (struct.get $String $codepoints (local.get $name)))
               (local.set $len (array.len (local.get $arr)))
               (local.set $out (call $make-i32growable-array
                                      (i32.add (i32.const 4)
                                               (i32.mul (local.get $len) (i32.const 2)))))
               (call $i32growable-array-add-string!
                     (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:hash-colon)))
               (if (i32.eq (local.get $style) (i32.const 2))
                   (then (call $i32growable-array-add! (local.get $out) (i32.const 124)))) ;; |
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $cp
                                       (array.get $I32Array
                                                  (local.get $arr)
                                                  (local.get $i)))
                            (if (i32.eq (local.get $cp) (i32.const 124)) ;; |
                                (then
                                 (call $i32growable-array-add! (local.get $out) (i32.const 92)) ;; \
                                 (call $i32growable-array-add! (local.get $out) (local.get $cp))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (call $i32growable-array-add! (local.get $out) (local.get $cp))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (if (i32.eq (local.get $style) (i32.const 2))
                   (then (call $i32growable-array-add! (local.get $out) (i32.const 124)))) ;; |
               (call $i32growable-array->immutable-string (local.get $out)))

         ;; format/write:struct : struct? -> string?
         ;;   Render ordinary structs with write-mode field formatting while
         ;;   preserving existing custom-write behavior.
         (func $format/write:struct
               (param $s (ref $Struct))
               (result   (ref $String))

               (local $type        (ref $StructType))
               (local $name        (ref eq))
               (local $fields      (ref $Array))
               (local $n           i32)
               (local $i           i32)
               (local $out         (ref $GrowableArray))
               (local $cw-sentinel (ref eq))
               (local $cw-name     (ref $Symbol))
               (local $cw-val      (ref eq))
               (local $cw-proc     (ref $Procedure))

               (local.set $type   (struct.get $Struct     $type   (local.get $s)))
               (local.set $name   (struct.get $StructType $name   (local.get $type)))
               (local.set $fields (struct.get $Struct     $fields (local.get $s)))
               (local.set $n      (array.len (local.get $fields)))
               (local.set $cw-name
                          (ref.cast (ref $Symbol)
                                    (global.get $symbol:prop:custom-write)))
               (local.set $cw-sentinel (call $cons (global.get $false) (global.get $false)))
               (local.set $cw-val
                          (call $struct-type-property-lookup-by-name
                                (local.get $type)
                                (local.get $cw-name)
                                (local.get $cw-sentinel)))
               (if (i32.eqz (ref.eq (local.get $cw-val) (local.get $cw-sentinel)))
                   (then
                    (if (ref.eq (call $procedure? (local.get $cw-val))
                                (global.get $true))
                        (then
                         (local.set $cw-proc
                                    (ref.cast (ref $Procedure)
                                              (local.get $cw-val)))
                         (return (call $format/struct/custom-write
                                       (local.get $s)
                                       (local.get $cw-proc)
                                       (global.get $true)))))))

               (local.set $out (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:struct-open)))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $name)))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                            (call $growable-array-add! (local.get $out)
                                  (ref.cast (ref $String)
                                            (global.get $string:space)))
                            (call $growable-array-add! (local.get $out)
                                  (call $format/write
                                        (array.get $Array
                                                   (local.get $fields)
                                                   (local.get $i))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/write:bytes : bytes? -> string?
         ;;   Render bytes in quoted byte-string notation.
         (func $format/write:bytes
               (param $bs (ref $Bytes))
               (result    (ref $String))
               (call $format/write:bytes/quoted (local.get $bs)))

         ;; format/write:pair : pair? -> string?
         ;;   Render pairs recursively using write/print conventions.
         (func $format/write:pair (param $v (ref eq)) (result (ref $String))
               (local $out   (ref $GrowableArray))
               (local $stack (ref $GrowableArray))
               (local $car   (ref eq))
               (local $cdr   (ref $Pair))
               (local $tail  (ref eq))
               (local $str   (ref $String))

               (local.set $out   (call $make-growable-array (i32.const 8)))
               (local.set $stack (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:open-paren)))
               (call $growable-array-add! (local.get $stack) (local.get $v))
               (block $done
                      (loop $walk
                            (br_if $done (i32.eqz (call $growable-array-count (local.get $stack))))
                            (local.set $tail (call $growable-array-remove-last! (local.get $stack)))
                            (if (ref.test (ref $Pair) (local.get $tail))
                                (then
                                 (local.set $cdr (ref.cast (ref $Pair) (local.get $tail)))
                                 (local.set $car (struct.get $Pair $a (local.get $cdr)))
                                 (local.set $tail (struct.get $Pair $d (local.get $cdr)))
                                 (local.set $str (call $format/write (local.get $car)))
                                 (call $growable-array-add! (local.get $out) (local.get $str))
                                 (if (ref.test (ref $Pair) (local.get $tail))
                                     (then
                                      (call $growable-array-add! (local.get $out)
                                                                 (ref.cast (ref $String)
                                                                           (global.get $string:space)))
                                      (call $growable-array-add! (local.get $stack) (local.get $tail)))
                                     (else
                                      (if (ref.eq (local.get $tail) (global.get $null))
                                          (then)
                                          (else
                                           (call $growable-array-add! (local.get $out)
                                                                      (ref.cast (ref $String)
                                                                                (global.get $string:space-dot-space)))
                                           (local.set $str (call $format/write (local.get $tail)))
                                           (call $growable-array-add! (local.get $out) (local.get $str)))))))
                                (else
                                 (call $raise-format/display:pair:expected-pair
                                       (local.get $tail))
                                 (unreachable)))
                            (br $walk)))
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/write:mpair : mpair? -> string?
         ;;   Render mutable pairs recursively using write/print conventions.
         (func $format/write:mpair (param $v (ref $MPair)) (result (ref $String))
               (local $out   (ref $GrowableArray))
               (local $stack (ref $GrowableArray))
               (local $car   (ref eq))
               (local $cdr   (ref $MPair))
               (local $tail  (ref eq))
               (local $str   (ref $String))
               (local $open  (ref $String))
               (local $close (ref $String))

               (local.set $open  (ref.cast (ref $String)
                                            (global.get $string:open-paren)))
               (local.set $close (ref.cast (ref $String)
                                            (global.get $string:close-paren)))
               (if (i32.eqz
                    (ref.eq (call $parameter-value-or-global
                                  (global.get $prim:print-mpair-curly-braces)
                                  (global.get $print-mpair-curly-braces-value))
                            (global.get $false)))
                   (then (local.set $open  (ref.cast (ref $String)
                                                     (global.get $string:open-brace)))
                         (local.set $close (ref.cast (ref $String)
                                                     (global.get $string:close-brace)))))
               (local.set $out   (call $make-growable-array (i32.const 8)))
               (local.set $stack (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out) (local.get $open))
               (call $growable-array-add! (local.get $stack) (local.get $v))
               (block $done
                      (loop $walk
                            (br_if $done (i32.eqz (call $growable-array-count (local.get $stack))))
                            (local.set $tail (call $growable-array-remove-last! (local.get $stack)))
                            (if (ref.test (ref $MPair) (local.get $tail))
                                (then
                                 (local.set $cdr (ref.cast (ref $MPair) (local.get $tail)))
                                 (local.set $car (struct.get $MPair $a (local.get $cdr)))
                                 (local.set $tail (struct.get $MPair $d (local.get $cdr)))
                                 (local.set $str (call $format/write (local.get $car)))
                                 (call $growable-array-add! (local.get $out) (local.get $str))
                                 (if (ref.test (ref $MPair) (local.get $tail))
                                     (then
                                      (call $growable-array-add! (local.get $out)
                                                                 (ref.cast (ref $String)
                                                                           (global.get $string:space)))
                                      (call $growable-array-add! (local.get $stack) (local.get $tail)))
                                     (else
                                      (if (ref.eq (local.get $tail) (global.get $null))
                                          (then)
                                          (else
                                           (call $growable-array-add! (local.get $out)
                                                                      (ref.cast (ref $String)
                                                                                (global.get $string:space-dot-space)))
                                           (local.set $str (call $format/write (local.get $tail)))
                                           (call $growable-array-add! (local.get $out) (local.get $str)))))))
                                (else
                                 (call $raise-format/display:pair:expected-pair
                                       (local.get $tail))
                                 (unreachable)))
                            (br $walk)))
               (call $growable-array-add! (local.get $out) (local.get $close))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/print:mpair : mpair? -> string?
         ;;   Render mutable pairs in Racket's print/error-value form.
         (func $format/print:mpair (param $v (ref $MPair)) (result (ref $String))
               (local $out (ref $GrowableArray))

               (local.set $out (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:mcons-prefix)))
               (call $growable-array-add!
                     (local.get $out)
                     (call $format/print
                           (struct.get $MPair $a (local.get $v))
                           (global.get $missing)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:space)))
               (call $growable-array-add!
                     (local.get $out)
                     (call $format/print
                           (struct.get $MPair $d (local.get $v))
                           (global.get $missing)))
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/write:vector : vector? -> string?
         ;;   Render vectors recursively using write/print conventions.
         (func $format/write:vector (param $v (ref $Vector)) (result (ref $String))
               (local $out   (ref $GrowableArray))
               (local $arr   (ref $Array))
               (local $len   i32)
               (local $i     i32)
               (local $elem  (ref eq))
               (local $str   (ref $String))

               (local.set $arr (struct.get $Vector $arr (local.get $v)))
               (local.set $len (array.len (local.get $arr)))
               (local.set $out (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:vector-prefix)))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                            (local.set $str (call $format/write (local.get $elem)))
                            (call $growable-array-add! (local.get $out) (local.get $str))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (if (i32.lt_u (local.get $i) (local.get $len))
                                (then
                                 (call $growable-array-add! (local.get $out)
                                                            (ref.cast (ref $String)
                                                                      (global.get $string:space)))))
                            (br $loop)))
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/write:hash : hash? -> string?
         ;;   Render hashes recursively using write/print conventions.
         (func $format/write:hash
               (param $ht (ref $Hash))
               (result (ref $String))

               (local $alist      (ref eq))
               (local $alist-str  (ref $String))
               (local $prefix     (ref $String))
               (local $out        (ref $GrowableArray))

               (local.set $alist (call $hash->list
                                       (ref.cast (ref eq) (local.get $ht))
                                       (global.get $false)))
               (local.set $alist-str (call $format/write:assoc (local.get $alist)))

               (local.set $prefix (ref.cast (ref $String)
                                            (global.get $string:hash-hash)))
               (if (ref.test (ref $HashEq) (local.get $ht))
                   (then (local.set $prefix (ref.cast (ref $String)
                                                      (global.get $string:hash-hasheq)))))
               (if (ref.test (ref $HashEqv) (local.get $ht))
                   (then (local.set $prefix (ref.cast (ref $String)
                                                      (global.get $string:hash-hasheqv)))))
               (if (ref.test (ref $HashEqualAlways) (local.get $ht))
                   (then (local.set $prefix (ref.cast (ref $String)
                                                      (global.get $string:hash-hashalw)))))

               (local.set $out (call $make-growable-array (i32.const 2)))
               (call $growable-array-add! (local.get $out) (local.get $prefix))
               (call $growable-array-add! (local.get $out) (local.get $alist-str))
               (call $growable-array-of-strings->string (local.get $out)))

         (func $format/display:hash
               (param $ht (ref $Hash))
               (result (ref $String))

               (local $alist      (ref eq))
               (local $alist-str  (ref $String))
               (local $prefix     (ref $String))
               (local $out        (ref $GrowableArray))

               ;; Convert hash entries to an association list.
               (local.set $alist (call $hash->list
                                          (ref.cast (ref eq) (local.get $ht))
                                          (global.get $false)))
               (local.set $alist-str (call $format/display:assoc (local.get $alist)))

               ;; Determine hash prefix based on table equivalence.
               (local.set $prefix (ref.cast (ref $String)
                                           (global.get $string:hash-hash)))
               (if (ref.test (ref $HashEq) (local.get $ht))
                   (then (local.set $prefix (ref.cast (ref $String)
                                                      (global.get $string:hash-hasheq)))))
               (if (ref.test (ref $HashEqv) (local.get $ht))
                   (then (local.set $prefix (ref.cast (ref $String)
                                                      (global.get $string:hash-hasheqv)))))
               (if (ref.test (ref $HashEqualAlways) (local.get $ht))
                   (then (local.set $prefix (ref.cast (ref $String)
                                                      (global.get $string:hash-hashalw)))))

               ;; Prefix + association list content -> final string.
               (local.set $out (call $make-growable-array (i32.const 2)))
               (call $growable-array-add! (local.get $out) (local.get $prefix))
               (call $growable-array-add! (local.get $out) (local.get $alist-str))
               (call $growable-array-of-strings->string (local.get $out)))

         (func $format/display:variable-reference
               (param $v (ref eq))
               (result   (ref $String))
               (ref.cast (ref $String)
                         (global.get $string:hash-variable-reference)))

         (func $format/display:namespace
               (param $ns (ref $Namespace))
               (result (ref $String))

               (local $name (ref eq))
               (local $out  (ref $GrowableArray))

               ;; Extract namespace name
               (local.set $name (struct.get $Namespace $name (local.get $ns)))
               ;; If no name, return constant
               (if (result (ref $String))
                   (ref.eq (local.get $name) (global.get $false))
                   (then (ref.cast (ref $String)
                                   (global.get $string:namespace)))
                   (else ;; Build "#<namespace:NAME>"
                    (local.set $out (call $make-growable-array (i32.const 3)))
                    (call $growable-array-add! (local.get $out)
                          (ref.cast (ref $String)
                                    (global.get $string:hash-less-namespace-colon)))
                    (call $growable-array-add! (local.get $out)
                          (ref.cast (ref $String) (local.get $name)))
                    (call $growable-array-add! (local.get $out)
                          (ref.cast (ref $String)
                                    (global.get $string:->)))
                    (call $growable-array-of-strings->string (local.get $out)))))

         (func $format/display:struct-type-property
               (param $prop (ref $StructTypeProperty))
               (result      (ref $String))

               (local $ga   (ref $GrowableArray))
               (local $name (ref $Symbol))

               (local.set $name (struct.get $StructTypeProperty $name (local.get $prop)))
               (local.set $ga   (call $make-growable-array (i32.const 3)))
               (call $growable-array-add! (local.get $ga)
                     (ref.cast (ref $String)
                               (global.get $string:hash-less-struct-type-property-colon)))
               (call $growable-array-add! (local.get $ga)
                     (ref.cast (ref $String)
                               (call $symbol->string (local.get $name))))
               (call $growable-array-add! (local.get $ga)
                     (ref.cast (ref $String) (global.get $string:->)))
               (call $array-of-strings->string
                     (call $growable-array->array (local.get $ga))))

         (func $format/display:external
               (param $v (ref $External))
               (result (ref $String))
               (if (result (ref $String))
                   (ref.is_null (struct.get $External $v (local.get $v)))
                   (then (ref.cast (ref $String)
                                   (global.get $string:external-null)))
                   (else (ref.cast (ref $String)
                                   (global.get $string:external)))))

         (func $format/display:procedure
               ; #<procedure:name:arity:mask>
               (param $v          (ref eq))
               (result            (ref $String))

               (local $p          (ref $Procedure))
               (local $name       (ref eq))         ;; $false or $Symbol
               #;(local $arity-fx   (ref eq))       ;; fixnum (i31)
               #;(local $arity-str  (ref $String))
               (local $mask       i32)
               (local $mask-str   (ref $String))
               (local $ga         (ref $GrowableArray))

               ;; Step 1: semantic procedure check and cast
               (if (ref.eq (call $procedure? (local.get $v))
                           (global.get $false))
                   (then (call $raise-argument-error:procedure-expected (local.get $v))))
               (local.set $p (ref.cast (ref $Procedure) (local.get $v)))
               ;; Step 2: extract fields
               (local.set $name      (struct.get $Procedure $name (local.get $p)))
               #;(local.set $arity-fx  (struct.get $Procedure $arity (local.get $p)))
               ;; Step 3: convert arity to string
               #;(local.set $arity-str (call $number->string (local.get $arity-fx) (global.get $false)))
               ;; Step 4: get mask and convert to string
               ; (local.set $mask      (call $procedure-arity-mask/checked/i32 (local.get $p)))
               ; (local.set $mask-str  (call $i32->string                      (local.get $mask)))
               ;; Step 5: build output
               (local.set $ga (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $ga)
                     (ref.cast (ref $String)
                               (global.get $string:hash-less-procedure-colon)))
               (call $growable-array-add! (local.get $ga)
                     (if (result (ref eq))
                         (ref.eq (local.get $name) (global.get $false))
                         (then (ref.cast (ref $String)
                                         (global.get $string:unknown)))
                         (else (ref.cast (ref $String)
                                         (call $symbol->string (local.get $name))))))
               #;(call $growable-array-add! (local.get $ga)
                     (ref.cast (ref $String)
                               (global.get $string:colon)))
               #;(call $growable-array-add! (local.get $ga) (local.get $arity-str))
               #;(call $growable-array-add! (local.get $ga)
                     (ref.cast (ref $String)
                               (global.get $string:colon)))
               #;(call $growable-array-add! (local.get $ga) (local.get $mask-str))
               (call $growable-array-add! (local.get $ga)
                     (ref.cast (ref $String)
                               (global.get $string:->)))
               ;; Step 5: convert to string
               (call $array-of-strings->string
                     (call $growable-array->array
                           (local.get $ga))))


         (func $format/display:primitive-procedure
               (param $v (ref eq))
               (result (ref $String))

               (local $p          (ref $PrimitiveProcedure))
               (local $name       (ref eq))         ;; $false or $Symbol
               (local $arity-str  (ref $String))
               (local $mask       i32)
               (local $mask-str   (ref $String))
               (local $ga         (ref $GrowableArray))

               ;; Step 1: type check and cast
               (if (i32.eqz (ref.test (ref $PrimitiveProcedure) (local.get $v)))
                   (then (call $raise-argument-error:primitive-procedure-expected
                               (local.get $v))))
               (local.set $p (ref.cast (ref $PrimitiveProcedure) (local.get $v)))
               ;; Step 2: extract fields
               (local.set $name      (struct.get $PrimitiveProcedure $name  (local.get $p)))
               ;; Step 3: convert arity to string
               (local.set $arity-str (call $procedure-arity->expected-string (local.get $p)))
               ;; Step 4: get mask and convert to string
               (local.set $mask      (call $procedure-arity-mask/checked/i32 (local.get $p)))
               (local.set $mask-str  (call $i32->string                      (local.get $mask)))
               ;; Step 5: build output
               (local.set $ga (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $ga)
                                        (ref.cast (ref $String)
                                                 (global.get $string:hash-less-primitive-colon)))
               (call $growable-array-add!
                     (local.get $ga)
                     (if (result (ref eq))
                         (ref.eq (local.get $name) (global.get $false))
                         (then (ref.cast (ref $String)
                                          (global.get $string:unknown)))
                         (else (call $symbol->string (local.get $name)))))
               (call $growable-array-add! (local.get $ga)
                                        (ref.cast (ref $String)
                                                 (global.get $string:colon)))
               (call $growable-array-add! (local.get $ga) (local.get $arity-str))
               (call $growable-array-add! (local.get $ga)
                                        (ref.cast (ref $String)
                                                 (global.get $string:colon)))
               (call $growable-array-add! (local.get $ga) (local.get $mask-str))
               (call $growable-array-add! (local.get $ga)
                                        (ref.cast (ref $String)
                                                 (global.get $string:->)))
               ;; Step 6: convert to string
               (call $array-of-strings->string
                     (call $growable-array->array (local.get $ga))))


         (func $format/display:symbol
               (param $v (ref eq))
               (result   (ref $String))

               (call $format/display
                     (call $symbol->string
                           (local.get $v))))

         (func $format/display:keyword
               (param $v (ref eq))
               (result (ref $String))
               ;; Fail early if not a keyword (and make the path unreachable).
               (if (i32.eqz (ref.test (ref $Keyword) (local.get $v)))
                   (then
                    (call $raise-keyword-expected (local.get $v))
                    (unreachable)))
               ;; "#:" ++ underlying name string
               (call $string-append/2
                     (global.get $string:hash-colon)
                     (struct.get $Keyword $str
                                 (ref.cast (ref $Keyword) (local.get $v)))))

         ;; format/display:bytes : bytes? -> string?
         ;;   Render bytes for display mode by mapping bytes to Latin-1 chars.
         (func $format/display:bytes
               (param $bs (ref $Bytes))
               (result    (ref $String))
               (ref.cast (ref $String)
                         (call $bytes->string/latin-1
                               (local.get $bs)
                               (global.get $false)
                               (global.get $missing)
                               (global.get $missing))))

         ;; format/write:bytes/quoted : bytes? -> string?
         ;;   Render bytes in Racket's quoted byte-string notation.
         (func $format/write:bytes/quoted
               (param $bs (ref $Bytes))
               (result    (ref $String))

               (local $arr  (ref $I8Array))
               (local $len  i32)
               (local $i    i32)
               (local $byte i32)
               (local $esc  i32)
               (local $s    (ref $String))
               (local $out  (ref $GrowableArray))

               ;; Extract raw byte array and its length
               (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
               (local.set $len (array.len (local.get $arr)))

               ;; Allocate result buffer.
               ;;   Format is #"<content>", so we need 2 chars for the quotes, plus worst-case
               ;;   room to escape *every* byte (e.g., "\ooo" or "\n"), hence len * 4 slack.
               (local.set $out
                          (call $make-growable-array
                                (i32.add (i32.const 2)
                                         (i32.mul (local.get $len) (i32.const 4)))))

               ;; Emit the quoted bytes prefix:  #"
               (call $growable-array-add! (local.get $out)
                     (global.get $string:bytes-prefix))

               ;; Iterate bytes and append escaped fragments
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))

                            ;; Read next byte as unsigned 0..255 (kept in i32)
                            (local.set $byte (call $i8array-ref (local.get $arr) (local.get $i)))

                            ;; If ASCII (<= 127) and graphic or blank, emit directly (with escapings for \" and \\).
                            ;; Otherwise, try a named special escape (e.g., \n, \t); if none, fall back to octal.
                            (if (i32.and
                                 (i32.le_u (local.get $byte) (i32.const 127))
                                 (i32.or (call $is-graphic (local.get $byte))
                                         (call $is-blank   (local.get $byte))))
                                (then
                                 ;; Handle the two ASCII characters that must be escaped inside quotes:
                                 ;;   92 = '\' backslash, 34 = '"' double quote
                                 (if (i32.eq (local.get $byte) (i32.const 92))       ;; '\'
                                     (then
                                      ;; Emit "\\" to represent a single backslash
                                      (call $growable-array-add! (local.get $out) (global.get $string:backslash))
                                      (call $growable-array-add! (local.get $out) (global.get $string:backslash)))
                                     (else
                                      (if (i32.eq (local.get $byte) (i32.const 34)) ;; '"'
                                          (then
                                           ;; Emit \" to include a literal quote inside the string
                                           (call $growable-array-add! (local.get $out) (global.get $string:backslash))
                                           (call $growable-array-add! (local.get $out) (global.get $string:double-quote)))
                                          (else
                                           ;; Safe printable ASCII → emit 1-char string directly
                                           (local.set $s (call $make-string/checked (i32.const 1) (local.get $byte)))
                                           (call $growable-array-add! (local.get $out) (local.get $s)))))))
                                (else
                                  ;; Non-printable or non-ASCII:
                                  ;; Try special escapes first (returns 0 if none, else codepoint of escaped letter).
                                  (local.set $esc (call $get-special-escape (local.get $byte)))
                                  (if (i32.ne (local.get $esc) (i32.const 0))
                                      (then
                                       ;; Emit backslash + special escape letter (e.g., "\n")
                                       (call $growable-array-add! (local.get $out) (global.get $string:backslash))
                                       (local.set $s (call $make-string/checked (i32.const 1) (local.get $esc)))
                                       (call $growable-array-add! (local.get $out) (local.get $s)))
                                      (else
                                       ;; Fallback: octal escape like "\ooo"
                                       (call $growable-array-add! (local.get $out) (global.get $string:backslash))
                                       (local.set $s (call $make-oct-string (local.get $byte)))
                                       (call $growable-array-add! (local.get $out) (local.get $s))))))

                            ;; Advance to next byte
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))

               ;; Close the quoted form with a trailing quote and materialize the final string
               (call $growable-array-add! (local.get $out)
                     (global.get $string:double-quote))
               (call $growable-array-of-strings->string (local.get $out)))


         (func $raise-format/display:pair:expected-pair
               (param $v (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:format)
                     (global.get $string:pair?)
                     (local.get $v))
               (unreachable))

         (func $format/display:pair (param $v (ref eq)) (result (ref $String))
               (local $out   (ref $GrowableArray))
               (local $stack (ref $GrowableArray))
               (local $car   (ref eq))
               (local $cdr   (ref $Pair))
               (local $tail  (ref eq))
               (local $str   (ref $String))

               ;; Initialize buffers
               (local.set $out   (call $make-growable-array (i32.const 8)))
               (local.set $stack (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:open-paren)))
               (call $growable-array-add! (local.get $stack) (local.get $v))

               (block $done
                      (loop $walk
                            (br_if $done (i32.eqz (call $growable-array-count (local.get $stack))))
                            (local.set $tail (call $growable-array-remove-last! (local.get $stack)))

                            (if (ref.test (ref $Pair) (local.get $tail))
                                (then
                                 (local.set $cdr (ref.cast (ref $Pair) (local.get $tail)))
                                 (local.set $car (struct.get $Pair $a (local.get $cdr)))
                                 (local.set $tail (struct.get $Pair $d (local.get $cdr)))
                                 ;; Format car
                                 (local.set $str (call $format/display (local.get $car)))
                                 (call $growable-array-add! (local.get $out) (local.get $str))
                                 ;; Handle cdr
                                 (if (ref.test (ref $Pair) (local.get $tail))
                                     (then (call $growable-array-add! (local.get $out)
                                                                       (ref.cast (ref $String)
                                                                                (global.get $string:space)))
                                           (call $growable-array-add! (local.get $stack) (local.get $tail)))
                                     (else (if (ref.eq (local.get $tail) (global.get $null))
                                               (then) ;; proper list: done
                                               (else  ;; improper list: emit ". cdr"
                                                (call $growable-array-add! (local.get $out)
                                                                         (ref.cast (ref $String)
                                                                                  (global.get $string:space-dot-space)))
                                                (local.set $str (call $format/display (local.get $tail)))
                                                (call $growable-array-add! (local.get $out) (local.get $str)))))))
                                (else
                                 (call $raise-format/display:pair:expected-pair
                                       (local.get $tail))
                                 (unreachable)))
                            (br $walk)))
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/display:mpair : mpair? -> string?
         ;;   Render mutable pairs recursively using display conventions.
         (func $format/display:mpair (param $v (ref $MPair)) (result (ref $String))
               (local $out   (ref $GrowableArray))
               (local $stack (ref $GrowableArray))
               (local $car   (ref eq))
               (local $cdr   (ref $MPair))
               (local $tail  (ref eq))
               (local $str   (ref $String))
               (local $open  (ref $String))
               (local $close (ref $String))

               (local.set $open  (ref.cast (ref $String)
                                            (global.get $string:open-paren)))
               (local.set $close (ref.cast (ref $String)
                                            (global.get $string:close-paren)))
               (if (i32.eqz
                    (ref.eq (call $parameter-value-or-global
                                  (global.get $prim:print-mpair-curly-braces)
                                  (global.get $print-mpair-curly-braces-value))
                            (global.get $false)))
                   (then (local.set $open  (ref.cast (ref $String)
                                                     (global.get $string:open-brace)))
                         (local.set $close (ref.cast (ref $String)
                                                     (global.get $string:close-brace)))))
               (local.set $out   (call $make-growable-array (i32.const 8)))
               (local.set $stack (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out) (local.get $open))
               (call $growable-array-add! (local.get $stack) (local.get $v))

               (block $done
                      (loop $walk
                            (br_if $done (i32.eqz (call $growable-array-count (local.get $stack))))
                            (local.set $tail (call $growable-array-remove-last! (local.get $stack)))

                            (if (ref.test (ref $MPair) (local.get $tail))
                                (then
                                 (local.set $cdr (ref.cast (ref $MPair) (local.get $tail)))
                                 (local.set $car (struct.get $MPair $a (local.get $cdr)))
                                 (local.set $tail (struct.get $MPair $d (local.get $cdr)))
                                 ;; Format car
                                 (local.set $str (call $format/display (local.get $car)))
                                 (call $growable-array-add! (local.get $out) (local.get $str))
                                 ;; Handle cdr
                                 (if (ref.test (ref $MPair) (local.get $tail))
                                     (then (call $growable-array-add! (local.get $out)
                                                                       (ref.cast (ref $String)
                                                                                (global.get $string:space)))
                                           (call $growable-array-add! (local.get $stack) (local.get $tail)))
                                     (else (if (ref.eq (local.get $tail) (global.get $null))
                                               (then) ;; proper mutable list: done
                                               (else  ;; improper mutable list: emit ". cdr"
                                                (call $growable-array-add! (local.get $out)
                                                                         (ref.cast (ref $String)
                                                                                  (global.get $string:space-dot-space)))
                                                (local.set $str (call $format/display (local.get $tail)))
                                                (call $growable-array-add! (local.get $out) (local.get $str)))))))
                                (else
                                 (call $raise-format/display:pair:expected-pair
                                       (local.get $tail))
                                 (unreachable)))
                            (br $walk)))
               (call $growable-array-add! (local.get $out) (local.get $close))
               (call $growable-array-of-strings->string (local.get $out)))


         (func $raise-format/display:vector:expected-vector
               (call $raise-arguments-error
                     (global.get $symbol:format)
                     (global.get $string:format-display:expected-vector)
                     (array.new_fixed $Args 0))
               (unreachable))

         (func $format/display:vector (param $v (ref $Vector)) (result (ref $String))
               (local $out   (ref $GrowableArray))
               (local $arr   (ref $Array))
               (local $len   i32)
               (local $i     i32)
               (local $elem  (ref eq))
               (local $str   (ref $String))

               ;; Extract internal array and its length
               (local.set $arr (struct.get $Vector $arr (local.get $v)))
               (local.set $len (array.len (local.get $arr)))
               ;; Allocate result buffer
               (local.set $out (call $make-growable-array (i32.const 8)))
               ;; Emit "#("
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:vector-prefix)))
               ;; Add formatted elements with spaces
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                            (local.set $str (call $format/display (local.get $elem)))
                            (call $growable-array-add! (local.get $out) (local.get $str))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (if (i32.lt_u (local.get $i) (local.get $len))
                                (then (call $growable-array-add! (local.get $out)
                                                                   (ref.cast (ref $String)
                                                                            (global.get $string:space)))))
                            (br $loop)))
               ;; Emit ")"
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:close-paren)))
               ;; Combine and return
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/display:treelist : (ref $Treelist) -> (ref $String)
         ;;   Format a treelist as #<treelist> or #<treelist: elem ...>.
         (func $format/display:treelist-node-into!
               (param $node    (ref $TreelistNode))
               (param $height  i32)
               (param $out     (ref $GrowableArray))
               (param $emitted i32)
               (param $write?  i32)
               (result i32)
               (local $children (ref $Array))
               (local $count    i32)
               (local $i        i32)
               (local $elem     (ref eq))
               (local $child    (ref $TreelistNode))
               (local.set $children (call $treelist-node-children (local.get $node)))
               (local.set $count    (array.len (local.get $children)))
               (if (i32.eqz (local.get $height))
                   (then
                    (local.set $i (i32.const 0))
                    (block $done-leaf
                           (loop $leaf
                                 (br_if $done-leaf (i32.ge_u (local.get $i) (local.get $count)))
                                 (if (i32.gt_u (local.get $emitted) (i32.const 0))
                                     (then
                                      (call $growable-array-add! (local.get $out)
                                                                 (ref.cast (ref $String)
                                                                           (global.get $string:space)))))
                                 (local.set $elem
                                            (array.get $Array (local.get $children) (local.get $i)))
                                 (if (local.get $write?)
                                     (then
                                      (call $growable-array-add!
                                            (local.get $out)
                                            (call $format/write (local.get $elem))))
                                     (else
                                      (call $growable-array-add!
                                            (local.get $out)
                                            (call $format/display (local.get $elem)))))
                                 (local.set $emitted (i32.add (local.get $emitted) (i32.const 1)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $leaf)))
                    (return (local.get $emitted))))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
                            (local.set $child
                                       (ref.cast (ref $TreelistNode)
                                                 (array.get $Array (local.get $children) (local.get $i))))
                            (local.set $emitted
                                       (call $format/display:treelist-node-into!
                                             (local.get $child)
                                             (i32.sub (local.get $height) (i32.const 1))
                                             (local.get $out)
                                             (local.get $emitted)
                                             (local.get $write?)))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (local.get $emitted))

         (func $format/display:treelist (param $tl (ref $Treelist)) (result (ref $String))
               (local $out  (ref $GrowableArray))
               (local $len  i32)
               (local $emitted i32)

               (local.set $len (struct.get $Treelist $size (local.get $tl)))
               (if (i32.eqz (local.get $len))
                   (then
                    (return (ref.cast (ref $String)
                                      (global.get $string:hash-less-treelist)))))
               (local.set $out (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                                          (ref.cast (ref $String)
                                                    (global.get $string:hash-less-treelist-colon-space)))
               (local.set $emitted
                          (call $format/display:treelist-node-into!
                                (struct.get $Treelist $root (local.get $tl))
                                (struct.get $Treelist $height (local.get $tl))
                                (local.get $out)
                                (i32.const 0)
                                (i32.const 0)))
               (call $growable-array-add! (local.get $out)
                                          (ref.cast (ref $String)
                                                    (global.get $string:->)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/write:treelist : treelist? -> string?
         ;;   Render treelist elements recursively using write/print conventions.
         (func $format/write:treelist (param $tl (ref $Treelist)) (result (ref $String))
               (local $out     (ref $GrowableArray))
               (local $len     i32)
               (local $emitted i32)

               (local.set $len (struct.get $Treelist $size (local.get $tl)))
               (if (i32.eqz (local.get $len))
                   (then
                    (return (ref.cast (ref $String)
                                      (global.get $string:hash-less-treelist)))))
               (local.set $out (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                                          (ref.cast (ref $String)
                                                    (global.get $string:hash-less-treelist-colon-space)))
               (local.set $emitted
                          (call $format/display:treelist-node-into!
                                (struct.get $Treelist $root (local.get $tl))
                                (struct.get $Treelist $height (local.get $tl))
                                (local.get $out)
                                (i32.const 0)
                                (i32.const 1)))
               (call $growable-array-add! (local.get $out)
                                          (ref.cast (ref $String)
                                                    (global.get $string:->)))
               (call $growable-array-of-strings->string (local.get $out)))

         ; Note: the `boxed` is internal to the compiler, so the following
         ;       is strictly for debug purposes
         (func $format/display:boxed
               (param $b (ref $Boxed))
               (result   (ref $String))

               (local $val     (ref eq))
               (local $val-str (ref $String))
               (local $out     (ref $GrowableArray))

               ;; Extract value
               (local.set $val (struct.get $Boxed $v (local.get $b)))
               ;; Format the value
               (local.set $val-str (call $format/display (local.get $val)))
               ;; Allocate a growable array
               (local.set $out (call $make-growable-array (i32.const 3)))
               ;; Append "#<boxed:"
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:hash-less-boxed-colon)))
               ;; Append formatted value
               (call $growable-array-add! (local.get $out) (local.get $val-str))
               ;; Append closing ">"
               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:->)))
               ;; Combine and return
               (call $growable-array-of-strings->string (local.get $out)))

         (func $format/display:box
               (param $b (ref $Box))
               (result   (ref $String))

               (local $val     (ref eq))
               (local $val-str (ref $String))
               (local $out     (ref $GrowableArray))

               ;; Get the boxed value
               (local.set $val (struct.get $Box $v (local.get $b)))
               ;; Format the value
               (local.set $val-str (call $format/display (local.get $val)))
               ;; Allocate a growable array
               (local.set $out (call $make-growable-array (i32.const 3)))
               ;; Append "#&"
               (call $growable-array-add! (local.get $out) (global.get $string:box-prefix)) ;; "#&"
               ;; Append formatted value
               (call $growable-array-add! (local.get $out) (local.get $val-str))
               ;; Combine and return
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/write:box : box? -> string?
         ;;   Render boxes recursively using write/print conventions.
         (func $format/write:box
               (param $b (ref $Box))
               (result   (ref $String))

               (local $val     (ref eq))
               (local $val-str (ref $String))
               (local $out     (ref $GrowableArray))

               (local.set $val (struct.get $Box $v (local.get $b)))
               (local.set $val-str (call $format/write (local.get $val)))
               (local.set $out (call $make-growable-array (i32.const 3)))
               (call $growable-array-add! (local.get $out) (global.get $string:box-prefix))
               (call $growable-array-add! (local.get $out) (local.get $val-str))
               (call $growable-array-of-strings->string (local.get $out)))

         (func $raise-format/display:vector:expected-values
               (call $raise-arguments-error
                     (global.get $symbol:format)
                     (global.get $string:format-display:expected-values)
                     (array.new_fixed $Args 0))
               (unreachable))

         (func $format/display:values (param $arr (ref $Values)) (result (ref $String))
               (local $out   (ref $GrowableArray))
               (local $len   i32)
               (local $i     i32)
               (local $elem  (ref eq))
               (local $str   (ref $String))

               ;; Extract length
               (local.set $len (array.len (local.get $arr)))
               ;; Allocate result buffer
               (local.set $out (call $make-growable-array (i32.const 8)))
               ;; Emit "(values"
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:values-prefix)))
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:space)))
               ;; Add formatted elements with spaces
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                            (local.set $str (call $format/display (local.get $elem)))
                            (call $growable-array-add! (local.get $out) (local.get $str))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (if (i32.lt_u (local.get $i) (local.get $len))
                                (then (call $growable-array-add! (local.get $out)
                                                                   (ref.cast (ref $String)
                                                                            (global.get $string:space)))))
                            (br $loop)))
               ;; Emit ")"
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:close-paren)))
               ;; Combine and return
               (call $growable-array-of-strings->string (local.get $out)))

         ,@path-display-formatting-runtime-only-forms

         (func $format/display:assoc
               (param $alist (ref eq))  ;; association list (list of pairs)
               (result       (ref $String))

               (local $out       (ref $GrowableArray))
               (local $cursor    (ref eq))
               (local $cell      (ref $Pair))
               (local $entry     (ref eq))
               (local $entry-str (ref $String))
               (local $first?    i32)

               ;; Empty association list prints as "()".
               (if (ref.eq (local.get $alist) (global.get $null))
                   (then (return (ref.cast (ref $String) (global.get $string:null)))))

               ;; Prepare builders and iteration state.
               (local.set $out    (call $make-growable-array (i32.const 8)))
               (local.set $cursor (local.get $alist))
               (local.set $first? (i32.const 1))

               ;; Emit opening parenthesis.
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:open-paren)))

               ;; Iterate through the list, verifying every element is a pair
               ;; and printing it using the generic formatter.
               (block $done
                      (loop $walk
                            (br_if $done (ref.eq (local.get $cursor) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $cursor)))
                                (then (call $raise-format/display:pair:expected-pair
                                            (local.get $cursor))
                                      (unreachable)))
                            (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                            (local.set $entry (struct.get $Pair $a (local.get $cell)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $entry)))
                                (then (call $raise-format/display:pair:expected-pair
                                            (local.get $entry))
                                      (unreachable)))
                            (if (i32.eqz (local.get $first?))
                                (then (call $growable-array-add! (local.get $out)
                                                                   (ref.cast (ref $String)
                                                                            (global.get $string:space))))
                                (else (local.set $first? (i32.const 0))))
                            (local.set $entry-str (call $format/display (local.get $entry)))
                            (call $growable-array-add! (local.get $out) (local.get $entry-str))
                            (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                            (br $walk)))

               ;; Close and materialize the final string.
               (call $growable-array-add! (local.get $out)
                                        (ref.cast (ref $String)
                                                 (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/write:assoc : (listof pair?) -> string?
         ;;   Render association lists recursively using write/print conventions.
         (func $format/write:assoc
               (param $alist (ref eq))
               (result       (ref $String))

               (local $out       (ref $GrowableArray))
               (local $cursor    (ref eq))
               (local $cell      (ref $Pair))
               (local $entry     (ref eq))
               (local $entry-str (ref $String))
               (local $first?    i32)

               (if (ref.eq (local.get $alist) (global.get $null))
                   (then (return (ref.cast (ref $String) (global.get $string:null)))))

               (local.set $out    (call $make-growable-array (i32.const 8)))
               (local.set $cursor (local.get $alist))
               (local.set $first? (i32.const 1))

               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:open-paren)))
               (block $done
                      (loop $walk
                            (br_if $done (ref.eq (local.get $cursor) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $cursor)))
                                (then (call $raise-format/display:pair:expected-pair
                                            (local.get $cursor))
                                      (unreachable)))
                            (local.set $cell (ref.cast (ref $Pair) (local.get $cursor)))
                            (local.set $entry (struct.get $Pair $a (local.get $cell)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $entry)))
                                (then (call $raise-format/display:pair:expected-pair
                                            (local.get $entry))
                                      (unreachable)))
                            (if (i32.eqz (local.get $first?))
                                (then (call $growable-array-add! (local.get $out)
                                            (ref.cast (ref $String)
                                                      (global.get $string:space))))
                                (else (local.set $first? (i32.const 0))))
                            (local.set $entry-str (call $format/write (local.get $entry)))
                            (call $growable-array-add! (local.get $out) (local.get $entry-str))
                            (local.set $cursor (struct.get $Pair $d (local.get $cell)))
                            (br $walk)))

               (call $growable-array-add! (local.get $out)
                     (ref.cast (ref $String)
                               (global.get $string:close-paren)))
               (call $growable-array-of-strings->string (local.get $out)))

         (func $format/display:unquoted-printing-string
               (param $ups (ref $UnquotedPrintingString))
               (result (ref $String))

               (ref.cast (ref $String)
                         (struct.get $UnquotedPrintingString $value (local.get $ups))))

         (func $format/display:syntax
               (param $stx (ref eq))
               (result (ref $String))

               (local $out   (ref $GrowableArray))
               (local $datum (ref eq))

               (local.set $out (call $make-growable-array (i32.const 3)))
               (call $growable-array-add!
                     (local.get $out)
                     (ref.cast (ref $String) (global.get $string:syntax-open)))
               (local.set $datum (call $syntax-e (local.get $stx)))
               (call $growable-array-add!
                     (local.get $out)
                     (call $format/display (local.get $datum)))
               (call $growable-array-add!
                     (local.get $out)
                     (ref.cast (ref $String) (global.get $string:syntax-close)))
               (call $growable-array-of-strings->string (local.get $out)))

         ;; format/display:char : char? -> string?
         ;;   Render a character for display mode as the character itself.
         (func $format/display:char
               (param $v (ref eq))
               (result   (ref $String))

               (local $cp i32)

               ;; Check if input is a character immediate
               (if (i32.or (i32.eqz (ref.test (ref i31) (local.get $v)))
                           (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $v)))
                                            (i32.const ,char-mask))
                                   (i32.const ,char-tag)))
                   (then (call $raise-check-char (local.get $v))))
               ;; Decode character
               (local.set $cp (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $v)))
                                         (i32.const ,char-shift)))
               (call $make-string/checked (i32.const 1) (local.get $cp)))

         ;; format/write:char : char? -> string?
         ;;   Render a character for write/print mode using #\ notation.
         (func $format/write:char
               (param $v (ref eq))
               (result   (ref $String))

               (local $cp i32)                 ;; codepoint
               (local $s  (ref $String))       ;; temporary string

               ;; Check if input is a character immediate
               (if (i32.or (i32.eqz (ref.test (ref i31) (local.get $v)))
                           (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $v)))
                                            (i32.const ,char-mask))
                                   (i32.const ,char-tag)))
                   (then (call $raise-check-char (local.get $v))))
               ;; Decode character
               (local.set $cp (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $v)))
                                         (i32.const ,char-shift)))
               ;; Special character names
               (if (i32.eq (local.get $cp) (i32.const 10))  ;; newline
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash))
                                (ref.cast (ref $String) (global.get $string:word-newline))))))
               (if (i32.eq (local.get $cp) (i32.const 13))  ;; return
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash))
                                (ref.cast (ref $String) (global.get $string:word-return))))))
               (if (i32.eq (local.get $cp) (i32.const 9))   ;; tab
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash))
                                (ref.cast (ref $String) (global.get $string:word-tab))))))
               (if (i32.eq (local.get $cp) (i32.const 8))   ;; backspace
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash))
                                (ref.cast (ref $String) (global.get $string:word-backspace))))))
               (if (i32.eq (local.get $cp) (i32.const 127)) ;; rubout
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash))
                                (ref.cast (ref $String) (global.get $string:word-rubout))))))
               (if (i32.eq (local.get $cp) (i32.const 32))  ;; space
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash))
                                (ref.cast (ref $String) (global.get $string:word-space))))))
               (if (i32.eq (local.get $cp) (i32.const 0))  ;; nul
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash))
                                (ref.cast (ref $String) (global.get $string:word-nul))))))
               ;; Printable graphic character
               (if (call $is-graphic (local.get $cp))
                   (then
                    (local.set $s (call $make-string/checked (i32.const 1) (local.get $cp)))
                    (return (call $string-append/2
                                  (ref.cast (ref $String) (global.get $string:hash-backslash))
                                  (local.get $s)))))

               ;; Fallback for non-printable or out-of-range characters
               ;; Fallback: #\uXXXX and #\UXXXXXX
               (if (i32.le_u (local.get $cp) (i32.const 65535))  ;; ≤ 0xFFFF
                   (then (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash-u))
                                (call $make-hex-string (local.get $cp) (i32.const 4)))))
                   ;; Else use #\UXXXXXX
                   (else (return
                          (call $string-append/2
                                (ref.cast (ref $String) (global.get $string:hash-backslash-U))
                                (call $make-hex-string (local.get $cp) (i32.const 6))))))
               (unreachable))

        (func $make-oct-string
              (param $n i32)
              (result (ref $String))
              (call $number->string:convert
                    (local.get $n)
                    (i32.const 8)
                    (i32.const 3)))

        (func $make-hex-string
              (param $n      i32)    ;; input number
              (param $digits i32)    ;; minimum number of hex digits
              (result        (ref $String))

               (local $raw (ref $String))
               (local $len i32)
               (local $pad i32)
               ;; Step 1: Convert number to hex string (unpadded)
               (local.set $raw
                          (call $number->string:convert
                                (local.get $n)
                                (i32.const 16)       ;; radix = 16
                                (i32.const 8)))      ;; allow up to 8 chars for safety
               ;; Step 2: Compute padding = digits - string-length(raw)
               (local.set $len (array.len
                                (struct.get $String $codepoints (local.get $raw))))
               (local.set $pad (select
                                (i32.sub (local.get $digits) (local.get $len))
                                (i32.const 0)
                                (i32.gt_s (local.get $digits) (local.get $len))))
               ;; Step 3: If padding is zero, return raw
               (if (i32.eqz (local.get $pad))
                   (then (return (local.get $raw))))
               ;; Step 4: Make padding string of '0's and append
               (return
                (call $string-append/2
                      (call $make-string/checked (local.get $pad) (i32.const 48)) ;; 48 = '0'
                      (local.get $raw))))

               ;;;
               ;;; Formatting
               ;;;

               (func $str-number (param $n (ref eq)) (result (ref $Bytes))
                     ;; Converts a fixnum (with LSB = 0) to a UTF-8 encoded byte string.

                     (local $i31 (ref i31))
                     (local $v   i32)
                     (local $abs i32)
                     (local $neg i32)
                     (local $tmp i32)
                     (local $i   i32)
                     (local $j   i32)
                     (local $len i32)
                     (local $buf (ref $I8Array))
                     (local $out (ref $I8Array))
                     ;; 1. Cast and unbox fixnum (assume it has LSB=0)
                     (local.set $i31 (ref.cast (ref i31) (local.get $n)))
                     (local.set $v (i32.shr_s (i31.get_s (local.get $i31)) (i32.const 1))) ;; shift to remove tag bit
                     ;; 2. Compute abs and sign
                     (local.set $neg (i32.lt_s (local.get $v) (i32.const 0)))
                     (local.set $abs (select
                                      (i32.sub (i32.const 0) (local.get $v))
                                      (local.get $v)
                                      (local.get $neg)))
                     ;; 3. Special case: 0
                     (if (i32.eqz (local.get $abs))
                         (then
                          (return
                           (struct.new $Bytes
                                       (i32.const 0)
                                       (i32.const 1)
                                       (array.new $I8Array (i32.const 48) (i32.const 1)))))) ;; ASCII '0'
                     ;; 4. Allocate temporary buffer (max 11 digits)
                     (local.set $buf (array.new_default $I8Array (i32.const 11)))
                     (local.set $i (i32.const 11))
                     ;; 5. Extract digits (in reverse)
                     (block $done
                            (loop $loop
                                  (br_if $done (i32.eqz (local.get $abs)))
                                  (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                                  (local.set $tmp (i32.rem_u (local.get $abs) (i32.const 10)))
                                  (array.set $I8Array (local.get $buf) (local.get $i)
                                             (i32.add (local.get $tmp) (i32.const 48))) ;; ASCII '0' + digit
                                  (local.set $abs (i32.div_u (local.get $abs) (i32.const 10)))
                                  (br $loop)))
                     ;; 6. Add minus sign if needed
                     (if (local.get $neg)
                         (then
                          (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                          (array.set $I8Array (local.get $buf) (local.get $i) (i32.const 45)))) ;; ASCII '-'
                     ;; 7. Allocate output and copy from temp
                     (local.set $len (i32.sub (i32.const 11) (local.get $i)))
                     (local.set $out (array.new_default $I8Array (local.get $len)))
                     (local.set $j (i32.const 0))
                     (block $done
                            (loop $copy
                                  (br_if $done (i32.ge_u (local.get $j) (local.get $len)))
                                  (array.set $I8Array (local.get $out) (local.get $j)
                                             (array.get_u $I8Array (local.get $buf)
                                                          (i32.add (local.get $i) (local.get $j))))
                                  (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                  (br $copy)))
                     ;; 8. Wrap in $Bytes struct
                     (struct.new $Bytes
                                 (i32.const 0)          ;; hash
                                 (i32.const 1)          ;; immutable
                                 (local.get $out)))


               ;; ----------------------------------------------------------------------------
               ;; Racket-style (str-bytes v opt-mode) in Wasm GC
               ;;
               ;; This module implements a function `$str-bytes` that converts a string `v`
               ;; into a byte string representation based on a given mode, following Racket's
               ;; conventions for `write`, `print`, and `display`.
               ;;
               ;; Assumed existing definitions:
               ;;   (type $Bytes  (array (mut i8)))
               ;;   (type $String (array (mut i32))) ;; An array of Unicode code points
               ;;   (type (sub (ref i31)) (ref eq))  ;; For fixnums
               ;; ----------------------------------------------------------------------------

               ;;;; ------------------------------------------------------------------------
               ;;;; Helper Functions
               ;;;; ------------------------------------------------------------------------

               ;;; (func $is-blank char) -> bool
               ;;; A simplified check for blank characters: space (32) and tab (9).
               (func $is-blank (param $char i32) (result i32)
                     (i32.or
                      (i32.eq (local.get $char) (i32.const 32))   ;; #\space
                      (i32.eq (local.get $char) (i32.const 9))))  ;; #\tab

               ;;; (func $is-graphic char) -> bool
               ;;; A simplified check for graphic characters. This is an approximation
               ;;; of Racket's `char-graphic?`. It treats characters as graphic if they
               ;;; are not C0 control characters (U+00-U+1F), not DEL (U+7F).
               (func $is-graphic (param $char i32) (result i32)
                     (i32.and
                      (i32.ge_u (local.get $char) (i32.const 32))
                      (i32.ne   (local.get $char) (i32.const 127))))

               ;;; (func $get-special-escape char) -> escape_char_or_0
               ;;; Checks if a character has a simple one-letter escape sequence.
               ;;; Returns the escape character's ASCII value (e.g., 'a' for BEL) or 0.
               (func $get-special-escape (param $char i32) (result i32)
                     (block $result (result i32)
                            (if (i32.eq (local.get $char) (i32.const  7)) (then (return (i32.const  97)))) ;; \a BEL
                            (if (i32.eq (local.get $char) (i32.const  8)) (then (return (i32.const  98)))) ;; \b BS
                            (if (i32.eq (local.get $char) (i32.const  9)) (then (return (i32.const 116)))) ;; \t TAB
                            (if (i32.eq (local.get $char) (i32.const 10)) (then (return (i32.const 110)))) ;; \n LF
                            (if (i32.eq (local.get $char) (i32.const 11)) (then (return (i32.const 118)))) ;; \v VT
                            (if (i32.eq (local.get $char) (i32.const 12)) (then (return (i32.const 102)))) ;; \f FF
                            (if (i32.eq (local.get $char) (i32.const 13)) (then (return (i32.const 114)))) ;; \r CR
                            (if (i32.eq (local.get $char) (i32.const 27)) (then (return (i32.const 101)))) ;; \e ESC
                            (i32.const 0))) ;; No special escape

               ;;; (func $utf8-size char) -> byte_count
               ;;; Calculates the number of bytes required to represent a Unicode
               ;;; code point in UTF-8.
               (func $utf8-size (param $char i32) (result i32)
                     (if (result i32) (i32.le_u (local.get $char) (i32.const 0x7f))
                         (then (i32.const 1))
                         (else
                          (if (result i32) (i32.le_u (local.get $char) (i32.const 0x7ff))
                              (then (i32.const 2))
                              (else
                               (if (result i32) (i32.le_u (local.get $char) (i32.const 0xffff))
                                   (then (i32.const 3))
                                   (else (i32.const 4))))))))

               ;;; (func $write-utf8 buf idx char) -> new_idx
               ;;; Encodes a Unicode code point as UTF-8 and writes it into the buffer.
               ;;; Returns the updated buffer index.
               (func $write-utf8
                     (param $buf  (ref $Bytes))
                     (param $idx  i32)
                     (param $char i32)
                     (result      i32)

                     (local $arr (ref $I8Array))
                     ;; Extract raw array from $Bytes struct
                     (local.set $arr (struct.get $Bytes 2 (local.get $buf))) ;; field 2 = $bs
                     ;; Encode UTF-8 based on code point range
                     (if (i32.le_u (local.get $char) (i32.const 0x7f))
                         (then (array.set $I8Array (local.get $arr) (local.get $idx) (local.get $char))
                               (return (i32.add (local.get $idx) (i32.const 1)))))

                     (if (i32.le_u (local.get $char) (i32.const 0x7ff))
                         (then
                          (array.set $I8Array (local.get $arr) (local.get $idx)
                                     (i32.or (i32.shr_u (local.get $char) (i32.const 6)) (i32.const 0xc0)))
                          (array.set $I8Array (local.get $arr)
                                     (i32.add (local.get $idx) (i32.const 1))
                                     (i32.or (i32.and (local.get $char) (i32.const 0x3f)) (i32.const 0x80)))
                          (return (i32.add (local.get $idx) (i32.const 2)))))

                     (if (i32.le_u (local.get $char) (i32.const 0xffff))
                         (then
                          (array.set $I8Array (local.get $arr) (local.get $idx)
                                     (i32.or (i32.shr_u (local.get $char) (i32.const 12)) (i32.const 0xe0)))
                          (array.set $I8Array (local.get $arr)
                                     (i32.add (local.get $idx) (i32.const 1))
                                     (i32.or (i32.and (i32.shr_u (local.get $char) (i32.const 6)) (i32.const 0x3f)) (i32.const 0x80)))
                          (array.set $I8Array (local.get $arr)
                                     (i32.add (local.get $idx) (i32.const 2))
                                     (i32.or (i32.and (local.get $char) (i32.const 0x3f)) (i32.const 0x80)))
                          (return (i32.add (local.get $idx) (i32.const 3)))))

                     (if (i32.le_u (local.get $char) (i32.const 0x10ffff))
                         (then
                          (array.set $I8Array (local.get $arr) (local.get $idx)
                                     (i32.or (i32.shr_u (local.get $char) (i32.const 18)) (i32.const 0xf0)))
                          (array.set $I8Array (local.get $arr)
                                     (i32.add (local.get $idx) (i32.const 1))
                                     (i32.or (i32.and (i32.shr_u (local.get $char) (i32.const 12)) (i32.const 0x3f)) (i32.const 0x80)))
                          (array.set $I8Array (local.get $arr)
                                     (i32.add (local.get $idx) (i32.const 2))
                                     (i32.or (i32.and (i32.shr_u (local.get $char) (i32.const 6)) (i32.const 0x3f)) (i32.const 0x80)))
                          (array.set $I8Array (local.get $arr)
                                     (i32.add (local.get $idx) (i32.const 3))
                                     (i32.or (i32.and (local.get $char) (i32.const 0x3f)) (i32.const 0x80)))
                          (return (i32.add (local.get $idx) (i32.const 4)))))
                     ;; Invalid input — return unchanged index
                     (local.get $idx)) ;; Should not happen for valid Unicode


               ;;; (func $write-hex buf idx val digits)
               ;;; Writes the lower `digits` of `val` as hexadecimal characters into the buffer.
               (func $write-hex
                     (param $buf (ref $Bytes))
                     (param $idx i32)
                     (param $val i32)
                     (param $digits i32)

                     (local $i i32)
                     (local $shift i32)
                     (local $nibble i32)
                     (local $char i32)
                     (local $write-pos i32)
                     (local $arr (ref $I8Array))

                     ;; Extract the raw array from the $Bytes struct
                     (local.set $arr (struct.get $Bytes 2 (local.get $buf)))

                     (local.set $i (i32.sub (local.get $digits) (i32.const 1)))
                     (loop $hex-loop
                           (if (i32.ge_s (local.get $i) (i32.const 0))
                               (then
                                ;; Compute nibble from val
                                (local.set $shift (i32.shl (local.get $i) (i32.const 2))) ;; same as *4
                                (local.set $nibble
                                           (i32.and
                                            (i32.shr_u (local.get $val) (local.get $shift))
                                            (i32.const 0xF)))
                                ;; Convert nibble to ASCII
                                (local.set $char
                                           (if (result i32) (i32.lt_s (local.get $nibble) (i32.const 10))
                                               (then (i32.add (local.get $nibble) (i32.const 48)))    ;; '0'..'9'
                                               (else (i32.add (local.get $nibble) (i32.const 87)))))  ;; 'a'..'f'
                                ;; Compute write index and store
                                (local.set $write-pos
                                           (i32.add
                                            (local.get $idx)
                                            (i32.sub (i32.sub (local.get $digits) (local.get $i)) (i32.const 1))))
                                (array.set $I8Array (local.get $arr) (local.get $write-pos) (local.get $char))
                                ;; Continue loop
                                (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                                (br $hex-loop)))))


               ;;;; ------------------------------------------------------------------------
               ;;;; Mode-Specific Implementations
               ;;;; ------------------------------------------------------------------------

               ;;; Converts a string to its 'display' representation (raw UTF-8 bytes).
               (func $string->bytes:display (param $str (ref $String)) (result (ref $Bytes))
                     (local $out-buf (ref $Bytes))
                     (local $arr     (ref $I8Array))
                     (local $str-len i32)
                     (local $i       i32)
                     (local $char    i32)
                     (local $total-size i32)
                     (local $idx     i32)

                     ;; Pass 1: calculate required UTF-8 buffer size
                     (local.set $str-len (struct.get $String 1 (local.get $str))) ;; string length
                     (local.set $i (i32.const 0))
                     (local.set $total-size (i32.const 0))
                     (loop $size-loop
                           (if (i32.lt_u (local.get $i) (local.get $str-len))
                               (then
                                (local.set $char
                                           (array.get $I32Array
                                                      (struct.get $String 2 (local.get $str))
                                                      (local.get $i)))
                                (local.set $total-size
                                           (i32.add (local.get $total-size)
                                                    (call $utf8-size (local.get $char))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $size-loop))))

                     ;; Allocate backing byte array and wrap in Bytes
                     (local.set $arr (array.new_default $I8Array (local.get $total-size)))
                     (local.set $out-buf
                                (struct.new $Bytes
                                            (i32.const 0)        ;; hash = 0
                                            (i32.const 1)        ;; immutable = true
                                            (local.get $arr)))   ;; backing array

                     ;; Pass 2: encode UTF-8 into buffer
                     (local.set $i   (i32.const 0))
                     (local.set $idx (i32.const 0))
                     (loop $fill-loop
                           (if (i32.lt_u (local.get $i) (local.get $str-len))
                               (then
                                (local.set $char
                                           (array.get $I32Array
                                                      (struct.get $String 2 (local.get $str))
                                                      (local.get $i)))
                                (local.set $idx
                                           (call $write-utf8
                                                 (local.get $out-buf)
                                                 (local.get $idx)
                                                 (local.get $char)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $fill-loop))))

                     (local.get $out-buf))


               ;;; Converts a string to its 'write'/'print' representation (quoted, escaped).
               #;(func $string->bytes:write (param $str (ref $String)) (result (ref $Bytes))
                       (local $out-buf    (ref $Bytes))
                       (local $arr        (ref $I8Array))
                       (local $str-len    i32)
                       (local $i          i32)
                       (local $char       i32)
                       (local $escape     i32)
                       (local $total-size i32)
                       (local $idx        i32)

                       ;; Pass 1: calculate output size
                       (local.set $str-len    (struct.get $String 1 (local.get $str))) ; todo: wrong
                       (local.set $i          (i32.const 0))
                       (local.set $total-size (i32.const 2)) ;; opening and closing quote
                       (loop $size-loop
                             (if (i32.lt_u (local.get $i) (local.get $str-len))
                                 (then
                                  (local.set $char
                                             (array.get $I32Array (struct.get $String 2 (local.get $str)) (local.get $i)))
                                  (block $char-size-done
                                         (if (i32.eq (local.get $char) (i32.const 34))
                                             (then
                                              (local.set $total-size (i32.add (local.get $total-size) (i32.const 2)))
                                              (br $char-size-done)))
                                         (if (i32.eq (local.get $char) (i32.const 92))
                                             (then
                                              (local.set $total-size (i32.add (local.get $total-size) (i32.const 2)))
                                              (br $char-size-done)))
                                         (if (call $get-special-escape (local.get $char))
                                             (then
                                              (local.set $total-size (i32.add (local.get $total-size) (i32.const 2)))
                                              (br $char-size-done)))
                                         (if (i32.or (call $is-graphic (local.get $char)) (call $is-blank (local.get $char)))
                                             (then
                                              (local.set $total-size
                                                         (i32.add (local.get $total-size) (call $utf8-size (local.get $char))))
                                              (br $char-size-done)))
                                         ;; Otherwise use hex escape
                                         (if (i32.le_u (local.get $char) (i32.const 0xffff))
                                             (then (local.set $total-size (i32.add (local.get $total-size) (i32.const 6))))
                                             (else (local.set $total-size (i32.add (local.get $total-size) (i32.const 10))))))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $size-loop))))

                       ;; Allocate output array and wrap in Bytes
                       (local.set $arr (array.new_default $I8Array (local.get $total-size)))
                       (local.set $out-buf
                                  (struct.new $Bytes
                                              (i32.const 0)          ;; hash
                                              (i32.const 1)          ;; immutable
                                              (local.get $arr)))     ;; backing array

                       ;; Write opening quote
                       (array.set $I8Array (local.get $arr) (i32.const 0) (i32.const 34))
                       (local.set $idx (i32.const 1))
                       (local.set $i   (i32.const 0))

                       ;; Fill output array
                       (loop $fill-loop
                             (if (i32.lt_u (local.get $i) (local.get $str-len))
                                 (then
                                  (local.set $char
                                             (array.get $I32Array (struct.get $String 2 (local.get $str)) (local.get $i)))
                                  (block $char-done
                                         (if (i32.eq (local.get $char) (i32.const 34))
                                             (then
                                              (array.set $I8Array (local.get $arr) (local.get $idx) (i32.const 92))
                                              (array.set $I8Array (local.get $arr) (i32.add (local.get $idx) (i32.const 1)) (i32.const 34))
                                              (local.set $idx (i32.add (local.get $idx) (i32.const 2)))
                                              (br $char-done)))
                                         (if (i32.eq (local.get $char) (i32.const 92))
                                             (then
                                              (array.set $I8Array (local.get $arr) (local.get $idx) (i32.const 92))
                                              (array.set $I8Array (local.get $arr) (i32.add (local.get $idx) (i32.const 1)) (i32.const 92))
                                              (local.set $idx (i32.add (local.get $idx) (i32.const 2)))
                                              (br $char-done)))
                                         (local.set $escape (call $get-special-escape (local.get $char)))
                                         (if (local.get $escape)
                                             (then
                                              (array.set $I8Array (local.get $arr) (local.get $idx) (i32.const 92))
                                              (array.set $I8Array (local.get $arr) (i32.add (local.get $idx) (i32.const 1)) (local.get $escape))
                                              (local.set $idx (i32.add (local.get $idx) (i32.const 2)))
                                              (br $char-done)))
                                         (if (i32.or (call $is-graphic (local.get $char)) (call $is-blank (local.get $char)))
                                             (then
                                              (local.set $idx (call $write-utf8 (local.get $out-buf) (local.get $idx) (local.get $char)))
                                              (br $char-done)))
                                         (if (i32.le_u (local.get $char) (i32.const 0xffff))
                                             (then
                                              (array.set $I8Array (local.get $arr) (local.get $idx) (i32.const 92))
                                              (array.set $I8Array (local.get $arr) (i32.add (local.get $idx) (i32.const 1)) (i32.const 117)) ;; 'u'
                                              (call $write-hex (local.get $out-buf) (i32.add (local.get $idx) (i32.const 2)) (local.get $char) (i32.const 4))
                                              (local.set $idx (i32.add (local.get $idx) (i32.const 6))))
                                             (else
                                              (array.set $I8Array (local.get $arr) (local.get $idx) (i32.const 92))
                                              (array.set $I8Array (local.get $arr) (i32.add (local.get $idx) (i32.const 1)) (i32.const 85)) ;; 'U'
                                              (call $write-hex (local.get $out-buf) (i32.add (local.get $idx) (i32.const 2)) (local.get $char) (i32.const 8))
                                              (local.set $idx (i32.add (local.get $idx) (i32.const 10))))))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $fill-loop)))

                             ;; Final quote
                             (array.set $I8Array (local.get $arr) (local.get $idx) (i32.const 34))
                             (local.get $out-buf)))


               (func $raise-not-a-string (param $val (ref eq)) (result (ref eq))
                     (call $raise-argument-error1
                           (global.get $symbol:format)
                           (global.get $string:string?)
                           (local.get $val))
                     (unreachable))

               #;(func $string->bytes (export "string->bytes")
                       ; todo: check mode
                       (param $v        (ref eq))
                       (param $mode-raw (ref eq))
                       (result (ref eq))

                       (local $mode     (ref i31))
                       (local $int-mode i32)
                       (local $str      (ref null $String))

                       ;; 1. Extract integer mode from fixnum
                       (local.set $mode (ref.cast (ref i31) (local.get $mode-raw)))
                       (local.set $int-mode (i31.get_u (local.get $mode)))

                       ;; 2. Check if $v is a string
                       (if (ref.test (ref $String) (local.get $v))
                           (then
                            (local.set $str (ref.cast (ref $String) (local.get $v))))
                           (else
                            ;; Raise an exception: not a string
                            (return (call $raise-not-a-string (local.get $v)))))

                       ;; 3. Dispatch by mode: 1 = display, else write
                       (if (result (ref eq))
                           (i32.eq (local.get $int-mode) (i32.const 1))
                           (then (call $string->bytes:display (local.get $str)))
                           (else (call $string->bytes:write   (local.get $str)))))


               #;(func $str-list
                       (param $v        (ref eq))
                       (param $opt-mode (ref eq))

                       (result (ref $Bytes))

                       (local $result (ref $SegmentVec))
                       (local $mode   i32)
                       (local $bs     (ref $Bytes))
                       ;; Determine mode
                       (local.set $mode
                                  (select
                                   ,(Half `(i31.get_s (ref.cast (ref i31) (local.get $opt-mode))))
                                   (i32.const 0)
                                   (ref.eq (local.get $opt-mode) (global.get $false))))
                       ;; Initialize accumulator with "("
                       (local.set $result
                                  (array.new_fixed $SegmentVec
                                                   (array.new_data $Bytes "(" (i32.const 1))))

                       ;; Traverse list and accumulate
                       (block $done
                              (loop $loop
                                    (br_if $done (ref.eq (local.get $v) (global.get $null)))

                                    ;; car
                                    (local.set $bs     (call $str (call $car (local.get $v))
                                                             (ref.i31 (local.get $mode))))
                                    (local.set $result (call $str-segment-vec-append
                                                             (local.get $result)
                                                             (local.get $bs)))
                                    ;; cdr
                                    (local.set $v (call $cdr (local.get $v)))

                                    (br_if $loop (ref.eq (local.get $v) (global.get $null)))

                                    ;; space between elements
                                    (local.set $result (call $str-segment-vec-append (local.get $result)
                                                             (array.new_data $Bytes " " (i32.const 1))))
                                    (br $loop)))

                       ;; Add closing ")"
                       (local.set $result (call $str-segment-vec-append (local.get $result)
                                                (array.new_data $Bytes ")" (i32.const 1))))

                       ;; Join all segments with no delimiter
                       (call $str-join (local.get $result)))
     ))

;; display-formatting-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register display-formatting helpers for runtime emission.
(define display-formatting-runtime-only-helpers
  (function-forms->runtime-helpers
   'display-formatting-runtime-only-helpers
   display-formatting-runtime-only-forms))

;; display-formatting-promoted-runtime-helper-names : (listof symbol?)
;;   Name display-formatting helpers available in the standalone core runtime.
(define display-formatting-promoted-runtime-helper-names
  (map core-runtime-helper-name display-formatting-runtime-only-helpers))

;; display-formatting-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate display-formatting helpers available in standalone core runtime.
(define display-formatting-core-runtime-helpers
  (select-runtime-helpers display-formatting-runtime-only-helpers
                          display-formatting-promoted-runtime-helper-names))

;; display-formatting-runtime-only-helpers* : (listof core-runtime-helper?)
;;   Enumerate display-formatting helpers that still depend on monolithic runtime globals.
(define display-formatting-runtime-only-helpers*
  (remove-runtime-helpers display-formatting-runtime-only-helpers
                          display-formatting-promoted-runtime-helper-names))

;; formatting-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for formatting and display helpers.
(define formatting-runtime-only-helper-names
  (map core-runtime-helper-name display-formatting-runtime-only-helpers*))

;; display-formatting-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted display-formatting helpers in runtime assembly order.
(define (display-formatting-core-runtime-helper-forms helper-index)
  (formatting-helper-forms helper-index display-formatting-promoted-runtime-helper-names))

;; formatting-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render formatting and display helpers in runtime assembly order.
(define (formatting-runtime-helper-forms helper-index)
  (formatting-helper-forms helper-index formatting-runtime-only-helper-names))

;; formatting-runtime-only-helpers : (listof core-runtime-helper?)
;;   Register printer-extension and display-formatting helpers for runtime emission.
(define formatting-runtime-only-helpers
  '())

;; formatting-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate formatting helpers available in the standalone core runtime.
(define formatting-core-runtime-helpers
  (append printer-extension-runtime-only-helpers
          unquoted-printing-string-core-runtime-helpers
          numeric-display-formatting-runtime-only-helpers
          display-formatting-core-runtime-helpers))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define formatting-core-helper-index
    (make-core-runtime-helper-index formatting-core-runtime-helpers))

  (define formatting-helper-index
    (make-core-runtime-helper-index
     (append formatting-core-runtime-helpers
             formatting-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name unquoted-printing-string-core-runtime-helpers)
   unquoted-printing-string-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (unquoted-printing-string-core-runtime-helper-forms formatting-core-helper-index))
   unquoted-printing-string-promoted-runtime-helper-names)

  (check-equal?
   (map core-runtime-helper-name display-formatting-core-runtime-helpers)
   display-formatting-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (display-formatting-core-runtime-helper-forms formatting-core-helper-index))
   display-formatting-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (printer-extension-runtime-helper-forms formatting-helper-index))
   printer-extension-runtime-only-helper-names)

  (check-equal?
   (map form-name (unquoted-printing-string-runtime-helper-forms formatting-helper-index))
   unquoted-printing-string-runtime-only-helper-names)

  (check-equal?
   (map form-name (numeric-display-formatting-runtime-helper-forms formatting-helper-index))
   numeric-display-formatting-runtime-only-helper-names)

  (check-equal?
   (map form-name (formatting-runtime-helper-forms formatting-helper-index))
   formatting-runtime-only-helper-names))
