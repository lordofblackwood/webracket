#lang racket

(provide logger-current-global-forms
         logger-runtime-symbol-constants
         logger-current-initializer-forms
         logger-runtime-only-helpers)

(require "../core-helper.rkt")

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
    log-message))

;; logger-current-global-forms : (listof datum?)
;;   Declare the current logger global.
(define logger-current-global-forms
  '(
               (global $current-logger-value      (mut (ref eq)) (global.get $false))))

;; logger-current-initializer-forms : (listof datum?)
;;   Initialize the root logger.
(define logger-current-initializer-forms
  '(
                     (global.set $current-logger-value
                                 (struct.new $Logger
                                             (i32.const 0)
                                             (global.get $false)))))

;; logger-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate logger helpers that still depend on monolithic runtime globals.
(define logger-runtime-only-helpers
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
             (global.get $void))))
))
