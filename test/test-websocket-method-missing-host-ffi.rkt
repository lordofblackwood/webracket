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
        const values = {
          url: url,
          protocols: protocols,
          readyState: 1,
          bufferedAmount: 0,
          protocol: '',
          extensions: ''
        };
        for (const [name, value] of Object.entries(values)) {
          if (name !== missing) {
            this[name] = value;
          }
        }
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

(define send-message
  (missing-method-message
   "send"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-send ws "payload"))))

(define close-message
  (missing-method-message
   "close"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-close ws))))

(define url-message
  (missing-method-message
   "url"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-url ws))))

(define ready-state-message
  (missing-method-message
   "readyState"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-ready-state-number ws))))

(define buffered-amount-message
  (missing-method-message
   "bufferedAmount"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-buffered-amount ws))))

(define protocol-message
  (missing-method-message
   "protocol"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-protocol ws))))

(define extensions-message
  (missing-method-message
   "extensions"
   (lambda ()
     (define ws (websocket-new "wss://example.invalid/socket"))
     (websocket-extensions ws))))

(check-message add-listener-message
               "WebSocket.addEventListener is not available"
               "missing WebSocket.addEventListener message")
(check-message remove-listener-message
               "WebSocket.removeEventListener is not available"
               "missing WebSocket.removeEventListener message")
(check-message send-message
               "WebSocket.send not available in this environment"
               "missing WebSocket.send message")
(check-message close-message
               "WebSocket.close not available in this environment"
               "missing WebSocket.close message")
(check-message url-message
               "WebSocket.url not available in this environment"
               "missing WebSocket.url message")
(check-message ready-state-message
               "WebSocket.readyState not available in this environment"
               "missing WebSocket.readyState message")
(check-message buffered-amount-message
               "WebSocket.bufferedAmount not available in this environment"
               "missing WebSocket.bufferedAmount message")
(check-message protocol-message
               "WebSocket.protocol not available in this environment"
               "missing WebSocket.protocol message")
(check-message extensions-message
               "WebSocket.extensions not available in this environment"
               "missing WebSocket.extensions message")

(js-eval "__wrWebSocketBoundaryRestore();")

(js-log "websocket-method-missing-host-ffi-ok")
#t
