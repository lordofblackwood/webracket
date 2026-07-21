#lang webracket/base

;; Browser smoke for JS standard-global accessors when globals are absent.

(require (only-in webracket/unsafe/standard
                  js-AsyncIterator
                  js-AsyncGenerator
                  js-BigInt
                  js-Intl
                  js-IntlCollator
                  js-SharedArrayBuffer
                  js-DisposableStack
                  js-eval
                  js-Generator
                  js-truthy?
                  js-undefined?))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

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
 "const wrStandardGlobalBoundaryObject = Object;
  const wrStandardGlobalBoundaryObjectDefineProperty = Object.defineProperty;
  const wrStandardGlobalBoundaryObjectGetOwnPropertyDescriptor = Object.getOwnPropertyDescriptor;
  const wrStandardGlobalBoundaryObjectKeys = Object.keys;
  const wrStandardGlobalBoundaryHasOwnProperty = Object.prototype.hasOwnProperty;
  globalThis.__wrStandardGlobalBoundarySaved = {};
  globalThis.__wrStandardGlobalBoundarySavedMethods = {};
  globalThis.__wrStandardGlobalBoundaryHide = (name) => {
    if (!wrStandardGlobalBoundaryHasOwnProperty.call(globalThis.__wrStandardGlobalBoundarySaved, name)) {
      globalThis.__wrStandardGlobalBoundarySaved[name] =
        wrStandardGlobalBoundaryObjectGetOwnPropertyDescriptor(globalThis, name) || null;
    }

    try {
      return delete globalThis[name];
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardGlobalBoundaryRestore = (name) => {
    const saved = globalThis.__wrStandardGlobalBoundarySaved[name];
    if (saved) {
      wrStandardGlobalBoundaryObjectDefineProperty(globalThis, name, saved);
    } else {
      delete globalThis[name];
    }
    delete globalThis.__wrStandardGlobalBoundarySaved[name];
  };
  globalThis.__wrStandardGlobalBoundaryHideMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName];
    if (!owner) {
      return false;
    }
    const key = ownerName + '.' + methodName;
    if (!wrStandardGlobalBoundaryHasOwnProperty.call(globalThis.__wrStandardGlobalBoundarySavedMethods, key)) {
      globalThis.__wrStandardGlobalBoundarySavedMethods[key] =
        wrStandardGlobalBoundaryObjectGetOwnPropertyDescriptor(owner, methodName) || null;
    }

    try {
      wrStandardGlobalBoundaryObjectDefineProperty(owner, methodName, {
        value: undefined,
        configurable: true,
        writable: true
      });
      return true;
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardGlobalBoundaryRestoreMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName];
    const key = ownerName + '.' + methodName;
    const saved = globalThis.__wrStandardGlobalBoundarySavedMethods[key];
    if (owner && saved) {
      wrStandardGlobalBoundaryObjectDefineProperty(owner, methodName, saved);
    } else if (owner) {
      delete owner[methodName];
    }
    delete globalThis.__wrStandardGlobalBoundarySavedMethods[key];
  };
  globalThis.__wrStandardGlobalBoundaryRestoreAll = () => {
    for (const name of wrStandardGlobalBoundaryObjectKeys(globalThis.__wrStandardGlobalBoundarySavedMethods)) {
      const parts = name.split('.');
      globalThis.__wrStandardGlobalBoundaryRestoreMethod(parts[0], parts[1]);
    }
    for (const name of wrStandardGlobalBoundaryObjectKeys(globalThis.__wrStandardGlobalBoundarySaved)) {
      globalThis.__wrStandardGlobalBoundaryRestore(name);
    }
    delete globalThis.__wrStandardGlobalBoundarySaved;
    delete globalThis.__wrStandardGlobalBoundarySavedMethods;
    delete globalThis.__wrStandardGlobalBoundaryHide;
    delete globalThis.__wrStandardGlobalBoundaryRestore;
    delete globalThis.__wrStandardGlobalBoundaryHideMethod;
    delete globalThis.__wrStandardGlobalBoundaryRestoreMethod;
    delete globalThis.__wrStandardGlobalBoundaryRestoreAll;
  };")

;; hidden-global? : string? -> boolean?
;;   Hide a global property when the browser allows it.
(define (hidden-global? name)
  (js-truthy?
   (js-eval (string-append "__wrStandardGlobalBoundaryHide('"
                           name
                           "')"))))

;; restore-global! : string? -> void?
;;   Restore a global property after a boundary check.
(define (restore-global! name)
  (js-eval (string-append "__wrStandardGlobalBoundaryRestore('"
                          name
                          "')"))
  (void))

;; check-hidden-global : string? (-> external/raw) string? -> void?
;;   Check that an absent standard global is reported as JavaScript undefined.
(define (check-hidden-global name thunk label)
  (cond
    [(hidden-global? name)
     (with-handlers ([exn:fail?
                      (lambda (e)
                        (restore-global! name)
                        (raise e))])
       (define value (thunk))
       (restore-global! name)
       (check-true (js-undefined? value) label))]
    [else
     (restore-global! name)]))

;; check-hidden-global-message : string? (-> any/c) string? string? -> void?
;;   Check that a hidden standard global produces a clear catchable error.
(define (check-hidden-global-message name thunk needle label)
  (cond
    [(hidden-global? name)
     (define message
       (catch-message/restoring thunk
                                (lambda () (restore-global! name))))
     (check-message message needle label)]
    [else
     (restore-global! name)]))

;; hidden-method? : string? string? -> boolean?
;;   Hide a standard global method when the browser allows it.
(define (hidden-method? owner-name method-name)
  (js-truthy?
   (js-eval (string-append "__wrStandardGlobalBoundaryHideMethod('"
                           owner-name
                           "', '"
                           method-name
                           "')"))))

;; restore-method! : string? string? -> void?
;;   Restore a standard global method after a boundary check.
(define (restore-method! owner-name method-name)
  (js-eval (string-append "__wrStandardGlobalBoundaryRestoreMethod('"
                          owner-name
                          "', '"
                          method-name
                          "')"))
  (void))

;; check-hidden-method-message : string? string? (-> any/c) string? string? -> void?
;;   Check that a hidden standard global method produces a clear catchable error.
(define (check-hidden-method-message owner-name method-name thunk needle label)
  (cond
    [(hidden-method? owner-name method-name)
     (define message
       (catch-message/restoring thunk
                                (lambda ()
                                  (restore-method! owner-name method-name))))
     (check-message message needle label)]
    [else
     (restore-method! owner-name method-name)]))

(check-hidden-global "BigInt"
                     js-BigInt
                     "missing BigInt reports undefined")
(check-hidden-global "SharedArrayBuffer"
                     js-SharedArrayBuffer
                     "missing SharedArrayBuffer reports undefined")
(check-hidden-global "Intl"
                     js-Intl
                     "missing Intl reports undefined")
(check-hidden-global "Intl"
                     js-IntlCollator
                     "missing Intl.Collator reports undefined")
(check-hidden-global "AsyncIterator"
                     js-AsyncIterator
                     "missing AsyncIterator reports undefined")
(check-hidden-global "DisposableStack"
                     js-DisposableStack
                     "missing DisposableStack reports undefined")

(check-hidden-global-message "Object"
                             js-Generator
                             "Object.getPrototypeOf not available in this environment"
                             "missing Object reports clear Generator message")
(check-hidden-global-message "Object"
                             js-AsyncGenerator
                             "Object.getPrototypeOf not available in this environment"
                             "missing Object reports clear AsyncGenerator message")

(check-hidden-method-message "Object"
                             "getPrototypeOf"
                             js-Generator
                             "Object.getPrototypeOf not available in this environment"
                             "missing Object.getPrototypeOf Generator message")
(check-hidden-method-message "Object"
                             "getPrototypeOf"
                             js-AsyncGenerator
                             "Object.getPrototypeOf not available in this environment"
                             "missing Object.getPrototypeOf AsyncGenerator message")

(js-eval "__wrStandardGlobalBoundaryRestoreAll();")

(js-log "js-standard-global-missing-host-ffi-ok")
#t
