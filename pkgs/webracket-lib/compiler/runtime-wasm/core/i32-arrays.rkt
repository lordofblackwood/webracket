#lang racket

(provide i32-array-core-runtime-helper-forms
         i32-array-core-runtime-helper-names
         i32-array-core-runtime-helpers
         i32-array-runtime-only-helper-names
         i32-array-runtime-helper-forms
         i32-array-runtime-only-helpers)

(require "../core-helper.rkt")

;; i32-array-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate I32Array helpers that can be emitted in core runtime.
(define i32-array-core-runtime-helpers
  (list
   ;;;
   ;;; I32Array - Arrays of i32
   ;;;

   ; (type $I32Array (array (mut i32)))

   (core-runtime-helper
    '$i32array-make
    "$i32array-make"
    (lambda ()
      `(func $i32array-make (param $size i32) (param $v i32) (result (ref $I32Array))
             (array.new $I32Array (local.get $v) (local.get $size)))))

   (core-runtime-helper
    '$i32array-length
    "$i32array-length"
    (lambda ()
      `(func $i32array-length (param $arr (ref $I32Array)) (result i32)
             (array.len (local.get $arr)))))

   (core-runtime-helper
    '$i32array-ref
    "$i32array-ref"
    (lambda ()
      `(func $i32array-ref (param $arr (ref $I32Array)) (param $pos i32) (result i32)
             (array.get $I32Array (local.get $arr) (local.get $pos)))))

   (core-runtime-helper
    '$i32array-set!
    "$i32array-set!"
    (lambda ()
      `(func $i32array-set! (param $arr (ref $I32Array)) (param $pos i32) (param $v i32)
             (array.set $I32Array (local.get $arr) (local.get $pos) (local.get $v)))))

   (core-runtime-helper
    '$i32array-equal?
    "$i32array-equal?"
    (lambda ()
      `(func $i32array-equal?
             (param $a (ref $I32Array)) (param $b (ref $I32Array))
             (result i32)

             (local $len i32)
             (local $i   i32)
             ;; Compare lengths
             (if (i32.ne (array.len (local.get $a))
                         (array.len (local.get $b)))
                 (then (return (i32.const 0))))
             ;; Set up loop
             (local.set $len (array.len (local.get $a)))
             (local.set $i (i32.const 0))
             (block $exit
                    (loop $loop
                          (br_if $exit (i32.ge_u (local.get $i) (local.get $len)))
                          (if (i32.ne
                               (array.get $I32Array (local.get $a) (local.get $i))
                               (array.get $I32Array (local.get $b) (local.get $i)))
                              (then (return (i32.const 0))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (i32.const 1))))

   (core-runtime-helper
    '$i32array-fill!
    "$i32array-fill!"
    (lambda ()
      `(func $i32array-fill! (param $arr (ref $I32Array)) (param $v i32)
             (local $i i32)
             (local.set $i (i32.const 0))
             (block $exit
                    (loop $fill
                          (br_if $exit (i32.ge_u (local.get $i) (array.len (local.get $arr))))
                          (array.set $I32Array (local.get $arr) (local.get $i) (local.get $v))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $fill))))))

   (core-runtime-helper
    '$i32array-copy!
    "$i32array-copy!"
    (lambda ()
      `(func $i32array-copy!
             (param $dest       (ref $I32Array))
             (param $dest-start i32)
             (param $src        (ref $I32Array))
             (param $src-start  i32)
             (param $src-end    i32)
             (local $len        i32)

             (local.set $len (i32.sub (local.get $src-end) (local.get $src-start)))
             (array.copy $I32Array $I32Array
                         (local.get $dest) (local.get $dest-start)
                         (local.get $src)  (local.get $src-start)
                         (local.get $len)))))

   (core-runtime-helper
    '$i32array-copy!/error
    "$i32array-copy!/error"
    (lambda ()
      `(func $i32array-copy!/error (param $dest (ref $I32Array)) (param $dest-start i32)
             (param $src (ref $I32Array)) (param $src-start i32) (param $src-end i32)
             (result i32)
             (local $src-len i32)
             (local $dest-len i32)
             (local $len i32)
             (local.set $src-len (array.len (local.get $src)))
             (local.set $dest-len (array.len (local.get $dest)))
             (if (i32.or
                  (i32.or (i32.lt_u (local.get $src-start) (i32.const 0))
                          (i32.gt_u (local.get $src-end) (local.get $src-len)))
                  (i32.gt_u (i32.add (local.get $dest-start) (i32.sub (local.get $src-end) (local.get $src-start)))
                            (local.get $dest-len)))
                 (then (return (i32.const 0))))
             (local.set $len (i32.sub (local.get $src-end) (local.get $src-start)))
             (array.copy $I32Array $I32Array
                         (local.get $dest) (local.get $dest-start)
                         (local.get $src)  (local.get $src-start)
                         (local.get $len))
             (i32.const 1))))

   (core-runtime-helper
    '$i32array-copy
    "$i32array-copy"
    (lambda ()
      `(func $i32array-copy (param $arr (ref $I32Array)) (param $start i32) (param $end i32) (result (ref $I32Array))
             (local $res (ref $I32Array))
             (local.set $res (call $i32array-make (i32.sub (local.get $end) (local.get $start)) (i32.const 0)))
             (call $i32array-copy! (local.get $res) (i32.const 0) (local.get $arr) (local.get $start) (local.get $end))
             (local.get $res))))

   (core-runtime-helper
    '$i32array-append
    "$i32array-append"
    (lambda ()
      `(func $i32array-append (param $a0 (ref $I32Array)) (param $a1 (ref $I32Array)) (result (ref $I32Array))
             (local $len0 i32)
             (local $len1 i32)
             (local $total i32)
             (local $arr (ref $I32Array))
             (local.set $len0 (array.len (local.get $a0)))
             (local.set $len1 (array.len (local.get $a1)))
             (local.set $total (i32.add (local.get $len0) (local.get $len1)))
             (local.set $arr (call $i32array-make (local.get $total) (i32.const 0)))
             (call $i32array-copy! (local.get $arr) (i32.const 0) (local.get $a0) (i32.const 0) (local.get $len0))
             (call $i32array-copy! (local.get $arr) (local.get $len0) (local.get $a1) (i32.const 0) (local.get $len1))
             (local.get $arr))))

   (core-runtime-helper
    '$i32array-take
    "$i32array-take"
    (lambda ()
      `(func $i32array-take (param $arr (ref $I32Array)) (param $pos i32) (result (ref $I32Array))
             (call $i32array-copy (local.get $arr) (i32.const 0) (local.get $pos)))))

   (core-runtime-helper
    '$i32array-take-right
    "$i32array-take-right"
    (lambda ()
      `(func $i32array-take-right (param $arr (ref $I32Array)) (param $pos i32) (result (ref $I32Array))
             (local $len i32)
             (local.set $len (array.len (local.get $arr)))
             (call $i32array-copy (local.get $arr) (i32.sub (local.get $len) (local.get $pos)) (local.get $len)))))

   (core-runtime-helper
    '$i32array-drop
    "$i32array-drop"
    (lambda ()
      `(func $i32array-drop (param $arr (ref $I32Array)) (param $pos i32) (result (ref $I32Array))
             (local $len i32)
             (local.set $len (array.len (local.get $arr)))
             (call $i32array-copy (local.get $arr) (local.get $pos) (local.get $len)))))

   (core-runtime-helper
    '$i32array-drop-right
    "$i32array-drop-right"
    (lambda ()
      `(func $i32array-drop-right (param $arr (ref $I32Array)) (param $pos i32) (result (ref $I32Array))
             (local $len i32)
             (local.set $len (array.len (local.get $arr)))
             (call $i32array-copy (local.get $arr) (i32.const 0) (i32.sub (local.get $len) (local.get $pos))))))

   (core-runtime-helper
    '$i32array-set/copy
    "$i32array-set/copy"
    (lambda ()
      `(func $i32array-set/copy (param $arr (ref $I32Array)) (param $pos i32) (param $val i32) (result (ref $I32Array))
             (local $len i32)
             (local $res (ref $I32Array))
             (local.set $len (array.len (local.get $arr)))
             (local.set $res (call $i32array-make (local.get $len) (i32.const 0)))
             (call $i32array-copy! (local.get $res) (i32.const 0) (local.get $arr) (i32.const 0) (local.get $len))
             (call $i32array-set! (local.get $res) (local.get $pos) (local.get $val))
             (local.get $res))))

   (core-runtime-helper
    '$i32array-extend
    "$i32array-extend"
    (lambda ()
      `(func $i32array-extend (param $arr (ref $I32Array)) (param $new-size i32) (param $val i32) (result (ref $I32Array))
             (local $old-size i32)
             (local $res (ref $I32Array))
             (local.set $old-size (array.len (local.get $arr)))
             (local.set $res (call $i32array-make (local.get $new-size) (local.get $val)))
             (call $i32array-copy! (local.get $res) (i32.const 0) (local.get $arr) (i32.const 0) (local.get $old-size))
             (local.get $res))))))

;; i32-array-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for i32 array conversion helpers.
(define i32-array-runtime-only-helper-names
  '($list->i32array))

;; i32-array-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate i32 array helpers that depend on full runtime support.
(define i32-array-runtime-only-helpers
  (function-forms->runtime-helpers
   'i32-array-runtime-only-helpers
   '(
     (func $list->i32array (param $xs (ref eq)) (result (ref $I32Array))
           (local $len i32)
           (local $arr  (ref $I32Array))
           (local $idx  i32)
           (local $x    (ref eq))
           (local $v    i32)
           (local $node (ref eq))
           ;; Step 1: compute length of list
           (local.set $len (call $length/i32 (local.get $xs)))
           ;; Step 2: allocate array of given length
           (local.set $arr (call $i32array-make (local.get $len) (i32.const 0)))
           ;; Step 3: initialize traversal variables
           (local.set $node (local.get $xs))
           (local.set $idx  (i32.const 0))
           ;; Step 4: fill array
           (block $done
                  (loop $fill
                        ;; Stop at null
                        (br_if $done (ref.eq (local.get $node) (global.get $null)))
                        ;; Check that it's a pair
                        (if (ref.test (ref $Pair) (local.get $node))
                            (then
                             ;; Get the car
                             (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                             ;; Check that car is a fixnum (i31 with LSB 0)
                             (if (ref.test (ref i31) (local.get $x))
                                 (then
                                  (local.set $v (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                  (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
                                      (then
                                       ;; Decode fixnum: shift right 1 and store
                                       (call $i32array-set! (local.get $arr)
                                             (local.get $idx)
                                             (i32.shr_u (local.get $v) (i32.const 1)))
                                       ;; Advance
                                       (local.set $idx  (i32.add (local.get $idx) (i32.const 1)))
                                       (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))
                                       (br $fill))
                                      (else (call $raise-check-fixnum (local.get $x))
                                            (unreachable))))
                                 (else (call $raise-check-fixnum (local.get $x))
                                       (unreachable))))
                            (else (call $raise-pair-expected (local.get $node))
                                  (unreachable)))))
           ;; Return the filled array
           (local.get $arr)))))

;; i32-array-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render i32 array runtime-only helpers in runtime assembly order.
(define (i32-array-runtime-helper-forms helper-index)
  (for/list ([name (in-list i32-array-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; i32-array-core-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for I32Array core helpers.
(define i32-array-core-runtime-helper-names
  '($i32array-make
    $i32array-length
    $i32array-ref
    $i32array-set!
    $i32array-equal?
    $i32array-fill!
    $i32array-copy!
    $i32array-copy!/error
    $i32array-copy
    $i32array-append
    $i32array-take
    $i32array-take-right
    $i32array-drop
    $i32array-drop-right
    $i32array-set/copy
    $i32array-extend))

;; i32-array-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render I32Array core helpers in runtime assembly order.
(define (i32-array-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list i32-array-core-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define i32-array-helper-index
    (make-core-runtime-helper-index i32-array-runtime-only-helpers))

  (define i32-array-core-helper-index
    (make-core-runtime-helper-index i32-array-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name i32-array-core-runtime-helpers)
   i32-array-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (i32-array-core-runtime-helper-forms i32-array-core-helper-index))
   i32-array-core-runtime-helper-names)

  (check-equal?
   (map form-name (i32-array-runtime-helper-forms i32-array-helper-index))
   i32-array-runtime-only-helper-names))
