#lang webracket/base

;; Browser smoke for JavaScript Number FFI host-method boundary errors.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-number-to-exponential
                  js-number-to-fixed
                  js-number-to-locale-string
                  js-number-to-precision
                  js-number-to-string
                  js-number-value-of))

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
 "globalThis.__wrNumberBoundary = {
    toExponential: Number.prototype.toExponential,
    toFixed: Number.prototype.toFixed,
    toLocaleString: Number.prototype.toLocaleString,
    toPrecision: Number.prototype.toPrecision,
    toString: Number.prototype.toString,
    valueOf: Number.prototype.valueOf
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
                  "'] = globalThis.__wrNumberBoundary['"
                  method
                  "'];"))
  message)

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

(js-eval
 "for (const name of Object.keys(globalThis.__wrNumberBoundary)) {
    Number.prototype[name] = globalThis.__wrNumberBoundary[name];
  }
  delete globalThis.__wrNumberBoundary;")

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
