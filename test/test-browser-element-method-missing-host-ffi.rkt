#lang webracket/base

;; Browser smoke for public browser/element wrapper host-method boundary errors.

(require browser/element
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

(define element (element-wrap (js-eval "({})")))
(define class-list (dom-token-list-wrap (js-eval "({})")))
(define callback (lambda args (void)))

(define add-event-listener-message
  (catch-message
   (lambda ()
     (element-add-event-listener! element 'click callback))))

(define remove-event-listener-message
  (catch-message
   (lambda ()
     (element-remove-event-listener! element 'click callback))))

(define append-message
  (catch-message
   (lambda ()
     (element-append! element "x"))))

(define prepend-message
  (catch-message
   (lambda ()
     (element-prepend! element "x"))))

(define before-message
  (catch-message
   (lambda ()
     (element-before! element "x"))))

(define after-message
  (catch-message
   (lambda ()
     (element-after! element "x"))))

(define set-scroll-top-message
  (catch-message
   (lambda ()
     (element-set-scroll-top! element 0.0))))

(define set-scroll-left-message
  (catch-message
   (lambda ()
     (element-set-scroll-left! element 0.0))))

(define value-message
  (catch-message
   (lambda ()
     (element-value element))))

(define set-value-message
  (catch-message
   (lambda ()
     (element-set-value! element "x"))))

(define contains-message
  (catch-message
   (lambda ()
     (dom-token-list-contains? class-list 'x))))

(define add-message
  (catch-message
   (lambda ()
     (dom-token-list-add! class-list 'x))))

(define remove-message
  (catch-message
   (lambda ()
     (dom-token-list-remove! class-list 'x))))

(define toggle-message
  (catch-message
   (lambda ()
     (dom-token-list-toggle! class-list 'x))))

(define replace-message
  (catch-message
   (lambda ()
     (dom-token-list-replace! class-list 'x 'y))))

(check-message add-event-listener-message
               "EventTarget.addEventListener not available in this environment"
               "missing addEventListener message")
(check-message remove-event-listener-message
               "EventTarget.removeEventListener not available in this environment"
               "missing removeEventListener message")
(check-message append-message
               "Element.append not available in this environment"
               "missing append message")
(check-message prepend-message
               "Element.prepend not available in this environment"
               "missing prepend message")
(check-message before-message
               "Element.before not available in this environment"
               "missing before message")
(check-message after-message
               "Element.after not available in this environment"
               "missing after message")
(check-message set-scroll-top-message
               "Element.scrollTop not available in this environment"
               "missing scrollTop setter message")
(check-message set-scroll-left-message
               "Element.scrollLeft not available in this environment"
               "missing scrollLeft setter message")
(check-message value-message
               "Element.value not available in this environment"
               "missing value getter message")
(check-message set-value-message
               "Element.value not available in this environment"
               "missing value setter message")
(check-message contains-message
               "DOMTokenList.contains not available in this environment"
               "missing contains message")
(check-message add-message
               "DOMTokenList.add not available in this environment"
               "missing add message")
(check-message remove-message
               "DOMTokenList.remove not available in this environment"
               "missing remove message")
(check-message toggle-message
               "DOMTokenList.toggle not available in this environment"
               "missing toggle message")
(check-message replace-message
               "DOMTokenList.replace not available in this environment"
               "missing replace message")

(js-log "browser-element-method-missing-host-ffi-ok")
#t
