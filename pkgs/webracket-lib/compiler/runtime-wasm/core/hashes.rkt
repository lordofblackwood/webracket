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

;; hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic hash helpers that span mutable and immutable hash kinds.
(define hash-runtime-only-helpers
  (append hash-count-runtime-only-helpers
          hash-list-runtime-only-helpers))
