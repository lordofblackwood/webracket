#lang racket

(provide bytes-runtime-string-constants
         bytes-runtime-bytes-constants
         byte-predicate-runtime-symbol-constants
         bytes-runtime-symbol-constants
         bytes-core-runtime-helpers
         bytes-basic-runtime-only-helper-names
         byte-comparison-runtime-only-helper-names
         byte-indexing-runtime-only-helper-names
         byte-converter-runtime-only-helper-names
         byte-sequence-runtime-only-helper-names
         byte-text-decoding-runtime-only-helper-names
         bytes-mutability-runtime-only-helper-names
         bytes-mutability-runtime-helper-forms
         bytes-main-runtime-helper-forms
         bytes-runtime-only-helpers)

(require "../core-helper.rkt"
         (only-in "../../private/immediates.rkt"
                  char-mask
                  char-shift
                  char-tag))

;; bytes-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by byte-string helpers and byte-string errors.
(define bytes-runtime-string-constants
  '((byte?                      "byte?")
    (listof-byte?                "(listof byte?)")
    (listof-bytes?               "(listof bytes?)")
    (bytes?                     "bytes?")
    (mutable-bytes?             "(and/c bytes? (not/c immutable?))")
    (char-or-false?             "(or/c char? #f)")
    (bytes->string/utf-8:bad-encoding ": byte string is not a well-formed UTF-8 encoding")
    (bytes:expected-mutable "expected mutable byte string")
    (bytes-converter?           "bytes-converter?")))

;; bytes-runtime-bytes-constants : (listof (list/c symbol? bytes?))
;;   Declare byte-string constants used by byte-string helpers.
(define bytes-runtime-bytes-constants
  '((empty #"")))

;; byte-predicate-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by byte predicate helpers.
(define byte-predicate-runtime-symbol-constants
  '(byte?))

;; bytes-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by byte-string helpers and byte-string errors.
(define bytes-runtime-symbol-constants
  '(bytes?
    bytevector->u8-list
    bytes=?
    bytes<?
    bytes>?
    bytes-converter?
    bytes-open-converter
    bytes-close-converter
    bytes-convert
    bytes-convert-end
    complete
    continues))

;; bytes-runtime-who-global : symbol? -> symbol?
;;   Return the runtime symbol global corresponding to a Wasm function name.
(define (bytes-runtime-who-global name)
  (string->symbol
   (format "$symbol:~a" (substring (symbol->string name) 1))))

;; raise-bytes-expected-form : symbol? datum? -> datum?
;;   Build a bytes? contract-error call for a public byte-string function.
(define (raise-bytes-expected-form who-name value-form)
  `(call $raise-argument-error1
         (global.get ,(bytes-runtime-who-global who-name))
         (global.get $string:bytes?)
         ,value-form))

;; make-predicate-body : symbol? -> (listof datum?)
;;   Generate the shared body for a single-argument Wasm predicate.
(define (make-predicate-body ref-type)
  `((param $v (ref eq))
    (result   (ref eq))
    (if (result (ref eq))
        (ref.test (ref ,ref-type) (local.get $v))
        (then (global.get $true))
        (else (global.get $false)))))

;; bytes-mutability-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for bytes mutability predicates.
(define bytes-mutability-runtime-only-helper-names
  '($mutable-bytes?
    $immutable-bytes?))

;; bytes-basic-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for basic byte-string helpers.
(define bytes-basic-runtime-only-helper-names
  '($raise-byte-out-of-range
    $raise-check-bytes/who
    $raise-check-bytes
    $raise-check-mutable-bytes/who
    $raise-check-byte/who
    $raise-check-byte
    $bytes-index/i32
    $byte-value/i32/who
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
     (func $raise-check-bytes/who (param $who (ref eq)) (param $x (ref eq))
           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:bytes?)
                 (local.get $x)))
     (func $raise-check-bytes (param $x (ref eq))
           (call $raise-check-bytes/who
                 (global.get $symbol:bytes?)
                 (local.get $x)))
     (func $raise-check-mutable-bytes/who (param $who (ref eq)) (param $x (ref eq))
           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:mutable-bytes?)
                 (local.get $x)))
     (func $raise-check-byte/who (param $who (ref eq)) (param $x (ref eq))
           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:byte?)
                 (local.get $x)))
     (func $raise-check-byte (param $x (ref eq))
           (call $raise-check-byte/who
                 (global.get $symbol:byte?)
                 (local.get $x)))
     (func $bytes-index/i32
           (param $who (ref eq))
           (param $x   (ref eq))
           (result i32)

           (local $idx  i32)

           (local.set $idx
                      (call $exact-nonnegative-integer->i32/saturating
                            (local.get $x)))
           (if (i32.lt_s (local.get $idx) (i32.const 0))
               (then
                (call $raise-argument-error1
                      (local.get $who)
                      (global.get $string:exact-nonnegative-integer?)
                      (local.get $x))
                (unreachable)))
           (local.get $idx))
     (func $byte-value/i32/who
           (param $who (ref eq))
           (param $x   (ref eq))
           (result i32)

           (local $val  i32)

           (local.set $val
                      (call $exact-nonnegative-integer->i32/saturating
                            (local.get $x)))
           (if (i32.or (i32.lt_s (local.get $val) (i32.const 0))
                       (i32.gt_u (local.get $val) (i32.const 255)))
               (then
                (call $raise-check-byte/who (local.get $who) (local.get $x))
                (unreachable)))
           (local.get $val))
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
           ;; Decode and check $k as exact-nonnegative-integer?
           (local.set $len
                      (call $bytes-index/i32
                            (global.get $symbol:make-bytes)
                            (local.get $k-raw)))
           ;; Handle optional byte argument
           (if (ref.eq (local.get $b-raw) (global.get $missing))
               (then (local.set $val (i32.const 0)))
               (else (local.set $val
                                (call $byte-value/i32/who
                                      (global.get $symbol:make-bytes)
                                      (local.get $b-raw)))))
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
                             (local.set $v
                                        (call $byte-value/i32/who
                                              (global.get $symbol:bytes)
                                              (local.get $x)))
                             (call $i8array-set! (local.get $arr) (local.get $i) (local.get $v))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $loop-list)))
                      (else
                       (loop $loop-args
                             (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                             (local.set $x (array.get $Args (local.get $as) (local.get $i)))
                             (local.set $v
                                        (call $byte-value/i32/who
                                              (global.get $symbol:bytes)
                                              (local.get $x)))
                             (call $i8array-set! (local.get $arr) (local.get $i) (local.get $v))
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
              (else (call $raise-check-bytes/who
                          (global.get $symbol:bytes->immutable-bytes)
                          (local.get $b))
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
               (else (call $raise-check-bytes/who
                           (global.get $symbol:bytes-length)
                           (local.get $a))
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

     (func $raise-expected-bytes (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:bytes?)
                 (global.get $string:bytes?)
                 (local.get $x)))

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
                 (then ,(raise-bytes-expected-form name '(local.get $v1))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Bytes) (local.get $v2)))
                 (then ,(raise-bytes-expected-form name '(local.get $v2))
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
                              (then ,(raise-bytes-expected-form name '(local.get $next/any))
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
                 (else ,(raise-bytes-expected-form name '(local.get $b0)) (unreachable)))
             ;; No more arguments → true
             (if (ref.eq (local.get $bs) (global.get $null))
                 (then (return (global.get $true))))
             ;; Extract second argument
             (local.set $node (ref.cast (ref $Pair) (local.get $bs)))
             (local.set $v    (struct.get $Pair $a (local.get $node)))
             (if (ref.test (ref $Bytes) (local.get $v))
                 (then (local.set $b2 (ref.cast (ref $Bytes) (local.get $v))))
                 (else ,(raise-bytes-expected-form name '(local.get $v)) (unreachable)))
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
               (else (call $raise-check-bytes/who
                           (global.get $symbol:bytes-ref)
                           (local.get $a))))
           ;; 2. Decode and check that $i is exact-nonnegative-integer?
           (local.set $idx
                      (call $bytes-index/i32
                            (global.get $symbol:bytes-ref)
                            (local.get $i)))
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
               (else (call $raise-check-mutable-bytes/who
                           (global.get $symbol:bytes-set!)
                           (local.get $a))))
           ;; Byte literals and bytes->immutable-bytes results must reject mutation.
           (if (i32.eq (struct.get $Bytes $immutable (local.get $b)) (i32.const 1))
               (then (call $raise-check-mutable-bytes/who
                           (global.get $symbol:bytes-set!)
                           (local.get $a))
                     (unreachable)))
           ;; 2. Decode and check exact-nonnegative-integer? index $i
           (local.set $idx
                      (call $bytes-index/i32
                            (global.get $symbol:bytes-set!)
                            (local.get $i)))
           ;; 3. Decode and check byte value $v
           (local.set $bv
                      (call $byte-value/i32/who
                            (global.get $symbol:bytes-set!)
                            (local.get $v)))
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
               (else (call $raise-check-bytes/who
                           (global.get $symbol:subbytes)
                           (local.get $b))
                     (unreachable)))

           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (local.set $len (call $i8array-length (local.get $arr)))
           ;; Decode and validate exact-nonnegative-integer? $start
           (local.set $from
                      (call $bytes-index/i32
                            (global.get $symbol:subbytes)
                            (local.get $start)))
           ;; Decode and validate exact-nonnegative-integer? $end (optional)
           (if (ref.eq (local.get $end) (global.get $missing))
               (then (local.set $to (local.get $len)))
               (else (local.set $to
                                (call $bytes-index/i32
                                      (global.get $symbol:subbytes)
                                      (local.get $end)))))
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
               (then (call $raise-check-mutable-bytes/who
                           (global.get $symbol:bytes-copy!)
                           (local.get $dest))))
           ;; --- Validate $src ---
           (if (i32.eqz (ref.test (ref $Bytes) (local.get $src)))
               (then (call $raise-check-bytes/who
                           (global.get $symbol:bytes-copy!)
                           (local.get $src))))
           ;; --- Cast after validation ---
           (local.set $d (ref.cast (ref $Bytes) (local.get $dest)))
           (local.set $s (ref.cast (ref $Bytes) (local.get $src)))
           ;; --- Reject immutable destination ---
           (if (i32.eq (struct.get $Bytes $immutable (local.get $d)) (i32.const 1))
               (then (call $raise-check-mutable-bytes/who
                           (global.get $symbol:bytes-copy!)
                           (local.get $dest))
                     (unreachable)))
           (local.set $di
                      (call $bytes-index/i32
                            (global.get $symbol:bytes-copy!)
                            (local.get $dest-start)))
           ;; --- Extract arrays and lengths  ---
           (local.set $darr     (struct.get $Bytes $bs (local.get $d)))
           (local.set $sarr     (struct.get $Bytes $bs (local.get $s)))
           (local.set $src-len  (call $i8array-length (local.get $sarr)))
           (local.set $dest-len (call $i8array-length (local.get $darr)))
           ;; --- Decode optional $src-start ---
           (if (ref.eq (local.get $src-start) (global.get $missing))
               (then (local.set $si (i32.const 0)))
               (else (local.set $si
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes-copy!)
                                      (local.get $src-start)))))
           ;; --- Decode optional $src-end ---
           (if (ref.eq (local.get $src-end) (global.get $missing))
               (then (local.set $ei (local.get $src-len)))
               (else (local.set $ei
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes-copy!)
                                      (local.get $src-end)))))
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
               (else (call $raise-check-bytes/who
                           (global.get $symbol:bytes-copy)
                           (local.get $src))
                     (unreachable)))
           ;; Extract and copy the underlying I8Array
           (local.set $a  (struct.get $Bytes $bs (local.get $b)))
           (local.set $a2 (call $i8array-copy (local.get $a) (i32.const 0) (call $i8array-length (local.get $a))))
           ;; Return a new mutable Bytes struct
           (struct.new $Bytes
                       (i32.const 0)          ;; hash
                       (i32.const 0)          ;; immutable = false
                       (local.get $a2)))
     )))

;; byte-converter-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for byte converter helpers.
(define byte-converter-runtime-only-helper-names
  '($bytes-converter?
    $bytes-open-converter
    $bytes-close-converter
    $bytes-convert
    $bytes-convert-end))

;; byte-converter-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate byte converter helpers used by the runtime.
(define byte-converter-runtime-only-helpers
  (function-forms->runtime-helpers
   'byte-converter-runtime-only-helpers
   `(
     ;; bytes-converter? : any/c -> boolean?
     ;;   Recognize WebRacket's minimal byte converters.
     (func $bytes-converter? (type $Prim1)
           ,@(make-predicate-body '$BytesConverter))

     ;; bytes-open-converter : string? string? -> (or/c bytes-converter? #f)
     ;;   Support the guaranteed UTF-8 identity cases used by module
     ;;   startup. WebRacket currently treats locale encoding as UTF-8.
     (func $bytes-open-converter (type $Prim2)
           (param $from (ref eq)) ;; string?
           (param $to   (ref eq)) ;; string?
           (result      (ref eq))
           (if (i32.eqz (ref.test (ref $String) (local.get $from)))
               (then (call $raise-argument-error1
                           (global.get $symbol:bytes-open-converter)
                           (global.get $string:string?)
                           (local.get $from))
                     (unreachable)))
           (if (i32.eqz (ref.test (ref $String) (local.get $to)))
               (then (call $raise-argument-error1
                           (global.get $symbol:bytes-open-converter)
                           (global.get $string:string?)
                           (local.get $to))
                     (unreachable)))
           (struct.new $BytesConverter (i32.const 0) (i32.const 0)))

     ;; bytes-close-converter : bytes-converter? -> void?
     ;;   Mark the minimal converter closed; it remains a converter? value,
     ;;   matching Racket's predicate behavior after close.
     (func $bytes-close-converter (type $Prim1)
           (param $converter-raw (ref eq)) ;; bytes-converter?
           (result               (ref eq))
           (if (i32.eqz (ref.test (ref $BytesConverter) (local.get $converter-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:bytes-close-converter)
                           (global.get $string:bytes-converter?)
                           (local.get $converter-raw))
                     (unreachable)))
           (struct.set $BytesConverter $closed
                       (ref.cast (ref $BytesConverter) (local.get $converter-raw))
                       (i32.const 1))
           (global.get $void))

     ;; bytes-convert : bytes-converter? bytes? [start end dest dest-start dest-end] -> values
     ;;   Minimal identity conversion for UTF-8/locale-as-UTF-8. The
     ;;   optional destination limit is accepted but this first slice only
     ;;   supports complete copies that fit the destination.
     (func $bytes-convert (type $Prim>=2)
           (param $converter-raw (ref eq)) ;; bytes-converter?
           (param $src-raw       (ref eq)) ;; bytes?
           (param $rest          (ref eq)) ;; optional arguments
           (result               (ref eq))

           (local $src          (ref $Bytes))
           (local $node         (ref eq))
           (local $src-start    (ref eq))
           (local $src-end      (ref eq))
           (local $dest-raw     (ref eq))
           (local $dest-start   (ref eq))
           (local $slice        (ref eq))
           (local $read-count   i32)
           (local $src-start/i  i32)
           (local $src-end/i    i32)
           (local $src-len      i32)

           (if (i32.eqz (ref.test (ref $BytesConverter) (local.get $converter-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:bytes-convert)
                           (global.get $string:bytes-converter?)
                           (local.get $converter-raw))
                     (unreachable)))
           (if (i32.eq
                (struct.get $BytesConverter $closed
                            (ref.cast (ref $BytesConverter) (local.get $converter-raw)))
                (i32.const 1))
               (then (call $raise-argument-error1
                           (global.get $symbol:bytes-convert)
                           (global.get $string:bytes-converter?)
                           (local.get $converter-raw))
                     (unreachable)))
           (if (i32.eqz (ref.test (ref $Bytes) (local.get $src-raw)))
               (then (call $raise-check-bytes/who
                           (global.get $symbol:bytes-convert)
                           (local.get $src-raw))
                     (unreachable)))
           (local.set $src (ref.cast (ref $Bytes) (local.get $src-raw)))
           (local.set $src-len
                      (call $i8array-length
                            (struct.get $Bytes $bs (local.get $src))))
           (local.set $src-start (ref.i31 (i32.const 0)))
           (local.set $src-end
                      (ref.i31
                       (i32.shl
                        (local.get $src-len)
                        (i32.const 1))))
           (local.set $dest-raw (global.get $false))
           (local.set $dest-start (ref.i31 (i32.const 0)))
           (local.set $node (local.get $rest))
           (if (ref.test (ref $Pair) (local.get $node))
               (then
                (local.set $src-start (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))))
           (if (ref.test (ref $Pair) (local.get $node))
               (then
                (local.set $src-end (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))))
           (if (ref.test (ref $Pair) (local.get $node))
               (then
                (local.set $dest-raw (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))))
           (if (ref.test (ref $Pair) (local.get $node))
               (then
                (local.set $dest-start (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))))
           (local.set $src-start/i
                      (call $bytes-index/i32
                            (global.get $symbol:bytes-convert)
                            (local.get $src-start)))
           (local.set $src-end/i
                      (call $bytes-index/i32
                            (global.get $symbol:bytes-convert)
                            (local.get $src-end)))
           (if (i32.or (i32.gt_u (local.get $src-start/i) (local.get $src-end/i))
                       (i32.gt_u (local.get $src-end/i) (local.get $src-len)))
               (then (call $raise-byte-string-range-error
                           (global.get $symbol:bytes-convert)
                           (local.get $src-raw)
                           (local.get $src-start/i)
                           (local.get $src-end/i)
                           (local.get $src-len))
                     (unreachable)))
           (local.set $read-count
                      (i32.sub (local.get $src-end/i) (local.get $src-start/i)))
           (local.set $slice
                      (struct.new $Bytes
                                  (i32.const 0)
                                  (i32.const 0)
                                  (call $i8array-copy
                                        (struct.get $Bytes $bs (local.get $src))
                                        (local.get $src-start/i)
                                        (local.get $src-end/i))))
           (if (ref.eq (local.get $dest-raw) (global.get $false))
               (then
                (return
                 (array.new_fixed $Values
                                  3
                                  (local.get $slice)
                                  (ref.i31 (i32.shl (local.get $read-count) (i32.const 1)))
                                  (global.get $symbol:complete)))))
           (if (i32.eqz (ref.test (ref $Bytes) (local.get $dest-raw)))
               (then (call $raise-check-bytes/who
                           (global.get $symbol:bytes-convert)
                           (local.get $dest-raw))
                     (unreachable)))
           (drop (call $bytes-copy!
                       (local.get $dest-raw)
                       (local.get $dest-start)
                       (local.get $slice)
                       (global.get $missing)
                       (global.get $missing)))
           (array.new_fixed $Values
                            3
                            (ref.i31 (i32.shl (local.get $read-count) (i32.const 1)))
                            (ref.i31 (i32.shl (local.get $read-count) (i32.const 1)))
                            (global.get $symbol:complete)))

     ;; bytes-convert-end : bytes-converter? [dest dest-start dest-end] -> values
     ;;   Identity converters have no shift sequence, so conversion ends
     ;;   with empty output and 'complete.
     (func $bytes-convert-end (type $Prim14)
           (param $converter-raw (ref eq)) ;; bytes-converter?
           (param $dest-raw      (ref eq)) ;; optional (or/c bytes? #f)
           (param $dest-start    (ref eq)) ;; optional exact-nonnegative-integer?
           (param $dest-end      (ref eq)) ;; optional bound, ignored
           (result               (ref eq))
           (if (i32.eqz (ref.test (ref $BytesConverter) (local.get $converter-raw)))
               (then (call $raise-argument-error1
                           (global.get $symbol:bytes-convert-end)
                           (global.get $string:bytes-converter?)
                           (local.get $converter-raw))
                     (unreachable)))
           (if (ref.eq (local.get $dest-raw) (global.get $missing))
               (then (local.set $dest-raw (global.get $false))))
           (if (ref.eq (local.get $dest-raw) (global.get $false))
               (then
                (return
                 (array.new_fixed $Values
                                  2
                                  (struct.new $Bytes
                                              (i32.const 0)
                                              (i32.const 0)
                                              (array.new_fixed $I8Array 0))
                                  (global.get $symbol:complete)))))
           (if (i32.eqz (ref.test (ref $Bytes) (local.get $dest-raw)))
               (then (call $raise-check-bytes/who
                           (global.get $symbol:bytes-convert-end)
                           (local.get $dest-raw))
                     (unreachable)))
           (array.new_fixed $Values
                            2
                            (ref.i31 (i32.const 0))
                            (global.get $symbol:complete)))
     )))

;; byte-sequence-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for byte fill, append, and list helpers.
(define byte-sequence-runtime-only-helper-names
  '($raise-expected-mutable-bytes
    $raise-listof-bytes/who
    $raise-listof-byte/who
    $bytes-append-args-length/i32/who
    $listof-bytes-length/i32/who
    $listof-byte-length/i32/who
    $bytes-fill!
    $bytes-append/who
    $bytes-append
    $bytes-append/1
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
     (func $raise-expected-mutable-bytes
           (call $raise-arguments-error
                 (global.get $symbol:bytes-fill!)
                 (global.get $string:bytes:expected-mutable)
                 (array.new_fixed $Args 0))
           (unreachable))
     (func $raise-listof-bytes/who (param $who (ref eq)) (param $xs (ref eq))
           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:listof-bytes?)
                 (local.get $xs)))
     (func $raise-listof-byte/who (param $who (ref eq)) (param $xs (ref eq))
           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:listof-byte?)
                 (local.get $xs)))
     (func $bytes-append-args-length/i32/who
           (param $who (ref eq))
           (param $xs  (ref eq))
           (result i32)

           (local $i i32)
           (local $v (ref eq))

           (local.set $i (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                            (then
                             (call $raise-check-bytes/who (local.get $who) (local.get $xs))
                             (unreachable)))
                        (local.set $v
                                   (struct.get $Pair $a
                                               (ref.cast (ref $Pair) (local.get $xs))))
                        (if (i32.eqz (ref.test (ref $Bytes) (local.get $v)))
                            (then
                             (call $raise-check-bytes/who (local.get $who) (local.get $v))
                             (unreachable)))
                        (local.set $xs
                                   (struct.get $Pair $d
                                               (ref.cast (ref $Pair) (local.get $xs))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $i))
     (func $listof-bytes-length/i32/who
           (param $who (ref eq))
           (param $xs  (ref eq))
           (result i32)

           (local $orig (ref eq))
           (local $i    i32)
           (local $v    (ref eq))

           (local.set $orig (local.get $xs))
           (local.set $i    (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                            (then
                             (call $raise-listof-bytes/who
                                   (local.get $who)
                                   (local.get $orig))
                             (unreachable)))
                        (local.set $v
                                   (struct.get $Pair $a
                                               (ref.cast (ref $Pair) (local.get $xs))))
                        (if (i32.eqz (ref.test (ref $Bytes) (local.get $v)))
                            (then
                             (call $raise-listof-bytes/who
                                   (local.get $who)
                                   (local.get $orig))
                             (unreachable)))
                        (local.set $xs
                                   (struct.get $Pair $d
                                               (ref.cast (ref $Pair) (local.get $xs))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $i))
     (func $listof-byte-length/i32/who
           (param $who (ref eq))
           (param $xs  (ref eq))
           (result i32)

           (local $orig (ref eq))
           (local $i    i32)
           (local $x    (ref eq))
           (local $bits i32)
           (local $v    i32)

           (local.set $orig (local.get $xs))
           (local.set $i    (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $xs) (global.get $null)))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                            (then
                             (call $raise-listof-byte/who
                                   (local.get $who)
                                   (local.get $orig))
                             (unreachable)))
                        (local.set $x
                                   (struct.get $Pair $a
                                               (ref.cast (ref $Pair) (local.get $xs))))
                        (if (i32.eqz (ref.test (ref i31) (local.get $x)))
                            (then
                             (call $raise-listof-byte/who
                                   (local.get $who)
                                   (local.get $orig))
                             (unreachable)))
                        (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                        (if (i32.and (local.get $bits) (i32.const 1))
                            (then
                             (call $raise-listof-byte/who
                                   (local.get $who)
                                   (local.get $orig))
                             (unreachable)))
                        (local.set $v (i32.shr_s (local.get $bits) (i32.const 1)))
                        (if (i32.or (i32.lt_s (local.get $v) (i32.const 0))
                                    (i32.gt_u (local.get $v) (i32.const 255)))
                            (then
                             (call $raise-listof-byte/who
                                   (local.get $who)
                                   (local.get $orig))
                             (unreachable)))
                        (local.set $xs
                                   (struct.get $Pair $d
                                               (ref.cast (ref $Pair) (local.get $xs))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $i))

     (func $bytes-fill! (type $Prim2)
           (param $dest (ref eq))
           (param $b    (ref eq))
           (result      (ref eq))

           (local $bs     (ref null $Bytes))
           (local $arr    (ref $I8Array))
           (local $val    i32)     ;; untagged byte value 0..255

           ;; dest must be a (mutable) byte string
           (if (ref.test (ref $Bytes) (local.get $dest))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $dest))))
               (else (call $raise-check-mutable-bytes/who
                           (global.get $symbol:bytes-fill!)
                           (local.get $dest))
                     (unreachable)))

           ;; reject immutable byte strings
           (if (i32.eq (struct.get $Bytes $immutable (local.get $bs)) (i32.const 1))
               (then (call $raise-check-mutable-bytes/who
                           (global.get $symbol:bytes-fill!)
                           (local.get $dest))
                     (unreachable)))

           (local.set $val
                      (call $byte-value/i32/who
                            (global.get $symbol:bytes-fill!)
                            (local.get $b)))

           ;; Fill underlying byte array
           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (call $i8array-fill! (local.get $arr) (local.get $val))

           ;; return void
           (global.get $void))

     (func $bytes-append/who
           (param $who (ref eq))
           (param $xs  (ref eq))
           (result     (ref eq))

           (local $n     i32)
           (local $node  (ref $Pair))
           (local $b     (ref $Bytes))
           (local $orig  (ref eq))
           (local $total i32)
           (local $len   i32)
           (local $arr   (ref $I8Array))
           (local $pos   i32)

           (local.set $b (ref.cast (ref $Bytes) (global.get $bytes:empty)))
           (local.set $orig (local.get $xs))
           (local.set $n
                      (call $bytes-append-args-length/i32/who
                            (local.get $who)
                            (local.get $xs)))
           (if (i32.eqz (local.get $n))
               (then (return (global.get $bytes:empty))))

           (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
           (local.set $b
                      (ref.cast (ref $Bytes)
                                (struct.get $Pair $a (local.get $node))))
           (if (i32.eq (local.get $n) (i32.const 1))
               (then (return (call $bytes-copy (local.get $b)))))

           (local.set $total
                      (call $i8array-length
                            (struct.get $Bytes $bs (local.get $b))))
           (local.set $xs (struct.get $Pair $d (local.get $node)))
           (block $done1
                  (loop $loop1
                        (br_if $done1 (ref.eq (local.get $xs) (global.get $null)))
                        (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                        (local.set $b
                                   (ref.cast (ref $Bytes)
                                             (struct.get $Pair $a (local.get $node))))
                        (local.set $len
                                   (call $i8array-length
                                         (struct.get $Bytes $bs (local.get $b))))
                        (local.set $total (i32.add (local.get $total) (local.get $len)))
                        (local.set $xs (struct.get $Pair $d (local.get $node)))
                        (br $loop1)))
           (if (i32.eqz (local.get $total))
               (then (return (global.get $bytes:empty))))
           (local.set $arr (call $i8make-array (local.get $total) (i32.const 0)))

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
                              (i32.const 0)
                              (local.get $len))
                        (local.set $pos (i32.add (local.get $pos) (local.get $len)))
                        (local.set $xs (struct.get $Pair $d (local.get $node)))
                        (br $loop2)))

           (struct.new $Bytes
                       (i32.const 0)
                       (i32.const 0)
                       (local.get $arr)))

     (func $bytes-append (type $Prim>=0)
           (param  $xs   (ref eq))        ;; list of byte strings
           (result       (ref eq))

           (call $bytes-append/who
                 (global.get $symbol:bytes-append)
                 (local.get $xs)))

     (func $bytes-append/1
           (param $b (ref eq))
           (result (ref eq))

           (if (result (ref eq))
               (ref.test (ref $Bytes) (local.get $b))
               (then (call $bytes-copy (local.get $b)))
               (else (call $raise-check-bytes/who
                           (global.get $symbol:bytes-append)
                           (local.get $b))
                     (unreachable))))


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
               (else (call $raise-check-bytes/who
                           (global.get $symbol:bytes-append)
                           (local.get $b1))
                     (unreachable)))
           (if (ref.test (ref $Bytes) (local.get $b2))
               (then (local.set $bs2 (ref.cast (ref $Bytes) (local.get $b2))))
               (else (call $raise-check-bytes/who
                           (global.get $symbol:bytes-append)
                           (local.get $b2))
                     (unreachable)))
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
           (local $v    (ref eq))

           ;; initialize locals with no defaults
           (local.set $last (global.get $false))
           ;; no extra args: first arg supplies list of bytes
           (if (ref.eq (local.get $rest) (global.get $null))
               (then
                (drop (call $listof-bytes-length/i32/who
                            (global.get $symbol:bytes-append*)
                            (local.get $str)))
                (return (call $bytes-append/who
                              (global.get $symbol:bytes-append*)
                              (local.get $str)))))

           (if (i32.eqz (ref.test (ref $Bytes) (local.get $str)))
               (then
                (call $raise-check-bytes/who
                      (global.get $symbol:bytes-append*)
                      (local.get $str))
                (unreachable)))

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
                            (else
                             (local.set $v (struct.get $Pair $a (local.get $node)))
                             (if (i32.eqz (ref.test (ref $Bytes) (local.get $v)))
                                 (then
                                  (call $raise-check-bytes/who
                                        (global.get $symbol:bytes-append*)
                                        (local.get $v))
                                  (unreachable)))
                             (local.set $acc
                                             (struct.new $Pair
                                                         (i32.const 0)
                                                         (local.get $v)
                                                         (local.get $acc)))
                             (br $loop)))))

           (drop (call $listof-bytes-length/i32/who
                       (global.get $symbol:bytes-append*)
                       (local.get $last)))

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
           (call $bytes-append/who
                 (global.get $symbol:bytes-append*)
                 (local.get $args)))

     (func $bytes-join (type $Prim2)
          (param $strs (ref eq)) ;; listof bytes?
          (param $sep  (ref eq)) ;; bytes?
          (result      (ref eq))

          (local $xs      (ref eq))
          (local $node    (ref $Pair))
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
              (else (call $raise-check-bytes/who
                          (global.get $symbol:bytes-join)
                          (local.get $sep))
                    (unreachable)))
          ;; --- Determine separator length ---
          (local.set $sep-len
                     (call $i8array-length
                           (struct.get $Bytes $bs (local.get $sep-bs))))
          ;; --- Determine number of byte strings ---
          (local.set $n
                     (call $listof-bytes-length/i32/who
                           (global.get $symbol:bytes-join)
                           (local.get $strs)))
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
                       (local.set $bs
                                  (ref.cast (ref $Bytes)
                                            (struct.get $Pair $a (local.get $node))))
                       (local.set $len
                                  (call $i8array-length
                                        (struct.get $Bytes $bs (local.get $bs))))
                       (local.set $total (i32.add (local.get $total) (local.get $len)))
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
               (else (call $raise-check-bytes/who
                           (global.get $symbol:bytevector->u8-list)
                           (local.get $bstr))
                     (unreachable)))
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
           (local $bits i32)
           (local $v    i32)
           ;; Step 1: Compute length of list
           (local.set $len
                      (call $listof-byte-length/i32/who
                            (global.get $symbol:list->bytes)
                            (local.get $xs)))
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
                        (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $xs))))
                        (local.set $bits (i31.get_s (ref.cast (ref i31) (local.get $x))))
                        (local.set $v (i32.shr_s (local.get $bits) (i32.const 1)))
                        (call $i8array-set! (local.get $arr) (local.get $i) (local.get $v))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (local.set $xs (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $xs))))
                        (br $loop)))
           ;; Step 5: Return the byte string struct
           (local.get $bs))
     )))

;; byte-text-decoding-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for byte text-decoding helpers.
(define byte-text-decoding-runtime-only-helper-names
  '($raise-byte-string-index-out-of-range
    $raise-byte-string-end-before-start
    $raise-byte-string-range-error
    $raise-bytes-utf-8-length:bad-argument
    $raise-bytes-utf-8-length:invalid-err-char
    $raise-bytes-utf-8-length:range-error
    $bytes-utf-8-length
    $raise-bytes->string/latin-1
    $raise-bytes->string/latin-1:invalid-err-char
    $raise-bytes->string/latin-1:range-error
    $bytes->string/latin-1
    $raise-bytes->string/utf-8:bad-argument
    $raise-bytes->string/utf-8
    $raise-bytes->string/utf-8:invalid-err-char
    $raise-bytes->string/utf-8:range-error
    $bytes->string/utf-8
    $bytes->string/utf-8/defaults
    $bytes->string/utf-8/checked
    $bytes->string/utf-8:work
    $bytes->string/utf-8:determine-utf-8-sequence))

;; byte-text-decoding-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate byte string-to-text decoding helpers.
(define byte-text-decoding-runtime-only-helpers
  (function-forms->runtime-helpers
   'byte-text-decoding-runtime-only-helpers
   `(
     (func $raise-byte-string-index-out-of-range
           (param $who         (ref eq))
           (param $reason      (ref eq))
           (param $index-label (ref eq))
           (param $bstr        (ref eq))
           (param $idx         i32)
           (param $len         i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 9)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $who)))
           (call $growable-array-add! (local.get $out)
                 (local.get $reason))
           (call $growable-array-add! (local.get $out)
                 (local.get $index-label))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (call $integer-from-i64
                             (i64.extend_i32_u (local.get $idx)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-ref:valid-range))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (call $integer-from-i64
                             (i64.extend_i32_u (local.get $len)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-ref:valid-range-close))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-utf8:byte-string))
           (call $growable-array-add! (local.get $out)
                 (call $format/error-value->string (local.get $bstr)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (call $raise
                 (call $exn:fail:contract/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $raise-byte-string-end-before-start
           (param $who   (ref eq))
           (param $bstr  (ref eq))
           (param $start i32)
           (param $end   i32)
           (param $len   i32)

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 11)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display (local.get $who)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:substring:ending-index-before-start))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:substring:ending-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (call $integer-from-i64
                             (i64.extend_i32_u (local.get $end)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:substring:starting-index))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (call $integer-from-i64
                             (i64.extend_i32_u (local.get $start)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-ref:valid-range))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (call $integer-from-i64
                             (i64.extend_i32_u (local.get $len)))))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-ref:valid-range-close))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-utf8:byte-string))
           (call $growable-array-add! (local.get $out)
                 (call $format/error-value->string (local.get $bstr)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (call $raise
                 (call $exn:fail:contract/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $raise-byte-string-range-error
           (param $who   (ref eq))
           (param $bstr  (ref eq))
           (param $start i32)
           (param $end   i32)
           (param $len   i32)

           (if (i32.gt_u (local.get $start) (local.get $len))
               (then (call $raise-byte-string-index-out-of-range
                           (local.get $who)
                           (global.get $string:substring:starting-index-out-of-range)
                           (global.get $string:substring:starting-index)
                           (local.get $bstr)
                           (local.get $start)
                           (local.get $len))
                     (unreachable)))
           (if (i32.gt_u (local.get $end) (local.get $len))
               (then (call $raise-byte-string-index-out-of-range
                           (local.get $who)
                           (global.get $string:substring:ending-index-out-of-range)
                           (global.get $string:substring:ending-index)
                           (local.get $bstr)
                           (local.get $end)
                           (local.get $len))
                     (unreachable)))
           (call $raise-byte-string-end-before-start
                 (local.get $who)
                 (local.get $bstr)
                 (local.get $start)
                 (local.get $end)
                 (local.get $len))
           (unreachable))

     (func $raise-bytes-utf-8-length:bad-argument
           (param $expected (ref eq))
           (param $bad      (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:bytes-utf-8-length)
                 (local.get $expected)
                 (local.get $bad))
           (unreachable))

     (func $raise-bytes-utf-8-length:invalid-err-char
           (param $bad (ref eq))
           (call $raise-bytes-utf-8-length:bad-argument
                 (global.get $string:char-or-false?)
                 (local.get $bad))
           (unreachable))

     (func $raise-bytes-utf-8-length:range-error
           (param $bstr  (ref eq))
           (param $start i32)
           (param $end   i32)
           (param $len   i32)
           (call $raise-byte-string-range-error
                 (global.get $symbol:bytes-utf-8-length)
                 (local.get $bstr)
                 (local.get $start)
                 (local.get $end)
                 (local.get $len))
           (unreachable))

     (func $bytes-utf-8-length (type $Prim14)
           (param $bstr         (ref eq)) ; bytes?
           (param $err-char     (ref eq)) ; optional char?, defaults to #f
           (param $start-raw    (ref eq)) ; optional exact-nonnegative-integer?, defaults to 0
           (param $end-raw      (ref eq)) ; optional exact-nonnegative-integer?, defaults to (bytes-length bstr)
           (result              (ref eq))

           (local $bs           (ref null $Bytes))
           (local $arr          (ref $I8Array))
           (local $len          i32)
           (local $start        i32)
           (local $end          i32)
           (local $use-err-char i32)
           (local $i            i32)
           (local $byte         i32)
           (local $need         i32)
           (local $acc          i32)
           (local $b2           i32)
           (local $count        i32)
           (local $raw-err-char i32)

           ;; --- Type check for bytes argument ---
           (if (ref.test (ref $Bytes) (local.get $bstr))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
               (else (call $raise-bytes-utf-8-length:bad-argument
                           (global.get $string:bytes?)
                           (local.get $bstr))))
           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (local.set $len (array.len (local.get $arr)))

           ;; --- Decode optional start ---
           (if (ref.eq (local.get $start-raw) (global.get $missing))
               (then (local.set $start (i32.const 0)))
               (else (local.set $start
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes-utf-8-length)
                                      (local.get $start-raw)))))

           ;; --- Decode optional end ---
           (if (ref.eq (local.get $end-raw) (global.get $missing))
               (then (local.set $end (local.get $len)))
               (else (local.set $end
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes-utf-8-length)
                                      (local.get $end-raw)))))

           ;; --- Decode optional err-char ---
           (if (ref.eq (local.get $err-char) (global.get $missing))
               (then (local.set $use-err-char (i32.const 0)))
               (else (if (ref.eq (local.get $err-char) (global.get $false))
                         (then (local.set $use-err-char (i32.const 0)))
                         (else (if (ref.test (ref i31) (local.get $err-char))
                                   (then (local.set $raw-err-char
                                                    (i31.get_s
                                                     (ref.cast (ref i31) (local.get $err-char))))
                                         (if (i32.eq (i32.and (local.get $raw-err-char)
                                                             (i32.const ,char-mask))
                                                     (i32.const ,char-tag))
                                             (then (local.set $use-err-char (i32.const 1)))
                                             (else (call $raise-bytes-utf-8-length:invalid-err-char
                                                         (local.get $err-char)))))
                                   (else (call $raise-bytes-utf-8-length:invalid-err-char
                                               (local.get $err-char))))))))

           ;; --- Range checks ---
           (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                       (i32.gt_u (local.get $end) (local.get $len)))
               (then (call $raise-bytes-utf-8-length:range-error
                           (local.get $bstr)
                           (local.get $start)
                           (local.get $end)
                           (local.get $len))))

           ;; --- Main decoding loop ---
           (local.set $i     (local.get $start))
           (local.set $count (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $end)))
                        (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $i)))
                        ;; ASCII fast path
                        (if (i32.lt_u (local.get $byte) (i32.const 128))
                            (then
                             (local.set $count (i32.add (local.get $count) (i32.const 1)))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $loop)))

                        (call $bytes->string/utf-8:determine-utf-8-sequence (local.get $byte))
                        (local.set $acc) (local.set $need)

                        ;; Invalid lead byte
                        (if (i32.lt_s (local.get $need) (i32.const 0))
                            (then
                             (if (i32.eqz (local.get $use-err-char))
                                 (then (return (global.get $false)))
                                 (else
                                  (local.set $count (i32.add (local.get $count) (i32.const 1)))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $loop)))))

                        ;; Not enough bytes left in substring
                        (if (i32.gt_u (i32.add (local.get $i) (local.get $need)) (local.get $end))
                            (then
                             (if (i32.eqz (local.get $use-err-char))
                                 (then (return (global.get $false)))
                                 (else
                                  (local.set $count (i32.add (local.get $count) (i32.const 1)))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $loop)))))

                        ;; Consume continuation bytes
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (block $cont-fail
                               (loop $cont-loop
                                     (br_if $cont-fail (i32.eqz (local.get $need)))
                                     (local.set $b2 (array.get_u $I8Array (local.get $arr) (local.get $i)))
                                     (if (i32.and (i32.ge_u (local.get $b2) (i32.const 128))
                                                  (i32.lt_u (local.get $b2) (i32.const 192)))
                                         (then
                                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                          (local.set $need (i32.sub (local.get $need) (i32.const 1)))
                                          (br $cont-loop)))))

                        ;; Invalid continuation sequence
                        (if (i32.ne (local.get $need) (i32.const 0))
                            (then
                             (if (i32.eqz (local.get $use-err-char))
                                 (then (return (global.get $false)))
                                 (else
                                  (local.set $count (i32.add (local.get $count) (i32.const 1)))
                                  (br $loop)))))

                        ;; Successful multi-byte sequence
                        (local.set $count (i32.add (local.get $count) (i32.const 1)))
                        (br $loop)))

           (ref.i31 (i32.shl (local.get $count) (i32.const 1))))

     (func $raise-bytes->string/latin-1
           (param $expected (ref eq))
           (param $bad      (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:bytes->string/latin-1)
                 (local.get $expected)
                 (local.get $bad))
           (unreachable))

     (func $raise-bytes->string/latin-1:invalid-err-char
           (param $bad (ref eq))
           (call $raise-bytes->string/latin-1
                 (global.get $string:char-or-false?)
                 (local.get $bad))
           (unreachable))

     (func $raise-bytes->string/latin-1:range-error
           (param $bstr  (ref eq))
           (param $start i32)
           (param $end   i32)
           (param $len   i32)
           (call $raise-byte-string-range-error
                 (global.get $symbol:bytes->string/latin-1)
                 (local.get $bstr)
                 (local.get $start)
                 (local.get $end)
                 (local.get $len))
           (unreachable))

     (func $bytes->string/latin-1 (type $Prim14)
           (param $bstr      (ref eq)) ; bytes?
           (param $err-char  (ref eq)) ; optional char?, defaults to #f
           (param $start-raw (ref eq)) ; optional exact-nonnegative-integer?, defaults to 0
           (param $end-raw   (ref eq)) ; optional exact-nonnegative-integer?, defaults to (bytes-length bstr)
           (result           (ref eq))

           (local $bs          (ref null $Bytes))
           (local $arr         (ref $I8Array))
           (local $len         i32)
           (local $start       i32)
           (local $end         i32)
           (local $count       i32)
           (local $codepoints  (ref $I32Array))
           (local $i           i32)
           (local $idx         i32)
           (local $byte        i32)
           (local $raw-err     i32)

           ;; --- Validate byte string argument ---
           (if (ref.test (ref $Bytes) (local.get $bstr))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
               (else (call $raise-bytes->string/latin-1
                           (global.get $string:bytes?)
                           (local.get $bstr))))
           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           (local.set $len (array.len (local.get $arr)))

           ;; --- Decode optional start ---
           (if (ref.eq (local.get $start-raw) (global.get $missing))
               (then (local.set $start (i32.const 0)))
               (else (local.set $start
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes->string/latin-1)
                                      (local.get $start-raw)))))

           ;; --- Decode optional end ---
           (if (ref.eq (local.get $end-raw) (global.get $missing))
               (then (local.set $end (local.get $len)))
               (else (local.set $end
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes->string/latin-1)
                                      (local.get $end-raw)))))

           ;; --- Validate optional err-char (ignored value) ---
           (if (ref.eq (local.get $err-char) (global.get $missing))
               (then (nop))
               (else (if (ref.eq (local.get $err-char) (global.get $false))
                         (then (nop))
                         (else (if (ref.test (ref i31) (local.get $err-char))
                                   (then (local.set $raw-err
                                                    (i31.get_s
                                                     (ref.cast (ref i31) (local.get $err-char))))
                                         (if (i32.ne (i32.and (local.get $raw-err)
                                                             (i32.const ,char-mask))
                                                     (i32.const ,char-tag))
                                             (then (call $raise-bytes->string/latin-1:invalid-err-char
                                                         (local.get $err-char)))))
                                   (else (call $raise-bytes->string/latin-1:invalid-err-char
                                               (local.get $err-char))))))))

           ;; --- Range checks ---
           (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                       (i32.gt_u (local.get $end) (local.get $len)))
               (then (call $raise-bytes->string/latin-1:range-error
                           (local.get $bstr)
                           (local.get $start)
                           (local.get $end)
                           (local.get $len))))

           ;; --- Allocate codepoint array and copy bytes ---
           (local.set $count (i32.sub (local.get $end) (local.get $start)))
           (local.set $codepoints (call $i32array-make (local.get $count) (i32.const 0)))
           (local.set $i    (i32.const 0))
           (local.set $idx  (local.get $start))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
                        (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $idx)))
                        (array.set $I32Array (local.get $codepoints) (local.get $i) (local.get $byte))
                        (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                        (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
                        (br $loop)))

           (call $i32array->immutable-string (local.get $codepoints)))


     (func $raise-bytes->string/utf-8:bad-argument
           (param $expected (ref eq))
           (param $bad      (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:bytes->string/utf-8)
                 (local.get $expected)
                 (local.get $bad))
           (unreachable))

     (func $raise-bytes->string/utf-8
           (param $bstr (ref eq))

           (local $out     (ref $GrowableArray))
           (local $message (ref $String))

           (local.set $out (call $make-growable-array (i32.const 4)))
           (call $growable-array-add! (local.get $out)
                 (call $format/display
                       (global.get $symbol:bytes->string/utf-8)))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:bytes->string/utf-8:bad-encoding))
           (call $growable-array-add! (local.get $out)
                 (global.get $string:string-utf8:byte-string))
           (call $growable-array-add! (local.get $out)
                 (call $format/error-value->string (local.get $bstr)))
           (local.set $message
                      (call $growable-array-of-strings->string (local.get $out)))
           (call $raise
                 (call $exn:fail:contract/make
                       (local.get $message)
                       (call $current-continuation-marks (global.get $missing)))
                 (global.get $true))
           (unreachable))

     (func $raise-bytes->string/utf-8:invalid-err-char
           (param $bad (ref eq))
           (call $raise-bytes->string/utf-8:bad-argument
                 (global.get $string:char-or-false?)
                 (local.get $bad))
           (unreachable))

     (func $raise-bytes->string/utf-8:range-error
           (param $bstr  (ref eq))
           (param $start i32)
           (param $end   i32)
           (param $len   i32)
           (call $raise-byte-string-range-error
                 (global.get $symbol:bytes->string/utf-8)
                 (local.get $bstr)
                 (local.get $start)
                 (local.get $end)
                 (local.get $len))
           (unreachable))

     (func $bytes->string/utf-8 (type $Prim14)
           (param $bstr         (ref eq))
           (param $err-char     (ref eq)) ; optional character?, defaults to #f
           (param $start-raw    (ref eq)) ; optional exact-nonnegative-integer?, defaults to 0
           (param $end-raw      (ref eq)) ; optional exact-nonnegative-integer?, defaults to (bytes-length bstr)
           (result              (ref eq))

           (local $bs               (ref null $Bytes))
           (local $len              i32)
           (local $start            i32)
           (local $end              i32)
           (local $use-err-char     i32)
           (local $decoded-err-char i32)
           (local $raw-err-char     i32)

           ;; Cast input to $Bytes
           (if (ref.test (ref $Bytes) (local.get $bstr))
               (then (local.set $bs (ref.cast (ref $Bytes) (local.get $bstr))))
               (else (call $raise-bytes->string/utf-8:bad-argument
                           (global.get $string:bytes?)
                           (local.get $bstr))))
           (local.set $len (array.len (struct.get $Bytes $bs (local.get $bs))))
           ;; Decode start
           (if (ref.eq (local.get $start-raw) (global.get $missing))
               (then (local.set $start (i32.const 0)))
               (else (local.set $start
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes->string/utf-8)
                                      (local.get $start-raw)))))
           ;; Decode end
           (if (ref.eq (local.get $end-raw) (global.get $missing))
               (then (local.set $end (local.get $len)))
               (else (local.set $end
                                (call $bytes-index/i32
                                      (global.get $symbol:bytes->string/utf-8)
                                      (local.get $end-raw)))))
           ;; Decode err-char
           (if (ref.eq (local.get $err-char) (global.get $missing))
               ; missing
               (then (local.set $use-err-char     (i32.const 0))
                     (local.set $decoded-err-char (i32.const 0)))
               (else
                ; false
                (if (ref.eq (local.get $err-char) (global.get $false))
                    (then (local.set $use-err-char     (i32.const 0))
                          (local.set $decoded-err-char (i32.const 0)))
                    (else
                     ; character
                     (if (ref.test (ref i31) (local.get $err-char))
                         (then (local.set $raw-err-char
                                          (i31.get_s
                                           (ref.cast (ref i31) (local.get $err-char))))
                               (if (i32.eq (i32.and (local.get $raw-err-char)
                                                   (i32.const ,char-mask))
                                           (i32.const ,char-tag))
                                   (then (local.set $use-err-char (i32.const 1))
                                         (local.set $decoded-err-char
                                                    (i32.shr_u
                                                     (local.get $raw-err-char)
                                                     (i32.const ,char-shift))))
                                   (else (call $raise-bytes->string/utf-8:invalid-err-char
                                               (local.get $err-char)))))
                         (else (call $raise-bytes->string/utf-8:invalid-err-char
                                     (local.get $err-char))))))))
           ;; Range check
           (if (i32.or (i32.gt_u (local.get $start) (local.get $end))
                       (i32.gt_u (local.get $end) (local.get $len)))
               (then (call $raise-bytes->string/utf-8:range-error
                           (local.get $bstr)
                           (local.get $start)
                           (local.get $end)
                           (local.get $len))))
           ;; Delegate to implementation
           (call $bytes->string/utf-8:work
                 (ref.as_non_null (local.get $bs))
                 (local.get $use-err-char)
                 (local.get $decoded-err-char)
                 (local.get $start)
                 (local.get $end)))

     (func $bytes->string/utf-8/defaults
           (param $bs (ref $Bytes))
           (result (ref $String))
           (ref.cast (ref $String)
                     (call $bytes->string/utf-8
                           (local.get $bs)
                           (global.get $missing)    ;; err-char = #f
                           (global.get $missing)    ;; start    = 0
                           (global.get $missing)))) ;; end      = full length

     (func $bytes->string/utf-8/checked
           (param $bs (ref $Bytes))
           (result (ref $String))
           (local $end i32)
           (local.set $end (array.len (struct.get $Bytes $bs (local.get $bs))))
           (call $bytes->string/utf-8:work
                 (local.get $bs)
                 (i32.const 0)   ;; use-err-char? = false
                 (i32.const 0)   ;; err-char = dummy
                 (i32.const 0)   ;; start
                 (local.get $end)))

     (func $bytes->string/utf-8:work
           (param $bs           (ref $Bytes))
           (param $use-err-char i32)
           (param $err-char     i32)
           (param $start        i32)
           (param $end          i32)
           (result              (ref $String))

           (local $buf  (ref $I32GrowableArray))
           (local $arr  (ref $I8Array))
           (local $i    i32)
           (local $byte i32)
           (local $need i32)
           (local $acc  i32)
           (local $b2   i32)
           (local $cp   i32)

           ;; Get underlying I8Array from Bytes
           (local.set $arr (struct.get $Bytes $bs (local.get $bs)))
           ;; Allocate buffer for codepoints
           (local.set $buf (call $make-i32growable-array (i32.const 16)))
           ;; Start decoding loop
           (local.set $i (local.get $start))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $end)))
                        (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $i)))
                        ;; ASCII fast path
                        (if (i32.lt_u (local.get $byte) (i32.const 128))
                            (then
                             (call $i32growable-array-add! (local.get $buf) (local.get $byte))
                             (local.set $i (i32.add (local.get $i) (i32.const 1)))
                             (br $loop)))
                        ;; Determine UTF-8 sequence size and initial accumulator
                        (call $bytes->string/utf-8:determine-utf-8-sequence (local.get $byte))
                        (local.set $acc) (local.set $need)
                        ;; Invalid lead byte
                        (if (i32.lt_s (local.get $need) (i32.const 0))
                            (then
                             (if (i32.eqz (local.get $use-err-char))
                                 (then (call $raise-bytes->string/utf-8
                                             (local.get $bs)))
                                 (else
                                  (call $i32growable-array-add! (local.get $buf) (local.get $err-char))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $loop)))))
                        ;; Not enough bytes left
                        (if (i32.gt_u (i32.add (local.get $i) (local.get $need)) (local.get $end))
                            (then
                             (if (i32.eqz (local.get $use-err-char))
                                 (then (call $raise-bytes->string/utf-8
                                             (local.get $bs)))
                                 (else
                                  (call $i32growable-array-add! (local.get $buf) (local.get $err-char))
                                  (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                  (br $loop)))))
                        ;; Decode continuation bytes
                        (local.set $cp (local.get $acc))
                        (local.set $i (i32.add (local.get $i) (i32.const 1))) ;; skip lead byte
                        (block $cont-fail
                               (loop $cont-loop
                                     (br_if $cont-fail (i32.eqz (local.get $need)))
                                     (local.set $b2 (array.get_u $I8Array (local.get $arr) (local.get $i)))
                                     (if (i32.and
                                          (i32.ge_u (local.get $b2) (i32.const 128))
                                          (i32.lt_u (local.get $b2) (i32.const 192)))
                                         (then
                                          (local.set $cp
                                                     (i32.or
                                                      (i32.shl (local.get $cp) (i32.const 6))
                                                      (i32.and (local.get $b2) (i32.const 0x3F))))
                                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                          (local.set $need (i32.sub (local.get $need) (i32.const 1)))
                                          (br $cont-loop)))))
                        ;; If we didn't finish the sequence, it's invalid
                        (if (i32.ne (local.get $need) (i32.const 0))
                            (then
                             (if (i32.eqz (local.get $use-err-char))
                                 (then (call $raise-bytes->string/utf-8
                                             (local.get $bs)))
                                 (else
                                  (call $i32growable-array-add! (local.get $buf) (local.get $err-char))
                                  (br $loop)))))
                        ;; Valid sequence
                        (call $i32growable-array-add! (local.get $buf) (local.get $cp))
                        (br $loop)))
           ;; Convert buffer to immutable string
           (call $i32growable-array->immutable-string (local.get $buf)))


     (func $bytes->string/utf-8:determine-utf-8-sequence ; returns two i32s
           ; This function determines how many continuation bytes are needed for
           ; a given UTF-8 lead byte, and extracts the initial bits for the code point accumulator.
           (param $lead i32)
           (result i32  i32) ;; (need acc) or (-1 -1) if invalid

           (if (i32.and (i32.ge_u (local.get $lead) (i32.const 0xC0))
                        (i32.lt_u (local.get $lead) (i32.const 0xE0)))
               (then (return (i32.const 1) (i32.and (local.get $lead) (i32.const 0x1F)))))

           (if (i32.and (i32.ge_u (local.get $lead) (i32.const 0xE0))
                        (i32.lt_u (local.get $lead) (i32.const 0xF0)))
               (then (return (i32.const 2) (i32.and (local.get $lead) (i32.const 0x0F)))))

           (if (i32.and (i32.ge_u (local.get $lead) (i32.const 0xF0))
                        (i32.lt_u (local.get $lead) (i32.const 0xF8)))
               (then (return (i32.const 3) (i32.and (local.get $lead) (i32.const 0x07)))))

           ;; Not a valid lead byte
           (return (i32.const -1) (i32.const -1)))
     )))

;; bytes-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given byte-string helper names from the runtime helper index.
(define (bytes-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; bytes-mutability-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render bytes mutability predicates in runtime assembly order.
(define (bytes-mutability-runtime-helper-forms helper-index)
  (bytes-helper-forms helper-index bytes-mutability-runtime-only-helper-names))

;; bytes-main-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render the main 4.3 byte-string helper block in runtime assembly order.
(define (bytes-main-runtime-helper-forms helper-index)
  (append
   (bytes-helper-forms helper-index bytes-basic-runtime-only-helper-names)
   (bytes-helper-forms helper-index byte-comparison-runtime-only-helper-names)
   (bytes-helper-forms helper-index byte-indexing-runtime-only-helper-names)
   (bytes-helper-forms helper-index byte-converter-runtime-only-helper-names)
   (bytes-helper-forms helper-index byte-sequence-runtime-only-helper-names)
   (bytes-helper-forms helper-index byte-text-decoding-runtime-only-helper-names)))

;; bytes-mutability-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate bytes mutability predicates.
(define bytes-mutability-runtime-helpers
  (function-forms->runtime-helpers
   'bytes-mutability-runtime-helpers
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


     )))

;; bytes-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate byte-string helpers in monolithic runtime order.
(define bytes-all-runtime-helpers
  (append
   bytes-basic-runtime-only-helpers
   byte-comparison-runtime-only-helpers
   byte-indexing-runtime-only-helpers
   byte-converter-runtime-only-helpers
   byte-sequence-runtime-only-helpers
   byte-text-decoding-runtime-only-helpers
   bytes-mutability-runtime-helpers))

;; bytes-core-runtime-helper-names : (listof symbol?)
;;   Name byte-string helpers available in the standalone core runtime.
(define bytes-core-runtime-helper-names
  (append bytes-basic-runtime-only-helper-names
          byte-comparison-runtime-only-helper-names
          byte-indexing-runtime-only-helper-names
          byte-converter-runtime-only-helper-names
          byte-sequence-runtime-only-helper-names
          byte-text-decoding-runtime-only-helper-names
          bytes-mutability-runtime-only-helper-names))

;; select-bytes-helpers : (listof core-runtime-helper?) (listof symbol?) -> (listof core-runtime-helper?)
;;   Select helpers by name while preserving the order of the source list.
(define (select-bytes-helpers helpers names)
  (define name-set
    (for/hasheq ([name (in-list names)])
      (values name #t)))
  (for/list ([helper (in-list helpers)]
             #:when (hash-ref name-set (core-runtime-helper-name helper) #f))
    helper))

;; bytes-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate byte-string helpers available in the standalone core runtime.
(define bytes-core-runtime-helpers
  (select-bytes-helpers bytes-all-runtime-helpers
                        bytes-core-runtime-helper-names))

;; bytes-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate bytes helpers that still depend on monolithic runtime globals.
(define bytes-runtime-only-helpers
  (let ([core-name-set
         (for/hasheq ([name (in-list bytes-core-runtime-helper-names)])
           (values name #t))])
    (for/list ([helper (in-list bytes-all-runtime-helpers)]
               #:unless (hash-ref core-name-set
                                  (core-runtime-helper-name helper)
                                  #f))
      helper)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define bytes-helper-index
    (make-core-runtime-helper-index
     (append bytes-core-runtime-helpers
             bytes-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name bytes-core-runtime-helpers)
   bytes-core-runtime-helper-names)

  (check-equal?
   (map form-name (bytes-mutability-runtime-helper-forms bytes-helper-index))
   bytes-mutability-runtime-only-helper-names)

  (check-equal?
   (map form-name (bytes-main-runtime-helper-forms bytes-helper-index))
   (append bytes-basic-runtime-only-helper-names
           byte-comparison-runtime-only-helper-names
           byte-indexing-runtime-only-helper-names
           byte-converter-runtime-only-helper-names
           byte-sequence-runtime-only-helper-names
           byte-text-decoding-runtime-only-helper-names)))
