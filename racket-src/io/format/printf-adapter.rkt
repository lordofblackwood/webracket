#lang racket/base

;;; Minimal adapter for `format/printf.rkt`.
;;;
;;; This module intentionally avoids requiring the full `io/print/main.rkt`
;;; transitive closure. It provides only the names that `format/printf.rkt`
;;; actually uses, delegating to the host/WebRacket-visible print and port
;;; surface. That keeps the next WebRacket provider step small.

(require racket/port)

(provide ->core-output-port
         PRINT-MODE/UNQUOTED
         display-via-handler
         write-via-handler
         print-via-handler
         do-display
         do-write
         do-print
         error-print-width
         error-value->string
         print-unreadable
         write-string)

(define PRINT-MODE/UNQUOTED 'unquoted)

;; Adapter parameter defaults chosen to match Racket's ordinary error printing.
(define error-print-width (make-parameter 1024))
(define print-unreadable (make-parameter #t))

;; ->core-output-port : output-port? [symbol?] -> output-port?
;;   In WebRacket the primitive output port is already the core output port.
(define (->core-output-port o [who '->core-output-port])
  (unless (output-port? o)
    (raise-argument-error who "output-port?" o))
  o)

;; display-via-handler : symbol? any/c output-port? -> void?
;;   Adapter for io/print's display handler path.
(define (display-via-handler who v o)
  (display v (->core-output-port o who)))

;; write-via-handler : symbol? any/c output-port? -> void?
;;   Adapter for io/print's write handler path.
(define (write-via-handler who v o)
  (write v (->core-output-port o who)))

;; print-via-handler : symbol? any/c output-port? any/c -> void?
;;   Adapter for io/print's print handler path.
(define (print-via-handler who v o _mode)
  (print v (->core-output-port o who)))

;; do-display : symbol? any/c output-port? [exact-nonnegative-integer?] -> void?
;;   Width-aware display adapter. The initial WebRacket bridge ignores width.
(define (do-display who v o [max-length #f])
  (display-via-handler who v o))

;; do-write : symbol? any/c output-port? [exact-nonnegative-integer?] -> void?
;;   Width-aware write adapter. The initial WebRacket bridge ignores width.
(define (do-write who v o [max-length #f])
  (write-via-handler who v o))

;; do-print : symbol? any/c output-port? any/c [exact-nonnegative-integer?] -> void?
;;   Width-aware print adapter. The initial WebRacket bridge ignores width.
(define (do-print who v o mode [max-length #f])
  (print-via-handler who v o mode))

;; error-value->string : any/c -> string?
;;   Minimal error-value formatter used by format/printf.rkt error paths.
(define (error-value->string v)
  (define o (open-output-string))
  (parameterize ([print-unreadable #t])
    (write v o))
  (define str (get-output-string o))
  (define width (error-print-width))
  (cond
    [(not (exact-nonnegative-integer? width)) str]
    [(<= (string-length str) width) str]
    [(<= width 3) (substring str 0 width)]
    [else (string-append (substring str 0 (- width 3)) "...")]))
