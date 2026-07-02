#lang racket

(provide string-core-runtime-helpers
         string-constructor-runtime-only-helper-names
         string-dummy-runtime-only-helper-names
         string-index-runtime-only-helper-names
         string-mutation-runtime-only-helper-names
         string-mutability-runtime-only-helper-names
         string-selector-runtime-only-helper-names
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

;; string-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate string helpers that still depend on monolithic runtime globals.
(define string-runtime-only-helpers
  (append string-mutability-runtime-only-helpers
          string-constructor-runtime-only-helpers
          string-index-runtime-only-helpers
          string-dummy-runtime-only-helpers
          string-selector-runtime-only-helpers
          string-mutation-runtime-only-helpers))
