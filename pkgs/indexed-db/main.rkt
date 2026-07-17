#lang webracket/base

(require webracket/unsafe/dom
         (only-in webracket/primitives
                  external?))

(provide (all-defined-out))

;;;
;;; IndexedDB wrappers
;;;

;; This library exposes a direct IndexedDB factory wrapper so browser code
;; can require `indexed-db` instead of reaching for `window-indexed-db`.

;; indexed-db-stringish->string : symbol? any/c -> string?
;;   Normalize an IndexedDB database name to a browser string.
(define (indexed-db-stringish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" v)]))

;; indexed-db-info : external/raw -> indexed-db-info?
;;   Wrap a browser IndexedDB factory object.
(struct indexed-db-info (raw) #:transparent)

;; indexed-db-constructor-present? : -> boolean?
;;   Check whether the host environment exposes the IDBFactory constructor.
(define (indexed-db-constructor-present?)
  (string=? (js-typeof (js-var "IDBFactory"))
            "function"))

;; indexed-db : -> indexed-db-info?
;;   Read the browser IndexedDB factory object.
(define (indexed-db)
  (indexed-db-info (js-window-indexed-db)))

;; indexed-db-raw : indexed-db-info? -> external/raw
;;   Extract the raw IndexedDB factory object.
(define (indexed-db-raw value)
  (indexed-db-info-raw value))

;; indexed-db? : any/c -> boolean?
;;   Report whether v is a wrapped IndexedDB factory object.
(define (indexed-db? v)
  (indexed-db-host-value? v))

;; indexed-db-host-value? : any/c -> boolean?
;;   Report whether v wraps a browser IDBFactory object.
(define (indexed-db-host-value? v)
  (and (indexed-db-info? v)
       (indexed-db-constructor-present?)
       (external? (indexed-db-raw v))
       (js-instanceof (indexed-db-raw v) (js-var "IDBFactory"))))

;; indexed-db-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable IDBFactory method.
(define (indexed-db-method-present? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; check-indexed-db : symbol? any/c -> void?
;;   Ensure value wraps an external IDBFactory host value.
(define (check-indexed-db who value)
  (unless (indexed-db-host-value? value)
    (raise-argument-error who "indexed-db-info?" value)))

;; check-indexed-db-method : symbol? indexed-db-info? string? -> void?
;;   Ensure a required IDBFactory method is available.
(define (check-indexed-db-method who value method-name)
  (unless (indexed-db-method-present? (indexed-db-raw value) method-name)
    (raise-arguments-error who
                           (string-append "IDBFactory." method-name " is not available"))))

;; indexed-db-open : indexed-db-info? (or/c string? symbol?) [any/c] -> external/raw
;;   Open a database and return the request object.
(define (indexed-db-open value name [version #f])
  (check-indexed-db 'indexed-db-open value)
  (check-indexed-db-method 'indexed-db-open value "open")
  (define name* (indexed-db-stringish->string 'indexed-db-open name))
  (define args
    (if (eq? version #f)
        (vector name*)
        (vector name* version)))
  (js-send/extern (indexed-db-raw value) "open" args))

;; indexed-db-delete-database! : indexed-db-info? (or/c string? symbol?) -> external/raw
;;   Request deletion of a database.
(define (indexed-db-delete-database! value name)
  (check-indexed-db 'indexed-db-delete-database! value)
  (check-indexed-db-method 'indexed-db-delete-database! value "deleteDatabase")
  (define name* (indexed-db-stringish->string 'indexed-db-delete-database! name))
  (js-send/extern (indexed-db-raw value) "deleteDatabase" (vector name*)))

;; indexed-db-cmp : indexed-db-info? any/c any/c -> integer?
;;   Compare two IndexedDB keys.
(define (indexed-db-cmp value a b)
  (check-indexed-db 'indexed-db-cmp value)
  (check-indexed-db-method 'indexed-db-cmp value "cmp")
  (js-send/value (indexed-db-raw value) "cmp" (vector a b)))

;; indexed-db-databases : indexed-db-info? -> external/raw
;;   Request the list of known databases.
(define (indexed-db-databases value)
  (check-indexed-db 'indexed-db-databases value)
  (check-indexed-db-method 'indexed-db-databases value "databases")
  (js-send/extern (indexed-db-raw value) "databases" (vector)))
