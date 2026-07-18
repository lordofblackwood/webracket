#lang webracket/base

;; Browser smoke for observer wrapper host-method boundary errors.

(require (only-in intersection-observer
                  intersection-observer?
                  intersection-observer-disconnect!
                  intersection-observer-observe!
                  intersection-observer-unobserve!
                  make-intersection-observer)
         (only-in resize-observer
                  make-resize-observer
                  resize-observer?
                  resize-observer-disconnect!
                  resize-observer-observe!
                  resize-observer-unobserve!)
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
 "globalThis.__wrObserverBoundarySavedIntersection = globalThis.IntersectionObserver;
  globalThis.__wrObserverBoundarySavedResize = globalThis.ResizeObserver;
  globalThis.__wrObserverBoundaryTarget = {nodeType: 1};
  globalThis.__wrObserverBoundaryInstallIntersection = (missing) => {
    globalThis.IntersectionObserver = class IntersectionObserver {
      constructor(callback, options) {
        this.callback = callback;
        this.options = options;
        this.calls = [];
      }
      observe(target) {
        this.calls.push(['observe', target]);
      }
      unobserve(target) {
        this.calls.push(['unobserve', target]);
      }
      disconnect() {
        this.calls.push(['disconnect']);
      }
    };
    delete globalThis.IntersectionObserver.prototype[missing];
  };
  globalThis.__wrObserverBoundaryInstallResize = (missing) => {
    globalThis.ResizeObserver = class ResizeObserver {
      constructor(callback) {
        this.callback = callback;
        this.calls = [];
      }
      observe(target, options) {
        this.calls.push(['observe', target, options]);
      }
      unobserve(target) {
        this.calls.push(['unobserve', target]);
      }
      disconnect() {
        this.calls.push(['disconnect']);
      }
    };
    delete globalThis.ResizeObserver.prototype[missing];
  };
  globalThis.__wrObserverBoundaryHideIntersection = () => {
    globalThis.IntersectionObserver = undefined;
  };
  globalThis.__wrObserverBoundaryHideResize = () => {
    globalThis.ResizeObserver = undefined;
  };
  globalThis.__wrObserverBoundaryRestoreIntersection = () => {
    if (globalThis.__wrObserverBoundarySavedIntersection === undefined) {
      delete globalThis.IntersectionObserver;
    } else {
      globalThis.IntersectionObserver = globalThis.__wrObserverBoundarySavedIntersection;
    }
  };
  globalThis.__wrObserverBoundaryRestoreResize = () => {
    if (globalThis.__wrObserverBoundarySavedResize === undefined) {
      delete globalThis.ResizeObserver;
    } else {
      globalThis.ResizeObserver = globalThis.__wrObserverBoundarySavedResize;
    }
  };
  globalThis.__wrObserverBoundaryRestore = () => {
    globalThis.__wrObserverBoundaryRestoreIntersection();
    globalThis.__wrObserverBoundaryRestoreResize();
    delete globalThis.__wrObserverBoundarySavedIntersection;
    delete globalThis.__wrObserverBoundarySavedResize;
    delete globalThis.__wrObserverBoundaryTarget;
    delete globalThis.__wrObserverBoundaryInstallIntersection;
    delete globalThis.__wrObserverBoundaryInstallResize;
    delete globalThis.__wrObserverBoundaryHideIntersection;
    delete globalThis.__wrObserverBoundaryHideResize;
    delete globalThis.__wrObserverBoundaryRestoreIntersection;
    delete globalThis.__wrObserverBoundaryRestoreResize;
    delete globalThis.__wrObserverBoundaryRestore;
  };")

(define target (js-eval "globalThis.__wrObserverBoundaryTarget"))
(define callback (lambda args (void)))

(define (missing-intersection-message method thunk)
  (js-eval (string-append "__wrObserverBoundaryInstallIntersection('"
                          method
                          "')"))
  (catch-message thunk))

(define (missing-resize-message method thunk)
  (js-eval (string-append "__wrObserverBoundaryInstallResize('"
                          method
                          "')"))
  (catch-message thunk))

(define (missing-intersection-constructor-message thunk)
  (js-eval "__wrObserverBoundaryHideIntersection();")
  (define message (catch-message thunk))
  (js-eval "__wrObserverBoundaryRestoreIntersection();")
  message)

(define (missing-resize-constructor-message thunk)
  (js-eval "__wrObserverBoundaryHideResize();")
  (define message (catch-message thunk))
  (js-eval "__wrObserverBoundaryRestoreResize();")
  message)

(define intersection-constructor-message
  (missing-intersection-constructor-message
   (lambda ()
     (make-intersection-observer callback))))

(define resize-constructor-message
  (missing-resize-constructor-message
   (lambda ()
     (make-resize-observer callback))))

(define intersection-observe-message
  (missing-intersection-message
   "observe"
   (lambda ()
     (define observer (make-intersection-observer callback))
     (check-true (intersection-observer? observer)
                 "intersection-observer? accepts fake host observer")
     (intersection-observer-observe! observer target))))

(define intersection-unobserve-message
  (missing-intersection-message
   "unobserve"
   (lambda ()
     (define observer (make-intersection-observer callback))
     (intersection-observer-unobserve! observer target))))

(define intersection-disconnect-message
  (missing-intersection-message
   "disconnect"
   (lambda ()
     (define observer (make-intersection-observer callback))
     (intersection-observer-disconnect! observer))))

(define resize-observe-message
  (missing-resize-message
   "observe"
   (lambda ()
     (define observer (make-resize-observer callback))
     (check-true (resize-observer? observer)
                 "resize-observer? accepts fake host observer")
     (resize-observer-observe! observer target))))

(define resize-unobserve-message
  (missing-resize-message
   "unobserve"
   (lambda ()
     (define observer (make-resize-observer callback))
     (resize-observer-unobserve! observer target))))

(define resize-disconnect-message
  (missing-resize-message
   "disconnect"
   (lambda ()
     (define observer (make-resize-observer callback))
     (resize-observer-disconnect! observer))))

(check-message intersection-constructor-message
               "IntersectionObserver is not available"
               "missing IntersectionObserver constructor message")
(check-message intersection-observe-message
               "IntersectionObserver.observe is not available"
               "missing IntersectionObserver.observe message")
(check-message intersection-unobserve-message
               "IntersectionObserver.unobserve is not available"
               "missing IntersectionObserver.unobserve message")
(check-message intersection-disconnect-message
               "IntersectionObserver.disconnect is not available"
               "missing IntersectionObserver.disconnect message")
(check-message resize-constructor-message
               "ResizeObserver is not available"
               "missing ResizeObserver constructor message")
(check-message resize-observe-message
               "ResizeObserver.observe is not available"
               "missing ResizeObserver.observe message")
(check-message resize-unobserve-message
               "ResizeObserver.unobserve is not available"
               "missing ResizeObserver.unobserve message")
(check-message resize-disconnect-message
               "ResizeObserver.disconnect is not available"
               "missing ResizeObserver.disconnect message")

(js-eval "__wrObserverBoundaryRestore();")

(js-log "observer-method-missing-host-ffi-ok")
#t
