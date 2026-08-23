#lang racket

(provide hash-runtime-only-helpers
         hash-core-runtime-helpers
         hash-seed-global-forms
         hash-seed-global-names
         hash-runtime-string-constants
         hash-runtime-symbol-constants
         hash-predicate-core-runtime-helper-forms
         hash-predicate-runtime-helper-forms
         hash-table-predicate-core-runtime-helper-forms
         hash-table-predicate-runtime-helper-forms
         hash-table-operation-runtime-helper-forms
         hash-code-runtime-helper-forms
         hash-count-list-runtime-only-helper-names
         hash-for-each-runtime-only-helper-names
         hash-map-runtime-only-helper-names
         hash-map-copy-runtime-only-helper-names
         hash-filter-runtime-only-helper-names
         hash-key-value-runtime-only-helper-names
         hash-seed-runtime-only-helper-names
         hash-equal-runtime-only-helper-names
         hash-equal-composite-runtime-only-helper-names
         hash-table-predicate-runtime-only-helper-names)

(require "../core-helper.rkt")

;; hash-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by hash predicates and hash-like checks.
(define hash-runtime-string-constants
  '((hash? "hash?")
    (mutable-hash? "(and/c hash? (not/c immutable?))")
    (hash-ref:no-value-found-key "hash-ref: no value found for key\n  key: ")
    (hash-ref-key:does-not-contain-key "hash-ref-key: hash does not contain key\n  key: ")
    (hash-ref!:no-value-found-key "hash-ref!: no value found for key: ")
    (hash-update!:no-value-found-key "hash-update!: no value found for key: ")
    (hash-iterate:no-element-at-index ": no element at index\n  index: ")
    (hash-callback-arity-2 "(procedure-arity-includes/c 2)")
    (hash-update-procedure "(any/c . -> . any/c)")
    (hash-table-full "WebRacket hash table insertion failed")))

;; hash-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by public hash contract checks.
(define hash-runtime-symbol-constants
  '(equal-hash-code
    hash-eq?
    hash-eqv?
    hash-equal?
    hash-equal-always?
    hash-count
    hash->list
    hash-for-each
    hash-map
    hash-map/copy
    hash-filter
    hash-filter-keys
    hash-filter-values
    hash-keys
    hash-values
    hash-ref
    hash-ref-key
    hash-set!
    hash-ref!
    hash-update!
    hash-remove!
    hash-clear!
    hash-copy
    hash-has-key?
    hash-keys-subset?
    hash-empty?
    mutable-hash-iterate-first
    mutable-hash-iterate-next
    mutable-hash-iterate-key
    mutable-hash-iterate-value
    mutable-hash-iterate-pair
    mutable-hash-iterate-key+value
    hash-iterate-first
    hash-iterate-next
    hash-iterate-key
    hash-iterate-value
    hash-iterate-pair
    hash-iterate-key+value))

;; hash-seed-global-forms : (listof datum?)
;;   Declare global state for hash-code seed generation.
(define hash-seed-global-forms
  '(
         (global $next-hash-state (mut i32) (i32.const 0x9e3779b9)))) ;; initial seed, can be randomized or fixed

;; hash-seed-global-names : (listof symbol?)
;;   Enumerate hash-code seed globals.
(define hash-seed-global-names
  (for/list ([form (in-list hash-seed-global-forms)])
    (match form
      [`(global ,name . ,_) name]
      [_ (error 'hash-seed-global-names
                "expected global form, got: ~s"
                form)])))

;; hash-predicate-all-runtime-helper-names : (listof symbol?)
;;   Preserve the full runtime emission order for hash predicate helpers.
(define hash-predicate-all-runtime-helper-names
  '($hash-leaf?/i32
    $mutable-hash-leaf?/i32
    $immutable-hash-leaf?/i32
    $mutable-hash?
    $immutable-hash?))

;; hash-predicate-core-runtime-helper-names : (listof symbol?)
;;   Name pure hash predicate helpers available in the standalone core runtime.
(define hash-predicate-core-runtime-helper-names
  hash-predicate-all-runtime-helper-names)

;; hash-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only emission order for hash predicate helpers.
(define hash-predicate-runtime-only-helper-names
  (remove* hash-predicate-core-runtime-helper-names
           hash-predicate-all-runtime-helper-names))

;; hash-count-list-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for hash count and list conversion helpers.
(define hash-count-list-runtime-only-helper-names
  '($hash-count
    $hasheq-count
    $hasheqv-count
    $hashequal-count
    $hashalw-count
    $hash->list
    $hash->list/generic
    $hasheq->list
    $hasheqv->list
    $hashequal->list
    $hashalw->list
    $hasheq->list/plain
    $hasheqv->list/plain
    $hashequal->list/plain
    $hashalw->list/plain
    $hasheq->list/plain/checked
    $hasheqv->list/plain/checked
    $hashequal->list/plain/checked
    $hashalw->list/plain/checked))

;; hash-for-each-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for hash for-each helpers.
(define hash-for-each-runtime-only-helper-names
  '($hash-for-each
    $hasheq-for-each
    $hasheqv-for-each
    $hashequal-for-each
    $hashalw-for-each
    $hasheq-for-each/checked
    $hasheqv-for-each/checked
    $hashequal-for-each/checked
    $hashalw-for-each/checked
    $hash-for-each/generic))

;; hash-map-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for hash map helpers.
(define hash-map-runtime-only-helper-names
  '($hash-map
    $hasheq-map
    $hasheqv-map
    $hashequal-map
    $hashalw-map
    $hasheq-map/plain
    $hasheqv-map/plain
    $hashequal-map/plain
    $hashalw-map/plain
    $hasheq-map/plain/checked
    $hasheqv-map/plain/checked
    $hashequal-map/plain/checked
    $hashalw-map/plain/checked
    $hash-map/generic))

;; hash-map-copy-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for hash map/copy helpers.
(define hash-map-copy-runtime-only-helper-names
  '($hash-map/copy
    $hash-map/copy/generic
    $hasheq-map/copy
    $hasheqv-map/copy
    $hashequal-map/copy
    $hashalw-map/copy
    $hasheq-map/copy/plain
    $hasheqv-map/copy/plain
    $hashequal-map/copy/plain
    $hashalw-map/copy/plain
    $hasheq-map/copy/plain/checked
    $hasheqv-map/copy/plain/checked
    $hashequal-map/copy/plain/checked
    $hashalw-map/copy/plain/checked))

;; hash-filter-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for hash filter helpers.
(define hash-filter-runtime-only-helper-names
  '($hash-filter
    $hash-filter-keys
    $hash-filter-values
    $hash-filter/generic
    $hasheq-filter
    $hasheqv-filter
    $hashequal-filter
    $hashalw-filter
    $hasheq-filter/plain
    $hasheqv-filter/plain
    $hashequal-filter/plain
    $hashalw-filter/plain
    $hasheq-filter/plain/checked
    $hasheqv-filter/plain/checked
    $hashequal-filter/plain/checked
    $hashalw-filter/plain/checked))

;; hash-key-value-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for hash keys and values helpers.
(define hash-key-value-runtime-only-helper-names
  '($hash-keys
    $hash-values
    $hash-keys/generic
    $hash-values/generic
    $hasheq-keys
    $hasheq-keys/plain
    $hasheq-keys/plain/checked
    $hasheqv-keys
    $hasheqv-keys/plain
    $hasheqv-keys/plain/checked
    $hashequal-keys
    $hashequal-keys/plain
    $hashequal-keys/plain/checked
    $hashalw-keys
    $hashalw-keys/plain
    $hashalw-keys/plain/checked
    $hasheq-values
    $hasheq-values/plain
    $hasheq-values/plain/checked
    $hasheqv-values
    $hasheqv-values/plain
    $hasheqv-values/plain/checked
    $hashequal-values
    $hashequal-values/plain
    $hashequal-values/plain/checked
    $hashalw-values
    $hashalw-values/plain
    $hashalw-values/plain/checked))

;; hash-seed-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for base hash-code helpers.
(define hash-seed-runtime-only-helper-names
  '($splitmix32
    $eq-hash-code
    $eq-hash/i32
    $eqv-hash-code
    $eqv-hash/i32))

;; hash-equal-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for equal? hash-code wrappers.
(define hash-equal-runtime-only-helper-names
  '($equal-hash-code
    $equal-always-hash-code
    $equal-always-hash/i32
    $equal-hash/i32))

;; hash-equal-composite-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for composite equal? hash-code helpers.
(define hash-equal-composite-runtime-only-helper-names
  '($equal-hash/pair
    $equal-hash/mpair
    $equal-hash/box
    $equal-hash/vector
    $equal-always-hash/pair
    $equal-always-hash/box
    $equal-always-hash/vector
    $equal-always-hash/struct
    $equal-hash/struct
    $equal-hash/hash
    $equal-hash/hash-generic
    $equal-hash/hash-core
    $equal-hash/hasheq-mutable
    $equal-hash/hasheqv-mutable
    $equal-hash/hashequal-mutable
    $equal-hash/hashalw-mutable
    $bytes-hash/i32))

;; hash-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render the given hash helper names from the runtime helper index.
(define (hash-helper-forms helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form helper-index name)))

;; hash-predicate-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted hash predicate helpers in runtime assembly order.
(define (hash-predicate-core-runtime-helper-forms helper-index)
  (hash-helper-forms helper-index hash-predicate-core-runtime-helper-names))

;; hash-predicate-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render runtime-only hash predicate helpers in runtime assembly order.
(define (hash-predicate-runtime-helper-forms helper-index)
  (hash-helper-forms helper-index hash-predicate-runtime-only-helper-names))

;; hash-table-predicate-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render hash table predicate helpers in runtime assembly order.
(define (hash-table-predicate-runtime-helper-forms helper-index)
  (hash-helper-forms helper-index hash-table-predicate-runtime-only-helper-names))

;; hash-table-operation-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render generic hash table operation helpers in runtime assembly order.
(define (hash-table-operation-runtime-helper-forms helper-index)
  (append
   ;; General hash-count and hash->list
   (hash-helper-forms helper-index hash-count-list-runtime-only-helper-names)
   ;; hash-for-each : apply proc to each key/value in a hash table.
   (hash-helper-forms helper-index hash-for-each-runtime-only-helper-names)
   ;; General hash-map
   (hash-helper-forms helper-index hash-map-runtime-only-helper-names)
   ;; hash-map/copy
   (hash-helper-forms helper-index hash-map-copy-runtime-only-helper-names)
   ;; hash-filter, hash-filter-keys, hash-filter-values
   (hash-helper-forms helper-index hash-filter-runtime-only-helper-names)
   ;; General hash-keys and hash-values
   (hash-helper-forms helper-index hash-key-value-runtime-only-helper-names)))

;; hash-code-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render hash-code helpers in runtime assembly order.
(define (hash-code-runtime-helper-forms helper-index)
  (append
   (hash-helper-forms helper-index hash-seed-runtime-only-helper-names)
   (hash-helper-forms helper-index hash-equal-runtime-only-helper-names)
   (hash-helper-forms helper-index hash-equal-composite-runtime-only-helper-names)))

;; hash-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate concrete hash predicate helpers.
(define hash-predicate-runtime-only-helpers
  (function-forms->runtime-helpers
   'hash-predicate-runtime-only-helpers
   '(
         ;; hash-leaf?/i32 : any/c -> i32
         ;;   Check concrete hash representations instead of the broad $Hash
         ;;   prefix type, which can also match non-hash structs by shape.
         (func $hash-leaf?/i32
               (param $v (ref eq)) ;; any/c
               (result   i32)
               ;; Wasm-GC struct subtyping is structural enough that the
               ;; broad hash wrapper shapes can accidentally match ordinary
               ;; Racket structs. Reject `$Struct` first; WebRacket hash
               ;; wrappers are runtime objects, not Racket struct values.
               (if (result i32)
                   (ref.test (ref $Struct) (local.get $v))
                   (then (i32.const 0))
                   (else
                    (i32.or (call $mutable-hash-leaf?/i32 (local.get $v))
                            (call $immutable-hash-leaf?/i32 (local.get $v))))))

         ;; mutable-hash-leaf?/i32 : any/c -> i32
         ;;   Check concrete mutable hash representations.
         (func $mutable-hash-leaf?/i32
               (param $v (ref eq)) ;; any/c
               (result   i32)
               (i32.or
                (i32.or
                 (if (result i32)
                     (ref.test (ref $HashEqMutable) (local.get $v))
                     (then (ref.eq (struct.get $HashEqMutable $mutable?
                                               (ref.cast (ref $HashEqMutable) (local.get $v)))
                                   (global.get $true)))
                     (else (i32.const 0)))
                 (if (result i32)
                     (ref.test (ref $HashEqvMutable) (local.get $v))
                     (then (ref.eq (struct.get $HashEqvMutable $mutable?
                                               (ref.cast (ref $HashEqvMutable) (local.get $v)))
                                   (global.get $true)))
                     (else (i32.const 0))))
                (i32.or
                 (if (result i32)
                     (ref.test (ref $HashEqualMutable) (local.get $v))
                     (then (ref.eq (struct.get $HashEqualMutable $mutable?
                                               (ref.cast (ref $HashEqualMutable) (local.get $v)))
                                   (global.get $true)))
                     (else (i32.const 0)))
                 (if (result i32)
                     (ref.test (ref $HashEqualAlwaysMutable) (local.get $v))
                     (then (ref.eq (struct.get $HashEqualAlwaysMutable $mutable?
                                               (ref.cast (ref $HashEqualAlwaysMutable) (local.get $v)))
                                   (global.get $true)))
                     (else (i32.const 0))))))

         ;; immutable-hash-leaf?/i32 : any/c -> i32
         ;;   Check concrete immutable hash representations.
         (func $immutable-hash-leaf?/i32
               (param $v (ref eq)) ;; any/c
               (result   i32)
               (i32.or
                (i32.or (ref.test (ref $HashEqImmutable) (local.get $v))
                        (ref.test (ref $HashEqvImmutable) (local.get $v)))
                (i32.or (ref.test (ref $HashEqualImmutable) (local.get $v))
                        (ref.test (ref $HashEqualAlwaysImmutable) (local.get $v)))))

         (func $mutable-hash? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (call $mutable-hash-leaf?/i32 (local.get $v))
                   (then (global.get $true))
                   (else (global.get $false))))

         (func $immutable-hash? (type $Prim1) (param $v (ref eq)) (result (ref eq))
               (if (result (ref eq))
                   (call $immutable-hash-leaf?/i32 (local.get $v))
                   (then (global.get $true))
                   (else (global.get $false))))


     )))

;; hash-table-predicate-all-runtime-helper-names : (listof symbol?)
;;   Preserve the full runtime emission order for public hash table predicates.
(define hash-table-predicate-all-runtime-helper-names
  '($hash?
    $hash-eq?
    $hash-eqv?
    $hash-equal?
    $hash-equal-always?))

;; hash-table-predicate-core-runtime-helper-names : (listof symbol?)
;;   Name pure public hash predicates available in the standalone core runtime.
(define hash-table-predicate-core-runtime-helper-names
  '($hash?))

;; hash-table-predicate-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime-only emission order for public hash table predicates.
(define hash-table-predicate-runtime-only-helper-names
  (remove* hash-table-predicate-core-runtime-helper-names
           hash-table-predicate-all-runtime-helper-names))

;; hash-table-predicate-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted public hash predicates in runtime assembly order.
(define (hash-table-predicate-core-runtime-helper-forms helper-index)
  (hash-helper-forms helper-index hash-table-predicate-core-runtime-helper-names))

;; hash-table-predicate-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate public hash table predicate helpers.
(define hash-table-predicate-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'hash-table-predicate-runtime-only-helpers
    '(
        (func $hash? (type $Prim1)
              (param $v (ref eq))
              (result   (ref eq))

              (if (result (ref eq))
                  (call $hash-leaf?/i32 (local.get $v))
                  (then (global.get $true))
                  (else (global.get $false))))))

   (for/list ([pred '($hash-eq? $hash-eqv? $hash-equal? $hash-equal-always?)]
              [who-symbol '($symbol:hash-eq?
                            $symbol:hash-eqv?
                            $symbol:hash-equal?
                            $symbol:hash-equal-always?)]
              [mutable-type '($HashEqMutable
                              $HashEqvMutable
                              $HashEqualMutable
                              $HashEqualAlwaysMutable)]
              [immutable-type '($HashEqImmutable
                                $HashEqvImmutable
                                $HashEqualImmutable
                                $HashEqualAlwaysImmutable)])
     (core-runtime-helper
      pred
      (symbol->string pred)
      (lambda ()
        `(func ,pred (type $Prim1)
               (param $ht (ref eq)) ;; hash table
               (result    (ref eq))
               ;; Validate argument is a hash table
               (if (i32.eqz (call $hash-leaf?/i32 (local.get $ht)))
                   (then (call $raise-argument-error1
                               (global.get ,who-symbol)
                               (global.get $string:hash?)
                               (local.get $ht))
                         (unreachable)))
               (if (result (ref eq))
                   (i32.or (ref.test (ref ,mutable-type) (local.get $ht))
                           (ref.test (ref ,immutable-type) (local.get $ht)))
                   (then (global.get $true))
                   (else (global.get $false)))))))))

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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-count)
                              (global.get $string:hash?)
                              (local.get $ht))
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
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash->list)
                              (global.get $string:hash?)
                              (local.get $ht))
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

               (local $f (ref $Procedure))

               ;; Check type: must be (ref $Hash)
               (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-for-each)
                               (global.get $string:hash?)
                               (local.get $ht))
                         (unreachable)))
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-for-each)
                               (global.get $string:hash-callback-arity-2)
                               (local.get $proc))
                         (unreachable)))
               (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $f)
                                  (i32.const 2)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:hash-for-each)
                               (global.get $string:hash-callback-arity-2)
                               (local.get $proc))
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
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
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
              (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
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

              (local $f (ref $Procedure))

              ;; Check type: must be (ref $Hash)
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-map)
                              (global.get $string:hash?)
                              (local.get $ht))
                        (unreachable)))
              ;; Validate procedure
              (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-map)
                              (global.get $string:hash-callback-arity-2)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 2)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-map)
                              (global.get $string:hash-callback-arity-2)
                              (local.get $proc))
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
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
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
              (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
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

              (local $f (ref $Procedure))

              ;; Validate argument is a hash table
              (if (i32.eqz (ref.test (ref $Hash) (local.get $ht)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-map/copy)
                              (global.get $string:hash?)
                              (local.get $ht))
                        (unreachable)))
              (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-map/copy)
                              (global.get $string:hash-callback-arity-2)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 2)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:hash-map/copy)
                              (global.get $string:hash-callback-arity-2)
                              (local.get $proc))
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
              (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                  (then (return (call $hash-map/copy/generic
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                  (then (return (call $hash-map/copy/generic
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                  (then (return (call $hash-map/copy/generic
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                  (then (return (call $hash-map/copy/generic
                                      (local.get $ht)
                                      (local.get $proc)
                                      (local.get $kind)))))
              (unreachable))))

   (function-forms->runtime-helpers
    'hash-map/copy-runtime-only-helpers
    '(
        ;; hash-map/copy/generic : immutable-hash? procedure? any/c -> immutable-hash?
        ;;   Iterator-backed fallback for immutable hash wrappers. The
        ;;   simplified positional kind argument is currently ignored.
        (func $hash-map/copy/generic
              (param $ht   (ref eq)) ;; immutable hash table
              (param $proc (ref eq)) ;; key/value mapper
              (param $kind (ref eq)) ;; optional kind, ignored
              (result      (ref eq))
              (local $f     (ref $Procedure))
              (local $finv  (ref $ProcedureInvoker))
              (local $args  (ref $Args))
              (local $pos   (ref eq))
              (local $key   (ref eq))
              (local $val   (ref eq))
              (local $res   (ref eq))
              (local $vals  (ref $Values))
              (local $nkey  (ref eq))
              (local $nval  (ref eq))
              (local $dst   (ref eq))
              (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:hash-map/copy)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f     (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv  (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args  (array.new_fixed $Args 2
                                                 (global.get $null)
                                                 (global.get $null)))
              (local.set $pos   (call $mutable-hash-iterate-first (local.get $ht)))
              (local.set $dst   (call $hash-clear (local.get $ht)))
              (local.set $nkey  (global.get $zero))
              (local.set $nval  (global.get $zero))
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
                           (local.set $res
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $finv)))
                           (if (ref.test (ref $Values) (local.get $res))
                               (then
                                (local.set $vals (ref.cast (ref $Values) (local.get $res)))
                                (if (i32.ne (array.len (local.get $vals)) (i32.const 2))
                                    (then (call $raise-wrong-number-of-values-received
                                                (i32.const 2)
                                                (array.len (local.get $vals)))
                                          (unreachable)))
                                (local.set $nkey (array.get $Values (local.get $vals) (i32.const 0)))
                                (local.set $nval (array.get $Values (local.get $vals) (i32.const 1))))
                               (else (call $raise-wrong-number-of-values-received
                                           (i32.const 2)
                                           (i32.const 1))
                                     (unreachable)))
                           (local.set $dst
                                      (call $hash-set
                                            (local.get $dst)
                                            (local.get $nkey)
                                            (local.get $nval)))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (local.get $dst))))

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
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
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
                                     (then (call $raise-wrong-number-of-values-received
                                                 (i32.const 2)
                                                 (array.len (local.get $vals)))
                                           (unreachable)))
                                 (local.set $nkey (array.get $Values (local.get $vals) (i32.const 0)))
                                 (local.set $nval (array.get $Values (local.get $vals) (i32.const 1))))
                                (else (call $raise-wrong-number-of-values-received
                                            (i32.const 2)
                                            (i32.const 1))
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
              [who-symbol '($symbol:hash-filter
                            $symbol:hash-filter-keys
                            $symbol:hash-filter-values)]
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
                   (then (call $raise-argument-error1
                               (global.get ,who-symbol)
                               (global.get $string:hash?)
                               (local.get $ht))
                         (unreachable)))

               ;; Validate predicate
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                   (then (call $raise-argument-error:procedure-expected/who
                               (global.get ,who-symbol)
                               (local.get $proc))
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
               (if (ref.test (ref $HashEqImmutable) (local.get $ht))
                   (then (return (call $hash-filter/generic
                                       (global.get ,who-symbol)
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (if (ref.test (ref $HashEqvImmutable) (local.get $ht))
                   (then (return (call $hash-filter/generic
                                       (global.get ,who-symbol)
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (if (ref.test (ref $HashEqualImmutable) (local.get $ht))
                   (then (return (call $hash-filter/generic
                                       (global.get ,who-symbol)
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (if (ref.test (ref $HashEqualAlwaysImmutable) (local.get $ht))
                   (then (return (call $hash-filter/generic
                                       (global.get ,who-symbol)
                                       (local.get $ht)
                                       (local.get $proc)
                                       (i32.const ,mode)))))
               (unreachable)))))

   (function-forms->runtime-helpers
    'hash-filter-runtime-only-helpers
    '(
        ;; hash-filter/generic : symbol? immutable-hash? procedure? i32 -> immutable-hash?
        ;;   Iterator-backed fallback for immutable hash wrappers.
        (func $hash-filter/generic
              (param $who  (ref eq)) ;; public primitive name
              (param $ht   (ref eq)) ;; immutable hash table
              (param $proc (ref eq)) ;; predicate
              (param $mode i32)      ;; 0 = key/value, 1 = key, 2 = value
              (result      (ref eq))
              (local $f     (ref $Procedure))
              (local $finv  (ref $ProcedureInvoker))
              (local $args  (ref $Args))
              (local $pos   (ref eq))
              (local $key   (ref eq))
              (local $val   (ref eq))
              (local $res   (ref eq))
              (local $dst   (ref eq))
              (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
                  (then (call $raise-argument-error:procedure-expected/who
                              (local.get $who)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args
                         (if (result (ref $Args))
                             (i32.eq (local.get $mode) (i32.const 0))
                             (then (array.new $Args (global.get $null) (i32.const 2)))
                             (else (array.new $Args (global.get $null) (i32.const 1)))))
              (local.set $pos  (call $mutable-hash-iterate-first (local.get $ht)))
              (local.set $dst  (call $hash-clear (local.get $ht)))
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
                           (if (i32.eq (local.get $mode) (i32.const 0))
                               (then (array.set $Args (local.get $args) (i32.const 0) (local.get $key))
                                     (array.set $Args (local.get $args) (i32.const 1) (local.get $val)))
                               (else (if (i32.eq (local.get $mode) (i32.const 1))
                                         (then (array.set $Args (local.get $args) (i32.const 0) (local.get $key)))
                                         (else (array.set $Args (local.get $args) (i32.const 0) (local.get $val))))))
                           (local.set $res
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $finv)))
                           (if (ref.eq (local.get $res) (global.get $false))
                               (then (nop))
                               (else (local.set $dst
                                                (call $hash-set
                                                      (local.get $dst)
                                                      (local.get $key)
                                                      (local.get $val)))))
                           (local.set $pos
                                      (call $mutable-hash-iterate-next
                                            (local.get $ht)
                                            (local.get $pos)))
                           (br $walk)))
              (local.get $dst))))

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
               (if (ref.eq (call $procedure? (local.get $proc))
                              (global.get $false))
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
              [who-symbol     '($symbol:hash-keys $symbol:hash-values)]
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
                   (then (call $raise-argument-error1
                               (global.get ,who-symbol)
                               (global.get $string:hash?)
                               (local.get $ht))
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

;; hash-code-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate hash-code helpers shared by mutable and immutable hash support.
(define hash-code-runtime-only-helpers
  (function-forms->runtime-helpers
   'hash-code-runtime-only-helpers
   '(
      (func $splitmix32 (result i32)
            (local $z i32)
            ;; z = state += 0x9E3779B9
            (local.set $z (i32.add (global.get $next-hash-state) (i32.const 0x9E3779B9)))
            (global.set $next-hash-state (local.get $z))
            ;; z ^= (z >> 16)
            (local.set $z (i32.xor (local.get $z) (i32.shr_u (local.get $z) (i32.const 16))))
            ;; z *= 0x85EBCA6B
            (local.set $z (i32.mul (local.get $z) (i32.const 0x85EBCA6B)))
            ;; z ^= (z >> 13)
            (local.set $z (i32.xor (local.get $z) (i32.shr_u (local.get $z) (i32.const 13))))
            ;; z *= 0xC2B2AE35
            (local.set $z (i32.mul (local.get $z) (i32.const 0xC2B2AE35)))
            ;; z ^= (z >> 16)
            (local.set $z (i32.xor (local.get $z) (i32.shr_u (local.get $z) (i32.const 16))))
            (local.get $z))

      (func $eq-hash-code (type $Prim1)
            (param $v (ref eq))
            (result (ref eq))

            (ref.i31
             (i32.shl (call $eq-hash/i32
                            (local.get $v))
                      (i32.const 1))))

      (func $eq-hash/i32
            (param $v (ref eq))
            (result   i32)

            (local $v-i31 i32)
            (local $heap  (ref $Heap))
            (local $h     i32)
            (local $f     (ref $Flonum))
            (local $bits i64)
            (local $low  i32)
            (local $high i32)
            (local $x    i32)

            (if (result i32)
                (ref.test (ref i31) (local.get $v))
                ;; Immediates
                (then
                 ;; --- Mix i31 immediate using Murmur3-style scramble ---
                 (local.set $v-i31 (i31.get_u (ref.cast (ref i31) (local.get $v))))
                 (i32.mul
                  (i32.rotl
                   (i32.mul (local.get $v-i31) (i32.const 0xcc9e2d51))
                   (i32.const 15))
                  (i32.const 0x1b873593)))
                ;; Notes:
                ;;   If the special case is commented out, then eq-hash-code
                ;;   will always produce the same hash code for the same flonum value.
                ;;   But that is not enough to make flonums work with $HashEQ since,
                ;;   we are using (ref.eq ...) to test for equality.
                ;; (else
                ;;  ;; --- Special case: flonum ---
                ;;  (if (result i32)
                ;;      (ref.test (ref $Flonum) (local.get $v))
                ;;      (then
                ;;       (local.set $f    (ref.cast (ref $Flonum) (local.get $v)))
                ;;       (local.set $bits (i64.reinterpret_f64
                ;;                         (struct.get $Flonum $v (local.get $f))))
                ;;       (local.set $low  (i32.wrap_i64 (local.get $bits)))
                ;;       (local.set $high (i32.wrap_i64 (i64.shr_u (local.get $bits) (i64.const 32))))
                ;;       (local.set $x    (i32.xor (local.get $low) (local.get $high)))
                ;;       ;; Murmur3 mix again
                ;;       (i32.mul
                ;;        (i32.rotl
                ;;         (i32.mul (local.get $x) (i32.const 0xcc9e2d51))
                ;;         (i32.const 15))
                ;;        (i32.const 0x1b873593)))

                (else
                 ;; --- Heap object: return or assign hash without mixing for now ---
                 (local.set $heap (ref.cast (ref $Heap) (local.get $v)))
                 (local.set $h    (struct.get $Heap $hash (local.get $heap)))
                 (if (result i32)
                     (i32.eqz (local.get $h))
                     ;; If the current stored hash value is zero,
                     ;; it means the hash value hasn't been computed yet.
                     (then (local.set $h (call $splitmix32))
                           ;; If $splitmix32 happens to return 0, we need a different
                           ;; value - since 0 means "not computed yet".
                           (if (i32.eqz (local.get $h))
                               (then (local.set $h (i32.const 2))))
                           ; Store we newly computed hash value.
                           (struct.set $Heap $hash (local.get $heap) (local.get $h))
                           (local.get $h))
                     ;; Just use the existing hash value.
                     (else (local.get $h))))))


      (func $eqv-hash-code (type $Prim1)
            (param $v (ref eq))
            (result (ref eq))

            (ref.i31
             (i32.shl (call $eqv-hash/i32
                            (local.get $v))
                      (i32.const 1))))

      (func $eqv-hash/i32
            (param $v (ref eq))
            (result   i32)

            (local $v-i31 i32)
            (local $heap  (ref $Heap))
            (local $h     i32)
            (local $f     (ref $Flonum))
            (local $c     (ref $Complex))
            (local $bits i64)
            (local $low  i32)
            (local $high i32)
            (local $x    i32)
            (local $hr   i32)
            (local $hi   i32)

            (if (ref.test (ref $Bignum) (local.get $v))
                (then (return (call $bignum-hash/i32
                                    (ref.cast (ref $Bignum) (local.get $v))))))

            (if (result i32)
                (ref.test (ref i31) (local.get $v))
                (then
                 ;; --- Mix i31 immediate using Murmur3-style scramble ---
                 (local.set $v-i31 (i31.get_u (ref.cast (ref i31) (local.get $v))))
                 (i32.mul
                  (i32.rotl
                   (i32.mul (local.get $v-i31) (i32.const 0xcc9e2d51))
                   (i32.const 15))
                  (i32.const 0x1b873593)))
                (else
                 ;; --- Special case: flonum hashed by value ---
                 (if (result i32)
                     (ref.test (ref $Flonum) (local.get $v))
                     (then
                      (local.set $f    (ref.cast (ref $Flonum) (local.get $v)))
                      (local.set $bits (i64.reinterpret_f64
                                        (struct.get $Flonum $v (local.get $f))))
                      (local.set $low  (i32.wrap_i64 (local.get $bits)))
                      (local.set $high (i32.wrap_i64 (i64.shr_u (local.get $bits) (i64.const 32))))
                      (local.set $x    (i32.xor (local.get $low) (local.get $high)))
                      ;; Murmur3 mix again
                      (i32.mul
                       (i32.rotl
                        (i32.mul (local.get $x) (i32.const 0xcc9e2d51))
                        (i32.const 15))
                       (i32.const 0x1b873593)))
                     (else
                      ;; --- Complex numbers are hashed by their components. ---
                      (if (result i32)
                          (ref.test (ref $Complex) (local.get $v))
                          (then
                           (local.set $c (ref.cast (ref $Complex) (local.get $v)))
                           (local.set $hr (call $eqv-hash/i32
                                                (struct.get $Complex $real (local.get $c))))
                           (local.set $hi (call $eqv-hash/i32
                                                (struct.get $Complex $imag (local.get $c))))
                           (i32.add (i32.mul (local.get $hr) (i32.const 33))
                                    (local.get $hi)))
                          (else
                           ;; --- Heap object: return or assign hash without mixing for now ---
                           (local.set $heap (ref.cast (ref $Heap) (local.get $v)))
                           (local.set $h (struct.get $Heap $hash (local.get $heap)))
                           (if (result i32)
                               (i32.eqz (local.get $h))
                               ;; If the current stored hash value is zero,
                               ;; it means the hash value hasn't been computed yet.
                               (then (local.set $h (call $splitmix32))
                                     ;; If $splitmix32 happens to return 0, we need a different
                                     ;; value - since 0 means "not computed yet".
                                     (if (i32.eqz (local.get $h))
                                         (then (local.set $h (i32.const 2))))
                                     ; Store the newly computed hash value.
                                     (struct.set $Heap $hash (local.get $heap) (local.get $h))
                                     (local.get $h))
                               ;; Just use the existing hash value.
                               (else (local.get $h))))))))))))
   )

;; hash-equal-code-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate equal?/equal-always? hash-code dispatch helpers.
(define hash-equal-code-runtime-only-helpers
  (function-forms->runtime-helpers
   'hash-equal-code-runtime-only-helpers
   '(
      ;; equal-hash-code -- computes a hash code consistent with equal?
      ;;   Supports struct customization via prop:equal+hash.
      ;;   Note: currently does not support user-defined extensions via
      ;;         gen:equal+hash or gen:equal-mode+hash.

      (func $equal-hash-code (type $Prim1)
            (param $v (ref eq))
            (result (ref eq))

            (ref.i31
             (i32.shl (call $equal-hash/i32 (local.get $v))
                      (i32.const 1))))

      ;; equal-always-hash-code : any/c -> fixnum?
      ;;   Compute a hash code consistent with equal-always?. Mutable
      ;;   containers hash by identity; immutable containers hash
      ;;   structurally with equal-always-hash/i32 for their contents.
      (func $equal-always-hash-code (type $Prim1)
            (param $v (ref eq))
            (result (ref eq))

            (ref.i31
             (i32.shl (call $equal-always-hash/i32 (local.get $v))
                      (i32.const 1))))

      (func $equal-always-hash/i32
            (param $v (ref eq))
            (result i32)

            (local $str (ref $String))
            (local $bs  (ref $Bytes))
            (local $kw  (ref $Keyword))

            (if (ref.test (ref i31) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            (if (ref.test (ref $Bignum) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            (if (ref.test (ref $Flonum) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            (if (ref.test (ref $Complex) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            (if (ref.test (ref $String) (local.get $v))
                (then (local.set $str (ref.cast (ref $String) (local.get $v)))
                      (if (i32.eq (struct.get $String $immutable (local.get $str))
                                  (i32.const 1))
                          (then (return (call $string-hash/i32 (local.get $str))))
                          (else (return (call $eq-hash/i32 (local.get $v)))))))
            (if (ref.test (ref $Keyword) (local.get $v))
                (then (local.set $kw (ref.cast (ref $Keyword) (local.get $v)))
                      (return (call $string-hash/i32
                                    (struct.get $Keyword $str (local.get $kw))))))
            (if (ref.test (ref $Bytes) (local.get $v))
                (then (local.set $bs (ref.cast (ref $Bytes) (local.get $v)))
                      (if (i32.eq (struct.get $Bytes $immutable (local.get $bs))
                                  (i32.const 1))
                          (then (return (call $bytes-hash/i32 (local.get $bs))))
                          (else (return (call $eq-hash/i32 (local.get $v)))))))
            (if (ref.test (ref $Pair) (local.get $v))
                (then (return_call $equal-always-hash/pair
                                   (ref.cast (ref $Pair) (local.get $v)))))
            (if (ref.test (ref $MPair) (local.get $v))
                (then (return (call $eq-hash/i32 (local.get $v)))))
            (if (ref.test (ref $Box) (local.get $v))
                (then (return_call $equal-always-hash/box
                                   (ref.cast (ref $Box) (local.get $v)))))
            (if (ref.test (ref $Vector) (local.get $v))
                (then (return_call $equal-always-hash/vector
                                   (ref.cast (ref $Vector) (local.get $v)))))
            (if (ref.test (ref $Struct) (local.get $v))
                (then (return_call $equal-always-hash/struct
                                   (ref.cast (ref $Struct) (local.get $v)))))
            (return (call $eqv-hash/i32 (local.get $v))))

      (func $equal-hash/i32
            (param $v (ref eq))
            (result i32)

            (local $str   (ref $String))
            (local $bs    (ref $Bytes))
            (local $kw    (ref $Keyword))
            (local $h     i32)

            ;; immediates and numbers fall back to eqv-hash
            (if (ref.test (ref i31) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            (if (ref.test (ref $Bignum) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            (if (ref.test (ref $Flonum) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            (if (ref.test (ref $Complex) (local.get $v))
                (then (return (call $eqv-hash/i32 (local.get $v)))))
            ;; strings
            (if (ref.test (ref $String) (local.get $v))
                (then (local.set $str (ref.cast (ref $String) (local.get $v)))
                      (local.set $h (call $string-hash/i32 (local.get $str)))
                      ;; reset memoized hash so eq-hash-code can still assign
                      (struct.set $String $hash (local.get $str) (i32.const 0))
                      (return (local.get $h))))
            ;; keywords
            (if (ref.test (ref $Keyword) (local.get $v))
                (then (local.set $kw  (ref.cast (ref $Keyword) (local.get $v)))
                      (local.set $str (struct.get $Keyword $str (local.get $kw)))
                      (local.set $h   (call $string-hash/i32 (local.get $str)))
                      ;; reset memoized hashes so eq-hash-code can still assign
                      (struct.set $String  $hash (local.get $str) (i32.const 0))
                      (struct.set $Keyword $hash (local.get $kw)  (i32.const 0))
                      (return (local.get $h))))
            ;; bytes
            (if (ref.test (ref $Bytes) (local.get $v))
                (then (local.set $bs (ref.cast (ref $Bytes) (local.get $v)))
                      (return (call $bytes-hash/i32 (local.get $bs)))))
            ;; pair
            (if (ref.test (ref $Pair) (local.get $v))
                (then (return_call $equal-hash/pair
                                   (ref.cast (ref $Pair) (local.get $v)))))
            ;; mpair
            (if (ref.test (ref $MPair) (local.get $v))
                (then (return_call $equal-hash/mpair
                                   (ref.cast (ref $MPair) (local.get $v)))))
            ;; box
            (if (ref.test (ref $Box) (local.get $v))
                (then (return_call $equal-hash/box
                                   (ref.cast (ref $Box) (local.get $v)))))
            ;; vector
            (if (ref.test (ref $Vector) (local.get $v))
                (then (return_call $equal-hash/vector
                                   (ref.cast (ref $Vector) (local.get $v)))))
            ;; struct
            (if (ref.test (ref $Struct) (local.get $v))
                (then (return_call $equal-hash/struct
                                   (ref.cast (ref $Struct) (local.get $v)))))
            ;; hash table
            (if (ref.test (ref $Hash) (local.get $v))
                (then (return_call $equal-hash/hash
                                   (ref.cast (ref $Hash) (local.get $v)))))
            ;; fallback to eqv-hash for other heap objects (symbols, etc.)
            (return (call $eqv-hash/i32 (local.get $v))))))
   )

;; hash-equal-worker-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate structural equal?/equal-always? hash-code worker helpers.
(define hash-equal-worker-runtime-only-helpers
  (append
   (function-forms->runtime-helpers
    'hash-equal-worker-runtime-only-helpers
    '(
      (func $equal-hash/pair
            (param $p (ref $Pair))
            (result i32)

            (local $heap (ref $Heap))
            (local $h    i32)
            (local $ha   i32)
            (local $hd   i32)

            (local.set $heap (ref.cast (ref $Heap) (local.get $p)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            ;; cycle detection
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $ha (call $equal-hash/i32 (struct.get $Pair $a (local.get $p))))
            (local.set $hd (call $equal-hash/i32 (struct.get $Pair $d (local.get $p))))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (local.set $h (i32.add (i32.mul (local.get $ha) (i32.const 33))
                                   (local.get $hd)))
            (local.get $h))

      (func $equal-hash/mpair
            (param $p (ref $MPair))
            (result i32)

            (local $heap (ref $Heap))
            (local $h    i32)
            (local $ha   i32)
            (local $hd   i32)

            (local.set $heap (ref.cast (ref $Heap) (local.get $p)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            ;; cycle detection
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $ha (call $equal-hash/i32 (struct.get $MPair $a (local.get $p))))
            (local.set $hd (call $equal-hash/i32 (struct.get $MPair $d (local.get $p))))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (local.set $h (i32.add (i32.mul (local.get $ha) (i32.const 33))
                                   (local.get $hd)))
            (local.get $h))

      (func $equal-hash/box
            (param $b (ref $Box))
            (result i32)

            (local $heap (ref $Heap))
            (local $h    i32)

            (local.set $heap (ref.cast (ref $Heap) (local.get $b)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $h (call $equal-hash/i32 (struct.get $Box $v (local.get $b))))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (i32.add (i32.const 1) (local.get $h)))

      (func $equal-hash/vector
            (param $v (ref $Vector))
            (result i32)

            (local $heap (ref $Heap))
            (local $arr  (ref $Array))
            (local $len  i32)
            (local $i    i32)
            (local $h    i32)
            (local $elem (ref eq))

            (local.set $heap (ref.cast (ref $Heap) (local.get $v)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $arr (struct.get $Vector $arr (local.get $v)))
            (local.set $len (array.len (local.get $arr)))
            (local.set $i   (i32.const 0))
            (local.set $h   (i32.const 0))
            (block $done
                   (loop $loop
                         (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                         (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                         (local.set $h (i32.add (i32.mul (local.get $h) (i32.const 33))
                                                (call $equal-hash/i32 (local.get $elem))))
                         (local.set $i (i32.add (local.get $i) (i32.const 1)))
                         (br $loop)))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (local.get $h))

      (func $equal-always-hash/pair
            (param $p (ref $Pair))
            (result i32)

            (local $heap (ref $Heap))
            (local $h    i32)
            (local $ha   i32)
            (local $hd   i32)

            (local.set $heap (ref.cast (ref $Heap) (local.get $p)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $ha (call $equal-always-hash/i32 (struct.get $Pair $a (local.get $p))))
            (local.set $hd (call $equal-always-hash/i32 (struct.get $Pair $d (local.get $p))))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (i32.add (i32.mul (local.get $ha) (i32.const 33))
                     (local.get $hd)))

      (func $equal-always-hash/box
            (param $b (ref $Box))
            (result i32)

            (local $heap (ref $Heap))
            (local $h    i32)

            (if (i32.ne (struct.get $Box $immutable (local.get $b)) (i32.const 1))
                (then (return (call $eq-hash/i32 (ref.cast (ref eq) (local.get $b))))))
            (local.set $heap (ref.cast (ref $Heap) (local.get $b)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $h (call $equal-always-hash/i32 (struct.get $Box $v (local.get $b))))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (i32.add (i32.const 1) (local.get $h)))

      (func $equal-always-hash/vector
            (param $v (ref $Vector))
            (result i32)

            (local $heap (ref $Heap))
            (local $arr  (ref $Array))
            (local $len  i32)
            (local $i    i32)
            (local $h    i32)
            (local $elem (ref eq))

            (if (i32.ne (struct.get $Vector $immutable (local.get $v)) (i32.const 1))
                (then (return (call $eq-hash/i32 (ref.cast (ref eq) (local.get $v))))))
            (local.set $heap (ref.cast (ref $Heap) (local.get $v)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $arr (struct.get $Vector $arr (local.get $v)))
            (local.set $len (array.len (local.get $arr)))
            (local.set $i   (i32.const 0))
            (local.set $h   (i32.const 0))
            (block $done
                   (loop $loop
                         (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                         (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                         (local.set $h (i32.add (i32.mul (local.get $h) (i32.const 33))
                                                (call $equal-always-hash/i32 (local.get $elem))))
                         (local.set $i (i32.add (local.get $i) (i32.const 1)))
                         (br $loop)))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (local.get $h))

      (func $equal-always-hash/struct
            (param $s (ref $Struct))
            (result i32)

            (local $type          (ref $StructType))
            (local $prop-name     (ref $Symbol))
            (local $prop-sentinel (ref eq))
            (local $prop-val      (ref eq))
            (local $prop-info     (ref $Array))

            (local.set $type (struct.get $Struct $type (local.get $s)))
            (local.set $prop-name (ref.cast (ref $Symbol)
                                             (global.get $symbol:prop:equal+hash)))
            (local.set $prop-sentinel (call $cons (global.get $false) (global.get $false)))
            (local.set $prop-val
                       (call $struct-type-property-lookup-by-name
                             (local.get $type)
                             (local.get $prop-name)
                             (local.get $prop-sentinel)))
            (if (i32.eqz (ref.eq (local.get $prop-val) (local.get $prop-sentinel)))
                (then
                 (local.set $prop-info (ref.cast (ref $Array) (local.get $prop-val)))
                 (return (call $struct-equal+hash-hash
                               (local.get $prop-info)
                               (local.get $s)
                               (i32.const 0)))))
            (call $eqv-hash/i32 (ref.cast (ref eq) (local.get $s))))

      (func $equal-hash/struct
            (param $s (ref $Struct))
            (result i32)

            (local $heap   (ref $Heap))
            (local $type   (ref $StructType))
            (local $fields (ref $Array))
            (local $len    i32)
            (local $i      i32)
            (local $h      i32)
            (local $elem   (ref eq))
            ; for prop:equal+hash if present
            (local $prop-name     (ref $Symbol))
            (local $prop-sentinel (ref eq))
            (local $prop-val      (ref eq))
            (local $prop-info     (ref $Array))

            (local.set $heap (ref.cast (ref $Heap) (local.get $s)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $type   (struct.get $Struct $type (local.get $s)))
            (local.set $prop-name (ref.cast (ref $Symbol)
                                             (global.get $symbol:prop:equal+hash)))
            (local.set $prop-sentinel (call $cons (global.get $false) (global.get $false)))
            (local.set $prop-val
                       (call $struct-type-property-lookup-by-name
                             (local.get $type)
                             (local.get $prop-name)
                             (local.get $prop-sentinel)))
            (if (i32.eqz (ref.eq (local.get $prop-val) (local.get $prop-sentinel)))
                (then
                 (local.set $prop-info (ref.cast (ref $Array) (local.get $prop-val)))
                 (local.set $h (call $struct-equal+hash-hash
                                     (local.get $prop-info)
                                     (local.get $s)
                                     (i32.const 1)))
                 (struct.set $Heap $hash (local.get $heap) (i32.const 0))
                 (return (local.get $h))))
            (local.set $h      (call $eqv-hash/i32 (local.get $type)))
            (local.set $fields (struct.get $Struct $fields (local.get $s)))
            (local.set $len    (array.len (local.get $fields)))
            (local.set $i      (i32.const 0))
            (block $done
                   (loop $loop
                         (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                         (local.set $elem (array.get $Array (local.get $fields) (local.get $i)))
                         (local.set $h (i32.add (i32.mul (local.get $h) (i32.const 33))
                                                (call $equal-hash/i32 (local.get $elem))))
                         (local.set $i (i32.add (local.get $i) (i32.const 1)))
                         (br $loop)))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (local.get $h))

      (func $equal-hash/hash
            (param $ht (ref eq))  ;; hash table
            (result i32)

            (if (ref.test (ref $Hash) (local.get $ht))
                (then (return_call $equal-hash/hash-generic (local.get $ht))))
            (return (call $eqv-hash/i32 (local.get $ht))))

      ;; equal-hash/hash-generic : hash? -> i32
      ;;   Hash table contents with the table's own key-comparison mode.
      (func $equal-hash/hash-generic
            (param $ht (ref eq))
            (result i32)

            (local $heap    (ref $Heap))
            (local $h       i32)
            (local $kind    i32)
            (local $pos     (ref eq))
            (local $key     (ref eq))
            (local $val     (ref eq))
            (local $entry-h i32)
            (local $key-h   i32)
            (local $val-h   i32)

            (local.set $heap (ref.cast (ref $Heap) (local.get $ht)))
            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $kind (call $hash-kind/i32 (local.get $ht)))
            (local.set $h (i32.const 0))
            (local.set $pos (call $mutable-hash-iterate-first (local.get $ht)))
            (block $done
                   (loop $loop
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
                         (local.set $key-h
                                    (call $hash-key-hash/kind
                                          (local.get $kind)
                                          (local.get $key)))
                         (local.set $entry-h
                                    (i32.mul
                                     (i32.rotl
                                      (i32.mul (local.get $key-h) (i32.const 0xcc9e2d51))
                                      (i32.const 15))
                                     (i32.const 0x1b873593)))
                         (local.set $val-h (call $equal-hash/i32 (local.get $val)))
                         (local.set $entry-h
                                    (i32.xor (local.get $entry-h) (local.get $val-h)))
                         (local.set $entry-h
                                    (i32.mul
                                     (i32.rotl
                                      (i32.mul (local.get $entry-h) (i32.const 0xcc9e2d51))
                                      (i32.const 15))
                                     (i32.const 0x1b873593)))
                         (local.set $h (i32.add (local.get $h) (local.get $entry-h)))
                         (local.set $pos
                                    (call $mutable-hash-iterate-next
                                          (local.get $ht)
                                          (local.get $pos)))
                         (br $loop)))
            (local.set $h (i32.add
                           (local.get $h)
                           (call $fixnum->i32 (call $hash-count (local.get $ht)))))
            (local.set $h (i32.add (local.get $h) (local.get $kind)))
            (local.set $h
                       (i32.mul
                        (i32.rotl
                         (i32.mul (local.get $h) (i32.const 0xcc9e2d51))
                         (i32.const 15))
                        (i32.const 0x1b873593)))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (local.get $h))

      (func $equal-hash/hash-core
            (param $heap    (ref $Heap))
            (param $entries (ref $Array))
            (param $count   i32)
            (param $salt    i32)
            (result i32)

            (local $h        i32)
            (local $capacity i32)
            (local $i        i32)
            (local $key      (ref eq))
            (local $val      (ref eq))
            (local $entry-h  i32)
            (local $key-h    i32)
            (local $val-h    i32)

            (local.set $h (struct.get $Heap $hash (local.get $heap)))
            (if (i32.eq (local.get $h) (i32.const -2147483648))
                (then (return (i32.const 0))))
            (struct.set $Heap $hash (local.get $heap) (i32.const -2147483648))
            (local.set $capacity (i32.div_u (array.len (local.get $entries)) (i32.const 2)))
            (local.set $i (i32.const 0))
            (local.set $h (i32.const 0))
            (block $done
                   (loop $loop
                         (br_if $done (i32.ge_u (local.get $i) (local.get $capacity)))
                         (local.set $key (array.get $Array
                                                    (local.get $entries)
                                                    (i32.shl (local.get $i) (i32.const 1))))
                         (if (i32.or (ref.eq (local.get $key) (global.get $missing))
                                     (ref.eq (local.get $key) (global.get $tombstone)))
                             (then (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                   (br $loop)))
                         (local.set $val (array.get $Array
                                                    (local.get $entries)
                                                    (i32.add (i32.shl (local.get $i) (i32.const 1))
                                                             (i32.const 1))))
                         (local.set $key-h (call $equal-hash/i32 (local.get $key)))
                         (local.set $entry-h
                                    (i32.mul
                                     (i32.rotl
                                      (i32.mul (local.get $key-h) (i32.const 0xcc9e2d51))
                                      (i32.const 15))
                                     (i32.const 0x1b873593)))
                         (local.set $val-h (call $equal-hash/i32 (local.get $val)))
                         (local.set $entry-h
                                    (i32.xor (local.get $entry-h) (local.get $val-h)))
                         (local.set $entry-h
                                    (i32.mul
                                     (i32.rotl
                                      (i32.mul (local.get $entry-h) (i32.const 0xcc9e2d51))
                                      (i32.const 15))
                                     (i32.const 0x1b873593)))
                         (local.set $h (i32.add (local.get $h) (local.get $entry-h)))
                         (local.set $i (i32.add (local.get $i) (i32.const 1)))
                         (br $loop)))
            (local.set $h (i32.add (local.get $h) (local.get $count)))
            (local.set $h (i32.add (local.get $h) (local.get $salt)))
            (local.set $h
                       (i32.mul
                        (i32.rotl
                         (i32.mul (local.get $h) (i32.const 0xcc9e2d51))
                         (i32.const 15))
                        (i32.const 0x1b873593)))
            (struct.set $Heap $hash (local.get $heap) (i32.const 0))
            (local.get $h))

      (func $bytes-hash/i32 ;  32-bit FNV-1a hash algorithm
            (param $b (ref $Bytes))
            (result i32)

            (local $hash i32)
            (local $arr  (ref $I8Array))
            (local $len  i32)
            (local $i    i32)
            (local $byte i32)

            (local.set $hash (i32.const 2166136261))
            (local.set $arr  (struct.get $Bytes $bs (local.get $b)))
            (local.set $len  (array.len (local.get $arr)))
            (local.set $i    (i32.const 0))
            (block $done
                   (loop $loop
                         (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                         (local.set $byte (array.get_u $I8Array (local.get $arr) (local.get $i)))
                         (local.set $hash
                                    (i32.mul
                                     (i32.xor (local.get $hash) (local.get $byte))
                                     (i32.const 16777619)))
                         (local.set $i (i32.add (local.get $i) (i32.const 1)))
                         (br $loop)))
            (local.get $hash))))

   (for/list ([name '($equal-hash/hasheq-mutable
                      $equal-hash/hasheqv-mutable
                      $equal-hash/hashequal-mutable
                      $equal-hash/hashalw-mutable)]
              [type '($HashEqMutable
                      $HashEqvMutable
                      $HashEqualMutable
                      $HashEqualAlwaysMutable)]
              [salt '(0 1 2 3)])
     (core-runtime-helper
      name
      (symbol->string name)
      (lambda ()
        `(func ,name
               (param $ht (ref ,type))
               (result i32)

               (return_call $equal-hash/hash-core
                            (ref.cast (ref $Heap) (local.get $ht))
                            (struct.get ,type $entries (local.get $ht))
                            (struct.get ,type $count   (local.get $ht))
                            (i32.const ,salt))))))))

;; hash-core-runtime-helper-names : (listof symbol?)
;;   Name generic hash helpers available in the standalone core runtime.
(define hash-core-runtime-helper-names
  (append hash-predicate-core-runtime-helper-names
          hash-table-predicate-core-runtime-helper-names
          hash-count-list-runtime-only-helper-names
          hash-for-each-runtime-only-helper-names
          hash-map-runtime-only-helper-names
          hash-map-copy-runtime-only-helper-names
          hash-filter-runtime-only-helper-names
          hash-key-value-runtime-only-helper-names
          '($equal-hash/hash-core
            $bytes-hash/i32)))

;; hash-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate generic hash helpers that span mutable and immutable hash kinds.
(define hash-all-runtime-helpers
  (append hash-predicate-runtime-only-helpers
          hash-table-predicate-runtime-only-helpers
          hash-count-runtime-only-helpers
          hash-list-runtime-only-helpers
          hash-for-each-runtime-only-helpers
          hash-map-runtime-only-helpers
          hash-map/copy-runtime-only-helpers
          hash-filter-runtime-only-helpers
          hash-keys-values-runtime-only-helpers
          hash-code-runtime-only-helpers
          hash-equal-code-runtime-only-helpers
          hash-equal-worker-runtime-only-helpers))

;; hash-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate generic hash helpers available in the standalone core runtime.
(define hash-core-runtime-helpers
  (select-runtime-helpers hash-all-runtime-helpers
                          hash-core-runtime-helper-names))

;; hash-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generic hash helpers that still depend on monolithic runtime globals.
(define hash-runtime-only-helpers
  (remove-runtime-helpers hash-all-runtime-helpers
                          hash-core-runtime-helper-names))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define hash-helper-index
    (make-core-runtime-helper-index
     (append hash-core-runtime-helpers
             hash-runtime-only-helpers)))

  (check-equal? hash-seed-global-names
                '($next-hash-state))

  (check-equal?
   (map core-runtime-helper-name hash-core-runtime-helpers)
   hash-core-runtime-helper-names)

  (check-equal?
   (map form-name
        (hash-predicate-core-runtime-helper-forms hash-helper-index))
   hash-predicate-core-runtime-helper-names)

  (check-equal?
   (map form-name (hash-predicate-runtime-helper-forms hash-helper-index))
   hash-predicate-runtime-only-helper-names)

  (check-equal?
   (map form-name
        (hash-table-predicate-core-runtime-helper-forms hash-helper-index))
   hash-table-predicate-core-runtime-helper-names)

  (check-equal?
   (map form-name (hash-table-predicate-runtime-helper-forms hash-helper-index))
   hash-table-predicate-runtime-only-helper-names)

  (check-equal?
   (map form-name (hash-table-operation-runtime-helper-forms hash-helper-index))
   (append hash-count-list-runtime-only-helper-names
           hash-for-each-runtime-only-helper-names
           hash-map-runtime-only-helper-names
           hash-map-copy-runtime-only-helper-names
           hash-filter-runtime-only-helper-names
           hash-key-value-runtime-only-helper-names))

  (check-equal?
   (map form-name (hash-code-runtime-helper-forms hash-helper-index))
   (append hash-seed-runtime-only-helper-names
           hash-equal-runtime-only-helper-names
           hash-equal-composite-runtime-only-helper-names)))
