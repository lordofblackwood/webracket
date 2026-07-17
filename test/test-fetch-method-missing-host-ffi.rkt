#lang webracket/base

;; Browser smoke for Fetch wrapper host-method boundary errors.

(require fetch
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
 "globalThis.__wrFetchBoundarySaved = {
    Headers: globalThis.Headers,
    Request: globalThis.Request,
    Response: globalThis.Response
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
        this.url = String(input);
        this.method = 'GET';
        this.headers = new globalThis.Headers();
        this.bodyUsed = false;
      }
      clone() {
        return new globalThis.Request(this.url);
      }
    };
    globalThis.Response = class Response {
      constructor(_body, init) {
        this.ok = true;
        this.status = init && init.status || 200;
        this.statusText = '';
        this.url = '';
        this.type = 'basic';
        this.bodyUsed = false;
        this.headers = new globalThis.Headers();
      }
      clone() {
        return new globalThis.Response(null, {status: this.status});
      }
    };
    delete globalThis[kind].prototype[missing];
  };
  globalThis.__wrFetchBoundaryRestore = () => {
    if (globalThis.__wrFetchBoundarySaved.Headers === undefined) {
      delete globalThis.Headers;
    } else {
      globalThis.Headers = globalThis.__wrFetchBoundarySaved.Headers;
    }
    if (globalThis.__wrFetchBoundarySaved.Request === undefined) {
      delete globalThis.Request;
    } else {
      globalThis.Request = globalThis.__wrFetchBoundarySaved.Request;
    }
    if (globalThis.__wrFetchBoundarySaved.Response === undefined) {
      delete globalThis.Response;
    } else {
      globalThis.Response = globalThis.__wrFetchBoundarySaved.Response;
    }
    delete globalThis.__wrFetchBoundarySaved;
    delete globalThis.__wrFetchBoundaryInstall;
    delete globalThis.__wrFetchBoundaryRestore;
  };")

(define callback (lambda args (void)))

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

(define response-clone-message
  (missing-fetch-method-message
   "Response"
   "clone"
   (lambda ()
     (define response (fetch-response (js-eval "new Response(null, {status: 204})")))
     (check-true (fetch-response? response)
                 "fetch-response? accepts fake host response")
     (fetch-response-clone response))))

(check-message headers-get-message
               "Headers.get is not available"
               "missing Headers.get message")
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
(check-message response-clone-message
               "Response.clone is not available"
               "missing Response.clone message")

(js-eval "__wrFetchBoundaryRestore();")

(js-log "fetch-method-missing-host-ffi-ok")
#t
