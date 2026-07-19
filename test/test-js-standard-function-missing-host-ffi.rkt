#lang webracket/base

;; Browser smoke for JS standard function accessors when globals are absent.

(require (only-in webracket/unsafe/standard
                  js-decode-uri
                  js-decode-uri-component
                  js-encode-uri
                  js-encode-uri-component
                  js-eval
                  js-finite?
                  js-is-finite
                  js-is-nan
                  js-nan?
                  js-parse-float
                  js-parse-int
                  js-truthy?))

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
 "globalThis.__wrStandardFunctionBoundarySaved = {};
  globalThis.__wrStandardFunctionBoundaryHide = (name) => {
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrStandardFunctionBoundarySaved, name)) {
      globalThis.__wrStandardFunctionBoundarySaved[name] =
        Object.getOwnPropertyDescriptor(globalThis, name) || null;
    }

    try {
      return delete globalThis[name];
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardFunctionBoundaryRestore = (name) => {
    const saved = globalThis.__wrStandardFunctionBoundarySaved[name];
    if (saved) {
      Object.defineProperty(globalThis, name, saved);
    } else {
      delete globalThis[name];
    }
    delete globalThis.__wrStandardFunctionBoundarySaved[name];
  };
  globalThis.__wrStandardFunctionBoundaryRestoreAll = () => {
    for (const name of Object.keys(globalThis.__wrStandardFunctionBoundarySaved)) {
      globalThis.__wrStandardFunctionBoundaryRestore(name);
    }
    delete globalThis.__wrStandardFunctionBoundarySaved;
    delete globalThis.__wrStandardFunctionBoundaryHide;
    delete globalThis.__wrStandardFunctionBoundaryRestore;
    delete globalThis.__wrStandardFunctionBoundaryRestoreAll;
  };")

;; hidden-global? : string? -> boolean?
;;   Hide a global function when the browser allows it.
(define (hidden-global? name)
  (js-truthy?
   (js-eval (string-append "__wrStandardFunctionBoundaryHide('"
                           name
                           "')"))))

;; restore-global! : string? -> void?
;;   Restore a global function after a boundary check.
(define (restore-global! name)
  (js-eval (string-append "__wrStandardFunctionBoundaryRestore('"
                          name
                          "')"))
  (void))

;; check-hidden-function : string? (-> any/c) string? string? -> void?
;;   Check that an absent standard function reports a clear host-boundary error.
(define (check-hidden-function name thunk needle label)
  (cond
    [(hidden-global? name)
     (define message (catch-message thunk))
     (restore-global! name)
     (check-message message needle label)]
    [else
     (restore-global! name)]))

(check-hidden-function "isFinite"
                       (lambda () (js-is-finite 1.0))
                       "isFinite not available in this environment"
                       "missing isFinite message")
(check-hidden-function "isFinite"
                       (lambda () (js-finite? 1.0))
                       "isFinite not available in this environment"
                       "missing finite? isFinite message")
(check-hidden-function "isNaN"
                       (lambda () (js-is-nan 0.0))
                       "isNaN not available in this environment"
                       "missing isNaN message")
(check-hidden-function "isNaN"
                       (lambda () (js-nan? 0.0))
                       "isNaN not available in this environment"
                       "missing nan? isNaN message")
(check-hidden-function "parseFloat"
                       (lambda () (js-parse-float "1.25"))
                       "parseFloat not available in this environment"
                       "missing parseFloat message")
(check-hidden-function "parseInt"
                       (lambda () (js-parse-int "12"))
                       "parseInt not available in this environment"
                       "missing parseInt message")
(check-hidden-function "decodeURI"
                       (lambda () (js-decode-uri "x"))
                       "decodeURI not available in this environment"
                       "missing decodeURI message")
(check-hidden-function "decodeURIComponent"
                       (lambda () (js-decode-uri-component "x"))
                       "decodeURIComponent not available in this environment"
                       "missing decodeURIComponent message")
(check-hidden-function "encodeURI"
                       (lambda () (js-encode-uri "x y"))
                       "encodeURI not available in this environment"
                       "missing encodeURI message")
(check-hidden-function "encodeURIComponent"
                       (lambda () (js-encode-uri-component "x y"))
                       "encodeURIComponent not available in this environment"
                       "missing encodeURIComponent message")

(js-eval "__wrStandardFunctionBoundaryRestoreAll();")

(js-log "js-standard-function-missing-host-ffi-ok")
#t
