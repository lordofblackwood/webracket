#lang webracket/base

;; Browser smoke for JavaScript Number FFI host-method boundary errors.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-number-epsilon
                  js-number-finite?
                  js-number-integer?
                  js-number-max-safe-integer
                  js-number-max-value
                  js-number-min-safe-integer
                  js-number-min-value
                  js-number-nan
                  js-number-nan?
                  js-number-negative-infinity
                  js-number-positive-infinity
                  js-number-safe-integer?
                  js-number-parse-float
                  js-number-parse-int
                  js-number-to-exponential
                  js-number-to-fixed
                  js-number-to-locale-string
                  js-number-to-precision
                  js-number-to-string
                  js-number-value-of
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
 "globalThis.__wrNumberBoundary = {
    numberDescriptor: Object.getOwnPropertyDescriptor(globalThis, 'Number') || null,
    prototype: {
      toExponential: Number.prototype.toExponential,
      toFixed: Number.prototype.toFixed,
      toLocaleString: Number.prototype.toLocaleString,
      toPrecision: Number.prototype.toPrecision,
      toString: Number.prototype.toString,
      valueOf: Number.prototype.valueOf
    },
    statics: {
      isFinite: Number.isFinite,
      isInteger: Number.isInteger,
      isNaN: Number.isNaN,
      isSafeInteger: Number.isSafeInteger,
      parseFloat: Number.parseFloat,
      parseInt: Number.parseInt
    },
    hideNumber() {
      try {
        return delete globalThis.Number;
      } catch (_e) {
        return false;
      }
    },
    restoreNumber() {
      const saved = globalThis.__wrNumberBoundary.numberDescriptor;
      if (saved) {
        Object.defineProperty(globalThis, 'Number', saved);
      } else {
        delete globalThis.Number;
      }
    }
  };")

(define (without-number-method method thunk)
  (js-eval
   (string-append "Number.prototype['"
                  method
                  "'] = undefined;"))
  (define message (catch-message thunk))
  (js-eval
   (string-append "Number.prototype['"
                  method
                  "'] = globalThis.__wrNumberBoundary.prototype['"
                  method
                  "'];"))
  message)

(define (without-number-static-method method thunk)
  (js-eval
   (string-append "Number['"
                  method
                  "'] = undefined;"))
  (define message (catch-message thunk))
  (js-eval
   (string-append "Number['"
                  method
                  "'] = globalThis.__wrNumberBoundary.statics['"
                  method
                  "'];"))
  message)

(define (hide-number-global?)
  (js-truthy?
   (js-eval "globalThis.__wrNumberBoundary.hideNumber()")))

(define (restore-number-global!)
  (js-eval "globalThis.__wrNumberBoundary.restoreNumber();")
  (void))

(define (check-hidden-number-global thunk needle label)
  (cond
    [(hide-number-global?)
     (define message
       (catch-message/restoring thunk restore-number-global!))
     (check-message message needle label)]
    [else
     (restore-number-global!)]))

(define finite-message
  (without-number-static-method
   "isFinite"
   (lambda ()
     (js-number-finite? 1.0))))

(define integer-message
  (without-number-static-method
   "isInteger"
   (lambda ()
     (js-number-integer? 1.0))))

(define nan-message
  (without-number-static-method
   "isNaN"
   (lambda ()
     (js-number-nan? 0.0))))

(define safe-integer-message
  (without-number-static-method
   "isSafeInteger"
   (lambda ()
     (js-number-safe-integer? 1.0))))

(define parse-float-message
  (without-number-static-method
   "parseFloat"
   (lambda ()
     (js-number-parse-float "1.5"))))

(define parse-int-message
  (without-number-static-method
   "parseInt"
   (lambda ()
     (js-number-parse-int "15"))))

(define to-exponential-message
  (without-number-method
   "toExponential"
   (lambda ()
     (js-number-to-exponential 1.0 (void)))))

(define to-fixed-message
  (without-number-method
   "toFixed"
   (lambda ()
     (js-number-to-fixed 1.0 (void)))))

(define to-locale-string-message
  (without-number-method
   "toLocaleString"
   (lambda ()
     (js-number-to-locale-string 1.0 (void) (void)))))

(define to-precision-message
  (without-number-method
   "toPrecision"
   (lambda ()
     (js-number-to-precision 1.0 (void)))))

(define to-string-message
  (without-number-method
   "toString"
   (lambda ()
     (js-number-to-string 255.0 16))))

(define value-of-message
  (without-number-method
   "valueOf"
   (lambda ()
     (js-number-value-of 1.0))))

(check-hidden-number-global
 (lambda () (js-number-epsilon))
 "Number.EPSILON not available in this environment"
 "missing Number global epsilon message")

(check-hidden-number-global
 (lambda () (js-number-max-safe-integer))
 "Number.MAX_SAFE_INTEGER not available in this environment"
 "missing Number global MAX_SAFE_INTEGER message")

(check-hidden-number-global
 (lambda () (js-number-max-value))
 "Number.MAX_VALUE not available in this environment"
 "missing Number global MAX_VALUE message")

(check-hidden-number-global
 (lambda () (js-number-min-safe-integer))
 "Number.MIN_SAFE_INTEGER not available in this environment"
 "missing Number global MIN_SAFE_INTEGER message")

(check-hidden-number-global
 (lambda () (js-number-min-value))
 "Number.MIN_VALUE not available in this environment"
 "missing Number global MIN_VALUE message")

(check-hidden-number-global
 (lambda () (js-number-nan))
 "Number.NaN not available in this environment"
 "missing Number global NaN message")

(check-hidden-number-global
 (lambda () (js-number-negative-infinity))
 "Number.NEGATIVE_INFINITY not available in this environment"
 "missing Number global NEGATIVE_INFINITY message")

(check-hidden-number-global
 (lambda () (js-number-positive-infinity))
 "Number.POSITIVE_INFINITY not available in this environment"
 "missing Number global POSITIVE_INFINITY message")

(check-hidden-number-global
 (lambda () (js-number-finite? 1.0))
 "Number.isFinite not available in this environment"
 "missing Number global isFinite message")

(js-eval
 "globalThis.__wrNumberBoundary.restoreNumber();
  for (const name of Object.keys(globalThis.__wrNumberBoundary.prototype)) {
    globalThis.Number.prototype[name] = globalThis.__wrNumberBoundary.prototype[name];
  }
  for (const name of Object.keys(globalThis.__wrNumberBoundary.statics)) {
    globalThis.Number[name] = globalThis.__wrNumberBoundary.statics[name];
  }
  delete globalThis.__wrNumberBoundary;")

(check-message finite-message
               "Number.isFinite not available in this environment"
               "missing Number.isFinite message")
(check-message integer-message
               "Number.isInteger not available in this environment"
               "missing Number.isInteger message")
(check-message nan-message
               "Number.isNaN not available in this environment"
               "missing Number.isNaN message")
(check-message safe-integer-message
               "Number.isSafeInteger not available in this environment"
               "missing Number.isSafeInteger message")
(check-message parse-float-message
               "Number.parseFloat not available in this environment"
               "missing Number.parseFloat message")
(check-message parse-int-message
               "Number.parseInt not available in this environment"
               "missing Number.parseInt message")
(check-message to-exponential-message
               "Number.toExponential not available in this environment"
               "missing Number.toExponential message")
(check-message to-fixed-message
               "Number.toFixed not available in this environment"
               "missing Number.toFixed message")
(check-message to-locale-string-message
               "Number.toLocaleString not available in this environment"
               "missing Number.toLocaleString message")
(check-message to-precision-message
               "Number.toPrecision not available in this environment"
               "missing Number.toPrecision message")
(check-message to-string-message
               "Number.toString not available in this environment"
               "missing Number.toString message")
(check-message value-of-message
               "Number.valueOf not available in this environment"
               "missing Number.valueOf message")

(js-log "js-number-method-missing-host-ffi-ok")
#t
