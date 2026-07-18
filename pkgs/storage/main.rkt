#lang webracket/base

(require webracket/unsafe/dom
         (only-in webracket/primitives
                  external?))

(provide (all-defined-out))

;;;
;;; Web Storage wrappers
;;;

;; This library exposes direct `localStorage` and `sessionStorage`
;; wrappers on top of the browser's `Storage` object.

;; storage-stringish->string : symbol? any/c -> string?
;;   Normalize a storage key or value to a browser string.
(define (storage-stringish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" v)]))

;; storage-info : external/raw -> storage-info?
;;   Wrap a browser Storage object.
(struct storage-info (raw) #:transparent)

;; storage : external/raw -> storage-info?
;;   Wrap a browser Storage object.
(define (storage raw)
  (storage-info raw))

;; storage-raw : storage-info? -> external/raw
;;   Extract the raw Storage object.
(define (storage-raw value)
  (storage-info-raw value))

;; storage? : any/c -> boolean?
;;   Report whether v is a wrapped Storage value.
(define (storage? v)
  (and (storage-info? v)
       (external? (storage-raw v))
       (storage-method-present? (storage-raw v) "key")
       (storage-method-present? (storage-raw v) "getItem")
       (storage-method-present? (storage-raw v) "setItem")
       (storage-method-present? (storage-raw v) "removeItem")
       (storage-method-present? (storage-raw v) "clear")))

;; storage-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable Storage method.
(define (storage-method-present? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; storage-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish property named property-name.
(define (storage-property-present? raw property-name)
  (not (js-nullish? (js-ref/extern raw property-name))))

;; check-storage : symbol? any/c -> void?
;;   Ensure value wraps an external Storage-like host value.
(define (check-storage who value)
  (unless (and (storage-info? value)
               (external? (storage-raw value)))
    (raise-argument-error who "storage-info?" value)))

;; check-storage-method : symbol? storage-info? string? -> void?
;;   Ensure a required Storage method is available.
(define (check-storage-method who value method-name)
  (unless (storage-method-present? (storage-raw value) method-name)
    (raise-arguments-error who
                           (string-append "Storage." method-name " is not available"))))

;; check-storage-property : symbol? storage-info? string? -> void?
;;   Ensure a required Storage property is available.
(define (check-storage-property who value property-name)
  (unless (storage-property-present? (storage-raw value) property-name)
    (raise-arguments-error who
                           (string-append "Storage." property-name " is not available"))))

;; local-storage : -> storage-info?
;;   Read the browser localStorage object.
(define (local-storage)
  (storage (js-window-local-storage)))

;; session-storage : -> storage-info?
;;   Read the browser sessionStorage object.
(define (session-storage)
  (storage (js-window-session-storage)))

;; storage-length : storage-info? -> exact-nonnegative-integer?
;;   Read the number of stored entries.
(define (storage-length value)
  (check-storage 'storage-length value)
  (check-storage-property 'storage-length value "length")
  (js-ref (storage-raw value) "length"))

;; storage-key : storage-info? exact-nonnegative-integer? -> (or/c #f string?)
;;   Read a storage key by numeric position.
(define (storage-key value index)
  (check-storage 'storage-key value)
  (check-storage-method 'storage-key value "key")
  (js-send/value (storage-raw value) "key" (vector index)))

;; storage-get-item : storage-info? (or/c string? symbol?) -> (or/c #f string?)
;;   Read a stored value by key.
(define (storage-get-item value key)
  (check-storage 'storage-get-item value)
  (check-storage-method 'storage-get-item value "getItem")
  (define key* (storage-stringish->string 'storage-get-item key))
  (js-send/value (storage-raw value) "getItem" (vector key*)))

;; storage-set-item! : storage-info? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Write a stored value by key.
(define (storage-set-item! value key data)
  (check-storage 'storage-set-item! value)
  (check-storage-method 'storage-set-item! value "setItem")
  (define key* (storage-stringish->string 'storage-set-item! key))
  (define data* (storage-stringish->string 'storage-set-item! data))
  (js-send/extern/nullish (storage-raw value) "setItem" (vector key* data*))
  (void))

;; storage-remove-item! : storage-info? (or/c string? symbol?) -> void?
;;   Remove a stored value by key.
(define (storage-remove-item! value key)
  (check-storage 'storage-remove-item! value)
  (check-storage-method 'storage-remove-item! value "removeItem")
  (define key* (storage-stringish->string 'storage-remove-item! key))
  (js-send/extern/nullish (storage-raw value) "removeItem" (vector key*))
  (void))

;; storage-clear! : storage-info? -> void?
;;   Remove all stored values.
(define (storage-clear! value)
  (check-storage 'storage-clear! value)
  (check-storage-method 'storage-clear! value "clear")
  (js-send/extern/nullish (storage-raw value) "clear" (vector))
  (void))
