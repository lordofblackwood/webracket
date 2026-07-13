#lang racket

(provide make-array
         array-copy!
         array-extend
         array-core-runtime-helper-forms
         array-runtime-helper-forms
         array-core-runtime-helpers
         array-runtime-only-helper-names
         array-runtime-only-helpers)

(require "../core-helper.rkt"
         "immediates.rkt")

;; make-array : datum? datum? -> datum?
;;   Return WAT that allocates a generic $Array filled with value.
(define (make-array size value)
  `(array.new $Array ,value ,size))

;; array-copy! : datum? datum? datum? datum? datum? -> datum?
;;   Return WAT that copies len elements from src into dest.
(define (array-copy! dest dest-start src src-start len)
  `(array.copy $Array $Array
               ,dest ,dest-start
               ,src  ,src-start
               ,len))

;; array-extend : symbol? datum? datum? datum? datum? -> (listof datum?)
;;   Return WAT that stores a grown copy of arr in target-local.
(define (array-extend target-local arr new-size fill old-size)
  `((local.set ,target-local ,(make-array new-size fill))
    ,(array-copy! `(local.get ,target-local) `(i32.const 0)
                  arr `(i32.const 0)
                  old-size)))

;; list->array-runtime-helper : core-runtime-helper?
;;   Convert a proper list to a generic array while preserving runtime order.
(define list->array-runtime-helper
  (first
   (function-forms->runtime-helpers
    'array-runtime-only-helpers
    '(
     (func $list->array
           (param $xs   (ref eq))
           (result      (ref $Array))

           (local $len  i32)
           (local $arr  (ref $Array))
           (local $idx  i32)
           (local $x    (ref eq))
           (local $node (ref eq))

           ;; Step 1: compute length of list
           (local.set $len (call $length/i32 (local.get $xs)))
           ;; Step 2: allocate array of given length
           (local.set $arr (call $make-array (local.get $len) (global.get $null)))
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
                             (local.set $x (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $node))))
                             (call $array-set! (local.get $arr) (local.get $idx) (local.get $x))
                             (local.set $idx (i32.add (local.get $idx) (i32.const 1)))
                             (local.set $node (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $node))))
                             (br $fill))
                            (else
                             (call $raise-pair-expected (local.get $node))
                             (unreachable)))))
           ;; Return the filled array
           (local.get $arr))))))

;; array-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate generic array helpers that can be emitted in core runtime.
(define array-core-runtime-helpers
  (list
   ;;;
   ;;; Arrays
   ;;;

   ;; Arrays are "vectors" of (ref eq) values.
   ;; They are used internally to implement various Racket data structures.

   ;; Define a mutable array type of (ref eq)
   ; (type $Array (array (mut (ref eq))))

   ;;  make-array : i32 (ref eq) -> $Array
   ;; (make-array size v) -> $Array
   (core-runtime-helper
    '$make-array
    "$make-array"
    (lambda ()
      `(func $make-array (param $size i32) (param $v (ref eq)) (result (ref $Array))
             (local $arr (ref $Array))
             (array.new $Array (local.get $v) (local.get $size)))))

   ;;  array-length : $Array -> i32
   ;; (array-length arr) -> i32
   ;;   Note: Could just use `array.len` directly.
   (core-runtime-helper
    '$array-length
    "$array-length"
    (lambda ()
      `(func $array-length
             (param $arr (ref $Array))
             (result i32)
             (array.len (local.get $arr)))))

   ;;  array-ref : $Array i32 -> (ref eq)
   ;; (array-ref arr pos) -> (ref eq)
   ;;   No bounds check.
   (core-runtime-helper
    '$array-ref
    "$array-ref"
    (lambda ()
      `(func $array-ref
             (param $arr (ref $Array)) (param $pos i32)
             (result (ref eq))
             (array.get $Array (local.get $arr) (local.get $pos)))))

   ;;  array-set! : $Array i32 (ref eq) ->
   ;; (array-set! arr pos v) -> void
   (core-runtime-helper
    '$array-set!
    "$array-set!"
    (lambda ()
      `(func $array-set!
             (param $arr (ref $Array)) (param $pos i32) (param $v (ref eq))
             (array.set $Array (local.get $arr) (local.get $pos) (local.get $v)))))

   ;; array-fill! : $Array (ref eq) ->
   ;; (array-fill! arr v) -> void
   (core-runtime-helper
    '$array-fill!
    "$array-fill!"
    (lambda ()
      `(func $array-fill!
             (param $arr (ref $Array)) (param $v (ref eq))
             (local $i i32)
             (local.set $i (i32.const 0))
             (block $exit
                    (loop $fill
                          (br_if $exit (i32.ge_u (local.get $i) (array.len (local.get $arr))))
                          (array.set $Array (local.get $arr) (local.get $i) (local.get $v))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $fill))))))

   ;;  array-copy! : $Array i32        $Array i32       i32      ->
   ;; (array-copy!   dest   dest-start src    src-start src-end) ->
   ;;   Traps on error
   (core-runtime-helper
    '$array-copy!
    "$array-copy!"
    (lambda ()
      `(func $array-copy!
             (param $dest (ref $Array))
             (param $dest-start i32)
             (param $src (ref $Array))
             (param $src-start i32)
             (param $src-end i32)
             (local $src-len i32)
             (local $dest-len i32)
             (local $len i32)
             ;; Bounds checks
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
             (array.copy $Array $Array
                         (local.get $dest) (local.get $dest-start)
                         (local.get $src)  (local.get $src-start)
                         (local.get $len)))))

   ;;  array-copy!/error : $Array i32        $Array i32       i32      -> i32
   ;; (array-copy!/error   dest   dest-start src    src-start src-end) -> i32
   ;;   Returns 1 on success, 0 on error.
   (core-runtime-helper
    '$array-copy!/error
    "$array-copy!/error"
    (lambda ()
      `(func $array-copy!/error
             (param $dest (ref $Array))
             (param $dest-start i32)
             (param $src (ref $Array))
             (param $src-start i32)
             (param $src-end i32)
             (result i32)
             (local $src-len i32)
             (local $dest-len i32)
             (local $len i32)
             ;; Bounds checks
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
             (array.copy $Array $Array
                         (local.get $dest) (local.get $dest-start)
                         (local.get $src)  (local.get $src-start)
                         (local.get $len))
             (i32.const 1))))

   ; array-append : $Array $Array -> $Array
   ;  Append the arrays.
   (core-runtime-helper
    '$array-append
    "$array-append"
    (lambda ()
      `(func $array-append (param $a0 (ref $Array)) (param $a1 (ref $Array)) (result (ref $Array))
             (local $len0  i32)
             (local $len1  i32)
             (local $total i32)
             (local $arr   (ref $Array))
             (local.set $len0  (array.len (local.get $a0)))
             (local.set $len1  (array.len (local.get $a1)))
             (local.set $total (i32.add (local.get $len0) (local.get $len1)))
             (local.set $arr   (call $make-array (local.get $total) ,false-ref))
             (call $array-copy! (local.get $arr) (i32.const 0)     (local.get $a0) (i32.const 0) (local.get $len0))
             (call $array-copy! (local.get $arr) (local.get $len0) (local.get $a1) (i32.const 0) (local.get $len1))
             (local.get $arr))))

   ; array-append-all : (array-of $Array) -> $Array
   ;  Given an array of arrays. Make a new array.
   (core-runtime-helper
    '$array-append-all
    "$array-append-all"
    (lambda ()
      `(func $array-append-all (param $arrs (ref $Array)) (result (ref $Array))
             (local $n     i32)
             (local $i     i32)
             (local $total i32)
             (local $len   i32)
             (local $dst   i32)
             (local $tmp (ref $Array))
             (local $result (ref $Array))

             (local.set $n (array.len (local.get $arrs)))
             (local.set $i (i32.const 0))
             (local.set $total (i32.const 0))
             (block $exit
                    (loop $count
                          (br_if $exit (i32.ge_u (local.get $i) (local.get $n)))
                          (local.set $tmp (ref.cast (ref $Array) (array.get $Array (local.get $arrs) (local.get $i))))
                          (local.set $len (array.len (local.get $tmp)))
                          (local.set $total (i32.add (local.get $total) (local.get $len)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $count)))
             (local.set $result (call $make-array (local.get $total) ,false-ref))
             (local.set $i (i32.const 0))
             (local.set $dst (i32.const 0))
             (block $done
                    (loop $copy
                          (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                          (local.set $tmp (ref.cast (ref $Array) (array.get $Array (local.get $arrs) (local.get $i))))
                          (local.set $len (array.len (local.get $tmp)))
                          (call $array-copy! (local.get $result) (local.get $dst) (local.get $tmp) (i32.const 0) (local.get $len))
                          (local.set $dst (i32.add (local.get $dst) (local.get $len)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $copy)))
             (local.get $result))))

   ; array-take : $Array i32 -> $Array
   (core-runtime-helper
    '$array-take
    "$array-take"
    (lambda ()
      `(func $array-take (param $arr (ref $Array)) (param $pos i32) (result (ref $Array))
             (call $array-copy (local.get $arr) (i32.const 0) (local.get $pos)))))

   ; array-take-right : $Array i32 -> $Array
   (core-runtime-helper
    '$array-take-right
    "$array-take-right"
    (lambda ()
      `(func $array-take-right (param $arr (ref $Array)) (param $pos i32) (result (ref $Array))
             (local $len i32)
             (local.set $len (array.len (local.get $arr)))
             (call $array-copy (local.get $arr) (i32.sub (local.get $len) (local.get $pos)) (local.get $len)))))

   ; array-drop : $Array i32 -> $Array
   (core-runtime-helper
    '$array-drop
    "$array-drop"
    (lambda ()
      `(func $array-drop (param $arr (ref $Array)) (param $pos i32) (result (ref $Array))
             (local $len i32)
             (local.set $len (array.len (local.get $arr)))
             (call $array-copy (local.get $arr) (local.get $pos) (local.get $len)))))

   ; array-drop-right : $Array i32 -> $Array
   (core-runtime-helper
    '$array-drop-right
    "$array-drop-right"
    (lambda ()
      `(func $array-drop-right (param $arr (ref $Array)) (param $pos i32) (result (ref $Array))
             (local $len i32)
             (local.set $len (array.len (local.get $arr)))
             (call $array-copy (local.get $arr) (i32.const 0) (i32.sub (local.get $len) (local.get $pos))))))

   ; array-split-at : $Array i32 -> (array $Array $Array)
   (core-runtime-helper
    '$array-split-at
    "$array-split-at"
    (lambda ()
      `(func $array-split-at (param $arr (ref $Array)) (param $pos i32) (result (ref $Array))
             (local $a   (ref $Array))
             (local $b   (ref $Array))
             (local $res (ref $Array))
             (local.set $a     (call $array-take (local.get $arr) (local.get $pos)))
             (local.set $b     (call $array-drop (local.get $arr) (local.get $pos)))
             (local.set $res   (call $make-array (i32.const 2) ,false-ref))
             (call $array-set! (local.get $res) (i32.const 0) (local.get $a))
             (call $array-set! (local.get $res) (i32.const 1) (local.get $b))
             (local.get $res))))

   ; $array-copy : $Array i32 i32 -> $Array
   ; (array-copy arr start end)
   (core-runtime-helper
    '$array-copy
    "$array-copy"
    (lambda ()
      `(func $array-copy (param $arr (ref $Array)) (param $start i32) (param $end i32) (result (ref $Array))
             (local $res (ref $Array))
             (local.set $res (call $make-array (i32.sub (local.get $end) (local.get $start))
                                               ,false-ref))
             (call $array-copy! (local.get $res) (i32.const 0) (local.get $arr) (local.get $start) (local.get $end))
             (local.get $res))))

   (core-runtime-helper
    '$array-set/copy
    "$array-set/copy"
    (lambda ()
      `(func $array-set/copy (param $arr (ref $Array)) (param $pos i32) (param $val (ref eq)) (result (ref $Array))
             (local $len i32)
             (local $res (ref $Array))
             (local.set $len (array.len (local.get $arr)))
             (local.set $res (call $make-array (local.get $len) ,false-ref))
             (call $array-copy! (local.get $res) (i32.const 0) (local.get $arr) (i32.const 0) (local.get $len))
             (call $array-set! (local.get $res) (local.get $pos) (local.get $val))
             (local.get $res))))

   (core-runtime-helper
    '$array-extend
    "$array-extend"
    (lambda ()
      `(func $array-extend (param $arr (ref $Array)) (param $new-size i32) (param $val (ref eq)) (result (ref $Array))
             (local $old-size i32)
             (local $res (ref $Array))
             (local.set $old-size (array.len (local.get $arr)))
             (local.set $res (call $make-array (local.get $new-size) (local.get $val)))
             (call $array-copy! (local.get $res) (i32.const 0) (local.get $arr) (i32.const 0) (local.get $old-size))
             (local.get $res))))

   list->array-runtime-helper))

;; array-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generic array conversion helpers.
(define array-runtime-only-helper-names
  '($list->array))

;; array-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic array helpers that depend on full runtime support.
(define array-runtime-only-helpers
  (list list->array-runtime-helper))

;; array-core-runtime-helper-specs : (listof (list/c symbol? (or/c string? #f)))
;;   Preserve the core runtime emission order and public exports for generic array helpers.
(define array-core-runtime-helper-specs
  '(($make-array #f)
    ($array-length "array-length")
    ($array-ref "array-ref")
    ($array-set! "array-set!")
    ($array-fill! "array-fill!")
    ($array-copy! "array-copy!")
    ($array-copy!/error "array-copy!/error")
    ($array-append #f)
    ($array-append-all #f)
    ($array-take #f)
    ($array-take-right #f)
    ($array-drop #f)
    ($array-drop-right #f)
    ($array-split-at #f)
    ($array-copy #f)
    ($array-set/copy #f)
    ($array-extend #f)))

;; array-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render generic array core helpers in runtime assembly order.
(define (array-core-runtime-helper-forms helper-index)
  (for/list ([spec (in-list array-core-runtime-helper-specs)])
    (match-define (list name export-name) spec)
    (if export-name
        (core-runtime-helper-form helper-index name
                                  #:export? #t
                                  #:export-name export-name)
        (core-runtime-helper-form helper-index name))))

;; array-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render generic array runtime-only helpers in runtime assembly order.
(define (array-runtime-helper-forms helper-index)
  (for/list ([name (in-list array-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

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

  (define array-core-helper-index
    (make-core-runtime-helper-index array-core-runtime-helpers))

  (define array-helper-index
    (make-core-runtime-helper-index array-runtime-only-helpers))

  (check-equal?
   (map form-name (array-core-runtime-helper-forms array-core-helper-index))
   (map first array-core-runtime-helper-specs))

  (check-equal?
   (map form-export-names (array-core-runtime-helper-forms array-core-helper-index))
   (for/list ([spec (in-list array-core-runtime-helper-specs)])
     (match-define (list _ export-name) spec)
     (if export-name
         (list export-name)
         '())))

  (check-equal?
   (map form-name (array-runtime-helper-forms array-helper-index))
   array-runtime-only-helper-names))
