#lang racket

(provide bytes-core-runtime-helpers
         bytes-basic-runtime-only-helper-names
         bytes-mutability-runtime-only-helper-names
         bytes-runtime-only-helpers)

(require "../core-helper.rkt")

;; bytes-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate byte helpers that can be emitted in core runtime.
(define bytes-core-runtime-helpers
  (list
   (core-runtime-helper
    '$i8array->bytes
    "$i8array->bytes"
    (lambda ()
      `(func $i8array->bytes (param $arr (ref $I8Array)) (result (ref $Bytes))
             ;; Constructs a mutable $Bytes object (immutable = 0, hash = 0).
             (struct.new $Bytes
                         (i32.const 0)      ;; hash = 0
                         (i32.const 0)      ;; immutable = false
                         (local.get $arr))))) ;; the backing I8Array

   (core-runtime-helper
    '$i8array->immutable-bytes
    "$i8array->immutable-bytes"
    (lambda ()
      `(func $i8array->immutable-bytes (param $arr (ref $I8Array))
             (result (ref $Bytes))
             ;; Constructs an immutable $Bytes object (immutable = 1, hash = 0).
             (struct.new $Bytes
                         (i32.const 0)      ;; hash = 0
                         (i32.const 1)      ;; immutable = true
                         (local.get $arr))))))) ;; the backing I8Array

;; bytes-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for bytes mutability predicates.
(define bytes-mutability-runtime-only-helper-names
  '($mutable-bytes?
    $immutable-bytes?))

;; bytes-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic byte-string helpers.
(define bytes-basic-runtime-only-helper-names
  '($raise-byte-out-of-range
    $raise-check-bytes
    $raise-check-byte
    $raise-bad-bytes-ref-index
    $raise-bad-bytes-set-index
    $raise-bad-bytes-range
    $make-bytes
    $bytes
    $bytes->immutable-bytes
    $datum-intern-literal
    $bytes-length
    $bytes?
    $raise-expected-bytes))

;; bytes-basic-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate basic byte-string helpers used by the monolithic runtime.
(define bytes-basic-runtime-only-helpers
  (function-forms->runtime-helpers
   'bytes-basic-runtime-only-helpers
   '(
     (func $raise-byte-out-of-range (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:byte?)
                 (global.get $string:byte?)
                 (local.get $x)))
     (func $raise-check-bytes (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:bytes?)
                 (global.get $string:bytes?)
                 (local.get $x)))
     (func $raise-check-byte (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:byte?)
                 (global.get $string:byte?)
                 (local.get $x)))
     ;; Out-of-range byte-string indexes must be catchable Racket errors,
     ;; not raw Wasm traps.
     (func $raise-bad-bytes-ref-index (param $x (ref eq)) (param $idx (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:bytes-ref)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $idx)))
     (func $raise-bad-bytes-set-index (param $x (ref eq)) (param $idx (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:bytes-set!)
                 (global.get $string:exact-nonnegative-integer?)
                 (local.get $idx)))
     (func $raise-bad-bytes-range     (param $x (ref eq)) (param $from i32) (param $to i32)
           (call $raise-argument-error1
                 (global.get $symbol:subbytes)
                 (global.get $string:exact-nonnegative-integer?)
                 (ref.i31 (i32.shl (local.get $from) (i32.const 1)))))

     (func $make-bytes (type $Prim12)
           (param $k-raw (ref eq))     ;; fixnum
           (param $b-raw (ref eq))     ;; optional byte
           (result       (ref eq))

           (local $len i32)
           (local $val i32)
           ;; Decode and check $k as fixnum
           (if (ref.test (ref i31) (local.get $k-raw))
               (then (local.set $len (i31.get_u (ref.cast (ref i31) (local.get $k-raw))))
                     (if (i32.eqz (i32.and (local.get $len) (i32.const 1)))
                         (then (local.set $len (i32.shr_u (local.get $len) (i32.const 1))))
                         (else (call $raise-check-fixnum (local.get $k-raw))
                               (unreachable))))
               (else (call $raise-check-fixnum (local.get $k-raw))
                     (unreachable)))
           ;; Handle optional byte argument
           (if (ref.eq (local.get $b-raw) (global.get $missing))
               (then (local.set $val (i32.const 0)))
               (else (if (ref.test (ref i31) (local.get $b-raw))
                         (then (local.set $val (i31.get_u (ref.cast (ref i31) (local.get $b-raw))))
                               (if (i32.eqz (i32.and (local.get $val) (i32.const 1)))
                                   (then (local.set $val (i32.shr_u (local.get $val) (i32.const 1)))
                                         (if (i32.gt_u (local.get $val) (i32.const 255))
                                             (then (call $raise-byte-out-of-range (local.get $b-raw))
                                                   (unreachable))))
                                   (else (call $raise-check-fixnum (local.get $b-raw))
                                         (unreachable))))
                         (else (call $raise-check-fixnum (local.get $b-raw))
                               (unreachable)))))
           ;; Construct mutable bytes object
           (call $debug-allocation-tick (i32.const 7))
           (struct.new $Bytes
                       (i32.const 0)  ;; hash
                       (i32.const 0)  ;; immutable = false
                       (call $i8make-array (local.get $len) (local.get $val))))


     (func $bytes (type $Prim>=0) ; handles both $Args and list rest arguments
           (param $args (ref eq))
           (result      (ref eq))

           (local $as        (ref $Args))
           (local $len       i32)
           (local $arr       (ref $I8Array))
           (local $i         i32)
           (local $x         (ref eq))
           (local $v         i32)
           (local $use-args? i32)
           (local $list      (ref eq))
           (local $node      (ref eq))
           (local $pair      (ref $Pair))

           ;; Initialize non-defaultable locals
           (local.set $as (array.new $Args (global.get $null) (i32.const 0)))
           (local.set $x  (global.get $false))

           ;; Determine whether we received an $Args array or a list of rest arguments.
           (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
           (local.set $list      (global.get $null))
           (local.set $node      (global.get $null))
           (local.set $len       (if (result i32) (local.get $use-args?)
                                     (then
                                      (local.set $as (ref.cast (ref $Args) (local.get $args)))
                                      (array.len (local.get $as)))
                                     (else
                                      (local.set $list (local.get $args))
                                      (local.set $node (local.get $list))
                                      (call $length/i32 (local.get $list)))))
           ;; Allocate mutable byte array
           (local.set $arr (call $i8make-array (local.get $len) (i32.const 0)))
           ;; Populate array from arguments or list elements
           (local.set $i (i32.const 0))
           (block $done
                  (if (i32.eqz (local.get $use-args?))
                      (then
                       (loop $loop-list
                             (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                             (if (ref.test (ref $Pair) (local.get $node))
                                 (then
                                  (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                                  (local.set $x    (struct.get $Pair $a (local.get $pair)))
                                  (local.set $node (struct.get $Pair $d (local.get $pair))))
                                 (else
                                  (call $raise-pair-expected (local.get $node))
                                  (unreachable)))
                             (if (ref.test (ref i31) (local.get $x))
                                 (then
                                  (local.set $v (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                  (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
                                      (then
                                       (local.set $v (i32.shr_u (local.get $v) (i32.const 1)))
                                       (if (i32.lt_u (local.get $v) (i32.const 256))
                                           (then
                                            (call $i8array-set! (local.get $arr) (local.get $i) (local.get $v)))
                                           (else
                                            (call $raise-byte-out-of-range (local.get $x))
                                            (unreachable))))
                                      (else
                                       (call $raise-check-fixnum (local.get $x))(unreachable)))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $loop-list)))))
                      (else
                       (loop $loop-args
                             (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                             (local.set $x (array.get $Args (local.get $as) (local.get $i)))
                             (if (ref.test (ref i31) (local.get $x))
                                 (then
                                  (local.set $v (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                  (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
                                      (then
                                       (local.set $v (i32.shr_u (local.get $v) (i32.const 1)))
                                       (if (i32.lt_u (local.get $v) (i32.const 256))
                                           (then
                                            (call $i8array-set! (local.get $arr) (local.get $i) (local.get $v)))
                                           (else
                                            (call $raise-byte-out-of-range (local.get $x))
                                            (unreachable))))
                                      (else
                                       (call $raise-check-fixnum (local.get $x))
                                       (unreachable))))
                                 (else
                                  (call $raise-check-fixnum (local.get $x))
                                  (unreachable)))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $loop-args)))))
           ;; Wrap in Bytes struct and return
           (struct.new $Bytes
                       (i32.const 0)
                       (i32.const 0)
                       (local.get $arr)))


     (func $bytes->immutable-bytes (type $Prim1) (param $b (ref eq)) (result (ref eq))
          (local $bs (ref $Bytes))
          (local.set $bs (ref.cast (ref $Bytes) (global.get $bytes:empty)))
          ;; 1. Check that b is a byte string
          (if (ref.test (ref $Bytes) (local.get $b))
              (then (local.set $bs (ref.cast (ref $Bytes) (local.get $b))))
              (else (call $raise-check-bytes (local.get $b))
                    (unreachable)))
          ;; 2. If already immutable, return it directly
          (if (result (ref eq))
              (i32.eq (struct.get $Bytes $immutable (local.get $bs)) (i32.const 1))
              (then (local.get $bs))
              (else
               (struct.new $Bytes
                           (struct.get $Bytes $hash (local.get $bs))  ;; inherit hash
                           (i32.const 1)                                ;; immutable
                           (call $i8array-copy
                                 (struct.get $Bytes $bs (local.get $bs))
                                 (i32.const 0)
                                 (call $i8array-length (struct.get $Bytes $bs (local.get $bs))))))))

     ;; datum-intern-literal : any/c -> any/c
     ;;   Bootstrap approximation of Racket CS literal interning. Racket
     ;;   interns immutable strings, immutable bytes, non-fixnum numbers,
     ;;   and optionally regexps using a weak table. WebRacket does not yet
     ;;   provide that weak interning table, so this preserves the value
     ;;   while coercing mutable strings/bytes to immutable copies.
     (func $datum-intern-literal (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))
           (if (ref.test (ref $String) (local.get $v))
               (then (return (call $string->immutable-string (local.get $v)))))
           (if (ref.test (ref $Bytes) (local.get $v))
               (then (return (call $bytes->immutable-bytes (local.get $v)))))
           (local.get $v))

     (func $bytes-length (type $Prim1) (param $a (ref eq)) (result (ref eq))
           (local $bs  (ref null $Bytes))
           (local $arr (ref $I8Array))
           (local $len i32)
           ;; Check that $a is a byte string
           (if (ref.test (ref $Bytes) (local.get $a))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $a))))
               (else (call $raise-check-bytes (local.get $a))
                     (unreachable)))
           ;; Get the backing array and compute length
           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (local.set $len (call $i8array-length (local.get $arr)))
           ;; Convert to fixnum and return
           (ref.i31 (i32.shl (local.get $len) (i32.const 1))))

     (func $bytes? (type $Prim1) (param $a (ref eq)) (result (ref eq))
           (if (result (ref eq)) (ref.test (ref $Bytes) (local.get $a))
               (then (global.get $true))
               (else (global.get $false))))

     (func $raise-expected-bytes (unreachable))

     )))

;; bytes-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate bytes helpers that still depend on monolithic runtime globals.
(define bytes-runtime-only-helpers
  (append
   bytes-basic-runtime-only-helpers
   (function-forms->runtime-helpers
    'bytes-runtime-only-helpers
    '(
         (func $mutable-bytes? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Bytes) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Bytes $immutable
                                                 (ref.cast (ref $Bytes) (local.get $v)))
                                     (i32.const 0))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))

         (func $immutable-bytes? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (ref.test (ref $Bytes) (local.get $v))
                   (then (if (result (ref eq))
                             (i32.eq (struct.get $Bytes $immutable
                                                 (ref.cast (ref $Bytes) (local.get $v)))
                                     (i32.const 1))
                             (then (global.get $true))
                             (else (global.get $false))))
                   (else (global.get $false))))


     ))))
