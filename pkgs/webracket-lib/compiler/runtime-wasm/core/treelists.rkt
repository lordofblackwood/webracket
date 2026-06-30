#lang racket

(provide treelist-runtime-only-helpers)

(require "../core-helper.rkt")

;; treelist-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate treelist helpers that still depend on monolithic runtime globals.
(define treelist-runtime-only-helpers
  (list
   ;; treelist-node-children : treelist-node? -> array?
   ;;   Return a treelist node children array.
   (core-runtime-helper
    '$treelist-node-children
    "$treelist-node-children"
    (lambda ()
       `(func $treelist-node-children
             (param $node (ref $TreelistNode))
             (result (ref $Array))
             (struct.get $TreelistNode $children (local.get $node)))))

   ;; treelist-node-sizes : treelist-node? -> (or/c i32array? null)
   ;;   Return a treelist node cumulative-size array, if present.
   (core-runtime-helper
    '$treelist-node-sizes
    "$treelist-node-sizes"
    (lambda ()
       `(func $treelist-node-sizes
             (param $node (ref $TreelistNode))
             (result (ref null $I32Array))
             (struct.get $TreelistNode $sizes (local.get $node)))))

   ;; treelist-node-leftwise-dense?/i32 : treelist-node? -> i32
   ;;   Check whether a treelist node omits cumulative sizes.
   (core-runtime-helper
    '$treelist-node-leftwise-dense?/i32
    "$treelist-node-leftwise-dense?/i32"
    (lambda ()
       `(func $treelist-node-leftwise-dense?/i32
             (param $node (ref $TreelistNode))
             (result i32)
             (ref.is_null
              (call $treelist-node-sizes (local.get $node))))))

   ;; treelist-node-child-count : treelist-node? -> i32
   ;;   Return the number of children in a treelist node.
   (core-runtime-helper
    '$treelist-node-child-count
    "$treelist-node-child-count"
    (lambda ()
       `(func $treelist-node-child-count
             (param $node (ref $TreelistNode))
             (result i32)
             (array.len
              (call $treelist-node-children (local.get $node))))))

   ;; treelist-node-find-child-index/relaxed : (ref $I32Array) i32 -> i32
   ;;   Find the child whose cumulative size first exceeds index.
   ;; treelist-node-find-child-index/relaxed : i32array? i32 -> i32
   ;;   Find the child whose cumulative size first exceeds index.
   (core-runtime-helper
    '$treelist-node-find-child-index/relaxed
    "$treelist-node-find-child-index/relaxed"
    (lambda ()
       `(func $treelist-node-find-child-index/relaxed
             (param $sizes (ref $I32Array))
             (param $index i32)
             (result i32)
             (local $len i32)
             (local $i i32)
             (local.set $len (array.len (local.get $sizes)))
             (local.set $i   (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                          (if (i32.lt_u (local.get $index)
                                        (array.get $I32Array
                                                   (local.get $sizes)
                                                   (local.get $i)))
                              (then (return (local.get $i))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (i32.sub (local.get $len) (i32.const 1)))))

   ;; treelist-node-child-start : (ref $TreelistNode) i32 i32 i32 -> i32
   ;;   Return the starting logical offset of child-index within node.
   ;; treelist-node-child-start : treelist-node? i32 i32 i32 -> i32
   ;;   Return the starting logical offset of a child.
   (core-runtime-helper
    '$treelist-node-child-start
    "$treelist-node-child-start"
    (lambda ()
       `(func $treelist-node-child-start
             (param $node       (ref $TreelistNode))
             (param $node-size  i32)
             (param $height     i32)
             (param $child-index i32)
             (result i32)
             (local $sizes (ref null $I32Array))
             (local $child-cap i32)
             (if (i32.eqz (local.get $child-index))
                 (then (return (i32.const 0))))
             (local.set $sizes (call $treelist-node-sizes (local.get $node)))
             (if (ref.is_null (local.get $sizes))
                 (then
                  (if (i32.eqz (local.get $height))
                      (then (return (local.get $child-index))))
                  (local.set $child-cap
                             (call $treelist-node-capacity
                                   (i32.sub (local.get $height) (i32.const 1))))
                  (return (i32.mul (local.get $child-index) (local.get $child-cap)))))
             (array.get $I32Array
                        (ref.cast (ref $I32Array) (local.get $sizes))
                        (i32.sub (local.get $child-index) (i32.const 1))))))

   ;; treelist-node-child-size : (ref $TreelistNode) i32 i32 i32 -> i32
   ;;   Return the subtree size contributed by child-index.
   ;; treelist-node-child-size : treelist-node? i32 i32 i32 -> i32
   ;;   Return the subtree size contributed by a child.
   (core-runtime-helper
    '$treelist-node-child-size
    "$treelist-node-child-size"
    (lambda ()
       `(func $treelist-node-child-size
             (param $node        (ref $TreelistNode))
             (param $node-size   i32)
             (param $height      i32)
             (param $child-index i32)
             (result i32)
             (local $sizes (ref null $I32Array))
             (local $child-count i32)
             (local $child-cap i32)
             (if (i32.eqz (local.get $height))
                 (then (return (i32.const 1))))
             (local.set $sizes (call $treelist-node-sizes (local.get $node)))
             (if (ref.is_null (local.get $sizes))
                 (then
                  (local.set $child-count
                             (call $treelist-node-child-count (local.get $node)))
                  (local.set $child-cap
                             (call $treelist-node-capacity
                                   (i32.sub (local.get $height) (i32.const 1))))
                  (if (i32.lt_u (local.get $child-index)
                                (i32.sub (local.get $child-count) (i32.const 1)))
                      (then (return (local.get $child-cap))))
                  (return
                   (i32.sub (local.get $node-size)
                            (i32.mul
                             (i32.sub (local.get $child-count) (i32.const 1))
                             (local.get $child-cap))))))
             (if (i32.eqz (local.get $child-index))
                 (then
                  (return
                   (array.get $I32Array
                              (ref.cast (ref $I32Array) (local.get $sizes))
                              (i32.const 0)))))
             (i32.sub
              (array.get $I32Array
                         (ref.cast (ref $I32Array) (local.get $sizes))
                         (local.get $child-index))
              (array.get $I32Array
                         (ref.cast (ref $I32Array) (local.get $sizes))
                         (i32.sub (local.get $child-index) (i32.const 1)))))))

   ;; treelist-radix : i32 i32 -> i32
   ;;   Extract the branch index for a logical element index at height.
   (core-runtime-helper
    '$treelist-radix
    "$treelist-radix"
    (lambda ()
       `(func $treelist-radix
             (param $index i32)
             (param $height i32)
             (result i32)
             (i32.and
              (i32.shr_u
               (local.get $index)
               (i32.mul (global.get $treelist:BITS) (local.get $height)))
              (global.get $treelist:MASK)))))

   ;; treelist-node-capacity : i32 -> i32
   ;;   Compute the dense capacity of a node at height.
   ;; treelist-node-capacity : i32 -> i32
   ;;   Compute the dense capacity of a node at height.
   (core-runtime-helper
    '$treelist-node-capacity
    "$treelist-node-capacity"
    (lambda ()
       `(func $treelist-node-capacity
             (param $height i32)
             (result i32)
             (i32.shl (i32.const 1)
                      (i32.mul (global.get $treelist:BITS)
                               (i32.add (local.get $height) (i32.const 1)))))))

   ;; treelist-height-for-size : i32 -> i32
   ;;   Compute the tree height needed for a size.
   (core-runtime-helper
    '$treelist-height-for-size
    "$treelist-height-for-size"
    (lambda ()
       `(func $treelist-height-for-size
             (param $size i32)
             (result i32)
             (local $height i32)
             (local $cap i32)
             (local.set $height (i32.const 0))
             (local.set $cap (global.get $treelist:MAX_WIDTH))
             (block $done
                    (loop $loop
                          (br_if $done (i32.le_u (local.get $size) (local.get $cap)))
                          (local.set $height (i32.add (local.get $height) (i32.const 1)))
                          (local.set $cap (i32.mul (local.get $cap) (global.get $treelist:MAX_WIDTH)))
                          (br $loop)))
             (local.get $height))))))
