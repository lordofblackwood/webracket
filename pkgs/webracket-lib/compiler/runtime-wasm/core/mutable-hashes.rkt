#lang racket

(provide mutable-hash-runtime-only-helpers)

(require "../core-helper.rkt")

;; mutable-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash helpers that still depend on monolithic runtime globals.
(define mutable-hash-runtime-only-helpers
  (append
   ;; Racket contains quite a few types of hash tables.
   ;;
   ;;   eq?/eqv?/equal?/equal-always?    mutable/immutable    strong/weak/ephemerons
   ;;
   ;; Currently `webracket` supports mutable, strong hash tables only.

   ;; We'll use an open-addressing hash table with linear probing for simplicity.
   ;; A load of 50% leads to fast lookup - but uses some more memory.
   ;;
   ;; Theory: https://thenumb.at/Hashtables/
   (for/list ([name '($make-empty-hasheq
                      $make-empty-hasheqv
                      $make-empty-hash
                      $make-empty-hashalw)]
              [type '($HashEqMutable
                      $HashEqvMutable
                      $HashEqualMutable
                      $HashEqualAlwaysMutable)])
     (core-runtime-helper
      name
      (symbol->string name)
      (lambda ()
        `(func ,name (type $Prim0)
               (result (ref eq))  ; an (ref $HashEqMutable)

               (local $entries (ref $Array))
               ;; Step 1: Allocate an array with 2 × capacity (key/value pairs)
               ;; Capacity = 16 entries → 32 elements
               (local.set $entries
                          (array.new $Array (global.get $missing) (i32.const 32)))
               ;; Step 2: Construct and return the hashtable struct
               (struct.new ,type
                           (i32.const 0)                 ;; hash = 0 (placeholder or unused)
                           (global.get $true)            ;; mutable? = #t
                           (local.get $entries)          ;; entries array
                           (i32.const 0))))))            ;; count = 0

   (list
    (core-runtime-helper
     '$raise-argument-error:pair-expected
     "$raise-argument-error:pair-expected"
     (lambda ()
       `(func $raise-argument-error:pair-expected (unreachable))))

    (core-runtime-helper
     '$raise-argument-error:pair-expected1
     "$raise-argument-error:pair-expected1"
     (lambda ()
       `(func $raise-argument-error:pair-expected1 (unreachable))))

    (core-runtime-helper
     '$raise-argument-error:pair-expected2
     "$raise-argument-error:pair-expected2"
     (lambda ()
       `(func $raise-argument-error:pair-expected2 (unreachable)))))

   (for/list ([make-hash '($make-hasheq
                           $make-hasheqv
                           $make-hash
                           $make-hashalw)]
              [make-empty '($make-empty-hasheq
                            $make-empty-hasheqv
                            $make-empty-hash
                            $make-empty-hashalw)]
              [type '($HashEqMutable
                      $HashEqvMutable
                      $HashEqualMutable
                      $HashEqualAlwaysMutable)]
              [set!/checked '($hasheq-set!/mutable/checked
                              $hasheqv-set!/mutable/checked
                              $hash-set!/mutable/checked
                              $hashalw-set!/mutable/checked)])
     (core-runtime-helper
      make-hash
      (symbol->string make-hash)
      (lambda ()
        `(func ,make-hash (type $Prim01) ; (make-hasheq [assocs])   - optional default null
               (param $assocs (ref eq))   ;; Either $missing or an alist of key/value pairs
               (result        (ref eq))   ;; an (ref $HashEqMutable)

               (local $alist (ref eq))
               (local $pair  (ref $Pair))
               (local $key   (ref eq))
               (local $val   (ref eq))
               (local $first (ref eq)) ; of the alist
               (local $rest  (ref eq)) ; of the alist
               (local $ht    (ref ,type))

               ;; Case 1: No argument => make empty table
               (if (ref.eq (local.get $assocs) (global.get $missing))
                   (then (return (call ,make-empty))))
               ;; Case 2: Provided association list
               (local.set $ht    (ref.cast (ref ,type)
                                           (call ,make-empty)))
               (local.set $alist (local.get $assocs))

               (block $done
                      (loop $walk
                            ;; Stop when list is null
                            (br_if $done (ref.eq (local.get $alist) (global.get $null)))
                            ;; Must be a pair
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $alist)))
                                (then (call $raise-argument-error:pair-expected1 (local.get $alist)) (unreachable)))
                            (local.set $pair (ref.cast (ref $Pair) (local.get $alist)))
                            ;; Extract car and cdr of current pair
                            (local.set $first (struct.get $Pair $a (local.get $pair))) ;; first = key/value pair
                            (local.set $rest  (struct.get $Pair $d (local.get $pair))) ;; rest  = remaining pairings
                            ;; Validate first is a pair (key . value)
                            (if (i32.eqz (ref.test (ref $Pair) (local.get $first)))
                                (then (call $raise-argument-error:pair-expected2 (local.get $first)) (unreachable)))
                            ;; Extract key and value from nested pair
                            (local.set $pair (ref.cast (ref $Pair) (local.get $first)))
                            (local.set $key  (struct.get $Pair $a (local.get $pair))) ;; key
                            (local.set $val  (struct.get $Pair $d (local.get $pair))) ;; value
                            ;; Insert into table
                            (call ,set!/checked (local.get $ht) (local.get $key) (local.get $val))
                            ;; Move to next element in alist
                            (local.set $alist (local.get $rest))
                            (br $walk)))
               (local.get $ht)))))))
