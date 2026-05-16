#lang racket/base

;;; WebRacket-staged adapter version of Racket's `io/format/main.rkt`.
;;;
;;; This keeps the upstream implementation shape, but routes the formatter
;;; through `printf-web.rkt` and uses host/WebRacket-visible port and print
;;; parameters from `printf-adapter.rkt`.

(require "printf-adapter.rkt"
         "printf-web.rkt")

(provide fprintf
         printf
         eprintf
         format)

(define (check who pred? v contract)
  (unless (pred? v)
    (raise-argument-error who contract v)))

(define (fprintf o fmt . args)
  (check 'fprintf output-port? o "output-port?")
  (check 'fprintf string? fmt "string?")
  (do-printf 'fprintf o fmt args))

(define (printf fmt . args)
  (check 'printf string? fmt "string?")
  (do-printf 'printf (current-output-port) fmt args))

(define (eprintf fmt . args)
  (check 'eprintf string? fmt "string?")
  (do-printf 'eprintf (current-error-port) fmt args))

;; ----------------------------------------

(define (general-format fmt args)
  (check 'format string? fmt "string?")
  (define o (open-output-string))
  (do-printf 'format o fmt args)
  (get-output-string o))

(define (simple-format a)
  (cond
    [(boolean? a) (string-copy (if (print-boolean-long-form)
                                   (if a "#true" "#false")
                                   (if a "#t" "#f")))]
    [(number? a) (number->string a)]
    [else #f]))

(define format
  (case-lambda
    [(fmt a)
     (cond
       [(or (equal? fmt "~a") (equal? fmt "~A"))
        (or (simple-format a)
            (cond
              [(bytes? a) (bytes->string/utf-8 a #\?)]
              [(string? a) (string-copy a)]
              [(symbol? a) (symbol->string a)]
              [(keyword? a) (string-append "#:" (keyword->string a))]
              [else (general-format fmt (list a))]))]
       [(or (equal? fmt "~s") (equal? fmt "~S"))
        (or (simple-format a)
            (general-format fmt (list a)))]
       [else (general-format fmt (list a))])]
    [(fmt . args)
     (general-format fmt args)]))
