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
