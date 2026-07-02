#lang racket

(provide bytes-core-runtime-helpers
         bytes-basic-runtime-only-helper-names
         byte-comparison-runtime-only-helper-names
         byte-indexing-runtime-only-helper-names
         byte-sequence-runtime-only-helper-names
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

;; byte-comparison-specs : (listof list?)
;;   Declare the generated byte-string comparison helper families.
(define byte-comparison-specs
  '(($bytes=? i32.eq   eq   #t)
    ($bytes<? i32.lt_u ord  #f)
    ($bytes>? i32.gt_u ord  #f)))

;; byte-comparison-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for byte-string comparison helpers.
(define byte-comparison-runtime-only-helper-names
  (append*
   (for/list ([spec (in-list byte-comparison-specs)])
     (define name (list-ref spec 0))
     (list (string->symbol (~a name "/2"))
           (string->symbol (~a name "/2/checked"))
           (string->symbol (~a name "/checked"))
           name))))

;; byte-comparison-runtime-only-forms : (listof datum?)
;;   Generate byte-string comparison helper forms.
(define byte-comparison-runtime-only-forms
  (append*
   (for/list ([spec (in-list byte-comparison-specs)])
     (define name           (list-ref spec 0))
     (define cmp            (list-ref spec 1))
     (define kind           (list-ref spec 2))
     (define signed?        (list-ref spec 3))
     (define name/2         (string->symbol (~a name "/2")))
     (define name/2/checked (string->symbol (~a name "/2/checked")))
     (define name/checked   (string->symbol (~a name "/checked")))
     (define fast-path
       (if (eq? kind 'eq)
           '((if (ref.eq (local.get $b1) (local.get $b2))
                 (then (return (global.get $true)))))
           '()))
     (define v1-get '(array.get_u $I8Array (local.get $a1) (local.get $i)))
     (define v2-get '(array.get_u $I8Array (local.get $a2) (local.get $i)))
     (define diff
       (if (eq? kind 'eq)
           '(if (i32.ne (local.get $v1) (local.get $v2))
                (then (return (global.get $false))))
           `(if (i32.ne (local.get $v1) (local.get $v2))
                (then (if (,cmp (local.get $v1) (local.get $v2))
                          (then (return (global.get $true)))
                          (else (return (global.get $false))))))))
     (define final
       (if (eq? kind 'eq)
           '(if (result (ref eq))
                (i32.eq (local.get $len1) (local.get $len2))
                (then (global.get $true))
                (else (global.get $false)))
           `(if (result (ref eq))
                (,cmp (local.get $len1) (local.get $len2))
                (then (global.get $true))
                (else (global.get $false)))))
     (list
      `(func ,name/2
             (param $v1 (ref eq)) ;; bytes?
             (param $v2 (ref eq)) ;; bytes?
             (result    (ref eq))
             (if (i32.eqz (ref.test (ref $Bytes) (local.get $v1)))
                 (then (call $raise-expected-bytes (local.get $v1))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Bytes) (local.get $v2)))
                 (then (call $raise-expected-bytes (local.get $v2))
                       (unreachable)))
             (return_call ,name/2/checked
                          (ref.cast (ref $Bytes) (local.get $v1))
                          (ref.cast (ref $Bytes) (local.get $v2))))
      `(func ,name/2/checked
             (param $b1 (ref $Bytes)) ;; bytes
             (param $b2 (ref $Bytes)) ;; bytes
             (result    (ref eq))
             (local $a1   (ref $I8Array))
             (local $a2   (ref $I8Array))
             (local $len1 i32)
             (local $len2 i32)
             (local $min  i32)
             (local $i    i32)
             (local $v1   i32)
             (local $v2   i32)

             ,@fast-path
             ;; Extract arrays and lengths
             (local.set $a1   (struct.get $Bytes $bs (local.get $b1)))
             (local.set $a2   (struct.get $Bytes $bs (local.get $b2)))
             (local.set $len1 (array.len (local.get $a1)))
             (local.set $len2 (array.len (local.get $a2)))
             ;; Determine minimum length
             (local.set $min (local.get $len1))
             (if (i32.lt_u (local.get $len2) (local.get $min))
                 (then (local.set $min (local.get $len2))))
             ;; Compare bytes one-by-one
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $min)))
                          (local.set $v1 ,v1-get)
                          (local.set $v2 ,v2-get)
                          ,diff
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             ;; All compared bytes equal – compare lengths
             ,final)
      `(func ,name/checked
             (param $b0 (ref $Bytes)) ;; first bytes
             (param $b1 (ref $Bytes)) ;; second bytes
             (param $bs (ref eq))     ;; rest bytes list
             (result (ref eq))
             (local $node      (ref $Pair))
             (local $next/any  (ref eq))       ;; raw car from the list
             (local $next      (ref $Bytes))   ;; refined to (ref $Bytes)
             (local $curr      (ref $Bytes))
             ;; Compare first two
             (if (ref.eq (call ,name/2/checked (local.get $b0) (local.get $b1))
                         (global.get $false))
                 (then (return (global.get $false))))
             (local.set $curr (local.get $b1))
             ;; Iterate remaining arguments
             (block $done
                    (loop $loop
                          (br_if $done (ref.eq (local.get $bs) (global.get $null)))
                          (local.set $node (ref.cast (ref $Pair) (local.get $bs)))
                          (local.set $next/any (struct.get $Pair $a (local.get $node)))
                          (if (i32.eqz (ref.test (ref $Bytes) (local.get $next/any)))
                              (then (call $raise-expected-bytes (local.get $next/any))
                                    (unreachable)))
                          (local.set $next
                                     (ref.cast (ref $Bytes) (local.get $next/any)))
                          (if (ref.eq (call ,name/2/checked (local.get $curr) (local.get $next))
                                      (global.get $false))
                              (then (return (global.get $false))))
                          (local.set $curr (local.get $next))
                          (local.set $bs   (struct.get $Pair $d (local.get $node)))
                          (br $loop)))
             (global.get $true))
      `(func ,name (type $Prim>=1)
             (param $b0 (ref eq)) ; bytes?
             (param $bs (ref eq)) ; rest list
             (result    (ref eq))
             (local $b1   (ref $Bytes))
             (local $b2   (ref $Bytes))
             (local $node (ref $Pair))
             (local $v    (ref eq))
             ;; Initialize non-defaultable locals
             (local.set $b1 (ref.cast (ref $Bytes) (global.get $bytes:empty)))
             (local.set $b2 (ref.cast (ref $Bytes) (global.get $bytes:empty)))
             ;; Validate first argument
             (if (ref.test (ref $Bytes) (local.get $b0))
                 (then (local.set $b1 (ref.cast (ref $Bytes) (local.get $b0))))
                 (else (call $raise-expected-bytes (local.get $b0)) (unreachable)))
             ;; No more arguments → true
             (if (ref.eq (local.get $bs) (global.get $null))
                 (then (return (global.get $true))))
             ;; Extract second argument
             (local.set $node (ref.cast (ref $Pair) (local.get $bs)))
             (local.set $v    (struct.get $Pair $a (local.get $node)))
             (if (ref.test (ref $Bytes) (local.get $v))
                 (then (local.set $b2 (ref.cast (ref $Bytes) (local.get $v))))
                 (else (call $raise-expected-bytes (local.get $v)) (unreachable)))
             (local.set $bs   (struct.get $Pair $d (local.get $node)))
             ;; Exactly two arguments?
             (if (ref.eq (local.get $bs) (global.get $null))
                 (then (return_call ,name/2/checked (local.get $b1) (local.get $b2)))
                 (else (return_call ,name/checked (local.get $b1) (local.get $b2) (local.get $bs))))
             (unreachable))))))

;; byte-comparison-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate byte-string comparison helpers used by the monolithic runtime.
(define byte-comparison-runtime-only-helpers
  (function-forms->runtime-helpers
   'byte-comparison-runtime-only-helpers
   byte-comparison-runtime-only-forms))

;; byte-indexing-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for byte indexing and copy helpers.
(define byte-indexing-runtime-only-helper-names
  '($byte?
    $bytes-ref
    $bytes-set!
    $bytes-set!/checked
    $subbytes
    $bytes-copy!
    $bytes-copy))

;; byte-indexing-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate byte indexing, mutation, and copy helpers used by the runtime.
(define byte-indexing-runtime-only-helpers
  (function-forms->runtime-helpers
   'byte-indexing-runtime-only-helpers
   '(
     (func $byte? (type $Prim1) (param $v (ref eq)) (result (ref eq))
           (local $i i32)
           (if (result (ref eq)) (ref.test (ref i31) (local.get $v))
               (then (local.set $i (i31.get_u (ref.cast (ref i31) (local.get $v))))
                     (if (result (ref eq))
                         ;; Check: is even (fixnum) and in range 0–255
                         (i32.and
                          (i32.eqz (i32.and (local.get $i) (i32.const 1)))       ;; even tag bit = 0
                          (i32.le_u (i32.shr_u (local.get $i) (i32.const 1))     ;; untagged value
                                    (i32.const 255)))
                         (then (global.get $true))
                         (else (global.get $false))))
               (else (global.get $false))))

     (func $bytes-ref (type $Prim2) (param $a (ref eq)) (param $i (ref eq)) (result (ref eq))
           (local $b   (ref null $Bytes))
           (local $arr (ref $I8Array))
           (local $idx i32)
           (local $v   i32)
           ;; 1. Check that $a is a byte string
           (if (ref.test (ref $Bytes) (local.get $a))
               (then (local.set $b (ref.cast (ref $Bytes) (local.get $a))))
               (else (call $raise-check-bytes (local.get $a))))
           ;; 2. Decode and check that $i is a fixnum
           (if (ref.test (ref i31) (local.get $i))
               (then (local.set $idx (i31.get_u (ref.cast (ref i31) (local.get $i))))
                     (if (i32.eqz (i32.and (local.get $idx) (i32.const 1)))
                         (then (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1))))
                         (else (call $raise-check-fixnum (local.get $i)) )))
               (else (call $raise-check-fixnum (local.get $i))))
           ;; 3. Get byte array and bounds-check
           (local.set $arr (struct.get $Bytes $bs (local.get $b)))
           (if (i32.lt_u (local.get $idx) (array.len (local.get $arr)))
               (then
                ;; 4. Read and box byte
                (local.set $v (call $i8array-ref (local.get $arr) (local.get $idx)))
                (return (ref.i31 (i32.shl (local.get $v) (i32.const 1)))))
               (else
                (call $raise-bad-bytes-ref-index (local.get $a) (local.get $i))))
           (unreachable))

     (func $bytes-set!
           (param $a (ref eq))
           (param $i (ref eq))
           (param $v (ref eq))

           (result (ref eq))

           (local $b   (ref null $Bytes))
           (local $arr (ref $I8Array))
           (local $idx i32)
           (local $bv  i32)
           ;; 1. Check that $a is a byte string
           (if (ref.test (ref $Bytes) (local.get $a))
               (then (local.set $b (ref.cast (ref $Bytes) (local.get $a))))
               (else (call $raise-check-bytes (local.get $a))))
           ;; Byte literals and bytes->immutable-bytes results must reject mutation.
           (if (i32.eq (struct.get $Bytes $immutable (local.get $b)) (i32.const 1))
               (then (call $raise-expected-mutable-bytes (local.get $a)) (unreachable)))
           ;; 2. Decode and check fixnum index $i
           (if (ref.test (ref i31) (local.get $i))
               (then
                (local.set $idx (i31.get_u (ref.cast (ref i31) (local.get $i))))
                (if (i32.eqz (i32.and (local.get $idx) (i32.const 1)))
                    (then (local.set $idx (i32.shr_u (local.get $idx) (i32.const 1))))
                    (else (call $raise-check-fixnum (local.get $i)))))
               (else (call $raise-check-fixnum (local.get $i))))
           ;; 3. Decode and check fixnum byte value $v
           (if (ref.test (ref i31) (local.get $v))
               (then
                (local.set $bv (i31.get_u (ref.cast (ref i31) (local.get $v))))
                (if (i32.eqz (i32.and (local.get $bv) (i32.const 1)))
                    (then
                     (local.set $bv (i32.shr_u (local.get $bv) (i32.const 1)))
                     (if (i32.gt_u (local.get $bv) (i32.const 255))
                         (then (call $raise-check-byte (local.get $v)))))
                    (else (call $raise-check-byte (local.get $v)))))
               (else (call $raise-check-byte (local.get $v))))
           ;; 4. Bounds check and set byte
           (local.set $arr (struct.get $Bytes $bs (local.get $b)))
           (if (i32.lt_u (local.get $idx) (call $i8array-length (local.get $arr)))
               (then (call $i8array-set! (local.get $arr) (local.get $idx) (local.get $bv))
                     (return (global.get $void)))
               (else (call $raise-bad-bytes-set-index (local.get $a) (local.get $i))))
           (unreachable))

     (func $bytes-set!/checked
           (param $a (ref $Bytes))
           (param $i i32)
           (param $b i32)
           ; unsafe
           (local $arr (ref $I8Array))
           (local.set $arr (struct.get $Bytes $bs (local.get $a)))
           (call $i8array-set! (local.get $arr) (local.get $i) (local.get $b)))

     (func $subbytes
           (param $b     (ref eq))   ;; input byte string
           (param $start (ref eq))   ;; start index
           (param $end   (ref eq))   ;; optional end index, default = (bytes-length $b)
           (result       (ref eq))

           (local $bs   (ref null $Bytes))
           (local $arr  (ref $I8Array))
           (local $from i32)
           (local $to   i32)
           (local $len  i32)
           ;; Check that $b is a byte string
           (if (ref.test (ref $Bytes) (local.get $b))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $b))))
               (else (call $raise-check-bytes (local.get $b)) (unreachable)))

           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (local.set $len (call $i8array-length (local.get $arr)))
           ;; Decode and validate fixnum $start
           (if (ref.test (ref i31) (local.get $start))
               (then
                (local.set $from (i31.get_u (ref.cast (ref i31) (local.get $start))))
                (if (i32.eqz (i32.and (local.get $from) (i32.const 1)))
                    (then (local.set $from (i32.shr_u (local.get $from) (i32.const 1))))
                    (else (call $raise-check-fixnum (local.get $start)) (unreachable))))
               (else (call $raise-check-fixnum (local.get $start)) (unreachable)))
           ;; Decode and validate fixnum $end (optional)
           (if (ref.eq (local.get $end) (global.get $missing))
               (then (local.set $to (local.get $len)))
               (else (if (ref.test (ref i31) (local.get $end))
                         (then
                          (local.set $to (i31.get_u (ref.cast (ref i31) (local.get $end))))
                          (if (i32.eqz (i32.and (local.get $to) (i32.const 1)))
                              (then (local.set $to (i32.shr_u (local.get $to) (i32.const 1))))
                              (else (call $raise-check-fixnum (local.get $end)) (unreachable))))
                         (else (call $raise-check-fixnum (local.get $end)) (unreachable)))))
           ;; Bounds check: 0 <= from <= to <= len
           (if (i32.gt_u (local.get $from) (local.get $to))
               (then (call $raise-bad-bytes-range (local.get $b) (local.get $from) (local.get $to)) (unreachable)))
           (if (i32.gt_u (local.get $to) (local.get $len))
               (then (call $raise-bad-bytes-range (local.get $b) (local.get $from) (local.get $to)) (unreachable)))
           ;; Copy the subarray
           (struct.new $Bytes
                       (i32.const 0)
                       (i32.const 0)
                       (call $i8array-copy (local.get $arr) (local.get $from) (local.get $to))))

     (func $bytes-copy!
           (param $dest       (ref eq))
           (param $dest-start (ref eq))
           (param $src        (ref eq))
           (param $src-start  (ref eq))  ;; optional fixnum, default = 0
           (param $src-end    (ref eq))  ;; optional fixnum, default = (bytes-length src)
           (result            (ref eq))

           (local $d          (ref $Bytes))
           (local $s          (ref $Bytes))
           (local $darr       (ref $I8Array))
           (local $sarr       (ref $I8Array))

           (local $di         i32)
           (local $si         i32)
           (local $ei         i32)
           (local $src-len    i32)
           (local $dest-len   i32)

           ;; --- Validate $dest ---
           (if (i32.eqz (ref.test (ref $Bytes) (local.get $dest)))
               (then (call $raise-check-bytes (local.get $dest))))
           ;; --- Validate $src ---
           (if (i32.eqz (ref.test (ref $Bytes) (local.get $src)))
               (then (call $raise-check-bytes (local.get $src))))
           ;; --- Cast after validation ---
           (local.set $d (ref.cast (ref $Bytes) (local.get $dest)))
           (local.set $s (ref.cast (ref $Bytes) (local.get $src)))
           ;; --- Reject immutable destination ---
           (if (i32.eq (struct.get $Bytes $immutable (local.get $d)) (i32.const 1))
               (then (call $raise-expected-mutable-bytes (local.get $dest)) (unreachable)))
           ;; --- Decode $dest-start ---
           (if (i32.eqz (ref.test (ref i31) (local.get $dest-start)))
               (then (call $raise-check-fixnum (local.get $dest-start))))
           (if (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $dest-start)))
                                (i32.const 1))
                       (i32.const 0))
               (then (call $raise-check-fixnum (local.get $dest-start))))
           (local.set $di
                      (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $dest-start)))
                                 (i32.const 1)))
           ;; --- Extract arrays and lengths  ---
           (local.set $darr     (struct.get $Bytes $bs (local.get $d)))
           (local.set $sarr     (struct.get $Bytes $bs (local.get $s)))
           (local.set $src-len  (call $i8array-length (local.get $sarr)))
           (local.set $dest-len (call $i8array-length (local.get $darr)))
           ;; --- Decode optional $src-start ---
           (if (ref.eq (local.get $src-start) (global.get $missing))
               (then (local.set $si (i32.const 0)))
               (else
                (if (i32.eqz (ref.test (ref i31) (local.get $src-start)))
                    (then (call $raise-check-fixnum (local.get $src-start))))
                (if (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $src-start)))
                                     (i32.const 1))
                            (i32.const 0))
                    (then (call $raise-check-fixnum (local.get $src-start))))
                (local.set $si
                           (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $src-start)))
                                      (i32.const 1)))))
           ;; --- Decode optional $src-end ---
           (if (ref.eq (local.get $src-end) (global.get $missing))
               (then (local.set $ei (local.get $src-len)))
               (else
                (if (i32.eqz (ref.test (ref i31) (local.get $src-end)))
                    (then (call $raise-check-fixnum (local.get $src-end))))
                (if (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $src-end)))
                                     (i32.const 1))
                            (i32.const 0))
                    (then (call $raise-check-fixnum (local.get $src-end))))
                (local.set $ei
                           (i32.shr_u (i31.get_u (ref.cast (ref i31) (local.get $src-end)))
                                      (i32.const 1)))))
           ;; --- Range validation ---
           (if (i32.gt_u (local.get $si) (local.get $ei))
               (then (call $raise-bad-bytes-range (local.get $src)
                           (local.get $si) (local.get $ei))
                     (unreachable)))
           (if (i32.gt_u (local.get $ei) (local.get $src-len))
               (then (call $raise-bad-bytes-range (local.get $src)
                           (local.get $si) (local.get $ei))
                     (unreachable)))
           (if (i32.gt_u (i32.add (local.get $di)
                                  (i32.sub (local.get $ei) (local.get $si)))
                         (local.get $dest-len))
               (then (call $raise-bad-bytes-range
                           (local.get $dest) (local.get $di)
                           (i32.add (local.get $di)
                                    (i32.sub (local.get $ei) (local.get $si))))
                     (unreachable)))
           ;; --- Copy bytes ---
           (call $i8array-copy! (local.get $darr) (local.get $di)
                 (local.get $sarr) (local.get $si) (local.get $ei))
           (global.get $void))


     (func $bytes-copy (type $Prim1)
           (param $src (ref eq))
           (result (ref eq))
           (local $b  (ref null $Bytes))
           (local $a  (ref $I8Array))
           (local $a2 (ref $I8Array))
           ;; Check that $src is a byte string
           (if (ref.test (ref $Bytes) (local.get $src))
               (then (local.set $b (ref.cast (ref $Bytes) (local.get $src))))
               (else (call $raise-check-bytes (local.get $src)) (unreachable)))
           ;; Extract and copy the underlying I8Array
           (local.set $a  (struct.get $Bytes $bs (local.get $b)))
           (local.set $a2 (call $i8array-copy (local.get $a) (i32.const 0) (call $i8array-length (local.get $a))))
           ;; Return a new mutable Bytes struct
           (struct.new $Bytes
                       (i32.const 0)          ;; hash
                       (i32.const 0)          ;; immutable = false
                       (local.get $a2)))
     )))

;; byte-sequence-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for byte fill, append, and list helpers.
(define byte-sequence-runtime-only-helper-names
  '($raise-expected-mutable-bytes
    $bytes-fill!
    $bytes-append
    $bytes-append/2
    $bytes-append*
    $bytes-join
    $bytes->list
    $list->bytes))

;; byte-sequence-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate byte fill, append, join, and list conversion helpers.
(define byte-sequence-runtime-only-helpers
  (function-forms->runtime-helpers
   'byte-sequence-runtime-only-helpers
   '(
     (func $raise-expected-mutable-bytes (unreachable))

     (func $bytes-fill! (type $Prim2)
           (param $dest (ref eq))
           (param $b    (ref eq))
           (result      (ref eq))

           (local $bs     (ref null $Bytes))
           (local $arr    (ref $I8Array))
           (local $b/tag  i32)     ;; raw i31 payload (tagged)
           (local $val    i32)     ;; untagged byte value 0..255

           ;; dest must be a (mutable) byte string
           (if (ref.test (ref $Bytes) (local.get $dest))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $dest))))
               (else (call $raise-check-bytes (local.get $dest)) (unreachable)))

           ;; reject immutable byte strings
           (if (i32.eq (struct.get $Bytes $immutable (local.get $bs)) (i32.const 1))
               (then (call $raise-expected-mutable-bytes (local.get $dest)) (unreachable)))

           ;; b must be a fixnum byte (i31 with lsb=0), then 0..255
           (if (ref.test (ref i31) (local.get $b))
               (then
                (local.set $b/tag (i31.get_u (ref.cast (ref i31) (local.get $b))))
                ;; ensure lsb=0 => fixnum (not a char etc.)
                (if (i32.ne (i32.and (local.get $b/tag) (i32.const 1)) (i32.const 0))
                    (then (call $raise-check-byte (local.get $b)) (unreachable)))
                ;; untag: shift right by 1 (your fixnum convention)
                (local.set $val (i32.shr_u (local.get $b/tag) (i32.const 1)))
                ;; range check 0..255
                (if (i32.ge_u (local.get $val) (i32.const 256))
                    (then (call $raise-check-byte (local.get $b)) (unreachable))))
               (else (call $raise-check-byte (local.get $b)) (unreachable)))

           ;; Fill underlying byte array
           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (call $i8array-fill! (local.get $arr) (local.get $val))

           ;; return void
           (global.get $void))

     (func $bytes-append (type $Prim>=0)
           (param  $xs   (ref eq))        ;; list of byte strings
           (result       (ref eq))

           (local $n     i32)
           (local $node  (ref $Pair))
           (local $b     (ref $Bytes))
           (local $v     (ref eq))
           (local $orig  (ref eq))
           (local $total i32)
           (local $len   i32)
           (local $arr   (ref $I8Array))
           (local $pos   i32)

           ;; === initialize non-defaultable refs ===
           (local.set $b (ref.cast (ref $Bytes) (global.get $bytes:empty)))

           ;; Preserve original list
           (local.set $orig (local.get $xs))
           ;; Determine number of arguments
           (local.set $n (call $length/i32 (local.get $xs)))
           ;; Zero arguments -> empty byte string
           (if (i32.eqz (local.get $n))
               (then (return (global.get $bytes:empty))))
           ;; Extract and check first argument
           (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
           (local.set $v    (struct.get $Pair $a (local.get $node)))
           (if (ref.test (ref $Bytes) (local.get $v))
               (then (local.set $b (ref.cast (ref $Bytes) (local.get $v))))
               (else (call $raise-check-bytes (local.get $v))))
           ;; Single argument -> copy to ensure fresh mutable bytes
           (if (i32.eq (local.get $n) (i32.const 1))
               (then (return (call $bytes-copy (local.get $b)))))
           ;; Compute total length
           (local.set $total
                      (call $i8array-length
                            (struct.get $Bytes $bs (local.get $b))))
           (local.set $xs (struct.get $Pair $d (local.get $node)))
           (block $done1
                  (loop $loop1
                        (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                        (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                        (local.set $v    (struct.get $Pair $a (local.get $node)))
                        (if (ref.test (ref $Bytes) (local.get $v))
                            (then
                             (local.set $b (ref.cast (ref $Bytes) (local.get $v)))
                             (local.set $len
                                        (call $i8array-length
                                              (struct.get $Bytes $bs (local.get $b))))
                             (local.set $total (i32.add (local.get $total) (local.get $len))))
                            (else (call $raise-check-bytes (local.get $v))))
                        (local.set $xs (struct.get $Pair $d (local.get $node)))
                        (br $loop1)))
           ;; All byte strings empty -> return empty byte string
           (if (i32.eqz (local.get $total))
               (then (return (global.get $bytes:empty))))
           ;; Allocate result array
           (local.set $arr (call $i8make-array (local.get $total) (i32.const 0)))
           ;; Copy byte strings into result array
           (local.set $xs (local.get $orig))
           (local.set $pos (i32.const 0))
           (block $done2
                  (loop $loop2
                        (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                        (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                        (local.set $b
                                   (ref.cast (ref $Bytes)
                                             (struct.get $Pair $a (local.get $node))))
                        (local.set $len
                                   (call $i8array-length
                                         (struct.get $Bytes $bs (local.get $b))))
                        (call $i8array-copy!
                              (local.get $arr) (local.get $pos)
                              (struct.get $Bytes $bs (local.get $b))
                              (i32.const 0) (local.get $len))
                        (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                        (local.set $xs (struct.get $Pair $d (local.get $node)))
                        (br $loop2)))

           (struct.new $Bytes
                       (i32.const 0)
                       (i32.const 0)
                       (local.get $arr)))


     (func $bytes-append/2
           (param $b1 (ref eq))
           (param $b2 (ref eq))
           (result (ref eq))

           (local $bs1 (ref null $Bytes))
           (local $bs2 (ref null $Bytes))
           (local $a1  (ref $I8Array))
           (local $a2  (ref $I8Array))
           (local $new (ref $I8Array))
           ;; Check both arguments are byte strings
           (if (ref.test (ref $Bytes) (local.get $b1))
               (then (local.set $bs1 (ref.cast (ref $Bytes) (local.get $b1))))
               (else (call $raise-check-bytes (local.get $b1)) (unreachable)))
           (if (ref.test (ref $Bytes) (local.get $b2))
               (then (local.set $bs2 (ref.cast (ref $Bytes) (local.get $b2))))
               (else (call $raise-check-bytes (local.get $b2)) (unreachable)))
           ;; Extract the underlying arrays
           (local.set $a1 (struct.get $Bytes $bs (local.get $bs1)))
           (local.set $a2 (struct.get $Bytes $bs (local.get $bs2)))
           ;; Call append function on the I8Arrays
           (local.set $new (call $i8array-append (local.get $a1) (local.get $a2)))
           ;; Wrap in new mutable Bytes struct
           (struct.new $Bytes
                       (i32.const 0) ;; hash
                       (i32.const 0) ;; mutable
                       (local.get $new)))


     (func $bytes-append* (type $Prim>=1)
           (param $str  (ref eq))  ;; bytes? or list of bytes
           (param $rest (ref eq))  ;; additional bytes, last element list
           (result      (ref eq))

           (local $xs   (ref eq))
           (local $node (ref $Pair))
           (local $acc  (ref eq))
           (local $last (ref eq))
           (local $args (ref eq))

           ;; initialize locals with no defaults
           (local.set $last (global.get $false))
           ;; no extra args: first arg supplies list of bytes
           (if (ref.eq (local.get $rest) (global.get $null))
               (then (return (call $bytes-append (local.get $str)))))

           ;; separate last list from preceding byte arguments
           (local.set $xs  (local.get $rest))
           (local.set $acc (global.get $null))
           (block $done
                  (loop $loop
                        (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                        (local.set $xs   (struct.get $Pair $d (local.get $node)))
                        (if (ref.eq (local.get $xs) (global.get $null))
                            (then (local.set $last (struct.get $Pair $a (local.get $node)))
                                  (br $done))
                            (else (local.set $acc
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
                        (local.set $args (struct.new $Pair
                                                     (i32.const 0)
                                                     (struct.get $Pair $a (local.get $node))
                                                     (local.get $args)))
                        (local.set $acc (struct.get $Pair $d (local.get $node)))
                        (br $loop2)))
           (local.set $args (struct.new $Pair (i32.const 0)
                                        (local.get $str)
                                        (local.get $args)))
           (call $bytes-append (local.get $args)))

     (func $bytes-join (type $Prim2)
          (param $strs (ref eq)) ;; listof bytes?
          (param $sep  (ref eq)) ;; bytes?
          (result      (ref eq))

          (local $xs      (ref eq))
          (local $node    (ref $Pair))
          (local $v       (ref eq))
          (local $bs      (ref $Bytes))
          (local $sep-bs  (ref $Bytes))
          (local $sep-len i32)
          (local $n       i32)
          (local $total   i32)
          (local $len     i32)
          (local $arr     (ref $I8Array))
          (local $pos     i32)

          ;; --- Initialize non-defaultable locals ---
          (local.set $bs     (ref.cast (ref $Bytes) (global.get $bytes:empty)))
          (local.set $sep-bs (ref.cast (ref $Bytes) (global.get $bytes:empty)))

          ;; --- Check separator ---
          (if (ref.test (ref $Bytes) (local.get $sep))
              (then (local.set $sep-bs (ref.cast (ref $Bytes) (local.get $sep))))
              (else (call $raise-check-bytes (local.get $sep)) (unreachable)))
          ;; --- Determine separator length ---
          (local.set $sep-len
                     (call $i8array-length
                           (struct.get $Bytes $bs (local.get $sep-bs))))
          ;; --- Determine number of byte strings ---
          (local.set $n (call $length/i32 (local.get $strs)))
          (if (i32.eqz (local.get $n))
              (then (return (global.get $bytes:empty))))
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
                       (if (ref.test (ref $Bytes) (local.get $v))
                           (then
                            (local.set $bs (ref.cast (ref $Bytes) (local.get $v)))
                            (local.set $len
                                       (call $i8array-length
                                             (struct.get $Bytes $bs (local.get $bs))))
                            (local.set $total (i32.add (local.get $total) (local.get $len))))
                           (else (call $raise-check-bytes (local.get $v)) (unreachable)))
                       (local.set $xs (struct.get $Pair $d (local.get $node)))
                       (br $loop1)))
          ;; --- All empty -> empty byte string ---
          (if (i32.eqz (local.get $total))
              (then (return (global.get $bytes:empty))))
          ;; --- Allocate result array ---
          (local.set $arr (call $i8make-array (local.get $total) (i32.const 0)))
          ;; --- Copy byte strings and separators ---
          (local.set $xs (local.get $strs))
          (local.set $pos (i32.const 0))
          (block $done2
                 (loop $loop2
                       (br_if $done2 (ref.eq (local.get $xs) (global.get $null)))
                       (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                       (local.set $bs
                                  (ref.cast (ref $Bytes)
                                            (struct.get $Pair $a (local.get $node))))
                       (local.set $len
                                  (call $i8array-length
                                        (struct.get $Bytes $bs (local.get $bs))))
                       (call $i8array-copy!
                             (local.get $arr) (local.get $pos)
                             (struct.get $Bytes $bs (local.get $bs))
                             (i32.const 0) (local.get $len))
                       (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                       (local.set $xs (struct.get $Pair $d (local.get $node)))
                       (if (ref.eq (local.get $xs) (global.get $null))
                           (then (nop))
                           (else
                            (call $i8array-copy!
                                  (local.get $arr) (local.get $pos)
                                  (struct.get $Bytes $bs (local.get $sep-bs))
                                  (i32.const 0) (local.get $sep-len))
                            (local.set $pos
                                       (i32.add (local.get $pos) (local.get $sep-len)))))
                       (br $loop2)))
          ;; --- Build result byte string ---
          (struct.new $Bytes
                      (i32.const 0)
                      (i32.const 0)
                      (local.get $arr)))

     (func $bytes->list (type $Prim1)
           (param $bstr (ref eq))
           (result (ref eq))
           (local $bs   (ref null $Bytes))
           (local $arr  (ref $I8Array))
           (local $len  i32)
           (local $i    i32)
           (local $val  i32)
           (local $acc  (ref eq))
           ;; Check input is a byte string
           (if (ref.test (ref $Bytes) (local.get $bstr))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
               (else (call $raise-check-bytes (local.get $bstr)) (unreachable)))
           ;; Extract underlying byte array
           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           ;; Get its length
           (local.set $len (call $i8array-length (local.get $arr)))
           ;; Build list in reverse
           (local.set $i (i32.sub (local.get $len) (i32.const 1)))
           (local.set $acc (global.get $null))
           (block $done
                  (loop $loop
                        (br_if $done (i32.lt_s (local.get $i) (i32.const 0)))
                        (local.set $val (call $i8array-ref (local.get $arr) (local.get $i)))
                        (local.set $acc
                                   (struct.new $Pair
                                               (i32.const 0)
                                               (ref.i31 (i32.shl (local.get $val) (i32.const 1))) ;; encode fixnum
                                               (local.get $acc)))
                        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $acc))

     (func $list->bytes (type $Prim1)
           (param $xs (ref eq))
           (result (ref eq))

           (local $bs   (ref $Bytes))
           (local $arr  (ref $I8Array))
           (local $i    i32)
           (local $len  i32)
           (local $x    (ref eq))
           (local $v    i32)
           ;; Step 1: Compute length of list
           (local.set $len (call $length/i32 (local.get $xs)))
           ;; Step 2: Allocate mutable byte array of length $len
           (local.set $arr (call $i8make-array (local.get $len) (i32.const 0)))
           ;; Step 3: Allocate mutable Bytes struct
           (local.set $bs  (struct.new $Bytes
                                       (i32.const 0)
                                       (i32.const 0)
                                       (local.get $arr)))
           ;; Step 4: Iterate through list and populate byte array
           (local.set $i (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                        (if (ref.test (ref $Pair) (local.get $xs))
                            (then
                             (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $xs))))
                             (if (ref.test (ref i31) (local.get $x))
                                 (then
                                  (local.set $v (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                  (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
                                      (then
                                       (local.set $v (i32.shr_u (local.get $v) (i32.const 1)))
                                       (if (i32.lt_u (local.get $v) (i32.const 256))
                                           (then
                                            (call $i8array-set! (local.get $arr) (local.get $i) (local.get $v))
                                            (local.set $i (i32.add (local.get $i) (i32.const 1))))
                                           (else
                                            (call $raise-byte-out-of-range (local.get $x))
                                            (unreachable))))
                                      (else
                                       (call $raise-check-fixnum (local.get $x))
                                       (unreachable))))
                                 (else
                                  (call $raise-check-fixnum (local.get $x))
                                  (unreachable)))
                             (local.set $xs (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $xs)))))
                            (else
                             (call $raise-pair-expected (local.get $xs))
                             (unreachable)))
                        (br $loop)))
           ;; Step 5: Return the byte string struct
           (local.get $bs))
     )))

;; bytes-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate bytes helpers that still depend on monolithic runtime globals.
(define bytes-runtime-only-helpers
  (append
   bytes-basic-runtime-only-helpers
   byte-comparison-runtime-only-helpers
   byte-indexing-runtime-only-helpers
   byte-sequence-runtime-only-helpers
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
