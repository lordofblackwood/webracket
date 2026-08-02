#lang racket

(provide syntax-global-forms
         syntax-global-names
         syntax-runtime-string-constants
         syntax-runtime-symbol-constants
         syntax-core-runtime-helpers
         syntax-runtime-only-helpers
         syntax-runtime-only-helper-names
         syntax-runtime-helper-forms
         correlated-syntax-runtime-only-helper-names
         correlated-syntax-runtime-helper-forms)

(require "../core-helper.rkt"
         (only-in "../../private/wasm-utils.rkt"
                  Undefined))

;; syntax-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by syntax and correlated syntax helpers.
(define syntax-runtime-string-constants
  `((syntax-or-false            "(or/c syntax? #f)")
    (datum->syntax-srcloc
     ,(string-append "(or/c #f syntax? srcloc? "
                     "(list/c any/c (or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f) "
                     "(or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f)) "
                     "(vector/c any/c (or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f) "
                     "(or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f)))"))
	    (syntax?                    "syntax?")
	    (identifier?                "identifier?")
	    (listof-identifier?         "(listof identifier?)")
	    (phase?                     "phase?")
	    (stx-list?                  "stx-list?")
    (syntax-introducer-mode?    "(or/c 'add 'remove 'flip)")
    (syntax-local-value-failure "(or/c (-> any/c) #f)")
    (syntax-local-value-binding "identifier with transformer binding")
    (set!-transformer?          "set!-transformer?")
    (correlated?                "correlated?")
    (correlated-or-false        "(or/c correlated? #f)")
    (datum->correlated-srcloc
     ,(string-append "(or/c correlated? #f (list/c any/c (or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f) (or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f)) "
                     "(vector/c any/c (or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f) "
                     "(or/c exact-positive-integer? #f) "
                     "(or/c exact-nonnegative-integer? #f)))"))))

;; syntax-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by syntax and correlated syntax helpers.
(define syntax-runtime-symbol-constants
  '(correlated->datum
    datum->correlated
    correlated-property
    correlated-property-symbol-keys
    correlated
    make-correlated
    correlated?
    correlated-source
    correlated-line
    correlated-column
    correlated-position
    correlated-span
    correlated-e
    correlated-props
    syntax
    make-syntax
    syntax?
    syntax-e
    syntax-scopes
    syntax-shifted-multi-scopes
    syntax-srcloc
    syntax-props
    empty-props
    syntax-source
    syntax-line
    syntax-column
    syntax-position
    syntax-span
    syntax-property
    syntax-property-symbol-keys
    datum->syntax
    syntax->datum
    syntax->list
    identifier?
    submod
    top-level
    add
    remove
    flip
    syntax-introducer))

;; syntax-global-forms : (listof datum?)
;;   Declare cached syntax and correlated syntax descriptors and property tables.
(define syntax-global-forms
  `(
         ;; Cached correlated struct type descriptor
         (global $correlated-type (mut (ref null $StructType)) (ref.null $StructType))
         ;; Shared empty correlated properties table
         (global $correlated-empty-props (mut (ref eq)) ,(Undefined))

         ;; Cached syntax struct type descriptor
         (global $syntax-type (mut (ref null $StructType)) (ref.null $StructType))
         ;; Shared empty syntax properties table
         (global $syntax-empty-props (mut (ref eq)) ,(Undefined))))

;; syntax-global-names : (listof symbol?)
;;   Enumerate cached syntax and correlated syntax global names.
(define syntax-global-names
  (for/list ([form (in-list syntax-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'syntax-global-names
                "expected global form, got: ~s"
                form)])))

;; syntax-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for syntax-object helpers.
(define syntax-runtime-only-helper-names
  '($ensure-syntax-type
    $ensure-syntax-empty-props
    $syntax/make
    $raise-argument-error:syntax-expected
    $syntax-build
    $syntax
    $make-syntax
    $syntax?
    $syntax-unwrap
    $syntax-e
    $syntax->list
    $syntax-scopes
    $syntax-shifted-multi-scopes
    $syntax-srcloc
    $syntax-srclocs
    $syntax-props
    $syntax-property
    $syntax-property-symbol-keys
    $empty-props
    $syntax-source
    $syntax-source-module
    $module-fixup/last-pass
    $module-fixup
    $module-name-fixup
    $module-path-fixup
    $syntax-line
    $syntax-column
	    $syntax-position
	    $syntax-span
	    $identifier?
	    $phase?/i32
	    $identifier-binding
    $syntax-transforming?
    $syntax-local-phase-level
    $syntax-local-infer-name
    $syntax-local-introduce
    $syntax-local-value
    $free-identifier=?
    $bound-identifier=?
    $check-duplicate-identifier
    $generate-temporaries
    $syntax-introducer
    $syntax-delta-introducer
    $make-syntax-introducer
    $make-syntax-delta-introducer
    $datum->syntax/convert
    $datum->syntax-srcloc-vector
    $datum->syntax
    $syntax->datum/convert
    $syntax->datum))

;; correlated-syntax-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for correlated syntax helpers.
(define correlated-syntax-runtime-only-helper-names
  '($ensure-correlated-type
    $ensure-correlated-empty-props
    $correlated/make
    $raise-argument-error:correlated-expected
    $correlated-build
    $correlated
    $make-correlated
    $correlated?
    $correlated-unwrap
    $correlated-source
    $correlated-line
    $correlated-column
    $correlated-position
    $correlated-span
    $correlated-e
    $correlated-props
    $correlated->datum/convert
    $correlated->datum
    $datum->correlated
    $correlated-property
    $correlated-property-symbol-keys))

;; correlated-syntax-promoted-runtime-helper-names : (listof symbol?)
;;   Name syntax helpers available in the standalone core runtime.
(define correlated-syntax-promoted-runtime-helper-names
  '($ensure-correlated-type
    $correlated/make
    $raise-argument-error:correlated-expected
    $correlated-build
    $correlated?
    $correlated-unwrap
    $correlated->datum/convert
    $ensure-syntax-empty-props
    $syntax/make
    $syntax-build
    $identifier?
    $free-identifier=?
    $datum->syntax/convert
    $syntax->datum/convert))

;; correlated-syntax-runtime-only-forms : (listof datum?)
;;   Enumerate correlated syntax helpers used by the monolithic runtime.
(define correlated-syntax-runtime-only-forms
  '(
         ;; Correlated Syntax

         (func $ensure-correlated-type
               (result (ref $StructType))

               (local $existing (ref null $StructType))
               (local $std      (ref $StructType))
               (local $indices  (ref eq))

               (local.set $existing (global.get $correlated-type))
               (if (ref.is_null (local.get $existing))
                   (then
                    (local.set $indices (call $list-from-range/checked (i32.const 0) (i32.const 7)))
                    (local.set $std
                               (struct.new $StructType
                                           (i32.const 0)
                                           (ref.cast (ref $Symbol) (global.get $symbol:correlated))
                                           (global.get $false)
                                           (i32.const 7)
                                           (local.get $indices)
                                           (global.get $null)
                                           (global.get $null)
                                           (ref.cast (ref eq) (call $struct-type-property-table-empty))
                                           (global.get $false)
                                           (local.get $indices)
                                           (global.get $false)
                                           (ref.cast (ref $Symbol) (global.get $symbol:correlated))))
                    (global.set $correlated-type (local.get $std))
                    (local.set $existing (local.get $std))))
               (ref.as_non_null (local.get $existing)))

         (func $ensure-correlated-empty-props
               (result (ref eq))

               (local $props (ref eq))

               (local.set $props (global.get $correlated-empty-props))
               (if (ref.eq (local.get $props) (global.get $undefined))
                   (then
                    (local.set  $props (call $make-hash (global.get $missing)))
                    (global.set $correlated-empty-props (local.get $props))))
                (local.get $props))

         (func $correlated/make
               (param $source   (ref eq))
               (param $line     (ref eq))
               (param $column   (ref eq))
               (param $position (ref eq))
               (param $span     (ref eq))
               (param $e        (ref eq))
               (param $props    (ref eq))
               (result (ref $Struct))

               (local $std    (ref $StructType))
               (local $fields (ref $Array))

               (local.set $std (call $ensure-correlated-type))
               (local.set $fields
                          (array.new_fixed $Array 7
                                           (local.get $source)
                                           (local.get $line)
                                           (local.get $column)
                                           (local.get $position)
                                           (local.get $span)
                                           (local.get $e)
                                           (local.get $props)))
               (struct.new $Struct
                           (i32.const 0)
                           (global.get $false)
                           (ref.i31 (i32.const 0))
                           (global.get $false)
                           (ref.func $invoke-struct)
                           (local.get $std)
                           (local.get $fields)))

         (func $raise-argument-error:correlated-expected
               (param $who (ref eq))
               (param $got (ref eq))

               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:correlated?)
                     (local.get $got)))

         (func $correlated-build
               (param $who      (ref eq))
               (param $source   (ref eq))
               (param $line     (ref eq))
               (param $column   (ref eq))
               (param $position (ref eq))
               (param $span     (ref eq))
               (param $e        (ref eq))
               (param $props    (ref eq))
               (result (ref eq))

               (local $line-checked     (ref eq))
               (local $column-checked   (ref eq))
               (local $position-checked (ref eq))
               (local $span-checked     (ref eq))
               (local $props-checked    (ref eq))

               ;; Initialize non-defaultable locals
               (local.set $props-checked (global.get $false))

               ;; Check arguments
               (local.set $line-checked
                          (call $srcloc-check-positive (local.get $who) (local.get $line)))
               (local.set $column-checked
                          (call $srcloc-check-nonnegative (local.get $who) (local.get $column)))
               (local.set $position-checked
                          (call $srcloc-check-positive (local.get $who) (local.get $position)))
               (local.set $span-checked
                          (call $srcloc-check-nonnegative (local.get $who) (local.get $span)))

               (if (ref.eq (local.get $props) (global.get $missing))
                   (then (local.set $props-checked (call $ensure-syntax-empty-props)))
                   (else
                    (if (ref.eq (call $hash? (local.get $props)) (global.get $true))
                        (then (local.set $props-checked (local.get $props)))
                        (else (call $raise-argument-error1 (local.get $who)
                                    (global.get $string:hash?)
                                    (local.get $props))
                              (unreachable)))))

               ;; Construct correlated syntax
               (call $correlated/make
                     (local.get $source)
                     (local.get $line-checked)
                     (local.get $column-checked)
                     (local.get $position-checked)
                     (local.get $span-checked)
                     (local.get $e)
                     (local.get $props-checked)))

         (func $correlated
               (param $source   (ref eq))
               (param $line     (ref eq))
               (param $column   (ref eq))
               (param $position (ref eq))
               (param $span     (ref eq))
               (param $e        (ref eq))
               (param $props    (ref eq))
               (result (ref eq))

               (call $correlated-build
                     (global.get $symbol:correlated)
                     (local.get $source)
                     (local.get $line)
                     (local.get $column)
                     (local.get $position)
                     (local.get $span)
                     (local.get $e)
                     (local.get $props)))

         (func $make-correlated
               (param $source   (ref eq))
               (param $line     (ref eq))
               (param $column   (ref eq))
               (param $position (ref eq))
               (param $span     (ref eq))
               (param $e        (ref eq))
               (param $props    (ref eq))
               (result (ref eq))

               (call $correlated-build
                     (global.get $symbol:make-correlated)
                     (local.get $source)
                     (local.get $line)
                     (local.get $column)
                     (local.get $position)
                     (local.get $span)
                     (local.get $e)
                     (local.get $props)))

         (func $correlated? (type $Prim1)
               (param $v (ref eq))
               (result   (ref eq))

               (local $struct (ref $Struct))
               (local $type   (ref eq))
               (local $std    (ref $StructType))
               (local $ok     i32)

               (local.set $std (call $ensure-correlated-type))
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

         (func $correlated-unwrap
               (param $who (ref eq))
               (param $v   (ref eq))
               (result     (ref $Array))

               (local $struct (ref $Struct))
               (local $type   (ref eq))
               (local $std    (ref $StructType))
               (local $ok     i32)

               (local.set $std (call $ensure-correlated-type))
               (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
                   (then (call $raise-argument-error:correlated-expected (local.get $who) (local.get $v))
                         (unreachable)))
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $type   (struct.get $Struct $type (local.get $struct)))
               (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
               (if (i32.eqz (local.get $ok))
                   (then (call $raise-argument-error:correlated-expected (local.get $who) (local.get $v))
                         (unreachable)))
               (struct.get $Struct $fields (local.get $struct)))

         (func $correlated-source (type $Prim1)
               (param $crlt (ref eq))
               (result (ref eq))

               (local $fields (ref $Array))

               (local.set $fields (call $correlated-unwrap
                                        (global.get $symbol:correlated-source)
                                        (local.get $crlt)))
               (array.get $Array (local.get $fields) (i32.const 0)))

         (func $correlated-line (type $Prim1)
               (param $crlt (ref eq))
               (result (ref eq))

               (local $fields (ref $Array))

               (local.set $fields (call $correlated-unwrap
                                        (global.get $symbol:correlated-line)
                                        (local.get $crlt)))
               (array.get $Array (local.get $fields) (i32.const 1)))

         (func $correlated-column (type $Prim1)
               (param $crlt (ref eq))
               (result (ref eq))

               (local $fields (ref $Array))

               (local.set $fields (call $correlated-unwrap
                                        (global.get $symbol:correlated-column)
                                        (local.get $crlt)))
               (array.get $Array (local.get $fields) (i32.const 2)))

         (func $correlated-position (type $Prim1)
               (param $crlt (ref eq))
               (result (ref eq))

               (local $fields (ref $Array))

               (local.set $fields (call $correlated-unwrap
                                        (global.get $symbol:correlated-position)
                                        (local.get $crlt)))
               (array.get $Array (local.get $fields) (i32.const 3)))

         (func $correlated-span (type $Prim1)
               (param $crlt (ref eq))
               (result (ref eq))

               (local $fields (ref $Array))

               (local.set $fields (call $correlated-unwrap
                                        (global.get $symbol:correlated-span)
                                        (local.get $crlt)))
               (array.get $Array (local.get $fields) (i32.const 4)))

         (func $correlated-e (type $Prim1)
               (param $crlt (ref eq))
               (result (ref eq))

               (local $fields (ref $Array))

               (local.set $fields (call $correlated-unwrap
                                        (global.get $symbol:correlated-e)
                                        (local.get $crlt)))
               (array.get $Array (local.get $fields) (i32.const 5)))

         (func $correlated-props
               (param $crlt (ref eq))
               (result (ref eq))

               (local $fields (ref $Array))

               (local.set $fields (call $correlated-unwrap
                                        (global.get $symbol:correlated-props)
                                        (local.get $crlt)))
               (array.get $Array (local.get $fields) (i32.const 6)))

         (func $correlated->datum/convert
               (param $who (ref eq))
               (param $v   (ref eq))
               (result (ref eq))

               (local $fields     (ref $Array))
               (local $e          (ref eq))
               (local $pair       (ref $Pair))
               (local $car-raw    (ref eq))
               (local $cdr-raw    (ref eq))
               (local $car-datum  (ref eq))
               (local $cdr-datum  (ref eq))
               (if (ref.eq (call $correlated? (local.get $v)) (global.get $true))
                   (then
                    (local.set $fields (call $correlated-unwrap (local.get $who) (local.get $v)))
                    (local.set $e (array.get $Array (local.get $fields) (i32.const 5)))
                    (return (call $correlated->datum/convert (local.get $who) (local.get $e)))))

               (if (ref.test (ref $Pair) (local.get $v))
                   (then
                    (local.set $pair (ref.cast (ref $Pair) (local.get $v)))
                    (local.set $car-raw (struct.get $Pair $a (local.get $pair)))
                    (local.set $cdr-raw (struct.get $Pair $d (local.get $pair)))
                    (local.set $car-datum (call $correlated->datum/convert (local.get $who) (local.get $car-raw)))
                    (local.set $cdr-datum (call $correlated->datum/convert (local.get $who) (local.get $cdr-raw)))
                    (return (call $cons (local.get $car-datum) (local.get $cdr-datum)))))

               (if (ref.test (ref $Vector) (local.get $v))
                   (then
                    ;; Match Racket's behavior: recurse through pairs, but preserve
                    ;; vector elements as-is, including correlated values.
                    (return (local.get $v))))

               (if (ref.test (ref $Box) (local.get $v))
                   (then
                    ;; Match Racket's behavior: boxes are preserved like vectors,
                    ;; including any correlated value inside the box.
                    (return (local.get $v))))

               (local.get $v))

         (func $correlated->datum (type $Prim1)
               (param $v (ref eq))
               (result (ref eq))

               (call $correlated->datum/convert
                     (global.get $symbol:correlated->datum)
                     (local.get $v)))

         (func $datum->correlated (type $Prim13)
               (param $v            (ref eq))
               (param $srcloc       (ref eq)) ; optional, default = #f
               (param $prop         (ref eq)) ; optional, default = #f
               (result              (ref eq))

               (local $who          (ref eq))
               (local $source       (ref eq))
               (local $line         (ref eq))
               (local $column       (ref eq))
               (local $position     (ref eq))
               (local $span         (ref eq))
               (local $srcloc-val   (ref eq))
               (local $tmp          (ref eq))
               (local $vec          (ref $Vector))
               (local $arr          (ref $Array))
               (local $len          i32)
               (local $props        (ref eq))
               (local $prop-val     (ref eq))

               (local.set $who      (global.get $symbol:datum->correlated))
               (local.set $source   (global.get $false))
               (local.set $line     (global.get $false))
               (local.set $column   (global.get $false))
               (local.set $position (global.get $false))
               (local.set $span     (global.get $false))
               (local.set $props    (global.get $missing))

               ; $srcloc-val is optional with default value #f
               (local.set $srcloc-val (local.get $srcloc))
               (if (ref.eq (local.get $srcloc-val) (global.get $missing))
                   (then (local.set $srcloc-val (global.get $false))))

               (block $srcloc-done
                      (if (ref.eq (local.get $srcloc-val) (global.get $false))
                          (then (br $srcloc-done)))
                      (if (ref.eq (call $correlated? (local.get $srcloc-val)) (global.get $true))
                          (then
                           (local.set $source (call $correlated-source (local.get $srcloc-val)))
                           (local.set $tmp (call $correlated-line (local.get $srcloc-val)))
                           (local.set $line (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (call $correlated-column (local.get $srcloc-val)))
                           (local.set $column (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (local.set $tmp (call $correlated-position (local.get $srcloc-val)))
                           (local.set $position (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (call $correlated-span (local.get $srcloc-val)))
                           (local.set $span (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (br $srcloc-done)))
                      (if (ref.eq (call $srcloc? (local.get $srcloc-val)) (global.get $true))
                          (then
                           (local.set $source (call $srcloc-source (local.get $srcloc-val)))
                           (local.set $tmp (call $srcloc-line (local.get $srcloc-val)))
                           (local.set $line (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (call $srcloc-column (local.get $srcloc-val)))
                           (local.set $column (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (local.set $tmp (call $srcloc-position (local.get $srcloc-val)))
                           (local.set $position (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (call $srcloc-span (local.get $srcloc-val)))
                           (local.set $span (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (br $srcloc-done)))
                      (if (ref.test (ref $Vector) (local.get $srcloc-val))
                          (then
                           (local.set $vec (ref.cast (ref $Vector) (local.get $srcloc-val)))
                           (local.set $arr (struct.get $Vector $arr (local.get $vec)))
                           (local.set $len (array.len (local.get $arr)))
                           (if (i32.ne (local.get $len) (i32.const 5))
                               (then (call $raise-argument-error1
                                           (local.get $who)
                                           (global.get $string:datum->correlated-srcloc)
                                           (local.get $srcloc-val))
                                     (unreachable)))
                           (local.set $source (array.get $Array (local.get $arr) (i32.const 0)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 1)))
                           (local.set $line (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 2)))
                           (local.set $column (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 3)))
                           (local.set $position (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 4)))
                           (local.set $span (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (br $srcloc-done)))
                      (if (ref.eq (call $list? (local.get $srcloc-val)) (global.get $true))
                          (then
                           (local.set $srcloc-val (call $list->vector (local.get $srcloc-val)))
                           (if (i32.eqz (ref.test (ref $Vector) (local.get $srcloc-val)))
                               (then (call $raise-argument-error1
                                           (local.get $who)
                                           (global.get $string:datum->correlated-srcloc)
                                           (local.get $srcloc-val))
                                     (unreachable)))
                           (local.set $vec (ref.cast (ref $Vector) (local.get $srcloc-val)))
                           (local.set $arr (struct.get $Vector $arr (local.get $vec)))
                           (local.set $len (array.len (local.get $arr)))
                           (if (i32.ne (local.get $len) (i32.const 5))
                               (then (call $raise-argument-error1
                                           (local.get $who)
                                           (global.get $string:datum->correlated-srcloc)
                                           (local.get $srcloc-val))
                                     (unreachable)))
                           (local.set $source (array.get $Array (local.get $arr) (i32.const 0)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 1)))
                           (local.set $line (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 2)))
                           (local.set $column (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 3)))
                           (local.set $position (call $srcloc-check-positive (local.get $who) (local.get $tmp)))
                           (local.set $tmp (array.get $Array (local.get $arr) (i32.const 4)))
                           (local.set $span (call $srcloc-check-nonnegative (local.get $who) (local.get $tmp)))
                           (br $srcloc-done)))
                      (call $raise-argument-error1
                            (local.get $who)
                            (global.get $string:datum->correlated-srcloc)
                            (local.get $srcloc-val))
                      (unreachable))

               ; $prop-val is optional with default value #f
               (local.set $prop-val (local.get $prop))
               (if (ref.eq (local.get $prop-val) (global.get $missing))
                   (then (local.set $prop-val (global.get $false))))

               (if (ref.eq (local.get $prop-val) (global.get $false))
                   (then (local.set $props (global.get $missing)))
                   (else
                    (if (ref.eq (call $correlated? (local.get $prop-val)) (global.get $true))
                        (then (local.set $props (call $correlated-props (local.get $prop-val))))
                        (else
                         (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:correlated-or-false)
                               (local.get $prop-val))
                         (unreachable)))))

               ;; `datum->correlated` mirrors `datum->syntax`: optional
               ;; arguments are validated, but correlated input is unchanged.
               (if (ref.eq (call $correlated? (local.get $v)) (global.get $true))
                   (then (return (local.get $v))))

               (call $correlated-build
                     (local.get $who)
                     (local.get $source)
                     (local.get $line)
                     (local.get $column)
                     (local.get $position)
                     (local.get $span)
                     (local.get $v)
                     (local.get $props)))

         (func $correlated-property (type $Prim23)
               (param $crlt (ref eq))
               (param $key  (ref eq))
               (param $val  (ref eq))
               (result      (ref eq))

               (local $fields     (ref $Array))
               (local $props      (ref eq))
               (local $source     (ref eq))
               (local $line       (ref eq))
               (local $column     (ref eq))
               (local $position   (ref eq))
               (local $span       (ref eq))
               (local $e          (ref eq))
               (local $val-arg    (ref eq))
               (local $new-props  (ref eq))
               (local $pairs      (ref eq))
               (local $list       (ref eq))
               (local $pair       (ref $Pair))
               (local $entry      (ref $Pair))
               (local $entry-key  (ref eq))
               (local $entry-val  (ref eq))

               (local.set $fields (call $correlated-unwrap
                                            (global.get $symbol:correlated-property)
                                            (local.get $crlt)))
               (local.set $source (array.get $Array (local.get $fields) (i32.const 0)))
               (local.set $line   (array.get $Array (local.get $fields) (i32.const 1)))
               (local.set $column (array.get $Array (local.get $fields) (i32.const 2)))
               (local.set $position (array.get $Array (local.get $fields) (i32.const 3)))
               (local.set $span   (array.get $Array (local.get $fields) (i32.const 4)))
               (local.set $e      (array.get $Array (local.get $fields) (i32.const 5)))
               (local.set $props  (array.get $Array (local.get $fields) (i32.const 6)))

               (if (ref.eq (local.get $val) (global.get $missing))
                   (then (return (call $hash-ref (local.get $props)
                                               (local.get $key)
                                               (global.get $false)))))

               (local.set $val-arg (local.get $val))
               (local.set $new-props (call $make-hasheq (global.get $missing)))
               (local.set $pairs (call $hash->list (local.get $props) (global.get $false)))
               (local.set $list (local.get $pairs))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $list) (global.get $null)))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $list)))
                            (local.set $entry (ref.cast (ref $Pair)
                                                        (struct.get $Pair $a (local.get $pair))))
                            (local.set $list (struct.get $Pair $d (local.get $pair)))
                            (local.set $entry-key (struct.get $Pair $a (local.get $entry)))
                            (local.set $entry-val (struct.get $Pair $d (local.get $entry)))
                            ; Correlated-property keys are identity-sensitive.
                            (if (ref.eq (local.get $entry-key) (local.get $key))
                                (then (br $loop)))
                            (drop (call $hash-set! (local.get $new-props)
                                        (local.get $entry-key)
                                        (local.get $entry-val)))
                            (br $loop)))

               (drop (call $hash-set! (local.get $new-props)
                           (local.get $key)
                           (local.get $val-arg)))

               (call $correlated/make
                     (local.get $source)
                     (local.get $line)
                     (local.get $column)
                     (local.get $position)
                     (local.get $span)
                     (local.get $e)
                     (local.get $new-props)))

         (func $correlated-property-symbol-keys (type $Prim1)
               (param $crlt (ref eq))
               (result      (ref eq))

               (local $fields (ref $Array))
               (local $props  (ref eq))
               (local $pairs  (ref eq))
               (local $list   (ref eq))
               (local $pair   (ref $Pair))
               (local $entry  (ref $Pair))
               (local $key    (ref eq))
               (local $acc    (ref eq))

               (local.set $fields (call $correlated-unwrap
                                            (global.get $symbol:correlated-property-symbol-keys)
                                            (local.get $crlt)))
               (local.set $props (array.get $Array (local.get $fields) (i32.const 6)))
               (local.set $pairs (call $hash->list (local.get $props) (global.get $false)))
               (local.set $list  (local.get $pairs))
               (local.set $acc   (global.get $null))
               (block $done
                      (loop $loop
                            (br_if $done (ref.eq (local.get $list) (global.get $null)))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $list)))
                            (local.set $entry (ref.cast (ref $Pair)
                                                        (struct.get $Pair $a (local.get $pair))))
                            (local.set $list (struct.get $Pair $d (local.get $pair)))
                            (local.set $key (struct.get $Pair $a (local.get $entry)))
                            (if (ref.test (ref $Symbol) (local.get $key))
                                (then
                                 (local.set $acc
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (local.get $key)
                                                        (local.get $acc)))))
                            (br $loop)))
               (call $reverse (local.get $acc)))

     ))

;; syntax-runtime-only-forms : (listof datum?)
;;   Enumerate syntax-object helpers used by the monolithic runtime.
(define syntax-runtime-only-forms
  '(
    (func $ensure-syntax-type
          (result (ref $StructType))

          (local $existing (ref null $StructType))
          (local $std      (ref $StructType))
          (local $indices  (ref eq))

          (local.set $existing (global.get $syntax-type))
          (if (ref.is_null (local.get $existing))
              (then
               (local.set $indices (call $list-from-range/checked (i32.const 0) (i32.const 5)))
               (local.set $std
                          (struct.new $StructType
                                      (i32.const 0)
                                      (ref.cast (ref $Symbol) (global.get $symbol:syntax))
                                      (global.get $false)
                                      (i32.const 5)
                                      (local.get $indices)
                                      (global.get $null)
                                      (global.get $null)
                                      (ref.cast (ref eq) (call $struct-type-property-table-empty))
                                      (global.get $false)
                                      (local.get $indices)
                                      (global.get $false)
                                      (ref.cast (ref $Symbol) (global.get $symbol:syntax))))
               (global.set $syntax-type (local.get $std))
               (local.set $existing (local.get $std))))
          (ref.as_non_null (local.get $existing)))

    (func $ensure-syntax-empty-props
          (result (ref eq))

          (local $props (ref eq))

          (local.set $props (global.get $syntax-empty-props))
          (if (ref.eq (local.get $props) (global.get $undefined))
              (then
               (local.set $props (call $make-hasheq (global.get $missing)))
               (global.set $syntax-empty-props (local.get $props))))
          (local.get $props))

    (func $syntax/make
          (param $e        (ref eq))
          (param $scopes   (ref eq))
          (param $shifted  (ref eq))
          (param $srcloc   (ref eq))
          (param $props    (ref eq))
          (result (ref $Struct))

          (local $std    (ref $StructType))
          (local $fields (ref $Array))

          (local.set $std (call $ensure-syntax-type))
          (local.set $fields
                     (array.new_fixed $Array 5
                                      (local.get $e)
                                      (local.get $scopes)
                                      (local.get $shifted)
                                      (local.get $srcloc)
                                      (local.get $props)))
          (struct.new $Struct
                      (i32.const 0)
                      (global.get $false)
                      (ref.i31 (i32.const 0))
                      (global.get $false)
                      (ref.func $invoke-struct)
                      (local.get $std)
                      (local.get $fields)))

    (func $raise-argument-error:syntax-expected
          (param $who (ref eq))
          (param $got (ref eq))

          (call $raise-argument-error1
                (local.get $who)
                (global.get $string:syntax?)
                (local.get $got)))

    (func $syntax-build
          (param $who      (ref eq))
          (param $e        (ref eq))
          (param $scopes   (ref eq))
          (param $shifted  (ref eq))
          (param $srcloc   (ref eq))
          (param $props    (ref eq))
          (result (ref eq))

          (local $srcloc-checked (ref eq))
          (local $props-checked  (ref eq))

          ;; Initialize non-defaultable locals
          (local.set $srcloc-checked (global.get $false))
          (local.set $props-checked  (global.get $false))

          (if (ref.eq (local.get $srcloc) (global.get $false))
              (then (local.set $srcloc-checked (local.get $srcloc)))
              (else
               (if (ref.eq (call $srcloc? (local.get $srcloc)) (global.get $true))
                   (then (local.set $srcloc-checked (local.get $srcloc)))
                   (else (call $raise-argument-error:srcloc-expected
                               (local.get $who)
                               (local.get $srcloc))
                         (unreachable)))))

          (if (ref.eq (local.get $props) (global.get $missing))
              (then (local.set $props-checked (call $ensure-syntax-empty-props)))
              (else
               (if (ref.eq (call $hash? (local.get $props)) (global.get $true))
                   (then (local.set $props-checked (local.get $props)))
                   (else (call $raise-argument-error1 (local.get $who)
                                                       (global.get $string:hash?)
                                                       (local.get $props))
                         (unreachable)))))

          (call $syntax/make
                (local.get $e)
                (local.get $scopes)
                (local.get $shifted)
                (local.get $srcloc-checked)
                (local.get $props-checked)))

    (func $syntax #;(type $Prim5)
          (param $e        (ref eq))
          (param $scopes   (ref eq))
          (param $shifted  (ref eq))
          (param $srcloc   (ref eq))
          (param $props    (ref eq))
          (result (ref eq))

          (call $syntax-build
                (global.get $symbol:syntax)
                (local.get $e)
                (local.get $scopes)
                (local.get $shifted)
                (local.get $srcloc)
                (local.get $props)))

    (func $make-syntax #;(type $Prim5)
          (param $e        (ref eq))
          (param $scopes   (ref eq))
          (param $shifted  (ref eq))
          (param $srcloc   (ref eq))
          (param $props    (ref eq))
          (result (ref eq))

          (call $syntax-build
                (global.get $symbol:make-syntax)
                (local.get $e)
                (local.get $scopes)
                (local.get $shifted)
                (local.get $srcloc)
                (local.get $props)))

    (func $syntax? (type $Prim1)
          (param $v (ref eq))
          (result   (ref eq))

          (local $struct (ref $Struct))
          (local $type   (ref eq))
          (local $std    (ref $StructType))
          (local $ok     i32)

          (local.set $std (call $ensure-syntax-type))
          (if (result (ref eq))
              (ref.test (ref $Struct) (local.get $v))
              (then
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $type (struct.get $Struct $type (local.get $struct)))
               (local.set $ok (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
               (if (result (ref eq))
                   (local.get $ok)
                   (then (global.get $true))
                   (else (global.get $false))))
              (else (global.get $false))))

    (func $syntax-unwrap
          (param $who (ref eq))
          (param $v   (ref eq))
          (result     (ref $Array))

          (local $struct (ref $Struct))
          (local $type   (ref eq))
          (local $std    (ref $StructType))
          (local $ok     i32)

          (local.set $std (call $ensure-syntax-type))
          (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
              (then (call $raise-argument-error:syntax-expected (local.get $who) (local.get $v))
                    (unreachable)))
          (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
          (local.set $type   (struct.get $Struct $type (local.get $struct)))
          (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
          (if (i32.eqz (local.get $ok))
              (then (call $raise-argument-error:syntax-expected (local.get $who) (local.get $v))
                    (unreachable)))
          (struct.get $Struct $fields (local.get $struct)))

    (func $syntax-e (type $Prim1)
          (param $stx (ref eq))
          (result     (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-e)
                                   (local.get $stx)))
          (array.get $Array (local.get $fields) (i32.const 0)))

    (func $syntax->list (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $current (ref eq))
          (local $pair    (ref $Pair))
          (local $elem    (ref eq))
          (local $acc     (ref eq))
          (local $result  (ref eq))

          (local.set $acc     (global.get $null))
          (local.set $result  (global.get $false))
          (local.set $current (call $syntax-e (local.get $stx)))

          (block $done
                 (block $fail
                        (loop $loop
                              ; current = '()  => done
                              (if (ref.eq (local.get $current) (global.get $null))
                                  (then
                                   (local.set $result (call $reverse (local.get $acc)))
                                   (br $done)))
                              ; current = (cons elem ...) => cons `elem` to $acc
                              (if (ref.test (ref $Pair) (local.get $current))
                                  (then
                                   (local.set $pair (ref.cast (ref $Pair) (local.get $current)))
                                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                                   (local.set $acc  (struct.new $Pair
                                                                (i32.const 0)
                                                                (local.get $elem)
                                                                (local.get $acc)))
                                   (local.set $current (struct.get $Pair $d (local.get $pair)))
                                   (br $loop)))
                              ; unwrap syntax in the cdr, if necessary
                              (if (ref.eq (call $syntax? (local.get $current))
                                          (global.get $true))
                                  (then
                                   (local.set $current (call $syntax-e (local.get $current)))
                                   (br $loop)))
                              (br $fail))))
          (local.get $result))

    (func $syntax-scopes
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-scopes)
                                   (local.get $stx)))
          (array.get $Array (local.get $fields) (i32.const 1)))

    (func $syntax-shifted-multi-scopes
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-shifted-multi-scopes)
                                   (local.get $stx)))
          (array.get $Array (local.get $fields) (i32.const 2)))

    (func $syntax-srcloc (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-srcloc)
                                   (local.get $stx)))
          (array.get $Array (local.get $fields) (i32.const 3)))

    (func $syntax-srclocs (type $Prim1)
          (param $stx (ref eq))
          (result     (ref eq))

          (local $srcloc   (ref eq))
          (struct.new $Pair
                      (i32.const 0)
                      (call $srcloc
                            (call $syntax-source   (local.get $stx))
                            (call $syntax-line     (local.get $stx))
                            (call $syntax-column   (local.get $stx))
                            (call $syntax-position (local.get $stx))
                            (call $syntax-span     (local.get $stx)))
                      (global.get $null)))

    (func $syntax-props
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-props)
                                   (local.get $stx)))
          (array.get $Array (local.get $fields) (i32.const 4)))

    (func $syntax-property (type $Prim24)
          (param $stx (ref eq)) ;; syntax object
          (param $key (ref eq)) ;; property key
          (param $val (ref eq)) ;; optional value (default: missing)
          (param $preserved (ref eq)) ;; optional preserved? (currently ignored; default #f)
          (result (ref eq))

          (local $fields     (ref $Array))
          (local $e          (ref eq))
          (local $scopes     (ref eq))
          (local $shifted    (ref eq))
          (local $srcloc     (ref eq))
          (local $props      (ref eq))
          (local $new-props  (ref eq))
          (local $pairs      (ref eq))
          (local $list       (ref eq))
          (local $pair       (ref $Pair))
          (local $entry      (ref $Pair))
          (local $entry-key  (ref eq))
          (local $entry-val  (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-property)
                                   (local.get $stx)))
          (local.set $e       (array.get $Array (local.get $fields) (i32.const 0)))
          (local.set $scopes  (array.get $Array (local.get $fields) (i32.const 1)))
          (local.set $shifted (array.get $Array (local.get $fields) (i32.const 2)))
          (local.set $srcloc  (array.get $Array (local.get $fields) (i32.const 3)))
          (local.set $props   (array.get $Array (local.get $fields) (i32.const 4)))

          (if (ref.eq (local.get $val) (global.get $missing))
              (then
               (return (call $hash-ref
                             (local.get $props)
                             (local.get $key)
                             (global.get $false)))))

          (local.set $new-props (call $make-hash (global.get $missing)))
          (local.set $pairs     (call $hash->list (local.get $props) (global.get $false)))
          (local.set $list      (local.get $pairs))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $list) (global.get $null)))
                       (local.set $pair (ref.cast (ref $Pair) (local.get $list)))
                       (local.set $entry (ref.cast (ref $Pair)
                                                   (struct.get $Pair $a (local.get $pair))))
                       (local.set $list (struct.get $Pair $d (local.get $pair)))
                       (local.set $entry-key (struct.get $Pair $a (local.get $entry)))
                       (local.set $entry-val (struct.get $Pair $d (local.get $entry)))
                       ;; Syntax-property keys are identity-sensitive.
                       (if (ref.eq (local.get $entry-key) (local.get $key))
                           (then (br $loop)))
                       (drop (call $hash-set!
                                   (local.get $new-props)
                                   (local.get $entry-key)
                                   (local.get $entry-val)))
                       (br $loop)))

          (drop (call $hash-set!
                      (local.get $new-props)
                      (local.get $key)
                      (local.get $val)))

          (call $syntax/make
                (local.get $e)
                (local.get $scopes)
                (local.get $shifted)
                (local.get $srcloc)
                (local.get $new-props)))

    (func $syntax-property-symbol-keys (type $Prim1)
          (param $stx (ref eq)) ;; syntax object
          (result (ref eq))

          (local $fields (ref $Array))
          (local $props  (ref eq))
          (local $pairs  (ref eq))
          (local $list   (ref eq))
          (local $pair   (ref $Pair))
          (local $entry  (ref $Pair))
          (local $key    (ref eq))
          (local $acc    (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-property-symbol-keys)
                                   (local.get $stx)))
          (local.set $props (array.get $Array (local.get $fields) (i32.const 4)))
          (local.set $pairs (call $hash->list (local.get $props) (global.get $false)))
          (local.set $list  (local.get $pairs))
          (local.set $acc   (global.get $null))
          (block $done
                 (loop $loop
                       (br_if $done (ref.eq (local.get $list) (global.get $null)))
                       (local.set $pair (ref.cast (ref $Pair) (local.get $list)))
                       (local.set $entry (ref.cast (ref $Pair)
                                                   (struct.get $Pair $a (local.get $pair))))
                       (local.set $list (struct.get $Pair $d (local.get $pair)))
                       (local.set $key (struct.get $Pair $a (local.get $entry)))
                       (if (ref.test (ref $Symbol) (local.get $key))
                           (then
                            (local.set $acc
                                       (struct.new $Pair
                                                   (i32.const 0)
                                                   (local.get $key)
                                                   (local.get $acc)))))
                       (br $loop)))
          (call $reverse (local.get $acc)))

    (func $empty-props
          (result (ref eq))

          (call $ensure-syntax-empty-props))

    (func $syntax-source (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))
          (local $srcloc (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-source)
                                   (local.get $stx)))
          (local.set $srcloc (array.get $Array (local.get $fields) (i32.const 3)))
          (if (result (ref eq))
              (ref.eq (local.get $srcloc) (global.get $false))
              (then (global.get $false))
              (else (call $srcloc-source (local.get $srcloc)))))

    ;; syntax-source-module : syntax? [any/c] -> (or/c module-path-index? symbol? path? resolved-module-path? #f)
    ;;   Module-origin metadata is not retained in WebRacket syntax
    ;;   objects yet. Validate the syntax argument, then report #f.
    (func $syntax-source-module (type $Prim12)
          (param $stx     (ref eq)) ;; syntax?
          (param $source? (ref eq)) ;; optional any/c, default = #f
          (result         (ref eq))
          (drop (call $syntax-unwrap
                      (global.get $symbol:syntax-source-module)
                      (local.get $stx)))
          (global.get $false))

    ;; module-fixup/last-pass : any/c i32 -> any/c
    ;;   Shared helper for `module-name-fixup` and
    ;;   `module-path-fixup`. When `as-modpath` is non-zero, symbols
    ;;   are quoted and list forms become `(submod ...)`.
    (func $module-fixup/last-pass
          (param $src        (ref eq)) ;; source/module shape
          (param $as-modpath i32)      ;; 0 = module name, 1 = module path
          (result            (ref eq))
          (local $base (ref eq))
          (local $sm   (ref eq))
          (if (ref.eq (call $path? (local.get $src)) (global.get $true))
              (then (return (local.get $src))))
          (if (ref.eq (call $symbol? (local.get $src)) (global.get $true))
              (then
               (if (local.get $as-modpath)
                   (then
                    (return
                     (call $cons
                           (global.get $symbol:quote)
                           (call $cons
                                 (local.get $src)
                                 (global.get $null)))))
                   (else
                    (return (local.get $src))))))
          (if (ref.eq (call $list? (local.get $src)) (global.get $true))
              (then
               (local.set $base
                          (call $module-fixup/last-pass
                                (call $car (local.get $src))
                                (local.get $as-modpath)))
               (local.set $sm (call $cdr (local.get $src)))
               (if (local.get $as-modpath)
                   (then
                    (return
                     (call $cons
                           (global.get $symbol:submod)
                           (call $cons
                                 (local.get $base)
                                 (local.get $sm)))))
                   (else
                    (return (call $cons
                                  (local.get $base)
                                  (local.get $sm)))))))
          (global.get $symbol:top-level))

    ;; module-fixup : any/c list? i32 -> any/c
    ;;   Apply the shared `syntax/location` runtime fixup algorithm
    ;;   after appending any requested submodule path elements.
    (func $module-fixup
          (param $src        (ref eq)) ;; original module source
          (param $path       (ref eq)) ;; list of submodule path elements
          (param $as-modpath i32)      ;; 0 = module name, 1 = module path
          (result            (ref eq))
          (call $module-fixup/last-pass
                (if (result (ref eq))
                    (ref.eq (local.get $path) (global.get $null))
                    (then (local.get $src))
                    (else
                     (if (result (ref eq))
                         (ref.eq (call $pair? (local.get $src))
                                 (global.get $true))
                         (then (call $append/2
                                     (local.get $src)
                                     (local.get $path)))
                         (else (call $cons
                                     (local.get $src)
                                     (local.get $path))))))
                (local.get $as-modpath)))

    ;; module-name-fixup : any/c list? -> any/c
    ;;   Mirror `syntax/location`'s runtime helper used by
    ;;   `quote-module-name` expansions.
    (func $module-name-fixup (type $Prim2)
          (param $src  (ref eq)) ;; source/module value
          (param $path (ref eq)) ;; list of submodule path elements
          (result      (ref eq))
          (call $module-fixup
                (local.get $src)
                (local.get $path)
                (i32.const 0)))

    ;; module-path-fixup : any/c list? -> any/c
    ;;   Mirror the internal `syntax/location` helper used by
    ;;   `quote-module-path` expansions.
    (func $module-path-fixup (type $Prim2)
          (param $src  (ref eq)) ;; source/module value
          (param $path (ref eq)) ;; list of submodule path elements
          (result      (ref eq))
          (call $module-fixup
                (local.get $src)
                (local.get $path)
                (i32.const 1)))

    (func $syntax-line (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))
          (local $srcloc (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-line)
                                   (local.get $stx)))
          (local.set $srcloc (array.get $Array (local.get $fields) (i32.const 3)))
          (if (result (ref eq))
              (ref.eq (local.get $srcloc) (global.get $false))
              (then (global.get $false))
              (else (call $srcloc-line (local.get $srcloc)))))

    (func $syntax-column (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))
          (local $srcloc (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-column)
                                   (local.get $stx)))
          (local.set $srcloc (array.get $Array (local.get $fields) (i32.const 3)))
          (if (result (ref eq))
              (ref.eq (local.get $srcloc) (global.get $false))
              (then (global.get $false))
              (else (call $srcloc-column (local.get $srcloc)))))

    (func $syntax-position (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))
          (local $srcloc (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-position)
                                   (local.get $stx)))
          (local.set $srcloc (array.get $Array (local.get $fields) (i32.const 3)))
          (if (result (ref eq))
              (ref.eq (local.get $srcloc) (global.get $false))
              (then (global.get $false))
              (else (call $srcloc-position (local.get $srcloc)))))

    (func $syntax-span (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))
          (local $srcloc (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax-span)
                                   (local.get $stx)))
          (local.set $srcloc (array.get $Array (local.get $fields) (i32.const 3)))
          (if (result (ref eq))
              (ref.eq (local.get $srcloc) (global.get $false))
              (then (global.get $false))
              (else (call $srcloc-span (local.get $srcloc)))))

    (func $identifier? (type $Prim1)
          (param $v (ref eq))
          (result   (ref eq))

          (local $fields (ref $Array))
          (local $datum  (ref eq))

          (if (result (ref eq))
              (ref.eq (call $syntax? (local.get $v)) (global.get $true))
              (then
               (local.set $fields (call $syntax-unwrap
                                        (global.get $symbol:identifier?)
                                        (local.get $v)))
               (local.set $datum (array.get $Array (local.get $fields) (i32.const 0)))
	               (if (result (ref eq))
	                   (ref.eq (call $symbol? (local.get $datum)) (global.get $true))
	                   (then (global.get $true))
	                   (else (global.get $false))))
	              (else (global.get $false))))

	    ;; phase?/i32 : any/c -> i32
	    ;;   Check WebRacket's current phase representation: exact integers
	    ;;   and #f for the label phase.
	    (func $phase?/i32
	          (param $v (ref eq)) ;; candidate phase value
	          (result   i32)
	          (i32.or
	           (ref.eq (local.get $v) (global.get $false))
	           (ref.eq (call $exact-integer? (local.get $v))
	                   (global.get $true))))

	    ;; identifier-binding : identifier? [phase?] [any/c] [any/c] -> any/c
	    ;;   Racket reports lexical/module binding metadata here.
    ;;   WebRacket runtime syntax objects do not retain binding
    ;;   tables yet, so validate the identifier and optional phase,
    ;;   then report no binding with #f.
    (func $identifier-binding (type $Prim14)
          (param $id                (ref eq)) ;; identifier?
          (param $phase             (ref eq)) ;; optional phase, default = syntax-local-phase-level
          (param $top-level-symbol? (ref eq)) ;; optional any/c, default = #f; ignored
          (param $exact-scopes?     (ref eq)) ;; optional any/c, default = #f; ignored
          (result                   (ref eq))

          (if (ref.eq (call $identifier? (local.get $id)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:identifier-binding)
                     (global.get $string:identifier?)
                     (local.get $id))
               (unreachable)))
	          (if (ref.eq (local.get $phase) (global.get $missing))
	              (then (local.set $phase (call $syntax-local-phase-level))))
	          (if (i32.eqz (call $phase?/i32 (local.get $phase)))
	              (then
	               (call $raise-argument-error1
	                     (global.get $symbol:identifier-binding)
	                     (global.get $string:phase?)
	                     (local.get $phase))
	               (unreachable)))
	          (if (ref.eq (local.get $phase) (global.get $false))
	              (then (return (global.get $false))))
	          (global.get $false))

    ;; syntax-transforming? : -> boolean?
    ;;   WebRacket currently runs host-expanded modules and has no
    ;;   active runtime transformer context or module-visit dynamic
    ;;   extent, so report #f.
    (func $syntax-transforming? (type $Prim0)
          (result (ref eq))
          (global.get $false))

    ;; syntax-local-phase-level : -> exact-integer?
    ;;   Outside the dynamic extent of a transformer application,
    ;;   Racket reports phase 0. WebRacket does not yet run an
    ;;   internal expander transformer context, so return 0.
    (func $syntax-local-phase-level (type $Prim0)
          (result (ref eq))
          (ref.i31 (i32.const 0)))

    ;; syntax-local-infer-name : syntax? [any/c] -> (or/c symbol? #f)
    ;;   Racket infers names from syntax properties, local context,
    ;;   and source locations. WebRacket currently has no active
    ;;   transformer/name-inference context in compiled modules, so
    ;;   report no inferred name. The optional use-local? argument
    ;;   defaults to #t and is currently ignored.
    (func $syntax-local-infer-name (type $Prim12)
          (param $stx        (ref eq)) ;; syntax?
          (param $use-local? (ref eq)) ;; optional any/c, default = #t; ignored
          (result            (ref eq))

          (if (result (ref eq))
              (ref.eq (call $syntax? (local.get $stx)) (global.get $true))
              (then (global.get $false))
              (else
               (call $raise-argument-error:syntax-expected
                     (global.get $symbol:syntax-local-infer-name)
                     (local.get $stx))
               (unreachable))))

    ;; syntax-local-introduce : syntax? -> syntax?
    ;;   Racket flips macro-introduction/use-site scopes for the
    ;;   current expansion context. WebRacket does not yet preserve
    ;;   syntax scopes, so this validates and returns the syntax
    ;;   object unchanged.
    (func $syntax-local-introduce (type $Prim1)
          (param $stx (ref eq)) ;; syntax?
          (result     (ref eq))

          (if (result (ref eq))
              (ref.eq (call $syntax? (local.get $stx)) (global.get $true))
              (then (local.get $stx))
              (else
               (call $raise-argument-error:syntax-expected
                     (global.get $symbol:syntax-local-introduce)
                     (local.get $stx))
               (unreachable))))

    ;; syntax-local-value : identifier? [(or/c (-> any/c) #f)] [any/c] -> any/c
    ;;   WebRacket is compiling host-expanded modules here and does
    ;;   not maintain an active transformer binding environment.
    ;;   Therefore lookup always misses: invoke the optional
    ;;   failure-thunk when supplied, or raise when it is #f/missing.
    ;;   The optional intdef-ctx argument defaults to #f and is
    ;;   currently ignored.
    (func $syntax-local-value (type $Prim13)
          (param $id            (ref eq)) ;; identifier?
          (param $failure-thunk (ref eq)) ;; optional procedure or #f, default = #f
          (param $intdef-ctx    (ref eq)) ;; optional internal-definition context(s), default = #f; ignored
          (result               (ref eq))

          (local $proc   (ref $Procedure))
          (local $args   (ref $Args))
          (local $result (ref eq))

          (if (ref.eq (call $identifier? (local.get $id)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:syntax-local-value)
                     (global.get $string:identifier?)
                     (local.get $id))
               (unreachable)))
          (if (ref.eq (local.get $failure-thunk) (global.get $missing))
              (then (local.set $failure-thunk (global.get $false))))
          (if (ref.eq (local.get $failure-thunk) (global.get $false))
              (then
               (call $raise-argument-error1
                     (global.get $symbol:syntax-local-value)
                     (global.get $string:syntax-local-value-binding)
                     (local.get $id))
               (unreachable)))
          (if (ref.eq (call $procedure? (local.get $failure-thunk)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:syntax-local-value)
                     (global.get $string:syntax-local-value-failure)
                     (local.get $failure-thunk))
               (unreachable)))
          (local.set $proc (ref.cast (ref $Procedure) (local.get $failure-thunk)))
          (local.set $args (array.new_fixed $Args 0))
          (local.set $result
                     (call $expect-one-value
                           (call_ref $ProcedureInvoker
                                     (local.get $proc)
                                     (local.get $args)
                                     (struct.get $Procedure $invoke (local.get $proc)))))
          (local.get $result))

	    ;; free-identifier=? : identifier? identifier? [phase?] [phase?] -> boolean?
    ;;   Compare lightweight WebRacket identifiers by datum. Full Racket also
    ;;   compares binding and phase information, which WebRacket syntax objects
    ;;   do not yet preserve.
    (func $free-identifier=? (type $Prim24)
          (param $a       (ref eq)) ;; identifier?
          (param $b       (ref eq)) ;; identifier?
          (param $a-phase (ref eq)) ;; optional phase level, default = syntax-local-phase-level; currently ignored
          (param $b-phase (ref eq)) ;; optional phase level, default = a-phase; currently ignored
          (result         (ref eq))

          (local $a-fields (ref $Array))
          (local $b-fields (ref $Array))
          (local $a-datum  (ref eq))
          (local $b-datum  (ref eq))

          (if (ref.eq (call $identifier? (local.get $a)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:free-identifier=?)
                     (global.get $string:identifier?)
                     (local.get $a))
               (unreachable)))

          (if (ref.eq (call $identifier? (local.get $b)) (global.get $true))
              (then (nop))
              (else
	               (call $raise-argument-error1
	                     (global.get $symbol:free-identifier=?)
	                     (global.get $string:identifier?)
	                     (local.get $b))
	               (unreachable)))

	          (if (ref.eq (local.get $a-phase) (global.get $missing))
	              (then (local.set $a-phase (call $syntax-local-phase-level))))
	          (if (ref.eq (local.get $b-phase) (global.get $missing))
	              (then (local.set $b-phase (local.get $a-phase))))
	          (if (i32.eqz (call $phase?/i32 (local.get $a-phase)))
	              (then
	               (call $raise-argument-error1
	                     (global.get $symbol:free-identifier=?)
	                     (global.get $string:phase?)
	                     (local.get $a-phase))
	               (unreachable)))
	          (if (i32.eqz (call $phase?/i32 (local.get $b-phase)))
	              (then
	               (call $raise-argument-error1
	                     (global.get $symbol:free-identifier=?)
	                     (global.get $string:phase?)
	                     (local.get $b-phase))
	               (unreachable)))

	          (local.set $a-fields (call $syntax-unwrap
	                                     (global.get $symbol:free-identifier=?)
	                                     (local.get $a)))
          (local.set $b-fields (call $syntax-unwrap
                                     (global.get $symbol:free-identifier=?)
                                     (local.get $b)))
          (local.set $a-datum (array.get $Array (local.get $a-fields) (i32.const 0)))
          (local.set $b-datum (array.get $Array (local.get $b-fields) (i32.const 0)))
          (call $symbol=? (local.get $a-datum) (local.get $b-datum)))

	    ;; bound-identifier=? : identifier? identifier? [phase?] -> boolean?
    ;;   Compare lightweight WebRacket identifiers by datum. Full
    ;;   Racket compares local binding scopes, which WebRacket
    ;;   runtime syntax objects do not retain yet.
    (func $bound-identifier=? (type $Prim23)
          (param $a     (ref eq)) ;; identifier?
          (param $b     (ref eq)) ;; identifier?
          (param $phase (ref eq)) ;; optional phase level, default = syntax-local-phase-level
	          (result       (ref eq))

	          (if (ref.eq (local.get $phase) (global.get $missing))
	              (then (local.set $phase (call $syntax-local-phase-level))))
	          (if (i32.eqz (call $phase?/i32 (local.get $phase)))
	              (then
	               (call $raise-argument-error1
	                     (global.get $symbol:bound-identifier=?)
	                     (global.get $string:phase?)
	                     (local.get $phase))
	               (unreachable)))
	          (if (ref.eq (local.get $phase) (global.get $false))
	              (then (return (call $free-identifier=?
	                                  (local.get $a)
	                                  (local.get $b)
	                                  (global.get $false)
	                                  (global.get $false)))))
	          (call $free-identifier=?
	                (local.get $a)
	                (local.get $b)
	                (local.get $phase)
	                (local.get $phase)))

    ;; check-duplicate-identifier : (listof identifier?) -> (or/c identifier? #f)
    ;;   Return the first later identifier whose datum duplicates an earlier one.
    (func $check-duplicate-identifier (type $Prim1)
          (param $ids (ref eq)) ;; (listof identifier?)
          (result     (ref eq))

          (local $scan       (ref eq))
          (local $outer      (ref eq))
          (local $inner      (ref eq))
          (local $scan-pair  (ref $Pair))
          (local $outer-pair (ref $Pair))
          (local $inner-pair (ref $Pair))
          (local $id         (ref eq))
          (local $other      (ref eq))

          (local.set $scan (local.get $ids))
          (block $validated
            (loop $validate-loop
              (br_if $validated (ref.eq (local.get $scan) (global.get $null)))
              (if (ref.test (ref $Pair) (local.get $scan))
                  (then
                   (local.set $scan-pair
                              (ref.cast (ref $Pair) (local.get $scan)))
                   (local.set $id (struct.get $Pair $a (local.get $scan-pair)))
                   (if (ref.eq (call $identifier? (local.get $id)) (global.get $true))
                       (then (nop))
                       (else
                        (call $raise-argument-error1
                              (global.get $symbol:check-duplicate-identifier)
                              (global.get $string:listof-identifier?)
                              (local.get $ids))
                        (unreachable)))
                   (local.set $scan (struct.get $Pair $d (local.get $scan-pair)))
                   (br $validate-loop))
                  (else
                   (call $raise-argument-error1
                         (global.get $symbol:check-duplicate-identifier)
                         (global.get $string:listof-identifier?)
                         (local.get $ids))
                   (unreachable)))))

          (local.set $outer (local.get $ids))
          (block $outer-done
            (loop $outer-loop
              (br_if $outer-done (ref.eq (local.get $outer) (global.get $null)))
              (local.set $outer-pair (ref.cast (ref $Pair) (local.get $outer)))
              (local.set $id (struct.get $Pair $a (local.get $outer-pair)))
              (local.set $inner (struct.get $Pair $d (local.get $outer-pair)))
              (block $inner-done
                (loop $inner-loop
                  (br_if $inner-done (ref.eq (local.get $inner) (global.get $null)))
                  (local.set $inner-pair (ref.cast (ref $Pair) (local.get $inner)))
                  (local.set $other (struct.get $Pair $a (local.get $inner-pair)))
                  (if (ref.eq (call $free-identifier=?
                                    (local.get $id)
                                    (local.get $other)
                                    (global.get $missing)
                                    (global.get $missing))
                              (global.get $true))
                      (then (return (local.get $other)))
                      (else (nop)))
                  (local.set $inner (struct.get $Pair $d (local.get $inner-pair)))
                  (br $inner-loop)))
              (local.set $outer (struct.get $Pair $d (local.get $outer-pair)))
              (br $outer-loop)))
          (global.get $false))

    ;; generate-temporaries : stx-list? -> (listof identifier?)
    ;;   Generate one fresh identifier per input element. Racket uses
    ;;   interned generated names plus scopes; WebRacket currently uses
    ;;   existing gensym-backed symbols because full scope introduction
    ;;   is not represented yet.
    (func $generate-temporaries (type $Prim1)
          (param $v (ref eq)) ;; stx-list?
          (result   (ref eq))

          (local $current (ref eq))
          (local $pair    (ref $Pair))
          (local $acc     (ref eq))
          (local $sym     (ref eq))
          (local $id      (ref eq))
          (local $stx-list (ref eq))

          (local.set $acc (global.get $null))
          (local.set $current (local.get $v))
          (if (ref.eq (call $syntax? (local.get $v)) (global.get $true))
              (then
               (local.set $stx-list (call $syntax->list (local.get $v)))
               (if (ref.eq (local.get $stx-list) (global.get $false))
                   (then
                    (call $raise-argument-error1
                          (global.get $symbol:generate-temporaries)
                          (global.get $string:stx-list?)
                          (local.get $v))
                    (unreachable))
                   (else
                    (local.set $current (local.get $stx-list)))))
              (else (nop)))

          (block $done
            (loop $loop
              (br_if $done (ref.eq (local.get $current) (global.get $null)))
              (if (ref.test (ref $Pair) (local.get $current))
                  (then
                   (local.set $pair
                              (ref.cast (ref $Pair) (local.get $current)))
                   (local.set $sym (call $gensym (global.get $missing)))
                   (local.set $id
                              (call $datum->syntax
                                    (global.get $false)
                                    (local.get $sym)
                                    (global.get $missing)
                                    (global.get $missing)
                                    (global.get $missing)))
                   (local.set $acc (struct.new $Pair
                                               (i32.const 0)
                                               (local.get $id)
                                               (local.get $acc)))
                   (local.set $current (struct.get $Pair $d (local.get $pair)))
                   (br $loop))
                  (else
                   (call $raise-argument-error1
                         (global.get $symbol:generate-temporaries)
                         (global.get $string:stx-list?)
                         (local.get $v))
                   (unreachable)))))
          (call $reverse (local.get $acc)))

    ;; syntax-introducer : syntax? [(or/c 'add 'remove 'flip)] -> syntax?
    ;;   Bootstrap introducer body. Full Racket adds, removes, or
    ;;   flips a scope set; WebRacket syntax objects do not yet
    ;;   preserve scope metadata, so this validates the public
    ;;   contract shape and returns the syntax object unchanged.
    (func $syntax-introducer (type $Prim12)
          (param $stx  (ref eq)) ;; syntax?
          (param $mode (ref eq)) ;; optional mode, default = 'flip
          (result      (ref eq))

          (if (ref.eq (call $syntax? (local.get $stx)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error:syntax-expected
                     (global.get $symbol:syntax-introducer)
                     (local.get $stx))
               (unreachable)))

          (if (ref.eq (local.get $mode) (global.get $missing))
              (then (local.set $mode (global.get $symbol:flip))))
          (if (i32.or
               (ref.eq (local.get $mode) (global.get $symbol:flip))
               (i32.or
                (ref.eq (local.get $mode) (global.get $symbol:add))
                (ref.eq (local.get $mode) (global.get $symbol:remove))))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:syntax-introducer)
                     (global.get $string:syntax-introducer-mode?)
                     (local.get $mode))
               (unreachable)))
          (local.get $stx))

    ;; syntax-delta-introducer : syntax? [(or/c 'add 'remove 'flip)] -> syntax?
    ;;   Body for make-syntax-delta-introducer. Racket's delta
    ;;   introducer defaults to 'add; WebRacket still returns the
    ;;   syntax object unchanged because scope sets are not modeled.
    (func $syntax-delta-introducer (type $Prim12)
          (param $stx  (ref eq)) ;; syntax?
          (param $mode (ref eq)) ;; optional mode, default = 'add
          (result      (ref eq))

          (if (ref.eq (call $syntax? (local.get $stx)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error:syntax-expected
                     (global.get $symbol:syntax-introducer)
                     (local.get $stx))
               (unreachable)))

          (if (ref.eq (local.get $mode) (global.get $missing))
              (then (local.set $mode (global.get $symbol:add))))
          (if (i32.or
               (ref.eq (local.get $mode) (global.get $symbol:flip))
               (i32.or
                (ref.eq (local.get $mode) (global.get $symbol:add))
                (ref.eq (local.get $mode) (global.get $symbol:remove))))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:syntax-introducer)
                     (global.get $string:syntax-introducer-mode?)
                     (local.get $mode))
               (unreachable)))
          (local.get $stx))

    ;; make-syntax-introducer : [any/c] -> procedure?
    ;;   The optional as-use-site? argument defaults to #f in Racket.
    ;;   Since WebRacket does not model syntax scopes yet, both
    ;;   macro-introduction and use-site introducers share the same
    ;;   identity procedure body for now.
    (func $make-syntax-introducer (type $Prim01)
          (param $as-use-site? (ref eq)) ;; optional any/c, default = #f; currently ignored
          (result              (ref eq))

          (struct.new $PrimitiveProcedure
                      (i32.const 0)
                      (global.get $symbol:syntax-introducer)
                      (ref.cast
                       (ref eq)
                       (array.new_fixed $I32Array 2
                                        (i32.const 1)
                                        (i32.const 2)))
                      (global.get $the-racket/primitive-realm)
                      (ref.func $primitive-invoke:shape-18)
                      (ref.func $syntax-introducer)
                      (global.get $false)))

	    ;; make-syntax-delta-introducer : syntax? (or/c syntax? #f) [phase?] -> procedure?
    ;;   The optional phase-level defaults to syntax-local-phase-level.
    ;;   The current runtime validates arguments but does not compute
    ;;   or preserve scope deltas, so it returns an identity
    ;;   introducer whose default mode is 'add.
    (func $make-syntax-delta-introducer (type $Prim23)
          (param $ext-stx    (ref eq)) ;; syntax?
          (param $base-stx   (ref eq)) ;; syntax? or #f
	          (param $phase      (ref eq)) ;; optional phase?, default = syntax-local-phase-level
          (result            (ref eq))

          (if (ref.eq (call $syntax? (local.get $ext-stx)) (global.get $true))
              (then (nop))
              (else
               (call $raise-argument-error:syntax-expected
                     (global.get $symbol:make-syntax-delta-introducer)
                     (local.get $ext-stx))
               (unreachable)))
          (if (i32.or
               (ref.eq (local.get $base-stx) (global.get $false))
               (ref.eq (call $syntax? (local.get $base-stx)) (global.get $true)))
              (then (nop))
              (else
               (call $raise-argument-error1
                     (global.get $symbol:make-syntax-delta-introducer)
                     (global.get $string:syntax-or-false)
                     (local.get $base-stx))
	               (unreachable)))
	          (if (i32.or
	               (ref.eq (local.get $phase) (global.get $missing))
	               (call $phase?/i32 (local.get $phase)))
	              (then (nop))
	              (else
	               (call $raise-argument-error1
	                     (global.get $symbol:make-syntax-delta-introducer)
	                     (global.get $string:phase?)
	                     (local.get $phase))
	               (unreachable)))
          (struct.new $PrimitiveProcedure
                      (i32.const 0)
                      (global.get $symbol:syntax-introducer)
                      (ref.cast
                       (ref eq)
                       (array.new_fixed $I32Array 2
                                        (i32.const 1)
                                        (i32.const 2)))
                      (global.get $the-racket/primitive-realm)
                      (ref.func $primitive-invoke:shape-18)
                      (ref.func $syntax-delta-introducer)
                      (global.get $false)))

    ;; NOTE: This initial implementation does not yet recursively convert
    ;;       datum contents (pairs, vectors, boxes, etc.) as Racket's
    ;;       datum->syntax does. Nested data are left unchanged.
    #;(func $datum->syntax (type $Prim15)
          (param $ctxt    (ref eq))  ;; syntax? or #f
          (param $datum   (ref eq))  ;; any/c
          (param $srcloc  (ref eq))  ;; optional srcloc? (default: #f)
          (param $prop    (ref eq))  ;; optional syntax? (default: #f)
          (param $ignored (ref eq))  ;; optional syntax? (default: #f)
          (result         (ref eq))

          (local $who             (ref eq))
          (local $fields          (ref $Array))
          (local $scopes          (ref eq))
          (local $shifted         (ref eq))
          (local $srcloc-checked  (ref eq))
          (local $props-checked   (ref eq))
          (local $is-syntax       (ref eq))

          (local.set $who            (global.get $symbol:datum->syntax))
          (local.set $scopes         (global.get $null))
          (local.set $shifted        (global.get $null))
          (local.set $srcloc-checked (global.get $false))
          (local.set $props-checked  (global.get $missing))

          (if (ref.eq (local.get $ctxt) (global.get $false))
              (then (nop))
              (else
               (local.set $fields (call $syntax-unwrap
                                         (local.get $who)
                                         (local.get $ctxt)))
               (local.set $scopes
                          (array.get $Array (local.get $fields) (i32.const 1)))
               (local.set $shifted
                          (array.get $Array (local.get $fields) (i32.const 2)))))

          (if (ref.eq (local.get $srcloc) (global.get $missing))
              (then (nop))
              (else
               (if (ref.eq (local.get $srcloc) (global.get $false))
                   (then (nop))
                   (else
                    (if (ref.eq (call $syntax? (local.get $srcloc)) (global.get $true))
                        (then
                         (local.set $srcloc-checked
                                    (call $syntax-srcloc (local.get $srcloc))))
                        (else
                         (if (ref.eq (call $srcloc? (local.get $srcloc))
                                     (global.get $true))
                             (then (local.set $srcloc-checked (local.get $srcloc)))
                             (else
                              (call $raise-argument-error:srcloc-expected
                                    (local.get $who)
                                    (local.get $srcloc))
                              (unreachable)))))))))

          (if (ref.eq (local.get $prop) (global.get $missing))
              (then (nop))
              (else
               (if (ref.eq (local.get $prop) (global.get $false))
                   (then (nop))
                   (else
                    (if (ref.eq (call $syntax? (local.get $prop)) (global.get $true))
                        (then
                         (local.set $props-checked
                                    (call $syntax-props (local.get $prop))))
                        (else
                         (call $raise-argument-error:syntax-expected
                               (local.get $who)
                               (local.get $prop))
                         (unreachable)))))))

          (if (ref.eq (local.get $ignored) (global.get $missing))
              (then (nop))
              (else
               (if (ref.eq (local.get $ignored) (global.get $false))
                   (then (nop))
                   (else
                    (if (ref.eq (call $syntax? (local.get $ignored))
                                (global.get $true))
                        (then (nop))
                        (else
                         (call $raise-argument-error:syntax-expected
                               (local.get $who)
                               (local.get $ignored))
                         (unreachable)))))))

          (local.set $is-syntax (call $syntax? (local.get $datum)))
          (if (ref.eq (local.get $is-syntax) (global.get $true))
              (then (return (local.get $datum))))

          (call $syntax-build
                (local.get $who)
                (local.get $datum)
                (local.get $scopes)
                (local.get $shifted)
                (local.get $srcloc-checked)
                (local.get $props-checked)))

    ;; ---------------------------------------------------------------

    ;; datum->syntax-srcloc-vector : any/c vector? -> srcloc?
    ;;   Decode a list/vector source-location argument with datum->syntax blame.
    (func $datum->syntax-srcloc-vector
          (param $original (ref eq))
          (param $vec      (ref $Vector))
          (result          (ref eq))

          (local $arr (ref $Array))
          (local $len i32)
          (local $tmp (ref eq))

          (local.set $arr (struct.get $Vector $arr (local.get $vec)))
          (local.set $len (array.len (local.get $arr)))
          (if (i32.ne (local.get $len) (i32.const 5))
              (then (call $raise-argument-error1
                          (global.get $symbol:datum->syntax)
                          (global.get $string:datum->syntax-srcloc)
                          (local.get $original))
                    (unreachable)))

          (local.set $tmp (array.get $Array (local.get $arr) (i32.const 1)))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $tmp) (global.get $false))
                       (ref.eq (call $exact-positive-integer? (local.get $tmp))
                               (global.get $true))))
              (then (call $raise-argument-error1
                          (global.get $symbol:datum->syntax)
                          (global.get $string:datum->syntax-srcloc)
                          (local.get $original))
                    (unreachable)))
          (local.set $tmp (array.get $Array (local.get $arr) (i32.const 2)))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $tmp) (global.get $false))
                       (ref.eq (call $exact-nonnegative-integer? (local.get $tmp))
                               (global.get $true))))
              (then (call $raise-argument-error1
                          (global.get $symbol:datum->syntax)
                          (global.get $string:datum->syntax-srcloc)
                          (local.get $original))
                    (unreachable)))
          (local.set $tmp (array.get $Array (local.get $arr) (i32.const 3)))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $tmp) (global.get $false))
                       (ref.eq (call $exact-positive-integer? (local.get $tmp))
                               (global.get $true))))
              (then (call $raise-argument-error1
                          (global.get $symbol:datum->syntax)
                          (global.get $string:datum->syntax-srcloc)
                          (local.get $original))
                    (unreachable)))
          (local.set $tmp (array.get $Array (local.get $arr) (i32.const 4)))
          (if (i32.eqz
               (i32.or (ref.eq (local.get $tmp) (global.get $false))
                       (ref.eq (call $exact-nonnegative-integer? (local.get $tmp))
                               (global.get $true))))
              (then (call $raise-argument-error1
                          (global.get $symbol:datum->syntax)
                          (global.get $string:datum->syntax-srcloc)
                          (local.get $original))
                    (unreachable)))

          (call $srcloc-build
                (global.get $symbol:datum->syntax)
                (array.get $Array (local.get $arr) (i32.const 0))
                (array.get $Array (local.get $arr) (i32.const 1))
                (array.get $Array (local.get $arr) (i32.const 2))
                (array.get $Array (local.get $arr) (i32.const 3))
                (array.get $Array (local.get $arr) (i32.const 4))))

    ;; NOTE: This implementation currently supports recursive conversion of
    ;; pairs, vectors, and boxes. Immutable hash tables and prefab
    ;; structures are not yet converted and will be wrapped as-is.
    ;; The `srcloc` argument accepts #f, srcloc? values, or syntax objects.
    (func $datum->syntax/convert
          (param $scopes  (ref eq))
          (param $shifted (ref eq))
          (param $srcloc  (ref eq))
          (param $props   (ref eq))
          (param $v       (ref eq))
          (result (ref eq))

          (local $pair     (ref $Pair))
          (local $car      (ref eq))
          (local $cdr      (ref eq))
          (local $car-stx  (ref eq))
          (local $cdr-stx  (ref eq))
          (local $vec      (ref $Vector))
          (local $arr      (ref $Array))
          (local $new-arr  (ref $Array))
          (local $len      i32)
          (local $i        i32)
          (local $elem     (ref eq))
          (local $elem-stx (ref eq))
          (local $result   (ref eq))
          (local $box      (ref $Box))
          (local $box-val  (ref eq))

          ;; Already syntax? return as-is.
          (if (ref.eq (call $syntax? (local.get $v)) (global.get $true))
              (then (return (local.get $v))))

          ;; Convert pairs.
          (if (ref.test (ref $Pair) (local.get $v))
              (then
               (local.set $pair (ref.cast (ref $Pair) (local.get $v)))
               (local.set $car  (struct.get $Pair $a (local.get $pair)))
               (local.set $cdr  (struct.get $Pair $d (local.get $pair)))
               (local.set $car-stx
                          (call $datum->syntax/convert
                                (local.get $scopes)
                                (local.get $shifted)
                                (local.get $srcloc)
                                (global.get $missing)
                                (local.get $car)))
               (local.set $cdr-stx
                          (call $datum->syntax/convert
                                (local.get $scopes)
                                (local.get $shifted)
                                (local.get $srcloc)
                                (global.get $missing)
                                (local.get $cdr)))
               (local.set $result
                          (call $cons
                                (local.get $car-stx)
                                (local.get $cdr-stx)))
               (return
                (call $syntax-build
                      (global.get $symbol:datum->syntax)
                      (local.get $result)
                      (local.get $scopes)
                      (local.get $shifted)
                      (local.get $srcloc)
                      (local.get $props)))))

          ;; Convert vectors (always producing an immutable vector).
          (if (ref.test (ref $Vector) (local.get $v))
              (then
               (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
               (local.set $arr (struct.get $Vector $arr (local.get $vec)))
               (local.set $len (array.len (local.get $arr)))
               (local.set $new-arr (call $make-array (local.get $len) (global.get $false)))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $elem
                                       (array.get $Array
                                                  (local.get $arr)
                                                  (local.get $i)))
                            (local.set $elem-stx
                                       (call $datum->syntax/convert
                                             (local.get $scopes)
                                             (local.get $shifted)
                                             (local.get $srcloc)
                                             (global.get $missing)
                                             (local.get $elem)))
                            (array.set $Array
                                       (local.get $new-arr)
                                       (local.get $i)
                                       (local.get $elem-stx))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (local.set $result
                          (struct.new $Vector
                                      (i32.const 0)
                                      (i32.const 1)
                                      (local.get $new-arr)))
               (return
                (call $syntax-build
                      (global.get $symbol:datum->syntax)
                      (local.get $result)
                      (local.get $scopes)
                      (local.get $shifted)
                      (local.get $srcloc)
                      (local.get $props)))))

          ;; Convert boxes (always immutable in the result).
          (if (ref.test (ref $Box) (local.get $v))
              (then
               (local.set $box (ref.cast (ref $Box) (local.get $v)))
               (local.set $box-val (struct.get $Box $v (local.get $box)))
               (local.set $box-val
                          (call $datum->syntax/convert
                                (local.get $scopes)
                                (local.get $shifted)
                                (local.get $srcloc)
                                (global.get $missing)
                                (local.get $box-val)))
               (local.set $result
                          (struct.new $Box
                                      (i32.const 0)
                                      (i32.const 1)
                                      (local.get $box-val)))
               (return
                (call $syntax-build
                      (global.get $symbol:datum->syntax)
                      (local.get $result)
                      (local.get $scopes)
                      (local.get $shifted)
                      (local.get $srcloc)
                      (local.get $props)))))

          (call $syntax-build
                (global.get $symbol:datum->syntax)
                (local.get $v)
                (local.get $scopes)
                (local.get $shifted)
                (local.get $srcloc)
                (local.get $props)))

    (func $datum->syntax (type $Prim25)
          (param $ctxt    (ref eq))
          (param $v       (ref eq))
          (param $srcloc  (ref eq))
          (param $prop    (ref eq))
          (param $ignored (ref eq))
          (result         (ref eq))

          (local $scopes         (ref eq))
          (local $shifted        (ref eq))
          (local $default-srcloc (ref eq))
          (local $default-props  (ref eq))
          (local $srcloc-checked (ref eq))
          (local $props-checked  (ref eq))
          (local $srcloc-val     (ref eq))
          (local $srcloc-original (ref eq))
          (local $vec            (ref $Vector))

          ;; Initialize defaults.
          (local.set $scopes         (global.get $null))
          (local.set $shifted        (global.get $null))
          (local.set $default-srcloc (global.get $false))
          (local.set $default-props  (global.get $missing))

          ;; Extract lexical context from the context syntax when available.
          (if (ref.eq (local.get $ctxt) (global.get $false))
              (then (nop))
              (else
               (if (ref.eq (call $syntax? (local.get $ctxt)) (global.get $true))
                   (then
                    (local.set $scopes         (call $syntax-scopes (local.get $ctxt)))
                    (local.set $shifted        (call $syntax-shifted-multi-scopes (local.get $ctxt)))
                    (local.set $default-srcloc (call $syntax-srcloc (local.get $ctxt)))
                    (local.set $default-props  (call $syntax-props (local.get $ctxt))))
                   (else
                    (call $raise-argument-error1
                          (global.get $symbol:datum->syntax)
                          (global.get $string:syntax-or-false)
                          (local.get $ctxt))
                    (unreachable)))))

          ;; Decode srcloc argument.
          (local.set $srcloc-checked (global.get $false))
          (local.set $srcloc-val (local.get $srcloc))
          (local.set $srcloc-original (local.get $srcloc-val))
          (if (ref.eq (local.get $srcloc-val) (global.get $missing))
              (then (local.set $srcloc-checked (local.get $default-srcloc)))
              (else
               (block $srcloc-done
                      (if (ref.eq (local.get $srcloc-val) (global.get $false))
                          (then
                           (local.set $srcloc-checked (global.get $false))
                           (br $srcloc-done)))
                      (if (ref.eq (call $syntax? (local.get $srcloc-val)) (global.get $true))
                          (then
                           (local.set $srcloc-checked
                                      (call $syntax-srcloc (local.get $srcloc-val)))
                           (br $srcloc-done)))
                      (if (ref.eq (call $srcloc? (local.get $srcloc-val)) (global.get $true))
                          (then
                           (local.set $srcloc-checked (local.get $srcloc-val))
                           (br $srcloc-done)))
                      (if (ref.test (ref $Vector) (local.get $srcloc-val))
                          (then
                           (local.set $vec (ref.cast (ref $Vector) (local.get $srcloc-val)))
                           (local.set $srcloc-checked
                                      (call $datum->syntax-srcloc-vector
                                            (local.get $srcloc-original)
                                            (local.get $vec)))
                           (br $srcloc-done)))
                      (if (ref.eq (call $list? (local.get $srcloc-val)) (global.get $true))
                          (then
                           (local.set $srcloc-val (call $list->vector (local.get $srcloc-val)))
                           (local.set $vec (ref.cast (ref $Vector) (local.get $srcloc-val)))
                           (local.set $srcloc-checked
                                      (call $datum->syntax-srcloc-vector
                                            (local.get $srcloc-original)
                                            (local.get $vec)))
                           (br $srcloc-done)))
                      (call $raise-argument-error1
                            (global.get $symbol:datum->syntax)
                            (global.get $string:datum->syntax-srcloc)
                            (local.get $srcloc-val))
                      (unreachable))))

          ;; Decode properties argument.
          (local.set $props-checked
                     (if (result (ref eq))
                         (ref.eq (local.get $prop) (global.get $missing))
                         (then (local.get $default-props))
                         (else
                          (if (result (ref eq))
                              (ref.eq (local.get $prop) (global.get $false))
                              (then (global.get $missing))
                              (else
                               (if (result (ref eq))
                                   (ref.eq (call $syntax? (local.get $prop)) (global.get $true))
                                   (then (call $syntax-props (local.get $prop)))
                                   (else
                                    (call $raise-argument-error1
                                          (global.get $symbol:datum->syntax)
                                          (global.get $string:syntax-or-false)
                                          (local.get $prop))
                                    (unreachable))))))))

          (call $datum->syntax/convert
                (local.get $scopes)
                (local.get $shifted)
                (local.get $srcloc-checked)
                (local.get $props-checked)
                (local.get $v)))

    ;; ---------------------------------------------------------------

    ;; (func $datum->syntax-copy
    ;;       (param $v (ref eq))
    ;;       (result (ref eq))

    ;;       (local $pair      (ref $Pair))
    ;;       (local $new-car   (ref eq))
    ;;       (local $new-cdr   (ref eq))
    ;;       (local $vec       (ref $Vector))
    ;;       (local $arr       (ref $Array))
    ;;       (local $new-arr   (ref $Array))
    ;;       (local $len       i32)
    ;;       (local $i         i32)
    ;;       (local $elem      (ref eq))
    ;;       (local $converted (ref eq))
    ;;       (local $box       (ref $Box))

    ;;       ;; Leave existing syntax objects untouched.
    ;;       (if (ref.eq (call $syntax? (local.get $v)) (global.get $true))
    ;;           (then (return (local.get $v))))

    ;;       ;; Copy pairs recursively.
    ;;       (if (ref.test (ref $Pair) (local.get $v))
    ;;           (then
    ;;            (local.set $pair (ref.cast (ref $Pair) (local.get $v)))
    ;;            (local.set $new-car (call $datum->syntax-copy
    ;;                                           (struct.get $Pair $a (local.get $pair))))
    ;;            (local.set $new-cdr (call $datum->syntax-copy
    ;;                                           (struct.get $Pair $d (local.get $pair))))
    ;;            (return (call $cons (local.get $new-car) (local.get $new-cdr)))))

    ;;       ;; Copy vectors and ensure the result is immutable.
    ;;       (if (ref.test (ref $Vector) (local.get $v))
    ;;           (then
    ;;            (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
    ;;            (local.set $arr (struct.get $Vector $arr (local.get $vec)))
    ;;            (local.set $len (array.len (local.get $arr)))
    ;;            (local.set $new-arr (call $make-array (local.get $len) (global.get $false)))
    ;;            (local.set $i (i32.const 0))
    ;;            (block $done
    ;;                   (loop $loop
    ;;                         (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
    ;;                         (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
    ;;                         (local.set $converted (call $datum->syntax-copy (local.get $elem)))
    ;;                         (array.set $Array (local.get $new-arr) (local.get $i) (local.get $converted))
    ;;                         (local.set $i (i32.add (local.get $i) (i32.const 1)))
    ;;                         (br $loop)))
    ;;            (return (struct.new $Vector
    ;;                                (i32.const 0)
    ;;                                (i32.const 1)
    ;;                                (local.get $new-arr)))))

    ;;       ;; Copy boxes and make them immutable.
    ;;       (if (ref.test (ref $Box) (local.get $v))
    ;;           (then
    ;;            (local.set $box (ref.cast (ref $Box) (local.get $v)))
    ;;            (local.set $converted (call $datum->syntax-copy
    ;;                                              (struct.get $Box $v (local.get $box))))
    ;;            (return (call $box-immutable (local.get $converted)))))

    ;;       (local.get $v))

    ;; (func $datum->syntax (type $Prim15)
    ;;       (param $ctxt        (ref eq))
    ;;       (param $v           (ref eq))
    ;;       (param $srcloc-raw  (ref eq))
    ;;       (param $prop-raw    (ref eq))
    ;;       (param $ignored     (ref eq))
    ;;       (result (ref eq))

    ;;       (local $scopes   (ref eq))
    ;;       (local $shifted  (ref eq))
    ;;       (local $srcloc   (ref eq))
    ;;       (local $props    (ref eq))
    ;;       (local $fields   (ref $Array))
    ;;       (local $prop     (ref eq))
    ;;       (local $converted (ref eq))

    ;;       ;; Default context fields.
    ;;       (local.set $scopes (global.get $null))
    ;;       (local.set $shifted (global.get $null))
    ;;       (local.set $srcloc (global.get $false))
    ;;       (local.set $props (global.get $missing))

    ;;       ;; If v is already a syntax object, return it unchanged.
    ;;       (if (ref.eq (call $syntax? (local.get $v)) (global.get $true))
    ;;           (then (return (local.get $v))))

    ;;       ;; Extract lexical information from the context.
    ;;       (if (ref.eq (local.get $ctxt) (global.get $false))
    ;;           (then (nop))
    ;;           (else
    ;;            (if (ref.eq (call $syntax? (local.get $ctxt)) (global.get $true))
    ;;                (then
    ;;                 (local.set $fields (call $syntax-unwrap
    ;;                                               (global.get $symbol:datum->syntax)
    ;;                                               (local.get $ctxt)))
    ;;                 (local.set $scopes (array.get $Array (local.get $fields) (i32.const 1)))
    ;;                 (local.set $shifted (array.get $Array (local.get $fields) (i32.const 2)))
    ;;                 (if (ref.eq (local.get $srcloc-raw) (global.get $missing))
    ;;                     (then (local.set $srcloc (array.get $Array (local.get $fields) (i32.const 3))))))
    ;;                (else
    ;;                 (call $raise-argument-error1
    ;;                       (global.get $symbol:datum->syntax)
    ;;                       (global.get $string:syntax?)
    ;;                       (local.get $ctxt))
    ;;                 (unreachable)))))

    ;;       ;; Interpret the srcloc argument if provided.
    ;;       (if (ref.eq (local.get $srcloc-raw) (global.get $missing))
    ;;           (then (nop))
    ;;           (else
    ;;            (if (ref.eq (local.get $srcloc-raw) (global.get $false))
    ;;                (then (local.set $srcloc (global.get $false)))
    ;;                (else
    ;;                 (if (ref.eq (call $syntax? (local.get $srcloc-raw)) (global.get $true))
    ;;                     (then (local.set $srcloc (call $syntax-srcloc (local.get $srcloc-raw))))
    ;;                     (else (local.set $srcloc (local.get $srcloc-raw)))))))

    ;;       ;; Determine properties to attach.
    ;;       (local.set $prop (local.get $prop-raw))
    ;;       (if (ref.eq (local.get $prop) (global.get $missing))
    ;;           (then (local.set $props (global.get $missing)))
    ;;           (else
    ;;            (if (ref.eq (local.get $prop) (global.get $false))
    ;;                (then (local.set $props (global.get $missing)))
    ;;                (else
    ;;                 (if (ref.eq (call $syntax? (local.get $prop)) (global.get $true))
    ;;                     (then (local.set $props (call $syntax-props (local.get $prop))))
    ;;                     (else
    ;;                      (call $raise-argument-error1
    ;;                            (global.get $symbol:datum->syntax)
    ;;                            (global.get $string:syntax?)
    ;;                            (local.get $prop))
    ;;                      (unreachable))))))

    ;;       (local.set $converted (call $datum->syntax-copy (local.get $v)))
    ;;       (call $syntax-build
    ;;             (global.get $symbol:datum->syntax)
    ;;             (local.get $converted)
    ;;             (local.get $scopes)
    ;;             (local.get $shifted)
    ;;             (local.get $srcloc)
    ;;             (local.get $props)))


    (func $syntax->datum/convert
          (param $who (ref eq))
          (param $v   (ref eq))
          (result (ref eq))

          (local $fields      (ref $Array))
          (local $e           (ref eq))
          (local $pair        (ref $Pair))
          (local $car-raw     (ref eq))
          (local $cdr-raw     (ref eq))
          (local $car-datum   (ref eq))
          (local $cdr-datum   (ref eq))
          (local $vec         (ref $Vector))
          (local $arr         (ref $Array))
          (local $new-arr     (ref $Array))
          (local $len         i32)
          (local $i           i32)
          (local $elem        (ref eq))
          (local $elem-datum  (ref eq))
          (local $hash        i32)
          (local $immutable   i32)
          (local $box         (ref $Box))
          (local $box-val     (ref eq))

          ;; Unwrap nested syntax objects recursively.
          (if (ref.eq (call $syntax? (local.get $v)) (global.get $true))
              (then
               (local.set $fields (call $syntax-unwrap (local.get $who) (local.get $v)))
               (local.set $e (array.get $Array (local.get $fields) (i32.const 0)))
               (return (call $syntax->datum/convert (local.get $who) (local.get $e)))))

          ;; Convert pairs.
          (if (ref.test (ref $Pair) (local.get $v))
              (then
               (local.set $pair (ref.cast (ref $Pair) (local.get $v)))
               (local.set $car-raw (struct.get $Pair $a (local.get $pair)))
               (local.set $cdr-raw (struct.get $Pair $d (local.get $pair)))
               (local.set $car-datum (call $syntax->datum/convert (local.get $who) (local.get $car-raw)))
               (local.set $cdr-datum (call $syntax->datum/convert (local.get $who) (local.get $cdr-raw)))
               (return (call $cons (local.get $car-datum) (local.get $cdr-datum)))))

          ;; Convert vectors element-wise.
          (if (ref.test (ref $Vector) (local.get $v))
              (then
               (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
               (local.set $arr (struct.get $Vector $arr (local.get $vec)))
               (local.set $len (array.len (local.get $arr)))
               (local.set $new-arr (call $make-array (local.get $len) (global.get $false)))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                            (local.set $elem-datum (call $syntax->datum/convert (local.get $who) (local.get $elem)))
                            (array.set $Array (local.get $new-arr) (local.get $i) (local.get $elem-datum))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (local.set $hash (struct.get $Vector $hash (local.get $vec)))
               (local.set $immutable (struct.get $Vector $immutable (local.get $vec)))
               (return (struct.new $Vector
                                   (local.get $hash)
                                   (local.get $immutable)
                                   (local.get $new-arr)))))

          ;; Convert boxes.
          (if (ref.test (ref $Box) (local.get $v))
              (then
               (local.set $box (ref.cast (ref $Box) (local.get $v)))
               (local.set $box-val (struct.get $Box $v (local.get $box)))
               (local.set $box-val (call $syntax->datum/convert (local.get $who) (local.get $box-val)))
               (local.set $hash (struct.get $Box $hash (local.get $box)))
               (local.set $immutable (struct.get $Box $immutable (local.get $box)))
               (return (struct.new $Box
                                   (local.get $hash)
                                   (local.get $immutable)
                                   (local.get $box-val)))))

          (local.get $v))

    (func $syntax->datum (type $Prim1)
          (param $stx (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))
          (local $e      (ref eq))

          (local.set $fields (call $syntax-unwrap
                                   (global.get $symbol:syntax->datum)
                                   (local.get $stx)))
          (local.set $e (array.get $Array (local.get $fields) (i32.const 0)))
          (call $syntax->datum/convert (global.get $symbol:syntax->datum) (local.get $e)))))

;; syntax-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate syntax-object helpers used by the monolithic runtime.
(define syntax-all-runtime-helpers
  (function-forms->runtime-helpers
   'syntax-runtime-only-helpers
   (append correlated-syntax-runtime-only-forms
           syntax-runtime-only-forms)))

;; syntax-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate syntax helpers available in the standalone core runtime.
(define syntax-core-runtime-helpers
  (select-runtime-helpers syntax-all-runtime-helpers
                          correlated-syntax-promoted-runtime-helper-names))

;; syntax-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate syntax helpers that still depend on monolithic runtime definitions.
(define syntax-runtime-only-helpers
  (remove-runtime-helpers syntax-all-runtime-helpers
                          correlated-syntax-promoted-runtime-helper-names))

;; syntax-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given syntax helper names from the runtime helper index.
(define (syntax-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; correlated-syntax-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render correlated syntax helpers in runtime assembly order.
(define (correlated-syntax-runtime-helper-forms helper-index)
  (syntax-helper-forms helper-index correlated-syntax-runtime-only-helper-names))

;; syntax-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render syntax-object helpers in runtime assembly order.
(define (syntax-runtime-helper-forms helper-index)
  (syntax-helper-forms helper-index syntax-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define syntax-helper-index
    (make-core-runtime-helper-index
     (append syntax-core-runtime-helpers
             syntax-runtime-only-helpers)))

  (check-equal? syntax-global-names
                '($correlated-type
                  $correlated-empty-props
                  $syntax-type
                  $syntax-empty-props))

  (check-equal?
   (map core-runtime-helper-name syntax-core-runtime-helpers)
   correlated-syntax-promoted-runtime-helper-names)

  (check-equal?
   (map form-name
        (correlated-syntax-runtime-helper-forms syntax-helper-index))
   correlated-syntax-runtime-only-helper-names)

  (check-equal?
   (map form-name (syntax-runtime-helper-forms syntax-helper-index))
   syntax-runtime-only-helper-names))
