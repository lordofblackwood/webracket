#lang webracket/base

;; Browser smoke for the temporary JavaScript benchmark FFI module.

(require js/temp
         (only-in webracket/unsafe/standard
                  js-eval
                  js-ref))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

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

(define obj (js-eval "({x: 17})"))
(define js-null (js-eval "null"))

(check-equal (temp-x obj) 17 "initial temp x")
(temp-set-x! obj "updated")
(check-equal (temp-x obj) "updated" "updated temp x")
(check-equal (js-ref obj "x") "updated" "raw object property")

(define temp-x-null-message
  (catch-message
   (lambda ()
     (temp-x js-null))))

(define temp-set-x-null-message
  (catch-message
   (lambda ()
     (temp-set-x! js-null "updated"))))

(check-message temp-x-null-message
               "temp.x: target object is null or undefined"
               "null temp.x message")
(check-message temp-set-x-null-message
               "temp.x: target object is null or undefined"
               "null temp.x setter message")

(js-log "js-temp-ffi-ok")
#t
