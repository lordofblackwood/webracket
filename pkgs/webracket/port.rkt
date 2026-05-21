#lang racket/base

(provide port->string)

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
