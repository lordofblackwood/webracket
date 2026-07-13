#lang racket

(provide thread-current-global-forms
         thread-current-core-global-forms
         thread-current-core-global-names
         thread-runtime-string-constants
         thread-runtime-symbol-constants
         thread-current-initializer-forms
         thread-group-current-global-forms
         thread-group-current-global-names
         thread-group-current-initializer-forms
         thread-core-runtime-helpers
         thread-core-runtime-helper-forms
         thread-runtime-helper-forms
         thread-runtime-only-helpers)

(require "../core-helper.rkt")

;; thread-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare string constants used by thread, thread-cell, and thread-group helpers.
(define thread-runtime-string-constants
  '((thread?       "thread?")
    (thread-cell?  "thread-cell?")
    (thread-group? "thread-group?")))

;; thread-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by thread, thread-cell, and thread-group helpers.
(define thread-runtime-symbol-constants
  '(thread?
    thread-dead?
    thread-running?
    thread-cell-ref
    thread-cell-set!
    thread-group?
    make-thread-group
    current-thread-group))

;; thread-group-current-global-forms : (listof datum?)
;;   Declare the current thread group global at its monolithic runtime position.
(define thread-group-current-global-forms
  '(
               (global $current-thread-group-value (mut (ref eq)) (global.get $false))))

;; thread-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a thread global form.
(define (thread-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'thread-global-form-name
              "expected global form, got: ~s"
              form)]))

;; thread-group-current-global-names : (listof symbol?)
;;   Enumerate current-thread-group globals shared by split modules.
(define thread-group-current-global-names
  (map thread-global-form-name thread-group-current-global-forms))

;; thread-current-global-forms : (listof datum?)
;;   Declare the current thread global at its monolithic runtime position.
(define thread-current-global-forms
  '(
               (global $current-thread-value     (mut (ref eq)) (global.get $false))))

;; thread-current-core-global-names : (listof symbol?)
;;   Name stable thread globals that can live in the standalone core runtime.
(define thread-current-core-global-names
  '($current-thread-value))

;; thread-current-core-global-forms : (listof datum?)
;;   Declare the standalone core runtime's stable current thread token.
(define thread-current-core-global-forms
  '(
               (global $current-thread-value     (ref eq) (struct.new $Thread (i32.const 0)))))

;; thread-current-initializer-forms : (listof datum?)
;;   Initialize WebRacket's single thread and initial thread group.
(define thread-current-initializer-forms
  '(
                     (global.set $current-thread-value
                                 (struct.new $Thread (i32.const 0)))
                     (global.set $current-thread-group-value
                                 (struct.new $ThreadGroup
                                             (i32.const 0)
                                             (global.get $false)))))

;; thread-group-current-initializer-forms : (listof datum?)
;;   Initialize the current thread group without touching current-thread.
(define thread-group-current-initializer-forms
  '(
                    (global.set $current-thread-group-value
                                (struct.new $ThreadGroup
                                            (i32.const 0)
                                            (global.get $false)))))

;; thread-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for thread and thread-cell helpers.
(define thread-helper-names
  '($make-thread-cell
    $thread-cell?
    $ensure-thread-cell
    $thread-cell-ref
    $thread-cell-set!
    $current-thread
    $thread?
    $thread-dead?
    $thread-running?
    $thread-group?
    $current-thread-group
    $make-thread-group))

;; thread-promoted-runtime-helper-names : (listof symbol?)
;;   Name thread helpers that are available in the standalone core runtime.
(define thread-promoted-runtime-helper-names
  thread-helper-names)

;; thread-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate thread helpers in monolithic runtime order.
(define thread-all-runtime-helpers
  (list
   ;;;
   ;;; 4.15 Thread Cells
   ;;;

   ;; make-thread-cell : any/c [any/c = #f] -> thread-cell?
   ;;   Create a single-threaded thread cell. The optional `preserved?`
   ;;   flag is stored for future thread support, but no thread-specific
   ;;   value map is needed while WebRacket has one thread.
   (core-runtime-helper
    '$make-thread-cell
    "$make-thread-cell"
    (lambda ()
      `(func $make-thread-cell (type $Prim2)
             (param $v (ref eq))           ;; initial value
             (param $preserved? (ref eq))  ;; optional, default #f
             (result (ref eq))
             (struct.new $ThreadCell
                         (i32.const 0)      ;; $hash
                         (local.get $v)     ;; $default
                         (local.get $v)     ;; $current
                         (i32.and
                          (i32.eqz (ref.eq (local.get $preserved?) (global.get $false)))
                          (i32.eqz (ref.eq (local.get $preserved?) (global.get $missing))))))))


   ;; thread-cell? : any/c -> boolean?
   ;;   Check whether a value is a thread cell.
   (core-runtime-helper
    '$thread-cell?
    "$thread-cell?"
    (lambda ()
      `(func $thread-cell? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $ThreadCell) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; ensure-thread-cell : symbol? any/c -> thread-cell?
   ;;   Check a thread-cell argument using the caller's `who` name.
   (core-runtime-helper
    '$ensure-thread-cell
    "$ensure-thread-cell"
    (lambda ()
      `(func $ensure-thread-cell
             (param $who (ref eq))
             (param $v   (ref eq))
             (result     (ref $ThreadCell))
             (if (i32.eqz (ref.test (ref $ThreadCell) (local.get $v)))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (global.get $string:thread-cell?)
                             (local.get $v))
                       (unreachable)))
             (ref.cast (ref $ThreadCell) (local.get $v)))))


   ;; thread-cell-ref : thread-cell? -> any/c
   ;;   Return the current value for the single WebRacket thread.
   (core-runtime-helper
    '$thread-cell-ref
    "$thread-cell-ref"
    (lambda ()
      `(func $thread-cell-ref (type $Prim1)
             (param $cell (ref eq))
             (result (ref eq))
             (struct.get $ThreadCell $current
                         (call $ensure-thread-cell
                               (global.get $symbol:thread-cell-ref)
                               (local.get $cell))))))


   ;; thread-cell-set! : thread-cell? any/c -> void?
   ;;   Set the current value for the single WebRacket thread.
   (core-runtime-helper
    '$thread-cell-set!
    "$thread-cell-set!"
    (lambda ()
      `(func $thread-cell-set! (type $Prim2)
             (param $cell (ref eq))  ;; thread cell
             (param $v    (ref eq))  ;; new current value
             (result (ref eq))
             (local $tc (ref $ThreadCell))
             (local.set $tc
                        (call $ensure-thread-cell
                              (global.get $symbol:thread-cell-set!)
                              (local.get $cell)))
             (struct.set $ThreadCell $current (local.get $tc) (local.get $v))
             (global.get $void))))


   ;; current-thread : -> thread?
   ;;   Return the single stable WebRacket thread token.
   (core-runtime-helper
    '$current-thread
    "$current-thread"
    (lambda ()
      `(func $current-thread (type $Prim0)
             (result (ref eq))
             (global.get $current-thread-value))))


   ;; thread? : any/c -> boolean?
   ;;   Recognize WebRacket's single stable thread token.
   (core-runtime-helper
    '$thread?
    "$thread?"
    (lambda ()
      `(func $thread? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Thread) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; thread-dead? : thread? -> boolean?
   ;;   WebRacket is single-threaded; its current thread token remains
   ;;   live for the duration of the program.
   (core-runtime-helper
    '$thread-dead?
    "$thread-dead?"
    (lambda ()
      `(func $thread-dead? (type $Prim1)
             (param $thd (ref eq)) ;; thread?
             (result     (ref eq))
             (if (i32.eqz (ref.test (ref $Thread) (local.get $thd)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:thread-dead?)
                             (global.get $string:thread?)
                             (local.get $thd))
                       (unreachable)))
             (global.get $false))))


   ;; thread-running? : thread? -> boolean?
   ;;   In single-threaded WebRacket the stable thread token is always
   ;;   running while user code can observe it.
   (core-runtime-helper
    '$thread-running?
    "$thread-running?"
    (lambda ()
      `(func $thread-running? (type $Prim1)
             (param $thd (ref eq)) ;; thread?
             (result     (ref eq))
             (if (i32.eqz (ref.test (ref $Thread) (local.get $thd)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:thread-running?)
                             (global.get $string:thread?)
                             (local.get $thd))
                       (unreachable)))
             (global.get $true))))


   ;; thread-group? : any/c -> boolean?
   ;;   Recognize WebRacket's minimal thread group records.
   (core-runtime-helper
    '$thread-group?
    "$thread-group?"
    (lambda ()
      `(func $thread-group? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $ThreadGroup) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; current-thread-group : [thread-group?] -> thread-group? or void?
   ;;   Parameter-like current thread group for future thread creation.
   ;;   Scheduling is not modeled in single-threaded WebRacket.
   (core-runtime-helper
    '$current-thread-group
    "$current-thread-group"
    (lambda ()
      `(func $current-thread-group (type $Prim01)
             (param $group-raw (ref eq)) ;; optional thread-group?
             (result           (ref eq))
             (if (ref.eq (local.get $group-raw) (global.get $missing))
                 (then (return (call $parameter-value-or-global
                                     (global.get $prim:current-thread-group)
                                     (global.get $current-thread-group-value)))))
             (if (i32.eqz (ref.test (ref $ThreadGroup) (local.get $group-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:current-thread-group)
                             (global.get $string:thread-group?)
                             (local.get $group-raw))
                       (unreachable)))
             (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                   (global.get $false)))
                 (then (return (call $extend-current-parameterization!
                                     (global.get $prim:current-thread-group)
                                     (local.get $group-raw)))))
             (global.set $current-thread-group-value (local.get $group-raw))
             (global.get $void))))


   ;; make-thread-group : [thread-group? = (current-thread-group)] -> thread-group?
   ;;   Create a minimal child thread group.
   (core-runtime-helper
    '$make-thread-group
    "$make-thread-group"
    (lambda ()
      `(func $make-thread-group (type $Prim01)
             (param $parent-raw (ref eq)) ;; optional thread-group?, default = current-thread-group
             (result            (ref eq))
             (if (ref.eq (local.get $parent-raw) (global.get $missing))
                 (then (local.set $parent-raw
                                  (call $current-thread-group
                                        (global.get $missing)))))
             (if (i32.eqz (ref.test (ref $ThreadGroup) (local.get $parent-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:make-thread-group)
                             (global.get $string:thread-group?)
                             (local.get $parent-raw))
                       (unreachable)))
             (struct.new $ThreadGroup
                         (i32.const 0)
                         (local.get $parent-raw)))))
))

;; thread-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate thread helpers available in the standalone core runtime.
(define thread-core-runtime-helpers
  (select-runtime-helpers thread-all-runtime-helpers
                          thread-promoted-runtime-helper-names))

;; thread-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate thread helpers that still depend on monolithic runtime globals.
(define thread-runtime-only-helpers
  (remove-runtime-helpers thread-all-runtime-helpers
                          thread-promoted-runtime-helper-names))

;; thread-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for thread and thread-cell helpers.
(define thread-runtime-only-helper-names
  (remove* thread-promoted-runtime-helper-names
           thread-helper-names
           eq?))

;; thread-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted thread helpers in runtime assembly order.
(define (thread-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list thread-promoted-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; thread-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render thread and thread-cell helpers in runtime assembly order.
(define (thread-runtime-helper-forms helper-index)
  (for/list ([name (in-list thread-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define thread-core-helper-index
    (make-core-runtime-helper-index thread-core-runtime-helpers))

  (define thread-helper-index
    (make-core-runtime-helper-index
     (append thread-core-runtime-helpers
             thread-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name thread-core-runtime-helpers)
   thread-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (thread-core-runtime-helper-forms thread-core-helper-index))
   thread-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (thread-runtime-helper-forms thread-helper-index))
   thread-runtime-only-helper-names))
