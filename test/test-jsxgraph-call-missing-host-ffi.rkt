#lang webracket/base

;; Browser smoke for dynamic JSXGraph method-call boundary errors.

(require (only-in webracket/unsafe/jsxgraph
                  js-jsx-circle-call
                  js-jsx-circle-call/nullish
                  js-jsx-curve-call
                  js-jsx-curve-call/nullish
                  js-jsx-element-call
                  js-jsx-element-call/nullish
                  js-jsx-line-call
                  js-jsx-line-call/nullish
                  js-jsx-polygon-call
                  js-jsx-polygon-call/nullish)
         (only-in webracket/unsafe/standard
                  js-eval))

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
  (js-eval "({ present() { return {ok: true}; } })"))

(define args (vector))

(define element-call-message
  (catch-message
   (lambda ()
     (js-jsx-element-call target "missingMethod" args))))

(define element-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-element-call/nullish target "missingMethod" args))))

(define line-call-message
  (catch-message
   (lambda ()
     (js-jsx-line-call target "missingMethod" args))))

(define line-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-line-call/nullish target "missingMethod" args))))

(define circle-call-message
  (catch-message
   (lambda ()
     (js-jsx-circle-call target "missingMethod" args))))

(define circle-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-circle-call/nullish target "missingMethod" args))))

(define curve-call-message
  (catch-message
   (lambda ()
     (js-jsx-curve-call target "missingMethod" args))))

(define curve-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-curve-call/nullish target "missingMethod" args))))

(define polygon-call-message
  (catch-message
   (lambda ()
     (js-jsx-polygon-call target "missingMethod" args))))

(define polygon-call/nullish-message
  (catch-message
   (lambda ()
     (js-jsx-polygon-call/nullish target "missingMethod" args))))

(check-message element-call-message
               "jsx-element.call: method missingMethod not available in this environment"
               "missing jsx-element call message")
(check-message element-call/nullish-message
               "jsx-element.call/nullish: method missingMethod not available in this environment"
               "missing jsx-element call/nullish message")
(check-message line-call-message
               "jsx-line.call: method missingMethod not available in this environment"
               "missing jsx-line call message")
(check-message line-call/nullish-message
               "jsx-line.call/nullish: method missingMethod not available in this environment"
               "missing jsx-line call/nullish message")
(check-message circle-call-message
               "jsx-circle.call: method missingMethod not available in this environment"
               "missing jsx-circle call message")
(check-message circle-call/nullish-message
               "jsx-circle.call/nullish: method missingMethod not available in this environment"
               "missing jsx-circle call/nullish message")
(check-message curve-call-message
               "jsx-curve.call: method missingMethod not available in this environment"
               "missing jsx-curve call message")
(check-message curve-call/nullish-message
               "jsx-curve.call/nullish: method missingMethod not available in this environment"
               "missing jsx-curve call/nullish message")
(check-message polygon-call-message
               "jsx-polygon.call: method missingMethod not available in this environment"
               "missing jsx-polygon call message")
(check-message polygon-call/nullish-message
               "jsx-polygon.call/nullish: method missingMethod not available in this environment"
               "missing jsx-polygon call/nullish message")

(js-log "jsxgraph-call-missing-host-ffi-ok")
#t
