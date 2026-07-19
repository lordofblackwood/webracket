#lang webracket/base

;; Browser smoke for observer wrapper host-method boundary errors.

(require (only-in intersection-observer
                  intersection-observer?
                  intersection-observer-disconnect!
                  intersection-observer-entry
                  intersection-observer-entry-bounding-client-rect
                  intersection-observer-entry-intersection-ratio
                  intersection-observer-entry-intersection-rect
                  intersection-observer-entry-is-intersecting?
                  intersection-observer-entry-root-bounds
                  intersection-observer-entry-target
                  intersection-observer-entry-time
                  intersection-observer-observe!
                  intersection-observer-unobserve!
                  make-intersection-observer)
         (only-in resize-observer
                  make-resize-observer
                  resize-observer?
                  resize-observer-disconnect!
                  resize-observer-entry
                  resize-observer-entry-content-rect
                  resize-observer-entry-target
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
  globalThis.__wrObserverBoundaryRect = {
    x: 0,
    y: 0,
    width: 10,
    height: 20,
    top: 0,
    right: 10,
    bottom: 20,
    left: 0
  };
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
  globalThis.__wrObserverBoundaryInstallNonConstructorIntersection = () => {
    globalThis.IntersectionObserver = () => {};
  };
  globalThis.__wrObserverBoundaryInstallNonConstructorResize = () => {
    globalThis.ResizeObserver = () => {};
  };
  globalThis.__wrObserverBoundaryFakeIntersectionEntry = (missing) => {
    const entry = {
      target: globalThis.__wrObserverBoundaryTarget,
      isIntersecting: true,
      intersectionRatio: 0.5,
      boundingClientRect: globalThis.__wrObserverBoundaryRect,
      intersectionRect: globalThis.__wrObserverBoundaryRect,
      rootBounds: null,
      time: 12.5
    };
    delete entry[missing];
    return entry;
  };
  globalThis.__wrObserverBoundaryFakeResizeEntry = (missing) => {
    const entry = {
      target: globalThis.__wrObserverBoundaryTarget,
      contentRect: globalThis.__wrObserverBoundaryRect
    };
    delete entry[missing];
    return entry;
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
    delete globalThis.__wrObserverBoundaryRect;
    delete globalThis.__wrObserverBoundaryInstallIntersection;
    delete globalThis.__wrObserverBoundaryInstallResize;
    delete globalThis.__wrObserverBoundaryHideIntersection;
    delete globalThis.__wrObserverBoundaryHideResize;
    delete globalThis.__wrObserverBoundaryInstallNonConstructorIntersection;
    delete globalThis.__wrObserverBoundaryInstallNonConstructorResize;
    delete globalThis.__wrObserverBoundaryFakeIntersectionEntry;
    delete globalThis.__wrObserverBoundaryFakeResizeEntry;
    delete globalThis.__wrObserverBoundaryRestoreIntersection;
    delete globalThis.__wrObserverBoundaryRestoreResize;
    delete globalThis.__wrObserverBoundaryRestore;
  };")

(define target (js-eval "globalThis.__wrObserverBoundaryTarget"))
(define callback (lambda args (void)))

(define (fake-intersection-entry missing-property)
  (intersection-observer-entry
   (js-eval
    (string-append "__wrObserverBoundaryFakeIntersectionEntry('"
                   missing-property
                   "')"))))

(define (fake-resize-entry missing-property)
  (resize-observer-entry
   (js-eval
    (string-append "__wrObserverBoundaryFakeResizeEntry('"
                   missing-property
                   "')"))))

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

(define (non-constructor-intersection-constructor-message thunk)
  (js-eval "__wrObserverBoundaryInstallNonConstructorIntersection();")
  (define message (catch-message thunk))
  (js-eval "__wrObserverBoundaryRestoreIntersection();")
  message)

(define (non-constructor-resize-constructor-message thunk)
  (js-eval "__wrObserverBoundaryInstallNonConstructorResize();")
  (define message (catch-message thunk))
  (js-eval "__wrObserverBoundaryRestoreResize();")
  message)

(define intersection-constructor-message
  (missing-intersection-constructor-message
   (lambda ()
     (make-intersection-observer callback))))

(define intersection-non-constructor-message
  (non-constructor-intersection-constructor-message
   (lambda ()
     (make-intersection-observer callback))))

(define resize-constructor-message
  (missing-resize-constructor-message
   (lambda ()
     (make-resize-observer callback))))

(define resize-non-constructor-message
  (non-constructor-resize-constructor-message
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

(define intersection-entry-target-message
  (catch-message
   (lambda ()
     (intersection-observer-entry-target (fake-intersection-entry "target")))))

(define intersection-entry-is-intersecting-message
  (catch-message
   (lambda ()
     (intersection-observer-entry-is-intersecting?
      (fake-intersection-entry "isIntersecting")))))

(define intersection-entry-ratio-message
  (catch-message
   (lambda ()
     (intersection-observer-entry-intersection-ratio
      (fake-intersection-entry "intersectionRatio")))))

(define intersection-entry-bounding-rect-message
  (catch-message
   (lambda ()
     (intersection-observer-entry-bounding-client-rect
      (fake-intersection-entry "boundingClientRect")))))

(define intersection-entry-intersection-rect-message
  (catch-message
   (lambda ()
     (intersection-observer-entry-intersection-rect
      (fake-intersection-entry "intersectionRect")))))

(define intersection-entry-root-bounds-message
  (catch-message
   (lambda ()
     (intersection-observer-entry-root-bounds
      (fake-intersection-entry "rootBounds")))))

(check-true (eq? (intersection-observer-entry-root-bounds
                  (fake-intersection-entry "notAProperty"))
                 #f)
            "IntersectionObserverEntry.rootBounds null still maps to #f")

(define intersection-entry-time-message
  (catch-message
   (lambda ()
     (intersection-observer-entry-time (fake-intersection-entry "time")))))

(define resize-entry-target-message
  (catch-message
   (lambda ()
     (resize-observer-entry-target (fake-resize-entry "target")))))

(define resize-entry-content-rect-message
  (catch-message
   (lambda ()
     (resize-observer-entry-content-rect (fake-resize-entry "contentRect")))))

(check-message intersection-constructor-message
               "IntersectionObserver is not available"
               "missing IntersectionObserver constructor message")
(check-message intersection-non-constructor-message
               "IntersectionObserver is not available"
               "non-constructible IntersectionObserver constructor message")
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
(check-message resize-non-constructor-message
               "ResizeObserver is not available"
               "non-constructible ResizeObserver constructor message")
(check-message resize-observe-message
               "ResizeObserver.observe is not available"
               "missing ResizeObserver.observe message")
(check-message resize-unobserve-message
               "ResizeObserver.unobserve is not available"
               "missing ResizeObserver.unobserve message")
(check-message resize-disconnect-message
               "ResizeObserver.disconnect is not available"
               "missing ResizeObserver.disconnect message")
(check-message intersection-entry-target-message
               "IntersectionObserverEntry.target is not available"
               "missing IntersectionObserverEntry.target message")
(check-message intersection-entry-is-intersecting-message
               "IntersectionObserverEntry.isIntersecting is not available"
               "missing IntersectionObserverEntry.isIntersecting message")
(check-message intersection-entry-ratio-message
               "IntersectionObserverEntry.intersectionRatio is not available"
               "missing IntersectionObserverEntry.intersectionRatio message")
(check-message intersection-entry-bounding-rect-message
               "IntersectionObserverEntry.boundingClientRect is not available"
               "missing IntersectionObserverEntry.boundingClientRect message")
(check-message intersection-entry-intersection-rect-message
               "IntersectionObserverEntry.intersectionRect is not available"
               "missing IntersectionObserverEntry.intersectionRect message")
(check-message intersection-entry-root-bounds-message
               "IntersectionObserverEntry.rootBounds is not available"
               "missing IntersectionObserverEntry.rootBounds message")
(check-message intersection-entry-time-message
               "IntersectionObserverEntry.time is not available"
               "missing IntersectionObserverEntry.time message")
(check-message resize-entry-target-message
               "ResizeObserverEntry.target is not available"
               "missing ResizeObserverEntry.target message")
(check-message resize-entry-content-rect-message
               "ResizeObserverEntry.contentRect is not available"
               "missing ResizeObserverEntry.contentRect message")

(js-eval "__wrObserverBoundaryRestore();")

(js-log "observer-method-missing-host-ffi-ok")
#t
