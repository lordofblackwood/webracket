#lang racket

(provide symbol-runtime-only-helpers)

(require "../core-helper.rkt")

;; symbol-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate symbol table helpers used by the monolithic runtime.
(define symbol-runtime-only-helpers
  (function-forms->runtime-helpers
   'symbol-runtime-only-helpers
   '(
     (func $make-symbol-table (result (ref $SymbolTable))
           (local $entries  (ref $Array))
           ;; Initial capacity is 16, so total entries = 2 * 16 = 32
           (local.set $entries
                      (array.new $Array (global.get $missing) (i32.const 1024))) ; todo: was 32 - was 1024
           (struct.new $SymbolTable
                       (local.get $entries)  ;; $entries
                       (i32.const 0)))       ;; $count

     (func $symbol-table-find ; returns $missing for "not found"
           (param $table (ref $SymbolTable))
           (param $key   (ref $String))
           (result       (ref eq))

           (local $entries  (ref $Array))
           (local $capacity i32)
           (local $hash     i32)
           (local $index    i32)
           (local $step     i32)
           (local $slot     i32)
           (local $k        (ref eq))
           ;; Get the entries array and capacity
           (local.set $entries  (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
           ;; Compute hash and initial index
           (local.set $hash  (call $string-hash/i32 (local.get $key)))
           (local.set $index (i32.rem_u (local.get $hash) (local.get $capacity)))
           (local.set $step  (i32.const 0))

           (block $not-found
                  (loop $probe
                        ;; Stop probing if we've gone through every slot
                        (br_if $not-found (i32.ge_u (local.get $step) (local.get $capacity)))
                        ;; Compute probe slot: (index + step) % capacity
                        (local.set $slot (i32.rem_u (i32.add (local.get $index) (local.get $step))
                                                    (local.get $capacity)))
                        ;; Load key at 2 * slot
                        (local.set $k
                                   (array.get $Array
                                              (local.get $entries)
                                              (i32.shl (local.get $slot) (i32.const 1))))
                        ;; If slot is unused, stop
                        (br_if $not-found
                               (ref.eq (local.get $k) (global.get $missing)))
                        ;; If match, return value at index + 1
                        (if #;(or (ref.eq (local.get $k) (local.get $key))
                                  (call $string=?/i32 (local.get $k) (local.get $key)))
                            (call $string=?/i32 (local.get $k) (local.get $key))
                            (then
                             (return ; returns value at slot 2*slot+1.
                              (array.get $Array
                                         (local.get $entries)
                                         (i32.add (i32.shl (local.get $slot) (i32.const 1))
                                                  (i32.const 1))))))
                        ;; Try next slot
                        (local.set $step (i32.add (local.get $step) (i32.const 1)))
                        (br $probe)))
           ;; Not found
           (global.get $missing))

     (func $raise-symbol-table-insert:table-full (unreachable))

     (func $symbol-table-insert
           (param $table (ref $SymbolTable))
           (param $key   (ref $String))  ;; must be interned or immutable
           (param $val   (ref eq))

           (local $entries  (ref $Array))
           (local $capacity i32)
           (local $hash     i32)
           (local $index    i32)
           (local $step     i32)
           (local $k        (ref eq))
           (local $slot     i32)
           ;; Possibly resize before inserting
           (local.set $table    (call $maybe-resize-symbol-table (local.get $table)))
           ;; Get updated entries array and capacity
           (local.set $entries  (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
           ;; Compute hash and initial index
           (local.set $hash     (call $string-hash/i32 (local.get $key))) ;
           (local.set $index    (i32.rem_u (local.get $hash) (local.get $capacity)))
           (local.set $step     (i32.const 0))

           (block $done
                  (block $full
                         (loop $probe
                               ;; Stop if probing exceeds capacity (should never happen if resize worked)
                               (br_if $full (i32.ge_u (local.get $step) (local.get $capacity)))
                               ;; Compute probe index and actual slot (2 * index)
                               (local.set $slot (i32.shl (i32.rem_u (i32.add (local.get $index) (local.get $step))
                                                                    (local.get $capacity))
                                                         (i32.const 1))) ;; multiply by 2
                               ;; Load key from slot
                               (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
                               ;; Empty slot - insert
                               (if (ref.eq (local.get $k) (global.get $missing))
                                   (then
                                    (array.set $Array (local.get $entries) (local.get $slot) (local.get $key))
                                    (array.set $Array (local.get $entries)
                                               (i32.add (local.get $slot) (i32.const 1))
                                               (local.get $val))
                                    (struct.set $SymbolTable $count
                                                (local.get $table)
                                                (i32.add (struct.get $SymbolTable $count (local.get $table)) (i32.const 1)))
                                    (br $done)))
                               ;; Key match - update value
                               (if (call $string=?/i32 (local.get $k) (local.get $key))
                                   (then (array.set $Array (local.get $entries)
                                                    (i32.add (local.get $slot) (i32.const 1))
                                                    (local.get $val))
                                         (br $done)))
                               ;; Otherwise, try next probe
                               (local.set $step (i32.add (local.get $step) (i32.const 1)))
                               (br $probe)))
                  ;; Failed to insert - table full (should not happen if resizing is correct)
                  (call $raise-symbol-table-insert:table-full)))

     (func $symbol-table-resize
           (param $table (ref $SymbolTable))
           (result (ref $SymbolTable))

           (local $old-entries (ref $Array))
           (local $old-cap     i32)
           (local $new-cap     i32)
           (local $new-array   (ref $Array))
           (local $new-table   (ref $SymbolTable))
           (local $i           i32)
           (local $len         i32)
           (local $key         (ref eq))
           (local $val         (ref eq))

           ;; Get old table size and entries
           (local.set $old-entries (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $old-cap     (i32.div_u (array.len (local.get $old-entries)) (i32.const 2)))
           (local.set $new-cap     (i32.mul (local.get $old-cap) (i32.const 2)))
           ;; Allocate new entries array with (2 * new-capacity) slots filled with $missing
           (local.set $new-array (array.new $Array (global.get $missing)
                                            (i32.mul (local.get $new-cap) (i32.const 2))))
           ;; Create new empty table with count = 0
           (local.set $new-table (struct.new $SymbolTable (local.get $new-array) (i32.const 0)))
           ;; Reinsert old entries
           (local.set $i (i32.const 0))
           (local.set $len (array.len (local.get $old-entries)))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                        ;; Get key and value
                        (local.set $key (array.get $Array (local.get $old-entries) (local.get $i)))
                        (local.set $val (array.get $Array (local.get $old-entries) (i32.add (local.get $i) (i32.const 1))))
                        ;; Insert if key is not $missing (i.e. dummy)
                        (if (ref.test (ref $String) (local.get $key))
                            (then (call $symbol-table-insert
                                        (local.get $new-table)
                                        (ref.cast (ref $String) (local.get $key))
                                        (local.get $val))))
                        ;; Step to next pair
                        (local.set $i (i32.add (local.get $i) (i32.const 2)))
                        (br $loop)))
           ; Store changes in the original table
           (struct.set $SymbolTable $entries (local.get $table) (local.get $new-array))
           (struct.set $SymbolTable $count   (local.get $table) (struct.get $SymbolTable $count
                                                                            (local.get $new-table)))
           (local.get $table))

     (func $maybe-resize-symbol-table
           (param $table    (ref $SymbolTable))
           (result          (ref $SymbolTable))

           (local $entries  (ref $Array))
           (local $capacity i32)
           (local $count    i32)
           ;; Get fields
           (local.set $entries  (struct.get $SymbolTable $entries (local.get $table)))
           (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
           (local.set $count    (struct.get $SymbolTable $count (local.get $table)))
           ;; Resize if count >= capacity / 2
           (if (i32.ge_u (local.get $count)
                         (i32.shr_u (local.get $capacity) (i32.const 1)))
               (then (return (call $symbol-table-resize (local.get $table)))))
           ;; Otherwise return unchanged
           (local.get $table)))))
