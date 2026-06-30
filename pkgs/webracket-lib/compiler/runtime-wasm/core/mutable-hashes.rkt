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

;; mutable-hash-write-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash mutation and insertion helpers.
(define mutable-hash-write-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$hash-set!
     "$hash-set!"
     (lambda ()
       `(func $hash-set! (type $Prim3)
              (param $ht  (ref eq))   ;; hash table
              (param $key (ref eq))   ;; key
              (param $val (ref eq))   ;; value
              (result     (ref eq))   ;; return void (an immediate)
              (call $debug-allocation-tick (i32.const 3))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-set!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $val)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-set!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $val)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-set!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $val)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-set!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $val)))))
              (unreachable))))

    (core-runtime-helper
     '$hash-copy
     "$hash-copy"
     (lambda ()
       `;; hash-copy : hash? -> (and/c hash? (not/c immutable?))
        ;;   Return a mutable hash with the same mappings and comparison mode.
        ;;   WebRacket currently models weak/ephemeron tables as strong tables,
        ;;   so key-holding strength is preserved only up to that existing
        ;;   approximation.
        (func $hash-copy (type $Prim1)
              (param $ht (ref eq)) ;; source hash table
              (result    (ref eq))

              (local $dst (ref eq))
              (local $pos (ref eq))
              (local $key (ref eq))
              (local $val (ref eq))

              (local.set $dst (call $make-empty-hash))
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))

              (if (i32.or
                   (ref.test (ref $HashEqMutable) (local.get $ht))
                   (ref.test (ref $HashEqImmutable) (local.get $ht)))
                  (then (local.set $dst (call $make-empty-hasheq)))
                  (else
                   (if (i32.or
                        (ref.test (ref $HashEqvMutable) (local.get $ht))
                        (ref.test (ref $HashEqvImmutable) (local.get $ht)))
                       (then (local.set $dst (call $make-empty-hasheqv)))
                       (else
                        (if (i32.or
                             (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                             (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht)))
                            (then (local.set $dst (call $make-empty-hashalw)))
                            (else (local.set $dst (call $make-empty-hash))))))))

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
                           (drop (call $hash-set!
                                       (local.get $dst)
                                       (local.get $key)
                                       (local.get $val)))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (local.get $dst)))))

   (for/list ([hash-set       '($hasheq-set!
                                $hasheqv-set!
                                $hashequal-set!
                                $hashalw-set!)]
              [set!/checked   '($hasheq-set!/mutable/checked
                                $hasheqv-set!/mutable/checked
                                $hash-set!/mutable/checked
                                $hashalw-set!/mutable/checked)]
              [type           '($HashEqMutable
                                $HashEqvMutable
                                $HashEqualMutable
                                $HashEqualAlwaysMutable)]
              [raise-expected '($raise-argument-error:mutable-hasheq-expected
                                $raise-argument-error:mutable-hasheqv-expected
                                $raise-argument-error:mutable-hash-expected
                                $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      hash-set
      (symbol->string hash-set)
      (lambda ()
        `(func ,hash-set (type $Prim3)
               (param $ht  (ref eq))   ;; table
               (param $key (ref eq))   ;; key
               (param $val (ref eq))   ;; value
               (result     (ref eq))   ;; return void

               (local $table (ref ,type))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               ;; Delegate
               (call ,set!/checked
                     (local.get $table)
                     (local.get $key)
                     (local.get $val))
               ; return void
               (global.get $void)))))

   (for/list ([raise-expected '($raise-argument-error:mutable-hasheq-expected
                                $raise-argument-error:mutable-hasheqv-expected
                                $raise-argument-error:mutable-hash-expected
                                $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      raise-expected
      (symbol->string raise-expected)
      (lambda ()
        `(func ,raise-expected (unreachable)))))

   (list
    (core-runtime-helper
     '$raise-hash-insert:table-full
     "$raise-hash-insert:table-full"
     (lambda ()
       `(func $raise-hash-insert:table-full (unreachable))))

    (core-runtime-helper
     '$hash-kind/i32
     "$hash-kind/i32"
     (lambda ()
       `;; hash-kind/i32 : hash? -> i32
        ;;   Return 0 eq?, 1 eqv?, 2 equal?, or 3 equal-always?.
        (func $hash-kind/i32
              (param $ht (ref eq))
              (result i32)

              (if (i32.or (ref.test (ref $HashEqMutable) (local.get $ht))
                          (ref.test (ref $HashEqImmutable) (local.get $ht)))
                  (then (return (i32.const 0))))
              (if (i32.or (ref.test (ref $HashEqvMutable) (local.get $ht))
                          (ref.test (ref $HashEqvImmutable) (local.get $ht)))
                  (then (return (i32.const 1))))
              (if (i32.or (ref.test (ref $HashEqualMutable) (local.get $ht))
                          (ref.test (ref $HashEqualImmutable) (local.get $ht)))
                  (then (return (i32.const 2))))
              (if (i32.or (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                          (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht)))
                  (then (return (i32.const 3))))
              (unreachable))))

    (core-runtime-helper
     '$hash-mutable?/i32
     "$hash-mutable?/i32"
     (lambda ()
       `;; hash-mutable?/i32 : hash? -> i32
        ;;   Check whether the concrete hash table is mutable.
        (func $hash-mutable?/i32
              (param $ht (ref eq))
              (result i32)

              (i32.or
               (i32.or (ref.test (ref $HashEqMutable) (local.get $ht))
                       (ref.test (ref $HashEqvMutable) (local.get $ht)))
               (i32.or (ref.test (ref $HashEqualMutable) (local.get $ht))
                       (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht)))))))

    (core-runtime-helper
     '$hash-key-hash/kind
     "$hash-key-hash/kind"
     (lambda ()
       `;; hash-key-hash/kind : i32 any/c -> i32
        ;;   Compute the mutable hash-table probe hash for kind:
        ;;   0 eq?, 1 eqv?, 2 equal?, 3 equal-always?.
        (func $hash-key-hash/kind
              (param $kind i32)
              (param $key  (ref eq))
              (result i32)

              (if (i32.eq (local.get $kind) (i32.const 0))
                  (then (return (call $eq-hash/i32 (local.get $key)))))
              (if (i32.eq (local.get $kind) (i32.const 1))
                  (then (return (call $eqv-hash/i32 (local.get $key)))))
              (if (i32.eq (local.get $kind) (i32.const 2))
                  (then (return (call $equal-hash/i32 (local.get $key)))))
              (call $equal-always-hash/i32 (local.get $key)))))

    (core-runtime-helper
     '$hash-key-matches?/kind
     "$hash-key-matches?/kind"
     (lambda ()
       `;; hash-key-matches?/kind : i32 any/c any/c -> i32
        ;;   Check mutable hash-table key equality for the same kind mapping
        ;;   used by hash-key-hash/kind.
        (func $hash-key-matches?/kind
              (param $kind i32)
              (param $a    (ref eq))
              (param $b    (ref eq))
              (result i32)

              (if (i32.eq (local.get $kind) (i32.const 0))
                  (then (return (ref.eq (local.get $a) (local.get $b)))))
              (if (i32.eq (local.get $kind) (i32.const 1))
                  (then (return (ref.eq (call $eqv?
                                              (local.get $a)
                                              (local.get $b))
                                        (global.get $true)))))
              (if (i32.eq (local.get $kind) (i32.const 2))
                  (then (return (ref.eq (call $equal?
                                              (local.get $a)
                                              (local.get $b))
                                        (global.get $true)))))
              (ref.eq (call $equal-always?
                            (local.get $a)
                            (local.get $b))
                      (global.get $true))))))

   (for/list ([set!/checked '($hasheq-set!/mutable/checked
                              $hasheqv-set!/mutable/checked
                              $hash-set!/mutable/checked
                              $hashalw-set!/mutable/checked)]
              [make-empty   '($make-empty-hasheq
                              $make-empty-hasheqv
                              $make-empty-hash
                              $make-empty-hashalw)]
              [type         '($HashEqMutable
                              $HashEqvMutable
                              $HashEqualMutable
                              $HashEqualAlwaysMutable)]
              [maybe-resize '($maybe-resize-hasheq
                              $maybe-resize-hasheqv
                              $maybe-resize-hashequal
                              $maybe-resize-hashalw)]
              [kind         '(0 1 2 3)])
     (core-runtime-helper
      set!/checked
      (symbol->string set!/checked)
      (lambda ()
        `(func ,set!/checked
               (param $table (ref ,type))
               (param $key   (ref eq))
               (param $val   (ref eq))

               (local $entries         (ref $Array))
               (local $capacity        i32)
               (local $hash            i32)
               (local $index           i32)
               (local $step            i32)
               (local $slot            i32)
               (local $k               (ref eq))
               (local $first-tombstone i32)

               ;; Maybe resize
               (call ,maybe-resize (local.get $table))
               ;; Get entries and capacity
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               ;; Compute initial hash/index
               (local.set $hash  (call $hash-key-hash/kind
                                       (i32.const ,kind)
                                       (local.get $key)))
               (local.set $index (i32.rem_u (local.get $hash) (local.get $capacity)))
               (local.set $step  (i32.const 0))
               ;; No tombstone seen yet
               (local.set $first-tombstone (i32.const -1))
               (block $done
                      (block $full
                             (loop $probe
                                   (br_if $full (i32.ge_u (local.get $step) (local.get $capacity)))
                                   ;; Compute probe slot = 2 * ((index + step) % capacity)
                                   (local.set $slot (i32.shl
                                                     (i32.rem_u (i32.add (local.get $index) (local.get $step))
                                                                (local.get $capacity))
                                                     (i32.const 1)))
                                   ;; Load key at slot
                                   (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
                                   ;; First tombstone — record slot
                                   (if (ref.eq (local.get $k) (global.get $tombstone))
                                       (then (if (i32.eq (local.get $first-tombstone) (i32.const -1))
                                                 (then (local.set $first-tombstone (local.get $slot))))))
                                   ;; Empty — insert into tombstone if available, else here
                                   (if (ref.eq (local.get $k) (global.get $missing))
                                       (then
                                        (local.set $slot
                                                   (select
                                                    (local.get $slot)
                                                    (local.get $first-tombstone)
                                                    (i32.eq (local.get $first-tombstone) (i32.const -1))))

                                        (array.set $Array (local.get $entries) (local.get $slot) (local.get $key))
                                        (array.set $Array
                                                   (local.get $entries)
                                                   (i32.add (local.get $slot) (i32.const 1))
                                                   (local.get $val))
                                        (struct.set ,type $count
                                                    (local.get $table)
                                                    (i32.add (struct.get ,type $count (local.get $table)) (i32.const 1)))
                                        (br $done)))
                                   ;; Key match — overwrite value
                                   (if (call $hash-key-matches?/kind
                                             (i32.const ,kind)
                                             (local.get $k)
                                             (local.get $key))
                                       (then
                                        (array.set $Array
                                                   (local.get $entries)
                                                   (i32.add (local.get $slot) (i32.const 1))
                                                   (local.get $val))
                                        (br $done)))
                                   ;; Next probe
                                   (local.set $step (i32.add (local.get $step) (i32.const 1)))
                                   (br $probe)))
                      ;; Table full — but insert into tombstone if one was found
                      (if (i32.ne (local.get $first-tombstone) (i32.const -1))
                          (then
                           (local.set $slot  (local.get $first-tombstone))
                           (array.set $Array (local.get $entries) (local.get $slot) (local.get $key))
                           (array.set $Array (local.get $entries)
                                      (i32.add (local.get $slot) (i32.const 1))
                                      (local.get $val))
                           (struct.set ,type $count
                                       (local.get $table)
                                       (i32.add (struct.get ,type $count (local.get $table))
                                                (i32.const 1)))
                           (br $done)))

                      (call $raise-hash-insert:table-full))))))))

;; mutable-hash-ref-bang-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash lookup-or-insert helpers.
(define mutable-hash-ref-bang-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$hash-ref!
     "$hash-ref!"
     (lambda ()
       `(func $hash-ref! (type $Prim3)
              (param $ht     (ref eq))  ;; hash table
              (param $key    (ref eq))  ;; lookup key
              (param $to-set (ref eq))  ;; value to insert when missing (optional, default = raises error)
              (result        (ref eq))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-ref!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $to-set)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-ref!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $to-set)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-ref!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $to-set)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-ref!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $to-set)))))
              (unreachable)))))

   (for/list ([hash-ref!       '($hasheq-ref!
                                 $hasheqv-ref!
                                 $hashequal-ref!
                                 $hashalw-ref!)]
              [hash-ref!/plain '($hasheq-ref!/plain
                                 $hasheqv-ref!/plain
                                 $hashequal-ref!/plain
                                 $hashalw-ref!/plain)])
     (core-runtime-helper
      hash-ref!
      (symbol->string hash-ref!)
      (lambda ()
        `(func ,hash-ref!
               (param $ht     (ref eq))  ;; hash table
               (param $key    (ref eq))  ;; lookup key
               (param $to-set (ref eq))  ;; value to insert when missing (optional, default = raises error)
               (result        (ref eq))

               (return_call ,hash-ref!/plain
                            (local.get $ht)
                            (local.get $key)
                            (local.get $to-set))))))

   (for/list ([hash-ref!/plain         '($hasheq-ref!/plain
                                         $hasheqv-ref!/plain
                                         $hashequal-ref!/plain
                                         $hashalw-ref!/plain)]
              [hash-ref!/plain/checked '($hasheq-ref!/plain/checked
                                         $hasheqv-ref!/plain/checked
                                         $hashequal-ref!/plain/checked
                                         $hashalw-ref!/plain/checked)]
              [type                     '($HashEqMutable
                                          $HashEqvMutable
                                          $HashEqualMutable
                                          $HashEqualAlwaysMutable)]
              [raise-expected           '($raise-argument-error:mutable-hasheq-expected
                                          $raise-argument-error:mutable-hasheqv-expected
                                          $raise-argument-error:mutable-hash-expected
                                          $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      hash-ref!/plain
      (symbol->string hash-ref!/plain)
      (lambda ()
        `(func ,hash-ref!/plain
               (param $ht     (ref eq))  ;; hash table
               (param $key    (ref eq))  ;; lookup key
               (param $to-set (ref eq))  ;; value to insert when missing (optional, default = raises error)
               (result        (ref eq))

               (local $table (ref ,type))

               ;; Check that ht is the expected mutable hash table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))

               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))

               ;; Delegate to checked implementation
               (call ,hash-ref!/plain/checked
                     (local.get $table)
                     (local.get $key)
                     (local.get $to-set))))))

   (for/list ([hash-ref!/plain/checked '($hasheq-ref!/plain/checked
                                         $hasheqv-ref!/plain/checked
                                         $hashequal-ref!/plain/checked
                                         $hashalw-ref!/plain/checked)]
              [type                     '($HashEqMutable
                                          $HashEqvMutable
                                          $HashEqualMutable
                                          $HashEqualAlwaysMutable)]
              [set!/checked             '($hasheq-set!/mutable/checked
                                          $hasheqv-set!/mutable/checked
                                          $hash-set!/mutable/checked
                                          $hashalw-set!/mutable/checked)]
              [kind                     '(0 1 2 3)])
     (core-runtime-helper
      hash-ref!/plain/checked
      (symbol->string hash-ref!/plain/checked)
      (lambda ()
        `(func ,hash-ref!/plain/checked
               (param $table  (ref ,type))
               (param $key    (ref eq))
               (param $to-set (ref eq))  ;; value to insert when missing (optional, default = raises error)
               (result        (ref eq))

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
               (local $value    (ref eq))

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

               ;; Missing entry — compute value to insert
               (if (ref.eq (local.get $to-set) (global.get $missing))
                   (then (call $raise-hash-ref-key-not-found (local.get $key))
                         (unreachable)))

               (local.set $value
                          (if (result (ref eq))
                              (ref.test (ref $Procedure) (local.get $to-set))
                              (then
                               (local.set $proc   (ref.cast (ref $Procedure) (local.get $to-set)))
                               (local.set $inv    (struct.get $Procedure $invoke (local.get $proc)))
                               (local.set $noargs (array.new $Args (global.get $null) (i32.const 0)))
                               (call_ref $ProcedureInvoker
                                         (local.get $proc)
                                         (local.get $noargs)
                                         (local.get $inv)))
                              (else
                               (local.get $to-set))))

               ;; Insert computed value and return it
               (call ,set!/checked (local.get $table) (local.get $key) (local.get $value))
               (local.get $value)))))))

;; mutable-hash-update-bang-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash update helpers.
(define mutable-hash-update-bang-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$hash-update!
     "$hash-update!"
     (lambda ()
       `(func $hash-update! (type $Prim34)
              (param $ht   (ref eq))   ;; hash table
              (param $key  (ref eq))   ;; key
              (param $proc (ref eq))   ;; updater procedure
              (param $fail (ref eq))   ;; optional failure result (default = raises error)
              (result      (ref eq))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))

              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-update!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $proc)
                                      (local.get $fail)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-update!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $proc)
                                      (local.get $fail)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-update!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $proc)
                                      (local.get $fail)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-update!
                                      (local.get $ht)
                                      (local.get $key)
                                      (local.get $proc)
                                      (local.get $fail)))))
              (unreachable)))))

   (for/list ([hash-update       '($hasheq-update!
                                   $hasheqv-update!
                                   $hashequal-update!
                                   $hashalw-update!)]
              [hash-update/plain '($hasheq-update!/plain
                                   $hasheqv-update!/plain
                                   $hashequal-update!/plain
                                   $hashalw-update!/plain)])
     (core-runtime-helper
      hash-update
      (symbol->string hash-update)
      (lambda ()
        `(func ,hash-update #;(type $Prim34) ;todo
               (param $ht   (ref eq))
               (param $key  (ref eq))
               (param $proc (ref eq))
               (param $fail (ref eq))
               (result      (ref eq))

               (return_call ,hash-update/plain
                            (local.get $ht)
                            (local.get $key)
                            (local.get $proc)
                            (local.get $fail))))))

   (for/list ([hash-update/plain         '($hasheq-update!/plain
                                           $hasheqv-update!/plain
                                           $hashequal-update!/plain
                                           $hashalw-update!/plain)]
              [hash-update/plain/checked '($hasheq-update!/plain/checked
                                           $hasheqv-update!/plain/checked
                                           $hashequal-update!/plain/checked
                                           $hashalw-update!/plain/checked)]
              [type                      '($HashEqMutable
                                           $HashEqvMutable
                                           $HashEqualMutable
                                           $HashEqualAlwaysMutable)]
              [raise-expected            '($raise-argument-error:mutable-hasheq-expected
                                           $raise-argument-error:mutable-hasheqv-expected
                                           $raise-argument-error:mutable-hash-expected
                                           $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      hash-update/plain
      (symbol->string hash-update/plain)
      (lambda ()
        `(func ,hash-update/plain
               (param $ht   (ref eq))
               (param $key  (ref eq))
               (param $proc (ref eq))
               (param $fail (ref eq))
               (result      (ref eq))

               (local $table (ref ,type))
               (local $f     (ref $Procedure))

               ;; Check that ht is the expected mutable hash table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))

               ;; Ensure updater is a procedure
               (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                   (then (call $raise-argument-error:procedure-expected (local.get $proc))
                         (unreachable)))

               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               (local.set $f     (ref.cast (ref $Procedure) (local.get $proc)))

               ;; Delegate to checked implementation
               (call ,hash-update/plain/checked
                     (local.get $table)
                     (local.get $key)
                     (local.get $f)
                     (local.get $fail))))))

   (for/list ([hash-update/plain/checked '($hasheq-update!/plain/checked
                                           $hasheqv-update!/plain/checked
                                           $hashequal-update!/plain/checked
                                           $hashalw-update!/plain/checked)]
              [type                      '($HashEqMutable
                                           $HashEqvMutable
                                           $HashEqualMutable
                                           $HashEqualAlwaysMutable)]
              [set!/checked              '($hasheq-set!/mutable/checked
                                           $hasheqv-set!/mutable/checked
                                           $hash-set!/mutable/checked
                                           $hashalw-set!/mutable/checked)]
              [kind                      '(0 1 2 3)])
     (core-runtime-helper
      hash-update/plain/checked
      (symbol->string hash-update/plain/checked)
      (lambda ()
        `(func ,hash-update/plain/checked
               (param $table (ref ,type))
               (param $key   (ref eq))
               (param $proc  (ref $Procedure))
               (param $fail  (ref eq))
               (result       (ref eq))

               (local $entries   (ref $Array))
               (local $capacity  i32)
               (local $hash      i32)
               (local $index     i32)
               (local $step      i32)
               (local $slot      i32)
               (local $k         (ref eq))
               (local $old-value (ref eq))
               (local $new-value (ref eq))
               (local $default   (ref eq))
               (local $finv      (ref $ProcedureInvoker))
               (local $args      (ref $Args))
               (local $fail-proc (ref $Procedure))
               (local $fail-inv  (ref $ProcedureInvoker))
               (local $noargs    (ref $Args))

               ;; Initialize locals used across branches
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $finv    (struct.get $Procedure $invoke (local.get $proc)))
               (local.set $args    (array.new $Args (global.get $null) (i32.const 1)))

               ;; Hash key
               (local.set $hash  (call $hash-key-hash/kind
                                       (i32.const ,kind)
                                       (local.get $key)))
               (local.set $index (i32.rem_u (local.get $hash) (local.get $capacity)))
               (local.set $step  (i32.const 0))
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
                            ;; Match? — compute new value and overwrite existing entry
                            (if (call $hash-key-matches?/kind
                                      (i32.const ,kind)
                                      (local.get $k)
                                      (local.get $key))
                                (then
                                 (local.set $old-value
                                            (array.get $Array
                                                       (local.get $entries)
                                                       (i32.add (local.get $slot) (i32.const 1))))
                                 (array.set $Args (local.get $args) (i32.const 0) (local.get $old-value))
                                 (local.set $new-value
                                            (call_ref $ProcedureInvoker
                                                      (local.get $proc)
                                                      (local.get $args)
                                                      (local.get $finv)))
                                 (array.set $Array
                                            (local.get $entries)
                                            (i32.add (local.get $slot) (i32.const 1))
                                            (local.get $new-value))
                                 (return (global.get $void))))
                            ;; Continue probing
                            (local.set $step (i32.add (local.get $step) (i32.const 1)))
                            (br $probe)))

               ;; Missing entry — compute default
               (if (ref.eq (local.get $fail) (global.get $missing))
                   (then (call $raise-hash-ref-key-not-found (local.get $key))
                         (unreachable)))

               (local.set $default
                          (if (result (ref eq))
                              (ref.test (ref $Procedure) (local.get $fail))
                              (then
                               (local.set $fail-proc (ref.cast (ref $Procedure) (local.get $fail)))
                               (local.set $fail-inv  (struct.get $Procedure $invoke (local.get $fail-proc)))
                               (local.set $noargs    (array.new $Args (global.get $null) (i32.const 0)))
                               (call_ref $ProcedureInvoker
                                         (local.get $fail-proc)
                                         (local.get $noargs)
                                         (local.get $fail-inv)))
                              (else
                               (local.get $fail))))

               ;; Apply updater to default and insert mapping
               (array.set $Args (local.get $args) (i32.const 0) (local.get $default))
               (local.set $new-value
                          (call_ref $ProcedureInvoker
                                    (local.get $proc)
                                    (local.get $args)
                                    (local.get $finv)))

               (call ,set!/checked
                     (local.get $table)
                     (local.get $key)
                     (local.get $new-value))

               (global.get $void)))))))

;; mutable-hash-remove-bang-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash removal helpers.
(define mutable-hash-remove-bang-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$raise-argument-error:hasheq-mutable-expected
     "$raise-argument-error:hasheq-mutable-expected"
     (lambda ()
       `(func $raise-argument-error:hasheq-mutable-expected (unreachable))))

    (core-runtime-helper
     '$hash-remove!
     "$hash-remove!"
     (lambda ()
       `(func $hash-remove! (type $Prim2)
              (param $ht  (ref eq))
              (param $key (ref eq))
              (result     (ref eq))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error:hash-expected)
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-remove!
                                      (local.get $ht) (local.get $key)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-remove!
                                      (local.get $ht) (local.get $key)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-remove!
                                      (local.get $ht) (local.get $key)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-remove!
                                      (local.get $ht) (local.get $key)))))
              (unreachable)))))

   (for/list ([hash-remove    '($hasheq-remove!
                                $hasheqv-remove!
                                $hashequal-remove!
                                $hashalw-remove!)]
              [remove!/checked '($hasheq-remove!/mutable/checked
                                 $hasheqv-remove!/mutable/checked
                                 $hash-remove!/mutable/checked
                                 $hashalw-remove!/mutable/checked)]
              [type            '($HashEqMutable
                                 $HashEqvMutable
                                 $HashEqualMutable
                                 $HashEqualAlwaysMutable)]
              [raise-expected  '($raise-argument-error:mutable-hasheq-expected
                                 $raise-argument-error:mutable-hasheqv-expected
                                 $raise-argument-error:mutable-hash-expected
                                 $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      hash-remove
      (symbol->string hash-remove)
      (lambda ()
        `(func ,hash-remove
               (param $ht  (ref eq))
               (param $key (ref eq))
               (result     (ref eq))

               (local $table (ref ,type))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               ;; Delegate
               (call ,remove!/checked (local.get $table) (local.get $key))
               ;; Return void
               (global.get $void)))))

   (for/list ([remove!/checked '($hasheq-remove!/mutable/checked
                                 $hasheqv-remove!/mutable/checked
                                 $hash-remove!/mutable/checked
                                 $hashalw-remove!/mutable/checked)]
              [type            '($HashEqMutable
                                 $HashEqvMutable
                                 $HashEqualMutable
                                 $HashEqualAlwaysMutable)]
              [kind            '(0 1 2 3)])
     (core-runtime-helper
      remove!/checked
      (symbol->string remove!/checked)
      (lambda ()
        `(func ,remove!/checked
               ;; Note: (global $tombstone) must be different from valid keys and $missing.
               (param $ht  (ref ,type))
               (param $key (ref eq))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $hash     i32)
               (local $index    i32)
               (local $step     i32)
               (local $k        (ref eq))
               (local $slot     i32)

               ;; Get entries and capacity
               (local.set $entries  (struct.get ,type $entries (local.get $ht)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               ;; Compute hash and initial index
               (local.set $hash  (call $hash-key-hash/kind
                                       (i32.const ,kind)
                                       (local.get $key)))
               (local.set $index (i32.rem_u (local.get $hash) (local.get $capacity)))
               (local.set $step  (i32.const 0))
               ;; Probe loop
               (block $done
                      (loop $probe
                            ;; Stop if probing exceeds capacity
                            (br_if $done (i32.ge_u (local.get $step) (local.get $capacity)))
                            ;; Compute probe slot (2 * index)
                            (local.set $slot (i32.shl
                                              (i32.rem_u (i32.add (local.get $index) (local.get $step))
                                                         (local.get $capacity))
                                              (i32.const 1)))
                            ;; Load key from slot
                            (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
                            ;; Stop if slot is missing
                            (br_if $done (ref.eq (local.get $k) (global.get $missing)))
                            ;; If key matches, remove
                            (if (call $hash-key-matches?/kind
                                      (i32.const ,kind)
                                      (local.get $k)
                                      (local.get $key))
                                (then
                                 ;; Replace key and value with tombstone
                                 (array.set $Array (local.get $entries) (local.get $slot) (global.get $tombstone))
                                 (array.set $Array (local.get $entries)
                                            (i32.add (local.get $slot) (i32.const 1))
                                            (global.get $tombstone))
                                 ;; Decrement count
                                 (struct.set ,type $count
                                             (local.get $ht)
                                             (i32.sub (struct.get ,type $count (local.get $ht))
                                                      (i32.const 1)))
                                 (br $done)))
                            ;; Step to next slot
                            (local.set $step (i32.add (local.get $step) (i32.const 1)))
                            (br $probe)))))))))

;; mutable-hash-resize-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash resize helpers.
(define mutable-hash-resize-runtime-only-helpers
  (append
   (for/list ([type         '($HashEqMutable
                              $HashEqvMutable
                              $HashEqualMutable
                              $HashEqualAlwaysMutable)]
              [resize       '($hasheq-resize
                              $hasheqv-resize
                              $hashequal-resize
                              $hashalw-resize)]
              [set!/checked '($hasheq-set!/mutable/checked
                              $hasheqv-set!/mutable/checked
                              $hash-set!/mutable/checked
                              $hashalw-set!/mutable/checked)])
     (core-runtime-helper
      resize
      (symbol->string resize)
      (lambda ()
        `(func ,resize
               (param $table (ref ,type))

               (local $old-entries (ref $Array))
               (local $old-cap     i32)
               (local $new-cap     i32)
               (local $new-array   (ref $Array))
               (local $i           i32)
               (local $len         i32)
               (local $key         (ref eq))
               (local $val         (ref eq))

               ;; Get old table size and entries
               (local.set $old-entries (struct.get ,type $entries (local.get $table)))
               (local.set $old-cap     (i32.div_u (array.len (local.get $old-entries)) (i32.const 2)))
               (local.set $new-cap     (i32.mul (local.get $old-cap) (i32.const 2)))
               ;; Allocate new entries array (2 * new-capacity), all set to $missing
               (local.set $new-array (array.new $Array (global.get $missing)
                                                (i32.mul (local.get $new-cap) (i32.const 2))))
               ;; Replace storage in-place and reset metadata
               (struct.set ,type $entries (local.get $table) (local.get $new-array))
               (struct.set ,type $count   (local.get $table) (i32.const 0))
               ;; Reinsert valid key-value pairs
               (local.set $i   (i32.const 0))
               (local.set $len (array.len (local.get $old-entries)))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                            ;; Load key and value
                            (local.set $key (array.get $Array (local.get $old-entries) (local.get $i)))
                            (local.set $val (array.get $Array (local.get $old-entries)
                                                       (i32.add (local.get $i) (i32.const 1))))
                            ;; Reinsert only if key is not $missing or $tombstone
                            (if (i32.eqz (ref.eq (local.get $key) (global.get $missing)))
                                (then (if (i32.eqz (ref.eq (local.get $key) (global.get $tombstone)))
                                          (then
                                           (call ,set!/checked
                                                 (local.get $table)
                                                 (local.get $key)
                                                 (local.get $val))))))
                            ;; Next pair
                            (local.set $i (i32.add (local.get $i) (i32.const 2)))
                            (br $loop)))))))

   (for/list ([type         '($HashEqMutable
                              $HashEqvMutable
                              $HashEqualMutable
                              $HashEqualAlwaysMutable)]
              [resize       '($hasheq-resize
                              $hasheqv-resize
                              $hashequal-resize
                              $hashalw-resize)]
              [maybe-resize '($maybe-resize-hasheq
                              $maybe-resize-hasheqv
                              $maybe-resize-hashequal
                              $maybe-resize-hashalw)])
     (core-runtime-helper
      maybe-resize
      (symbol->string maybe-resize)
      (lambda ()
        `(func ,maybe-resize
               (param $table (ref ,type))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $count    i32)
               ;; Get fields
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $count    (struct.get ,type $count (local.get $table)))
               ;; Resize if count ≥ capacity / 2
               (if (i32.ge_u (local.get $count)
                             (i32.shr_u (local.get $capacity) (i32.const 1)))
                   (then (call ,resize (local.get $table))))))))))

;; mutable-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash helpers that still depend on monolithic runtime globals.
(define mutable-hash-runtime-only-helpers
  (append mutable-hash-constructor-runtime-only-helpers
          mutable-hash-read-runtime-only-helpers
          mutable-hash-ref-key-runtime-only-helpers
          mutable-hash-write-runtime-only-helpers
          mutable-hash-ref-bang-runtime-only-helpers
          mutable-hash-update-bang-runtime-only-helpers
          mutable-hash-remove-bang-runtime-only-helpers
          mutable-hash-resize-runtime-only-helpers))
