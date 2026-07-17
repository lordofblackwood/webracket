#lang webracket/base

;; Browser smoke for optional/deprecated document host functions.

(require (only-in webracket/unsafe/document
                  js-caret-range-from-point
                  js-create-expression
                  js-enable-style-sheets-for-set
                  js-evaluate
                  js-exit-fullscreen
                  js-exit-picture-in-picture
                  js-exit-pointer-lock
                  js-release-events)
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

(define js-null (js-eval "null"))
(define js-document (js-eval "document"))

(js-eval
 "globalThis.__wrDocumentBoundaryNames = [
    'caretRangeFromPoint',
    'createExpression',
    'enableStyleSheetsForSet',
    'evaluate',
    'exitFullscreen',
    'exitPictureInPicture',
    'exitPointerLock',
    'releaseEvents'
  ];
  globalThis.__wrDocumentBoundary = {};
  for (const name of globalThis.__wrDocumentBoundaryNames) {
    globalThis.__wrDocumentBoundary[name] = {
      descriptor: Object.getOwnPropertyDescriptor(document, name)
    };
    Object.defineProperty(document, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  }")

(define caret-message
  (catch-message
   (lambda ()
     (js-caret-range-from-point 0.0 0.0))))

(define create-expression-message
  (catch-message
   (lambda ()
     (js-create-expression "//*" js-null))))

(define enable-style-sheets-message
  (catch-message
   (lambda ()
     (js-enable-style-sheets-for-set "missing"))))

(define evaluate-message
  (catch-message
   (lambda ()
     (js-evaluate "//*" js-document js-null 0 js-null))))

(define exit-fullscreen-message
  (catch-message
   (lambda ()
     (js-exit-fullscreen))))

(define exit-picture-in-picture-message
  (catch-message
   (lambda ()
     (js-exit-picture-in-picture))))

(define exit-pointer-lock-message
  (catch-message
   (lambda ()
     (js-exit-pointer-lock))))

(define release-events-message
  (catch-message
   (lambda ()
     (js-release-events))))

(js-eval
 "for (const name of globalThis.__wrDocumentBoundaryNames) {
    const saved = globalThis.__wrDocumentBoundary[name];
    if (saved.descriptor) {
      Object.defineProperty(document, name, saved.descriptor);
    } else {
      delete document[name];
    }
  }
  delete globalThis.__wrDocumentBoundary;
  delete globalThis.__wrDocumentBoundaryNames;")

(check-message caret-message
               "document.caretRangeFromPoint not available in this environment"
               "missing caretRangeFromPoint message")
(check-message create-expression-message
               "document.createExpression not available in this environment"
               "missing createExpression message")
(check-message enable-style-sheets-message
               "document.enableStyleSheetsForSet not available in this environment"
               "missing enableStyleSheetsForSet message")
(check-message evaluate-message
               "document.evaluate not available in this environment"
               "missing evaluate message")
(check-message exit-fullscreen-message
               "document.exitFullscreen not available in this environment"
               "missing exitFullscreen message")
(check-message exit-picture-in-picture-message
               "document.exitPictureInPicture not available in this environment"
               "missing exitPictureInPicture message")
(check-message exit-pointer-lock-message
               "document.exitPointerLock not available in this environment"
               "missing exitPointerLock message")
(check-message release-events-message
               "document.releaseEvents not available in this environment"
               "missing releaseEvents message")

(js-log "document-missing-host-ffi-ok")
#t
