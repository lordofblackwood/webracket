#lang racket

(provide list-core-runtime-helpers)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; list-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate list helpers that can be emitted in core runtime.
(define list-core-runtime-helpers
  (list
   ;; pair? : (ref eq) -> (ref eq)
   ;;   Return #t if the value is a pair, #f otherwise.
   (core-runtime-helper
    '$pair?
    "$pair?"
    (lambda ()
      `(func $pair? (type $Prim1)
             (param $v (ref eq))
             (result (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Pair) (local.get $v))
                 (then ,(Imm #t))
                 (else ,(Imm #f))))))

   ;; cons? : (ref eq) -> (ref eq)
   ;;   Return #t if the value is a pair, #f otherwise.
   (core-runtime-helper
    '$cons?
    "$cons?"
    (lambda ()
      `(func $cons? (type $Prim1)
             (param $v (ref eq))
             (result (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Pair) (local.get $v))
                 (then ,(Imm #t))
                 (else ,(Imm #f))))))

   ;; null? : (ref eq) -> (ref eq)
   ;;   Return #t if the value is the empty list, #f otherwise.
   (core-runtime-helper
    '$null?
    "$null?"
    (lambda ()
      `(func $null? (type $Prim1)
             (param $v (ref eq))
             (result (ref eq))
             (if (result (ref eq))
                 (ref.eq (local.get $v) ,(Imm '()))
                 (then ,(Imm #t))
                 (else ,(Imm #f))))))

   ;; empty? : (ref eq) -> (ref eq)
   ;;   Return #t if the value is the empty list, #f otherwise.
   (core-runtime-helper
    '$empty?
    "$empty?"
    (lambda ()
      `(func $empty? (type $Prim1)
             (param $v (ref eq))
             (result (ref eq))
             (call $null? (local.get $v)))))

   ;; list? : (ref eq) -> (ref eq)
   ;;   Return #t if the value is a proper list, #f otherwise.
   (core-runtime-helper
    '$list?
    "$list?"
    (lambda ()
      `(func $list? (type $Prim1) (param $v (ref eq)) (result (ref eq))
             (block $exit (result (ref eq))
                    (loop $loop
                          (if (ref.eq (local.get $v) ,(Imm '()))
                              (then (return ,(Imm #t))))
                          (if (ref.test (ref $Pair) (local.get $v))
                              (then
                               (local.set $v
                                          (struct.get $Pair $d
                                                      (ref.cast (ref $Pair) (local.get $v))))
                               (br $loop))
                              (else (return ,(Imm #f)))))
                    ;; fallthrough: not a proper list
                    ,(Imm #f)))))

   ;; list : (ref eq) -> (ref eq)
   ;;   Return the already-built rest argument list.
   (core-runtime-helper
    '$list
    "$list"
    (lambda ()
      `(func $list (type $Prim>=0)
             (param $args (ref eq))
             (result      (ref eq))

             (local.get $args))))

   ;; list* : (ref eq) (ref eq) -> (ref eq)
   ;;   Build a list* value from the first argument and the rest argument list.
   (core-runtime-helper
    '$list*
    "$list*"
    (lambda ()
      `(func $list* (type $Prim>=1) (param $a (ref eq)) (param $tail (ref eq)) (result (ref eq))
             (local $head (ref $Pair))
             (local $prev (ref $Pair))
             (local $next (ref eq))
             (local $rest (ref eq))
             (local $node (ref $Pair))
             (local $newp (ref $Pair))
             ;; (list* x) => x
             (if (ref.eq (local.get $tail) ,(Imm '()))
                 (then (return (local.get $a))))
             ;; Build prefix pairs, and use the last argument as final tail.
             (local.set $head (struct.new $Pair (i32.const 0) (local.get $a) ,(Imm '())))
             (local.set $prev (local.get $head))
             (local.set $rest (local.get $tail))
             (block $done
                    (loop $loop
                          (local.set $node (ref.cast (ref $Pair) (local.get $rest)))
                          (local.set $next (struct.get $Pair $d (local.get $node)))
                          (if (ref.eq (local.get $next) ,(Imm '()))
                              (then
                               (struct.set $Pair $d (local.get $prev)
                                           (struct.get $Pair $a (local.get $node)))
                               (return (local.get $head))))
                          (local.set $newp
                                     (struct.new $Pair
                                                 (i32.const 0)
                                                 (struct.get $Pair $a (local.get $node))
                                                 ,(Imm '())))
                          (struct.set $Pair $d (local.get $prev) (local.get $newp))
                          (local.set $prev (local.get $newp))
                          (local.set $rest (local.get $next))
                          (br $loop)))
             (local.get $head))))

   ;; last-pair/checked : (ref $Pair) -> (ref $Pair)
   ;;   Return the final pair in a known pair chain.
   (core-runtime-helper
    '$last-pair/checked
    "$last-pair/checked"
    (lambda ()
      `(func $last-pair/checked
             (param $p (ref $Pair))
             (result   (ref $Pair))

             (local $node (ref $Pair))
             (local $next (ref eq))

             (local.set $node (local.get $p))
             (loop $loop
                   (local.set $next (struct.get $Pair $d (local.get $node)))
                   (if (ref.test (ref $Pair) (local.get $next))
                       (then (local.set $node (ref.cast (ref $Pair) (local.get $next)))
                             (br $loop))
                       (else (return (local.get $node)))))
             (unreachable))))

   ;; make-list/checked : i32 (ref eq) -> (ref eq)
   ;;   Build a proper list after the caller has validated the element count.
   (core-runtime-helper
    '$make-list/checked
    "$make-list/checked"
    (lambda ()
      `(func $make-list/checked
             (param $n i32)             ;; number of elements
             (param $v (ref eq))        ;; value to repeat
             (result (ref eq))          ;; proper list

             (local $i i32)
             (local $acc (ref eq))

             (local.set $i   (i32.const 0))
             (local.set $acc ,(Imm '()))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $n)))
                          (local.set $acc
                                     (struct.new $Pair
                                                 (i32.const 0)
                                                 (local.get $v)
                                                 (local.get $acc)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))
             (local.get $acc))))))
