#lang racket

(provide lock-runtime-string-constants
         lock-runtime-symbol-constants
         lock-runtime-helper-forms
         lock-runtime-only-helpers)

(require "../core-helper.rkt")

;; lock-runtime-string-constants : (listof (list/c symbol? string?))
;;   Declare strings used by uninterruptible-lock contract checks.
(define lock-runtime-string-constants
  '((uninterruptible-lock? "uninterruptible-lock?")))

;; lock-runtime-symbol-constants : (listof symbol?)
;;   Declare symbols used by uninterruptible-lock contract checks.
(define lock-runtime-symbol-constants
  '(unsafe-uninterruptible-lock-acquire
    unsafe-uninterruptible-lock-release))

;; lock-runtime-only-helpers : (listof core-runtime-helper?)
;;   Enumerate lock helpers that still depend on monolithic runtime globals.
(define lock-runtime-only-helpers
  (list
   ;; unsafe-make-uninterruptible-lock : -> lock?
   ;;   Create an opaque single-threaded lock token.
   (core-runtime-helper
    '$unsafe-make-uninterruptible-lock
    "$unsafe-make-uninterruptible-lock"
    (lambda ()
      `(func $unsafe-make-uninterruptible-lock (type $Prim0)
             (result (ref eq))
             (struct.new $UninterruptibleLock (i32.const 0)))))


   ;; unsafe-uninterruptible-lock-acquire : lock? -> void?
   ;;   No-op acquire for WebRacket's current single-threaded runtime.
   (core-runtime-helper
    '$unsafe-uninterruptible-lock-acquire
    "$unsafe-uninterruptible-lock-acquire"
    (lambda ()
      `(func $unsafe-uninterruptible-lock-acquire (type $Prim1)
             (param $lock (ref eq)) ;; uninterruptible lock
             (result      (ref eq))
             (if (i32.eqz (ref.test (ref $UninterruptibleLock) (local.get $lock)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:unsafe-uninterruptible-lock-acquire)
                             (global.get $string:uninterruptible-lock?)
                             (local.get $lock))
                       (unreachable)))
             (global.get $void))))


   ;; unsafe-uninterruptible-lock-release : lock? -> void?
   ;;   No-op release for WebRacket's current single-threaded runtime.
   (core-runtime-helper
    '$unsafe-uninterruptible-lock-release
    "$unsafe-uninterruptible-lock-release"
    (lambda ()
      `(func $unsafe-uninterruptible-lock-release (type $Prim1)
             (param $lock (ref eq)) ;; uninterruptible lock
             (result      (ref eq))
             (if (i32.eqz (ref.test (ref $UninterruptibleLock) (local.get $lock)))
                 (then (call $raise-argument-error1
                             (global.get $symbol:unsafe-uninterruptible-lock-release)
                             (global.get $string:uninterruptible-lock?)
                             (local.get $lock))
                       (unreachable)))
             (global.get $void))))
))

;; lock-runtime-only-helper-names : (listof symbol?)
;;   Preserve the runtime emission order for uninterruptible-lock helpers.
(define lock-runtime-only-helper-names
  '($unsafe-make-uninterruptible-lock
    $unsafe-uninterruptible-lock-acquire
    $unsafe-uninterruptible-lock-release))

;; lock-runtime-helper-forms : hasheq? -> (listof datum?)
;;   Render uninterruptible-lock helpers in runtime assembly order.
(define (lock-runtime-helper-forms helper-index)
  (for/list ([name (in-list lock-runtime-only-helper-names)])
    (core-runtime-helper-form helper-index name)))

(module+ test
  (require rackunit)

  ;; form-name : datum? -> symbol?
  ;;   Return the function name from a rendered helper form.
  (define (form-name form)
    (second form))

  (define lock-helper-index
    (make-core-runtime-helper-index lock-runtime-only-helpers))

  (check-equal?
   (map form-name (lock-runtime-helper-forms lock-helper-index))
   lock-runtime-only-helper-names))
