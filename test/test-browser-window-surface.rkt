#lang webracket/base

(require browser/window
         browser/element
         (only-in webracket/unsafe/standard
                  js-eval
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

(define malformed-host (js-eval "({})"))

(check-false (window-custom-elements-info? (window-custom-elements-info malformed-host))
             "window-custom-elements-info? rejects malformed raw")
(check-false (window-history-info? (window-history-info malformed-host))
             "window-history-info? rejects malformed raw")
(check-false (window-screen-info? (window-screen-info malformed-host))
             "window-screen-info? rejects malformed raw")
(check-false (window-performance-info? (window-performance-info malformed-host))
             "window-performance-info? rejects malformed raw")
(check-false (window-local-storage-info? (window-local-storage-info malformed-host))
             "window-local-storage-info? rejects malformed raw")
(check-false (window-session-storage-info? (window-session-storage-info malformed-host))
             "window-session-storage-info? rejects malformed raw")
(check-false (window-indexed-db-info? (window-indexed-db-info malformed-host))
             "window-indexed-db-info? rejects malformed raw")
(check-false (window-caches-info? (window-caches-info malformed-host))
             "window-caches-info? rejects malformed raw")
(check-false (window-speech-synthesis-info? (window-speech-synthesis-info malformed-host))
             "window-speech-synthesis-info? rejects malformed raw")
(check-false (window-crypto-info? (window-crypto-info malformed-host))
             "window-crypto-info? rejects malformed raw")

(js-eval
 "globalThis.__wrWindowSurfaceBoundary = {
    saved: {},
    fake(name) {
      this.saved[name] = Object.getOwnPropertyDescriptor(window, name);
      Object.defineProperty(window, name, {
        value: {},
        configurable: true,
        writable: true
      });
    },
    restore(name) {
      const descriptor = this.saved[name];
      if (descriptor) {
        Object.defineProperty(window, name, descriptor);
      } else {
        delete window[name];
      }
      delete this.saved[name];
    }
  };")

(define (window-surface-boundary-fake! property-name)
  (js-eval
   (string-append "globalThis.__wrWindowSurfaceBoundary.fake('" property-name "');")))

(define (window-surface-boundary-restore! property-name)
  (js-eval
   (string-append "globalThis.__wrWindowSurfaceBoundary.restore('" property-name "');")))

(define (window-surface-message property-name thunk)
  (with-handlers ([exn:fail? (lambda (e)
                               (window-surface-boundary-restore! property-name)
                               (exn-message e))])
    (window-surface-boundary-fake! property-name)
    (thunk)
    (window-surface-boundary-restore! property-name)
    #f))

(define custom-elements-result-message
  (window-surface-message "customElements"
                          (lambda ()
                            (window-custom-elements))))

(define history-result-message
  (window-surface-message "history"
                          (lambda ()
                            (window-history))))

(define screen-result-message
  (window-surface-message "screen"
                          (lambda ()
                            (window-screen))))

(define performance-result-message
  (window-surface-message "performance"
                          (lambda ()
                            (window-performance))))

(define local-storage-result-message
  (window-surface-message "localStorage"
                          (lambda ()
                            (window-local-storage))))

(define session-storage-result-message
  (window-surface-message "sessionStorage"
                          (lambda ()
                            (window-session-storage))))

(define indexed-db-result-message
  (window-surface-message "indexedDB"
                          (lambda ()
                            (window-indexed-db))))

(define caches-result-message
  (window-surface-message "caches"
                          (lambda ()
                            (window-caches))))

(define speech-synthesis-result-message
  (window-surface-message "speechSynthesis"
                          (lambda ()
                            (window-speech-synthesis))))

(define crypto-result-message
  (window-surface-message "crypto"
                          (lambda ()
                            (window-crypto))))

(js-eval "delete globalThis.__wrWindowSurfaceBoundary;")

(check-message custom-elements-result-message
               "window.customElements result must be CustomElementRegistry"
               "malformed customElements result message")
(check-message history-result-message
               "window.history result must be History"
               "malformed history result message")
(check-message screen-result-message
               "window.screen result must be Screen"
               "malformed screen result message")
(check-message performance-result-message
               "window.performance result must be Performance"
               "malformed performance result message")
(check-message local-storage-result-message
               "window.localStorage result must be Storage"
               "malformed localStorage result message")
(check-message session-storage-result-message
               "window.sessionStorage result must be Storage"
               "malformed sessionStorage result message")
(check-message indexed-db-result-message
               "window.indexedDB result must be IDBFactory"
               "malformed indexedDB result message")
(check-message caches-result-message
               "window.caches result must be CacheStorage"
               "malformed caches result message")
(check-message speech-synthesis-result-message
               "window.speechSynthesis result must be SpeechSynthesis"
               "malformed speechSynthesis result message")
(check-message crypto-result-message
               "window.crypto result must be Crypto"
               "malformed crypto result message")

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
