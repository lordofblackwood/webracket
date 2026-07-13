#lang racket

(provide logger-current-global-forms
         logger-current-global-names
         logger-runtime-string-constants
         logger-runtime-symbol-constants
         logger-current-initializer-forms
         logger-core-runtime-helpers
         logger-core-runtime-helper-forms
         logger-runtime-helper-forms
         logger-runtime-only-helpers)

(require "../core-helper.rkt")

;; logger-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by logger and log-receiver helpers.
(define logger-runtime-string-constants
  '((logger?         "logger?")
    (log-receiver?   "log-receiver?")
    (log-level/c     "(or/c 'none 'fatal 'error 'warning 'info 'debug)")
    (string-or-symbol "(or/c string? symbol?)")
    (false-or-symbol "(or/c #f symbol?)")
    (symbol-or-false "(or/c symbol? #f)")))

;; logger-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by logger and log-receiver helpers.
(define logger-runtime-symbol-constants
  '(current-logger
    logger?
    log-receiver?
    make-log-receiver
    make-logger
    logger-name
    log-level?
    log-max-level
    log-message
    none
    fatal
    error
    warning
    info
    debug))

;; logger-current-global-forms : (listof datum?)
;;   Declare the current logger global.
(define logger-current-global-forms
  '(
               (global $current-logger-value      (mut (ref eq)) (global.get $false))))

;; logger-global-form-name : datum? -> symbol?
;;   Return the Wasm global name declared by a logger global form.
(define (logger-global-form-name form)
  (match form
    [`(global ,name . ,_) name]
    [_ (error 'logger-global-form-name
              "expected global form, got: ~s"
              form)]))

;; logger-current-global-names : (listof symbol?)
;;   Enumerate logger current globals shared by split modules.
(define logger-current-global-names
  (map logger-global-form-name logger-current-global-forms))

;; logger-current-initializer-forms : (listof datum?)
;;   Initialize the root logger.
(define logger-current-initializer-forms
  '(
                     (global.set $current-logger-value
                                 (struct.new $Logger
                                             (i32.const 0)
                                             (global.get $false)))))

;; logger-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for logger helpers.
(define logger-helper-names
  '($logger?
    $log-receiver?
    $log-level?/i32
    $check-log-level
    $check-log-topic
    $check-log-topics
    $check-log-message
    $make-logger
    $make-log-receiver
    $logger-name
    $current-logger
    $log-level?
    $log-max-level
    $log-message))

;; logger-promoted-runtime-helper-names : (listof symbol?)
;;   Name logger helpers that are available in the standalone core runtime.
(define logger-promoted-runtime-helper-names
  logger-helper-names)

;; logger-all-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate logger helpers in monolithic runtime order.
(define logger-all-runtime-helpers
  (list
   ;; logger? : any/c -> boolean?
   ;;   Predicate for WebRacket's minimal logger objects.
   (core-runtime-helper
    '$logger?
    "$logger?"
    (lambda ()
      `(func $logger? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $Logger) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; log-receiver? : any/c -> boolean?
   ;;   Predicate for inert log receivers.
   (core-runtime-helper
    '$log-receiver?
    "$log-receiver?"
    (lambda ()
      `(func $log-receiver? (type $Prim1)
             (param $v (ref eq))
             (result   (ref eq))
             (if (result (ref eq))
                 (ref.test (ref $LogReceiver) (local.get $v))
                 (then (global.get $true))
                 (else (global.get $false))))))


   ;; log-level?/i32 : any/c -> i32
   ;;   Check whether a value is one of Racket's log-level symbols.
   (core-runtime-helper
    '$log-level?/i32
    "$log-level?/i32"
    (lambda ()
      `(func $log-level?/i32
             (param $level (ref eq))
             (result       i32)
             (i32.or
              (i32.or
               (ref.eq (local.get $level) (global.get $symbol:none))
               (ref.eq (local.get $level) (global.get $symbol:fatal)))
              (i32.or
               (i32.or
                (ref.eq (local.get $level) (global.get $symbol:error))
                (ref.eq (local.get $level) (global.get $symbol:warning)))
               (i32.or
                (ref.eq (local.get $level) (global.get $symbol:info))
                (ref.eq (local.get $level) (global.get $symbol:debug))))))))


   ;; check-log-level : symbol? any/c -> void?
   ;;   Raise a Racket contract error unless level is a log-level symbol.
   (core-runtime-helper
    '$check-log-level
    "$check-log-level"
    (lambda ()
      `(func $check-log-level
             (param $who   (ref eq)) ;; symbol
             (param $level (ref eq)) ;; log-level/c
             (if (i32.eqz (call $log-level?/i32 (local.get $level)))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (global.get $string:log-level/c)
                             (local.get $level))
                       (unreachable))))))


   ;; check-log-topic : symbol? any/c -> void?
   ;;   Raise a Racket contract error unless topic is #f or a symbol.
   (core-runtime-helper
    '$check-log-topic
    "$check-log-topic"
    (lambda ()
      `(func $check-log-topic
             (param $who   (ref eq)) ;; symbol
             (param $topic (ref eq)) ;; (or/c #f symbol?)
             (if (i32.eqz (i32.or
                           (ref.eq (local.get $topic) (global.get $false))
                           (ref.test (ref $Symbol) (local.get $topic))))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (global.get $string:false-or-symbol)
                             (local.get $topic))
                       (unreachable))))))


   ;; check-log-topics : symbol? list? -> void?
   ;;   Validate a rest-list of logger topics.
   (core-runtime-helper
    '$check-log-topics
    "$check-log-topics"
    (lambda ()
      `(func $check-log-topics
             (param $who    (ref eq)) ;; symbol
             (param $topics (ref eq)) ;; rest-list of (or/c #f symbol?)
             (local $node  (ref eq))
             (local $pair  (ref $Pair))
             (local.set $node (local.get $topics))
             (block $done
                    (loop $loop
                          (br_if $done
                                 (ref.eq (local.get $node) (global.get $null)))
                          (if (i32.eqz (ref.test (ref $Pair) (local.get $node)))
                              (then (call $raise-argument-error1
                                          (local.get $who)
                                          (global.get $string:false-or-symbol)
                                          (local.get $node))
                                    (unreachable)))
                          (local.set $pair
                                     (ref.cast (ref $Pair) (local.get $node)))
                          (call $check-log-topic
                                (local.get $who)
                                (struct.get $Pair $a (local.get $pair)))
                          (local.set $node
                                     (struct.get $Pair $d (local.get $pair)))
                          (br $loop))))))


   ;; check-log-message : symbol? any/c -> void?
   ;;   Raise a Racket contract error unless message is a string or symbol.
   (core-runtime-helper
    '$check-log-message
    "$check-log-message"
    (lambda ()
      `(func $check-log-message
             (param $who     (ref eq)) ;; symbol
             (param $message (ref eq)) ;; (or/c string? symbol?)
             (if (i32.eqz (i32.or
                           (ref.test (ref $String) (local.get $message))
                           (ref.test (ref $Symbol) (local.get $message))))
                 (then (call $raise-argument-error1
                             (local.get $who)
                             (global.get $string:string-or-symbol)
                             (local.get $message))
                       (unreachable))))))


   ;; make-logger : [(or/c symbol? #f)] ... -> logger?
   ;;   Create an inert logger. Only the optional topic/name is retained;
   ;;   parent and filter arguments are accepted but ignored for now.
   (core-runtime-helper
    '$make-logger
    "$make-logger"
    (lambda ()
      `(func $make-logger (type $Prim>=0)
             (param $args (ref eq)) ;; list of optional logger arguments
             (result      (ref eq))
             (local $name (ref eq))
             (local.set $name (global.get $false))
             (if (ref.test (ref $Pair) (local.get $args))
                 (then
                  (local.set $name
                             (struct.get $Pair $a
                                         (ref.cast (ref $Pair) (local.get $args))))))
             (if (i32.eqz (i32.or (ref.eq (local.get $name) (global.get $false))
                                   (ref.test (ref $Symbol) (local.get $name))))
                 (then (call $raise-argument-error1
                             (global.get $symbol:make-logger)
                             (global.get $string:symbol-or-false)
                             (local.get $name))
                       (unreachable)))
             (struct.new $Logger (i32.const 0) (local.get $name)))))


   ;; make-log-receiver : logger? log-level/c [(or/c #f symbol?)] ... -> log-receiver?
   ;;   Create a synchronizable but never-ready receiver. WebRacket's
   ;;   logger layer is currently inert, so no queued log events exist.
   (core-runtime-helper
    '$make-log-receiver
    "$make-log-receiver"
    (lambda ()
      `(func $make-log-receiver (type $Prim>=2)
             (param $logger-raw (ref eq)) ;; logger?
             (param $level      (ref eq)) ;; log-level/c, retained but not interpreted
             (param $topics     (ref eq)) ;; topic filters
             (result            (ref eq))
             (if (i32.eqz (ref.test (ref $Logger) (local.get $logger-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:make-log-receiver)
                             (global.get $string:logger?)
                             (local.get $logger-raw))
                       (unreachable)))
             (call $check-log-level
                   (global.get $symbol:make-log-receiver)
                   (local.get $level))
             (call $check-log-topics
                   (global.get $symbol:make-log-receiver)
                   (local.get $topics))
             (struct.new $LogReceiver
                         (i32.const 0)
                         (ref.cast (ref $Logger) (local.get $logger-raw))
                         (local.get $level)
                         (local.get $topics)))))


   ;; logger-name : logger? -> (or/c symbol? #f)
   ;;   Return the topic/name carried by a minimal logger.
   (core-runtime-helper
    '$logger-name
    "$logger-name"
    (lambda ()
      `(func $logger-name (type $Prim1)
             (param $logger-raw (ref eq)) ;; logger?
             (result            (ref eq))
             (if (i32.eqz (ref.test (ref $Logger) (local.get $logger-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:logger-name)
                             (global.get $string:logger?)
                             (local.get $logger-raw))
                       (unreachable)))
             (struct.get $Logger $name
                         (ref.cast (ref $Logger) (local.get $logger-raw))))))


   ;; current-logger : [logger?] -> logger? or void?
   ;;   Parameter-like current logger. It participates in the existing
   ;;   poor-man's parameterization table so parameterize can override it.
   (core-runtime-helper
    '$current-logger
    "$current-logger"
    (lambda ()
      `(func $current-logger (type $Prim01)
             (param $logger-raw (ref eq)) ;; optional logger?
             (result            (ref eq))
             (if (ref.eq (local.get $logger-raw) (global.get $missing))
                 (then (return (call $parameter-value-or-global
                                     (global.get $prim:current-logger)
                                     (global.get $current-logger-value)))))
             (if (i32.eqz (ref.test (ref $Logger) (local.get $logger-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:current-logger)
                             (global.get $string:logger?)
                             (local.get $logger-raw))
                       (unreachable)))
             (if (i32.eqz (ref.eq (global.get $current-parameterization-value)
                                   (global.get $false)))
                 (then (return (call $extend-current-parameterization!
                                     (global.get $prim:current-logger)
                                     (local.get $logger-raw)))))
             (global.set $current-logger-value (local.get $logger-raw))
             (global.get $void))))


   ;; log-level? : logger? log-level/c [(or/c symbol? #f)] -> #f
   ;;   Logging is currently inert in WebRacket; returning #f keeps
   ;;   library logging branches quiet without needing receivers/events.
   (core-runtime-helper
    '$log-level?
    "$log-level?"
    (lambda ()
      `(func $log-level? (type $Prim23)
             (param $logger-raw (ref eq)) ;; logger?
             (param $level      (ref eq)) ;; log-level/c, currently ignored
             (param $topic      (ref eq)) ;; optional topic, currently ignored
             (result            (ref eq))
             (if (i32.eqz (ref.test (ref $Logger) (local.get $logger-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:log-level?)
                             (global.get $string:logger?)
                             (local.get $logger-raw))
                       (unreachable)))
             (call $check-log-level
                   (global.get $symbol:log-level?)
                   (local.get $level))
             (if (i32.eqz (ref.eq (local.get $topic) (global.get $missing)))
                 (then (call $check-log-topic
                             (global.get $symbol:log-level?)
                             (local.get $topic))))
             (global.get $false))))


   ;; log-max-level : logger? [(or/c symbol? #f)] -> #f
   ;;   Inert logger support reports no enabled levels.
   (core-runtime-helper
    '$log-max-level
    "$log-max-level"
    (lambda ()
      `(func $log-max-level (type $Prim12)
             (param $logger-raw (ref eq)) ;; logger?
             (param $topic      (ref eq)) ;; optional topic, currently ignored
             (result            (ref eq))
             (if (i32.eqz (ref.test (ref $Logger) (local.get $logger-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:log-max-level)
                             (global.get $string:logger?)
                             (local.get $logger-raw))
                       (unreachable)))
             (if (i32.eqz (ref.eq (local.get $topic) (global.get $missing)))
                 (then (call $check-log-topic
                             (global.get $symbol:log-max-level)
                             (local.get $topic))))
             (global.get $false))))


   ;; log-message : logger? log-level/c any/c ... -> void?
   ;;   Accept and discard log messages for the inert logger substrate.
   (core-runtime-helper
    '$log-message
    "$log-message"
    (lambda ()
      `(func $log-message (type $Prim>=3)
             (param $logger-raw (ref eq)) ;; logger?
             (param $level      (ref eq)) ;; log-level/c, currently ignored
             (param $message    (ref eq)) ;; any/c, currently ignored
             (param $rest       (ref eq)) ;; remaining optional args
             (result            (ref eq))
             (if (i32.eqz (ref.test (ref $Logger) (local.get $logger-raw)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:log-message)
                             (global.get $string:logger?)
                             (local.get $logger-raw))
                       (unreachable)))
             (call $check-log-level
                   (global.get $symbol:log-message)
                   (local.get $level))
             (call $check-log-message
                   (global.get $symbol:log-message)
                   (local.get $message))
             (global.get $void))))
))

;; logger-core-runtime-helpers : (listof core-runtime-helper?)
;;   Enumerate logger helpers available in the standalone core runtime.
(define logger-core-runtime-helpers
  (select-runtime-helpers logger-all-runtime-helpers
                          logger-promoted-runtime-helper-names))

;; logger-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate logger helpers that still depend on monolithic runtime globals.
(define logger-runtime-only-helpers
  (remove-runtime-helpers logger-all-runtime-helpers
                          logger-promoted-runtime-helper-names))

;; logger-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for logger helpers.
(define logger-runtime-only-helper-names
  (remove* logger-promoted-runtime-helper-names
           logger-helper-names
           eq?))

;; logger-core-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render promoted logger helpers in runtime assembly order.
(define (logger-core-runtime-helper-forms helper-index)
  (for/list ([name (in-list logger-promoted-runtime-helper-names)])
    (core-runtime-helper-form helper-index name)))

;; logger-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render logger helpers in runtime assembly order.
(define (logger-runtime-helper-forms helper-index)
  (for/list ([name (in-list logger-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define logger-core-helper-index
    (make-core-runtime-helper-index logger-core-runtime-helpers))

  (define logger-helper-index
    (make-core-runtime-helper-index
     (append logger-core-runtime-helpers
             logger-runtime-only-helpers)))

  (check-equal?
   (map core-runtime-helper-name logger-core-runtime-helpers)
   logger-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (logger-core-runtime-helper-forms logger-core-helper-index))
   logger-promoted-runtime-helper-names)

  (check-equal?
   (map form-name (logger-runtime-helper-forms logger-helper-index))
   logger-runtime-only-helper-names))
