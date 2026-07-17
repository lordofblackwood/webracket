#lang webracket/base

;; Browser smoke for module-based RQuery event helpers.

(require rquery
         (only-in browser/document
                  document-body
                  document-create-element)
         (only-in browser/element
                  element-append!
                  element-id
                  element-set-class-name!
                  element-set-id!
                  element-set-text-content!))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal label)))

(define body (document-body))
(define root (document-create-element 'div))
(define button (document-create-element 'button))

(element-set-id! root "rquery-surface-root")
(element-set-id! button "rquery-surface-button")
(element-set-class-name! button "delegate-target")
(element-set-text-content! button "Trigger")
(element-append! root button)
(element-append! body root)

(define root-sel (list->$selection (list root)))
(define button-sel ($ "#rquery-surface-button"))
(define click-count 0)
(define delegate-count 0)
(define delegate-match #f)

(void
 ($on 'click
      (lambda (_evt)
        (set! click-count (add1 click-count)))
      button-sel))

(void
 ($on-delegate 'click
               ".delegate-target"
               (lambda (matched _evt)
                 (set! delegate-count (add1 delegate-count))
                 (set! delegate-match (element-id matched)))
               root-sel))

(void ($trigger 'click button-sel))

(check-equal ($length button-sel) 1 "rquery selector length")
(check-equal click-count 1 "rquery trigger click count")
(check-equal delegate-count 1 "rquery delegated click count")
(check-equal delegate-match "rquery-surface-button" "rquery delegated match")

(js-log "rquery-surface-ffi-ok")
#t
