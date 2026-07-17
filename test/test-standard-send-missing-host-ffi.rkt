#lang webracket/base

;; Browser smoke for generic JS send boundary errors.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-null
                  js-send
                  js-send/boolean
                  js-send/extern
                  js-send/extern/null
                  js-send/extern/nullish
                  js-send/extern/undefined
                  js-send/flonum
                  js-send/truthy
                  js-send/value))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(define target
  (js-eval "({ present() { return true; } })"))

(define missing-send-message
  (catch-message
   (lambda ()
     (js-send target "missingMethod" (vector)))))

(define missing-send/extern-message
  (catch-message
   (lambda ()
     (js-send/extern target "missingMethod" (vector)))))

(define missing-send/extern/null-message
  (catch-message
   (lambda ()
     (js-send/extern/null target "missingMethod" (vector)))))

(define missing-send/extern/undefined-message
  (catch-message
   (lambda ()
     (js-send/extern/undefined target "missingMethod" (vector)))))

(define missing-send/extern/nullish-message
  (catch-message
   (lambda ()
     (js-send/extern/nullish target "missingMethod" (vector)))))

(define missing-send/value-message
  (catch-message
   (lambda ()
     (js-send/value target "missingMethod" (vector)))))

(define missing-send/boolean-message
  (catch-message
   (lambda ()
     (js-send/boolean target "missingMethod" (vector)))))

(define missing-send/truthy-message
  (catch-message
   (lambda ()
     (js-send/truthy target "missingMethod" (vector)))))

(define missing-send/flonum-message
  (catch-message
   (lambda ()
     (js-send/flonum target "missingMethod" (vector)))))

(define null-target-message
  (catch-message
   (lambda ()
     (js-send/value (js-null) "missingMethod" (vector)))))

(check-message missing-send-message
               "js-send: method missingMethod not available in this environment"
               "missing js-send message")
(check-message missing-send/extern-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern message")
(check-message missing-send/extern/null-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern/null message")
(check-message missing-send/extern/undefined-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern/undefined message")
(check-message missing-send/extern/nullish-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern/nullish message")
(check-message missing-send/value-message
               "js-send/value: method missingMethod not available in this environment"
               "missing js-send/value message")
(check-message missing-send/boolean-message
               "js-send/boolean: method missingMethod not available in this environment"
               "missing js-send/boolean message")
(check-message missing-send/truthy-message
               "js-send/truthy: method missingMethod not available in this environment"
               "missing js-send/truthy message")
(check-message missing-send/flonum-message
               "js-send/flonum: method missingMethod not available in this environment"
               "missing js-send/flonum message")
(check-message null-target-message
               "js-send/value: target object is null or undefined"
               "missing null target message")

(js-log "standard-send-missing-host-ffi-ok")
#t
