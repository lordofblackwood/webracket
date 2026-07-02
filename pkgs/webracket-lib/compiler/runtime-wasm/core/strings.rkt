#lang racket

(provide string-core-runtime-helpers
         string-append-runtime-only-helper-names
         string-case-runtime-only-helper-names
         string-constructor-runtime-only-helper-names
         string-copy-runtime-only-helper-names
         string-dummy-runtime-only-helper-names
         string-index-runtime-only-helper-names
         string-list-conversion-runtime-only-helper-names
         string-mutation-runtime-only-helper-names
         string-mutability-runtime-only-helper-names
         string-selector-runtime-only-helper-names
         string-split-runtime-only-helper-names
         string-runtime-only-helpers)

(require "../core-helper.rkt"
         (only-in "../../private/immediates.rkt"
                  char-mask
                  char-shift
                  char-tag))

;; string-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate string helpers that can be emitted in core runtime.
(define string-core-runtime-helpers
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

;; string-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string construction helpers.
(define string-constructor-runtime-only-helper-names
  '($raise-make-string:bad-length
    $raise-make-string:bad-char
    $raise-argument-error:char-expected
    $make-string
    $make-string/checked
    $make-immutable-string/checked
    $string->immutable-string))

;; string-index-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string index error helpers.
(define string-index-runtime-only-helper-names
  '($raise-bad-string-index
    $raise-bad-string-index/i32
    $raise-string-length:bad-argument
    $raise-string-index-out-of-bounds/i32))

;; string-dummy-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string dummy construction helpers.
(define string-dummy-runtime-only-helper-names
  '($make-dummy-string))

;; string-selector-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string selector helpers.
(define string-selector-runtime-only-helper-names
  '($string-length
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
  '($substring
    $string-copy
    $raise-immutable-string
    $string-fill!))

;; string-append-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string append helpers.
(define string-append-runtime-only-helper-names
  '($string-append/2
    $string-append
    $string-append-immutable
    $string-append*))

;; string-split-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for string join and split helpers.
(define string-split-runtime-only-helper-names
  '($string-join
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
             (then (call $raise-check-string (local.get $s))))
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

;; string-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string construction helpers that still depend on monolithic runtime globals.
(define string-constructor-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-constructor-runtime-only-helpers
   `(
         (func $raise-make-string:bad-length       (unreachable))
         (func $raise-make-string:bad-char         (unreachable))
         (func $raise-argument-error:char-expected (unreachable))

         (func $make-string (type $Prim12)
               (param $n-raw  (ref eq))    ;; fixnum
               (param $ch-raw (ref eq))    ;; optional immediate character
               (result        (ref eq))

               (local $n          i32)
               (local $ch-tagged  i32)
               (local $ch         i32)
               ;; --- Type check for length ---
               (if (i32.eqz (ref.test (ref i31) (local.get $n-raw)))
                   (then (call $raise-make-string:bad-length)))
               ;; --- Decode length ---
               (local.set $n (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $n-raw))) (i32.const 1)))
               ;; --- Handle optional character ---
               (if (ref.eq (local.get $ch-raw) (global.get $missing))
                   (then (local.set $ch (i32.const 0)))
                   (else
                    ;; --- Validate character ---
                    (if (i32.eqz (ref.test (ref i31) (local.get $ch-raw)))
                        (then (call $raise-make-string:bad-char)))
                    (local.set $ch-tagged (i31.get_u (ref.cast (ref i31) (local.get $ch-raw))))
                    (if (i32.ne (i32.and (local.get $ch-tagged) (i32.const ,char-mask)) (i32.const ,char-tag))
                        (then (call $raise-make-string:bad-char)))
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
                   (then (call $raise-check-string (local.get $s))))
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

;; string-index-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string index error helpers that still depend on monolithic runtime globals.
(define string-index-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-index-runtime-only-helpers
   '(
         (func $raise-bad-string-index     (param $x (ref eq)) (param $i (ref eq))  (unreachable))
         (func $raise-bad-string-index/i32 (param $x (ref eq)) (param $i i32)       (unreachable))
         (func $raise-string-length:bad-argument (unreachable))

         (func $raise-string-index-out-of-bounds/i32 (param $x (ref eq)) (param $i i32) (param $n i32)
               (unreachable))
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

;; string-selector-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string selector helpers that still depend on monolithic runtime globals.
(define string-selector-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-selector-runtime-only-helpers
   `(
         (func $string-length (type $Prim1)
               (param $s-raw (ref eq))
               (result (ref eq))

               (local $s   (ref $String))
               (local $len i32)
               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s-raw)))
                   (then (call $raise-string-length:bad-argument)))
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

               (local $str     (ref $String))
               (local $idx-i31 (ref i31))
               (local $idx     i32)

               ;; --- All tests ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))

               (if (i32.eqz (ref.test (ref i31) (local.get $i)))
                   (then (call $raise-check-fixnum (local.get $i))))

               (local.set $idx-i31 (ref.cast (ref i31) (local.get $i)))
               (local.set $idx (i31.get_u (local.get $idx-i31)))
               (if (i32.ne (i32.and (local.get $idx) (i32.const 1)) (i32.const 0))
                   (then (call $raise-check-fixnum (local.get $i))))

               ;; --- All decoding ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1)))

               ;; --- Bounds check and delegate ---
               (if (result (ref eq))
                   (i32.lt_u (local.get $idx)
                             (call $string-length/checked/i32 (local.get $str)))
                   (then (call $string-ref/checked (local.get $str) (local.get $idx)))
                   (else (call $raise-bad-string-index/i32 (local.get $s) (local.get $idx))
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
         (func $raise-string-set!:string-expected  (param $x (ref eq)) (unreachable))
         (func $raise-string-set!:fixnum-expected  (param $x (ref eq)) (unreachable))
         (func $raise-string-set!:char-expected    (param $x (ref eq)) (unreachable))
         (func $raise-string-set!:string-immutable (param $x (ref eq)) (unreachable))

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
               ;; --- Type checks ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-string-set!:string-expected (local.get $s))))
               (if (i32.eqz (ref.test (ref i31) (local.get $i)))
                   (then (call $raise-string-set!:fixnum-expected (local.get $i))))
               (if (i32.eqz (ref.test (ref i31) (local.get $ch)))
                   (then (call $raise-string-set!:char-expected (local.get $ch))))
               ;; --- Decode ---
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; Check for immutability
               (if (i32.eq (struct.get $String $immutable (local.get $str)) (i32.const 1))
                   (then (call $raise-string-set!:string-immutable (local.get $s))))
               ;; Decode and validate fixnum index
               (local.set $idx (i31.get_u (ref.cast (ref i31) (local.get $i))))
               (if (i32.eqz (i32.and (local.get $idx) (i32.const 1)))
                   (then (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1))))
                   (else (call $raise-string-set!:fixnum-expected (local.get $i))))
               ;; Decode and validate character
               (local.set $tagged (i31.get_u (ref.cast (ref i31) (local.get $ch))))
               (if (i32.ne (i32.and (local.get $tagged) (i32.const ,char-mask)) (i32.const ,char-tag))
                   (then (call $raise-string-set!:char-expected (local.get $ch))))
               (local.set $cp (i32.shr_u (local.get $tagged) (i32.const ,char-shift)))
               ;; --- Bounds-check and write ---
               (local.set $arr (struct.get $String $codepoints (local.get $str)))
               (if (i32.lt_u (local.get $idx) (call $i32array-length (local.get $arr)))
                   (then (call $i32array-set! (local.get $arr) (local.get $idx) (local.get $cp))
                         ;; Keep the hash. The eq-identity doesn't change.
                         (return (global.get $void)))
                   (else (call $raise-bad-string-index/i32 (local.get $s) (local.get $idx))))
               (unreachable))
     )))

;; string-copy-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string copy and fill helpers that still depend on monolithic runtime globals.
(define string-copy-runtime-only-helpers
  (function-forms->runtime-helpers
   'string-copy-runtime-only-helpers
   `(
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
                  (else (call $raise-check-string (local.get $s))))
              ;; decode and check start index
              (if (ref.test (ref i31) (local.get $start))
                  (then (local.set $i32start (i31.get_u (ref.cast (ref i31) (local.get $start))))
                        (if (i32.ne (i32.and (local.get $i32start) (i32.const 1)) (i32.const 0))
                            (then (call $raise-check-fixnum (local.get $start))))
                        (local.set $i32start (i32.shr_u (local.get $i32start) (i32.const 1))))
                  (else (call $raise-check-fixnum (local.get $start))))
              ;; get array and length
              (local.set $arr (struct.get $String $codepoints (local.get $str)))
              (local.set $len (call $i32array-length (local.get $arr)))
              ;; supply default value for the optional end index
              (if (ref.eq (local.get $end) (global.get $missing))
                  (then (local.set $end
                                   (ref.i31 (i32.shl (local.get $len) (i32.const 1))))))
              ;; decode and check end index
              (if (ref.test (ref i31) (local.get $end))
                  (then (local.set $i32end (i31.get_u (ref.cast (ref i31) (local.get $end))))
                        (if (i32.ne (i32.and (local.get $i32end) (i32.const 1)) (i32.const 0))
                            (then (call $raise-check-fixnum (local.get $end))))
                        (local.set $i32end (i32.shr_u (local.get $i32end) (i32.const 1))))
                  (else (call $raise-check-fixnum (local.get $end))))
              ;; bounds check: start <= end <= len
              (if (i32.or (i32.gt_u (local.get $i32start) (local.get $i32end))
                          (i32.gt_u (local.get $i32end) (local.get $len)))
                  (then (call $raise-string-index-out-of-bounds/i32 (local.get $s) (local.get $i32end) (local.get $len))))
              ;; create new string
              (struct.new $String
                          (i32.const 0) ; hash
                          (i32.const 0) ; mutable (also for immutable input)
                          (call $i32array-copy (local.get $arr) (local.get $i32start) (local.get $i32end))))

         (func $string-copy (type $Prim1)
               (param $s (ref eq))
               (result (ref eq))

               (local $str (ref $String))
               (local $arr (ref $I32Array))
               (local $len i32)
               (local $copy (ref $I32Array))
               ;; --- Type check ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
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

         (func $raise-immutable-string (param $x (ref eq)) (unreachable))

         (func $string-fill! (type $Prim2)
               (param $s   (ref eq))
               (param $ch  (ref eq))
               (result     (ref eq))

               (local $str (ref $String))
               (local $arr (ref $I32Array))
               (local $cp  i32)

               ;; --- 1. Check and cast string ---
               (if (i32.eqz (ref.test (ref $String) (local.get $s)))
                   (then (call $raise-check-string (local.get $s))))
               (local.set $str (ref.cast (ref $String) (local.get $s)))
               ;; --- 2. Raise if immutable ---
               (if (i32.ne (struct.get $String $immutable (local.get $str)) (i32.const 0))
                   (then (call $raise-immutable-string (local.get $s))))
               ;; --- 3. Decode and check char immediate ---
               (if (i32.eqz (ref.test (ref i31) (local.get $ch)))
                   (then (call $raise-check-char (local.get $ch))))
               (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $ch))))
               (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask)) (i32.const ,char-tag))
                   (then (call $raise-check-char (local.get $ch))))
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
         (func $string-append/2 (param $s1 (ref eq)) (param $s2 (ref eq)) (result (ref $String))
               (local $str1 (ref null $String))
               (local $str2 (ref null $String))
               (if (ref.test (ref $String) (local.get $s1))
                   (then (local.set $str1 (ref.cast (ref $String) (local.get $s1))))
                   (else (call $raise-check-string (local.get $s1))))
               (if (ref.test (ref $String) (local.get $s2))
                   (then (local.set $str2 (ref.cast (ref $String) (local.get $s2))))
                   (else (call $raise-check-string (local.get $s2))))
               (struct.new $String
                           (i32.const 0)
                           (i32.const 0)
                           (call $i32array-append
                                 (struct.get $String $codepoints (local.get $str1))
                                 (struct.get $String $codepoints (local.get $str2)))))


         (func $string-append (type $Prim>=0)
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
                   (else (call $raise-check-string (local.get $v))))
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
                                (else (call $raise-check-string (local.get $v))))
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


         (func $string-append-immutable (type $Prim>=0)
               (param  $xs (ref eq))         ;; list of strings
               (result     (ref eq))

               (local $s   (ref $String))
               (local $arr (ref $I32Array))
               ;; Do the append (returns a fresh $String)
               (local.set $s (ref.cast (ref $String)
                                       (call $string-append (local.get $xs))))
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
                   (then (return (call $string-append (local.get $str)))))

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

               ;; --- Handle optional separator ---
               (local.set $sep-str
                          (if (result (ref $String))
                              (ref.eq (local.get $sep) (global.get $missing))
                              (then (ref.cast (ref $String) (global.get $string:space)))
                              (else (if (result (ref $String))
                                        (ref.test (ref $String) (local.get $sep))
                                        (then (ref.cast (ref $String) (local.get $sep)))
                                        (else (call $raise-check-string (local.get $sep))
                                              (unreachable))))))
               ;; --- Determine separator length ---
               (local.set $sep-len
                          (call $i32array-length
                                (struct.get $String $codepoints (local.get $sep-str))))
               ;; --- Determine number of strings ---
               (local.set $n (call $length/i32 (local.get $strs)))
               (if (i32.eqz (local.get $n))
                   (then (return (global.get $string:empty))))
               ;; --- Compute total length ---
               (local.set $xs (local.get $strs))
               (local.set $total
                          (i32.mul (i32.sub (local.get $n) (i32.const 1))
                                   (local.get $sep-len)))
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
                                 (local.set $total (i32.add (local.get $total) (local.get $len))))
                                (else (call $raise-check-string (local.get $v)) (unreachable)))
                            (local.set $xs (struct.get $Pair $d (local.get $node)))
                            (br $loop1)))
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
                   (then (call $raise-check-string (local.get $str-raw))))
               (local.set $str (ref.cast (ref $String) (local.get $str-raw)))

               (local.set $sep
                          (if (result (ref $String))
                              (ref.eq (local.get $sep-raw) (global.get $missing))
                              (then (ref.cast (ref $String) (global.get $string:space)))
                              (else (if (result (ref $String))
                                        (ref.test (ref $String) (local.get $sep-raw))
                                        (then (ref.cast (ref $String) (local.get $sep-raw)))
                                        (else (call $raise-check-string (local.get $sep-raw))
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
                   (then (call $raise-check-string (local.get $s))
                         (unreachable)))
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
                   (else (call $raise-check-string (local.get $s))))
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
               ;; 1. Compute list length (will raise if not proper list)
               (local.set $len (call $length/i32 (local.get $xs)))
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
                                 (local.set $cp (i31.get_u (ref.cast (ref i31) (local.get $chimm))))
                                 (if (i32.ne (i32.and (local.get $cp) (i32.const ,char-mask)) (i32.const ,char-tag))
                                     (then (call $raise-check-char (local.get $chimm))
                                           (unreachable)))
                                 ;; extract codepoint
                                 (local.set $cp (i32.shr_u (local.get $cp) (i32.const 8)))
                                 ;; write codepoint
                                 (call $i32array-set! (local.get $arr) (local.get $i) (local.get $cp))
                                 ;; advance
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node)))))
                                (else
                                 (call $raise-pair-expected (local.get $node))
                                 (unreachable)))
                            (br $fill)))
               ;; 5. Return string
               (local.get $str))
     )))

;; string-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string helpers that still depend on monolithic runtime globals.
(define string-runtime-only-helpers
  (append string-mutability-runtime-only-helpers
          string-constructor-runtime-only-helpers
          string-index-runtime-only-helpers
          string-dummy-runtime-only-helpers
          string-selector-runtime-only-helpers
          string-mutation-runtime-only-helpers
          string-copy-runtime-only-helpers
          string-append-runtime-only-helpers
          string-split-runtime-only-helpers
          string-case-runtime-only-helpers
          string-list-conversion-runtime-only-helpers))
