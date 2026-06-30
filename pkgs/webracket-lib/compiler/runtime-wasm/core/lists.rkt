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

;; member-runtime-helper : symbol? symbol? boolean? any/c -> core-runtime-helper?
;;   Build a member-family helper with an optional comparator procedure.
(define (member-runtime-helper name type needs-proc? cmp)
  (define who (string->symbol
               (format "$symbol:~a" (substring (symbol->string name) 1))))
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type ,type)
            (param $needle (ref eq))          ;; value to find
            (param $xs     (ref eq))          ;; list to search
            ,@(if needs-proc?
                  '((param $same? (ref eq))) ;; optional comparator, defaults to equal?
                  '())
            (result (ref eq))

            (local $pair (ref $Pair))
            (local $elem (ref eq))
            ,@(if needs-proc? '((local $args     (ref $Args))
                                (local $res      (ref eq))
                                (local $use-proc i32))
                  '())
            ,@(if needs-proc?
                  `((if (ref.eq (local.get $same?) (global.get $missing))
                        (then (local.set $use-proc (i32.const 0)))
                        (else
                         (if (i32.eqz (ref.test (ref $Procedure) (local.get $same?)))
                             (then (call $raise-argument-error:procedure-expected/who
                                         (global.get ,who)
                                         (local.get $same?))
                                   (unreachable)))
                         (local.set $use-proc (i32.const 1))))
                    (local.set $args (array.new $Args (global.get $null) (i32.const 2))))
                  '())
            (loop $search
                  ;; 1) end-of-list? => not found
                  (if (ref.eq (local.get $xs) (global.get $null))
                      (then (return (global.get $false))))
                  ;; 2) must be a Pair
                  (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                      (then (call $raise-pair-expected/who
                                  (global.get ,who)
                                  (local.get $xs))
                            (unreachable)))
                  (local.set $pair (ref.cast (ref $Pair) (local.get $xs)))
                  (local.set $elem (struct.get $Pair $a (local.get $pair)))
                  ,(if needs-proc?
                       `(if (i32.eqz (local.get $use-proc))
                            (then
                             (if (ref.eq (call $equal? (local.get $needle) (local.get $elem))
                                         (global.get $true))
                                 (then (return (local.get $xs)))))
                            (else
                             (array.set $Args (local.get $args) (i32.const 0) (local.get $needle))
                             (array.set $Args (local.get $args) (i32.const 1) (local.get $elem))
                             (local.set $res
                                        (call_ref $ProcedureInvoker
                                                  (ref.cast (ref $Procedure) (local.get $same?))
                                                  (local.get $args)
                                                  (struct.get $Procedure $invoke
                                                              (ref.cast (ref $Procedure) (local.get $same?)))))
                             (if (ref.eq (local.get $res) (global.get $true))
                                 (then (return (local.get $xs))))))
                       `(if ,cmp (then (return (local.get $xs)))))
                  ;; 3) advance to cdr
                  (local.set $xs (struct.get $Pair $d (local.get $pair)))
                  (br $search))
            (unreachable)))))

;; assoc-runtime-helper : symbol? symbol? boolean? any/c -> core-runtime-helper?
;;   Build an association-list search helper with an optional comparator procedure.
(define (assoc-runtime-helper name type needs-proc? cmp)
  (define who (string->symbol
               (format "$symbol:~a" (substring (symbol->string name) 1))))
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type ,type)
            (param $needle (ref eq))  ;; key to locate
            (param $alist  (ref eq))  ;; association list
            ,@(if needs-proc?
                  '((param $same? (ref eq))) ;; optional comparator for assoc
                  '())
            (result (ref eq))

            (local $list-pair  (ref $Pair))
            (local $entry      (ref eq))
            (local $entry-pair (ref $Pair))
            (local $key        (ref eq))
            ,@(if needs-proc? '((local $args     (ref $Args))
                                (local $res      (ref eq))
                                (local $use-proc i32))
                  '())
            ,@(if needs-proc?
                  `((if (ref.eq (local.get $same?) (global.get $missing))
                        (then (local.set $use-proc (i32.const 0)))
                        (else
                         (if (i32.eqz (ref.test (ref $Procedure) (local.get $same?)))
                             (then (call $raise-argument-error:procedure-expected/who
                                         (global.get ,who)
                                         (local.get $same?))
                                   (unreachable)))
                         (local.set $use-proc (i32.const 1))))
                    (local.set $args (array.new $Args (global.get $null) (i32.const 2))))
                  '())
            (loop $search
                  (if (ref.eq (local.get $alist) (global.get $null))
                      (then (return (global.get $false))))
                  (if (i32.eqz (ref.test (ref $Pair) (local.get $alist)))
                      (then (call $raise-pair-expected/who
                                  (global.get ,who)
                                  (local.get $alist))
                            (unreachable)))
                  (local.set $list-pair (ref.cast (ref $Pair) (local.get $alist)))
                  (local.set $entry (struct.get $Pair $a (local.get $list-pair)))
                  (if (i32.eqz (ref.test (ref $Pair) (local.get $entry)))
                      (then (call $raise-pair-expected/who
                                  (global.get ,who)
                                  (local.get $entry))
                            (unreachable)))
                  (local.set $entry-pair (ref.cast (ref $Pair) (local.get $entry)))
                  (local.set $key (struct.get $Pair $a (local.get $entry-pair)))
                  ,(if needs-proc?
                       `(if (i32.eqz (local.get $use-proc))
                            (then
                             (if (ref.eq (call $equal? (local.get $needle) (local.get $key))
                                         (global.get $true))
                                 (then (return (local.get $entry)))))
                            (else
                             (array.set $Args (local.get $args) (i32.const 0) (local.get $needle))
                             (array.set $Args (local.get $args) (i32.const 1) (local.get $key))
                             (local.set $res
                                        (call_ref $ProcedureInvoker
                                                  (ref.cast (ref $Procedure) (local.get $same?))
                                                  (local.get $args)
                                                  (struct.get $Procedure $invoke
                                                              (ref.cast (ref $Procedure) (local.get $same?)))))
                             (if (ref.eq (local.get $res) (global.get $true))
                                 (then (return (local.get $entry))))))
                       `(if ,cmp (then (return (local.get $entry)))))
                  (local.set $alist (struct.get $Pair $d (local.get $list-pair)))
                  (br $search))
            (unreachable)))))

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
              (call $list-set/checked (local.get $pair) (local.get $idx) (local.get $v)))))

    ;; append : list? ... any/c -> any/c
    ;;   Append all argument lists, using the final argument directly as the tail.
    (core-runtime-helper
     '$append
     "$append"
     (lambda ()
       `(func $append (type $Prim>=0)
              (param $xs (ref eq))        ;; list of arguments
              (result    (ref eq))

              (local $rev (ref eq))
              (local $node (ref $Pair))
              (local $arg (ref eq))
              (local $acc (ref eq))

              ;; Zero arguments -> null
              (if (ref.eq (local.get $xs) (global.get $null))
                  (then (return (global.get $null))))

              ;; Reverse argument list to process from last to first
              (local.set $rev (call $reverse (local.get $xs)))

              ;; Initialize accumulator with last argument
              (local.set $node (ref.cast (ref $Pair) (local.get $rev)))
              (local.set $acc  (struct.get $Pair $a (local.get $node)))
              (local.set $rev  (struct.get $Pair $d (local.get $node)))

              ;; Fold over remaining arguments with $append/2
              (block $done
                     (loop $loop
                           (br_if $done (ref.eq (local.get $rev) (global.get $null)))
                           (local.set $node (ref.cast (ref $Pair) (local.get $rev)))
                           (local.set $arg  (struct.get $Pair $a (local.get $node)))
                           (local.set $acc  (call $append/2 (local.get $arg) (local.get $acc)))
                           (local.set $rev  (struct.get $Pair $d (local.get $node)))
                           (br $loop)))

              (local.get $acc))))

    ;; append/2 : (ref eq) (ref eq) -> (ref eq)
    ;;   Append one list to a tail value.
    (core-runtime-helper
     '$append/2
     "$append/2"
     (lambda ()
       `(func $append/2
              (param $xs (ref eq))
              (param $ys (ref eq))
              (result    (ref eq))

              (if (result (ref eq))
                  (ref.eq (local.get $xs) (global.get $null))
                  (then (local.get $ys))  ; "the last list is used directly in the output"
                  (else (if (result (ref eq))
                            (ref.test (ref $Pair) (local.get $xs))
                            (then
                             (struct.new $Pair (i32.const 0)
                                         (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $xs)))
                                         (call $append/2
                                               (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $xs)))
                                               (local.get $ys))))
                            (else (call $raise-pair-expected (local.get $xs))
                                  (unreachable))))))))

    ;; qq-append : any/c any/c -> any/c
    ;;   Helper generated by Racket's quasiquote expansion for splices.
    (core-runtime-helper
     '$qq-append
     "$qq-append"
     (lambda ()
       `(func $qq-append (type $Prim2)
              (param $xs (ref eq)) ;; candidate splice list
              (param $ys (ref eq)) ;; tail
              (result (ref eq))

              (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:qq-append)
                              (global.get $string:list?)
                              (local.get $xs))
                        (unreachable)))
              (call $append/2 (local.get $xs) (local.get $ys)))))

    ;; append* : list? any/c ... -> any/c
    ;;   Append a list of lists, optionally with preceding list arguments.
    (core-runtime-helper
     '$append*
     "$append*"
     (lambda ()
       `(func $append* (type $Prim>=1)
              (param $lst  (ref eq))  ;; preceding list argument
              (param $rest (ref eq))  ;; list of remaining arguments; last supplies more append args
              (result      (ref eq))

              (local $xs   (ref eq))
              (local $node (ref $Pair))
              (local $acc  (ref eq))
              (local $last (ref eq))
              (local $args (ref eq))

              ;; initialize locals with no defaults
              (local.set $last (global.get $false))

              ;; no extra args: first argument already provides list of append arguments
              (if (ref.eq (local.get $rest) (global.get $null))
                  (then (return (call $append (local.get $lst)))))

              ;; separate final list argument from preceding list values
              (local.set $xs  (local.get $rest))
              (local.set $acc (global.get $null))
              (block $done
                     (loop $loop
                           (local.set $node (ref.cast (ref $Pair) (local.get $xs)))
                           (local.set $xs   (struct.get $Pair $d (local.get $node)))
                           (if (ref.eq (local.get $xs) (global.get $null))
                               (then (local.set $last (struct.get $Pair $a (local.get $node)))
                                     (br $done))
                               (else (local.set $acc
                                                (struct.new $Pair
                                                            (i32.const 0)
                                                            (struct.get $Pair $a (local.get $node))
                                                            (local.get $acc)))
                                     (br $loop)))))

              ;; rebuild argument list so that last argument's list is appended at the end
              (local.set $args (local.get $last))
              (block $done2
                     (loop $loop2
                           (br_if $done2 (ref.eq (local.get $acc) (global.get $null)))
                           (local.set $node (ref.cast (ref $Pair) (local.get $acc)))
                           (local.set $args (struct.new $Pair
                                                        (i32.const 0)
                                                        (struct.get $Pair $a (local.get $node))
                                                        (local.get $args)))
                           (local.set $acc (struct.get $Pair $d (local.get $node)))
                           (br $loop2)))

              (local.set $args (struct.new $Pair (i32.const 0)
                                           (local.get $lst)
                                           (local.get $args)))
              (call $append (local.get $args)))))

    ;; flatten : any/c -> list?
    ;;   Flatten pairs in a tree-like value into a proper list.
    (core-runtime-helper
     '$flatten
     "$flatten"
     (lambda ()
       `(func $flatten (type $Prim1) (param $v (ref eq)) (result (ref eq))
              (local $stack (ref eq))
              (local $node  (ref $Pair))
              (local $cur   (ref eq))
              (local $p     (ref $Pair))
              (local $acc   (ref eq))

              ;; Initialize stack with initial value and empty accumulator
              (local.set $stack (call $cons (local.get $v) (global.get $null)))
              (local.set $acc   (global.get $null))

              (block $done
                     (loop $loop
                           (br_if $done (ref.eq (local.get $stack) (global.get $null)))
                           (local.set $node  (ref.cast (ref $Pair) (local.get $stack)))
                           (local.set $cur   (struct.get $Pair $a  (local.get $node)))
                           (local.set $stack (struct.get $Pair $d  (local.get $node)))
                           (if (ref.eq (local.get $cur) (global.get $null))
                               (then (nop))
                               (else
                                (if (ref.test (ref $Pair) (local.get $cur))
                                    (then (local.set $p     (ref.cast (ref $Pair) (local.get $cur)))
                                          ;; Push cdr then car to visit car first
                                          (local.set $stack (call $cons (struct.get $Pair $d (local.get $p)) (local.get $stack)))
                                          (local.set $stack (call $cons (struct.get $Pair $a (local.get $p)) (local.get $stack))))
                                    (else
                                     (local.set $acc (call $cons (local.get $cur) (local.get $acc)))))))
                           (br $loop)))
              (call $reverse (local.get $acc)))))

    ;; reverse : list? -> list?
    ;;   Reverse a proper list.
    (core-runtime-helper
     '$reverse
     "$reverse"
     (lambda ()
       `(func $reverse (type $Prim1) (param $xs (ref eq)) (result (ref eq))
              (local $acc (ref eq))
              (local.set $acc (global.get $null))
              (block $done
                     (loop $rev
                           (if (ref.eq (local.get $xs) (global.get $null))
                               (then (return (local.get $acc))))
                           (if (ref.test (ref $Pair) (local.get $xs))
                               (then
                                (local.set $acc
                                           (struct.new $Pair (i32.const 0)
                                                       (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $xs)))
                                                       (local.get $acc)))
                                (local.set $xs
                                           (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $xs)))))
                               (else (call $raise-pair-expected (local.get $xs))))
                           (br $rev)))
              (unreachable))))

    ;; alt-reverse : list? -> list?
    ;;   Reverse a proper list for expansions that call Racket's alt-reverse.
    (core-runtime-helper
     '$alt-reverse
     "$alt-reverse"
     (lambda ()
       `(func $alt-reverse (type $Prim1) (param $xs (ref eq)) (result (ref eq))
              (local $acc (ref eq))
              (local.set $acc (global.get $null))
              (block $done
                     (loop $rev
                           (if (ref.eq (local.get $xs) (global.get $null))
                               (then (return (local.get $acc))))
                           (if (ref.test (ref $Pair) (local.get $xs))
                               (then
                                (local.set $acc
                                           (struct.new $Pair (i32.const 0)
                                                       (struct.get $Pair $a (ref.cast (ref $Pair) (local.get $xs)))
                                                       (local.get $acc)))
                                (local.set $xs
                                           (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $xs)))))
                               (else (call $raise-pair-expected (local.get $xs))))
                           (br $rev)))
              (unreachable))))

    ;; make-list : exact-nonnegative-integer? any/c -> list?
    ;;   Validate the element count and build a repeated-value list.
    (core-runtime-helper
     '$make-list
     "$make-list"
     (lambda ()
       `(func $make-list (type $Prim2)
              (param $n-raw (ref eq))    ;; fixnum
              (param $v     (ref eq))    ;; value to repeat
              (result       (ref eq))

              (local $n i32)

              ;; Check and unwrap fixnum
              (if (i32.or
                   (i32.eqz (ref.test (ref i31) (local.get $n-raw)))
                   (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $n-raw))) (i32.const 1))
                           (i32.const 0)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:make-list)
                              (global.get $string:exact-nonnegative-integer?)
                              (local.get $n-raw))
                        (unreachable)))
              (local.set $n (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $n-raw))) (i32.const 1)))
              ;; Negative counts must fail before allocation; unsigned decoding
              ;; would otherwise turn them into huge positive counts.
              (if (i32.lt_s (local.get $n) (i32.const 0))
                  (then (call $raise-argument-error1
                              (global.get $symbol:make-list)
                              (global.get $string:exact-nonnegative-integer?)
                              (local.get $n-raw))
                        (unreachable)))
              (call $make-list/checked (local.get $n) (local.get $v)))))

    ;; drop/who : symbol? list? exact-nonnegative-integer? -> any/c
    ;;   Drop a prefix from a list using who for error reporting.
    (core-runtime-helper
     '$drop/who
     "$drop/who"
     (lambda ()
       `(func $drop/who
              (param $who (ref eq))
              (param $lst (ref eq))  ; list
              (param $pos (ref eq))  ; exact-nonnegative-integer?
              (result (ref eq))

              (local $n         i32)
              (local $remaining i32)
              (local $orig      (ref $Pair))
              (local $node      (ref $Pair))
              (local $next      (ref eq))
              (local $len       i32)

              ;; Initialize non-defaultable locals
              (local.set $orig (global.get $dummy-pair))
              (local.set $node (global.get $dummy-pair))
              (local.set $next (global.get $null))

              ;; Decode and validate index
              (if (ref.test (ref i31) (local.get $pos))
                  (then
                   (local.set $n
                              (i32.shr_s
                               (i31.get_s (ref.cast (ref i31) (local.get $pos)))
                               (i32.const 1)))
                   (if (i32.lt_s (local.get $n) (i32.const 0))
                       (then (call $raise-exact-nonnegative-integer-expected/who
                                   (local.get $who)
                                   (local.get $pos))
                             (unreachable))))
                  (else (call $raise-exact-nonnegative-integer-expected/who
                              (local.get $who)
                              (local.get $pos))
                        (unreachable)))

              ;; Dropping zero elements returns the list unchanged
              (if (i32.eqz (local.get $n))
                  (then (return (local.get $lst))))

              ;; Non-empty list required when dropping more than zero
              (if (ref.eq (local.get $lst) (global.get $null))
                  (then (call $raise-bad-list-ref-index/who
                              (local.get $who)
                              (local.get $lst)
                              (local.get $n)
                              (i32.const 0))
                        (unreachable)))
              (if (i32.eqz (ref.test (ref $Pair) (local.get $lst)))
                  (then (call $raise-pair-expected/who
                              (local.get $who)
                              (local.get $lst))
                        (unreachable)))

              (local.set $orig (ref.cast (ref $Pair) (local.get $lst)))
              (local.set $node (local.get $orig))
              (local.set $remaining (local.get $n))

              (loop $loop
                    (local.set $next (struct.get $Pair $d (local.get $node)))
                    (local.set $remaining (i32.sub (local.get $remaining) (i32.const 1)))
                    (if (i32.eqz (local.get $remaining))
                        (then (return (local.get $next))))
                    (if (ref.test (ref $Pair) (local.get $next))
                        (then (local.set $node (ref.cast (ref $Pair) (local.get $next)))
                              (br $loop))
                        (else
                         (local.set $len
                                    (i32.sub (local.get $n) (local.get $remaining)))
                         (call $raise-bad-list-ref-index/who
                               (local.get $who)
                               (local.get $orig)
                               (local.get $n)
                               (local.get $len))
                         (unreachable))))
              (unreachable))))

    ;; drop : list? exact-nonnegative-integer? -> any/c
    ;;   Drop a prefix from a list.
    (core-runtime-helper
     '$drop
     "$drop"
     (lambda ()
       `(func $drop (type $Prim2)
              (param $lst (ref eq))
              (param $pos (ref eq))
              (result (ref eq))
              (call $drop/who
                    (global.get $symbol:drop)
                    (local.get $lst)
                    (local.get $pos)))))

    ;; drop-right/who : symbol? list? exact-nonnegative-integer? -> any/c
    ;;   Drop a suffix from a list using who for error reporting.
    (core-runtime-helper
     '$drop-right/who
     "$drop-right/who"
     (lambda ()
       `(func $drop-right/who
              (param $who (ref eq))
              (param $lst (ref eq))  ; list
              (param $pos (ref eq))  ; exact-nonnegative-integer?
              (result (ref eq))

              (local $n         i32)
              (local $remaining i32)
              (local $first     (ref $Pair))
              (local $lead      (ref eq))
              (local $lag       (ref eq))
              (local $lead-pair (ref $Pair))
              (local $lag-pair  (ref $Pair))
              (local $acc       (ref eq))
              (local $tail      (ref eq))
              (local $rev       (ref eq))
              (local $len       i32)

              ;; Initialize locals for non-defaultable references
              (local.set $first     (global.get $dummy-pair))
              (local.set $lead      (local.get $lst))
              (local.set $lag       (local.get $lst))
              (local.set $lead-pair (global.get $dummy-pair))
              (local.set $lag-pair  (global.get $dummy-pair))
              (local.set $acc       (global.get $null))
              (local.set $tail      (global.get $null))
              (local.set $rev       (global.get $null))

              ;; Decode and validate index
              (if (ref.test (ref i31) (local.get $pos))
                  (then
                   (local.set $n
                              (i32.shr_s
                               (i31.get_s (ref.cast (ref i31) (local.get $pos)))
                               (i32.const 1)))
                   (if (i32.lt_s (local.get $n) (i32.const 0))
                       (then (call $raise-exact-nonnegative-integer-expected/who
                                   (local.get $who)
                                   (local.get $pos))
                             (unreachable))))
                  (else (call $raise-exact-nonnegative-integer-expected/who
                              (local.get $who)
                              (local.get $pos))
                        (unreachable)))

              (if (i32.eqz (local.get $n))
                  (then (return (local.get $lst))))

              (if (ref.eq (local.get $lst) (global.get $null))
                  (then (call $raise-bad-list-ref-index/who
                              (local.get $who)
                              (local.get $lst)
                              (local.get $n)
                              (i32.const 0))
                        (unreachable)))
              (if (i32.eqz (ref.test (ref $Pair) (local.get $lst)))
                  (then (call $raise-pair-expected/who
                              (local.get $who)
                              (local.get $lst))
                        (unreachable)))

              (local.set $first (ref.cast (ref $Pair) (local.get $lst)))
              (local.set $lead (local.get $lst))
              (local.set $lag  (local.get $lst))
              (local.set $remaining (local.get $n))

              (block $advance-done
                     (loop $advance
                           (br_if $advance-done (i32.eqz (local.get $remaining)))
                           (if (ref.test (ref $Pair) (local.get $lead))
                               (then
                                (local.set $lead-pair (ref.cast (ref $Pair) (local.get $lead)))
                                (local.set $lead (struct.get $Pair $d (local.get $lead-pair)))
                                (local.set $remaining (i32.sub (local.get $remaining) (i32.const 1)))
                                (br $advance))
                               (else
                                (if (ref.eq (local.get $lead) (global.get $null))
                                    (then
                                     (local.set $len
                                                (i32.sub (local.get $n) (local.get $remaining)))
                                     (call $raise-bad-list-ref-index/who
                                           (local.get $who)
                                           (local.get $first)
                                           (local.get $n)
                                           (local.get $len))
                                     (unreachable))
                                    (else (call $raise-pair-expected/who
                                                (local.get $who)
                                                (local.get $lead))
                                          (unreachable)))))))

              (local.set $lag (local.get $lst))
              (local.set $acc (global.get $null))
              (block $build-done
                     (loop $build
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $lead)))
                               (then (br $build-done)))
                           (local.set $lag-pair (ref.cast (ref $Pair) (local.get $lag)))
                           (local.set $acc
                                      (call $cons
                                            (struct.get $Pair $a (local.get $lag-pair))
                                            (local.get $acc)))
                           (local.set $lag (struct.get $Pair $d (local.get $lag-pair)))
                           (local.set $lead
                                      (struct.get $Pair $d
                                                  (ref.cast (ref $Pair) (local.get $lead))))
                           (br $build)))

              (local.set $tail (local.get $lead))
              (local.set $rev (call $reverse (local.get $acc)))
              (if (ref.eq (local.get $tail) (global.get $null))
                  (then (return (local.get $rev))))
              (return (call $append/2 (local.get $rev) (local.get $tail))))))

    ;; drop-right : list? exact-nonnegative-integer? -> any/c
    ;;   Drop a suffix from a list.
    (core-runtime-helper
     '$drop-right
     "$drop-right"
     (lambda ()
       `(func $drop-right (type $Prim2)
              (param $lst (ref eq))
              (param $pos (ref eq))
              (result (ref eq))
              (call $drop-right/who
                    (global.get $symbol:drop-right)
                    (local.get $lst)
                    (local.get $pos)))))

    ;; split-at : list? exact-nonnegative-integer? -> values?
    ;;   Return prefix and suffix values split at the given position.
    (core-runtime-helper
     '$split-at
     "$split-at"
     (lambda ()
       `(func $split-at (type $Prim2)
              (param $lst (ref eq))  ; list
              (param $pos (ref eq))  ; exact-nonnegative-integer?
              (result (ref eq))      ; returns two values

              (local $prefix (ref eq))
              (local $suffix (ref eq))

              (local.set $prefix (global.get $null))
              (local.set $suffix (global.get $null))

              (local.set $prefix
                         (call $take/who
                               (global.get $symbol:split-at)
                               (local.get $lst)
                               (local.get $pos)))
              (local.set $suffix
                         (call $drop/who
                               (global.get $symbol:split-at)
                               (local.get $lst)
                               (local.get $pos)))

              (array.new_fixed $Values 2
                               (local.get $prefix)
                               (local.get $suffix)))))

    ;; split-at-right : list? exact-nonnegative-integer? -> values?
    ;;   Return prefix and suffix values split from the right.
    (core-runtime-helper
     '$split-at-right
     "$split-at-right"
     (lambda ()
       `(func $split-at-right (type $Prim2)
              (param $lst (ref eq))  ; list
              (param $pos (ref eq))  ; exact-nonnegative-integer?
              (result (ref eq))      ; returns two values

              (local $prefix  (ref eq))
              (local $suffix  (ref eq))
              (local $acc      (ref eq))
              (local $current  (ref eq))
              (local $pair     (ref $Pair))

              (local.set $prefix  (global.get $null))
              (local.set $suffix  (global.get $null))
              (local.set $acc     (global.get $null))
              (local.set $current (global.get $null))
              (local.set $pair    (global.get $dummy-pair))

              (local.set $suffix
                         (call $take-right/who
                               (global.get $symbol:split-at-right)
                               (local.get $lst)
                               (local.get $pos)))
              (local.set $current (local.get $lst))
              (block $done
                     (loop $build
                           (if (ref.eq (local.get $current) (local.get $suffix))
                               (then (br $done)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $current)))
                               (then (call $raise-pair-expected/who
                                           (global.get $symbol:split-at-right)
                                           (local.get $current))
                                     (unreachable)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $current)))
                           (local.set $acc
                                      (call $cons
                                            (struct.get $Pair $a (local.get $pair))
                                            (local.get $acc)))
                           (local.set $current (struct.get $Pair $d (local.get $pair)))
                           (br $build)))

              (local.set $prefix (call $reverse (local.get $acc)))

              (array.new_fixed $Values 2
                               (local.get $prefix)
                               (local.get $suffix)))))

    ;; dropf : list? procedure? -> any/c
    ;;   Drop leading elements while proc returns a true value.
    (core-runtime-helper
     '$dropf
     "$dropf"
     (lambda ()
       `(func $dropf (type $Prim2)
              (param $lst  (ref eq))  ; list
              (param $proc (ref eq))  ; predicate
              (result (ref eq))

              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))
              (local $args (ref $Args))
              (local $cur  (ref eq))
              (local $pair (ref $Pair))
              (local $elem (ref eq))
              (local $r    (ref eq))

              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:dropf)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              (local.set $cur (local.get $lst))
              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (local.get $cur))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (return (local.get $cur))))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                    (local.set $r
                               (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $args)
                                         (local.get $finv)))
                    (if (ref.eq (local.get $r) (global.get $false))
                        (then (return (local.get $cur))))
                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (br $loop))
              (unreachable))))

    ;; dropf-right : list? procedure? -> any/c
    ;;   Drop trailing elements while proc returns a true value.
    (core-runtime-helper
     '$dropf-right
     "$dropf-right"
     (lambda ()
       `(func $dropf-right (type $Prim2)
              (param $lst  (ref eq))  ; list
              (param $proc (ref eq))  ; predicate
              (result (ref eq))

              (local $f      (ref $Procedure))
              (local $finv   (ref $ProcedureInvoker))
              (local $args   (ref $Args))
              (local $cur    (ref eq))
              (local $pair   (ref $Pair))
              (local $elem   (ref eq))
              (local $r      (ref eq))
              (local $acc    (ref eq))
              (local $suffix (ref eq))
              (local $tmp    (ref eq))
              (local $node   (ref $Pair))
              (local $tail   (ref eq))
              (local $rev    (ref eq))

              ;; Initialize locals for non-defaultable references
              (local.set $acc    (global.get $null))
              (local.set $suffix (global.get $null))
              (local.set $tmp    (global.get $null))
              (local.set $tail   (global.get $null))
              (local.set $rev    (global.get $null))

              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:dropf-right)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              (local.set $cur (local.get $lst))
              (block $done
                     (loop $loop
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                               (then (br $done)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                           (local.set $elem (struct.get $Pair $a (local.get $pair)))
                           (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                           (local.set $r
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $finv)))
                           (if (ref.eq (local.get $r) (global.get $false))
                               (then
                                (if (ref.eq (local.get $suffix) (global.get $null))
                                    (then (nop))
                                    (else
                                     (local.set $tmp (call $reverse (local.get $suffix)))
                                     (local.set $suffix (global.get $null))
                                     (block $flush
                                            (loop $flush-loop
                                                  (if (ref.eq (local.get $tmp) (global.get $null))
                                                      (then (br $flush)))
                                                  (local.set $node
                                                             (ref.cast (ref $Pair)
                                                                       (local.get $tmp)))
                                                  (local.set $acc
                                                             (call $cons
                                                                   (struct.get $Pair $a (local.get $node))
                                                                   (local.get $acc)))
                                                  (local.set $tmp
                                                             (struct.get $Pair $d (local.get $node)))
                                                  (br $flush-loop)))))
                                (local.set $acc (call $cons (local.get $elem) (local.get $acc))))
                               (else
                                (local.set $suffix
                                           (call $cons (local.get $elem) (local.get $suffix)))))
                           (local.set $cur (struct.get $Pair $d (local.get $pair)))
                           (br $loop)))

              (local.set $tail (local.get $cur))
              (local.set $rev (call $reverse (local.get $acc)))
              (if (ref.eq (local.get $tail) (global.get $null))
                  (then (return (local.get $rev))))
              (return (call $append/2 (local.get $rev) (local.get $tail))) )))

    ;; splitf-at : list? procedure? -> values?
    ;;   Split a list where proc first returns #f.
    (core-runtime-helper
     '$splitf-at
     "$splitf-at"
     (lambda ()
       `(func $splitf-at (type $Prim2)
              (param $lst  (ref eq))  ; list
              (param $proc (ref eq))  ; predicate
              (result (ref eq))       ; returns two values

              (local $f      (ref $Procedure))
              (local $inv    (ref $ProcedureInvoker))
              (local $args   (ref $Args))
              (local $res    (ref eq))
              (local $cur    (ref eq))
              (local $pair   (ref $Pair))
              (local $elem   (ref eq))
              (local $acc    (ref eq))
              (local $prefix (ref eq))
              (local $suffix (ref eq))

              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:splitf-at)
                              (local.get $proc))
                        (unreachable)))

              (local.set $f      (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $inv    (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args   (array.new $Args (global.get $null) (i32.const 1)))
              (local.set $pair   (global.get $dummy-pair))
              (local.set $acc    (global.get $null))
              (local.set $prefix (global.get $null))
              (local.set $suffix (global.get $null))

              (local.set $cur (local.get $lst))
              (block $done
                     (loop $loop
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                               (then (local.set $suffix (local.get $cur))
                                     (br $done)))

                           (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                           (local.set $elem (struct.get $Pair $a (local.get $pair)))
                           (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                           (local.set $res
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $inv)))
                           (if (ref.eq (local.get $res) (global.get $false))
                               (then (local.set $suffix (local.get $cur))
                                     (br $done)))

                           (local.set $acc (call $cons (local.get $elem) (local.get $acc)))
                           (local.set $cur (struct.get $Pair $d (local.get $pair)))
                           (br $loop)))

              (local.set $prefix (call $reverse (local.get $acc)))
              (array.new_fixed $Values 2
                               (local.get $prefix)
                               (local.get $suffix)))))

    ;; splitf-at-right : list? procedure? -> values?
    ;;   Split a list from the right where proc first returns #f.
    (core-runtime-helper
     '$splitf-at-right
     "$splitf-at-right"
     (lambda ()
       `(func $splitf-at-right (type $Prim2)
              (param $lst  (ref eq))  ; list
              (param $proc (ref eq))  ; predicate
              (result (ref eq))       ; returns two values

              (local $f            (ref $Procedure))
              (local $finv         (ref $ProcedureInvoker))
              (local $args         (ref $Args))
              (local $cur          (ref eq))
              (local $pair         (ref $Pair))
              (local $elem         (ref eq))
              (local $r            (ref eq))
              (local $acc          (ref eq))
              (local $suffix-rev   (ref eq))
              (local $tmp          (ref eq))
              (local $node         (ref $Pair))
              (local $tail         (ref eq))
              (local $rev          (ref eq))
              (local $prefix       (ref eq))
              (local $suffix       (ref eq))
              (local $suffix-start (ref eq))

              ;; Initialize locals for non-defaultable references
              (local.set $acc          (global.get $null))
              (local.set $suffix-rev   (global.get $null))
              (local.set $tmp          (global.get $null))
              (local.set $tail         (global.get $null))
              (local.set $rev          (global.get $null))
              (local.set $prefix       (global.get $null))
              (local.set $suffix       (global.get $null))

              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:splitf-at-right)
                              (local.get $proc))
                        (unreachable)))

              (local.set $f            (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv         (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args         (array.new $Args (global.get $null) (i32.const 1)))
              (local.set $pair         (global.get $dummy-pair))
              (local.set $suffix-start (local.get $lst))

              (local.set $cur (local.get $lst))
              (block $done
                     (loop $loop
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                               (then (local.set $tail (local.get $cur))
                                     (br $done)))

                           (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                           (local.set $elem (struct.get $Pair $a (local.get $pair)))
                           (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                           (local.set $r
                                      (call_ref $ProcedureInvoker
                                                (local.get $f)
                                                (local.get $args)
                                                (local.get $finv)))
                           (if (ref.eq (local.get $r) (global.get $false))
                               (then
                                (if (ref.eq (local.get $suffix-rev) (global.get $null))
                                    (then (nop))
                                    (else
                                     (local.set $tmp (call $reverse (local.get $suffix-rev)))
                                     (local.set $suffix-rev (global.get $null))
                                     (block $flush
                                            (loop $flush-loop
                                                  (if (ref.eq (local.get $tmp) (global.get $null))
                                                      (then (br $flush)))
                                                  (local.set $node
                                                             (ref.cast (ref $Pair)
                                                                       (local.get $tmp)))
                                                  (local.set $acc
                                                             (call $cons
                                                                   (struct.get $Pair $a (local.get $node))
                                                                   (local.get $acc)))
                                                  (local.set $tmp
                                                             (struct.get $Pair $d (local.get $node)))
                                                  (br $flush-loop)))))
                                (local.set $acc (call $cons (local.get $elem) (local.get $acc)))
                                (local.set $suffix-start (struct.get $Pair $d (local.get $pair))))
                               (else
                                (local.set $suffix-rev
                                           (call $cons (local.get $elem) (local.get $suffix-rev)))))

                           (local.set $cur (struct.get $Pair $d (local.get $pair)))
                           (br $loop)))

              (local.set $rev (call $reverse (local.get $acc)))
              (local.set $prefix
                         (if (result (ref eq))
                             (ref.eq (local.get $tail) (global.get $null))
                             (then (local.get $rev))
                             (else (call $append/2 (local.get $rev) (local.get $tail)))))
              (local.set $suffix (local.get $suffix-start))

              (array.new_fixed $Values 2
                               (local.get $prefix)
                               (local.get $suffix)))))

    ;; memq : any/c list? -> any/c
    ;;   Return the first tail whose car is eq? to needle.
    (member-runtime-helper
     '$memq '$Prim2 #f
     '(ref.eq (local.get $needle) (local.get $elem)))

    ;; memv : any/c list? -> any/c
    ;;   Return the first tail whose car is eqv? to needle.
    (member-runtime-helper
     '$memv '$Prim2 #f
     '(ref.eq (call $eqv? (local.get $needle) (local.get $elem))
              (global.get $true)))

    ;; member : any/c list? [procedure?] -> any/c
    ;;   Return the first tail whose car matches needle.
    (member-runtime-helper
     '$member '$Prim23 #t #f)

    ;; memw : any/c list? -> any/c
    ;;   Return the first tail whose car is equal-always? to needle.
    (member-runtime-helper
     '$memw '$Prim2 #f
     '(ref.eq (call $equal-always? (local.get $needle) (local.get $elem))
              (global.get $true)))

    ;; memf : procedure? list? -> any/c
    ;;   Return the first tail whose car satisfies proc.
    (core-runtime-helper
     '$memf
     "$memf"
     (lambda ()
       `(func $memf (type $Prim2)
              (param $proc (ref eq)) ;; predicate
              (param $lst  (ref eq)) ;; list to search
              (result      (ref eq))

              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))
              (local $cur  (ref eq))
              (local $pair (ref $Pair))
              (local $elem (ref eq))
              (local $args (ref $Args))
              (local $res  (ref eq))

              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:memf)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              (local.set $cur (local.get $lst))
              (loop $search
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (global.get $false))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:memf)
                                    (local.get $cur))
                              (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                    (local.set $res
                               (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $args)
                                         (local.get $finv)))
                    (if (ref.eq (local.get $res) (global.get $false))
                        (then (local.set $cur (struct.get $Pair $d (local.get $pair)))
                              (br $search)))
                    (return (local.get $cur)))
              (unreachable))))

    ;; assoc : any/c list? [procedure?] -> any/c
    ;;   Return the first association pair whose key matches needle.
    (assoc-runtime-helper
     '$assoc '$Prim23 #t #f)

    ;; assw : any/c list? -> any/c
    ;;   Return the first association pair whose key is equal-always? to needle.
    (assoc-runtime-helper
     '$assw '$Prim2 #f
     '(ref.eq (call $equal-always? (local.get $needle) (local.get $key))
              (global.get $true)))

    ;; assv : any/c list? -> any/c
    ;;   Return the first association pair whose key is eqv? to needle.
    (assoc-runtime-helper
     '$assv '$Prim2 #f
     '(ref.eq (call $eqv? (local.get $needle) (local.get $key))
              (global.get $true)))

    ;; assq : any/c list? -> any/c
    ;;   Return the first association pair whose key is eq? to needle.
    (assoc-runtime-helper
     '$assq '$Prim2 #f
     '(ref.eq (local.get $needle) (local.get $key)))

    ;; assf : procedure? list? -> any/c
    ;;   Return the first association pair whose key satisfies proc.
    (core-runtime-helper
     '$assf
     "$assf"
     (lambda ()
       `(func $assf (type $Prim2)
              (param $proc  (ref eq)) ;; predicate
              (param $alist (ref eq)) ;; association list
              (result       (ref eq))

              (local $f          (ref $Procedure))
              (local $finv       (ref $ProcedureInvoker))
              (local $list-pair  (ref $Pair))
              (local $entry      (ref eq))
              (local $entry-pair (ref $Pair))
              (local $key        (ref eq))
              (local $args       (ref $Args))
              (local $res        (ref eq))

              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:assf)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              (loop $search
                    (if (ref.eq (local.get $alist) (global.get $null))
                        (then (return (global.get $false))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $alist)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:assf)
                                    (local.get $alist))
                              (unreachable)))
                    (local.set $list-pair (ref.cast (ref $Pair) (local.get $alist)))
                    (local.set $entry (struct.get $Pair $a (local.get $list-pair)))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $entry)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:assf)
                                    (local.get $entry))
                              (unreachable)))
                    (local.set $entry-pair (ref.cast (ref $Pair) (local.get $entry)))
                    (local.set $key (struct.get $Pair $a (local.get $entry-pair)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $key))
                    (local.set $res
                               (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $args)
                                         (local.get $finv)))
                    (if (ref.eq (local.get $res) (global.get $false))
                        (then (local.set $alist (struct.get $Pair $d (local.get $list-pair)))
                              (br $search)))
                    (return (local.get $entry)))
              (unreachable))))

    ;; findf : procedure? list? -> any/c
    ;;   Return the first element satisfying proc.
    (core-runtime-helper
     '$findf
     "$findf"
     (lambda ()
       `(func $findf (type $Prim2)
              (param $proc (ref eq)) ;; predicate
              (param $lst  (ref eq)) ;; list to search
              (result      (ref eq))

              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))
              (local $cur  (ref eq))
              (local $pair (ref $Pair))
              (local $elem (ref eq))
              (local $args (ref $Args))
              (local $res  (ref eq))

              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:findf)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              (local.set $cur (local.get $lst))
              (loop $search
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (global.get $false))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:findf)
                                    (local.get $cur))
                              (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                    (local.set $res
                               (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $args)
                                         (local.get $finv)))
                    (if (ref.eq (local.get $res) (global.get $false))
                        (then (local.set $cur (struct.get $Pair $d (local.get $pair)))
                              (br $search)))
                    (return (local.get $elem)))
              (unreachable))))

    ;; index-of : list? any/c [procedure?] -> any/c
    ;;   Return the first matching element index, or #f.
    (core-runtime-helper
     '$index-of
     "$index-of"
     (lambda ()
       `(func $index-of (type $Prim23)
              (param $xs     (ref eq))  ;; list
              (param $v      (ref eq))  ;; value to find
              (param $same?  (ref eq))  ;; optional comparator, default equal?
              (result        (ref eq))

              (local $cur      (ref eq))
              (local $pair     (ref $Pair))
              (local $elem     (ref eq))
              (local $args     (ref $Args))
              (local $res      (ref eq))
              (local $use-proc i32)
              (local $i        i32)

              ;; Handle optional comparator
              (if (ref.eq (local.get $same?) (global.get $missing))
                  (then (local.set $use-proc (i32.const 0)))
                  (else
                   (if (i32.eqz (ref.test (ref $Procedure) (local.get $same?)))
                       (then
                        (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:index-of)
                              (local.get $same?))
                        (unreachable)))
                   (local.set $use-proc (i32.const 1))))

              ;; Unconditionally allocate args buffer once; overwrite each iteration.
              (local.set $args (array.new $Args (global.get $null) (i32.const 2)))

              (local.set $cur (local.get $xs))
              (local.set $i   (i32.const 0))
              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (global.get $false))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:index-of)
                                    (local.get $cur))
                              (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))

                    (block $same
                           (if (i32.eqz (local.get $use-proc))
                               (then
                                (if (ref.eq (call $equal? (local.get $elem) (local.get $v))
                                            (global.get $false))
                                    (then (br $same))
                                    (else
                                     (return
                                      (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))))
                               (else
                                ;; Prepare args once per iteration
                                (array.set $Args (local.get $args) (i32.const 0) (local.get $v))
                                (array.set $Args (local.get $args) (i32.const 1) (local.get $elem))
                                ;; Call provided comparator without storing non-defaultable locals
                                (local.set $res
                                           (call_ref $ProcedureInvoker
                                                     (ref.cast (ref $Procedure) (local.get $same?))
                                                     (local.get $args)
                                                     (struct.get $Procedure $invoke
                                                                 (ref.cast (ref $Procedure) (local.get $same?)))))
                                (if (ref.eq (local.get $res) (global.get $false))
                                    (then (br $same))
                                    (else
                                     (return
                                      (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))))))

                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                    (br $loop))
              (unreachable))))

    ;; index-where : list? procedure? -> any/c
    ;;   Return the first index whose element satisfies proc, or #f.
    (core-runtime-helper
     '$index-where
     "$index-where"
     (lambda ()
       `(func $index-where (type $Prim2)
              (param $xs   (ref eq)) ; list
              (param $proc (ref eq)) ; predicate
              (result      (ref eq))

              (local $cur   (ref eq))
              (local $pair  (ref $Pair))
              (local $elem  (ref eq))
              (local $f     (ref $Procedure))
              (local $finv  (ref $ProcedureInvoker))
              (local $args  (ref $Args))
              (local $res   (ref eq))
              (local $i     i32)

              ;; Ensure proc is a procedure
              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:index-where)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              (local.set $cur (local.get $xs))
              (local.set $i   (i32.const 0))
              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (global.get $false))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:index-where)
                                    (local.get $cur))
                              (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                    (local.set $res
                               (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $args)
                                         (local.get $finv)))
                    (if (ref.eq (local.get $res) (global.get $false))
                        (then (nop))
                        (else (return (ref.i31 (i32.shl (local.get $i) (i32.const 1))))))
                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                    (br $loop))
              (unreachable))))

    ;; indexes-of : list? any/c [procedure?] -> list?
    ;;   Return all matching element indexes.
    (core-runtime-helper
     '$indexes-of
     "$indexes-of"
     (lambda ()
       `(func $indexes-of (type $Prim23)
              (param $xs      (ref eq))  ;; list
              (param $v       (ref eq))  ;; value to find
              (param $same?   (ref eq))  ;; optional comparator, default equal?
              (result         (ref eq))

              (local $cur      (ref eq))
              (local $pair     (ref $Pair))
              (local $elem     (ref eq))
              (local $args     (ref $Args))
              (local $res      (ref eq))
              (local $use-proc i32)
              (local $i        i32)
              (local $acc      (ref eq))

              ;; Handle optional comparator
              (if (ref.eq (local.get $same?) (global.get $missing))
                  (then (local.set $use-proc (i32.const 0)))
                  (else
                   (if (i32.eqz (ref.test (ref $Procedure) (local.get $same?)))
                       (then
                        (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:indexes-of)
                              (local.get $same?))
                        (unreachable)))
                   (local.set $use-proc (i32.const 1))))

              ;; Unconditionally allocate args buffer once; we overwrite each iteration.
              (local.set $args (array.new $Args (global.get $null) (i32.const 2)))

              (local.set $cur (local.get $xs))
              (local.set $i   (i32.const 0))
              (local.set $acc (global.get $null))
              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (call $reverse (local.get $acc)))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then
                         (call $raise-pair-expected/who
                               (global.get $symbol:indexes-of)
                               (local.get $cur))
                         (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))

                    (block $same
                           (if (i32.eqz (local.get $use-proc))
                               (then
                                (if (ref.eq (call $equal? (local.get $elem) (local.get $v))
                                            (global.get $false))
                                    (then (br $same))
                                    (else
                                     (local.set $acc
                                                (call $cons
                                                      (ref.i31 (i32.shl (local.get $i) (i32.const 1)))
                                                      (local.get $acc))))))
                               (else
                                ;; Prepare args for comparator: (v, elem)
                                (array.set $Args (local.get $args) (i32.const 0) (local.get $v))
                                (array.set $Args (local.get $args) (i32.const 1) (local.get $elem))

                                ;; Call provided comparator without non-defaultable locals
                                (local.set $res
                                           (call_ref $ProcedureInvoker
                                                     (ref.cast (ref $Procedure) (local.get $same?))
                                                     (local.get $args)
                                                     (struct.get $Procedure $invoke
                                                                 (ref.cast (ref $Procedure) (local.get $same?)))))

                                (if (ref.eq (local.get $res) (global.get $false))
                                    (then (br $same))
                                    (else
                                     (local.set $acc
                                                (call $cons
                                                      (ref.i31 (i32.shl (local.get $i) (i32.const 1)))
                                                      (local.get $acc))))))))

                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                    (br $loop))
              (unreachable))))

    ;; indexes-where : list? procedure? -> list?
    ;;   Return all indexes whose elements satisfy proc.
    (core-runtime-helper
     '$indexes-where
     "$indexes-where"
     (lambda ()
       `(func $indexes-where (type $Prim2)
              (param $xs   (ref eq)) ; list
              (param $proc (ref eq)) ; predicate
              (result      (ref eq))

              (local $cur   (ref eq))
              (local $pair  (ref $Pair))
              (local $elem  (ref eq))
              (local $f     (ref $Procedure))
              (local $finv  (ref $ProcedureInvoker))
              (local $args  (ref $Args))
              (local $res   (ref eq))
              (local $i     i32)
              (local $acc   (ref eq))

              ;; Ensure proc is a procedure
              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:indexes-where)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
              (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

              (local.set $cur (local.get $xs))
              (local.set $i   (i32.const 0))
              (local.set $acc (global.get $null))
              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (call $reverse (local.get $acc)))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:indexes-where)
                                    (local.get $cur))
                              (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                    (local.set $res
                               (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $args)
                                         (local.get $finv)))
                    (if (ref.eq (local.get $res) (global.get $false))
                        (then (nop))
                        (else (local.set $acc
                                         (call $cons
                                               (ref.i31 (i32.shl (local.get $i) (i32.const 1)))
                                               (local.get $acc)))))
                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (local.set $i   (i32.add (local.get $i) (i32.const 1)))
                    (br $loop))
              (unreachable))))

    ;; group-by : procedure? list? [procedure?] -> list?
    ;;   Groups list elements by a key function.
    (core-runtime-helper
     '$group-by
     "$group-by"
     (lambda ()
       `(func $group-by (type $Prim23)
              (param $proc  (ref eq))  ;; key function
              (param $xs    (ref eq))  ;; list
              (param $same? (ref eq))  ;; optional comparator, default equal?
              (result       (ref eq))

              (local $f        (ref $Procedure))
              (local $finv     (ref $ProcedureInvoker))
              (local $cur      (ref eq))
              (local $pair     (ref $Pair))
              (local $x        (ref eq))
              (local $call     (ref $Args))
              (local $k        (ref eq))
              (local $groups   (ref eq))
              (local $use-proc i32)
              (local $same-f   (ref $Procedure))
              (local $same-inv (ref $ProcedureInvoker))

              ; safe defaults for non-defaultable locals
              (local.set $same-f   (ref.cast (ref $Procedure) (global.get $prim:equal?)))
              (local.set $same-inv (ref.cast (ref $ProcedureInvoker)
                                             (struct.get $Procedure $invoke (local.get $same-f))))

              ;; Ensure proc is a procedure and fetch invoker
              (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:group-by)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; Handle optional comparator
              (if (ref.eq (local.get $same?) (global.get $missing))
                  (then (local.set $use-proc (i32.const 0)))
                  (else
                   (if (i32.eqz (ref.test (ref $Procedure) (local.get $same?)))
                       (then (call $raise-argument-error:procedure-expected/who
                                   (global.get $symbol:group-by)
                                   (local.get $same?))
                             (unreachable)))
                   (local.set $use-proc (i32.const 1))
                   (local.set $same-f   (ref.cast (ref $Procedure) (local.get $same?)))
                   (local.set $same-inv (struct.get $Procedure $invoke (local.get $same-f)))))

              ;; Prepare argument buffer for key function
              (local.set $call (array.new $Args (global.get $null) (i32.const 1)))

              ;; Iterate over list building groups
              (local.set $groups (global.get $null))
              (local.set $cur (local.get $xs))
              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (call $group-by:fix-order
                                            (call $group-by:extract-groups (local.get $groups))))))
                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:group-by)
                                    (local.get $cur))
                              (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $x (struct.get $Pair $a (local.get $pair)))
                    (array.set $Args (local.get $call) (i32.const 0) (local.get $x))
                    (local.set $k (call_ref $ProcedureInvoker
                                            (local.get $f)
                                            (local.get $call)
                                            (local.get $finv)))
                    (local.set $groups
                               (if (result (ref eq)) (i32.eqz (local.get $use-proc))
                                   (then (call $group-by:update-groups/equal?
                                               (local.get $k)
                                               (local.get $x)
                                               (local.get $groups)))
                                   (else (call $group-by:update-groups/general
                                               (local.get $k)
                                               (local.get $x)
                                               (local.get $groups)
                                               (local.get $same-f)
                                               (local.get $same-inv)))))
                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (br $loop))
              (unreachable))))

    ;; group-by:fix-order : list? -> list?
    ;;   Fix order of groups and their elements produced in reverse.
    (core-runtime-helper
     '$group-by:fix-order
     "$group-by:fix-order"
     (lambda ()
       `(func $group-by:fix-order
              (param $groups (ref eq))  ;;  list of lists
              (result        (ref eq))

              (local $node  (ref $Pair))
              (local $xs    (ref eq))
              (local $acc   (ref eq))     ;; reversed accumulator of fixed groups

              (local.set $acc (global.get $null))
              (block $done
                     (loop $loop
                           ;; End of outer list -> return reversed accumulator
                           (if (ref.eq (local.get $groups) (global.get $null))
                               (then (return (local.get $acc))))

                           ;; Ensure groups is a proper list
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $groups)))
                               (then (call $raise-pair-expected (local.get $groups))
                                     (unreachable)))

                           (local.set $node (ref.cast (ref $Pair) (local.get $groups)))
                           (local.set $xs   (struct.get $Pair $a (local.get $node)))
                           (local.set $groups (struct.get $Pair $d (local.get $node)))

                           ;; Reverse each subgroup and cons onto accumulator
                           (local.set $acc
                                      (struct.new $Pair (i32.const 0)
                                                  (call $reverse (local.get $xs))
                                                  (local.get $acc)))

                           (br $loop)))

              (unreachable))))

    ;; group-by:update-groups/equal? : any/c any/c list? -> list?
    ;;   Add an element to an equal?-matched group.
    (core-runtime-helper
     '$group-by:update-groups/equal?
     "$group-by:update-groups/equal?"
     (lambda ()
       `(func $group-by:update-groups/equal?
              (param $k      (ref eq)) ;; key
              (param $x      (ref eq)) ;; element
              (param $groups (ref eq)) ;; groups list
              (result        (ref eq))

              (local $gs     (ref eq))
              (local $pair   (ref $Pair))
              (local $bucket (ref $Pair))
              (local $bk     (ref eq))
              (local $box    (ref eq))
              (local.set $gs (local.get $groups))
              (loop $loop
                    (if (ref.eq (local.get $gs) (global.get $null))
                        (then (return (call $cons
                                            (call $cons (local.get $k)
                                                  (call $box
                                                        (call $cons (local.get $x)
                                                              (global.get $null))))
                                            (local.get $groups)))))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $gs)))
                    (local.set $bucket (ref.cast (ref $Pair) (struct.get $Pair $a (local.get $pair))))
                    (local.set $bk  (struct.get $Pair $a (local.get $bucket)))
                    (local.set $box (struct.get $Pair $d (local.get $bucket)))
                    (if (ref.eq (call $equal? (local.get $k) (local.get $bk)) (global.get $false))
                        (then (local.set $gs (struct.get $Pair $d (local.get $pair)))
                              (br $loop))
                        (else (call $set-box!
                                    (local.get $box)
                                    (call $cons (local.get $x)
                                          (call $unbox (local.get $box))))
                              (return (local.get $groups)))))
              (unreachable))))

    ;; group-by:update-groups/general : any/c any/c list? procedure? any/c -> list?
    ;;   Add an element to a group matched by a comparator procedure.
    (core-runtime-helper
     '$group-by:update-groups/general
     "$group-by:update-groups/general"
     (lambda ()
       `(func $group-by:update-groups/general
              (param $k        (ref eq))         ;; key
              (param $x        (ref eq))         ;; element
              (param $groups   (ref eq))         ;; groups list
              (param $same     (ref $Procedure)) ;; comparator
              (param $same-inv (ref $ProcedureInvoker))
              (result          (ref eq))

              (local $gs    (ref eq))
              (local $pair  (ref $Pair))
              (local $bucket (ref $Pair))
              (local $bk    (ref eq))
              (local $box   (ref eq))
              (local $args  (ref $Args))
              (local $res   (ref eq))

              (local.set $gs   (local.get $groups))
              (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
              (loop $loop
                    (if (ref.eq (local.get $gs) (global.get $null))
                        (then (return (call $cons
                                            (call $cons (local.get $k)
                                                  (call $box
                                                        (call $cons (local.get $x)
                                                              (global.get $null))))
                                            (local.get $groups)))))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $gs)))
                    (local.set $bucket (ref.cast (ref $Pair) (struct.get $Pair $a (local.get $pair))))
                    (local.set $bk  (struct.get $Pair $a (local.get $bucket)))
                    (local.set $box (struct.get $Pair $d (local.get $bucket)))
                    (array.set $Args (local.get $args) (i32.const 0) (local.get $k))
                    (array.set $Args (local.get $args) (i32.const 1) (local.get $bk))
                    (local.set $res (call_ref $ProcedureInvoker
                                              (local.get $same)
                                              (local.get $args)
                                              (local.get $same-inv)))
                    (if (ref.eq (local.get $res) (global.get $false))
                        (then (local.set $gs (struct.get $Pair $d (local.get $pair)))
                              (br $loop))
                        (else (call $set-box!
                                    (local.get $box)
                                    (call $cons (local.get $x)
                                          (call $unbox (local.get $box))))
                              (return (local.get $groups)))))
              (unreachable))))

    ;; group-by:extract-groups : list? -> list?
    ;;   Extract grouped element lists from group buckets.
    (core-runtime-helper
     '$group-by:extract-groups
     "$group-by:extract-groups"
     (lambda ()
       `(func $group-by:extract-groups
              (param $groups (ref eq))
              (result        (ref eq))

              (local $cur    (ref eq))
              (local $pair   (ref $Pair))
              (local $bucket (ref $Pair))
              (local $box    (ref eq))
              (local $acc    (ref eq))

              (local.set $cur (local.get $groups))
              (local.set $acc (global.get $null))

              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (call $reverse (local.get $acc)))))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $bucket (ref.cast (ref $Pair) (struct.get $Pair $a (local.get $pair))))
                    (local.set $box (struct.get $Pair $d (local.get $bucket)))
                    (local.set $acc (call $cons (call $unbox (local.get $box)) (local.get $acc)))
                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (br $loop))
              (unreachable))))

    ;; map : procedure? list? ... -> list?
    ;;   Apply proc over one or more lists and collect results.
    (core-runtime-helper
     '$map
     "$map"
     (lambda ()
       `(func $map (type $Prim>=2)
             (param $proc   (ref eq))   ;; procedure
             (param $xs0    (ref eq))   ;; list?
             (param $rest   (ref eq))   ;; list of lists
             (result        (ref eq))

             (local $f      (ref $Procedure))
             (local $finv   (ref $ProcedureInvoker))
             (local $pair   (ref $Pair))
             (local $nlists i32)
             (local $xss    (ref eq))

             (local $lists  (ref $Args))  ;; cursors for each list
             (local $call   (ref $Args))  ;; args for f (length = nlists)
             (local $i      i32)
             (local $cur    (ref eq))
             (local $stop   i32)

             (local $acc    (ref eq))     ;; reversed accumulator
             (local $res    (ref eq))     ;; final result
             (local $r      (ref eq))

             ;; 1) Check that $proc is a procedure and fetch its invoker
             (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:map)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; 2) Build list-of-lists from first list and rest
             (local.set $xss (struct.new $Pair
                                         (i32.const 0)
                                         (local.get $xs0)
                                         (local.get $rest)))

             ;; 3) Walk outer list xss to count #lists; ensure xss is proper and each element is a list head
             (local.set $nlists (call $validate-list-args
                                      (global.get $symbol:map)
                                      (local.get $xss)))

             ;; Racket's map requires at least one list argument
             (if (i32.eq (local.get $nlists) (i32.const 0))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:map))
                             (i32.const 1))
                       (unreachable)))

             ;; 4) Allocate arrays for list cursors and call arguments; seed list cursors from xss
             (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
             (local.set $call  (array.new $Args (global.get $null) (local.get $nlists)))
             (call $seed-list-args (local.get $xss) (local.get $lists))

             ;; 5) Main loop: stop at the shortest list
             (local.set $acc (global.get $null))

             (loop $loop
                   ;; (a) Check state of all lists; determine if we stop
                   (local.set $stop (i32.const 0))
                   (local.set $i (i32.const 0))
                   (block $check_done
                          (loop $check
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $check_done)))
                                (local.set $cur (array.get $Args (local.get $lists) (local.get $i)))
                                (if (ref.eq (local.get $cur) (global.get $null))
                                    (then (local.set $stop (i32.const 1)))
                                    (else
                                     (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                                         (then (call $raise-pair-expected/who
                                                     (global.get $symbol:map)
                                                     (local.get $cur))
                                               (unreachable)))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $check)))

                   ;; If any list is empty → finish by reversing $acc
                   (if (i32.ne (local.get $stop) (i32.const 0))
                       (then
                        (local.set $res  (global.get $null))
                        (local.set $cur  (local.get $acc))
                        (loop $rev
                              (if (ref.eq (local.get $cur) (global.get $null))
                                  (then (return (local.get $res))))
                              (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                              (local.set $res
                                         (call $cons
                                               (struct.get $Pair $a (local.get $pair))
                                               (local.get $res)))
                              (local.set $cur (struct.get $Pair $d (local.get $pair)))
                              (br $rev))))

                   ;; (b) Build call args for f: cars of each list
                   (local.set $i (i32.const 0))
                   (block $cars_done
                          (loop $cars
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $cars_done)))
                                (local.set $pair
                                           (ref.cast (ref $Pair)
                                                     (array.get $Args (local.get $lists) (local.get $i))))
                                (array.set $Args
                                           (local.get $call) (local.get $i)
                                           (struct.get $Pair $a (local.get $pair)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $cars)))

                   ;; (c) Apply f to those cars
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))

                   ;; (d) cons the result onto the accumulator
                   (local.set $acc (call $cons (local.get $r) (local.get $acc)))

                   ;; (e) Advance each list (cdr)
                   (local.set $i (i32.const 0))
                   (block $cdrs_done
                          (loop $cdrs
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $cdrs_done)))
                                (local.set $pair
                                           (ref.cast (ref $Pair)
                                                     (array.get $Args (local.get $lists) (local.get $i))))
                                (array.set $Args
                                           (local.get $lists) (local.get $i)
                                           (struct.get $Pair $d (local.get $pair)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $cdrs)))

                   (br $loop))
             (unreachable))))

    ;; andmap : procedure? list? ... -> any/c
    ;;   Apply proc over one or more lists until #f or the end.
    (core-runtime-helper
     '$andmap
     "$andmap"
     (lambda ()
       `(func $andmap (type $Prim>=2)
             (param $proc (ref eq))   ;; procedure
             (param $xs0  (ref eq))   ;; list?
             (param $rest (ref eq))   ;; list of lists
             (result      (ref eq))

             (local $f      (ref $Procedure))
             (local $finv   (ref $ProcedureInvoker))
             (local $pair   (ref $Pair))
             (local $nlists i32)
             (local $xss    (ref eq))

             (local $lists  (ref $Args))  ;; cursors for each list
             (local $call   (ref $Args))  ;; args for f (length = nlists)
             (local $i      i32)
             (local $cur    (ref eq))
             (local $stop   i32)
             (local $r      (ref eq))

             ;; 1) Check that $proc is a procedure and fetch its invoker
             (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:andmap)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; 2) Build list-of-lists from first list and rest
             (local.set $xss (struct.new $Pair
                                         (i32.const 0)
                                         (local.get $xs0)
                                         (local.get $rest)))

             ;; 3) Walk outer list xss to count #lists; ensure xss is proper and each element is a list head
             (local.set $nlists (call $validate-list-args
                                      (global.get $symbol:andmap)
                                      (local.get $xss)))

             ;; Racket's andmap requires at least one list argument
             (if (i32.eq (local.get $nlists) (i32.const 0))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:andmap))
                             (i32.const 1))
                       (unreachable)))

             ;; 4) Allocate arrays for list cursors and call arguments; seed list cursors from xss
             (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
             (local.set $call  (array.new $Args (global.get $null) (local.get $nlists)))

             (call $seed-list-args (local.get $xss) (local.get $lists))

             ;; 5) Main loop: stop at the shortest list or when f returns #f
             (loop $loop
                   ;; (a) Check state of all lists; determine if we stop (empty)
                   (local.set $stop (i32.const 0))
                   (local.set $i (i32.const 0))
                   (block $check_done
                          (loop $check
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $check_done)))
                                (local.set $cur (array.get $Args (local.get $lists) (local.get $i)))
                                (if (ref.eq (local.get $cur) (global.get $null))
                                    (then (local.set $stop (i32.const 1)))
                                    (else
                                     (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                                         (then (call $raise-pair-expected/who
                                                     (global.get $symbol:andmap)
                                                     (local.get $cur))
                                               (unreachable)))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $check)))

                   ;; If any list is empty → return #t
                   (if (i32.ne (local.get $stop) (i32.const 0))
                       (then (return (global.get $true))))

                   ;; (b) Build call args for f: cars of each list and advance lists
                   (local.set $stop (i32.const 0))
                   (local.set $i (i32.const 0))
                   (block $cars_done
                          (loop $cars
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $cars_done)))
                                (local.set $pair
                                           (ref.cast (ref $Pair)
                                                     (array.get $Args (local.get $lists) (local.get $i))))
                                (array.set $Args
                                           (local.get $call) (local.get $i)
                                           (struct.get $Pair $a (local.get $pair)))
                                (local.set $cur (struct.get $Pair $d (local.get $pair)))
                                (array.set $Args
                                           (local.get $lists) (local.get $i) (local.get $cur))
                                (if (ref.eq (local.get $cur) (global.get $null))
                                    (then (local.set $stop (i32.const 1))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $cars)))

                   ;; (c) Apply f to those cars
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))

                   ;; (d) If result is #f, return #f
                   (if (ref.eq (local.get $r) (global.get $false))
                       (then (return (global.get $false))))

                   ;; (e) If we've reached the end, return the result
                   (if (i32.ne (local.get $stop) (i32.const 0))
                       (then (return (local.get $r))))

                   ;; (f) Continue
                   (br $loop))
             (unreachable))))

    ;; ormap : procedure? list? ... -> any/c
    ;;   Apply proc over one or more lists until a true result or the end.
    (core-runtime-helper
     '$ormap
     "$ormap"
     (lambda ()
       `(func $ormap (type $Prim>=2)
             (param $proc (ref eq))   ;; procedure
             (param $xs0  (ref eq))   ;; list?
             (param $rest (ref eq))   ;; list of lists
             (result      (ref eq))

             (local $f      (ref $Procedure))
             (local $finv   (ref $ProcedureInvoker))
             (local $pair   (ref $Pair))
             (local $nlists i32)
             (local $xss    (ref eq))

             (local $lists  (ref $Args))  ;; cursors for each list
             (local $call   (ref $Args))  ;; args for f (length = nlists)
             (local $i      i32)
             (local $cur    (ref eq))
             (local $stop   i32)
             (local $r      (ref eq))

             ;; 1) Check that $proc is a procedure and fetch its invoker
             (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:ormap)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; 2) Build list-of-lists from first list and rest
             (local.set $xss (struct.new $Pair
                                         (i32.const 0)
                                         (local.get $xs0)
                                         (local.get $rest)))

             ;; 3) Walk outer list xss to count #lists; ensure xss is proper and each element is a list head
             (local.set $nlists (call $validate-list-args
                                      (global.get $symbol:ormap)
                                      (local.get $xss)))

             ;; Racket's ormap requires at least one list argument
             (if (i32.eq (local.get $nlists) (i32.const 0))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:ormap))
                             (i32.const 1))
                       (unreachable)))

             ;; 4) Allocate arrays for list cursors and call arguments; seed list cursors from xss
             (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
             (local.set $call  (array.new $Args (global.get $null) (local.get $nlists)))

             (call $seed-list-args (local.get $xss) (local.get $lists))

             ;; 5) Main loop: stop at the shortest list or when f returns truthy
             (loop $loop
                   ;; (a) Check state of all lists; determine if we stop
                   (local.set $stop (i32.const 0))
                   (local.set $i (i32.const 0))
                   (block $check_done
                          (loop $check
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $check_done)))
                                (local.set $cur (array.get $Args (local.get $lists) (local.get $i)))
                                (if (ref.eq (local.get $cur) (global.get $null))
                                    (then (local.set $stop (i32.const 1)))
                                    (else
                                     (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                                         (then (call $raise-pair-expected/who
                                                     (global.get $symbol:ormap)
                                                     (local.get $cur))
                                               (unreachable)))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $check)))

                   ;; If any list is empty → return #f
                   (if (i32.ne (local.get $stop) (i32.const 0))
                       (then (return (global.get $false))))

                   ;; (b) Build call args for f: cars of each list
                   (local.set $i (i32.const 0))
                   (block $cars_done
                          (loop $cars
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $cars_done)))
                                (local.set $pair
                                           (ref.cast (ref $Pair)
                                                     (array.get $Args (local.get $lists) (local.get $i))))
                                (array.set $Args
                                           (local.get $call) (local.get $i)
                                           (struct.get $Pair $a (local.get $pair)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $cars)))

                   ;; (c) Apply f to those cars
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))

                   ;; (d) If result is not #f, return it
                   (if (ref.eq (local.get $r) (global.get $false))
                       (then (nop))
                       (else (return (local.get $r))))

                   ;; (e) Advance each list (cdr)
                   (local.set $i (i32.const 0))
                   (block $cdrs_done
                          (loop $cdrs
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $cdrs_done)))
                                (local.set $pair
                                           (ref.cast (ref $Pair)
                                                     (array.get $Args (local.get $lists) (local.get $i))))
                                (array.set $Args
                                           (local.get $lists) (local.get $i)
                                           (struct.get $Pair $d (local.get $pair)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $cdrs)))

                   (br $loop))
             (unreachable))))

    ;; for-each : procedure? list? ... -> void?
    ;;   Apply proc over one or more lists for effects.
    (core-runtime-helper
     '$for-each
     "$for-each"
     (lambda ()
       `(func $for-each (type $Prim>=2)
             (param $proc (ref eq))   ;; procedure
             (param $xs0  (ref eq))   ;; list?
             (param $rest (ref eq))   ;; list of lists
             (result      (ref eq))

             (local $f      (ref $Procedure))
             (local $finv   (ref $ProcedureInvoker))
             (local $pair   (ref $Pair))
             (local $nlists i32)
             (local $xss    (ref eq))

             (local $lists  (ref $Args))  ;; cursors for each list
             (local $call   (ref $Args))  ;; args for f (length = nlists)
             (local $i      i32)
             (local $cur    (ref eq))
             (local $stop   i32)

             ;; 1) Check that $proc is a procedure and fetch its invoker
             (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc)))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:for-each)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; 2) Build list-of-lists from first list and rest
             (local.set $xss (struct.new $Pair
                                         (i32.const 0)
                                         (local.get $xs0)
                                         (local.get $rest)))

             ;; 3) Walk outer list xss to count #lists; ensure xss is proper and each element is a list head
             (local.set $nlists (call $validate-list-args
                                      (global.get $symbol:for-each)
                                      (local.get $xss)))

             ;; Racket's for-each requires at least one list argument
             (if (i32.eq (local.get $nlists) (i32.const 0))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:for-each))
                             (i32.const 1))
                       (unreachable)))

             ;; 4) Allocate arrays for list cursors and call arguments; seed list cursors from xss
             (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
             (local.set $call  (array.new $Args (global.get $null) (local.get $nlists)))
             (call $seed-list-args (local.get $xss) (local.get $lists))

             ;; 5) Main loop: stop at the shortest list
             (loop $loop
                   ;; (a) Check state of all lists; determine if we stop
                   (local.set $stop (i32.const 0))
                   (local.set $i (i32.const 0))
                   (block $check_done
                          (loop $check
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $check_done)))
                                (local.set $cur (array.get $Args (local.get $lists) (local.get $i)))
                                (if (ref.eq (local.get $cur) (global.get $null))
                                    (then (local.set $stop (i32.const 1)))
                                    (else
                                     (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                                         (then (call $raise-pair-expected/who
                                                     (global.get $symbol:for-each)
                                                     (local.get $cur))
                                               (unreachable)))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $check)))

                   ;; If any list is empty → return void
                   (if (i32.ne (local.get $stop) (i32.const 0))
                       (then (return (global.get $void))))

                   ;; (b) Build call args for f: cars of each list
                   (local.set $i (i32.const 0))
                   (block $cars_done
                          (loop $cars
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $cars_done)))
                                (local.set $pair
                                           (ref.cast (ref $Pair)
                                                     (array.get $Args (local.get $lists) (local.get $i))))
                                (array.set $Args
                                           (local.get $call) (local.get $i)
                                           (struct.get $Pair $a (local.get $pair)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $cars)))

                   ;; (c) Apply f to those cars and drop result
                   (drop (call_ref $ProcedureInvoker
                                   (local.get $f)
                                   (local.get $call)
                                   (local.get $finv)))

                   ;; (d) Advance each list (cdr)
                   (local.set $i (i32.const 0))
                   (block $cdrs_done
                          (loop $cdrs
                                (if (i32.ge_u (local.get $i) (local.get $nlists))
                                    (then (br $cdrs_done)))
                                (local.set $pair
                                           (ref.cast (ref $Pair)
                                                     (array.get $Args (local.get $lists) (local.get $i))))
                                (array.set $Args
                                           (local.get $lists) (local.get $i)
                                           (struct.get $Pair $d (local.get $pair)))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $cdrs)))

                   (br $loop))
             (unreachable)))))))
