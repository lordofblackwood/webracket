#lang racket

(provide hash-runtime-only-helpers)

(require "../core-helper.rkt")

;; hash-count-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash count helpers.
(define hash-count-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'hash-count-runtime-only-helpers
    '(
        ; General hash-count
        (func $hash-count (type $Prim1)
              (param $ht (ref eq))
              (result (ref eq))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-count (local.get $ht)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-count (local.get $ht)))))
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then
                   (return
                    (ref.i31
                     (i32.shl
                      (struct.get $HashEqImmutable $count
                                  (ref.cast (ref $HashEqImmutable)
                                            (local.get $ht)))
                      (i32.const 1))))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then
                   (return
                    (ref.i31
                     (i32.shl
                      (struct.get $HashEqvImmutable $count
                                  (ref.cast (ref $HashEqvImmutable)
                                            (local.get $ht)))
                      (i32.const 1))))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-count (local.get $ht)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then
                   (return
                    (ref.i31
                     (i32.shl
                      (struct.get $HashEqualImmutable $count
                                  (ref.cast (ref $HashEqualImmutable)
                                            (local.get $ht)))
                      (i32.const 1))))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then
                   (return
                    (ref.i31
                     (i32.shl
                      (struct.get $HashEqualAlwaysImmutable $count
                                  (ref.cast (ref $HashEqualAlwaysImmutable)
                                            (local.get $ht)))
                      (i32.const 1))))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-count (local.get $ht)))))
              (unreachable))))

   (for/list ([hash-count       '($hasheq-count
                                  $hasheqv-count
                                  $hashequal-count
                                  $hashalw-count)]
              [type             '($HashEqMutable
                                  $HashEqvMutable
                                  $HashEqualMutable
                                  $HashEqualAlwaysMutable)]
              [raise-expected   '($raise-argument-error:hasheq-expected
                                  $raise-argument-error:hasheqv-expected
                                  $raise-argument-error:hash-expected
                                  $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-count
      (symbol->string hash-count)
      (lambda ()
        `(func ,hash-count
               (param $ht (ref eq))   ;; table
               (result (ref eq))      ;; fixnum count

               (local $table (ref ,type))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               ;; Return fixnum of count
               (ref.i31
                (i32.shl (struct.get ,type $count (local.get $table))
                         (i32.const 1)))))))))

;; hash-list-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash list-conversion helpers.
(define hash-list-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'hash-list-runtime-only-helpers
    '(
        ;; General hash->list

        (func $hash->list (type $Prim2)
              (param $ht  (ref eq))   ;; hash table
              (param $try (ref eq))   ;; optional try-order? (default #f)
              (result     (ref eq))   ;; list of pairs

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))

              ;; Use the general hash-iteration entry points. Despite their
              ;; historical mutable-* names, they now handle immutable hashes
              ;; too, and keep hash->list aligned with printer traversal.
              (return_call $hash->list/generic (local.get $ht)))

        (func $hash->list/generic
              (param $ht (ref eq)) ;; hash table
              (result    (ref eq)) ;; list of pairs

              (local $pos  (ref eq))
              (local $pair (ref eq))
              (local $acc  (ref eq))

              (local.set $pos (call $mutable-hash-iterate-first (local.get $ht)))
              (local.set $acc (global.get $null))
              (block $done
                     (loop $walk
                           (br_if $done (ref.eq (local.get $pos) (global.get $false)))
                           (local.set $pair
                                      (call $mutable-hash-iterate-pair
                                            (local.get $ht)
                                            (local.get $pos)
                                            (global.get $missing)))
                           (local.set $acc (call $cons (local.get $pair) (local.get $acc)))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (local.get $acc))))

   (for/list ([hash->list       '($hasheq->list
                                  $hasheqv->list
                                  $hashequal->list
                                  $hashalw->list)]
              [hash->list/plain '($hasheq->list/plain
                                  $hasheqv->list/plain
                                  $hashequal->list/plain
                                  $hashalw->list/plain)])
     (core-runtime-helper
      hash->list
      (symbol->string hash->list)
      (lambda ()
        `(func ,hash->list
               (param $ht  (ref eq))
               (param $try (ref eq))
               (result     (ref eq))

               (return_call ,hash->list/plain
                            (local.get $ht)
                            (local.get $try))))))

   (for/list ([hash->list/plain         '($hasheq->list/plain
                                          $hasheqv->list/plain
                                          $hashequal->list/plain
                                          $hashalw->list/plain)]
              [hash->list/plain/checked '($hasheq->list/plain/checked
                                          $hasheqv->list/plain/checked
                                          $hashequal->list/plain/checked
                                          $hashalw->list/plain/checked)]
              [type                     '($HashEqMutable
                                          $HashEqvMutable
                                          $HashEqualMutable
                                          $HashEqualAlwaysMutable)]
              [raise-expected           '($raise-argument-error:hasheq-expected
                                          $raise-argument-error:hasheqv-expected
                                          $raise-argument-error:hash-expected
                                          $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash->list/plain
      (symbol->string hash->list/plain)
      (lambda ()
        `(func ,hash->list/plain
               (param $ht  (ref eq))
               (param $try (ref eq))
               (result     (ref eq))

               (local $table (ref ,type))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               ;; Delegate to checked implementation
               (call ,hash->list/plain/checked
                     (local.get $table))))))

   (for/list ([hash->list/plain/checked '($hasheq->list/plain/checked
                                          $hasheqv->list/plain/checked
                                          $hashequal->list/plain/checked
                                          $hashalw->list/plain/checked)]
              [type                     '($HashEqMutable
                                          $HashEqvMutable
                                          $HashEqualMutable
                                          $HashEqualAlwaysMutable)])
     (core-runtime-helper
      hash->list/plain/checked
      (symbol->string hash->list/plain/checked)
      (lambda ()
        `(func ,hash->list/plain/checked
               (param $table (ref ,type))
               (result       (ref eq))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $i        i32)
               (local $key      (ref eq))
               (local $val      (ref eq))
               (local $pair     (ref eq))
               (local $acc      (ref eq))

               ;; Initialize locals
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $i        (i32.const 0))
               (local.set $acc      (global.get $null))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))

                            ;; Load key
                            (local.set $key (array.get $Array
                                                       (local.get $entries)
                                                       (i32.shl (local.get $i) (i32.const 1))))
                            ;; Skip empty or tombstone slots
                            (if (ref.eq (local.get $key) (global.get $missing))
                                (then
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (ref.eq (local.get $key) (global.get $tombstone))
                                (then
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))

                            ;; Load value and cons onto result
                            (local.set $val (array.get $Array
                                                      (local.get $entries)
                                                      (i32.add (i32.shl (local.get $i) (i32.const 1))
                                                               (i32.const 1))))
                            (local.set $pair (call $cons (local.get $key) (local.get $val)))
                            (local.set $acc  (call $cons (local.get $pair) (local.get $acc)))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))

               (local.get $acc)))))))

;; hash-for-each-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash-for-each helpers.
(define hash-for-each-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'hash-for-each-runtime-only-helpers
    '(
         ;; hash-for-each : apply proc to each key/value in a hash table.
         ;; The try-order? argument is accepted but ignored.
         (func $hash-for-each (type $Prim23)
               (param $ht   (ref eq))   ;; hash table
               (param $proc (ref eq))   ;; procedure
               (param $try  (ref eq))   ;; optional try-order? (default #f)
               (result      (ref eq))

               ;; Check type: must be (ref $Hash)
               (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                   (then (call $raise-argument-error:hash-expected)
                         (unreachable)))
               ;; Optional for try-order
               (if (ref.eq (local.get $try) (global.get $missing))
                   (then (local.set $try (global.get $false))))

               ;; Dispatch on table type
               (if (ref.test (ref $HashEqMutable) (local.get $ht))
                   (then (return (call $hasheq-for-each (local.get $ht) (local.get $proc)))))
               (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                   (then (return (call $hasheqv-for-each (local.get $ht) (local.get $proc)))))
               (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                   (then (return (call $hashequal-for-each (local.get $ht) (local.get $proc)))))
               (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                   (then (return (call $hashalw-for-each (local.get $ht) (local.get $proc)))))
               (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                   (then (return (call $hash-for-each/generic
                                       (local.get $ht)
                                       (local.get $proc)))))
               (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                   (then (return (call $hash-for-each/generic
                                       (local.get $ht)
                                       (local.get $proc)))))
               (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                   (then (return (call $hash-for-each/generic
                                       (local.get $ht)
                                       (local.get $proc)))))
               (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                   (then (return (call $hash-for-each/generic
                                       (local.get $ht)
                                       (local.get $proc)))))
               (unreachable))))

   (for/list ([hash-for-each '($hasheq-for-each
                               $hasheqv-for-each
                               $hashequal-for-each
                               $hashalw-for-each)]
              [hash-for-each/checked '($hasheq-for-each/checked
                                       $hasheqv-for-each/checked
                                       $hashequal-for-each/checked
                                       $hashalw-for-each/checked)]
              [type '($HashEqMutable
                      $HashEqvMutable
                      $HashEqualMutable
                      $HashEqualAlwaysMutable)]
              [raise-expected '($raise-argument-error:hasheq-expected
                                $raise-argument-error:hasheqv-expected
                                $raise-argument-error:hash-expected
                                $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-for-each
      (symbol->string hash-for-each)
      (lambda ()
        `(func ,hash-for-each
               (param $ht   (ref eq))
               (param $proc (ref eq))
               (result      (ref eq))

               (local $table (ref ,type))
               (local $f     (ref $Procedure))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))

               ;; Ensure proc is a procedure
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                   (then (call $raise-argument-error:procedure-expected (local.get $proc))
                         (unreachable)))

               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               (local.set $f     (ref.cast (ref $Procedure) (local.get $proc)))

               ;; Delegate to checked implementation
               (return_call ,hash-for-each/checked
                            (local.get $table)
                            (local.get $f))))))

   (for/list ([hash-for-each/checked '($hasheq-for-each/checked
                                       $hasheqv-for-each/checked
                                       $hashequal-for-each/checked
                                       $hashalw-for-each/checked)]
              [type '($HashEqMutable
                      $HashEqvMutable
                      $HashEqualMutable
                      $HashEqualAlwaysMutable)])
     (core-runtime-helper
      hash-for-each/checked
      (symbol->string hash-for-each/checked)
      (lambda ()
        `(func ,hash-for-each/checked
               (param $table (ref ,type))
               (param $f     (ref $Procedure))
               (result       (ref eq))

               (local $finv    (ref $ProcedureInvoker))
               (local $entries (ref $Array))
               (local $capacity i32)
               (local $i       i32)
               (local $key     (ref eq))
               (local $val     (ref eq))
               (local $call    (ref $Args))

               ;; Fetch procedure invoker and table fields
               (local.set $finv   (struct.get $Procedure $invoke (local.get $f)))
               (local.set $entries (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $i       (i32.const 0))
               (local.set $call    (array.new_fixed $Args 2 (global.get $null) (global.get $null)))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))

                            ;; Load key
                            (local.set $key (array.get $Array
                                                       (local.get $entries)
                                                       (i32.shl (local.get $i) (i32.const 1))))
                            ;; Skip empty or tombstone slots
                            (if (ref.eq (local.get $key) (global.get $missing))
                                (then
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (ref.eq (local.get $key) (global.get $tombstone))
                                (then
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))

                            ;; Load value
                            (local.set $val (array.get $Array
                                                       (local.get $entries)
                                                       (i32.add (i32.shl (local.get $i) (i32.const 1))
                                                                (i32.const 1))))

                            ;; Prepare call arguments
                            (array.set $Args (local.get $call) (i32.const 0) (local.get $key))
                            (array.set $Args (local.get $call) (i32.const 1) (local.get $val))

                            ;; Apply procedure and drop result
                            (drop (call_ref $ProcedureInvoker
                                            (local.get $f)
                                            (local.get $call)
                                            (local.get $finv)))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))

               (global.get $void)))))

   (function-forms->runtime-helpers
    'hash-for-each-runtime-only-helpers
    '(
        ;; hash-for-each/generic : hash? procedure? -> void?
        ;;   Iterator-backed fallback for immutable hash wrappers.
        (func $hash-for-each/generic
              (param $ht   (ref eq)) ;; hash table
              (param $proc (ref eq)) ;; procedure
              (result      (ref eq))
              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))
              (local $args (ref $Args))
              (local $pos  (ref eq))
              (local $key  (ref eq))
              (local $val  (ref eq))
              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new_fixed $Args 2
                                                (global.get $null)
                                                (global.get $null)))
              (local.set $pos (call $mutable-hash-iterate-first (local.get $ht)))
              (block $done
                     (loop $walk
                           (br_if $done (ref.eq (local.get $pos) (global.get $false)))
                           (local.set $key
                                      (call $mutable-hash-iterate-key
                                            (local.get $ht)
                                            (local.get $pos)
                                            (global.get $missing)))
                           (local.set $val
                                      (call $mutable-hash-iterate-value
                                            (local.get $ht)
                                            (local.get $pos)
                                            (global.get $missing)))
                           (array.set $Args (local.get $args) (i32.const 0) (local.get $key))
                           (array.set $Args (local.get $args) (i32.const 1) (local.get $val))
                           (drop (call_ref $ProcedureInvoker
                                           (local.get $f)
                                           (local.get $args)
                                           (local.get $finv)))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (global.get $void))))))

;; hash-map-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash-map helpers.
(define hash-map-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'hash-map-runtime-only-helpers
    '(
        ;; General hash-map
        (func $hash-map (type $Prim23)
              (param $ht   (ref eq))   ;; hash table
              (param $proc (ref eq))   ;; procedure
              (param $try  (ref eq))   ;; optional try-order? (default #f)
              (result      (ref eq))   ;; list of results

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))
              ;; Validate procedure
              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected (local.get $proc))
                        (unreachable)))
              ;; Optional try-order?
              (if (ref.eq (local.get $try) (global.get $missing))
                   (then (local.set $try (global.get $false))))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-map (local.get $ht)
                                      (local.get $proc)
                                      (local.get $try)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-map (local.get $ht)
                                      (local.get $proc)
                                      (local.get $try)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-map (local.get $ht)
                                      (local.get $proc)
                                      (local.get $try)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-map (local.get $ht)
                                      (local.get $proc)
                                      (local.get $try)))))
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then (return (call $hash-map/generic
                                      (local.get $ht)
                                      (local.get $proc)))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (call $hash-map/generic
                                      (local.get $ht)
                                      (local.get $proc)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then (return (call $hash-map/generic
                                      (local.get $ht)
                                      (local.get $proc)))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then (return (call $hash-map/generic
                                      (local.get $ht)
                                      (local.get $proc)))))
              (unreachable))))

   (for/list ([hash-map       '($hasheq-map
                                $hasheqv-map
                                $hashequal-map
                                $hashalw-map)]
              [hash-map/plain '($hasheq-map/plain
                                $hasheqv-map/plain
                                $hashequal-map/plain
                                $hashalw-map/plain)])
     (core-runtime-helper
      hash-map
      (symbol->string hash-map)
      (lambda ()
        `(func ,hash-map
               (param $ht   (ref eq))
               (param $proc (ref eq))
               (param $try  (ref eq))
               (result      (ref eq))

               (return_call ,hash-map/plain
                            (local.get $ht)
                            (local.get $proc)
                            (local.get $try))))))

   (for/list ([hash-map/plain         '($hasheq-map/plain
                                        $hasheqv-map/plain
                                        $hashequal-map/plain
                                        $hashalw-map/plain)]
              [hash-map/plain/checked '($hasheq-map/plain/checked
                                        $hasheqv-map/plain/checked
                                        $hashequal-map/plain/checked
                                        $hashalw-map/plain/checked)]
              [type                   '($HashEqMutable
                                        $HashEqvMutable
                                        $HashEqualMutable
                                        $HashEqualAlwaysMutable)]
              [raise-expected         '($raise-argument-error:hasheq-expected
                                        $raise-argument-error:hasheqv-expected
                                        $raise-argument-error:hash-expected
                                        $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-map/plain
      (symbol->string hash-map/plain)
      (lambda ()
        `(func ,hash-map/plain
               (param $ht   (ref eq))
               (param $proc (ref eq))
               (param $try  (ref eq)) ;; try-order?, default #f
               (result      (ref eq))

               (local $table (ref ,type))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               ;; Delegate to checked implementation
               (call ,hash-map/plain/checked
                     (local.get $table)
                     (local.get $proc))))))

   (for/list ([hash-map/plain/checked '($hasheq-map/plain/checked
                                        $hasheqv-map/plain/checked
                                        $hashequal-map/plain/checked
                                        $hashalw-map/plain/checked)]
              [type                   '($HashEqMutable
                                        $HashEqvMutable
                                        $HashEqualMutable
                                        $HashEqualAlwaysMutable)])
     (core-runtime-helper
      hash-map/plain/checked
      (symbol->string hash-map/plain/checked)
      (lambda ()
        `(func ,hash-map/plain/checked
               (param $table (ref ,type))
               (param $proc  (ref eq))
               (result       (ref eq))

               (local $f       (ref $Procedure))
               (local $finv    (ref $ProcedureInvoker))
               (local $entries (ref $Array))
               (local $capacity i32)
               (local $i       i32)
               (local $key     (ref eq))
               (local $val     (ref eq))
               (local $args    (ref $Args))
               (local $r       (ref eq))
               (local $acc     (ref eq))

               ;; Validate procedure
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                   (then (call $raise-argument-error:procedure-expected (local.get $proc))
                         (unreachable)))
               (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
               (local.set $args (array.new $Args (global.get $null) (i32.const 2)))

               ;; Initialize locals
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $i        (i32.const 0))
               (local.set $acc      (global.get $null))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))

                            ;; Load key
                            (local.set $key
                                       (array.get $Array
                                                  (local.get $entries)
                                                  (i32.shl (local.get $i) (i32.const 1))))
                            ;; Skip empty or tombstone slots
                            (if (ref.eq (local.get $key) (global.get $missing))
                                (then
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))
                            (if (ref.eq (local.get $key) (global.get $tombstone))
                                (then
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))

                            ;; Load value
                            (local.set $val
                                       (array.get $Array
                                                  (local.get $entries)
                                                  (i32.add (i32.shl (local.get $i) (i32.const 1))
                                                           (i32.const 1))))
                            ;; Prepare arguments and invoke procedure
                            (array.set $Args (local.get $args) (i32.const 0) (local.get $key))
                            (array.set $Args (local.get $args) (i32.const 1) (local.get $val))
                            (local.set $r
                                       (call_ref $ProcedureInvoker
                                                 (local.get $f)
                                                 (local.get $args)
                                                 (local.get $finv)))
                            ;; Accumulate result
                            (local.set $acc (call $cons (local.get $r) (local.get $acc)))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))

               (local.get $acc)))))

   (function-forms->runtime-helpers
    'hash-map-runtime-only-helpers
    '(
        ;; hash-map/generic : hash? procedure? -> list?
        ;;   Iterator-backed fallback for immutable hash wrappers.
        (func $hash-map/generic
              (param $ht   (ref eq)) ;; hash table
              (param $proc (ref eq)) ;; procedure
              (result      (ref eq))
              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))
              (local $args (ref $Args))
              (local $pos  (ref eq))
              (local $key  (ref eq))
              (local $val  (ref eq))
              (local $r    (ref eq))
              (local $acc  (ref eq))
              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new_fixed $Args 2
                                                (global.get $null)
                                                (global.get $null)))
              (local.set $pos (call $mutable-hash-iterate-first (local.get $ht)))
              (local.set $acc (global.get $null))
              (block $done
                     (loop $walk
                           (br_if $done (ref.eq (local.get $pos) (global.get $false)))
                           (local.set $key
                                      (call $mutable-hash-iterate-key
                                            (local.get $ht)
                                            (local.get $pos)
                                            (global.get $missing)))
                           (local.set $val
                                      (call $mutable-hash-iterate-value
                                            (local.get $ht)
                                            (local.get $pos)
                                            (global.get $missing)))
                           (array.set $Args (local.get $args) (i32.const 0) (local.get $key))
                           (array.set $Args (local.get $args) (i32.const 1) (local.get $val))
                           (local.set $r
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $finv)))
                           (local.set $acc (call $cons (local.get $r) (local.get $acc)))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (local.get $acc))))))

;; hash-map/copy-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash-map/copy helpers.
(define hash-map/copy-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'hash-map/copy-runtime-only-helpers
    '(
        ;; -------------------------------------------------------------------
        ;; hash-map/copy
        ;; Applies `proc` to each key/value in `ht`, producing a new hash.
        ;; The optional `kind` argument defaults to #f and is currently ignored
        ;; (only mutable hashes are supported).
        ;; Note: The original Racket `hash-map/copy` uses keyword arguments.
        ;; -------------------------------------------------------------------

        (func $hash-map/copy (type $Prim23)
              (param $ht   (ref eq))   ;; hash table
              (param $proc (ref eq))   ;; (key value -> (values key value))
              (param $kind (ref eq))   ;; optional kind, default #f
              (result      (ref eq))

              ;; Validate argument is a hash table
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))

              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-map/copy
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-map/copy
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-map/copy
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-map/copy
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (unreachable))))

   (for/list ([hash-map/copy  '($hasheq-map/copy
                                $hasheqv-map/copy
                                $hashequal-map/copy
                                $hashalw-map/copy)]
              [hash-map/plain '($hasheq-map/copy/plain
                                $hasheqv-map/copy/plain
                                $hashequal-map/copy/plain
                                $hashalw-map/copy/plain)])
     (core-runtime-helper
      hash-map/copy
      (symbol->string hash-map/copy)
      (lambda ()
        `(func ,hash-map/copy
               (param $ht   (ref eq))
               (param $proc (ref eq))
               (param $kind (ref eq))
               (result      (ref eq))

               (return_call ,hash-map/plain
                            (local.get $ht)
                            (local.get $proc)
                            (local.get $kind))))))

   (for/list ([hash-map/plain   '($hasheq-map/copy/plain
                                  $hasheqv-map/copy/plain
                                  $hashequal-map/copy/plain
                                  $hashalw-map/copy/plain)]
              [hash-map/checked '($hasheq-map/copy/plain/checked
                                  $hasheqv-map/copy/plain/checked
                                  $hashequal-map/copy/plain/checked
                                  $hashalw-map/copy/plain/checked)]
              [type             '($HashEqMutable
                                  $HashEqvMutable
                                  $HashEqualMutable
                                  $HashEqualAlwaysMutable)]
              [raise-expected   '($raise-argument-error:hasheq-expected
                                  $raise-argument-error:hasheqv-expected
                                  $raise-argument-error:hash-expected
                                  $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-map/plain
      (symbol->string hash-map/plain)
      (lambda ()
        `(func ,hash-map/plain
               (param $ht   (ref eq))
               (param $proc (ref eq))
               (param $kind (ref eq))
               (result      (ref eq))

               (local $table (ref ,type))
               (local $f     (ref $Procedure))
               (local $finv  (ref $ProcedureInvoker))

               ;; Check hash table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Check procedure
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                   (then (call $raise-argument-error:procedure-expected (local.get $proc))
                         (unreachable)))

               ;; Decode and fetch invoker
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               (local.set $f     (ref.cast (ref $Procedure) (local.get $proc)))
               (local.set $finv  (struct.get $Procedure $invoke (local.get $f)))

               ;; Delegate
               (call ,hash-map/checked
                     (local.get $table)
                     (local.get $f)
                     (local.get $finv)
                     (local.get $kind))))))

   (for/list ([hash-map/checked '($hasheq-map/copy/plain/checked
                                  $hasheqv-map/copy/plain/checked
                                  $hashequal-map/copy/plain/checked
                                  $hashalw-map/copy/plain/checked)]
              [type             '($HashEqMutable
                                  $HashEqvMutable
                                  $HashEqualMutable
                                  $HashEqualAlwaysMutable)]
              [make-empty       '($make-empty-hasheq
                                  $make-empty-hasheqv
                                  $make-empty-hash
                                  $make-empty-hashalw)]
              [set!/checked     '($hasheq-set!/mutable/checked
                                  $hasheqv-set!/mutable/checked
                                  $hash-set!/mutable/checked
                                  $hashalw-set!/mutable/checked)])
     (core-runtime-helper
      hash-map/checked
      (symbol->string hash-map/checked)
      (lambda ()
        `(func ,hash-map/checked
               (param $table (ref ,type))
               (param $f     (ref $Procedure))
               (param $finv  (ref $ProcedureInvoker))
               (param $kind  (ref eq)) ;; optional kind, ignored
               (result (ref eq))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $i        i32)
               (local $key      (ref eq))
               (local $val      (ref eq))
               (local $nkey     (ref eq))
               (local $nval     (ref eq))
               (local $dst      (ref ,type))
               (local $call     (ref $Args))
               (local $res      (ref eq))
               (local $vals     (ref $Values))

               ;; Initialize non-defaultable locals.
               (local.set $kind (global.get $false)) ; todo: remove, when kind support is added.
               (local.set $nkey (global.get $zero))
               (local.set $nval (global.get $zero))

               ;; Create destination hash. Only mutable hashes are supported.
               (local.set $dst (ref.cast (ref ,type) (call ,make-empty)))

               ;; Prepare iteration
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $i        (i32.const 0))
               (local.set $call     (array.new_fixed $Args 2 (global.get $null) (global.get $null)))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))

                            ;; Load key
                            (local.set $key (array.get $Array
                                                       (local.get $entries)
                                                       (i32.shl (local.get $i) (i32.const 1))))
                            ;; Skip empty or tombstone
                            (if (ref.eq (local.get $key) (global.get $missing))
                                (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))
                            (if (ref.eq (local.get $key) (global.get $tombstone))
                                (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))

                            ;; Load value
                            (local.set $val (array.get $Array
                                                       (local.get $entries)
                                                       (i32.add (i32.shl (local.get $i) (i32.const 1))
                                                                (i32.const 1))))

                            ;; Call procedure
                            (array.set $Args (local.get $call) (i32.const 0) (local.get $key))
                            (array.set $Args (local.get $call) (i32.const 1) (local.get $val))
                            (local.set $res
                                       (call_ref $ProcedureInvoker
                                                 (local.get $f)
                                                 (local.get $call)
                                                 (local.get $finv)))

                            ;; Expect two values
                            (if (ref.test (ref $Values) (local.get $res))
                                (then
                                 (local.set $vals (ref.cast (ref $Values) (local.get $res)))
                                 (if (i32.ne (array.len (local.get $vals)) (i32.const 2))
                                     (then (call $raise-wrong-number-of-values-received)
                                           (unreachable)))
                                 (local.set $nkey (array.get $Values (local.get $vals) (i32.const 0)))
                                 (local.set $nval (array.get $Values (local.get $vals) (i32.const 1))))
                                (else (call $raise-wrong-number-of-values-received)
                                      (unreachable)))

                            ;; Insert into destination table
                            (call ,set!/checked
                                  (local.get $dst)
                                  (local.get $nkey)
                                  (local.get $nval))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))

               (local.get $dst)))))))

;; hash-filter-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash-filter helpers.
(define hash-filter-runtime-only-helpers
  (append
   (for/list ([prim '($hash-filter
                      $hash-filter-keys
                      $hash-filter-values)]
              [mode '(0 1 2)])
     (core-runtime-helper
      prim
      (symbol->string prim)
      (lambda ()
        `(func ,prim (type $Prim2)
               (param $ht   (ref eq))   ;; hash table
               (param $proc (ref eq))   ;; predicate
               (result      (ref eq))   ;; filtered hash

               ;; Check type: must be (ref $Hash)
               (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                   (then (call $raise-argument-error:hash-expected)
                         (unreachable)))

               ;; Validate predicate
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                   (then (call $raise-argument-error:procedure-expected (local.get $proc))
                         (unreachable)))

               ;; Dispatch on table type
               (if (ref.test (ref $HashEqMutable) (local.get $ht))
                   (then (return (call $hasheq-filter
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                   (then (return (call $hasheqv-filter
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                   (then (return (call $hashequal-filter
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                   (then (return (call $hashalw-filter
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (unreachable)))))

   (for/list ([filter '($hasheq-filter
                        $hasheqv-filter
                        $hashequal-filter
                        $hashalw-filter)]
              [plain  '($hasheq-filter/plain
                        $hasheqv-filter/plain
                        $hashequal-filter/plain
                        $hashalw-filter/plain)])
     (core-runtime-helper
      filter
      (symbol->string filter)
      (lambda ()
        `(func ,filter
               (param $ht   (ref eq))
               (param $proc (ref eq))
               (param $mode i32)
               (result      (ref eq))

               (return_call ,plain
                            (local.get $ht)
                            (local.get $proc)
                            (local.get $mode))))))

   (for/list ([plain   '($hasheq-filter/plain
                         $hasheqv-filter/plain
                         $hashequal-filter/plain
                         $hashalw-filter/plain)]
              [checked '($hasheq-filter/plain/checked
                         $hasheqv-filter/plain/checked
                         $hashequal-filter/plain/checked
                         $hashalw-filter/plain/checked)]
              [type    '($HashEqMutable
                         $HashEqvMutable
                         $HashEqualMutable
                         $HashEqualAlwaysMutable)]
              [raise   '($raise-argument-error:hasheq-expected
                         $raise-argument-error:hasheqv-expected
                         $raise-argument-error:hash-expected
                         $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      plain
      (symbol->string plain)
      (lambda ()
        `(func ,plain
               (param $ht   (ref eq))
               (param $proc (ref eq))
               (param $mode i32)
               (result      (ref eq))

               (local $table (ref ,type))
               (local $f     (ref $Procedure))
               (local $finv  (ref $ProcedureInvoker))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise (local.get $ht))
                         (unreachable)))

               ;; Validate predicate
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                   (then (call $raise-argument-error:procedure-expected (local.get $proc))
                         (unreachable)))

               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               (local.set $f     (ref.cast (ref $Procedure) (local.get $proc)))
               (local.set $finv  (struct.get $Procedure $invoke (local.get $f)))

               ;; Delegate to checked implementation
               (call ,checked
                     (local.get $table)
                     (local.get $f)
                     (local.get $finv)
                     (local.get $mode))))))

   (for/list ([checked      '($hasheq-filter/plain/checked
                              $hasheqv-filter/plain/checked
                              $hashequal-filter/plain/checked
                              $hashalw-filter/plain/checked)]
              [type         '($HashEqMutable
                              $HashEqvMutable
                              $HashEqualMutable
                              $HashEqualAlwaysMutable)]
              [make-empty   '($make-empty-hasheq
                              $make-empty-hasheqv
                              $make-empty-hash
                              $make-empty-hashalw)]
              [set!/checked '($hasheq-set!/mutable/checked
                              $hasheqv-set!/mutable/checked
                              $hash-set!/mutable/checked
                              $hashalw-set!/mutable/checked)])
     (core-runtime-helper
      checked
      (symbol->string checked)
      (lambda ()
        `(func ,checked
               (param $table (ref ,type))
               (param $f     (ref $Procedure))
               (param $finv  (ref $ProcedureInvoker))
               (param $mode  i32)
               (result (ref eq))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $i        i32)
               (local $key      (ref eq))
               (local $val      (ref eq))
               (local $dst      (ref ,type))
               (local $args     (ref $Args))
               (local $res      (ref eq))

               ;; Create destination hash
               (local.set $dst (ref.cast (ref ,type) (call ,make-empty)))

               ;; Prepare iteration
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $i        (i32.const 0))
               (local.set $args
                          (if (result (ref $Args))
                              (i32.eq (local.get $mode) (i32.const 0))
                              (then (array.new $Args (global.get $null) (i32.const 2)))
                              (else (array.new $Args (global.get $null) (i32.const 1)))))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))

                            ;; Load key
                            (local.set $key (array.get $Array
                                                       (local.get $entries)
                                                       (i32.shl (local.get $i) (i32.const 1))))
                            ;; Skip empty or tombstone slots
                            (if (ref.eq (local.get $key) (global.get $missing))
                                (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))
                            (if (ref.eq (local.get $key) (global.get $tombstone))
                                (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                      (br $loop)))

                            ;; Load value
                            (local.set $val (array.get $Array
                                                       (local.get $entries)
                                                       (i32.add (i32.shl (local.get $i) (i32.const 1))
                                                                (i32.const 1))))

                            ;; Prepare predicate arguments based on mode
                            (if (i32.eq (local.get $mode) (i32.const 0))
                                (then (array.set $Args (local.get $args) (i32.const 0) (local.get $key))
                                      (array.set $Args (local.get $args) (i32.const 1) (local.get $val)))
                                (else (if (i32.eq (local.get $mode) (i32.const 1))
                                          (then (array.set $Args (local.get $args) (i32.const 0) (local.get $key)))
                                          (else (array.set $Args (local.get $args) (i32.const 0) (local.get $val))))))

                            ;; Invoke predicate
                            (local.set $res
                                       (call_ref $ProcedureInvoker
                                                 (local.get $f)
                                                 (local.get $args)
                                                 (local.get $finv)))

                            ;; Insert when predicate result is not #f
                            (if (ref.eq (local.get $res) (global.get $false))
                                (then (nop))
                                (else (call ,set!/checked
                                            (local.get $dst)
                                            (local.get $key)
                                            (local.get $val))))

                            (local.set $i (i32.add (local.get $i) (i32.const 1)))
                            (br $loop)))

               (local.get $dst)))))))

;; hash-keys-values-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash key/value list helpers.
(define hash-keys-values-runtime-only-helpers
  (append
   ;; General hash-keys and hash-values

   ;; The try-order? argument is accepted but ignored.
   (for/list ([prim           '($hash-keys       $hash-values)]
              [hasheq-prim    '($hasheq-keys     $hasheq-values)]
              [hasheqv-prim   '($hasheqv-keys    $hasheqv-values)]
              [hashequal-prim '($hashequal-keys  $hashequal-values)]
              [hashalw-prim   '($hashalw-keys    $hashalw-values)])
     (core-runtime-helper
      prim
      (symbol->string prim)
      (lambda ()
        `(func ,prim (type $Prim12)
               (param $ht  (ref eq))   ;; hash table
               (param $try (ref eq))   ;; optional try-order? (default #f)
               (result     (ref eq))   ;; list of keys/values

               ;; Check type: must be (ref $Hash)
               (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                   (then (call $raise-argument-error:hash-expected)
                         (unreachable)))

               ;; Dispatch on table type
               (if (ref.test (ref $HashEqMutable) (local.get $ht))
                   (then (return (call ,hasheq-prim (local.get $ht) (local.get $try)))))
               (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                   (then (return (call ,hasheqv-prim (local.get $ht) (local.get $try)))))
               (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                   (then (return (call ,hashequal-prim (local.get $ht) (local.get $try)))))
               (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                   (then (return (call ,hashalw-prim (local.get $ht) (local.get $try)))))
               (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                   (then (return (call ,(if (eq? prim '$hash-keys)
                                           '$hash-keys/generic
                                           '$hash-values/generic)
                                       (local.get $ht)))))
               (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                   (then (return (call ,(if (eq? prim '$hash-keys)
                                           '$hash-keys/generic
                                           '$hash-values/generic)
                                       (local.get $ht)))))
               (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                   (then (return (call ,(if (eq? prim '$hash-keys)
                                           '$hash-keys/generic
                                           '$hash-values/generic)
                                       (local.get $ht)))))
               (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                   (then (return (call ,(if (eq? prim '$hash-keys)
                                           '$hash-keys/generic
                                           '$hash-values/generic)
                                       (local.get $ht)))))
               (unreachable)))))

   (function-forms->runtime-helpers
    'hash-keys-values-runtime-only-helpers
    '(
        (func $hash-keys/generic
              (param $ht (ref eq)) ;; immutable hash table
              (result    (ref eq))
              (local $pos (ref eq))
              (local $acc (ref eq))
              (local.set $pos (call $mutable-hash-iterate-first (local.get $ht)))
              (local.set $acc (global.get $null))
              (block $done
                     (loop $walk
                           (br_if $done (ref.eq (local.get $pos) (global.get $false)))
                           (local.set $acc
                                      (call $cons
                                            (call $mutable-hash-iterate-key
                                                  (local.get $ht)
                                                  (local.get $pos)
                                                  (global.get $missing))
                                            (local.get $acc)))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (local.get $acc))

        (func $hash-values/generic
              (param $ht (ref eq)) ;; immutable hash table
              (result    (ref eq))
              (local $pos (ref eq))
              (local $acc (ref eq))
              (local.set $pos (call $mutable-hash-iterate-first (local.get $ht)))
              (local.set $acc (global.get $null))
              (block $done
                     (loop $walk
                           (br_if $done (ref.eq (local.get $pos) (global.get $false)))
                           (local.set $acc
                                      (call $cons
                                            (call $mutable-hash-iterate-value
                                                  (local.get $ht)
                                                  (local.get $pos)
                                                  (global.get $missing))
                                            (local.get $acc)))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (local.get $acc))))

   (append*
    (for/list ([spec '("keys" "values")] [offset '(0 1)])
      (define name spec)
      (define off offset)
      (define (mk base)
        (string->symbol (format "$~a-~a" base name)))
      (define (mkp base suf)
        (string->symbol (format "~a/~a" (symbol->string (mk base)) suf)))
      (append*
       (for/list ([base  '("hasheq" "hasheqv" "hashequal" "hashalw")]
                  [type  '($HashEqMutable
                           $HashEqvMutable
                           $HashEqualMutable
                           $HashEqualAlwaysMutable)]
                  [raise '($raise-argument-error:hasheq-expected
                           $raise-argument-error:hasheqv-expected
                           $raise-argument-error:hash-expected
                           $raise-argument-error:hashalw-expected)])
         (define fun (mk base))
         (define plain (mkp base "plain"))
         (define checked (mkp base "plain/checked"))
         (list
          (core-runtime-helper
           fun
           (symbol->string fun)
           (lambda ()
             `(func ,fun
                    (param $ht  (ref eq))
                    (param $try (ref eq))
                    (result     (ref eq))

                    (return_call ,plain
                                 (local.get $ht)
                                 (local.get $try)))))

          (core-runtime-helper
           plain
           (symbol->string plain)
           (lambda ()
             `(func ,plain
                    (param $ht  (ref eq))
                    (param $try (ref eq))
                    (result     (ref eq))

                    (local $table (ref ,type))

                    ;; Check that ht is expected table type
                    (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                        (then (call ,raise (local.get $ht))
                              (unreachable)))
                    ;; Decode
                    (local.set $table (ref.cast (ref ,type) (local.get $ht)))
                    ;; Delegate to checked implementation
                    (call ,checked
                          (local.get $table)))))

          (core-runtime-helper
           checked
           (symbol->string checked)
           (lambda ()
             `(func ,checked
                    (param $table (ref ,type))
                    (result       (ref eq))

                    (local $entries  (ref $Array))
                    (local $capacity i32)
                    (local $i        i32)
                    (local $key      (ref eq))
                    (local $val      (ref eq))
                    (local $acc      (ref eq))

                    ;; Initialize locals
                    (local.set $entries  (struct.get ,type $entries (local.get $table)))
                    (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
                    (local.set $i        (i32.const 0))
                    (local.set $acc      (global.get $null))

                    (block $done
                           (loop $loop
                                 (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))

                                 ;; Load key
                                 (local.set $key (array.get $Array
                                                            (local.get $entries)
                                                            (i32.shl (local.get $i) (i32.const 1))))
                                 ;; Skip empty or tombstone slots
                                 (if (ref.eq (local.get $key) (global.get $missing))
                                     (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                           (br $loop)))
                                 (if (ref.eq (local.get $key) (global.get $tombstone))
                                     (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                           (br $loop)))

                                 ,@(if (zero? off)
                                       '()
                                       '((local.set $val (array.get $Array
                                                                    (local.get $entries)
                                                                    (i32.add (i32.shl (local.get $i) (i32.const 1))
                                                                             (i32.const 1))))))
                                 (local.set $acc (call $cons
                                                       ,(if (zero? off)
                                                            '(local.get $key)
                                                            '(local.get $val))
                                                       (local.get $acc)))

                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $loop)))

                    (local.get $acc)))))))))))

;; hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic hash helpers that span mutable and immutable hash kinds.
(define hash-runtime-only-helpers
  (append hash-count-runtime-only-helpers
          hash-list-runtime-only-helpers
          hash-for-each-runtime-only-helpers
          hash-map-runtime-only-helpers
          hash-map/copy-runtime-only-helpers
          hash-filter-runtime-only-helpers
          hash-keys-values-runtime-only-helpers))
