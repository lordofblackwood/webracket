#lang racket

(provide will-runtime-string-constants
         will-runtime-symbol-constants
         will-core-runtime-helpers
         will-core-runtime-helper-forms
         will-runtime-helper-forms
         will-runtime-only-helpers)

(require "../core-helper.rkt")

;; will-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by will-executor helpers.
(define will-runtime-string-constants
  '((will-executor?          "will-executor?")
    (will-procedure-arity-1 "(procedure-arity-includes/c 1)")))

;; will-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by will-executor helpers.
(define will-runtime-symbol-constants
  '(make-will-executor
    will-executor?
    will-register
    will-execute
    will-try-execute))

;; will-promoted-runtime-helper-names : (listof symbol?)
;;   Name will-executor helpers that are available in the standalone core runtime.
(define will-promoted-runtime-helper-names
  '($make-will-executor
    $will-executor?))

;; will-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate will-executor helpers in monolithic runtime order.
(define will-all-runtime-helpers
  (list
   ;; make-will-executor : -> will-executor?
   ;;   Create an inert will executor. Registrations are retained, but
   ;;   WebRacket has no GC finalization hook to make wills ready.
   (core-runtime-helper
    '$make-will-executor
    "$make-will-executor"
    (lambda ()
      `(func $make-will-executor (type $Prim0)
             (result (ref eq))
             (struct.new $WillExecutor
                         (i32.const 0)
                         (global.get $null)))))


   ;; will-executor? : any/c -> boolean?
   ;;   Recognize WebRacket's minimal will executor records.
   (core-runtime-helper
    '$will-executor?
    "$will-executor?"
    (lambda ()
      `(func $will-executor? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $WillExecutor) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; will-register : will-executor? any/c procedure? -> void?
   ;;   Retain the registration so the will procedure remains strongly
   ;;   referenced. No registration becomes ready until finalization is
   ;;   implemented.
   (core-runtime-helper
    '$will-register
    "$will-register"
    (lambda ()
      `(func $will-register (type $Prim3)
             (param $executor-raw (ref eq)) ;; will-executor?
             (param $v            (ref eq)) ;; registered value
             (param $proc-raw     (ref eq)) ;; procedure accepting 1 arg
             (result              (ref eq))
             (local $executor (ref $WillExecutor))
             (local $proc     (ref $Procedure))

             (if (i32.eqz (ref.test (ref $WillExecutor) (local.get $executor-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:will-register)
                             (global.get $string:will-executor?)
                             (local.get $executor-raw))
                       (unreachable)))
             (if (ref.eq (call $procedure? (local.get $proc-raw))
                         (global.get $false))
                 (then (call $raise-argument-error1
                             (global.get $symbol:will-register)
                             (global.get $string:will-procedure-arity-1)
                             (local.get $proc-raw))
                       (unreachable)))
             (local.set $proc (ref.cast (ref $Procedure) (local.get $proc-raw)))
             (if (i32.eqz (call $procedure-arity-includes?/checked/i32
                                (local.get $proc)
                                (i32.const 1)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:will-register)
                             (global.get $string:will-procedure-arity-1)
                             (local.get $proc-raw))
                       (unreachable)))
             (local.set $executor
                        (ref.cast (ref $WillExecutor) (local.get $executor-raw)))
             (struct.set $WillExecutor $registrations
                         (local.get $executor)
                         (call $cons
                               (call $cons (local.get $v) (local.get $proc-raw))
                               (struct.get $WillExecutor $registrations
                                           (local.get $executor))))
             (global.get $void))))


   ;; will-try-execute : will-executor? [any/c = #f] -> any/c
   ;;   Return the default because no GC-discovered wills are ready in
   ;;   the current runtime.
   (core-runtime-helper
    '$will-try-execute
    "$will-try-execute"
    (lambda ()
      `(func $will-try-execute (type $Prim12)
             (param $executor-raw (ref eq)) ;; will-executor?
             (param $default      (ref eq)) ;; optional default, default = #f
             (result              (ref eq))
             (if (i32.eqz (ref.test (ref $WillExecutor) (local.get $executor-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:will-try-execute)
                             (global.get $string:will-executor?)
                             (local.get $executor-raw))
                       (unreachable)))
             (if (result (ref eq))
                 (ref.eq (local.get $default) (global.get $missing))
                 (then (global.get $false))
                 (else (local.get $default))))))


   ;; will-execute : will-executor? -> any/c
   ;;   Blocking is unavailable without a scheduler/finalizer queue, so
   ;;   this behaves like an immediate unsuccessful poll.
   (core-runtime-helper
    '$will-execute
    "$will-execute"
    (lambda ()
      `(func $will-execute (type $Prim1)
             (param $executor-raw (ref eq)) ;; will-executor?
             (result              (ref eq))
             (if (i32.eqz (ref.test (ref $WillExecutor) (local.get $executor-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:will-execute)
                             (global.get $string:will-executor?)
                             (local.get $executor-raw))
                       (unreachable)))
             (call $will-try-execute
                   (local.get $executor-raw)
                   (global.get $false)))))
))

;; will-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate will-executor helpers available in the standalone core runtime.
(define will-core-runtime-helpers
  (select-runtime-helpers will-all-runtime-helpers
                          will-promoted-runtime-helper-names))

;; will-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate will-executor helpers that still depend on monolithic runtime globals.
(define will-runtime-only-helpers
  (remove-runtime-helpers will-all-runtime-helpers
                          will-promoted-runtime-helper-names))

;; will-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for will-executor helpers.
(define will-runtime-only-helper-names
  '($will-register
    $will-try-execute
    $will-execute))

;; will-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted will-executor helpers in runtime assembly order.
(define (will-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list will-promoted-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; will-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render will-executor helpers in runtime assembly order.
(define (will-runtime-helper-forms helper-index)
  (for/list ([name (in-list will-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define will-core-helper-index
    (make-core-runtime-helper-index will-core-runtime-helpers))

  (define will-helper-index
    (make-core-runtime-helper-index
     (append will-core-runtime-helpers
             will-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name will-core-runtime-helpers)
   will-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (will-core-runtime-helper-forms will-core-helper-index))
   will-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (will-runtime-helper-forms will-helper-index))
   will-runtime-only-helper-names))
