#lang webracket/base

(require browser/window
         browser/element
         (only-in webracket/unsafe/standard
                  js-null
                  js-undefined))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-false got label)
  (when got
    (error 'check-false label)))

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

(define (all-procedures? xs)
  (cond
    [(null? xs) #t]
    [(procedure? (car xs)) (all-procedures? (cdr xs))]
    [else #f]))

(check-true
 (all-procedures?
  (list
   Window
   dom-window?
   dom-window-raw
   window-self
   window-document
   window-document-info?
   window-document-info-raw
   window-name
   window-set-name!
   window-location
   window-location-info?
   window-location-info-raw
   window-custom-elements
   window-custom-elements-info?
   window-custom-elements-info-raw
   window-history
   window-history-info?
   window-history-info-raw
   window-visual-viewport
   window-visual-viewport-info?
   window-visual-viewport-info-raw
   window-navigator
   window-navigator-info?
   window-navigator-info-raw
   window-screen
   window-screen-info?
   window-screen-info-raw
   window-performance
   window-performance-info?
   window-performance-info-raw
   window-local-storage
   window-local-storage-info?
   window-local-storage-info-raw
   window-session-storage
   window-session-storage-info?
   window-session-storage-info-raw
   window-indexed-db
   window-indexed-db-info?
   window-indexed-db-info-raw
   window-caches
   window-caches-info?
   window-caches-info-raw
   window-speech-synthesis
   window-speech-synthesis-info?
   window-speech-synthesis-info-raw
   window-style-media
   window-style-media-info?
   window-style-media-info-raw
   window-crypto
   window-crypto-info?
   window-crypto-info-raw
   make-window-scroll-options
   window-scroll-options?
   window-scroll-options-top
   window-scroll-options-left
   window-scroll-options-behavior
   window-set-location!
   window-closed?
   window-length
   window-origin
   window-device-pixel-ratio
   window-inner-height
   window-inner-width
   window-outer-height
   window-outer-width
   window-screen-x
   window-screen-y
   window-screen-left
   window-screen-top
   window-page-x-offset
   window-page-y-offset
   window-scroll-x
   window-scroll-y
   window-is-secure-context?
   window-cross-origin-isolated?
   window-open
   window-fetch
   window-confirm
   window-prompt
   window-alert
   window-print
   window-focus
   window-stop
   window-scroll-to
   window-scroll-by
   window-scroll
   window-resize-to
   window-resize-by
   window-move-to
   window-move-by
   window-set-timeout
   window-set-timeout/delay
   window-clear-timeout
   window-set-interval
   window-clear-interval
   window-request-animation-frame
   window-cancel-animation-frame
   window-request-idle-callback
   window-cancel-idle-callback
   window-get-selection
   window-match-media
   window-get-computed-style
   window-structured-clone))
 "window exports are procedures")

(define (check-nullish-host-wrapper-rejected predicate make-wrapper label)
  (check-false (predicate (make-wrapper (js-null)))
               (string-append label " rejects null raw"))
  (check-false (predicate (make-wrapper (js-undefined)))
               (string-append label " rejects undefined raw")))

(check-nullish-host-wrapper-rejected dom-window? dom-window "dom-window?")
(check-nullish-host-wrapper-rejected window-document-info? window-document-info "window-document-info?")
(check-nullish-host-wrapper-rejected window-location-info? window-location-info "window-location-info?")
(check-nullish-host-wrapper-rejected window-custom-elements-info?
                                     window-custom-elements-info
                                     "window-custom-elements-info?")
(check-nullish-host-wrapper-rejected window-history-info? window-history-info "window-history-info?")
(check-nullish-host-wrapper-rejected window-visual-viewport-info?
                                     window-visual-viewport-info
                                     "window-visual-viewport-info?")
(check-nullish-host-wrapper-rejected window-navigator-info?
                                     window-navigator-info
                                     "window-navigator-info?")
(check-nullish-host-wrapper-rejected window-screen-info? window-screen-info "window-screen-info?")
(check-nullish-host-wrapper-rejected window-performance-info?
                                     window-performance-info
                                     "window-performance-info?")
(check-nullish-host-wrapper-rejected window-local-storage-info?
                                     window-local-storage-info
                                     "window-local-storage-info?")
(check-nullish-host-wrapper-rejected window-session-storage-info?
                                     window-session-storage-info
                                     "window-session-storage-info?")
(check-nullish-host-wrapper-rejected window-indexed-db-info?
                                     window-indexed-db-info
                                     "window-indexed-db-info?")
(check-nullish-host-wrapper-rejected window-caches-info? window-caches-info "window-caches-info?")
(check-nullish-host-wrapper-rejected window-speech-synthesis-info?
                                     window-speech-synthesis-info
                                     "window-speech-synthesis-info?")
(check-nullish-host-wrapper-rejected window-style-media-info?
                                     window-style-media-info
                                     "window-style-media-info?")
(check-nullish-host-wrapper-rejected window-crypto-info? window-crypto-info "window-crypto-info?")

(define computed-style-null-element-message
  (catch-message
   (lambda ()
     (window-get-computed-style (dom-element (js-null))))))

(check-message computed-style-null-element-message
               "window-get-computed-style"
               "computed style null element who")
(check-message computed-style-null-element-message
               "Element host value"
               "computed style null element message")

#t
