#lang racket

(provide string-core-runtime-helpers
         string-runtime-string-constants
         string-runtime-symbol-constants
         string-additional-runtime-only-helper-names
         string-append-runtime-only-helper-names
         string-array-conversion-runtime-only-helper-names
         string-basic-runtime-only-helper-names
         string-buffer-error-runtime-only-helper-names
         string-build-runtime-only-helper-names
         string-case-runtime-only-helper-names
         string-check-runtime-only-helper-names
         string-comparison-runtime-only-helper-names
         string-constructor-runtime-only-helper-names
         string-codepoint-runtime-only-helper-names
         string-copy!-runtime-only-helper-names
         string-copy-runtime-only-helper-names
         string-dummy-runtime-only-helper-names
         string-error-runtime-only-helper-names
         string-index-runtime-only-helper-names
         string-list-conversion-runtime-only-helper-names
         string-mutation-runtime-only-helper-names
         string-mutability-runtime-only-helper-names
         string-selector-runtime-only-helper-names
         string-split-runtime-only-helper-names
         string-take-drop-runtime-only-helper-names
         string-trim-runtime-only-helper-names
         string-utf8-runtime-only-helper-names
         string-mutability-runtime-helper-forms
         string-hash-core-runtime-helper-forms
         string-main-runtime-helper-forms
         string-buffer-runtime-helper-forms
         string-runtime-only-helpers)

(require "../core-helper.rkt"
         (only-in "../../private/immediates.rkt"
                  char-mask
                  char-shift
                  char-tag
                  immediate-rep))

;; string-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by string helpers and string contract checks.
(define string-runtime-string-constants
  '((empty           "")
    (space           " ")
    (char?           "char?")
    (string?         "string?")
    (mutable-string? "mutable-string?")
    (string-copy!:destination-contract "(and/c string? (not/c immutable?))")
    (string-copy!:not-enough-room ": not enough room in target string")
    (string-copy!:target-length "\n  target length: ")
    (string-copy!:needed-length "\n  needed length: ")
    (string-trim:separator-contract "(or/c string? regexp?)")
    (string-ref:index-out-of-range ": index is out of range")
    (string-ref:index-out-of-range-empty ": index is out of range for empty string")
    (string-ref:index "\n  index: ")
    (string-ref:valid-range "\n  valid range: [0, ")
    (string-ref:valid-range-close "]")
    (string-ref:string "\n  string: ")
    (substring:starting-index-out-of-range ": starting index is out of range")
    (substring:ending-index-out-of-range ": ending index is out of range")
    (substring:ending-index-before-start ": ending index is smaller than starting index")
    (substring:starting-index "\n  starting index: ")
    (substring:ending-index "\n  ending index: ")
    (string-utf8:byte-string "\n  byte string: ")
    (string-buffer-overflow "WebRacket linear-memory buffer is too small")
    (string-length-too-large ": requested length is too large for WebRacket")
    (string-check:string-copy!/checked "internal string-copy!/checked bounds check failed")
    (string-check:index-out-of-bounds "internal string index bounds check failed")
    (string-check:invalid-utf8-input "invalid UTF-8 input")
    (string-check:invalid-utf8-start "invalid UTF-8 starting index")
    (string-check:invalid-utf8-end "invalid UTF-8 ending index")
    (string-check:invalid-utf8-range "invalid UTF-8 range")
    (string-check:internal-invariant "internal string invariant failed")
    (build-string-procedure "(exact-nonnegative-integer? . -> . char?)")
    (listof-string? "(listof string?)")
    (string-or-bytes "(or/c string? bytes?)")))

;; string-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by string helpers and string errors.
(define string-runtime-symbol-constants
  '(string
    string-set!
    string-take
    string-take-right
    string-drop
    string-drop-right
    string=?
    string<?
    string<=?
    string>?
    string>=?
    string-ci=?
    string-ci<?
    string-ci<=?
    string-ci>?
    string-ci>=?
    string-trim-left
    string-trim-right))

;; string-base-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate manually defined string helpers that originated in core runtime.
(define string-base-core-runtime-helpers
  (list
   (core-runtime-helper
    '$i32array->string
    "$i32array->string"
    (lambda ()
      `(func $i32array->string (param $arr (ref $I32Array)) (result (ref $String))
             ;; Constructs a $String from an I32Array of codepoints.
             ;; Assumes the string is mutable and un-hashed (hash = 0).
             (struct.new $String
                         (i32.const 0)            ;; hash = 0
                         (i32.const 0)            ;; mutable
                         (local.get $arr)))))     ;; codepoints

   (core-runtime-helper
    '$i32array->immutable-string
    "$i32array->immutable-string"
    (lambda ()
      `(func $i32array->immutable-string (param $arr (ref $I32Array)) (result (ref $String))
             ;; Constructs a $String from an I32Array of codepoints.
             ;; Assumes the string is immutable and un-hashed (hash = 0).
             (struct.new $String
                         (i32.const 0)            ;; hash = 0
                         (i32.const 1)            ;; immutable
                         (local.get $arr)))))     ;; codepoints

   (core-runtime-helper
    '$i32growable-array->string
    "$i32growable-array->string"
    (lambda ()
      `(func $i32growable-array->string (param $g (ref $I32GrowableArray)) (result (ref $String))
             (call $i32array->string
                   (call $i32growable-array->array (local.get $g))))))

   (core-runtime-helper
    '$i32growable-array->immutable-string
    "$i32growable-array->immutable-string"
    (lambda ()
      `(func $i32growable-array->immutable-string (param $g (ref $I32GrowableArray)) (result (ref $String))
             (call $i32array->immutable-string
                   (call $i32growable-array->array (local.get $g))))))

   (core-runtime-helper
    '$string-hash/i32
    "$string-hash/i32"
    (lambda ()
      `(func $string-hash/i32
             (param $s (ref $String))
             (result i32)

             (local $hash i32)
             (local $arr  (ref $I32Array))
             (local $len  i32)
             (local $i    i32)
             (local $cp   i32)

             ;; Check if already memoized
             (local.set $hash (struct.get $String $hash (local.get $s)))
             (if (result i32)
                 (i32.ne (local.get $hash) (i32.const 0))
                 (then (return (local.get $hash))) ;; Already cached
                 ;; Compute FNV-1a hash
                 (else
                  (local.set $hash (i32.const 2166136261)) ; offset
                  (local.set $arr  (struct.get $String $codepoints (local.get $s)))
                  (local.set $len  (array.len (local.get $arr)))
                  (local.set $i    (i32.const 0))
                  (block $done
                         (loop $loop
                               (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                               (local.set $cp (array.get $I32Array (local.get $arr) (local.get $i)))
                               (local.set $hash
                                          (i32.mul
                                           (i32.xor (local.get $hash) (local.get $cp))
                                           (i32.const 16777619))) ; prime
                               (local.set $i (i32.add (local.get $i) (i32.const 1)))
                               (br $loop)))
                  ;; Ensure non-zero before memoizing
                  (if (i32.eqz (local.get $hash))
                      (then (local.set $hash (i32.const 2))))
                  ;; Memoize
                  (struct.set $String $hash (local.get $s) (local.get $hash))
                  (local.get $hash))))))))

;; string-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string mutability predicates.
(define string-mutability-runtime-only-helper-names
  '($mutable-string?
    $immutable-string?))

;; string-check-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string check helpers.
(define string-check-runtime-only-helper-names
  '($raise-check-string))

;; string-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string construction helpers.
(define string-constructor-runtime-only-helper-names
  '($raise-make-string:bad-length
    $raise-make-string:bad-char
    $raise-argument-error:char-expected/who
    $raise-argument-error:char-expected
    $raise-string-length-too-large/who
    $string-length/i32/who
    $make-string
    $make-string/checked
    $make-immutable-string/checked
    $string->immutable-string))

;; string-index-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string index error helpers.
(define string-index-runtime-only-helper-names
  '($raise-string-index-out-of-range/who/i32
    $raise-bad-string-index
    $raise-bad-string-index/i32
    $string-index/i32/who
    $raise-string-length:bad-argument
    $raise-string-index-out-of-bounds/i32))

;; string-codepoint-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for single-codepoint string helpers.
(define string-codepoint-runtime-only-helper-names
  '($codepoint->string))

;; string-dummy-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string dummy construction helpers.
(define string-dummy-runtime-only-helper-names
  '($make-dummy-string))

;; string-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic string predicates and constructors.
(define string-basic-runtime-only-helper-names
  '($string?
    $non-empty-string?
    $raise-string:char-expected
    $string-char->integer/i32
    $string))

;; string-buffer-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string-buffer error helpers.
(define string-buffer-error-runtime-only-helper-names
  '($raise-string-buffer-overflow))

;; string-build-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for build-string helpers.
(define string-build-runtime-only-helper-names
  '($raise-build-string:bad-length
    $raise-build-string:char-expected
    $build-string))

;; string-selector-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string selector helpers.
(define string-selector-runtime-only-helper-names
  '($raise-string-ref:string-expected
    $raise-string-ref:index-expected
    $raise-string-ref:index-out-of-range
    $string-length
    $string-length/checked/i32
    $string-ref
    $string-ref/checked
    $string-ref/checked/i32))

;; string-mutation-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string mutation helpers.
(define string-mutation-runtime-only-helper-names
  '($raise-string-set!:string-expected
    $raise-string-set!:fixnum-expected
    $raise-string-set!:char-expected
    $raise-string-set!:string-immutable
    $string-set!))

;; string-copy-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string copy and fill helpers.
(define string-copy-runtime-only-helper-names
  '($raise-substring:string-expected
    $raise-substring:index-expected
    $raise-substring-index-out-of-range
    $raise-substring-end-before-start
    $substring
    $string-grapheme-span
    $raise-string-copy:string-expected
    $string-copy
    $raise-immutable-string
    $raise-string-fill!:string-expected
    $raise-string-fill!:char-expected
    $raise-string-fill!:string-immutable
    $string-fill!))

;; string-copy!-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string-copy! helpers.
(define string-copy!-runtime-only-helper-names
  '($raise-string-copy!:bad-destination
    $raise-string-copy!:bad-destination-start
    $raise-string-copy!:bad-source
    $raise-string-copy!:bad-source-start
    $raise-string-copy!:bad-source-end
    $raise-string-copy!:bad-source-range
    $raise-string-copy!:bad-destination-range
    $string-copy!
    $raise-string-copy!/checked:out-of-bounds
    $string-copy!/checked))

;; string-append-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string append helpers.
(define string-append-runtime-only-helper-names
  '($raise-string-append:string-expected
    $raise-string-append*:list-expected
    $string-append/2
    $string-append/who
    $string-append
    $string-append-immutable
    $string-append*))

;; string-array-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for array-of-strings conversion helpers.
(define string-array-conversion-runtime-only-helper-names
  '($array-of-strings->string
    $growable-array-of-strings->string))

;; string-take-drop-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string take/drop helpers.
(define string-take-drop-runtime-only-helper-names
  '($string-take
    $string-take/checked
    $string-take-right
    $string-take-right/checked
    $string-drop
    $string-drop/checked
    $string-drop-right
    $string-drop-right/checked))

;; string-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string-section error stubs.
(define string-error-runtime-only-helper-names
  '($raise-argument-error:string-expected/who
    $raise-argument-error:string-expected
    $bomb))

;; string-trim-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string trim helpers.
(define string-trim-runtime-only-helper-names
  '($raise-string-trim:string-expected
    $raise-string-trim:separator-expected
    $string-trim-right
    $string-trim-left
    $string-trim))

;; string-additional-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for additional racket/string helpers.
(define string-additional-runtime-only-helper-names
  '($raise-racket-string:string-expected
    $string-suffix?
    $string-suffix?/i32
    $string-suffix?/i32/checked
    $string-prefix?
    $string-prefix?/i32
    $string-prefix?/i32/checked
    $string-contains?
    $string-find/who
    $string-find
    $string-replace))

;; string-split-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string join and split helpers.
(define string-split-runtime-only-helper-names
  '($raise-string-join:listof-string-expected
    $raise-string-join:separator-expected
    $string-join
    $string-split
    $string-split:matches?
    $string-split:trim-left
    $string-split:trim-right
    $string-split:find-match
    $string-split:skip-repeats))

;; string-case-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string case-conversion helpers.
(define string-case-runtime-only-helper-names
  '($string-upcase
    $string-downcase
    $string-foldcase
    $string-titlecase))

;; string-list-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string/list conversion helpers.
(define string-list-conversion-runtime-only-helper-names
  '($string->list
    $list->string))

;; string-case-helper-form : symbol? symbol? -> datum?
;;   Build a unary string case-conversion helper that maps codepoints through imp.
(define (string-case-helper-form name imp)
  (define who (string->symbol
               (format "$symbol:~a" (substring (symbol->string name) 1))))
  `(func ,name (type $Prim1) (param $s (ref eq)) (result (ref eq))
         (local $str (ref $String))
         (local $arr (ref $I32Array))
         (local $len i32)
         (local $res (ref $I32Array))
         (local $i   i32)
         (local $cp  i32)
         (local $cp2 i32)
         ;; Type check
         (if (i32.eqz (ref.test (ref $String) (local.get $s)))
             (then (call $raise-racket-string:string-expected
                         (global.get ,who)
                         (local.get $s))))
         ;; Extract codepoint array and length
         (local.set $str (ref.cast (ref $String) (local.get $s)))
         (local.set $arr (struct.get $String $codepoints (local.get $str)))
         (local.set $len (array.len (local.get $arr)))
         ;; Allocate result array
         (local.set $res (call $i32array-make (local.get $len) (i32.const 0)))
         ;; Loop over characters
         (local.set $i (i32.const 0))
         (block $done
                (loop $loop
                      (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                      (local.set $cp (call $i32array-ref (local.get $arr) (local.get $i)))
                      (local.set $cp2 (call ,imp (local.get $cp)))
                      (call $i32array-set! (local.get $res) (local.get $i) (local.get $cp2))
                      (local.set $i (i32.add (local.get $i) (i32.const 1)))
                      (br $loop)))
         ;; Build new mutable string
         (struct.new $String
                     (i32.const 0)
                     (i32.const 0)
                     (local.get $res))))

;; string-mutability-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string mutability helpers that still depend on monolithic runtime globals.
(define string-mutability-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-mutability-runtime-only-helpers
   '(
         (func $mutable-string? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $String) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $String $immutable
                                                 (ref.cast (ref $String) (local.get $v)))
                                     (i32.const 0))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $immutable-string? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $String) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $String $immutable
                                                 (ref.cast (ref $String) (local.get $v)))
                                     (i32.const 1))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))


     )))

;; string-check-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string check helpers that still depend on monolithic runtime globals.
(define string-check-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-check-runtime-only-helpers
   '(
         (func $raise-check-string
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string)
                     (global.get $string:string?)
                     (local.get $x))
               (unreachable))
     )))

;; string-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string construction helpers that still depend on monolithic runtime globals.
(define string-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-constructor-runtime-only-helpers
   `(
         (func $raise-make-string:bad-length
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:make-string)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $x)))
         (func $raise-make-string:bad-char
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:make-string)
                     (global.get $string:char?)
                     (local.get $x)))
         (func $raise-argument-error:char-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:char?)
                     (local.get $x))
               (unreachable))
         (func $raise-argument-error:char-expected
               (param $x (ref eq))
               (call $raise-argument-error:char-expected/who
                     (global.get $symbol:char?)
                     (local.get $x))
               (unreachable))
         (func $raise-string-length-too-large/who
               (param $who (ref eq))

               (local $message (ref $String))

               (local.set $message
                          (call $string-append/2
                                (call $format/display (local.get $who))
                                (global.get $string:string-length-too-large)))
               (call $raise
                     (call $exn:fail/make
                           (local.get $message)
                           (call $current-continuation-marks
                                 (global.get $missing)))
                     (global.get $true))
               (unreachable))
         (func $string-length/i32/who
               (param $who      (ref eq))
               (param $len-raw  (ref eq))
               (param $expected (ref eq))
               (result i32)

               (local $len i32)

               (local.set $len
                          (call $exact-nonnegative-integer->i32/saturating
                                (local.get $len-raw)))
               (if (i32.lt_s (local.get $len) (i32.const 0))
                   (then
                    (call $raise-argument-error1
                          (local.get $who)
                          (local.get $expected)
                          (local.get $len-raw))
                    (unreachable)))
               (if (i32.gt_s (local.get $len) (i32.const 536870911))
                   (then
                    (call $raise-string-length-too-large/who (local.get $who))
                    (unreachable)))
               (local.get $len))

         (func $make-string (type $Prim12)
               (param $n-raw  (ref eq))    ;; exact nonnegative integer
               (param $ch-raw (ref eq))    ;; optional immediate character
               (result        (ref eq))

               (local $n          i32)
               (local $ch-tagged  i32)
               (local $ch         i32)
               ;; --- Type check for length ---
               (local.set $n
                          (call $string-length/i32/who
                                (global.get $symbol:make-string)
                                (local.get $n-raw)
                                (global.get $string:exact-nonnegative-integer?)))
               ;; --- Handle optional character ---
               (if (ref.eq (local.get $ch-raw) (global.get $missing))
                   (then (local.set $ch (i32.const 0)))
                   (else
                    ;; --- Validate character ---
                    (if (i32.eqz (ref.test (ref i31) (local.get $ch-raw)))
                        (then (call $raise-make-string:bad-char (local.get $ch-raw))))
                    (local.set $ch-tagged (i31.get_u (ref.cast (ref i31) (local.get $ch-raw))))
                    (if (i32.ne (i32.and (local.get $ch-tagged) (i32.const ,char-mask)) (i32.const ,char-tag))
                        (then (call $raise-make-string:bad-char (local.get $ch-raw))))
                    ;; --- Extract code point from character ---
                    (local.set $ch (i32.shr_u (local.get $ch-tagged) (i32.const ,char-shift)))))
               ;; --- Delegate ---
               (call $make-string/checked (local.get $n) (local.get $ch)))

         (func $make-string/checked
               (param $n  i32)      ;; number of characters
               (param $ch i32)      ;; codepoint to fill
               (result    (ref $String))

               (local $arr (ref $I32Array))
               ;; Create backing array and fill with `ch`
               (local.set $arr (array.new $I32Array (local.get $ch) (local.get $n)))
               ;; Construct mutable string
               (call $debug-allocation-tick (i32.const 6))
               (struct.new $String
                           (i32.const 0)     ;; hash = 0
                           (i32.const 0)     ;; mutable
                           (local.get $arr)))

         (func $make-immutable-string/checked
               (param $n  i32)      ;; number of characters
               (param $ch i32)      ;; codepoint to fill
               (result    (ref $String))

               (local $arr (ref $I32Array))
               ;; Create backing array and fill with `ch`
               (local.set $arr (array.new $I32Array (local.get $ch) (local.get $n)))
               ;; Construct mutable string
               (struct.new $String
                           (i32.const 0)     ;; hash = 0
                           (i32.const 1)     ;; immutable
                           (local.get $arr)))

         (func $string->immutable-string (type $Prim1)
               (param $s (ref eq))
               (result   (ref eq))

               (local $str (ref $String))

               (local.set $str (call $make-dummy-string))
               ;; 1. Check that s is a String
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string->immutable-string)
                               (local.get $s))
                         (unreachable)))
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; 2. If already immutable, return it directly
               (if (result (ref eq))
                   (i32.eq (struct.get $String $immutable (local.get $str)) (i32.const 1))
                   (then (local.get $str))
                   (else
                   ;; Otherwise, create a new immutable copy
                   (struct.new $String
                               ; Note: now the mutable and immutable string gets the same hash code.
                               ;       Okay?
                               (struct.get $String $hash (local.get $str))  ;; inherit hash
                               (i32.const 1)                                ;; immutable
                               (call $i32array-copy
                                     (struct.get $String $codepoints (local.get $str))
                                     (i32.const 0)
                                     (call $i32array-length (struct.get $String $codepoints (local.get $str)))))))))))

;; string-build-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate build-string helpers that still depend on monolithic runtime globals.
(define string-build-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-build-runtime-only-helpers
   `(
         (func $raise-build-string:bad-length
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:build-string)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $bad)))
         (func $raise-build-string:char-expected
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-set!)
                     (global.get $string:char?)
                     (local.get $bad)))

         (func $build-string (type $Prim2)
               (param $n-raw (ref eq))
               (param $proc  (ref eq))
               (result       (ref eq))

               (local $n    i32)
               (local $f    (ref $Procedure))
               (local $finv (ref $ProcedureInvoker))
               (local $args (ref $Args))
               (local $arr  (ref $I32Array))
               (local $i    i32)
               (local $res  (ref eq))
               (local $cp   i32)
               (local $str  (ref $String))

               ;; --- Check arguments ---
               (local.set $n
                          (call $string-length/i32/who
                                (global.get $symbol:build-string)
                                (local.get $n-raw)
                                (global.get $string:exact-nonnegative-integer?)))
               (if (ref.eq (call $procedure? (local.get $proc))
                           (global.get $false))
                   (then (call $raise-argument-error1
                               (global.get $symbol:build-string)
                               (global.get $string:build-string-procedure)
                               (local.get $proc))
                         (unreachable)))
               (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $f)
                                  (i32.const 1)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:build-string)
                               (global.get $string:build-string-procedure)
                               (local.get $proc))
                         (unreachable)))

               ;; --- Decode and prepare ---
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

               (local.set $arr  (call $i32array-make (local.get $n) (i32.const 0)))
               (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

               ;; --- Loop ---
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                            ;; Set argument to current index as fixnum
                            (array.set $Args (local.get $args) (i32.const 0)
                                       (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                            ;; Call procedure
                            (local.set $res
                                       (call_ref $ProcedureInvoker
                                                 (local.get $f)
                                                 (local.get $args)
                                                 (local.get $finv)))
                            ;; Validate character result
                            (if (i32.eqz (ref.test (ref i31) (local.get $res)))
                                (then (call $raise-build-string:char-expected (local.get $res))
                                      (unreachable)))
                            (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $res))))
                            (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask))
                                        (i32.const ,char-tag))
                                (then (call $raise-build-string:char-expected (local.get $res))
                                      (unreachable)))
                            (local.set $cp (i32.shr_u (local.get $cp) (i32.const ,char-shift)))
                            (call $i32array-set! (local.get $arr) (local.get $i) (local.get $cp))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               ;; --- Construct string ---
               (local.set $str
                          (struct.new $String
                                      (i32.const 0)
                                      (i32.const 0)
                                      (local.get $arr)))
               (local.get $str))
     )))

;; string-index-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string index error helpers that still depend on monolithic runtime globals.
(define string-index-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-index-runtime-only-helpers
   '(
         (func $raise-string-index-out-of-range/who/i32
               (param $who (ref eq))
               (param $s   (ref eq))
               (param $idx i32)
               (param $max i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 10)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (if (i32.lt_s (local.get $max) (i32.const 0))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:index-out-of-range-empty)))
                   (else
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:index-out-of-range))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $idx) (i32.const 1)))))
               (if (i32.ge_s (local.get $max) (i32.const 0))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:valid-range))
                    (call $growable-array-add! (local.get $out)
                          (call $format/display
                                (ref.i31 (i32.shl (local.get $max) (i32.const 1)))))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:valid-range-close))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:string))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $s)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $raise-bad-string-index
               (param $x (ref eq))
               (param $i (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-ref)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $i))
               (unreachable))
         (func $raise-bad-string-index/i32
               (param $x (ref eq))
               (param $i i32)

               (local $str (ref $String))
               (local $len i32)

               (local.set $str (ref.cast (ref $String) (local.get $x)))
               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (call $raise-string-index-out-of-range/who/i32
                     (global.get $symbol:string-ref)
                     (local.get $x)
                     (local.get $i)
                     (i32.sub (local.get $len) (i32.const 1)))
               (unreachable))
         (func $string-index/i32/who
               (param $who   (ref eq))
               (param $i-raw (ref eq))
               (result i32)

               (local $idx i32)

               (local.set $idx
                          (call $exact-nonnegative-integer->i32/saturating
                                (local.get $i-raw)))
               (if (i32.lt_s (local.get $idx) (i32.const 0))
                   (then
                    (call $raise-argument-error1
                          (local.get $who)
                          (global.get $string:exact-nonnegative-integer?)
                          (local.get $i-raw))
                    (unreachable)))
               (if (i32.gt_s (local.get $idx) (i32.const 536870911))
                   (then (return (i32.const 536870911))))
               (local.get $idx))
         (func $raise-string-length:bad-argument
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-length)
                     (global.get $string:string?)
                     (local.get $x)))

         (func $raise-string-index-out-of-bounds/i32
               (param $x (ref eq))
               (param $i i32)
               (param $n i32)
               (call $raise-arguments-error
                     (global.get $symbol:string-ref)
                     (global.get $string:string-check:index-out-of-bounds)
                     (array.new_fixed $Args 0))
               (unreachable))
     )))

;; string-codepoint-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate single-codepoint string helpers that still depend on monolithic runtime globals.
(define string-codepoint-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-codepoint-runtime-only-helpers
   `(
         ; for single character strings
         (func $codepoint->string
               (param  $ch i32)                    ;; Unicode scalar value
               (result     (ref $String))

               (local $cp  (ref $I32Array))
               ;; Validate that ch is a Unicode scalar (i.e. not in surrogate range)
               (if (i32.or (i32.lt_u (local.get $ch) (i32.const 0))
                           (i32.gt_u (local.get $ch) (i32.const 0x10FFFF)))
                   (then (call $raise-argument-error:char-expected (ref.i31 (local.get $ch)))
                         (unreachable)))
               (if (i32.and (i32.ge_u (local.get $ch) (i32.const 0xD800))
                            (i32.le_u (local.get $ch) (i32.const 0xDFFF)))
                   (then (call $raise-argument-error:char-expected (ref.i31 (local.get $ch)))
                         (unreachable)))
               ;; Allocate I32Array of length 1
               (local.set $cp (array.new_fixed $I32Array 1 (local.get $ch)))
               ;; Create string with immutable = 1, hash = 0
               (struct.new $String
                           (i32.const 0)       ;; hash (lazy)
                           (i32.const 1)       ;; immutable
                           (local.get $cp)))
     )))

;; string-dummy-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string dummy construction helpers that still depend on monolithic runtime globals.
(define string-dummy-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-dummy-runtime-only-helpers
   '(
         (func $make-dummy-string (result (ref $String))
               (struct.new $String
                           (i32.const 0)  ;; hash = 0
                           (i32.const 0)  ;; mutable
                           (call $i32array-make (i32.const 0) (i32.const 0))))
     )))

;; string-basic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate basic string predicates and constructors that still depend on monolithic runtime globals.
(define string-basic-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-basic-runtime-only-helpers
   `(
         (func $string? (type $Prim1) (param $s (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $String) (local.get $s))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $non-empty-string? (type $Prim1)
               (param $s (ref eq))
               (result   (ref eq))

               (local $str (ref $String))
               (local $len i32)
               (if (result (ref eq))
                   (ref.test (ref $String) (local.get $s))
                   (then (local.set $str (ref.cast (ref $String) (local.get $s)))
                         (local.set $len (call $i32array-length
                                                  (struct.get $String $codepoints (local.get $str))))
                         (if (result (ref eq))
                             (i32.eqz (local.get $len))
                             (then (global.get $false))
                             (else (global.get $true))))
                   (else (global.get $false))))

         ;; Constructors

         (func $raise-string:char-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string)
                     (global.get $string:char?)
                     (local.get $x))
               (unreachable))

         (func $string-char->integer/i32
               (param $c (ref eq))
               (result i32)

               (local $raw i32)

               (if (i32.eqz (ref.test (ref i31) (local.get $c)))
                   (then (call $raise-string:char-expected (local.get $c))
                         (unreachable)))
               (local.set $raw (i31.get_u (ref.cast (ref i31) (local.get $c))))
               (if (i32.ne (i32.and (local.get $raw) (i32.const ,char-mask))
                           (i32.const ,char-tag))
                   (then (call $raise-string:char-expected (local.get $c))
                         (unreachable)))
               (i32.shr_u (local.get $raw) (i32.const ,char-shift)))

         (func $string (type $Prim>=0)
               (param $args (ref eq))
               (result      (ref eq))

               (local $argv      (ref $Args))
               (local $len       i32)
               (local $arr       (ref $I32Array))
               (local $i         i32)
               (local $ch        (ref eq))
               (local $use-args? i32)
               (local $list      (ref eq))
               (local $node      (ref eq))
               (local $pair      (ref $Pair))

               ;; Initialize non-defaultable locals
               (local.set $argv (array.new $Args (global.get $null) (i32.const 0)))
               (local.set $ch   (global.get $false))

               ;; Support both $Args arrays and ordinary rest argument lists.
               (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
               (local.set $list      (global.get $null))
               (local.set $node      (global.get $null))
               (local.set $len       (if (result i32) (local.get $use-args?)
                                         (then
                                          (local.set $argv (ref.cast (ref $Args) (local.get $args)))
                                          (array.len (local.get $argv)))
                                         (else
                                          (local.set $list (local.get $args))
                                          (local.set $node (local.get $list))
                                          (call $length/i32 (local.get $list)))))

               ;; Allocate array for codepoints
               (local.set $arr (array.new $I32Array (i32.const 0) (local.get $len)))

               ;; Fill array with characters from either representation
               (local.set $i (i32.const 0))
               (if (i32.eqz (local.get $use-args?))
                   (then
                    (local.set $node (local.get $list))
                    (block $done
                           (loop $loop
                                 (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                 (if (ref.test (ref $Pair) (local.get $node))
                                     (then
                                      (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                      (local.set $ch   (struct.get $Pair $a (local.get $pair)))
                                      (local.set $node (struct.get $Pair $d (local.get $pair))))
                                     (else
                                      (call $raise-pair-expected (local.get $node))
                                      (unreachable)))
                                 (array.set $I32Array
                                            (local.get $arr)
                                            (local.get $i)
                                            (call $string-char->integer/i32 (local.get $ch)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop))))
                   (else
                    (block $done
                           (loop $loop
                                 (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                                 (local.set $ch (array.get $Args (local.get $argv) (local.get $i)))
                                 (array.set $I32Array
                                            (local.get $arr)
                                            (local.get $i)
                                            (call $string-char->integer/i32 (local.get $ch)))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))))
               ;; Construct mutable string
               (struct.new $String
                           (i32.const 0)  ;; hash
                           (i32.const 0)  ;; mutable
                           (local.get $arr)))
     )))

;; string-selector-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string selector helpers that still depend on monolithic runtime globals.
(define string-selector-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-selector-runtime-only-helpers
   `(
         (func $raise-string-ref:string-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-ref)
                     (global.get $string:string?)
                     (local.get $x)))

         (func $raise-string-ref:index-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-ref)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $x)))

         (func $raise-string-ref:index-out-of-range
               (param $s   (ref $String))
               (param $idx i32)
               (param $len i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 10)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (global.get $symbol:string-ref)))
               (if (i32.eqz (local.get $len))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:index-out-of-range-empty)))
                   (else
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:index-out-of-range))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $idx) (i32.const 1)))))
               (if (i32.ne (local.get $len) (i32.const 0))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:valid-range))
                    (call $growable-array-add! (local.get $out)
                          (call $format/display
                                (ref.i31
                                 (i32.shl (i32.sub (local.get $len) (i32.const 1))
                                          (i32.const 1)))))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:valid-range-close))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:string))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $s)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $string-length (type $Prim1)
               (param $s-raw (ref eq))
               (result (ref eq))

               (local $s   (ref $String))
               (local $len i32)
               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s-raw)))
                   (then (call $raise-string-length:bad-argument (local.get $s-raw))))
               ;; --- Decode ---
               (local.set $s (ref.cast (ref $String) (local.get $s-raw)))
               ;; --- Compute ---
               (local.set $len (call $i32array-length
                                     (struct.get $String $codepoints (local.get $s))))
               ;; --- Return fixnum ---
               (ref.i31 (i32.shl (local.get $len) (i32.const 1))))


         (func $string-length/checked/i32
               (param $s (ref $String))
               (result i32)
               ;; Fetch the length of the codepoints array
               (call $i32array-length (struct.get $String $codepoints (local.get $s))))


         (func $string-ref (type $Prim2)
               (param $s (ref eq))
               (param $i (ref eq))
               (result (ref eq))

               (local $str (ref $String))
               (local $idx i32)
               (local $len i32)

               ;; --- All tests ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-string-ref:string-expected (local.get $s))))

               ;; --- All decoding ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (local.set $idx
                          (call $string-index/i32/who
                                (global.get $symbol:string-ref)
                                (local.get $i)))
               (local.set $len (call $string-length/checked/i32 (local.get $str)))

               ;; --- Bounds check and delegate ---
               (if (result (ref eq))
                   (i32.lt_u (local.get $idx) (local.get $len))
                   (then (call $string-ref/checked (local.get $str) (local.get $idx)))
                   (else (call $raise-string-ref:index-out-of-range
                               (local.get $str)
                               (local.get $idx)
                               (local.get $len))
                         (unreachable))))

         (func $string-ref/checked   ; unsafe: no bounds check
               (param $str (ref $String))
               (param $idx i32)
               (result     (ref eq))

               (local $arr (ref $I32Array))
               (local $cp  i32)

               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $cp  (call $i32array-ref (local.get $arr) (local.get $idx)))
               ;; Return (char): (cp << char-shift) | char-tag
               (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const ,char-shift))
                                (i32.const ,char-tag))))

         (func $string-ref/checked/i32   ; unsafe: no bounds check
               (param $str (ref $String))
               (param $idx i32)
               (result     i32)

               (local $arr (ref $I32Array))
               (local $cp  i32)

               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $cp  (call $i32array-ref (local.get $arr) (local.get $idx)))
               (local.get $cp))
     )))

;; string-mutation-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string mutation helpers that still depend on monolithic runtime globals.
(define string-mutation-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-mutation-runtime-only-helpers
   `(
         (func $raise-string-set!:string-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-set!)
                     (global.get $string:mutable-string?)
                     (local.get $x)))
         (func $raise-string-set!:fixnum-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-set!)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $x)))
         (func $raise-string-set!:char-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-set!)
                     (global.get $string:char?)
                     (local.get $x)))
         (func $raise-string-set!:string-immutable
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-set!)
                     (global.get $string:mutable-string?)
                     (local.get $x)))

         (func $string-set!
               (param $s   (ref eq))
               (param $i   (ref eq))
               (param $ch  (ref eq))
               (result     (ref eq))

               (local $str     (ref $String))
               (local $arr     (ref $I32Array))
               (local $idx     i32)
               (local $cp      i32)
               (local $tagged  i32)
               (local $len     i32)
               ;; --- Type checks ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-string-set!:string-expected (local.get $s))))
               (local.set $idx
                          (call $string-index/i32/who
                                (global.get $symbol:string-set!)
                                (local.get $i)))
               (if (i32.eqz (ref.test (ref i31) (local.get $ch)))
                   (then (call $raise-string-set!:char-expected (local.get $ch))))
               ;; --- Decode ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; Check for immutability
               (if (i32.eq (struct.get $String $immutable (local.get $str)) (i32.const 1))
                   (then (call $raise-string-set!:string-immutable (local.get $s))))
               ;; Decode and validate character
               (local.set $tagged (i31.get_u (ref.cast (ref i31) (local.get $ch))))
               (if (i32.ne (i32.and (local.get $tagged) (i32.const ,char-mask)) (i32.const ,char-tag))
                   (then (call $raise-string-set!:char-expected (local.get $ch))))
               (local.set $cp (i32.shr_u (local.get $tagged) (i32.const ,char-shift)))
               ;; --- Bounds-check and write ---
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $len (call $i32array-length (local.get $arr)))
               (if (i32.lt_u (local.get $idx) (local.get $len))
                   (then (call $i32array-set! (local.get $arr) (local.get $idx) (local.get $cp))
                         ;; Keep the hash. The eq-identity doesn't change.
                         (return (global.get $void)))
                   (else (call $raise-string-index-out-of-range/who/i32
                               (global.get $symbol:string-set!)
                               (local.get $s)
                               (local.get $idx)
                               (i32.sub (local.get $len) (i32.const 1)))))
               (unreachable))
     )))

;; string-copy-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string copy and fill helpers that still depend on monolithic runtime globals.
(define string-copy-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-copy-runtime-only-helpers
   `(
         (func $raise-substring:string-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:substring)
                     (global.get $string:string?)
                     (local.get $x)))

         (func $raise-substring:index-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:substring)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $x)))

         (func $raise-substring-index-out-of-range
               (param $reason      (ref eq))
               (param $index-label (ref eq))
               (param $s           (ref $String))
               (param $idx         i32)
               (param $len         i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 9)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (global.get $symbol:substring)))
               (call $growable-array-add! (local.get $out)
                     (local.get $reason))
               (call $growable-array-add! (local.get $out)
                     (local.get $index-label))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $idx) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:string))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $s)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $raise-substring-end-before-start
               (param $s     (ref $String))
               (param $start i32)
               (param $end   i32)
               (param $len   i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 11)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (global.get $symbol:substring)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:substring:ending-index-before-start))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:substring:ending-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $end) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:substring:starting-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $start) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:string))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $s)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $substring (type $Prim23)
              (param $s     (ref eq))
              (param $start (ref eq))
              (param $end   (ref eq)) ; optional, default to (string-length s)
              (result       (ref eq))

              (local $str      (ref null $String))
              (local $arr      (ref $I32Array))
              (local $i32start i32)
              (local $i32end   i32)
              (local $len      i32)
              ;; check string
              (if (ref.test (ref $String) (local.get $s))
                  (then (local.set $str (ref.cast (ref $String) (local.get $s))))
                  (else (call $raise-substring:string-expected (local.get $s))))
              ;; decode and check start index
              (local.set $i32start
                         (call $string-index/i32/who
                               (global.get $symbol:substring)
                               (local.get $start)))
              ;; get array and length
              (local.set $arr (struct.get $String $codepoints (local.get $str)))
              (local.set $len (call $i32array-length (local.get $arr)))
              ;; supply default value for the optional end index
              (if (ref.eq (local.get $end) (global.get $missing))
                  (then (local.set $i32end (local.get $len)))
                  (else
                   ;; decode and check end index
                   (local.set $i32end
                              (call $string-index/i32/who
                                    (global.get $symbol:substring)
                                    (local.get $end)))))
              ;; bounds check: start <= end <= len
              (if (i32.gt_u (local.get $i32start) (local.get $len))
                  (then (call $raise-substring-index-out-of-range
                              (global.get $string:substring:starting-index-out-of-range)
                              (global.get $string:substring:starting-index)
                              (ref.cast (ref $String) (local.get $str))
                              (local.get $i32start)
                              (local.get $len))))
              (if (i32.gt_u (local.get $i32end) (local.get $len))
                  (then (call $raise-substring-index-out-of-range
                              (global.get $string:substring:ending-index-out-of-range)
                              (global.get $string:substring:ending-index)
                              (ref.cast (ref $String) (local.get $str))
                              (local.get $i32end)
                              (local.get $len))))
              (if (i32.gt_u (local.get $i32start) (local.get $i32end))
                  (then (call $raise-substring-end-before-start
                              (ref.cast (ref $String) (local.get $str))
                              (local.get $i32start)
                              (local.get $i32end)
                              (local.get $len))))
              ;; create new string
              (struct.new $String
                          (i32.const 0) ; hash
                          (i32.const 0) ; mutable (also for immutable input)
                          (call $i32array-copy (local.get $arr) (local.get $i32start) (local.get $i32end))))

         ;; string-grapheme-span : string? exact-nonnegative-integer? [exact-nonnegative-integer?] -> exact-nonnegative-integer?
         ;;   Return the number of codepoints in the grapheme cluster at start.
         (func $string-grapheme-span (type $Prim23)
               (param $s     (ref eq))
               (param $start (ref eq))
               (param $end   (ref eq)) ; optional, default to (string-length s)
               (result       (ref eq))

               (local $str      (ref $String))
               (local $i32start i32)
               (local $i32end   i32)
               (local $len      i32)
               (local $i        i32)
               (local $state    (ref eq))
               (local $steps    (ref $Values))
               (local $consumed (ref eq))
               (local $span     i32)

               ;; Validate string and indices first.
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:string-grapheme-span)
                               (global.get $string:string?)
                               (local.get $s))
                         (unreachable)))
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (local.set $i32start
                          (call $string-index/i32/who
                                (global.get $symbol:string-grapheme-span)
                                (local.get $start)))
               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (if (ref.eq (local.get $end) (global.get $missing))
                   (then (local.set $i32end (local.get $len)))
                   (else
                    (local.set $i32end
                               (call $string-index/i32/who
                                     (global.get $symbol:string-grapheme-span)
                                     (local.get $end)))))
               (if (i32.gt_u (local.get $i32start) (local.get $len))
                   (then (call $raise-arguments-error
                               (global.get $symbol:string-grapheme-span)
                               (global.get $string:substring:starting-index-out-of-range)
                               (array.new_fixed $Args 0))
                         (unreachable)))
               (if (i32.gt_u (local.get $i32end) (local.get $len))
                   (then (call $raise-arguments-error
                               (global.get $symbol:string-grapheme-span)
                               (global.get $string:substring:ending-index-out-of-range)
                               (array.new_fixed $Args 0))
                         (unreachable)))
               (if (i32.gt_u (local.get $i32start) (local.get $i32end))
                   (then (call $raise-arguments-error
                               (global.get $symbol:string-grapheme-span)
                               (global.get $string:substring:ending-index-before-start)
                               (array.new_fixed $Args 0))
                         (unreachable)))

               ;; A completed cluster with a nonzero state has already read
               ;; the first codepoint of the following cluster. A completed
               ;; CRLF cluster has state zero, so its final LF is included.
               (local.set $i (local.get $i32start))
               (local.set $state (ref.i31 (i32.const 0)))
               (local.set $span (i32.const 0))
               (block $done
                      (loop $scan
                            (br_if $done (i32.ge_u (local.get $i) (local.get $i32end)))
                            (local.set $steps
                                       (ref.cast
                                        (ref $Values)
                                        (call $char-grapheme-step
                                              (call $string-ref/checked
                                                    (local.get $str)
                                                    (local.get $i))
                                              (local.get $state))))
                            (local.set $consumed
                                       (array.get $Values (local.get $steps) (i32.const 0)))
                            (local.set $state
                                       (array.get $Values (local.get $steps) (i32.const 1)))
                            (if (ref.eq (local.get $consumed) (global.get $true))
                                (then
                                 (if (i32.eqz
                                      (i31.get_u
                                       (ref.cast (ref i31) (local.get $state))))
                                     (then
                                      (local.set $span
                                                 (i32.add
                                                  (i32.sub (local.get $i) (local.get $i32start))
                                                  (i32.const 1))))
                                     (else
                                      (local.set $span
                                                 (i32.sub (local.get $i) (local.get $i32start)))))
                                 (br $done)))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $scan)))
               (if (i32.eqz (local.get $span))
                   (then (local.set $span
                                    (i32.sub (local.get $i32end) (local.get $i32start)))))
               (ref.i31 (i32.shl (local.get $span) (i32.const 1))))

         (func $raise-string-copy:string-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-copy)
                     (global.get $string:string?)
                     (local.get $x)))

         (func $string-copy (type $Prim1)
               (param $s (ref eq))
               (result (ref eq))

               (local $str (ref $String))
               (local $arr (ref $I32Array))
               (local $len i32)
               (local $copy (ref $I32Array))
               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-string-copy:string-expected (local.get $s))))
               ;; --- Cast and extract ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $len (array.len (local.get $arr)))
               ;; --- Copy the codepoint array ---
               (local.set $copy (call $i32array-copy (local.get $arr) (i32.const 0) (local.get $len)))
               ;; --- Construct new mutable string with hash = 0 ---
               (struct.new $String
                           (i32.const 0)       ;; $hash
                           (i32.const 0)       ;; mutable
                           (local.get $copy))) ;; $codepoints

         (func $raise-immutable-string
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-copy!)
                     (global.get $string:string-copy!:destination-contract)
                     (local.get $x)))

         (func $raise-string-fill!:string-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-fill!)
                     (global.get $string:mutable-string?)
                     (local.get $x)))
         (func $raise-string-fill!:char-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-fill!)
                     (global.get $string:char?)
                     (local.get $x)))
         (func $raise-string-fill!:string-immutable
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-fill!)
                     (global.get $string:mutable-string?)
                     (local.get $x)))

         (func $string-fill! (type $Prim2)
               (param $s   (ref eq))
               (param $ch  (ref eq))
               (result     (ref eq))

               (local $str (ref $String))
               (local $arr (ref $I32Array))
               (local $cp  i32)

               ;; --- 1. Check and cast string ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-string-fill!:string-expected (local.get $s))))
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; --- 2. Raise if immutable ---
               (if (i32.ne (struct.get $String $immutable (local.get $str)) (i32.const 0))
                   (then (call $raise-string-fill!:string-immutable (local.get $s))))
               ;; --- 3. Decode and check char immediate ---
               (if (i32.eqz (ref.test (ref i31) (local.get $ch)))
                   (then (call $raise-string-fill!:char-expected (local.get $ch))))
               (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $ch))))
               (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask)) (i32.const ,char-tag))
                   (then (call $raise-string-fill!:char-expected (local.get $ch))))
               (local.set $cp (i32.shr_u (local.get $cp) (i32.const ,char-shift)))
               ;; --- 4. Fill (keep eq-hash-code) ---
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (call $i32array-fill! (local.get $arr) (local.get $cp))
               ;; --- 5. Return void ---
               (global.get $void))
     )))

;; string-append-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string append helpers that still depend on monolithic runtime globals.
(define string-append-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-append-runtime-only-helpers
   '(
         (func $raise-string-append:string-expected
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:string?)
                     (local.get $x)))

         (func $raise-string-append*:list-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:apply)
                     (global.get $string:list?)
                     (local.get $x)))

         (func $string-append/2 (param $s1 (ref eq)) (param $s2 (ref eq)) (result (ref $String))
               (local $str1 (ref null $String))
               (local $str2 (ref null $String))
               (if (ref.test (ref $String) (local.get $s1))
                   (then (local.set $str1 (ref.cast (ref $String) (local.get $s1))))
                   (else (call $raise-string-append:string-expected
                               (global.get $symbol:string-append)
                               (local.get $s1))))
               (if (ref.test (ref $String) (local.get $s2))
                   (then (local.set $str2 (ref.cast (ref $String) (local.get $s2))))
                   (else (call $raise-string-append:string-expected
                               (global.get $symbol:string-append)
                               (local.get $s2))))
               (struct.new $String
                           (i32.const 0)
                           (i32.const 0)
                           (call $i32array-append
                                 (struct.get $String $codepoints (local.get $str1))
                                 (struct.get $String $codepoints (local.get $str2)))))


         (func $string-append/who
               (param  $who  (ref eq))
               (param  $xs   (ref eq))        ;; expects a list of strings
               (result       (ref eq))

               (local $n     i32)
               (local $node  (ref $Pair))
               (local $s     (ref $String))
               (local $v     (ref eq))
               (local $orig  (ref eq))
               (local $total i32)
               (local $len   i32)
               (local $arr   (ref $I32Array))
               (local $pos   i32)

               ;; === initialize non-defaultable refs ===
               (local.set $s (ref.cast (ref $String) (global.get $string:empty)))

               ;; Preserve original list
               (local.set $orig (local.get $xs))
               ;; Determine number of arguments
               (local.set $n (call $length/i32 (local.get $xs)))
               ;; Zero arguments -> existing empty string
               (if (i32.eqz (local.get $n))
                   (then (return (global.get $string:empty))))
               ;; Extract and check first argument
               (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
               (local.set $v    (struct.get $Pair $a (local.get $node)))
               (if (ref.test (ref $String) (local.get $v))
                   (then (local.set $s (ref.cast (ref $String) (local.get $v))))
                   (else (call $raise-string-append:string-expected
                               (local.get $who)
                               (local.get $v))))
               ;; Single argument -> copy to ensure fresh mutable string
               (if (i32.eq (local.get $n) (i32.const 1))
                   (then (if (ref.eq (local.get $s) (global.get $string:empty))
                             (then (return (global.get $string:empty)))
                             (else (return (call $string-copy (local.get $s)))))))
               ;; Compute total length
               (local.set $total
                          (call $i32array-length
                                (struct.get $String $codepoints (local.get $s))))
               (local.set $xs (struct.get $Pair $d (local.get $node)))
               (block $done1
                      (loop $loop1
                            (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v    (struct.get $Pair $a (local.get $node)))
                            (if (ref.test (ref $String) (local.get $v))
                                (then
                                 (local.set $s (ref.cast (ref $String) (local.get $v)))
                                 (local.set $len
                                            (call $i32array-length
                                                  (struct.get $String $codepoints (local.get $s))))
                                 (local.set $total (i32.add (local.get $total) (local.get $len))))
                                (else (call $raise-string-append:string-expected
                                            (local.get $who)
                                            (local.get $v))))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop1)))
               ;; All strings empty -> return empty string
               (if (i32.eqz (local.get $total))
                   (then (return (global.get $string:empty))))
               ;; Allocate result array
               (local.set $arr (call $i32array-make (local.get $total) (i32.const 0)))
               ;; Copy strings into result array
               (local.set $xs (local.get $orig))
               (local.set $pos (i32.const 0))
               (block $done2
                      (loop $loop2
                            (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $s
                                       (ref.cast (ref $String) (struct.get $Pair $a (local.get $node))))
                            (local.set $len
                                       (call $i32array-length
                                             (struct.get $String $codepoints (local.get $s))))
                            (call $i32array-copy!
                                  (local.get $arr) (local.get $pos)
                                  (struct.get $String $codepoints (local.get $s))
                                  (i32.const 0) (local.get $len))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop2)))

               (struct.new $String
                           (i32.const 0)
                           (i32.const 0)
                           (local.get $arr)))

         (func $string-append (type $Prim>=0)
               (param  $xs   (ref eq))        ;; expects a list of strings
               (result       (ref eq))
               (call $string-append/who
                     (global.get $symbol:string-append)
                     (local.get $xs)))


         (func $string-append-immutable (type $Prim>=0)
               (param  $xs (ref eq))         ;; list of strings
               (result     (ref eq))

               (local $s   (ref $String))
               (local $arr (ref $I32Array))
               ;; Do the append (returns a fresh $String)
               (local.set $s (ref.cast (ref $String)
                                       (call $string-append/who
                                             (global.get $symbol:string-append-immutable)
                                             (local.get $xs))))
               ;; Reuse its codepoint array
               (local.set $arr (struct.get $String $codepoints (local.get $s)))
               ;; Build a new $String that is immutable (=1). Hash = 0 (lazy).
               (struct.new $String
                           (i32.const 0)      ;; $hash
                           (i32.const 1)      ;; $immutable
                           (local.get $arr))) ;; $codepoints

         (func $string-append* (type $Prim>=1)
               (param $str  (ref eq))  ;; string? or list of strings
               (param $rest (ref eq))  ;; additional strings, last element list
               (result      (ref eq))

               (local $xs   (ref eq))
               (local $node (ref $Pair))
               (local $acc  (ref eq))
               (local $last (ref eq))
               (local $args (ref eq))

               ; initialize locals with no defaults
               (local.set $last (global.get $false))
               ;; no extra args: first arg supplies list of strings
               (if (ref.eq (local.get $rest) (global.get $null))
                   (then
                    (if (ref.eq (call $list? (local.get $str)) (global.get $false))
                        (then (call $raise-string-append*:list-expected (local.get $str))))
                    (return (call $string-append (local.get $str)))))

               ;; separate last list from preceding string arguments
               (local.set $xs  (local.get $rest))
               (local.set $acc (global.get $null))
               (block $done
                      (loop $loop
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $xs   (struct.get $Pair $d (local.get $node)))
                            (if (ref.eq (local.get $xs) (global.get $null))
                                (then
                                 (local.set $last (struct.get $Pair $a (local.get $node)))
                                 (br $done))
                                (else
                                 (local.set $acc
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (struct.get $Pair $a (local.get $node))
                                                        (local.get $acc)))
                                 (br $loop)))))

               ;; rebuild argument list in proper order
               (if (ref.eq (call $list? (local.get $last)) (global.get $false))
                   (then (call $raise-string-append*:list-expected (local.get $last))))
               (local.set $args (local.get $last))
               (block $done2
                      (loop $loop2
                            (br_if $done2 (ref.eq (local.get $acc) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $acc)))
                            (local.set $args
                                       (struct.new $Pair
                                                   (i32.const 0)
                                                   (struct.get $Pair $a (local.get $node))
                                                   (local.get $args)))
                            (local.set $acc (struct.get $Pair $d (local.get $node)))
                            (br $loop2)))
               (local.set $args
                          (struct.new $Pair (i32.const 0)
                                      (local.get $str)
                                      (local.get $args)))
               (call $string-append (local.get $args)))
     )))

;; string-split-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string join and split helpers that still depend on monolithic runtime globals.
(define string-split-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-split-runtime-only-helpers
   '(
         (func $raise-string-join:listof-string-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-join)
                     (global.get $string:listof-string?)
                     (local.get $x)))

         (func $raise-string-join:separator-expected
               (param $x (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-join)
                     (global.get $string:string?)
                     (local.get $x)))

         ;; Note: Simplified version: accepts list of strings and optional separator only.
         (func $string-join (type $Prim12)
               (param $strs (ref eq)) ;; listof string?
               (param $sep  (ref eq)) ;; optional string?, default = " "
               (result      (ref eq))

               (local $xs      (ref eq))
               (local $node    (ref $Pair))
               (local $v       (ref eq))
               (local $str     (ref $String))
               (local $sep-str (ref $String))
               (local $sep-len i32)
               (local $n       i32)
               (local $total   i32)
               (local $len     i32)
               (local $arr     (ref $I32Array))
               (local $pos     i32)

               ;; --- Validate and measure strings before checking separator ---
               (if (ref.eq (call $list? (local.get $strs)) (global.get $false))
                   (then (call $raise-string-join:listof-string-expected (local.get $strs))))
               (local.set $xs    (local.get $strs))
               (local.set $n     (i32.const 0))
               (local.set $total (i32.const 0))
               (block $done1
                      (loop $loop1
                            (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $v (struct.get $Pair $a (local.get $node)))
                            (if (ref.test (ref $String) (local.get $v))
                                (then
                                 (local.set $str (ref.cast (ref $String) (local.get $v)))
                                 (local.set $len
                                            (call $i32array-length
                                                  (struct.get $String $codepoints (local.get $str))))
                                 (local.set $total (i32.add (local.get $total) (local.get $len)))
                                 (local.set $n (i32.add (local.get $n) (i32.const 1))))
                                (else (call $raise-string-join:listof-string-expected
                                            (local.get $strs))))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop1)))

               ;; --- Handle optional separator ---
               (local.set $sep-str
                          (if (result (ref $String))
                              (ref.eq (local.get $sep) (global.get $missing))
                              (then (ref.cast (ref $String) (global.get $string:space)))
                              (else (if (result (ref $String))
                                        (ref.test (ref $String) (local.get $sep))
                                        (then (ref.cast (ref $String) (local.get $sep)))
                                        (else (call $raise-string-join:separator-expected
                                                    (local.get $sep))
                                              (unreachable))))))
               ;; --- Determine separator length ---
               (local.set $sep-len
                          (call $i32array-length
                                (struct.get $String $codepoints (local.get $sep-str))))
               (if (i32.eqz (local.get $n))
                   (then (return (global.get $string:empty))))
               ;; --- Add separator lengths ---
               (local.set $total
                          (i32.add
                           (local.get $total)
                           (i32.mul (i32.sub (local.get $n) (i32.const 1))
                                    (local.get $sep-len))))
               ;; --- All empty -> empty string ---
               (if (i32.eqz (local.get $total))
                   (then (return (global.get $string:empty))))
               ;; --- Allocate result array ---
               (local.set $arr (call $i32array-make (local.get $total) (i32.const 0)))
               ;; --- Copy strings and separators ---
               (local.set $xs (local.get $strs))
               (local.set $pos (i32.const 0))
               (block $done2
                      (loop $loop2
                            (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                            (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                            (local.set $str
                                       (ref.cast (ref $String)
                                                 (struct.get $Pair $a (local.get $node))))
                            (local.set $len
                                       (call $i32array-length
                                             (struct.get $String $codepoints (local.get $str))))
                            (call $i32array-copy!
                                  (local.get $arr) (local.get $pos)
                                  (struct.get $String $codepoints (local.get $str))
                                  (i32.const 0) (local.get $len))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (if (ref.eq (local.get $xs) (global.get $null))
                                (then (nop))
                                (else
                                 (call $i32array-copy!
                                       (local.get $arr) (local.get $pos)
                                       (struct.get $String $codepoints (local.get $sep-str))
                                       (i32.const 0) (local.get $sep-len))
                                 (local.set $pos
                                            (i32.add (local.get $pos) (local.get $sep-len)))))
                            (br $loop2)))
               ;; --- Build result string ---
               (struct.new $String
                           (i32.const 0)
                           (i32.const 0)
                           (local.get $arr)))


         ;; Note: Unlike Racket's string-split, this variant does not support
         ;; keyword arguments or regular-expression separators.
         (func $string-split (type $Prim14)
               (param $str-raw    (ref eq)) ;; string?
               (param $sep-raw    (ref eq)) ;; optional string?, default = " "
               (param $trim-raw   (ref eq)) ;; optional any/c, default = #t
               (param $repeat-raw (ref eq)) ;; optional any/c, default = #f
               (result            (ref eq))

               (local $str          (ref $String))
               (local $sep          (ref $String))
               (local $trim-val     (ref eq))
               (local $repeat-val   (ref eq))
               (local $arr-str      (ref $I32Array))
               (local $arr-sep      (ref $I32Array))
               (local $len-str      i32)
               (local $len-sep      i32)
               (local $trim-flag    i32)
               (local $repeat-flag  i32)
               (local $start        i32)
               (local $end          i32)
               (local $match-pos    i32)
               (local $segment-len  i32)
               (local $acc          (ref eq))
               (local $piece        (ref $String))
               (local $idx          i32)
               (local $empty        (ref $String))
               (local $found        i32)
               (local $pos          i32)

               ;; --- Decode defaults ---
               (if (i32.eqz (ref.test (ref $String) (local.get $str-raw)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string-split)
                               (local.get $str-raw))
                         (unreachable)))
               (local.set $str (ref.cast (ref $String) (local.get $str-raw)))

               (local.set $sep
                          (if (result (ref $String))
                              (ref.eq (local.get $sep-raw) (global.get $missing))
                              (then (ref.cast (ref $String) (global.get $string:space)))
                              (else (if (result (ref $String))
                                        (ref.test (ref $String) (local.get $sep-raw))
                                        (then (ref.cast (ref $String) (local.get $sep-raw)))
                                        (else (call $raise-argument-error:string-expected/who
                                                    (global.get $symbol:string-split)
                                                    (local.get $sep-raw))
                                              (unreachable))))))

               (local.set $trim-val
                          (if (result (ref eq))
                              (ref.eq (local.get $trim-raw) (global.get $missing))
                              (then (global.get $true))
                              (else (local.get $trim-raw))))
               (local.set $repeat-val
                          (if (result (ref eq))
                              (ref.eq (local.get $repeat-raw) (global.get $missing))
                              (then (global.get $false))
                              (else (local.get $repeat-raw))))

               (local.set $trim-flag
                          (if (result i32)
                              (ref.eq (local.get $trim-val) (global.get $false))
                              (then (i32.const 0))
                              (else (i32.const 1))))
               (local.set $repeat-flag
                          (if (result i32)
                              (ref.eq (local.get $repeat-val) (global.get $false))
                              (then (i32.const 0))
                              (else (i32.const 1))))

               (local.set $arr-str (struct.get $String $codepoints (local.get $str)))
               (local.set $arr-sep (struct.get $String $codepoints (local.get $sep)))
               (local.set $len-str (call $i32array-length (local.get $arr-str)))
               (local.set $len-sep (call $i32array-length (local.get $arr-sep)))

               (local.set $start (i32.const 0))
               (local.set $end   (local.get $len-str))

               ;; --- Trim using literal separator when requested ---
               (if (i32.and (local.get $trim-flag)
                            (i32.ne (local.get $len-sep) (i32.const 0)))
                   (then
                    (local.set $start
                               (call $string-split:trim-left
                                     (local.get $arr-str)
                                     (local.get $arr-sep)
                                     (local.get $len-sep)
                                     (local.get $start)
                                     (local.get $end)
                                     (local.get $repeat-flag)))
                    (local.set $end
                               (call $string-split:trim-right
                                     (local.get $arr-str)
                                     (local.get $arr-sep)
                                     (local.get $len-sep)
                                     (local.get $start)
                                     (local.get $end)
                                     (local.get $repeat-flag)))))

               ;; --- Special-case empty after trimming ---
               (if (i32.eq (local.get $start) (local.get $end))
                   (then
                    (if (local.get $trim-flag)
                        (then (return (global.get $null)))
                        (else
                         (local.set $empty (ref.cast (ref $String) (global.get $string:empty)))
                         (return (struct.new $Pair
                                             (i32.const 0)
                                             (local.get $empty)
                                             (global.get $null)))))))

               ;; --- Handle empty separator by splitting into codepoints ---
               (if (i32.eqz (local.get $len-sep))
                   (then
                    (local.set $acc (global.get $null))
                    (local.set $idx (i32.sub (local.get $end) (i32.const 1)))
                    (block $chars-done
                           (loop $chars
                                 (br_if $chars-done (i32.lt_s (local.get $idx) (local.get $start)))
                                 (local.set $piece
                                            (call $codepoint->string
                                                  (call $i32array-ref
                                                        (local.get $arr-str)
                                                        (local.get $idx))))
                                 (local.set $acc
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (local.get $piece)
                                                        (local.get $acc)))
                                 (if (i32.eq (local.get $idx) (local.get $start))
                                     (then (br $chars-done)))
                                 (local.set $idx (i32.sub (local.get $idx) (i32.const 1)))
                                 (br $chars)))
                    (return (local.get $acc))))

               (local.set $acc (global.get $null))
               (local.set $pos (local.get $start))
               (local.set $empty (ref.cast (ref $String) (global.get $string:empty)))

               (block $done
                      (loop $split
                            (local.set $match-pos
                                       (call $string-split:find-match
                                             (local.get $arr-str)
                                             (local.get $arr-sep)
                                             (local.get $len-sep)
                                             (local.get $pos)
                                             (local.get $end)))
                            (local.set $segment-len
                                       (i32.sub (local.get $match-pos) (local.get $pos)))
                            (local.set $found
                                       (i32.ne (local.get $match-pos) (local.get $end)))
                            (if (i32.or (i32.ne (local.get $segment-len) (i32.const 0))
                                        (i32.eqz (local.get $repeat-flag)))
                                (then
                                 (local.set $piece
                                            (if (result (ref $String))
                                                (i32.eqz (local.get $segment-len))
                                                (then (local.get $empty))
                                                (else (call $i32array->string
                                                            (call $i32array-copy
                                                                  (local.get $arr-str)
                                                                  (local.get $pos)
                                                                  (local.get $match-pos))))))
                                 (local.set $acc
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (local.get $piece)
                                                        (local.get $acc)))))
                            (if (i32.eqz (local.get $found))
                                (then (br $done)))
                            (local.set $pos
                                       (i32.add (local.get $match-pos) (local.get $len-sep)))
                            (if (local.get $repeat-flag)
                                (then
                                 (local.set $pos
                                            (call $string-split:skip-repeats
                                                  (local.get $arr-str)
                                                  (local.get $arr-sep)
                                                  (local.get $len-sep)
                                                  (local.get $pos)
                                                  (local.get $end)))))
                            (br $split)))

               (call $reverse (local.get $acc)))

         (func $string-split:matches?
               (param $arr-str (ref $I32Array))
               (param $arr-sep (ref $I32Array))
               (param $pos     i32)
               (param $len-sep i32)
               (result i32)

               (local $j i32)

               (local.set $j (i32.const 0))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $j) (local.get $len-sep)))
                            (if (i32.ne (call $i32array-ref
                                              (local.get $arr-str)
                                              (i32.add (local.get $pos) (local.get $j)))
                                        (call $i32array-ref (local.get $arr-sep) (local.get $j)))
                                (then (return (i32.const 0))))
                            (local.set $j (i32.add (local.get $j) (i32.const 1)))
                            (br $loop)))

               (i32.const 1))

         (func $string-split:trim-left
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $start    i32)
               (param $end      i32)
               (param $repeat   i32)
               (result i32)

               (local $pos i32)

               (local.set $pos (local.get $start))

               (block $done
                      (loop $loop
                            (br_if $done
                                   (i32.lt_u (i32.sub (local.get $end) (local.get $pos))
                                             (local.get $len-sep)))
                            (if (i32.eqz (call $string-split:matches?
                                               (local.get $arr-str)
                                               (local.get $arr-sep)
                                               (local.get $pos)
                                               (local.get $len-sep)))
                                (then (br $done)))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len-sep)))
                            (if (i32.eqz (local.get $repeat)) (then (br $done)))
                            (br $loop)))

               (local.get $pos))

         (func $string-split:trim-right
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $start    i32)
               (param $end      i32)
               (param $repeat   i32)
               (result i32)

               (local $limit       i32)
               (local $match-start i32)

               (local.set $limit (local.get $end))

               (block $done
                      (loop $loop
                            (br_if $done
                                   (i32.lt_u (i32.sub (local.get $limit) (local.get $start))
                                             (local.get $len-sep)))
                            (local.set $match-start
                                       (i32.sub (local.get $limit) (local.get $len-sep)))
                            (if (i32.eqz (call $string-split:matches?
                                               (local.get $arr-str)
                                               (local.get $arr-sep)
                                               (local.get $match-start)
                                               (local.get $len-sep)))
                                (then (br $done)))
                            (local.set $limit (local.get $match-start))
                            (if (i32.eqz (local.get $repeat)) (then (br $done)))
                            (br $loop)))

               (local.get $limit))

         (func $string-split:find-match
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $pos      i32)
               (param $end      i32)
               (result i32)

               (local $limit i32)
               (local $scan  i32)

               (if (i32.eqz (local.get $len-sep))
                   (then (return (local.get $pos))))
               (if (i32.gt_u (local.get $len-sep) (local.get $end))
                   (then (return (local.get $end))))

               (local.set $limit (i32.sub (local.get $end) (local.get $len-sep)))
               (if (i32.gt_u (local.get $pos) (local.get $limit))
                   (then (return (local.get $end))))

               (local.set $scan (local.get $pos))

               (block $done
                      (loop $loop
                            (br_if $done (i32.gt_u (local.get $scan) (local.get $limit)))
                            (if (call $string-split:matches?
                                      (local.get $arr-str)
                                      (local.get $arr-sep)
                                      (local.get $scan)
                                      (local.get $len-sep))
                                (then (return (local.get $scan))))
                            (local.set $scan (i32.add (local.get $scan) (i32.const 1)))
                            (br $loop)))

               (local.get $end))

         (func $string-split:skip-repeats
               (param $arr-str  (ref $I32Array))
               (param $arr-sep  (ref $I32Array))
               (param $len-sep  i32)
               (param $pos      i32)
               (param $end      i32)
               (result i32)

               (local $scan  i32)
               (local $limit i32)

               (if (i32.eqz (local.get $len-sep))
                   (then (return (local.get $pos))))
               (if (i32.gt_u (local.get $len-sep) (local.get $end))
                   (then (return (local.get $pos))))

               (local.set $limit (i32.sub (local.get $end) (local.get $len-sep)))
               (local.set $scan (local.get $pos))

               (block $done
                      (loop $loop
                            (br_if $done (i32.gt_u (local.get $scan) (local.get $limit)))
                            (if (i32.eqz (call $string-split:matches?
                                               (local.get $arr-str)
                                               (local.get $arr-sep)
                                               (local.get $scan)
                                               (local.get $len-sep)))
                                (then (br $done)))
                            (local.set $scan (i32.add (local.get $scan) (local.get $len-sep)))
                            (br $loop)))

               (local.get $scan))
     )))

;; string-case-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string case-conversion helpers that still depend on monolithic runtime globals.
(define string-case-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-case-runtime-only-helpers
   (append
    (for/list ([name+imp
                (in-list '(($string-upcase    $char-upcase/ucs)
                           ($string-downcase  $char-downcase/ucs)
                           ($string-foldcase  $char-foldcase/ucs)))])
      (define name (car  name+imp))
      (define imp  (cadr name+imp))
      (string-case-helper-form name imp))
    '(
         ;; string-titlecase : string? -> string?
         ;;   Note: Approximates Unicode Case_Ignorable via general categories
         ;;         Mn, Me, Cf, Lm, Sk. No optional parameters.
         (func $string-titlecase (type $Prim1)
               (param $s (ref eq))
               (result   (ref eq))

               (local $t      (ref $String))
               (local $len    i32)
               (local $i      i32)
               (local $in-run i32)
               (local $c      (ref eq))
               (local $cat    (ref eq))

               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-racket-string:string-expected
                               (global.get $symbol:string-titlecase)
                               (local.get $s))))
               ;; --- Make mutable copy and get length ---
               (local.set $t      (ref.cast (ref $String) (call $string-copy (local.get $s))))
               (local.set $len    (call $string-length/checked/i32 (local.get $t)))
               (local.set $i      (i32.const 0))
               (local.set $in-run (i32.const 0))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))

                            (local.set $c (call $string-ref/checked (local.get $t) (local.get $i)))

                            (if (i32.or (ref.eq (call $char-upper-case? (local.get $c)) (global.get $true))
                                        (ref.eq (call $char-lower-case? (local.get $c)) (global.get $true)))
                                (then
                                 (drop ; rememember, string-set! returns `void`
                                  (call $string-set!
                                        (local.get $t)
                                        (ref.i31 (i32.shl (local.get $i) (i32.const 1)))
                                        (if (result (ref eq)) (local.get $in-run)
                                            (then (call $char-downcase (local.get $c)))
                                            (else (call $char-upcase (local.get $c))))))
                                 (local.set $in-run (i32.const 1)))
                                (else
                                 (local.set $cat (call $char-general-category (local.get $c)))
                                 (if (i32.eqz (i32.or (ref.eq       (local.get $cat) (global.get $symbol:mn))
                                                (i32.or (ref.eq     (local.get $cat) (global.get $symbol:me))
                                                  (i32.or (ref.eq   (local.get $cat) (global.get $symbol:cf))
                                                    (i32.or (ref.eq (local.get $cat) (global.get $symbol:lm))
                                                            (ref.eq (local.get $cat) (global.get $symbol:sk)))))))
                                     (then (local.set $in-run (i32.const 0))))))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (local.get $t))))))

;; string-list-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string/list conversion helpers that still depend on monolithic runtime globals.
(define string-list-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-list-conversion-runtime-only-helpers
   `(
         (func $string->list (type $Prim1) (param $s (ref eq)) (result (ref eq))
               (local $str   (ref null $String))
               (local $arr   (ref $I32Array))
               (local $len   i32)
               (local $i     i32)
               (local $res   (ref $Pair))
               (local $cp    i32)
               ;; check string
               (if (ref.test (ref $String) (local.get $s))
                   (then (local.set $str (ref.cast (ref $String) (local.get $s))))
                   (else (call $raise-racket-string:string-expected
                               (global.get $symbol:string->list)
                               (local.get $s))))
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (local.set $len (call $i32array-length (local.get $arr)))
               ;; special case len=0
               (if (result (ref eq))
                   (i32.eqz (local.get $len))
                   (then (return (global.get $null)))
                   ; ;; special case len>=1
                   (else (local.set $i   (i32.sub (local.get $len) (i32.const 1))) ; from end
                         (local.set $cp  (call $i32array-ref (local.get $arr) (local.get $i)))
                         (local.set $res (struct.new $Pair (i32.const 0)
                                                     (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const 8)) (i32.const ,char-tag)))
                                                     (global.get $null)))
                         (local.set $i   (i32.sub (local.get $i) (i32.const 1)))
                         (block $done
                                (loop $build
                                      (br_if $done (i32.lt_s (local.get $i) (i32.const 0)))
                                      (local.set $cp (call $i32array-ref (local.get $arr) (local.get $i)))
                                      ;; tag cp as char
                                      (local.set $res
                                                 (struct.new $Pair (i32.const 0)
                                                             (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const 8)) (i32.const ,char-tag)))
                                                             (local.get $res)))
                                      (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                                      (br $build)))
                         (local.get $res))))

         (func $list->string (type $Prim1) (param $xs (ref eq)) (result (ref eq))
               (local $len   i32)
               (local $str   (ref $String))
               (local $arr   (ref $I32Array))
               (local $i     i32)
               (local $node  (ref eq))
               (local $chimm (ref eq))
               (local $cp    i32)
               ;; 1. Compute list length and validate proper-list shape.
               (local.set $len  (i32.const 0))
               (local.set $node (local.get $xs))
               (block $length-done
                      (loop $length-loop
                            (br_if $length-done
                                   (ref.eq (local.get $node) (global.get $null)))
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                                (then (call $raise-list-expected/who
                                            (global.get $symbol:list->string)
                                            (local.get $xs))))
                            (local.set $len (i32.add (local.get $len) (i32.const 1)))
                            (local.set $node
                                       (struct.get $Pair $d
                                                   (ref.cast (ref $Pair) (local.get $node))))
                            (br $length-loop)))
               ;; 2. Create new mutable string
               (local.set $str
                          (struct.new $String
                                      (i32.const 0)  ;; hash
                                      (i32.const 0)  ;; immutable = false
                                      (call $i32array-make (local.get $len) (i32.const 0))))
               ;; 3. Grab codepoint array once
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               ;; 4. Fill from list directly
               (local.set $i (i32.const 0))
               (local.set $node (local.get $xs))
               (block $done
                      (loop $fill
                            (br_if $done (ref.eq (local.get $node) (global.get $null)))
                            ;; Check node is a pair
                            (if (ref.test (ref $Pair) (local.get $node))
                                (then
                                 ;; extract car
                                 (local.set $chimm (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                                 ;; decode and validate character
                                 (if (i32.eqz (ref.test (ref i31) (local.get $chimm)))
                                     (then (call $raise-argument-error1
                                                 (global.get $symbol:list->string)
                                                 (global.get $string:char?)
                                                 (local.get $chimm))))
                                 (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $chimm))))
                                 (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask)) (i32.const ,char-tag))
                                     (then (call $raise-argument-error1
                                                 (global.get $symbol:list->string)
                                                 (global.get $string:char?)
                                                 (local.get $chimm))))
                                 ;; extract codepoint
                                 (local.set $cp (i32.shr_u (local.get $cp) (i32.const 8)))
                                 ;; write codepoint
                                 (call $i32array-set! (local.get $arr) (local.get $i) (local.get $cp))
                                 ;; advance
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node)))))
                                (else
                                 (call $raise-list-expected/who
                                       (global.get $symbol:list->string)
                                       (local.get $xs))))
                            (br $fill)))
               ;; 5. Return string
               (local.get $str))
     )))

;; string-comparison-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string comparison helpers that still depend on monolithic runtime globals.
(define string-comparison-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-comparison-runtime-only-helpers
   (append
    '(
         (func $string=?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string=?/i32 (local.get $a) (local.get $b))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string=? : string? string? ... -> boolean? (at least 1)
         (func $string=? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string=?)
                               (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected/who
                                     (global.get $symbol:string=?)
                                     (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     (if (i32.eqz (call $string=?/i32/checked (local.get $prev) (local.get $curr)))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string=?/i32
               (param $a-raw (ref eq)) (param $b-raw (ref eq))
               (result i32)

               (local $a (ref $String))
               (local $b (ref $String))
               ;; Check types
               (if (i32.eqz (ref.test (ref $String) (local.get $a-raw)))
                   (then (return (i32.const 0))))
               (if (i32.eqz (ref.test (ref $String) (local.get $b-raw)))
                   (then (return (i32.const 0))))
               ;; Cast and delegate
               (local.set $a (ref.cast (ref $String) (local.get $a-raw)))
               (local.set $b (ref.cast (ref $String) (local.get $b-raw)))
               (return_call $string=?/i32/checked (local.get $a) (local.get $b)))

         (func $string=?/i32/checked
               (param $a (ref $String)) (param $b (ref $String))
               (result i32)

               (return_call $i32array-equal?
                            (struct.get $String $codepoints (local.get $a))
                            (struct.get $String $codepoints (local.get $b))))

         (func $string<?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string</i32 (local.get $a) (local.get $b))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string<? : string? string? ... -> boolean? (at least 1)
         (func $string<? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string<?)
                               (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected/who
                                     (global.get $symbol:string<?)
                                     (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     (if (i32.eqz (call $string</i32/checked (local.get $prev) (local.get $curr)))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string<=?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (i32.or (call $string</i32 (local.get $a) (local.get $b))
                           (call $string=?/i32 (local.get $a) (local.get $b)))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string<=? : string? string? ... -> boolean? (at least 1)
         (func $string<=? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string<=?)
                               (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected/who
                                     (global.get $symbol:string<=?)
                                     (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     ;; Fail if current < previous
                     (if (i32.ne (call $string</i32/checked (local.get $curr) (local.get $prev)) (i32.const 0))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string>?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string</i32 (local.get $b) (local.get $a))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string>? : string? string? ... -> boolean? (at least 1)
         (func $string>? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string>?)
                               (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected/who
                                     (global.get $symbol:string>?)
                                     (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     (if (i32.eqz (call $string</i32/checked (local.get $curr) (local.get $prev)))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string>=?/2
               (param $a (ref eq)) (param $b (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (i32.or (call $string</i32 (local.get $b) (local.get $a))
                           (call $string=?/i32 (local.get $a) (local.get $b)))
                   (then (global.get $true))
                   (else (global.get $false))))

         ;; string>=? : string? string? ... -> boolean? (at least 1)
         (func $string>=? (type $Prim>=1)
               (param $a    (ref eq))   ;; string?
               (param $rest (ref eq))   ;; list of string?
               (result      (ref eq))

               (local $prev     (ref $String))
               (local $curr     (ref $String))
               (local $restlist (ref eq))
               (local $pair     (ref $Pair))
               (local $next     (ref eq))

               ;; Type check first argument
               (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string>=?)
                               (local.get $a))
                         (unreachable)))
               (local.set $prev (ref.cast (ref $String) (local.get $a)))
               (local.set $restlist (local.get $rest))

               ;; Single argument => #t
               (if (ref.eq (local.get $restlist) (global.get $null))
                   (then (return (global.get $true))))

               (loop $loop
                     (if (ref.eq (local.get $restlist) (global.get $null))
                         (then (return (global.get $true))))
                     (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                         (then (call $raise-pair-expected (local.get $restlist))
                               (unreachable)))
                     (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                     (local.set $next (struct.get $Pair $a (local.get $pair)))
                     (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                         (then (call $raise-argument-error:string-expected/who
                                     (global.get $symbol:string>=?)
                                     (local.get $next))
                               (unreachable)))
                     (local.set $curr (ref.cast (ref $String) (local.get $next)))
                     ;; Fail if previous < current
                     (if (i32.ne (call $string</i32/checked (local.get $prev) (local.get $curr)) (i32.const 0))
                         (then (return (global.get $false))))
                     (local.set $prev (local.get $curr))
                     (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                     (br $loop))
               (unreachable))

         (func $string</i32
               (param $a-raw (ref eq)) (param $b-raw (ref eq))
               (result i32)

               (local $a (ref $String))
               (local $b (ref $String))

               ;; Check types
               (if (i32.eqz (ref.test (ref $String) (local.get $a-raw)))
                   (then (return (i32.const 0))))
               (if (i32.eqz (ref.test (ref $String) (local.get $b-raw)))
                   (then (return (i32.const 0))))
               ;; Cast and delegate
               (local.set $a (ref.cast (ref $String) (local.get $a-raw)))
               (local.set $b (ref.cast (ref $String) (local.get $b-raw)))
               (return_call $string</i32/checked (local.get $a) (local.get $b)))

         (func $string</i32/checked
               (param $a (ref $String)) (param $b (ref $String))
               (result i32)

               (local $arr-a (ref $I32Array))
               (local $arr-b (ref $I32Array))
               (local $len-a i32)
               (local $len-b i32)
               (local $i i32)
               (local $cp-a i32)
               (local $cp-b i32)

               (local.set $arr-a (struct.get $String $codepoints (local.get $a)))
               (local.set $arr-b (struct.get $String $codepoints (local.get $b)))
               (local.set $len-a (array.len (local.get $arr-a)))
               (local.set $len-b (array.len (local.get $arr-b)))
               (local.set $i (i32.const 0))

               (block $exit
                      (loop $loop
                            (br_if $exit (i32.ge_u (local.get $i) (local.get $len-a)))
                            (br_if $exit (i32.ge_u (local.get $i) (local.get $len-b)))
                            (local.set $cp-a (array.get $I32Array (local.get $arr-a) (local.get $i)))
                            (local.set $cp-b (array.get $I32Array (local.get $arr-b) (local.get $i)))
                            (if (i32.lt_u (local.get $cp-a) (local.get $cp-b))
                                (then (return (i32.const 1))))
                            (if (i32.gt_u (local.get $cp-a) (local.get $cp-b))
                                (then (return (i32.const 0))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               ;; If one is a prefix of the other
               (return (i32.lt_u (local.get $len-a) (local.get $len-b))))


         (func $string-ci-compare/checked
               (param $a (ref $String)) (param $b (ref $String))
               (result i32)

               (local $arr-a (ref $I32Array))
               (local $arr-b (ref $I32Array))
               (local $len-a i32)
               (local $len-b i32)
               (local $i     i32)
               (local $cp-a  i32)
               (local $cp-b  i32)
               (local $fc-a  i32)
               (local $fc-b  i32)

               (local.set $arr-a (struct.get $String $codepoints (local.get $a)))
               (local.set $arr-b (struct.get $String $codepoints (local.get $b)))
               (local.set $len-a (array.len (local.get $arr-a)))
               (local.set $len-b (array.len (local.get $arr-b)))
               (local.set $i (i32.const 0))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len-a)))
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len-b)))
                            (local.set $cp-a (array.get $I32Array (local.get $arr-a) (local.get $i)))
                            (local.set $cp-b (array.get $I32Array (local.get $arr-b) (local.get $i)))
                            (local.set $fc-a (call $char-foldcase/ucs (local.get $cp-a)))
                            (local.set $fc-b (call $char-foldcase/ucs (local.get $cp-b)))
                            (if (i32.ne (local.get $fc-a) (local.get $fc-b))
                                (then (return (i32.sub (local.get $fc-a) (local.get $fc-b)))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (return (i32.sub (local.get $len-a) (local.get $len-b))))
     )
    (for*/list ([entry (in-list '(($string-ci=?   $symbol:string-ci=?   eq)
                                        ($string-ci<?   $symbol:string-ci<?   lt)
                                        ($string-ci<=?  $symbol:string-ci<=?  le)
                                        ($string-ci>?   $symbol:string-ci>?   gt)
                                        ($string-ci>=?  $symbol:string-ci>=?  ge)))]
                      [form
                       (in-list
                        (let* ([cmp             (car entry)]
                               [who             (cadr entry)]
                               [kind            (caddr entry)]
                               [cmp/2           (string->symbol (~a cmp "/2"))]
                               [cmp/i32         (string->symbol (~a cmp "/i32"))]
                               [cmp/i32/checked (string->symbol (~a cmp "/i32/checked"))]
                               [cond-expr
                                (case kind
                                  [(eq) `(i32.eqz (call $string-ci-compare/checked
                                                       (local.get $a)
                                                       (local.get $b)))]
                                  [(lt) `(i32.lt_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))]
                                  [(le) `(i32.le_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))]
                                  [(gt) `(i32.gt_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))]
                                  [(ge) `(i32.ge_s (call $string-ci-compare/checked
                                                         (local.get $a)
                                                         (local.get $b))
                                                   (i32.const 0))])]
                               [fail-cond
                                (case kind
                                  [(eq) `(i32.ne (local.get $cmp) (i32.const 0))]
                                  [(lt) `(i32.ge_s (local.get $cmp) (i32.const 0))]
                                  [(le) `(i32.gt_s (local.get $cmp) (i32.const 0))]
                                  [(gt) `(i32.le_s (local.get $cmp) (i32.const 0))]
                                  [(ge) `(i32.lt_s (local.get $cmp) (i32.const 0))])])
                          (list
                           `(func ,cmp/2
                                  (param $a (ref eq)) (param $b (ref eq))
                                  (result (ref eq))
                                  (if (result (ref eq))
                                      (call ,cmp/i32 (local.get $a) (local.get $b))
                                      (then (global.get $true))
                                      (else (global.get $false))))
                           `(func ,cmp (type $Prim>=1)
                                  (param $a (ref eq))   ;; string?
                                  (param $rest (ref eq)) ;; list of string?
                                  (result (ref eq))

                                  (local $prev (ref $String))
                                  (local $curr (ref $String))
                                  (local $restlist (ref eq))
                                  (local $pair (ref $Pair))
                                  (local $next (ref eq))
                                  (local $cmp i32)

                                  ;; Type check first argument
                                  (if (i32.eqz (ref.test (ref $String) (local.get $a)))
                                      (then (call $raise-argument-error:string-expected/who
                                                  (global.get ,who)
                                                  (local.get $a))
                                            (unreachable)))
                                  (local.set $prev (ref.cast (ref $String) (local.get $a)))
                                  (local.set $restlist (local.get $rest))

                                  ;; Single argument => #t
                                  (if (ref.eq (local.get $restlist) (global.get $null))
                                      (then (return (global.get $true))))

                                  (loop $loop
                                        (if (ref.eq (local.get $restlist) (global.get $null))
                                            (then (return (global.get $true))))
                                        (if (i32.eqz (ref.test (ref $Pair) (local.get $restlist)))
                                            (then (call $raise-pair-expected (local.get $restlist))
                                                  (unreachable)))
                                        (local.set $pair (ref.cast (ref $Pair) (local.get $restlist)))
                                        (local.set $next (struct.get $Pair $a (local.get $pair)))
                                        (if (i32.eqz (ref.test (ref $String) (local.get $next)))
                                            (then (call $raise-argument-error:string-expected/who
                                                        (global.get ,who)
                                                        (local.get $next))
                                                  (unreachable)))
                                        (local.set $curr (ref.cast (ref $String) (local.get $next)))
                                        (local.set $cmp (call $string-ci-compare/checked (local.get $prev) (local.get $curr)))
                                        (if ,fail-cond
                                            (then (return (global.get $false))))
                                        (local.set $prev (local.get $curr))
                                        (local.set $restlist (struct.get $Pair $d (local.get $pair)))
                                        (br $loop))
                                  (unreachable))
                           `(func ,cmp/i32
                                  (param $a-raw (ref eq)) (param $b-raw (ref eq))
                                  (result i32)

                                  (local $a (ref $String))
                                  (local $b (ref $String))

                                  (if (i32.eqz (ref.test (ref $String) (local.get $a-raw)))
                                      (then (return (i32.const 0))))
                                  (if (i32.eqz (ref.test (ref $String) (local.get $b-raw)))
                                      (then (return (i32.const 0))))
                                  (local.set $a (ref.cast (ref $String) (local.get $a-raw)))
                                  (local.set $b (ref.cast (ref $String) (local.get $b-raw)))
                                  (return_call ,cmp/i32/checked (local.get $a) (local.get $b)))
                           `(func ,cmp/i32/checked
                                  (param $a (ref $String)) (param $b (ref $String))
                                  (result i32)
                                  (return ,cond-expr)))))])
            form))))

;; string-comparison-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string comparison helpers.
(define string-comparison-runtime-only-helper-names
  (map core-runtime-helper-name string-comparison-runtime-only-helpers))

;; string-utf8-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string UTF-8 conversion helpers that still depend on monolithic runtime globals.
(define string-utf8-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-utf8-runtime-only-helpers
   `(
         (func $raise-invalid-utf8-input (param $bad (ref eq)) (result (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string->bytes/utf-8)
                     (global.get $string:string-check:invalid-utf8-input)
                     (local.get $bad))
               (unreachable))

         (func $raise-invalid-utf8-start (param $bad (ref eq)) (result (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string->bytes/utf-8)
                     (global.get $string:string-check:invalid-utf8-start)
                     (local.get $bad))
               (unreachable))

         (func $raise-invalid-utf8-end (param $bad (ref eq)) (result (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string->bytes/utf-8)
                     (global.get $string:string-check:invalid-utf8-end)
                     (local.get $bad))
               (unreachable))

         (func $raise-invalid-utf8-range (param $start (ref eq)) (param $end (ref eq)) (result (ref eq))
               (call $raise-arguments-error
                     (global.get $symbol:string->bytes/utf-8)
                     (global.get $string:string-check:invalid-utf8-range)
                     (array.new_fixed $Args 0))
               (unreachable))

         (func $raise-string-utf8-index-out-of-range
               (param $who         (ref eq))
               (param $reason      (ref eq))
               (param $index-label (ref eq))
               (param $s           (ref $String))
               (param $idx         i32)
               (param $len         i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 9)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (local.get $reason))
               (call $growable-array-add! (local.get $out)
                     (local.get $index-label))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $idx) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-utf8:byte-string))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $s)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $raise-string-utf8-end-before-start
               (param $who   (ref eq))
               (param $s     (ref $String))
               (param $start i32)
               (param $end   i32)
               (param $len   i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 11)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:substring:ending-index-before-start))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:substring:ending-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $end) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:substring:starting-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $start) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-utf8:byte-string))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $s)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $raise-string-utf8-range-error
               (param $who   (ref eq))
               (param $s     (ref $String))
               (param $start i32)
               (param $end   i32)
               (param $len   i32)

               (if (i32.gt_u (local.get $start) (local.get $len))
                   (then (call $raise-string-utf8-index-out-of-range
                               (local.get $who)
                               (global.get $string:substring:starting-index-out-of-range)
                               (global.get $string:substring:starting-index)
                               (local.get $s)
                               (local.get $start)
                               (local.get $len))
                         (unreachable)))
               (if (i32.gt_u (local.get $end) (local.get $len))
                   (then (call $raise-string-utf8-index-out-of-range
                               (local.get $who)
                               (global.get $string:substring:ending-index-out-of-range)
                               (global.get $string:substring:ending-index)
                               (local.get $s)
                               (local.get $end)
                               (local.get $len))
                         (unreachable)))
               (call $raise-string-utf8-end-before-start
                     (local.get $who)
                     (local.get $s)
                     (local.get $start)
                     (local.get $end)
                     (local.get $len))
               (unreachable))

         (func $raise-string->bytes/utf8
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string->bytes/utf-8)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $bad))
               (unreachable))

         (func $raise-string->bytes/utf8:expected-string
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string->bytes/utf-8)
                     (global.get $string:string?)
                     (local.get $bad))
               (unreachable))

         (func $raise-string->bytes/utf8:range-error
               (param $s     (ref $String))
               (param $start i32)
               (param $end   i32)
               (param $len   i32)
               (call $raise-string-utf8-range-error
                     (global.get $symbol:string->bytes/utf-8)
                     (local.get $s)
                     (local.get $start)
                     (local.get $end)
                     (local.get $len))
               (unreachable))

         (func $string->bytes/utf-8 (export "string->bytes/utf-8")
               (param $str       (ref eq))
               (param $err-byte  (ref eq)) ;; Ignored
               (param $start-raw (ref eq))
               (param $end-raw   (ref eq))
               (result (ref eq))

               (local $s         (ref null $String))
               (local $cp        (ref $I32Array))
               (local $start     i32)
               (local $end       i32)
               (local $len       i32)
               (local $out-bytes (ref $I8Array))
               (local $idx       i32)
               (local $i         i32)
               (local $char      i32)
               (local $bs        (ref $Bytes))

               ;; Check and cast $str
               (if (ref.test (ref $String) (local.get $str))
                   (then (local.set $s (ref.cast (ref $String) (local.get $str))))
                   (else (call $raise-string->bytes/utf8:expected-string
                               (local.get $str)))) ;; code 1 = not a string
               ;; Get codepoints array and length
               (local.set $cp  (struct.get $String $codepoints (local.get $s)))
               (local.set $len (array.len (local.get $cp)))
               ;; Decode start
               (if (ref.eq (local.get $start-raw) (global.get $false))
                   (then (local.set $start (i32.const 0)))
                   (else
                    (local.set $start
                               (call $string-index/i32/who
                                     (global.get $symbol:string->bytes/utf-8)
                                     (local.get $start-raw)))))
               ;; Decode end
               (if (ref.eq (local.get $end-raw) (global.get $false))
                   (then (local.set $end (local.get $len)))
                   (else
                    (local.set $end
                               (call $string-index/i32/who
                                     (global.get $symbol:string->bytes/utf-8)
                                     (local.get $end-raw)))))
               ;; Bounds check
               (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                           (i32.gt_u (local.get $end) (local.get $len)))
                   (then (call $raise-string->bytes/utf8:range-error
                               (ref.cast (ref $String) (local.get $s))
                               (local.get $start)
                               (local.get $end)
                               (local.get $len))))
               ;; First pass: compute output size
               (local.set $i   (local.get $start))
               (local.set $idx (i32.const 0))
               (loop $size-loop
                     (if (i32.lt_u (local.get $i) (local.get $end))
                         (then
                          (local.set $char (array.get $I32Array (local.get $cp) (local.get $i)))
                          (local.set $idx (i32.add (local.get $idx) (call $utf8-size (local.get $char))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $size-loop))))
               ;; Allocate byte array
               (local.set $out-bytes (array.new_default $I8Array (local.get $idx)))
               (local.set $bs
                          (struct.new $Bytes
                                      (i32.const 0) ;; hash
                                      (i32.const 1) ;; immutable
                                      (local.get $out-bytes)))
               ;; Second pass: encode into buffer
               (local.set $i   (local.get $start))
               (local.set $idx (i32.const 0))
               (loop $encode-loop
                     (if (i32.lt_u (local.get $i) (local.get $end))
                         (then
                          (local.set $char (array.get $I32Array (local.get $cp) (local.get $i)))
                          (local.set $idx  (call $write-utf8 (local.get $bs) (local.get $idx) (local.get $char)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $encode-loop))))
               (local.get $bs))

         (func $string->bytes/locale (type $Prim14)
               ;; string->bytes/locale : string? [err-byte] [start] [end] -> bytes?
               ;; WebRacket has no host locale layer yet, so locale encoding is
               ;; currently UTF-8. The optional err-byte is accepted like
               ;; string->bytes/utf-8 but not needed for Unicode-to-UTF-8.
               (param $str       (ref eq)) ;; string?
               (param $err-byte  (ref eq)) ;; optional #f-or-byte?, default = #f
               (param $start-raw (ref eq)) ;; optional exact-nonnegative-integer?, default = 0
               (param $end-raw   (ref eq)) ;; optional exact-nonnegative-integer?, default = string length
               (result           (ref eq))
               (call $string->bytes/utf-8
                     (local.get $str)
                     (local.get $err-byte)
                     (local.get $start-raw)
                     (local.get $end-raw)))

         (func $raise-string-utf-8-length:bad-argument
               (param $expected (ref eq))
               (param $bad      (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-utf-8-length)
                     (local.get $expected)
                     (local.get $bad))
               (unreachable))

         (func $raise-string-utf-8-length:range-error
               (param $s     (ref $String))
               (param $start i32)
               (param $end   i32)
               (param $len   i32)
               (call $raise-string-utf8-range-error
                     (global.get $symbol:string-utf-8-length)
                     (local.get $s)
                     (local.get $start)
                     (local.get $end)
                     (local.get $len))
               (unreachable))

         (func $string-utf-8-length (type $Prim13)
               (param $str       (ref eq))
               (param $start-raw (ref eq))   ;; optional exact nonnegative integer, default = 0
               (param $end-raw   (ref eq))   ;; optional exact nonnegative integer, default = string length
               (result (ref eq))

               (local $s     (ref null $String))
               (local $cp    (ref $I32Array))
               (local $len   i32)
               (local $start i32)
               (local $end   i32)
               (local $i     i32)
               (local $char  i32)
               (local $total i32)

               ;; --- Type check for string ---
               (if (ref.test (ref $String) (local.get $str))
                   (then (local.set $s (ref.cast (ref $String) (local.get $str))))
                   (else (call $raise-string-utf-8-length:bad-argument
                               (global.get $string:string?)
                               (local.get $str))))
               ;; --- Extract codepoints and length ---
               (local.set $cp  (struct.get $String $codepoints (local.get $s)))
               (local.set $len (array.len (local.get $cp)))
               ;; --- Decode start ---
               (if (ref.eq (local.get $start-raw) (global.get $missing))
                   (then (local.set $start (i32.const 0)))
                   (else
                    (local.set $start
                               (call $string-index/i32/who
                                     (global.get $symbol:string-utf-8-length)
                                     (local.get $start-raw)))))
               ;; --- Decode end ---
               (if (ref.eq (local.get $end-raw) (global.get $missing))
                   (then (local.set $end (local.get $len)))
                   (else
                    (local.set $end
                               (call $string-index/i32/who
                                     (global.get $symbol:string-utf-8-length)
                                     (local.get $end-raw)))))
               ;; --- Range check ---
               (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                           (i32.gt_u (local.get $end) (local.get $len)))
                   (then (call $raise-string-utf-8-length:range-error
                               (ref.cast (ref $String) (local.get $s))
                               (local.get $start)
                               (local.get $end)
                               (local.get $len))))
               ;; --- Compute UTF-8 length ---
               (local.set $i     (local.get $start))
               (local.set $total (i32.const 0))
               (loop $len-loop
                     (if (i32.lt_u (local.get $i) (local.get $end))
                         (then
                          (local.set $char (array.get $I32Array (local.get $cp) (local.get $i)))
                          (local.set $total (i32.add (local.get $total) (call $utf8-size (local.get $char))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $len-loop))))
               (ref.i31 (i32.shl (local.get $total) (i32.const 1))))
     )))

;; string-utf8-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string UTF-8 conversion helpers.
(define string-utf8-runtime-only-helper-names
  (map core-runtime-helper-name string-utf8-runtime-only-helpers))

;; string-copy!-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string-copy! helpers that still depend on monolithic runtime globals.
(define string-copy!-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-copy!-runtime-only-helpers
   '(
         (func $raise-string-copy!:bad-destination
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-copy!)
                     (global.get $string:string-copy!:destination-contract)
                     (local.get $bad)))
         (func $raise-string-copy!:bad-destination-start
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-copy!)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $bad)))
         (func $raise-string-copy!:bad-source
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-copy!)
                     (global.get $string:string?)
                     (local.get $bad)))
         (func $raise-string-copy!:bad-source-start
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-copy!)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $bad)))
         (func $raise-string-copy!:bad-source-end
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-copy!)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $bad)))
         (func $raise-string-copy!:bad-source-range
               (param $src   (ref $String))
               (param $start i32)
               (param $end   i32)
               (param $len   i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out (call $make-growable-array (i32.const 12)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (global.get $symbol:string-copy!)))
               (if (i32.gt_u (local.get $start) (local.get $len))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:substring:starting-index-out-of-range))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:substring:starting-index))
                    (call $growable-array-add! (local.get $out)
                          (call $format/display
                                (ref.i31 (i32.shl (local.get $start) (i32.const 1))))))
                   (else
                    (if (i32.gt_u (local.get $start) (local.get $end))
                        (then
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:substring:ending-index-before-start))
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:substring:ending-index))
                         (call $growable-array-add! (local.get $out)
                               (call $format/display
                                     (ref.i31 (i32.shl (local.get $end) (i32.const 1)))))
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:substring:starting-index))
                         (call $growable-array-add! (local.get $out)
                               (call $format/display
                                     (ref.i31 (i32.shl (local.get $start) (i32.const 1))))))
                        (else
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:substring:ending-index-out-of-range))
                         (call $growable-array-add! (local.get $out)
                               (global.get $string:substring:ending-index))
                         (call $growable-array-add! (local.get $out)
                               (call $format/display
                                     (ref.i31 (i32.shl (local.get $end) (i32.const 1)))))))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:valid-range-close))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:string-ref:string))
               (call $growable-array-add! (local.get $out)
                     (call $format/write (local.get $src)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))
         (func $raise-string-copy!:bad-destination-range
               (param $dst    (ref $String))
               (param $start  i32)
               (param $needed i32)
               (param $len    i32)

               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out (call $make-growable-array (i32.const 10)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (global.get $symbol:string-copy!)))
               (if (i32.gt_u (local.get $start) (local.get $len))
                   (then
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:substring:starting-index-out-of-range))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:substring:starting-index))
                    (call $growable-array-add! (local.get $out)
                          (call $format/display
                                (ref.i31 (i32.shl (local.get $start) (i32.const 1)))))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:valid-range))
                    (call $growable-array-add! (local.get $out)
                          (call $format/display
                                (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:valid-range-close))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-ref:string))
                    (call $growable-array-add! (local.get $out)
                          (call $format/write (local.get $dst))))
                   (else
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-copy!:not-enough-room))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-copy!:target-length))
                    (call $growable-array-add! (local.get $out)
                          (call $format/display
                                (ref.i31 (i32.shl (local.get $len) (i32.const 1)))))
                    (call $growable-array-add! (local.get $out)
                          (global.get $string:string-copy!:needed-length))
                    (call $growable-array-add! (local.get $out)
                          (call $format/display
                                (ref.i31 (i32.shl (local.get $needed) (i32.const 1)))))))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))

         (func $string-copy! (type $Prim35)
               (param $dst-raw       (ref eq))
               (param $dst-start-raw (ref eq))
               (param $src-raw       (ref eq))
               (param $src-start-raw (ref eq))   ;; optional exact nonnegative integer, default = 0
               (param $src-end-raw   (ref eq))   ;; optional exact nonnegative integer, default = source length
               (result (ref eq))

               (local $dst        (ref $String))
               (local $src        (ref $String))
               (local $dst-start  i32)
               (local $src-start  i32)
               (local $src-end    i32)
               (local $src-len    i32)
               (local $dst-len    i32)
               (local $needed     i32)
               ;; --- Type + index checks ---
               (if (i32.eqz (ref.test (ref $String) (local.get $dst-raw)))
                   (then (call $raise-string-copy!:bad-destination (local.get $dst-raw))
                         (unreachable)))
               (local.set $dst (ref.cast (ref $String) (local.get $dst-raw)))
               (local.set $dst-start
                          (call $string-index/i32/who
                                (global.get $symbol:string-copy!)
                                (local.get $dst-start-raw)))

               (if (i32.eqz (ref.test (ref $String) (local.get $src-raw)))
                   (then (call $raise-string-copy!:bad-source (local.get $src-raw))
                         (unreachable)))
               (local.set $src     (ref.cast (ref $String) (local.get $src-raw)))
               (local.set $src-len (call $string-length/checked/i32 (local.get $src)))
               ;; src-start optional
               (if (ref.eq (local.get $src-start-raw) (global.get $missing))
                   (then (local.set $src-start (i32.const 0)))
                   (else
                    (local.set $src-start
                               (call $string-index/i32/who
                                     (global.get $symbol:string-copy!)
                                     (local.get $src-start-raw)))))
               ;; src-end optional
               (if (ref.eq (local.get $src-end-raw) (global.get $missing))
                   (then (local.set $src-end (local.get $src-len)))
                   (else
                    (local.set $src-end
                               (call $string-index/i32/who
                                     (global.get $symbol:string-copy!)
                                     (local.get $src-end-raw)))))
               ;; --- Mutability Check ---
               (if (i32.ne (struct.get $String $immutable (local.get $dst)) (i32.const 0))
                   (then (call $raise-immutable-string (local.get $dst))
                         (unreachable)))
               ;; --- Range Validation ---
               (local.set $dst-len (call $string-length/checked/i32 (local.get $dst)))
               (if (i32.or
                    (i32.gt_u (local.get $src-start) (local.get $src-end))
                    (i32.or
                     (i32.gt_u (local.get $src-start) (local.get $src-len))
                     (i32.gt_u (local.get $src-end) (local.get $src-len))))
                   (then (call $raise-string-copy!:bad-source-range
                               (local.get $src)
                               (local.get $src-start)
                               (local.get $src-end)
                               (local.get $src-len))
                         (unreachable)))
               (local.set $needed
                          (i32.add (local.get $dst-start)
                                   (i32.sub (local.get $src-end) (local.get $src-start))))
               (if (i32.gt_u (local.get $needed) (i32.const 536870911))
                   (then (local.set $needed (i32.const 536870911))))
               (if (i32.gt_u (local.get $needed) (local.get $dst-len))
                   (then (call $raise-string-copy!:bad-destination-range
                               (local.get $dst)
                               (local.get $dst-start)
                               (local.get $needed)
                               (local.get $dst-len))
                         (unreachable)))
               ;; --- Delegate ---
               (call $string-copy!/checked
                     (local.get $dst)
                     (local.get $dst-start)
                     (local.get $src)
                     (local.get $src-start)
                     (local.get $src-end))
               ;; --- Invalidate hash ---
               (struct.set $String $hash (local.get $dst) (i32.const 0))
               ;; --- Return ---
               (global.get $void))


         (func $raise-string-copy!/checked:out-of-bounds
               (call $raise-arguments-error
                     (global.get $symbol:string-copy!)
                     (global.get $string:string-check:string-copy!/checked)
                     (array.new_fixed $Args 0))
               (unreachable))

         (func $string-copy!/checked
               (param $dst        (ref $String)) ;; Destination string
               (param $dst-start  i32)           ;; Start index in destination
               (param $src        (ref $String)) ;; Source string
               (param $src-start  i32)           ;; Start index in source
               (param $src-end    i32)           ;; End index in source (exclusive)

               (local $dst-len i32)
               (local $src-len i32)
               (local $len     i32)

               ;; --- Compute source slice length ---
               (local.set $len (i32.sub (local.get $src-end) (local.get $src-start)))
               ;; --- Range Checks ---
               (if (i32.lt_u (local.get $src-end) (local.get $src-start))
                   (then (call $raise-string-copy!/checked:out-of-bounds)))
               (local.set $dst-len (call $string-length/checked/i32 (local.get $dst)))
               (local.set $src-len (call $string-length/checked/i32 (local.get $src)))
               (if (i32.gt_u (i32.add (local.get $dst-start) (local.get $len)) (local.get $dst-len))
                   (then (call $raise-string-copy!/checked:out-of-bounds)))
               (if (i32.gt_u (local.get $src-end) (local.get $src-len))
                   (then (call $raise-string-copy!/checked:out-of-bounds)))
               ;; --- Copy elements ---
               (call $i32array-copy!
                     (struct.get $String $codepoints (local.get $dst))
                     (local.get $dst-start)
                     (struct.get $String $codepoints (local.get $src))
                     (local.get $src-start)
                     (local.get $src-end))
               ;; --- Invalidate destination hash ---
               (struct.set $String $hash (local.get $dst) (i32.const 0)))
     )))

;; string-array-conversion-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate array-of-strings conversion helpers that still depend on monolithic runtime globals.
(define string-array-conversion-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-array-conversion-runtime-only-helpers
   '(
         (func $array-of-strings->string
               (param $arr (ref $Array))
               (result (ref $String))

               (local $n     i32)
               (local $i     i32)
               (local $total i32)
               (local $s     (ref $String))
               (local $len   i32)
               (local $dst   (ref $String))
               (local $pos   i32)

               ;; Pass 1: compute total length
               (local.set $n     (array.len (local.get $arr)))
               (local.set $i     (i32.const 0))
               (local.set $total (i32.const 0))

               (block $count-done
                      (loop $count-loop
                            (br_if $count-done (i32.ge_u (local.get $i) (local.get $n)))
                            (local.set $s     (ref.cast (ref $String) (array.get $Array (local.get $arr) (local.get $i))))
                            (local.set $len   (call $string-length/checked/i32 (local.get $s)))
                            (local.set $total (i32.add (local.get $total) (local.get $len)))
                            (local.set $i     (i32.add (local.get $i) (i32.const 1)))
                            (br $count-loop)))
               ;; Allocate destination string directly. The inputs are already
               ;; known strings, and the copy ranges below are derived from
               ;; their lengths, so the public checked helpers are unnecessary.
               (local.set $dst
                          (struct.new $String
                                      (i32.const 0)
                                      (i32.const 0)
                                      (array.new $I32Array
                                                 (i32.const 0)
                                                 (local.get $total))))
               ;; Pass 2: copy individual strings into destination
               (local.set $i   (i32.const 0))
               (local.set $pos (i32.const 0))
               (block $copy-done
                      (loop $copy-loop
                            (br_if $copy-done (i32.ge_u (local.get $i) (local.get $n)))
                            (local.set $s   (ref.cast (ref $String) (array.get $Array (local.get $arr) (local.get $i))))
                            (local.set $len (call $string-length/checked/i32 (local.get $s)))
                            (call $i32array-copy!
                                  (struct.get $String $codepoints (local.get $dst))
                                  (local.get $pos)
                                  (struct.get $String $codepoints (local.get $s))
                                  (i32.const 0)
                                  (local.get $len))
                            (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                            (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                            (br $copy-loop)))
               (local.get $dst))

         (func $growable-array-of-strings->string
               (param $g (ref $GrowableArray))
               (result (ref $String))
               ;; Convert growable array to normal array and concatenate its strings
               (call $array-of-strings->string
                     (call $growable-array->array (local.get $g))))
     )))

;; string-take-drop-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string take/drop helpers that still depend on monolithic runtime globals.
(define string-take-drop-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-take-drop-runtime-only-helpers
   '(
         (func $string-take (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq))  ; an (ref $String)

               (local $str   (ref $String))
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string-take)
                               (local.get $s))
                         (unreachable)))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/i32
                          (call $string-index/i32/who
                                (global.get $symbol:string-take)
                                (local.get $n)))

               (local.set $len
                          (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-string-index-out-of-range/who/i32
                               (global.get $symbol:string-take)
                               (local.get $s)
                               (local.get $n/i32)
                               (local.get $len))
                         (unreachable)))

               (call $string-take/checked (local.get $str) (local.get $n/i32)))

         (func $string-take/checked
               (param $s (ref $String)) (param $n i32)
               (result (ref $String))
               (call $i32array->string
                     (call $i32array-take
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))



         (func $string-take-right (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq))  ; an (ref $String)

               (local $str   (ref $String))
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string-take-right)
                               (local.get $s))
                         (unreachable)))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/i32
                          (call $string-index/i32/who
                                (global.get $symbol:string-take-right)
                                (local.get $n)))

               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-string-index-out-of-range/who/i32
                               (global.get $symbol:string-take-right)
                               (local.get $s)
                               (local.get $n/i32)
                               (local.get $len))
                         (unreachable)))

               (call $string-take-right/checked (local.get $str) (local.get $n/i32)))

         (func $string-take-right/checked
               (param $s (ref $String))
               (param $n i32)
               (result   (ref $String))

               (call $i32array->string
                     (call $i32array-take-right
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))

         (func $string-drop (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq))  ; an (ref $String)

               (local $str   (ref $String))
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string-drop)
                               (local.get $s))
                         (unreachable)))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/i32
                          (call $string-index/i32/who
                                (global.get $symbol:string-drop)
                                (local.get $n)))

               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-string-index-out-of-range/who/i32
                               (global.get $symbol:string-drop)
                               (local.get $s)
                               (local.get $n/i32)
                               (local.get $len))
                         (unreachable)))

               (call $string-drop/checked (local.get $str) (local.get $n/i32)))

         (func $string-drop/checked
               (param $s (ref $String)) (param $n i32)
               (result (ref $String))
               (call $i32array->string
                     (call $i32array-drop
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))

         (func $string-drop-right (type $Prim2)
               (param $s (ref eq))
               (param $n (ref eq))
               (result   (ref eq)) ; an (ref $String)

               (local $str   (ref $String))
               (local $n/i32 i32)
               (local $len   i32)

               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string-drop-right)
                               (local.get $s))
                         (unreachable)))

               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $n/i32
                          (call $string-index/i32/who
                                (global.get $symbol:string-drop-right)
                                (local.get $n)))

               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (if (i32.gt_u (local.get $n/i32) (local.get $len))
                   (then (call $raise-string-index-out-of-range/who/i32
                               (global.get $symbol:string-drop-right)
                               (local.get $s)
                               (local.get $n/i32)
                               (local.get $len))
                         (unreachable)))

               (call $string-drop-right/checked (local.get $str) (local.get $n/i32)))

         (func $string-drop-right/checked
               (param $s (ref $String)) (param $n i32)
               (result (ref $String))
               (call $i32array->string
                     (call $i32array-drop-right
                           (struct.get $String $codepoints (local.get $s))
                           (local.get $n))))
     )))

;; string-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string-section error stubs that still depend on monolithic runtime globals.
(define string-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-error-runtime-only-helpers
   '(
         (func $raise-argument-error:string-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:string?)
                     (local.get $x))
               (unreachable))
         (func $raise-argument-error:string-expected
               (param $x (ref eq))
               (call $raise-argument-error:string-expected/who
                     (global.get $symbol:string-trim)
                     (local.get $x))
               (unreachable))

         (func $bomb
               (call $raise-arguments-error
                     (global.get $symbol:string)
                     (global.get $string:string-check:internal-invariant)
                     (array.new_fixed $Args 0))
               (unreachable))
     )))

;; string-trim-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string trim helpers that still depend on monolithic runtime globals.
(define string-trim-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-trim-runtime-only-helpers
   `(
         (func $raise-string-trim:string-expected
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-trim)
                     (global.get $string:string?)
                     (local.get $bad))
               (unreachable))

         (func $raise-string-trim:separator-expected
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:string-trim)
                     (global.get $string:string-trim:separator-contract)
                     (local.get $bad))
               (unreachable))

         (func $string-trim-right (type $Prim2)
               (param $s       (ref eq))   ;; any value, must be a string
               (param $sep     (ref eq))   ;; a character (tagged i31) or #f
               (result         (ref eq))   ;; an (ref $String)

               (local $str     (ref $String))
               (local $len     i32)
               (local $new-len i32)
               (local $sep/tag i32) ;; still-tagged char
               (local $sep-ch  i32) ;; decoded code point
               (local $use-whitespace? i32)
               (local $ch      i32)

               ;; --- Type check inputs ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string-trim-right)
                               (local.get $s))
                         (unreachable)))

               (if (ref.eq (local.get $sep) (global.get $false))
                   (then (local.set $use-whitespace? (i32.const 1)))
                   (else
                    (if (i32.eqz (ref.test (ref i31) (local.get $sep)))
                        (then (call $raise-argument-error:char-expected/who
                                    (global.get $symbol:string-trim-right)
                                    (local.get $sep))
                              (unreachable)))
                    (local.set $sep/tag (i31.get_u (ref.cast (ref i31) (local.get $sep))))
                    (if (i32.ne (i32.and (local.get $sep/tag) (i32.const ,char-mask))
                                (i32.const ,char-tag))
                        (then (call $raise-argument-error:char-expected/who
                                    (global.get $symbol:string-trim-right)
                                    (local.get $sep))
                              (unreachable)))
                    (local.set $use-whitespace? (i32.const 0))))

               ;; --- Decode after checks ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (if (i32.eq (local.get $use-whitespace?) (i32.const 0))
                   (then (local.set $sep-ch (i32.shr_u (local.get $sep/tag) (i32.const ,char-shift)))))

               ;; --- Get length ---
               (local.set $len     (call $string-length/checked/i32 (local.get $str)))
               (local.set $new-len (local.get $len))

               ;; --- Scan backward ---
               (block $done
                      (loop $scan
                            (br_if $done (i32.eqz (local.get $new-len)))
                            (local.set $ch
                                       (call $string-ref/checked/i32
                                             (local.get $str)
                                             (i32.sub (local.get $new-len) (i32.const 1))))

                            (if (i32.eq (local.get $use-whitespace?) (i32.const 1))
                                ;; --- Trim if whitespace ---
                                (then
                                 (if (ref.eq (call $char-whitespace?/ucs (local.get $ch))
                                             (global.get $true))
                                     (then
                                      (local.set $new-len (i32.sub (local.get $new-len) (i32.const 1)))
                                      (br $scan))))
                                ;; --- Else trim if equals sep-ch ---
                                (else
                                 (if (i32.eq (local.get $ch) (local.get $sep-ch))
                                     (then
                                      (local.set $new-len (i32.sub (local.get $new-len) (i32.const 1)))
                                      (br $scan))))))
                      )

               ;; --- Return result ---
               (if (i32.eq (local.get $new-len) (local.get $len))
                   (then (return (local.get $str)))
                   (else (return (call $string-take/checked (local.get $str) (local.get $new-len)))))

               (unreachable))

         (func $string-trim-left (type $Prim2)
               (param $s   (ref eq))   ;; any value, must be a string
               (param $sep (ref eq))   ;; a character (i31) or #f
               (result     (ref eq))   ;; an (ref $String)

               (local $str     (ref $String))
               (local $len     i32)
               (local $i       i32)
               (local $sep-ch  i32)
               (local $use-whitespace? i32) ;; boolean flag
               (local $sep/tag i32)
               (local $ch      i32)

               ;; --- Check inputs ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-argument-error:string-expected/who
                               (global.get $symbol:string-trim-left)
                               (local.get $s))
                         (unreachable)))

               (if (ref.eq (local.get $sep) (global.get $false))
                   (then (local.set $use-whitespace? (i32.const 1)))
                   (else
                    ;; Check: is it a (ref i31)?
                    (if (i32.eqz (ref.test (ref i31) (local.get $sep)))
                        (then (call $raise-argument-error:char-expected/who
                                    (global.get $symbol:string-trim-left)
                                    (local.get $sep))
                              (unreachable)))
                    ;; Extract raw tagged value
                    (local.set $sep/tag
                               (i31.get_u (ref.cast (ref i31) (local.get $sep))))
                    ;; Check tag matches ,char-tag
                    (if (i32.ne (i32.and (local.get $sep/tag) (i32.const ,char-mask))
                                (i32.const ,char-tag))
                        (then (call $raise-argument-error:char-expected/who
                                    (global.get $symbol:string-trim-left)
                                    (local.get $sep))
                              (unreachable)))
                    ;; Passed: decode
                    (local.set $use-whitespace? (i32.const 0))
                    (local.set $sep-ch (i32.shr_u (local.get $sep/tag)
                                                  (i32.const ,char-shift)))))
               ;; --- Decode after checks ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; --- Get string length (as i32) ---
               (local.set $len (call $string-length/checked/i32 (local.get $str)))
               (local.set $i   (i32.const 0))
               ;; --- Scan forward ---
               (block $done
                      (loop $scan
                            (br_if $done (i32.eq (local.get $i) (local.get $len)))

                            (local.set $ch (call $string-ref/checked/i32
                                                 (local.get $str)
                                                 (local.get $i)))

                            (if (i32.eq (local.get $use-whitespace?) (i32.const 1))
                                ;; --- Trim if character is whitespace ---
                                (then (if (ref.eq (call $char-whitespace?/ucs (local.get $ch))
                                                  (global.get $true))
                                          (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                                (br $scan))))
                                ;; --- Else trim if char equals $sep-ch ---
                                (else (if (i32.eq (local.get $ch) (local.get $sep-ch))
                                          (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                                (br $scan)))))))

               ;; --- Return result ---
               (if (i32.eqz (local.get $i))
                   (then (return (local.get $str)))
                   (else (return (call $string-drop
                                       (local.get $str)
                                       (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))))
               (unreachable))


         (func $string-trim (type $Prim15)
               (param $s       (ref eq))   ;; string?
               (param $sep     (ref eq))   ;; optional string?, default = " "
               (param $left?   (ref eq))   ;; optional any/c, default = #t
               (param $right?  (ref eq))   ;; optional any/c, default = #t
               (param $repeat? (ref eq))   ;; optional any/c, default = #f
               (result         (ref eq))

               (local $str             (ref $String))
               (local $sep-str         (ref $String))
               (local $result          (ref $String))
               (local $use-whitespace? i32)
               (local $trim-left?      i32)
               (local $trim-right?     i32)
               (local $repeat-flag     i32)
               (local $sep-len         i32)

               ;; NOTE: WebRacket does not yet support keyword arguments or regular-expression separators here.

               ;; --- Initilize non-defaultable ---
               (local.set $str     (ref.cast (ref $String) (global.get $string:empty)))
               (local.set $sep-str (ref.cast (ref $String) (global.get $string:empty)))
               ; (local.set $str (ref.cast (ref $String) (global.get $string:empty)))

               ;; --- Check and decode required string argument ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-string-trim:string-expected (local.get $s))))
               (local.set $str    (ref.cast (ref $String) (local.get $s)))
               (local.set $result (local.get $str))
               ;; --- Handle optional separator (defaults to whitespace trimming) ---
               (if (ref.eq (local.get $sep) (global.get $missing))
                   (then (local.set $use-whitespace? (i32.const 1)))
                   (else (if (i32.eqz (ref.test (ref $String) (local.get $sep)))
                             (then (call $raise-string-trim:separator-expected (local.get $sep))))
                         (local.set $sep-str (ref.cast (ref $String) (local.get $sep)))
                         (local.set $use-whitespace? (i32.const 0))))
               ;; --- Decode left? flag (default #t) ---
               (if (ref.eq (local.get $left?) (global.get $missing))
                   (then (local.set $trim-left? (i32.const 1)))
                   (else (local.set $trim-left?
                                    (if (result i32)
                                        (ref.eq (local.get $left?) (global.get $false))
                                        (then (i32.const 0))
                                        (else (i32.const 1))))))
               ;; --- Decode right? flag (default #t) ---
               (if (ref.eq (local.get $right?) (global.get $missing))
                   (then (local.set $trim-right? (i32.const 1)))
                   (else (local.set $trim-right?
                                    (if (result i32)
                                        (ref.eq (local.get $right?) (global.get $false))
                                        (then (i32.const 0))
                                        (else (i32.const 1))))))
               ;; --- Decode repeat? flag (default #f) ---
               (if (ref.eq (local.get $repeat?) (global.get $missing))
                   (then (local.set $repeat-flag (i32.const 0)))
                   (else (local.set $repeat-flag
                                    (if (result i32)
                                        (ref.eq (local.get $repeat?) (global.get $false))
                                        (then (i32.const 0))
                                        (else (i32.const 1))))))
               ;; --- Whitespace trimming delegates to existing helpers ---
               (if (i32.eq (local.get $use-whitespace?) (i32.const 1))
                   (then
                    (if (local.get $trim-left?)
                        (then (local.set $result
                                         (ref.cast (ref $String)
                                                   (call $string-trim-left
                                                         (local.get $result)
                                                         (global.get $false))))))
                    (if (local.get $trim-right?)
                        (then (local.set $result
                                         (ref.cast (ref $String)
                                                   (call $string-trim-right
                                                         (local.get $result)
                                                         (global.get $false))))))
                    (return (local.get $result))))
               ;; --- Literal separator trimming ---
               (local.set $sep-len (call $string-length/checked/i32 (local.get $sep-str)))
               (if (i32.eqz (local.get $sep-len))
                   (then (return (local.get $result))))
               ;; Trim left side if requested
               (if (local.get $trim-left?)
                   (then
                    (block $left-done
                           (loop $left-loop
                                 (br_if $left-done
                                        (i32.eqz (call $string-prefix?/i32/checked
                                                       (local.get $result)
                                                       (local.get $sep-str))))
                                 (local.set $result
                                            (call $string-drop/checked
                                                  (local.get $result)
                                                  (local.get $sep-len)))
                                 (if (i32.eqz (local.get $repeat-flag))
                                     (then (br $left-done)))
                                 (br $left-loop)))))
               ;; Trim right side if requested
               (if (local.get $trim-right?)
                   (then
                    (block $right-done
                           (loop $right-loop
                                 (br_if $right-done
                                        (i32.eqz (call $string-suffix?/i32/checked
                                                       (local.get $result)
                                                       (local.get $sep-str))))
                                 (local.set $result
                                            (call $string-drop-right/checked
                                                  (local.get $result)
                                                  (local.get $sep-len)))
                                 (if (i32.eqz (local.get $repeat-flag))
                                     (then (br $right-done)))
                                 (br $right-loop)))))

               (local.get $result))
     )))

;; string-additional-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate additional racket/string helpers that still depend on monolithic runtime globals.
(define string-additional-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-additional-runtime-only-helpers
   '(
         (func $raise-racket-string:string-expected
               (param $who (ref eq))
               (param $x   (ref eq))

               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:string?)
                     (local.get $x)))

         (func $string-suffix? (type $Prim2)
               (param $s (ref eq)) (param $suffix (ref eq))
               (result (ref eq))
               (if (result (ref eq))
                   (call $string-suffix?/i32 (local.get $s) (local.get $suffix))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $string-suffix?/i32
               (param $s-raw (ref eq)) (param $suffix-raw (ref eq))
               (result i32)

               (local $s (ref $String))
               (local $suf (ref $String))

               ;; Type checks
               (if (i32.eqz (ref.test (ref $String) (local.get $s-raw)))
                   (then (call $raise-racket-string:string-expected
                               (global.get $symbol:string-suffix?)
                               (local.get $s-raw))))
               (if (i32.eqz (ref.test (ref $String) (local.get $suffix-raw)))
                   (then (call $raise-racket-string:string-expected
                               (global.get $symbol:string-suffix?)
                               (local.get $suffix-raw))))

               ;; Cast and delegate
               (local.set $s   (ref.cast (ref $String) (local.get $s-raw)))
               (local.set $suf (ref.cast (ref $String) (local.get $suffix-raw)))
               (return_call $string-suffix?/i32/checked (local.get $s) (local.get $suf)))

         (func $string-suffix?/i32/checked
               (param $s (ref $String)) (param $suf (ref $String))
               (result i32)

               (local $arr-s   (ref $I32Array))
               (local $arr-suf (ref $I32Array))
               (local $len-s   i32)
               (local $len-suf i32)
               (local $offset  i32)
               (local $i       i32)

               (local.set $arr-s   (struct.get $String $codepoints (local.get $s)))
               (local.set $arr-suf (struct.get $String $codepoints (local.get $suf)))
               (local.set $len-s   (array.len (local.get $arr-s)))
               (local.set $len-suf (array.len (local.get $arr-suf)))

               ;; If suffix longer than string, fail
               (if (i32.gt_u (local.get $len-suf) (local.get $len-s))
                   (then (return (i32.const 0))))

               (local.set $offset (i32.sub (local.get $len-s) (local.get $len-suf)))
               (local.set $i (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len-suf)))
                            (if (i32.ne
                                 (array.get $I32Array (local.get $arr-s)
                                            (i32.add (local.get $offset) (local.get $i)))
                                 (array.get $I32Array (local.get $arr-suf) (local.get $i)))
                                (then (return (i32.const 0))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (i32.const 1))

         (func $string-prefix? (type $Prim2)
               (param $s (ref eq)) (param $prefix (ref eq))
               (result (ref eq))
               (if (result (ref eq)) (call $string-prefix?/i32 (local.get $s) (local.get $prefix))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $string-prefix?/i32
               (param $s-raw (ref eq)) (param $prefix-raw (ref eq))
               (result i32)

               (local $s (ref $String))
               (local $p (ref $String))

               (if (i32.eqz (ref.test (ref $String) (local.get $s-raw)))
                   (then (call $raise-racket-string:string-expected
                               (global.get $symbol:string-prefix?)
                               (local.get $s-raw))))
               (if (i32.eqz (ref.test (ref $String) (local.get $prefix-raw)))
                   (then (call $raise-racket-string:string-expected
                               (global.get $symbol:string-prefix?)
                               (local.get $prefix-raw))))

               (local.set $s (ref.cast (ref $String) (local.get $s-raw)))
               (local.set $p (ref.cast (ref $String) (local.get $prefix-raw)))

               (return_call $string-prefix?/i32/checked (local.get $s) (local.get $p)))

         (func $string-prefix?/i32/checked
               (param $s (ref $String)) (param $p (ref $String))
               (result i32)

               (local $arr-s (ref $I32Array))
               (local $arr-p (ref $I32Array))
               (local $len-s i32)
               (local $len-p i32)
               (local $i i32)
               (local $cp-s i32)
               (local $cp-p i32)

               (local.set $arr-s (struct.get $String $codepoints (local.get $s)))
               (local.set $arr-p (struct.get $String $codepoints (local.get $p)))
               (local.set $len-s (array.len (local.get $arr-s)))
               (local.set $len-p (array.len (local.get $arr-p)))
               (if (i32.lt_u (local.get $len-s) (local.get $len-p))
                   (then (return (i32.const 0))))
               (local.set $i (i32.const 0))
               (block $exit
                      (loop $loop
                            (br_if $exit (i32.ge_u (local.get $i) (local.get $len-p)))
                            (local.set $cp-s (array.get $I32Array (local.get $arr-s) (local.get $i)))
                            (local.set $cp-p (array.get $I32Array (local.get $arr-p) (local.get $i)))
                            (if (i32.ne (local.get $cp-s) (local.get $cp-p))
                                (then (return (i32.const 0))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))
               (i32.const 1))

         (func $string-contains? (type $Prim2)
               (param $s         (ref eq)) ;; string?
               (param $contained (ref eq)) ;; string?
               (result           (ref eq))

               ;; Delegate to string-find and report only presence.
               (if (result (ref eq))
                   (ref.eq (call $string-find/who
                                 (global.get $symbol:string-contains?)
                                 (local.get $s)
                                 (local.get $contained))
                           (global.get $false))
                   (then (global.get $false))
                   (else (global.get $true))))

         (func $string-find/who
               (param $who       (ref eq))
               (param $s (ref eq))
               (param $contained (ref eq))
               (result (ref eq))

               (local $str    (ref $String))
               (local $sub    (ref $String))
               (local $arr-s  (ref $I32Array))
               (local $arr-c  (ref $I32Array))
               (local $len-s  i32)
               (local $len-c  i32)
               (local $limit  i32)
               (local $i      i32)
               (local $j      i32)
               (local $ch-s   i32)
               (local $ch-c   i32)

               ;; --- Check inputs ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-racket-string:string-expected
                               (local.get $who)
                               (local.get $s))))
               (if (i32.eqz (ref.test (ref $String) (local.get $contained)))
                   (then (call $raise-racket-string:string-expected
                               (local.get $who)
                               (local.get $contained))))

               ;; --- Decode after checks ---
               (local.set $str   (ref.cast (ref $String) (local.get $s)))
               (local.set $sub   (ref.cast (ref $String) (local.get $contained)))
               (local.set $arr-s (struct.get $String $codepoints (local.get $str)))
               (local.set $arr-c (struct.get $String $codepoints (local.get $sub)))
               (local.set $len-s (array.len (local.get $arr-s)))
               (local.set $len-c (array.len (local.get $arr-c)))

               ;; --- Edge cases ---
               (if (i32.eqz (local.get $len-c))
                   (then (return (global.get $zero))))
               (if (i32.lt_u (local.get $len-s) (local.get $len-c))
                   (then (return (global.get $false))))

               (local.set $limit (i32.sub (local.get $len-s) (local.get $len-c)))
               (local.set $i     (i32.const 0))
               (block $not-found
                      (loop $outer
                            (br_if $not-found
                                   (i32.gt_u (local.get $i) (local.get $limit)))
                            (local.set $j (i32.const 0))
                            (block $mismatch
                                   (loop $inner
                                         (br_if $mismatch
                                                (i32.ge_u (local.get $j) (local.get $len-c)))
                                         (local.set $ch-s
                                                    (call $i32array-ref
                                                          (local.get $arr-s)
                                                          (i32.add (local.get $i) (local.get $j))))
                                         (local.set $ch-c
                                                    (call $i32array-ref
                                                          (local.get $arr-c)
                                                          (local.get $j)))
                                         (if (i32.ne (local.get $ch-s) (local.get $ch-c))
                                             (then (br $mismatch)))
                                         (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                         (br $inner)))
                            (if (i32.eq (local.get $j) (local.get $len-c))
                                (then (return (ref.i31 (i32.shl (local.get $i) (i32.const 1))))))
                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $outer)))
               (global.get $false))

         (func $string-find (type $Prim2)
               (param $s         (ref eq))
               (param $contained (ref eq))
               (result           (ref eq))

               (call $string-find/who
                     (global.get $symbol:string-find)
                     (local.get $s)
                     (local.get $contained)))


        (func $string-replace (type $Prim34)
              (param $s     (ref eq)) ;; string?
              (param $from  (ref eq)) ;; string?
              (param $to    (ref eq)) ;; string?
              (param $all?  (ref eq)) ;; boolean?, optional with default #t
              (result        (ref eq))

              (local $str      (ref $String))
              (local $f        (ref $String))
              (local $t        (ref $String))
              (local $arr-s    (ref $I32Array))
              (local $arr-f    (ref $I32Array))
              (local $arr-t    (ref $I32Array))
              (local $n        i32)
              (local $m        i32)
              (local $r        i32)
              (local $idxs     (ref $I32GrowableArray))
              (local $limit    i32)
              (local $i        i32)
              (local $j        i32)
              (local $k        i32)
              (local $res-len  i32)
              (local $res      (ref $I32Array))
              (local $dst      i32)
              (local $src      i32)
              (local $idx      i32)

              ;; Handle optional all? with default #t
              (if (ref.eq (local.get $all?) (global.get $missing))
                  (then (local.set $all? (global.get $true))))

              ;; Type checks
              (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                  (then (call $raise-argument-error:string-expected/who
                              (global.get $symbol:string-replace)
                              (local.get $s))
                        (unreachable)))
              (if (i32.eqz (ref.test (ref $String) (local.get $from)))
                  (then (call $raise-argument-error:string-expected/who
                              (global.get $symbol:string-replace)
                              (local.get $from))
                        (unreachable)))
              (if (i32.eqz (ref.test (ref $String) (local.get $to)))
                  (then (call $raise-argument-error:string-expected/who
                              (global.get $symbol:string-replace)
                              (local.get $to))
                        (unreachable)))
              (if (ref.eq (call $boolean? (local.get $all?)) (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:string-replace)
                              (global.get $string:boolean?)
                              (local.get $all?))
                        (unreachable)))

              ;; Decode after checks
              (local.set $str   (ref.cast (ref $String) (local.get $s)))
              (local.set $f     (ref.cast (ref $String) (local.get $from)))
              (local.set $t     (ref.cast (ref $String) (local.get $to)))
              (local.set $arr-s (struct.get $String $codepoints (local.get $str)))
              (local.set $arr-f (struct.get $String $codepoints (local.get $f)))
              (local.set $arr-t (struct.get $String $codepoints (local.get $t)))
              (local.set $n     (array.len (local.get $arr-s)))
              (local.set $m     (array.len (local.get $arr-f)))
              (local.set $r     (array.len (local.get $arr-t)))

              ;; Collect match indices
              (local.set $idxs (call $make-i32growable-array (i32.const 4)))
              (if (i32.eqz (local.get $m))
                  (then
                   (if (ref.eq (local.get $all?) (global.get $false))
                       (then (call $i32growable-array-add! (local.get $idxs) (i32.const 0)))
                       (else
                        (local.set $i (i32.const 0))
                        (block $done
                               (loop $loop
                                     (br_if $done (i32.gt_u (local.get $i) (local.get $n)))
                                     (call $i32growable-array-add! (local.get $idxs) (local.get $i))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $loop))))))
                  (else
                   (local.set $limit (i32.sub (local.get $n) (local.get $m)))
                   (local.set $i (i32.const 0))
                   (if (ref.eq (local.get $all?) (global.get $false))
                       (then
                        (block $done
                               (loop $loop
                                     (br_if $done (i32.gt_u (local.get $i) (local.get $limit)))
                                     (local.set $j (i32.const 0))
                                     (block $mismatch
                                            (loop $inner
                                                  (br_if $mismatch (i32.ge_u (local.get $j) (local.get $m)))
                                                  (br_if $mismatch
                                                         (i32.ne
                                                          (call $i32array-ref
                                                                (local.get $arr-s)
                                                                (i32.add (local.get $i) (local.get $j)))
                                                          (call $i32array-ref (local.get $arr-f) (local.get $j))))
                                                  (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                                  (br $inner)))
                                     (if (i32.eq (local.get $j) (local.get $m))
                                         (then (call $i32growable-array-add! (local.get $idxs) (local.get $i))
                                               (br $done)))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $loop))))
                       (else
                        (block $end
                               (loop $loop
                                     (br_if $end (i32.gt_u (local.get $i) (local.get $limit)))
                                     (local.set $j (i32.const 0))
                                     (block $mismatch
                                            (loop $inner
                                                  (br_if $mismatch (i32.ge_u (local.get $j) (local.get $m)))
                                                  (br_if $mismatch
                                                         (i32.ne
                                                          (call $i32array-ref
                                                                (local.get $arr-s)
                                                                (i32.add (local.get $i) (local.get $j)))
                                                          (call $i32array-ref (local.get $arr-f) (local.get $j))))
                                                  (local.set $j (i32.add (local.get $j) (i32.const 1)))
                                                  (br $inner)))
                                     (if (i32.eq (local.get $j) (local.get $m))
                                         (then (call $i32growable-array-add! (local.get $idxs) (local.get $i))
                                               (local.set $i (i32.add (local.get $i) (local.get $m)))
                                               (br $loop)))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $loop)))))))

              (local.set $k (call $i32growable-array-count (local.get $idxs)))
              (if (i32.eqz (local.get $k))
                  (then (return (local.get $str))))

              (local.set $res-len
                        (i32.add (local.get $n)
                                 (i32.mul (local.get $k)
                                          (i32.sub (local.get $r) (local.get $m)))))
              (local.set $res (array.new_default $I32Array (local.get $res-len)))
              (local.set $dst (i32.const 0))
              (local.set $src (i32.const 0))
              (local.set $i   (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $k)))
                           (local.set $idx (call $i32growable-array-ref (local.get $idxs) (local.get $i)))
                           (call $i32array-copy!
                                 (local.get $res) (local.get $dst)
                                 (local.get $arr-s) (local.get $src) (local.get $idx))
                           (local.set $dst (i32.add (local.get $dst)
                                                    (i32.sub (local.get $idx) (local.get $src))))
                           (call $i32array-copy!
                                 (local.get $res) (local.get $dst)
                                 (local.get $arr-t) (i32.const 0) (local.get $r))
                           (local.set $dst (i32.add (local.get $dst) (local.get $r)))
                           (local.set $src (i32.add (local.get $idx) (local.get $m)))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop)))
              (call $i32array-copy!
                    (local.get $res) (local.get $dst)
                    (local.get $arr-s) (local.get $src) (local.get $n))
              (struct.new $String
                          (i32.const 0)
                          (i32.const 0)
                          (local.get $res)))
     )))

;; string-core-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for core string conversion helpers.
(define string-core-conversion-runtime-only-helper-names
  '($i32array->string
    $i32array->immutable-string
    $i32growable-array->string
    $i32growable-array->immutable-string))

;; string-hash-core-runtime-helper-names : (listof symbol?)
;;   Preserve the FNV hash helper emission point; hash 0 means "not computed".
(define string-hash-core-runtime-helper-names
  '($string-hash/i32))

;; string-promoted-runtime-helper-names : (listof symbol?)
;;   Name runtime string helpers that are available in the standalone core runtime.
(define string-promoted-runtime-helper-names
  (append string-mutability-runtime-only-helper-names
          string-check-runtime-only-helper-names
          string-index-runtime-only-helper-names
          string-codepoint-runtime-only-helper-names
          string-dummy-runtime-only-helper-names
          string-basic-runtime-only-helper-names
          string-constructor-runtime-only-helper-names
          string-build-runtime-only-helper-names
          string-selector-runtime-only-helper-names
          string-mutation-runtime-only-helper-names
          string-copy-runtime-only-helper-names
          string-append-runtime-only-helper-names
          string-split-runtime-only-helper-names
          string-case-runtime-only-helper-names
          string-list-conversion-runtime-only-helper-names
          string-comparison-runtime-only-helper-names
          string-utf8-runtime-only-helper-names
          string-buffer-error-runtime-only-helper-names
          string-copy!-runtime-only-helper-names
          string-array-conversion-runtime-only-helper-names
          string-take-drop-runtime-only-helper-names
          string-error-runtime-only-helper-names
          string-trim-runtime-only-helper-names
          string-additional-runtime-only-helper-names))

;; string-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given string helper names from the runtime helper index.
(define (string-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; string-mutability-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render string mutability predicates in runtime assembly order.
(define (string-mutability-runtime-helper-forms helper-index)
  (string-helper-forms helper-index string-mutability-runtime-only-helper-names))

;; string-hash-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render the string hash core helper in runtime assembly order.
(define (string-hash-core-runtime-helper-forms helper-index)
  (string-helper-forms helper-index string-hash-core-runtime-helper-names))

;; string-main-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render the main 4.4 string helper block in runtime assembly order.
(define (string-main-runtime-helper-forms runtime-helper-index core-runtime-helper-index)
  (append
   (string-helper-forms runtime-helper-index string-check-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-index-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-codepoint-runtime-only-helper-names)
   (string-helper-forms core-runtime-helper-index string-core-conversion-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-dummy-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-basic-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-constructor-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-build-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-selector-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-mutation-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-copy-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-append-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-split-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-case-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-list-conversion-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-comparison-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-utf8-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-copy!-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-array-conversion-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-take-drop-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-error-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-trim-runtime-only-helper-names)
   (string-helper-forms runtime-helper-index string-additional-runtime-only-helper-names)))

;; string-buffer-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render string-buffer error helpers in runtime assembly order.
(define (string-buffer-runtime-helper-forms helper-index)
  (string-helper-forms helper-index string-buffer-error-runtime-only-helper-names))

;;;
;;; Data segment strings
;;;

;; The current (June 2005) support for strings in WebAssembly is *very* limited.
;; The data segment can be used to embed byte sequences in the source.
;; However in order to access the data, one must copy them to the linear memory first.

; Turns out that the `memory.init` instruction requires a fixed
; segment number. So since we can't pass the segment number as an argument,
; we can't use these functions. Sigh.

#;(func $data:codepoints->string
        (param $segment   i32)  ;; index of the passive data segment
        (param $count     i32)  ;; number of UTF-32 codepoints
        (result           (ref $String))

        (local $base      i32)
        (local $i         i32)
        (local $arr       (ref $I32Array))
        (local $str       (ref $String))
        (local $byte-size i32)

        ;; 1. Get base address for string buffer
        (local.set $base (global.get $memory-map:string-buffer-base))
        ;; 2. Compute byte size = count * 4
        (local.set $byte-size (i32.mul (local.get $count) (i32.const 4)))
        ;; 3. Bounds check (optional but recommended)
        (if (i32.gt_u (local.get $byte-size)
                      (global.get $memory-map:string-buffer-length))
            (then (call $raise-string-buffer-overflow)))
        ;; 4. Copy data segment to string buffer
        (memory.init (local.get $segment)
                     (local.get $base)
                     (i32.const 0)
                     (local.get $byte-size))
        ;; 5. Allocate I32Array
        (local.set $arr (array.new_default $I32Array (local.get $count)))
        ;; 6. Copy from memory buffer into array
        (local.set $i (i32.const 0))
        (loop $copy (array.set $I32Array
                               (local.get $arr)
                               (local.get $i)
                               (i32.load
                                (i32.add
                                 (local.get $base)
                                 (i32.mul (local.get $i) (i32.const 4)))))
              (local.set $i (i32.add (local.get $i) (i32.const 1)))
              (br_if $copy (i32.lt_u (local.get $i) (local.get $count))))

        ;; 7. Convert to string
        (local.set $str (call $i32array->string (local.get $arr)))
        (local.get $str))

#;(func $data:bytes->string
        (param $segment    i32) ;; passive data segment index
        (param $byte-count i32) ;; number of UTF-8 bytes
        (result            (ref $String))

        (local $base  i32)
        (local $i     i32)
        (local $arr   (ref $I8Array))
        (local $bs    (ref $Bytes))
        (local $str   (ref $String))
        ;; 1. Get base address for string buffer
        (local.set $base (global.get $memory-map:string-buffer-base))
        ;; 2. Bounds check
        (if (i32.gt_u (local.get $byte-count)
                      (global.get $memory-map:string-buffer-length))
            (then (call $raise-string-buffer-overflow)))
        ;; 3. Copy from data segment into memory buffer
        (memory.init (local.get $segment)
                     (local.get $base)
                     (i32.const 0)
                     (local.get $byte-count))
        ;; 4. Allocate and fill I8Array
        (local.set $arr (array.new_default $I8Array (local.get $byte-count)))
        (local.set $i (i32.const 0))
        (loop $copy
              (array.set $I8Array (local.get $arr) (local.get $i)
                         (i32.load8_u
                          (i32.add (local.get $base)
                                   (local.get $i))))
              (local.set $i (i32.add (local.get $i) (i32.const 1)))
              (br_if $copy (i32.lt_u (local.get $i) (local.get $byte-count))))
        ;; 5. Wrap I8Array in Bytes struct
        (local.set $bs (struct.new $Bytes
                                   (i32.const 0)         ;; hash = 0 (unset)
                                   (local.get $byte-count)
                                   (local.get $arr)))
        ;; 6. Decode UTF-8
        (local.set $str (call $bytes->string/utf-8/checked
                              (local.get $bs)))
        (local.get $str))

;; string-buffer-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string-buffer error helpers used by the monolithic runtime.
(define string-buffer-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-buffer-error-runtime-only-helpers
   '(
         (func $raise-string-buffer-overflow
               (drop (call $raise
                           (call $make-exn:fail:out-of-memory
                                 (global.get $string:string-buffer-overflow)
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))
     )))

;; string-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate string helpers in monolithic runtime order.
(define string-all-runtime-helpers
  (append string-mutability-runtime-only-helpers
          string-check-runtime-only-helpers
          string-index-runtime-only-helpers
          string-codepoint-runtime-only-helpers
          string-dummy-runtime-only-helpers
          string-basic-runtime-only-helpers
          string-constructor-runtime-only-helpers
          string-build-runtime-only-helpers
          string-selector-runtime-only-helpers
          string-mutation-runtime-only-helpers
          string-copy-runtime-only-helpers
          string-append-runtime-only-helpers
          string-split-runtime-only-helpers
          string-case-runtime-only-helpers
          string-list-conversion-runtime-only-helpers
          string-comparison-runtime-only-helpers
          string-utf8-runtime-only-helpers
          string-buffer-error-runtime-only-helpers
          string-copy!-runtime-only-helpers
          string-array-conversion-runtime-only-helpers
          string-take-drop-runtime-only-helpers
          string-error-runtime-only-helpers
          string-trim-runtime-only-helpers
          string-additional-runtime-only-helpers))

;; string-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate string helpers available in the standalone core runtime.
(define string-core-runtime-helpers
  (append string-base-core-runtime-helpers
          (select-runtime-helpers string-all-runtime-helpers
                                  string-promoted-runtime-helper-names)))

;; string-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string helpers that still depend on monolithic runtime globals.
(define string-runtime-only-helpers
  (remove-runtime-helpers string-all-runtime-helpers
                          string-promoted-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define string-helper-index
    (make-core-runtime-helper-index
     (append string-core-runtime-helpers
             string-runtime-only-helpers)))

  (define string-core-helper-index
    (make-core-runtime-helper-index string-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name string-core-runtime-helpers)
   (append string-core-conversion-runtime-only-helper-names
           string-hash-core-runtime-helper-names
           string-promoted-runtime-helper-names))

  (check-equal?
   (map form-name (string-hash-core-runtime-helper-forms string-core-helper-index))
   string-hash-core-runtime-helper-names)

  (check-equal?
   (map form-name (string-mutability-runtime-helper-forms string-helper-index))
   string-mutability-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (string-main-runtime-helper-forms string-helper-index string-core-helper-index))
   (append string-check-runtime-only-helper-names
           string-index-runtime-only-helper-names
           string-codepoint-runtime-only-helper-names
           string-core-conversion-runtime-only-helper-names
           string-dummy-runtime-only-helper-names
           string-basic-runtime-only-helper-names
           string-constructor-runtime-only-helper-names
           string-build-runtime-only-helper-names
           string-selector-runtime-only-helper-names
           string-mutation-runtime-only-helper-names
           string-copy-runtime-only-helper-names
           string-append-runtime-only-helper-names
           string-split-runtime-only-helper-names
           string-case-runtime-only-helper-names
           string-list-conversion-runtime-only-helper-names
           string-comparison-runtime-only-helper-names
           string-utf8-runtime-only-helper-names
           string-copy!-runtime-only-helper-names
           string-array-conversion-runtime-only-helper-names
           string-take-drop-runtime-only-helper-names
           string-error-runtime-only-helper-names
           string-trim-runtime-only-helper-names
           string-additional-runtime-only-helper-names))

  (check-equal?
   (map form-name (string-buffer-runtime-helper-forms string-helper-index))
   string-buffer-error-runtime-only-helper-names))
