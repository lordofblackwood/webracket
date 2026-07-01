#lang racket

(provide procedure-core-runtime-helpers
         procedure-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; procedure-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate procedure-call helpers that can be emitted in core runtime.
(define procedure-core-runtime-helpers
  (list
   ;; rest-arguments->list : (ref $Args) i32 -> (ref eq)
   ;;   Copy arguments from index n onward into a freshly allocated list.
   (core-runtime-helper
    '$rest-arguments->list
    "$rest-arguments->list"
    (lambda ()
      `(func $rest-arguments->list
             (param $args (ref $Args))
             (param $n    i32)
             (result      (ref eq))

             (local $len  i32)
             (local $i    i32)
             (local $x    (ref eq))
             (local $xs   (ref eq))
             ;; Compute length of args
             (local.set $len (array.len (local.get $args)))
             ;; Return empty list if n >= len
             (if (i32.ge_u (local.get $n) (local.get $len))
                 (then (return ,(Imm '()))))
             ;; Start with empty list
             (local.set $xs ,(Imm '()))
             ;; Start loop from len - 1 down to n (inclusive)
             (local.set $i (i32.sub (local.get $len) (i32.const 1)))
             (block $done
                    (loop $rev
                          ;; x = args[i]
                          (local.set $x (array.get $Args (local.get $args) (local.get $i)))
                          ;; xs = (cons x xs)
                          (local.set $xs
                                     (struct.new $Pair
                                                 (i32.const 0)        ;; dummy hash
                                                 (local.get $x)       ;; car
                                                 (local.get $xs)))    ;; cdr
                          ;; Stop when i == n
                          (br_if $done (i32.eq (local.get $i) (local.get $n)))
                          ;; i--
                          (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                          (br $rev)))
             (local.get $xs))))

   ;; rest-arguments->args : (ref $Args) i32 -> (ref $Args)
   ;;   Copy arguments from index n onward into a fresh argument array.
   (core-runtime-helper
    '$rest-arguments->args
    "$rest-arguments->args"
    (lambda ()
      `(func $rest-arguments->args
             (param $args (ref $Args))
             (param $n    i32)
             (result      (ref $Args))

             (local $len   i32)
             (local $count i32)
             (local $res   (ref $Args))

             (local.set $len (array.len (local.get $args)))
             (if (i32.ge_u (local.get $n) (local.get $len))
                 (then (return (array.new $Args ,(Imm '()) (i32.const 0)))))
             (local.set $count (i32.sub (local.get $len) (local.get $n)))
             (local.set $res (array.new $Args ,(Imm '()) (local.get $count)))
             (array.copy $Args $Args
                         (local.get $res)
                         (i32.const 0)
                         (local.get $args)
                         (local.get $n)
                         (local.get $count))
             (local.get $res))))))

;; procedure-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate procedure helpers used by the monolithic runtime.
(define procedure-runtime-only-helpers
  (function-forms->runtime-helpers
   'procedure-runtime-only-helpers
   '(
     ;; Support for the arity-at-least structure used by procedure-arity.
     (func $ensure-arity-at-least-type
           (result (ref $StructType))

           (local $existing (ref null $StructType))
           (local $std      (ref $StructType))
           (local $indices  (ref eq))

           (local.set $existing (global.get $arity-at-least-type))
           (if (ref.is_null (local.get $existing))
               (then
                (local.set $indices (call $list-from-range/checked (i32.const 0) (i32.const 1)))
                (local.set $std
                           (struct.new $StructType
                                       (i32.const 0)
                                       (ref.cast (ref $Symbol) (global.get $symbol:arity-at-least))
                                       (global.get $false)
                                       (i32.const 1)
                                       (local.get $indices)
                                       (global.get $null)
                                       (global.get $null)
                                       (ref.cast (ref eq) (call $struct-type-property-table-empty))
                                       (global.get $false)
                                       (local.get $indices)
                                       (global.get $false)
                                       (ref.cast (ref $Symbol) (global.get $symbol:arity-at-least))))
                (global.set $arity-at-least-type (local.get $std))
                (local.set $existing (local.get $std))))
           (ref.as_non_null (local.get $existing)))

     (func $arity-at-least/make
           (param $value i32)   ;; exact non-negative integer
           (result (ref eq))

           (local $std    (ref $StructType))
           (local $fields (ref $Array))

           (local.set $std (call $ensure-arity-at-least-type))
           (local.set $fields
                      (array.new_fixed $Array 1
                                       (ref.i31 (i32.shl (local.get $value) (i32.const 1)))))
           (ref.cast (ref eq)
                     (struct.new $Struct
                                 (i32.const 0)
                                 (global.get $false)
                                 (ref.i31 (i32.const 0))
                                 (global.get $false)
                                 (ref.func $invoke-struct)
                                 (local.get $std)
                                 (local.get $fields))))

     (func $make-arity-at-least (type $Prim1)
           (param $value (ref eq)) ; exact-nonnegative-integer?
           (result (ref eq))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $value)) (global.get $false))
               (then (call $raise-argument-error1
                           (global.get $symbol:make-arity-at-least)
                           (global.get $string:exact-nonnegative-integer?)
                           (local.get $value))
                     (unreachable)))
           (call $arity-at-least/make
                 (i32.shr_s
                  (i31.get_s (ref.cast (ref i31) (local.get $value)))
                  (i32.const 1))))

     (func $arity-at-least (type $Prim1)
           (param $value (ref eq)) ; exact-nonnegative-integer?
           (result (ref eq))

           (return_call $make-arity-at-least (local.get $value)))

     (func $raise-argument-error:arity-at-least-expected
           (param $who (ref eq))
           (param $got (ref eq))

           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:arity-at-least?)
                 (local.get $got)))

     (func $arity-at-least-unwrap
           (param $who (ref eq))
           (param $v   (ref eq))
           (result (ref $Struct))

           (local $struct (ref $Struct))
           (local $type   (ref eq))
           (local $std    (ref $StructType))
           (local $ok     i32)

           (local.set $std (call $ensure-arity-at-least-type))
           (if (i32.eqz (ref.test (ref $Struct) (local.get $v)))
               (then (call $raise-argument-error:arity-at-least-expected (local.get $who) (local.get $v))
                     (unreachable)))
           (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
           (local.set $type   (struct.get $Struct $type (local.get $struct)))
           (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
           (if (i32.eqz (local.get $ok))
               (then (call $raise-argument-error:arity-at-least-expected (local.get $who) (local.get $v))
                     (unreachable)))
           (local.get $struct))

     (func $arity-at-least? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $struct (ref $Struct))
           (local $type   (ref eq))
           (local $std    (ref $StructType))
           (local $ok     i32)

           (local.set $std (call $ensure-arity-at-least-type))
           (if (result (ref eq))
               (ref.test (ref $Struct) (local.get $v))
               (then
                (local.set $struct (ref.cast (ref $Struct) (local.get $v)))
                (local.set $type   (struct.get $Struct $type (local.get $struct)))
                (local.set $ok     (call $struct-type-is-a?/i32 (local.get $type) (local.get $std)))
                (if (result (ref eq))
                    (local.get $ok)
                    (then (global.get $true))
                    (else (global.get $false))))
               (else (global.get $false))))

     (func $arity-at-least-value (type $Prim1)
           (param $v (ref eq))
           (result (ref eq))

           (local $struct (ref $Struct))
           (local $fields (ref $Array))

           (local.set $struct (call $arity-at-least-unwrap
                                     (global.get $symbol:arity-at-least-value)
                                     (local.get $v)))
           (local.set $fields (struct.get $Struct $fields (local.get $struct)))
           (array.get $Array (local.get $fields) (i32.const 0)))

     (func $procedure-arity-entry->marker/i32
           (param $who (ref eq))
           (param $v   (ref eq))
           (result i32)

           (local $struct (ref $Struct))
           (local $fields (ref $Array))
           (local $value  (ref eq))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $v)) (global.get $true))
               (then
                (return
                 (i32.shr_s
                  (i31.get_s (ref.cast (ref i31) (local.get $v)))
                  (i32.const 1)))))
           (if (ref.eq (call $arity-at-least? (local.get $v)) (global.get $true))
               (then
                (local.set $struct (call $arity-at-least-unwrap (local.get $who) (local.get $v)))
                (local.set $fields (struct.get $Struct $fields (local.get $struct)))
                (local.set $value  (array.get $Array (local.get $fields) (i32.const 0)))
                (return
                 (i32.sub
                  (i32.const -1)
                  (i32.shr_s
                   (i31.get_s (ref.cast (ref i31) (local.get $value)))
                   (i32.const 1))))))
           (call $raise-argument-error1
                 (local.get $who)
                 (global.get $string:procedure-arity?)
                 (local.get $v))
           (unreachable))

     ;; procedure-arity? : any/c -> boolean?
     ;;   A procedure arity is an exact nonnegative integer, an
     ;;   arity-at-least value, or a proper list of those values.
     (func $procedure-arity? (type $Prim1)
           (param $v (ref eq))
           (result   (ref eq))

           (local $node  (ref eq))
           (local $entry (ref eq))

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $v))
                       (global.get $true))
               (then (return (global.get $true))))
           (if (ref.eq (call $arity-at-least? (local.get $v))
                       (global.get $true))
               (then (return (global.get $true))))
           (if (ref.eq (call $list? (local.get $v)) (global.get $false))
               (then (return (global.get $false))))
           (local.set $node (local.get $v))
           (block $done
                  (loop $loop
                        (br_if $done (ref.eq (local.get $node)
                                             (global.get $null)))
                        (local.set $entry
                                   (struct.get $Pair $a
                                               (ref.cast (ref $Pair)
                                                         (local.get $node))))
                        (if (ref.eq (call $exact-nonnegative-integer?
                                          (local.get $entry))
                                    (global.get $false))
                            (then
                             (if (ref.eq (call $arity-at-least?
                                               (local.get $entry))
                                         (global.get $false))
                                 (then (return (global.get $false))))))
                        (local.set $node
                                   (struct.get $Pair $d
                                               (ref.cast (ref $Pair)
                                                         (local.get $node))))
                        (br $loop)))
           (global.get $true))

     (func $procedure-arity-value->field
           (param $who   (ref eq))
           (param $arity (ref eq))
           (result (ref eq))

           (local $len    i32)
           (local $arr    (ref $I32Array))
           (local $i      i32)
           (local $node   (ref eq))
           (local $entry  (ref eq))
           (local $marker i32)

           (if (ref.eq (call $exact-nonnegative-integer? (local.get $arity)) (global.get $true))
               (then (return (local.get $arity))))
           (if (ref.eq (call $arity-at-least? (local.get $arity)) (global.get $true))
               (then
                (local.set $marker (call $procedure-arity-entry->marker/i32
                                         (local.get $who)
                                         (local.get $arity)))
                (return (ref.i31 (i32.shl (local.get $marker) (i32.const 1))))))
           (if (ref.eq (call $list? (local.get $arity)) (global.get $false))
               (then
                (call $raise-argument-error1
                      (local.get $who)
                      (global.get $string:procedure-arity?)
                      (local.get $arity))
                (unreachable)))
           (local.set $len (call $length/i32 (local.get $arity)))
           (if (i32.eqz (local.get $len))
               (then
                (return (ref.cast (ref eq)
                                  (array.new_fixed $I32Array 0)))))
           (if (i32.eq (local.get $len) (i32.const 1))
               (then
                (return
                 (ref.i31
                  (i32.shl
                   (call $procedure-arity-entry->marker/i32
                         (local.get $who)
                         (call $car (local.get $arity)))
                   (i32.const 1))))))
           (local.set $arr (call $i32array-make (local.get $len) (i32.const 0)))
           (local.set $node (local.get $arity))
           (local.set $i    (i32.const 0))
           (block $done
                  (loop $fill
                        (br_if $done (ref.eq (local.get $node) (global.get $null)))
                        (local.set $entry (struct.get $Pair $a
                                                      (ref.cast (ref $Pair) (local.get $node))))
                        (local.set $marker (call $procedure-arity-entry->marker/i32
                                                 (local.get $who)
                                                 (local.get $entry)))
                        (call $i32array-set! (local.get $arr) (local.get $i) (local.get $marker))
                        (local.set $node (struct.get $Pair $d
                                                     (ref.cast (ref $Pair) (local.get $node))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $fill)))
           (ref.cast (ref eq) (local.get $arr)))

     (func $procedure-arity-field->mask/i32
           (param $a (ref eq))
           (result i32)

           (local $arr   (ref $I32Array))
           (local $i     i32)
           (local $n     i32)
           (local $m     i32)
           (local $arity i32)
           (local $mask  i32)
           (local $start i32)

           (if (ref.test (ref i31) (local.get $a))
               (then
                (local.set $arity (i32.shr_s
                                   (i31.get_s
                                    (ref.cast (ref i31) (local.get $a)))
                                   (i32.const 1)))
                (return
                 (if (result i32)
                     (i32.ge_s (local.get $arity) (i32.const 0))
                     (then (i32.shl (i32.const 1) (local.get $arity)))
                     (else (i32.shl (i32.const -1)
                                    (i32.sub (i32.const -1) (local.get $arity))))))))
           (local.set $arr (ref.cast (ref $I32Array) (local.get $a)))
           (local.set $n   (array.len (local.get $arr)))
           (local.set $i   (i32.const 0))
           (local.set $mask (i32.const 0))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                        (local.set $m
                                   (array.get $I32Array (local.get $arr) (local.get $i)))
                        (if (i32.ge_s (local.get $m) (i32.const 0))
                            (then
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const 1) (local.get $m)))))
                            (else
                             (local.set $start
                                        (i32.sub (i32.const -1) (local.get $m)))
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const -1) (local.get $start))))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $mask))

     (func $procedure-arity-mask-value->field
           (param $who      (ref eq))
           (param $mask-raw (ref eq)) ; exact-integer?
           (result (ref eq))

           (local $mask          i32)
           (local $negative?     i32)
           (local $at-least-from i32)
           (local $limit         i32)
           (local $i             i32)
           (local $len           i32)
           (local $out           i32)
           (local $marker        i32)
           (local $arr           (ref $I32Array))

           (if (ref.eq (call $exact-integer? (local.get $mask-raw)) (global.get $false))
               (then
                (call $raise-argument-error1
                      (local.get $who)
                      (global.get $string:exact-integer?)
                      (local.get $mask-raw))
                (unreachable)))
           (local.set $mask
                      (i32.shr_s
                       (i31.get_s (ref.cast (ref i31) (local.get $mask-raw)))
                       (i32.const 1)))
           (local.set $negative? (i32.lt_s (local.get $mask) (i32.const 0)))
           (local.set $at-least-from (i32.const 31))
           (local.set $limit (i32.const 31))
           (if (local.get $negative?)
               (then
                ;; Negative masks represent exact arities below the first
                ;; all-ones suffix plus an arity-at-least marker.
                (local.set $at-least-from (i32.const 0))
                (block $found
                       (loop $find
                             (if (i32.eq (i32.shr_s
                                          (local.get $mask)
                                          (local.get $at-least-from))
                                         (i32.const -1))
                                 (then (br $found)))
                             (local.set $at-least-from
                                        (i32.add (local.get $at-least-from)
                                                 (i32.const 1)))
                             (br $find)))
                (local.set $limit (local.get $at-least-from))))

           (local.set $i (i32.const 0))
           (block $count-done
                  (loop $count
                        (br_if $count-done (i32.ge_u (local.get $i) (local.get $limit)))
                        (if (i32.ne (i32.and (local.get $mask)
                                             (i32.shl (i32.const 1) (local.get $i)))
                                    (i32.const 0))
                            (then
                             (local.set $marker (local.get $i))
                             (local.set $len (i32.add (local.get $len) (i32.const 1)))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $count)))
           (if (local.get $negative?)
               (then
                (local.set $marker
                           (i32.sub (i32.const -1) (local.get $at-least-from)))
                (local.set $len (i32.add (local.get $len) (i32.const 1)))))
           (if (i32.eqz (local.get $len))
               (then
                (return (ref.cast (ref eq)
                                  (array.new_fixed $I32Array 0)))))
           (if (i32.eq (local.get $len) (i32.const 1))
               (then
                (return (ref.i31 (i32.shl (local.get $marker) (i32.const 1))))))

           (local.set $arr (call $i32array-make (local.get $len) (i32.const 0)))
           (local.set $i (i32.const 0))
           (local.set $out (i32.const 0))
           (block $fill-done
                  (loop $fill
                        (br_if $fill-done (i32.ge_u (local.get $i) (local.get $limit)))
                        (if (i32.ne (i32.and (local.get $mask)
                                             (i32.shl (i32.const 1) (local.get $i)))
                                    (i32.const 0))
                            (then
                             (call $i32array-set!
                                   (local.get $arr)
                                   (local.get $out)
                                   (local.get $i))
                             (local.set $out (i32.add (local.get $out) (i32.const 1)))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $fill)))
           (if (local.get $negative?)
               (then
                (call $i32array-set!
                      (local.get $arr)
                      (local.get $out)
                      (i32.sub (i32.const -1) (local.get $at-least-from)))))
           (ref.cast (ref eq) (local.get $arr)))

     ;; make-composed-procedure : list? boolean? -> procedure?
     ;;   Build the procedure returned by compose or compose1.
     (func $make-composed-procedure
           (param $args    (ref eq))
           (param $single? (ref eq))
           (result         (ref eq))

           (local $procs (ref $Array))
           (local $n     i32)
           (local $i     i32)
           (local $p     (ref $Procedure))
           (local $free  (ref $Free))

           (local.set $procs (call $list->array (local.get $args)))
           (local.set $n     (array.len (local.get $procs)))
           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                        (if (i32.eqz
                             (ref.test (ref $Procedure)
                                       (array.get $Array
                                                  (local.get $procs)
                                                  (local.get $i))))
                            (then
                             (call $raise-argument-error:procedure-expected
                                   (array.get $Array
                                              (local.get $procs)
                                              (local.get $i)))
                             (unreachable)))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (if (i32.eq (local.get $n) (i32.const 1))
               (then (return (array.get $Array (local.get $procs) (i32.const 0)))))
           (if (i32.eqz (local.get $n))
               (then
                (local.set $free
                           (array.new_fixed $Free
                                            2
                                            (ref.cast (ref eq) (local.get $procs))
                                            (local.get $single?)))
                (return
                 (struct.new $Closure
                             (i32.const 0)
                             (global.get $symbol:compose)
                             (ref.i31 (i32.const -2))
                             (global.get $the-racket-realm)
                             (ref.func $invoke-composed-procedure)
                             (global.get $symbol:compose)
                             (ref.func $dummy-code)
                             (local.get $free)))))
           (local.set $p (ref.cast (ref $Procedure)
                                    (array.get $Array
                                               (local.get $procs)
                                               (i32.sub (local.get $n) (i32.const 1)))))
           (local.set $free
                      (array.new_fixed $Free
                                       2
                                       (ref.cast (ref eq) (local.get $procs))
                                       (local.get $single?)))
           (struct.new $Closure
                       (i32.const 0)
                       (global.get $symbol:compose)
                       (struct.get $Procedure $arity (local.get $p))
                       (global.get $the-racket-realm)
                       (ref.func $invoke-composed-procedure)
                       (global.get $symbol:compose)
                       (ref.func $dummy-code)
                       (local.get $free)))

     (func $compose (type $Prim>=0)
           (param $args (ref eq))
           (result      (ref eq))
           (call $make-composed-procedure (local.get $args) (global.get $false)))

     (func $compose1 (type $Prim>=0)
           (param $args (ref eq))
           (result      (ref eq))
           (call $make-composed-procedure (local.get $args) (global.get $true)))

     (func $procedure-extract-target (type $Prim1)
           (param $proc (ref eq)) ; procedure?
           (result      (ref eq))
           ;; Racket extracts a target procedure from a struct procedure
           ;; whose prop:procedure value names a field. WebRacket does
           ;; not yet expose that internal target, so ordinary procedures
           ;; conservatively return #f for now.
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (global.get $false))

     (func $procedure-reduce-arity (type $Prim24)
           (param $proc  (ref eq)) ; procedure?
           (param $arity (ref eq)) ; procedure-arity?
           (param $name  (ref eq)) ; (or/c symbol? #f), default #f
           (param $realm (ref eq)) ; symbol?, default 'racket
           (result (ref eq))

           (local $p          (ref $Procedure))
           (local $new-arity  (ref eq))
           (local $new-mask   i32)
           (local $old-mask   i32)
           (local $new-name   (ref eq))
           (local $new-realm  (ref eq))
           (local $free       (ref $Free))

           (local.set $new-arity (global.get $false))
           (local.set $new-name  (global.get $false))
           (local.set $new-realm (global.get $false))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))
           (local.set $new-arity (call $procedure-arity-value->field
                                       (global.get $symbol:procedure-reduce-arity)
                                       (local.get $arity)))
           (local.set $new-mask (call $procedure-arity-field->mask/i32 (local.get $new-arity)))
           (local.set $old-mask (call $procedure-arity-mask/checked/i32 (local.get $p)))
           (if (i32.ne (i32.and (local.get $new-mask)
                                (i32.xor (local.get $old-mask) (i32.const -1)))
                       (i32.const 0))
               (then
                (call $raise-argument-error1
                      (global.get $symbol:procedure-reduce-arity)
                      (global.get $string:procedure-arity?)
                      (local.get $arity))
                (unreachable)))

           (if (ref.eq (local.get $name) (global.get $missing))
               (then (local.set $name (global.get $false))))
           (if (ref.eq (local.get $name) (global.get $false))
               (then
                (local.set $new-name  (struct.get $Procedure $name (local.get $p)))
                (local.set $new-realm (struct.get $Procedure $realm (local.get $p))))
               (else
                (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
                    (then
                     (call $raise-argument-error1
                           (global.get $symbol:procedure-reduce-arity)
                           (global.get $string:symbol?)
                           (local.get $name))
                     (unreachable)))
                (local.set $new-name (local.get $name))
                (if (ref.eq (local.get $realm) (global.get $missing))
                    (then (local.set $new-realm (global.get $symbol:racket)))
                    (else
                     (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm)))
                         (then
                          (call $raise-argument-error1
                                (global.get $symbol:procedure-reduce-arity)
                                (global.get $string:symbol?)
                                (local.get $realm))
                          (unreachable)))
                     (local.set $new-realm (local.get $realm))))))

           ;; Keep the original procedure as payload. The reduced wrapper
           ;; checks its new arity, then forwards the original user args.
           (local.set $free (array.new_fixed $Free 1 (local.get $p)))
           (struct.new $Closure
                       (i32.const 0)
                       (local.get $new-name)
                       (local.get $new-arity)
                       (local.get $new-realm)
                       (ref.func $invoke-reduced-procedure)
                       (local.get $new-name)
                       (ref.func $dummy-code)
                       (local.get $free)))

     (func $procedure-reduce-arity-mask (type $Prim24)
           (param $proc  (ref eq)) ; procedure?
           (param $mask  (ref eq)) ; exact-integer?
           (param $name  (ref eq)) ; (or/c symbol? #f), default #f
           (param $realm (ref eq)) ; symbol?, default 'racket
           (result (ref eq))

           (local $p          (ref $Procedure))
           (local $new-arity  (ref eq))
           (local $new-mask   i32)
           (local $old-mask   i32)
           (local $new-name   (ref eq))
           (local $new-realm  (ref eq))
           (local $free       (ref $Free))

           (local.set $new-arity (global.get $false))
           (local.set $new-name  (global.get $false))
           (local.set $new-realm (global.get $false))
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))
           (local.set $new-arity
                      (call $procedure-arity-mask-value->field
                            (global.get $symbol:procedure-reduce-arity-mask)
                            (local.get $mask)))
           (local.set $new-mask (call $procedure-arity-field->mask/i32 (local.get $new-arity)))
           (local.set $old-mask (call $procedure-arity-mask/checked/i32 (local.get $p)))
           (if (i32.ne (i32.and (local.get $new-mask)
                                (i32.xor (local.get $old-mask) (i32.const -1)))
                       (i32.const 0))
               (then
                (call $raise-argument-error1
                      (global.get $symbol:procedure-reduce-arity-mask)
                      (global.get $string:exact-integer?)
                      (local.get $mask))
                (unreachable)))

           (if (ref.eq (local.get $name) (global.get $missing))
               (then (local.set $name (global.get $false))))
           (if (ref.eq (local.get $name) (global.get $false))
               (then
                (local.set $new-name  (struct.get $Procedure $name (local.get $p)))
                (local.set $new-realm (struct.get $Procedure $realm (local.get $p))))
               (else
                (if (i32.eqz (ref.test (ref $Symbol) (local.get $name)))
                    (then
                     (call $raise-argument-error1
                           (global.get $symbol:procedure-reduce-arity-mask)
                           (global.get $string:symbol?)
                           (local.get $name))
                     (unreachable)))
                (local.set $new-name (local.get $name))
                (if (ref.eq (local.get $realm) (global.get $missing))
                    (then (local.set $new-realm (global.get $symbol:racket)))
                    (else
                     (if (i32.eqz (ref.test (ref $Symbol) (local.get $realm)))
                         (then
                          (call $raise-argument-error1
                                (global.get $symbol:procedure-reduce-arity-mask)
                                (global.get $string:symbol?)
                                (local.get $realm))
                          (unreachable)))
                     (local.set $new-realm (local.get $realm))))))

           (local.set $free (array.new_fixed $Free 1 (local.get $p)))
           (struct.new $Closure
                       (i32.const 0)
                       (local.get $new-name)
                       (local.get $new-arity)
                       (local.get $new-realm)
                       (ref.func $invoke-reduced-procedure)
                       (local.get $new-name)
                       (ref.func $dummy-code)
                       (local.get $free)))

     (func $procedure-arity (type $Prim1)
           ; Wrapper: accepts any value, checks that it’s a procedure, then delegates
           ; to the checked version that expects (ref $Procedure).
           (param $proc (ref eq))
           (result      (ref eq))
          ;; 1. Check that $proc is a semantic procedure. Structs are
          ;; represented under $Procedure for fast application, but only
          ;; structs with prop:procedure are Racket procedures.
          (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
              (then (call $raise-argument-error:procedure-expected (local.get $proc))
                    (unreachable)))
           ;; 2. Delegate to the checked implementation
           (return_call $procedure-arity/checked
                        (ref.cast (ref $Procedure) (local.get $proc))))

     (func $procedure-arity/checked
           ; Produces normalized arity information: exact integers or arity-at-least structs.
           (param $p (ref $Procedure))
           (result (ref eq))

           (local $a         (ref eq))
           (local $arr       (ref $I32Array))
           (local $n         i32)
           (local $i         i32)
           (local $m         i32)
           (local $list      (ref eq))
           (local $fx        (ref i31))
           (local $elem      (ref eq))
           (local $arity-i32 i32)
           (local $value     i32)
           (local $delegate  (ref eq))

           ;; Initialize non-defaultable locals
           (local.set $elem (global.get $false))
           (local.set $delegate (global.get $false))

           ;; Applicable structs should reflect the arity of their
           ;; field-based prop:procedure delegate, not their wrapper
           ;; struct's internal zero-arity application shell.
           (if (ref.test (ref $Struct) (local.get $p))
               (then
                (local.set $delegate (call $struct-procedure-delegate
                                           (local.get $p)))
                (if (ref.test (ref $Procedure) (local.get $delegate))
                    (then (return_call $procedure-arity/checked
                                       (ref.cast (ref $Procedure)
                                                 (local.get $delegate)))))))

           ;; 1. Extract arity field (either a fixnum (ref i31) or an $I32Array of markers)
           (local.set $a (struct.get $Procedure $arity (local.get $p)))
           ;; 2. If it’s a single-arity fixnum, normalize negatives to arity-at-least
           (if (ref.test (ref i31) (local.get $a))
               (then (local.set $fx       (ref.cast (ref i31) (local.get $a)))
                     (local.set $arity-i32 (i32.shr_s (i31.get_s (local.get $fx)) (i32.const 1)))
                     (if (i32.ge_s (local.get $arity-i32) (i32.const 0))
                         (then (return (local.get $a)))
                         (else (local.set $value (i32.sub (i32.const -1) (local.get $arity-i32)))
                               (return (call $arity-at-least/make (local.get $value)))))))
           ;; 3. Otherwise, cast to $I32Array and build a list of ALL markers (incl. negatives)
           (local.set $arr (ref.cast (ref $I32Array) (local.get $a)))
           (local.set $n   (array.len (local.get $arr)))
           (local.set $list (global.get $null))
           ;;    Iterate right-to-left so that consing preserves original order
           (local.set $i (i32.sub (local.get $n) (i32.const 1)))
           (loop $rev
                 ;; 4. If done, return the accumulated list
                 (if (i32.lt_s (local.get $i) (i32.const 0))
                     (then (return (local.get $list))))
                 ;; 5. Read marker m at index i and normalize it
                 (local.set $m (array.get $I32Array (local.get $arr) (local.get $i)))
                 (if (i32.ge_s (local.get $m) (i32.const 0))
                     (then (local.set $elem (ref.i31 (i32.shl (local.get $m) (i32.const 1)))))
                     (else (local.set $value (i32.sub (i32.const -1) (local.get $m)))
                           (local.set $elem (call $arity-at-least/make (local.get $value)))))
                 (local.set $list (call $cons (local.get $elem) (local.get $list)))
                 ;; 6. Decrement i and continue
                 (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                 (br $rev))
           (unreachable))

     ;; procedure-result-arity : procedure? -> (or/c #f procedure-arity?)
     ;;   Return known result arity. WebRacket currently does not track
     ;;   result arity for closures, so report #f conservatively except
     ;;   for primitive procedures, which store explicit metadata.
     (func $procedure-result-arity (type $Prim1)
           (param $proc (ref eq)) ;; procedure?
           (result      (ref eq))

           (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
               (then (call $raise-argument-error:procedure-expected (local.get $proc))
                     (unreachable)))
           (if (ref.test (ref $PrimitiveProcedure) (local.get $proc))
               (then
                (return
                 (struct.get $PrimitiveProcedure $result-arity
                             (ref.cast (ref $PrimitiveProcedure)
                                       (local.get $proc))))))
           (global.get $false))

     (func $procedure-arity-mask (type $Prim1)
           ; TODO: Only tested with closures.
           ;       Also test with primitives and case-lambda
           (param $proc (ref eq))
           (result (ref eq))

           (local $p     (ref null $Procedure))
           (local $mask  i32)

          ;; Step 1: type check and cast. Use semantic procedure-ness so
          ;; plain structs do not expose their internal application fields.
          (if (ref.eq (call $procedure? (local.get $proc)) (global.get $false))
              (then (call $raise-argument-error:procedure-expected (local.get $proc))
                    (unreachable)))
          (local.set $p (ref.cast (ref $Procedure) (local.get $proc)))
           ;; Step 2: compute mask in checked helper
           (local.set $mask
                      (call $procedure-arity-mask/checked/i32
                            (ref.cast (ref $Procedure) (local.get $p))))
           ;; Step 4: return as fixnum
           (ref.i31 (i32.shl (local.get $mask) (i32.const 1))))

     (func $procedure-arity-mask/checked/i32
           ; TODO: Only tested with closures.
           ;       Also test with primitives and case-lambda
           (param $proc (ref $Procedure))
           (result      i32)

           (local $a     (ref eq))
           (local $arr   (ref $I32Array))
           (local $i     i32)
           (local $n     i32)
           (local $m     i32)
           (local $arity i32)
           (local $mask  i32)
           (local $start i32)
           (local $delegate (ref eq))

           (local.set $delegate (global.get $false))
           (if (ref.test (ref $Struct) (local.get $proc))
               (then
                (local.set $delegate (call $struct-procedure-delegate
                                           (local.get $proc)))
                (if (ref.test (ref $Procedure) (local.get $delegate))
                    (then (return_call $procedure-arity-mask/checked/i32
                                       (ref.cast (ref $Procedure)
                                                 (local.get $delegate)))))))

           ;; Step 1: inspect the procedure arity representation
           (local.set $a (struct.get $Procedure $arity (local.get $proc)))

           ;; Step 2: single arity marker stored as fixnum
           (if (ref.test (ref i31) (local.get $a))
               (then
                (local.set $arity (i32.shr_s
                                   (i31.get_s
                                    (ref.cast (ref i31) (local.get $a)))
                                   (i32.const 1)))
                (local.set $mask
                           (if (result i32)
                               (i32.ge_s (local.get $arity) (i32.const 0))
                               ;; If arity ≥ 0, mask = 1 << arity
                               (then (i32.shl (i32.const 1) (local.get $arity)))
                               ;; If arity < 0, mask = -1 << (-1 - arity)
                               (else (i32.shl (i32.const -1)
                                              (i32.sub (i32.const -1) (local.get $arity))))))
                (return (local.get $mask))))

           ;; Step 3: arity set stored as $I32Array of markers
           (local.set $arr (ref.cast (ref $I32Array) (local.get $a)))
           (local.set $n   (array.len (local.get $arr)))
           (local.set $i   (i32.const 0))
           (local.set $mask (i32.const 0))

           (block $done
                  (loop $loop
                        (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                        (local.set $m
                                   (array.get $I32Array (local.get $arr) (local.get $i)))
                        (if (i32.ge_s (local.get $m) (i32.const 0))
                            (then
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const 1) (local.get $m)))))
                            (else
                             (local.set $start
                                        (i32.sub (i32.const -1) (local.get $m)))
                             (local.set $mask
                                        (i32.or
                                         (local.get $mask)
                                         (i32.shl (i32.const -1) (local.get $start))))))
                        (local.set $i (i32.add (local.get $i) (i32.const 1)))
                        (br $loop)))
           (local.get $mask))

     (func $raise-argument-error:fixnum-expected (unreachable))

     (func $procedure-arity-includes?
           (param $proc    (ref eq))
           (param $k       (ref eq))    ;; fixnum
           (param $kws-ok? (ref eq))    ;; fixnum or #f
           (result         (ref eq))    ;; returns #true or #false

           (local $k-fx    (ref i31))
           (local $k-i32   i32)
           (local $mask-fx (ref i31))
           (local $mask    i32)

           ;; Step 1: type check and decode k
           (if (ref.test (ref i31) (local.get $k))
               (then
                (local.set $k-fx (ref.cast (ref i31) (local.get $k)))
                (local.set $k-i32 (i32.shr_u (i31.get_u (local.get $k-fx)) (i32.const 1))))
               (else
                (call $raise-argument-error:fixnum-expected)
                (unreachable)))
           ;; Step 2: call procedure-arity-mask
           (local.set $mask-fx (ref.cast (ref i31)
                                         (call $procedure-arity-mask (local.get $proc))))
           (local.set $mask    (i32.shr_u (i31.get_u (local.get $mask-fx)) (i32.const 1)))
           ;; Step 3: check if bit $k-i32 is set in $mask
           (if (i32.ne (i32.and (local.get $mask)
                                (i32.shl (i32.const 1) (local.get $k-i32)))
                       (i32.const 0))
               (then (return (global.get $true)))
               (else (return (global.get $false))))
           (unreachable))

     (func $procedure-arity-includes?/checked/i32
           (param $proc    (ref $Procedure))
           (param $k-i32   i32)
           ; (param $kws-ok? (ref eq))          ;; we don't use this yet
           (result         i32)

           (local $mask i32)

           ;; Step 1: get the arity mask
           (local.set $mask (call $procedure-arity-mask/checked/i32
                                  (local.get $proc)))
           ;; Step 2: check if bit $k-i32 is set in $mask
           (i32.ne (i32.and (local.get $mask)
                            (i32.shl (i32.const 1) (local.get $k-i32)))
                   (i32.const 0))))))
