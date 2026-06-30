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


   ;; treelist-leaf : (ref eq) -> (ref $TreelistNode)
   ;;   Build a leaf node containing one value.
   (core-runtime-helper
    '$treelist-leaf
    "$treelist-leaf"
    (lambda ()
      `(func $treelist-leaf
             (param $v (ref eq))
             (result (ref $TreelistNode))
             (struct.new $TreelistNode
                         (i32.const 0)                     ;; hash
                         (array.new_fixed $Array 1 (local.get $v))
                         (ref.null $I32Array)))))


   ;; treelist-build-dense-node : (ref $Array) i32 i32 i32 -> (ref $TreelistNode)
   ;;   Build a dense subtree from a source array slice.
   (core-runtime-helper
    '$treelist-build-dense-node
    "$treelist-build-dense-node"
    (lambda ()
      `(func $treelist-build-dense-node
             (param $src    (ref $Array))
             (param $start  i32)
             (param $count  i32)
             (param $height i32)
             (result (ref $TreelistNode))

             (local $arr         (ref $Array))
             (local $child-count i32)
             (local $chunk-size  i32)
             (local $remaining   i32)
             (local $child-size  i32)
             (local $child-start i32)
             (local $child-index i32)
             (local $child-node  (ref $TreelistNode))

             (if (i32.eqz (local.get $height))
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (call $array-copy
                                     (local.get $src)
                                     (local.get $start)
                                     (i32.add (local.get $start) (local.get $count)))
                               (ref.null $I32Array)))))

             (local.set $chunk-size
                        (i32.shl (i32.const 1)
                                 (i32.mul (global.get $treelist:BITS) (local.get $height))))
             (local.set $child-count
                        (i32.div_u
                         (i32.add
                          (local.get $count)
                          (i32.sub (local.get $chunk-size) (i32.const 1)))
                         (local.get $chunk-size)))
             (local.set $arr (call $make-array (local.get $child-count) (global.get $false)))
             (local.set $remaining   (local.get $count))
             (local.set $child-start (local.get $start))
             (local.set $child-index (i32.const 0))

             (block $done
                    (loop $loop
                          (br_if $done
                                 (i32.ge_u (local.get $child-index) (local.get $child-count)))
                          (local.set $child-size
                                     (if (result i32)
                                         (i32.lt_u (local.get $remaining) (local.get $chunk-size))
                                         (then (local.get $remaining))
                                         (else (local.get $chunk-size))))
                          (local.set $child-node
                                     (call $treelist-build-dense-node
                                           (local.get $src)
                                           (local.get $child-start)
                                           (local.get $child-size)
                                           (i32.sub (local.get $height) (i32.const 1))))
                          (array.set $Array
                                     (local.get $arr)
                                     (local.get $child-index)
                                     (local.get $child-node))
                          (local.set $child-start
                                     (i32.add (local.get $child-start) (local.get $child-size)))
                          (local.set $remaining
                                     (i32.sub (local.get $remaining) (local.get $child-size)))
                          (local.set $child-index
                                     (i32.add (local.get $child-index) (i32.const 1)))
                          (br $loop)))

             (struct.new $TreelistNode
                         (i32.const 0)
                         (local.get $arr)
                         (ref.null $I32Array)))))


   ;; array->treelist/checked : (ref $Array) -> (ref $Treelist)
   ;;   Build a treelist from an array of already-checked elements.
   (core-runtime-helper
    '$array->treelist/checked
    "$array->treelist/checked"
    (lambda ()
      `(func $array->treelist/checked
             (param $src (ref $Array))
             (result (ref $Treelist))
             (local $len i32)
             (local $height i32)
             (local $root (ref $TreelistNode))
             (local.set $len (array.len (local.get $src)))
             (if (i32.eqz (local.get $len))
                 (then (return (global.get $empty-treelist))))
             (local.set $height (call $treelist-height-for-size (local.get $len)))
             (local.set $root
                        (call $treelist-build-dense-node
                              (local.get $src)
                              (i32.const 0)
                              (local.get $len)
                              (local.get $height)))
             (struct.new $Treelist
                         (i32.const 0)
                         (local.get $root)
                         (local.get $len)
                         (local.get $height)))))


   ;; treelist-node-build/checked : (ref $Array) (ref $I32Array) i32 -> (ref $TreelistNode)
   ;;   Build a node from children plus exact child sizes, preserving sizes = null when dense.
   (core-runtime-helper
    '$treelist-node-build/checked
    "$treelist-node-build/checked"
    (lambda ()
      `(func $treelist-node-build/checked
             (param $children    (ref $Array))
             (param $child-sizes (ref $I32Array))
             (param $height      i32)
             (result (ref $TreelistNode))
             (local $count     i32)
             (local $child-cap i32)
             (local $dense-ok  i32)
             (local $i         i32)
             (local $child-raw (ref eq))
             (local $sizes     (ref $I32Array))
             (local $sum       i32)
             (local.set $count (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (local.get $children)
                               (ref.null $I32Array)))))
             (local.set $child-cap
                        (call $treelist-node-capacity
                              (i32.sub (local.get $height) (i32.const 1))))
             (local.set $dense-ok (i32.const 1))
             (local.set $i (i32.const 0))
             (block $check-done
                    (loop $check-loop
                          (br_if $check-done (i32.ge_u (local.get $i) (local.get $count)))
                          (local.set $child-raw
                                     (array.get $Array (local.get $children) (local.get $i)))
                          (if (i32.eqz
                               (call $treelist-node-leftwise-dense?/i32
                                     (ref.cast (ref $TreelistNode) (local.get $child-raw))))
                              (then (local.set $dense-ok (i32.const 0))
                                    (br $check-done)))
                          (if (i32.and
                               (i32.lt_u (local.get $i) (i32.sub (local.get $count) (i32.const 1)))
                               (i32.ne (array.get $I32Array (local.get $child-sizes) (local.get $i))
                                       (local.get $child-cap)))
                              (then (local.set $dense-ok (i32.const 0))
                                    (br $check-done)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $check-loop)))
             (if (local.get $dense-ok)
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (local.get $children)
                               (ref.null $I32Array)))))
             (local.set $sizes (array.new $I32Array (i32.const 0) (local.get $count)))
             (local.set $sum (i32.const 0))
             (local.set $i   (i32.const 0))
             (block $sizes-done
                    (loop $sizes-loop
                          (br_if $sizes-done (i32.ge_u (local.get $i) (local.get $count)))
                          (local.set $sum
                                     (i32.add
                                      (local.get $sum)
                                      (array.get $I32Array
                                                 (local.get $child-sizes)
                                                 (local.get $i))))
                          (array.set $I32Array
                                     (local.get $sizes)
                                     (local.get $i)
                                     (local.get $sum))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $sizes-loop)))
             (struct.new $TreelistNode
                         (i32.const 0)
                         (local.get $children)
                         (local.get $sizes)))))


   ;; treelist-from-node/checked : (ref $TreelistNode) i32 i32 -> (ref $Treelist)
   ;;   Build a treelist from a non-empty root and squash unary roots.
   (core-runtime-helper
    '$treelist-from-node/checked
    "$treelist-from-node/checked"
    (lambda ()
      `(func $treelist-from-node/checked
             (param $node   (ref $TreelistNode))
             (param $size   i32)
             (param $height i32)
             (result (ref $Treelist))
             (local $cur-node (ref $TreelistNode))
             (local $curh     i32)
             (local $child    (ref eq))
             (local.set $cur-node (local.get $node))
             (local.set $curh     (local.get $height))
             (if (i32.eqz (local.get $size))
                 (then (return (global.get $empty-treelist))))
             (local.set $child (global.get $false))
             (block $done
                    (loop $loop
                          (br_if $done
                                 (i32.or
                                  (i32.eqz (local.get $curh))
                                  (i32.ne (call $treelist-node-child-count (local.get $cur-node))
                                          (i32.const 1))))
                          (local.set $child
                                     (array.get $Array
                                                (call $treelist-node-children (local.get $cur-node))
                                                (i32.const 0)))
                          (local.set $cur-node (ref.cast (ref $TreelistNode) (local.get $child)))
                          (local.set $curh (i32.sub (local.get $curh) (i32.const 1)))
                          (br $loop)))
             (struct.new $Treelist
                         (i32.const 0)
                         (local.get $cur-node)
                         (local.get $size)
                         (local.get $curh)))))


   ;; treelist-singleton-branch : i32 (ref eq) -> (ref $TreelistNode)
   ;;   Build a dense rightmost branch containing one value at height.
   (core-runtime-helper
    '$treelist-singleton-branch
    "$treelist-singleton-branch"
    (lambda ()
      `(func $treelist-singleton-branch
             (param $height i32)
             (param $v      (ref eq))
             (result (ref $TreelistNode))
             (local $child (ref $TreelistNode))
             (local.set $child (global.get $dummy-treelist-node))
             (if (i32.eqz (local.get $height))
                 (then
                  (return (call $treelist-leaf (local.get $v)))))
             (local.set $child
                        (call $treelist-singleton-branch
                              (i32.sub (local.get $height) (i32.const 1))
                              (local.get $v)))
             (struct.new $TreelistNode
                         (i32.const 0)
                         (array.new_fixed $Array 1 (local.get $child))
                         (ref.null $I32Array)))))


   ;; treelist-node-child-sizes/exact : (ref $TreelistNode) i32 i32 -> (ref $I32Array)
   ;;   Compute exact subtree sizes for each child of node.
   (core-runtime-helper
    '$treelist-node-child-sizes/exact
    "$treelist-node-child-sizes/exact"
    (lambda ()
      `(func $treelist-node-child-sizes/exact
             (param $node      (ref $TreelistNode))
             (param $node-size i32)
             (param $height    i32)
             (result (ref $I32Array))
             (local $child-count i32)
             (local $sizes      (ref $I32Array))
             (local $i          i32)
             (local.set $child-count
                        (call $treelist-node-child-count (local.get $node)))
             (local.set $sizes
                        (array.new $I32Array (i32.const 0) (local.get $child-count)))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $child-count)))
                          (array.set $I32Array
                                     (local.get $sizes)
                                     (local.get $i)
                                     (call $treelist-node-child-size
                                           (local.get $node)
                                           (local.get $node-size)
                                           (local.get $height)
                                           (local.get $i)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $sizes))))


   ;; treelist-node-copy-into! : (ref $TreelistNode) i32 (ref $Array) i32 -> i32
   ;;   Copy node elements into dest and return the next destination index.
   (core-runtime-helper
    '$treelist-node-copy-into!
    "$treelist-node-copy-into!"
    (lambda ()
      `(func $treelist-node-copy-into!
             (param $node       (ref $TreelistNode))
             (param $height     i32)
             (param $dest       (ref $Array))
             (param $dest-start i32)
             (result i32)
             (local $children (ref $Array))
             (local $len      i32)
             (local $i        i32)
             (local $x        (ref eq))
             (local $pos      i32)
             (local $child    (ref $TreelistNode))

             (local.set $children (struct.get $TreelistNode $children (local.get $node)))
             (local.set $len      (array.len (local.get $children)))

             (if (i32.eqz (local.get $height))
                 (then
                  (local.set $i (i32.const 0))
                  (block $done-leaf
                         (loop $leaf
                               (br_if $done-leaf (i32.ge_u (local.get $i) (local.get $len)))
                               (local.set $x (array.get $Array (local.get $children) (local.get $i)))
                               (array.set $Array
                                          (local.get $dest)
                                          (i32.add (local.get $dest-start) (local.get $i))
                                          (local.get $x))
                               (local.set $i (i32.add (local.get $i) (i32.const 1)))
                               (br $leaf)))
                  (return (i32.add (local.get $dest-start) (local.get $len)))))

             (local.set $pos (local.get $dest-start))
             (local.set $i   (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                          (local.set $child
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Array (local.get $children) (local.get $i))))
                          (local.set $pos
                                     (call $treelist-node-copy-into!
                                           (local.get $child)
                                           (i32.sub (local.get $height) (i32.const 1))
                                           (local.get $dest)
                                           (local.get $pos)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $pos))))


   ;; treelist->array/checked : (ref $Treelist) -> (ref $Array)
   ;;   Copy treelist elements into a new array.
   (core-runtime-helper
    '$treelist->array/checked
    "$treelist->array/checked"
    (lambda ()
      `(func $treelist->array/checked
             (param $tl (ref $Treelist))
             (result (ref $Array))
             (local $len i32)
             (local $arr (ref $Array))
             (local.set $len (struct.get $Treelist $size (local.get $tl)))
             (local.set $arr (call $make-array (local.get $len) (global.get $false)))
             (if (i32.eqz (local.get $len))
                 (then (return (local.get $arr))))
             (drop
              (call $treelist-node-copy-into!
                    (struct.get $Treelist $root (local.get $tl))
                    (struct.get $Treelist $height (local.get $tl))
                    (local.get $arr)
                    (i32.const 0)))
             (local.get $arr))))


   ;; treelist-node-split/checked : (ref $TreelistNode) i32 i32 i32 -> (ref $Values)
   ;;   Split node at logical index i, returning left-node, right-node, left-size, right-size.
   (core-runtime-helper
    '$treelist-node-split/checked
    "$treelist-node-split/checked"
    (lambda ()
      `(func $treelist-node-split/checked
             (param $node      (ref $TreelistNode))
             (param $node-size i32)
             (param $height    i32)
             (param $i         i32)
             (result (ref $Values))
             (local $children      (ref $Array))
             (local $child-count   i32)
             (local $child-cap     i32)
             (local $child-index   i32)
             (local $child-start   i32)
             (local $child-size    i32)
             (local $child-local   i32)
             (local $split-values  (ref $Values))
             (local $split-left-raw  (ref eq))
             (local $split-right-raw (ref eq))
             (local $split-left-node  (ref $TreelistNode))
             (local $split-right-node (ref $TreelistNode))
             (local $split-left-size  i32)
             (local $split-right-size i32)
             (local $left-ga       (ref $GrowableArray))
             (local $right-ga      (ref $GrowableArray))
             (local $left-sizes-ga  (ref $I32GrowableArray))
             (local $right-sizes-ga (ref $I32GrowableArray))
             (local $left-node     (ref $TreelistNode))
             (local $right-node    (ref $TreelistNode))
             (local $left-size     i32)
             (local $right-size    i32)
             (local $j             i32)
             (local $child-raw     (ref eq))
             (local $child-j-size  i32)
             (local $left-children  (ref $Array))
             (local $right-children (ref $Array))
             (local $left-sizes     (ref $I32Array))
             (local $right-sizes    (ref $I32Array))
             (local.set $children        (global.get $dummy-array))
             (local.set $split-values    (array.new_fixed $Values 4
                                                          (global.get $false)
                                                          (global.get $false)
                                                          (global.get $false)
                                                          (global.get $false)))
             (local.set $split-left-node  (global.get $dummy-treelist-node))
             (local.set $split-right-node (global.get $dummy-treelist-node))
             (local.set $left-ga        (call $make-growable-array (i32.const 4)))
             (local.set $right-ga       (call $make-growable-array (i32.const 4)))
             (local.set $left-sizes-ga  (call $make-i32growable-array (i32.const 4)))
             (local.set $right-sizes-ga (call $make-i32growable-array (i32.const 4)))
             (local.set $left-node      (global.get $dummy-treelist-node))
             (local.set $right-node     (global.get $dummy-treelist-node))
             (local.set $left-children  (global.get $dummy-array))
             (local.set $right-children (global.get $dummy-array))
             (local.set $left-sizes     (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $right-sizes    (array.new $I32Array (i32.const 0) (i32.const 0)))
             (if (i32.eqz (local.get $i))
                 (then
                  (return
                   (array.new_fixed $Values 4
                                    (global.get $dummy-treelist-node)
                                    (local.get $node)
                                    (ref.i31 (i32.const 0))
                                    (ref.i31 (i32.shl (local.get $node-size) (i32.const 1)))))))
             (if (i32.eq (local.get $i) (local.get $node-size))
                 (then
                  (return
                   (array.new_fixed $Values 4
                                    (local.get $node)
                                    (global.get $dummy-treelist-node)
                                    (ref.i31 (i32.shl (local.get $node-size) (i32.const 1)))
                                    (ref.i31 (i32.const 0))))))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (return
                   (array.new_fixed $Values 4
                                    (struct.new $TreelistNode
                                                (i32.const 0)
                                                (call $array-copy
                                                      (local.get $children)
                                                      (i32.const 0)
                                                      (local.get $i))
                                                (ref.null $I32Array))
                                    (struct.new $TreelistNode
                                                (i32.const 0)
                                                (call $array-copy
                                                      (local.get $children)
                                                      (local.get $i)
                                                      (local.get $node-size))
                                                (ref.null $I32Array))
                                    (ref.i31 (i32.shl (local.get $i) (i32.const 1)))
                                    (ref.i31 (i32.shl
                                              (i32.sub (local.get $node-size) (local.get $i))
                                              (i32.const 1)))))))
             (local.set $child-cap
                        (call $treelist-node-capacity
                              (i32.sub (local.get $height) (i32.const 1))))
             (if (call $treelist-node-leftwise-dense?/i32 (local.get $node))
                 (then
                  (local.set $child-index
                             (i32.div_u (local.get $i) (local.get $child-cap)))
                  (local.set $child-start
                             (i32.mul (local.get $child-index) (local.get $child-cap))))
                 (else
                  (local.set $child-index
                             (call $treelist-node-find-child-index/relaxed
                                   (ref.cast (ref $I32Array)
                                             (call $treelist-node-sizes (local.get $node)))
                                   (local.get $i)))
                  (local.set $child-start
                             (call $treelist-node-child-start
                                   (local.get $node)
                                   (local.get $node-size)
                                   (local.get $height)
                                   (local.get $child-index)))))
             (local.set $child-size
                        (call $treelist-node-child-size
                              (local.get $node)
                              (local.get $node-size)
                              (local.get $height)
                              (local.get $child-index)))
             (local.set $child-local
                        (i32.sub (local.get $i) (local.get $child-start)))
             (local.set $split-values
                        (call $treelist-node-split/checked
                              (ref.cast (ref $TreelistNode)
                                        (array.get $Array (local.get $children) (local.get $child-index)))
                              (local.get $child-size)
                              (i32.sub (local.get $height) (i32.const 1))
                              (local.get $child-local)))
             (local.set $split-left-raw  (array.get $Values (local.get $split-values) (i32.const 0)))
             (local.set $split-right-raw (array.get $Values (local.get $split-values) (i32.const 1)))
             (local.set $split-left-size
                        (i32.shr_u
                         (i31.get_u (ref.cast (ref i31)
                                              (array.get $Values (local.get $split-values) (i32.const 2))))
                         (i32.const 1)))
             (local.set $split-right-size
                        (i32.shr_u
                         (i31.get_u (ref.cast (ref i31)
                                              (array.get $Values (local.get $split-values) (i32.const 3))))
                         (i32.const 1)))
             (if (i32.gt_u (local.get $split-left-size) (i32.const 0))
                 (then
                  (local.set $split-left-node
                             (ref.cast (ref $TreelistNode) (local.get $split-left-raw)))))
             (if (i32.gt_u (local.get $split-right-size) (i32.const 0))
                 (then
                  (local.set $split-right-node
                             (ref.cast (ref $TreelistNode) (local.get $split-right-raw)))))
             (local.set $left-size (i32.const 0))
             (local.set $j (i32.const 0))
             (block $left-prefix-done
                    (loop $left-prefix-loop
                          (br_if $left-prefix-done
                                 (i32.ge_u (local.get $j) (local.get $child-index)))
                          (local.set $child-raw
                                     (array.get $Array (local.get $children) (local.get $j)))
                          (local.set $child-j-size
                                     (call $treelist-node-child-size
                                           (local.get $node)
                                           (local.get $node-size)
                                           (local.get $height)
                                           (local.get $j)))
                          (call $growable-array-add! (local.get $left-ga) (local.get $child-raw))
                          (call $i32growable-array-add! (local.get $left-sizes-ga) (local.get $child-j-size))
                          (local.set $left-size (i32.add (local.get $left-size) (local.get $child-j-size)))
                          (local.set $j (i32.add (local.get $j) (i32.const 1)))
                          (br $left-prefix-loop)))
             (if (i32.gt_u (local.get $split-left-size) (i32.const 0))
                 (then
                  (call $growable-array-add! (local.get $left-ga) (local.get $split-left-node))
                  (call $i32growable-array-add! (local.get $left-sizes-ga) (local.get $split-left-size))
                  (local.set $left-size
                             (i32.add (local.get $left-size) (local.get $split-left-size)))))
             (local.set $right-size (i32.const 0))
             (if (i32.gt_u (local.get $split-right-size) (i32.const 0))
                 (then
                  (call $growable-array-add! (local.get $right-ga) (local.get $split-right-node))
                  (call $i32growable-array-add! (local.get $right-sizes-ga) (local.get $split-right-size))
                  (local.set $right-size (local.get $split-right-size))))
             (local.set $j (i32.add (local.get $child-index) (i32.const 1)))
             (block $right-suffix-done
                    (loop $right-suffix-loop
                          (br_if $right-suffix-done
                                 (i32.ge_u (local.get $j) (local.get $child-count)))
                          (local.set $child-raw
                                     (array.get $Array (local.get $children) (local.get $j)))
                          (local.set $child-j-size
                                     (call $treelist-node-child-size
                                           (local.get $node)
                                           (local.get $node-size)
                                           (local.get $height)
                                           (local.get $j)))
                          (call $growable-array-add! (local.get $right-ga) (local.get $child-raw))
                          (call $i32growable-array-add! (local.get $right-sizes-ga) (local.get $child-j-size))
                          (local.set $right-size (i32.add (local.get $right-size) (local.get $child-j-size)))
                          (local.set $j (i32.add (local.get $j) (i32.const 1)))
                          (br $right-suffix-loop)))
             (if (i32.eqz (local.get $left-size))
                 (then
                  (local.set $left-node (global.get $dummy-treelist-node)))
                 (else
                  (local.set $left-children
                             (call $growable-array->array (local.get $left-ga)))
                  (local.set $left-sizes
                             (call $i32growable-array->array (local.get $left-sizes-ga)))
                  (local.set $left-node
                             (call $treelist-node-build/checked
                                   (local.get $left-children)
                                   (local.get $left-sizes)
                                   (local.get $height)))))
             (if (i32.eqz (local.get $right-size))
                 (then
                  (local.set $right-node (global.get $dummy-treelist-node)))
                 (else
                  (local.set $right-children
                             (call $growable-array->array (local.get $right-ga)))
                  (local.set $right-sizes
                             (call $i32growable-array->array (local.get $right-sizes-ga)))
                  (local.set $right-node
                             (call $treelist-node-build/checked
                                   (local.get $right-children)
                                   (local.get $right-sizes)
                                   (local.get $height)))))
             (array.new_fixed $Values 4
                              (local.get $left-node)
                              (local.get $right-node)
                              (ref.i31 (i32.shl (local.get $left-size) (i32.const 1)))
                              (ref.i31 (i32.shl (local.get $right-size) (i32.const 1)))))))


   ;; treelist-length/checked/i32 : (ref $Treelist) -> i32
   ;;   Return the element count of an already-checked treelist.
   (core-runtime-helper
    '$treelist-length/checked/i32
    "$treelist-length/checked/i32"
    (lambda ()
      `(func $treelist-length/checked/i32
             (param $tl (ref $Treelist))
             (result i32)
             (struct.get $Treelist $size (local.get $tl)))))


   ;; treelist-ref-node/checked : (ref $TreelistNode) i32 i32 -> (ref eq)
   ;;   Return the indexed value from a node, assuming the index is valid.
   (core-runtime-helper
    '$treelist-ref-node/checked
    "$treelist-ref-node/checked"
    (lambda ()
      `(func $treelist-ref-node/checked
             (param $node   (ref $TreelistNode))
             (param $index  i32)
             (param $height i32)
             (result (ref eq))
             (local $child-index i32)
             (local $child-start i32)
             (local $child-local i32)
             (local $child-raw (ref eq))
             (if (i32.eqz (local.get $height))
                 (then
                  (return
                   (array.get $Array
                              (call $treelist-node-children (local.get $node))
                              (local.get $index)))))
             (if (call $treelist-node-leftwise-dense?/i32 (local.get $node))
                 (then
                  (local.set $child-index
                             (call $treelist-radix (local.get $index) (local.get $height)))
                  (local.set $child-start
                             (call $treelist-node-child-start
                                   (local.get $node)
                                   (i32.const 0)
                                   (local.get $height)
                                   (local.get $child-index))))
                 (else
                  (local.set $child-index
                             (call $treelist-node-find-child-index/relaxed
                                   (ref.cast (ref $I32Array)
                                             (call $treelist-node-sizes (local.get $node)))
                                   (local.get $index)))
                  (local.set $child-start
                             (call $treelist-node-child-start
                                   (local.get $node)
                                   (i32.const 0)
                                   (local.get $height)
                                   (local.get $child-index)))))
             (local.set $child-local
                        (i32.sub (local.get $index) (local.get $child-start)))
             (local.set $child-raw
                        (array.get $Array
                                   (call $treelist-node-children (local.get $node))
                                   (local.get $child-index)))
             (call $treelist-ref-node/checked
                   (ref.cast (ref $TreelistNode) (local.get $child-raw))
                   (local.get $child-local)
                   (i32.sub (local.get $height) (i32.const 1))))))


   ;; treelist-ref/checked : (ref $Treelist) i32 -> (ref eq)
   ;;   Return the indexed value from a treelist after bounds checking.
   (core-runtime-helper
    '$treelist-ref/checked
    "$treelist-ref/checked"
    (lambda ()
      `(func $treelist-ref/checked
             (param $tl (ref $Treelist))
             (param $i i32)
             (result (ref eq))
             (local $len i32)
             (local.set $len (struct.get $Treelist $size (local.get $tl)))
             (if (result (ref eq))
                 (i32.lt_u (local.get $i) (local.get $len))
                 (then
                  (call $treelist-ref-node/checked
                        (struct.get $Treelist $root (local.get $tl))
                        (local.get $i)
                        (struct.get $Treelist $height (local.get $tl))))
                 (else
             (call $raise-bad-treelist-ref-index
                    (local.get $tl) (local.get $i) (local.get $len))
                  (unreachable))))))


   ;; treelist-node-set/checked : (ref $TreelistNode) i32 i32 (ref eq) -> (ref $TreelistNode)
   ;;   Path-copy a node and replace the indexed element.
   (core-runtime-helper
    '$treelist-node-set/checked
    "$treelist-node-set/checked"
    (lambda ()
      `(func $treelist-node-set/checked
             (param $node   (ref $TreelistNode))
             (param $index  i32)
             (param $height i32)
             (param $v      (ref eq))
             (result (ref $TreelistNode))
             (local $children    (ref $Array))
             (local $child-index i32)
             (local $child-start i32)
             (local $child-local i32)
             (local $child-raw   (ref eq))
             (local $child-new   (ref $TreelistNode))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (if (i32.eqz (local.get $height))
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (call $array-set/copy
                                     (local.get $children)
                                     (local.get $index)
                                     (local.get $v))
                               (call $treelist-node-sizes (local.get $node))))))
             (if (call $treelist-node-leftwise-dense?/i32 (local.get $node))
                 (then
                  (local.set $child-index
                             (call $treelist-radix (local.get $index) (local.get $height)))
                  (local.set $child-start
                             (call $treelist-node-child-start
                                   (local.get $node)
                                   (i32.const 0)
                                   (local.get $height)
                                   (local.get $child-index))))
                 (else
                  (local.set $child-index
                             (call $treelist-node-find-child-index/relaxed
                                   (ref.cast (ref $I32Array)
                                             (call $treelist-node-sizes (local.get $node)))
                                   (local.get $index)))
                  (local.set $child-start
                             (call $treelist-node-child-start
                                   (local.get $node)
                                   (i32.const 0)
                                   (local.get $height)
                                   (local.get $child-index)))))
             (local.set $child-local
                        (i32.sub (local.get $index) (local.get $child-start)))
             (local.set $child-raw
                        (array.get $Array
                                   (local.get $children)
                                   (local.get $child-index)))
             (local.set $child-new
                        (call $treelist-node-set/checked
                              (ref.cast (ref $TreelistNode) (local.get $child-raw))
                              (local.get $child-local)
                              (i32.sub (local.get $height) (i32.const 1))
                              (local.get $v)))
             (struct.new $TreelistNode
                         (i32.const 0)
                         (call $array-set/copy
                               (local.get $children)
                               (local.get $child-index)
                               (local.get $child-new))
                         (call $treelist-node-sizes (local.get $node))))))


   ;; treelist-node-can-add-right-fast?/i32 : (ref $TreelistNode) i32 i32 -> i32
   ;;   Check whether append-one can stay on the existing right spine.
   (core-runtime-helper
    '$treelist-node-can-add-right-fast?/i32
    "$treelist-node-can-add-right-fast?/i32"
    (lambda ()
      `(func $treelist-node-can-add-right-fast?/i32
             (param $node      (ref $TreelistNode))
             (param $node-size i32)
             (param $height    i32)
             (result i32)
             (local $children         (ref $Array))
             (local $child-count      i32)
             (local $child-capacity   i32)
             (local $last-child-index i32)
             (local $last-child-size  i32)
             (local $last-child-raw   (ref eq))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (return (i32.lt_u (local.get $child-count)
                                    (global.get $treelist:MAX_WIDTH)))))
             (local.set $child-capacity
                        (call $treelist-node-capacity
                              (i32.sub (local.get $height) (i32.const 1))))
             (local.set $last-child-index
                        (i32.sub (local.get $child-count) (i32.const 1)))
             (local.set $last-child-size
                        (call $treelist-node-child-size
                              (local.get $node)
                              (local.get $node-size)
                              (local.get $height)
                              (local.get $last-child-index)))
             (if (i32.lt_u (local.get $last-child-size) (local.get $child-capacity))
                 (then
                  (local.set $last-child-raw
                             (array.get $Array
                                        (local.get $children)
                                        (local.get $last-child-index)))
                  (return
                   (call $treelist-node-can-add-right-fast?/i32
                         (ref.cast (ref $TreelistNode) (local.get $last-child-raw))
                         (local.get $last-child-size)
                         (i32.sub (local.get $height) (i32.const 1))))))
             (i32.lt_u (local.get $child-count) (global.get $treelist:MAX_WIDTH)))))


   ;; treelist-node-can-add-left-fast?/i32 : (ref $TreelistNode) i32 i32 -> i32
   ;;   Check whether prepend-one can stay on the existing left spine.
   (core-runtime-helper
    '$treelist-node-can-add-left-fast?/i32
    "$treelist-node-can-add-left-fast?/i32"
    (lambda ()
      `(func $treelist-node-can-add-left-fast?/i32
             (param $node      (ref $TreelistNode))
             (param $node-size i32)
             (param $height    i32)
             (result i32)
             (local $children         (ref $Array))
             (local $child-count      i32)
             (local $child-capacity   i32)
             (local $first-child-size i32)
             (local $first-child-raw  (ref eq))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (return (i32.lt_u (local.get $child-count)
                                    (global.get $treelist:MAX_WIDTH)))))
             (local.set $child-capacity
                        (call $treelist-node-capacity
                              (i32.sub (local.get $height) (i32.const 1))))
             (local.set $first-child-size
                        (call $treelist-node-child-size
                              (local.get $node)
                              (local.get $node-size)
                              (local.get $height)
                              (i32.const 0)))
             (if (i32.lt_u (local.get $first-child-size) (local.get $child-capacity))
                 (then
                  (local.set $first-child-raw
                             (array.get $Array
                                        (local.get $children)
                                        (i32.const 0)))
                  (return
                   (call $treelist-node-can-add-left-fast?/i32
                         (ref.cast (ref $TreelistNode) (local.get $first-child-raw))
                         (local.get $first-child-size)
                         (i32.sub (local.get $height) (i32.const 1))))))
             (i32.lt_u (local.get $child-count) (global.get $treelist:MAX_WIDTH)))))


   ;; treelist-node-add-right/checked : (ref $TreelistNode) i32 i32 (ref eq) -> (ref $TreelistNode)
   ;;   Path-copy the right spine and append one value without reshaping the whole tree.
   (core-runtime-helper
    '$treelist-node-add-right/checked
    "$treelist-node-add-right/checked"
    (lambda ()
      `(func $treelist-node-add-right/checked
             (param $node      (ref $TreelistNode))
             (param $node-size i32)
             (param $height    i32)
             (param $v         (ref eq))
             (result (ref $TreelistNode))
             (local $children         (ref $Array))
             (local $sizes            (ref null $I32Array))
             (local $child-count      i32)
             (local $child-capacity   i32)
             (local $last-child-index i32)
             (local $last-child-size  i32)
             (local $last-child-raw   (ref eq))
             (local $last-child-new   (ref $TreelistNode))
             (local $children-new     (ref $Array))
             (local $sizes-new        (ref $I32Array))
             (local.set $children       (global.get $dummy-array))
             (local.set $last-child-new (global.get $dummy-treelist-node))
             (local.set $children-new   (global.get $dummy-array))
             (local.set $sizes-new      (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (local.set $sizes    (call $treelist-node-sizes (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (call $array-append
                                     (local.get $children)
                                     (array.new_fixed $Array 1 (local.get $v)))
                               (ref.null $I32Array)))))
             (local.set $child-capacity
                        (call $treelist-node-capacity
                              (i32.sub (local.get $height) (i32.const 1))))
             (local.set $last-child-index
                        (i32.sub (local.get $child-count) (i32.const 1)))
             (local.set $last-child-size
                        (call $treelist-node-child-size
                              (local.get $node)
                              (local.get $node-size)
                              (local.get $height)
                              (local.get $last-child-index)))
             (if (i32.lt_u (local.get $last-child-size) (local.get $child-capacity))
                 (then
                  (local.set $last-child-raw
                             (array.get $Array
                                        (local.get $children)
                                        (local.get $last-child-index)))
                  (local.set $last-child-new
                             (call $treelist-node-add-right/checked
                                   (ref.cast (ref $TreelistNode) (local.get $last-child-raw))
                                   (local.get $last-child-size)
                                   (i32.sub (local.get $height) (i32.const 1))
                                   (local.get $v)))
                  (local.set $children-new
                             (call $array-set/copy
                                   (local.get $children)
                                   (local.get $last-child-index)
                                   (local.get $last-child-new)))
                  (if (ref.is_null (local.get $sizes))
                      (then
                       (return
                        (struct.new $TreelistNode
                                    (i32.const 0)
                                    (local.get $children-new)
                                    (ref.null $I32Array)))))
                  (local.set $sizes-new
                             (call $i32array-set/copy
                                   (ref.cast (ref $I32Array) (local.get $sizes))
                                   (local.get $last-child-index)
                                   (i32.add (local.get $node-size) (i32.const 1))))
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (local.get $children-new)
                               (local.get $sizes-new)))))
             (local.set $children-new
                        (call $array-append
                              (local.get $children)
                              (array.new_fixed $Array
                                               1
                                               (call $treelist-singleton-branch
                                                     (i32.sub (local.get $height) (i32.const 1))
                                                     (local.get $v)))))
             (if (ref.is_null (local.get $sizes))
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (local.get $children-new)
                               (ref.null $I32Array)))))
             (local.set $sizes-new
                        (call $i32array-append
                              (ref.cast (ref $I32Array) (local.get $sizes))
                              (array.new_fixed $I32Array 1 (i32.add (local.get $node-size)
                                                                    (i32.const 1)))))
             (struct.new $TreelistNode
                         (i32.const 0)
                         (local.get $children-new)
                         (local.get $sizes-new)))))


   ;; treelist-node-add-left/checked : (ref $TreelistNode) i32 i32 (ref eq) -> (ref $TreelistNode)
   ;;   Path-copy the left spine and prepend one value without reshaping the whole tree.
   (core-runtime-helper
    '$treelist-node-add-left/checked
    "$treelist-node-add-left/checked"
    (lambda ()
      `(func $treelist-node-add-left/checked
             (param $node      (ref $TreelistNode))
             (param $node-size i32)
             (param $height    i32)
             (param $v         (ref eq))
             (result (ref $TreelistNode))
             (local $children         (ref $Array))
             (local $child-sizes      (ref $I32Array))
             (local $child-capacity   i32)
             (local $first-child-size i32)
             (local $first-child-raw  (ref eq))
             (local $first-child-new  (ref $TreelistNode))
             (local $children-new     (ref $Array))
             (local $sizes-new        (ref $I32Array))
             (local $new-child        (ref $TreelistNode))
             (local.set $children        (global.get $dummy-array))
             (local.set $child-sizes     (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $first-child-new (global.get $dummy-treelist-node))
             (local.set $children-new    (global.get $dummy-array))
             (local.set $sizes-new       (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $new-child       (global.get $dummy-treelist-node))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (if (i32.eqz (local.get $height))
                 (then
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (call $array-append
                                     (array.new_fixed $Array 1 (local.get $v))
                                     (local.get $children))
                               (ref.null $I32Array)))))
             (local.set $child-sizes
                        (call $treelist-node-child-sizes/exact
                              (local.get $node)
                              (local.get $node-size)
                              (local.get $height)))
             (local.set $child-capacity
                        (call $treelist-node-capacity
                              (i32.sub (local.get $height) (i32.const 1))))
             (local.set $first-child-size
                        (array.get $I32Array (local.get $child-sizes) (i32.const 0)))
             (if (i32.lt_u (local.get $first-child-size) (local.get $child-capacity))
                 (then
                  (local.set $first-child-raw
                             (array.get $Array
                                        (local.get $children)
                                        (i32.const 0)))
                  (local.set $first-child-new
                             (call $treelist-node-add-left/checked
                                   (ref.cast (ref $TreelistNode) (local.get $first-child-raw))
                                   (local.get $first-child-size)
                                   (i32.sub (local.get $height) (i32.const 1))
                                   (local.get $v)))
                  (local.set $children-new
                             (call $array-set/copy
                                   (local.get $children)
                                   (i32.const 0)
                                   (local.get $first-child-new)))
                  (local.set $sizes-new
                             (call $i32array-set/copy
                                   (local.get $child-sizes)
                                   (i32.const 0)
                                   (i32.add (local.get $first-child-size) (i32.const 1))))
                  (return
                   (call $treelist-node-build/checked
                         (local.get $children-new)
                         (local.get $sizes-new)
                         (local.get $height)))))
             (local.set $new-child
                        (call $treelist-singleton-branch
                              (i32.sub (local.get $height) (i32.const 1))
                              (local.get $v)))
             (local.set $children-new
                        (call $array-append
                              (array.new_fixed $Array 1 (local.get $new-child))
                              (local.get $children)))
             (local.set $sizes-new
                        (call $i32array-append
                              (array.new_fixed $I32Array 1 (i32.const 1))
                              (local.get $child-sizes)))
             (call $treelist-node-build/checked
                   (local.get $children-new)
                   (local.get $sizes-new)
                   (local.get $height)))))


   ;; treelist-set/checked : (ref $Treelist) i32 (ref eq) -> (ref $Treelist)
   ;;   Return a treelist with the indexed value replaced.
   (core-runtime-helper
    '$treelist-set/checked
    "$treelist-set/checked"
    (lambda ()
      `(func $treelist-set/checked
             (param $tl (ref $Treelist))
             (param $i  i32)
             (param $v  (ref eq))
             (result (ref $Treelist))
             (local $len i32)
             (local $root (ref $TreelistNode))
             (local.set $len (struct.get $Treelist $size (local.get $tl)))
             (if (i32.eqz (i32.lt_u (local.get $i) (local.get $len)))
                 (then
                  (call $raise-bad-treelist-set-index
                        (local.get $tl) (local.get $i) (local.get $len))
                  (unreachable)))
             (local.set $root
                        (call $treelist-node-set/checked
                              (struct.get $Treelist $root (local.get $tl))
                              (local.get $i)
                              (struct.get $Treelist $height (local.get $tl))
                              (local.get $v)))
             (struct.new $Treelist
                         (i32.const 0)
                         (local.get $root)
                         (local.get $len)
                         (struct.get $Treelist $height (local.get $tl))))))


   ;; treelist-add/checked : (ref $Treelist) (ref eq) -> (ref $Treelist)
   ;;   Return a treelist with v appended on the right.
   (core-runtime-helper
    '$treelist-add/checked
    "$treelist-add/checked"
    (lambda ()
      `(func $treelist-add/checked
             (param $tl (ref $Treelist))
             (param $v  (ref eq))
             (result (ref $Treelist))
             (local $size i32)
             (local $height i32)
             (local $root (ref $TreelistNode))
             (local $capacity i32)
             (local $new-root (ref $TreelistNode))
             (local $can-fast-add i32)
             (local.set $root     (global.get $dummy-treelist-node))
             (local.set $new-root (global.get $dummy-treelist-node))
             (local.set $can-fast-add (i32.const 0))
             (local.set $size (struct.get $Treelist $size (local.get $tl)))
             (local.set $height (struct.get $Treelist $height (local.get $tl)))
             (local.set $root   (struct.get $Treelist $root (local.get $tl)))
             (local.set $capacity (call $treelist-node-capacity (local.get $height)))
             (if (i32.eqz (local.get $size))
                 (then
                  (return
                   (struct.new $Treelist
                               (i32.const 0)
                               (call $treelist-leaf (local.get $v))
                               (i32.const 1)
                               (i32.const 0)))))
             (if (i32.eq (local.get $size) (local.get $capacity))
                 (then
                  (local.set $new-root
                             (struct.new $TreelistNode
                                         (i32.const 0)
                                         (array.new_fixed $Array
                                                          2
                                                          (local.get $root)
                                                          (call $treelist-singleton-branch
                                                                (local.get $height)
                                                                (local.get $v)))
                                         (ref.null $I32Array)))
                  (return
                   (struct.new $Treelist
                               (i32.const 0)
                               (local.get $new-root)
                               (i32.add (local.get $size) (i32.const 1))
                               (i32.add (local.get $height) (i32.const 1))))))
             (local.set $can-fast-add
                        (call $treelist-node-can-add-right-fast?/i32
                              (local.get $root)
                              (local.get $size)
                              (local.get $height)))
             (if (i32.eqz (local.get $can-fast-add))
                 (then
                  (return
                   (call $treelist-append2/checked
                         (local.get $tl)
                         (struct.new $Treelist
                                     (i32.const 0)
                                     (call $treelist-leaf (local.get $v))
                                     (i32.const 1)
                                     (i32.const 0))))))
             (struct.new $Treelist
                         (i32.const 0)
                         (call $treelist-node-add-right/checked
                               (local.get $root)
                               (local.get $size)
                               (local.get $height)
                               (local.get $v))
                         (i32.add (local.get $size) (i32.const 1))
                         (local.get $height)))))


   ;; treelist-slice/checked : (ref $Treelist) i32 i32 -> (ref $Treelist)
   ;;   Return the selected half-open range using structural splits.
   (core-runtime-helper
    '$treelist-slice/checked
    "$treelist-slice/checked"
    (lambda ()
      `(func $treelist-slice/checked
             (param $tl    (ref $Treelist))
             (param $start i32)
             (param $end   i32)
             (result (ref $Treelist))
             (local $split1 (ref $Values))
             (local $split2 (ref $Values))
             (local $mid    (ref $Treelist))
             (if (i32.eq (local.get $start) (i32.const 0))
                 (then
                  (if (i32.eq (local.get $end) (struct.get $Treelist $size (local.get $tl)))
                      (then (return (local.get $tl))))
                  (local.set $split1
                             (call $treelist-split-at/checked
                                   (local.get $tl)
                                   (local.get $end)))
                  (return
                   (ref.cast (ref $Treelist)
                             (array.get $Values (local.get $split1) (i32.const 0))))))
             (if (i32.eq (local.get $start) (local.get $end))
                 (then (return (global.get $empty-treelist))))
             (local.set $split1
                        (call $treelist-split-at/checked
                              (local.get $tl)
                              (local.get $start)))
             (local.set $mid
                        (ref.cast (ref $Treelist)
                                  (array.get $Values (local.get $split1) (i32.const 1))))
             (if (i32.eq (local.get $end) (struct.get $Treelist $size (local.get $tl)))
                 (then (return (local.get $mid))))
             (local.set $split2
                        (call $treelist-split-at/checked
                              (local.get $mid)
                              (i32.sub (local.get $end) (local.get $start))))
             (ref.cast (ref $Treelist)
                       (array.get $Values (local.get $split2) (i32.const 0))))))


   ;; treelist-sublist/checked : (ref $Treelist) i32 i32 -> (ref $Treelist)
   ;;   Return the half-open range [start,end) after validating bounds.
   (core-runtime-helper
    '$treelist-sublist/checked
    "$treelist-sublist/checked"
    (lambda ()
      `(func $treelist-sublist/checked
             (param $tl    (ref $Treelist))
             (param $start i32)
             (param $end   i32)
             (result (ref $Treelist))
             (local $len i32)
             (local.set $len (struct.get $Treelist $size (local.get $tl)))
             (if (i32.or
                  (i32.gt_u (local.get $start) (local.get $end))
                  (i32.gt_u (local.get $end) (local.get $len)))
                 (then
                  (call $raise-bad-treelist-split-index
                        (global.get $symbol:treelist-sublist)
                        (local.get $tl) (local.get $end) (local.get $len))
                  (unreachable)))
             (call $treelist-slice/checked
                   (local.get $tl)
                   (local.get $start)
                   (local.get $end)))))


   ;; treelist-split-at/checked : (ref $Treelist) i32 -> (ref $Values)
   ;;   Return two treelists split at i.
   (core-runtime-helper
    '$treelist-split-at/checked
    "$treelist-split-at/checked"
    (lambda ()
      `(func $treelist-split-at/checked
             (param $tl (ref $Treelist))
             (param $i  i32)
             (result (ref $Values))
             (local $len i32)
             (local $split-values (ref $Values))
             (local $left-size    i32)
             (local $right-size   i32)
             (local.set $len (struct.get $Treelist $size (local.get $tl)))
             (if (i32.gt_u (local.get $i) (local.get $len))
                 (then
                  (call $raise-bad-treelist-split-index
                        (global.get $symbol:treelist-split-at)
                        (local.get $tl) (local.get $i) (local.get $len))
                  (unreachable)))
             (if (i32.eqz (local.get $i))
                 (then
                  (return
                   (array.new_fixed $Values 2
                                    (global.get $empty-treelist)
                                    (local.get $tl)))))
             (if (i32.eq (local.get $i) (local.get $len))
                 (then
                  (return
                   (array.new_fixed $Values 2
                                    (local.get $tl)
                                    (global.get $empty-treelist)))))
             (local.set $split-values
                        (call $treelist-node-split/checked
                              (struct.get $Treelist $root (local.get $tl))
                              (local.get $len)
                              (struct.get $Treelist $height (local.get $tl))
                              (local.get $i)))
             (local.set $left-size
                        (i32.shr_u
                         (i31.get_u (ref.cast (ref i31)
                                              (array.get $Values (local.get $split-values) (i32.const 2))))
                         (i32.const 1)))
             (local.set $right-size
                        (i32.shr_u
                         (i31.get_u (ref.cast (ref i31)
                                              (array.get $Values (local.get $split-values) (i32.const 3))))
                         (i32.const 1)))
             (array.new_fixed $Values 2
                              (call $treelist-from-node/checked
                                    (ref.cast (ref $TreelistNode)
                                              (array.get $Values (local.get $split-values) (i32.const 0)))
                                    (local.get $left-size)
                                    (struct.get $Treelist $height (local.get $tl)))
                              (call $treelist-from-node/checked
                                    (ref.cast (ref $TreelistNode)
                                              (array.get $Values (local.get $split-values) (i32.const 1)))
                                    (local.get $right-size)
                                    (struct.get $Treelist $height (local.get $tl)))))))


   ;; treelist-node-reverse/checked : (ref $TreelistNode) i32 i32 -> (ref $TreelistNode)
   ;;   Reverse a treelist node structurally.
   (core-runtime-helper
    '$treelist-node-reverse/checked
    "$treelist-node-reverse/checked"
    (lambda ()
      `(func $treelist-node-reverse/checked
             (param $node      (ref $TreelistNode))
             (param $node-size i32)
             (param $height    i32)
             (result (ref $TreelistNode))
             (local $children     (ref $Array))
             (local $child-count  i32)
             (local $children-new (ref $Array))
             (local $child-sizes  (ref $I32Array))
             (local $i            i32)
             (local $src-index    i32)
             (local $child-size   i32)
             (local $child-raw    (ref eq))
             (local $child-new    (ref $TreelistNode))
             (local.set $children     (global.get $dummy-array))
             (local.set $children-new (global.get $dummy-array))
             (local.set $child-sizes  (array.new $I32Array (i32.const 0) (i32.const 0)))
             (local.set $child-new    (global.get $dummy-treelist-node))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (local.set $children-new
                             (call $make-array (local.get $child-count) (global.get $false)))
                  (local.set $i (i32.const 0))
                  (block $leaf-done
                         (loop $leaf-loop
                               (br_if $leaf-done
                                      (i32.ge_u (local.get $i) (local.get $child-count)))
                               (array.set $Array
                                          (local.get $children-new)
                                          (local.get $i)
                                          (array.get $Array
                                                     (local.get $children)
                                                     (i32.sub
                                                      (i32.sub (local.get $child-count) (i32.const 1))
                                                      (local.get $i))))
                               (local.set $i (i32.add (local.get $i) (i32.const 1)))
                               (br $leaf-loop)))
                  (return
                   (struct.new $TreelistNode
                               (i32.const 0)
                               (local.get $children-new)
                               (ref.null $I32Array)))))
             (local.set $children-new
                        (call $make-array (local.get $child-count) (global.get $false)))
             (local.set $child-sizes
                        (array.new $I32Array (i32.const 0) (local.get $child-count)))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $child-count)))
                          (local.set $src-index
                                     (i32.sub
                                      (i32.sub (local.get $child-count) (i32.const 1))
                                      (local.get $i)))
                          (local.set $child-size
                                     (call $treelist-node-child-size
                                           (local.get $node)
                                           (local.get $node-size)
                                           (local.get $height)
                                           (local.get $src-index)))
                          (local.set $child-raw
                                     (array.get $Array
                                                (local.get $children)
                                                (local.get $src-index)))
                          (local.set $child-new
                                     (call $treelist-node-reverse/checked
                                           (ref.cast (ref $TreelistNode) (local.get $child-raw))
                                           (local.get $child-size)
                                           (i32.sub (local.get $height) (i32.const 1))))
                          (array.set $Array
                                     (local.get $children-new)
                                     (local.get $i)
                                     (local.get $child-new))
                          (array.set $I32Array
                                     (local.get $child-sizes)
                                     (local.get $i)
                                     (local.get $child-size))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (call $treelist-node-build/checked
                   (local.get $children-new)
                   (local.get $child-sizes)
                   (local.get $height)))))


   ;; treelist-reverse/checked : (ref $Treelist) -> (ref $Treelist)
   ;;   Reverse a treelist structurally by recursively reversing its nodes.
   (core-runtime-helper
    '$treelist-reverse/checked
    "$treelist-reverse/checked"
    (lambda ()
      `(func $treelist-reverse/checked
             (param $tl (ref $Treelist))
             (result (ref $Treelist))
             (local $len i32)
             (local $root (ref $TreelistNode))
             (local $height i32)
             (local.set $len (struct.get $Treelist $size (local.get $tl)))
             (if (i32.eqz (local.get $len))
                 (then (return (global.get $empty-treelist))))
             (local.set $height (struct.get $Treelist $height (local.get $tl)))
             (local.set $root
                        (call $treelist-node-reverse/checked
                              (struct.get $Treelist $root (local.get $tl))
                              (local.get $len)
                              (local.get $height)))
             (call $treelist-from-node/checked
                   (local.get $root)
                   (local.get $len)
                   (local.get $height)))))


   ;; treelist-node-size/check : (ref $TreelistNode) i32 -> i32
   ;;   Compute the element count for node, or return 0 if the subtree is invalid.
   (core-runtime-helper
    '$treelist-node-size/check
    "$treelist-node-size/check"
    (lambda ()
      `(func $treelist-node-size/check
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (result i32)
             (local $children    (ref $Array))
             (local $sizes/null  (ref null $I32Array))
             (local $sizes       (ref $I32Array))
             (local $child-count i32)
             (local $child-cap   i32)
             (local $i           i32)
             (local $sum         i32)
             (local $prev        i32)
             (local $cum         i32)
             (local $exact       i32)
             (local $child-raw   (ref eq))
             (local $child-node  (ref $TreelistNode))
             (local $child-size  i32)
             (local.set $children   (call $treelist-node-children (local.get $node)))
             (local.set $sizes/null (call $treelist-node-sizes (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (if (i32.eqz (local.get $child-count))
                 (then (return (i32.const 0))))
             (if (i32.gt_u (local.get $child-count) (global.get $treelist:MAX_WIDTH))
                 (then (return (i32.const 0))))
             (if (i32.eqz (local.get $height))
                 (then
                  (if (ref.is_null (local.get $sizes/null))
                      (then (return (local.get $child-count))))
                  (local.set $sizes (ref.cast (ref $I32Array) (local.get $sizes/null)))
                  (if (i32.ne (array.len (local.get $sizes)) (local.get $child-count))
                      (then (return (i32.const 0))))
                  (local.set $prev (i32.const 0))
                  (local.set $i    (i32.const 0))
                  (block $leaf-done
                         (loop $leaf-loop
                               (br_if $leaf-done
                                      (i32.ge_u (local.get $i) (local.get $child-count)))
                               (local.set $cum
                                          (array.get $I32Array
                                                     (local.get $sizes)
                                                     (local.get $i)))
                               (if (i32.le_u (local.get $cum) (local.get $prev))
                                   (then (return (i32.const 0))))
                               (if (i32.ne (i32.sub (local.get $cum) (local.get $prev))
                                           (i32.const 1))
                                   (then (return (i32.const 0))))
                               (local.set $prev (local.get $cum))
                               (local.set $i (i32.add (local.get $i) (i32.const 1)))
                               (br $leaf-loop)))
                  (return (local.get $prev))))
             (local.set $child-cap
                        (call $treelist-node-capacity
                              (i32.sub (local.get $height) (i32.const 1))))
             (if (ref.is_null (local.get $sizes/null))
                 (then
                  (local.set $sum (i32.const 0))
                  (local.set $i   (i32.const 0))
                  (block $dense-done
                         (loop $dense-loop
                               (br_if $dense-done
                                      (i32.ge_u (local.get $i) (local.get $child-count)))
                               (local.set $child-raw
                                          (array.get $Array
                                                     (local.get $children)
                                                     (local.get $i)))
                               (if (i32.eqz (ref.test (ref $TreelistNode) (local.get $child-raw)))
                                   (then (return (i32.const 0))))
                               (local.set $child-node
                                          (ref.cast (ref $TreelistNode) (local.get $child-raw)))
                               (if (i32.eqz
                                    (call $treelist-node-leftwise-dense?/i32
                                          (local.get $child-node)))
                                   (then (return (i32.const 0))))
                               (local.set $child-size
                                          (call $treelist-node-size/check
                                                (local.get $child-node)
                                                (i32.sub (local.get $height)
                                                         (i32.const 1))))
                               (if (i32.eqz (local.get $child-size))
                                   (then (return (i32.const 0))))
                               (if (i32.lt_u (local.get $i)
                                             (i32.sub (local.get $child-count)
                                                      (i32.const 1)))
                                   (then
                                    (if (i32.ne (local.get $child-size)
                                                (local.get $child-cap))
                                        (then (return (i32.const 0)))))
                                   (else
                                    (if (i32.gt_u (local.get $child-size)
                                                  (local.get $child-cap))
                                        (then (return (i32.const 0))))))
                               (local.set $sum
                                          (i32.add (local.get $sum) (local.get $child-size)))
                               (local.set $i (i32.add (local.get $i) (i32.const 1)))
                               (br $dense-loop)))
                  (return (local.get $sum))))
             (local.set $sizes (ref.cast (ref $I32Array) (local.get $sizes/null)))
             (if (i32.ne (array.len (local.get $sizes)) (local.get $child-count))
                 (then (return (i32.const 0))))
             (local.set $prev (i32.const 0))
             (local.set $i    (i32.const 0))
             (block $relaxed-done
                    (loop $relaxed-loop
                          (br_if $relaxed-done
                                 (i32.ge_u (local.get $i) (local.get $child-count)))
                          (local.set $cum
                                     (array.get $I32Array
                                                (local.get $sizes)
                                                (local.get $i)))
                          (if (i32.le_u (local.get $cum) (local.get $prev))
                              (then (return (i32.const 0))))
                          (local.set $exact
                                     (i32.sub (local.get $cum) (local.get $prev)))
                          (local.set $child-raw
                                     (array.get $Array
                                                (local.get $children)
                                                (local.get $i)))
                          (if (i32.eqz (ref.test (ref $TreelistNode) (local.get $child-raw)))
                              (then (return (i32.const 0))))
                          (local.set $child-node
                                     (ref.cast (ref $TreelistNode) (local.get $child-raw)))
                          (local.set $child-size
                                     (call $treelist-node-size/check
                                           (local.get $child-node)
                                           (i32.sub (local.get $height) (i32.const 1))))
                          (if (i32.eqz (local.get $child-size))
                              (then (return (i32.const 0))))
                          (if (i32.ne (local.get $child-size) (local.get $exact))
                              (then (return (i32.const 0))))
                          (local.set $prev (local.get $cum))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $relaxed-loop)))
             (local.get $prev))))


   ;; treelist-node-valid?/i32 : (ref $TreelistNode) i32 i32 -> i32
   ;;   Check whether node is structurally valid at height with expected-size.
   (core-runtime-helper
    '$treelist-node-valid?/i32
    "$treelist-node-valid?/i32"
    (lambda ()
      `(func $treelist-node-valid?/i32
             (param $node          (ref $TreelistNode))
             (param $height        i32)
             (param $expected-size i32)
             (result i32)
             (local $actual-size i32)
             (local.set $actual-size
                        (call $treelist-node-size/check
                              (local.get $node)
                              (local.get $height)))
             (if (i32.eqz (local.get $actual-size))
                 (then (return (i32.const 0))))
             (if (i32.ne (local.get $actual-size) (local.get $expected-size))
                 (then (return (i32.const 0))))
             (i32.const 1))))


   ;; treelist-valid?/i32 : treelist? -> i32
   ;;   Check whether tl satisfies the current treelist shape invariants.
   (core-runtime-helper
    '$treelist-valid?/i32
    "$treelist-valid?/i32"
    (lambda ()
      `(func $treelist-valid?/i32
             (param $tl (ref $Treelist))
             (result i32)
             (local $size   i32)
             (local $height i32)
             (local $root   (ref $TreelistNode))
             (local.set $size   (struct.get $Treelist $size (local.get $tl)))
             (local.set $height (struct.get $Treelist $height (local.get $tl)))
             (local.set $root   (struct.get $Treelist $root (local.get $tl)))
             (if (i32.eqz (local.get $size))
                 (then
                  (if (i32.eqz (ref.eq (local.get $root) (global.get $dummy-treelist-node)))
                      (then (return (i32.const 0))))
                  (return
                   (if (result i32)
                       (i32.eqz (local.get $height))
                       (then (i32.const 1))
                       (else (i32.const 0))))))
             (if (ref.eq (local.get $root) (global.get $dummy-treelist-node))
                 (then (return (i32.const 0))))
             (call $treelist-node-valid?/i32
                   (local.get $root)
                   (local.get $height)
                   (local.get $size)))))


   ;; treelist-node-count/checked : (ref $TreelistNode) i32 -> i32
   ;;   Count nodes in the subtree rooted at node.
   (core-runtime-helper
    '$treelist-node-count/checked
    "$treelist-node-count/checked"
    (lambda ()
      `(func $treelist-node-count/checked
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (result i32)
             (local $children    (ref $Array))
             (local $child-count i32)
             (local $i           i32)
             (local $sum         i32)
             (local $child-raw   (ref eq))
             (local.set $children    (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (local.set $sum         (i32.const 1))
             (if (i32.eqz (local.get $height))
                 (then (return (local.get $sum))))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $child-count)))
                          (local.set $child-raw
                                     (array.get $Array (local.get $children) (local.get $i)))
                          (local.set $sum
                                     (i32.add
                                      (local.get $sum)
                                      (call $treelist-node-count/checked
                                            (ref.cast (ref $TreelistNode) (local.get $child-raw))
                                            (i32.sub (local.get $height) (i32.const 1)))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $sum))))


   ;; treelist-node-relaxed-count/checked : (ref $TreelistNode) i32 -> i32
   ;;   Count relaxed nodes in the subtree rooted at node.
   (core-runtime-helper
    '$treelist-node-relaxed-count/checked
    "$treelist-node-relaxed-count/checked"
    (lambda ()
      `(func $treelist-node-relaxed-count/checked
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (result i32)
             (local $children    (ref $Array))
             (local $child-count i32)
             (local $i           i32)
             (local $sum         i32)
             (local $child-raw   (ref eq))
             (local.set $children    (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (local.set $sum
                        (if (result i32)
                            (ref.is_null (call $treelist-node-sizes (local.get $node)))
                            (then (i32.const 0))
                            (else (i32.const 1))))
             (if (i32.eqz (local.get $height))
                 (then (return (local.get $sum))))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $child-count)))
                          (local.set $child-raw
                                     (array.get $Array (local.get $children) (local.get $i)))
                          (local.set $sum
                                     (i32.add
                                      (local.get $sum)
                                      (call $treelist-node-relaxed-count/checked
                                            (ref.cast (ref $TreelistNode) (local.get $child-raw))
                                            (i32.sub (local.get $height) (i32.const 1)))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $sum))))


   ;; treelist-node-max-child-count/checked : (ref $TreelistNode) i32 -> i32
   ;;   Compute the maximum child count in the subtree rooted at node.
   (core-runtime-helper
    '$treelist-node-max-child-count/checked
    "$treelist-node-max-child-count/checked"
    (lambda ()
      `(func $treelist-node-max-child-count/checked
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (result i32)
             (local $children    (ref $Array))
             (local $child-count i32)
             (local $i           i32)
             (local $best        i32)
             (local $child-best  i32)
             (local $child-raw   (ref eq))
             (local.set $children    (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (local.set $best        (local.get $child-count))
             (if (i32.eqz (local.get $height))
                 (then (return (local.get $best))))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $child-count)))
                          (local.set $child-raw
                                     (array.get $Array (local.get $children) (local.get $i)))
                          (local.set $child-best
                                     (call $treelist-node-max-child-count/checked
                                           (ref.cast (ref $TreelistNode) (local.get $child-raw))
                                           (i32.sub (local.get $height) (i32.const 1))))
                          (if (i32.gt_u (local.get $child-best) (local.get $best))
                              (then (local.set $best (local.get $child-best))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $best))))


   ;; treelist-node-unary-start-depth/checked : (ref $TreelistNode) i32 -> i32
   ;;   Compute the unary-chain depth starting at node.
   (core-runtime-helper
    '$treelist-node-unary-start-depth/checked
    "$treelist-node-unary-start-depth/checked"
    (lambda ()
      `(func $treelist-node-unary-start-depth/checked
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (result i32)
             (local $child-raw (ref eq))
             (if (i32.eqz (local.get $height))
                 (then (return (i32.const 0))))
             (if (i32.ne (call $treelist-node-child-count (local.get $node)) (i32.const 1))
                 (then (return (i32.const 0))))
             (local.set $child-raw
                        (array.get $Array
                                   (call $treelist-node-children (local.get $node))
                                   (i32.const 0)))
             (i32.add
              (i32.const 1)
              (call $treelist-node-unary-start-depth/checked
                    (ref.cast (ref $TreelistNode) (local.get $child-raw))
                    (i32.sub (local.get $height) (i32.const 1)))))))


   ;; treelist-node-max-unary-depth/checked : (ref $TreelistNode) i32 -> i32
   ;;   Compute the maximum unary-chain depth anywhere in the subtree rooted at node.
   (core-runtime-helper
    '$treelist-node-max-unary-depth/checked
    "$treelist-node-max-unary-depth/checked"
    (lambda ()
      `(func $treelist-node-max-unary-depth/checked
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (result i32)
             (local $children    (ref $Array))
             (local $child-count i32)
             (local $i           i32)
             (local $best        i32)
             (local $child-best  i32)
             (local $child-raw   (ref eq))
             (local.set $best (call $treelist-node-unary-start-depth/checked
                                    (local.get $node)
                                    (local.get $height)))
             (if (i32.eqz (local.get $height))
                 (then (return (local.get $best))))
             (local.set $children    (call $treelist-node-children (local.get $node)))
             (local.set $child-count (array.len (local.get $children)))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $child-count)))
                          (local.set $child-raw
                                     (array.get $Array (local.get $children) (local.get $i)))
                          (local.set $child-best
                                     (call $treelist-node-max-unary-depth/checked
                                           (ref.cast (ref $TreelistNode) (local.get $child-raw))
                                           (i32.sub (local.get $height) (i32.const 1))))
                          (if (i32.gt_u (local.get $child-best) (local.get $best))
                              (then (local.set $best (local.get $child-best))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $best))))


   ;; treelist-debug-shape : treelist? -> list?
   ;;   Private internal diagnostic helper kept out of normal language bindings.
   (core-runtime-helper
    '$treelist-debug-shape
    "$treelist-debug-shape"
    (lambda ()
      `(func $treelist-debug-shape (type $Prim1)
             (param $v0 (ref eq))
             (result (ref eq))
             (local $tl              (ref $Treelist))
             (local $valid           i32)
             (local $size            i32)
             (local $height          i32)
             (local $node-count      i32)
             (local $relaxed-count   i32)
             (local $max-unary-depth i32)
             (local $max-child-count i32)
             (local $xs              (ref eq))
             (local.set $tl (global.get $empty-treelist))
             (local.set $xs (global.get $null))
             (if (ref.test (ref $Treelist) (local.get $v0))
                 (then (local.set $tl (ref.cast (ref $Treelist) (local.get $v0))))
                 (else (call $raise-check-treelist/who
                             ;; Reuse an existing private symbol global; this helper
                             ;; is not a normal language binding.
                             (global.get $symbol:treelist-ref)
                             (local.get $v0))
                       (unreachable)))
             (local.set $valid  (call $treelist-valid?/i32 (local.get $tl)))
             (local.set $size   (struct.get $Treelist $size (local.get $tl)))
             (local.set $height (struct.get $Treelist $height (local.get $tl)))
             (if (i32.eqz (local.get $size))
                 (then
                  (local.set $node-count      (i32.const 0))
                  (local.set $relaxed-count   (i32.const 0))
                  (local.set $max-unary-depth (i32.const 0))
                  (local.set $max-child-count (i32.const 0)))
                 (else
                  (local.set $node-count
                             (call $treelist-node-count/checked
                                   (struct.get $Treelist $root (local.get $tl))
                                   (local.get $height)))
                  (local.set $relaxed-count
                             (call $treelist-node-relaxed-count/checked
                                   (struct.get $Treelist $root (local.get $tl))
                                   (local.get $height)))
                  (local.set $max-unary-depth
                             (call $treelist-node-max-unary-depth/checked
                                   (struct.get $Treelist $root (local.get $tl))
                                   (local.get $height)))
                  (local.set $max-child-count
                             (call $treelist-node-max-child-count/checked
                                   (struct.get $Treelist $root (local.get $tl))
                                   (local.get $height)))))
             (local.set $xs
                        (struct.new $Pair
                                    (i32.const 0)
                                    (ref.i31 (i32.shl (local.get $max-child-count) (i32.const 1)))
                                    (local.get $xs)))
             (local.set $xs
                        (struct.new $Pair
                                    (i32.const 0)
                                    (ref.i31 (i32.shl (local.get $valid) (i32.const 1)))
                                    (local.get $xs)))
             (local.set $xs
                        (struct.new $Pair
                                    (i32.const 0)
                                    (ref.i31 (i32.shl (local.get $max-unary-depth) (i32.const 1)))
                                    (local.get $xs)))
             (local.set $xs
                        (struct.new $Pair
                                    (i32.const 0)
                                    (ref.i31 (i32.shl (local.get $relaxed-count) (i32.const 1)))
                                    (local.get $xs)))
             (local.set $xs
                        (struct.new $Pair
                                    (i32.const 0)
                                    (ref.i31 (i32.shl (local.get $node-count) (i32.const 1)))
                                    (local.get $xs)))
             (local.set $xs
                        (struct.new $Pair
                                    (i32.const 0)
                                    (ref.i31 (i32.shl (local.get $height) (i32.const 1)))
                                    (local.get $xs)))
             (struct.new $Pair
                         (i32.const 0)
                         (ref.i31 (i32.shl (local.get $size) (i32.const 1)))
                         (local.get $xs)))))


   ;; treelist-node-append*-collect-into! : (ref $TreelistNode) i32 (ref $Array) i32 -> i32
   ;;   Traverse outer node left-to-right, validating treelist elements and storing them into dst.
   (core-runtime-helper
    '$treelist-node-append*-collect-into!
    "$treelist-node-append*-collect-into!"
    (lambda ()
      `(func $treelist-node-append*-collect-into!
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (param $dst    (ref $Array))
             (param $start  i32)
             (result i32)
             (local $children (ref $Array))
             (local $count    i32)
             (local $i        i32)
             (local $pos      i32)
             (local $elem     (ref eq))
             (local $child    (ref $TreelistNode))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (local.set $count    (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (local.set $i   (i32.const 0))
                  (local.set $pos (local.get $start))
                  (block $done-leaf
                         (loop $leaf
                               (br_if $done-leaf (i32.ge_u (local.get $i) (local.get $count)))
                               (local.set $elem
                                          (array.get $Array (local.get $children) (local.get $i)))
                               (if (i32.eqz (ref.test (ref $Treelist) (local.get $elem)))
                                   (then (call $raise-check-treelist/who
                                               (global.get $symbol:treelist-append*)
                                               (local.get $elem))
                                         (unreachable)))
                               (array.set $Array (local.get $dst) (local.get $pos) (local.get $elem))
                               (local.set $pos (i32.add (local.get $pos) (i32.const 1)))
                               (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                               (br $leaf)))
                  (return (local.get $pos))))
             (local.set $i   (i32.const 0))
             (local.set $pos (local.get $start))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
                          (local.set $child
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Array (local.get $children) (local.get $i))))
                          (local.set $pos
                                     (call $treelist-node-append*-collect-into!
                                           (local.get $child)
                                           (i32.sub (local.get $height) (i32.const 1))
                                           (local.get $dst)
                                           (local.get $pos)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $pos))))


   (core-runtime-helper
    '$treelist-flatten-into!
    "$treelist-flatten-into!"
    (lambda ()
      `(func $treelist-flatten-into!
             (param $v  (ref eq))
             (param $ga (ref $GrowableArray))
             (local $tl   (ref $Treelist))
             (local.set $tl   (global.get $empty-treelist))
             (if (ref.test (ref $Treelist) (local.get $v))
                 (then
                  (local.set $tl  (ref.cast (ref $Treelist) (local.get $v)))
                  (call $treelist-node-flatten-into!
                        (struct.get $Treelist $root (local.get $tl))
                        (struct.get $Treelist $height (local.get $tl))
                        (local.get $ga)))
                 (else
                  (call $growable-array-add! (local.get $ga) (local.get $v)))))))


   ;; treelist-flatten : any/c -> treelist?
   ;;   Flatten nested treelists, treating non-treelist input as a singleton treelist.
   (core-runtime-helper
    '$treelist-flatten
    "$treelist-flatten"
    (lambda ()
      `(func $treelist-flatten (type $Prim1)
             (param $v0 (ref eq))
             (result (ref eq))
             (local $ga (ref $GrowableArray))
             (local.set $ga (call $make-growable-array (i32.const 8)))
             (call $treelist-flatten-into! (local.get $v0) (local.get $ga))
             (call $array->treelist/checked
                   (call $growable-array->array (local.get $ga))))))


   ;; treelist-sort/checked : (ref $Treelist) (ref eq) -> (ref $Treelist)
   ;;   Sort a treelist using the existing two-argument list sort and rebuild densely.
   (core-runtime-helper
    '$treelist-sort/checked
    "$treelist-sort/checked"
    (lambda ()
      `(func $treelist-sort/checked
             (param $tl   (ref $Treelist))
             (param $proc (ref eq))
             (result (ref $Treelist))
             (local $xs (ref eq))
             (local $ys (ref eq))
             (local.set $xs
                        (call $vector->list/checked
                              (call $treelist->vector/checked (local.get $tl))))
             (local.set $ys (call $sort (local.get $xs) (local.get $proc)))
             (call $array->treelist/checked
                   (call $list->array (local.get $ys))))))


   ;; treelist-sort : treelist? procedure? -> treelist?
   ;;   Sort a treelist with less-than?; only the positional two-argument form is supported.
   (core-runtime-helper
    '$treelist-sort
    "$treelist-sort"
    (lambda ()
      `(func $treelist-sort (type $Prim2)
             (param $v0 (ref eq))
             (param $v1 (ref eq))
             (result (ref eq))
             (local $tl (ref $Treelist))
             (local.set $tl (global.get $empty-treelist))
             (if (ref.test (ref $Treelist) (local.get $v0))
                 (then (local.set $tl (ref.cast (ref $Treelist) (local.get $v0))))
                 (else (call $raise-check-treelist/who
                             (global.get $symbol:treelist-sort)
                             (local.get $v0))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Procedure) (local.get $v1)))
                 (then (call $raise-argument-error:procedure-expected (local.get $v1))
                       (unreachable)))
             (call $treelist-sort/checked
                   (local.get $tl)
                   (local.get $v1)))))


   ;; treelist-flatten-into! : (ref eq) (ref $GrowableArray) -> void
   ;;   Recursively flatten nested treelists into ga, treating other values as singletons.
   (core-runtime-helper
    '$treelist-node-flatten-into!
    "$treelist-node-flatten-into!"
    (lambda ()
      `(func $treelist-node-flatten-into!
             (param $node   (ref $TreelistNode))
             (param $height i32)
             (param $ga     (ref $GrowableArray))
             (local $children (ref $Array))
             (local $count    i32)
             (local $i        i32)
             (local $elem     (ref eq))
             (local $child    (ref $TreelistNode))
             (local.set $children (call $treelist-node-children (local.get $node)))
             (local.set $count    (array.len (local.get $children)))
             (if (i32.eqz (local.get $height))
                 (then
                  (local.set $i (i32.const 0))
                  (block $done-leaf
                         (loop $leaf
                               (br_if $done-leaf (i32.ge_u (local.get $i) (local.get $count)))
                               (local.set $elem
                                          (array.get $Array (local.get $children) (local.get $i)))
                               (call $treelist-flatten-into!
                                     (local.get $elem)
                                     (local.get $ga))
                               (local.set $i (i32.add (local.get $i) (i32.const 1)))
                               (br $leaf)))
                  (return)))
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $count)))
                          (local.set $child
                                     (ref.cast (ref $TreelistNode)
                                               (array.get $Array (local.get $children) (local.get $i))))
                          (call $treelist-node-flatten-into!
                                (local.get $child)
                                (i32.sub (local.get $height) (i32.const 1))
                                (local.get $ga))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop))))))
))
