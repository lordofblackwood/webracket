#lang racket/base

(require (only-in "format.rkt"
                  [format wr-format]))

(provide pretty-display
         pretty-format
         pretty-print
         pretty-write)

;; A small contract-free `racket/pretty` substitute for Goal 1 module
;; programs. It follows the Reference entry points, but intentionally ignores
;; column-sensitive layout and pretty-printer hooks for now.

;; pretty-value->string : any/c symbol? -> string?
;;   Render v using the selected pretty-format mode.
(define (pretty-value->string v mode)
  (case mode
    [(display) (wr-format "~a" v)]
    [(write print) (wr-format "~s" v)]
    [else (raise-argument-error 'pretty-format "(or/c 'print 'write 'display)" mode)]))

;; maybe-newline : output-port? boolean? -> void?
;;   Emit the optional trailing newline used by pretty output functions.
(define (maybe-newline out newline?)
  (when newline?
    (newline out)))

;; pretty-format : any/c [exact-nonnegative-integer?] #:mode symbol? -> string?
;;   Return a pretty-printed string. The columns argument is accepted for
;;   compatibility and currently ignored; default: (pretty-print-columns).
(define (pretty-format v [columns 79] #:mode [mode 'print])
  (unless (or (eq? columns 'infinity)
              (and (exact-nonnegative-integer? columns)
                   (positive? columns)))
    (raise-argument-error 'pretty-format
                          "(or/c exact-positive-integer? 'infinity)"
                          columns))
  (pretty-value->string v mode))

;; pretty-print : any/c [output-port?] [0-or-1?] #:newline? boolean? -> void?
;;   Print v in print mode. The quote-depth argument is accepted for
;;   compatibility and currently ignored; default: 0.
(define (pretty-print v [out (current-output-port)] [quote-depth 0]
                      #:newline? [newline? #t])
  (unless (or (equal? quote-depth 0) (equal? quote-depth 1))
    (raise-argument-error 'pretty-print "(or/c 0 1)" quote-depth))
  (display (pretty-value->string v 'print) out)
  (maybe-newline out newline?))

;; pretty-write : any/c [output-port?] #:newline? boolean? -> void?
;;   Print v in write mode.
(define (pretty-write v [out (current-output-port)] #:newline? [newline? #t])
  (display (pretty-value->string v 'write) out)
  (maybe-newline out newline?))

;; pretty-display : any/c [output-port?] #:newline? boolean? -> void?
;;   Print v in display mode.
(define (pretty-display v [out (current-output-port)] #:newline? [newline? #t])
  (display (pretty-value->string v 'display) out)
  (maybe-newline out newline?))
