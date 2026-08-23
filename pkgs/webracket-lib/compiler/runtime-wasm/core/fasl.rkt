#lang racket

(provide fasl-tag-global-forms
         fasl-tag-global-names
         fasl-tag-runtime-only-helper-names
         fasl-tag-runtime-helper-forms
         fasl-runtime-string-constants
         fasl-runtime-symbol-constants
         fasl-encoding-runtime-only-helper-names
         fasl-encoding-runtime-helper-forms
         fasl-decoding-runtime-helper-forms
         fasl-core-runtime-helpers
         fasl-runtime-only-helpers
         fasl-runtime-only-helper-names)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt"
         (only-in "../../private/immediates.rkt"
                  boolean-mask
                  boolean-shift
                  boolean-tag
                  char-mask
                  char-shift
                  char-tag
                  empty-value
                  eof-value
                  void-value))

;; fasl-tag-global-specs : (listof (list symbol? exact-integer?))
;;   Describe the FASL tag globals and their encoded numeric tag values.
(define fasl-tag-global-specs
  '(($fasl-fixnum    0)
    ($fasl-character 1)
    ($fasl-symbol    2)
    ($fasl-string    3)
    ($fasl-bytes     4)
    ($fasl-boolean   5)
    ($fasl-null      6)
    ($fasl-pair      7)
    ($fasl-vector    8)
    ($fasl-flonum    9)
    ($fasl-void      10)
    ($fasl-eof       11)
    ($fasl-external  12)
    ($fasl-keyword   13)
    ($fasl-bignum    14)
    ($fasl-rational  15)
    ($fasl-complex   16)))

;; fasl-tag-global-names : (listof symbol?)
;;   Preserve the runtime emission order for FASL tag globals.
(define fasl-tag-global-names
  (map first fasl-tag-global-specs))

;; fasl-tag-runtime-only-helper-names : (listof symbol?)
;;   Backward-compatible name for FASL tag globals.
(define fasl-tag-runtime-only-helper-names
  fasl-tag-global-names)

;; fasl-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by FASL helpers.
(define fasl-runtime-symbol-constants
  '(s-exp->fasl
    fasl->s-exp
    linear-memory->string))

;; fasl-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by FASL helpers.
(define fasl-runtime-string-constants
  '((fasl->s-exp-input "(or/c bytes? input-port?)")
    (s-exp->fasl-unsupported-prefix
     "s-exp->fasl: unsupported value\n  value: ")))

;; fasl-tag-global-forms : (listof datum?)
;;   Enumerate FASL tag globals used by the runtime.
(define fasl-tag-global-forms
  (for/list ([spec (in-list fasl-tag-global-specs)])
    (define name  (first spec))
    (define value (second spec))
    `(global ,name (ref i31) ,(Imm value))))

;; fasl-encoding-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for FASL encoding helpers.
(define fasl-encoding-runtime-only-helper-names
  '($s-exp->fasl
    $raise-s-exp->fasl:unsupported-value
    $fasl:s-exp->fasl
    $s-exp->fasl/immediate
    $fasl:write-u32
    $fasl:write-bignum
    $fasl:write-bytes
    $fasl:write-string
    $fasl:write-symbol
    $fasl:write-keyword
    $fasl:write-f64))

;; fasl-encoding-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate FASL encoding helpers used by the monolithic runtime.
(define fasl-encoding-runtime-only-helpers
  (function-forms->runtime-helpers
   'fasl-encoding-runtime-only-helpers
   `(
         (func $s-exp->fasl (type $Prim2)
               (param $v   (ref eq))
               ; optionals:
               (param $out (ref eq)) ;; a StringPort or #f (or $missing)
               (result     (ref eq))

               (local $port (ref eq))
               (local $res  (ref eq))

               ; Handle optional arguments
               (if (ref.eq (local.get $out) (global.get $missing))
                   (then (local.set $out (global.get $false))))

               (if (result (ref eq))
                   (ref.eq (local.get $out) (global.get $false))
                   (then
                    (local.set $port (call $open-output-bytes (global.get $missing)))
                    (call $fasl:s-exp->fasl (local.get $v) (local.get $port))
                    (local.set $res
                               (call $get-output-bytes
                                     (local.get $port)
                                     (global.get $missing)
                                     (global.get $missing)
                                     (global.get $missing)))
                    (local.get $res))
                   (else
                    (if (result (ref eq))
                        (ref.test (ref $OutputStringPort) (local.get $out))
                        (then
                         (call $fasl:s-exp->fasl (local.get $v) (local.get $out))
                         (global.get $void))
                        (else (call $raise-check-port-or-false
                                    (global.get $symbol:s-exp->fasl)
                                    (local.get $out))
                              (unreachable))))))

         ;; raise-s-exp->fasl:unsupported-value : any/c -> none
         ;;   Raise a regular exception for values that cannot be FASL encoded.
         (func $raise-s-exp->fasl:unsupported-value
               (param $v (ref eq))

               (drop (call $raise
                           (call $exn:fail:unsupported/make
                                 (call $string-append/2
                                       (global.get $string:s-exp->fasl-unsupported-prefix)
                                       (call $format/error-value->string (local.get $v)))
                                 (call $current-continuation-marks
                                       (global.get $missing)))
                           (global.get $true)))
               (unreachable))

         (func $fasl:s-exp->fasl
               (param $v   (ref eq))
               (param $out (ref eq)) ;; a StringPort

               (local $i   i32)
               (local $n   i32)
               (local $vec (ref $Vector))
               (local $arr (ref $Array))

               ;; Dispatch by type tag.
               (if (ref.test (ref i31) (local.get $v))
                   (then
                    (local.set $i (i31.get_u (ref.cast (ref i31) (local.get $v))))
                    (if (i32.eqz (i32.and (local.get $i) (i32.const 1)))
                        (then
                         (drop (call $write-byte (global.get $fasl-fixnum) (local.get $out)))
                         (call $fasl:write-u32
                               (i32.shr_u (local.get $i) (i32.const 1))
                               (local.get $out)))
                        (else
                         (call $s-exp->fasl/immediate
                               (local.get $i)
                               (local.get $v)
                               (local.get $out))))
                    (return)))
               (if (ref.test (ref $Bignum) (local.get $v))
                   (then
                    (drop (call $write-byte (global.get $fasl-bignum) (local.get $out)))
                    (call $fasl:write-bignum
                          (ref.cast (ref $Bignum) (local.get $v))
                          (local.get $out))
                    (return)))
               (if (ref.test (ref $Rational) (local.get $v))
                   (then
                    (drop (call $write-byte (global.get $fasl-rational) (local.get $out)))
                    (call $fasl:s-exp->fasl
                          (struct.get $Rational $num
                                      (ref.cast (ref $Rational) (local.get $v)))
                          (local.get $out))
                    (call $fasl:s-exp->fasl
                          (struct.get $Rational $den
                                      (ref.cast (ref $Rational) (local.get $v)))
                          (local.get $out))
                    (return)))
               (if (ref.test (ref $Complex) (local.get $v))
                   (then
                    (drop (call $write-byte (global.get $fasl-complex) (local.get $out)))
                    (call $fasl:s-exp->fasl
                          (struct.get $Complex $real
                                      (ref.cast (ref $Complex) (local.get $v)))
                          (local.get $out))
                    (call $fasl:s-exp->fasl
                          (struct.get $Complex $imag
                                      (ref.cast (ref $Complex) (local.get $v)))
                          (local.get $out))
                    (return)))
               (if (ref.test (ref $String) (local.get $v))
                        (then
                         (drop (call $write-byte (global.get $fasl-string) (local.get $out)))
                         (call $fasl:write-string
                               (ref.cast (ref $String) (local.get $v))
                               (local.get $out)))
                        (else
                         (if (ref.test (ref $Path) (local.get $v))
                             (then
                              ;; JS console logging uses FASL as a transport format.
                              ;; Paths are not a real FASL datum here, so send their
                              ;; existing display rendering as a string.
                              (drop (call $write-byte (global.get $fasl-string) (local.get $out)))
                              (call $fasl:write-string
                                    (call $format/display:path
                                          (ref.cast (ref $Path) (local.get $v)))
                                    (local.get $out)))
                             (else
                              (if (ref.test (ref $Bytes) (local.get $v))
                                  (then
                                   (drop (call $write-byte (global.get $fasl-bytes) (local.get $out)))
                                   (call $fasl:write-bytes
                                         (ref.cast (ref $Bytes) (local.get $v))
                                         (local.get $out)))
                                  (else
                                   (if (ref.test (ref $Symbol) (local.get $v))
                                       (then
                                        (drop (call $write-byte (global.get $fasl-symbol) (local.get $out)))
                                        (call $fasl:write-symbol
                                              (ref.cast (ref $Symbol) (local.get $v))
                                              (local.get $out)))
                                       (else
                                        (if (ref.test (ref $Keyword) (local.get $v))
                                            (then
                                             (drop (call $write-byte (global.get $fasl-keyword) (local.get $out)))
                                             (call $fasl:write-keyword
                                                   (ref.cast (ref $Keyword) (local.get $v))
                                                   (local.get $out)))
                                            (else
                                             (if (ref.test (ref $Flonum) (local.get $v))
                                                 (then
                                                  (drop (call $write-byte (global.get $fasl-flonum) (local.get $out)))
                                                  (call $fasl:write-f64
                                                        (struct.get $Flonum $v
                                                                    (ref.cast (ref $Flonum) (local.get $v)))
                                                        (local.get $out)))
                                                 (else
                                                  (if (ref.test (ref $Pair) (local.get $v))
                                                      (then
                                                       (drop (call $write-byte (global.get $fasl-pair) (local.get $out)))
                                                       (call $fasl:s-exp->fasl
                                                             (struct.get $Pair $a
                                                                         (ref.cast (ref $Pair) (local.get $v)))
                                                             (local.get $out))
                                                       (call $fasl:s-exp->fasl
                                                             (struct.get $Pair $d
                                                                         (ref.cast (ref $Pair) (local.get $v)))
                                                             (local.get $out)))
                                                      (else
                                                       (if (ref.test (ref $Vector) (local.get $v))
                                                           (then
                                                            (local.set $vec (ref.cast (ref $Vector) (local.get $v)))
                                                            (drop (call $write-byte (global.get $fasl-vector) (local.get $out)))
                                                            (local.set $arr (struct.get $Vector $arr (local.get $vec)))
                                                            (local.set $n   (array.len (local.get $arr)))
                                                            (call $fasl:write-u32 (local.get $n) (local.get $out))
                                                            (local.set $i (i32.const 0))
                                                            (block $break
                                                                   (loop $loop
                                                                         (br_if $break
                                                                                (i32.ge_u (local.get $i) (local.get $n)))
                                                                         (call $fasl:s-exp->fasl
                                                                               (array.get $Array
                                                                                          (local.get $arr)
                                                                                          (local.get $i))
                                                                               (local.get $out))
                                                                         (local.set $i
                                                                                    (i32.add (local.get $i)
                                                                                             (i32.const 1)))
                                                                         (br $loop))))
                                                           (else
                                                            (if (ref.test (ref $External) (local.get $v))
                                                                (then
                                                                 (drop (call $write-byte (global.get $fasl-external) (local.get $out)))
                                                                 (call $fasl:write-u32
                                                                       (call $js-register-external
                                                                             (ref.as_non_null
                                                                              (struct.get $External $v
                                                                                          (ref.cast (ref $External)
                                                                                                    (local.get $v)))))
                                                                       (local.get $out)))
                                                                (else
                                                                 (call $raise-s-exp->fasl:unsupported-value
                                                                       (local.get $v))
                                                                 (unreachable))))))))))))))))))))

         (func $s-exp->fasl/immediate
               (param $i   i32)
               (param $v   (ref eq))
               (param $out (ref eq))

               (local $b i32)

               ;; Character immediate
               (if (i32.eq (i32.and (local.get $i) (i32.const ,char-mask)) (i32.const ,char-tag))
                   (then
                    (drop (call $write-byte (global.get $fasl-character) (local.get $out)))
                    (call $fasl:write-u32 (i32.shr_u (local.get $i) (i32.const ,char-shift)) (local.get $out)))
                   (else
                    ;; Boolean immediate
                    (if (i32.eq (i32.and (local.get $i) (i32.const ,boolean-mask)) (i32.const ,boolean-tag))
                        (then
                         (local.set $b (i32.shr_u (local.get $i) (i32.const ,boolean-shift)))
                         (drop (call $write-byte (global.get $fasl-boolean) (local.get $out)))
                         (drop (call $write-byte (ref.i31 (i32.shl (local.get $b) (i32.const 1))) (local.get $out))))
                        (else
                         ;; Null immediate
                         (if (i32.eq (local.get $i) (i32.const ,empty-value))
                             (then
                              (drop (call $write-byte (global.get $fasl-null) (local.get $out))))
                             (else
                              ;; Void immediate
                              (if (i32.eq (local.get $i) (i32.const ,void-value))
                                  (then (drop (call $write-byte (global.get $fasl-void) (local.get $out))))
                                  (else
                                   ;; EOF immediate
                                   (if (i32.eq (local.get $i) (i32.const ,eof-value))
                                       (then (drop (call $write-byte (global.get $fasl-eof) (local.get $out))))
                                       (else (unreachable))))))))))))

         (func $fasl:write-u32
              (param $v i32)
              (param $out (ref eq))

              ;; write the four bytes of $v in big-endian order
              (drop
               (call $write-byte
                     (ref.i31 (i32.shl (i32.and (i32.shr_u (local.get $v) (i32.const 24)) (i32.const 255)) (i32.const 1)))
                     (local.get $out)))
              (drop
               (call $write-byte
                     (ref.i31 (i32.shl (i32.and (i32.shr_u (local.get $v) (i32.const 16)) (i32.const 255)) (i32.const 1)))
                     (local.get $out)))
              (drop
               (call $write-byte
                     (ref.i31 (i32.shl (i32.and (i32.shr_u (local.get $v) (i32.const 8)) (i32.const 255)) (i32.const 1)))
                     (local.get $out)))
              (drop
               (call $write-byte
                     (ref.i31 (i32.shl (i32.and (local.get $v) (i32.const 255)) (i32.const 1)))
                     (local.get $out))))

        ;; fasl:write-bignum : bignum? output-port? -> void?
        ;;   Encode a canonical bignum as sign, limb count, and little-endian limbs.
        (func $fasl:write-bignum
              (param $b   (ref $Bignum))
              (param $out (ref eq))

              (local $limbs (ref $I32Array))
              (local $len   i32)
              (local $i     i32)

              (local.set $limbs (struct.get $Bignum $limbs (local.get $b)))
              (local.set $len (array.len (local.get $limbs)))
              (call $fasl:write-u32
                    (struct.get $Bignum $sign (local.get $b))
                    (local.get $out))
              (call $fasl:write-u32 (local.get $len) (local.get $out))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                           (call $fasl:write-u32
                                 (array.get $I32Array
                                            (local.get $limbs)
                                            (local.get $i))
                                 (local.get $out))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop))))

        (func $fasl:write-bytes
              (param $b   (ref $Bytes))
              (param $out (ref eq))

              (local $arr (ref $I8Array))
              (local $len i32)
              (local $i   i32)
              (local $val i32)

              ;; write length first
              (local.set $arr (struct.get $Bytes $bs (local.get $b)))
              (local.set $len (array.len (local.get $arr)))
              (call $fasl:write-u32 (local.get $len) (local.get $out))

              ;; output each byte
              (local.set $i (i32.const 0))
              (block $done
                     (loop $loop
                           (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                           (local.set $val (call $i8array-ref (local.get $arr) (local.get $i)))
                           (drop (call $write-byte
                                       (ref.i31 (i32.shl (local.get $val) (i32.const 1)))
                                       (local.get $out)))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $loop))))

         (func $fasl:write-string
               (param $s (ref $String))
               (param $out (ref eq))

               (local $bs (ref eq))

               (local.set $bs (call $string->bytes/utf-8 (local.get $s) (global.get $false) (global.get $false) (global.get $false)))
               (call $fasl:write-bytes (ref.cast (ref $Bytes) (local.get $bs)) (local.get $out)))

         (func $fasl:write-symbol
               (param $sym (ref $Symbol))
               (param $out (ref eq))

               (call $fasl:write-string (struct.get $Symbol $name (local.get $sym)) (local.get $out)))

         ;; fasl:write-keyword : keyword? output-port? -> void?
         ;;   Encode a keyword as its underlying string without the "#:" prefix.
         (func $fasl:write-keyword
               (param $kw  (ref $Keyword))
               (param $out (ref eq))

               (call $fasl:write-string
                     (struct.get $Keyword $str (local.get $kw))
                     (local.get $out)))

         (func $fasl:write-f64
               (param $v f64)
               (param $out (ref eq))

               (local $bits i64)
               (local $hi i32)
               (local $lo i32)

               (local.set $bits (i64.reinterpret_f64 (local.get $v)))
               (local.set $hi   (i32.wrap_i64 (i64.shr_u (local.get $bits) (i64.const 32))))
               (local.set $lo   (i32.wrap_i64 (local.get $bits)))
               (call $fasl:write-u32 (local.get $hi) (local.get $out))
               (call $fasl:write-u32 (local.get $lo) (local.get $out))))))

;; fasl-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for FASL decoding helpers.
(define fasl-runtime-only-helper-names
  '($fasl->s-exp
    $fasl:read-u32
    $fasl:read-bytes
    $fasl:read-string
    $fasl:read-symbol
    $fasl:read-f64
    $fasl:read-bignum
    $fasl:read-rational
    $fasl:read-complex
    $fasl:read-s-exp
    $fasl-memory:read-u32
    $fasl-memory:read-bytes
    $fasl-memory:read-string
    $fasl-memory:read-symbol
    $fasl-memory:read-f64
    $fasl-memory:read-bignum
    $fasl-memory:read-rational
    $fasl-memory:read-complex
    $fasl-memory:read-s-exp
    $fasl-memory->s-exp
    $copy-memory-to-i8array
    $linear-memory->value
    $linear-memory->string))

;; fasl-core-runtime-helper-names : (listof symbol?)
;;   Name closed FASL decoding helpers available in the standalone core runtime.
(define fasl-core-runtime-helper-names
  '($fasl:read-u32
    $fasl:read-bytes
    $fasl:read-string
    $fasl:read-symbol
    $fasl:read-f64
    $fasl:read-bignum
    $fasl:read-rational
    $fasl:read-complex
    $fasl:read-s-exp))

;; fasl-runtime-only-forms : (listof datum?)
;;   Enumerate FASL decoding helpers used by the monolithic runtime.
(define fasl-runtime-only-forms
  `(
    (func $fasl->s-exp (type $Prim1)
          ;; entry point: decode byte string
          (param $bs (ref eq))
          (result    (ref eq))

          (local $b   (ref $Bytes))
          (local $arr (ref $I8Array))
          (local $len i32)
          (local $val (ref eq))
          (local $i   i32)

          (if (i32.eqz (ref.test (ref $Bytes) (local.get $bs)))
              (then (call $raise-argument-error1
                          (global.get $symbol:fasl->s-exp)
                          (global.get $string:fasl->s-exp-input)
                          (local.get $bs))
                    (unreachable)))
          (local.set $b   (ref.cast (ref $Bytes) (local.get $bs)))

          (local.set $arr (struct.get $Bytes $bs (local.get $b)))
          (local.set $len (array.len (local.get $arr)))
          (local.set $i   (i32.const 0))
          ;; ; the call returns two values: the decoded value and the index
          (call $fasl:read-s-exp (local.get $arr) (local.get $len) (local.get $i))
          (local.set $i) (local.set $val) ; note: reversed compared to $fasl:read-s-exp

          (local.get $val))


    (func $fasl:read-u32
          ;; read 4 bytes as big-endian u32
          ;; returns value and new index
          (param $arr (ref $I8Array))
          (param $i   i32)
          (result i32 i32)

          (local $b0 i32)
          (local $b1 i32)
          (local $b2 i32)
          (local $b3 i32)

          (local.set $b0 (array.get_u $I8Array (local.get $arr)          (local.get $i)))
          (local.set $b1 (array.get_u $I8Array (local.get $arr) (i32.add (local.get $i) (i32.const 1))))
          (local.set $b2 (array.get_u $I8Array (local.get $arr) (i32.add (local.get $i) (i32.const 2))))
          (local.set $b3 (array.get_u $I8Array (local.get $arr) (i32.add (local.get $i) (i32.const 3))))

          (return (i32.or   (i32.shl (local.get $b0) (i32.const 24))
                            (i32.or  (i32.shl (local.get $b1) (i32.const 16))
                                     (i32.or (i32.shl (local.get $b2) (i32.const  8))
                                             (local.get $b3))))
                  (i32.add (local.get $i) (i32.const 4))))

    (func $fasl:read-bytes
           ;; read length-prefixed byte array
           (param $arr (ref $I8Array))
           (param $i   i32)
           (result     (ref $Bytes) i32)

           (local $len  i32)
           (local $next i32)
           (local $data (ref $I8Array))

           (call $fasl:read-u32 (local.get $arr) (local.get $i))
           (local.set $next) (local.set $len) ; note: reversed

           (local.set $data (call $i8array-copy
                                  (local.get $arr)
                                  (local.get $next)
                                  (i32.add (local.get $next) (local.get $len))))
           (return
            (struct.new $Bytes
                        (i32.const 0)      ; hash
                        (i32.const 1)      ; immutable
                        (local.get $data)) ; I8Array
            (i32.add (local.get $next) (local.get $len))))

    (func $fasl:read-string
          ;; read bytes and convert to string
          (param $arr (ref $I8Array))
          (param $i   i32)
          (result     (ref $String) i32)

          (local $bs   (ref $Bytes))
          (local $next i32)

          (call $fasl:read-bytes (local.get $arr) (local.get $i))
          (local.set $next) (local.set $bs) ; note: reversed

          (return (call $bytes->string/utf-8/checked (local.get $bs))
                  (local.get $next)))

    (func $fasl:read-symbol
          ;; read string and intern symbol
          (param $arr (ref $I8Array))
          (param $i   i32)
          (result     (ref $Symbol) i32)

          (local $str  (ref $String))
          (local $next i32)

          (call $fasl:read-string (local.get $arr) (local.get $i))
          (local.set $next) (local.set $str) ; note: reversed

          (return (ref.cast (ref $Symbol)
                            (call $string->symbol (local.get $str)))
                  (local.get $next)))

    (func $fasl:read-f64
          ;; read IEEE double
          (param $arr (ref $I8Array))
          (param $i   i32)
          (result     (ref $Flonum) i32)

          (local $hi   i32)
          (local $idx  i32)
          (local $lo   i32)
          (local $next i32)
          (local $bits i64)

          (call $fasl:read-u32 (local.get $arr) (local.get $i))
          (local.set $idx) (local.set $hi) ; reversed

          (call $fasl:read-u32 (local.get $arr) (local.get $idx))
          (local.set $next) (local.set $lo) ; reversed

          (local.set $bits
                     (i64.or (i64.shl (i64.extend_i32_u (local.get $hi)) (i64.const 32))
                             (i64.extend_i32_u (local.get $lo))))
          (return
           (struct.new $Flonum
                       (i32.const 0)
                       (f64.reinterpret_i64 (local.get $bits)))
           (local.get $next)))

    ;; fasl:read-bignum : i8-array? i32 -> exact-integer? i32
    ;;   Decode a sign plus little-endian limb payload.
    (func $fasl:read-bignum
          (param $arr (ref $I8Array))
          (param $i   i32)
          (result (ref eq) i32)

          (local $sign  i32)
          (local $len   i32)
          (local $limbs (ref $I32Array))
          (local $j     i32)
          (local $limb  i32)

          (call $fasl:read-u32 (local.get $arr) (local.get $i))
          (local.set $i) (local.set $sign)
          (call $fasl:read-u32 (local.get $arr) (local.get $i))
          (local.set $i) (local.set $len)
          (local.set $limbs (array.new_default $I32Array (local.get $len)))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $j) (local.get $len)))
                       (call $fasl:read-u32 (local.get $arr) (local.get $i))
                       (local.set $i) (local.set $limb)
                       (array.set $I32Array
                                  (local.get $limbs)
                                  (local.get $j)
                                  (local.get $limb))
                       (local.set $j (i32.add (local.get $j) (i32.const 1)))
                       (br $loop)))
          (return (call $bignum-normalize
                        (local.get $sign)
                        (local.get $limbs))
                  (local.get $i)))

    ;; fasl:read-rational : i8-array? i32 i32 -> exact-rational? i32
    ;;   Decode numerator and denominator recursively.
    (func $fasl:read-rational
          (param $arr (ref $I8Array))
          (param $len i32)
          (param $i   i32)
          (result (ref eq) i32)

          (local $num (ref eq))
          (local $den (ref eq))

          (call $fasl:read-s-exp
                (local.get $arr)
                (local.get $len)
                (local.get $i))
          (local.set $i) (local.set $num)
          (call $fasl:read-s-exp
                (local.get $arr)
                (local.get $len)
                (local.get $i))
          (local.set $i) (local.set $den)
          (return (call $rational-normalize
                        (local.get $num)
                        (local.get $den))
                  (local.get $i)))

    ;; fasl:read-complex : i8-array? i32 i32 -> number? i32
    ;;   Decode real and imaginary components recursively.
    (func $fasl:read-complex
          (param $arr (ref $I8Array))
          (param $len i32)
          (param $i   i32)
          (result (ref eq) i32)

          (local $real (ref eq))
          (local $imag (ref eq))

          (call $fasl:read-s-exp
                (local.get $arr)
                (local.get $len)
                (local.get $i))
          (local.set $i) (local.set $real)
          (call $fasl:read-s-exp
                (local.get $arr)
                (local.get $len)
                (local.get $i))
          (local.set $i) (local.set $imag)
          (return (call $make-rectangular/canonical
                        (local.get $real)
                        (local.get $imag))
                  (local.get $i)))

    (func $fasl:read-s-exp
          ;; decode one FASL value by tag
          (param $arr (ref $I8Array))
          (param $len i32)
          (param $i   i32)
          (result (ref eq) i32)

          (local $tag  i32)
          (local $val  i32)
          (local $cp   i32)
          (local $sym  (ref $Symbol))
          (local $kw   (ref $Keyword))
          (local $str  (ref $String))
          (local $bs   (ref $Bytes))
          (local $b    i32)
          (local $car  (ref eq))
          (local $cdr  (ref eq))
          (local $n    i32)
          (local $vec  (ref $Vector))
          (local $j    i32)
          (local $elem (ref eq))
          (local $fl   (ref $Flonum))
          (local $idx  i32)
          (local $obj  (ref eq))

          (local.set $tag (array.get_u $I8Array (local.get $arr) (local.get $i)))
          (local.set $tag (i32.shl (local.get $tag) (i32.const 1))) ; as fixnum
          (local.set $i   (i32.add (local.get $i) (i32.const 1)))

          (if (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-bignum)))
              (then
               (call $fasl:read-bignum (local.get $arr) (local.get $i))
               (local.set $i) (local.set $obj)
               (return (local.get $obj) (local.get $i))))
          (if (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-rational)))
              (then
               (call $fasl:read-rational
                     (local.get $arr)
                     (local.get $len)
                     (local.get $i))
               (local.set $i) (local.set $obj)
               (return (local.get $obj) (local.get $i))))
          (if (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-complex)))
              (then
               (call $fasl:read-complex
                     (local.get $arr)
                     (local.get $len)
                     (local.get $i))
               (local.set $i) (local.set $obj)
               (return (local.get $obj) (local.get $i))))

          (if (result (ref eq) i32)
              (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-fixnum)))
              (then
               (call $fasl:read-u32 (local.get $arr) (local.get $i))
               (local.set $i) (local.set $val)
               (return (ref.i31 (i32.shl (local.get $val) (i32.const 1)))
                       (local.get $i)))
              (else
               (if (result (ref eq) i32)
                   (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-character)))
                   (then
                    (call $fasl:read-u32 (local.get $arr) (local.get $i))
                    (local.set $i) (local.set $cp)
                    (return (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const ,char-shift))
                                             (i32.const ,char-tag)))
                            (local.get $i)))
                   (else
                    (if (result (ref eq) i32)
                        (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-symbol)))
                        (then
                         (call $fasl:read-symbol (local.get $arr) (local.get $i))
                         (local.set $i) (local.set $sym)
                         (return (local.get $sym) (local.get $i)))
                        (else
                         (if (result (ref eq) i32)
                             (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-keyword)))
                             (then
                              (call $fasl:read-string (local.get $arr) (local.get $i))
                              (local.set $i) (local.set $str)
                              (local.set $kw (call $string->keyword/checked (local.get $str)))
                              (return (local.get $kw) (local.get $i)))
                             (else
                              (if (result (ref eq) i32)
                                  (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-string)))
                                  (then
                                   (call $fasl:read-string (local.get $arr) (local.get $i))
                                   (local.set $i) (local.set $str)
                                   (return (local.get $str) (local.get $i)))
                                  (else
                                   (if (result (ref eq) i32)
                                       (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-bytes)))
                                       (then
                                        (call $fasl:read-bytes (local.get $arr) (local.get $i))
                                        (local.set $i) (local.set $bs)
                                        (return (local.get $bs) (local.get $i)))
                                       (else
                                        (if (result (ref eq) i32)
                                            (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-boolean)))
                                            (then
                                             (local.set $b
                                                        (array.get_u $I8Array
                                                                     (local.get $arr)
                                                                     (local.get $i)))
                                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                             (return (if (result (ref eq))
                                                         (i32.ne (local.get $b) (i32.const 0))
                                                         (then (global.get $true))
                                                         (else (global.get $false)))
                                                     (local.get $i)))
                                            (else
                                             (if (result (ref eq) i32)
                                                 (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-null)))
                                                 (then
                                                  (return (global.get $null) (local.get $i)))
                                                 (else
                                                  (if (result (ref eq) i32)
                                                      (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-pair)))
                                                      (then
                                                       (call $fasl:read-s-exp
                                                             (local.get $arr)
                                                             (local.get $len)
                                                             (local.get $i))
                                                       (local.set $i) (local.set $car)
                                                       (call $fasl:read-s-exp
                                                             (local.get $arr)
                                                             (local.get $len)
                                                             (local.get $i))
                                                       (local.set $i) (local.set $cdr)
                                                       (return (call $cons (local.get $car) (local.get $cdr))
                                                               (local.get $i)))
                                                      (else
                                                       (if (result (ref eq) i32)
                                                           (i32.eq (local.get $tag)
                                                                   (i31.get_u (global.get $fasl-vector)))
                                                           (then
                                                            (call $fasl:read-u32
                                                                  (local.get $arr)
                                                                  (local.get $i))
                                                            (local.set $i) (local.set $n)
                                                            (local.set $vec
                                                                       (call $make-vector/checked
                                                                             (local.get $n)
                                                                             (global.get $void)))
                                                            (local.set $j (i32.const 0))
                                                            (block $done
                                                                   (loop $loop
                                                                         (br_if $done
                                                                                (i32.ge_u (local.get $j)
                                                                                          (local.get $n)))
                                                                         (call $fasl:read-s-exp
                                                                               (local.get $arr)
                                                                               (local.get $len)
                                                                               (local.get $i))
                                                                         (local.set $i) (local.set $elem)
                                                                         (call $vector-set!/checked
                                                                               (local.get $vec)
                                                                               (local.get $j)
                                                                               (local.get $elem))
                                                                         (local.set $j
                                                                                    (i32.add (local.get $j)
                                                                                             (i32.const 1)))
                                                                         (br $loop)))
                                                            (return (local.get $vec) (local.get $i)))
                                                           (else
                                                            (if (result (ref eq) i32)
                                                                (i32.eq (local.get $tag)
                                                                        (i31.get_u (global.get $fasl-flonum)))
                                                                (then
                                                                 (call $fasl:read-f64
                                                                       (local.get $arr)
                                                                       (local.get $i))
                                                                 (local.set $i) (local.set $fl)
                                                                 (return (local.get $fl) (local.get $i)))
                                                                (else
                                                                 (if (result (ref eq) i32)
                                                                     (i32.eq (local.get $tag)
                                                                             (i31.get_u (global.get $fasl-void)))
                                                                     (then
                                                                      (return (global.get $void)
                                                                              (local.get $i)))
                                                                     (else
                                                                      (if (result (ref eq) i32)
                                                                          (i32.eq (local.get $tag)
                                                                                  (i31.get_u (global.get $fasl-eof)))
                                                                          (then
                                                                           (return (ref.i31 (i32.const ,eof-value))
                                                                                   (local.get $i)))
                                                                          (else
                                                                           (if (result (ref eq) i32)
                                                                               (i32.eq (local.get $tag)
                                                                                       (i31.get_u (global.get $fasl-external)))
                                                                               (then
                                                                                (call $fasl:read-u32
                                                                                      (local.get $arr)
                                                                                      (local.get $i))
                                                                                (local.set $i) (local.set $idx)
                                                                                (return (struct.new $External
                                                                                                    (i32.const 0)
                                                                                                    (call $js-lookup-external
                                                                                                          (local.get $idx)))
                                                                                        (local.get $i)))
                                                                               (else
                                                                                (unreachable))))))))))))))))))))))))))))))

    ;; Decode FASL data directly from linear memory.
    (func $fasl-memory:read-u32
          (param $i i32)
          (result i32 i32)

          (local $b0 i32)
          (local $b1 i32)
          (local $b2 i32)
          (local $b3 i32)

          (local.set $b0 (i32.load8_u (local.get $i)))
          (local.set $b1 (i32.load8_u (i32.add (local.get $i) (i32.const 1))))
          (local.set $b2 (i32.load8_u (i32.add (local.get $i) (i32.const 2))))
          (local.set $b3 (i32.load8_u (i32.add (local.get $i) (i32.const 3))))

          (return (i32.or   (i32.shl (local.get $b0) (i32.const 24))
                            (i32.or  (i32.shl (local.get $b1) (i32.const 16))
                                     (i32.or (i32.shl (local.get $b2) (i32.const  8))
                                             (local.get $b3))))
                  (i32.add (local.get $i) (i32.const 4))))

    (func $fasl-memory:read-bytes
          (param $i i32)
          (result (ref $Bytes) i32)

          (local $len  i32)
          (local $next i32)
          (local $data (ref $I8Array))
          (local $j    i32)

          (call $fasl-memory:read-u32 (local.get $i))
          (local.set $next) (local.set $len)

          (local.set $data (array.new_default $I8Array (local.get $len)))
          (local.set $j (i32.const 0))
          (block $done
                 (loop $copy
                       (br_if $done (i32.ge_u (local.get $j) (local.get $len)))
                       (array.set $I8Array (local.get $data) (local.get $j)
                                  (i32.load8_u
                                   (i32.add (local.get $next) (local.get $j))))
                       (local.set $j (i32.add (local.get $j) (i32.const 1)))
                       (br $copy)))

          (return (struct.new $Bytes
                               (i32.const 0)
                               (i32.const 1)
                               (local.get $data))
                  (i32.add (local.get $next) (local.get $len))))

    (func $fasl-memory:read-string
          (param $i i32)
          (result (ref $String) i32)

          (local $bs   (ref $Bytes))
          (local $next i32)

          (call $fasl-memory:read-bytes (local.get $i))
          (local.set $next) (local.set $bs)

          (return (call $bytes->string/utf-8/checked (local.get $bs))
                  (local.get $next)))

    (func $fasl-memory:read-symbol
          (param $i i32)
          (result (ref $Symbol) i32)

          (local $str  (ref $String))
          (local $next i32)

          (call $fasl-memory:read-string (local.get $i))
          (local.set $next) (local.set $str)

          (return (ref.cast (ref $Symbol)
                            (call $string->symbol (local.get $str)))
                  (local.get $next)))

    (func $fasl-memory:read-f64
          (param $i i32)
          (result (ref $Flonum) i32)

          (local $hi   i32)
          (local $idx  i32)
          (local $lo   i32)
          (local $next i32)
          (local $bits i64)

          (call $fasl-memory:read-u32 (local.get $i))
          (local.set $idx) (local.set $hi)

          (call $fasl-memory:read-u32 (local.get $idx))
          (local.set $next) (local.set $lo)

          (local.set $bits
                     (i64.or (i64.shl (i64.extend_i32_u (local.get $hi)) (i64.const 32))
                             (i64.extend_i32_u (local.get $lo))))

          (return (struct.new $Flonum
                              (i32.const 0)
                              (f64.reinterpret_i64 (local.get $bits)))
                  (local.get $next)))

    ;; fasl-memory:read-bignum : i32 -> exact-integer? i32
    ;;   Decode a sign plus little-endian limb payload from linear memory.
    (func $fasl-memory:read-bignum
          (param $i i32)
          (result (ref eq) i32)

          (local $sign  i32)
          (local $len   i32)
          (local $limbs (ref $I32Array))
          (local $j     i32)
          (local $limb  i32)

          (call $fasl-memory:read-u32 (local.get $i))
          (local.set $i) (local.set $sign)
          (call $fasl-memory:read-u32 (local.get $i))
          (local.set $i) (local.set $len)
          (local.set $limbs (array.new_default $I32Array (local.get $len)))
          (block $done
                 (loop $loop
                       (br_if $done (i32.ge_u (local.get $j) (local.get $len)))
                       (call $fasl-memory:read-u32 (local.get $i))
                       (local.set $i) (local.set $limb)
                       (array.set $I32Array
                                  (local.get $limbs)
                                  (local.get $j)
                                  (local.get $limb))
                       (local.set $j (i32.add (local.get $j) (i32.const 1)))
                       (br $loop)))
          (return (call $bignum-normalize
                        (local.get $sign)
                        (local.get $limbs))
                  (local.get $i)))

    ;; fasl-memory:read-rational : i32 -> exact-rational? i32
    ;;   Decode numerator and denominator recursively from linear memory.
    (func $fasl-memory:read-rational
          (param $i i32)
          (result (ref eq) i32)

          (local $num (ref eq))
          (local $den (ref eq))

          (call $fasl-memory:read-s-exp (local.get $i))
          (local.set $i) (local.set $num)
          (call $fasl-memory:read-s-exp (local.get $i))
          (local.set $i) (local.set $den)
          (return (call $rational-normalize
                        (local.get $num)
                        (local.get $den))
                  (local.get $i)))

    ;; fasl-memory:read-complex : i32 -> number? i32
    ;;   Decode real and imaginary components recursively from linear memory.
    (func $fasl-memory:read-complex
          (param $i i32)
          (result (ref eq) i32)

          (local $real (ref eq))
          (local $imag (ref eq))

          (call $fasl-memory:read-s-exp (local.get $i))
          (local.set $i) (local.set $real)
          (call $fasl-memory:read-s-exp (local.get $i))
          (local.set $i) (local.set $imag)
          (return (call $make-rectangular/canonical
                        (local.get $real)
                        (local.get $imag))
                  (local.get $i)))

    (func $fasl-memory:read-s-exp
          (param $i i32)
          (result (ref eq) i32)

          (local $tag  i32)
          (local $val  i32)
          (local $cp   i32)
          (local $sym  (ref $Symbol))
          (local $kw   (ref $Keyword))
          (local $str  (ref $String))
          (local $bs   (ref $Bytes))
          (local $b    i32)
          (local $car  (ref eq))
          (local $cdr  (ref eq))
          (local $n    i32)
          (local $vec  (ref $Vector))
          (local $j    i32)
          (local $elem (ref eq))
          (local $fl   (ref $Flonum))
          (local $idx  i32)
          (local $obj  (ref eq))

          (local.set $tag (i32.load8_u (local.get $i)))
          (local.set $tag (i32.shl (local.get $tag) (i32.const 1)))
          (local.set $i   (i32.add (local.get $i) (i32.const 1)))

          (if (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-bignum)))
              (then
               (call $fasl-memory:read-bignum (local.get $i))
               (local.set $i) (local.set $obj)
               (return (local.get $obj) (local.get $i))))
          (if (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-rational)))
              (then
               (call $fasl-memory:read-rational (local.get $i))
               (local.set $i) (local.set $obj)
               (return (local.get $obj) (local.get $i))))
          (if (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-complex)))
              (then
               (call $fasl-memory:read-complex (local.get $i))
               (local.set $i) (local.set $obj)
               (return (local.get $obj) (local.get $i))))

          (if (result (ref eq) i32)
              (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-fixnum)))
              (then
               (call $fasl-memory:read-u32 (local.get $i))
               (local.set $i) (local.set $val)
               (return (ref.i31 (i32.shl (local.get $val) (i32.const 1)))
                       (local.get $i)))
              (else
               (if (result (ref eq) i32)
                   (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-character)))
                   (then
                    (call $fasl-memory:read-u32 (local.get $i))
                    (local.set $i) (local.set $cp)
                    (return (ref.i31 (i32.or (i32.shl (local.get $cp) (i32.const ,char-shift))
                                             (i32.const ,char-tag)))
                            (local.get $i)))
                   (else
                    (if (result (ref eq) i32)
                        (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-symbol)))
                        (then
                         (call $fasl-memory:read-symbol (local.get $i))
                         (local.set $i) (local.set $sym)
                         (return (local.get $sym) (local.get $i)))
                        (else
                         (if (result (ref eq) i32)
                             (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-keyword)))
                             (then
                              (call $fasl-memory:read-string (local.get $i))
                              (local.set $i) (local.set $str)
                              (local.set $kw (call $string->keyword/checked (local.get $str)))
                              (return (local.get $kw) (local.get $i)))
                             (else
                              (if (result (ref eq) i32)
                                  (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-string)))
                                  (then
                                   (call $fasl-memory:read-string (local.get $i))
                                   (local.set $i) (local.set $str)
                                   (return (local.get $str) (local.get $i)))
                                  (else
                                   (if (result (ref eq) i32)
                                       (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-bytes)))
                                       (then
                                        (call $fasl-memory:read-bytes (local.get $i))
                                        (local.set $i) (local.set $bs)
                                        (return (local.get $bs) (local.get $i)))
                                       (else
                                        (if (result (ref eq) i32)
                                            (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-boolean)))
                                            (then
                                             (local.set $b (i32.load8_u (local.get $i)))
                                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                             (return (if (result (ref eq))
                                                         (i32.ne (local.get $b) (i32.const 0))
                                                         (then (global.get $true))
                                                         (else (global.get $false)))
                                                     (local.get $i)))
                                            (else
                                             (if (result (ref eq) i32)
                                                 (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-null)))
                                                 (then
                                                  (return (global.get $null) (local.get $i)))
                                                 (else
                                                  (if (result (ref eq) i32)
                                                      (i32.eq (local.get $tag) (i31.get_u (global.get $fasl-pair)))
                                                      (then
                                                       (call $fasl-memory:read-s-exp (local.get $i))
                                                       (local.set $i) (local.set $car)
                                                       (call $fasl-memory:read-s-exp (local.get $i))
                                                       (local.set $i) (local.set $cdr)
                                                       (return (call $cons (local.get $car) (local.get $cdr))
                                                               (local.get $i)))
                                                      (else
                                                       (if (result (ref eq) i32)
                                                           (i32.eq (local.get $tag)
                                                                   (i31.get_u (global.get $fasl-vector)))
                                                           (then
                                                            (call $fasl-memory:read-u32 (local.get $i))
                                                            (local.set $i) (local.set $n)
                                                            (local.set $vec
                                                                       (call $make-vector/checked
                                                                             (local.get $n)
                                                                             (global.get $void)))
                                                            (local.set $j (i32.const 0))
                                                            (block $done
                                                                   (loop $loop
                                                                         (br_if $done
                                                                                (i32.ge_u (local.get $j)
                                                                                          (local.get $n)))
                                                                         (call $fasl-memory:read-s-exp
                                                                               (local.get $i))
                                                                         (local.set $i) (local.set $elem)
                                                                         (call $vector-set!/checked
                                                                               (local.get $vec)
                                                                               (local.get $j)
                                                                               (local.get $elem))
                                                                         (local.set $j
                                                                                    (i32.add (local.get $j)
                                                                                             (i32.const 1)))
                                                                         (br $loop)))
                                                            (return (local.get $vec) (local.get $i)))
                                                           (else
                                                            (if (result (ref eq) i32)
                                                                (i32.eq (local.get $tag)
                                                                        (i31.get_u (global.get $fasl-flonum)))
                                                                (then
                                                                 (call $fasl-memory:read-f64 (local.get $i))
                                                                 (local.set $i) (local.set $fl)
                                                                 (return (local.get $fl) (local.get $i)))
                                                                (else
                                                                 (if (result (ref eq) i32)
                                                                     (i32.eq (local.get $tag)
                                                                             (i31.get_u (global.get $fasl-void)))
                                                                     (then
                                                                      (return (global.get $void)
                                                                              (local.get $i)))
                                                                     (else
                                                                      (if (result (ref eq) i32)
                                                                          (i32.eq (local.get $tag)
                                                                                  (i31.get_u (global.get $fasl-eof)))
                                                                          (then
                                                                           (return (ref.i31 (i32.const ,eof-value))
                                                                                   (local.get $i)))
                                                                          (else
                                                                           (if (result (ref eq) i32)
                                                                               (i32.eq (local.get $tag)
                                                                                       (i31.get_u (global.get $fasl-external)))
                                                                               (then
                                                                                (call $fasl-memory:read-u32 (local.get $i))
                                                                                (local.set $i) (local.set $idx)
                                                                                (return (struct.new $External
                                                                                                    (i32.const 0)
                                                                                                    (call $js-lookup-external
                                                                                                          (local.get $idx)))
                                                                                        (local.get $i)))
                                                                               (else
                                                                                (unreachable))))))))))))))))))))))))))))))

    (func $fasl-memory->s-exp
          (param $start i32)
          (result (ref eq))

          (local $val (ref eq))
          (local $end i32)

          (call $fasl-memory:read-s-exp (local.get $start))
          (local.set $end) (local.set $val)

          (local.get $val))


    (func $copy-memory-to-i8array (export "copy-memory-to-i8array")
          (param $start i32)
          (result (ref $I8Array) i32)

          (local $mem-bytes i32)
          (local $len       i32)
          (local $arr       (ref $I8Array))
          (local $i         i32)
          (local $end       i32)
          (local $res       (ref $I8Array))

          ; The Performance tab in Chrome shows that we are spending way too much time here.
          ; It is called from linear-memory->value.
          ; Why are we copying linear memory?

          ; memory.size returns number of pages. The page size is 64 KiB = 65536.
          (local.set $mem-bytes (i32.mul (memory.size) (i32.const 65536)))
          (local.set $len       (i32.sub (local.get $mem-bytes) (local.get $start)))
          (local.set $arr       (array.new_default $I8Array (local.get $len)))
          (local.set $i         (i32.const 0))
          ; Note: Currently (sep 2025) there are no bulk copy operations from
          ;       memory to array. So the loop can't be replaced with bulk copy.
          (block $done
                 (loop $copy
                       (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                       (array.set $I8Array (local.get $arr) (local.get $i)
                                  (i32.load8_u
                                   (i32.add (local.get $start) (local.get $i))))
                       (local.set $i (i32.add (local.get $i) (i32.const 1)))
                       (br $copy)))

          (call $fasl:read-s-exp (local.get $arr) (local.get $len) (i32.const 0))
          (local.set $end) (drop)

          (local.set $res (call $i8array-copy (local.get $arr) (i32.const 0) (local.get $end)))
          (return (local.get $res) (i32.add (local.get $start) (local.get $end))))

    (func $linear-memory->value (export "linear-memory->value")
          (param $start i32)
          (result (ref eq))

          (local $val (ref eq))

          (local.set $val (call $fasl-memory->s-exp (local.get $start)))
          (local.get $val))

    (func $linear-memory->string (export "linear-memory->string")
          (param $start i32)
          (result (ref eq))

          (local $v (ref eq))

          (local.set $v (call $linear-memory->value (local.get $start)))
          (if (i32.eqz (ref.test (ref $String) (local.get $v)))
              (then (call $raise-argument-error1
                          (global.get $symbol:linear-memory->string)
                          (global.get $string:string?)
                          (local.get $v))
                    (unreachable)))
          (return (ref.cast (ref $String) (local.get $v))))))

;; fasl-decoding-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate FASL decoding helpers used by the monolithic runtime.
(define fasl-decoding-runtime-only-helpers
  (function-forms->runtime-helpers
   'fasl-decoding-runtime-only-helpers
   fasl-runtime-only-forms))

;; fasl-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate FASL helpers available in the standalone core runtime.
(define fasl-core-runtime-helpers
  (select-runtime-helpers fasl-decoding-runtime-only-helpers
                          fasl-core-runtime-helper-names))

;; fasl-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate all FASL function helpers used by the monolithic runtime.
(define fasl-runtime-only-helpers
  (append fasl-encoding-runtime-only-helpers
          fasl-decoding-runtime-only-helpers))

;; fasl-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given FASL helper names from the runtime helper index.
(define (fasl-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; fasl-tag-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render FASL tag globals in runtime assembly order.
(define (fasl-tag-runtime-helper-forms helper-index)
  fasl-tag-global-forms)

;; fasl-encoding-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render FASL encoding helpers in runtime assembly order.
(define (fasl-encoding-runtime-helper-forms helper-index)
  (fasl-helper-forms helper-index fasl-encoding-runtime-only-helper-names))

;; fasl-decoding-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render FASL decoding helpers in runtime assembly order.
(define (fasl-decoding-runtime-helper-forms helper-index)
  (fasl-helper-forms helper-index fasl-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the global or function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define fasl-helper-index
    (make-core-runtime-helper-index fasl-runtime-only-helpers))

  (check-equal?
   (map form-name (fasl-tag-runtime-helper-forms fasl-helper-index))
   fasl-tag-global-names)

  (check-equal?
   (map form-name (fasl-encoding-runtime-helper-forms fasl-helper-index))
   fasl-encoding-runtime-only-helper-names)

  (check-equal?
   (map form-name (fasl-decoding-runtime-helper-forms fasl-helper-index))
   fasl-runtime-only-helper-names))
