#lang webracket/base

;; Browser smoke for WebSocket wrapper host-method boundary errors.

(require websocket
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

(js-eval
 "globalThis.__wrWebSocketBoundarySaved = globalThis.WebSocket;
  globalThis.__wrWebSocketBoundaryInstall = (missing) => {
    globalThis.WebSocket = class WebSocket {
      constructor(url, protocols) {
        this.url = url;
        this.protocols = protocols;
        this.readyState = 1;
        this.bufferedAmount = 0;
        this.protocol = '';
        this.extensions = '';
      }
      send(_data) {}
      close(_code, _reason) {}
      addEventListener(_type, _listener, _options) {}
      removeEventListener(_type, _listener, _options) {}
    };
    delete globalThis.WebSocket.prototype[missing];
  };
  globalThis.__wrWebSocketBoundaryRestore = () => {
    globalThis.WebSocket = globalThis.__wrWebSocketBoundarySaved;
    delete globalThis.__wrWebSocketBoundarySaved;
    delete globalThis.__wrWebSocketBoundaryInstall;
    delete globalThis.__wrWebSocketBoundaryRestore;
  };")

(define callback (lambda args (void)))

(define (missing-method-message method thunk)
  (js-eval (string-append "__wrWebSocketBoundaryInstall('"
                          method
                          "')"))
  (define message (catch-message thunk))
  message)

(define add-listener-message
  (missing-method-message
   "addEventListener"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-add-event-listener! ws 'message callback))))

(define remove-listener-message
  (missing-method-message
   "removeEventListener"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-remove-event-listener! ws 'message callback))))

(check-message add-listener-message
               "WebSocket.addEventListener is not available"
               "missing WebSocket.addEventListener message")
(check-message remove-listener-message
               "WebSocket.removeEventListener is not available"
               "missing WebSocket.removeEventListener message")

(js-eval "__wrWebSocketBoundaryRestore();")

(js-log "websocket-method-missing-host-ffi-ok")
#t
