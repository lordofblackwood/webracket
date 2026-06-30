#lang racket

(provide mutable-hash-runtime-only-helpers)

(require "../core-helper.rkt")

;; mutable-hash-constructor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash constructor helpers that still depend on monolithic runtime globals.
(define mutable-hash-constructor-runtime-only-helpers
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

;; mutable-hash-read-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash value lookup helpers.
(define mutable-hash-read-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$raise-hash-ref-key-not-found
     "$raise-hash-ref-key-not-found"
     (lambda ()
       `(func $raise-hash-ref-key-not-found (param $key (ref eq)) (unreachable))))

    (core-runtime-helper
     '$hash-ref
     "$hash-ref"
     (lambda ()
       `(func $hash-ref (type $Prim23)
              (param $ht      (ref eq))   ;; must be a mutable hasheq
              (param $key     (ref eq))
              (param $failure (ref eq))   ;; failure result
              (result         (ref eq))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))
              ;; Mutable or immutable?
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-ref
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-ref
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheq-ref
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-ref
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-ref
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then
                   (return (call $immutable-hash-ref
                                 (local.get $ht)
                                 (local.get $key)
                                 (local.get $failure)))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then
                   (return (call $immutable-hashalw-ref
                                 (local.get $ht)
                                 (local.get $key)
                                 (local.get $failure)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-ref
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (unreachable)))))

   (for/list ([hash-ref       '($hasheq-ref
                                $hasheqv-ref
                                $hashequal-ref
                                $hashalw-ref)]
              [hash-ref/plain '($hasheq-ref/plain
                                $hasheqv-ref/plain
                                $hashequal-ref/plain
                                $hashalw-ref/plain)])
     (core-runtime-helper
      hash-ref
      (symbol->string hash-ref)
      (lambda ()
        `(func ,hash-ref (type $Prim23) ; todo
               (param $ht      (ref eq))     ;; hasheq
               (param $key     (ref eq))     ;; lookup key
               (param $failure (ref eq))     ;; value to return if not found
               (result         (ref eq))

               (return_call ,hash-ref/plain
                            (local.get $ht) (local.get $key) (local.get $failure))))))

   (for/list ([raise-expected '($raise-argument-error:hasheq-expected
                                $raise-argument-error:hasheqv-expected
                                $raise-argument-error:hash-expected
                                $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      raise-expected
      (symbol->string raise-expected)
      (lambda ()
        `(func ,raise-expected (unreachable)))))

   (for/list ([hash-ref/plain         '($hasheq-ref/plain
                                        $hasheqv-ref/plain
                                        $hashequal-ref/plain
                                        $hashalw-ref/plain)]
              [hash-ref/plain/checked '($hasheq-ref/plain/checked
                                        $hasheqv-ref/plain/checked
                                        $hashequal-ref/plain/checked
                                        $hashalw-ref/plain/checked)]
              [type                   '($HashEqMutable
                                        $HashEqvMutable
                                        $HashEqualMutable
                                        $HashEqualAlwaysMutable)]
              [raise-expected         '($raise-argument-error:hasheq-expected
                                        $raise-argument-error:hasheqv-expected
                                        $raise-argument-error:hash-expected
                                        $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-ref/plain
      (symbol->string hash-ref/plain)
      (lambda ()
        `(func ,hash-ref/plain
               (param $ht      (ref eq))     ;; hasheq
               (param $key     (ref eq))     ;; lookup key
               (param $failure (ref eq))     ;; value to return if not found
               (result         (ref eq))

               (local $table (ref ,type))

               ;; Check that ht is a mutable hasheq
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))

               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))

               ;; Delegate to checked implementation
               (call ,hash-ref/plain/checked
                     (local.get $table)
                     (local.get $key)
                     (local.get $failure))))))

   (for/list ([hash-ref/plain/checked '($hasheq-ref/plain/checked
                                        $hasheqv-ref/plain/checked
                                        $hashequal-ref/plain/checked
                                        $hashalw-ref/plain/checked)]
              [type                   '($HashEqMutable
                                        $HashEqvMutable
                                        $HashEqualMutable
                                        $HashEqualAlwaysMutable)]
              [kind                   '(0 1 2 3)])
     (core-runtime-helper
      hash-ref/plain/checked
      (symbol->string hash-ref/plain/checked)
      (lambda ()
        `(func ,hash-ref/plain/checked
               (param $table (ref ,type))
               (param $key   (ref eq))
               (param $fail  (ref eq))
               (result       (ref eq))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $index    i32)
               (local $step     i32)
               (local $hash     i32)
               (local $k        (ref eq))
               (local $slot     i32)
               (local $proc     (ref $Procedure))
               (local $inv      (ref $ProcedureInvoker))
               (local $noargs   (ref $Args))

               ;; Get entries and compute capacity
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               ;; Hash key
               (local.set $hash     (call $hash-key-hash/kind
                                          (i32.const ,kind)
                                          (local.get $key)))
               (local.set $index    (i32.rem_u (local.get $hash) (local.get $capacity)))
               (local.set $step     (i32.const 0))
               (block $not-found
                      (loop $probe
                            ;; Stop probing if we've checked all slots
                            (br_if $not-found (i32.ge_u (local.get $step) (local.get $capacity)))
                            ;; slot = 2 * ((index + step) % capacity)
                            (local.set $slot
                                       (i32.shl
                                        (i32.rem_u
                                         (i32.add (local.get $index) (local.get $step))
                                         (local.get $capacity))
                                        (i32.const 1)))
                            ;; Get key at slot
                            (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
                            ;; Empty slot means not found
                            (br_if $not-found (ref.eq (local.get $k) (global.get $missing)))
                            ;; Tombstone? — skip and continue probing
                            (if (ref.eq (local.get $k) (global.get $tombstone))
                                (then
                                 (local.set $step (i32.add (local.get $step) (i32.const 1)))
                                 (br $probe)))
                            ;; Match? — return value at slot + 1
                            (if (call $hash-key-matches?/kind
                                      (i32.const ,kind)
                                      (local.get $k)
                                      (local.get $key))
                                (then
                                 (return
                                  (array.get $Array
                                             (local.get $entries)
                                             (i32.add (local.get $slot) (i32.const 1))))))
                            ;; Continue probing
                            (local.set $step (i32.add (local.get $step) (i32.const 1)))
                            (br $probe)))
               ;; Not found — handle failure result
               (if (result (ref eq))
                   (ref.eq (local.get $fail) (global.get $missing))
                   (then (call $raise-hash-ref-key-not-found (local.get $key))
                         (unreachable))
                   (else
                    (if (result (ref eq))
                        (ref.test (ref $Procedure) (local.get $fail))
                        (then
                         (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                         (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                         (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                         (return_call_ref $ProcedureInvoker
                                          (local.get $proc)
                                          (local.get $noargs)
                                          (local.get $inv)))
                        (else
                         (local.get $fail)))))))))))

;; mutable-hash-ref-key-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash stored-key lookup helpers.
(define mutable-hash-ref-key-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$hash-ref-key
     "$hash-ref-key"
     (lambda ()
       `;; hash-ref-key : hash? any/c [any/c or (-> any/c)] -> any/c
        ;;   Return the actual stored key that matches a lookup key.
        (func $hash-ref-key (type $Prim23)
              (param $ht      (ref eq)) ;; hash table
              (param $key     (ref eq)) ;; lookup key
              (param $failure (ref eq)) ;; optional failure, default raises
              (result         (ref eq))
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-ref-key
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-ref-key
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheq-ref-key
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-ref-key
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-ref-key
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then (return (call $immutable-hash-ref-key
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then
                   (return (call $immutable-hashalw-ref-key
                                 (local.get $ht)
                                 (local.get $key)
                                 (local.get $failure)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-ref-key
                                      (local.get $ht) (local.get $key) (local.get $failure)))))
              (unreachable)))))

   (for/list ([hash-ref-key       '($hasheq-ref-key
                                    $hasheqv-ref-key
                                    $hashequal-ref-key
                                    $hashalw-ref-key)]
              [hash-ref-key/plain '($hasheq-ref-key/plain
                                    $hasheqv-ref-key/plain
                                    $hashequal-ref-key/plain
                                    $hashalw-ref-key/plain)])
     (core-runtime-helper
      hash-ref-key
      (symbol->string hash-ref-key)
      (lambda ()
        `(func ,hash-ref-key (type $Prim23)
               (param $ht      (ref eq))     ;; hash table
               (param $key     (ref eq))     ;; lookup key
               (param $failure (ref eq))     ;; value/procedure if not found
               (result         (ref eq))

               (return_call ,hash-ref-key/plain
                            (local.get $ht) (local.get $key) (local.get $failure))))))

   (for/list ([hash-ref-key/plain         '($hasheq-ref-key/plain
                                            $hasheqv-ref-key/plain
                                            $hashequal-ref-key/plain
                                            $hashalw-ref-key/plain)]
              [hash-ref-key/plain/checked '($hasheq-ref-key/plain/checked
                                            $hasheqv-ref-key/plain/checked
                                            $hashequal-ref-key/plain/checked
                                            $hashalw-ref-key/plain/checked)]
              [type                       '($HashEqMutable
                                            $HashEqvMutable
                                            $HashEqualMutable
                                            $HashEqualAlwaysMutable)]
              [raise-expected             '($raise-argument-error:hasheq-expected
                                            $raise-argument-error:hasheqv-expected
                                            $raise-argument-error:hash-expected
                                            $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-ref-key/plain
      (symbol->string hash-ref-key/plain)
      (lambda ()
        `(func ,hash-ref-key/plain
               (param $ht      (ref eq))     ;; hash table
               (param $key     (ref eq))     ;; lookup key
               (param $failure (ref eq))     ;; value/procedure if not found
               (result         (ref eq))

               (local $table (ref ,type))

               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))

               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               (call ,hash-ref-key/plain/checked
                     (local.get $table)
                     (local.get $key)
                     (local.get $failure))))))

   (for/list ([hash-ref-key/plain/checked '($hasheq-ref-key/plain/checked
                                            $hasheqv-ref-key/plain/checked
                                            $hashequal-ref-key/plain/checked
                                            $hashalw-ref-key/plain/checked)]
              [type                       '($HashEqMutable
                                            $HashEqvMutable
                                            $HashEqualMutable
                                            $HashEqualAlwaysMutable)]
              [kind                       '(0 1 2 3)])
     (core-runtime-helper
      hash-ref-key/plain/checked
      (symbol->string hash-ref-key/plain/checked)
      (lambda ()
        `(func ,hash-ref-key/plain/checked
               (param $table (ref ,type))
               (param $key   (ref eq))
               (param $fail  (ref eq))
               (result       (ref eq))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $index    i32)
               (local $step     i32)
               (local $hash     i32)
               (local $k        (ref eq))
               (local $slot     i32)
               (local $proc     (ref $Procedure))
               (local $inv      (ref $ProcedureInvoker))
               (local $noargs   (ref $Args))

               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $hash     (call $hash-key-hash/kind
                                          (i32.const ,kind)
                                          (local.get $key)))
               (local.set $index    (i32.rem_u (local.get $hash) (local.get $capacity)))
               (local.set $step     (i32.const 0))
               (block $not-found
                      (loop $probe
                            (br_if $not-found (i32.ge_u (local.get $step) (local.get $capacity)))
                            (local.set $slot
                                       (i32.shl
                                        (i32.rem_u
                                         (i32.add (local.get $index) (local.get $step))
                                         (local.get $capacity))
                                        (i32.const 1)))
                            (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
                            (br_if $not-found (ref.eq (local.get $k) (global.get $missing)))
                            (if (ref.eq (local.get $k) (global.get $tombstone))
                                (then
                                 (local.set $step (i32.add (local.get $step) (i32.const 1)))
                                 (br $probe)))
                            (if (call $hash-key-matches?/kind
                                      (i32.const ,kind)
                                      (local.get $k)
                                      (local.get $key))
                                (then (return (local.get $k))))
                            (local.set $step (i32.add (local.get $step) (i32.const 1)))
                            (br $probe)))
               (if (result (ref eq))
                   (ref.eq (local.get $fail) (global.get $missing))
                   (then (call $raise-hash-ref-key-not-found (local.get $key))
                         (unreachable))
                   (else
                    (if (result (ref eq))
                        (ref.test (ref $Procedure) (local.get $fail))
                        (then
                         (local.set $proc   (ref.cast (ref $Procedure) (local.get $fail)))
                         (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                         (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                         (return_call_ref $ProcedureInvoker
                                          (local.get $proc)
                                          (local.get $noargs)
                                          (local.get $inv)))
                        (else
                         (local.get $fail)))))))))))

;; mutable-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash helpers that still depend on monolithic runtime globals.
(define mutable-hash-runtime-only-helpers
  (append mutable-hash-constructor-runtime-only-helpers
          mutable-hash-read-runtime-only-helpers
          mutable-hash-ref-key-runtime-only-helpers))
