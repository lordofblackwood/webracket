#lang webracket/base

;; Browser smoke for malformed built-in host constructors.

(require audio
         browser/image
         websocket
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

(js-eval
 "globalThis.__wrConstructorBoundary = {
    Image: globalThis.Image,
    AudioContext: globalThis.AudioContext,
    WebSocket: globalThis.WebSocket
  };
  globalThis.Image = {};
  globalThis.AudioContext = {};
  globalThis.WebSocket = {};")

(define image-message
  (catch-message
   (lambda ()
     (image-new))))

(define audio-message
  (catch-message
   (lambda ()
     (audio-context-new))))

(define websocket-message
  (catch-message
   (lambda ()
     (websocket-new "wss://example.invalid/socket"))))

(js-eval
 "globalThis.Image = (() => false);
  globalThis.AudioContext = (() => false);
  globalThis.WebSocket = (() => false);")

(define image-non-constructor-message
  (catch-message
   (lambda ()
     (image-new))))

(define audio-non-constructor-message
  (catch-message
   (lambda ()
     (audio-context-new))))

(define websocket-non-constructor-message
  (catch-message
   (lambda ()
     (websocket-new "wss://example.invalid/socket"))))

(js-eval
 "globalThis.Image = class Image {
    constructor() {
      return { src: '', width: 1, height: 1, complete: true, currentSrc: '' };
    }
  };")

(define image-constructor-result-message
  (catch-message
   (lambda ()
     (image-new))))

(js-eval
 "globalThis.Image = globalThis.__wrConstructorBoundary.Image;
  globalThis.AudioContext = globalThis.__wrConstructorBoundary.AudioContext;
  globalThis.WebSocket = globalThis.__wrConstructorBoundary.WebSocket;
  delete globalThis.__wrConstructorBoundary;")

(check-true (and image-message
                 (string-contains/simple? image-message
                                          "Image not available in this environment: new"))
            "missing Image constructor message")
(check-true (and audio-message
                 (string-contains/simple? audio-message
                                          "AudioContext not available in this environment: context-new"))
            "missing AudioContext constructor message")
(check-true (and websocket-message
                 (string-contains/simple? websocket-message
                                          "WebSocket not available in this environment: new"))
            "missing WebSocket constructor message")
(check-true (and image-non-constructor-message
                 (string-contains/simple? image-non-constructor-message
                                          "Image not available in this environment: new"))
            "non-constructible Image constructor message")
(check-true (and audio-non-constructor-message
                 (string-contains/simple? audio-non-constructor-message
                                          "AudioContext not available in this environment: context-new"))
            "non-constructible AudioContext constructor message")
(check-true (and websocket-non-constructor-message
                 (string-contains/simple? websocket-non-constructor-message
                                          "WebSocket not available in this environment: new"))
            "non-constructible WebSocket constructor message")
(check-true (and image-constructor-result-message
                 (string-contains/simple? image-constructor-result-message
                                          "Image constructor result must be HTMLImageElement-like"))
            "bad Image constructor result message")

(js-log "browser-constructor-missing-host-ffi-ok")
#t
