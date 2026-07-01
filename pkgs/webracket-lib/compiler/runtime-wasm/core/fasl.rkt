#lang racket

(provide fasl-runtime-only-helpers
         fasl-runtime-only-helper-names)

(require "../core-helper.rkt"
         (only-in "../../private/immediates.rkt"
                  char-shift
                  char-tag
                  eof-value))

;; fasl-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for FASL decoding helpers.
(define fasl-runtime-only-helper-names
  '($fasl->s-exp
    $fasl:read-u32
    $fasl:read-bytes
    $fasl:read-string
    $fasl:read-symbol
    $fasl:read-f64
    $fasl:read-s-exp
    $fasl-memory:read-u32
    $fasl-memory:read-bytes
    $fasl-memory:read-string
    $fasl-memory:read-symbol
    $fasl-memory:read-f64
    $fasl-memory:read-s-exp
    $fasl-memory->s-exp
    $copy-memory-to-i8array
    $linear-memory->value
    $linear-memory->string))

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
              (then (call $raise-argument-error/internal (local.get $bs))
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

          (local.set $tag (array.get_u $I8Array (local.get $arr) (local.get $i)))
          (local.set $tag (i32.shl (local.get $tag) (i32.const 1))) ; as fixnum
          (local.set $i   (i32.add (local.get $i) (i32.const 1)))

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

          (local.set $tag (i32.load8_u (local.get $i)))
          (local.set $tag (i32.shl (local.get $tag) (i32.const 1)))
          (local.set $i   (i32.add (local.get $i) (i32.const 1)))

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
              (then (call $raise-expected-string)
                    (unreachable)))
          (return (ref.cast (ref $String) (local.get $v))))))

;; fasl-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate FASL decoding helpers used by the monolithic runtime.
(define fasl-runtime-only-helpers
  (function-forms->runtime-helpers
   'fasl-runtime-only-helpers
   fasl-runtime-only-forms))
