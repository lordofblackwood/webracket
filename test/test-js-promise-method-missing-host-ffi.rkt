#lang webracket/base

;; Browser smoke for JS Promise wrapper host-method boundaries.

(require js/promise
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

(js-eval
 "globalThis.__wrPromiseBoundarySaved = globalThis.Promise;
  globalThis.__wrPromiseBoundaryThenOnly = {
    then(_onFulfilled, _onRejected) {
      return this;
    }
  };
  globalThis.__wrPromiseBoundaryBadResults = {
    then(_onFulfilled, _onRejected) {
      return 42;
    },
    catch(_onRejected) {
      return null;
    },
    finally(_onFinally) {
      return {};
    }
  };
  globalThis.Promise = (() => false);
  globalThis.Promise.resolve = (_value) => globalThis.__wrPromiseBoundaryThenOnly;
  globalThis.Promise.reject = (_value) => globalThis.__wrPromiseBoundaryThenOnly;")

(define non-constructor-resolve-message
  (catch-message
   (lambda ()
     (js-promise-resolved 'ok))))

(define non-constructor-reject-message
  (catch-message
   (lambda ()
     (js-promise-rejected 'bad))))

(js-eval
 "globalThis.Promise = function Promise() {};")

(js-eval
 "globalThis.Promise.resolve = (_value) => 42;
  globalThis.Promise.reject = (_value) => null;")

(define bad-resolve-result-message
  (catch-message
   (lambda ()
     (js-promise-resolved 'ok))))

(define bad-reject-result-message
  (catch-message
   (lambda ()
     (js-promise-rejected 'bad))))

(js-eval
 "globalThis.Promise = function Promise() {};")

(define then-only-promise
  (js-promise-wrap
   (js-eval "globalThis.__wrPromiseBoundaryThenOnly")))

(define bad-result-promise
  (js-promise-wrap
   (js-eval "globalThis.__wrPromiseBoundaryBadResults")))

(define null-raw-promise
  (js-promise (js-null)))

(define undefined-raw-promise
  (js-promise (js-undefined)))

(check-false (js-promise? null-raw-promise)
             "js-promise? rejects null raw")
(check-false (js-promise? undefined-raw-promise)
             "js-promise? rejects undefined raw")
(check-false (js-promise-thenable? null-raw-promise)
             "js-promise-thenable? rejects null raw")
(check-false (js-promise-thenable? undefined-raw-promise)
             "js-promise-thenable? rejects undefined raw")

(define null-wrap-message
  (catch-message
   (lambda ()
     (js-promise-wrap (js-null)))))

(define undefined-wrap-message
  (catch-message
   (lambda ()
     (js-promise-wrap (js-undefined)))))

(define null-raw-then-message
  (catch-message
   (lambda ()
     (js-promise-then null-raw-promise
                      (lambda (value) value)))))

(define undefined-raw-then-message
  (catch-message
   (lambda ()
     (js-promise-then undefined-raw-promise
                      (lambda (value) value)))))

(define bad-then-result-message
  (catch-message
   (lambda ()
     (js-promise-then bad-result-promise
                      (lambda (value) value)))))

(define resolve-message
  (catch-message
   (lambda ()
     (js-promise-resolved 'ok))))

(define reject-message
  (catch-message
   (lambda ()
     (js-promise-rejected 'bad))))

(define catch-method-message
  (catch-message
   (lambda ()
     (js-promise-catch then-only-promise
                       (lambda (_value) (void))))))

(define bad-catch-result-message
  (catch-message
   (lambda ()
     (js-promise-catch bad-result-promise
                       (lambda (_value) (void))))))

(define finally-method-message
  (catch-message
   (lambda ()
     (js-promise-finally then-only-promise
                         (lambda () (void))))))

(define bad-finally-result-message
  (catch-message
   (lambda ()
     (js-promise-finally bad-result-promise
                         (lambda () (void))))))

(js-eval
 "globalThis.Promise = globalThis.__wrPromiseBoundarySaved;
  delete globalThis.__wrPromiseBoundarySaved;
  delete globalThis.__wrPromiseBoundaryThenOnly;
  delete globalThis.__wrPromiseBoundaryBadResults;")

(check-message resolve-message
               "Promise.resolve is not available"
               "missing Promise.resolve message")
(check-message reject-message
               "Promise.reject is not available"
               "missing Promise.reject message")
(check-message non-constructor-resolve-message
               "Promise is not available"
               "non-constructible Promise.resolve message")
(check-message non-constructor-reject-message
               "Promise is not available"
               "non-constructible Promise.reject message")
(check-message bad-resolve-result-message
               "Promise.resolve result must be Promise-like"
               "bad Promise.resolve result message")
(check-message bad-reject-result-message
               "Promise.reject result must be Promise-like"
               "bad Promise.reject result message")
(check-message null-wrap-message
               "Promise-like external/raw"
               "null raw Promise wrap message")
(check-message undefined-wrap-message
               "Promise-like external/raw"
               "undefined raw Promise wrap message")
(check-message null-raw-then-message
               "js-promise?"
               "null raw Promise then message")
(check-message undefined-raw-then-message
               "js-promise?"
               "undefined raw Promise then message")
(check-message bad-then-result-message
               "Promise.then result must be Promise-like"
               "bad Promise.then result message")
(check-message catch-method-message
               "Promise.catch is not available"
               "missing Promise.catch message")
(check-message bad-catch-result-message
               "Promise.catch result must be Promise-like"
               "bad Promise.catch result message")
(check-message finally-method-message
               "Promise.finally is not available"
               "missing Promise.finally message")
(check-message bad-finally-result-message
               "Promise.finally result must be Promise-like"
               "bad Promise.finally result message")

(js-log "js-promise-method-missing-host-ffi-ok")
#t
