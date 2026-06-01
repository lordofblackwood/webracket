#lang racket/base

(require (only-in "private/format.rkt"
                  [format wr-format]))

(provide pretty-display
         pretty-format
         pretty-print
         pretty-print-.-symbol-without-bars
         pretty-print-abbreviate-read-macros
         pretty-print-columns
         pretty-print-current-style-table
         pretty-print-depth
         pretty-print-exact-as-decimal
         pretty-print-extend-style-table
         pretty-print-handler
         pretty-print-newline
         pretty-print-post-print-hook
         pretty-print-pre-print-hook
         pretty-print-print-hook
         pretty-print-print-line
         pretty-print-remap-stylable
         pretty-print-show-inexactness
         pretty-print-size-hook
         pretty-print-style-table?
         pretty-printing
         pretty-write)

;; A small contract-free `racket/pretty` substitute for Goal 1 module
;; programs. It follows the Reference entry points, but intentionally ignores
;; column-sensitive layout and pretty-printer hooks for now.

(define pretty-print-columns (make-parameter 79))
(define pretty-print-depth (make-parameter #f))
(define pretty-print-exact-as-decimal (make-parameter #f))
(define pretty-print-.-symbol-without-bars (make-parameter #f))
(define pretty-print-show-inexactness (make-parameter #f))
(define pretty-print-abbreviate-read-macros (make-parameter #t))
(define pretty-print-current-style-table (make-parameter #f))
(define pretty-print-remap-stylable (make-parameter (lambda (v) #f)))
(define pretty-print-size-hook (make-parameter (lambda (v display? out) #f)))
(define pretty-print-print-hook
  (make-parameter
   (lambda (v display? out)
     (display (pretty-value->string v (if display? 'display 'write)) out))))
(define pretty-print-print-line
  (make-parameter
   (lambda (line out offset width)
     ;; The full pretty printer uses this callback while breaking output into
     ;; columns. This compact provider accepts the hook but does not compute
     ;; indentation, so it reports that no extra characters were printed.
     (when (and line (positive? line))
       (newline out))
     0)))
(define pretty-print-pre-print-hook (make-parameter (lambda (v out) (void))))
(define pretty-print-post-print-hook (make-parameter (lambda (v out) (void))))
(define pretty-printing (make-parameter #f))

;; pretty-print-style-table? : any/c -> boolean?
;;   Recognize the staged style-table representation.
(define (pretty-print-style-table? v)
  (or (not v) (hash? v)))

;; pretty-print-extend-style-table : style-table? list? list? -> style-table?
;;   Record a compact mapping table for code that expects the API.
(define (pretty-print-extend-style-table style-table symbol-list like-symbol-list)
  (unless (pretty-print-style-table? style-table)
    (raise-argument-error 'pretty-print-extend-style-table
                          "pretty-print-style-table?"
                          style-table))
  (unless (= (length symbol-list) (length like-symbol-list))
    (raise-argument-error 'pretty-print-extend-style-table
                          "lists of the same length"
                          like-symbol-list))
  (let loop ([table (or style-table (hash))]
             [symbols symbol-list]
             [like-symbols like-symbol-list])
    (cond
      [(null? symbols) table]
      [else
       (loop (hash-set table (car symbols) (car like-symbols))
             (cdr symbols)
             (cdr like-symbols))])))

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

;; write-pretty-value : any/c output-port? symbol? -> void?
;;   Write v through the basic pretty hooks while layout remains compact.
(define (write-pretty-value v out mode)
  ((pretty-print-pre-print-hook) v out)
  (parameterize ([pretty-printing #t])
    (case mode
      [(display) (display (pretty-value->string v 'display) out)]
      [(write) (display (pretty-value->string v 'write) out)]
      [(print) ((pretty-print-print-hook) v #f out)]
      [else (raise-argument-error 'pretty-output "(or/c 'print 'write 'display)" mode)]))
  ((pretty-print-post-print-hook) v out))

;; pretty-format : any/c [exact-nonnegative-integer?] #:mode symbol? -> string?
;;   Return a pretty-printed string. The columns argument is accepted for
;;   compatibility and currently ignored; default: (pretty-print-columns).
(define (pretty-format v [columns (pretty-print-columns)] #:mode [mode 'print])
  (unless (or (eq? columns 'infinity)
              (and (exact-nonnegative-integer? columns)
                   (positive? columns)))
    (raise-argument-error 'pretty-format
                          "(or/c exact-positive-integer? 'infinity)"
                          columns))
  (pretty-value->string v mode))

;; pretty-print-handler : any/c -> void?
;;   Print non-void REPL values through the staged pretty printer.
(define (pretty-print-handler v)
  (unless (void? v)
    (pretty-print v)))

;; pretty-print-newline : output-port? exact-nonnegative-integer? -> void?
;;   Emit a newline; column-sensitive indentation is postponed.
(define (pretty-print-newline out column)
  (newline out))

;; pretty-print : any/c [output-port?] [0-or-1?] #:newline? boolean? -> void?
;;   Print v in print mode. The quote-depth argument is accepted for
;;   compatibility and currently ignored; default: 0.
(define (pretty-print v [out (current-output-port)] [quote-depth 0]
                      #:newline? [newline? #t])
  (unless (or (equal? quote-depth 0) (equal? quote-depth 1))
    (raise-argument-error 'pretty-print "(or/c 0 1)" quote-depth))
  (write-pretty-value v out 'print)
  (maybe-newline out newline?))

;; pretty-write : any/c [output-port?] #:newline? boolean? -> void?
;;   Print v in write mode.
(define (pretty-write v [out (current-output-port)] #:newline? [newline? #t])
  (write-pretty-value v out 'write)
  (maybe-newline out newline?))

;; pretty-display : any/c [output-port?] #:newline? boolean? -> void?
;;   Print v in display mode.
(define (pretty-display v [out (current-output-port)] #:newline? [newline? #t])
  (write-pretty-value v out 'display)
  (maybe-newline out newline?))
