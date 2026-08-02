#lang racket

(provide semaphore-runtime-string-constants
         semaphore-core-runtime-helpers
         semaphore-core-runtime-helper-forms
         semaphore-runtime-helper-forms
         semaphore-runtime-only-helpers)

(require "../core-helper.rkt")

;; semaphore-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by semaphore helpers and semaphore errors.
(define semaphore-runtime-string-constants
  '((semaphore? "semaphore?")
    (try-fail-thunk-or-false "(or/c (procedure-arity-includes/c 0) #f)")))

;; semaphore-promoted-runtime-helper-names : (listof symbol?)
;;   Name semaphore helpers that are available in the standalone core runtime.
(define semaphore-promoted-runtime-helper-names
  '($semaphore?
    $semaphore-peek-evt?))

;; semaphore-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate semaphore helpers in monolithic runtime order.
(define semaphore-all-runtime-helpers
  (list
   ;; make-semaphore : [exact-nonnegative-integer? = 0] -> semaphore?
   ;;   Create a lightweight single-threaded semaphore.
   (core-runtime-helper
    '$make-semaphore
    "$make-semaphore"
    (lambda ()
      `(func $make-semaphore (type $Prim01)
             (param $count-raw (ref eq)) ;; optional initial count, default = 0
             (result           (ref eq))
       
             (local $count i32)
             (if (ref.eq (local.get $count-raw) (global.get $missing))
                 (then (local.set $count (i32.const 0)))
                 (else
                  (if (ref.eq (call $exact-nonnegative-integer? (local.get $count-raw))
                              (global.get $false))
                      (then
                       (call $raise-argument-error1
                             (global.get $symbol:make-semaphore)
                             (global.get $string:exact-nonnegative-integer?)
                             (local.get $count-raw))
                       (unreachable)))
                  (local.set $count
                             (i32.shr_s
                              (i31.get_s (ref.cast (ref i31) (local.get $count-raw)))
                              (i32.const 1)))))
             (struct.new $Semaphore
                         (i32.const 0)
                         (local.get $count)))))


   ;; semaphore? : any/c -> boolean?
   ;;   Check whether a value is a lightweight semaphore.
   (core-runtime-helper
    '$semaphore?
    "$semaphore?"
    (lambda ()
      `(func $semaphore? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Semaphore) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; semaphore-peek-evt? : any/c -> boolean?
   ;;   Check whether a value is a semaphore peek event.
   (core-runtime-helper
    '$semaphore-peek-evt?
    "$semaphore-peek-evt?"
    (lambda ()
      `(func $semaphore-peek-evt? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $SemaphorePeekEvt) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; semaphore-post : semaphore? -> void?
   ;;   Increment a lightweight semaphore's ready count.
   (core-runtime-helper
    '$semaphore-post
    "$semaphore-post"
    (lambda ()
      `(func $semaphore-post (type $Prim1)
             (param $sema-raw (ref eq)) ;; semaphore?
             (result          (ref eq))
       
             (local $sema (ref $Semaphore))
             (if (i32.eqz (ref.test (ref $Semaphore) (local.get $sema-raw)))
                 (then
                  (call $raise-argument-error1
                        (global.get $symbol:semaphore-post)
                        (global.get $string:semaphore?)
                        (local.get $sema-raw))
                  (unreachable)))
             (local.set $sema (ref.cast (ref $Semaphore) (local.get $sema-raw)))
             (struct.set $Semaphore $count
                         (local.get $sema)
                         (i32.add (struct.get $Semaphore $count (local.get $sema))
                                  (i32.const 1)))
             (global.get $void))))


   ;; semaphore-try-wait? : semaphore? -> boolean?
   ;;   Non-blocking wait: decrement and return #t when a count is
   ;;   available; otherwise return #f without changing the semaphore.
   (core-runtime-helper
    '$semaphore-try-wait?
    "$semaphore-try-wait?"
    (lambda ()
      `(func $semaphore-try-wait? (type $Prim1)
             (param $sema-raw (ref eq)) ;; semaphore?
             (result          (ref eq))
       
             (local $sema (ref $Semaphore))
             (if (i32.eqz (ref.test (ref $Semaphore) (local.get $sema-raw)))
                 (then
                  (call $raise-argument-error1
                        (global.get $symbol:semaphore-try-wait?)
                        (global.get $string:semaphore?)
                        (local.get $sema-raw))
                  (unreachable)))
             (local.set $sema (ref.cast (ref $Semaphore) (local.get $sema-raw)))
             (if (i32.le_s (struct.get $Semaphore $count (local.get $sema))
                           (i32.const 0))
                 (then (return (global.get $false))))
             (struct.set $Semaphore $count
                         (local.get $sema)
                         (i32.sub (struct.get $Semaphore $count (local.get $sema))
                                  (i32.const 1)))
             (global.get $true))))


   ;; call-with-semaphore : semaphore? procedure? [try-fail-thunk] arg ... -> any/c
   ;;   Single-threaded approximation of Racket's semaphore protocol:
   ;;   consume a ready semaphore count, invoke proc with args, and post
   ;;   afterward, including on exceptions. Blocking waits cannot suspend
   ;;   yet, so a zero-count semaphore behaves like try-fail when a
   ;;   try-fail thunk is provided.
   (core-runtime-helper
    '$call-with-semaphore
    "$call-with-semaphore"
    (lambda ()
      `(func $call-with-semaphore (type $Prim>=2)
             (param $sema-raw (ref eq)) ;; semaphore?
             (param $proc-raw (ref eq)) ;; procedure?
             (param $rest     (ref eq)) ;; optional try-fail-thunk followed by args
             (result          (ref eq))
       
             (local $sema      (ref $Semaphore))
             (local $proc      (ref $Procedure))
             (local $inv       (ref $ProcedureInvoker))
             (local $pair      (ref $Pair))
             (local $try-fail  (ref eq))
             (local $args-list (ref eq))
             (local $args      (ref $Args))
             (local $node      (ref eq))
             (local $len       i32)
             (local $i         i32)
             (local $res       (ref eq))
             (local $exn-val   (ref eq))
       
             (if (i32.eqz (ref.test (ref $Semaphore) (local.get $sema-raw)))
                 (then
                  (call $raise-argument-error1
                        (global.get $symbol:call-with-semaphore)
                        (global.get $string:semaphore?)
                        (local.get $sema-raw))
                  (unreachable)))
             (if (ref.eq (call $procedure? (local.get $proc-raw))
                         (global.get $false))
                 (then (call $raise-argument-error:procedure-expected/who
                             (global.get $symbol:call-with-semaphore)
                             (local.get $proc-raw))
                       (unreachable)))
             (local.set $sema (ref.cast (ref $Semaphore) (local.get $sema-raw)))
             (local.set $proc (ref.cast (ref $Procedure) (local.get $proc-raw)))
             (local.set $try-fail (global.get $false))
             (local.set $args-list (global.get $null))
             (if (i32.eqz (ref.eq (local.get $rest) (global.get $null)))
                 (then
                  (if (i32.eqz (ref.test (ref $Pair) (local.get $rest)))
                      (then (call $raise-pair-expected (local.get $rest))
                            (unreachable)))
                  (local.set $pair (ref.cast (ref $Pair) (local.get $rest)))
                  (local.set $try-fail (struct.get $Pair $a (local.get $pair)))
                  (local.set $args-list (struct.get $Pair $d (local.get $pair)))))
             (if (i32.and
                  (i32.and
                   (i32.eqz (ref.eq (local.get $try-fail) (global.get $false)))
                   (i32.eqz (ref.eq (local.get $try-fail) (global.get $undefined))))
                  (i32.and
                   (i32.eqz (ref.eq (local.get $try-fail) (global.get $unsafe-undefined)))
                   (ref.eq (call $procedure? (local.get $try-fail))
                           (global.get $false))))
                 (then (call $raise-argument-error1
                             (global.get $symbol:call-with-semaphore)
                             (global.get $string:try-fail-thunk-or-false)
                             (local.get $try-fail))
                       (unreachable)))
             (if (ref.eq (call $procedure? (local.get $try-fail))
                         (global.get $true))
                 (then
                  (if (i32.eqz
                       (call $procedure-arity-includes?/checked/i32
                             (ref.cast (ref $Procedure) (local.get $try-fail))
                             (i32.const 0)))
                      (then (call $raise-argument-error1
                                  (global.get $symbol:call-with-semaphore)
                                  (global.get $string:try-fail-thunk-or-false)
                                  (local.get $try-fail))
                            (unreachable)))))
             (if (i32.le_s (struct.get $Semaphore $count (local.get $sema))
                           (i32.const 0))
                 (then
                  (if (i32.and
                       (i32.and
                        (i32.eqz (ref.eq (local.get $try-fail) (global.get $false)))
                        (i32.eqz (ref.eq (local.get $try-fail) (global.get $undefined))))
                       (i32.eqz (ref.eq (local.get $try-fail) (global.get $unsafe-undefined))))
                      (then (return (call $call-thunk (local.get $try-fail)))))))
             (if (i32.gt_s (struct.get $Semaphore $count (local.get $sema))
                           (i32.const 0))
                 (then
                  (struct.set $Semaphore $count
                              (local.get $sema)
                              (i32.sub
                               (struct.get $Semaphore $count (local.get $sema))
                               (i32.const 1)))))
             (local.set $len (call $length/i32 (local.get $args-list)))
             (local.set $args (array.new $Args (global.get $null) (local.get $len)))
             (local.set $node (local.get $args-list))
             (local.set $i (i32.const 0))
             (block $args-done
                    (loop $args-loop
                          (br_if $args-done (i32.ge_u (local.get $i) (local.get $len)))
                          (local.set $pair (ref.cast (ref $Pair) (local.get $node)))
                          (array.set $Args
                                     (local.get $args)
                                     (local.get $i)
                                     (struct.get $Pair $a (local.get $pair)))
                          (local.set $node (struct.get $Pair $d (local.get $pair)))
                          (local.set $i (i32.add (local.get $i) (i32.const 1)))
                          (br $args-loop)))
             (local.set $inv (struct.get $Procedure $invoke (local.get $proc)))
             (local.set $res
                        (block $done (result (ref eq))
                               (block $handler-block (result (ref eq))
                                      (try_table (result (ref eq))
                                                 (catch $exn $handler-block)
                                                 (call_ref $ProcedureInvoker
                                                           (local.get $proc)
                                                           (local.get $args)
                                                           (local.get $inv))
                                                 (br $done)))
                               (local.set $exn-val)
                               (drop (call $semaphore-post (local.get $sema)))
                               (throw $exn (local.get $exn-val))
                               (unreachable)))
             (drop (call $semaphore-post (local.get $sema)))
             (local.get $res))))


   ;; semaphore-peek-evt : semaphore? -> semaphore-peek-evt?
   ;;   Create an event that becomes ready when the semaphore is ready
   ;;   without consuming the semaphore count.
   (core-runtime-helper
    '$semaphore-peek-evt
    "$semaphore-peek-evt"
    (lambda ()
      `(func $semaphore-peek-evt (type $Prim1)
             (param $sema-raw (ref eq)) ;; semaphore?
             (result          (ref eq))
       
             (if (i32.eqz (ref.test (ref $Semaphore) (local.get $sema-raw)))
                 (then
                  (call $raise-argument-error1
                        (global.get $symbol:semaphore-peek-evt)
                        (global.get $string:semaphore?)
                        (local.get $sema-raw))
                  (unreachable)))
             (struct.new $SemaphorePeekEvt
                         (i32.const 0)
                         (ref.cast (ref $Semaphore) (local.get $sema-raw))))))
))

;; semaphore-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate semaphore helpers available in the standalone core runtime.
(define semaphore-core-runtime-helpers
  (select-runtime-helpers semaphore-all-runtime-helpers
                          semaphore-promoted-runtime-helper-names))

;; semaphore-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate semaphore helpers that still depend on monolithic runtime globals.
(define semaphore-runtime-only-helpers
  (remove-runtime-helpers semaphore-all-runtime-helpers
                          semaphore-promoted-runtime-helper-names))

;; semaphore-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for semaphore helpers.
(define semaphore-runtime-only-helper-names
  '($make-semaphore
    $semaphore-post
    $semaphore-try-wait?
    $call-with-semaphore
    $semaphore-peek-evt))

;; semaphore-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted semaphore helpers in runtime assembly order.
(define (semaphore-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list semaphore-promoted-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; semaphore-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render semaphore helpers in runtime assembly order.
(define (semaphore-runtime-helper-forms helper-index)
  (for/list ([name (in-list semaphore-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define semaphore-core-helper-index
    (make-core-runtime-helper-index semaphore-core-runtime-helpers))

  (define semaphore-helper-index
    (make-core-runtime-helper-index
     (append semaphore-core-runtime-helpers
             semaphore-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name semaphore-core-runtime-helpers)
   semaphore-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (semaphore-core-runtime-helper-forms semaphore-core-helper-index))
   semaphore-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (semaphore-runtime-helper-forms semaphore-helper-index))
   semaphore-runtime-only-helper-names))
