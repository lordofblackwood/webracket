#lang racket

(provide mutable-hash-constructor-runtime-only-helper-names
         mutable-hash-pair-error-runtime-only-helper-names
         mutable-hash-association-constructor-runtime-only-helper-names
         mutable-hash-constructor-runtime-helper-forms
         mutable-hash-read-runtime-helper-forms
         mutable-hash-write-runtime-helper-forms
         mutable-hash-update-runtime-helper-forms
         mutable-hash-remove-membership-clear-runtime-helper-forms
         mutable-hash-empty-iteration-runtime-helper-forms
         mutable-hash-core-runtime-helpers
         mutable-hash-runtime-only-helpers)

(require "../core-helper.rkt")

;; mutable-hash-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for empty mutable hash constructors.
(define mutable-hash-constructor-runtime-only-helper-names
  '($make-empty-hasheq
    $make-empty-hasheqv
    $make-empty-hash
    $make-empty-hashalw))

;; mutable-hash-pair-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for mutable hash association-list errors.
(define mutable-hash-pair-error-runtime-only-helper-names
  '($raise-argument-error:pair-expected
    $raise-argument-error:pair-expected1
    $raise-argument-error:pair-expected2))

;; mutable-hash-association-constructor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for association-list mutable hash constructors.
(define mutable-hash-association-constructor-runtime-only-helper-names
  '($make-hasheq/who
    $make-hasheqv/who
    $make-hash/who
    $make-hashalw/who
    $make-hasheq
    $make-hasheqv
    $make-hash
    $make-hashalw))

;; mutable-hash-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given mutable hash helper names from the runtime helper index.
(define (mutable-hash-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; runtime-helper-names : (listof core-runtime-helper?) -> (listof symbol?)
;;   Return helper names in their registered emission order.
(define (runtime-helper-names helpers)
  (for/list ([helper (in-list helpers)])
    (core-runtime-helper-name helper)))

;; hash-iterate-position-validation-forms : datum? symbol? symbol? -> (listof datum?)
;;   Generate validation for an exact-nonnegative-integer iterator position.
(define (hash-iterate-position-validation-forms who-expr pos-local index-local)
  `((if (ref.test (ref i31) (local.get ,pos-local))
        (then (local.set ,index-local
                         (i31.get_s (ref.cast (ref i31) (local.get ,pos-local))))
              (if (i32.ne (i32.and (local.get ,index-local) (i32.const 1))
                          (i32.const 0))
                  (then (call $raise-exact-nonnegative-integer-expected/who
                              ,who-expr
                              (local.get ,pos-local))
                        (unreachable)))
              (local.set ,index-local
                         (i32.shr_s (local.get ,index-local) (i32.const 1))))
        (else (call $raise-exact-nonnegative-integer-expected/who
                    ,who-expr
                    (local.get ,pos-local))
              (unreachable)))
    (if (i32.lt_s (local.get ,index-local) (i32.const 0))
        (then (call $raise-exact-nonnegative-integer-expected/who
                    ,who-expr
                    (local.get ,pos-local))
              (unreachable)))))

;; mutable-hash-constructor-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render mutable hash constructor helpers in runtime assembly order.
(define (mutable-hash-constructor-runtime-helper-forms helper-index)
  (mutable-hash-helper-forms
   helper-index
   (append mutable-hash-constructor-runtime-only-helper-names
           mutable-hash-pair-error-runtime-only-helper-names
           mutable-hash-association-constructor-runtime-only-helper-names)))

;; mutable-hash-read-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render mutable hash value and stored-key lookup helpers in runtime assembly order.
(define (mutable-hash-read-runtime-helper-forms helper-index)
  (mutable-hash-helper-forms
   helper-index
   (append (runtime-helper-names mutable-hash-read-runtime-only-helpers)
           (runtime-helper-names mutable-hash-ref-key-runtime-only-helpers))))

;; mutable-hash-write-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render mutable hash insertion and lookup-or-insert helpers in runtime assembly order.
(define (mutable-hash-write-runtime-helper-forms helper-index)
  (mutable-hash-helper-forms
   helper-index
   (append (runtime-helper-names mutable-hash-write-runtime-only-helpers)
           (runtime-helper-names mutable-hash-ref-bang-runtime-only-helpers))))

;; mutable-hash-update-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render mutable hash update! helpers in runtime assembly order.
(define (mutable-hash-update-runtime-helper-forms helper-index)
  (mutable-hash-helper-forms
   helper-index
   (runtime-helper-names mutable-hash-update-bang-runtime-only-helpers)))

;; mutable-hash-remove-membership-clear-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for remove, resize, membership, and clear! helpers.
(define mutable-hash-remove-membership-clear-runtime-helper-names
  '($hash-remove!
    $hasheq-remove!
    $hasheqv-remove!
    $hashequal-remove!
    $hashalw-remove!
    $hasheq-remove!/mutable/checked
    $hasheqv-remove!/mutable/checked
    $hash-remove!/mutable/checked
    $hashalw-remove!/mutable/checked
    $hasheq-resize
    $hasheqv-resize
    $hashequal-resize
    $hashalw-resize
    $maybe-resize-hasheq
    $maybe-resize-hasheqv
    $maybe-resize-hashequal
    $maybe-resize-hashalw
    $hash-has-key?
    $hash-keys-subset?
    $hasheq-has-key?
    $hasheqv-has-key?
    $hashequal-has-key?
    $hashalw-has-key?
    $hasheq-has-key?/plain
    $hasheqv-has-key?/plain
    $hashequal-has-key?/plain
    $hashalw-has-key?/plain
    $hasheq-has-key?/plain/checked
    $hasheqv-has-key?/plain/checked
    $hashequal-has-key?/plain/checked
    $hashalw-has-key?/plain/checked
    $hash-clear!
    $hasheq-clear!
    $hasheqv-clear!
    $hashequal-clear!
    $hashalw-clear!
    $hasheq-clear!/mutable/checked
    $hasheqv-clear!/mutable/checked
    $hash-clear!/mutable/checked
    $hashalw-clear!/mutable/checked))

;; mutable-hash-empty-iteration-runtime-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for hash emptiness and iteration helpers.
(define mutable-hash-empty-iteration-runtime-helper-names
  '($hash-empty?
    $hasheq-empty?
    $hasheqv-empty?
    $hashequal-empty?
    $hashalw-empty?
    $hasheq-empty?/mutable/checked
    $hasheqv-empty?/mutable/checked
    $hash-empty?/mutable/checked
    $hashalw-empty?/mutable/checked
    $raise-mutable-hash-iterate-bad-index
    $hash-iterate-first
    $hash-iterate-next
    $hash-iterate-key
    $hash-iterate-value
    $hash-iterate-pair
    $hash-iterate-key+value
    $mutable-hash-iterate-first/who
    $mutable-hash-iterate-first
    $hasheq-iterate-first
    $hasheqv-iterate-first
    $hashequal-iterate-first
    $hashalw-iterate-first
    $mutable-hash-iterate-next/who
    $mutable-hash-iterate-next
    $hasheq-iterate-next
    $hasheqv-iterate-next
    $hashequal-iterate-next
    $hashalw-iterate-next
    $mutable-hash-iterate-key/who
    $mutable-hash-iterate-value/who
    $mutable-hash-iterate-pair/who
    $mutable-hash-iterate-key+value/who
    $mutable-hash-iterate-key
    $mutable-hash-iterate-value
    $mutable-hash-iterate-pair
    $mutable-hash-iterate-key+value
    $hasheq-iterate-key
    $hasheqv-iterate-key
    $hashequal-iterate-key
    $hashalw-iterate-key
    $hasheq-iterate-value
    $hasheqv-iterate-value
    $hashequal-iterate-value
    $hashalw-iterate-value
    $hasheq-iterate-pair
    $hasheqv-iterate-pair
    $hashequal-iterate-pair
    $hashalw-iterate-pair
    $hasheq-iterate-key+value
    $hasheqv-iterate-key+value
    $hashequal-iterate-key+value
    $hashalw-iterate-key+value))

;; mutable-hash-remove-membership-clear-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render remove, resize, membership, and clear! helpers in runtime assembly order.
(define (mutable-hash-remove-membership-clear-runtime-helper-forms helper-index)
  (mutable-hash-helper-forms
   helper-index
   mutable-hash-remove-membership-clear-runtime-helper-names))

;; mutable-hash-empty-iteration-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render hash emptiness and iteration helpers in runtime assembly order.
(define (mutable-hash-empty-iteration-runtime-helper-forms helper-index)
  (mutable-hash-helper-forms
   helper-index
   mutable-hash-empty-iteration-runtime-helper-names))

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
       `(func $raise-argument-error:pair-expected
              (param $who (ref eq))
              (param $got (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:listof-pair?)
                    (local.get $got))
              (unreachable))))

    (core-runtime-helper
     '$raise-argument-error:pair-expected1
     "$raise-argument-error:pair-expected1"
     (lambda ()
       `(func $raise-argument-error:pair-expected1
              (param $who (ref eq))
              (param $got (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:listof-pair?)
                    (local.get $got))
              (unreachable))))

    (core-runtime-helper
     '$raise-argument-error:pair-expected2
     "$raise-argument-error:pair-expected2"
     (lambda ()
       `(func $raise-argument-error:pair-expected2
              (param $who (ref eq))
              (param $got (ref eq))
              (call $raise-argument-error1
                    (local.get $who)
                    (global.get $string:listof-pair?)
                    (local.get $got))
              (unreachable)))))

   (append
    (for/list ([make-hash/who '($make-hasheq/who
                                $make-hasheqv/who
                                $make-hash/who
                                $make-hashalw/who)]
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
       make-hash/who
       (symbol->string make-hash/who)
       (lambda ()
         `(func ,make-hash/who (type $Prim2)
                (param $who    (ref eq)) ;; public constructor name for errors
                (param $assocs (ref eq)) ;; optional alist, default = missing
                (result        (ref eq)) ;; an (ref $HashEqMutable)

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
                                 (then (call $raise-argument-error:pair-expected1
                                             (local.get $who)
                                             (local.get $assocs))
                                       (unreachable)))
                             (local.set $pair (ref.cast (ref $Pair) (local.get $alist)))
                             ;; Extract car and cdr of current pair
                             (local.set $first (struct.get $Pair $a (local.get $pair))) ;; first = key/value pair
                             (local.set $rest  (struct.get $Pair $d (local.get $pair))) ;; rest  = remaining pairings
                             ;; Validate first is a pair (key . value)
                             (if (i32.eqz (ref.test (ref $Pair) (local.get $first)))
                                 (then (call $raise-argument-error:pair-expected2
                                             (local.get $who)
                                             (local.get $assocs))
                                       (unreachable)))
                             ;; Extract key and value from nested pair
                             (local.set $pair (ref.cast (ref $Pair) (local.get $first)))
                             (local.set $key  (struct.get $Pair $a (local.get $pair))) ;; key
                             (local.set $val  (struct.get $Pair $d (local.get $pair))) ;; value
                             ;; Insert into table
                             (call ,set!/checked (local.get $ht) (local.get $key) (local.get $val))
                             ;; Move to next element in alist
                             (local.set $alist (local.get $rest))
                             (br $walk)))
                (local.get $ht)))))
    (for/list ([make-hash '($make-hasheq
                            $make-hasheqv
                            $make-hash
                            $make-hashalw)]
               [make-hash/who '($make-hasheq/who
                                $make-hasheqv/who
                                $make-hash/who
                                $make-hashalw/who)]
               [who-symbol '($symbol:make-hasheq
                             $symbol:make-hasheqv
                             $symbol:make-hash
                             $symbol:make-hashalw)])
      (core-runtime-helper
       make-hash
       (symbol->string make-hash)
       (lambda ()
         `(func ,make-hash (type $Prim01) ; optional assocs, default = null
                (param $assocs (ref eq))
                (result        (ref eq))
                (return_call ,make-hash/who
                             (global.get ,who-symbol)
                             (local.get $assocs)))))))))

;; mutable-hash-read-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic and mutable hash value lookup helpers.
(define mutable-hash-read-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$raise-hash-ref-key-not-found
     "$raise-hash-ref-key-not-found"
     (lambda ()
       `(func $raise-hash-ref-key-not-found
              (param $prefix (ref eq))
              (param $key    (ref eq))
              (local $out     (ref $GrowableArray))
              (local $message (ref $String))

              (local.set $out (call $make-growable-array (i32.const 2)))
              (call $growable-array-add! (local.get $out)
                    (ref.cast (ref $String) (local.get $prefix)))
              (call $growable-array-add! (local.get $out)
                    (call $format/display (local.get $key)))
              (local.set $message
                         (call $growable-array-of-strings->string (local.get $out)))
              (call $raise
                    (call $exn:fail:contract/make
                          (local.get $message)
                          (call $current-continuation-marks (global.get $missing)))
                    (global.get $true))
              (unreachable))))

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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-ref)
                              (global.get $string:hash?)
                              (local.get $ht))
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
        `(func ,raise-expected
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:hash-ref)
                     (global.get $string:hash?)
                     (local.get $bad))
               (unreachable)))))

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
                   (then (call $raise-hash-ref-key-not-found
                               (global.get $string:hash-ref:no-value-found-key)
                               (local.get $key))
                         (unreachable))
                   (else
                    (if (result (ref eq))
                        (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-ref-key)
                              (global.get $string:hash?)
                              (local.get $ht))
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
                   (then (call $raise-hash-ref-key-not-found
                               (global.get $string:hash-ref-key:does-not-contain-key)
                               (local.get $key))
                         (unreachable))
                   (else
                    (if (result (ref eq))
                        (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-set!)
                              (global.get $string:mutable-hash?)
                              (local.get $ht))
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
              (call $raise-argument-error1
                    (global.get $symbol:hash-set!)
                    (global.get $string:mutable-hash?)
                    (local.get $ht))
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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-copy)
                              (global.get $string:hash?)
                              (local.get $ht))
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
        `(func ,raise-expected
               (param $bad (ref eq))
               (call $raise-argument-error1
                     (global.get $symbol:hash-set!)
                     (global.get $string:mutable-hash?)
                     (local.get $bad))
               (unreachable)))))

   (list
    (core-runtime-helper
     '$raise-hash-insert:table-full
     "$raise-hash-insert:table-full"
     (lambda ()
       `(func $raise-hash-insert:table-full
              (drop (call $raise
                          (call $make-exn:fail:out-of-memory
                                (global.get $string:hash-table-full)
                                (call $current-continuation-marks
                                      (global.get $missing)))
                          (global.get $true)))
              (unreachable))))

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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-ref!)
                              (global.get $string:mutable-hash?)
                              (local.get $ht))
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
              (call $raise-argument-error1
                    (global.get $symbol:hash-ref!)
                    (global.get $string:mutable-hash?)
                    (local.get $ht))
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
                   (then (call $raise-hash-ref-key-not-found
                               (global.get $string:hash-ref!:no-value-found-key)
                               (local.get $key))
                         (unreachable)))

               (local.set $value
                          (if (result (ref eq))
                              (ref.eq (call $procedure? (local.get $to-set))
                                  (global.get $true))
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

              (local $f (ref $Procedure))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-update!)
                              (global.get $string:mutable-hash?)
                              (local.get $ht))
                        (unreachable)))
              (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-update!)
                              (global.get $string:hash-update-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 1)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-update!)
                              (global.get $string:hash-update-procedure)
                              (local.get $proc))
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
              (call $raise-argument-error1
                    (global.get $symbol:hash-update!)
                    (global.get $string:mutable-hash?)
                    (local.get $ht))
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
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
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
                   (then (call $raise-hash-ref-key-not-found
                               (global.get $string:hash-update!:no-value-found-key)
                               (local.get $key))
                         (unreachable)))

               (local.set $default
                          (if (result (ref eq))
                              (ref.eq (call $procedure? (local.get $fail))
                                  (global.get $true))
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
       `(func $raise-argument-error:hasheq-mutable-expected
              (call $raise-arguments-error
                    (global.get $symbol:hash-remove!)
                    (global.get $string:mutable-hash?)
                    (array.new_fixed $Args 0))
              (unreachable))))

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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-remove!)
                              (global.get $string:mutable-hash?)
                              (local.get $ht))
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
              (call $raise-argument-error1
                    (global.get $symbol:hash-remove!)
                    (global.get $string:mutable-hash?)
                    (local.get $ht))
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

;; mutable-hash-membership-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash membership helpers.
(define mutable-hash-membership-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$hash-has-key?
     "$hash-has-key?"
     (lambda ()
       `; General hash-has-key?
        (func $hash-has-key? (type $Prim2)
              (param $ht  (ref eq))
              (param $key (ref eq))
              (result     (ref eq))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-has-key?)
                              (global.get $string:hash?)
                              (local.get $ht))
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-has-key?
                                      (local.get $ht)
                                      (local.get $key)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-has-key?
                                      (local.get $ht)
                                      (local.get $key)))))
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheq-has-key?
                                      (local.get $ht)
                                      (local.get $key)))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-has-key?
                                      (local.get $ht)
                                      (local.get $key)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-has-key?
                                      (local.get $ht)
                                      (local.get $key)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then
                   (return (call $immutable-hash-has-key?
                                 (local.get $ht)
                                 (local.get $key)))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then
                   (return (call $immutable-hashalw-has-key?
                                 (local.get $ht)
                                 (local.get $key)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-has-key?
                                      (local.get $ht)
                                      (local.get $key)))))
              (unreachable))))

    (core-runtime-helper
     '$hash-keys-subset?
     "$hash-keys-subset?"
     (lambda ()
       `;; hash-keys-subset? : hash? hash? -> boolean?
        ;;   Check whether every key in ht1 is present in ht2. The expander's
        ;;   lightweight set layer uses this directly, and the generic
        ;;   iteration helpers below cover both mutable and immutable hashes.
        (func $hash-keys-subset? (type $Prim2)
              (param $ht1 (ref eq)) ;; hash table whose keys are tested
              (param $ht2 (ref eq)) ;; hash table that must contain them
              (result     (ref eq))

              (local $pos (ref eq))
              (local $key (ref eq))

              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht1)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-keys-subset?)
                              (global.get $string:hash?)
                              (local.get $ht1))
                        (unreachable)))
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht2)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-keys-subset?)
                              (global.get $string:hash?)
                              (local.get $ht2))
                        (unreachable)))

              (local.set $pos (call $mutable-hash-iterate-first (local.get $ht1)))
              (block $done
                     (loop $walk
                           (br_if $done (ref.eq (local.get $pos) (global.get $false)))
                           (local.set $key
                                      (call $mutable-hash-iterate-key
                                            (local.get $ht1)
                                            (local.get $pos)
                                            (global.get $missing)))
                           (if (ref.eq (call $hash-has-key?
                                             (local.get $ht2)
                                             (local.get $key))
                                       (global.get $false))
                               (then (return (global.get $false))))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht1)
                                            (local.get $pos)))
                           (br $walk)))
              (global.get $true)))))

   ;; Specialized hash-has-key?
   (for/list ([hash-has-key       '($hasheq-has-key?
                                    $hasheqv-has-key?
                                    $hashequal-has-key?
                                    $hashalw-has-key?)]
              [hash-has-key/plain '($hasheq-has-key?/plain
                                    $hasheqv-has-key?/plain
                                    $hashequal-has-key?/plain
                                    $hashalw-has-key?/plain)])
     (core-runtime-helper
      hash-has-key
      (symbol->string hash-has-key)
      (lambda ()
        `(func ,hash-has-key
               (param $ht  (ref eq))   ;; hash table
               (param $key (ref eq))   ;; key
               (result     (ref eq))   ;; boolean result

               (return_call ,hash-has-key/plain
                            (local.get $ht)
                            (local.get $key))))))

   (for/list ([hash-has-key/plain         '($hasheq-has-key?/plain
                                            $hasheqv-has-key?/plain
                                            $hashequal-has-key?/plain
                                            $hashalw-has-key?/plain)]
              [hash-has-key/plain/checked '($hasheq-has-key?/plain/checked
                                            $hasheqv-has-key?/plain/checked
                                            $hashequal-has-key?/plain/checked
                                            $hashalw-has-key?/plain/checked)]
              [type                        '($HashEqMutable
                                             $HashEqvMutable
                                             $HashEqualMutable
                                             $HashEqualAlwaysMutable)]
              [raise-expected              '($raise-argument-error:hasheq-expected
                                             $raise-argument-error:hasheqv-expected
                                             $raise-argument-error:hash-expected
                                             $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-has-key/plain
      (symbol->string hash-has-key/plain)
      (lambda ()
        `(func ,hash-has-key/plain
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

               ;; Delegate to checked implementation
               (call ,hash-has-key/plain/checked
                     (local.get $table)
                     (local.get $key))))))

   (for/list ([hash-has-key/plain/checked '($hasheq-has-key?/plain/checked
                                            $hasheqv-has-key?/plain/checked
                                            $hashequal-has-key?/plain/checked
                                            $hashalw-has-key?/plain/checked)]
              [type                        '($HashEqMutable
                                             $HashEqvMutable
                                             $HashEqualMutable
                                             $HashEqualAlwaysMutable)]
              [kind                        '(0 1 2 3)])
     (core-runtime-helper
      hash-has-key/plain/checked
      (symbol->string hash-has-key/plain/checked)
      (lambda ()
        `(func ,hash-has-key/plain/checked
               (param $table (ref ,type))
               (param $key   (ref eq))
               (result       (ref eq))

               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $index    i32)
               (local $step     i32)
               (local $hash     i32)
               (local $k        (ref eq))
               (local $slot     i32)

               ;; Get entries and capacity
               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))

               ;; Hash key and compute initial index
               (local.set $hash  (call $hash-key-hash/kind
                                       (i32.const ,kind)
                                       (local.get $key)))
               (local.set $index (i32.rem_u (local.get $hash) (local.get $capacity)))
               (local.set $step  (i32.const 0))

               (block $not-found
                      (loop $probe
                            ;; Stop if we've probed the full table
                            (br_if $not-found (i32.ge_u (local.get $step) (local.get $capacity)))
                            ;; slot = 2 * ((index + step) % capacity)
                            (local.set $slot
                                       (i32.shl
                                        (i32.rem_u
                                         (i32.add (local.get $index) (local.get $step))
                                         (local.get $capacity))
                                        (i32.const 1)))
                            ;; Load key from slot
                            (local.set $k (array.get $Array (local.get $entries) (local.get $slot)))
                            ;; Empty slot: key is not in the table
                            (br_if $not-found (ref.eq (local.get $k) (global.get $missing)))
                            ;; Tombstone: skip
                            (if (ref.eq (local.get $k) (global.get $tombstone))
                                (then
                                 (local.set $step (i32.add (local.get $step) (i32.const 1)))
                                 (br $probe)))
                            ;; Match: return #t
                            (if (call $hash-key-matches?/kind
                                      (i32.const ,kind)
                                      (local.get $k)
                                      (local.get $key))
                                (then (return (global.get $true))))
                            ;; Otherwise try next slot
                            (local.set $step (i32.add (local.get $step) (i32.const 1)))
                            (br $probe)))

               ;; Not found: return #f
               (global.get $false)))))))

;; mutable-hash-clear-bang-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash destructive clear helpers.
(define mutable-hash-clear-bang-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$hash-clear!
     "$hash-clear!"
     (lambda ()
       `(func $hash-clear! (type $Prim1)
              (param $ht (ref eq))
              (result    (ref eq))
              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-clear!)
                              (global.get $string:mutable-hash?)
                              (local.get $ht))
                        (unreachable)))

              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-clear!
                                      (local.get $ht)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-clear!
                                      (local.get $ht)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-clear!
                                      (local.get $ht)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-clear!
                                      (local.get $ht)))))
              (call $raise-argument-error1
                    (global.get $symbol:hash-clear!)
                    (global.get $string:mutable-hash?)
                    (local.get $ht))
              (unreachable)))))

   (for/list ([hash-clear     '($hasheq-clear!
                                $hasheqv-clear!
                                $hashequal-clear!
                                $hashalw-clear!)]
              [clear!/checked '($hasheq-clear!/mutable/checked
                                $hasheqv-clear!/mutable/checked
                                $hash-clear!/mutable/checked
                                $hashalw-clear!/mutable/checked)]
              [type           '($HashEqMutable
                                $HashEqvMutable
                                $HashEqualMutable
                                $HashEqualAlwaysMutable)]
              [raise-expected '($raise-argument-error:mutable-hasheq-expected
                                $raise-argument-error:mutable-hasheqv-expected
                                $raise-argument-error:mutable-hash-expected
                                $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      hash-clear
      (symbol->string hash-clear)
      (lambda ()
        `(func ,hash-clear
               (param $ht (ref eq))   ;; table
               (result    (ref eq))   ;; return void

               (local $table (ref ,type))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               ;; Delegate
               (call ,clear!/checked (local.get $table))
               ;; Return void
               (global.get $void)))))

   (for/list ([clear!/checked '($hasheq-clear!/mutable/checked
                                $hasheqv-clear!/mutable/checked
                                $hash-clear!/mutable/checked
                                $hashalw-clear!/mutable/checked)]
              [type           '($HashEqMutable
                                $HashEqvMutable
                                $HashEqualMutable
                                $HashEqualAlwaysMutable)])
     (core-runtime-helper
      clear!/checked
      (symbol->string clear!/checked)
      (lambda ()
        `(func ,clear!/checked
               (param $ht (ref ,type))

               (local $new-entries (ref $Array))

               ;; Allocate fresh array of default size (16 entries = 32 slots)
               (local.set $new-entries (array.new $Array (global.get $missing) (i32.const 32)))
               ;; Replace entries array
               (struct.set ,type $entries (local.get $ht) (local.get $new-entries))
               ;; Reset count to 0
               (struct.set ,type $count (local.get $ht) (i32.const 0))))))))

;; mutable-hash-empty-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate hash emptiness predicates for mutable hash tables.
(define mutable-hash-empty-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$hash-empty?
     "$hash-empty?"
     (lambda ()
       `;; hash-empty?

        (func $hash-empty? (type $Prim1)
              (param $ht (ref eq))
              (result    (ref eq))
              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-empty?)
                              (global.get $string:hash?)
                              (local.get $ht))
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-empty? (local.get $ht)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-empty? (local.get $ht)))))
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then
                   (return
                    (if (result (ref eq))
                        (i32.eqz
                         (struct.get $HashEqImmutable $count
                                     (ref.cast (ref $HashEqImmutable)
                                               (local.get $ht))))
                        (then (global.get $true))
                        (else (global.get $false))))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then
                   (return
                    (if (result (ref eq))
                        (i32.eqz
                         (struct.get $HashEqvImmutable $count
                                     (ref.cast (ref $HashEqvImmutable)
                                               (local.get $ht))))
                        (then (global.get $true))
                        (else (global.get $false))))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-empty? (local.get $ht)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then
                   (return
                    (if (result (ref eq))
                        (i32.eqz
                         (struct.get $HashEqualImmutable $count
                                     (ref.cast (ref $HashEqualImmutable)
                                               (local.get $ht))))
                        (then (global.get $true))
                        (else (global.get $false))))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-empty? (local.get $ht)))))
              (unreachable)))))

   (for/list ([hash-empty     '($hasheq-empty?
                                $hasheqv-empty?
                                $hashequal-empty?
                                $hashalw-empty?)]
              [empty?/checked '($hasheq-empty?/mutable/checked
                                $hasheqv-empty?/mutable/checked
                                $hash-empty?/mutable/checked
                                $hashalw-empty?/mutable/checked)]
              [type           '($HashEqMutable
                                $HashEqvMutable
                                $HashEqualMutable
                                $HashEqualAlwaysMutable)]
              [raise-expected '($raise-argument-error:hasheq-expected
                                $raise-argument-error:hasheqv-expected
                                $raise-argument-error:hash-expected
                                $raise-argument-error:hashalw-expected)])
     (core-runtime-helper
      hash-empty
      (symbol->string hash-empty)
      (lambda ()
        `(func ,hash-empty
               (param $ht (ref eq))   ;; table
               (result (ref eq))      ;; boolean result

               (local $table (ref ,type))
               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))
               ;; Decode
               (local.set $table (ref.cast (ref ,type) (local.get $ht)))
               ;; Delegate
               (call ,empty?/checked (local.get $table))))))

   (for/list ([empty?/checked '($hasheq-empty?/mutable/checked
                                $hasheqv-empty?/mutable/checked
                                $hash-empty?/mutable/checked
                                $hashalw-empty?/mutable/checked)]
              [type           '($HashEqMutable
                                $HashEqvMutable
                                $HashEqualMutable
                                $HashEqualAlwaysMutable)])
     (core-runtime-helper
      empty?/checked
      (symbol->string empty?/checked)
      (lambda ()
        `(func ,empty?/checked
               (param $ht (ref ,type))   ;; hash table
               (result (ref eq))         ;; boolean result

               (if (result (ref eq))
                   (i32.eqz (struct.get ,type $count (local.get $ht)))
                   (then (global.get $true))
                   (else (global.get $false)))))))))

;; mutable-hash-iteration-dispatch-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public hash iteration dispatch helpers.
(define mutable-hash-iteration-dispatch-runtime-only-helpers
  (list
   (core-runtime-helper
    '$raise-mutable-hash-iterate-bad-index
    "$raise-mutable-hash-iterate-bad-index"
    (lambda ()
      `(func $raise-mutable-hash-iterate-bad-index
             (param $who (ref eq))  ;; public iterator accessor name
             (param $pos (ref eq))  ;; iteration position
             (local $out     (ref $GrowableArray))
             (local $message (ref $String))

             (local.set $out (call $make-growable-array (i32.const 3)))
             (call $growable-array-add! (local.get $out)
                   (call $format/display (local.get $who)))
             (call $growable-array-add! (local.get $out)
                   (global.get $string:hash-iterate:no-element-at-index))
             (call $growable-array-add! (local.get $out)
                   (call $format/display (local.get $pos)))
             (local.set $message
                        (call $growable-array-of-strings->string (local.get $out)))
             (call $raise
                   (call $exn:fail:contract/make
                         (local.get $message)
                         (call $current-continuation-marks (global.get $missing)))
                   (global.get $true))
             (unreachable))))

   (core-runtime-helper
    '$hash-iterate-first
    "$hash-iterate-first"
    (lambda ()
      `;; hash-iterate-first : hash? -> (or/c #f exact-nonnegative-integer?)
       ;;   Public hash iterator entry point for mutable and immutable hashes.
       (func $hash-iterate-first (type $Prim1)
             (param $ht (ref eq)) ;; hash table
             (result    (ref eq))
             (if (call $immutable-hash-leaf?/i32 (local.get $ht))
                 (then
                  (return_call $immutable-hash-iterate-first/public
                               (local.get $ht))))
             (return_call $mutable-hash-iterate-first/who
                          (global.get $symbol:hash-iterate-first)
                          (global.get $string:hash?)
                          (local.get $ht)))))

   (core-runtime-helper
    '$hash-iterate-next
    "$hash-iterate-next"
    (lambda ()
      `;; hash-iterate-next : hash? exact-nonnegative-integer? -> (or/c #f exact-nonnegative-integer?)
       ;;   Public hash iterator successor for mutable and immutable hashes.
       (func $hash-iterate-next (type $Prim2)
             (param $ht  (ref eq)) ;; hash table
             (param $pos (ref eq)) ;; iteration position
             (result     (ref eq))
             (if (call $immutable-hash-leaf?/i32 (local.get $ht))
                 (then
                  (return_call $immutable-hash-iterate-next/public
                               (local.get $ht)
                               (local.get $pos))))
             (return_call $mutable-hash-iterate-next/who
                          (global.get $symbol:hash-iterate-next)
                          (global.get $string:hash?)
                          (local.get $ht)
                          (local.get $pos)))))

   (core-runtime-helper
    '$hash-iterate-key
    "$hash-iterate-key"
    (lambda ()
      `;; hash-iterate-key : hash? exact-nonnegative-integer? [any/c] -> any/c
       ;;   Public hash iterator key accessor. Optional bad-index value defaults to raising.
       (func $hash-iterate-key (type $Prim23)
             (param $ht        (ref eq)) ;; hash table
             (param $pos       (ref eq)) ;; iteration position
             (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
             (result           (ref eq))
             (if (call $immutable-hash-leaf?/i32 (local.get $ht))
                 (then
                  (return_call $immutable-hash-iterate-key/public
                               (local.get $ht)
                               (local.get $pos)
                               (local.get $bad-index))))
             (return_call $mutable-hash-iterate-key/who
                          (global.get $symbol:hash-iterate-key)
                          (global.get $string:hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))

   (core-runtime-helper
    '$hash-iterate-value
    "$hash-iterate-value"
    (lambda ()
      `;; hash-iterate-value : hash? exact-nonnegative-integer? [any/c] -> any/c
       ;;   Public hash iterator value accessor. Optional bad-index value defaults to raising.
       (func $hash-iterate-value (type $Prim23)
             (param $ht        (ref eq)) ;; hash table
             (param $pos       (ref eq)) ;; iteration position
             (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
             (result           (ref eq))
             (if (call $immutable-hash-leaf?/i32 (local.get $ht))
                 (then
                  (return_call $immutable-hash-iterate-value/public
                               (local.get $ht)
                               (local.get $pos)
                               (local.get $bad-index))))
             (return_call $mutable-hash-iterate-value/who
                          (global.get $symbol:hash-iterate-value)
                          (global.get $string:hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))

   (core-runtime-helper
    '$hash-iterate-pair
    "$hash-iterate-pair"
    (lambda ()
      `;; hash-iterate-pair : hash? exact-nonnegative-integer? [any/c] -> pair?
       ;;   Public hash iterator pair accessor. Optional bad-index value defaults to raising.
       (func $hash-iterate-pair (type $Prim23)
             (param $ht        (ref eq)) ;; hash table
             (param $pos       (ref eq)) ;; iteration position
             (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
             (result           (ref eq))
             (if (call $immutable-hash-leaf?/i32 (local.get $ht))
                 (then
                  (return_call $immutable-hash-iterate-pair/public
                               (local.get $ht)
                               (local.get $pos)
                               (local.get $bad-index))))
             (return_call $mutable-hash-iterate-pair/who
                          (global.get $symbol:hash-iterate-pair)
                          (global.get $string:hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))

   (core-runtime-helper
    '$hash-iterate-key+value
    "$hash-iterate-key+value"
    (lambda ()
      `;; hash-iterate-key+value : hash? exact-nonnegative-integer? [any/c] -> values
       ;;   Public hash iterator key/value accessor. Optional bad-index value defaults to raising.
       (func $hash-iterate-key+value (type $Prim23)
             (param $ht        (ref eq)) ;; hash table
             (param $pos       (ref eq)) ;; iteration position
             (param $bad-index (ref eq)) ;; optional bad-index value, default = raise
             (result           (ref eq))
             (if (call $immutable-hash-leaf?/i32 (local.get $ht))
                 (then
                  (return_call $immutable-hash-iterate-key+value/public
                               (local.get $ht)
                               (local.get $pos)
                               (local.get $bad-index))))
             (return_call $mutable-hash-iterate-key+value/who
                          (global.get $symbol:hash-iterate-key+value)
                          (global.get $string:hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))))

;; mutable-hash-iteration-position-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash iterator position helpers.
(define mutable-hash-iteration-position-runtime-only-helpers
  (append
   (list
    (core-runtime-helper
     '$mutable-hash-iterate-first/who
     "$mutable-hash-iterate-first/who"
     (lambda ()
       `;; mutable-hash-iterate-first/who
        (func $mutable-hash-iterate-first/who
              (param $who      (ref eq))  ;; public primitive name
              (param $expected (ref eq))  ;; expected contract string
              (param $ht       (ref eq))  ;; mutable hash table
              (result          (ref eq))  ;; first iteration position or #f

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (local.get $who)
                              (local.get $expected)
                              (local.get $ht))
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-iterate-first (local.get $ht)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-iterate-first (local.get $ht)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-iterate-first (local.get $ht)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-iterate-first (local.get $ht)))))
              ;; Bootstrap compatibility: schemified expander code uses
              ;; `hash-iterate-first`, which can currently resolve through
              ;; this helper. Preserve general hash iteration for immutable
              ;; hashes instead of failing on the misleading helper name.
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-first
                                      (call $immutable-hash-as-hasheqv (local.get $ht))))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-first
                                      (call $immutable-hash-as-hasheqv (local.get $ht))))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-first
                                      (call $immutable-hash-as-hasheqv (local.get $ht))))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-first
                                      (call $immutable-hash-as-hasheqv (local.get $ht))))))
              (call $raise-argument-error1
                    (local.get $who)
                    (local.get $expected)
                    (local.get $ht))
              (unreachable))))

    (core-runtime-helper
     '$mutable-hash-iterate-first
     "$mutable-hash-iterate-first"
     (lambda ()
       `;; mutable-hash-iterate-first
        (func $mutable-hash-iterate-first (type $Prim1)
              (param $ht (ref eq))   ;; mutable hash table
              (result    (ref eq))   ;; first iteration position or #f
              (return_call $mutable-hash-iterate-first/who
                           (global.get $symbol:mutable-hash-iterate-first)
                           (global.get $string:mutable-hash?)
                           (local.get $ht)))))

    (core-runtime-helper
     '$mutable-hash-iterate-next/who
     "$mutable-hash-iterate-next/who"
     (lambda ()
       `;; mutable-hash-iterate-next/who
        (func $mutable-hash-iterate-next/who
              (param $who      (ref eq))  ;; public primitive name
              (param $expected (ref eq))  ;; expected contract string
              (param $ht       (ref eq))  ;; mutable hash table
              (param $pos      (ref eq))  ;; current position
              (result          (ref eq))  ;; next position or #f

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (local.get $who)
                              (local.get $expected)
                              (local.get $ht))
                        (unreachable)))
              ;; Dispatch on table type
              (if (ref.test (ref $HashEqMutable) (local.get $ht))
                  (then (return (call $hasheq-iterate-next
                                      (local.get $ht)
                                      (local.get $pos)
                                      (local.get $who)))))
              (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                  (then (return (call $hasheqv-iterate-next
                                      (local.get $ht)
                                      (local.get $pos)
                                      (local.get $who)))))
              (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                  (then (return (call $hashequal-iterate-next
                                      (local.get $ht)
                                      (local.get $pos)
                                      (local.get $who)))))
              (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                  (then (return (call $hashalw-iterate-next
                                      (local.get $ht)
                                      (local.get $pos)
                                      (local.get $who)))))
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-next
                                      (call $immutable-hash-as-hasheqv (local.get $ht))
                                      (local.get $pos)))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-next
                                      (call $immutable-hash-as-hasheqv (local.get $ht))
                                      (local.get $pos)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-next
                                      (call $immutable-hash-as-hasheqv (local.get $ht))
                                      (local.get $pos)))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then (return (call $immutable-hasheqv-iterate-next
                                      (call $immutable-hash-as-hasheqv (local.get $ht))
                                      (local.get $pos)))))
              (call $raise-argument-error1
                    (local.get $who)
                    (local.get $expected)
                    (local.get $ht))
              (unreachable))))

    (core-runtime-helper
     '$mutable-hash-iterate-next
     "$mutable-hash-iterate-next"
     (lambda ()
       `;; mutable-hash-iterate-next
        (func $mutable-hash-iterate-next (type $Prim2)
              (param $ht  (ref eq))   ;; mutable hash table
              (param $pos (ref eq))   ;; current position
              (result     (ref eq))   ;; next position or #f
              (return_call $mutable-hash-iterate-next/who
                           (global.get $symbol:mutable-hash-iterate-next)
                           (global.get $string:mutable-hash?)
                           (local.get $ht)
                           (local.get $pos))))))

   (for/list ([iter-first     '($hasheq-iterate-first
                                $hasheqv-iterate-first
                                $hashequal-iterate-first
                                $hashalw-iterate-first)]
              [type           '($HashEqMutable
                                $HashEqvMutable
                                $HashEqualMutable
                                $HashEqualAlwaysMutable)]
              [raise-expected '($raise-argument-error:mutable-hasheq-expected
                                $raise-argument-error:mutable-hasheqv-expected
                                $raise-argument-error:mutable-hash-expected
                                $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      iter-first
      (symbol->string iter-first)
      (lambda ()
        `(func ,iter-first
               (type $Prim1)
               (param $ht (ref eq))   ;; mutable hash table
               (result    (ref eq))

               (local $table    (ref ,type))
               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $i        i32)
               (local $key      (ref eq))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))

               (local.set $table   (ref.cast (ref ,type) (local.get $ht)))
               (if (i32.eqz (struct.get ,type $count (local.get $table)))
                   (then (return (global.get $false))))

               (local.set $entries  (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
               (local.set $i        (i32.const 0))
               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))
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

                            (return (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                            ))
               (global.get $false)))))

   (for/list ([iter-next      '($hasheq-iterate-next
                                $hasheqv-iterate-next
                                $hashequal-iterate-next
                                $hashalw-iterate-next)]
              [type           '($HashEqMutable
                                $HashEqvMutable
                                $HashEqualMutable
                                $HashEqualAlwaysMutable)]
              [raise-expected '($raise-argument-error:mutable-hasheq-expected
                                $raise-argument-error:mutable-hasheqv-expected
                                $raise-argument-error:mutable-hash-expected
                                $raise-argument-error:mutable-hashalw-expected)])
     (core-runtime-helper
      iter-next
      (symbol->string iter-next)
      (lambda ()
        `(func ,iter-next
               (param $ht  (ref eq))   ;; mutable hash table
               (param $pos (ref eq))   ;; current iteration position
               (param $who (ref eq))   ;; public primitive name
               (result     (ref eq))   ;; next iteration position or #f

               (local $table    (ref ,type))
               (local $entries  (ref $Array))
               (local $capacity i32)
               (local $i        i32)
               (local $key      (ref eq))

               ;; Check that ht is expected table type
               (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                   (then (call ,raise-expected (local.get $ht))
                         (unreachable)))

               ;; Decode and validate position.
               ,@(hash-iterate-position-validation-forms
                  '(local.get $who)
                  '$pos
                  '$i)

               (local.set $table   (ref.cast (ref ,type) (local.get $ht)))
               (local.set $entries (struct.get ,type $entries (local.get $table)))
               (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))

               (local.set $i (i32.add (local.get $i) (i32.const 1)))

               (block $done
                      (loop $loop
                            (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))
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

                            (return (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                            ))
               (global.get $false)))))))

;; mutable-hash-iteration-accessor-dispatch-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash iterator accessor dispatch helpers.
(define mutable-hash-iteration-accessor-dispatch-runtime-only-helpers
  (list
   (core-runtime-helper
    '$mutable-hash-iterate-key/who
    "$mutable-hash-iterate-key/who"
    (lambda ()
      `;; mutable-hash-iterate-key/who
       (func $mutable-hash-iterate-key/who
             (param $who       (ref eq))  ;; public primitive name
             (param $expected  (ref eq))  ;; expected contract string
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))
             (local $entry     (ref $ImmutableHashEntry))

             ;; Check type: must be (ref $Hash)
             (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (local.get $expected)
                             (local.get $ht))
                       (unreachable)))
             ;; Dispatch on table type
             (if (ref.test (ref $HashEqMutable) (local.get $ht))
                 (then (return (call $hasheq-iterate-key
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                 (then (return (call $hasheqv-iterate-key
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                 (then (return (call $hashequal-iterate-key
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                 (then (return (call $hashalw-iterate-key
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $Hash) (local.get $ht))
                 (then
                  (local.set $entry
                             (ref.cast (ref $ImmutableHashEntry)
                                       (call $immutable-hasheqv-iterate-entry
                                             (call $immutable-hash-as-hasheqv (local.get $ht))
                                             (local.get $who)
                                             (local.get $pos)
                                             (local.get $bad-index))))
                  (return (struct.get $ImmutableHashEntry $key (local.get $entry)))))
             (call $raise-argument-error1
                   (local.get $who)
                   (local.get $expected)
                   (local.get $ht))
             (unreachable))))

   (core-runtime-helper
    '$mutable-hash-iterate-key
    "$mutable-hash-iterate-key"
    (lambda ()
      `;; mutable-hash-iterate-key
       (func $mutable-hash-iterate-key (type $Prim23)
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))
             (return_call $mutable-hash-iterate-key/who
                          (global.get $symbol:mutable-hash-iterate-key)
                          (global.get $string:mutable-hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))

   (core-runtime-helper
    '$mutable-hash-iterate-value/who
    "$mutable-hash-iterate-value/who"
    (lambda ()
      `;; mutable-hash-iterate-value/who
       (func $mutable-hash-iterate-value/who
             (param $who       (ref eq))  ;; public primitive name
             (param $expected  (ref eq))  ;; expected contract string
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))
             (local $entry     (ref $ImmutableHashEntry))

             ;; Check type: must be (ref $Hash)
             (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (local.get $expected)
                             (local.get $ht))
                       (unreachable)))
             ;; Dispatch on table type
             (if (ref.test (ref $HashEqMutable) (local.get $ht))
                 (then (return (call $hasheq-iterate-value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                 (then (return (call $hasheqv-iterate-value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                 (then (return (call $hashequal-iterate-value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                 (then (return (call $hashalw-iterate-value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $Hash) (local.get $ht))
                 (then
                  (local.set $entry
                             (ref.cast (ref $ImmutableHashEntry)
                                       (call $immutable-hasheqv-iterate-entry
                                             (call $immutable-hash-as-hasheqv (local.get $ht))
                                             (local.get $who)
                                             (local.get $pos)
                                             (local.get $bad-index))))
                  (return (struct.get $ImmutableHashEntry $value (local.get $entry)))))
             (call $raise-argument-error1
                   (local.get $who)
                   (local.get $expected)
                   (local.get $ht))
             (unreachable))))

   (core-runtime-helper
    '$mutable-hash-iterate-value
    "$mutable-hash-iterate-value"
    (lambda ()
      `;; mutable-hash-iterate-value
       (func $mutable-hash-iterate-value (type $Prim23)
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))
             (return_call $mutable-hash-iterate-value/who
                          (global.get $symbol:mutable-hash-iterate-value)
                          (global.get $string:mutable-hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))

   (core-runtime-helper
    '$mutable-hash-iterate-pair/who
    "$mutable-hash-iterate-pair/who"
    (lambda ()
      `;; mutable-hash-iterate-pair/who
       (func $mutable-hash-iterate-pair/who
             (param $who       (ref eq))  ;; public primitive name
             (param $expected  (ref eq))  ;; expected contract string
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))
             (local $entry     (ref $ImmutableHashEntry))

             ;; Check type: must be (ref $Hash)
             (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (local.get $expected)
                             (local.get $ht))
                       (unreachable)))
             ;; Dispatch on table type
             (if (ref.test (ref $HashEqMutable) (local.get $ht))
                 (then (return (call $hasheq-iterate-pair
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                 (then (return (call $hasheqv-iterate-pair
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                 (then (return (call $hashequal-iterate-pair
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                 (then (return (call $hashalw-iterate-pair
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $Hash) (local.get $ht))
                 (then
                  (local.set $entry
                             (ref.cast (ref $ImmutableHashEntry)
                                       (call $immutable-hasheqv-iterate-entry
                                             (call $immutable-hash-as-hasheqv (local.get $ht))
                                             (local.get $who)
                                             (local.get $pos)
                                             (local.get $bad-index))))
                  (return (call $cons
                                (struct.get $ImmutableHashEntry $key (local.get $entry))
                                (struct.get $ImmutableHashEntry $value (local.get $entry))))))
             (call $raise-argument-error1
                   (local.get $who)
                   (local.get $expected)
                   (local.get $ht))
             (unreachable))))

   (core-runtime-helper
    '$mutable-hash-iterate-pair
    "$mutable-hash-iterate-pair"
    (lambda ()
      `;; mutable-hash-iterate-pair
       (func $mutable-hash-iterate-pair (type $Prim23)
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))
             (return_call $mutable-hash-iterate-pair/who
                          (global.get $symbol:mutable-hash-iterate-pair)
                          (global.get $string:mutable-hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))

   (core-runtime-helper
    '$mutable-hash-iterate-key+value/who
    "$mutable-hash-iterate-key+value/who"
    (lambda ()
      `;; mutable-hash-iterate-key+value/who
       (func $mutable-hash-iterate-key+value/who
             (param $who       (ref eq))  ;; public primitive name
             (param $expected  (ref eq))  ;; expected contract string
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))  ;; returns two values encoded in $Values
             (local $entry     (ref $ImmutableHashEntry))

             ;; Check type: must be (ref $Hash)
             (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (local.get $expected)
                             (local.get $ht))
                       (unreachable)))
             ;; Dispatch on table type
             (if (ref.test (ref $HashEqMutable) (local.get $ht))
                 (then (return (call $hasheq-iterate-key+value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqvMutable) (local.get $ht))
                 (then (return (call $hasheqv-iterate-key+value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualMutable) (local.get $ht))
                 (then (return (call $hashequal-iterate-key+value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $HashEqualAlwaysMutable) (local.get $ht))
                 (then (return (call $hashalw-iterate-key+value
                                     (local.get $ht)
                                     (local.get $pos)
                                     (local.get $bad-index)
                                     (local.get $who)))))
             (if (ref.test (ref $Hash) (local.get $ht))
                 (then
                  (local.set $entry
                             (ref.cast (ref $ImmutableHashEntry)
                                       (call $immutable-hasheqv-iterate-entry
                                             (call $immutable-hash-as-hasheqv (local.get $ht))
                                             (local.get $who)
                                             (local.get $pos)
                                             (local.get $bad-index))))
                  (return (array.new_fixed $Values 2
                                           (struct.get $ImmutableHashEntry $key (local.get $entry))
                                           (struct.get $ImmutableHashEntry $value (local.get $entry))))))
             (call $raise-argument-error1
                   (local.get $who)
                   (local.get $expected)
                   (local.get $ht))
             (unreachable))))

   (core-runtime-helper
    '$mutable-hash-iterate-key+value
    "$mutable-hash-iterate-key+value"
    (lambda ()
      `;; mutable-hash-iterate-key+value
       (func $mutable-hash-iterate-key+value (type $Prim23)
             (param $ht        (ref eq))  ;; mutable hash table
             (param $pos       (ref eq))  ;; iteration position
             (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
             (result           (ref eq))  ;; returns two values encoded in $Values
             (return_call $mutable-hash-iterate-key+value/who
                          (global.get $symbol:mutable-hash-iterate-key+value)
                          (global.get $string:mutable-hash?)
                          (local.get $ht)
                          (local.get $pos)
                          (local.get $bad-index)))))))

;; mutable-hash-iteration-accessor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate table-specific mutable hash iterator accessor helpers.
(define mutable-hash-iteration-accessor-runtime-only-helpers
  (append*
   (for/list ([iter-key         '($hasheq-iterate-key
                                  $hasheqv-iterate-key
                                  $hashequal-iterate-key
                                  $hashalw-iterate-key)]
              [iter-value       '($hasheq-iterate-value
                                  $hasheqv-iterate-value
                                  $hashequal-iterate-value
                                  $hashalw-iterate-value)]
              [iter-pair        '($hasheq-iterate-pair
                                  $hasheqv-iterate-pair
                                  $hashequal-iterate-pair
                                  $hashalw-iterate-pair)]
              [iter-key+value   '($hasheq-iterate-key+value
                                  $hasheqv-iterate-key+value
                                  $hashequal-iterate-key+value
                                  $hashalw-iterate-key+value)]
              [type             '($HashEqMutable
                                  $HashEqvMutable
                                  $HashEqualMutable
                                  $HashEqualAlwaysMutable)]
              [raise-expected   '($raise-argument-error:mutable-hasheq-expected
                                  $raise-argument-error:mutable-hasheqv-expected
                                  $raise-argument-error:mutable-hash-expected
                                  $raise-argument-error:mutable-hashalw-expected)])
     (list
      (core-runtime-helper
       iter-key
       (symbol->string iter-key)
       (lambda ()
         `(func ,iter-key
                (param $ht        (ref eq))  ;; mutable hash table
                (param $pos       (ref eq))  ;; iteration position
                (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
                (param $who       (ref eq))  ;; public primitive name
                (result (ref eq))

                (local $table   (ref ,type))
                (local $entries (ref $Array))
                (local $capacity i32)
                (local $index    i32)
                (local $key      (ref eq))

                (block $bad-index
                       ;; Check that ht is expected table type
                       (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                           (then (call ,raise-expected (local.get $ht))
                                 (unreachable)))

                       ;; Decode and validate position.
                       ,@(hash-iterate-position-validation-forms
                          '(local.get $who)
                          '$pos
                          '$index)

                       (local.set $table   (ref.cast (ref ,type) (local.get $ht)))
                       (local.set $entries (struct.get ,type $entries (local.get $table)))
                       (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))

                       (if (i32.ge_u (local.get $index) (local.get $capacity))
                           (then (br $bad-index)))

                       (local.set $key
                                  (array.get $Array
                                             (local.get $entries)
                                             (i32.shl (local.get $index) (i32.const 1))))
                       (if (ref.eq (local.get $key) (global.get $missing))
                           (then (br $bad-index)))
                       (if (ref.eq (local.get $key) (global.get $tombstone))
                           (then (br $bad-index)))

                       (return (local.get $key)))

                (if (ref.eq (local.get $bad-index) (global.get $missing))
                    (then (call $raise-mutable-hash-iterate-bad-index
                                (local.get $who)
                                (local.get $pos))
                          (unreachable)))
                (return (local.get $bad-index)))))

      (core-runtime-helper
       iter-value
       (symbol->string iter-value)
       (lambda ()
         `(func ,iter-value
                (param $ht        (ref eq))  ;; mutable hash table
                (param $pos       (ref eq))  ;; iteration position
                (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
                (param $who       (ref eq))  ;; public primitive name
                (result (ref eq))

                (local $table   (ref ,type))
                (local $entries (ref $Array))
                (local $capacity i32)
                (local $index    i32)
                (local $key      (ref eq))

                (block $bad-index
                       ;; Check that ht is expected table type
                       (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                           (then (call ,raise-expected (local.get $ht))
                                 (unreachable)))

                       ;; Decode and validate position.
                       ,@(hash-iterate-position-validation-forms
                          '(local.get $who)
                          '$pos
                          '$index)

                       (local.set $table   (ref.cast (ref ,type) (local.get $ht)))
                       (local.set $entries (struct.get ,type $entries (local.get $table)))
                       (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))

                       (if (i32.ge_u (local.get $index) (local.get $capacity))
                           (then (br $bad-index)))

                       (local.set $key
                                  (array.get $Array
                                             (local.get $entries)
                                             (i32.shl (local.get $index) (i32.const 1))))
                       (if (ref.eq (local.get $key) (global.get $missing))
                           (then (br $bad-index)))
                       (if (ref.eq (local.get $key) (global.get $tombstone))
                           (then (br $bad-index)))

                       (return (array.get $Array
                                          (local.get $entries)
                                          (i32.add (i32.shl (local.get $index) (i32.const 1))
                                                   (i32.const 1)))))

                (if (ref.eq (local.get $bad-index) (global.get $missing))
                    (then (call $raise-mutable-hash-iterate-bad-index
                                (local.get $who)
                                (local.get $pos))
                          (unreachable)))
                (return (local.get $bad-index)))))

      (core-runtime-helper
       iter-pair
       (symbol->string iter-pair)
       (lambda ()
         `(func ,iter-pair
                (param $ht        (ref eq))  ;; mutable hash table
                (param $pos       (ref eq))  ;; iteration position
                (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
                (param $who       (ref eq))  ;; public primitive name
                (result (ref eq))

                (local $table   (ref ,type))
                (local $entries (ref $Array))
                (local $capacity i32)
                (local $index    i32)
                (local $key      (ref eq))
                (local $val      (ref eq))

                (block $bad-index
                       ;; Check that ht is expected table type
                       (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                           (then (call ,raise-expected (local.get $ht))
                                 (unreachable)))

                       ;; Decode and validate position.
                       ,@(hash-iterate-position-validation-forms
                          '(local.get $who)
                          '$pos
                          '$index)

                       (local.set $table   (ref.cast (ref ,type) (local.get $ht)))
                       (local.set $entries (struct.get ,type $entries (local.get $table)))
                       (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))

                       (if (i32.ge_u (local.get $index) (local.get $capacity))
                           (then (br $bad-index)))

                       (local.set $key
                                  (array.get $Array
                                             (local.get $entries)
                                             (i32.shl (local.get $index) (i32.const 1))))
                       (if (ref.eq (local.get $key) (global.get $missing))
                           (then (br $bad-index)))
                       (if (ref.eq (local.get $key) (global.get $tombstone))
                           (then (br $bad-index)))

                       (local.set $val
                                  (array.get $Array
                                             (local.get $entries)
                                             (i32.add (i32.shl (local.get $index) (i32.const 1))
                                                      (i32.const 1))))
                       (return (call $cons (local.get $key) (local.get $val))))

                (if (ref.eq (local.get $bad-index) (global.get $missing))
                    (then (call $raise-mutable-hash-iterate-bad-index
                                (local.get $who)
                                (local.get $pos))
                          (unreachable)))
                (return (call $cons (local.get $bad-index) (local.get $bad-index))))))

      (core-runtime-helper
       iter-key+value
       (symbol->string iter-key+value)
       (lambda ()
         `(func ,iter-key+value
                (param $ht        (ref eq))  ;; mutable hash table
                (param $pos       (ref eq))  ;; iteration position
                (param $bad-index (ref eq))  ;; optional bad-index value, default = raise
                (param $who       (ref eq))  ;; public primitive name
                (result (ref eq))            ;; returns two values encoded in $Values

                (local $table   (ref ,type))
                (local $entries (ref $Array))
                (local $capacity i32)
                (local $index    i32)
                (local $key      (ref eq))
                (local $val      (ref eq))

                (block $bad-index
                       ;; Check that ht is expected table type
                       (if (i32.eqz (ref.test (ref ,type) (local.get $ht)))
                           (then (call ,raise-expected (local.get $ht))
                                 (unreachable)))

                       ;; Decode and validate position.
                       ,@(hash-iterate-position-validation-forms
                          '(local.get $who)
                          '$pos
                          '$index)

                       (local.set $table   (ref.cast (ref ,type) (local.get $ht)))
                       (local.set $entries (struct.get ,type $entries (local.get $table)))
                       (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))

                       (if (i32.ge_u (local.get $index) (local.get $capacity))
                           (then (br $bad-index)))

                       (local.set $key
                                  (array.get $Array
                                             (local.get $entries)
                                             (i32.shl (local.get $index) (i32.const 1))))
                       (if (ref.eq (local.get $key) (global.get $missing))
                           (then (br $bad-index)))
                       (if (ref.eq (local.get $key) (global.get $tombstone))
                           (then (br $bad-index)))

                       (local.set $val
                                  (array.get $Array
                                             (local.get $entries)
                                             (i32.add (i32.shl (local.get $index) (i32.const 1))
                                                      (i32.const 1))))
                       (return (array.new_fixed $Values 2 (local.get $key) (local.get $val))))

                (if (ref.eq (local.get $bad-index) (global.get $missing))
                    (then (call $raise-mutable-hash-iterate-bad-index
                                (local.get $who)
                                (local.get $pos))
                          (unreachable)))
                (return (array.new_fixed $Values 2
                                         (local.get $bad-index)
                                         (local.get $bad-index))))))))))

;; mutable-hash-core-runtime-helper-names : (listof symbol?)
;;   Name mutable hash helpers available in the standalone core runtime.
(define mutable-hash-core-runtime-helper-names
  '($make-empty-hasheq
    $make-empty-hasheqv
    $make-empty-hash
    $make-empty-hashalw
    $hash-set!
    $hasheq-set!
    $hasheqv-set!
    $hashequal-set!
    $hashalw-set!
    $hash-kind/i32
    $hash-mutable?/i32
    $hasheqv-set!/mutable/checked
    $hash-set!/mutable/checked
    $hashalw-set!/mutable/checked
    $hasheqv-resize
    $hashequal-resize
    $hashalw-resize
    $maybe-resize-hasheqv
    $maybe-resize-hashequal
    $maybe-resize-hashalw
    $hasheq-clear!/mutable/checked
    $hasheqv-clear!/mutable/checked
    $hash-clear!/mutable/checked
    $hashalw-clear!/mutable/checked
    $hasheq-empty?/mutable/checked
    $hasheqv-empty?/mutable/checked
    $hash-empty?/mutable/checked
    $hashalw-empty?/mutable/checked))

;; mutable-hash-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash helpers in monolithic runtime order.
(define mutable-hash-all-runtime-helpers
  (append mutable-hash-constructor-runtime-only-helpers
          mutable-hash-read-runtime-only-helpers
          mutable-hash-ref-key-runtime-only-helpers
          mutable-hash-write-runtime-only-helpers
          mutable-hash-ref-bang-runtime-only-helpers
          mutable-hash-update-bang-runtime-only-helpers
          mutable-hash-remove-bang-runtime-only-helpers
          mutable-hash-resize-runtime-only-helpers
          mutable-hash-membership-runtime-only-helpers
          mutable-hash-clear-bang-runtime-only-helpers
          mutable-hash-empty-runtime-only-helpers
          mutable-hash-iteration-dispatch-runtime-only-helpers
          mutable-hash-iteration-position-runtime-only-helpers
          mutable-hash-iteration-accessor-dispatch-runtime-only-helpers
          mutable-hash-iteration-accessor-runtime-only-helpers))

;; mutable-hash-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash helpers available in the standalone core runtime.
(define mutable-hash-core-runtime-helpers
  (select-runtime-helpers mutable-hash-all-runtime-helpers
                          mutable-hash-core-runtime-helper-names))

;; mutable-hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate mutable hash helpers that still depend on monolithic runtime globals.
(define mutable-hash-runtime-only-helpers
  (remove-runtime-helpers mutable-hash-all-runtime-helpers
                          mutable-hash-core-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define mutable-hash-helper-index
    (make-core-runtime-helper-index
     (append mutable-hash-core-runtime-helpers
             mutable-hash-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name mutable-hash-core-runtime-helpers)
   mutable-hash-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (mutable-hash-constructor-runtime-helper-forms mutable-hash-helper-index))
   (append mutable-hash-constructor-runtime-only-helper-names
           mutable-hash-pair-error-runtime-only-helper-names
           mutable-hash-association-constructor-runtime-only-helper-names))

  (check-equal?
   (map form-name
        (mutable-hash-read-runtime-helper-forms mutable-hash-helper-index))
   (append (runtime-helper-names mutable-hash-read-runtime-only-helpers)
           (runtime-helper-names mutable-hash-ref-key-runtime-only-helpers)))

  (check-equal?
   (map form-name
        (mutable-hash-write-runtime-helper-forms mutable-hash-helper-index))
   (append (runtime-helper-names mutable-hash-write-runtime-only-helpers)
           (runtime-helper-names mutable-hash-ref-bang-runtime-only-helpers)))

  (check-equal?
   (map form-name
        (mutable-hash-update-runtime-helper-forms mutable-hash-helper-index))
   (runtime-helper-names mutable-hash-update-bang-runtime-only-helpers))

  (check-equal?
   (map form-name
        (mutable-hash-remove-membership-clear-runtime-helper-forms mutable-hash-helper-index))
   mutable-hash-remove-membership-clear-runtime-helper-names)

  (check-equal?
   (map form-name
        (mutable-hash-empty-iteration-runtime-helper-forms mutable-hash-helper-index))
   mutable-hash-empty-iteration-runtime-helper-names))
