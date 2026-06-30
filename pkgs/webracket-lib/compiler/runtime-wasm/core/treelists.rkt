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
             (local.get $height))))

   ;; treelist-make-parent-root/checked : (ref $TreelistNode) i32 (ref $TreelistNode) i32 i32 -> (ref $TreelistNode)
   ;;   Make a parent node over two same-height subtrees.
   (core-runtime-helper
    '$treelist-make-parent-root/checked
    "$treelist-make-parent-root/checked"
    (lambda ()
      `(func $treelist-make-parent-root/checked
             (param $left-root  (ref $TreelistNode))
             (param $left-size  i32)
             (param $right-root (ref $TreelistNode))
             (param $right-size i32)
             (param $height     i32)
             (result (ref $TreelistNode))
             (local $children-new (ref $Array))
             (local $sizes       (ref $I32Array))
             (local.set $children-new
                        (array.new_fixed $Array 2 (local.get $left-root) (local.get $right-root)))
             (if (i32.eq (local.get $left-size)
                         (call $treelist-node-capacity (local.get $height)))
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (local.get $children-new)
                               (ref.null $I32Array)))))
             (local.set $sizes (array.new $I32Array (i32.const 0) (i32.const 2)))
             (array.set $I32Array (local.get $sizes) (i32.const 0) (local.get $left-size))
             (array.set $I32Array
                        (local.get $sizes)
                        (i32.const 1)
                        (i32.add (local.get $left-size) (local.get $right-size)))
             (struct.new $TreelistNode
                         (i32.const 0)
                         (local.get $children-new)
                         (local.get $sizes)))))


   ;; treelist-rebalance-node-count : i32 -> i32
   ;;   Compute the number of packed nodes needed for total-child-count.
   (core-runtime-helper
    '$treelist-rebalance-node-count
    "$treelist-rebalance-node-count"
    (lambda ()
      `(func $treelist-rebalance-node-count
             (param $total-child-count i32)
             (result i32)
             (i32.div_u
              (i32.add
               (local.get $total-child-count)
               (i32.sub (global.get $treelist:MAX_WIDTH) (i32.const 1)))
              (global.get $treelist:MAX_WIDTH)))))


   ;; treelist-rebalance-pack-sizes : i32 -> (ref $I32Array)
   ;;   Compute balanced packed child counts for total-child-count.
   (core-runtime-helper
    '$treelist-rebalance-pack-sizes
    "$treelist-rebalance-pack-sizes"
    (lambda ()
      `(func $treelist-rebalance-pack-sizes
             (param $total-child-count i32)
             (result (ref $I32Array))
             (local $node-count i32)
             (local $remainder  i32)
             (local $sizes      (ref $I32Array))
             (local $prefix-count i32)
             (local $tail-total   i32)
             (local $tail-left    i32)
             (local $tail-right   i32)
             (local $i          i32)
             (local.set $node-count
                        (call $treelist-rebalance-node-count
                              (local.get $total-child-count)))
             (if (i32.eqz (local.get $node-count))
                 (then
                  (return
                   (array.new $I32Array (i32.const 0) (i32.const 0)))))
             (local.set $remainder
                        (i32.rem_u (local.get $total-child-count)
                                   (global.get $treelist:MAX_WIDTH)))
             (local.set $sizes
                        (array.new $I32Array (i32.const 0) (local.get $node-count)))
             (if (i32.eqz (local.get $remainder))
                 (then
                  (local.set $i (i32.const 0))
                  (block $full-done
                         (loop $full-loop
                               (br_if $full-done
                                      (i32.ge_u (local.get $i) (local.get $node-count)))
                               (array.set $I32Array
                                          (local.get $sizes)
                                          (local.get $i)
                                          (global.get $treelist:MAX_WIDTH))
                               (local.set $i (i32.add (local.get $i) (i32.const 1)))
                               (br $full-loop)))
                  (return (local.get $sizes))))
             (if (i32.eq (local.get $node-count) (i32.const 1))
                 (then
                  (array.set $I32Array
                             (local.get $sizes)
                             (i32.const 0)
                             (local.get $total-child-count))
                  (return (local.get $sizes))))
             (local.set $prefix-count
                        (i32.sub (local.get $node-count) (i32.const 1)))
             (if (i32.le_u (local.get $remainder) (i32.const 1))
                 (then
                  (local.set $prefix-count
                             (i32.sub (local.get $node-count) (i32.const 2)))))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $prefix-count)))
                          (array.set $I32Array
                                     (local.get $sizes)
                                     (local.get $i)
                                     (global.get $treelist:MAX_WIDTH))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (if (i32.eq (local.get $prefix-count)
                         (i32.sub (local.get $node-count) (i32.const 1)))
                 (then
                  (array.set $I32Array
                             (local.get $sizes)
                             (local.get $prefix-count)
                             (local.get $remainder))
                  (return (local.get $sizes))))
             (local.set $tail-total
                        (i32.add (global.get $treelist:MAX_WIDTH)
                                 (local.get $remainder)))
             (local.set $tail-right
                        (i32.div_u (local.get $tail-total) (i32.const 2)))
             (local.set $tail-left
                        (i32.sub (local.get $tail-total) (local.get $tail-right)))
             (array.set $I32Array
                        (local.get $sizes)
                        (local.get $prefix-count)
                        (local.get $tail-left))
             (array.set $I32Array
                        (local.get $sizes)
                        (i32.add (local.get $prefix-count) (i32.const 1))
                        (local.get $tail-right))
             (local.get $sizes))))


   ;; treelist-pack-children-range/checked : (ref $Array) (ref $I32Array) i32 i32 i32 -> values
   ;;   Build one packed node from a child slice and return the node plus its exact size.
   (core-runtime-helper
    '$treelist-pack-children-range/checked
    "$treelist-pack-children-range/checked"
    (lambda ()
      `(func $treelist-pack-children-range/checked
             (param $children      (ref $Array))
             (param $child-sizes   (ref $I32Array))
             (param $start         i32)
             (param $count         i32)
             (param $height        i32)
             (result (ref $Values))
             (local $slice-children (ref $Array))
             (local $slice-sizes    (ref $I32Array))
             (local $node           (ref $TreelistNode))
             (local $size           i32)
             (local $i              i32)
             (local.set $slice-children
                        (call $array-copy
                              (local.get $children)
                              (local.get $start)
                              (i32.add (local.get $start) (local.get $count))))
             (local.set $slice-sizes
                        (call $i32array-copy
                              (local.get $child-sizes)
                              (local.get $start)
                              (i32.add (local.get $start) (local.get $count))))
             (local.set $size (i32.const 0))
             (local.set $i    (i32.const 0))
             (block $sum-done
                    (loop $sum-loop
                          (br_if $sum-done (i32.ge_u (local.get $i) (local.get $count)))
                          (local.set $size
                                     (i32.add
                                      (local.get $size)
                                      (array.get $I32Array
                                                 (local.get $slice-sizes)
                                                 (local.get $i))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $sum-loop)))
             (local.set $node
                        (call $treelist-node-build/checked
                              (local.get $slice-children)
                              (local.get $slice-sizes)
                              (local.get $height)))
             (array.new_fixed $Values 2
                              (local.get $node)
                              (ref.i31 (i32.shl (local.get $size) (i32.const 1)))))))


   ;; treelist-rebalance-same-height/checked : (ref $Array) (ref $I32Array) i32 -> values
   ;;   Pack an ordered same-height child sequence into balanced nodes and exact packed sizes.
   (core-runtime-helper
    '$treelist-rebalance-same-height/checked
    "$treelist-rebalance-same-height/checked"
    (lambda ()
      `(func $treelist-rebalance-same-height/checked
             (param $children    (ref $Array))
             (param $child-sizes (ref $I32Array))
             (param $height      i32)
             (result (ref $Values))
             (local $child-count    i32)
             (local $packed-counts  (ref $I32Array))
             (local $packed-nodes   (ref $Array))
             (local $packed-sizes   (ref $I32Array))
             (local $packed-count   i32)
             (local $offset         i32)
             (local $i              i32)
             (local $piece-count    i32)
             (local $packed         (ref $Values))
             (local $packed-node    (ref $TreelistNode))
             (local $packed-size    i32)
             (local.set $packed-counts (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $packed-nodes  (global.get $dummy-array))
             (local.set $packed-sizes  (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $packed       (array.new_fixed $Values 0))
             (local.set $packed-node  (global.get $dummy-treelist-node))
             (local.set $child-count (array.len (local.get $children)))
             (if (i32.ne (array.len (local.get $child-sizes)) (local.get $child-count))
                 (then
                  (return
                   (array.new_fixed $Values 2
                                    (global.get $dummy-array)
                                    (array.new $I32Array (i32.const 0) (i32.const 0))))))
             (local.set $packed-counts
                        (call $treelist-rebalance-pack-sizes
                              (local.get $child-count)))
             (local.set $packed-count (array.len (local.get $packed-counts)))
             (local.set $packed-nodes
                        (call $make-array (local.get $packed-count) (global.get $false)))
             (local.set $packed-sizes
                        (array.new $I32Array (i32.const 0) (local.get $packed-count)))
             (local.set $offset (i32.const 0))
             (local.set $i      (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $packed-count)))
                          (local.set $piece-count
                                     (array.get $I32Array
                                                (local.get $packed-counts)
                                                (local.get $i)))
                          (local.set $packed
                                     (call $treelist-pack-children-range/checked
                                           (local.get $children)
                                           (local.get $child-sizes)
                                           (local.get $offset)
                                           (local.get $piece-count)
                                           (local.get $height)))
                          (local.set $packed-node
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Values (local.get $packed) (i32.const 0))))
                          (local.set $packed-size
                                     (i32.shr_u
                                      (i31.get_u
                                       (ref.cast (ref i31)
                                                 (array.get $Values (local.get $packed) (i32.const 1))))
                                      (i32.const 1)))
                          (array.set $Array
                                     (local.get $packed-nodes)
                                     (local.get $i)
                                     (local.get $packed-node))
                          (array.set $I32Array
                                     (local.get $packed-sizes)
                                     (local.get $i)
                                     (local.get $packed-size))
                          (local.set $offset
                                     (i32.add (local.get $offset) (local.get $piece-count)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (array.new_fixed $Values 2
                              (local.get $packed-nodes)
                              (local.get $packed-sizes)))))


   ;; treelist-pack-same-height/checked : (ref $TreelistNode) i32 (ref $TreelistNode) i32 i32 -> values
   ;;   Pack two same-height sibling nodes into one or two fuller same-height nodes.
   (core-runtime-helper
    '$treelist-pack-same-height/checked
    "$treelist-pack-same-height/checked"
    (lambda ()
      `(func $treelist-pack-same-height/checked
             (param $left-node  (ref $TreelistNode))
             (param $left-size  i32)
             (param $right-node (ref $TreelistNode))
             (param $right-size i32)
             (param $height     i32)
             (result (ref $Values))
             (local $left-children   (ref $Array))
             (local $right-children  (ref $Array))
             (local $left-sizes      (ref $I32Array))
             (local $right-sizes     (ref $I32Array))
             (local $all-children    (ref $Array))
             (local $all-sizes       (ref $I32Array))
             (local $total-size      i32)
             (local $rebalanced      (ref $Values))
             (local $packed-nodes    (ref $Array))
             (local $packed-sizes    (ref $I32Array))
             (local $packed-count    i32)
             (local $first-node      (ref $TreelistNode))
             (local $second-node     (ref $TreelistNode))
             (local $first-size      i32)
             (local $second-size     i32)
             (local.set $left-children
                        (call $treelist-node-children (local.get $left-node)))
             (local.set $right-children
                        (call $treelist-node-children (local.get $right-node)))
             (local.set $left-sizes
                        (call $treelist-node-child-sizes/exact
                              (local.get $left-node)
                              (local.get $left-size)
                              (local.get $height)))
             (local.set $right-sizes
                        (call $treelist-node-child-sizes/exact
                              (local.get $right-node)
                              (local.get $right-size)
                              (local.get $height)))
             (local.set $all-children
                        (call $array-append
                              (local.get $left-children)
                              (local.get $right-children)))
             (local.set $all-sizes
                        (call $i32array-append
                              (local.get $left-sizes)
                              (local.get $right-sizes)))
             (local.set $total-size
                        (i32.add (local.get $left-size) (local.get $right-size)))
             (local.set $rebalanced
                        (call $treelist-rebalance-same-height/checked
                              (local.get $all-children)
                              (local.get $all-sizes)
                              (local.get $height)))
             (local.set $packed-nodes
                        (ref.cast (ref $Array)
                                  (array.get $Values (local.get $rebalanced) (i32.const 0))))
             (local.set $packed-sizes
                        (ref.cast (ref $I32Array)
                                  (array.get $Values (local.get $rebalanced) (i32.const 1))))
             (local.set $packed-count (array.len (local.get $packed-nodes)))
             (if (i32.eqz (local.get $packed-count))
                 (then
                  (return
                   (array.new_fixed $Values 4
                                    (global.get $dummy-treelist-node)
                                    (global.get $dummy-treelist-node)
                                    (ref.i31 (i32.const 0))
                                    (ref.i31 (i32.const 0))))))
             (local.set $first-node
                        (ref.cast (ref $TreelistNode)
                                  (array.get $Array (local.get $packed-nodes) (i32.const 0))))
             (local.set $first-size
                        (array.get $I32Array (local.get $packed-sizes) (i32.const 0)))
             (if (i32.eq (local.get $packed-count) (i32.const 1))
                 (then
                  (return
                   (array.new_fixed $Values 4
                                    (local.get $first-node)
                                    (global.get $dummy-treelist-node)
                                    (ref.i31 (i32.shl (local.get $first-size) (i32.const 1)))
                                    (ref.i31 (i32.const 0))))))
             (local.set $second-node
                        (ref.cast (ref $TreelistNode)
                                  (array.get $Array (local.get $packed-nodes) (i32.const 1))))
             (local.set $second-size
                        (array.get $I32Array (local.get $packed-sizes) (i32.const 1)))
             (array.new_fixed $Values 4
                              (local.get $first-node)
                              (local.get $second-node)
                              (ref.i31 (i32.shl (local.get $first-size) (i32.const 1)))
                              (ref.i31 (i32.shl (local.get $second-size) (i32.const 1)))))))


   ;; treelist-short-node : (ref $I32Array) i32 -> i32
   ;;   Find the first plan slot whose child count is below MAX_WIDTH - 1.
   (core-runtime-helper
    '$treelist-short-node
    "$treelist-short-node"
    (lambda ()
      `(func $treelist-short-node
             (param $plan      (ref $I32Array))
             (param $index     i32)
             (result i32)
             (if (result i32)
                 (i32.lt_u
                  (array.get $I32Array
                             (local.get $plan)
                             (local.get $index))
                  (i32.sub (global.get $treelist:MAX_WIDTH) (i32.const 1)))
                 (then (local.get $index))
                 (else
                  (call $treelist-short-node
                        (local.get $plan)
                        (i32.add (local.get $index) (i32.const 1))))))))


   ;; treelist-concat-plan/distribute : (ref $I32Array) i32 i32 i32 -> (ref $I32Array)
   ;;   Redistribute child counts with MAX_ERROR = 2 and return the surviving prefix.
   (core-runtime-helper
    '$treelist-concat-plan/distribute
    "$treelist-concat-plan/distribute"
    (lambda ()
      `(func $treelist-concat-plan/distribute
             (param $plan        (ref $I32Array))
             (param $target      i32)
             (param $count       i32)
             (param $node-index  i32)
             (result (ref $I32Array))
             (local $init-index i32)
             (local $i          i32)
             (local $r          i32)
             (local $min-size   i32)
             (local $j          i32)
             (if (i32.ge_u (local.get $target) (local.get $count))
                 (then
                  (return
                   (call $i32array-copy
                         (local.get $plan)
                         (i32.const 0)
                         (local.get $count)))))
             (local.set $init-index
                        (call $treelist-short-node
                              (local.get $plan)
                              (local.get $node-index)))
             (local.set $i (local.get $init-index))
             (local.set $r
                        (array.get $I32Array
                                   (local.get $plan)
                                   (local.get $init-index)))
             (block $redistribute-done
                    (loop $redistribute-loop
                          (br_if $redistribute-done
                                 (i32.eqz (local.get $r)))
                          (local.set $min-size
                                     (if (result i32)
                                         (i32.lt_u
                                          (i32.add
                                           (local.get $r)
                                           (array.get $I32Array
                                                      (local.get $plan)
                                                      (i32.add (local.get $i) (i32.const 1))))
                                          (global.get $treelist:MAX_WIDTH))
                                         (then
                                          (i32.add
                                           (local.get $r)
                                           (array.get $I32Array
                                                      (local.get $plan)
                                                      (i32.add (local.get $i) (i32.const 1)))))
                                         (else
                                          (global.get $treelist:MAX_WIDTH))))
                          (array.set $I32Array
                                     (local.get $plan)
                                     (local.get $i)
                                     (local.get $min-size))
                          (local.set $r
                                     (i32.sub
                                      (i32.add
                                       (local.get $r)
                                       (array.get $I32Array
                                                  (local.get $plan)
                                                  (i32.add (local.get $i) (i32.const 1))))
                                      (local.get $min-size)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $redistribute-loop)))
             (local.set $j (local.get $i))
             (block $shift-done
                    (loop $shift-loop
                          (br_if $shift-done
                                 (i32.ge_u (local.get $j)
                                           (i32.sub (local.get $count) (i32.const 1))))
                          (array.set $I32Array
                                     (local.get $plan)
                                     (local.get $j)
                                     (array.get $I32Array
                                                (local.get $plan)
                                                (i32.add (local.get $j) (i32.const 1))))
                          (local.set $j (i32.add (local.get $j) (i32.const 1)))
                          (br $shift-loop)))
             (call $treelist-concat-plan/distribute
                   (local.get $plan)
                   (local.get $target)
                   (i32.sub (local.get $count) (i32.const 1))
                   (i32.sub (local.get $i) (i32.const 1))))))


   ;; treelist-concat-plan : (ref $Array) -> (ref $I32Array)
   ;;   Compute RRB-style concat redistribution counts, or an empty array when no plan is needed.
   (core-runtime-helper
    '$treelist-concat-plan
    "$treelist-concat-plan"
    (lambda ()
      `(func $treelist-concat-plan
             (param $slots (ref $Array))
             (result (ref $I32Array))
             (local $slot-count        i32)
             (local $plan              (ref $I32Array))
             (local $child-count       i32)
             (local $optimal-node-len  i32)
             (local $target-node-len   i32)
             (local $i                 i32)
             (local $slot              (ref $TreelistNode))
             (local.set $slot-count (array.len (local.get $slots)))
             (local.set $plan
                        (array.new $I32Array (i32.const 0) (local.get $slot-count)))
             (local.set $child-count (i32.const 0))
             (local.set $i           (i32.const 0))
             (block $fill-done
                    (loop $fill-loop
                          (br_if $fill-done
                                 (i32.ge_u (local.get $i) (local.get $slot-count)))
                          (local.set $slot
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Array
                                                          (local.get $slots)
                                                          (local.get $i))))
                          (array.set $I32Array
                                     (local.get $plan)
                                     (local.get $i)
                                     (array.len
                                      (call $treelist-node-children
                                            (local.get $slot))))
                          (local.set $child-count
                                     (i32.add
                                      (local.get $child-count)
                                      (array.get $I32Array
                                                 (local.get $plan)
                                                 (local.get $i))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $fill-loop)))
             (local.set $optimal-node-len
                        (call $treelist-rebalance-node-count
                              (local.get $child-count)))
             (local.set $target-node-len
                        (i32.add (local.get $optimal-node-len) (i32.const 2)))
             (if (i32.ge_u (local.get $target-node-len) (local.get $slot-count))
                 (then
                  (return
                   (array.new $I32Array (i32.const 0) (i32.const 0)))))
             (call $treelist-concat-plan/distribute
                   (local.get $plan)
                   (local.get $target-node-len)
                   (local.get $slot-count)
                   (i32.const 0)))))


   ;; treelist-merge-boundary-slots/checked : left-node left-size center-nodes center-sizes right-node right-size height -> values
   ;;   Merge all but the last left child, all center nodes, and all but the first right child.
   (core-runtime-helper
    '$treelist-merge-boundary-slots/checked
    "$treelist-merge-boundary-slots/checked"
    (lambda ()
      `(func $treelist-merge-boundary-slots/checked
             (param $left-node     (ref $TreelistNode))
             (param $left-size     i32)
             (param $center-nodes  (ref $Array))
             (param $center-sizes  (ref $I32Array))
             (param $right-node    (ref $TreelistNode))
             (param $right-size    i32)
             (param $height        i32)
             (result (ref $Values))
             (local $left-present   i32)
             (local $right-present  i32)
             (local $left-children  (ref $Array))
             (local $right-children (ref $Array))
             (local $left-count     i32)
             (local $right-count    i32)
             (local $center-count   i32)
             (local $slot-count     i32)
             (local $slots          (ref $Array))
             (local $slot-sizes     (ref $I32Array))
             (local $i              i32)
             (local $dst            i32)
             (local $left-sizes     (ref $I32Array))
             (local $right-sizes    (ref $I32Array))
             (local.set $left-present
                        (if (result i32)
                            (i32.eqz (local.get $left-size))
                            (then (i32.const 0))
                            (else (i32.const 1))))
             (local.set $right-present
                        (if (result i32)
                            (i32.eqz (local.get $right-size))
                            (then (i32.const 0))
                            (else (i32.const 1))))
             (local.set $left-children  (global.get $dummy-array))
             (local.set $right-children (global.get $dummy-array))
             (local.set $left-sizes
                        (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $right-sizes
                        (array.new $I32Array (i32.const 0) (i32.const 0)))
             (if (local.get $left-present)
                 (then
                  (local.set $left-children
                             (call $treelist-node-children
                                   (local.get $left-node)))
                  (local.set $left-sizes
                             (call $treelist-node-child-sizes/exact
                                   (local.get $left-node)
                                   (local.get $left-size)
                                   (local.get $height)))))
             (if (local.get $right-present)
                 (then
                  (local.set $right-children
                             (call $treelist-node-children
                                   (local.get $right-node)))
                  (local.set $right-sizes
                             (call $treelist-node-child-sizes/exact
                                   (local.get $right-node)
                                   (local.get $right-size)
                                   (local.get $height)))))
             (local.set $left-count
                        (if (result i32)
                            (local.get $left-present)
                            (then
                             (i32.sub
                              (array.len (local.get $left-children))
                              (i32.const 1)))
                            (else (i32.const 0))))
             (local.set $right-count
                        (if (result i32)
                            (local.get $right-present)
                            (then
                             (i32.sub
                              (array.len (local.get $right-children))
                              (i32.const 1)))
                            (else (i32.const 0))))
             (local.set $center-count (array.len (local.get $center-nodes)))
             (local.set $slot-count
                        (i32.add
                         (i32.add (local.get $left-count) (local.get $center-count))
                         (local.get $right-count)))
             (local.set $slots
                        (call $make-array (local.get $slot-count) (global.get $false)))
             (local.set $slot-sizes
                        (array.new $I32Array (i32.const 0) (local.get $slot-count)))
             (local.set $i   (i32.const 0))
             (local.set $dst (i32.const 0))
             (block $left-done
                    (loop $left-loop
                          (br_if $left-done
                                 (i32.ge_u (local.get $i) (local.get $left-count)))
                          (array.set $Array
                                     (local.get $slots)
                                     (local.get $dst)
                                     (array.get $Array
                                                (local.get $left-children)
                                                (local.get $i)))
                          (array.set $I32Array
                                     (local.get $slot-sizes)
                                     (local.get $dst)
                                     (array.get $I32Array
                                                (local.get $left-sizes)
                                                (local.get $i)))
                          (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                          (local.set $dst (i32.add (local.get $dst) (i32.const 1)))
                          (br $left-loop)))
             (local.set $i (i32.const 0))
             (block $center-done
                    (loop $center-loop
                          (br_if $center-done
                                 (i32.ge_u (local.get $i) (local.get $center-count)))
                          (array.set $Array
                                     (local.get $slots)
                                     (local.get $dst)
                                     (array.get $Array
                                                (local.get $center-nodes)
                                                (local.get $i)))
                          (array.set $I32Array
                                     (local.get $slot-sizes)
                                     (local.get $dst)
                                     (array.get $I32Array
                                                (local.get $center-sizes)
                                                (local.get $i)))
                          (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                          (local.set $dst (i32.add (local.get $dst) (i32.const 1)))
                          (br $center-loop)))
             (local.set $i (i32.const 1))
             (block $right-done
                    (loop $right-loop
                          (br_if $right-done
                                 (i32.ge_u (local.get $i)
                                           (array.len (local.get $right-children))))
                          (array.set $Array
                                     (local.get $slots)
                                     (local.get $dst)
                                     (array.get $Array
                                                (local.get $right-children)
                                                (local.get $i)))
                          (array.set $I32Array
                                     (local.get $slot-sizes)
                                     (local.get $dst)
                                     (array.get $I32Array
                                                (local.get $right-sizes)
                                                (local.get $i)))
                          (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                          (local.set $dst (i32.add (local.get $dst) (i32.const 1)))
                          (br $right-loop)))
             (array.new_fixed $Values 2
                              (local.get $slots)
                              (local.get $slot-sizes)))))


   ;; treelist-exec-concat-plan/checked : slots slot-sizes plan height -> values
   ;;   Flatten exactly one child level and rebuild rebalanced slots at height - 1.
   (core-runtime-helper
    '$treelist-exec-concat-plan/checked
    "$treelist-exec-concat-plan/checked"
    (lambda ()
      `(func $treelist-exec-concat-plan/checked
             (param $slots       (ref $Array))
             (param $slot-sizes  (ref $I32Array))
             (param $plan        (ref $I32Array))
             (param $height      i32)
             (result (ref $Values))
             (local $slot-count        i32)
             (local $flattened-count   i32)
             (local $flattened         (ref $Array))
             (local $flattened-sizes   (ref $I32Array))
             (local $slot-index        i32)
             (local $child-index       i32)
             (local $flatten-index     i32)
             (local $slot              (ref $TreelistNode))
             (local $slot-size         i32)
             (local $slot-children     (ref $Array))
             (local $slot-child-sizes  (ref $I32Array))
             (local $packed-count      i32)
             (local $packed-nodes      (ref $Array))
             (local $packed-sizes      (ref $I32Array))
             (local $offset            i32)
             (local $piece-count       i32)
             (local $packed            (ref $Values))
             (local $packed-node       (ref $TreelistNode))
             (local $packed-size       i32)
             (local $i                 i32)
             (if (i32.eqz (array.len (local.get $plan)))
                 (then
                  (return
                   (array.new_fixed $Values 2
                                    (local.get $slots)
                                    (local.get $slot-sizes)))))
             (local.set $slot-count      (array.len (local.get $slots)))
             (local.set $flattened-count (i32.const 0))
             (local.set $slot-index      (i32.const 0))
             (block $count-done
                    (loop $count-loop
                          (br_if $count-done
                                 (i32.ge_u (local.get $slot-index) (local.get $slot-count)))
                          (local.set $slot
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Array
                                                          (local.get $slots)
                                                          (local.get $slot-index))))
                          (local.set $flattened-count
                                     (i32.add
                                      (local.get $flattened-count)
                                      (array.len
                                       (call $treelist-node-children
                                             (local.get $slot)))))
                          (local.set $slot-index
                                     (i32.add (local.get $slot-index) (i32.const 1)))
                          (br $count-loop)))
             (local.set $flattened
                        (call $make-array (local.get $flattened-count) (global.get $false)))
             (local.set $flattened-sizes
                        (array.new $I32Array (i32.const 0) (local.get $flattened-count)))
             (local.set $flatten-index (i32.const 0))
             (local.set $slot-index    (i32.const 0))
             (block $flatten-slots-done
                    (loop $flatten-slots-loop
                          (br_if $flatten-slots-done
                                 (i32.ge_u (local.get $slot-index) (local.get $slot-count)))
                          (local.set $slot
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Array
                                                          (local.get $slots)
                                                          (local.get $slot-index))))
                          (local.set $slot-size
                                     (array.get $I32Array
                                                (local.get $slot-sizes)
                                                (local.get $slot-index)))
                          (local.set $slot-children
                                     (call $treelist-node-children
                                           (local.get $slot)))
                          (local.set $slot-child-sizes
                                     (call $treelist-node-child-sizes/exact
                                           (local.get $slot)
                                           (local.get $slot-size)
                                           (i32.sub (local.get $height) (i32.const 1))))
                          (local.set $child-index (i32.const 0))
                          (block $flatten-child-done
                                 (loop $flatten-child-loop
                                       (br_if $flatten-child-done
                                              (i32.ge_u (local.get $child-index)
                                                        (array.len (local.get $slot-children))))
                                       (array.set $Array
                                                  (local.get $flattened)
                                                  (local.get $flatten-index)
                                                  (array.get $Array
                                                             (local.get $slot-children)
                                                             (local.get $child-index)))
                                       (array.set $I32Array
                                                  (local.get $flattened-sizes)
                                                  (local.get $flatten-index)
                                                  (array.get $I32Array
                                                             (local.get $slot-child-sizes)
                                                             (local.get $child-index)))
                                       (local.set $child-index
                                                  (i32.add (local.get $child-index) (i32.const 1)))
                                       (local.set $flatten-index
                                                  (i32.add (local.get $flatten-index) (i32.const 1)))
                                       (br $flatten-child-loop)))
                          (local.set $slot-index
                                     (i32.add (local.get $slot-index) (i32.const 1)))
                          (br $flatten-slots-loop)))
             (local.set $packed-count (array.len (local.get $plan)))
             (local.set $packed-nodes
                        (call $make-array (local.get $packed-count) (global.get $false)))
             (local.set $packed-sizes
                        (array.new $I32Array (i32.const 0) (local.get $packed-count)))
             (local.set $offset (i32.const 0))
             (local.set $i      (i32.const 0))
             (block $pack-done
                    (loop $pack-loop
                          (br_if $pack-done
                                 (i32.ge_u (local.get $i) (local.get $packed-count)))
                          (local.set $piece-count
                                     (array.get $I32Array
                                                (local.get $plan)
                                                (local.get $i)))
                          (local.set $packed
                                     (call $treelist-pack-children-range/checked
                                           (local.get $flattened)
                                           (local.get $flattened-sizes)
                                           (local.get $offset)
                                           (local.get $piece-count)
                                           (i32.sub (local.get $height) (i32.const 1))))
                          (local.set $packed-node
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Values (local.get $packed) (i32.const 0))))
                          (local.set $packed-size
                                     (i32.shr_u
                                      (i31.get_u
                                       (ref.cast (ref i31)
                                                 (array.get $Values (local.get $packed) (i32.const 1))))
                                      (i32.const 1)))
                          (array.set $Array
                                     (local.get $packed-nodes)
                                     (local.get $i)
                                     (local.get $packed-node))
                          (array.set $I32Array
                                     (local.get $packed-sizes)
                                     (local.get $i)
                                     (local.get $packed-size))
                          (local.set $offset
                                     (i32.add (local.get $offset) (local.get $piece-count)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $pack-loop)))
             (array.new_fixed $Values 2
                              (local.get $packed-nodes)
                              (local.get $packed-sizes)))))


   ;; treelist-rebalance-boundary/checked : left-node left-size center-nodes center-sizes right-node right-size height -> values
   ;;   Rebalance one append boundary level, returning one or two nodes at height.
   (core-runtime-helper
    '$treelist-rebalance-boundary/checked
    "$treelist-rebalance-boundary/checked"
    (lambda ()
      `(func $treelist-rebalance-boundary/checked
             (param $left-node     (ref $TreelistNode))
             (param $left-size     i32)
             (param $center-nodes  (ref $Array))
             (param $center-sizes  (ref $I32Array))
             (param $right-node    (ref $TreelistNode))
             (param $right-size    i32)
             (param $height        i32)
             (result (ref $Values))
             (local $merged        (ref $Values))
             (local $slots         (ref $Array))
             (local $slot-sizes    (ref $I32Array))
             (local $plan          (ref $I32Array))
             (local $rebalanced    (ref $Values))
             (local $packed-nodes  (ref $Array))
             (local $packed-sizes  (ref $I32Array))
             (local $packed-count  i32)
             (local $first-node    (ref $TreelistNode))
             (local $second-node   (ref $TreelistNode))
             (local $first-size    i32)
             (local $second-size   i32)
             (local.set $merged
                        (call $treelist-merge-boundary-slots/checked
                              (local.get $left-node)
                              (local.get $left-size)
                              (local.get $center-nodes)
                              (local.get $center-sizes)
                              (local.get $right-node)
                              (local.get $right-size)
                              (local.get $height)))
             (local.set $slots
                        (ref.cast (ref $Array)
                                  (array.get $Values (local.get $merged) (i32.const 0))))
             (local.set $slot-sizes
                        (ref.cast (ref $I32Array)
                                  (array.get $Values (local.get $merged) (i32.const 1))))
             (local.set $plan
                        (call $treelist-concat-plan
                              (local.get $slots)))
             (local.set $rebalanced
                        (call $treelist-exec-concat-plan/checked
                              (local.get $slots)
                              (local.get $slot-sizes)
                              (local.get $plan)
                              (local.get $height)))
             (local.set $packed-nodes
                        (ref.cast (ref $Array)
                                  (array.get $Values (local.get $rebalanced) (i32.const 0))))
             (local.set $packed-sizes
                        (ref.cast (ref $I32Array)
                                  (array.get $Values (local.get $rebalanced) (i32.const 1))))
             (local.set $packed-count (array.len (local.get $packed-nodes)))
             (if (i32.le_u (local.get $packed-count) (global.get $treelist:MAX_WIDTH))
                 (then
                  (local.set $first-node
                             (call $treelist-node-build/checked
                                   (local.get $packed-nodes)
                                   (local.get $packed-sizes)
                                   (local.get $height)))
                  (local.set $first-size (i32.const 0))
                  (local.set $packed-count (i32.const 0))
                  (block $sum-done
                         (loop $sum-loop
                               (br_if $sum-done
                                      (i32.ge_u (local.get $packed-count)
                                                (array.len (local.get $packed-sizes))))
                               (local.set $first-size
                                          (i32.add
                                           (local.get $first-size)
                                           (array.get $I32Array
                                                      (local.get $packed-sizes)
                                                      (local.get $packed-count))))
                               (local.set $packed-count
                                          (i32.add (local.get $packed-count) (i32.const 1)))
                               (br $sum-loop)))
                  (return
                   (array.new_fixed $Values 4
                                    (local.get $first-node)
                                    (global.get $dummy-treelist-node)
                                    (ref.i31 (i32.shl (local.get $first-size) (i32.const 1)))
                                    (ref.i31 (i32.const 0))))))
             (local.set $first-node
                        (call $treelist-node-build/checked
                              (call $array-copy
                                    (local.get $packed-nodes)
                                    (i32.const 0)
                                    (global.get $treelist:MAX_WIDTH))
                              (call $i32array-copy
                                    (local.get $packed-sizes)
                                    (i32.const 0)
                                    (global.get $treelist:MAX_WIDTH))
                              (local.get $height)))
             (local.set $second-node
                        (call $treelist-node-build/checked
                              (call $array-copy
                                    (local.get $packed-nodes)
                                    (global.get $treelist:MAX_WIDTH)
                                    (array.len (local.get $packed-nodes)))
                              (call $i32array-copy
                                    (local.get $packed-sizes)
                                    (global.get $treelist:MAX_WIDTH)
                                    (array.len (local.get $packed-sizes)))
                              (local.get $height)))
             (local.set $first-size (i32.const 0))
             (local.set $packed-count (i32.const 0))
             (block $sum-left-done
                    (loop $sum-left-loop
                          (br_if $sum-left-done
                                 (i32.ge_u (local.get $packed-count)
                                           (global.get $treelist:MAX_WIDTH)))
                          (local.set $first-size
                                     (i32.add
                                      (local.get $first-size)
                                      (array.get $I32Array
                                                 (local.get $packed-sizes)
                                                 (local.get $packed-count))))
                          (local.set $packed-count
                                     (i32.add (local.get $packed-count) (i32.const 1)))
                          (br $sum-left-loop)))
             (local.set $second-size
                        (i32.const 0))
             (block $sum-right-done
                    (loop $sum-right-loop
                          (br_if $sum-right-done
                                 (i32.ge_u (local.get $packed-count)
                                           (array.len (local.get $packed-sizes))))
                          (local.set $second-size
                                     (i32.add
                                      (local.get $second-size)
                                      (array.get $I32Array
                                                 (local.get $packed-sizes)
                                                 (local.get $packed-count))))
                          (local.set $packed-count
                                     (i32.add (local.get $packed-count) (i32.const 1)))
                          (br $sum-right-loop)))
             (array.new_fixed $Values 4
                              (local.get $first-node)
                              (local.get $second-node)
                              (ref.i31 (i32.shl (local.get $first-size) (i32.const 1)))
                              (ref.i31 (i32.shl (local.get $second-size) (i32.const 1)))))))


   ;; treelist-concat-subtree/checked : left-node left-size left-height right-node right-size right-height -> values
   ;;   Concatenate two subtree roots using Racket-style boundary rebalance, returning one or two nodes.
   (core-runtime-helper
    '$treelist-concat-subtree/checked
    "$treelist-concat-subtree/checked"
    (lambda ()
      `(func $treelist-concat-subtree/checked
             (param $left-node     (ref $TreelistNode))
             (param $left-size     i32)
             (param $left-height   i32)
             (param $right-node    (ref $TreelistNode))
             (param $right-size    i32)
             (param $right-height  i32)
             (result (ref $Values))
             (local $children      (ref $Array))
             (local $last-index    i32)
             (local $left-child    (ref $TreelistNode))
             (local $left-child-size i32)
             (local $right-child   (ref $TreelistNode))
             (local $right-child-size i32)
             (local $mid           (ref $Values))
             (local $center-nodes  (ref $Array))
             (local $center-sizes  (ref $I32Array))
             (local $center-count  i32)
             (local $first         (ref $TreelistNode))
             (local $second        (ref $TreelistNode))
             (local $first-size    i32)
             (local $second-size   i32)
             (local.set $children     (global.get $dummy-array))
             (local.set $left-child   (global.get $dummy-treelist-node))
             (local.set $right-child  (global.get $dummy-treelist-node))
             (local.set $mid          (array.new_fixed $Values 0))
             (local.set $center-nodes (global.get $dummy-array))
             (local.set $center-sizes (array.new $I32Array (i32.const 0) (i32.const 0)))
             (if (i32.gt_u (local.get $left-height) (local.get $right-height))
                 (then
                  (local.set $children
                             (call $treelist-node-children
                                   (local.get $left-node)))
                  (local.set $last-index
                             (i32.sub (array.len (local.get $children)) (i32.const 1)))
                  (local.set $left-child
                             (ref.cast (ref $TreelistNode)
                                       (array.get $Array
                                                  (local.get $children)
                                                  (local.get $last-index))))
                  (local.set $left-child-size
                             (call $treelist-node-child-size
                                   (local.get $left-node)
                                   (local.get $left-size)
                                   (local.get $left-height)
                                   (local.get $last-index)))
                  (local.set $mid
                             (call $treelist-concat-subtree/checked
                                   (local.get $left-child)
                                   (local.get $left-child-size)
                                   (i32.sub (local.get $left-height) (i32.const 1))
                                   (local.get $right-node)
                                   (local.get $right-size)
                                   (local.get $right-height)))
                  (local.set $first
                             (ref.cast (ref $TreelistNode)
                                       (array.get $Values (local.get $mid) (i32.const 0))))
                  (local.set $first-size
                             (i32.shr_u
                              (i31.get_u
                               (ref.cast (ref i31)
                                         (array.get $Values (local.get $mid) (i32.const 2))))
                              (i32.const 1)))
                  (local.set $second-size
                             (i32.shr_u
                              (i31.get_u
                               (ref.cast (ref i31)
                                         (array.get $Values (local.get $mid) (i32.const 3))))
                              (i32.const 1)))
                  (local.set $center-count
                             (if (result i32)
                                 (i32.eqz (local.get $second-size))
                                 (then (i32.const 1))
                                 (else (i32.const 2))))
                  (local.set $center-nodes
                             (call $make-array (local.get $center-count) (global.get $false)))
                  (local.set $center-sizes
                             (array.new $I32Array (i32.const 0) (local.get $center-count)))
                  (array.set $Array (local.get $center-nodes) (i32.const 0) (local.get $first))
                  (array.set $I32Array (local.get $center-sizes) (i32.const 0) (local.get $first-size))
                  (if (i32.gt_u (local.get $second-size) (i32.const 0))
                      (then
                       (local.set $second
                                  (ref.cast (ref $TreelistNode)
                                            (array.get $Values (local.get $mid) (i32.const 1))))
                       (array.set $Array (local.get $center-nodes) (i32.const 1) (local.get $second))
                       (array.set $I32Array (local.get $center-sizes) (i32.const 1) (local.get $second-size))))
                  (return
                   (call $treelist-rebalance-boundary/checked
                         (local.get $left-node)
                         (local.get $left-size)
                         (local.get $center-nodes)
                         (local.get $center-sizes)
                         (global.get $dummy-treelist-node)
                         (i32.const 0)
                         (local.get $left-height)))))
             (if (i32.lt_u (local.get $left-height) (local.get $right-height))
                 (then
                  (local.set $children
                             (call $treelist-node-children
                                   (local.get $right-node)))
                  (local.set $right-child
                             (ref.cast (ref $TreelistNode)
                                       (array.get $Array
                                                  (local.get $children)
                                                  (i32.const 0))))
                  (local.set $right-child-size
                             (call $treelist-node-child-size
                                   (local.get $right-node)
                                   (local.get $right-size)
                                   (local.get $right-height)
                                   (i32.const 0)))
                  (local.set $mid
                             (call $treelist-concat-subtree/checked
                                   (local.get $left-node)
                                   (local.get $left-size)
                                   (local.get $left-height)
                                   (local.get $right-child)
                                   (local.get $right-child-size)
                                   (i32.sub (local.get $right-height) (i32.const 1))))
                  (local.set $first
                             (ref.cast (ref $TreelistNode)
                                       (array.get $Values (local.get $mid) (i32.const 0))))
                  (local.set $first-size
                             (i32.shr_u
                              (i31.get_u
                               (ref.cast (ref i31)
                                         (array.get $Values (local.get $mid) (i32.const 2))))
                              (i32.const 1)))
                  (local.set $second-size
                             (i32.shr_u
                              (i31.get_u
                               (ref.cast (ref i31)
                                         (array.get $Values (local.get $mid) (i32.const 3))))
                              (i32.const 1)))
                  (local.set $center-count
                             (if (result i32)
                                 (i32.eqz (local.get $second-size))
                                 (then (i32.const 1))
                                 (else (i32.const 2))))
                  (local.set $center-nodes
                             (call $make-array (local.get $center-count) (global.get $false)))
                  (local.set $center-sizes
                             (array.new $I32Array (i32.const 0) (local.get $center-count)))
                  (array.set $Array (local.get $center-nodes) (i32.const 0) (local.get $first))
                  (array.set $I32Array (local.get $center-sizes) (i32.const 0) (local.get $first-size))
                  (if (i32.gt_u (local.get $second-size) (i32.const 0))
                      (then
                       (local.set $second
                                  (ref.cast (ref $TreelistNode)
                                            (array.get $Values (local.get $mid) (i32.const 1))))
                       (array.set $Array (local.get $center-nodes) (i32.const 1) (local.get $second))
                       (array.set $I32Array (local.get $center-sizes) (i32.const 1) (local.get $second-size))))
                  (return
                   (call $treelist-rebalance-boundary/checked
                         (global.get $dummy-treelist-node)
                         (i32.const 0)
                         (local.get $center-nodes)
                         (local.get $center-sizes)
                         (local.get $right-node)
                         (local.get $right-size)
                         (local.get $right-height)))))
             (if (i32.eqz (local.get $left-height))
                 (then
                  (return
                   (call $treelist-pack-same-height/checked
                         (local.get $left-node)
                         (local.get $left-size)
                         (local.get $right-node)
                         (local.get $right-size)
                         (i32.const 0)))))
             (local.set $children
                        (call $treelist-node-children
                              (local.get $left-node)))
             (local.set $last-index
                        (i32.sub (array.len (local.get $children)) (i32.const 1)))
             (local.set $left-child
                        (ref.cast (ref $TreelistNode)
                                  (array.get $Array
                                             (local.get $children)
                                             (local.get $last-index))))
             (local.set $left-child-size
                        (call $treelist-node-child-size
                              (local.get $left-node)
                              (local.get $left-size)
                              (local.get $left-height)
                              (local.get $last-index)))
             (local.set $children
                        (call $treelist-node-children
                              (local.get $right-node)))
             (local.set $right-child
                        (ref.cast (ref $TreelistNode)
                                  (array.get $Array
                                             (local.get $children)
                                             (i32.const 0))))
             (local.set $right-child-size
                        (call $treelist-node-child-size
                              (local.get $right-node)
                              (local.get $right-size)
                              (local.get $right-height)
                              (i32.const 0)))
             (local.set $mid
                        (call $treelist-concat-subtree/checked
                              (local.get $left-child)
                              (local.get $left-child-size)
                              (i32.sub (local.get $left-height) (i32.const 1))
                              (local.get $right-child)
                              (local.get $right-child-size)
                              (i32.sub (local.get $right-height) (i32.const 1))))
             (local.set $first
                        (ref.cast (ref $TreelistNode)
                                  (array.get $Values (local.get $mid) (i32.const 0))))
             (local.set $first-size
                        (i32.shr_u
                         (i31.get_u
                          (ref.cast (ref i31)
                                    (array.get $Values (local.get $mid) (i32.const 2))))
                         (i32.const 1)))
             (local.set $second-size
                        (i32.shr_u
                         (i31.get_u
                          (ref.cast (ref i31)
                                    (array.get $Values (local.get $mid) (i32.const 3))))
                         (i32.const 1)))
             (local.set $center-count
                        (if (result i32)
                            (i32.eqz (local.get $second-size))
                            (then (i32.const 1))
                            (else (i32.const 2))))
             (local.set $center-nodes
                        (call $make-array (local.get $center-count) (global.get $false)))
             (local.set $center-sizes
                        (array.new $I32Array (i32.const 0) (local.get $center-count)))
             (array.set $Array (local.get $center-nodes) (i32.const 0) (local.get $first))
             (array.set $I32Array (local.get $center-sizes) (i32.const 0) (local.get $first-size))
             (if (i32.gt_u (local.get $second-size) (i32.const 0))
                 (then
                  (local.set $second
                             (ref.cast (ref $TreelistNode)
                                       (array.get $Values (local.get $mid) (i32.const 1))))
                  (array.set $Array (local.get $center-nodes) (i32.const 1) (local.get $second))
                  (array.set $I32Array (local.get $center-sizes) (i32.const 1) (local.get $second-size))))
             (call $treelist-rebalance-boundary/checked
                   (local.get $left-node)
                   (local.get $left-size)
                   (local.get $center-nodes)
                   (local.get $center-sizes)
                   (local.get $right-node)
                   (local.get $right-size)
                   (local.get $left-height)))))


   ;; treelist-append2/checked : (ref $Treelist) (ref $Treelist) -> (ref $Treelist)
   ;;   Append two treelists structurally via recursive concat-subtree boundary rebalance.
   (core-runtime-helper
    '$treelist-append2/checked
    "$treelist-append2/checked"
    (lambda ()
      `(func $treelist-append2/checked
             (param $left  (ref $Treelist))
             (param $right (ref $Treelist))
             (result (ref $Treelist))
             (local $left-size     i32)
             (local $right-size    i32)
             (local $total-size    i32)
             (local $left-height   i32)
             (local $right-height  i32)
             (local $packed        (ref $Values))
             (local $packed-first  (ref $TreelistNode))
             (local $packed-second (ref $TreelistNode))
             (local $packed-size-1 i32)
             (local $packed-size-2 i32)
             (local.set $packed      (array.new_fixed $Values 0))
             (local.set $packed-first (global.get $dummy-treelist-node))
             (local.set $packed-second (global.get $dummy-treelist-node))
             (local.set $left-size  (struct.get $Treelist $size (local.get $left)))
             (local.set $right-size (struct.get $Treelist $size (local.get $right)))
             (if (i32.eqz (local.get $left-size))
                 (then (return (local.get $right))))
             (if (i32.eqz (local.get $right-size))
                 (then (return (local.get $left))))
             (local.set $left-height  (struct.get $Treelist $height (local.get $left)))
             (local.set $right-height (struct.get $Treelist $height (local.get $right)))
             (local.set $total-size
                        (i32.add (local.get $left-size) (local.get $right-size)))
             (local.set $packed
                        (call $treelist-concat-subtree/checked
                              (struct.get $Treelist $root (local.get $left))
                              (local.get $left-size)
                              (local.get $left-height)
                              (struct.get $Treelist $root (local.get $right))
                              (local.get $right-size)
                              (local.get $right-height)))
             (local.set $packed-first
                        (ref.cast (ref $TreelistNode)
                                  (array.get $Values (local.get $packed) (i32.const 0))))
             (local.set $packed-size-1
                        (i32.shr_u
                         (i31.get_u
                          (ref.cast (ref i31)
                                    (array.get $Values (local.get $packed) (i32.const 2))))
                         (i32.const 1)))
             (local.set $packed-size-2
                        (i32.shr_u
                         (i31.get_u
                          (ref.cast (ref i31)
                                    (array.get $Values (local.get $packed) (i32.const 3))))
                         (i32.const 1)))
             (if (i32.eqz (local.get $packed-size-2))
                 (then
                  (return
                   (struct.new $Treelist
                               (i32.const 0)
                               (local.get $packed-first)
                               (local.get $total-size)
                               (if (result i32)
                                   (i32.gt_u (local.get $left-height) (local.get $right-height))
                                   (then (local.get $left-height))
                                   (else (local.get $right-height)))))))
             (local.set $packed-second
                        (ref.cast (ref $TreelistNode)
                                  (array.get $Values (local.get $packed) (i32.const 1))))
             (struct.new $Treelist
                         (i32.const 0)
                         (call $treelist-make-parent-root/checked
                               (local.get $packed-first)
                               (local.get $packed-size-1)
                               (local.get $packed-second)
                               (local.get $packed-size-2)
                               (if (result i32)
                                   (i32.gt_u (local.get $left-height) (local.get $right-height))
                                   (then (local.get $left-height))
                                   (else (local.get $right-height))))
                         (local.get $total-size)
                         (i32.add
                          (if (result i32)
                              (i32.gt_u (local.get $left-height) (local.get $right-height))
                              (then (local.get $left-height))
                              (else (local.get $right-height)))
                          (i32.const 1))))))
))
