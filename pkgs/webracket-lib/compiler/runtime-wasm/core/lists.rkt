#lang racket

(provide list-core-runtime-helpers
         list-runtime-only-helpers)

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

   ;; cons : (ref eq) (ref eq) -> (ref eq)
   ;;   Allocate a pair from the given car and cdr values.
   (core-runtime-helper
    '$cons
    "$cons"
    (lambda ()
      `(func $cons (type $Prim2)
             (param $a (ref eq))
             (param $d (ref eq))
             (result (ref eq))

             (struct.new $Pair
                         (i32.const 0)
                         (local.get $a)
                         (local.get $d)))))

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

;; pair-accessor-names : (listof symbol?)
;;   Names for generated composed car/cdr accessors.
(define pair-accessor-names
  '($caar $cadr $cdar $cddr
    $caaar $caadr $cadar $caddr
    $cdaar $cdadr $cddar $cdddr
    $caaaar $caaadr $caadar $caaddr
    $cadaar $cadadr $caddar $cadddr
    $cdaaar $cdaadr $cdadar $cdaddr
    $cddaar $cddadr $cdddar $cddddr))

;; pair-accessor-helper : symbol? -> core-runtime-helper?
;;   Build a helper for a generated composed car/cdr accessor.
(define (pair-accessor-helper name)
  (define str (substring (symbol->string name) 1))
  (define letters (substring str 1 (sub1 (string-length str))))
  (define ops
    (for/list ([ch (in-list (reverse (string->list letters)))])
      (case ch
        [(#\a) 'car]
        [(#\d) 'cdr]
        [else (error 'pair-accessor-helper
                     "invalid pair accessor name: ~a" name)])))
  (define body
    (for/fold ([expr '(local.get $v)]) ([op (in-list ops)])
      (case op
        [(car) `(call $car ,expr)]
        [(cdr) `(call $cdr ,expr)])))
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type $Prim1)
            (param $v (ref eq))
            (result (ref eq))
            ,body))))

;; list-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate list helpers that are sourced from this file but still depend on
;;   monolithic runtime error services or globals.
(define list-runtime-only-helpers
  (append
   (list
    ;; car : (ref eq) -> (ref eq)
    ;;   Return the car of a pair or raise a pair contract error.
    (core-runtime-helper
     '$car
     "$car"
     (lambda ()
       `(func $car (type $Prim1) (param $v (ref eq)) (result (ref eq))
              (if (result (ref eq)) (ref.test (ref $Pair) (local.get $v))
                  (then (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $v))))
                  (else (call $raise-pair-expected/who
                              (global.get $symbol:car)
                              (local.get $v))
                        (unreachable))))))

    ;; cdr : (ref eq) -> (ref eq)
    ;;   Return the cdr of a pair or raise a pair contract error.
    (core-runtime-helper
     '$cdr
     "$cdr"
     (lambda ()
       `(func $cdr (type $Prim1) (param $v (ref eq)) (result (ref eq))
              (if (result (ref eq)) (ref.test (ref $Pair) (local.get $v))
                  (then (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $v))))
                  (else (call $raise-pair-expected/who
                              (global.get $symbol:cdr)
                              (local.get $v))
                        (unreachable))))))

    ;; length/i32 : (ref eq) -> i32
    ;;   Count a proper list and return an unboxed length.
    (core-runtime-helper
     '$length/i32
     "$length/i32"
     (lambda ()
       `(func $length/i32 (param $xs (ref eq)) (result i32)
              (local $i i32)
              (local.set $i (i32.const 0))
              (block $done
                     (loop $count
                           ;; if we've reached null, return the count so far
                           (if (ref.eq (local.get $xs) (global.get $null))
                               (then (return (local.get $i))))
                           ;; else, must be a pair: follow its cdr
                           (if (ref.test (ref $Pair) (local.get $xs))
                               (then (local.set $xs
                                                (struct.get $Pair $d
                                                            (ref.cast (ref $Pair) (local.get $xs)))))
                               ;; neither null nor pair: error
                               (else (call $raise-pair-expected (local.get $xs))))
                           ;; increment and repeat
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $count)))
              ;; fall-through just returns the current count
              (local.get $i))))

    ;; length : (ref eq) -> (ref eq)
    ;;   Count a proper list and return a fixnum length.
    (core-runtime-helper
     '$length
     "$length"
     (lambda ()
       `(func $length (type $Prim1) (param $xs (ref eq)) (result (ref eq))
              (local $i i32)
              (local.set $i (i32.const 0))
              (block $done
                     (loop $count
                           (if (ref.eq (local.get $xs) (global.get $null))
                               (then (br $done)))
                           (if (ref.test (ref $Pair) (local.get $xs))
                               (then (local.set $xs
                                                (struct.get $Pair $d
                                                            (ref.cast (ref $Pair) (local.get $xs)))))
                               (else (call $raise-list-expected/who
                                           (global.get $symbol:length)
                                           (local.get $xs))))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $count)))
              (ref.i31 (i32.shl (local.get $i) (i32.const 1))))))

    ;; list-ref/checked : (ref $Pair) i32 -> (ref eq)
    ;;   Return the indexed element after the caller has checked the arguments.
    (core-runtime-helper
     '$list-ref/checked
     "$list-ref/checked"
     (lambda ()
       `(func $list-ref/checked (param $xs (ref $Pair)) (param $i i32) (result (ref eq))
              (local $v    (ref $Pair))
              (local $k    i32)
              (local $next (ref eq))
              (local $len  i32)

              (local.set $v (local.get $xs))
              (local.set $k (local.get $i))

              (loop $loop
                    ;; If we've reached the desired pair, return its car.
                    (if (i32.eqz (local.get $k))
                        (then (return (struct.get $Pair $a (local.get $v)))))
                    ;; Otherwise, try to step to the next pair.
                    (local.set $next (struct.get $Pair $d (local.get $v)))
                    (if (ref.test (ref $Pair) (local.get $next))
                        (then
                         (local.set $v (ref.cast (ref $Pair) (local.get $next)))
                         (local.set $k (i32.sub (local.get $k) (i32.const 1)))
                         (br $loop))
                        (else
                         ;; Ran out of pairs before reaching index: compute length of the
                         ;; pair-chain we've actually got and raise.
                         ;; len = steps_so_far + 1 = i - k + 1
                         (local.set $len
                                    (i32.add (i32.sub (local.get $i) (local.get $k)) (i32.const 1)))
                         (call $raise-bad-list-ref-index (local.get $xs) (local.get $i) (local.get $len))
                         (unreachable))))
              ;; Should not fall through.
              (unreachable))))

    ;; list-ref : (ref eq) (ref eq) -> (ref eq)
    ;;   Return the indexed list element after validating the list and index.
    (core-runtime-helper
     '$list-ref
     "$list-ref"
     (lambda ()
       `(func $list-ref (type $Prim2) (param $xs (ref eq)) (param $i (ref eq)) (result (ref eq))
              (local $idx i32)
              ;; Decode & check exact-nonnegative-integer index
              (if (ref.test (ref i31) (local.get $i))
                  (then (local.set $idx
                                   (i31.get_s (ref.cast (ref i31) (local.get $i))))
                        (if (i32.ne (i32.and (local.get $idx) (i32.const 1)) (i32.const 0))
                            (then (call $raise-exact-nonnegative-integer-expected/who
                                        (global.get $symbol:list-ref)
                                        (local.get $i))
                                  (unreachable)))
                        (local.set $idx (i32.shr_s (local.get $idx) (i32.const 1))))
                  (else (call $raise-exact-nonnegative-integer-expected/who
                              (global.get $symbol:list-ref)
                              (local.get $i))
                        (unreachable)))
              (if (i32.lt_s (local.get $idx) (i32.const 0))
                  (then (call $raise-exact-nonnegative-integer-expected/who
                              (global.get $symbol:list-ref)
                              (local.get $i))
                        (unreachable)))
              ;; Check & dispatch on Pair
              (if (result (ref eq))
                  (ref.test (ref $Pair) (local.get $xs))
                  (then (call $list-ref/checked
                              (ref.cast (ref $Pair) (local.get $xs))
                              (local.get $idx)))
                  (else (call $raise-pair-expected/who
                              (global.get $symbol:list-ref)
                              (local.get $xs))
                        (unreachable)))))))
   (map pair-accessor-helper pair-accessor-names)
   (list
    ;; rest : (ref eq) -> (ref eq)
    ;;   Return the rest of a non-empty proper list.
    (core-runtime-helper
     '$rest
     "$rest"
     (lambda ()
       `(func $rest (type $Prim1) (param $xs (ref eq)) (result (ref eq))
              ;; Type check: non-empty proper list
              (if (ref.eq (local.get $xs) (global.get $null))
                  (then (call $raise-pair-expected/who
                              (global.get $symbol:rest)
                              (local.get $xs))
                        (unreachable)))
              (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                  (then (call $raise-list-expected/who
                              (global.get $symbol:rest)
                              (local.get $xs))
                        (unreachable)))
              ;; Return tail
              (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $xs))))))

    ;; last : (ref eq) -> (ref eq)
    ;;   Return the final element of a non-empty proper list.
    (core-runtime-helper
     '$last
     "$last"
     (lambda ()
       `(func $last (type $Prim1) (param $xs (ref eq)) (result (ref eq))
              (local $p (ref $Pair))
              ;; Type check: non-empty proper list
              (if (ref.eq (local.get $xs) (global.get $null))
                  (then (call $raise-argument-error/internal (local.get $xs)) (unreachable)))
              (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                  (then (call $raise-argument-error/internal (local.get $xs)) (unreachable)))
              ;; Retrieve last element
              (local.set $p (call $last-pair/checked (ref.cast (ref $Pair) (local.get $xs))))
              (struct.get $Pair $a (local.get $p)))))

    ;; last-pair : (ref eq) -> (ref eq)
    ;;   Return the final pair in a pair chain.
    (core-runtime-helper
     '$last-pair
     "$last-pair"
     (lambda ()
       `(func $last-pair (type $Prim1) (param $xs (ref eq)) (result (ref eq))
              ;; Type check: pair?
              (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                  (then (call $raise-pair-expected (local.get $xs)) (unreachable)))
              (call $last-pair/checked (ref.cast (ref $Pair) (local.get $xs))))))

    ;; list-tail/checked/who : (ref eq) (ref $Pair) i32 -> (ref eq)
    ;;   Return cdr^i of xs after the caller has validated the pair start.
    (core-runtime-helper
     '$list-tail/checked/who
     "$list-tail/checked/who"
     (lambda ()
       `(func $list-tail/checked/who
              (param $who (ref eq))
              (param $xs  (ref $Pair))
              (param $i   i32)
              (result (ref eq))
              (local $v    (ref $Pair))
              (local $k    i32)
              (local $next (ref eq))

              (local.set $v (local.get $xs))
              (local.set $k (local.get $i))

              (loop $loop
                    ;; If no steps remain, return current tail (a Pair value is fine as (ref eq)).
                    (if (i32.eqz (local.get $k))
                        (then (return (local.get $v))))
                    ;; Step once.
                    (local.set $next (struct.get $Pair $d (local.get $v)))
                    (local.set $k (i32.sub (local.get $k) (i32.const 1)))
                    ;; If that single step completed all steps, return whatever we landed on
                    ;; (pair or not).
                    (if (i32.eqz (local.get $k))
                        (then (return (local.get $next))))
                    ;; Otherwise, we must continue stepping. Ensure next is a Pair.
                    (if (ref.test (ref $Pair) (local.get $next))
                        (then
                        (local.set $v (ref.cast (ref $Pair) (local.get $next)))
                         (br $loop))
                        (else
                         (call $raise-pair-expected/who
                               (local.get $who)
                               (local.get $next)))))
              (unreachable))))

    ;; list-tail/checked : (ref $Pair) i32 -> (ref eq)
    ;;   Return cdr^i of xs with list-tail as the error name.
    (core-runtime-helper
     '$list-tail/checked
     "$list-tail/checked"
     (lambda ()
       `(func $list-tail/checked
              (param $xs (ref $Pair))
              (param $i  i32)
              (result (ref eq))
              (call $list-tail/checked/who
                    (global.get $symbol:list-tail)
                    (local.get $xs)
                    (local.get $i)))))

    ;; list-tail : (ref eq) (ref eq) -> (ref eq)
    ;;   Return cdr^i of a list after validating the index.
    (core-runtime-helper
     '$list-tail
     "$list-tail"
     (lambda ()
       `(func $list-tail (type $Prim2) (param $xs (ref eq)) (param $i (ref eq)) (result (ref eq))
              (local $pair (ref $Pair))
              (local $idx  i32)
              ;; Initialize non-defaultable local to a safe value.
              (local.set $pair (global.get $dummy-pair))
              ;; Decode and check exact-nonnegative-integer index.
              (if (ref.test (ref i31) (local.get $i))
                  (then
                   (local.set $idx (i31.get_s (ref.cast (ref i31) (local.get $i))))
                   (if (i32.ne (i32.and (local.get $idx) (i32.const 1)) (i32.const 0))
                       (then (call $raise-exact-nonnegative-integer-expected/who
                                   (global.get $symbol:list-tail)
                                   (local.get $i))
                             (unreachable)))
                   (local.set $idx (i32.shr_s (local.get $idx) (i32.const 1))))
                  (else (call $raise-exact-nonnegative-integer-expected/who
                              (global.get $symbol:list-tail)
                              (local.get $i))
                        (unreachable)))
              (if (i32.lt_s (local.get $idx) (i32.const 0))
                  (then (call $raise-exact-nonnegative-integer-expected/who
                              (global.get $symbol:list-tail)
                              (local.get $i))
                        (unreachable)))
              ;; (list-tail xs 0) => xs
              (if (i32.eqz (local.get $idx))
                  (then (return (local.get $xs))))
              ;; For idx > 0, xs must be a Pair. Make dominance explicit with `unreachable`.
              (if (ref.test (ref $Pair) (local.get $xs))
                  (then (local.set $pair (ref.cast (ref $Pair) (local.get $xs))))
                  (else
                   (call $raise-pair-expected/who
                         (global.get $symbol:list-tail)
                         (local.get $xs))
                   (unreachable)))

              (call $list-tail/checked/who
                    (global.get $symbol:list-tail)
                    (local.get $pair)
                    (local.get $idx)))))

    ;; list-set/checked : (ref $Pair) i32 (ref eq) -> (ref eq)
    ;;   Return a new list with the indexed element replaced by v.
    (core-runtime-helper
     '$list-set/checked
     "$list-set/checked"
     (lambda ()
       `(func $list-set/checked
              (param $xs (ref $Pair))
              (param $i  i32)
              (param $v  (ref eq))
              (result    (ref eq))

              (local $p      (ref $Pair))
              (local $k      i32)
              (local $next   (ref eq))
              (local $rev    (ref eq))
              (local $len    i32)
              (local $tail   (ref eq))
              (local $res    (ref eq))
              (local $prefix (ref eq))

              (local.set $p   (local.get $xs))
              (local.set $k   (local.get $i))
              (local.set $rev (global.get $null))

              (loop $loop
                    (if (i32.eqz (local.get $k))
                        (then
                         (local.set $tail (struct.get $Pair $d (local.get $p)))
                         (local.set $res
                                    (struct.new $Pair (i32.const 0)
                                                (local.get $v) (local.get $tail)))
                         (local.set $prefix (local.get $rev))
                         (loop $rebuild
                               (if (ref.eq (local.get $prefix) (global.get $null))
                                   (then (return (local.get $res))))
                               (local.set $res
                                          (struct.new $Pair (i32.const 0)
                                                      (struct.get $Pair $a
                                                                  (ref.cast (ref $Pair)
                                                                            (local.get $prefix)))
                                                      (local.get $res)))
                               (local.set $prefix
                                          (struct.get $Pair $d
                                                      (ref.cast (ref $Pair)
                                                                (local.get $prefix))))
                               (br $rebuild))))
                    (local.set $rev
                               (struct.new $Pair (i32.const 0)
                                           (struct.get $Pair $a (local.get $p))
                                           (local.get $rev)))
                    (local.set $next (struct.get $Pair $d (local.get $p)))
                    (if (ref.test (ref $Pair) (local.get $next))
                        (then
                         (local.set $p (ref.cast (ref $Pair) (local.get $next)))
                         (local.set $k (i32.sub (local.get $k) (i32.const 1)))
                         (br $loop))
                        (else
                         (local.set $len
                                    (i32.add (i32.sub (local.get $i) (local.get $k))
                                             (i32.const 1)))
                         (call $raise-bad-list-set-index
                               (local.get $xs) (local.get $i) (local.get $len))
                         (unreachable))))

              (unreachable))))

    ;; list-set : (ref eq) (ref eq) (ref eq) -> (ref eq)
    ;;   Return a new list with the indexed element replaced after validation.
    (core-runtime-helper
     '$list-set
     "$list-set"
     (lambda ()
       `(func $list-set (type $Prim3)
              (param $xs (ref eq))
              (param $i  (ref eq))
              (param $v  (ref eq))
              (result    (ref eq))

              (local $idx  i32)
              (local $pair (ref $Pair))

              ;; Decode & check exact-nonnegative-integer index
              (if (ref.test (ref i31) (local.get $i))
                  (then (local.set $idx (i31.get_s (ref.cast (ref i31) (local.get $i))))
                        (if (i32.ne (i32.and (local.get $idx) (i32.const 1)) (i32.const 0))
                            (then (call $raise-argument-error1
                                        (global.get $symbol:list-set)
                                        (global.get $string:exact-nonnegative-integer?)
                                        (local.get $i))
                                  (unreachable)))
                        (local.set $idx (i32.shr_s (local.get $idx) (i32.const 1))))
                  (else (call $raise-argument-error1
                              (global.get $symbol:list-set)
                              (global.get $string:exact-nonnegative-integer?)
                              (local.get $i))
                        (unreachable)))
              (if (i32.lt_s (local.get $idx) (i32.const 0))
                  (then (call $raise-argument-error1
                              (global.get $symbol:list-set)
                              (global.get $string:exact-nonnegative-integer?)
                              (local.get $i))
                        (unreachable)))

              ;; Ensure non-empty proper list
              (if (ref.eq (local.get $xs) (global.get $null))
                  (then (call $raise-bad-list-set-index
                              (local.get $xs) (local.get $idx) (i32.const 0))
                        (unreachable)))
              (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                  (then (call $raise-list-expected/who
                              (global.get $symbol:list-set)
                              (local.get $xs))
                        (unreachable)))

              (local.set $pair (ref.cast (ref $Pair) (local.get $xs)))
              (call $list-set/checked (local.get $pair) (local.get $idx) (local.get $v))))))))
