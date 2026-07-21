#lang webracket/base

;; Browser smoke for generic JS standard operations at hostile host boundaries.

(require (only-in webracket/unsafe/standard
                  js-eval
                  js-instanceof
                  js-null
                  js-operator
                  js-ref
                  js-send/boolean
                  js-send/flonum
                  js-truthy?
                  js-value->string))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

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

(define (catch-message/restoring thunk restore!)
  (with-handlers ([exn:fail?
                   (lambda (e)
                     (restore!)
                     (exn-message e))])
    (thunk)
    (restore!)
    #f))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(js-eval
 "globalThis.__wrStandardGenericBoundarySaved = {};
  globalThis.__wrStandardGenericBoundarySavedPrototypeMethods = {};
  globalThis.__wrStandardGenericBoundaryBoxedBoolean = new Boolean(false);
  globalThis.__wrStandardGenericBoundaryBoxedNumber = new Number(1.5);
  globalThis.__wrStandardGenericBoundaryTarget = {
    boxedNumberValue: globalThis.__wrStandardGenericBoundaryBoxedNumber,
    boxedBoolean() {
      return globalThis.__wrStandardGenericBoundaryBoxedBoolean;
    },
    boxedNumber() {
      return globalThis.__wrStandardGenericBoundaryBoxedNumber;
    }
  };
  globalThis.__wrStandardGenericBoundaryHide = (name) => {
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrStandardGenericBoundarySaved, name)) {
      globalThis.__wrStandardGenericBoundarySaved[name] =
        Object.getOwnPropertyDescriptor(globalThis, name) || null;
    }

    try {
      return delete globalThis[name];
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardGenericBoundaryRestore = (name) => {
    const saved = globalThis.__wrStandardGenericBoundarySaved[name];
    if (saved) {
      Object.defineProperty(globalThis, name, saved);
    } else {
      delete globalThis[name];
    }
    delete globalThis.__wrStandardGenericBoundarySaved[name];
  };
  globalThis.__wrStandardGenericBoundaryHidePrototypeMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName] && globalThis[ownerName].prototype;
    if (!owner) {
      return false;
    }
    const key = ownerName + '.' + methodName;
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrStandardGenericBoundarySavedPrototypeMethods, key)) {
      globalThis.__wrStandardGenericBoundarySavedPrototypeMethods[key] =
        Object.getOwnPropertyDescriptor(owner, methodName) || null;
    }

    try {
      Object.defineProperty(owner, methodName, {
        value: undefined,
        configurable: true,
        writable: true
      });
      return true;
    } catch (_e) {
      return false;
    }
  };
  globalThis.__wrStandardGenericBoundaryRestorePrototypeMethod = (ownerName, methodName) => {
    const owner = globalThis[ownerName] && globalThis[ownerName].prototype;
    const key = ownerName + '.' + methodName;
    const saved = globalThis.__wrStandardGenericBoundarySavedPrototypeMethods[key];
    if (owner && saved) {
      Object.defineProperty(owner, methodName, saved);
    } else if (owner) {
      delete owner[methodName];
    }
    delete globalThis.__wrStandardGenericBoundarySavedPrototypeMethods[key];
  };
  globalThis.__wrStandardGenericBoundaryRestoreAll = () => {
    for (const name of Object.keys(globalThis.__wrStandardGenericBoundarySaved)) {
      globalThis.__wrStandardGenericBoundaryRestore(name);
    }
    for (const key of Object.keys(globalThis.__wrStandardGenericBoundarySavedPrototypeMethods)) {
      const parts = key.split('.');
      globalThis.__wrStandardGenericBoundaryRestorePrototypeMethod(parts[0], parts[1]);
    }
    delete globalThis.__wrStandardGenericBoundarySaved;
    delete globalThis.__wrStandardGenericBoundarySavedPrototypeMethods;
    delete globalThis.__wrStandardGenericBoundaryHide;
    delete globalThis.__wrStandardGenericBoundaryRestore;
    delete globalThis.__wrStandardGenericBoundaryHidePrototypeMethod;
    delete globalThis.__wrStandardGenericBoundaryRestorePrototypeMethod;
    delete globalThis.__wrStandardGenericBoundaryRestoreAll;
    delete globalThis.__wrStandardGenericBoundaryBoxedBoolean;
    delete globalThis.__wrStandardGenericBoundaryBoxedNumber;
    delete globalThis.__wrStandardGenericBoundaryTarget;
  };")

;; hidden-global? : string? -> boolean?
;;   Hide a global binding when the browser allows it.
(define (hidden-global? name)
  (js-truthy?
   (js-eval (string-append "__wrStandardGenericBoundaryHide('"
                           name
                           "')"))))

;; restore-global! : string? -> void?
;;   Restore a global binding after a boundary check.
(define (restore-global! name)
  (js-eval (string-append "__wrStandardGenericBoundaryRestore('"
                          name
                          "')"))
  (void))

;; check-hidden-global : string? (-> any/c) string? string? -> void?
;;   Check that an absent global reports a clear catchable error.
(define (check-hidden-global name thunk needle label)
  (cond
    [(hidden-global? name)
     (define message
       (catch-message/restoring thunk
                                (lambda () (restore-global! name))))
     (check-message message needle label)]
    [else
     (restore-global! name)]))

;; hidden-prototype-method? : string? string? -> boolean?
;;   Hide a host prototype method when the browser allows it.
(define (hidden-prototype-method? owner-name method-name)
  (js-truthy?
   (js-eval (string-append "__wrStandardGenericBoundaryHidePrototypeMethod('"
                           owner-name
                           "', '"
                           method-name
                           "')"))))

;; restore-prototype-method! : string? string? -> void?
;;   Restore a host prototype method after a boundary check.
(define (restore-prototype-method! owner-name method-name)
  (js-eval (string-append "__wrStandardGenericBoundaryRestorePrototypeMethod('"
                          owner-name
                          "', '"
                          method-name
                          "')"))
  (void))

;; check-hidden-prototype-method : string? string? (-> any/c) string? string? -> void?
;;   Check that an absent prototype method reports a clear catchable error.
(define (check-hidden-prototype-method owner-name method-name thunk needle label)
  (cond
    [(hidden-prototype-method? owner-name method-name)
     (define message
       (catch-message/restoring thunk
                                (lambda ()
                                  (restore-prototype-method! owner-name method-name))))
     (check-message message needle label)]
    [else
     (restore-prototype-method! owner-name method-name)]))

(check-hidden-global "String"
                     (lambda () (js-value->string (js-null)))
                     "String not available in this environment"
                     "missing String message")

(check-hidden-global "Function"
                     (lambda () (js-operator "+" (vector 1 2)))
                     "Function not available in this environment"
                     "missing Function message")

(check-message
 (catch-message
  (lambda () (js-instanceof (js-eval "({})") (js-null))))
 "js-instanceof: constructor is null or undefined"
 "null instanceof constructor message")

(check-message
 (catch-message
  (lambda () (js-instanceof (js-eval "({})") (js-eval "({})"))))
 "js-instanceof: expected constructor function, got object"
 "object instanceof constructor message")

(check-message
 (catch-message
  (lambda () (js-instanceof (js-eval "({})") (js-eval "(() => {})"))))
 "js-instanceof: expected constructible function"
 "non-constructor instanceof message")

(define boundary-target
  (js-eval "__wrStandardGenericBoundaryTarget"))

(check-hidden-global "Boolean"
                     (lambda () (js-send/boolean boundary-target
                                                 "boxedBoolean"
                                                 (vector)))
                     "js-send/boolean: expected boolean result, got object"
                     "boxed Boolean missing constructor message")

(check-hidden-global "Number"
                     (lambda () (js-send/flonum boundary-target
                                                "boxedNumber"
                                                (vector)))
                     "js-send/flonum: expected number result, got object"
                     "boxed Number missing constructor message")

(check-hidden-prototype-method "Boolean"
                               "valueOf"
                               (lambda () (js-send/boolean boundary-target
                                                           "boxedBoolean"
                                                           (vector)))
                               "Boolean.valueOf not available in this environment"
                               "boxed Boolean missing valueOf message")

(check-hidden-prototype-method "Number"
                               "valueOf"
                               (lambda () (js-send/flonum boundary-target
                                                          "boxedNumber"
                                                          (vector)))
                               "Number.valueOf not available in this environment"
                               "boxed Number missing valueOf message")

(check-hidden-prototype-method "Number"
                               "valueOf"
                               (lambda () (js-ref boundary-target "boxedNumberValue"))
                               "Number.valueOf not available in this environment"
                               "boxed Number FASL conversion missing valueOf message")

(js-eval "__wrStandardGenericBoundaryRestoreAll();")

(js-log "js-standard-generic-missing-host-ffi-ok")
#t
