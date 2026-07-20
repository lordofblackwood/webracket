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

;; clipboard-core-methods-present? : external/raw -> boolean?
;;   Report whether raw has the required Clipboard text methods.
(define (clipboard-core-methods-present? raw)
  (and (clipboard-method-present? raw "readText")
       (clipboard-method-present? raw "writeText")))

;; clipboard-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (clipboard-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; clipboard-supported-raw : -> (or/c #f external/raw)
;;   Read navigator.clipboard when it is available.
(define (clipboard-supported-raw)
  (with-handlers ([exn:fail? (lambda (_e) #f)])
    (define raw (js-ref/extern (js-window-navigator) "clipboard"))
    (and (not (js-nullish? raw))
         (clipboard-core-methods-present? raw)
         raw)))

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
  (and (clipboard-host-value? v)
       (clipboard-core-methods-present? (clipboard-raw v))))

;; clipboard-host-value? : any/c -> boolean?
;;   Report whether v wraps an external Clipboard-like host value.
(define (clipboard-host-value? v)
  (and (clipboard-info? v)
       (clipboard-raw-host-value? (clipboard-raw v))))

;; check-clipboard : symbol? any/c -> void?
;;   Ensure value wraps an external Clipboard-like host value.
(define (check-clipboard who value)
  (unless (clipboard-host-value? value)
    (raise-argument-error who "clipboard-info?" value)))

;; check-clipboard-method : symbol? clipboard-info? string? -> void?
;;   Ensure a required Clipboard method is available.
(define (check-clipboard-method who value method-name)
  (unless (clipboard-method-present? (clipboard-raw value) method-name)
    (raise-arguments-error who
                           (string-append "Clipboard." method-name " is not available"))))

;; clipboard-read-text : clipboard-info? -> js-promise?
;;   Start an asynchronous clipboard text read and return a wrapped browser Promise.
(define (clipboard-read-text value)
  (check-clipboard 'clipboard-read-text value)
  (check-clipboard-method 'clipboard-read-text value "readText")
  (js-promise-wrap
   (js-send/extern (clipboard-raw value) "readText" (vector))))

;; clipboard-write-text! : clipboard-info? (or/c string? symbol?) -> js-promise?
;;   Start an asynchronous clipboard text write and return a wrapped browser Promise.
(define (clipboard-write-text! value text)
  (check-clipboard 'clipboard-write-text! value)
  (check-clipboard-method 'clipboard-write-text! value "writeText")
  (define text* (clipboard-stringish->string 'clipboard-write-text! text))
  (js-promise-wrap
   (js-send/extern (clipboard-raw value) "writeText" (vector text*))))
