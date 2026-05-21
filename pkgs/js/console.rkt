#lang racket/base

(require (prefix-in unsafe: webracket/unsafe/console))

(provide console-log
         console-info
         console-warn
         console-error
         console-debug
         console-assert
         console-clear
         console-dir
         console-dirxml
         console-table
         console-group
         console-group-collapsed
         console-group-end
         console-count
         console-count-reset
         console-time
         console-time-end
         console-time-log
         console-time-stamp
         console-trace
         console-profile
         console-profile-end
         console-exception)

;; console-textish->string : symbol? (or/c string? symbol?) -> string?
;;   Convert a label-like value to the string expected by browser console methods.
(define (console-textish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" v)]))

;; console-args->vector : (listof any/c) -> vector?
;;   Pack console arguments into the vector shape expected by the raw bindings.
(define (console-args->vector args)
  (list->vector args))

;; console-normalize-value : any/c -> any/c
;;   Convert a symbol to a string and leave other values unchanged.
(define (console-normalize-value v)
  (if (symbol? v)
      (symbol->string v)
      v))

;; console-normalize-args : (listof any/c) -> (listof any/c)
;;   Normalize console arguments before packing them for the raw binding.
(define (console-normalize-args args)
  (let loop ([args args])
    (cond
      [(null? args) '()]
      [else (cons (console-normalize-value (car args))
                  (loop (cdr args)))])))

;; console-log : any/c ... -> void?
;;   Write a log message.
(define (console-log . args)
  (unsafe:js-console-log (console-args->vector (console-normalize-args args)))
  (void))

;; console-info : any/c ... -> void?
;;   Write an informational message.
(define (console-info . args)
  (unsafe:js-console-info (console-args->vector (console-normalize-args args)))
  (void))

;; console-warn : any/c ... -> void?
;;   Write a warning message.
(define (console-warn . args)
  (unsafe:js-console-warn (console-args->vector (console-normalize-args args)))
  (void))

;; console-error : any/c ... -> void?
;;   Write an error message.
(define (console-error . args)
  (unsafe:js-console-error (console-args->vector (console-normalize-args args)))
  (void))

;; console-debug : any/c ... -> void?
;;   Write a debug message.
(define (console-debug . args)
  (unsafe:js-console-debug (console-args->vector (console-normalize-args args)))
  (void))

;; console-assert : any/c any/c ... -> void?
;;   Report an assertion failure when the condition is false.
(define (console-assert condition . args)
  (unsafe:js-console-assert
   (console-args->vector
    (cons condition (console-normalize-args args))))
  (void))

;; console-clear : -> void?
;;   Clear the console.
(define (console-clear)
  (unsafe:js-console-clear)
  (void))

;; console-dir : any/c [any/c] -> void?
;;   Inspect a value in the console.
(define (console-dir value [options #f])
  (cond
    [(eq? options #f)
     (unsafe:js-console-dir (console-args->vector (list value)))
     (void)]
    [else
     (unsafe:js-console-dir
      (console-args->vector (list (console-normalize-value value) options)))
     (void)]))

;; console-dirxml : any/c ... -> void?
;;   Inspect XML/HTML output in the console.
(define (console-dirxml . args)
  (unsafe:js-console-dirxml (console-args->vector (console-normalize-args args)))
  (void))

;; console-table : any/c [any/c] -> void?
;;   Display tabular data.
(define (console-table data [columns #f])
  (cond
    [(eq? columns #f)
     (unsafe:js-console-table (console-args->vector (list data)))
     (void)]
    [else
     (unsafe:js-console-table
      (console-args->vector
       (list (console-normalize-value data) columns)))
     (void)]))

;; console-group : any/c ... -> void?
;;   Start a new console group.
(define (console-group . args)
  (unsafe:js-console-group (console-args->vector (console-normalize-args args)))
  (void))

;; console-group-collapsed : any/c ... -> void?
;;   Start a collapsed console group.
(define (console-group-collapsed . args)
  (unsafe:js-console-group-collapsed
   (console-args->vector (console-normalize-args args)))
  (void))

;; console-group-end : -> void?
;;   End the current console group.
(define (console-group-end)
  (unsafe:js-console-group-end)
  (void))

;; console-count : [label (or/c #f string? symbol?)] -> void?
;;   Increment and display a counter.
(define (console-count [label #f])
  (if (eq? label #f)
      (unsafe:js-console-count (void))
      (unsafe:js-console-count
       (console-args->vector
        (list (console-textish->string 'console-count label)))))
  (void))

;; console-count-reset : [label (or/c #f string? symbol?)] -> void?
;;   Reset a counter.
(define (console-count-reset [label #f])
  (if (eq? label #f)
      (unsafe:js-console-count-reset (void))
      (unsafe:js-console-count-reset
       (console-args->vector
        (list (console-textish->string 'console-count-reset label)))))
  (void))

;; console-time : [label (or/c #f string? symbol?)] -> void?
;;   Start a timer.
(define (console-time [label #f])
  (if (eq? label #f)
      (unsafe:js-console-time (void))
      (unsafe:js-console-time
       (console-args->vector
        (list (console-textish->string 'console-time label)))))
  (void))

;; console-time-end : [label (or/c #f string? symbol?)] -> void?
;;   End a timer.
(define (console-time-end [label #f])
  (if (eq? label #f)
      (unsafe:js-console-time-end (void))
      (unsafe:js-console-time-end
       (console-args->vector
        (list (console-textish->string 'console-time-end label)))))
  (void))

;; console-time-log : [label (or/c #f string? symbol?)] any/c ... -> void?
;;   Log the current timer value and any additional data.
(define (console-time-log [label #f] . args)
  (define prefix
    (if (eq? label #f)
        '()
        (list (console-textish->string 'console-time-log label))))
  (unsafe:js-console-time-log
   (console-args->vector (append prefix (console-normalize-args args))))
  (void))

;; console-time-stamp : [label (or/c #f string? symbol?)] -> void?
;;   Add a performance timeline marker.
(define (console-time-stamp [label #f])
  (if (eq? label #f)
      (unsafe:js-console-time-stamp (void))
      (unsafe:js-console-time-stamp
       (console-args->vector
        (list (console-textish->string 'console-time-stamp label)))))
  (void))

;; console-trace : any/c ... -> void?
;;   Write a stack trace.
(define (console-trace . args)
  (unsafe:js-console-trace (console-args->vector (console-normalize-args args)))
  (void))

;; console-profile : [label (or/c #f string? symbol?)] -> void?
;;   Start a profiler session.
(define (console-profile [label #f])
  (if (eq? label #f)
      (unsafe:js-console-profile (void))
      (unsafe:js-console-profile
       (console-args->vector
        (list (console-textish->string 'console-profile label)))))
  (void))

;; console-profile-end : [label (or/c #f string? symbol?)] -> void?
;;   End a profiler session.
(define (console-profile-end [label #f])
  (if (eq? label #f)
      (unsafe:js-console-profile-end (void))
      (unsafe:js-console-profile-end
       (console-args->vector
        (list (console-textish->string 'console-profile-end label)))))
  (void))

;; console-exception : any/c ... -> void?
;;   Deprecated alias for `console-error`.
(define (console-exception . args)
  (unsafe:js-console-exception (console-args->vector (console-normalize-args args)))
  (void))
