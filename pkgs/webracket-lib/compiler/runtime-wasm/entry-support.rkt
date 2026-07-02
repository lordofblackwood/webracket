#lang racket

(provide entry-support-forms)

;; entry-support-forms : (listof datum?)
;;   Declare static exported entry support helpers.
(define entry-support-forms
  '(
               (func $get-bytes (export "get_bytes")
                     (result (ref $Bytes))
                     (ref.cast (ref $Bytes) (global.get $result-bytes)))

               (func $entry-uncaught-exception2
                     (param $e (ref eq))
                     (local $message (ref eq))

                     ;; Keep this intentionally verbose for bootstrap probes:
                     ;; a malformed exception may have an undefined message,
                     ;; so log both the full exception shape and its message.
                     (drop (call $js-log (call $format/display (local.get $e))))
                     (local.set $message (call $exn-message (local.get $e)))
                     (drop (call $js-log (local.get $message)))
                     (drop (call $js-log (call $format/display (local.get $message)))))

               (func $entry-uncaught-exception1
                     (param $e (ref eq))
                     (drop (call $js-log (local.get $e))))

               (func $entry-uncaught-exception
                     (param $e (ref eq))
                     (if (ref.eq (call $exn? (local.get $e)) (global.get $false))
                         (then
                         (call $entry-uncaught-exception1 (local.get $e)))
                         (else
                          (call $entry-uncaught-exception2 (local.get $e))))
                     (throw $exn (local.get $e)))))
