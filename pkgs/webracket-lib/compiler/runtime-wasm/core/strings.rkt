#lang racket

(provide string-core-runtime-helpers)

(require "../core-helper.rkt")

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
