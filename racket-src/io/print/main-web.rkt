#lang racket/base

;;; WebRacket-facing public print provider seed.
;;;
;;; This module gives Webify a cell-only provider target for the high-level
;;; printing names while the full upstream `print/main.rkt` closure is being
;;; staged. It routes through the same handler-aware adapter used by io/format.

(require "../format/printf-adapter.rkt")

(provide display
         displayln
         newline
         print
         println
         write
         writeln)

;; display : any/c [output-port?] -> void?
;;   Display through the port display handler path.
(define (display v [o (current-output-port)])
  (display-via-handler 'display v o))

;; write : any/c [output-port?] -> void?
;;   Write through the port write handler path.
(define (write v [o (current-output-port)])
  (write-via-handler 'write v o))

;; print : any/c [output-port?] [any/c] -> void?
;;   Print through the staged adapter; quote-depth support is still incomplete.
(define (print v [o (current-output-port)] [quote-depth PRINT-MODE/UNQUOTED])
  (print-via-handler 'print v o quote-depth))

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
