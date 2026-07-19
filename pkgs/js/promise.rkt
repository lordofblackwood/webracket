#lang racket/base

(require webracket/unsafe/standard
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (struct-out js-promise)
         js-promise-wrap
         js-promise-unwrap
         js-promise-thenable?
         js-promise-resolved
         js-promise-rejected
         js-promise-then
         js-promise-catch
         js-promise-finally)

;;;
;;; JavaScript Promise wrappers
;;;

;; js-promise : external/raw -> js-promise?
;;   Wrap a JavaScript Promise-like value.
(struct js-promise (raw) #:transparent)

;; js-promise-thenable-method? : external/raw string? -> boolean?
;;   Report whether raw exposes a function-valued method called method-name.
(define (js-promise-thenable-method? raw method-name)
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

;; check-js-promise-host-method : symbol? external/raw string? string? -> void?
;;   Ensure a required Promise host method is available.
(define (check-js-promise-host-method who raw receiver-name method-name)
  (unless (js-promise-thenable-method? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name
                                          "."
                                          method-name
                                          " is not available"))))

;; check-js-promise-global-method : symbol? string? -> external/raw
;;   Return the Promise constructor after checking a required static method.
(define (check-js-promise-global-method who method-name)
  (define promise-ctor (js-var "Promise"))
  (unless (js-constructible? promise-ctor)
    (raise-arguments-error who "Promise is not available"))
  (check-js-promise-host-method who promise-ctor "Promise" method-name)
  promise-ctor)

;; js-promise-wrap : external/raw -> js-promise?
;;   Wrap a Promise-like value after validating that it is thenable.
(define (js-promise-wrap raw)
  (unless (and (external? raw)
               (js-promise-thenable-method? raw "then"))
    (raise-argument-error 'js-promise-wrap "Promise-like external/raw" raw))
  (js-promise raw))

;; js-promise-unwrap : js-promise? -> external/raw
;;   Extract the raw Promise-like value.
(define (js-promise-unwrap promise)
  (js-promise-raw promise))

;; js-promise-thenable? : any/c -> boolean?
;;   Report whether v is a wrapped Promise-like value.
(define (js-promise-thenable? v)
  (and (js-promise? v)
       (external? (js-promise-unwrap v))
       (js-promise-thenable-method? (js-promise-unwrap v) "then")))

;; js-promise-callback-cache : hash?
;;   Reuse stable external callbacks for Promise handlers.
(define js-promise-callback-cache (make-hasheq))

;; js-promise-handler->external : symbol? (or/c procedure? external?) -> external?
;;   Convert a handler to a stable external callback.
(define (js-promise-handler->external who handler)
  (cond
    [(external? handler) handler]
    [(procedure? handler)
     (define cached (hash-ref js-promise-callback-cache handler #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply handler args))))
        (hash-set! js-promise-callback-cache handler external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" handler)]))

;; js-promise-resolved : any/c -> js-promise?
;;   Build an already-resolved JavaScript Promise.
(define (js-promise-resolved value)
  (define promise-ctor (check-js-promise-global-method 'js-promise-resolved "resolve"))
  (js-promise-wrap
   (js-send/extern promise-ctor "resolve" (vector value))))

;; js-promise-rejected : any/c -> js-promise?
;;   Build an already-rejected JavaScript Promise.
(define (js-promise-rejected value)
  (define promise-ctor (check-js-promise-global-method 'js-promise-rejected "reject"))
  (js-promise-wrap
   (js-send/extern promise-ctor "reject" (vector value))))

;; js-promise-then : js-promise? (or/c procedure? external?) [(or/c #f procedure? external?)] -> js-promise?
;;   Attach fulfillment and optional rejection handlers to a Promise.
(define (js-promise-then promise on-fulfilled [on-rejected #f])
  (unless (js-promise-thenable? promise)
    (raise-argument-error 'js-promise-then "js-promise?" promise))
  (define on-fulfilled* (js-promise-handler->external 'js-promise-then on-fulfilled))
  (js-promise-wrap
   (if (eq? on-rejected #f)
       (js-send/extern (js-promise-unwrap promise) "then" (vector on-fulfilled*))
       (js-send/extern (js-promise-unwrap promise)
                       "then"
                       (vector on-fulfilled*
                               (js-promise-handler->external 'js-promise-then on-rejected))))))

;; js-promise-catch : js-promise? (or/c procedure? external?) -> js-promise?
;;   Attach a rejection handler to a Promise.
(define (js-promise-catch promise on-rejected)
  (unless (js-promise-thenable? promise)
    (raise-argument-error 'js-promise-catch "js-promise?" promise))
  (check-js-promise-host-method 'js-promise-catch
                                (js-promise-unwrap promise)
                                "Promise"
                                "catch")
  (js-promise-wrap
   (js-send/extern (js-promise-unwrap promise)
                   "catch"
                   (vector (js-promise-handler->external 'js-promise-catch on-rejected)))))

;; js-promise-finally : js-promise? (or/c procedure? external?) -> js-promise?
;;   Attach a finally handler to a Promise.
(define (js-promise-finally promise on-finally)
  (unless (js-promise-thenable? promise)
    (raise-argument-error 'js-promise-finally "js-promise?" promise))
  (check-js-promise-host-method 'js-promise-finally
                                (js-promise-unwrap promise)
                                "Promise"
                                "finally")
  (js-promise-wrap
   (js-send/extern (js-promise-unwrap promise)
                   "finally"
                   (vector (js-promise-handler->external 'js-promise-finally on-finally)))))
