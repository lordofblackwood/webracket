#lang webracket/base

;; Browser smoke for JS Promise wrapper host-method boundaries.

(require js/promise
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
 "globalThis.__wrPromiseBoundarySaved = globalThis.Promise;
  globalThis.__wrPromiseBoundaryThenOnly = {
    then(_onFulfilled, _onRejected) {
      return this;
    }
  };
  globalThis.Promise = function Promise() {};")

(define then-only-promise
  (js-promise-wrap
   (js-eval "globalThis.__wrPromiseBoundaryThenOnly")))

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

(define finally-method-message
  (catch-message
   (lambda ()
     (js-promise-finally then-only-promise
                         (lambda () (void))))))

(js-eval
 "globalThis.Promise = globalThis.__wrPromiseBoundarySaved;
  delete globalThis.__wrPromiseBoundarySaved;
  delete globalThis.__wrPromiseBoundaryThenOnly;")

(check-message resolve-message
               "Promise.resolve is not available"
               "missing Promise.resolve message")
(check-message reject-message
               "Promise.reject is not available"
               "missing Promise.reject message")
(check-message catch-method-message
               "Promise.catch is not available"
               "missing Promise.catch message")
(check-message finally-method-message
               "Promise.finally is not available"
               "missing Promise.finally message")

(js-log "js-promise-method-missing-host-ffi-ok")
#t
