#lang webracket/base

;; Browser smoke for optional window host functions.

(require browser/window
         (only-in webracket/unsafe/standard
                  js-eval)
         (only-in webracket/unsafe/window
                  js-window-create-image-bitmap
                  js-window-queue-microtask
                  js-window-report-error))

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

(define callback (js-eval "() => {}"))
(define image-source (js-eval "new Blob(['x'])"))

(js-eval
 "globalThis.__wrWindowBoundary = {
    cancelIdleCallback: window.cancelIdleCallback,
    createImageBitmap: window.createImageBitmap,
    fetch: window.fetch,
    queueMicrotask: window.queueMicrotask,
    reportError: window.reportError,
    requestIdleCallback: window.requestIdleCallback,
    structuredClone: window.structuredClone
  };
  window.cancelIdleCallback = undefined;
  window.createImageBitmap = undefined;
  window.fetch = undefined;
  window.queueMicrotask = undefined;
  window.reportError = undefined;
  window.requestIdleCallback = undefined;
  window.structuredClone = undefined;")

(define cancel-idle-message
  (catch-message
   (lambda ()
     (window-cancel-idle-callback 1))))

(define create-image-bitmap-message
  (catch-message
   (lambda ()
     (js-window-create-image-bitmap image-source
                                    (void)
                                    (void)
                                    (void)
                                    (void)
                                    (void)))))

(define fetch-message
  (catch-message
   (lambda ()
     (window-fetch "https://example.invalid/"))))

(define queue-microtask-message
  (catch-message
   (lambda ()
     (js-window-queue-microtask callback))))

(define report-error-message
  (catch-message
   (lambda ()
     (js-window-report-error "boom"))))

(define request-idle-message
  (catch-message
   (lambda ()
     (window-request-idle-callback callback))))

(define structured-clone-message
  (catch-message
   (lambda ()
     (window-structured-clone "value"))))

(js-eval
 "window.cancelIdleCallback = globalThis.__wrWindowBoundary.cancelIdleCallback;
  window.createImageBitmap = globalThis.__wrWindowBoundary.createImageBitmap;
  window.fetch = globalThis.__wrWindowBoundary.fetch;
  window.queueMicrotask = globalThis.__wrWindowBoundary.queueMicrotask;
  window.reportError = globalThis.__wrWindowBoundary.reportError;
  window.requestIdleCallback = globalThis.__wrWindowBoundary.requestIdleCallback;
  window.structuredClone = globalThis.__wrWindowBoundary.structuredClone;
  delete globalThis.__wrWindowBoundary;")

(check-message cancel-idle-message
               "window.cancelIdleCallback not available in this environment"
               "missing cancelIdleCallback message")
(check-message create-image-bitmap-message
               "window.createImageBitmap not available in this environment"
               "missing createImageBitmap message")
(check-message fetch-message
               "window.fetch not available in this environment"
               "missing fetch message")
(check-message queue-microtask-message
               "window.queueMicrotask not available in this environment"
               "missing queueMicrotask message")
(check-message report-error-message
               "window.reportError not available in this environment"
               "missing reportError message")
(check-message request-idle-message
               "window.requestIdleCallback not available in this environment"
               "missing requestIdleCallback message")
(check-message structured-clone-message
               "window.structuredClone not available in this environment"
               "missing structuredClone message")

(js-log "window-missing-host-ffi-ok")
#t
