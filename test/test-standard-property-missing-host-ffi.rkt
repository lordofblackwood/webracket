#lang webracket/base

;; Browser smoke for generic JS property/new boundary errors.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-index
                  js-new
                  js-null
                  js-ref
                  js-ref/extern
                  js-set!))

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

(define null-value (js-null))
(define plain-object (js-eval "({})"))

(define ref-message
  (catch-message
   (lambda ()
     (js-ref null-value "missing"))))

(define ref/extern-message
  (catch-message
   (lambda ()
     (js-ref/extern null-value "missing"))))

(define set-message
  (catch-message
   (lambda ()
     (js-set! null-value "missing" 1))))

(define index-message
  (catch-message
   (lambda ()
     (js-index null-value "missing"))))

(define new-null-message
  (catch-message
   (lambda ()
     (js-new null-value (vector)))))

(define new-object-message
  (catch-message
   (lambda ()
     (js-new plain-object (vector)))))

(check-message ref-message
               "js-ref: target object is null or undefined"
               "missing js-ref null target message")
(check-message ref/extern-message
               "js-ref/extern: target object is null or undefined"
               "missing js-ref/extern null target message")
(check-message set-message
               "js-set!: target object is null or undefined"
               "missing js-set! null target message")
(check-message index-message
               "js-index: target object is null or undefined"
               "missing js-index null target message")
(check-message new-null-message
               "js-new: constructor is null or undefined"
               "missing js-new null constructor message")
(check-message new-object-message
               "js-new: expected constructor function, got object"
               "missing js-new object constructor message")

(js-log "standard-property-missing-host-ffi-ok")
#t
