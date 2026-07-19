#lang webracket/base

(require webracket/unsafe/dom
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (all-defined-out))

;;;
;;; Fetch wrappers
;;;

;; This library exposes a small, Rackety Fetch surface on top of the
;; browser's `fetch`, `Request`, `Response`, and `Headers` globals.

;; fetch-stringish->string : symbol? any/c -> string?
;;   Normalize a request or header label to a browser string.
(define (fetch-stringish->string who v)
  (cond
    [(string? v) v]
    [(symbol? v) (symbol->string v)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" v)]))

;; fetch-resolve-optional : any/c -> any/c
;;   Treat #f as omitted and force thunks when a literal value is needed.
(define (fetch-resolve-optional value)
  (cond
    [(eq? value #f) (void)]
    [(procedure? value) (value)]
    [else value]))

;; fetch-constructor-present? : string? -> boolean?
;;   Check whether the host environment exposes a named constructor.
(define (fetch-constructor-present? name)
  (string=? (js-typeof (js-var name)) "function"))

;; check-fetch-constructor : symbol? string? -> void?
;;   Ensure the host environment exposes a named Fetch constructor.
(define (check-fetch-constructor who name)
  (unless (fetch-constructor-present? name)
    (raise-arguments-error who
                           (string-append name " constructor is not available"))))

;; fetch-host-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable Fetch API method.
(define (fetch-host-method-present? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; check-fetch-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required Fetch API host method is available.
(define (check-fetch-host-method who raw receiver-name method-name)
  (unless (fetch-host-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " is not available"))))

;; fetch-headers-info : external/raw -> fetch-headers-info?
;;   Wrap a browser Headers object.
(struct fetch-headers-info (raw) #:transparent)

;; fetch-request-info : external/raw -> fetch-request-info?
;;   Wrap a browser Request object.
(struct fetch-request-info (raw) #:transparent)

;; fetch-response-info : external/raw -> fetch-response-info?
;;   Wrap a browser Response object.
(struct fetch-response-info (raw) #:transparent)

;; fetch-headers : external/raw -> fetch-headers-info?
;;   Wrap a browser Headers object.
(define (fetch-headers raw)
  (fetch-headers-info raw))

;; fetch-headers-raw : fetch-headers-info? -> external/raw
;;   Extract the raw Headers object.
(define (fetch-headers-raw headers)
  (fetch-headers-info-raw headers))

;; fetch-request : external/raw -> fetch-request-info?
;;   Wrap a browser Request object.
(define (fetch-request raw)
  (fetch-request-info raw))

;; fetch-request-raw : fetch-request-info? -> external/raw
;;   Extract the raw Request object.
(define (fetch-request-raw request)
  (fetch-request-info-raw request))

;; fetch-response : external/raw -> fetch-response-info?
;;   Wrap a browser Response object.
(define (fetch-response raw)
  (fetch-response-info raw))

;; fetch-response-raw : fetch-response-info? -> external/raw
;;   Extract the raw Response object.
(define (fetch-response-raw response)
  (fetch-response-info-raw response))

;; fetch-headers? : any/c -> boolean?
;;   Report whether v is a wrapped Headers value.
(define (fetch-headers? v)
  (and (fetch-headers-info? v)
       (fetch-constructor-present? "Headers")
       (external? (fetch-headers-raw v))
       (js-instanceof (fetch-headers-raw v) (js-var "Headers"))))

;; fetch-request? : any/c -> boolean?
;;   Report whether v is a wrapped Request value.
(define (fetch-request? v)
  (and (fetch-request-info? v)
       (fetch-constructor-present? "Request")
       (external? (fetch-request-raw v))
       (js-instanceof (fetch-request-raw v) (js-var "Request"))))

;; fetch-response? : any/c -> boolean?
;;   Report whether v is a wrapped Response value.
(define (fetch-response? v)
  (and (fetch-response-info? v)
       (fetch-constructor-present? "Response")
       (external? (fetch-response-raw v))
       (js-instanceof (fetch-response-raw v) (js-var "Response"))))

;; check-fetch-headers : symbol? any/c -> void?
;;   Ensure headers wraps an external Headers host value.
(define (check-fetch-headers who headers)
  (unless (and (fetch-headers-info? headers)
               (external? (fetch-headers-raw headers)))
    (raise-argument-error who "fetch-headers-info?" headers))
  (check-fetch-constructor who "Headers")
  (unless (js-instanceof (fetch-headers-raw headers) (js-var "Headers"))
    (raise-argument-error who "fetch-headers-info?" headers)))

;; check-fetch-request : symbol? any/c -> void?
;;   Ensure request wraps an external Request host value.
(define (check-fetch-request who request)
  (unless (and (fetch-request-info? request)
               (external? (fetch-request-raw request)))
    (raise-argument-error who "fetch-request-info?" request))
  (check-fetch-constructor who "Request")
  (unless (js-instanceof (fetch-request-raw request) (js-var "Request"))
    (raise-argument-error who "fetch-request-info?" request)))

;; check-fetch-response : symbol? any/c -> void?
;;   Ensure response wraps an external Response host value.
(define (check-fetch-response who response)
  (unless (and (fetch-response-info? response)
               (external? (fetch-response-raw response)))
    (raise-argument-error who "fetch-response-info?" response))
  (check-fetch-constructor who "Response")
  (unless (js-instanceof (fetch-response-raw response) (js-var "Response"))
    (raise-argument-error who "fetch-response-info?" response)))

;; make-fetch-headers : [any/c #f] -> fetch-headers-info?
;;   Create a new Headers object from an optional initializer.
(define (make-fetch-headers [init #f])
  (check-fetch-constructor 'make-fetch-headers "Headers")
  (define init* (fetch-resolve-optional init))
  (fetch-headers (js-new (js-var "Headers") (vector init*))))

;; make-fetch-request : any/c [any/c #f] -> fetch-request-info?
;;   Create a new Request object from an input and optional initializer.
(define (make-fetch-request input [init #f])
  (check-fetch-constructor 'make-fetch-request "Request")
  (define input* (if (symbol? input) (symbol->string input) input))
  (define init* (fetch-resolve-optional init))
  (fetch-request (js-new (js-var "Request") (vector input* init*))))

;; fetch : any/c [any/c #f] -> external/raw
;;   Start a fetch request.
(define (fetch request [init #f])
  (define request*
    (cond
      [(fetch-request-info? request)
       (check-fetch-request 'fetch request)
       (fetch-request-raw request)]
      [else request]))
  (js-window-fetch request* (fetch-resolve-optional init)))

;; fetch-request-method : fetch-request-info? -> any/c
;;   Read the request method.
(define (fetch-request-method request)
  (check-fetch-request 'fetch-request-method request)
  (js-ref (fetch-request-raw request) "method"))

;; fetch-request-url : fetch-request-info? -> any/c
;;   Read the request URL.
(define (fetch-request-url request)
  (check-fetch-request 'fetch-request-url request)
  (js-ref (fetch-request-raw request) "url"))

;; fetch-request-body-used? : fetch-request-info? -> boolean?
;;   Report whether the request body has already been consumed.
(define (fetch-request-body-used? request)
  (check-fetch-request 'fetch-request-body-used? request)
  (js-ref (fetch-request-raw request) "bodyUsed"))

;; fetch-request-headers : fetch-request-info? -> fetch-headers-info?
;;   Read the request headers wrapper.
(define (fetch-request-headers request)
  (check-fetch-request 'fetch-request-headers request)
  (fetch-headers (js-ref (fetch-request-raw request) "headers")))

;; fetch-request-clone : fetch-request-info? -> fetch-request-info?
;;   Clone a request.
(define (fetch-request-clone request)
  (check-fetch-request 'fetch-request-clone request)
  (check-fetch-host-method 'fetch-request-clone
                           (fetch-request-raw request)
                           "Request"
                           "clone")
  (fetch-request (js-send/extern (fetch-request-raw request) "clone" (vector))))

;; fetch-response-ok? : fetch-response-info? -> boolean?
;;   Report whether the response status is in the successful range.
(define (fetch-response-ok? response)
  (check-fetch-response 'fetch-response-ok? response)
  (js-ref (fetch-response-raw response) "ok"))

;; fetch-response-status : fetch-response-info? -> exact-nonnegative-integer?
;;   Read the response status code.
(define (fetch-response-status response)
  (check-fetch-response 'fetch-response-status response)
  (js-ref (fetch-response-raw response) "status"))

;; fetch-response-status-text : fetch-response-info? -> string?
;;   Read the response status text.
(define (fetch-response-status-text response)
  (check-fetch-response 'fetch-response-status-text response)
  (js-ref (fetch-response-raw response) "statusText"))

;; fetch-response-url : fetch-response-info? -> string?
;;   Read the final response URL.
(define (fetch-response-url response)
  (check-fetch-response 'fetch-response-url response)
  (js-ref (fetch-response-raw response) "url"))

;; fetch-response-type : fetch-response-info? -> string?
;;   Read the response type.
(define (fetch-response-type response)
  (check-fetch-response 'fetch-response-type response)
  (js-ref (fetch-response-raw response) "type"))

;; fetch-response-body-used? : fetch-response-info? -> boolean?
;;   Report whether the response body has already been consumed.
(define (fetch-response-body-used? response)
  (check-fetch-response 'fetch-response-body-used? response)
  (js-ref (fetch-response-raw response) "bodyUsed"))

;; fetch-response-headers : fetch-response-info? -> fetch-headers-info?
;;   Read the response headers wrapper.
(define (fetch-response-headers response)
  (check-fetch-response 'fetch-response-headers response)
  (fetch-headers (js-ref (fetch-response-raw response) "headers")))

;; fetch-response-clone : fetch-response-info? -> fetch-response-info?
;;   Clone a response.
(define (fetch-response-clone response)
  (check-fetch-response 'fetch-response-clone response)
  (check-fetch-host-method 'fetch-response-clone
                           (fetch-response-raw response)
                           "Response"
                           "clone")
  (fetch-response (js-send/extern (fetch-response-raw response) "clone" (vector))))

;; fetch-headers-get : fetch-headers-info? (or/c string? symbol?) -> (or/c #f string?)
;;   Read a header value by name.
(define (fetch-headers-get headers name)
  (check-fetch-headers 'fetch-headers-get headers)
  (check-fetch-host-method 'fetch-headers-get
                           (fetch-headers-raw headers)
                           "Headers"
                           "get")
  (define name* (fetch-stringish->string 'fetch-headers-get name))
  (js-send/value (fetch-headers-raw headers) "get" (vector name*)))

;; fetch-headers-has? : fetch-headers-info? (or/c string? symbol?) -> boolean?
;;   Check whether a header is present.
(define (fetch-headers-has? headers name)
  (check-fetch-headers 'fetch-headers-has? headers)
  (check-fetch-host-method 'fetch-headers-has?
                           (fetch-headers-raw headers)
                           "Headers"
                           "has")
  (define name* (fetch-stringish->string 'fetch-headers-has? name))
  (js-send/boolean (fetch-headers-raw headers) "has" (vector name*)))

;; fetch-headers-set! : fetch-headers-info? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Set a header value.
(define (fetch-headers-set! headers name value)
  (check-fetch-headers 'fetch-headers-set! headers)
  (check-fetch-host-method 'fetch-headers-set!
                           (fetch-headers-raw headers)
                           "Headers"
                           "set")
  (define name* (fetch-stringish->string 'fetch-headers-set! name))
  (define value* (fetch-stringish->string 'fetch-headers-set! value))
  (js-send/extern/nullish (fetch-headers-raw headers) "set" (vector name* value*))
  (void))

;; fetch-headers-append! : fetch-headers-info? (or/c string? symbol?) (or/c string? symbol?) -> void?
;;   Append a header value.
(define (fetch-headers-append! headers name value)
  (check-fetch-headers 'fetch-headers-append! headers)
  (check-fetch-host-method 'fetch-headers-append!
                           (fetch-headers-raw headers)
                           "Headers"
                           "append")
  (define name* (fetch-stringish->string 'fetch-headers-append! name))
  (define value* (fetch-stringish->string 'fetch-headers-append! value))
  (js-send/extern/nullish (fetch-headers-raw headers) "append" (vector name* value*))
  (void))

;; fetch-headers-delete! : fetch-headers-info? (or/c string? symbol?) -> void?
;;   Delete a header.
(define (fetch-headers-delete! headers name)
  (check-fetch-headers 'fetch-headers-delete! headers)
  (check-fetch-host-method 'fetch-headers-delete!
                           (fetch-headers-raw headers)
                           "Headers"
                           "delete")
  (define name* (fetch-stringish->string 'fetch-headers-delete! name))
  (js-send/extern/nullish (fetch-headers-raw headers) "delete" (vector name*))
  (void))

;; fetch-headers-callback-cache : hash?
;;   Cache JS callback wrappers for Headers iteration.
(define fetch-headers-callback-cache (make-hasheq))

;; fetch-headers->external : any/c -> external?
;;   Convert a Headers callback to a stable external value.
(define (fetch-headers->external proc)
  (cond
    [(external? proc) proc]
    [(procedure? proc)
     (define cached (hash-ref fetch-headers-callback-cache proc #f))
     (cond
       [cached cached]
       [else
        (define external (procedure->external proc))
        (hash-set! fetch-headers-callback-cache proc external)
        external])]
    [else
     (raise-argument-error 'fetch-headers-for-each "(or/c procedure? external?)" proc)]))

;; fetch-headers-for-each : fetch-headers-info? (or/c procedure? external?) [any/c] -> void?
;;   Iterate over headers with a Map-style callback.
(define (fetch-headers-for-each headers proc [this-arg #f])
  (check-fetch-headers 'fetch-headers-for-each headers)
  (check-fetch-host-method 'fetch-headers-for-each
                           (fetch-headers-raw headers)
                           "Headers"
                           "forEach")
  (define proc* (fetch-headers->external proc))
  (define args
    (if (eq? this-arg #f)
        (vector proc*)
        (vector proc* this-arg)))
  (js-send/extern/nullish (fetch-headers-raw headers) "forEach" args)
  (void))
