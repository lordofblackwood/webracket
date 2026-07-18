#lang webracket/base

;; Browser smoke for Fullscreen wrapper host-method boundary errors.

(require fullscreen
         (only-in webracket/unsafe/dom
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
 "globalThis.__wrFullscreenBoundaryFakeElement = {};
  globalThis.__wrFullscreenBoundarySavedDocument = {};
  globalThis.__wrFullscreenBoundaryPatchDocument = (methodName) => {
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrFullscreenBoundarySavedDocument, methodName)) {
      globalThis.__wrFullscreenBoundarySavedDocument[methodName] =
        Object.getOwnPropertyDescriptor(document, methodName) || null;
    }
    Object.defineProperty(document, methodName, {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrFullscreenBoundaryRestoreDocument = (methodName) => {
    const descriptor = globalThis.__wrFullscreenBoundarySavedDocument[methodName];
    if (descriptor) {
      Object.defineProperty(document, methodName, descriptor);
    } else {
      delete document[methodName];
    }
    delete globalThis.__wrFullscreenBoundarySavedDocument[methodName];
  };
  globalThis.__wrFullscreenBoundaryRestoreAll = () => {
    for (const methodName of Object.keys(globalThis.__wrFullscreenBoundarySavedDocument)) {
      globalThis.__wrFullscreenBoundaryRestoreDocument(methodName);
    }
    delete globalThis.__wrFullscreenBoundaryFakeElement;
    delete globalThis.__wrFullscreenBoundarySavedDocument;
    delete globalThis.__wrFullscreenBoundaryPatchDocument;
    delete globalThis.__wrFullscreenBoundaryRestoreDocument;
    delete globalThis.__wrFullscreenBoundaryRestoreAll;
  };")

(define fake-element
  (js-eval "__wrFullscreenBoundaryFakeElement"))

(define (missing-document-method-message method thunk)
  (js-eval (string-append "__wrFullscreenBoundaryPatchDocument('"
                          method
                          "')"))
  (define message (catch-message thunk))
  (js-eval (string-append "__wrFullscreenBoundaryRestoreDocument('"
                          method
                          "')"))
  message)

(define callback (lambda args (void)))

(define request-message
  (catch-message
   (lambda ()
     (fullscreen-request! fake-element))))

(define exit-message
  (missing-document-method-message
   "exitFullscreen"
   (lambda ()
     (fullscreen-exit!))))

(define add-change-message
  (missing-document-method-message
   "addEventListener"
   (lambda ()
     (fullscreen-add-change-listener! callback))))

(define remove-change-message
  (missing-document-method-message
   "removeEventListener"
   (lambda ()
     (fullscreen-remove-change-listener! callback))))

(define add-error-message
  (missing-document-method-message
   "addEventListener"
   (lambda ()
     (fullscreen-add-error-listener! callback))))

(define remove-error-message
  (missing-document-method-message
   "removeEventListener"
   (lambda ()
     (fullscreen-remove-error-listener! callback))))

(check-message request-message
               "Element.requestFullscreen is not available"
               "missing Element.requestFullscreen message")
(check-message exit-message
               "document.exitFullscreen is not available"
               "missing document.exitFullscreen message")
(check-message add-change-message
               "document.addEventListener is not available"
               "missing change addEventListener message")
(check-message remove-change-message
               "document.removeEventListener is not available"
               "missing change removeEventListener message")
(check-message add-error-message
               "document.addEventListener is not available"
               "missing error addEventListener message")
(check-message remove-error-message
               "document.removeEventListener is not available"
               "missing error removeEventListener message")

(js-eval "__wrFullscreenBoundaryRestoreAll();")

(js-log "fullscreen-method-missing-host-ffi-ok")
#t
