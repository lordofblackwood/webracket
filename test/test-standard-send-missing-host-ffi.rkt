#lang webracket/base

;; Browser smoke for generic JS send boundary errors.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-null
                  js-send
                  js-send/boolean
                  js-send/extern
                  js-send/extern/null
                  js-send/extern/nullish
                  js-send/extern/undefined
                  js-send/flonum
                  js-send/truthy
                  js-send/value))

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

(define target
  (js-eval "({ present() { return true; }, notBoolean() { return 'not boolean'; } })"))

(define throwing-target
  (js-eval "({ throws() { throw new Error('wr hidden WebAssembly host failure'); } })"))

(js-eval
 "(() => {
    const hostObject = Object;
    const getOwnPropertyDescriptor = hostObject.getOwnPropertyDescriptor;
    const defineProperty = hostObject.defineProperty;
    const savedWebAssembly =
      getOwnPropertyDescriptor.call(hostObject, globalThis, 'WebAssembly') || null;
    globalThis.__wrStandardSendBoundary = {
      hideWebAssembly() {
        try {
          defineProperty.call(hostObject, globalThis, 'WebAssembly', {
            configurable: true,
            enumerable: savedWebAssembly ? savedWebAssembly.enumerable : false,
            writable: true,
            value: undefined
          });
          return globalThis.WebAssembly === undefined;
        } catch (_e) {
          try {
            globalThis.WebAssembly = undefined;
            return globalThis.WebAssembly === undefined;
          } catch (_e2) {
            return false;
          }
        }
      },
      restoreWebAssembly() {
        if (savedWebAssembly) {
          defineProperty.call(hostObject, globalThis, 'WebAssembly', savedWebAssembly);
        } else {
          delete globalThis.WebAssembly;
        }
      },
      cleanup() {
        this.restoreWebAssembly();
        delete globalThis.__wrStandardSendBoundary;
      }
    };
  })();")

(js-eval
 "(() => {
    const hostObject = Object;
    const getOwnPropertyDescriptor = hostObject.getOwnPropertyDescriptor;
    const defineProperty = hostObject.defineProperty;
    const hasOwn = hostObject.prototype.hasOwnProperty;
    const saved = {};
    globalThis.__wrStandardSendErrorBoundary = {
      hide(name) {
        if (!hasOwn.call(saved, name)) {
          saved[name] = getOwnPropertyDescriptor.call(hostObject, globalThis, name) || null;
        }
        try {
          defineProperty.call(hostObject, globalThis, name, {
            configurable: true,
            enumerable: saved[name] ? saved[name].enumerable : false,
            writable: true,
            value: undefined
          });
          return globalThis[name] === undefined;
        } catch (_e) {
          try {
            globalThis[name] = undefined;
            return globalThis[name] === undefined;
          } catch (_e2) {
            return false;
          }
        }
      },
      restore(name) {
        if (!hasOwn.call(saved, name)) {
          return;
        }
        const descriptor = saved[name];
        if (descriptor) {
          defineProperty.call(hostObject, globalThis, name, descriptor);
        } else {
          delete globalThis[name];
        }
        delete saved[name];
      },
      cleanup() {
        for (const name of hostObject.keys(saved)) {
          this.restore(name);
        }
        delete globalThis.__wrStandardSendErrorBoundary;
      }
    };
  })();")

(define missing-send-message
  (catch-message
   (lambda ()
     (js-send target "missingMethod" (vector)))))

(define missing-send/extern-message
  (catch-message
   (lambda ()
     (js-send/extern target "missingMethod" (vector)))))

(define missing-send/extern/null-message
  (catch-message
   (lambda ()
     (js-send/extern/null target "missingMethod" (vector)))))

(define missing-send/extern/undefined-message
  (catch-message
   (lambda ()
     (js-send/extern/undefined target "missingMethod" (vector)))))

(define missing-send/extern/nullish-message
  (catch-message
   (lambda ()
     (js-send/extern/nullish target "missingMethod" (vector)))))

(define missing-send/value-message
  (catch-message
   (lambda ()
     (js-send/value target "missingMethod" (vector)))))

(define missing-send/boolean-message
  (catch-message
   (lambda ()
     (js-send/boolean target "missingMethod" (vector)))))

(define missing-send/truthy-message
  (catch-message
   (lambda ()
     (js-send/truthy target "missingMethod" (vector)))))

(define missing-send/flonum-message
  (catch-message
   (lambda ()
     (js-send/flonum target "missingMethod" (vector)))))

(define null-target-message
  (catch-message
   (lambda ()
     (js-send/value (js-null) "missingMethod" (vector)))))

(define (hide-webassembly!)
  (js-eval "__wrStandardSendBoundary.hideWebAssembly()"))

(define (restore-webassembly!)
  (js-eval "__wrStandardSendBoundary.restoreWebAssembly();"))

(define (hide-error-constructor! name)
  (js-eval (string-append "__wrStandardSendErrorBoundary.hide('" name "')")))

(define (restore-error-constructor! name)
  (js-eval (string-append "__wrStandardSendErrorBoundary.restore('" name "');")))

(define (catch-message/hidden-error-constructor name thunk)
  (if (hide-error-constructor! name)
      (catch-message/restoring
       thunk
       (lambda () (restore-error-constructor! name)))
      (begin
        (restore-error-constructor! name)
        #f)))

(define hidden-webassembly-host-exception-message
  (if (hide-webassembly!)
      (catch-message/restoring
       (lambda ()
         (js-send/value throwing-target "throws" (vector)))
       restore-webassembly!)
      (begin
        (restore-webassembly!)
        (catch-message
         (lambda ()
           (js-send/value throwing-target "throws" (vector)))))))

(define hidden-error-missing-send/value-message
  (catch-message/hidden-error-constructor
   "Error"
   (lambda ()
     (js-send/value target "missingMethod" (vector)))))

(define hidden-type-error-send/boolean-message
  (catch-message/hidden-error-constructor
   "TypeError"
   (lambda ()
     (js-send/boolean target "notBoolean" (vector)))))

(check-message missing-send-message
               "js-send: method missingMethod not available in this environment"
               "missing js-send message")
(check-message missing-send/extern-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern message")
(check-message missing-send/extern/null-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern/null message")
(check-message missing-send/extern/undefined-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern/undefined message")
(check-message missing-send/extern/nullish-message
               "js-send/extern: method missingMethod not available in this environment"
               "missing js-send/extern/nullish message")
(check-message missing-send/value-message
               "js-send/value: method missingMethod not available in this environment"
               "missing js-send/value message")
(check-message missing-send/boolean-message
               "js-send/boolean: method missingMethod not available in this environment"
               "missing js-send/boolean message")
(check-message missing-send/truthy-message
               "js-send/truthy: method missingMethod not available in this environment"
               "missing js-send/truthy message")
(check-message missing-send/flonum-message
               "js-send/flonum: method missingMethod not available in this environment"
               "missing js-send/flonum message")
(check-message null-target-message
               "js-send/value: target object is null or undefined"
               "missing null target message")
(check-message hidden-webassembly-host-exception-message
               "wr hidden WebAssembly host failure"
               "host exception survives hidden WebAssembly")

(when hidden-error-missing-send/value-message
  (check-message hidden-error-missing-send/value-message
                 "js-send/value: method missingMethod not available in this environment"
                 "host error constructor hidden message"))

(when hidden-type-error-send/boolean-message
  (check-message hidden-type-error-send/boolean-message
                 "js-send/boolean: expected boolean result, got string"
                 "host type error constructor hidden message"))

(js-eval "__wrStandardSendBoundary.cleanup();")
(js-eval "__wrStandardSendErrorBoundary.cleanup();")

(js-log "standard-send-missing-host-ffi-ok")
#t
