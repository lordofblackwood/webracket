#lang racket/base

;;; WebRacket-facing public print provider seed.
;;;
;;; This module gives Webify a cell-only provider target for the high-level
;;; printing names while the full upstream `print/main.rkt` closure is being
;;; staged. It routes through the same handler-aware adapter used by io/format.

(require racket/port
         "../format/printf-adapter.rkt")

(provide display
         displayln
         do-display
         do-print
         do-write
         newline
         print
         println
         write
         writeln)

;; display : any/c [output-port?] -> void?
;;   Display through the port display handler path.
(define (display v [o (current-output-port)])
  (define core-o (->core-output-port o 'display))
  (define handler (port-display-handler core-o))
  (if handler
      (handler v core-o)
      (do-display 'display v core-o)))

;; do-display : symbol? any/c output-port? -> void?
;;   Default display path for the provider seed.
(define (do-display who v o)
  (display-via-handler who v o))

;; write : any/c [output-port?] -> void?
;;   Write through the port write handler path.
(define (write v [o (current-output-port)])
  (define core-o (->core-output-port o 'write))
  (define handler (port-write-handler core-o))
  (if handler
      (handler v core-o)
      (do-write 'write v core-o)))

;; do-write : symbol? any/c output-port? -> void?
;;   Default write path for the provider seed.
(define (do-write who v o)
  (write-via-handler who v o))

;; print : any/c [output-port?] [any/c] -> void?
;;   Print through the staged adapter; quote-depth support is still incomplete.
(define (print v [o (current-output-port)] [quote-depth PRINT-MODE/UNQUOTED])
  (define core-o (->core-output-port o 'print))
  (define handler (port-print-handler core-o))
  (if handler
      (handler v core-o quote-depth)
      (do-print 'print v core-o quote-depth)))

;; do-print : symbol? any/c output-port? any/c -> void?
;;   Default print path for the provider seed.
(define (do-print who v o quote-depth)
  (print-via-handler who v o quote-depth))

;; newline : [output-port?] -> void?
;;   Write one linefeed to the target port.
(define (newline [o (current-output-port)])
  (write-string "\n" o))

;; displayln : any/c [output-port?] -> void?
;;   Display a value followed by a newline.
(define (displayln v [o (current-output-port)])
  (display v o)
  (newline o))

;; writeln : any/c [output-port?] -> void?
;;   Write a value followed by a newline.
(define (writeln v [o (current-output-port)])
  (write v o)
  (newline o))

;; println : any/c [output-port?] [any/c] -> void?
;;   Print a value followed by a newline.
(define (println v [o (current-output-port)] [quote-depth PRINT-MODE/UNQUOTED])
  (print v o quote-depth)
  (newline o))
