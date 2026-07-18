#lang webracket/base

;; Browser smoke for optional window host properties.

(require (only-in webracket/unsafe/dom
                  js-window-caches
                  js-window-closed
                  js-window-crypto
                  js-window-custom-elements
                  js-window-device-pixel-ratio
                  js-window-frame-element
                  js-window-history
                  js-window-inner-width
                  js-window-indexed-db
                  js-window-is-secure-context
                  js-window-length
                  js-window-local-storage
                  js-window-name
                  js-window-navigator
                  js-window-origin
                  js-window-performance
                  js-window-screen
                  js-window-scroll-x
                  js-window-session-storage
                  js-window-speech-synthesis
                  js-window-style-media
                  js-window-visual-viewport
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

(js-eval
 "globalThis.__wrWindowValueBoundaryNames = [
    'caches',
    'closed',
    'crypto',
    'customElements',
    'devicePixelRatio',
    'frameElement',
    'history',
    'innerWidth',
    'indexedDB',
    'isSecureContext',
    'length',
    'localStorage',
    'name',
    'navigator',
    'origin',
    'performance',
    'screen',
    'scrollX',
    'sessionStorage',
    'speechSynthesis',
    'styleMedia',
    'visualViewport'
  ];
  globalThis.__wrWindowValueBoundary = {};
  for (const name of globalThis.__wrWindowValueBoundaryNames) {
    globalThis.__wrWindowValueBoundary[name] = {
      descriptor: Object.getOwnPropertyDescriptor(window, name)
    };
    Object.defineProperty(window, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define caches-message
  (catch-message
   (lambda ()
     (js-window-caches))))

(define closed-message
  (catch-message
   (lambda ()
     (js-window-closed))))

(define crypto-message
  (catch-message
   (lambda ()
     (js-window-crypto))))

(define custom-elements-message
  (catch-message
   (lambda ()
     (js-window-custom-elements))))

(define device-pixel-ratio-message
  (catch-message
   (lambda ()
     (js-window-device-pixel-ratio))))

(define frame-element-message
  (catch-message
   (lambda ()
     (js-window-frame-element))))

(define history-message
  (catch-message
   (lambda ()
     (js-window-history))))

(define inner-width-message
  (catch-message
   (lambda ()
     (js-window-inner-width))))

(define indexed-db-message
  (catch-message
   (lambda ()
     (js-window-indexed-db))))

(define is-secure-context-message
  (catch-message
   (lambda ()
     (js-window-is-secure-context))))

(define length-message
  (catch-message
   (lambda ()
     (js-window-length))))

(define local-storage-message
  (catch-message
   (lambda ()
     (js-window-local-storage))))

(define name-message
  (catch-message
   (lambda ()
     (js-window-name))))

(define navigator-message
  (catch-message
   (lambda ()
     (js-window-navigator))))

(define origin-message
  (catch-message
   (lambda ()
     (js-window-origin))))

(define performance-message
  (catch-message
   (lambda ()
     (js-window-performance))))

(define screen-message
  (catch-message
   (lambda ()
     (js-window-screen))))

(define scroll-x-message
  (catch-message
   (lambda ()
     (js-window-scroll-x))))

(define session-storage-message
  (catch-message
   (lambda ()
     (js-window-session-storage))))

(define speech-synthesis-message
  (catch-message
   (lambda ()
     (js-window-speech-synthesis))))

(define style-media-message
  (catch-message
   (lambda ()
     (js-window-style-media))))

(define visual-viewport-message
  (catch-message
   (lambda ()
     (js-window-visual-viewport))))

(js-eval
 "for (const name of globalThis.__wrWindowValueBoundaryNames) {
    const saved = globalThis.__wrWindowValueBoundary[name];
    if (saved.descriptor) {
      Object.defineProperty(window, name, saved.descriptor);
    } else {
      delete window[name];
    }
  }
  delete globalThis.__wrWindowValueBoundary;
  delete globalThis.__wrWindowValueBoundaryNames;")

(check-message caches-message
               "window.caches not available in this environment"
               "missing caches message")
(check-message closed-message
               "window.closed not available in this environment"
               "missing closed message")
(check-message crypto-message
               "window.crypto not available in this environment"
               "missing crypto message")
(check-message custom-elements-message
               "window.customElements not available in this environment"
               "missing customElements message")
(check-message device-pixel-ratio-message
               "window.devicePixelRatio not available in this environment"
               "missing devicePixelRatio message")
(check-message frame-element-message
               "window.frameElement not available in this environment"
               "missing frameElement message")
(check-message history-message
               "window.history not available in this environment"
               "missing history message")
(check-message inner-width-message
               "window.innerWidth not available in this environment"
               "missing innerWidth message")
(check-message indexed-db-message
               "window.indexedDB not available in this environment"
               "missing indexedDB message")
(check-message is-secure-context-message
               "window.isSecureContext not available in this environment"
               "missing isSecureContext message")
(check-message length-message
               "window.length not available in this environment"
               "missing length message")
(check-message local-storage-message
               "window.localStorage not available in this environment"
               "missing localStorage message")
(check-message name-message
               "window.name not available in this environment"
               "missing name message")
(check-message navigator-message
               "window.navigator not available in this environment"
               "missing navigator message")
(check-message origin-message
               "window.origin not available in this environment"
               "missing origin message")
(check-message performance-message
               "window.performance not available in this environment"
               "missing performance message")
(check-message screen-message
               "window.screen not available in this environment"
               "missing screen message")
(check-message scroll-x-message
               "window.scrollX not available in this environment"
               "missing scrollX message")
(check-message session-storage-message
               "window.sessionStorage not available in this environment"
               "missing sessionStorage message")
(check-message speech-synthesis-message
               "window.speechSynthesis not available in this environment"
               "missing speechSynthesis message")
(check-message style-media-message
               "window.styleMedia not available in this environment"
               "missing styleMedia message")
(check-message visual-viewport-message
               "window.visualViewport not available in this environment"
               "missing visualViewport message")

(js-log "window-value-missing-host-ffi-ok")
#t
