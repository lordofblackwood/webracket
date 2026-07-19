#lang webracket/base

;; Browser smoke for Fetch wrapper host-method boundary errors.

(require fetch
         (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (catch-message/restoring thunk restore!)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore!)
                     (exn-message e))])
    (thunk)
    (restore!)
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
 "globalThis.__wrFetchBoundarySaved = {
    Headers: Object.getOwnPropertyDescriptor(globalThis, 'Headers') || null,
    Request: Object.getOwnPropertyDescriptor(globalThis, 'Request') || null,
    Response: Object.getOwnPropertyDescriptor(globalThis, 'Response') || null
  };
  globalThis.__wrFetchBoundaryRestoreConstructor = (kind) => {
    const saved = globalThis.__wrFetchBoundarySaved[kind];
    if (saved) {
      Object.defineProperty(globalThis, kind, saved);
    } else {
      delete globalThis[kind];
    }
  };
  globalThis.__wrFetchBoundaryHideConstructor = (kind) => {
    try {
      Object.defineProperty(globalThis, kind, {
        value: undefined,
        configurable: true,
        writable: true
      });
      return true;
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrFetchBoundaryInstallNonConstructor = (kind) => {
    try {
      Object.defineProperty(globalThis, kind, {
        value: () => {},
        configurable: true,
        writable: true
      });
      return true;
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrFetchBoundaryInstall = (kind, missing) => {
    globalThis.Headers = class Headers {
      constructor(_init) {
        this.map = new Map();
      }
      get(name) {
        return this.map.get(String(name).toLowerCase()) || null;
      }
      has(name) {
        return this.map.has(String(name).toLowerCase());
      }
      set(name, value) {
        this.map.set(String(name).toLowerCase(), String(value));
      }
      append(name, value) {
        this.set(name, value);
      }
      delete(name) {
        this.map.delete(String(name).toLowerCase());
      }
      forEach(callback, thisArg) {
        for (const [name, value] of this.map.entries()) {
          callback.call(thisArg, value, name, this);
        }
      }
    };
    globalThis.Request = class Request {
      constructor(input, _init) {
        if (kind !== 'Request' || missing !== 'url') this.url = String(input);
        if (kind !== 'Request' || missing !== 'method') this.method = 'GET';
        if (kind !== 'Request' || missing !== 'headers') this.headers = new globalThis.Headers();
        if (kind !== 'Request' || missing !== 'bodyUsed') this.bodyUsed = false;
      }
      clone() {
        return new globalThis.Request(this.url);
      }
    };
    globalThis.Response = class Response {
      constructor(_body, init) {
        if (kind !== 'Response' || missing !== 'ok') this.ok = true;
        if (kind !== 'Response' || missing !== 'status') this.status = init && init.status || 200;
        if (kind !== 'Response' || missing !== 'statusText') this.statusText = '';
        if (kind !== 'Response' || missing !== 'url') this.url = '';
        if (kind !== 'Response' || missing !== 'type') this.type = 'basic';
        if (kind !== 'Response' || missing !== 'bodyUsed') this.bodyUsed = false;
        if (kind !== 'Response' || missing !== 'headers') this.headers = new globalThis.Headers();
      }
      clone() {
        return new globalThis.Response(null, {status: this.status});
      }
    };
    delete globalThis[kind].prototype[missing];
  };
  globalThis.__wrFetchBoundaryRestore = () => {
    globalThis.__wrFetchBoundaryRestoreConstructor('Headers');
    globalThis.__wrFetchBoundaryRestoreConstructor('Request');
    globalThis.__wrFetchBoundaryRestoreConstructor('Response');
    delete globalThis.__wrFetchBoundarySaved;
    delete globalThis.__wrFetchBoundaryRestoreConstructor;
    delete globalThis.__wrFetchBoundaryHideConstructor;
    delete globalThis.__wrFetchBoundaryInstallNonConstructor;
    delete globalThis.__wrFetchBoundaryInstall;
    delete globalThis.__wrFetchBoundaryRestore;
  };")

(define callback (lambda args (void)))

(define headers-before-constructor-patch (make-fetch-headers))
(define request-before-constructor-patch
  (make-fetch-request "https://example.invalid/fetch"))
(define response-before-constructor-patch
  (fetch-response (js-eval "new Response(null, {status: 204})")))

(define (hide-fetch-constructor? kind)
  (js-truthy?
   (js-eval (string-append "__wrFetchBoundaryHideConstructor('"
                           kind
                           "')"))))

(define (install-fetch-non-constructor? kind)
  (js-truthy?
   (js-eval (string-append "__wrFetchBoundaryInstallNonConstructor('"
                           kind
                           "')"))))

(define (restore-fetch-constructor! kind)
  (js-eval (string-append "__wrFetchBoundaryRestoreConstructor('"
                          kind
                          "')"))
  (void))

(define (missing-constructor-message kind thunk)
  (cond
    [(hide-fetch-constructor? kind)
     (catch-message/restoring
      thunk
      (lambda ()
        (restore-fetch-constructor! kind)))]
    [else
     (restore-fetch-constructor! kind)
     #f]))

(define (non-constructor-message kind thunk)
  (cond
    [(install-fetch-non-constructor? kind)
     (catch-message/restoring
      thunk
      (lambda ()
        (restore-fetch-constructor! kind)))]
    [else
     (restore-fetch-constructor! kind)
     #f]))

(define headers-constructor-message
  (missing-constructor-message
   "Headers"
   (lambda ()
     (make-fetch-headers))))

(define headers-non-constructor-message
  (non-constructor-message
   "Headers"
   (lambda ()
     (make-fetch-headers))))

(define headers-existing-wrapper-constructor-message
  (missing-constructor-message
   "Headers"
   (lambda ()
     (fetch-headers-get headers-before-constructor-patch 'x-test))))

(define request-constructor-message
  (missing-constructor-message
   "Request"
   (lambda ()
     (make-fetch-request "https://example.invalid/fetch"))))

(define request-non-constructor-message
  (non-constructor-message
   "Request"
   (lambda ()
     (make-fetch-request "https://example.invalid/fetch"))))

(define request-existing-wrapper-constructor-message
  (missing-constructor-message
   "Request"
   (lambda ()
     (fetch-request-url request-before-constructor-patch))))

(define response-existing-wrapper-constructor-message
  (missing-constructor-message
   "Response"
   (lambda ()
     (fetch-response-status response-before-constructor-patch))))

(define (missing-fetch-method-message kind method thunk)
  (js-eval (string-append "__wrFetchBoundaryInstall('"
                          kind
                          "', '"
                          method
                          "')"))
  (catch-message thunk))

(define (missing-headers-message method thunk)
  (missing-fetch-method-message "Headers" method thunk))

(define headers-get-message
  (missing-headers-message
   "get"
   (lambda ()
     (define headers (make-fetch-headers))
     (check-true (fetch-headers? headers)
                 "fetch-headers? accepts fake host headers")
     (fetch-headers-get headers 'x-test))))

(define headers-has-message
  (missing-headers-message
   "has"
   (lambda ()
     (define headers (make-fetch-headers))
     (fetch-headers-has? headers 'x-test))))

(define headers-set-message
  (missing-headers-message
   "set"
   (lambda ()
     (define headers (make-fetch-headers))
     (fetch-headers-set! headers 'x-test "1"))))

(define headers-append-message
  (missing-headers-message
   "append"
   (lambda ()
     (define headers (make-fetch-headers))
     (fetch-headers-append! headers 'x-test "1"))))

(define headers-delete-message
  (missing-headers-message
   "delete"
   (lambda ()
     (define headers (make-fetch-headers))
     (fetch-headers-delete! headers 'x-test))))

(define headers-for-each-message
  (missing-headers-message
   "forEach"
   (lambda ()
     (define headers (make-fetch-headers))
     (fetch-headers-for-each headers callback))))

(define request-clone-message
  (missing-fetch-method-message
   "Request"
   "clone"
   (lambda ()
     (define request (make-fetch-request "https://example.invalid/fetch"))
     (check-true (fetch-request? request)
                 "fetch-request? accepts fake host request")
     (fetch-request-clone request))))

(define (missing-request-property-message property thunk)
  (missing-fetch-method-message "Request" property thunk))

(define request-method-message
  (missing-request-property-message
   "method"
   (lambda ()
     (fetch-request-method (make-fetch-request "https://example.invalid/fetch")))))

(define request-url-message
  (missing-request-property-message
   "url"
   (lambda ()
     (fetch-request-url (make-fetch-request "https://example.invalid/fetch")))))

(define request-body-used-message
  (missing-request-property-message
   "bodyUsed"
   (lambda ()
     (fetch-request-body-used? (make-fetch-request "https://example.invalid/fetch")))))

(define request-headers-message
  (missing-request-property-message
   "headers"
   (lambda ()
     (fetch-request-headers (make-fetch-request "https://example.invalid/fetch")))))

(define response-clone-message
  (missing-fetch-method-message
   "Response"
   "clone"
   (lambda ()
     (define response (fetch-response (js-eval "new Response(null, {status: 204})")))
     (check-true (fetch-response? response)
                 "fetch-response? accepts fake host response")
     (fetch-response-clone response))))

(define (missing-response-property-message property thunk)
  (missing-fetch-method-message "Response" property thunk))

(define response-ok-message
  (missing-response-property-message
   "ok"
   (lambda ()
     (fetch-response-ok? (fetch-response (js-eval "new Response(null, {status: 204})"))))))

(define response-status-message
  (missing-response-property-message
   "status"
   (lambda ()
     (fetch-response-status (fetch-response (js-eval "new Response(null, {status: 204})"))))))

(define response-status-text-message
  (missing-response-property-message
   "statusText"
   (lambda ()
     (fetch-response-status-text (fetch-response (js-eval "new Response(null, {status: 204})"))))))

(define response-url-message
  (missing-response-property-message
   "url"
   (lambda ()
     (fetch-response-url (fetch-response (js-eval "new Response(null, {status: 204})"))))))

(define response-type-message
  (missing-response-property-message
   "type"
   (lambda ()
     (fetch-response-type (fetch-response (js-eval "new Response(null, {status: 204})"))))))

(define response-body-used-message
  (missing-response-property-message
   "bodyUsed"
   (lambda ()
     (fetch-response-body-used? (fetch-response (js-eval "new Response(null, {status: 204})"))))))

(define response-headers-message
  (missing-response-property-message
   "headers"
   (lambda ()
     (fetch-response-headers (fetch-response (js-eval "new Response(null, {status: 204})"))))))

(check-message headers-get-message
               "Headers.get is not available"
               "missing Headers.get message")
(when headers-constructor-message
  (check-message headers-constructor-message
                 "Headers constructor is not available"
                 "missing Headers constructor message"))
(when headers-non-constructor-message
  (check-message headers-non-constructor-message
                 "Headers constructor is not available"
                 "non-constructible Headers constructor message"))
(when headers-existing-wrapper-constructor-message
  (check-message headers-existing-wrapper-constructor-message
                 "Headers constructor is not available"
                 "missing existing Headers wrapper constructor message"))
(check-message headers-has-message
               "Headers.has is not available"
               "missing Headers.has message")
(check-message headers-set-message
               "Headers.set is not available"
               "missing Headers.set message")
(check-message headers-append-message
               "Headers.append is not available"
               "missing Headers.append message")
(check-message headers-delete-message
               "Headers.delete is not available"
               "missing Headers.delete message")
(check-message headers-for-each-message
               "Headers.forEach is not available"
               "missing Headers.forEach message")
(check-message request-clone-message
               "Request.clone is not available"
               "missing Request.clone message")
(check-message request-method-message
               "Request.method is not available"
               "missing Request.method message")
(check-message request-url-message
               "Request.url is not available"
               "missing Request.url message")
(check-message request-body-used-message
               "Request.bodyUsed is not available"
               "missing Request.bodyUsed message")
(check-message request-headers-message
               "Request.headers is not available"
               "missing Request.headers message")
(when request-constructor-message
  (check-message request-constructor-message
                 "Request constructor is not available"
                 "missing Request constructor message"))
(when request-non-constructor-message
  (check-message request-non-constructor-message
                 "Request constructor is not available"
                 "non-constructible Request constructor message"))
(when request-existing-wrapper-constructor-message
  (check-message request-existing-wrapper-constructor-message
                 "Request constructor is not available"
                 "missing existing Request wrapper constructor message"))
(check-message response-clone-message
               "Response.clone is not available"
               "missing Response.clone message")
(check-message response-ok-message
               "Response.ok is not available"
               "missing Response.ok message")
(check-message response-status-message
               "Response.status is not available"
               "missing Response.status message")
(check-message response-status-text-message
               "Response.statusText is not available"
               "missing Response.statusText message")
(check-message response-url-message
               "Response.url is not available"
               "missing Response.url message")
(check-message response-type-message
               "Response.type is not available"
               "missing Response.type message")
(check-message response-body-used-message
               "Response.bodyUsed is not available"
               "missing Response.bodyUsed message")
(check-message response-headers-message
               "Response.headers is not available"
               "missing Response.headers message")
(when response-existing-wrapper-constructor-message
  (check-message response-existing-wrapper-constructor-message
                 "Response constructor is not available"
                 "missing existing Response wrapper constructor message"))

(js-eval "__wrFetchBoundaryRestore();")

(js-log "fetch-method-missing-host-ffi-ok")
#t
