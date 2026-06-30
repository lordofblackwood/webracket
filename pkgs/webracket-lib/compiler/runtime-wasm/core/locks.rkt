#lang racket

(provide lock-runtime-only-helpers)

(require "../core-helper.rkt")

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
                 (then (unreachable)))
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
                 (then (unreachable)))
             (global.get $void))))
))
