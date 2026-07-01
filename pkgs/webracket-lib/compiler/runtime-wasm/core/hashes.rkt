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

;; hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic hash helpers that span mutable and immutable hash kinds.
(define hash-runtime-only-helpers
  (append hash-count-runtime-only-helpers
          hash-list-runtime-only-helpers
          hash-for-each-runtime-only-helpers
          hash-map-runtime-only-helpers))
