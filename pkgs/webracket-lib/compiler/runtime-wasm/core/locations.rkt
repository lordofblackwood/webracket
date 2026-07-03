#lang racket

(provide location-global-forms
         location-runtime-string-constants
         location-runtime-only-helpers
         source-location-runtime-only-helper-names)

(require "../core-helper.rkt")

;; location-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by source-location helpers.
(define location-runtime-string-constants
  '((srcloc?                    "srcloc?")
    (srcloc-positive-or-false   "(or/c exact-positive-integer? #f)")
    (srcloc-nonnegative-or-false "(or/c exact-nonnegative-integer? #f)")))

;; location-global-forms : (listof datum?)
;;   Declare cached source-location struct type descriptors.
(define location-global-forms
  '(
         ;; Cached srcloc struct type descriptor
         (global $srcloc-type (mut (ref null $StructType)) (ref.null $StructType))))

;; source-location-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for source-location helpers.
(define source-location-runtime-only-helper-names
  '($ensure-srcloc-type
    $srcloc/make
    $srcloc-check-positive
    $srcloc-check-nonnegative
    $srcloc-build
    $srcloc
    $make-srcloc
    $srcloc?
    $raise-argument-error:srcloc-expected
    $srcloc-unwrap
    $srcloc-source
    $srcloc-line
    $srcloc-column
    $srcloc-position
    $srcloc-span
    $srcloc->string))

;; location-runtime-only-forms : (listof datum?)
;;   Enumerate reader and source-location helpers used by the monolithic runtime.
(define location-runtime-only-forms
  '(
    (func $make-initial-location (result (ref eq))
          ;; (location 1 0 1)
          (struct.new $Location
                      (i32.const 0)            ;; hash (placeholder)
                      (global.get $one)        ;; line
                      (global.get $zero)       ;; col
                      (global.get $one)))      ;; pos

    (func $ensure-srcloc-type
          (result (ref $StructType))

          (local $existing (ref null $StructType))
          (local $std      (ref $StructType))
          (local $indices  (ref eq))

          (local.set $existing (global.get $srcloc-type))
          (if (ref.is_null (local.get $existing))
              (then
               (local.set $indices (call $list-from-range/checked (i32.const 0) (i32.const 5)))
               (local.set $std
                          (struct.new $StructType
                                      (i32.const 0)
                                      (ref.cast (ref $Symbol) (global.get $symbol:srcloc))
                                      (global.get $false)
                                      (i32.const 5)
                                      (local.get $indices)
                                      (global.get $null)
                                      (global.get $null)
                                      (ref.cast (ref eq) (call $struct-type-property-table-empty))
                                      (global.get $false)
                                      (local.get $indices)
                                      (global.get $false)
                                      (ref.cast (ref $Symbol) (global.get $symbol:srcloc))))
               (global.set $srcloc-type (local.get $std))
               (local.set $existing (local.get $std))))
          (ref.as_non_null (local.get $existing)))

    (func $srcloc/make
          (param $source   (ref eq))
          (param $line     (ref eq))
          (param $column   (ref eq))
          (param $position (ref eq))
          (param $span     (ref eq))
          (result (ref $Struct))

          (local $std    (ref $StructType))
          (local $fields (ref $Array))

          (local.set $std (call $ensure-srcloc-type))
          (local.set $fields
                     (array.new_fixed $Array 5
                                      (local.get $source)
                                      (local.get $line)
                                      (local.get $column)
                                      (local.get $position)
                                      (local.get $span)))
          (struct.new $Struct
                      (i32.const 0)
                      (global.get $false)
                      (ref.i31 (i32.const 0))
                      (global.get $false)
                      (ref.func $invoke-struct)
                      (local.get $std)
                      (local.get $fields)))

    (func $srcloc-check-positive
          (param $who (ref eq))
          (param $v   (ref eq))
          (result (ref eq))

          (if (result (ref eq))
              (ref.eq (local.get $v) (global.get $false))
              (then (local.get $v))
              (else (if (result (ref eq))
                        (ref.eq (call $exact-positive-integer? (local.get $v)) (global.get $true))
                        (then (local.get $v))
                        (else (call $raise-argument-error1 (local.get $who)
                                    (global.get $string:srcloc-positive-or-false)
                                    (local.get $v))
                              (unreachable))))))

    (func $srcloc-check-nonnegative
          (param $who (ref eq))
          (param $v   (ref eq))
          (result (ref eq))

          (if (result (ref eq))
              (ref.eq (local.get $v) (global.get $false))
              (then (local.get $v))
              (else (if (result (ref eq))
                        (ref.eq (call $exact-nonnegative-integer? (local.get $v)) (global.get $true))
                        (then (local.get $v))
                        (else (call $raise-argument-error1 (local.get $who)
                                    (global.get $string:srcloc-nonnegative-or-false)
                                    (local.get $v))
                              (unreachable))))))

    (func $srcloc-build
          (param $who (ref eq))
          (param $source   (ref eq))
          (param $line     (ref eq))
          (param $column   (ref eq))
          (param $position (ref eq))
          (param $span     (ref eq))
          (result (ref eq))

          (local $line-checked     (ref eq))
          (local $column-checked   (ref eq))
          (local $position-checked (ref eq))
          (local $span-checked     (ref eq))

          (local.set $line-checked
                     (call $srcloc-check-positive (local.get $who) (local.get $line)))
          (local.set $column-checked
                     (call $srcloc-check-nonnegative (local.get $who) (local.get $column)))
          (local.set $position-checked
                     (call $srcloc-check-positive (local.get $who) (local.get $position)))
          (local.set $span-checked
                     (call $srcloc-check-nonnegative (local.get $who) (local.get $span)))
          (call $srcloc/make
                (local.get $source)
                (local.get $line-checked)
                (local.get $column-checked)
                (local.get $position-checked)
                (local.get $span-checked)))

    (func $srcloc (type $Prim5)
          (param $source (ref eq))
          (param $line (ref eq))
          (param $column (ref eq))
          (param $position (ref eq))
          (param $span (ref eq))
          (result (ref eq))

          (call $srcloc-build
                (global.get $symbol:srcloc)
                (local.get $source)
                (local.get $line)
                (local.get $column)
                (local.get $position)
                (local.get $span)))

    (func $make-srcloc (type $Prim5)
          (param $source (ref eq))
          (param $line (ref eq))
          (param $column (ref eq))
          (param $position (ref eq))
          (param $span (ref eq))
          (result (ref eq))

          (call $srcloc-build
                (global.get $symbol:make-srcloc)
                (local.get $source)
                (local.get $line)
                (local.get $column)
                (local.get $position)
                (local.get $span)))

    (func $srcloc? (type $Prim1)
          (param $v (ref eq))
          (result   (ref eq))

          (local $struct (ref $Struct))
          (local $type   (ref eq))
          (local $std    (ref $StructType))
          (local $ok     i32)

          (local.set $std (call $ensure-srcloc-type))
          (if (result (ref eq))
              (ref.test (ref $Struct) (local.get $v))
              (then
               (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
               (local.set $type   (struct.get $Struct $type (local.get $struct)))
               (local.set $ok     (call $struct-type-is-a?/i32
                                        (local.get $type)
                                        (local.get $std)))
               (if (result (ref eq))
                   (local.get $ok)
                   (then (global.get $true))
                   (else (global.get $false))))
              (else (global.get $false))))

    (func $raise-argument-error:srcloc-expected
          (param $who (ref eq))
          (param $got (ref eq))

          (call $raise-argument-error1
                (local.get $who)
                (global.get $string:srcloc?)
                (local.get $got)))

    (func $srcloc-unwrap
          (param $who (ref eq))
          (param $v   (ref eq))
          (result     (ref $Array))

          (local $struct (ref $Struct))
          (local $type   (ref eq))
          (local $std    (ref $StructType))
          (local $ok     i32)

          (local.set $std (call $ensure-srcloc-type))
          (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
              (then (call $raise-argument-error:srcloc-expected (local.get $who) (local.get $v))
                    (unreachable)))
          (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
          (local.set $type   (struct.get $Struct $type (local.get $struct)))
          (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
          (if (i32.eqz (local.get $ok))
              (then (call $raise-argument-error:srcloc-expected (local.get $who) (local.get $v))
                    (unreachable)))
          (struct.get $Struct $fields (local.get $struct)))

    (func $srcloc-source (type $Prim1)
          (param $loc (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $srcloc-unwrap
                                   (global.get $symbol:srcloc-source)
                                   (local.get $loc)))
          (array.get $Array (local.get $fields) (i32.const 0)))

    (func $srcloc-line (type $Prim1)
          (param $loc (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $srcloc-unwrap
                                   (global.get $symbol:srcloc-line)
                                   (local.get $loc)))
          (array.get $Array (local.get $fields) (i32.const 1)))

    (func $srcloc-column (type $Prim1)
          (param $loc (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $srcloc-unwrap
                                   (global.get $symbol:srcloc-column)
                                   (local.get $loc)))
          (array.get $Array (local.get $fields) (i32.const 2)))

    (func $srcloc-position (type $Prim1)
          (param $loc (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields (call $srcloc-unwrap
                                   (global.get $symbol:srcloc-position)
                                   (local.get $loc)))
          (array.get $Array (local.get $fields) (i32.const 3)))

    (func $srcloc-span (type $Prim1)
          (param $loc (ref eq))
          (result (ref eq))

          (local $fields (ref $Array))

          (local.set $fields
                     (call $srcloc-unwrap
                           (global.get $symbol:srcloc-span)
                           (local.get $loc)))
          (array.get $Array (local.get $fields) (i32.const 4)))

    ; Formats an `srcloc` into a string suitable for use in an error message.
    (func $srcloc->string (type $Prim1)
          (param $loc (ref eq))
          (result     (ref eq))

          (local $fields    (ref $Array))
          (local $source    (ref eq))
          (local $line      (ref eq))
          (local $column    (ref eq))
          (local $position  (ref eq))
          (local $span      (ref eq))
          (local $parts     (ref eq))
          (local $part      (ref eq))
          (local $path      (ref $Path))
          (local $relative  (ref eq))
          (local $relative-parts (ref eq))
          (local $relative-node  (ref $Pair))
          (local $reversed  (ref eq))
          (local $with-seps (ref eq))

          ;; Initialize non-defaultable locals
          (local.set $part (global.get $string:empty))
          (local.set $path (ref.cast (ref $Path)
                                     (call $bytes->path
                                           (global.get $bytes:non-empty) ; ignored
                                           (global.get $missing))))
          (local.set $relative (global.get $false))
          (local.set $relative-parts (global.get $null))
          (local.set $relative-node (ref.cast (ref $Pair)
                                              (call $cons
                                                    (global.get $false)
                                                    (global.get $null))))
          ;; Extract fields
          (local.set $fields (call $srcloc-unwrap
                                   (global.get $symbol:srcloc->string)
                                   (local.get $loc)))
          (local.set $source   (array.get $Array (local.get $fields) (i32.const 0)))
          (local.set $line     (array.get $Array (local.get $fields) (i32.const 1)))
          (local.set $column   (array.get $Array (local.get $fields) (i32.const 2)))
          (local.set $position (array.get $Array (local.get $fields) (i32.const 3)))
          (local.set $span     (array.get $Array (local.get $fields) (i32.const 4)))

          ;; Accumulate output in parts
          (local.set $parts (global.get $null))

          (if (ref.eq (local.get $source) (global.get $false))
              (then (nop))
              (else
               (if (ref.test (ref $String) (local.get $source))
                   (then (local.set $part (local.get $source)))
                   (else
                    (if (ref.test (ref $Path) (local.get $source))
                        (then
                         (local.set $path (ref.cast (ref $Path) (local.get $source)))
                         (local.set $relative
                                    (call $find-relative-path
                                          (global.get $current-directory-for-user-path)
                                          (local.get $path)
                                          (global.get $false)
                                          (global.get $true)
                                          (global.get $true)))
                         (local.set $relative-parts (call $explode-path (local.get $relative)))
                         (if (i32.and
                              (ref.test (ref $Pair) (local.get $relative-parts))
                              (ref.eq (struct.get $Pair $a
                                                  (ref.cast (ref $Pair)
                                                            (local.get $relative-parts)))
                                      (global.get $symbol:up)))
                             (then (local.set $relative (local.get $path))))
                         (local.set $part (call $path->string (local.get $relative))))
                        (else
                         (local.set $part (call $format/display (local.get $source)))))))
               (local.set $parts (call $cons (local.get $part) (local.get $parts)))))

          (if (ref.eq (local.get $line) (global.get $false))
              (then (nop))
              (else
               (local.set $part  (call $number->string (local.get $line) (global.get $missing)))
               (local.set $parts (call $cons (local.get $part) (local.get $parts)))))

          (if (ref.eq (local.get $column) (global.get $false))
              (then (nop))
              (else
               (local.set $part (call $number->string (local.get $column) (global.get $missing)))
               (local.set $parts (call $cons (local.get $part) (local.get $parts)))))

          ;; Note: support for position/span depends on struct-type-property?
          ;; which is not yet implemented, so skip them for now.
          (drop (local.get $position))
          (drop (local.get $span))

          (local.set $reversed  (call $reverse (local.get $parts)))
          (local.set $with-seps (call $add-between
                                      (local.get $reversed)
                                      (global.get $string:colon)))
          (call $string-append* (local.get $with-seps) (global.get $null)))))

;; location-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate reader and source-location helpers used by the monolithic runtime.
(define location-runtime-only-helpers
  (function-forms->runtime-helpers
   'location-runtime-only-helpers
   location-runtime-only-forms))
