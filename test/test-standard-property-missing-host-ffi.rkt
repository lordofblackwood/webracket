#lang webracket/base

;; Browser smoke for generic JS property/new boundary errors.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-index
                  js-new
                  js-null
                  js-ref
                  js-ref/extern
                  js-set!))

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

(define null-value (js-null))
(define plain-object (js-eval "({})"))

(js-eval
 "(() => {
    const hostObject = Object;
    const getOwnPropertyDescriptor = hostObject.getOwnPropertyDescriptor;
    const defineProperty = hostObject.defineProperty;
    const savedReflect =
      getOwnPropertyDescriptor.call(hostObject, globalThis, 'Reflect') || null;
    globalThis.__wrStandardPropertyBoundary = {
      constructor: class WRReflectBoundary {
        constructor() {
          this.ok = 41;
        }
      },
      hideReflect() {
        try {
          return delete globalThis.Reflect;
        } catch (_e) {
          return false;
        }
      },
      restoreReflect() {
        if (savedReflect) {
          defineProperty.call(hostObject, globalThis, 'Reflect', savedReflect);
        } else {
          delete globalThis.Reflect;
        }
      },
      cleanup() {
        this.restoreReflect();
        delete globalThis.__wrStandardPropertyBoundary;
      }
    };
  })();")

(define (hidden-reflect?)
  (js-eval "__wrStandardPropertyBoundary.hideReflect()"))

(define (restore-reflect!)
  (js-eval "__wrStandardPropertyBoundary.restoreReflect()")
  (void))

(define (check-hidden-reflect/new-survives)
  (define (construct)
    (define value
      (js-new (js-ref/extern (js-eval "__wrStandardPropertyBoundary")
                             "constructor")
              (vector)))
    (check-true (= (js-ref value "ok") 41)
                "js-new constructed with hidden Reflect"))
  (cond
    [(hidden-reflect?)
     (define message
       (catch-message/restoring construct restore-reflect!))
     (check-true (not message)
                 "js-new survives hidden Reflect")]
    [else
     (restore-reflect!)
     (define message (catch-message construct))
     (check-true (not message)
                 "js-new works when Reflect cannot be hidden")]))

(define ref-message
  (catch-message
   (lambda ()
     (js-ref null-value "missing"))))

(define ref/extern-message
  (catch-message
   (lambda ()
     (js-ref/extern null-value "missing"))))

(define set-message
  (catch-message
   (lambda ()
     (js-set! null-value "missing" 1))))

(define index-message
  (catch-message
   (lambda ()
     (js-index null-value "missing"))))

(define new-null-message
  (catch-message
   (lambda ()
     (js-new null-value (vector)))))

(define new-object-message
  (catch-message
   (lambda ()
     (js-new plain-object (vector)))))

(define new-non-constructor-message
  (catch-message
   (lambda ()
     (js-new (js-eval "(() => {})") (vector)))))

(check-hidden-reflect/new-survives)

(check-message ref-message
               "js-ref: target object is null or undefined"
               "missing js-ref null target message")
(check-message ref/extern-message
               "js-ref/extern: target object is null or undefined"
               "missing js-ref/extern null target message")
(check-message set-message
               "js-set!: target object is null or undefined"
               "missing js-set! null target message")
(check-message index-message
               "js-index: target object is null or undefined"
               "missing js-index null target message")
(check-message new-null-message
               "js-new: constructor is null or undefined"
               "missing js-new null constructor message")
(check-message new-object-message
               "js-new: expected constructor function, got object"
               "missing js-new object constructor message")
(check-message new-non-constructor-message
               "js-new: expected constructible function"
               "missing js-new non-constructor function message")

(js-eval "__wrStandardPropertyBoundary.cleanup();")

(js-log "standard-property-missing-host-ffi-ok")
#t
