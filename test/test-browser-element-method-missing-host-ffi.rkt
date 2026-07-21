#lang webracket/base

;; Browser smoke for public browser/element wrapper host-method boundary errors.

(require browser/element
         (only-in webracket/unsafe/standard
                  js-eval
                  js-null
                  js-undefined))

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
(define nodeish-host
  (element-wrap
   (js-eval
    "({
       append(_x) {},
       prepend(_x) {},
       before(_x) {},
       after(_x) {},
       appendChild(_x) {},
       insertAdjacentElement(_pos, child) { return child; },
       setAttributeNode(attr) { return attr; },
       setAttributeNodeNS(attr) { return attr; },
       removeAttributeNode(attr) { return attr; },
       replaceChildren(_x) {},
       replaceWith(_x) {}
     })")))
(define null-node (dom-node (js-null)))
(define undefined-node (dom-node (js-undefined)))
(define null-element (dom-element (js-null)))
(define undefined-element (dom-element (js-undefined)))
(define null-text (dom-text (js-null)))
(define undefined-attr (dom-attr (js-undefined)))

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

(define forged-append-child-message
  (catch-message
   (lambda ()
     (append-child! nodeish-host undefined-node))))

(define forged-append-message
  (catch-message
   (lambda ()
     (element-append! nodeish-host null-node))))

(define forged-prepend-message
  (catch-message
   (lambda ()
     (element-prepend! nodeish-host undefined-element))))

(define forged-before-message
  (catch-message
   (lambda ()
     (element-before! nodeish-host null-element))))

(define forged-after-message
  (catch-message
   (lambda ()
     (element-after! nodeish-host null-text))))

(define forged-insert-adjacent-element-message
  (catch-message
   (lambda ()
     (element-insert-adjacent-element! nodeish-host 'beforeend null-node))))

(define forged-set-attribute-node-message
  (catch-message
   (lambda ()
     (element-set-attribute-node! nodeish-host undefined-attr))))

(define forged-set-attribute-node-ns-message
  (catch-message
   (lambda ()
     (element-set-attribute-node-ns! nodeish-host undefined-attr))))

(define forged-remove-attribute-node-message
  (catch-message
   (lambda ()
     (element-remove-attribute-node! nodeish-host undefined-attr))))

(define forged-replace-children-message
  (catch-message
   (lambda ()
     (replace-children! nodeish-host null-node))))

(define forged-element-replace-children-message
  (catch-message
   (lambda ()
     (element-replace-children! nodeish-host undefined-element))))

(define forged-replace-with-message
  (catch-message
   (lambda ()
     (replace-with! nodeish-host null-text))))

(define forged-element-replace-with-message
  (catch-message
   (lambda ()
     (element-replace-with! nodeish-host null-element))))

(define (check-nodeish-message message who label)
  (check-message message
                 (symbol->string who)
                 (string-append label " who"))
  (check-message message
                 "DOM node wrapper with non-null host value"
                 label))

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
(check-nodeish-message forged-append-child-message
                       'append-child!
                       "forged append-child message")
(check-nodeish-message forged-append-message
                       'element-append!
                       "forged append message")
(check-nodeish-message forged-prepend-message
                       'element-prepend!
                       "forged prepend message")
(check-nodeish-message forged-before-message
                       'element-before!
                       "forged before message")
(check-nodeish-message forged-after-message
                       'element-after!
                       "forged after message")
(check-nodeish-message forged-insert-adjacent-element-message
                       'element-insert-adjacent-element!
                       "forged insert adjacent element message")
(check-nodeish-message forged-set-attribute-node-message
                       'element-set-attribute-node!
                       "forged set attribute node message")
(check-nodeish-message forged-set-attribute-node-ns-message
                       'element-set-attribute-node-ns!
                       "forged set attribute node ns message")
(check-nodeish-message forged-remove-attribute-node-message
                       'element-remove-attribute-node!
                       "forged remove attribute node message")
(check-nodeish-message forged-replace-children-message
                       'replace-children!
                       "forged replace children message")
(check-nodeish-message forged-element-replace-children-message
                       'element-replace-children!
                       "forged element replace children message")
(check-nodeish-message forged-replace-with-message
                       'replace-with!
                       "forged replace with message")
(check-nodeish-message forged-element-replace-with-message
                       'element-replace-with!
                       "forged element replace with message")

(js-log "browser-element-method-missing-host-ffi-ok")
#t
