#lang racket/base

;;; Minimal adapter for `format/printf.rkt`.
;;;
;;; This module intentionally avoids requiring the full `io/print/main.rkt`
;;; transitive closure. It provides only the names that `format/printf.rkt`
;;; actually uses, delegating to the host/WebRacket-visible print and port
;;; surface. That keeps the next WebRacket provider step small.
;;;
;;; The adapter deliberately routes printing through port handler primitives
;;; instead of the public `display`, `write`, and `print` bindings. That keeps
;;; the staged provider usable in `--no-stdlib` module composition, where those
;;; public names may not exist yet.

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
         print-boolean-long-form
         print-unreadable
         write-string)

(define PRINT-MODE/UNQUOTED 0)

;; Re-export racket/base's `error-print-width` so `~.` directives observe the
;; same parameter that user programs set.
(define print-boolean-long-form (make-parameter #f))
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
  (define core-o (->core-output-port o who))
  ((port-display-handler core-o) v core-o))

;; write-via-handler : symbol? any/c output-port? -> void?
;;   Adapter for io/print's write handler path.
(define (write-via-handler who v o)
  (define core-o (->core-output-port o who))
  ((port-write-handler core-o) v core-o))

;; print-via-handler : symbol? any/c output-port? any/c -> void?
;;   Adapter for io/print's print handler path.
(define (print-via-handler who v o mode)
  (define core-o (->core-output-port o who))
  ((port-print-handler core-o) v core-o mode))

;; truncate-to-width : string? any/c -> string?
;;   Apply Racket's error-print-width truncation convention.
(define (truncate-to-width str width)
  (cond
    [(not (exact-nonnegative-integer? width)) str]
    [(<= (string-length str) width) str]
    [(<= width 3) (substring "..." 0 width)]
    [else (string-append (substring str 0 (- width 3)) "...")]))

;; call-with-limited-output : output-port? any/c (output-port? -> any/c) -> void?
;;   Render through a temporary string port when a max length is requested.
(define (call-with-limited-output o max-length proc)
  (cond
    [(not (exact-nonnegative-integer? max-length))
     (proc o)]
    [else
     (define tmp (open-output-string))
     (proc tmp)
     (write-string (truncate-to-width (get-output-string tmp) max-length) o)]))

;; do-display : symbol? any/c output-port? [exact-nonnegative-integer?] -> void?
;;   Width-aware display adapter.
(define (do-display who v o [max-length #f])
  (call-with-limited-output
   o max-length
   (lambda (out)
     (display-via-handler who v out))))

;; do-write : symbol? any/c output-port? [exact-nonnegative-integer?] -> void?
;;   Width-aware write adapter.
(define (do-write who v o [max-length #f])
  (call-with-limited-output
   o max-length
   (lambda (out)
     (write-via-handler who v out))))

;; do-print : symbol? any/c output-port? any/c [exact-nonnegative-integer?] -> void?
;;   Width-aware print adapter.
(define (do-print who v o mode [max-length #f])
  (call-with-limited-output
   o max-length
   (lambda (out)
     (print-via-handler who v out mode))))

;; error-value->string : any/c -> string?
;;   Minimal error-value formatter used by format/printf.rkt error paths.
(define (error-value->string v)
  (define o (open-output-string))
  (parameterize ([print-unreadable #t])
    (write-via-handler 'error-value->string v o))
  (define str (get-output-string o))
  (define width (error-print-width))
  (truncate-to-width str width))
