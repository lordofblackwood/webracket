#lang racket

(provide list-core-runtime-helpers
         pair-global-forms
         list-higher-order-primitive-global-forms
         list-higher-order-primitive-global-names
         list-pre-contract-runtime-helper-forms
         list-post-contract-runtime-helper-forms
         list-runtime-string-constants
         list-runtime-symbol-constants
         list-runtime-only-helpers)

(require "../core-helper.rkt"
         "../../private/wasm-utils.rkt")

;; list-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a list support global form.
(define (list-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'list-global-form-name
              "expected global form, got: ~s"
              form)]))

;; list-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by pair/list predicates and list errors.
(define list-runtime-string-constants
  '((pair?           "pair?")
    (list?           "list?")
    (non-empty-list? "(and/c list? (not/c empty?))")
    (listof-pair?    "(listof pair?)")
    (list-index-too-large ": index too large for list")
    (list-index-reaches-non-pair ": index reaches a non-pair")
    (list-index      "\n  index: ")
    (list-in         "\n  in: ")
    (list-at-least-elements-prefix "a list with at least ")
    (list-at-least-elements-suffix " elements")
    (list-at-least-pairs-prefix "a (possibly improper) list with at least ")
    (list-at-least-pairs-suffix " pairs")
    (list-procedure "procedure?")
    (build-list-procedure "(exact-nonnegative-integer? . -> . any/c)")
    (memf-procedure "(any/c . -> any/c)")
    (list-unary-procedure "(any/c . -> . any/c)")
    (list-index-predicate "(-> any/c any/c)")
    (list-index-comparator "(-> any/c any/c any/c)")
    (list-binary-comparator "(any/c any/c . -> . any/c)")
    (member-comparator "(procedure-arity-includes/c 2)")
    (argminmax-procedure "(any/c . -> . real?)")
    (range:non-zero-step "(and/c real? (not/c zero?))")))

;; list-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by pair and list helpers.
(define list-runtime-symbol-constants
  '(list
    cons
    car
    cdr
    pair?
    length
    list-ref
    list-tail
    list-set
    list-update
    count
    rest
    take
    take-right
    drop
    drop-right
    split-at
    split-at-right
    first
    second
    third
    fourth
    fifth
    sixth
    seventh
    eighth
    ninth
    tenth
    eleventh
    twelfth
    thirteenth
    fourteenth
    fifteenth
    last
    in-inclusive-range))

;; pair-global-forms : (listof datum?)
;;   Declare shared pair values used for default local initialization.
(define pair-global-forms
  '(
         (global $dummy-pair (ref $Pair)
                 (struct.new $Pair
                             (i32.const 0)            ;; hash = 0
                             (global.get $false)      ;; a = null
                             (global.get $false)))))  ;; d = null

;; list-higher-order-primitive-global-forms : (listof datum?)
;;   Declare primitive globals used by higher-order list helpers for error reporting.
(define list-higher-order-primitive-global-forms
  '(
               (global $prim:map        (mut (ref eq)) (global.get $undefined))
               (global $prim:andmap     (mut (ref eq)) (global.get $undefined))
               (global $prim:ormap      (mut (ref eq)) (global.get $undefined))
               (global $prim:for-each   (mut (ref eq)) (global.get $undefined))
               (global $prim:append-map (mut (ref eq)) (global.get $undefined))
               (global $prim:count      (mut (ref eq)) (global.get $undefined))
               (global $prim:foldl      (mut (ref eq)) (global.get $undefined))
               (global $prim:foldr      (mut (ref eq)) (global.get $undefined))))

;; list-higher-order-primitive-global-names : (listof symbol?)
;;   Enumerate higher-order list primitive globals shared by split modules.
(define list-higher-order-primitive-global-names
  (map list-global-form-name list-higher-order-primitive-global-forms))

;; list-base-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate manually defined list helpers that originated in core runtime.
(define list-base-core-runtime-helpers
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

;; pair-accessor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generated composed car/cdr accessors.
(define pair-accessor-runtime-only-helper-names
  pair-accessor-names)

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

;; list-ordinal-accessor-names : (listof symbol?)
;;   Names for generated ordinal list accessors.
(define list-ordinal-accessor-names
  '($first $second $third $fourth $fifth $sixth $seventh $eighth
    $ninth $tenth $eleventh $twelfth $thirteenth $fourteenth $fifteenth))

;; list-ordinal-accessor-helper : symbol? exact-nonnegative-integer? -> core-runtime-helper?
;;   Build a helper for a generated ordinal list accessor.
(define (list-ordinal-accessor-helper name idx)
  (define who-global
    (string->symbol
     (format "$symbol:~a" (substring (symbol->string name) 1))))
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type $Prim1)
            (param $xs (ref eq))
            (result (ref eq))
            ;; Type check: non-empty proper list
            (if (ref.eq (local.get $xs) (global.get $null))
                (then (call $raise-argument-error1
                            (global.get ,who-global)
                            (global.get $string:non-empty-list?)
                            (local.get $xs))
                      (unreachable)))
            (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                (then (call $raise-argument-error1
                            (global.get ,who-global)
                            (global.get $string:non-empty-list?)
                            (local.get $xs))
                      (unreachable)))
            ;; Retrieve element using list-ref
            (call $list-ref
                  (local.get $xs)
                  (ref.i31 (i32.shl (i32.const ,idx) (i32.const 1))))))))

;; list-ordinal-accessor-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate generated ordinal list accessors used by the monolithic runtime.
(define list-ordinal-accessor-runtime-only-helpers
  (for/list ([name (in-list list-ordinal-accessor-names)]
             [idx  (in-naturals)])
    (list-ordinal-accessor-helper name idx)))

;; list-ordinal-accessor-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for generated ordinal list accessors.
(define list-ordinal-accessor-runtime-only-helper-names
  (map core-runtime-helper-name list-ordinal-accessor-runtime-only-helpers))

;; list-member-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for member-family helpers.
(define list-member-runtime-only-helper-names
  '($memq
    $memv
    $member
    $memw))

;; list-association-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for assoc-family helpers.
(define list-association-runtime-only-helper-names
  '($assoc
    $assw
    $assv
    $assq))

;; list-group-by-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for group-by helpers.
(define list-group-by-runtime-only-helper-names
  '($group-by
    $group-by:fix-order
    $group-by:update-groups/equal?
    $group-by:update-groups/general
    $group-by:extract-groups))

;; list-remove-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for single-value removal helpers.
(define list-remove-runtime-only-helper-names
  '($remq
    $remv
    $remw))

;; list-remove-star-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for multi-value removal helpers.
(define list-remove-star-runtime-only-helper-names
  '($remq*
    $remv*
    $remw*))

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
                         (if (ref.eq (call $procedure? (local.get $same?))
                                     (global.get $false))
                             (then (call $raise-argument-error1
                                         (global.get ,who)
                                         (global.get $string:member-comparator)
                                         (local.get $same?))
                                   (unreachable)))
                         (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                            (ref.cast (ref $Procedure) (local.get $same?))
                                            (i32.const 2)))
                             (then (call $raise-argument-error1
                                         (global.get ,who)
                                         (global.get $string:member-comparator)
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
                         (if (ref.eq (call $procedure? (local.get $same?))
                                     (global.get $false))
                             (then (call $raise-argument-error1
                                         (global.get ,who)
                                         (global.get $string:list-binary-comparator)
                                         (local.get $same?))
                                   (unreachable)))
                         (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                            (ref.cast (ref $Procedure) (local.get $same?))
                                            (i32.const 2)))
                             (then (call $raise-argument-error1
                                         (global.get ,who)
                                         (global.get $string:list-binary-comparator)
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

;; remove-alias-runtime-helper : symbol? symbol? symbol? symbol? -> core-runtime-helper?
;;   Build a fixed-comparator remove/remove* alias helper.
(define (remove-alias-runtime-helper name target first-param cmp)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type $Prim2)
            (param ,first-param (ref eq))
            (param $lst (ref eq))
            (result     (ref eq))

            (return_call ,target
                         (local.get ,first-param)
                         (local.get $lst)
                         (global.get ,cmp))))))

;; argminmax-runtime-helper : symbol? symbol? symbol? -> core-runtime-helper?
;;   Build an argmin/argmax helper with the given comparison primitive.
(define (argminmax-runtime-helper name who cmp)
  (core-runtime-helper
   name
   (symbol->string name)
   (lambda ()
     `(func ,name (type $Prim2)
            (param $proc (ref eq))
            (param $lst  (ref eq))
            (result (ref eq))

            (local $f     (ref $Procedure))
            (local $finv  (ref $ProcedureInvoker))
            (local $args  (ref $Args))
            (local $pair  (ref $Pair))
            (local $best  (ref eq))
            (local $bestv (ref eq))
            (local $elem  (ref eq))
            (local $val   (ref eq))
            (local $cur   (ref eq))

            ;; Check that proc is a procedure and fetch its invoker
            (if (ref.eq (call $procedure? (local.get $proc))
                        (global.get $false))
                (then (call $raise-argument-error1
                            (global.get ,who)
                            (global.get $string:argminmax-procedure)
                            (local.get $proc))
                      (unreachable)))
            ;; Ensure lst is a non-empty proper list
            (if (ref.eq (local.get $lst) (global.get $null))
                (then (call $raise-argument-error1
                            (global.get ,who)
                            (global.get $string:non-empty-list?)
                            (local.get $lst))
                      (unreachable)))
            (if (ref.eq (call $list? (local.get $lst)) (global.get $false))
                (then (call $raise-argument-error1
                            (global.get ,who)
                            (global.get $string:non-empty-list?)
                            (local.get $lst))
                      (unreachable)))
            (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
            (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

            ;; Prepare argument array
            (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

            (local.set $pair (ref.cast (ref $Pair) (local.get $lst)))
            (local.set $elem (struct.get $Pair $a (local.get $pair)))
            (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
            (local.set $best  (local.get $elem))
            (local.set $bestv (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $args)
                                        (local.get $finv)))
            (local.set $cur (struct.get $Pair $d (local.get $pair)))

            (block $done
                   (loop $loop
                         (if (ref.eq (local.get $cur) (global.get $null))
                             (then (br $done)))
                         (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                             (then (call $raise-pair-expected (local.get $cur)) (unreachable)))
                         (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                         (local.set $elem (struct.get $Pair $a (local.get $pair)))
                         (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                         (local.set $val
                                    (call_ref $ProcedureInvoker
                                              (local.get $f)
                                              (local.get $args)
                                              (local.get $finv)))
                         (if (ref.eq (call ,cmp (local.get $bestv) (local.get $val))
                                     (global.get $true))
                             (then (local.set $best  (local.get $elem))
                                   (local.set $bestv (local.get $val))))
                         (local.set $cur (struct.get $Pair $d (local.get $pair)))
                         (br $loop)))
             (local.get $best)))))

;; list-error-runtime-only-forms : (listof datum?)
;;   Enumerate pair/list error helpers used by the monolithic runtime.
(define list-error-runtime-only-forms
  '(
        ;; Pair/list related exceptions
         (func $raise-pair-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:pair?)
                     (local.get $x)))
         (func $raise-pair-expected
               (param $x (ref eq))
               (call $raise-pair-expected/who
                     (global.get $symbol:pair?)
                     (local.get $x)))
         (func $raise-list-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:list?)
                     (local.get $x)))
         (func $raise-exact-nonnegative-integer-expected/who
               (param $who (ref eq))
               (param $x   (ref eq))
               (call $raise-argument-error1
                     (local.get $who)
                     (global.get $string:exact-nonnegative-integer?)
                     (local.get $x)))
         (func $raise-bad-list-ref-index/who
               (param $who (ref eq))
               (param $xs  (ref eq))
               (param $i   i32)
               (param $len i32)
               (local $out     (ref $GrowableArray))
               (local $message (ref $String))

               (local.set $out
                          (call $make-growable-array (i32.const 8)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (if (ref.eq (call $list? (local.get $xs)) (global.get $true))
                   (then (call $growable-array-add! (local.get $out)
                               (global.get $string:list-index-too-large)))
                   (else (call $growable-array-add! (local.get $out)
                               (global.get $string:list-index-reaches-non-pair))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:list-index))
               (call $growable-array-add! (local.get $out)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $i) (i32.const 1)))))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:list-in))
               (call $growable-array-add! (local.get $out)
                     (call $format/print
                           (local.get $xs)
                           (global.get $missing)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))
         (func $raise-bad-list-ref-index
               (param $xs (ref eq)) (param $i i32) (param $len i32)
               (call $raise-bad-list-ref-index/who
                     (global.get $symbol:list-ref)
                     (local.get $xs)
                     (local.get $i)
                     (local.get $len)))
         (func $raise-bad-list-set-index/who
               (param $who (ref eq))
               (param $xs  (ref eq))
               (param $i   i32)
               (param $len i32)
               (call $raise-bad-list-ref-index/who
                     (local.get $who)
                     (local.get $xs)
                     (local.get $i)
                     (local.get $len)))
         (func $raise-bad-list-set-index
               (param $xs (ref eq)) (param $i i32) (param $len i32)
               (call $raise-bad-list-set-index/who
                     (global.get $symbol:list-set)
                     (local.get $xs)
                     (local.get $i)
                     (local.get $len)))
         (func $raise-list-not-enough-elements/who
               (param $who (ref eq))
               (param $xs  (ref eq))
               (param $n   i32)
               (param $len i32)
               (local $expected     (ref $GrowableArray))
               (local $expected-str (ref $String))
               (local $out          (ref $GrowableArray))
               (local $message      (ref $String))

               (local.set $expected
                          (call $make-growable-array (i32.const 3)))
               (if (ref.eq (call $list? (local.get $xs)) (global.get $true))
                   (then (call $growable-array-add! (local.get $expected)
                               (global.get $string:list-at-least-elements-prefix)))
                   (else (call $growable-array-add! (local.get $expected)
                               (global.get $string:list-at-least-pairs-prefix))))
               (call $growable-array-add! (local.get $expected)
                     (call $format/display
                           (ref.i31 (i32.shl (local.get $n) (i32.const 1)))))
               (if (ref.eq (call $list? (local.get $xs)) (global.get $true))
                   (then (call $growable-array-add! (local.get $expected)
                               (global.get $string:list-at-least-elements-suffix)))
                   (else (call $growable-array-add! (local.get $expected)
                               (global.get $string:list-at-least-pairs-suffix))))
               (local.set $expected-str
                          (call $growable-array-of-strings->string (local.get $expected)))

               (local.set $out
                          (call $make-growable-array (i32.const 5)))
               (call $growable-array-add! (local.get $out)
                     (call $format/display (local.get $who)))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:contract-violation:prefix))
               (call $growable-array-add! (local.get $out)
                     (local.get $expected-str))
               (call $growable-array-add! (local.get $out)
                     (global.get $string:arity-error:given))
               (call $growable-array-add! (local.get $out)
                     (call $format/print
                           (local.get $xs)
                           (global.get $missing)))
               (local.set $message
                          (call $growable-array-of-strings->string (local.get $out)))
               (call $raise
                     (call $exn:fail:contract/make
                           (local.get $message)
                           (call $current-continuation-marks (global.get $missing)))
                     (global.get $true))
               (unreachable))))

;; list-error-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate pair/list error helpers used by the monolithic runtime.
(define list-error-runtime-only-helpers
  (function-forms->runtime-helpers
   'list-error-runtime-only-helpers
   list-error-runtime-only-forms))

;; list-error-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for pair/list error helpers.
(define list-error-runtime-only-helper-names
  (map core-runtime-helper-name list-error-runtime-only-helpers))

;; list-all-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate list helpers originally sourced from the monolithic runtime.
(define list-all-runtime-only-helpers
  (append
   list-error-runtime-only-helpers
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
   list-ordinal-accessor-runtime-only-helpers
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
                  (then (call $raise-argument-error1
                              (global.get $symbol:last)
                              (global.get $string:non-empty-list?)
                              (local.get $xs))
                        (unreachable)))
              (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:last)
                              (global.get $string:non-empty-list?)
                              (local.get $xs))
                        (unreachable)))
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
              (local $orig-i i32)
              (local $next (ref eq))

              (local.set $v (local.get $xs))
              (local.set $k (local.get $i))
              (local.set $orig-i (local.get $i))

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
                         (call $raise-bad-list-ref-index/who
                               (local.get $who)
                               (local.get $xs)
                               (local.get $orig-i)
                               (i32.const 0)))))
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
                   (call $raise-bad-list-ref-index/who
                         (global.get $symbol:list-tail)
                         (local.get $xs)
                         (local.get $idx)
                         (i32.const 0))
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
                  (then (call $raise-list-not-enough-elements/who
                              (local.get $who)
                              (local.get $lst)
                              (local.get $n)
                              (i32.const 0))
                        (unreachable)))
              (if (i32.eqz (ref.test (ref $Pair) (local.get $lst)))
                  (then (call $raise-list-not-enough-elements/who
                              (local.get $who)
                              (local.get $lst)
                              (local.get $n)
                              (i32.const 0))
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
                         (call $raise-list-not-enough-elements/who
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
                  (then (call $raise-list-not-enough-elements/who
                              (local.get $who)
                              (local.get $lst)
                              (local.get $n)
                              (i32.const 0))
                        (unreachable)))
              (if (i32.eqz (ref.test (ref $Pair) (local.get $lst)))
                  (then (call $raise-list-not-enough-elements/who
                              (local.get $who)
                              (local.get $lst)
                              (local.get $n)
                              (i32.const 0))
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
                                     (call $raise-list-not-enough-elements/who
                                           (local.get $who)
                                           (local.get $first)
                                           (local.get $n)
                                           (local.get $len))
                                     (unreachable))
                                    (else (call $raise-list-not-enough-elements/who
                                                (local.get $who)
                                                (local.get $first)
                                                (local.get $n)
                                                (i32.sub (local.get $n)
                                                         (local.get $remaining)))
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

              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error/position
                              (global.get $symbol:dropf)
                              (global.get $string:list-procedure)
                              (i32.const 1)
                              (local.get $proc)
                              (array.new_fixed $Args 2
                                               (local.get $lst)
                                               (local.get $proc)))
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

              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error/position
                              (global.get $symbol:dropf-right)
                              (global.get $string:list-procedure)
                              (i32.const 1)
                              (local.get $proc)
                              (array.new_fixed $Args 2
                                               (local.get $lst)
                                               (local.get $proc)))
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

              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error/position
                              (global.get $symbol:splitf-at)
                              (global.get $string:list-procedure)
                              (i32.const 1)
                              (local.get $proc)
                              (array.new_fixed $Args 2
                                               (local.get $lst)
                                               (local.get $proc)))
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

              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error/position
                              (global.get $symbol:splitf-at-right)
                              (global.get $string:list-procedure)
                              (i32.const 1)
                              (local.get $proc)
                              (array.new_fixed $Args 2
                                               (local.get $lst)
                                               (local.get $proc)))
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

              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:memf)
                              (global.get $string:memf-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 1)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:memf)
                              (global.get $string:memf-procedure)
                              (local.get $proc))
                        (unreachable)))
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

              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:assf)
                              (global.get $string:list-unary-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 1)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:assf)
                              (global.get $string:list-unary-procedure)
                              (local.get $proc))
                        (unreachable)))
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

              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:findf)
                              (global.get $string:list-unary-procedure)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                 (local.get $f)
                                 (i32.const 1)))
                  (then (call $raise-argument-error1
                              (global.get $symbol:findf)
                              (global.get $string:list-unary-procedure)
                              (local.get $proc))
                        (unreachable)))
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
                   (if (ref.eq (call $procedure? (local.get $same?))
                               (global.get $false))
                       (then
                          (call $raise-argument-error1
                                (global.get $symbol:index-of)
                                (global.get $string:list-index-comparator)
                                (local.get $same?))
                          (unreachable)))
                     (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                        (ref.cast (ref $Procedure) (local.get $same?))
                                        (i32.const 2)))
                         (then
                          (call $raise-argument-error1
                                (global.get $symbol:index-of)
                                (global.get $string:list-index-comparator)
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
                (if (ref.eq (call $procedure? (local.get $proc))
                            (global.get $false))
                    (then (call $raise-argument-error1
                                (global.get $symbol:index-where)
                                (global.get $string:list-index-predicate)
                                (local.get $proc))
                          (unreachable)))
                (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
                (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                   (local.get $f)
                                   (i32.const 1)))
                    (then (call $raise-argument-error1
                                (global.get $symbol:index-where)
                                (global.get $string:list-index-predicate)
                                (local.get $proc))
                          (unreachable)))
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
                   (if (ref.eq (call $procedure? (local.get $same?))
                               (global.get $false))
                       (then
                          (call $raise-argument-error1
                                (global.get $symbol:indexes-of)
                                (global.get $string:list-index-comparator)
                                (local.get $same?))
                          (unreachable)))
                     (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                        (ref.cast (ref $Procedure) (local.get $same?))
                                        (i32.const 2)))
                         (then
                          (call $raise-argument-error1
                                (global.get $symbol:indexes-of)
                                (global.get $string:list-index-comparator)
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
                (if (ref.eq (call $procedure? (local.get $proc))
                            (global.get $false))
                    (then (call $raise-argument-error1
                                (global.get $symbol:indexes-where)
                                (global.get $string:list-index-predicate)
                                (local.get $proc))
                          (unreachable)))
                (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
                (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                   (local.get $f)
                                   (i32.const 1)))
                    (then (call $raise-argument-error1
                                (global.get $symbol:indexes-where)
                                (global.get $string:list-index-predicate)
                                (local.get $proc))
                          (unreachable)))
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
                (if (ref.eq (call $procedure? (local.get $proc))
                            (global.get $false))
                    (then (call $raise-argument-error1
                                (global.get $symbol:group-by)
                                (global.get $string:list-index-predicate)
                                (local.get $proc))
                          (unreachable)))
                (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
                (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                   (local.get $f)
                                   (i32.const 1)))
                    (then (call $raise-argument-error1
                                (global.get $symbol:group-by)
                                (global.get $string:list-index-predicate)
                                (local.get $proc))
                          (unreachable)))
                (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; Handle optional comparator
              (if (ref.eq (local.get $same?) (global.get $missing))
                  (then (local.set $use-proc (i32.const 0)))
                  (else
                     (if (ref.eq (call $procedure? (local.get $same?))
                                 (global.get $false))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:group-by)
                                     (global.get $string:list-binary-comparator)
                                     (local.get $same?))
                               (unreachable)))
                     (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                        (ref.cast (ref $Procedure) (local.get $same?))
                                        (i32.const 2)))
                         (then (call $raise-argument-error1
                                     (global.get $symbol:group-by)
                                     (global.get $string:list-binary-comparator)
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
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
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
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
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
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
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
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
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
             (unreachable))))

    ;; filter : procedure? list? -> list?
    ;;   Keep elements for which proc returns a true value.
    (core-runtime-helper
     '$filter
     "$filter"
     (lambda ()
       `(func $filter (type $Prim2)
             (param $proc (ref eq))  ;; predicate
             (param $xs   (ref eq))  ;; list
             (result      (ref eq))

             (local $f    (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))
             (local $cur  (ref eq))
             (local $pair (ref $Pair))
             (local $elem (ref eq))
             (local $call (ref $Args))
             (local $r    (ref eq))
             (local $acc  (ref eq))
             (local $res  (ref eq))

            ;; 1) Check that $proc is a procedure and fetch its invoker
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:filter)
                              (global.get $string:list-unary-procedure)
                              (local.get $proc))
                        (unreachable)))
               (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $f)
                                  (i32.const 1)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:filter)
                               (global.get $string:list-unary-procedure)
                               (local.get $proc))
                         (unreachable)))
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; 2) Prepare argument array for predicate
             (local.set $call (array.new $Args (global.get $null) (i32.const 1)))

             ;; 3) Iterate through list, building reversed accumulator
             (local.set $cur (local.get $xs))
             (local.set $acc (global.get $null))
             (loop $loop
                   (if (ref.eq (local.get $cur) (global.get $null))
                       (then
                        ;; Reverse accumulator and return
                        (local.set $res (global.get $null))
                        (local.set $cur (local.get $acc))
                        (loop $rev
                              (if (ref.eq (local.get $cur) (global.get $null))
                                  (then (return (local.get $res))))
                              (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                              (local.set $res (call $cons
                                                    (struct.get $Pair $a (local.get $pair))
                                                    (local.get $res)))
                              (local.set $cur (struct.get $Pair $d (local.get $pair)))
                              (br $rev))))

                   (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                       (then (call $raise-pair-expected/who
                                   (global.get $symbol:filter)
                                   (local.get $cur))
                             (unreachable)))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                   (array.set $Args (local.get $call) (i32.const 0) (local.get $elem))
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))
                   (if (ref.eq (local.get $r) (global.get $false))
                       (then (nop))
                       (else (local.set $acc (call $cons (local.get $elem) (local.get $acc)))))
                   (local.set $cur (struct.get $Pair $d (local.get $pair)))
                   (br $loop))
             (unreachable))))

    ;; filter-map : procedure? list? ... -> list?
    ;;   Map proc across lists and keep true results.
    (core-runtime-helper
     '$filter-map
     "$filter-map"
     (lambda ()
       `(func $filter-map (type $Prim>=2)
             (param $proc (ref eq))   ;; procedure
             (param $xs0  (ref eq))   ;; first list
             (param $rest (ref eq))   ;; rest lists
             (result      (ref eq))

              (local $f      (ref $Procedure))
              (local $finv   (ref $ProcedureInvoker))
              (local $outer  (ref eq))
              (local $pair   (ref $Pair))
              (local $elem   (ref eq))
              (local $nlists i32)

              (local $lists  (ref $Args))  ;; cursors for each list
              (local $call   (ref $Args))  ;; args for f (length = nlists)
              (local $i      i32)
              (local $cur    (ref eq))
              (local $stop   i32)

              (local $acc    (ref eq))     ;; reversed accumulator
              (local $res    (ref eq))     ;; final result
              (local $r      (ref eq))

              ;; 1) Check that $proc is a procedure and fetch its invoker
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error:procedure-expected/who
                              (global.get $symbol:filter-map)
                              (local.get $proc))
                        (unreachable)))
              (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
              (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; 2) Ensure $xs0 is a list head; walk $rest to count #lists and validate each head
              (if (i32.eqz
                   (i32.or
                    (ref.eq (local.get $xs0) (global.get $null))
                    (ref.test (ref $Pair) (local.get $xs0))))
                  (then (call $raise-pair-expected/who
                              (global.get $symbol:filter-map)
                              (local.get $xs0))
                        (unreachable)))
              (local.set $nlists (i32.const 1))
              (local.set $outer  (local.get $rest))
              (block $count_done
                     (loop $count
                           (if (ref.eq (local.get $outer) (global.get $null))
                               (then (br $count_done)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $outer)))
                               (then (call $raise-pair-expected/who
                                           (global.get $symbol:filter-map)
                                           (local.get $outer))
                                     (unreachable)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $outer)))
                           (local.set $elem (struct.get $Pair $a (local.get $pair)))
                           (if (i32.eqz
                                (i32.or
                                 (ref.eq (local.get $elem) (global.get $null))
                                 (ref.test (ref $Pair) (local.get $elem))))
                               (then (call $raise-pair-expected/who
                                           (global.get $symbol:filter-map)
                                           (local.get $elem))
                                     (unreachable)))
                           (local.set $nlists (i32.add (local.get $nlists) (i32.const 1)))
                           (local.set $outer (struct.get $Pair $d (local.get $pair)))
                           (br $count)))

              ;; 3) Allocate arrays for list cursors and call arguments; seed list cursors
              (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
              (local.set $call  (array.new $Args (global.get $null) (local.get $nlists)))

              (array.set $Args (local.get $lists) (i32.const 0) (local.get $xs0))
              (local.set $outer (local.get $rest))
              (local.set $i (i32.const 1))
              (block $seed_done
                     (loop $seed
                           (if (i32.ge_u (local.get $i) (local.get $nlists))
                               (then (br $seed_done)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $outer)))
                           (local.set $elem (struct.get $Pair $a (local.get $pair)))
                           (array.set $Args (local.get $lists) (local.get $i) (local.get $elem))
                           (local.set $outer (struct.get $Pair $d (local.get $pair)))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $seed)))

              ;; 4) Main loop: stop at the shortest list
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
                                                      (global.get $symbol:filter-map)
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

                    ;; (d) cons the result onto the accumulator if non-#f
                    (if (ref.eq (local.get $r) (global.get $false))
                        (then (nop))
                        (else (local.set $acc (call $cons (local.get $r) (local.get $acc)))))

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

    ;; filter-not : procedure? list? -> list?
    ;;   Keep elements for which proc returns #f.
    (core-runtime-helper
     '$filter-not
     "$filter-not"
     (lambda ()
       `(func $filter-not (type $Prim2)
             (param $proc (ref eq))  ;; predicate
             (param $xs   (ref eq))  ;; list
             (result      (ref eq))

             (local $f    (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))
             (local $cur  (ref eq))
             (local $pair (ref $Pair))
             (local $elem (ref eq))
             (local $call (ref $Args))
             (local $r    (ref eq))
             (local $acc  (ref eq))
             (local $res  (ref eq))

            ;; 1) Check that $proc is a procedure and fetch its invoker
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error1
                              (global.get $symbol:filter-not)
                              (global.get $string:list-unary-procedure)
                              (local.get $proc))
                        (unreachable)))
               (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $f)
                                  (i32.const 1)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:filter-not)
                               (global.get $string:list-unary-procedure)
                               (local.get $proc))
                         (unreachable)))
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; 2) Prepare argument array for predicate
             (local.set $call (array.new $Args (global.get $null) (i32.const 1)))

             ;; 3) Iterate through list, building reversed accumulator
             (local.set $cur (local.get $xs))
             (local.set $acc (global.get $null))
             (loop $loop
                   (if (ref.eq (local.get $cur) (global.get $null))
                       (then
                        ;; Reverse accumulator and return
                        (local.set $res (global.get $null))
                        (local.set $cur (local.get $acc))
                        (loop $rev
                              (if (ref.eq (local.get $cur) (global.get $null))
                                  (then (return (local.get $res))))
                              (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                              (local.set $res (call $cons
                                                    (struct.get $Pair $a (local.get $pair))
                                                    (local.get $res)))
                              (local.set $cur (struct.get $Pair $d (local.get $pair)))
                              (br $rev))))

                   (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                       (then (call $raise-pair-expected/who
                                   (global.get $symbol:filter-not)
                                   (local.get $cur))
                             (unreachable)))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                   (array.set $Args (local.get $call) (i32.const 0) (local.get $elem))
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))
                   (if (ref.eq (local.get $r) (global.get $false))
                       (then (local.set $acc (call $cons (local.get $elem) (local.get $acc)))))
                   (local.set $cur (struct.get $Pair $d (local.get $pair)))
                   (br $loop))
             (unreachable))))

    ;; partition : procedure? list? -> values?
    ;;   Split elements into true and false predicate partitions.
    (core-runtime-helper
     '$partition
     "$partition"
     (lambda ()
       `(func $partition (type $Prim2)
             (param $proc (ref eq))  ;; predicate
             (param $xs   (ref eq))  ;; list
             (result      (ref eq))

              (local $f    (ref $Procedure))
              (local $finv (ref $ProcedureInvoker))
              (local $cur  (ref eq))
              (local $pair (ref $Pair))
              (local $elem (ref eq))
              (local $call (ref $Args))
              (local $r    (ref eq))
              (local $acc-t (ref eq))
              (local $acc-f (ref eq))

              ;; 1) Check that $proc is a procedure and fetch its invoker
                (if (ref.eq (call $procedure? (local.get $proc))
                            (global.get $false))
                    (then (call $raise-argument-error1
                                (global.get $symbol:partition)
                                (global.get $string:list-unary-procedure)
                                (local.get $proc))
                          (unreachable)))
                (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
                (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                   (local.get $f)
                                   (i32.const 1)))
                    (then (call $raise-argument-error1
                                (global.get $symbol:partition)
                                (global.get $string:list-unary-procedure)
                                (local.get $proc))
                          (unreachable)))
                (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

              ;; 2) Prepare argument array for predicate
              (local.set $call (array.new $Args (global.get $null) (i32.const 1)))

              ;; 3) Iterate through list, building two reversed accumulators
              (local.set $cur  (local.get $xs))
              (local.set $acc-t (global.get $null))
              (local.set $acc-f (global.get $null))
              (loop $loop
                    (if (ref.eq (local.get $cur) (global.get $null))
                        (then (return (array.new_fixed $Values 2
                                                        (call $reverse (local.get $acc-t))
                                                        (call $reverse (local.get $acc-f))))))

                    (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                        (then (call $raise-pair-expected/who
                                    (global.get $symbol:partition)
                                    (local.get $cur))
                              (unreachable)))
                    (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                    (local.set $elem (struct.get $Pair $a (local.get $pair)))
                    (array.set $Args (local.get $call) (i32.const 0) (local.get $elem))
                    (local.set $r
                               (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $call)
                                         (local.get $finv)))
                    (if (ref.eq (local.get $r) (global.get $false))
                        (then (local.set $acc-f (call $cons (local.get $elem) (local.get $acc-f))))
                        (else (local.set $acc-t (call $cons (local.get $elem) (local.get $acc-t)))))
                    (local.set $cur (struct.get $Pair $d (local.get $pair)))
                    (br $loop))
              (unreachable))))

    ;; remove : any/c list? [procedure?] -> list?
    ;;   Remove the first element matching a value comparator.
    (core-runtime-helper
     '$remove
     "$remove"
     (lambda ()
       `(func $remove (type $Prim23)
             (param $v    (ref eq))   ;; value to remove
             (param $lst  (ref eq))   ;; list
             (param $proc (ref eq))   ;; optional comparator
             (result      (ref eq))

             (local $cur      (ref eq))
             (local $pair     (ref $Pair))
             (local $elem     (ref eq))
             (local $acc      (ref eq))
             (local $res      (ref eq))
             (local $r        (ref eq))
             (local $tail     (ref eq))
             (local $args     (ref $Args))
             (local $f        (ref $Procedure))
             (local $finv     (ref $ProcedureInvoker))

             ;; 1) Handle optional comparator.
             (if (ref.eq (local.get $proc) (global.get $missing))
                 (then (local.set $proc (global.get $prim:equal?)))
                 (else
                  ;; Type check $proc
                    (if (ref.eq (call $procedure? (local.get $proc))
                                (global.get $false))
                        (then
                         (call $raise-argument-error1
                               (global.get $symbol:remove)
                               (global.get $string:list-binary-comparator)
                               (local.get $proc))
                         (unreachable))
                        (else))))
               (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $f)
                                  (i32.const 2)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:remove)
                               (global.get $string:list-binary-comparator)
                               (local.get $proc))
                         (unreachable)))
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
             (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
             (array.set $Args (local.get $args) (i32.const 0) (local.get $v))

             ;; 2) Iterate through list until match found
             (local.set $cur  (local.get $lst))
             (local.set $acc  (global.get $null))
             (loop $loop
                   (if (ref.eq (local.get $cur) (global.get $null))
                       (then (return (local.get $lst)))
                       (else))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                       (then
                        (call $raise-pair-expected/who
                              (global.get $symbol:remove)
                              (local.get $cur))
                        (unreachable))
                       (else))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                   (local.set $tail (struct.get $Pair $d (local.get $pair)))

                   (block $found
                          ;; args := [v, elem]
                          (array.set $Args (local.get $args) (i32.const 1) (local.get $elem))
                          (local.set $r
                                     (call_ref $ProcedureInvoker
                                               (local.get $f)
                                               (local.get $args)
                                               (local.get $finv)))
                          (if (ref.eq (local.get $r) (global.get $false))
                              (then
                               (local.set $acc
                                          (call $cons (local.get $elem) (local.get $acc)))
                               (local.set $cur (local.get $tail))
                               (br $loop))
                              (else (br $found))))

                   ;; found match, fallthrough: rebuild with accumulator
                   (local.set $cur (local.get $tail))
                   (local.set $res (local.get $cur))
                   (local.set $cur (local.get $acc))
                   (loop $rev
                         (if (ref.eq (local.get $cur) (global.get $null))
                             (then (return (local.get $res)))
                             (else))
                         (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                         (local.set $res
                                    (call $cons (struct.get $Pair $a (local.get $pair)) (local.get $res)))
                         (local.set $cur (struct.get $Pair $d (local.get $pair)))
                         (br $rev)))
             (unreachable))))

    ;; remf : procedure? list? -> list?
    ;;   Remove the first element satisfying a predicate.
    (core-runtime-helper
     '$remf
     "$remf"
     (lambda ()
       `(func $remf (type $Prim2)    ;; removes first element that satisfies predicate
             (param $proc (ref eq)) ;; predicate
             (param $lst  (ref eq)) ;; list
             (result      (ref eq))

             (return_call $remf/impl
                          (global.get $symbol:remf)
                          (local.get $proc)
                          (local.get $lst)
                          (i32.const 0)))))

    ;; remf* : procedure? list? -> list?
    ;;   Remove all elements satisfying a predicate.
    (core-runtime-helper
     '$remf*
     "$remf*"
     (lambda ()
       `(func $remf* (type $Prim2)   ;; removes first element that satisfies predicate
             (param $proc (ref eq)) ;; predicate
             (param $lst  (ref eq)) ;; list
             (result      (ref eq))

             (return_call $remf/impl
                          (global.get $symbol:remf*)
                          (local.get $proc)
                          (local.get $lst)
                          (i32.const 1)))))

    ;; remf/impl : symbol? procedure? list? i32 -> list?
    ;;   Shared predicate-removal implementation.
    (core-runtime-helper
     '$remf/impl
     "$remf/impl"
     (lambda ()
       `(func $remf/impl
             (param $who  (ref eq))
             (param $proc (ref eq)) ;; predicate
             (param $lst  (ref eq)) ;; list
             (param $all  i32)      ;; non-zero => remove all matches
             (result      (ref eq))

             (local $f     (ref $Procedure))
             (local $finv  (ref $ProcedureInvoker))
             (local $cur   (ref eq))
             (local $pair  (ref $Pair))
             (local $elem  (ref eq))
             (local $tail  (ref eq))
             (local $acc   (ref eq))
             (local $res   (ref eq))
             (local $args  (ref $Args))
             (local $r     (ref eq))
             (local $found i32)

            ;; Ensure proc is a procedure
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
                  (then (call $raise-argument-error1
                              (local.get $who)
                              (global.get $string:list-index-predicate)
                              (local.get $proc))
                        (unreachable)))
               (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (local.get $f)
                                  (i32.const 1)))
                   (then (call $raise-argument-error1
                               (local.get $who)
                               (global.get $string:list-index-predicate)
                               (local.get $proc))
                         (unreachable)))
               (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
             (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

             ;; Iterate through list
             (local.set $cur (local.get $lst))
             (local.set $acc (global.get $null))
             (local.set $found (i32.const 0))
             (block $done
                    (loop $loop
                          (if (ref.eq (local.get $cur) (global.get $null))
                              (then (br $done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                              (then (call $raise-pair-expected/who
                                          (local.get $who)
                                          (local.get $cur))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                          (local.set $elem (struct.get $Pair $a (local.get $pair)))
                          (local.set $tail (struct.get $Pair $d (local.get $pair)))
                          (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                          (local.set $r
                                     (call_ref $ProcedureInvoker
                                               (local.get $f)
                                               (local.get $args)
                                               (local.get $finv)))
                          (if (ref.eq (local.get $r) (global.get $false))
                              (then
                               (local.set $acc (call $cons (local.get $elem) (local.get $acc)))
                               (local.set $cur (local.get $tail))
                               (br $loop))
                              (else
                               (local.set $found (i32.const 1))
                               (local.set $cur (local.get $tail))
                               (if (i32.eqz (local.get $all))
                                   (then (br $done))
                                   (else (br $loop)))))))
             (if (i32.eqz (local.get $found))
                 (then (return (local.get $lst))))
             (local.set $res (local.get $cur))
             (local.set $cur (local.get $acc))
             (loop $rev
                   (if (ref.eq (local.get $cur) (global.get $null))
                       (then (return (local.get $res))))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $res (call $cons (struct.get $Pair $a (local.get $pair))
                                         (local.get $res)))
                   (local.set $cur (struct.get $Pair $d (local.get $pair)))
                   (br $rev))
             (unreachable))))

    ;; remove* : list? list? [procedure?] -> list?
    ;;   Remove all occurrences of each value in a value list.
    (core-runtime-helper
     '$remove*
     "$remove*"
     (lambda ()
       `(func $remove* (type $Prim23)
             (param $v-lst (ref eq))   ;; list of values
             (param $lst   (ref eq))   ;; list
             (param $proc  (ref eq))   ;; optional comparator, defaults to equal?
             (result       (ref eq))

             ;; Handle optional comparator
             (if (ref.eq (local.get $proc) (global.get $missing))
                 (then (local.set $proc (global.get $prim:equal?)))
                 (else
                    (if (ref.eq (call $procedure? (local.get $proc))
                                (global.get $false))
                        (then (call $raise-argument-error1
                                    (global.get $symbol:remove*)
                                    (global.get $string:list-binary-comparator)
                                    (local.get $proc))
                              (unreachable)))))
               (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                  (ref.cast (ref $Procedure) (local.get $proc))
                                  (i32.const 2)))
                   (then (call $raise-argument-error1
                               (global.get $symbol:remove*)
                               (global.get $string:list-binary-comparator)
                               (local.get $proc))
                         (unreachable)))

               ;; If v-lst is empty, return original list
             (if (ref.eq (local.get $v-lst) (global.get $null))
                 (then (return (local.get $lst))))

             (return_call $remove*/checked
                          (local.get $v-lst)
                          (local.get $lst)
                          (local.get $proc)))))

    ;; remove*/checked : list? list? procedure? -> list?
    ;;   Remove each checked value from a list in sequence.
    (core-runtime-helper
     '$remove*/checked
     "$remove*/checked"
     (lambda ()
       `(func $remove*/checked
             (param $v-lst (ref eq))
             (param $lst   (ref eq))
             (param $proc  (ref eq))
             (result       (ref eq))

             (local $vlcur  (ref eq))
             (local $vlpair (ref $Pair))
             (local $v      (ref eq))
             (local $res    (ref eq))

             (local.set $vlcur (local.get $v-lst))
             (local.set $res   (local.get $lst))
             (loop $loop
                   (if (ref.eq (local.get $vlcur) (global.get $null))
                       (then (return (local.get $res))))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $vlcur)))
                       (then (call $raise-pair-expected/who
                                   (global.get $symbol:remove*)
                                   (local.get $vlcur))
                             (unreachable)))
                   (local.set $vlpair (ref.cast (ref $Pair) (local.get $vlcur)))
                   (local.set $v      (struct.get $Pair $a (local.get $vlpair)))
                   (local.set $vlcur  (struct.get $Pair $d (local.get $vlpair)))
                   (local.set $res (call $remove*/checked/1
                                         (local.get $v)
                                         (local.get $res)
                                         (local.get $proc)))
                   (br $loop))
             (unreachable))))

    ;; remove*/checked/1 : any/c list? procedure? -> list?
    ;;   Remove all occurrences of one checked value.
    (core-runtime-helper
     '$remove*/checked/1
     "$remove*/checked/1"
     (lambda ()
       `(func $remove*/checked/1
             (param $v    (ref eq))
             (param $lst  (ref eq))
             (param $proc (ref eq))
             (result      (ref eq))

             (local $cur      (ref eq))
             (local $pair     (ref $Pair))
             (local $elem     (ref eq))
             (local $acc      (ref eq))
             (local $res      (ref eq))
             (local $tail     (ref eq))
             (local $args     (ref $Args))
             (local $r        (ref eq))
             (local $f        (ref $Procedure))
             (local $finv     (ref $ProcedureInvoker))
             (local $modified i32)

             ;; Prepare comparator call
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
             (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
             (array.set $Args (local.get $args) (i32.const 0) (local.get $v))

             (local.set $cur      (local.get $lst))
             (local.set $acc      (global.get $null))
             (local.set $modified (i32.const 0))

             (block $done
                    (loop $loop
                          (if (ref.eq (local.get $cur) (global.get $null))
                              (then (br $done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                              (then (call $raise-pair-expected/who
                                          (global.get $symbol:remove*)
                                          (local.get $cur))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                          (local.set $elem (struct.get $Pair $a (local.get $pair)))
                          (local.set $tail (struct.get $Pair $d (local.get $pair)))
                          (array.set $Args (local.get $args) (i32.const 1) (local.get $elem))
                          (local.set $r
                                     (call_ref $ProcedureInvoker
                                               (local.get $f)
                                               (local.get $args)
                                               (local.get $finv)))
                          (if (ref.eq (local.get $r) (global.get $false))
                              (then (local.set $acc (call $cons (local.get $elem) (local.get $acc))))
                              (else (local.set $modified (i32.const 1))))
                          (local.set $cur (local.get $tail))
                          (br $loop)))

             (if (i32.eqz (local.get $modified))
                 (then (return (local.get $lst))))

             ;; Rebuild reversed accumulator
             (local.set $cur (local.get $acc))
             (local.set $res (global.get $null))
             (loop $rev
                   (if (ref.eq (local.get $cur) (global.get $null))
                       (then (return (local.get $res))))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $res (call $cons (struct.get $Pair $a (local.get $pair))
                                         (local.get $res)))
                   (local.set $cur (struct.get $Pair $d (local.get $pair)))
                   (br $rev))
             (unreachable))))

    ;; remq : any/c list? -> list?
    ;;   Remove the first eq?-matching element.
    (remove-alias-runtime-helper
     '$remq '$remove '$v '$prim:eq?)

    ;; remv : any/c list? -> list?
    ;;   Remove the first eqv?-matching element.
    (remove-alias-runtime-helper
     '$remv '$remove '$v '$prim:eqv?)

    ;; remw : any/c list? -> list?
    ;;   Remove the first equal-always?-matching element.
    (remove-alias-runtime-helper
     '$remw '$remove '$v '$prim:equal-always?)

    ;; remq* : list? list? -> list?
    ;;   Remove all eq?-matching elements in a value list.
    (remove-alias-runtime-helper
     '$remq* '$remove* '$v-lst '$prim:eq?)

    ;; remv* : list? list? -> list?
    ;;   Remove all eqv?-matching elements in a value list.
    (remove-alias-runtime-helper
     '$remv* '$remove* '$v-lst '$prim:eqv?)

    ;; remw* : list? list? -> list?
    ;;   Remove all equal-always?-matching elements in a value list.
    (remove-alias-runtime-helper
     '$remw* '$remove* '$v-lst '$prim:equal-always?)

    ; Note: Simplified version of sort. Internally it uses a merge sort.
    ;       The keyword-expanded path supports #:key for module-language
    ;       programs. When #:cache-keys? is true, each key is computed once
    ;       before sorting, matching Racket's visible key-effect behavior.
    ;; sort : list? procedure? -> list?
    ;;   Sort a list using the supplied less-than procedure.
    (core-runtime-helper
     '$sort
     "$sort"
     (lambda ()
       `(func $sort (type $Prim2)
             (param $xs   (ref eq))
             (param $proc (ref eq))
             (result      (ref eq))

             (local $f    (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))
             (local $call (ref $Args))

             (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:sort)
                             (global.get $string:list?)
                             (local.get $xs))
                       (unreachable)))
            (if (ref.eq (call $procedure? (local.get $proc))
                        (global.get $false))
                (then (call $raise-argument-error1
                            (global.get $symbol:sort)
                            (global.get $string:list-binary-comparator)
                            (local.get $proc))
                      (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                (local.get $f)
                                (i32.const 2)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:sort)
                             (global.get $string:list-binary-comparator)
                             (local.get $proc))
                       (unreachable)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
             (local.set $call (array.new $Args (global.get $null) (i32.const 2)))

             (return_call $sort:merge-sort
                          (local.get $xs)
                          (local.get $f)
                          (local.get $finv)
                          (local.get $call)))))

    ;; sort/expanded-keywords : list? procedure? any/c any/c any/c any/c -> list?
    ;;   Sort with expanded #:key and #:cache-keys? keyword arguments.
    (core-runtime-helper
     '$sort/expanded-keywords
     "$sort/expanded-keywords"
     (lambda ()
       `(func $sort/expanded-keywords (type $Prim6)
             (param $xs          (ref eq)) ; list to sort
             (param $proc        (ref eq)) ; less-than? procedure
             (param $kw-key      (ref eq)) ; expanded #:key marker
             (param $key-proc    (ref eq)) ; key procedure or #f
             (param $kw-cache    (ref eq)) ; expanded #:cache-keys? marker
             (param $cache-keys? (ref eq)) ; accepted for compatibility
             (result             (ref eq))

             (local $f          (ref $Procedure))
             (local $finv       (ref $ProcedureInvoker))
             (local $key-f      (ref $Procedure))
             (local $key-finv   (ref $ProcedureInvoker))
             (local $less-call  (ref $Args))
             (local $key-call   (ref $Args))

             (if (ref.eq (local.get $key-proc) (global.get $false))
                 (then (return_call $sort (local.get $xs) (local.get $proc))))
             (if (ref.eq (call $list? (local.get $xs)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:sort)
                             (global.get $string:list?)
                             (local.get $xs))
                       (unreachable)))
            (if (ref.eq (call $procedure? (local.get $proc))
                        (global.get $false))
                (then (call $raise-argument-error1
                            (global.get $symbol:sort)
                            (global.get $string:list-binary-comparator)
                            (local.get $proc))
                      (unreachable)))
            (if (ref.eq (call $procedure? (local.get $key-proc))
                        (global.get $false))
                (then (call $raise-argument-error1
                            (global.get $symbol:sort)
                            (global.get $string:list-unary-procedure)
                            (local.get $key-proc))
                      (unreachable)))
             (local.set $f        (ref.cast (ref $Procedure) (local.get $proc)))
             (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                (local.get $f)
                                (i32.const 2)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:sort)
                             (global.get $string:list-binary-comparator)
                             (local.get $proc))
                       (unreachable)))
             (local.set $finv     (struct.get $Procedure $invoke (local.get $f)))
             (local.set $key-f    (ref.cast (ref $Procedure) (local.get $key-proc)))
             (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                (local.get $key-f)
                                (i32.const 1)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:sort)
                             (global.get $string:list-unary-procedure)
                             (local.get $key-proc))
                       (unreachable)))
             (local.set $key-finv (struct.get $Procedure $invoke (local.get $key-f)))
             (local.set $less-call (array.new $Args (global.get $null) (i32.const 2)))
             (local.set $key-call  (array.new $Args (global.get $null) (i32.const 1)))

             (if (result (ref eq))
                 (ref.eq (local.get $cache-keys?) (global.get $false))
                 (then
                  (call $sort:merge-sort/key
                        (local.get $xs)
                        (local.get $f)
                        (local.get $finv)
                        (local.get $key-f)
                        (local.get $key-finv)
                        (local.get $less-call)
                        (local.get $key-call)))
                 (else
                  (call $sort:extract-cached-values
                        (call $sort:merge-sort/cached-key
                              (call $sort:cache-key-pairs
                                    (local.get $xs)
                                    (local.get $key-f)
                                    (local.get $key-finv)
                                    (local.get $key-call))
                              (local.get $f)
                              (local.get $finv)
                              (local.get $less-call))))))))

    ;; sort/keyword-apply : list? procedure? list? list? -> list?
    ;;   Dispatch keyword-applied sort arguments to the expanded sort path.
    (core-runtime-helper
     '$sort/keyword-apply
     "$sort/keyword-apply"
     (lambda ()
       `(func $sort/keyword-apply (type $Prim4)
             (param $kws      (ref eq)) ; sorted keyword list from keyword-procedure-extract
             (param $kw-args  (ref eq)) ; parallel keyword value list
             (param $xs       (ref eq)) ; list to sort
             (param $proc     (ref eq)) ; less-than? procedure
             (result          (ref eq))

             (local $kw-cell      (ref $Pair))
             (local $kw-rest      (ref eq))
             (local $arg-cell     (ref $Pair))
             (local $arg-rest     (ref eq))
             (local $key-proc     (ref eq))
             (local $cache-keys?  (ref eq))

             ;; Racket's keyword-procedure extraction passes sorted keywords,
             ;; but either #:key or #:cache-keys? can appear alone.
             (local.set $key-proc    (global.get $false))
             (local.set $cache-keys? (global.get $false))
             (local.set $kw-rest (local.get $kws))
             (local.set $arg-rest (local.get $kw-args))
             (block $done
               (loop $loop
                 (if (i32.eqz (ref.test (ref $Pair) (local.get $kw-rest)))
                     (then (br $done)))
                 (local.set $kw-cell (ref.cast (ref $Pair) (local.get $kw-rest)))
                 (local.set $arg-cell (ref.cast (ref $Pair) (local.get $arg-rest)))
                 (if (ref.eq
                      (struct.get $Pair $a (local.get $kw-cell))
                      (call
                       $string->keyword/checked
                       (ref.cast (ref $String) (global.get $string:keyword:key))))
                     (then
                      (local.set $key-proc (struct.get $Pair $a (local.get $arg-cell)))))
                 (if (ref.eq
                      (struct.get $Pair $a (local.get $kw-cell))
                      (call
                       $string->keyword/checked
                       (ref.cast (ref $String) (global.get $string:keyword:cache-keys?))))
                     (then
                      (local.set $cache-keys? (struct.get $Pair $a (local.get $arg-cell)))))
                 (local.set $kw-rest (struct.get $Pair $d (local.get $kw-cell)))
                 (local.set $arg-rest (struct.get $Pair $d (local.get $arg-cell)))
                 (br $loop)))
             (if (ref.test (ref $Pair) (local.get $kw-args))
                 (then
                  (local.set $arg-cell (ref.cast (ref $Pair) (local.get $kw-args)))
                  (if (ref.eq (struct.get $Pair $d (local.get $arg-cell))
                              (global.get $null))
                      (then
                       (local.set $key-proc
                                  (struct.get $Pair $a (local.get $arg-cell)))))))
             (return_call $sort/expanded-keywords
                          (local.get $xs)
                          (local.get $proc)
                          (global.get $missing)
                          (local.get $key-proc)
                          (global.get $missing)
                          (local.get $cache-keys?)))))

    ;; sort:merge : list? list? procedure? any/c any/c -> list?
    ;;   Merge two sorted lists with the supplied comparator.
    (core-runtime-helper
     '$sort:merge
     "$sort:merge"
     (lambda ()
       `(func $sort:merge
             (param $a    (ref eq))
             (param $b    (ref eq))
             (param $f    (ref $Procedure))
             (param $finv (ref $ProcedureInvoker))
             (param $call (ref $Args))
             (result      (ref eq))

             (local $apair (ref $Pair))
             (local $bpair (ref $Pair))
             (local $x     (ref eq))
             (local $y     (ref eq))
             (local $r     (ref eq))

             (if (ref.eq (local.get $a) (global.get $null))
                 (then (return (local.get $b))))
             (if (ref.eq (local.get $b) (global.get $null))
                 (then (return (local.get $a))))

             (if (i32.eqz (ref.test (ref $Pair) (local.get $a)))
                 (then (call $raise-pair-expected (local.get $a))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $b)))
                 (then (call $raise-pair-expected (local.get $b))
                       (unreachable)))

             (local.set $apair (ref.cast (ref $Pair) (local.get $a)))
             (local.set $bpair (ref.cast (ref $Pair) (local.get $b)))
             (local.set $x     (struct.get $Pair $a (local.get $apair)))
             (local.set $y     (struct.get $Pair $a (local.get $bpair)))

             (array.set $Args  (local.get $call) (i32.const 0) (local.get $y))
             (array.set $Args  (local.get $call) (i32.const 1) (local.get $x))
             (local.set $r     (call_ref $ProcedureInvoker
                                         (local.get $f)
                                         (local.get $call)
                                         (local.get $finv)))
             (if (result (ref eq))
                 (ref.eq (local.get $r) (global.get $false))
                 (then (call $cons (local.get $x)
                             (call $sort:merge
                                   (struct.get $Pair $d (local.get $apair))
                                   (local.get $b)
                                   (local.get $f)
                                   (local.get $finv)
                                   (local.get $call))))
                 (else (call $cons (local.get $y)
                             (call $sort:merge
                                   (local.get $a)
                                   (struct.get $Pair $d (local.get $bpair))
                                   (local.get $f)
                                   (local.get $finv)
                                   (local.get $call))))))))

    ;; sort:merge/key : list? list? procedure? any/c procedure? any/c any/c any/c -> list?
    ;;   Merge two sorted lists while computing keys on demand.
    (core-runtime-helper
     '$sort:merge/key
     "$sort:merge/key"
     (lambda ()
       `(func $sort:merge/key
             (param $a         (ref eq))
             (param $b         (ref eq))
             (param $f         (ref $Procedure))
             (param $finv      (ref $ProcedureInvoker))
             (param $key-f     (ref $Procedure))
             (param $key-finv  (ref $ProcedureInvoker))
             (param $less-call (ref $Args))
             (param $key-call  (ref $Args))
             (result           (ref eq))

             (local $apair (ref $Pair))
             (local $bpair (ref $Pair))
             (local $x     (ref eq))
             (local $y     (ref eq))
             (local $kx    (ref eq))
             (local $ky    (ref eq))
             (local $r     (ref eq))

             (if (ref.eq (local.get $a) (global.get $null))
                 (then (return (local.get $b))))
             (if (ref.eq (local.get $b) (global.get $null))
                 (then (return (local.get $a))))

             (if (i32.eqz (ref.test (ref $Pair) (local.get $a)))
                 (then (call $raise-pair-expected (local.get $a))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $b)))
                 (then (call $raise-pair-expected (local.get $b))
                       (unreachable)))

             (local.set $apair (ref.cast (ref $Pair) (local.get $a)))
             (local.set $bpair (ref.cast (ref $Pair) (local.get $b)))
             (local.set $x     (struct.get $Pair $a (local.get $apair)))
             (local.set $y     (struct.get $Pair $a (local.get $bpair)))

             (array.set $Args (local.get $key-call) (i32.const 0) (local.get $y))
             (local.set $ky (call_ref $ProcedureInvoker
                                       (local.get $key-f)
                                       (local.get $key-call)
                                       (local.get $key-finv)))
             (array.set $Args (local.get $key-call) (i32.const 0) (local.get $x))
             (local.set $kx (call_ref $ProcedureInvoker
                                       (local.get $key-f)
                                       (local.get $key-call)
                                       (local.get $key-finv)))
             (array.set $Args (local.get $less-call) (i32.const 0) (local.get $ky))
             (array.set $Args (local.get $less-call) (i32.const 1) (local.get $kx))
             (local.set $r (call_ref $ProcedureInvoker
                                     (local.get $f)
                                     (local.get $less-call)
                                     (local.get $finv)))
             (if (result (ref eq))
                 (ref.eq (local.get $r) (global.get $false))
                 (then (call $cons (local.get $x)
                             (call $sort:merge/key
                                   (struct.get $Pair $d (local.get $apair))
                                   (local.get $b)
                                   (local.get $f)
                                   (local.get $finv)
                                   (local.get $key-f)
                                   (local.get $key-finv)
                                   (local.get $less-call)
                                   (local.get $key-call))))
                 (else (call $cons (local.get $y)
                             (call $sort:merge/key
                                   (local.get $a)
                                   (struct.get $Pair $d (local.get $bpair))
                                   (local.get $f)
                                   (local.get $finv)
                                   (local.get $key-f)
                                   (local.get $key-finv)
                                   (local.get $less-call)
                                   (local.get $key-call))))))))

    ;; sort:split : list? -> values?
    ;;   Split a list into two halves for merge sort.
    (core-runtime-helper
     '$sort:split
     "$sort:split"
     (lambda ()
       `(func $sort:split (param $lst (ref eq))
             (result (ref $Values))

             (local $slow (ref eq))
             (local $fast (ref eq))
             (local $acc  (ref eq))
             (local $pair (ref $Pair))
             (local $fastcdr (ref eq))
             (local $slowpair (ref $Pair))

             (local.set $slow (local.get $lst))
             (local.set $fast (local.get $lst))
             (local.set $acc  (global.get $null))

             (block $done
                    (loop $loop
                          (if (ref.eq (local.get $fast) (global.get $null))
                              (then (br $done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $fast)))
                              (then (call $raise-pair-expected (local.get $fast))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $fast)))
                          (local.set $fastcdr (struct.get $Pair $d (local.get $pair)))
                          (if (ref.eq (local.get $fastcdr) (global.get $null))
                              (then (br $done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $slow)))
                              (then (call $raise-pair-expected (local.get $slow))
                                    (unreachable)))
                          (local.set $slowpair (ref.cast (ref $Pair) (local.get $slow)))
                          (local.set $acc (call $cons (struct.get $Pair $a (local.get $slowpair))
                                                (local.get $acc)))
                          (local.set $slow (struct.get $Pair $d (local.get $slowpair)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $fastcdr)))
                              (then (call $raise-pair-expected (local.get $fastcdr))
                                    (unreachable)))
                          (local.set $fast (struct.get $Pair $d (ref.cast (ref $Pair) (local.get $fastcdr))))
                          (br $loop)))
             (array.new_fixed $Values 2 (call $reverse (local.get $acc)) (local.get $slow)))))

    ;; sort:merge-sort : list? procedure? any/c any/c -> list?
    ;;   Sort a list using merge sort and the supplied comparator.
    (core-runtime-helper
     '$sort:merge-sort
     "$sort:merge-sort"
     (lambda ()
       `(func $sort:merge-sort
             (param $lst  (ref eq))
             (param $f    (ref $Procedure))
             (param $finv (ref $ProcedureInvoker))
             (param $call (ref $Args))

             (result      (ref eq))

             (local $pair (ref $Pair))
             (local $rest (ref eq))
             (local $vals (ref $Values))
             (local $a    (ref eq))
             (local $b    (ref eq))
             (local $sa   (ref eq))
             (local $sb   (ref eq))

             (if (ref.eq (local.get $lst) (global.get $null))
                 (then (return (local.get $lst))))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $lst)))
                 (then (call $raise-pair-expected (local.get $lst))
                       (unreachable)))
             (local.set $pair (ref.cast (ref $Pair) (local.get $lst)))
             (local.set $rest (struct.get $Pair $d (local.get $pair)))
             (if (ref.eq (local.get $rest) (global.get $null))
                 (then (return (local.get $lst))))

             (local.set $vals  (call $sort:split (local.get $lst)))
             (local.set $a     (array.get $Values (local.get $vals) (i32.const 0)))
             (local.set $b     (array.get $Values (local.get $vals) (i32.const 1)))
             (local.set $sa    (call $sort:merge-sort (local.get $a) (local.get $f) (local.get $finv) (local.get $call)))
             (local.set $sb    (call $sort:merge-sort (local.get $b) (local.get $f) (local.get $finv) (local.get $call)))
             (return_call $sort:merge
                          (local.get $sa) (local.get $sb) (local.get $f) (local.get $finv) (local.get $call)))))

    ;; sort:merge-sort/key : list? procedure? any/c procedure? any/c any/c any/c -> list?
    ;;   Sort a list with an on-demand key procedure.
    (core-runtime-helper
     '$sort:merge-sort/key
     "$sort:merge-sort/key"
     (lambda ()
       `(func $sort:merge-sort/key
             (param $lst       (ref eq))
             (param $f         (ref $Procedure))
             (param $finv      (ref $ProcedureInvoker))
             (param $key-f     (ref $Procedure))
             (param $key-finv  (ref $ProcedureInvoker))
             (param $less-call (ref $Args))
             (param $key-call  (ref $Args))
             (result           (ref eq))

             (local $pair (ref $Pair))
             (local $rest (ref eq))
             (local $vals (ref $Values))
             (local $a    (ref eq))
             (local $b    (ref eq))
             (local $sa   (ref eq))
             (local $sb   (ref eq))

             (if (ref.eq (local.get $lst) (global.get $null))
                 (then (return (local.get $lst))))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $lst)))
                 (then (call $raise-pair-expected (local.get $lst))
                       (unreachable)))
             (local.set $pair (ref.cast (ref $Pair) (local.get $lst)))
             (local.set $rest (struct.get $Pair $d (local.get $pair)))
             (if (ref.eq (local.get $rest) (global.get $null))
                 (then (return (local.get $lst))))

             (local.set $vals (call $sort:split (local.get $lst)))
             (local.set $a    (array.get $Values (local.get $vals) (i32.const 0)))
             (local.set $b    (array.get $Values (local.get $vals) (i32.const 1)))
             (local.set $sa   (call $sort:merge-sort/key
                                    (local.get $a)
                                    (local.get $f)
                                    (local.get $finv)
                                    (local.get $key-f)
                                    (local.get $key-finv)
                                    (local.get $less-call)
                                    (local.get $key-call)))
             (local.set $sb   (call $sort:merge-sort/key
                                    (local.get $b)
                                    (local.get $f)
                                    (local.get $finv)
                                    (local.get $key-f)
                                    (local.get $key-finv)
                                    (local.get $less-call)
                                    (local.get $key-call)))
             (return_call $sort:merge/key
                          (local.get $sa)
                          (local.get $sb)
                          (local.get $f)
                          (local.get $finv)
                          (local.get $key-f)
                          (local.get $key-finv)
                          (local.get $less-call)
                          (local.get $key-call)))))

    ;; sort:cache-key-pairs : list? procedure? any/c any/c -> list?
    ;;   Decorate each list element with a cached key.
    (core-runtime-helper
     '$sort:cache-key-pairs
     "$sort:cache-key-pairs"
     (lambda ()
       `(func $sort:cache-key-pairs
             (param $lst      (ref eq))
             (param $key-f    (ref $Procedure))
             (param $key-finv (ref $ProcedureInvoker))
             (param $key-call (ref $Args))
             (result          (ref eq))

             (local $cur  (ref eq))
             (local $acc  (ref eq))
             (local $pair (ref $Pair))
             (local $x    (ref eq))
             (local $key  (ref eq))

             (local.set $cur (local.get $lst))
             (local.set $acc (global.get $null))
             (block $done
                    (loop $loop
                          (if (ref.eq (local.get $cur) (global.get $null))
                              (then (br $done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                              (then (call $raise-pair-expected (local.get $cur))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                          (local.set $x    (struct.get $Pair $a (local.get $pair)))
                          (array.set $Args (local.get $key-call) (i32.const 0) (local.get $x))
                          (local.set $key
                                     (call_ref $ProcedureInvoker
                                               (local.get $key-f)
                                               (local.get $key-call)
                                               (local.get $key-finv)))
                          (local.set $acc
                                     (call $cons
                                           (call $cons (local.get $key) (local.get $x))
                                           (local.get $acc)))
                          (local.set $cur (struct.get $Pair $d (local.get $pair)))
                          (br $loop)))
             (call $reverse (local.get $acc)))))

    ;; sort:extract-cached-values : list? -> list?
    ;;   Remove cached keys from a decorated sorted list.
    (core-runtime-helper
     '$sort:extract-cached-values
     "$sort:extract-cached-values"
     (lambda ()
       `(func $sort:extract-cached-values
             (param $lst (ref eq))
             (result     (ref eq))

             (local $cur       (ref eq))
             (local $acc       (ref eq))
             (local $cell      (ref $Pair))
             (local $decorated (ref $Pair))

             (local.set $cur (local.get $lst))
             (local.set $acc (global.get $null))
             (block $done
                    (loop $loop
                          (if (ref.eq (local.get $cur) (global.get $null))
                              (then (br $done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                              (then (call $raise-pair-expected (local.get $cur))
                                    (unreachable)))
                          (local.set $cell (ref.cast (ref $Pair) (local.get $cur)))
                          (if (i32.eqz (ref.test (ref $Pair) (struct.get $Pair $a (local.get $cell))))
                              (then (call $raise-pair-expected (struct.get $Pair $a (local.get $cell)))
                                    (unreachable)))
                          (local.set $decorated (ref.cast (ref $Pair) (struct.get $Pair $a (local.get $cell))))
                          (local.set $acc
                                     (call $cons
                                           (struct.get $Pair $d (local.get $decorated))
                                           (local.get $acc)))
                          (local.set $cur (struct.get $Pair $d (local.get $cell)))
                          (br $loop)))
             (call $reverse (local.get $acc)))))

    ;; sort:merge/cached-key : list? list? procedure? any/c any/c -> list?
    ;;   Merge two sorted decorated lists using cached keys.
    (core-runtime-helper
     '$sort:merge/cached-key
     "$sort:merge/cached-key"
     (lambda ()
       `(func $sort:merge/cached-key
             (param $a         (ref eq))
             (param $b         (ref eq))
             (param $f         (ref $Procedure))
             (param $finv      (ref $ProcedureInvoker))
             (param $less-call (ref $Args))
             (result           (ref eq))

             (local $apair (ref $Pair))
             (local $bpair (ref $Pair))
             (local $x     (ref eq))
             (local $y     (ref eq))
             (local $xpair (ref $Pair))
             (local $ypair (ref $Pair))
             (local $kx    (ref eq))
             (local $ky    (ref eq))
             (local $r     (ref eq))

             (if (ref.eq (local.get $a) (global.get $null))
                 (then (return (local.get $b))))
             (if (ref.eq (local.get $b) (global.get $null))
                 (then (return (local.get $a))))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $a)))
                 (then (call $raise-pair-expected (local.get $a))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $b)))
                 (then (call $raise-pair-expected (local.get $b))
                       (unreachable)))

             (local.set $apair (ref.cast (ref $Pair) (local.get $a)))
             (local.set $bpair (ref.cast (ref $Pair) (local.get $b)))
             (local.set $x     (struct.get $Pair $a (local.get $apair)))
             (local.set $y     (struct.get $Pair $a (local.get $bpair)))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $x)))
                 (then (call $raise-pair-expected (local.get $x))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $y)))
                 (then (call $raise-pair-expected (local.get $y))
                       (unreachable)))
             (local.set $xpair (ref.cast (ref $Pair) (local.get $x)))
             (local.set $ypair (ref.cast (ref $Pair) (local.get $y)))
             (local.set $kx    (struct.get $Pair $a (local.get $xpair)))
             (local.set $ky    (struct.get $Pair $a (local.get $ypair)))

             (array.set $Args (local.get $less-call) (i32.const 0) (local.get $ky))
             (array.set $Args (local.get $less-call) (i32.const 1) (local.get $kx))
             (local.set $r (call_ref $ProcedureInvoker
                                     (local.get $f)
                                     (local.get $less-call)
                                     (local.get $finv)))
             (if (result (ref eq))
                 (ref.eq (local.get $r) (global.get $false))
                 (then (call $cons (local.get $x)
                             (call $sort:merge/cached-key
                                   (struct.get $Pair $d (local.get $apair))
                                   (local.get $b)
                                   (local.get $f)
                                   (local.get $finv)
                                   (local.get $less-call))))
                 (else (call $cons (local.get $y)
                             (call $sort:merge/cached-key
                                   (local.get $a)
                                   (struct.get $Pair $d (local.get $bpair))
                                   (local.get $f)
                                   (local.get $finv)
                                   (local.get $less-call))))))))

    ;; sort:merge-sort/cached-key : list? procedure? any/c any/c -> list?
    ;;   Sort a decorated list with cached keys.
    (core-runtime-helper
     '$sort:merge-sort/cached-key
     "$sort:merge-sort/cached-key"
     (lambda ()
       `(func $sort:merge-sort/cached-key
             (param $lst       (ref eq))
             (param $f         (ref $Procedure))
             (param $finv      (ref $ProcedureInvoker))
             (param $less-call (ref $Args))
             (result           (ref eq))

             (local $pair (ref $Pair))
             (local $rest (ref eq))
             (local $vals (ref $Values))
             (local $a    (ref eq))
             (local $b    (ref eq))
             (local $sa   (ref eq))
             (local $sb   (ref eq))

             (if (ref.eq (local.get $lst) (global.get $null))
                 (then (return (local.get $lst))))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $lst)))
                 (then (call $raise-pair-expected (local.get $lst))
                       (unreachable)))
             (local.set $pair (ref.cast (ref $Pair) (local.get $lst)))
             (local.set $rest (struct.get $Pair $d (local.get $pair)))
             (if (ref.eq (local.get $rest) (global.get $null))
                 (then (return (local.get $lst))))

             (local.set $vals (call $sort:split (local.get $lst)))
             (local.set $a    (array.get $Values (local.get $vals) (i32.const 0)))
             (local.set $b    (array.get $Values (local.get $vals) (i32.const 1)))
             (local.set $sa   (call $sort:merge-sort/cached-key
                                    (local.get $a)
                                    (local.get $f)
                                    (local.get $finv)
                                    (local.get $less-call)))
             (local.set $sb   (call $sort:merge-sort/cached-key
                                    (local.get $b)
                                    (local.get $f)
                                    (local.get $finv)
                                    (local.get $less-call)))
             (return_call $sort:merge/cached-key
                          (local.get $sa)
                          (local.get $sb)
                          (local.get $f)
                          (local.get $finv)
                          (local.get $less-call)))))

    ;; cartesian-product : list? ... -> list?
    ;;   Build the Cartesian product of the supplied lists.
    (core-runtime-helper
     '$cartesian-product
     "$cartesian-product"
     (lambda ()
       `(func $cartesian-product (type $Prim>=0)
             (param $xss (ref eq))
             (result (ref eq))

              (local $pair   (ref $Pair))
              (local $xs     (ref eq))
              (local $rest   (ref eq))
              (local $prod   (ref eq))
              (local $list   (ref eq))
              (local $elem   (ref eq))
              (local $rs     (ref eq))
              (local $rpair  (ref $Pair))
              (local $r      (ref eq))
              (local $tmp    (ref eq))
              (local $acc    (ref eq))

              ;; Base case: no lists -> '(())
              (if (ref.eq (local.get $xss) (global.get $null))
                  (then (return (struct.new $Pair (i32.const 0)
                                            (global.get $null)
                                            (global.get $null)))))

              ;; Ensure xss is a proper list
              (if (i32.eqz (ref.test (ref $Pair) (local.get $xss)))
                  (then (call $raise-pair-expected (local.get $xss))
                        (unreachable)))
              (local.set $pair (ref.cast (ref $Pair) (local.get $xss)))
              (local.set $xs   (struct.get $Pair $a (local.get $pair)))
              (local.set $rest (struct.get $Pair $d (local.get $pair)))

              ;; Recursively compute product of remaining lists
              (local.set $prod (call $cartesian-product (local.get $rest)))

              ;; Iterate over first list and combine with rest
              (local.set $list (local.get $xs))
              (local.set $acc  (global.get $null))
              (block $outer_done
                     (loop $outer
                           (if (ref.eq (local.get $list) (global.get $null))
                               (then (br $outer_done)))
                           (if (i32.eqz (ref.test (ref $Pair) (local.get $list)))
                               (then (call $raise-pair-expected (local.get $list))
                                     (unreachable)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $list)))
                           (local.set $elem (struct.get $Pair $a (local.get $pair)))
                           (local.set $rs   (local.get $prod))
                           (block $inner_done
                                  (loop $inner
                                        (if (ref.eq (local.get $rs) (global.get $null))
                                            (then (br $inner_done)))
                                        (local.set $rpair (ref.cast (ref $Pair) (local.get $rs)))
                                        (local.set $r     (struct.get $Pair $a (local.get $rpair)))
                                        (local.set $tmp   (call $cons (local.get $elem) (local.get $r)))
                                        (local.set $acc   (call $cons (local.get $tmp) (local.get $acc)))
                                        (local.set $rs    (struct.get $Pair $d (local.get $rpair)))
                                        (br $inner)))
                           (local.set $list (struct.get $Pair $d (local.get $pair)))
                           (br $outer)))

             (call $reverse (local.get $acc)))))

    ;; permutations : list? -> list?
    ;;   Build all permutations of a list.
    (core-runtime-helper
     '$permutations
     "$permutations"
     (lambda ()
       `(func $permutations (type $Prim1)
             (param $lst (ref eq))
             (result     (ref eq))

             (local $len i32)                 ;; length of input list
             (local $vec (ref $Vector))       ;; vector representation
             (local $cnt (ref $I32Array))     ;; counters for Heap's algorithm
             (local $i i32)                   ;; index
             (local $ci i32)                  ;; counter value at i
             (local $x (ref eq))              ;; temporary for swaps
             (local $y (ref eq))
             (local $perm (ref eq))           ;; list for current permutation
             (local $acc (ref eq))            ;; accumulator of permutations

             ;; Determine length and ensure lst is a proper list
             (local.set $len (call $length/i32 (local.get $lst)))

             ;; If length <= 1, return list containing lst
             (if (i32.le_u (local.get $len) (i32.const 1))
                 (then (return (call $cons (local.get $lst) (global.get $null)))))

             ;; Convert list to vector and allocate counters
             (local.set $vec (ref.cast (ref $Vector) (call $list->vector (local.get $lst))))
             (local.set $cnt (call $i32array-make (local.get $len) (i32.const 0)))

             ;; Initialize accumulator with original list
             (local.set $acc (call $cons (local.get $lst) (global.get $null)))

             ;; Main Heap's algorithm loop
             (local.set $i (i32.const 0))
             (block $done
               (loop $loop
                 (if (i32.ge_u (local.get $i) (local.get $len))
                     (then (br $done)))
                 (local.set $ci (call $i32array-ref (local.get $cnt) (local.get $i)))
                 (if (i32.lt_u (local.get $ci) (local.get $i))
                     (then
                      ;; Swap depending on parity of i
                      (if (i32.eqz (i32.and (local.get $i) (i32.const 1)))
                          (then
                           (local.set $x (call $vector-ref/checked (local.get $vec) (i32.const 0)))
                           (local.set $y (call $vector-ref/checked (local.get $vec) (local.get $i)))
                           (call $vector-set!/checked (local.get $vec) (i32.const 0) (local.get $y))
                           (call $vector-set!/checked (local.get $vec) (local.get $i) (local.get $x)))
                          (else
                           (local.set $x (call $vector-ref/checked (local.get $vec) (local.get $ci)))
                           (local.set $y (call $vector-ref/checked (local.get $vec) (local.get $i)))
                           (call $vector-set!/checked (local.get $vec) (local.get $ci) (local.get $y))
                           (call $vector-set!/checked (local.get $vec) (local.get $i) (local.get $x))))

                      ;; Record permutation
                      (local.set $perm (call $vector->list (local.get $vec)))
                      (local.set $acc (call $cons (local.get $perm) (local.get $acc)))

                      ;; Increment counter and reset i
                      (call $i32array-set! (local.get $cnt) (local.get $i)
                                           (i32.add (local.get $ci) (i32.const 1)))
                      (local.set $i (i32.const 0)))
                     (else
                      ;; Reset counter and advance i
                      (call $i32array-set! (local.get $cnt) (local.get $i) (i32.const 0))
                      (local.set $i (i32.add (local.get $i) (i32.const 1)))))
                 (br $loop)))

             ;; Reverse accumulator to preserve generation order
             (call $reverse (local.get $acc)))))

    ;; build-list : exact-nonnegative-integer? procedure? -> list?
    ;;   Build a list by calling a procedure for each index.
    (core-runtime-helper
     '$build-list
     "$build-list"
     (lambda ()
       `(func $build-list (type $Prim2)
             (param $n-raw (ref eq))  ;; exact-nonnegative integer
             (param $proc  (ref eq))  ;; procedure
             (result (ref eq))

             (local $n   i32)
             (local $f   (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))

             ;; Check and unwrap n
             (if (i32.or
                  (i32.eqz (ref.test (ref i31) (local.get $n-raw)))
                  (i32.ne (i32.and (i31.get_u (ref.cast (ref i31) (local.get $n-raw))) (i32.const 1))
                          (i32.const 0)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:build-list)
                             (global.get $string:exact-nonnegative-integer?)
                             (local.get $n-raw))
                       (unreachable)))
             (local.set $n
                        (i32.shr_s
                         (i31.get_s (ref.cast (ref i31) (local.get $n-raw)))
                         (i32.const 1)))
             (if (i32.lt_s (local.get $n) (i32.const 0))
                 (then (call $raise-argument-error1
                             (global.get $symbol:build-list)
                             (global.get $string:exact-nonnegative-integer?)
                             (local.get $n-raw))
                       (unreachable)))

             ;; Check procedure and fetch invoker
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:build-list)
                             (global.get $string:build-list-procedure)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                (local.get $f)
                                (i32.const 1)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:build-list)
                             (global.get $string:build-list-procedure)
                             (local.get $proc))
                       (unreachable)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; Delegate
             (call $build-list/checked (local.get $n) (local.get $f) (local.get $finv)))))

    ;; build-list/checked : i32 procedure? procedure-invoker? -> list?
    ;;   Build a list after the length and procedure have been validated.
    (core-runtime-helper
     '$build-list/checked
     "$build-list/checked"
     (lambda ()
       `(func $build-list/checked
             (param $n   i32)
             (param $f   (ref $Procedure))
             (param $finv (ref $ProcedureInvoker))
             (result (ref eq))

             (local $args (ref $Args))
             (local $acc  (ref eq))
             (local $r    (ref eq))
             (local $i    i32)

             ;; Prepare argument array and accumulator
             (local.set $args (array.new $Args (global.get $null) (i32.const 1)))
             (local.set $acc  (global.get $null))
             (local.set $i    (local.get $n))

             (block $done
                    (loop $loop
                          (br_if $done (i32.eqz (local.get $i)))
                          (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                          (array.set $Args
                                     (local.get $args)
                                     (i32.const 0)
                                     (ref.i31 (i32.shl (local.get $i) (i32.const 1))))
                          (local.set $r
                                     (call_ref $ProcedureInvoker
                                               (local.get $f)
                                               (local.get $args)
                                               (local.get $finv)))
                          (local.set $acc (call $cons (local.get $r) (local.get $acc)))
                          (br $loop)))
             (local.get $acc))))

    ;; raise-range:real-expected : symbol? any/c -> none
    ;;   Raise a range real? contract error with a Racket-compatible who.
    (core-runtime-helper
     '$raise-range:real-expected
     "$raise-range:real-expected"
     (lambda ()
       `(func $raise-range:real-expected
             (param $who (ref eq))
             (param $bad (ref eq))
             (call $raise-argument-error1
                   (local.get $who)
                   (global.get $string:real?)
                   (local.get $bad))
             (unreachable))))

    ;; raise-range:zero-step : symbol? any/c -> none
    ;;   Raise a catchable contract error for WebRacket's zero-step rejection.
    (core-runtime-helper
     '$raise-range:zero-step
     "$raise-range:zero-step"
     (lambda ()
       `(func $raise-range:zero-step
             (param $who (ref eq))
             (param $bad (ref eq))
             (call $raise-argument-error1
                   (local.get $who)
                   (global.get $string:range:non-zero-step)
                   (local.get $bad))
             (unreachable))))

    ;; range-proc : real? real? optional-real? -> list?
    ;;   First-class wrapper for range.
    (core-runtime-helper
     '$range-proc
     "$range-proc"
     (lambda ()
       `(func $range-proc (type $Prim13)
             (param $start (ref eq))
             (param $end   (ref eq))
             (param $step  (ref eq)) ;; $missing for default 1
             (result       (ref eq))
             (call $range (local.get $start) (local.get $end) (local.get $step)))))

    ;; range : real? optional-real? optional-real? -> list?
    ;;   Build a half-open numeric range.
    (core-runtime-helper
     '$range
     "$range"
     (lambda ()
       `(func $range (type $Prim13)
             (param $start-raw (ref eq))
             (param $end-raw   (ref eq))
             (param $step-raw  (ref eq)) ;; $missing for defaults 0/1
             (result           (ref eq))

             (local $use-fl       i32)
             (local $start-i32    i32)
             (local $end-i32      i32)
             (local $step-i32     i32)
             (local $start-f64    f64)
             (local $end-f64      f64)
             (local $step-f64     f64)
             (local $start-is-fl  i32)
             (local $end-is-fl    i32)
             (local $step-is-fl   i32)
             (local $start-val    (ref eq))
             (local $end-val      (ref eq))
             (local $step-val     (ref eq))

             ;; First-class calls use $missing for omitted optional arguments.
             ;; Normalize (range end) into (range 0 end 1) before validation.
             (local.set $start-val (global.get $missing))
             (local.set $end-val   (global.get $missing))
             (local.set $step-val  (global.get $missing))
             (if (ref.eq (local.get $end-raw) (global.get $missing))
                 (then (local.set $start-val (ref.i31 (i32.const 0)))
                       (local.set $end-val   (local.get $start-raw))
                       (local.set $step-val  (global.get $missing)))
                 (else (local.set $start-val (local.get $start-raw))
                       (local.set $end-val   (local.get $end-raw))
                       (local.set $step-val  (local.get $step-raw))))

             ;; start (optional, defaults to 0)
             (if (ref.eq (local.get $start-val) (global.get $missing))
                 (then (local.set $start-i32 (i32.const 0)))
                 (else (if (call $fl?/i32 (local.get $start-val))
                           (then (local.set $use-fl (i32.const 1))
                                 (local.set $start-is-fl (i32.const 1))
                                 (local.set $start-f64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $start-val)))))
                           (else (if (call $fx?/i32 (local.get $start-val))
                                     (then (local.set $start-i32
                                                     (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $start-val))) (i32.const 1))))
                                     (else (call $raise-range:real-expected
                                                 (global.get $symbol:in-range)
                                                 (local.get $start-val))))))))

             ;; end
             (if (call $fl?/i32 (local.get $end-val))
                 (then (local.set $use-fl (i32.const 1))
                       (local.set $end-is-fl (i32.const 1))
                       (local.set $end-f64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $end-val)))))
                 (else (if (call $fx?/i32 (local.get $end-val))
                           (then (local.set $end-i32
                                           (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $end-val))) (i32.const 1))))
                           (else (call $raise-range:real-expected
                                       (global.get $symbol:in-range)
                                       (local.get $end-val))))))

             ;; step (optional, defaults to 1)
             (if (ref.eq (local.get $step-val) (global.get $missing))
                 (then (if (i32.eqz (local.get $use-fl))
                           (then (local.set $step-i32 (i32.const 1)))
                           (else (local.set $step-is-fl (i32.const 1))
                                 (local.set $step-f64 (f64.const 1.0)))))
                 (else (if (call $fl?/i32 (local.get $step-val))
                           (then (local.set $use-fl (i32.const 1))
                                 (local.set $step-is-fl (i32.const 1))
                                 (local.set $step-f64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $step-val)))))
                           (else (if (call $fx?/i32 (local.get $step-val))
                                     (then (local.set $step-i32
                                                     (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $step-val))) (i32.const 1))))
                                     (else (call $raise-range:real-expected
                                                 (global.get $symbol:in-range)
                                                 (local.get $step-val))))))))

             ;; step must be non-zero when provided
             (if (i32.eqz (ref.eq (local.get $step-val) (global.get $missing)))
                 (then (if (i32.eqz (local.get $use-fl))
                           (then (if (i32.eq (local.get $step-i32) (i32.const 0))
                                     (then (call $raise-range:zero-step
                                                 (global.get $symbol:in-range)
                                                 (local.get $step-val)))))
                           (else (if (f64.eq (local.get $step-f64) (f64.const 0))
                                     (then (call $raise-range:zero-step
                                                 (global.get $symbol:in-range)
                                                 (local.get $step-val))))))))

             ;; decide variant
             (if (i32.eqz (local.get $use-fl))
                 (then (return (call $range/fixnum
                                      (local.get $start-i32)
                                      (local.get $end-i32)
                                      (local.get $step-i32)))))

             ;; convert fixnums to flonums if needed
             (if (i32.eqz (local.get $start-is-fl))
                 (then (local.set $start-f64 (f64.convert_i32_s (local.get $start-i32)))))
             (if (i32.eqz (local.get $end-is-fl))
                 (then (local.set $end-f64 (f64.convert_i32_s (local.get $end-i32)))))
             (if (i32.eqz (local.get $step-is-fl))
                 (then (local.set $step-f64 (f64.convert_i32_s (local.get $step-i32)))))

             (call $range/flonum
                   (local.get $start-f64)
                   (local.get $end-f64)
                   (local.get $step-f64)
                   (local.get $start-val)
                   (i32.eqz (local.get $start-is-fl))))))

    ;; range/fixnum : i32 i32 i32 -> list?
    ;;   Build a half-open fixnum range.
    (core-runtime-helper
     '$range/fixnum
     "$range/fixnum"
     (lambda ()
       `(func $range/fixnum
             (param $start i32)
             (param $end   i32)
             (param $step  i32)
             (result (ref eq))

             (local $cur i32)
             (local $lst (ref eq))

             (local.set $cur (local.get $start))
             (local.set $lst (global.get $null))
             (block $done
                    (loop $loop
                          (if (i32.gt_s (local.get $step) (i32.const 0))
                              (then (br_if $done (i32.ge_s (local.get $cur) (local.get $end))))
                              (else (br_if $done (i32.le_s (local.get $cur) (local.get $end)))))
                          (local.set $lst
                                     (struct.new $Pair
                                                 (i32.const 0)
                                                 (ref.i31 (i32.shl (local.get $cur) (i32.const 1)))
                                                 (local.get $lst)))
                          (local.set $cur (i32.add (local.get $cur) (local.get $step)))
                          (br $loop)))
             (call $reverse (local.get $lst)))))

    ;; range/flonum : f64 f64 f64 any/c i32 -> list?
    ;;   Build a half-open flonum range.
    (core-runtime-helper
     '$range/flonum
     "$range/flonum"
     (lambda ()
       `(func $range/flonum
             (param $start f64)
             (param $end   f64)
             (param $step  f64)
             (param $start-raw (ref eq))
             (param $preserve-start i32)
             (result (ref eq))

             (local $n   i32)
             (local $cur f64)
             (local $lst (ref eq))

             (local.set $n   (i32.const 0))
             (local.set $lst (global.get $null))
             (block $done
                    (loop $loop
                          (local.set $cur
                                     (f64.add (local.get $start)
                                              (f64.mul (f64.convert_i32_s (local.get $n)) (local.get $step))))
                          (if (f64.gt (local.get $step) (f64.const 0))
                              (then (br_if $done (f64.ge (local.get $cur) (local.get $end))))
                              (else (br_if $done (f64.le (local.get $cur) (local.get $end)))))
                          (local.set $lst
                                     (struct.new $Pair
                                                 (i32.const 0)
                                                 (if (result (ref eq))
                                                     (i32.and (i32.eqz (local.get $n))
                                                              (local.get $preserve-start))
                                                     (then (local.get $start-raw))
                                                     (else (struct.new $Flonum (i32.const 0) (local.get $cur))))
                                                 (local.get $lst)))
                          (local.set $n (i32.add (local.get $n) (i32.const 1)))
                          (br $loop)))
             (call $reverse (local.get $lst)))))

    ;; inclusive-range-proc : real? real? optional-real? -> list?
    ;;   First-class wrapper for inclusive-range.
    (core-runtime-helper
     '$inclusive-range-proc
     "$inclusive-range-proc"
     (lambda ()
       `(func $inclusive-range-proc (type $Prim23)
             (param $start (ref eq))
             (param $end   (ref eq))
             (param $step  (ref eq)) ;; $missing for default 1/-1
             (result       (ref eq))
             (call $inclusive-range (local.get $start) (local.get $end) (local.get $step)))))

    ;; Unlike Racket's @racket[inclusive-range], the step defaults to
    ;; either 1 or -1 based on the ordering of @racket[start] and
    ;; @racket[end] when omitted.
    ;; inclusive-range : real? real? optional-real? -> list?
    ;;   Build an inclusive numeric range.
    (core-runtime-helper
     '$inclusive-range
     "$inclusive-range"
     (lambda ()
       `(func $inclusive-range (type $Prim23)
             (param $start-raw (ref eq))
             (param $end-raw   (ref eq))
             (param $step-raw  (ref eq)) ;; $missing for default 1/-1
             (result (ref eq))

             (local $use-fl       i32)
             (local $start-i32    i32)
             (local $end-i32      i32)
             (local $step-i32     i32)
             (local $start-f64    f64)
             (local $end-f64      f64)
             (local $step-f64     f64)
             (local $start-is-fl  i32)
             (local $end-is-fl    i32)
             (local $step-is-fl   i32)

             ;; start
             (if (call $fl?/i32 (local.get $start-raw))
                 (then (local.set $use-fl (i32.const 1))
                       (local.set $start-is-fl (i32.const 1))
                       (local.set $start-f64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $start-raw)))))
                 (else (if (call $fx?/i32 (local.get $start-raw))
                           (then (local.set $start-i32
                                           (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $start-raw))) (i32.const 1))))
                           (else (call $raise-range:real-expected
                                       (global.get $symbol:in-inclusive-range)
                                       (local.get $start-raw))))))

             ;; end
             (if (call $fl?/i32 (local.get $end-raw))
                 (then (local.set $use-fl (i32.const 1))
                       (local.set $end-is-fl (i32.const 1))
                       (local.set $end-f64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $end-raw)))))
                 (else (if (call $fx?/i32 (local.get $end-raw))
                           (then (local.set $end-i32
                                           (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $end-raw))) (i32.const 1))))
                           (else (call $raise-range:real-expected
                                       (global.get $symbol:in-inclusive-range)
                                       (local.get $end-raw))))))

             ;; step
             (if (ref.eq (local.get $step-raw) (global.get $missing))
                 (then (if (i32.eqz (local.get $use-fl))
                           (then (if (i32.le_s (local.get $start-i32) (local.get $end-i32))
                                     (then (local.set $step-i32 (i32.const 1)))
                                     (else (local.set $step-i32 (i32.const -1)))))
                           (else (if (i32.eqz (local.get $start-is-fl))
                                     (then (local.set $start-f64 (f64.convert_i32_s (local.get $start-i32)))))
                                 (if (i32.eqz (local.get $end-is-fl))
                                     (then (local.set $end-f64 (f64.convert_i32_s (local.get $end-i32)))))
                                 (local.set $step-is-fl (i32.const 1))
                                 (if (f64.le (local.get $start-f64) (local.get $end-f64))
                                     (then (local.set $step-f64 (f64.const 1.0)))
                                     (else (local.set $step-f64 (f64.const -1.0)))))))
                 (else (if (call $fl?/i32 (local.get $step-raw))
                           (then (local.set $use-fl (i32.const 1))
                                 (local.set $step-is-fl (i32.const 1))
                                 (local.set $step-f64 (struct.get $Flonum $v (ref.cast (ref $Flonum) (local.get $step-raw)))))
                           (else (if (call $fx?/i32 (local.get $step-raw))
                                     (then (local.set $step-i32
                                                     (i32.shr_s (i31.get_s (ref.cast (ref i31) (local.get $step-raw))) (i32.const 1))))
                                     (else (call $raise-range:real-expected
                                                 (global.get $symbol:in-inclusive-range)
                                                 (local.get $step-raw))))))))

             ;; step must be non-zero when provided
             (if (i32.eqz (ref.eq (local.get $step-raw) (global.get $missing)))
                 (then (if (i32.eqz (local.get $use-fl))
                           (then (if (i32.eq (local.get $step-i32) (i32.const 0))
                                     (then (call $raise-range:zero-step
                                                 (global.get $symbol:in-inclusive-range)
                                                 (local.get $step-raw)))))
                           (else (if (f64.eq (local.get $step-f64) (f64.const 0))
                                     (then (call $raise-range:zero-step
                                                 (global.get $symbol:in-inclusive-range)
                                                 (local.get $step-raw))))))))

             ;; decide variant
             (if (i32.eqz (local.get $use-fl))
                 (then (return (call $inclusive-range/fixnum
                                      (local.get $start-i32)
                                      (local.get $end-i32)
                                      (local.get $step-i32)))))

             ;; convert fixnums to flonums if needed
             (if (i32.eqz (local.get $start-is-fl))
                 (then (local.set $start-f64 (f64.convert_i32_s (local.get $start-i32)))))
             (if (i32.eqz (local.get $end-is-fl))
                 (then (local.set $end-f64 (f64.convert_i32_s (local.get $end-i32)))))
             (if (i32.eqz (local.get $step-is-fl))
                 (then (local.set $step-f64 (f64.convert_i32_s (local.get $step-i32)))))

             (call $inclusive-range/flonum
                   (local.get $start-f64)
                   (local.get $end-f64)
                   (local.get $step-f64)))))

    ;; inclusive-range/fixnum : i32 i32 i32 -> list?
    ;;   Build an inclusive fixnum range.
    (core-runtime-helper
     '$inclusive-range/fixnum
     "$inclusive-range/fixnum"
     (lambda ()
       `(func $inclusive-range/fixnum
             (param $start i32)
             (param $end   i32)
             (param $step  i32)
             (result (ref eq))

             (local $cur i32)
             (local $lst (ref eq))

             (local.set $cur (local.get $start))
             (local.set $lst (global.get $null))
             (block $done
                    (loop $loop
                          (if (i32.gt_s (local.get $step) (i32.const 0))
                              (then (br_if $done (i32.gt_s (local.get $cur) (local.get $end))))
                              (else (br_if $done (i32.lt_s (local.get $cur) (local.get $end)))))
                          (local.set $lst
                                     (struct.new $Pair
                                                 (i32.const 0)
                                                 (ref.i31 (i32.shl (local.get $cur) (i32.const 1)))
                                                 (local.get $lst)))
                          (local.set $cur (i32.add (local.get $cur) (local.get $step)))
                          (br $loop)))
             (call $reverse (local.get $lst)))))

    ;; inclusive-range/flonum : f64 f64 f64 -> list?
    ;;   Build an inclusive flonum range.
    (core-runtime-helper
     '$inclusive-range/flonum
     "$inclusive-range/flonum"
     (lambda ()
       `(func $inclusive-range/flonum
             (param $start f64)
             (param $end   f64)
             (param $step  f64)
             (result (ref eq))

             (local $n   i32)
             (local $cur f64)
             (local $lst (ref eq))

             (local.set $n   (i32.const 0))
             (local.set $lst (global.get $null))
             (block $done
                    (loop $loop
                          (local.set $cur
                                     (f64.add (local.get $start)
                                              (f64.mul (f64.convert_i32_s (local.get $n)) (local.get $step))))
                          (if (f64.gt (local.get $step) (f64.const 0))
                              (then (br_if $done (f64.gt (local.get $cur) (local.get $end))))
                              (else (br_if $done (f64.lt (local.get $cur) (local.get $end)))))
                          (local.set $lst
                                     (struct.new $Pair
                                                 (i32.const 0)
                                                 (struct.new $Flonum (i32.const 0) (local.get $cur))
                                                 (local.get $lst)))
                          (local.set $n (i32.add (local.get $n) (i32.const 1)))
                          (br $loop)))
             (call $reverse (local.get $lst)))))

    ;; list-from-range : fixnum? fixnum? -> list?
    ;;   Build a fixnum list from checked Racket values.
    (core-runtime-helper
     '$list-from-range
     "$list-from-range"
     (lambda ()
       `(func $list-from-range
             (param $start-raw (ref eq))   ;; inclusive, fixnum
             (param $end-raw   (ref eq))   ;; exclusive, fixnum
             (result (ref eq))

             (local $start-i31 (ref i31))
             (local $end-i31   (ref i31))
             (local $start     i32)
             (local $end       i32)

             ;; Check and unwrap start
             (if (i32.eqz (ref.test (ref i31) (local.get $start-raw)))
                 (then (call $raise-expected-fixnum (local.get $start-raw))))
             (local.set $start-i31 (ref.cast (ref i31) (local.get $start-raw)))
             (local.set $start (i32.shr_u (i31.get_u (local.get $start-i31)) (i32.const 1)))
             ;; Check and unwrap end
             (if (i32.eqz (ref.test (ref i31) (local.get $end-raw)))
                 (then (call $raise-expected-fixnum (local.get $end-raw))))
             (local.set $end-i31 (ref.cast (ref i31) (local.get $end-raw)))
             (local.set $end (i32.shr_u (i31.get_u (local.get $end-i31)) (i32.const 1)))
             ;; Delegate
             (call $list-from-range/checked (local.get $start) (local.get $end)))))

    ;; list-from-range/checked : i32 i32 -> list?
    ;;   Build a fixnum list from unboxed bounds.
    (core-runtime-helper
     '$list-from-range/checked
     "$list-from-range/checked"
     (lambda ()
       `(func $list-from-range/checked
             (param $start i32)  ;; inclusive
             (param $end   i32)  ;; exclusive
             (result (ref eq))   ;; proper list of fixnums

             (local $i   i32)
             (local $lst (ref eq))  ;; initially null

             ;; Start from end and build backwards
             (local.set $i   (local.get $end))
             (local.set $lst (global.get $null))
             (block $done
                    (loop $loop
                          (br_if $done (i32.le_s (local.get $i) (local.get $start)))
                          ;; Decrement i
                          (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                          ;; Prepend (ref.i31 (i32.shl $i 1)) as fixnum
                          (local.set $lst
                                     (struct.new $Pair
                                                 (i32.const 0)  ;; hash
                                                 (ref.i31 (i32.shl (local.get $i) (i32.const 1)))
                                                 (local.get $lst)))
                          (br $loop)))
             (local.get $lst))))

    ;; list-update/checked/who: takes a Pair, an index, and an updater procedure.
    ;; Returns a list like the input except that the element at index
    ;; is replaced by the result of applying the updater.
    ;; list-update/checked/who : symbol? pair? i32 procedure? procedure-invoker? args? -> list?
    ;;   Update a list element after validation, reporting errors with who.
    (core-runtime-helper
     '$list-update/checked/who
     "$list-update/checked/who"
     (lambda ()
       `(func $list-update/checked/who
             (param $who  (ref eq))
             (param $xs   (ref $Pair))
             (param $i    i32)
             (param $f    (ref $Procedure))
             (param $finv (ref $ProcedureInvoker))
             (param $args (ref $Args))
             (result (ref eq))

             (local $orig    (ref $Pair))
             (local $node    (ref $Pair))
             (local $acc     (ref eq))
             (local $k       i32)
             (local $next    (ref eq))
             (local $elem    (ref eq))
             (local $updated (ref eq))
             (local $len     i32)

             (local.set $orig (local.get $xs))
             (local.set $node (local.get $xs))
             (local.set $acc  (global.get $null))
             (local.set $k    (local.get $i))

             (loop $loop
                   (if (i32.eqz (local.get $k))
                       (then
                        (local.set $elem (struct.get $Pair $a (local.get $node)))
                        (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                        (local.set $updated
                                   (call_ref $ProcedureInvoker
                                             (local.get $f)
                                             (local.get $args)
                                             (local.get $finv)))
                        (return
                         (call $append/2
                               (call $reverse (local.get $acc))
                               (call $cons
                                     (local.get $updated)
                                     (struct.get $Pair $d (local.get $node)))))))

                   (local.set $acc
                              (call $cons
                                    (struct.get $Pair $a (local.get $node))
                                    (local.get $acc)))
                   (local.set $next (struct.get $Pair $d (local.get $node)))
                   (if (ref.test (ref $Pair) (local.get $next))
                       (then (local.set $node (ref.cast (ref $Pair) (local.get $next)))
                             (local.set $k (i32.sub (local.get $k) (i32.const 1)))
                             (br $loop))
                       (else
                        (local.set $len
                                   (i32.add
                                    (i32.sub (local.get $i) (local.get $k))
                                    (i32.const 1)))
                        (call $raise-bad-list-ref-index/who
                              (local.get $who)
                              (local.get $orig)
                              (local.get $i)
                              (local.get $len))
                        (unreachable))))
             (unreachable))))

    ;; list-update/checked : pair? i32 procedure? procedure-invoker? args? -> list?
    ;;   Update a list element after validation.
    (core-runtime-helper
     '$list-update/checked
     "$list-update/checked"
     (lambda ()
       `(func $list-update/checked
             (param $xs   (ref $Pair))
             (param $i    i32)
             (param $f    (ref $Procedure))
             (param $finv (ref $ProcedureInvoker))
             (param $args (ref $Args))
             (result (ref eq))
             (call $list-update/checked/who
                   (global.get $symbol:list-update)
                   (local.get $xs)
                   (local.get $i)
                   (local.get $f)
                   (local.get $finv)
                   (local.get $args)))))

    ;; list-update : list? exact-nonnegative-integer? procedure? -> list?
    ;;   Validate arguments and update one list element.
    (core-runtime-helper
     '$list-update
     "$list-update"
     (lambda ()
       `(func $list-update (type $Prim3)
             (param $xs   (ref eq))
             (param $i    (ref eq))
             (param $proc (ref eq))
             (result      (ref eq))

             (local $idx  i32)
             (local $f    (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))
             (local $args (ref $Args))

             (if (ref.test (ref i31) (local.get $i))
                 (then
                  (local.set $idx (i31.get_s (ref.cast (ref i31) (local.get $i))))
                  (if (i32.ne (i32.and (local.get $idx) (i32.const 1)) (i32.const 0))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:list-update)
                                  (global.get $string:exact-nonnegative-integer?)
                                  (local.get $i))
                            (unreachable)))
                  (local.set $idx (i32.shr_s (local.get $idx) (i32.const 1))))
                 (else (call $raise-argument-error1
                             (global.get $symbol:list-update)
                             (global.get $string:exact-nonnegative-integer?)
                             (local.get $i))
                       (unreachable)))
             (if (i32.lt_s (local.get $idx) (i32.const 0))
                 (then (call $raise-argument-error1
                             (global.get $symbol:list-update)
                             (global.get $string:exact-nonnegative-integer?)
                             (local.get $i))
                       (unreachable)))

            (if (ref.eq (call $procedure? (local.get $proc))
                        (global.get $false))
                (then (call $raise-argument-error1
                            (global.get $symbol:list-update)
                            (global.get $string:list-index-predicate)
                            (local.get $proc))
                      (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
             (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

             (if (result (ref eq))
                 (ref.test (ref $Pair) (local.get $xs))
                 (then
                  (call $list-update/checked/who
                        (global.get $symbol:list-update)
                        (ref.cast (ref $Pair) (local.get $xs))
                        (local.get $idx)
                        (local.get $f)
                        (local.get $finv)
                        (local.get $args)))
                 (else
                  (call $raise-pair-expected/who
                        (global.get $symbol:list-update)
                        (local.get $xs))
                  (unreachable))))))

    ;; argmax : procedure? non-empty-list? -> any/c
    ;;   Return the element whose projected value is largest.
    (argminmax-runtime-helper '$argmax '$symbol:argmax '$</2)

    ;; argmin : procedure? non-empty-list? -> any/c
    ;;   Return the element whose projected value is smallest.
    (argminmax-runtime-helper '$argmin '$symbol:argmin '$>/2)

    ;; Walks the outer list of lists to count the arity while validating
    ;; that the outer list is proper and every element is either null or
    ;; a pair (i.e. a list head). Uses `who` for raised argument errors
    ;; on malformed input.
    ;; validate-list-args : args? symbol? i32 -> void?
    ;;   Validate that rest arguments contain enough proper lists.
    (core-runtime-helper
     '$validate-list-args
     "$validate-list-args"
     (lambda ()
       `(func $validate-list-args
             (param $who (ref eq))   ;; primitive name symbol
             (param $xss (ref eq))   ;; list of lists
             (result i32)            ;; number of lists

             (local $outer  (ref eq))
             (local $pair   (ref $Pair))
             (local $elem   (ref eq))
             (local $nlists i32)

             (local.set $nlists (i32.const 0))
             (local.set $outer  (local.get $xss))
             (block $count_done
                    (loop $count
                          (if (ref.eq (local.get $outer) (global.get $null))
                              (then (br $count_done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $outer)))
                              (then (call $raise-argument-error1
                                          (local.get $who)
                                          (global.get $string:list?)
                                          (local.get $outer))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $outer)))
                          (local.set $elem (struct.get $Pair $a (local.get $pair)))
                          (if (i32.eqz
                               (i32.or
                                (ref.eq (local.get $elem) (global.get $null))
                                (ref.test (ref $Pair) (local.get $elem))))
                              (then (call $raise-argument-error1
                                          (local.get $who)
                                          (global.get $string:list?)
                                          (local.get $elem))
                                    (unreachable)))
                          (local.set $nlists (i32.add (local.get $nlists) (i32.const 1)))
                          (local.set $outer (struct.get $Pair $d (local.get $pair)))
                          (br $count)))
             (local.get $nlists))))

    ;; Seeds an array of list cursors from the validated list-of-lists
    ;; argument, storing each inner list head in $lists.
    ;; seed-list-args : args? args? i32 -> i32
    ;;   Copy the current heads of list arguments into a call argument array.
    (core-runtime-helper
     '$seed-list-args
     "$seed-list-args"
     (lambda ()
       `(func $seed-list-args
             (param $xss   (ref eq))
             (param $lists (ref $Args))
              (local $outer (ref eq))
              (local $pair  (ref $Pair))
              (local $i     i32)

              (local.set $outer (local.get $xss))
              (local.set $i (i32.const 0))
              (block $seed_done
                     (loop $seed
                           (if (ref.eq (local.get $outer) (global.get $null))
                               (then (br $seed_done)))
                           (local.set $pair (ref.cast (ref $Pair) (local.get $outer)))
                           (array.set $Args
                                      (local.get $lists)
                                      (local.get $i)
                                      (struct.get $Pair $a (local.get $pair)))
                           (local.set $outer (struct.get $Pair $d (local.get $pair)))
                           (local.set $i (i32.add (local.get $i) (i32.const 1)))
                           (br $seed))))))

    ;; append-map : procedure? list? list? ... -> list?
    ;;   Map a procedure over lists and append the resulting lists.
    (core-runtime-helper
     '$append-map
     "$append-map"
     (lambda ()
       `(func $append-map (type $Prim>=2)
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

             (local $res    (ref eq))     ;; accumulated output (forward order)
             (local $tail   (ref null $Pair))  ;; tail of $res when non-null
             (local $r      (ref eq))

             (local $seg-cur  (ref eq))   ;; cursor for copying non-final segments
             (local $seg-head (ref eq))
             (local $seg-tail (ref null $Pair))
             (local $seg-pair (ref $Pair))
             (local $new     (ref $Pair))

              ;; 1) Check that $proc is a procedure and fetch its invoker
              (if (ref.eq (call $procedure? (local.get $proc))
                          (global.get $false))
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
                                        (global.get $symbol:append-map)
                                        (local.get $xss)))

              ;; Racket's append-map requires at least one list argument
              (if (i32.eq (local.get $nlists) (i32.const 0))
                  (then (call $primitive-invoke:raise-arity-error
                              (ref.cast (ref $PrimitiveProcedure)
                                        (global.get $prim:append-map))
                              (i32.const 1))
                        (unreachable)))

              ;; 4) Allocate arrays for list cursors and call arguments; seed list cursors from xss
              (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
              (local.set $call  (array.new $Args (global.get $null) (local.get $nlists)))

              (call $seed-list-args (local.get $xss) (local.get $lists))

              ;; 5) Main loop: stop at the shortest list
              (local.set $res (global.get $null))

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
                                                      (global.get $symbol:append-map)
                                                      (local.get $cur))
                                                (unreachable)))))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $check)))

                    ;; If any list is empty → return accumulated result
                    (if (i32.ne (local.get $stop) (i32.const 0))
                        (then (return (local.get $res))))

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

                    ;; (d) Advance each list (cdr) and note if this is the last iteration
                    (local.set $stop (i32.const 0))
                    (local.set $i (i32.const 0))
                    (block $cdrs_done
                           (loop $cdrs
                                 (if (i32.ge_u (local.get $i) (local.get $nlists))
                                     (then (br $cdrs_done)))
                                 (local.set $pair
                                            (ref.cast (ref $Pair)
                                                      (array.get $Args (local.get $lists) (local.get $i))))
                                 (local.set $cur (struct.get $Pair $d (local.get $pair)))
                                 (array.set $Args
                                            (local.get $lists) (local.get $i)
                                            (local.get $cur))
                                 (if (ref.eq (local.get $cur) (global.get $null))
                                     (then (local.set $stop (i32.const 1))))
                                 (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                 (br $cdrs)))

                    ;; (e) If this is the final segment, splice it directly and return
                    (if (i32.ne (local.get $stop) (i32.const 0))
                        (then (if (ref.eq (local.get $r) (global.get $null))
                                  (then (return (local.get $res)))
                                  (else (if (ref.eq (local.get $res) (global.get $null))
                                            (then (return (local.get $r)))
                                            (else (struct.set $Pair $d (ref.as_non_null (local.get $tail)) (local.get $r))
                                                  (return (local.get $res))))))))

                    ;; (f) Copy non-final segment and append to accumulated result
                    (local.set $seg-cur  (local.get $r))
                    (local.set $seg-head (global.get $null))
                    (block $copy_done
                           (loop $copy
                                 (if (ref.eq (local.get $seg-cur) (global.get $null))
                                     (then (br $copy_done)))
                                 (if (i32.eqz (ref.test (ref $Pair) (local.get $seg-cur)))
                                     (then (call $raise-pair-expected/who
                                                 (global.get $symbol:append-map)
                                                 (local.get $seg-cur))
                                           (unreachable)))
                                 (local.set $seg-pair (ref.cast (ref $Pair) (local.get $seg-cur)))
                                 (local.set $new
                                            (struct.new $Pair
                                                        (i32.const 0)
                                                        (struct.get $Pair $a (local.get $seg-pair))
                                                        (global.get $null)))
                                 (if (ref.eq (local.get $seg-head) (global.get $null))
                                     (then (local.set $seg-head (local.get $new)))
                                     (else (struct.set $Pair $d (ref.as_non_null (local.get $seg-tail)) (local.get $new))))
                                 (local.set $seg-tail (local.get $new))
                                 (local.set $seg-cur (struct.get $Pair $d (local.get $seg-pair)))
                                 (br $copy)))

                    (if (ref.eq (local.get $seg-head) (global.get $null))
                        (then (br $loop)))

                    (if (ref.eq (local.get $res) (global.get $null))
                        (then (local.set $res (local.get $seg-head)))
                        (else (struct.set $Pair $d (ref.as_non_null (local.get $tail)) (local.get $seg-head))))
                    (local.set $tail (local.get $seg-tail))

                    (br $loop))
              (unreachable))))

    ;; count : procedure? list? list? ... -> exact-nonnegative-integer?
    ;;   Count positions where a predicate returns true.
    (core-runtime-helper
     '$count
     "$count"
     (lambda ()
       `(func $count (type $Prim>=2)
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
             (local $r      (ref eq))
             (local $cnt    i32)

             ;; 1) Check that $proc is a procedure and fetch its invoker
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:count)
                             (local.get $proc))
                       (unreachable))
                 (else))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; 2) Build list-of-lists from first list and rest
             (local.set $xss (struct.new $Pair
                                         (i32.const 0)
                                         (local.get $xs0)
                                         (local.get $rest)))

             ;; 3) Walk outer list xss to count #lists; ensure xss is proper and each element is a list head
             (local.set $nlists (call $validate-list-args
                                      (global.get $symbol:count)
                                      (local.get $xss)))

             ;; Racket's count requires at least one list argument
             (if (i32.eq (local.get $nlists) (i32.const 0))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:count))
                             (i32.const 1))
                       (unreachable))
                 (else))

             ;; Fast path when exactly one list is supplied
             (if (i32.eq (local.get $nlists) (i32.const 1))
                 (then
                  ;; Recompute the sole inner list directly from $xss, do not rely on $elem
                  (local.set $pair (ref.cast (ref $Pair) (local.get $xss)))
                  (local.set $cur  (struct.get $Pair $a (local.get $pair)))
                  (local.set $call (array.new $Args (global.get $null) (i32.const 1)))
                  (local.set $cnt  (i32.const 0))
                  (loop $loop1
                        (if (ref.eq (local.get $cur) (global.get $null))
                            (then (return (ref.i31 (i32.shl (local.get $cnt) (i32.const 1)))))
                            (else))
                        (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                            (then (call $raise-pair-expected/who
                                        (global.get $symbol:count)
                                        (local.get $cur))
                                  (unreachable))
                            (else))
                        (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                        (array.set $Args (local.get $call) (i32.const 0)
                                   (struct.get $Pair $a (local.get $pair)))
                        (local.set $cur (struct.get $Pair $d (local.get $pair)))
                        (local.set $r
                                   (call_ref $ProcedureInvoker
                                             (local.get $f)
                                             (local.get $call)
                                             (local.get $finv)))
                        (if (i32.eqz (ref.eq (local.get $r) (global.get $false)))
                            (then (local.set $cnt (i32.add (local.get $cnt) (i32.const 1))))
                            (else))
                        (br $loop1))
                  (unreachable))
                 (else
                  ;; General case for multiple lists
                  ;; 3) Allocate arrays for list cursors and call arguments; seed list cursors from xss
                  (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
                  (local.set $call  (array.new $Args (global.get $null) (local.get $nlists)))
                  (call $seed-list-args (local.get $xss) (local.get $lists))

                  ;; 4) Main loop: stop at the shortest list
                  (local.set $cnt (i32.const 0))
                  (loop $loop2
                        ;; (a) Check state of all lists; determine if we stop
                        (local.set $i (i32.const 0))
                        (block $check_done
                               (loop $check
                                     (if (i32.ge_u (local.get $i) (local.get $nlists))
                                         (then (br $check_done))
                                         (else))
                                     (local.set $cur (array.get $Args (local.get $lists) (local.get $i)))
                                     (if (ref.eq (local.get $cur) (global.get $null))
                                         (then (return (ref.i31 (i32.shl (local.get $cnt) (i32.const 1)))))
                                         (else
                                          (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                                              (then (call $raise-pair-expected/who
                                                          (global.get $symbol:count)
                                                          (local.get $cur))
                                                    (unreachable))
                                              (else))))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $check)))

                        ;; (b) Build call args for f: cars of each list and advance lists
                        (local.set $i (i32.const 0))
                        (block $cars_done
                               (loop $cars
                                     (if (i32.ge_u (local.get $i) (local.get $nlists))
                                         (then (br $cars_done))
                                         (else))
                                     (local.set $pair
                                                (ref.cast (ref $Pair)
                                                          (array.get $Args (local.get $lists) (local.get $i))))
                                     (array.set $Args
                                                (local.get $call) (local.get $i)
                                                (struct.get $Pair $a (local.get $pair)))
                                     (array.set $Args
                                                (local.get $lists) (local.get $i)
                                                (struct.get $Pair $d (local.get $pair)))
                                     (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                     (br $cars)))

                        ;; (c) Apply f to those cars
                        (local.set $r
                                   (call_ref $ProcedureInvoker
                                             (local.get $f)
                                             (local.get $call)
                                             (local.get $finv)))

                        ;; (d) Increment count if result is truthy
                        (if (i32.eqz (ref.eq (local.get $r) (global.get $false)))
                            (then (local.set $cnt (i32.add (local.get $cnt) (i32.const 1))))
                            (else))

                        (br $loop2))
                  (unreachable)))
             (unreachable))))

    ;; foldl : general entry point that dispatches to helpers
    ;; foldl : procedure? any/c list? list? ... -> any/c
    ;;   Dispatch foldl by list arity.
    (core-runtime-helper
     '$foldl
     "$foldl"
     (lambda ()
       `(func $foldl (type $Prim>=3)
             (param $proc (ref eq))   ;; procedure
             (param $init (ref eq))   ;; initial accumulator
             (param $xs   (ref eq))   ;; first list
             (param $rest (ref eq))   ;; remaining lists
             (result      (ref eq))

             (local $xss   (ref eq))
             (local $nlists i32)
             (local $ys    (ref eq))
             (local $outer (ref null $Pair))

             ;; Combine first list with remaining lists.
             ;; Use cons here: $rest is already the list of remaining list-arguments.
             ;; Calling list* here would treat the last list argument as final tail.
             (local.set $xss (call $cons (local.get $xs) (local.get $rest)))
             (local.set $ys  (global.get $null))

             ;; Walk outer list xss to count #lists; capture second list
             (local.set $nlists (call $validate-list-args
                                      (global.get $symbol:foldl)
                                      (local.get $xss)))

             (if (i32.ge_u (local.get $nlists) (i32.const 2))
                 (then (local.set $outer (ref.cast (ref $Pair) (local.get $xss)))
                       (local.set $outer
                                  (ref.cast (ref $Pair)
                                            (struct.get $Pair $d (local.get $outer))))
                       (local.set $ys    (struct.get $Pair $a (local.get $outer)))))

             ;; Racket's foldl requires at least one list argument
             (if (i32.eq (local.get $nlists) (i32.const 0))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:foldl))
                             (i32.const 1))
                       (unreachable)))

             ;; Dispatch based on number of lists
             (if (i32.eq (local.get $nlists) (i32.const 1))
                 (then (return (call $foldl/1 (local.get $proc)
                                     (local.get $init)
                                     (local.get $xs)))))
             (if (i32.eq (local.get $nlists) (i32.const 2))
                 (then (return (call $foldl/2 (local.get $proc)
                                     (local.get $init)
                                     (local.get $xs)
                                     (local.get $ys)))))

             (call $foldl/n (local.get $proc) (local.get $init) (local.get $xss)))))

    ;; foldl/1 : (X Acc -> Acc) Acc (Listof X) -> Acc
    ;; foldl/1 : procedure? any/c list? -> any/c
    ;;   Fold left over one list.
    (core-runtime-helper
     '$foldl/1
     "$foldl/1"
     (lambda ()
       `(func $foldl/1 (type $Prim3)
             (param $proc (ref eq))   ;; procedure
             (param $acc  (ref eq))   ;; initial accumulator
             (param $xs   (ref eq))   ;; list
             (result      (ref eq))

             (local $f    (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))
             (local $pair (ref $Pair))
             (local $elem (ref eq))
             (local $call (ref $Args))
             (local $r    (ref eq))

             ;; Ensure $proc is a procedure and fetch its invoker
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:foldl)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; Prepare argument array for procedure
             (local.set $call (array.new_fixed $Args 2 (global.get $null) (global.get $null)))

             ;; Iterate through list
             (loop $loop
                   (if (ref.eq (local.get $xs) (global.get $null))
                       (then (return (local.get $acc))))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                       (then (call $raise-pair-expected/who
                                   (global.get $symbol:foldl)
                                   (local.get $xs))
                             (unreachable)))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $xs)))
                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                   (array.set $Args (local.get $call) (i32.const 0) (local.get $elem))
                   (array.set $Args (local.get $call) (i32.const 1) (local.get $acc))
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))
                   (local.set $acc (local.get $r))
                   (local.set $xs (struct.get $Pair $d (local.get $pair)))
                   (br $loop))
             (unreachable))))

    ;; foldl/2 : (X Y Acc -> Acc) Acc (Listof X) (Listof Y) -> Acc
    ;; foldl/2 : procedure? any/c list? list? -> any/c
    ;;   Fold left over two lists.
    (core-runtime-helper
     '$foldl/2
     "$foldl/2"
     (lambda ()
       `(func $foldl/2 (type $Prim4)
             (param $proc (ref eq))   ;; procedure
             (param $acc  (ref eq))   ;; initial accumulator
             (param $xs   (ref eq))   ;; first list
             (param $ys   (ref eq))   ;; second list
             (result      (ref eq))

             (local $f     (ref $Procedure))
             (local $finv  (ref $ProcedureInvoker))
             (local $pairx (ref $Pair))
             (local $pairy (ref $Pair))
             (local $call  (ref $Args))
             (local $r     (ref eq))

             ;; Ensure $proc is a procedure and fetch its invoker
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:foldl)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; Prepare argument array for procedure
             (local.set $call (array.new_fixed $Args 3 (global.get $null) (global.get $null) (global.get $null)))

             ;; Iterate through both lists in lockstep; stop at shortest
             (loop $loop
                   (if (i32.or (ref.eq (local.get $xs) (global.get $null))
                               (ref.eq (local.get $ys) (global.get $null)))
                       (then (return (local.get $acc))))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                       (then (call $raise-pair-expected/who
                                   (global.get $symbol:foldl)
                                   (local.get $xs))
                             (unreachable)))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $ys)))
                       (then (call $raise-pair-expected/who
                                   (global.get $symbol:foldl)
                                   (local.get $ys))
                             (unreachable)))
                   (local.set $pairx (ref.cast (ref $Pair) (local.get $xs)))
                   (local.set $pairy (ref.cast (ref $Pair) (local.get $ys)))
                   (array.set $Args (local.get $call) (i32.const 0)
                              (struct.get $Pair $a (local.get $pairx)))
                   (array.set $Args (local.get $call) (i32.const 1)
                              (struct.get $Pair $a (local.get $pairy)))
                   (array.set $Args (local.get $call) (i32.const 2) (local.get $acc))
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))
                   (local.set $acc (local.get $r))
                   (local.set $xs (struct.get $Pair $d (local.get $pairx)))
                   (local.set $ys (struct.get $Pair $d (local.get $pairy)))
                   (br $loop))
             (unreachable))))

    ;; foldl/n : (X1 X2 ... Xn Acc -> Acc) Acc (Listof X1) ... (Listof Xn) -> Acc
    ;; foldl/n : procedure? any/c args? -> any/c
    ;;   Fold left over three or more lists.
    (core-runtime-helper
     '$foldl/n
     "$foldl/n"
     (lambda ()
       `(func $foldl/n (type $Prim>=2)
             (param $proc (ref eq))   ;; procedure
             (param $acc  (ref eq))   ;; initial accumulator
             (param $xss  (ref eq))   ;; list of lists
             (result      (ref eq))

             (local $f      (ref $Procedure))
             (local $finv   (ref $ProcedureInvoker))
             (local $pair   (ref $Pair))
             (local $nlists i32)

             (local $lists  (ref $Args))
             (local $call   (ref $Args))
             (local $i      i32)
             (local $cur    (ref eq))
             (local $stop   i32)
             (local $r      (ref eq))

             ;; Check that $proc is a procedure and fetch its invoker
             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:foldl)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             ;; Walk outer list xss to count #lists; ensure xss is proper and each element is a list head
             (local.set $nlists (call $validate-list-args
                                      (global.get $symbol:foldl)
                                      (local.get $xss)))

             ;; Racket's foldl requires at least one list argument
             (if (i32.eq (local.get $nlists) (i32.const 0))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:foldl))
                             (i32.const 1))
                       (unreachable)))

             ;; Allocate arrays for list cursors and call arguments (extra slot for accumulator)
             (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
             (local.set $call  (array.new $Args (global.get $null)
                                          (i32.add (local.get $nlists) (i32.const 1))))

             ;; Seed list cursors from xss
             (call $seed-list-args (local.get $xss) (local.get $lists))

             ;; Main loop: stop at the shortest list
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
                                                     (global.get $symbol:foldl)
                                                     (local.get $cur))
                                               (unreachable)))))
                                (local.set $i (i32.add (local.get $i) (i32.const 1)))
                                (br $check)))

                   ;; If any list is empty → return accumulator
                   (if (i32.ne (local.get $stop) (i32.const 0))
                       (then (return (local.get $acc))))

                   ;; (b) Build call args for f: cars of each list + accumulator
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
                   (array.set $Args (local.get $call) (local.get $nlists) (local.get $acc))

                   ;; (c) Apply f and update accumulator
                   (local.set $r
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $call)
                                        (local.get $finv)))
                   (local.set $acc (local.get $r))

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
             (unreachable))))

    ;; foldr : procedure? any/c list? list? ... -> any/c
    ;;   Dispatch foldr by list arity.
    (core-runtime-helper
     '$foldr
     "$foldr"
     (lambda ()
       `(func $foldr (type $Prim>=3)
            (param $proc (ref eq))   ;; procedure
            (param $init (ref eq))   ;; initial value
            (param $xs   (ref eq))   ;; first list
            (param $rest (ref eq))   ;; remaining lists
            (result      (ref eq))

            (local $pair  (ref $Pair))
            (local $ys    (ref eq))
            (local $rest2 (ref eq))
            (local $xss   (ref eq))

            ;; Combine first list with remaining lists for n-ary case.
            ;; Use cons for the same reason as in foldl.
            (local.set $xss (call $cons (local.get $xs) (local.get $rest)))

            ;; Single list case
            (if (ref.eq (local.get $rest) (global.get $null))
                (then (return (call $foldr/1 (local.get $proc) (local.get $init)
                                    (local.get $xs)))))

            ;; Two-list case
            (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                (then (call $raise-pair-expected/who
                            (global.get $symbol:foldr)
                            (local.get $rest))
                      (unreachable)))
            (local.set $pair  (ref.cast (ref $Pair) (local.get $rest)))
            (local.set $ys    (struct.get $Pair $a (local.get $pair)))
            (local.set $rest2 (struct.get $Pair $d (local.get $pair)))

            (if (ref.eq (local.get $rest2) (global.get $null))
                (then (return (call $foldr/2 (local.get $proc) (local.get $init)
                                    (local.get $xs) (local.get $ys)))))

            ;; N-ary case
            (call $foldr/n (local.get $proc) (local.get $init) (local.get $xss)))))

    ;; foldr/1-loop : procedure? procedure-invoker? args? list? any/c -> any/c
    ;;   Recursive foldr loop over one list.
    (core-runtime-helper
     '$foldr/1-loop
     "$foldr/1-loop"
     (lambda ()
       `(func $foldr/1-loop
             (param $f    (ref $Procedure))
             (param $finv (ref $ProcedureInvoker))
             (param $init (ref eq))
             (param $xs   (ref eq))
             (result      (ref eq))

             (local $pair (ref $Pair))
             (local $call (ref $Args))
             (local $rest (ref eq))

             (if (ref.eq (local.get $xs) (global.get $null))
                 (then (return (local.get $init))))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                 (then (call $raise-pair-expected/who
                             (global.get $symbol:foldr)
                             (local.get $xs))
                       (unreachable)))
             (local.set $pair (ref.cast (ref $Pair) (local.get $xs)))
             (local.set $rest
                        (call $foldr/1-loop
                              (local.get $f) (local.get $finv) (local.get $init)
                              (struct.get $Pair $d (local.get $pair))))
             (local.set $call
                        (array.new_fixed $Args 2
                                         (struct.get $Pair $a (local.get $pair))
                                         (local.get $rest)))
             (call_ref $ProcedureInvoker
                       (local.get $f)
                       (local.get $call)
                       (local.get $finv)))))

    ;; foldr/1 : procedure? any/c list? -> any/c
    ;;   Fold right over one list.
    (core-runtime-helper
     '$foldr/1
     "$foldr/1"
     (lambda ()
       `(func $foldr/1
             (param $proc (ref eq))   ;; procedure
             (param $init (ref eq))   ;; initial value
             (param $xs   (ref eq))   ;; list
             (result      (ref eq))

             (local $f    (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))

             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:foldr)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
             (call $foldr/1-loop (local.get $f) (local.get $finv)
                   (local.get $init) (local.get $xs)))))

    ;; foldr/2-loop : procedure? procedure-invoker? args? list? list? any/c -> any/c
    ;;   Recursive foldr loop over two lists.
    (core-runtime-helper
     '$foldr/2-loop
     "$foldr/2-loop"
     (lambda ()
       `(func $foldr/2-loop
             (param $f    (ref $Procedure))
             (param $finv (ref $ProcedureInvoker))
             (param $init (ref eq))
             (param $xs   (ref eq))
             (param $ys   (ref eq))
             (result      (ref eq))

             (local $px   (ref $Pair))
             (local $py   (ref $Pair))
             (local $call (ref $Args))
             (local $rest (ref eq))

             (if (i32.or (ref.eq (local.get $xs) (global.get $null))
                         (ref.eq (local.get $ys) (global.get $null)))
                 (then (return (local.get $init))))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $xs)))
                 (then (call $raise-pair-expected/who
                             (global.get $symbol:foldr)
                             (local.get $xs))
                       (unreachable)))
             (if (i32.eqz (ref.test (ref $Pair) (local.get $ys)))
                 (then (call $raise-pair-expected/who
                             (global.get $symbol:foldr)
                             (local.get $ys))
                       (unreachable)))
             (local.set $px (ref.cast (ref $Pair) (local.get $xs)))
             (local.set $py (ref.cast (ref $Pair) (local.get $ys)))
             (local.set $rest
                        (call $foldr/2-loop (local.get $f) (local.get $finv)
                              (local.get $init)
                              (struct.get $Pair $d (local.get $px))
                              (struct.get $Pair $d (local.get $py))))
             (local.set $call
                        (array.new_fixed $Args 3
                                         (struct.get $Pair $a (local.get $px))
                                         (struct.get $Pair $a (local.get $py))
                                         (local.get $rest)))
             (call_ref $ProcedureInvoker
                       (local.get $f)
                       (local.get $call)
                       (local.get $finv)))))

    ;; foldr/2 : procedure? any/c list? list? -> any/c
    ;;   Fold right over two lists.
    (core-runtime-helper
     '$foldr/2
     "$foldr/2"
     (lambda ()
       `(func $foldr/2
             (param $proc (ref eq))   ;; procedure
             (param $init (ref eq))   ;; initial value
             (param $xs   (ref eq))   ;; list X
             (param $ys   (ref eq))   ;; list Y
             (result (ref eq))

             (local $f    (ref $Procedure))
             (local $finv (ref $ProcedureInvoker))

             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:foldr)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))
             (call $foldr/2-loop (local.get $f) (local.get $finv)
                   (local.get $init)
                   (local.get $xs) (local.get $ys)))))

    ;; foldr/n-loop : procedure? procedure-invoker? args? args? any/c -> any/c
    ;;   Recursive foldr loop over three or more lists.
    (core-runtime-helper
     '$foldr/n-loop
     "$foldr/n-loop"
     (lambda ()
       `(func $foldr/n-loop
             (param $f     (ref $Procedure))
             (param $finv  (ref $ProcedureInvoker))
             (param $lists (ref $Args))
             (param $nlists i32)
             (param $init  (ref eq))
             (result (ref eq))

             (local $i     i32)
             (local $cur   (ref eq))
             (local $tails (ref $Args))
             (local $call  (ref $Args))
             (local $pair  (ref $Pair))
             (local $rest  (ref eq))

             ;; Check for empty lists
             (local.set $i (i32.const 0))
             (block $check_done
                    (loop $check
                          (if (i32.ge_u (local.get $i) (local.get $nlists))
                              (then (br $check_done)))
                          (local.set $cur (array.get $Args (local.get $lists) (local.get $i)))
                          (if (ref.eq (local.get $cur) (global.get $null))
                              (then (return (local.get $init))))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                              (then (call $raise-pair-expected/who
                                          (global.get $symbol:foldr)
                                          (local.get $cur))
                                    (unreachable)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $check)))

             ;; Build tails and call arrays
             (local.set $tails (array.new $Args (global.get $null) (local.get $nlists)))
             (local.set $call  (array.new $Args (global.get $null)
                                          (i32.add (local.get $nlists) (i32.const 1))))
             (local.set $i (i32.const 0))
             (block $build_done
                    (loop $build
                          (if (i32.ge_u (local.get $i) (local.get $nlists))
                              (then (br $build_done)))
                          (local.set $pair
                                     (ref.cast (ref $Pair)
                                               (array.get $Args (local.get $lists) (local.get $i))))
                          (array.set $Args (local.get $call) (local.get $i)
                                     (struct.get $Pair $a (local.get $pair)))
                          (array.set $Args (local.get $tails) (local.get $i)
                                     (struct.get $Pair $d (local.get $pair)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $build)))

             ;; Recursive call on tails
             (local.set $rest
                        (call $foldr/n-loop (local.get $f) (local.get $finv)
                              (local.get $tails) (local.get $nlists)
                              (local.get $init)))
             (array.set $Args (local.get $call) (local.get $nlists) (local.get $rest))
             (call_ref $ProcedureInvoker
                       (local.get $f)
                       (local.get $call)
                       (local.get $finv)))))

    ;; foldr/n : procedure? any/c args? -> any/c
    ;;   Fold right over three or more lists.
    (core-runtime-helper
     '$foldr/n
     "$foldr/n"
     (lambda ()
       `(func $foldr/n
             (param $proc (ref eq))   ;; procedure
             (param $init (ref eq))   ;; initial value
             (param $xss  (ref eq))   ;; list of lists
             (result (ref eq))

             (local $f      (ref $Procedure))
             (local $finv   (ref $ProcedureInvoker))
             (local $outer  (ref eq))
             (local $pair   (ref $Pair))
             (local $elem   (ref eq))
             (local $nlists i32)
             (local $lists  (ref $Args))
             (local $i      i32)

             (if (ref.eq (call $procedure? (local.get $proc))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:foldr)
                             (local.get $proc))
                       (unreachable)))
             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $finv (struct.get $Procedure $invoke (local.get $f)))

             (if (ref.eq (local.get $xss) (global.get $null))
                 (then (call $primitive-invoke:raise-arity-error
                             (ref.cast (ref $PrimitiveProcedure)
                                       (global.get $prim:foldr))
                             (i32.const 1))
                       (unreachable)))

             ;; Count lists
             (local.set $nlists (i32.const 0))
             (local.set $outer  (local.get $xss))
             (block $count_done
                    (loop $count
                          (if (ref.eq (local.get $outer) (global.get $null))
                              (then (br $count_done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $outer)))
                              (then (call $raise-pair-expected/who
                                          (global.get $symbol:foldr)
                                          (local.get $outer))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $outer)))
                          (local.set $elem (struct.get $Pair $a (local.get $pair)))
                          (if (i32.eqz (i32.or (ref.eq (local.get $elem) (global.get $null))
                                               (ref.test (ref $Pair) (local.get $elem))))
                              (then (call $raise-pair-expected/who
                                          (global.get $symbol:foldr)
                                          (local.get $elem))
                                    (unreachable)))
                          (local.set $nlists (i32.add (local.get $nlists) (i32.const 1)))
                          (local.set $outer (struct.get $Pair $d (local.get $pair)))
                          (br $count)))

             (local.set $lists (array.new $Args (global.get $null) (local.get $nlists)))
             (local.set $outer (local.get $xss))
             (local.set $i (i32.const 0))
             (block $seed_done
                    (loop $seed
                          (if (i32.ge_u (local.get $i) (local.get $nlists))
                              (then (br $seed_done)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $outer)))
                          (array.set $Args (local.get $lists) (local.get $i)
                                     (struct.get $Pair $a (local.get $pair)))
                          (local.set $outer (struct.get $Pair $d (local.get $pair)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $seed)))

             (call $foldr/n-loop (local.get $f) (local.get $finv)
                   (local.get $lists) (local.get $nlists)
                   (local.get $init)))))

    ;; raise-take:bad-length : list? i32 -> none
    ;;   Report that take asked for too many elements.
    (core-runtime-helper
     '$raise-take:bad-length
     "$raise-take:bad-length"
     (lambda ()
       `(func $raise-take:bad-length
             (param $xs  (ref eq))
             (param $n   i32)
             (param $len i32)
             (call $raise-take:bad-length/who
                   (global.get $symbol:take)
                   (local.get $xs)
                   (local.get $n)
                   (local.get $len)))))

    ;; raise-take:bad-length/who : symbol? list? i32 -> none
    ;;   Report a take-style length error with who.
    (core-runtime-helper
     '$raise-take:bad-length/who
     "$raise-take:bad-length/who"
     (lambda ()
       `(func $raise-take:bad-length/who
             (param $who (ref eq))
             (param $xs  (ref eq))
             (param $n   i32)
             (param $len i32)
             (call $raise-list-not-enough-elements/who
                   (local.get $who)
                   (local.get $xs)
                   (local.get $n)
                   (local.get $len)))))

    ;; raise-take-right:bad-length : list? i32 -> none
    ;;   Report that take-right asked for too many elements.
    (core-runtime-helper
     '$raise-take-right:bad-length
     "$raise-take-right:bad-length"
     (lambda ()
       `(func $raise-take-right:bad-length
             (param $xs  (ref eq))
             (param $n   i32)
             (param $len i32)
             (call $raise-take-right:bad-length/who
                   (global.get $symbol:take-right)
                   (local.get $xs)
                   (local.get $n)
                   (local.get $len)))))

    ;; raise-take-right:bad-length/who : symbol? list? i32 -> none
    ;;   Report a take-right-style length error with who.
    (core-runtime-helper
     '$raise-take-right:bad-length/who
     "$raise-take-right:bad-length/who"
     (lambda ()
       `(func $raise-take-right:bad-length/who
             (param $who (ref eq))
             (param $xs  (ref eq))
             (param $n   i32)
             (param $len i32)
             (call $raise-list-not-enough-elements/who
                   (local.get $who)
                   (local.get $xs)
                   (local.get $n)
                   (local.get $len)))))

    ;; take/who : symbol? list? exact-nonnegative-integer? -> list?
    ;;   Return the first n elements of a list, reporting errors with who.
    (core-runtime-helper
     '$take/who
     "$take/who"
     (lambda ()
       `(func $take/who
             (param $who   (ref eq))
             (param $xs    (ref eq))
             (param $n/fx  (ref eq))
             (result       (ref eq))

             (local $count      i32)
             (local $orig-count i32)
             (local $taken      i32)
             (local $cur        (ref eq))
             (local $pair       (ref $Pair))
             (local $elem       (ref eq))
             (local $acc        (ref eq))

             (if (ref.test (ref i31) (local.get $n/fx))
                 (then (local.set $count (i31.get_s (ref.cast (ref i31) (local.get $n/fx))))
                       (if (i32.ne (i32.and (local.get $count) (i32.const 1)) (i32.const 0))
                           (then (call $raise-exact-nonnegative-integer-expected/who
                                       (local.get $who)
                                       (local.get $n/fx))
                                 (unreachable)))
                       (local.set $count (i32.shr_s (local.get $count) (i32.const 1))))
                 (else (call $raise-exact-nonnegative-integer-expected/who
                             (local.get $who)
                             (local.get $n/fx))
                       (unreachable)))
             (if (i32.lt_s (local.get $count) (i32.const 0))
                 (then (call $raise-exact-nonnegative-integer-expected/who
                             (local.get $who)
                             (local.get $n/fx))
                       (unreachable)))

             (local.set $orig-count (local.get $count))

             (if (i32.eqz (local.get $count))
                 (then (return (global.get $null))))

             (local.set $cur  (local.get $xs))
             (local.set $pair (global.get $dummy-pair))
             (local.set $acc  (global.get $null))
             (local.set $taken (i32.const 0))

             (loop $loop
                   (if (i32.eqz (local.get $count))
                       (then (return (call $reverse (local.get $acc)))))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                       (then (call $raise-take:bad-length/who
                                   (local.get $who)
                                   (local.get $xs)
                                   (local.get $orig-count)
                                   (local.get $taken))
                             (unreachable)))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                   (local.set $acc  (call $cons (local.get $elem) (local.get $acc)))
                   (local.set $cur  (struct.get $Pair $d (local.get $pair)))
                   (local.set $count (i32.sub (local.get $count) (i32.const 1)))
                   (local.set $taken (i32.add (local.get $taken) (i32.const 1)))
                   (br $loop))
             (unreachable))))

    ;; take : list? exact-nonnegative-integer? -> list?
    ;;   Return the first n elements of a list.
    (core-runtime-helper
     '$take
     "$take"
     (lambda ()
       `(func $take (type $Prim2)
             (param $xs   (ref eq))
             (param $n/fx (ref eq))
             (result      (ref eq))
             (call $take/who
                   (global.get $symbol:take)
                   (local.get $xs)
                   (local.get $n/fx)))))

    ;; take-right/who : symbol? list? exact-nonnegative-integer? -> list?
    ;;   Return the last n elements of a list, reporting errors with who.
    (core-runtime-helper
     '$take-right/who
     "$take-right/who"
     (lambda ()
       `(func $take-right/who
             (param $who   (ref eq))
             (param $xs    (ref eq))
             (param $n/fx  (ref eq))
             (result       (ref eq))

             (local $count      i32)
             (local $orig-count i32)
             (local $remaining  i32)
             (local $available  i32)
             (local $lead       (ref eq))
             (local $lag        (ref eq))
             (local $pair       (ref $Pair))
             (local $lag-pair   (ref $Pair))

             (if (ref.test (ref i31) (local.get $n/fx))
                 (then (local.set $count (i31.get_s (ref.cast (ref i31) (local.get $n/fx))))
                       (if (i32.ne (i32.and (local.get $count) (i32.const 1)) (i32.const 0))
                           (then (call $raise-exact-nonnegative-integer-expected/who
                                       (local.get $who)
                                       (local.get $n/fx))
                                 (unreachable)))
                       (local.set $count (i32.shr_s (local.get $count) (i32.const 1))))
                 (else (call $raise-exact-nonnegative-integer-expected/who
                             (local.get $who)
                             (local.get $n/fx))
                       (unreachable)))
             (if (i32.lt_s (local.get $count) (i32.const 0))
                 (then (call $raise-exact-nonnegative-integer-expected/who
                             (local.get $who)
                             (local.get $n/fx))
                       (unreachable)))

             (local.set $orig-count (local.get $count))

             (if (i32.eqz (local.get $count))
                 (then (return (local.get $xs))))

             (local.set $lead      (local.get $xs))
             (local.set $remaining (local.get $count))
             (local.set $available (i32.const 0))
             (local.set $pair      (global.get $dummy-pair))
             (local.set $lag-pair  (global.get $dummy-pair))

             (block $advance-done
                    (loop $advance
                          (if (i32.eqz (local.get $remaining))
                              (then (br $advance-done)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $lead)))
                              (then (call $raise-take-right:bad-length/who
                                          (local.get $who)
                                          (local.get $xs)
                                          (local.get $orig-count)
                                          (local.get $available))
                                    (unreachable)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $lead)))
                          (local.set $lead (struct.get $Pair $d (local.get $pair)))
                          (local.set $remaining (i32.sub (local.get $remaining) (i32.const 1)))
                          (local.set $available (i32.add (local.get $available) (i32.const 1)))
                          (br $advance)))

             (local.set $lag (local.get $xs))

             (loop $slide
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $lead)))
                       (then (return (local.get $lag))))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $lead)))
                   (local.set $lag-pair (ref.cast (ref $Pair) (local.get $lag)))
                   (local.set $lead (struct.get $Pair $d (local.get $pair)))
                   (local.set $lag  (struct.get $Pair $d (local.get $lag-pair)))
                   (br $slide))
             (unreachable))))

    ;; take-right : list? exact-nonnegative-integer? -> list?
    ;;   Return the last n elements of a list.
    (core-runtime-helper
     '$take-right
     "$take-right"
     (lambda ()
       `(func $take-right (type $Prim2)
             (param $xs   (ref eq))
             (param $n/fx (ref eq))
             (result      (ref eq))
             (call $take-right/who
                   (global.get $symbol:take-right)
                   (local.get $xs)
                   (local.get $n/fx)))))

    ;; takef : list? procedure? -> list?
    ;;   Return the longest prefix accepted by a predicate.
    (core-runtime-helper
     '$takef
     "$takef"
     (lambda ()
       `(func $takef (type $Prim2)
             (param $xs   (ref eq))
             (param $proc (ref eq))
             (result      (ref eq))

             (local $f    (ref $Procedure))
             (local $inv  (ref $ProcedureInvoker))
             (local $args (ref $Args))
             (local $res  (ref eq))
             (local $cur  (ref eq))
             (local $pair (ref $Pair))
             (local $elem (ref eq))
             (local $acc  (ref eq))

            (if (ref.eq (call $procedure? (local.get $proc))
                        (global.get $false))
                 (then (call $raise-argument-error/position
                             (global.get $symbol:takef)
                             (global.get $string:list-procedure)
                             (i32.const 1)
                             (local.get $proc)
                             (array.new_fixed $Args 2
                                              (local.get $xs)
                                              (local.get $proc)))
                       (unreachable)))

             (local.set $f   (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $inv (struct.get $Procedure $invoke (local.get $f)))
             (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

             (local.set $cur  (local.get $xs))
             (local.set $pair (global.get $dummy-pair))
             (local.set $acc  (global.get $null))

             (loop $loop
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                       (then (return (call $reverse (local.get $acc)))))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                   (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                   (local.set $res
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $args)
                                        (local.get $inv)))
                   (if (ref.eq (local.get $res) (global.get $false))
                       (then (return (call $reverse (local.get $acc)))))
                   (local.set $acc (call $cons (local.get $elem) (local.get $acc)))
                   (local.set $cur (struct.get $Pair $d (local.get $pair)))
                   (br $loop))
             (unreachable))))

    ;; takef-right : list? procedure? -> list?
    ;;   Return the longest suffix accepted by a predicate.
    (core-runtime-helper
     '$takef-right
     "$takef-right"
     (lambda ()
       `(func $takef-right (type $Prim2)
             (param $xs   (ref eq))
             (param $proc (ref eq))
             (result      (ref eq))

             (local $f      (ref $Procedure))
             (local $inv    (ref $ProcedureInvoker))
             (local $args   (ref $Args))
             (local $res    (ref eq))
             (local $cur    (ref eq))
             (local $pair   (ref $Pair))
             (local $elem   (ref eq))
             (local $suffix (ref eq))

            (if (ref.eq (call $procedure? (local.get $proc))
                        (global.get $false))
                 (then (call $raise-argument-error/position
                             (global.get $symbol:takef-right)
                             (global.get $string:list-procedure)
                             (i32.const 1)
                             (local.get $proc)
                             (array.new_fixed $Args 2
                                              (local.get $xs)
                                              (local.get $proc)))
                       (unreachable)))

             (local.set $f    (ref.cast (ref $Procedure) (local.get $proc)))
             (local.set $inv  (struct.get $Procedure $invoke (local.get $f)))
             (local.set $args (array.new $Args (global.get $null) (i32.const 1)))

             (local.set $cur    (local.get $xs))
             (local.set $pair   (global.get $dummy-pair))
             (local.set $suffix (local.get $xs))

             (loop $loop
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $cur)))
                       (then (return (local.get $suffix))))
                   (local.set $pair (ref.cast (ref $Pair) (local.get $cur)))
                   (local.set $elem (struct.get $Pair $a (local.get $pair)))
                   (array.set $Args (local.get $args) (i32.const 0) (local.get $elem))
                   (local.set $res
                              (call_ref $ProcedureInvoker
                                        (local.get $f)
                                        (local.get $args)
                                        (local.get $inv)))
                   (if (ref.eq (local.get $res) (global.get $false))
                       (then (local.set $suffix (struct.get $Pair $d (local.get $pair)))))
                   (local.set $cur (struct.get $Pair $d (local.get $pair)))
                   (br $loop))
             (unreachable))))

    ;; list-prefix? : list? list? procedure? -> boolean?
    ;;   Check whether one list is a prefix of another.
    (core-runtime-helper
     '$list-prefix?
     "$list-prefix?"
     (lambda ()
       `(func $list-prefix? (type $Prim23)
             (param $l     (ref eq)) ; list
             (param $r     (ref eq)) ; list
             (param $same? (ref eq)) ; optional, defaults to equal?
             (result       (ref eq))

             (local $lcur   (ref eq))
             (local $rcur   (ref eq))
             (local $lpair  (ref $Pair))
             (local $rpair  (ref $Pair))
             (local $lelem  (ref eq))
             (local $relem  (ref eq))
             (local $args   (ref $Args))
             (local $res    (ref eq))
             (local $use-proc i32)

             ;; Handle optional comparator
             (if (ref.eq (local.get $same?) (global.get $missing))
                 (then (local.set $use-proc (i32.const 0)))
                 (else
                  (if (ref.eq (call $procedure? (local.get $same?))
                              (global.get $false))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:list-prefix?)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable))
                      (else))
                  (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                     (ref.cast (ref $Procedure) (local.get $same?))
                                     (i32.const 2)))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:list-prefix?)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable)))
                  (local.set $use-proc (i32.const 1))))

             (if (ref.eq (call $list? (local.get $l)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:list-prefix?)
                             (global.get $string:list?)
                             (local.get $l))
                       (unreachable)))
             (if (ref.eq (call $list? (local.get $r)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:list-prefix?)
                             (global.get $string:list?)
                             (local.get $r))
                       (unreachable)))

             ;; Iterate through lists
             (local.set $lcur (local.get $l))
             (local.set $rcur (local.get $r))
             (loop $loop
                   (if (ref.eq (local.get $lcur) (global.get $null))
                       (then (return (global.get $true))))
                   (if (ref.eq (local.get $rcur) (global.get $null))
                       (then (return (global.get $false))))

                   (if (i32.eqz (ref.test (ref $Pair) (local.get $lcur)))
                       (then (call $raise-pair-expected (local.get $lcur))
                             (unreachable)))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $rcur)))
                       (then (call $raise-pair-expected (local.get $rcur))
                             (unreachable)))

                   (local.set $lpair (ref.cast (ref $Pair) (local.get $lcur)))
                   (local.set $rpair (ref.cast (ref $Pair) (local.get $rcur)))
                   (local.set $lelem (struct.get $Pair $a (local.get $lpair)))
                   (local.set $relem (struct.get $Pair $a (local.get $rpair)))

                   (block $same
                          (if (i32.eqz (local.get $use-proc))
                              (then
                               (if (ref.eq (call $equal? (local.get $lelem) (local.get $relem))
                                           (global.get $false))
                                   (then (return (global.get $false)))
                                   (else (br $same))))
                              (else
                               (local.set $res
                                          (call_ref $ProcedureInvoker
                                                    (ref.cast (ref $Procedure) (local.get $same?))
                                                    (block (result (ref $Args))
                                                           (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
                                                           (array.set $Args (local.get $args) (i32.const 0) (local.get $lelem))
                                                           (array.set $Args (local.get $args) (i32.const 1) (local.get $relem))
                                                           (local.get $args))
                                                    (struct.get $Procedure $invoke
                                                               (ref.cast (ref $Procedure) (local.get $same?)))))
                               (if (ref.eq (local.get $res) (global.get $false))
                                   (then (return (global.get $false)))
                                   (else (br $same))))))

                   (local.set $lcur (struct.get $Pair $d (local.get $lpair)))
                   (local.set $rcur (struct.get $Pair $d (local.get $rpair)))
                   (br $loop))
             (unreachable))))

    ;; take-common-prefix : list? list? procedure? -> list?
    ;;   Return the common prefix of two lists.
    (core-runtime-helper
     '$take-common-prefix
     "$take-common-prefix"
     (lambda ()
       `(func $take-common-prefix (type $Prim23)
             (param $l     (ref eq)) ; list
             (param $r     (ref eq)) ; list
             (param $same? (ref eq)) ; optional, defaults to equal?
             (result       (ref eq))

             (local $lcur   (ref eq))
             (local $rcur   (ref eq))
             (local $lpair  (ref $Pair))
             (local $rpair  (ref $Pair))
             (local $lelem  (ref eq))
             (local $relem  (ref eq))
             (local $acc    (ref eq))
             (local $args   (ref $Args))
             (local $res    (ref eq))
             (local $use-proc i32)

             ;; Handle optional comparator
             (if (ref.eq (local.get $same?) (global.get $missing))
                 (then (local.set $use-proc (i32.const 0)))
                 (else
                  (if (ref.eq (call $procedure? (local.get $same?))
                              (global.get $false))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:take-common-prefix)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable))
                      (else))
                  (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                     (ref.cast (ref $Procedure) (local.get $same?))
                                     (i32.const 2)))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:take-common-prefix)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable)))
                  (local.set $use-proc (i32.const 1))))

             (if (ref.eq (call $list? (local.get $l)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:take-common-prefix)
                             (global.get $string:list?)
                             (local.get $l))
                       (unreachable)))
             (if (ref.eq (call $list? (local.get $r)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:take-common-prefix)
                             (global.get $string:list?)
                             (local.get $r))
                       (unreachable)))

             ;; Iterate through lists, building accumulator
             (local.set $lcur (local.get $l))
             (local.set $rcur (local.get $r))
             (local.set $acc (global.get $null))
             (loop $loop
                   (if (ref.eq (local.get $lcur) (global.get $null))
                       (then (return (call $reverse (local.get $acc)))))
                   (if (ref.eq (local.get $rcur) (global.get $null))
                       (then (return (call $reverse (local.get $acc)))))

                   (if (i32.eqz (ref.test (ref $Pair) (local.get $lcur)))
                       (then (call $raise-pair-expected (local.get $lcur))
                             (unreachable)))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $rcur)))
                       (then (call $raise-pair-expected (local.get $rcur))
                             (unreachable)))

                   (local.set $lpair (ref.cast (ref $Pair) (local.get $lcur)))
                   (local.set $rpair (ref.cast (ref $Pair) (local.get $rcur)))
                   (local.set $lelem (struct.get $Pair $a (local.get $lpair)))
                   (local.set $relem (struct.get $Pair $a (local.get $rpair)))

                   (block $same
                          (if (i32.eqz (local.get $use-proc))
                              (then
                               (if (ref.eq (call $equal? (local.get $lelem) (local.get $relem))
                                           (global.get $false))
                                   (then (return (call $reverse (local.get $acc))))
                                   (else (br $same))))
                              (else
                               (local.set $res
                                          (call_ref $ProcedureInvoker
                                                    (ref.cast (ref $Procedure) (local.get $same?))
                                                    (block (result (ref $Args))
                                                           (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
                                                           (array.set $Args (local.get $args) (i32.const 0) (local.get $lelem))
                                                           (array.set $Args (local.get $args) (i32.const 1) (local.get $relem))
                                                           (local.get $args))
                                                    (struct.get $Procedure $invoke
                                                               (ref.cast (ref $Procedure) (local.get $same?)))))
                               (if (ref.eq (local.get $res) (global.get $false))
                                   (then (return (call $reverse (local.get $acc))))
                                   (else (br $same))))))

                   (local.set $acc (call $cons (local.get $lelem) (local.get $acc)))
                   (local.set $lcur (struct.get $Pair $d (local.get $lpair)))
                   (local.set $rcur (struct.get $Pair $d (local.get $rpair)))
                   (br $loop))
             (unreachable))))

    ;; drop-common-prefix : list? list? procedure? -> values?
    ;;   Return the remaining tails after dropping a common prefix.
    (core-runtime-helper
     '$drop-common-prefix
     "$drop-common-prefix"
     (lambda ()
       `(func $drop-common-prefix (type $Prim23)
             (param $l     (ref eq)) ; list
             (param $r     (ref eq)) ; list
             (param $same? (ref eq)) ; optional, defaults to equal?
             (result       (ref eq))

             (local $lcur   (ref eq))
             (local $rcur   (ref eq))
             (local $lpair  (ref $Pair))
             (local $rpair  (ref $Pair))
             (local $lelem  (ref eq))
             (local $relem  (ref eq))
             (local $args   (ref $Args))
             (local $res    (ref eq))
             (local $use-proc i32)

             ;; Handle optional comparator
             (if (ref.eq (local.get $same?) (global.get $missing))
                 (then (local.set $use-proc (i32.const 0)))
                 (else
                  (if (ref.eq (call $procedure? (local.get $same?))
                              (global.get $false))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:drop-common-prefix)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable))
                      (else))
                  (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                     (ref.cast (ref $Procedure) (local.get $same?))
                                     (i32.const 2)))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:drop-common-prefix)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable)))
                  (local.set $use-proc (i32.const 1))))

             (if (ref.eq (call $list? (local.get $l)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:drop-common-prefix)
                             (global.get $string:list?)
                             (local.get $l))
                       (unreachable)))
             (if (ref.eq (call $list? (local.get $r)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:drop-common-prefix)
                             (global.get $string:list?)
                             (local.get $r))
                       (unreachable)))

             ;; Iterate through lists, dropping common prefix
             (local.set $lcur (local.get $l))
             (local.set $rcur (local.get $r))
             (loop $loop
                   (if (ref.eq (local.get $lcur) (global.get $null))
                       (then (return (array.new_fixed $Values 2 (local.get $lcur) (local.get $rcur)))))
                   (if (ref.eq (local.get $rcur) (global.get $null))
                       (then (return (array.new_fixed $Values 2 (local.get $lcur) (local.get $rcur)))))

                   (if (i32.eqz (ref.test (ref $Pair) (local.get $lcur)))
                       (then (call $raise-pair-expected (local.get $lcur))
                             (unreachable)))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $rcur)))
                       (then (call $raise-pair-expected (local.get $rcur))
                             (unreachable)))

                   (local.set $lpair (ref.cast (ref $Pair) (local.get $lcur)))
                   (local.set $rpair (ref.cast (ref $Pair) (local.get $rcur)))
                   (local.set $lelem (struct.get $Pair $a (local.get $lpair)))
                   (local.set $relem (struct.get $Pair $a (local.get $rpair)))

                   (block $same
                          (if (i32.eqz (local.get $use-proc))
                              (then
                               (if (ref.eq (call $equal? (local.get $lelem) (local.get $relem))
                                           (global.get $false))
                                   (then (return (array.new_fixed $Values 2 (local.get $lcur) (local.get $rcur))))
                                   (else (br $same))))
                              (else
                               (local.set $res
                                          (call_ref $ProcedureInvoker
                                                    (ref.cast (ref $Procedure) (local.get $same?))
                                                    (block (result (ref $Args))
                                                           (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
                                                           (array.set $Args (local.get $args) (i32.const 0) (local.get $lelem))
                                                           (array.set $Args (local.get $args) (i32.const 1) (local.get $relem))
                                                           (local.get $args))
                                                    (struct.get $Procedure $invoke
                                                               (ref.cast (ref $Procedure) (local.get $same?)))))
                               (if (ref.eq (local.get $res) (global.get $false))
                                   (then (return (array.new_fixed $Values 2 (local.get $lcur) (local.get $rcur))))
                                   (else (br $same))))))

                   (local.set $lcur (struct.get $Pair $d (local.get $lpair)))
                   (local.set $rcur (struct.get $Pair $d (local.get $rpair)))
                   (br $loop))
             (unreachable))))

    ;; split-common-prefix : list? list? procedure? -> values?
    ;;   Return the common prefix and remaining tails.
    (core-runtime-helper
     '$split-common-prefix
     "$split-common-prefix"
     (lambda ()
       `(func $split-common-prefix (type $Prim23)
             (param $l     (ref eq)) ; list
             (param $r     (ref eq)) ; list
             (param $same? (ref eq)) ; optional, defaults to equal?
             (result       (ref eq))

             (local $lcur   (ref eq))
             (local $rcur   (ref eq))
             (local $lpair  (ref $Pair))
             (local $rpair  (ref $Pair))
             (local $lelem  (ref eq))
             (local $relem  (ref eq))
             (local $acc    (ref eq))
             (local $args   (ref $Args))
             (local $res    (ref eq))
             (local $use-proc i32)

             ;; Handle optional comparator
             (if (ref.eq (local.get $same?) (global.get $missing))
                 (then (local.set $use-proc (i32.const 0)))
                 (else
                  (if (ref.eq (call $procedure? (local.get $same?))
                              (global.get $false))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:split-common-prefix)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable))
                      (else))
                  (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                     (ref.cast (ref $Procedure) (local.get $same?))
                                     (i32.const 2)))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:split-common-prefix)
                                  (global.get $string:list-binary-comparator)
                                  (local.get $same?))
                            (unreachable)))
                  (local.set $use-proc (i32.const 1))))

             (if (ref.eq (call $list? (local.get $l)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:split-common-prefix)
                             (global.get $string:list?)
                             (local.get $l))
                       (unreachable)))
             (if (ref.eq (call $list? (local.get $r)) (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:split-common-prefix)
                             (global.get $string:list?)
                             (local.get $r))
                       (unreachable)))

             ;; Iterate through lists, building accumulator and returning tails
             (local.set $lcur (local.get $l))
             (local.set $rcur (local.get $r))
             (local.set $acc (global.get $null))
             (loop $loop
                   (if (ref.eq (local.get $lcur) (global.get $null))
                       (then (return (array.new_fixed $Values 3 (call $reverse (local.get $acc))
                                                         (local.get $lcur) (local.get $rcur)))))
                   (if (ref.eq (local.get $rcur) (global.get $null))
                       (then (return (array.new_fixed $Values 3 (call $reverse (local.get $acc))
                                                         (local.get $lcur) (local.get $rcur)))))

                   (if (i32.eqz (ref.test (ref $Pair) (local.get $lcur)))
                       (then (call $raise-pair-expected (local.get $lcur))
                             (unreachable)))
                   (if (i32.eqz (ref.test (ref $Pair) (local.get $rcur)))
                       (then (call $raise-pair-expected (local.get $rcur))
                             (unreachable)))

                   (local.set $lpair (ref.cast (ref $Pair) (local.get $lcur)))
                   (local.set $rpair (ref.cast (ref $Pair) (local.get $rcur)))
                   (local.set $lelem (struct.get $Pair $a (local.get $lpair)))
                   (local.set $relem (struct.get $Pair $a (local.get $rpair)))

                   (block $same
                          (if (i32.eqz (local.get $use-proc))
                              (then
                               (if (ref.eq (call $equal? (local.get $lelem) (local.get $relem))
                                           (global.get $false))
                                   (then (return (array.new_fixed $Values 3 (call $reverse (local.get $acc))
                                                              (local.get $lcur) (local.get $rcur))))
                                   (else (br $same))))
                              (else
                               (local.set $res
                                          (call_ref $ProcedureInvoker
                                                    (ref.cast (ref $Procedure) (local.get $same?))
                                                    (block (result (ref $Args))
                                                           (local.set $args (array.new $Args (global.get $null) (i32.const 2)))
                                                           (array.set $Args (local.get $args) (i32.const 0) (local.get $lelem))
                                                           (array.set $Args (local.get $args) (i32.const 1) (local.get $relem))
                                                           (local.get $args))
                                                    (struct.get $Procedure $invoke
                                                               (ref.cast (ref $Procedure) (local.get $same?)))))
                               (if (ref.eq (local.get $res) (global.get $false))
                                   (then (return (array.new_fixed $Values 3 (call $reverse (local.get $acc))
                                                              (local.get $lcur) (local.get $rcur))))
                                   (else (br $same))))))

                   (local.set $acc (call $cons (local.get $lelem) (local.get $acc)))
                   (local.set $lcur (struct.get $Pair $d (local.get $lpair)))
                   (local.set $rcur (struct.get $Pair $d (local.get $rpair)))
                   (br $loop))
             (unreachable))))

    ;; Note: Only implements the two-argument form of Racket's add-between.
    ;;       Keyword arguments such as #:before-first are not supported.
    ;; add-between : list? any/c -> list?
    ;;   Insert a separator between list elements.
    (core-runtime-helper
     '$add-between
     "$add-between"
     (lambda ()
       `(func $add-between (type $Prim2)
             (param $xs  (ref eq)) ; list
             (param $v   (ref eq)) ; separator value
             (result     (ref eq))
             (local $acc (ref eq))
             (local $p   (ref $Pair))

             (local.set $acc (global.get $null))

             (block $done
                    (loop $loop
                          (if (ref.eq (local.get $xs) (global.get $null))
                              (then (br $done)))
                          (if (ref.test (ref $Pair) (local.get $xs))
                              (then
                               (local.set $p (ref.cast (ref $Pair) (local.get $xs)))
                               (local.set $acc
                                          (call $cons
                                                (struct.get $Pair $a (local.get $p))
                                                (local.get $acc)))
                               (local.set $xs (struct.get $Pair $d (local.get $p)))
                               (if (ref.eq (local.get $xs) (global.get $null))
                                   (then (br $loop))
                                   (else
                                    (local.set $acc (call $cons (local.get $v) (local.get $acc)))
                                    (br $loop))))
                              (else (call $raise-pair-expected (local.get $xs))
                                    (unreachable)))))

             (call $reverse (local.get $acc)))))

    ;; shuffle : list? -> list?
    ;;   Return a shuffled copy of a list.
    (core-runtime-helper
     '$shuffle
     "$shuffle"
     (lambda ()
       `(func $shuffle (type $Prim1)
             (param $xs (ref eq))  ;; list
             (result (ref eq))

             (local $arr  (ref $Array))
             (local $len  i32)
             (local $i    i32)
             (local $j    i32)
             (local $tmp  (ref eq))
             (local $elem (ref eq))
             (local $res  (ref eq))

             ;; 1) Convert list to array (validates list)
             (local.set $arr (call $list->array (local.get $xs)))
             (local.set $len (array.len (local.get $arr)))

             ;; 2) Fisher-Yates shuffle
             (local.set $i (i32.const 0))
             (block $done
                    (loop $loop
                          (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
                          (local.set $j
                                     (i32.rem_u (call $random-u32)
                                                (i32.add (local.get $i) (i32.const 1))))
                          (if (i32.ne (local.get $j) (local.get $i))
                              (then
                               (local.set $tmp (array.get $Array (local.get $arr) (local.get $i)))
                               (local.set $elem (array.get $Array (local.get $arr) (local.get $j)))
                               (array.set $Array (local.get $arr) (local.get $i) (local.get $elem))
                               (array.set $Array (local.get $arr) (local.get $j) (local.get $tmp))))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $loop)))

             ;; 3) Convert array back to list
             (local.set $res (global.get $null))
             (local.set $i (i32.sub (local.get $len) (i32.const 1)))
             (block $rev-done
                    (loop $rev
                          (br_if $rev-done (i32.lt_s (local.get $i) (i32.const 0)))
                          (local.set $elem (array.get $Array (local.get $arr) (local.get $i)))
                          (local.set $res (struct.new $Pair (i32.const 0)
                                                       (local.get $elem)
                                                       (local.get $res)))
                          (local.set $i (i32.sub (local.get $i) (i32.const 1)))
                          (br $rev)))
             (local.get $res)))))))

;; list-post-contract-runtime-helper-names : (listof symbol?)
;;   Preserve list helper emission order after generic contract helpers.
(define list-post-contract-runtime-helper-names
  (append
   '($list-from-range
     $list-from-range/checked
     $map
     $andmap
     $ormap
     $validate-list-args
     $seed-list-args
     $append-map
     $count
     $for-each
     $foldl
     $foldl/1
     $foldl/2
     $foldl/n
     $foldr
     $foldr/1-loop
     $foldr/1
     $foldr/2-loop
     $foldr/2
     $foldr/n-loop
     $foldr/n
     $filter
     $filter-map
     $filter-not
     $shuffle
     $partition
     $remove
     $remf
     $remf*
     $remf/impl)
   list-remove-runtime-only-helper-names
   '($remove*
     $remove*/checked
     $remove*/checked/1)
   list-remove-star-runtime-only-helper-names
   '($raise-take:bad-length
     $raise-take:bad-length/who
     $raise-take-right:bad-length
     $raise-take-right:bad-length/who
     $take/who
     $take
     $take-right/who
     $take-right
     $takef
     $takef-right
     $list-prefix?
     $take-common-prefix
     $drop-common-prefix
     $split-common-prefix
     $add-between
     $sort
     $sort/expanded-keywords
     $sort/keyword-apply
     $sort:merge
     $sort:merge/key
     $sort:split
     $sort:merge-sort
     $sort:merge-sort/key
     $sort:cache-key-pairs
     $sort:extract-cached-values
     $sort:merge/cached-key
     $sort:merge-sort/cached-key)))

;; list-promoted-runtime-helper-names : (listof symbol?)
;;   Name runtime list helpers that are available in the standalone core runtime.
(define list-promoted-runtime-helper-names
  (remove-duplicates
   (append
    list-error-runtime-only-helper-names
    '($car
     $cdr
     $length/i32
     $length
     $list-ref/checked
     $list-ref
     $rest
     $last
     $last-pair
     $list-tail/checked/who
     $list-tail/checked
     $list-tail
     $drop/who
     $drop
     $append
     $append/2
     $reverse
     $alt-reverse
     $list-set/checked
     $list-set
     $drop-right/who
     $drop-right
     $dropf
     $dropf-right
     $split-at
     $split-at-right
     $splitf-at
     $splitf-at-right
     $qq-append
     $append*
     $flatten
     $memf
     $assf
     $findf
     $index-of
     $index-where
     $indexes-of
     $indexes-where
     $raise-range:real-expected
     $validate-list-args
     $seed-list-args
     $cartesian-product
     $permutations
     $make-list
     $build-list
     $build-list/checked
     $raise-range:zero-step
     $range-proc
     $range
     $range/fixnum
     $range/flonum
     $inclusive-range-proc
     $inclusive-range
     $inclusive-range/fixnum
     $inclusive-range/flonum
     $list-update/checked/who
     $list-update/checked
     $list-update
     $argmax
     $argmin)
    pair-accessor-runtime-only-helper-names
    list-ordinal-accessor-runtime-only-helper-names
    list-member-runtime-only-helper-names
    list-association-runtime-only-helper-names
    list-group-by-runtime-only-helper-names
    list-remove-runtime-only-helper-names
    list-remove-star-runtime-only-helper-names
    list-post-contract-runtime-helper-names)))

;; list-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate list helpers available in the standalone core runtime.
(define list-core-runtime-helpers
  (append list-base-core-runtime-helpers
          (select-runtime-helpers list-all-runtime-only-helpers
                                  list-promoted-runtime-helper-names)))

;; list-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate list helpers that still depend on monolithic runtime globals.
(define list-runtime-only-helpers
  (remove-runtime-helpers list-all-runtime-only-helpers
                          list-promoted-runtime-helper-names))

;; list-promoted-runtime-helper-name-set : hasheq?
;;   Index promoted list helper names for emission-source selection.
(define list-promoted-runtime-helper-name-set
  (for/hasheq ([name (in-list list-promoted-runtime-helper-names)])
    (values name #t)))

;; list-helper-source : symbol? -> symbol?
;;   Return the helper source used when preserving monolithic list order.
(define (list-helper-source name)
  (if (hash-ref list-promoted-runtime-helper-name-set name #f)
      'core
      'runtime))

;; list-helper-spec : symbol? -> (list/c symbol? symbol?)
;;   Build a list helper emission spec for the given helper.
(define (list-helper-spec name)
  (list (list-helper-source name) name))

;; list-helper-forms : hasheq? (listof symbol?) -> (listof datum?)
;;   Render list helpers from the monolithic runtime helper index.
(define (list-helper-forms runtime-helper-index names)
  (for/list ([name (in-list names)])
    (core-runtime-helper-form runtime-helper-index name)))

;; list-pre-contract-runtime-helper-specs : (listof (list/c symbol? symbol?))
;;   Preserve list helper emission order before generic contract helpers.
(define list-pre-contract-runtime-helper-specs
  (append
   (for/list ([name (in-list list-error-runtime-only-helper-names)])
     (list-helper-spec name))
   '((core    $pair?)
     (core    $cons?)
     (core    $null?)
     (core    $empty?)
     (core    $cons)
     (core    $list*)
     (core    $car)
     (core    $cdr))
   (for/list ([name (in-list pair-accessor-runtime-only-helper-names)])
     (list-helper-spec name))
   '((core    $list?)
     (core    $list)
     (core    $length/i32)
     (core    $length)
     (core    $list-ref/checked)
     (core    $list-ref))
   (for/list ([name (in-list list-ordinal-accessor-runtime-only-helper-names)])
     (list-helper-spec name))
   '((core    $rest)
     (core    $last-pair/checked)
     (core    $last)
     (core    $last-pair)
     (core    $list-tail/checked/who)
     (core    $list-tail/checked)
     (core    $list-tail)
     (core    $list-set/checked)
     (core    $list-set)
     (core    $drop/who)
     (core    $drop)
     (core    $drop-right/who)
     (core    $drop-right)
     (core    $dropf)
     (core    $dropf-right)
     (core    $split-at)
     (core    $split-at-right)
     (core    $splitf-at)
     (core    $splitf-at-right)
     (core    $append)
     (core    $append/2)
     (core    $qq-append)
     (core    $append*)
     (core    $flatten)
     (core    $reverse)
     (core    $alt-reverse))
   (for/list ([name (in-list list-member-runtime-only-helper-names)])
     (list-helper-spec name))
   '((core    $memf))
   (for/list ([name (in-list list-association-runtime-only-helper-names)])
     (list-helper-spec name))
   '((core    $assf)
     (core    $findf)
     (core    $index-of)
     (core    $index-where)
     (core    $indexes-of)
     (core    $indexes-where))
   (for/list ([name (in-list list-group-by-runtime-only-helper-names)])
     (list-helper-spec name))
   '((core    $cartesian-product)
     (core    $permutations)
     (core    $make-list)
     (core    $make-list/checked)
     (core    $build-list)
     (core    $build-list/checked)
     (core    $raise-range:real-expected)
     (core    $raise-range:zero-step)
     (core    $range-proc)
     (core    $range)
     (core    $range/fixnum)
     (core    $range/flonum)
     (core    $inclusive-range-proc)
     (core    $inclusive-range)
     (core    $inclusive-range/fixnum)
     (core    $inclusive-range/flonum)
     (core    $list-update/checked/who)
     (core    $list-update/checked)
     (core    $list-update)
     (core    $argmax)
     (core    $argmin))))

;; list-post-contract-runtime-helper-specs : (listof (list/c symbol? symbol?))
;;   Preserve post-contract list helper order while selecting core/runtime sources.
(define list-post-contract-runtime-helper-specs
  (map list-helper-spec list-post-contract-runtime-helper-names))

;; list-source-helper-forms : hasheq? hasheq? (listof (list/c symbol? symbol?)) symbol? -> (listof datum?)
;;   Render helper specs from either runtime-local or standalone core indexes.
(define (list-source-helper-forms runtime-helper-index
                                  core-runtime-helper-index
                                  specs
                                  who)
  (for/list ([spec (in-list specs)])
    (match-define (list source name) spec)
    (case source
      [(core)    (core-runtime-helper-form core-runtime-helper-index name)]
      [(runtime) (core-runtime-helper-form runtime-helper-index name)]
      [else      (error who "unknown helper source: ~a" source)])))

;; list-pre-contract-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render list helpers that appear before generic contract helpers.
(define (list-pre-contract-runtime-helper-forms runtime-helper-index
                                                core-runtime-helper-index)
  (list-source-helper-forms runtime-helper-index
                            core-runtime-helper-index
                            list-pre-contract-runtime-helper-specs
                            'list-pre-contract-runtime-helper-forms))

;; list-post-contract-runtime-helper-forms : hasheq? hasheq? -> (listof datum?)
;;   Render list helpers that appear after generic contract helpers.
(define (list-post-contract-runtime-helper-forms runtime-helper-index
                                                 core-runtime-helper-index)
  (list-source-helper-forms runtime-helper-index
                            core-runtime-helper-index
                            list-post-contract-runtime-helper-specs
                            'list-post-contract-runtime-helper-forms))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define list-core-helper-index
    (make-core-runtime-helper-index list-core-runtime-helpers))

  (define list-helper-index
    (make-core-runtime-helper-index list-runtime-only-helpers))

  (check-equal?
   list-higher-order-primitive-global-names
   '($prim:map
     $prim:andmap
     $prim:ormap
     $prim:for-each
     $prim:append-map
     $prim:count
     $prim:foldl
     $prim:foldr))

  (check-equal?
   (map form-name
        (list-pre-contract-runtime-helper-forms list-helper-index
                                                list-core-helper-index))
   (map second list-pre-contract-runtime-helper-specs))

  (check-equal?
   (map form-name (list-post-contract-runtime-helper-forms list-helper-index
                                                           list-core-helper-index))
   list-post-contract-runtime-helper-names))
