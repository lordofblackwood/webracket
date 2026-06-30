#lang racket

(provide i8-array-core-runtime-helpers)

(require "../core-helper.rkt")

;; i8-array-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate I8Array helpers that can be emitted in core runtime.
(define i8-array-core-runtime-helpers
  (list
   ;;;
   ;;; I8Array
   ;;;

   ; (type $I8Array (array (mut i8)))

   (core-runtime-helper
    '$i8make-array
    "$i8make-array"
    (lambda ()
      `(func $i8make-array (param $size i32) (param $v i32) (result (ref $I8Array))
             (array.new $I8Array (local.get $v) (local.get $size)))))

   (core-runtime-helper
    '$i8array-length
    "$i8array-length"
    (lambda ()
      `(func $i8array-length
             (param $arr (ref $I8Array))
             (result i32)
             (array.len (local.get $arr)))))

   (core-runtime-helper
    '$i8array-ref
    "$i8array-ref"
    (lambda ()
      `(func $i8array-ref
             (param $arr (ref $I8Array)) (param $pos i32)
             (result i32)
             (array.get_u $I8Array (local.get $arr) (local.get $pos)))))

   (core-runtime-helper
    '$i8array-set!
    "$i8array-set!"
    (lambda ()
      `(func $i8array-set!
             (param $arr (ref $I8Array)) (param $pos i32) (param $v i32)
             (array.set $I8Array (local.get $arr) (local.get $pos) (local.get $v)))))

   (core-runtime-helper
    '$i8array-fill!
    "$i8array-fill!"
    (lambda ()
      `(func $i8array-fill!
             (param $arr (ref $I8Array)) (param $v i32)
             (local $i i32)
             (local.set $i (i32.const 0))
             (block $exit
                    (loop $fill
                          (br_if $exit (i32.ge_u (local.get $i) (array.len (local.get $arr))))
                          (array.set $I8Array (local.get $arr) (local.get $i) (local.get $v))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $fill))))))

   (core-runtime-helper
    '$i8array-copy!
    "$i8array-copy!"
    (lambda ()
      `(func $i8array-copy!
             (param $dest (ref $I8Array))
             (param $dest-start i32)
             (param $src (ref $I8Array))
             (param $src-start i32)
             (param $src-end i32)
             (local $src-len i32)
             (local $dest-len i32)
             (local $len i32)
             (local.set $src-len (array.len (local.get $src)))
             (local.set $dest-len (array.len (local.get $dest)))
             (if (i32.or
                  (i32.or (i32.lt_u (local.get $src-start) (i32.const 0))
                          (i32.gt_u (local.get $src-end) (local.get $src-len)))
                  (i32.gt_u (i32.add (local.get $dest-start)
                                     (i32.sub (local.get $src-end) (local.get $src-start)))
                            (local.get $dest-len)))
                 (then (unreachable)))
             (local.set $len (i32.sub (local.get $src-end) (local.get $src-start)))
             (array.copy $I8Array $I8Array
                         (local.get $dest) (local.get $dest-start)
                         (local.get $src)  (local.get $src-start)
                         (local.get $len)))))

   (core-runtime-helper
    '$i8array-copy!/error
    "$i8array-copy!/error"
    (lambda ()
      `(func $i8array-copy!/error
             (param $dest (ref $I8Array))
             (param $dest-start i32)
             (param $src (ref $I8Array))
             (param $src-start i32)
             (param $src-end i32)
             (result i32)
             (local $src-len i32)
             (local $dest-len i32)
             (local $len i32)
             (local.set $src-len (array.len (local.get $src)))
             (local.set $dest-len (array.len (local.get $dest)))
             (if (i32.or
                  (i32.or (i32.lt_u (local.get $src-start) (i32.const 0))
                          (i32.gt_u (local.get $src-end) (local.get $src-len)))
                  (i32.gt_u (i32.add (local.get $dest-start)
                                     (i32.sub (local.get $src-end) (local.get $src-start)))
                            (local.get $dest-len)))
                 (then (return (i32.const 0))))
             (local.set $len (i32.sub (local.get $src-end) (local.get $src-start)))
             (array.copy $I8Array $I8Array
                         (local.get $dest) (local.get $dest-start)
                         (local.get $src)  (local.get $src-start)
                         (local.get $len))
             (i32.const 1))))

   (core-runtime-helper
    '$i8array-copy
    "$i8array-copy"
    (lambda ()
      `(func $i8array-copy (param $arr (ref $I8Array)) (param $start i32) (param $end i32) (result (ref $I8Array))
             (local $res (ref $I8Array))
             (local.set $res (call $i8make-array (i32.sub (local.get $end) (local.get $start)) (i32.const 0)))
             (call $i8array-copy! (local.get $res) (i32.const 0) (local.get $arr) (local.get $start) (local.get $end))
             (local.get $res))))

   (core-runtime-helper
    '$i8array-set/copy
    "$i8array-set/copy"
    (lambda ()
      `(func $i8array-set/copy (param $arr (ref $I8Array)) (param $pos i32) (param $val i32) (result (ref $I8Array))
             (local $len i32)
             (local $res (ref $I8Array))
             (local.set $len (array.len (local.get $arr)))
             (local.set $res (call $i8make-array (local.get $len) (i32.const 0)))
             (call $i8array-copy! (local.get $res) (i32.const 0) (local.get $arr) (i32.const 0) (local.get $len))
             (call $i8array-set! (local.get $res) (local.get $pos) (local.get $val))
             (local.get $res))))

   (core-runtime-helper
    '$i8array-extend
    "$i8array-extend"
    (lambda ()
      `(func $i8array-extend (param $arr (ref $I8Array)) (param $new-size i32) (param $val i32) (result (ref $I8Array))
             (local $old-size i32)
             (local $res (ref $I8Array))
             (local.set $old-size (array.len (local.get $arr)))
             (local.set $res (call $i8make-array (local.get $new-size) (local.get $val)))
             (call $i8array-copy! (local.get $res) (i32.const 0) (local.get $arr) (i32.const 0) (local.get $old-size))
             (local.get $res))))

   (core-runtime-helper
    '$i8array-append
    "$i8array-append"
    (lambda ()
      `(func $i8array-append
             (param $a0  (ref $I8Array))
             (param $a1  (ref $I8Array))
             (result     (ref $I8Array))

             (local $n0  i32)
             (local $n1  i32)
             (local $res (ref $I8Array))

             (local.set $n0  (array.len (local.get $a0)))
             (local.set $n1  (array.len (local.get $a1)))
             (local.set $res (array.new $I8Array (i32.const 0) (i32.add (local.get $n0) (local.get $n1))))
             (call $i8array-copy! (local.get $res) (i32.const 0)   (local.get $a0) (i32.const 0) (local.get $n0))
             (call $i8array-copy! (local.get $res) (local.get $n0) (local.get $a1) (i32.const 0) (local.get $n1))
             (local.get $res))))))
