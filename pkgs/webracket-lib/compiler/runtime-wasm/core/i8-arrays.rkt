#lang racket

(provide i8-array-core-runtime-helper-forms
         i8-array-core-runtime-helper-names
         i8-array-core-runtime-helpers
         i8-array-error-runtime-only-helper-names
         i8-array-conversion-runtime-only-helper-names
         i8-array-error-runtime-helper-forms
         i8-array-conversion-runtime-helper-forms
         i8-array-runtime-only-helpers)

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

;; i8-array-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for i8 array error helpers.
(define i8-array-error-runtime-only-helper-names
  '($raise-bad-byte))

;; i8-array-conversion-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for i8 array conversion helpers.
(define i8-array-conversion-runtime-only-helper-names
  '($list->i8array))

;; i8-array-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate i8 array helpers that still depend on monolithic runtime support.
(define i8-array-runtime-only-helpers
  (function-forms->runtime-helpers
   'i8-array-runtime-only-helpers
   '(
     (func $raise-bad-byte (param $x (ref eq))
           (call $raise-argument-error1
                 (global.get $symbol:byte?)
                 (global.get $string:byte?)
                 (local.get $x)))

     (func $list->i8array (param $xs (ref eq)) (result (ref $I8Array))
           (local $len  i32)
           (local $arr  (ref $I8Array))
           (local $idx  i32)
           (local $x    (ref eq))
           (local $v    i32)
           (local $node (ref eq))
           ;; Step 1: compute list length
           (local.set $len (call $length/i32 (local.get $xs)))
           ;; Step 2: allocate array of that length
           (local.set $arr (array.new $I8Array (i32.const 0) (local.get $len)))
           ;; Step 3: initialize index and node
           (local.set $idx  (i32.const 0))
           (local.set $node (local.get $xs))
           ;; Step 4: fill loop
           (block $done
                  (loop $fill
                        ;; If we hit null, stop
                        (br_if $done (ref.eq (local.get $node) (global.get $null)))
                        ;; Must be a pair
                        (if (ref.test (ref $Pair) (local.get $node))
                            (then
                             ;; Extract the car
                             (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                             ;; Check that car is a fixnum
                             (if (ref.test (ref i31) (local.get $x))
                                 (then
                                  (local.set $v (i31.get_u (ref.cast (ref i31) (local.get $x))))
                                  ;; Check fixnum has LSB = 0
                                  (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
                                      (then
                                       ;; Shift right to get raw i32
                                       (local.set $v (i32.shr_u (local.get $v) (i32.const 1)))
                                       ;; Check range 0–255
                                       (if (i32.le_u (local.get $v) (i32.const 255))
                                           (then
                                            ;; Store into array
                                            (array.set $I8Array (local.get $arr)
                                                       (local.get $idx)
                                                       (local.get $v))
                                            ;; Advance
                                            (local.set $idx  (i32.add (local.get $idx) (i32.const 1)))
                                            (local.set $node (struct.get $Pair $d
                                                                 (ref.cast (ref $Pair) (local.get $node))))
                                            (br $fill))
                                           (else (call $raise-bad-byte (local.get $x))
                                                 (unreachable))))
                                      (else (call $raise-check-fixnum (local.get $x))
                                            (unreachable))))
                                 (else (call $raise-check-fixnum (local.get $x))
                                       (unreachable))))
                            (else (call $raise-pair-expected (local.get $node))
                                  (unreachable)))))
           ;; Return array
           (local.get $arr)))))

;; i8-array-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given i8 array helper names from the runtime helper index.
(define (i8-array-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; i8-array-core-runtime-helper-specs : (listof (list/c symbol? (or/c string? #f)))
;;   Preserve the core runtime emission order and public exports for I8Array helpers.
(define i8-array-core-runtime-helper-specs
  '(($i8make-array #f)
    ($i8array-length "i8array-length")
    ($i8array-ref "i8array-ref")
    ($i8array-set! "i8array-set!")
    ($i8array-fill! "i8array-fill!")
    ($i8array-copy! "i8array-copy!")
    ($i8array-copy!/error "i8array-copy!/error")
    ($i8array-copy #f)
    ($i8array-set/copy #f)
    ($i8array-extend #f)
    ($i8array-append #f)))

;; i8-array-core-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for I8Array core helpers.
(define i8-array-core-runtime-helper-names
  (map first i8-array-core-runtime-helper-specs))

;; i8-array-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render I8Array core helpers in runtime assembly order.
(define (i8-array-core-runtime-helper-forms helper-index)
  (for/list ([spec (in-list i8-array-core-runtime-helper-specs)])
    (match-define (list name export-name) spec)
    (if export-name
        (core-runtime-helper-form helper-index name
                                  #:export? #t
                                  #:export-name export-name)
        (core-runtime-helper-form helper-index name))))

;; i8-array-error-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render i8 array error helpers in runtime assembly order.
(define (i8-array-error-runtime-helper-forms helper-index)
  (i8-array-helper-forms helper-index i8-array-error-runtime-only-helper-names))

;; i8-array-conversion-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render i8 array conversion helpers in runtime assembly order.
(define (i8-array-conversion-runtime-helper-forms helper-index)
  (i8-array-helper-forms helper-index i8-array-conversion-runtime-only-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  ;; form-export-names : datum? -> (listof string?)
  ;;   Return export names attached directly to a rendered helper form.
  (define (form-export-names form)
    (for/list ([part (in-list (cddr form))]
               #:when (and (pair? part)
                           (eq? 'export (car part))))
      (second part)))

  (define i8-array-helper-index
    (make-core-runtime-helper-index i8-array-runtime-only-helpers))

  (define i8-array-core-helper-index
    (make-core-runtime-helper-index i8-array-core-runtime-helpers))

  (check-equal?
   (map core-runtime-helper-name i8-array-core-runtime-helpers)
   i8-array-core-runtime-helper-names)

  (check-equal?
   (map form-name (i8-array-core-runtime-helper-forms i8-array-core-helper-index))
   i8-array-core-runtime-helper-names)

  (check-equal?
   (map form-export-names (i8-array-core-runtime-helper-forms i8-array-core-helper-index))
   (for/list ([spec (in-list i8-array-core-runtime-helper-specs)])
     (match-define (list _ export-name) spec)
     (if export-name
         (list export-name)
         '())))

  (check-equal?
   (map form-name (i8-array-error-runtime-helper-forms i8-array-helper-index))
   i8-array-error-runtime-only-helper-names)

  (check-equal?
   (map form-name (i8-array-conversion-runtime-helper-forms i8-array-helper-index))
   i8-array-conversion-runtime-only-helper-names))
