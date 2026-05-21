#lang racket/base

;; Generated-style unsafe surface for `ffi/console.ffi`.
;; Raw exports resolve to active `.ffi` primitive closures at compile time.

(require (only-in "../private/ffi.rkt" unsafe-ffi-primitive))

(provide js-console-log
         js-console-info
         js-console-warn
         js-console-error
         js-console-debug
         js-console-assert
         js-console-clear
         js-console-dir
         js-console-dirxml
         js-console-table
         js-console-group
         js-console-group-collapsed
         js-console-group-end
         js-console-count
         js-console-count-reset
         js-console-time
         js-console-time-end
         js-console-time-log
         js-console-time-stamp
         js-console-trace
         js-console-profile
         js-console-profile-end
         js-console-exception)

;; js-console-log : ffi (value) -> ()
;;   Raw console log binding.
(define js-console-log (unsafe-ffi-primitive 'js-console-log))

;; js-console-info : ffi (value) -> ()
;;   Raw console info binding.
(define js-console-info (unsafe-ffi-primitive 'js-console-info))

;; js-console-warn : ffi (value) -> ()
;;   Raw console warn binding.
(define js-console-warn (unsafe-ffi-primitive 'js-console-warn))

;; js-console-error : ffi (value) -> ()
;;   Raw console error binding.
(define js-console-error (unsafe-ffi-primitive 'js-console-error))

;; js-console-debug : ffi (value) -> ()
;;   Raw console debug binding.
(define js-console-debug (unsafe-ffi-primitive 'js-console-debug))

;; js-console-assert : ffi (value) -> ()
;;   Raw console assert binding.
(define js-console-assert (unsafe-ffi-primitive 'js-console-assert))

;; js-console-clear : ffi () -> ()
;;   Raw console clear binding.
(define js-console-clear (unsafe-ffi-primitive 'js-console-clear))

;; js-console-dir : ffi (value) -> ()
;;   Raw console dir binding.
(define js-console-dir (unsafe-ffi-primitive 'js-console-dir))

;; js-console-dirxml : ffi (value) -> ()
;;   Raw console dirxml binding.
(define js-console-dirxml (unsafe-ffi-primitive 'js-console-dirxml))

;; js-console-table : ffi (value) -> ()
;;   Raw console table binding.
(define js-console-table (unsafe-ffi-primitive 'js-console-table))

;; js-console-group : ffi (value) -> ()
;;   Raw console group binding.
(define js-console-group (unsafe-ffi-primitive 'js-console-group))

;; js-console-group-collapsed : ffi (value) -> ()
;;   Raw console collapsed group binding.
(define js-console-group-collapsed
  (unsafe-ffi-primitive 'js-console-group-collapsed))

;; js-console-group-end : ffi () -> ()
;;   Raw console group-end binding.
(define js-console-group-end (unsafe-ffi-primitive 'js-console-group-end))

;; js-console-count : ffi (value) -> ()
;;   Raw console count binding.
(define js-console-count (unsafe-ffi-primitive 'js-console-count))

;; js-console-count-reset : ffi (value) -> ()
;;   Raw console count-reset binding.
(define js-console-count-reset
  (unsafe-ffi-primitive 'js-console-count-reset))

;; js-console-time : ffi (value) -> ()
;;   Raw console time binding.
(define js-console-time (unsafe-ffi-primitive 'js-console-time))

;; js-console-time-end : ffi (value) -> ()
;;   Raw console time-end binding.
(define js-console-time-end (unsafe-ffi-primitive 'js-console-time-end))

;; js-console-time-log : ffi (value) -> ()
;;   Raw console time-log binding.
(define js-console-time-log (unsafe-ffi-primitive 'js-console-time-log))

;; js-console-time-stamp : ffi (value) -> ()
;;   Raw console time-stamp binding.
(define js-console-time-stamp
  (unsafe-ffi-primitive 'js-console-time-stamp))

;; js-console-trace : ffi (value) -> ()
;;   Raw console trace binding.
(define js-console-trace (unsafe-ffi-primitive 'js-console-trace))

;; js-console-profile : ffi (value) -> ()
;;   Raw console profile binding.
(define js-console-profile (unsafe-ffi-primitive 'js-console-profile))

;; js-console-profile-end : ffi (value) -> ()
;;   Raw console profile-end binding.
(define js-console-profile-end
  (unsafe-ffi-primitive 'js-console-profile-end))

;; js-console-exception : ffi (value) -> ()
;;   Raw console exception binding.
(define js-console-exception (unsafe-ffi-primitive 'js-console-exception))
