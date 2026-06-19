#lang racket/base

(require (only-in "./primitives.rkt"
                  open-output-string
                  get-output-string))

(provide port->string
         open-output-string
         get-output-string
         call-with-output-string)

;; A small contract-free `racket/port` substitute for Goal 1 module programs.

;; port->string : [input-port?] -> string?
;;   Read all characters from an input port into a string.
(define port->string
  (case-lambda
    [() (port->string (current-input-port))]
    [(in)
     (unless (input-port? in)
       (raise-argument-error 'port->string "input-port?" in))
     (let loop ([chars null])
       (define ch (read-char in))
       (if (eof-object? ch)
           (list->string (reverse chars))
           (loop (cons ch chars))))]))

;; call-with-output-string : (output-port? -> any/c) -> string?
;;   Run proc with a fresh string output port and return the accumulated text.
(define (call-with-output-string proc)
  (unless (procedure? proc)
    (raise-argument-error 'call-with-output-string "procedure?" proc))
  (define out (open-output-string))
  (proc out)
  (get-output-string out))
