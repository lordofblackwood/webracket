#lang webracket/base

(require js/promise
         webracket/unsafe/dom
         (only-in webracket/primitives
                  external?))

(provide (all-defined-out))

;;;
;;; Clipboard wrappers
;;;

;; This library exposes the browser Clipboard API via `navigator.clipboard`.

;; clipboard-stringish->string : symbol? any/c -> string?
;;   Normalize clipboard text input to a browser string.
(define (clipboard-stringish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" v)]))

;; clipboard-info : external/raw -> clipboard-info?
;;   Wrap a browser Clipboard object.
(struct clipboard-info (raw) #:transparent)

;; clipboard-raw : clipboard-info? -> external/raw
;;   Extract the raw Clipboard object.
(define (clipboard-raw value)
  (clipboard-info-raw value))

;; clipboard-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish method named method-name.
(define (clipboard-method-present? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; clipboard-supported-raw : -> (or/c #f external/raw)
;;   Read navigator.clipboard when it is available.
(define (clipboard-supported-raw)
  (define raw (js-ref/extern (js-window-navigator) "clipboard"))
  (and (not (js-nullish? raw))
       (clipboard-method-present? raw "readText")
       (clipboard-method-present? raw "writeText")
       raw))

;; clipboard-supported? : -> boolean?
;;   Report whether the browser exposes navigator.clipboard text helpers.
(define (clipboard-supported?)
  (not (eq? (clipboard-supported-raw) #f)))

;; clipboard : -> (or/c #f clipboard-info?)
;;   Read the browser Clipboard object when it is available.
(define (clipboard)
  (define raw (clipboard-supported-raw))
  (and raw (clipboard-info raw)))

;; clipboard? : any/c -> boolean?
;;   Report whether v is a wrapped Clipboard value.
(define (clipboard? v)
  (and (clipboard-info? v)
       (external? (clipboard-raw v))
       (clipboard-method-present? (clipboard-raw v) "readText")
       (clipboard-method-present? (clipboard-raw v) "writeText")))

;; clipboard-read-text : clipboard-info? -> js-promise?
;;   Start an asynchronous clipboard text read and return a wrapped browser Promise.
(define (clipboard-read-text value)
  (unless (clipboard? value)
    (raise-argument-error 'clipboard-read-text "clipboard-info?" value))
  (js-promise-wrap
   (js-send/extern (clipboard-raw value) "readText" (vector))))

;; clipboard-write-text! : clipboard-info? (or/c string? symbol?) -> js-promise?
;;   Start an asynchronous clipboard text write and return a wrapped browser Promise.
(define (clipboard-write-text! value text)
  (unless (clipboard? value)
    (raise-argument-error 'clipboard-write-text! "clipboard-info?" value))
  (define text* (clipboard-stringish->string 'clipboard-write-text! text))
  (js-promise-wrap
   (js-send/extern (clipboard-raw value) "writeText" (vector text*))))
