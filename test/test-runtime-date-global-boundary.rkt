#lang webracket/base

;; Browser smoke for runtime Date use after the host global is changed.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-truthy?))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (with-restored-date thunk)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore-date-global!)
                     (raise e))])
    (define result (thunk))
    (restore-date-global!)
    result))

(js-eval
 "globalThis.__wrDateBoundary = {
    descriptor: Object.getOwnPropertyDescriptor(globalThis, 'Date') || null,
    hide() {
      try {
        Object.defineProperty(globalThis, 'Date', {
          value: undefined,
          configurable: true,
          writable: true
        });
        return true;
      } catch (_e) {
        return false;
      }
    },
    restore() {
      const saved = globalThis.__wrDateBoundary.descriptor;
      if (saved) {
        Object.defineProperty(globalThis, 'Date', saved);
      } else {
        delete globalThis.Date;
      }
    }
  };")

(define (hide-date-global?)
  (js-truthy?
   (js-eval "globalThis.__wrDateBoundary.hide()")))

(define (restore-date-global!)
  (js-eval "globalThis.__wrDateBoundary.restore();")
  (void))

(define values-with-hidden-date
  (cond
    [(hide-date-global?)
     (with-restored-date
      (lambda ()
        (vector (current-inexact-milliseconds)
                (current-milliseconds)
                (seconds->date 0 #f))))]
    [else
     (restore-date-global!)
     (vector (current-inexact-milliseconds)
             (current-milliseconds)
             (seconds->date 0 #f))]))

(js-eval
 "globalThis.__wrDateBoundary.restore();
  delete globalThis.__wrDateBoundary;")

(define hidden-inexact-ms (vector-ref values-with-hidden-date 0))
(define hidden-exact-ms (vector-ref values-with-hidden-date 1))
(define hidden-date (vector-ref values-with-hidden-date 2))

(check-true (real? hidden-inexact-ms)
            "current-inexact-milliseconds result is real")
(check-true (inexact? hidden-inexact-ms)
            "current-inexact-milliseconds result is inexact")
(check-true (exact-integer? hidden-exact-ms)
            "current-milliseconds result is exact integer")
(check-true (equal? (date-year hidden-date) 1970)
            "seconds->date keeps using captured Date constructor")

(js-log "runtime-date-global-boundary-ok")
#t
