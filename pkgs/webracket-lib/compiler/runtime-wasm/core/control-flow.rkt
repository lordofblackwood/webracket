#lang racket

(provide control-flow-runtime-only-helpers)

(require "../core-helper.rkt")

;; control-flow-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate control-flow helpers used by the monolithic runtime.
(define control-flow-runtime-only-helpers
  (function-forms->runtime-helpers
   'control-flow-runtime-only-helpers
   '(
     (func $values (type $Prim>=0)
           (param $args (ref eq))
           (result      (ref eq))

           (local $use-args? i32)
           (local $as        (ref $Args))
           (local $arr       (ref $Array))
           (local $len       i32)
           (local $vals      (ref $Values))

           ;; Initialize non-defaultable locals.
           (local.set $as   (array.new $Args (global.get $null) (i32.const 0)))
           (local.set $arr  (call $make-array (i32.const 0) (global.get $null)))
           (local.set $vals (array.new $Values (global.get $null) (i32.const 0)))
           (local.set $len  (i32.const 0))

           ;; Determine whether the rest arguments are in an $Args array or a list.
           (local.set $use-args? (ref.test (ref $Args) (local.get $args)))
           (if (local.get $use-args?)
               ;; -- $Args case --
               (then
                (local.set $as  (ref.cast (ref $Args) (local.get $args)))
                (local.set $len (array.len (local.get $as)))
                ;; Single argument -> return it directly.
                (if (i32.eq (local.get $len) (i32.const 1))
                    (then (return (array.get $Args (local.get $as) (i32.const 0)))))
                ;; No arguments -> return an empty $Values array (zero values).
                (if (i32.eqz (local.get $len))
                    (then (return (local.get $vals))))
                ;; Multiple arguments -> pack them into a new $Values array.
                (local.set $vals (array.new $Values (global.get $null) (local.get $len)))
                (array.copy $Values $Args
                            (local.get $vals) (i32.const 0)
                            (local.get $as)  (i32.const 0)
                            (local.get $len)))
               ;; -- list case --
               (else
                (local.set $arr (call $list->array (local.get $args)))
                (local.set $len (array.len (local.get $arr)))
                ;; Single argument -> return it directly.
                (if (i32.eq (local.get $len) (i32.const 1))
                    (then (return (array.get $Array (local.get $arr) (i32.const 0)))))
                ;; No arguments -> return an empty $Values array (zero values).
                (if (i32.eqz (local.get $len))
                    (then (return (local.get $vals))))
                ;; Multiple arguments -> pack them into a new $Values array.
                (local.set $vals (array.new $Values (global.get $null) (local.get $len)))
                (array.copy $Values $Array
                            (local.get $vals) (i32.const 0)
                            (local.get $arr) (i32.const 0)
                            (local.get $len))))

           (local.get $vals))


     (func $call-with-values (type $Prim2)
           (param $gen (ref eq))
           (param $rec (ref eq))
           (result     (ref eq))

           (local $g     (ref $Procedure))
           (local $r     (ref $Procedure))
           (local $ginv  (ref $ProcedureInvoker))
           (local $rinv  (ref $ProcedureInvoker))
           (local $vals  (ref eq))
           (local $vals* (ref $Values))
           (local $args  (ref $Args))
           (local $n     i32)

           ;; initialize $args to satisfy the validator; overwritten later
           (local.set $args (array.new $Args (global.get $null) (i32.const 0)))

           ;; Step 1: type check generator
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $gen)))
               (then (call $raise-argument-error:procedure-expected (local.get $gen))
                     (unreachable)))
           (local.set $g    (ref.cast (ref $Procedure) (local.get $gen)))

           ;; Step 2: type check receiver
           (if (i32.eqz (ref.test (ref $Procedure) (local.get $rec)))
               (then (call $raise-argument-error:procedure-expected (local.get $rec))
                     (unreachable)))
           (local.set $r    (ref.cast (ref $Procedure) (local.get $rec)))

           ;; Step 3: call generator with zero arguments
           (local.set $ginv (struct.get $Procedure $invoke (local.get $g)))
           (local.set $vals
                      (call_ref $ProcedureInvoker
                                (local.get $g)
                                (array.new $Args (global.get $null) (i32.const 0))
                                (local.get $ginv)))

           ;; Step 4: unpack returned values into argument array
           (if (ref.test (ref $Values) (local.get $vals))
               (then (local.set $vals* (ref.cast (ref $Values) (local.get $vals)))
                     (local.set $n     (array.len (local.get $vals*)))
                     (local.set $args  (array.new $Args (global.get $null) (local.get $n)))
                     (array.copy $Args $Values
                                 (local.get $args) (i32.const 0)
                                 (local.get $vals*) (i32.const 0)
                                 (local.get $n)))
               (else (local.set $args (array.new_fixed $Args 1 (local.get $vals)))))

           ;; Step 5: call receiver in tail position
           (local.set $rinv (struct.get $Procedure $invoke (local.get $r)))
           (return_call_ref $ProcedureInvoker
                            (local.get $r)
                            (local.get $args)
                            (local.get $rinv))))))
