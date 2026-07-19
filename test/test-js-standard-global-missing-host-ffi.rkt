#lang webracket/base

;; Browser smoke for JS standard-global accessors when globals are absent.

(require (only-in webracket/unsafe/standard
                  js-AsyncIterator
                  js-BigInt
                  js-Intl
                  js-IntlCollator
                  js-SharedArrayBuffer
                  js-DisposableStack
                  js-eval
                  js-truthy?
                  js-undefined?))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(js-eval
 "globalThis.__wrStandardGlobalBoundarySaved = {};
  globalThis.__wrStandardGlobalBoundaryHide = (name) => {
    if (!Object.prototype.hasOwnProperty.call(globalThis.__wrStandardGlobalBoundarySaved, name)) {
      globalThis.__wrStandardGlobalBoundarySaved[name] =
        Object.getOwnPropertyDescriptor(globalThis, name) || null;
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
      Object.defineProperty(globalThis, name, saved);
    } else {
      delete globalThis[name];
    }
    delete globalThis.__wrStandardGlobalBoundarySaved[name];
  };
  globalThis.__wrStandardGlobalBoundaryRestoreAll = () => {
    for (const name of Object.keys(globalThis.__wrStandardGlobalBoundarySaved)) {
      globalThis.__wrStandardGlobalBoundaryRestore(name);
    }
    delete globalThis.__wrStandardGlobalBoundarySaved;
    delete globalThis.__wrStandardGlobalBoundaryHide;
    delete globalThis.__wrStandardGlobalBoundaryRestore;
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

(js-eval "__wrStandardGlobalBoundaryRestoreAll();")

(js-log "js-standard-global-missing-host-ffi-ok")
#t
